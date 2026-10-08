#!/usr/bin/env python3
"""Auswertung des Statistik-Kanals (ADR 0021) als lokale HTML-Seite.

Liest, was tools/stats/fetch.sh vom Server geholt hat (je Profil ein Verzeichnis mit
Tages-Snapshots und der bereinigten Spur), und schreibt eine Übersicht:

    python3 tools/stats/report.py                       # stats-data/ms-stats -> stats-data/report.html
    python3 tools/stats/report.py --data DIR --out FILE
    python3 tools/stats/report.py --self-test           # ohne Daten, für die CI

Lexem-Ids werden aus dem Submodule (data/language/lexemes) zu Wörtern aufgelöst. Die
Seite enthält damit Wortlisten aus geschütztem Material: sie bleibt auf diesem Rechner,
wie stats-data/ selbst (gitignored), und gehört in kein Repo und in keinen Report.

Nur Standardbibliothek.
"""

from __future__ import annotations

import argparse
import collections
import datetime as dt
import gzip
import html
import json
import pathlib
import statistics
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[2]

# Ab so vielen Versuchen (über alle Profile) zählt ein Wort für „schwer".
MIN_ATTEMPTS = 6
# Abstand bis hierher heißt „verschrieben", darüber „nicht gewusst".
TYPO_DISTANCE = 2


# --- Lesen -----------------------------------------------------------------------------

def read_gz_json(path: pathlib.Path) -> dict:
    with gzip.open(path, "rt", encoding="utf-8") as fh:
        return json.load(fh)


def read_trace(directory: pathlib.Path) -> list[dict]:
    """Alle Spurzeilen eines Profils, über die Monatsdateien (gzip-Glieder werden
    nacheinander gelesen)."""
    out: list[dict] = []
    for path in sorted(directory.glob("trace-*.jsonl.gz")):
        with gzip.open(path, "rt", encoding="utf-8") as fh:
            for line in fh:
                line = line.strip()
                if line:
                    try:
                        out.append(json.loads(line))
                    except json.JSONDecodeError:
                        pass
    return out


def load_profiles(data: pathlib.Path) -> list[dict]:
    """Je Profil: Id, alle Tages-Snapshots (älteste zuerst) und die Spur."""
    profiles = []
    for directory in sorted(p for p in data.iterdir() if p.is_dir() and not p.name.startswith("_")):
        snapshots = []
        for path in sorted(directory.glob("snapshot-*.json.gz")):
            try:
                snap = read_gz_json(path)
            except (OSError, json.JSONDecodeError):
                continue
            snap["_day"] = path.name[len("snapshot-"):-len(".json.gz")]
            snapshots.append(snap)
        if not snapshots:
            continue
        profiles.append({"id": directory.name, "snapshots": snapshots, "trace": read_trace(directory)})
    return profiles


def load_lemmas(language_root: pathlib.Path) -> dict[str, str]:
    """lexeme_id -> „deutsch – fremd". Ohne Submodule leer; dann bleiben die Ids stehen."""
    lemmas: dict[str, str] = {}
    for path in sorted((language_root / "lexemes").glob("*.json")):
        try:
            entries = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            continue
        for entry in entries if isinstance(entries, list) else []:
            foreign = entry.get("lemma_%s" % (entry.get("language") or "en"), "")
            lemmas[str(entry.get("id", ""))] = " – ".join(
                x for x in [str(entry.get("lemma_de", "")), str(foreign)] if x)
    return lemmas


def lexeme_of(learnable_id: str) -> str:
    """Die Lexem-Id in einer learnable_id (translate:de_to_en:lex.… , conjugation:lex.…:…)."""
    for part in learnable_id.split(":"):
        if part.startswith("lex."):
            return part
    return learnable_id


# --- Rechnen ---------------------------------------------------------------------------

def profile_summary(profile: dict) -> dict:
    last = profile["snapshots"][-1]
    sessions = last.get("sessions", []) or []
    answers = sum(int(s.get("answers", 0)) for s in sessions)
    correct = sum(int(s.get("correct", 0)) for s in sessions)
    seconds = sum(max(0, int(s.get("ended_at", 0)) - int(s.get("started_at", 0))) for s in sessions)
    progress = last.get("progress", {}) or {}
    mastered = sum(1 for r in progress.values() if r.get("mastered_at"))
    days = sorted({dt.datetime.fromtimestamp(int(s.get("started_at", 0))).date() for s in sessions})
    return {
        "id": profile["id"][:8],
        "app": last.get("app_version", ""),
        "last_seen": last.get("_day", ""),
        "sessions": len(sessions),
        "days": len(days),
        "minutes": round(seconds / 60),
        "waves": sum(int(s.get("waves_cleared", 0)) for s in sessions),
        "answers": answers,
        "accuracy": (correct / answers) if answers else None,
        "gold": (last.get("wallet") or {}).get("total_earned", 0),
        "xp": (last.get("level") or {}).get("total_xp", 0),
        "seen": len(progress),
        "mastered": mastered,
        "difficulty": (last.get("settings") or {}).get("difficulty", ""),
    }


