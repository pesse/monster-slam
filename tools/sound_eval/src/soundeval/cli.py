"""Kommandozeile: sound-eval doctor | effects | evaluate | batch | rank | generate | budget."""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

TOOL_DIR = Path(__file__).resolve().parents[2]
DEFAULT_PROFILE = TOOL_DIR / "profiles" / "monster_slam.yaml"
DEFAULT_OUT = TOOL_DIR / "reports"
DEFAULT_GENERATED = TOOL_DIR / "generated"
EXIT_NEEDS_CONFIRMATION = 3


def _profile(args):
    from .profile import load_profile

    return load_profile(args.profile)


def _evaluator(args, profile):
    from .clap import ClapEmbedder
    from .evaluate import Evaluator

    print(f"Lade CLAP ({profile.model}) …", file=sys.stderr)
    embedder = ClapEmbedder(profile.model, device=args.device, use_cache=not args.no_cache)
    print(f"Gerät: {embedder.device}", file=sys.stderr)
    return Evaluator(profile, embedder, use_references=not args.no_references)


def _summary(report: dict) -> str:
    rows = report.get("ranking")
    by_file = {r["file"]: r for r in report["results"]}
    order = [by_file[r["file"]] for r in rows] if rows else report["results"]
    out = []
    for i, r in enumerate(order):
        s = r["scores"]
        f = lambda k: "  –" if s.get(k) is None else f"{s[k]:3.0f}"  # noqa: E731
        star = "★" if rows and rows[i]["recommended"] else " "
        name = Path(r["file"]).name
        if r.get("error"):
            out.append(f"  {name:32s} FEHLER: {r['error']}")
            continue
        out.append(
            f"{star} {name:32s} {r['effect'] or '–':22s} gesamt {f('total')} | sem {f('semantic')} stil {f('style')} "
            f"ref {f('reference')} tech {f('technical')} | {r['verdict']}"
        )
    return "\n".join(out)


def _finish(args, report: dict, stem: str) -> int:
    from . import report as rep

    if args.json:
        print(json.dumps(report, ensure_ascii=False, indent=2))
        return 0
    print(_summary(report))
    if not args.no_write:
        j, md = rep.write(report, Path(args.out), stem)
        print(f"\nReport: {md}\nJSON:   {j}")
    print(f"\nHinweis: {report['disclaimer']}")
    return 0


def cmd_evaluate(args) -> int:
    from . import report as rep
    from .audio import find_audio

    profile = _profile(args)
    files = find_audio(args.paths, recursive=not args.flat)
    if not files:
        print("Keine Audiodateien gefunden.", file=sys.stderr)
        return 1
    ev = _evaluator(args, profile)
    results = ev.evaluate(files, args.effect)
    ranking = rep.rank(results, args.top) if args.command == "rank" else None
    report = rep.build(results, profile.name, profile.model, args.command, ranking)
    stem = f"{args.command}-{args.effect}" if args.effect else args.command
    return _finish(args, report, stem)


def cmd_effects(args) -> int:
    profile = _profile(args)
    print(f"Profil: {profile.name} ({profile.path})\n")
    for e in profile.effects.values():
        dur = f"{e.duration[0]}–{e.duration[1]} s" if e.duration else "–"
        print(f"{e.name:22s} {dur:12s} {e.description}")
    return 0


