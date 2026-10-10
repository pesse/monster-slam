#!/usr/bin/env python3
"""Spielstand aus den Statistik-Snapshots zurückbauen (ADR 0024, Entwicklerwerkzeug).

Für einen Spieler, dessen Spielstand verloren ging, bevor es Sicherungen gab: der Server
hat je Tag einen Snapshot (ADR 0021). Daraus werden die Dateien des Profils gebaut —
als Klartext-JSON zum Einlegen bei geschlossenem Spiel (`--format legacy`) oder als
Datei für „Laden…“ in den Einstellungen (`--format export`).

    # Was gibt es? Je Tag: XP, Gold, Lernstände, Sitzungen, Version.
    python3 tools/stats/rebuild_save.py --stats-id 3fa1 --list

    # Den Stand vom 2026-10-08 als Datei für „Laden…“:
    python3 tools/stats/rebuild_save.py --stats-id 3fa1 --day 2026-10-08 \\
        --profile anna --name Anna --format export --out ~/Anna-zurück.zip

    # Nur die Erfahrung, plus was seit dem Verlust neu verdient wurde (aus dem neuesten
    # Snapshot; mit --base aus den jetzigen Dateien). Der Lernstand bleibt, wie er ist:
    python3 tools/stats/rebuild_save.py --stats-id 3fa1 --day 2026-10-08 --only _level \\
        --profile anna --name Anna --add-live-xp --out ~/Anna-Erfahrung.zip

Der Snapshot trägt nicht alles: Abzeichen und Testlisten fehlen, und Lernzeiten nur, soweit
sie gesendet wurden. Gebaut wird nur, was er hat; „Laden…“ ersetzt nur die Teile, die in
der Datei stehen, die anderen bleiben, wie sie sind.

Nur Standardbibliothek. `--self-test` prüft ohne Daten (für die CI).
"""

from __future__ import annotations

import argparse
import datetime as dt
import gzip
import hashlib
import json
import pathlib
import sys
import tempfile
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[2]
FORMAT = 1
ARCHIVE_HEAD = "monster-slam.json"
ARCHIVE_PREFIX = "spielstand"

# Snapshot-Schlüssel -> (Endung der Datei, Feld in der Datei). Spiegelt
# StatsUploader.SNAPSHOT_FILES rückwärts.
FILES = {
    "progress": ("", "records"),
    "sessions": ("_sessions", "sessions"),
    "wallet": ("_wallet", None),
    "level": ("_level", None),
    "skills": ("_skills", None),
    "inventory": ("_inventory", "slots"),
    "bosses": ("_bosses", "wins"),
}


# --- Lesen -----------------------------------------------------------------------------

def read_gz_json(path: pathlib.Path) -> dict:
    with gzip.open(path, "rt", encoding="utf-8") as fh:
        return json.load(fh)


def profile_dir(data: pathlib.Path, stats_id: str) -> pathlib.Path:
    """Das Verzeichnis zu einer stats_id oder einem eindeutigen Anfang davon."""
    found = [p for p in data.iterdir() if p.is_dir() and p.name.startswith(stats_id)]
    if len(found) != 1:
        raise SystemExit("stats_id '%s' passt auf %d Profile." % (stats_id, len(found)))
    return found[0]


def snapshots(directory: pathlib.Path) -> list[tuple[str, dict]]:
    out = []
    for path in sorted(directory.glob("snapshot-*.json.gz")):
        out.append((path.name[len("snapshot-"):-len(".json.gz")], read_gz_json(path)))
    return out


def read_save(path: pathlib.Path) -> dict:
    """Eine Profildatei, mit oder ohne Hülle (die Hülle ist gültiges JSON, `_save` fällt weg)."""
    data = json.loads(path.read_text(encoding="utf-8"))
    data.pop("_save", None)
    return data


# --- Bauen -----------------------------------------------------------------------------

def summary(snap: dict) -> dict:
    wallet = snap.get("wallet") or {}
    return {
        "xp": int((snap.get("level") or {}).get("total_xp", 0)),
        "gold": int(wallet.get("gold", 0)),
        "earned": int(wallet.get("total_earned", 0)),
        "records": len(snap.get("progress") or {}),
        "sessions": len(snap.get("sessions") or []),
        "skills": len((snap.get("skills") or {}).get("unlocked") or []),
        "app": snap.get("app_version", ""),
    }


def files_from(snap: dict, profile: str) -> dict[str, dict]:
    """Endung -> Inhalt der Datei, aus einem Snapshot."""
    out: dict[str, dict] = {}
    for key, (suffix, field) in FILES.items():
        if key not in snap:
            continue
        content: dict = {"player_id": profile}
        if field is None:
            content.update(snap[key])
        else:
            content[field] = snap[key]
        out[suffix] = content
    if "_sessions" in out:
        out["_sessions"]["current"] = {}
    if "_bosses" in out:
        out["_bosses"].pop("player_id")   # BossRecord schreibt keine
    return out