def sessions_per_day(profiles: list[dict]) -> list[tuple[str, int, int]]:
    """(Tag, Sitzungen, Profile) über alle Profile."""
    count: dict[str, int] = collections.Counter()
    who: dict[str, set] = collections.defaultdict(set)
    for profile in profiles:
        for s in profile["snapshots"][-1].get("sessions", []) or []:
            day = dt.datetime.fromtimestamp(int(s.get("started_at", 0))).date().isoformat()
            count[day] += 1
            who[day].add(profile["id"])
    return [(day, count[day], len(who[day])) for day in sorted(count)]


def hardest(profiles: list[dict], lemmas: dict[str, str], limit: int = 40) -> list[dict]:
    """Aufgaben mit der niedrigsten Trefferquote über alle Profile."""
    totals: dict[str, list[int]] = collections.defaultdict(lambda: [0, 0, 0])
    for profile in profiles:
        for learnable, record in (profile["snapshots"][-1].get("progress", {}) or {}).items():
            t = totals[learnable]
            t[0] += int(record.get("attempts", 0))
            t[1] += int(record.get("correct_total", 0))
            t[2] += 1
    rows = []
    for learnable, (attempts, correct, players) in totals.items():
        if attempts < MIN_ATTEMPTS:
            continue
        lex = lexeme_of(learnable)
        rows.append({"id": learnable, "word": lemmas.get(lex, lex), "attempts": attempts,
                     "accuracy": correct / attempts, "players": players})
    rows.sort(key=lambda r: (r["accuracy"], -r["attempts"]))
    return rows[:limit]


def answer_profile(profiles: list[dict]) -> dict:
    """Aus der Spur: Antwortzeiten und wie die Fehlversuche aussehen."""
    rts: list[int] = []
    misses = collections.Counter()
    for profile in profiles:
        for line in profile["trace"]:
            if line.get("e") != "answer":
                continue
            if line.get("hit") and int(line.get("rt", 0)) > 0:
                rts.append(int(line["rt"]))
            if not line.get("hit"):
                if "dist" not in line:
                    misses["ohne Bezug (kein passendes Monster)"] += 1
                elif int(line["dist"]) <= TYPO_DISTANCE:
                    misses["knapp daneben (Abstand ≤ %d)" % TYPO_DISTANCE] += 1
                else:
                    misses["weit daneben"] += 1
    return {
        "answers_timed": len(rts),
        "rt_median": statistics.median(rts) if rts else None,
        "rt_p90": sorted(rts)[int(len(rts) * 0.9)] if rts else None,
        "misses": dict(misses),
        "leaks": sum(1 for p in profiles for l in p["trace"] if l.get("e") == "leak"),
    }


# --- Schreiben -------------------------------------------------------------------------

def pct(value) -> str:
    return "–" if value is None else "%d %%" % round(value * 100)


def table(headers: list[str], rows: list[list]) -> str:
    head = "".join("<th>%s</th>" % html.escape(h) for h in headers)
    body = "".join(
        "<tr>%s</tr>" % "".join("<td>%s</td>" % html.escape(str(c)) for c in row) for row in rows)
    return "<table><thead><tr>%s</tr></thead><tbody>%s</tbody></table>" % (head, body)