def cmd_generate(args) -> int:
    from . import elevenlabs as el
    from . import report as rep

    profile = _profile(args)
    effect = profile.effects.get(args.effect) if args.effect else None
    if args.effect and effect is None:
        print(f"Effekt '{args.effect}' steht nicht im Profil.", file=sys.stderr)
        return 1
    prompt = args.prompt or (profile.generation_prompt(effect) if effect else None)
    if not prompt:
        print("--effect oder --prompt angeben.", file=sys.stderr)
        return 1
    duration = args.duration
    if duration is None and effect and effect.duration and not args.auto_duration:
        duration = round(max(0.5, sum(effect.duration) / 2), 2)  # Mitte des gewünschten Bereichs
    settings = el.settings_for(profile.elevenlabs)
    if args.max_credits is not None:
        settings["max_credits_per_run"] = args.max_credits
    try:
        plan = el.make_plan(prompt, args.variants, duration, settings)
    except (el.BudgetError, ValueError) as exc:
        print(f"Abgebrochen: {exc}", file=sys.stderr)
        return 2
    spent = el.spent_total()
    print(
        f"Plan: {plan.variants} × \"{plan.prompt}\" "
        f"({'Dauer ' + str(plan.duration) + ' s' if plan.duration else 'Dauer automatisch'}, prompt_influence {settings['prompt_influence']})\n"
        f"Geschätzte Kosten: {plan.credits_total} Credits ({plan.credits_each} je Variante). "
        f"Bisher laut Ledger: {spent} von {settings['max_credits_total']}."
    )
    if args.dry_run:
        return 0
    confirmed = args.yes
    if not confirmed and sys.stdin.isatty():
        confirmed = input("Kostenpflichtig generieren? [j/N] ").strip().lower() in ("j", "ja", "y", "yes")
    if not confirmed:
        print("Nicht gesendet. Nach Bestätigung mit --yes erneut aufrufen.", file=sys.stderr)
        return EXIT_NEEDS_CONFIRMATION
    if not os.environ.get("ELEVENLABS_API_KEY"):
        print("ELEVENLABS_API_KEY ist nicht gesetzt.", file=sys.stderr)
        return 1
    files = el.generate(plan, Path(args.generated), name=args.effect, confirmed=True)
    print("Erzeugt:\n" + "\n".join(f"  {f}" for f in files))
    ev = _evaluator(args, profile)
    results = ev.evaluate(files, args.effect)
    report = rep.build(results, profile.name, profile.model, "generate", rep.rank(results, args.top))
    report["generation"] = {"prompt": plan.prompt, "duration": plan.duration, "credits_estimated": plan.credits_total}
    return _finish(args, report, f"generate-{args.effect or 'prompt'}")


def cmd_budget(args) -> int:
    from . import elevenlabs as el

    settings = el.settings_for(_profile(args).elevenlabs)
    print(f"Ledger: {el.ledger_path()}\nVerbraucht (geschätzt): {el.spent_total()} von {settings['max_credits_total']} Credits")
    return 0


