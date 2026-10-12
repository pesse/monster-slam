"""Ranking und Reports (JSON für Maschinen und Claude, Markdown für Menschen)."""

from __future__ import annotations

import datetime as dt
import json
from pathlib import Path

from .evaluate import DISCLAIMER, Evaluation

TIE_MARGIN = 3.0  # Punkte; darunter gelten Varianten als gleichauf
MIN_RECOMMEND = 50.0  # darunter wird nichts empfohlen, auch wenn es die beste Variante ist


def rank(evaluations: list[Evaluation], top: int = 1) -> list[dict]:
    """Sortiert nach Gesamtscore; Varianten mit hartem technischem Fehler stehen hinter allen anderen."""
    ok = sorted((e for e in evaluations if not e.error), key=lambda e: (not e.hard_fail, e.total), reverse=True)
    out = []
    for i, e in enumerate(ok):
        entry = {"rank": i + 1, "file": e.file, "total": e.total, "verdict": e.verdict,
                 "recommended": i < top and not e.hard_fail and e.total >= MIN_RECOMMEND}
        if i > 0 and ok[i - 1].hard_fail == e.hard_fail and ok[i - 1].total - e.total < TIE_MARGIN:
            entry["tie_with_previous"] = True
        out.append(entry)
    return out


def build(evaluations: list[Evaluation], profile_name: str, model: str, mode: str, ranking: list[dict] | None = None) -> dict:
    report = {
        "generated": dt.datetime.now().isoformat(timespec="seconds"),
        "profile": profile_name,
        "model": model,
        "mode": mode,
        "disclaimer": DISCLAIMER,
        "results": [e.to_dict() for e in evaluations],
    }
    if ranking is not None:
        report["ranking"] = ranking
    return report


def _fmt(v) -> str:
    return "–" if v is None else f"{v:.0f}"


def to_markdown(report: dict) -> str:
    lines = [
        f"# Sound-Bewertung ({report['mode']})",
        "",
        f"Profil **{report['profile']}**, Modell `{report['model']}`, {report['generated']}",
        "",
        f"> {report['disclaimer']}",
        "",
    ]
    results = report["results"]
    if report.get("ranking"):
        by_file = {r["file"]: r for r in results}
        lines += ["## Ranking", "", "| # | Datei | Gesamt | Semantik | Stil | Referenz | Technik | Urteil |", "|---|---|---|---|---|---|---|---|"]
        for r in report["ranking"]:
            s = by_file[r["file"]]["scores"]
            mark = " ★" if r["recommended"] else ""
            tie = " (≈)" if r.get("tie_with_previous") else ""
            lines.append(
                f"| {r['rank']}{mark} | {Path(r['file']).name} | {_fmt(s.get('total'))}{tie} | {_fmt(s.get('semantic'))} | "
                f"{_fmt(s.get('style'))} | {_fmt(s.get('reference'))} | {_fmt(s.get('technical'))} | {r['verdict']} |"
            )
        lines += ["", "★ = empfohlen; (≈) = weniger als 3 Punkte hinter dem Vorgänger – nach Gehör entscheiden. "
                  "Varianten mit hartem technischem Fehler (Clipping, stumm) stehen unabhängig vom Score hinten; "
                  f"unter {MIN_RECOMMEND:.0f} Punkten wird nichts empfohlen.", ""]
    else:
        lines += ["## Übersicht", "", "| Datei | Effekt | Gesamt | Semantik | Stil | Referenz | Technik | Urteil |", "|---|---|---|---|---|---|---|---|"]
        for r in results:
            s = r["scores"]
            lines.append(
                f"| {Path(r['file']).name} | {r['effect'] or '–'} | {_fmt(s.get('total'))} | {_fmt(s.get('semantic'))} | "
                f"{_fmt(s.get('style'))} | {_fmt(s.get('reference'))} | {_fmt(s.get('technical'))} | {r['verdict']} |"
            )
        lines.append("")

    lines += ["## Details", ""]
    for r in results:
        lines.append(f"### {Path(r['file']).name}")
        lines.append("")
        if r.get("error"):
            lines += [f"Fehler: {r['error']}", ""]
            continue
        m = r["technical"]["metrics"]
        lines.append(
            f"Effekt: {r['effect'] or '–'} · Urteil: **{r['verdict']}** · Dauer {m['duration_s']:.2f} s · "
            f"{m['loudness_lufs']:.1f} LUFS · True Peak {m['true_peak_dbfs']:.1f} dBTP · {m['sample_rate']} Hz/{m['channels']} ch/{m['subtype']}"
        )
        lines.append("")
        lines += [f"- {x}" for x in r["reasons"]]
        if r["suggestions"]:
            lines += ["", "Vorschläge:", ""] + [f"- {x}" for x in r["suggestions"]]
        lines.append("")
    return "\n".join(lines)


def write(report: dict, out_dir: Path, stem: str) -> tuple[Path, Path]:
    out_dir.mkdir(parents=True, exist_ok=True)
    stamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    j = out_dir / f"{stem}-{stamp}.json"
    md = out_dir / f"{stem}-{stamp}.md"
    j.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    md.write_text(to_markdown(report), encoding="utf-8")
    return j, md