def render(profiles: list[dict], lemmas: dict[str, str]) -> str:
    summaries = [profile_summary(p) for p in profiles]
    days = sessions_per_day(profiles)
    peak = max((n for _, n, _ in days), default=1)
    answers = answer_profile(profiles)
    parts = [
        "<h1>Monster Slam – Spieldaten</h1>",
        "<p class=note>Lokal erzeugt am %s aus %d Profilen. Enthält Wörter aus geschütztem "
        "Material – nicht weitergeben.</p>" % (dt.datetime.now().strftime("%d.%m.%Y %H:%M"), len(profiles)),
        "<h2>Profile</h2>",
        table(["Profil", "App", "zuletzt", "Sitzungen", "Tage", "Minuten", "Wellen", "Antworten",
               "Quote", "Gold gesamt", "XP", "gesehen", "gemeistert", "Schwierigkeit"],
              [[s["id"], s["app"], s["last_seen"], s["sessions"], s["days"], s["minutes"], s["waves"],
                s["answers"], pct(s["accuracy"]), s["gold"], s["xp"], s["seen"], s["mastered"],
                s["difficulty"]] for s in summaries]),
        "<h2>Sitzungen je Tag</h2><div class=bars>",
    ]
    for day, n, who in days:
        parts.append("<div class=bar><span>%s</span><i style='width:%d%%'></i><b>%d (%d Profile)</b></div>"
                     % (day, round(100 * n / peak), n, who))
    parts.append("</div>")
    parts += [
        "<h2>Antworten aus der Spur</h2>",
        table(["Größe", "Wert"], [
            ["Treffer mit Zeit", answers["answers_timed"]],
            ["Antwortzeit Median (ms)", answers["rt_median"] if answers["rt_median"] is not None else "–"],
            ["Antwortzeit 90 % (ms)", answers["rt_p90"] if answers["rt_p90"] is not None else "–"],
            ["durchgelassene Monster", answers["leaks"]],
        ] + [["Fehlversuch: " + k, v] for k, v in sorted(answers["misses"].items())]),
        "<h2>Schwerste Aufgaben (ab %d Versuchen)</h2>" % MIN_ATTEMPTS,
        table(["Wort", "Aufgabe", "Versuche", "Quote", "Profile"],
              [[r["word"], r["id"], r["attempts"], pct(r["accuracy"]), r["players"]]
               for r in hardest(profiles, lemmas)]),
    ]
    style = """
    :root { --bg:#fbfaf7; --fg:#1f1d1a; --muted:#6b665e; --line:#e3dfd6; --bar:#7a5cc4; }
    @media (prefers-color-scheme: dark) { :root { --bg:#191817; --fg:#ece8e1; --muted:#a39d93;
      --line:#34312d; --bar:#a58bf0; } }
    body { background:var(--bg); color:var(--fg); font:15px/1.45 system-ui, sans-serif;
      margin:0 auto; max-width:1100px; padding:24px 16px; }
    h1 { font-size:24px; } h2 { font-size:18px; margin-top:32px; }
    .note { color:var(--muted); }
    table { border-collapse:collapse; width:100%; font-variant-numeric:tabular-nums; display:block;
      overflow-x:auto; }
    th, td { text-align:left; padding:4px 8px; border-bottom:1px solid var(--line); white-space:nowrap; }
    th { color:var(--muted); font-weight:600; }
    .bar { display:grid; grid-template-columns:110px 1fr 140px; gap:8px; align-items:center; }
    .bar i { display:block; height:10px; background:var(--bar); border-radius:2px; }
    .bar b { font-weight:400; color:var(--muted); }
    """
    return ("<!doctype html><html lang=de><head><meta charset=utf-8>"
            "<meta name=viewport content='width=device-width, initial-scale=1'>"
            "<title>Spieldaten</title><style>%s</style></head><body>%s</body></html>"
            % (style, "".join(parts)))


# --- Selbsttest ------------------------------------------------------------------------

def self_test() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        data = pathlib.Path(tmp)
        profile = data / ("ab" * 16)
        profile.mkdir()
        (data / "_rate").mkdir()
        snap = {
            "format": 1, "app_version": "0.28.0",
            "sessions": [{"started_at": 1791000000, "ended_at": 1791000600, "answers": 10,
                          "correct": 7, "waves_cleared": 3}],
            "wallet": {"total_earned": 50}, "level": {"total_xp": 400},
            "progress": {"translate:de_to_en:lex.zz.a": {"attempts": 8, "correct_total": 2},
                         "translate:de_to_en:lex.zz.b": {"attempts": 2, "correct_total": 0,
                                                         "mastered_at": 5}},
            "settings": {"difficulty": 3},
        }
        with gzip.open(profile / "snapshot-2026-10-01.json.gz", "wt", encoding="utf-8") as fh:
            json.dump(snap, fh)
        # Zwei gzip-Glieder hintereinander, wie der Endpunkt sie anhängt.
        with open(profile / "trace-2026-10.jsonl.gz", "wb") as fh:
            fh.write(gzip.compress(b'{"e":"answer","hit":true,"rt":1200}\n'))
            fh.write(gzip.compress(b'{"e":"answer","hit":false,"dist":1}\n{"e":"leak"}\n'))
        profiles = load_profiles(data)
        assert len(profiles) == 1, profiles
        assert len(profiles[0]["trace"]) == 3, "gzip-Glieder nicht alle gelesen"
        summary = profile_summary(profiles[0])
        assert summary["minutes"] == 10 and summary["mastered"] == 1, summary
        assert abs(summary["accuracy"] - 0.7) < 1e-9
        rows = hardest(profiles, {"lex.zz.a": "Beispiel – example"})
        assert [r["word"] for r in rows] == ["Beispiel – example"], rows
        answers = answer_profile(profiles)
        assert answers["rt_median"] == 1200 and answers["leaks"] == 1, answers
        assert lexeme_of("conjugation:lex.zz.go:past") == "lex.zz.go"
        page = render(profiles, {})
        assert "<table>" in page and "lex.zz.a" in page
    print("report.py: Selbsttest bestanden.")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--data", default=str(ROOT / "stats-data" / "ms-stats"))
    parser.add_argument("--out", default=str(ROOT / "stats-data" / "report.html"))
    parser.add_argument("--language", default=str(ROOT / "data" / "language"))
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return 0
    data = pathlib.Path(args.data)
    if not data.is_dir():
        print("Keine Daten unter %s — erst tools/stats/fetch.sh." % data, file=sys.stderr)
        return 1
    profiles = load_profiles(data)
    out = pathlib.Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(render(profiles, load_lemmas(pathlib.Path(args.language))), encoding="utf-8")
    print("%d Profile -> %s" % (len(profiles), out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