def cmd_doctor(args) -> int:
    import platform

    ok = True
    print(f"Python      {platform.python_version()} ({sys.executable})")
    print(f"System      {platform.system()} {platform.release()}")
    try:
        import torch

        print(f"PyTorch     {torch.__version__}")
        if torch.cuda.is_available():
            cap = torch.cuda.get_device_capability(0)
            arch = f"sm_{cap[0]}{cap[1]}"
            supported = arch in torch.cuda.get_arch_list()
            print(f"CUDA        {torch.cuda.get_device_name(0)} ({arch}) – {'unterstützt' if supported else 'NICHT im Build: CPU-Fallback oder cu128-Build installieren'}")
            ok &= supported
        else:
            print("CUDA        nicht verfügbar – CPU wird verwendet (langsamer, funktioniert)")
    except ImportError:
        print("PyTorch     FEHLT – setup ausführen")
        ok = False
    try:
        import soundfile as sf

        mp3 = "MP3" in sf.available_formats()
        print(f"libsndfile  {sf.__libsndfile_version__} – MP3 {'ja' if mp3 else 'NEIN'}")
        ok &= mp3
    except ImportError:
        print("soundfile   FEHLT")
        ok = False
    try:
        import transformers

        print(f"transformers {transformers.__version__}")
    except ImportError:
        print("transformers FEHLT")
        ok = False
    try:
        profile = _profile(args)
        print(f"Profil      {profile.name}: {len(profile.effects)} Effekte, {len(profile.references)} Referenzquelle(n)")
        from .clap import model_cached

        print(f"Modell      {profile.model} – {'im Cache' if model_cached(profile.model) else 'wird beim ersten Lauf geladen (~800 MB)'}")
    except Exception as exc:  # Doctor soll alles zeigen, nicht beim ersten Fehler aufhören
        print(f"Profil      Fehler: {exc}")
        ok = False
    print(f"ElevenLabs  {'API-Key gesetzt' if os.environ.get('ELEVENLABS_API_KEY') else 'kein API-Key (optional)'}")
    if args.smoke:
        from .clap import ClapEmbedder

        emb = ClapEmbedder(_profile(args).model, device=args.device)
        t = emb.embed_text(["a dog barking"])
        print(f"Smoke-Test  CLAP-Text-Einbettung {t.shape} auf {emb.device} – ok")
    print("\nAlles bereit." if ok else "\nEs fehlt etwas (siehe oben).")
    return 0 if ok else 1


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="sound-eval", description="Bewertet Spiel-Soundeffekte lokal (LAION-CLAP + technische Analyse).")
    p.add_argument("--profile", default=os.environ.get("SOUND_EVAL_PROFILE", str(DEFAULT_PROFILE)), help="Setting-Profil (YAML)")
    p.add_argument("--device", default="auto", choices=["auto", "cpu", "cuda"])
    sub = p.add_subparsers(dest="command", required=True)

    def common(sp):
        sp.add_argument("--out", default=str(DEFAULT_OUT), help="Verzeichnis für Reports")
        sp.add_argument("--json", action="store_true", help="vollständigen JSON-Report auf stdout statt Zusammenfassung")
        sp.add_argument("--no-write", action="store_true", help="keine Report-Dateien schreiben")
        sp.add_argument("--no-references", action="store_true", help="ohne Referenz-Abgleich")
        sp.add_argument("--no-cache", action="store_true", help="Audio-Einbettungen nicht cachen")
        sp.add_argument("--top", type=int, default=1, help="so viele Varianten empfehlen (rank/generate)")

    for name, help_ in (("evaluate", "Dateien/Verzeichnisse bewerten"), ("batch", "wie evaluate, für ganze Verzeichnisse"),
                        ("rank", "Varianten eines Effekts vergleichen")):
        sp = sub.add_parser(name, help=help_)
        sp.add_argument("paths", nargs="+")
        sp.add_argument("--effect", help="Ziel-Effekt aus dem Profil (sonst per Dateimuster)")
        sp.add_argument("--flat", action="store_true", help="Verzeichnisse nicht rekursiv durchsuchen")
        common(sp)
        sp.set_defaults(func=cmd_evaluate)

    sp = sub.add_parser("generate", help="über ElevenLabs erzeugen (kostenpflichtig) und bewerten")
    sp.add_argument("--effect")
    sp.add_argument("--prompt", help="Text statt des Profil-Prompts")
    sp.add_argument("--variants", type=int, default=3)
    sp.add_argument("--duration", type=float, help="Sekunden (0,5–30); Standard: Mitte des Effekt-Bereichs")
    sp.add_argument("--auto-duration", action="store_true", help="Dauer vom Modell wählen lassen (teurer)")
    sp.add_argument("--max-credits", type=int, help="Limit für diesen Lauf")
    sp.add_argument("--dry-run", action="store_true", help="nur Kosten schätzen")
    sp.add_argument("--yes", action="store_true", help="Kosten bestätigt – senden")
    sp.add_argument("--generated", default=str(DEFAULT_GENERATED), help="Zielordner der erzeugten Dateien")
    common(sp)
    sp.set_defaults(func=cmd_generate)

    sp = sub.add_parser("effects", help="Effekte des Profils auflisten")
    sp.set_defaults(func=cmd_effects)
    sp = sub.add_parser("budget", help="verbrauchte ElevenLabs-Credits laut Ledger")
    sp.set_defaults(func=cmd_budget)
    sp = sub.add_parser("doctor", help="Umgebung prüfen")
    sp.add_argument("--smoke", action="store_true", help="zusätzlich CLAP laden und eine Einbettung rechnen")
    sp.set_defaults(func=cmd_doctor)
    return p


def main(argv: list[str] | None = None) -> int:
    if hasattr(sys.stdout, "reconfigure"):  # Windows-Konsole: Umlaute und ★ nicht an cp1252 scheitern lassen
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    os.environ.setdefault("TRANSFORMERS_VERBOSITY", "error")
    os.environ.setdefault("HF_HUB_DISABLE_PROGRESS_BARS", "1")
    args = build_parser().parse_args(argv)
    try:
        return args.func(args)
    except (KeyError, FileNotFoundError, ValueError) as exc:
        print(f"Fehler: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