def encode(data: dict) -> bytes:
    """Wie SaveStore.encode: Hülle mit Prüfsumme vorn, Daten wie JSON.stringify(data, "\\t")."""
    body = json.dumps(data, indent="\t", ensure_ascii=False, sort_keys=True).encode("utf-8")
    head = '{"_save":{"format":%d,"sha256":"%s"}' % (FORMAT, hashlib.sha256(body).hexdigest())
    return head.encode("utf-8") + (b"," if data else b"") + body[1:]


def decode(raw: bytes) -> dict:
    """Gegenstück für den Selbsttest, wie SaveStore.decode."""
    text = raw.decode("utf-8")
    prefix_end = text.index("}") + 1
    head = json.loads(text[len('{"_save":'):prefix_end])
    rest = raw[len(text[:prefix_end].encode("utf-8")):]
    if rest.startswith(b","):
        rest = rest[1:]
    body = b"{" + rest
    if hashlib.sha256(body).hexdigest() != head["sha256"]:
        raise ValueError("Prüfsumme")
    return json.loads(body)


def write_legacy(files: dict[str, dict], profile: str, out: pathlib.Path) -> list[pathlib.Path]:
    out.mkdir(parents=True, exist_ok=True)
    written = []
    for suffix, content in files.items():
        path = out / ("%s%s.json" % (profile, suffix))
        path.write_text(json.dumps(content, indent="\t", ensure_ascii=False), encoding="utf-8")
        written.append(path)
    return written


def write_export(files: dict[str, dict], name: str, saved_at: int, out: pathlib.Path) -> None:
    """Ein Zip wie SaveArchive.write — „Laden…“ liest es."""
    entries = {"%s%s.json" % (ARCHIVE_PREFIX, suffix): encode(content) for suffix, content in files.items()}
    head = {
        "format": FORMAT, "name": name, "saved_at": saved_at, "app_version": "rebuild_save.py",
        "files": {suffix: hashlib.sha256(entries["%s%s.json" % (ARCHIVE_PREFIX, suffix)]).hexdigest()
                  for suffix in files},
    }
    out.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as zf:
        for entry, raw in entries.items():
            zf.writestr(entry, raw)
        zf.writestr(ARCHIVE_HEAD, json.dumps(head, indent="\t", ensure_ascii=False))


def rebuild(snap: dict, profile: str, only: list[str] | None, live_xp: int = 0) -> dict[str, dict]:
    """`live_xp`: was seit dem Verlust neu verdient wurde, kommt auf die Erfahrung."""
    files = files_from(snap, profile)
    if only:
        files = {s: c for s, c in files.items() if s in only}
    if live_xp and "_level" in files:
        files["_level"]["total_xp"] = int(files["_level"].get("total_xp", 0)) + live_xp
    return files


def live_xp(found: list[tuple[str, dict]], day: str, base: pathlib.Path | None, profile: str) -> tuple[int, str]:
    """Erfahrung seit dem Verlust und woher sie stammt: die jetzige _level.json (`base`) oder
    der neueste Snapshot nach `day`. Der muss nach dem Verlust liegen (weniger XP als `day`),
    sonst würde der Stand doppelt gezählt."""
    if base is not None:
        return int(read_save(base / ("%s_level.json" % profile)).get("total_xp", 0)), str(base)
    good = summary(dict(found)[day])["xp"]
    later = [(d, summary(s)["xp"]) for d, s in found if d > day]
    if not later:
        raise SystemExit("Kein Snapshot nach dem %s — --base mit den jetzigen Dateien angeben." % day)
    newest, xp = later[-1]
    if xp >= good:
        raise SystemExit("Der Snapshot vom %s hat %d XP, nicht weniger als %d am %s — dort fehlt "
                         "nichts. Falscher Tag?" % (newest, xp, good, day))
    return xp, "Snapshot vom %s" % newest


# --- Selbsttest ------------------------------------------------------------------------

def self_test() -> None:
    snap = {
        "format": 1, "app_version": "0.29.0",
        "progress": {"translate:de_to_en:lex.zz.a": {"confidence": 0.5}},
        "sessions": [{"started_at": 1, "answers": 4}],
        "wallet": {"gold": 12, "total_earned": 40, "chests_opened": 1},
        "level": {"total_xp": 32500},
        "skills": {"unlocked": ["s.a"], "spent_points": 1},
        "bosses": [{"unit": "zz/1", "won_at": 5}],
    }
    with tempfile.TemporaryDirectory() as tmp:
        root = pathlib.Path(tmp)
        data = root / "ms-stats" / ("ab" * 16)
        data.mkdir(parents=True)
        with gzip.open(data / "snapshot-2026-10-08.json.gz", "wt", encoding="utf-8") as fh:
            json.dump(snap, fh)
        found = snapshots(profile_dir(root / "ms-stats", "abab"))
        assert [d for d, _ in found] == ["2026-10-08"], found
        assert summary(found[0][1])["xp"] == 32500

        files = files_from(snap, "zz")
        assert files[""]["records"] == snap["progress"]
        assert files["_level"] == {"player_id": "zz", "total_xp": 32500}
        assert files["_bosses"] == {"wins": snap["bosses"]}
        assert "_inventory" not in files

        # Erfahrung seit dem Verlust dazurechnen: die Live-Datei trägt die Hülle.
        base = root / "progress"
        base.mkdir()
        (base / "zz_level.json").write_bytes(encode({"player_id": "zz", "total_xp": 700}))
        assert live_xp(found, "2026-10-08", base, "zz")[0] == 700
        rebuilt = rebuild(snap, "zz", ["_level"], 700)
        assert list(rebuilt) == ["_level"] and rebuilt["_level"]["total_xp"] == 33200, rebuilt

        # Ohne --base aus dem neuesten Snapshot danach — nur, wenn dort wirklich XP fehlt.
        lost = dict(snap, level={"total_xp": 900})
        found_after = found + [("2026-10-09", dict(snap, level={"total_xp": 400})), ("2026-10-10", lost)]
        assert live_xp(found_after, "2026-10-08", None, "zz") == (900, "Snapshot vom 2026-10-10")
        for bad in [found, found + [("2026-10-09", snap)]]:
            try:
                live_xp(bad, "2026-10-08", None, "zz")
            except SystemExit:
                pass
            else:
                raise AssertionError("live_xp hätte abbrechen müssen")

        for sample in [{}, {"a": 1}, {"ä": "ü", "n": [1, 2.5]}]:
            assert decode(encode(sample)) == sample, sample

        legacy = write_legacy(files, "zz", root / "out")
        assert json.loads((root / "out" / "zz_wallet.json").read_text(encoding="utf-8"))["gold"] == 12
        assert len(legacy) == len(files)

        archive = root / "stand.zip"
        write_export(files, "Anna", 1791000000, archive)
        with zipfile.ZipFile(archive) as zf:
            head = json.loads(zf.read(ARCHIVE_HEAD))
            for suffix, digest in head["files"].items():
                raw = zf.read("%s%s.json" % (ARCHIVE_PREFIX, suffix))
                assert hashlib.sha256(raw).hexdigest() == digest
                assert decode(raw) == files[suffix]
    print("rebuild_save.py: Selbsttest bestanden.")


# --- Aufruf ----------------------------------------------------------------------------

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--data", default=str(ROOT / "stats-data" / "ms-stats"))
    parser.add_argument("--stats-id", help="Profilnummer oder ihr eindeutiger Anfang")
    parser.add_argument("--list", action="store_true", help="Tage mit ihren Kennzahlen zeigen")
    parser.add_argument("--day", help="Tag des Snapshots, JJJJ-MM-TT")
    parser.add_argument("--profile", help="player_id des Ziels (Dateinamen)")
    parser.add_argument("--name", default="", help="Anzeigename im Export")
    parser.add_argument("--only", default="", help="nur diese Endungen, z. B. _level,_wallet; der Lernstand hat die "
                        "leere Endung (',_level')")
    parser.add_argument("--base", help="Ordner mit den jetzigen Dateien des Profils")
    parser.add_argument("--add-live-xp", action="store_true", help="XP seit dem Verlust dazurechnen: aus der "
                        "jetzigen _level.json (--base) oder dem neuesten Snapshot")
    parser.add_argument("--format", choices=["legacy", "export"], default="export")
    parser.add_argument("--out", help="Ordner (legacy) oder .zip (export)")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return 0
    if not args.stats_id:
        parser.error("--stats-id fehlt")
    found = snapshots(profile_dir(pathlib.Path(args.data), args.stats_id))
    if args.list or not args.day:
        print("Tag         XP       Gold  verdient  Lernstände  Sitzungen  Skills  App")
        for day, snap in found:
            s = summary(snap)
            print("%-10s %8d %8d %9d %11d %10d %7d  %s" % (
                day, s["xp"], s["gold"], s["earned"], s["records"], s["sessions"], s["skills"], s["app"]))
        return 0
    chosen = dict(found).get(args.day)
    if chosen is None:
        raise SystemExit("Kein Snapshot vom %s." % args.day)
    if not args.profile or not args.out:
        parser.error("--profile und --out fehlen")
    only = [s.strip() for s in args.only.split(",")] if args.only else None
    extra = 0
    if args.add_live_xp:
        extra, source = live_xp(found, args.day, pathlib.Path(args.base) if args.base else None, args.profile)
        print("+%d XP seit dem Verlust (%s). Was danach noch dazukommt, fehlt." % (extra, source))
    files = rebuild(chosen, args.profile, only, extra)
    out = pathlib.Path(args.out).expanduser()
    if args.format == "legacy":
        for path in write_legacy(files, args.profile, out):
            print(path)
        print("Bei geschlossenem Spiel nach user://progress legen; das Spiel schreibt sie beim "
              "nächsten Öffnen mit Prüfsumme um.")
    else:
        saved_at = int(dt.datetime.fromisoformat(args.day).replace(hour=12).timestamp())
        write_export(files, args.name, saved_at, out)
        print("%s — im Spiel unter Einstellungen → Profil → „Laden…“." % out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
