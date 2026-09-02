#!/usr/bin/env python3
"""Meldungen aus dem Rückkanal zu Issues im privaten Content-Repo bündeln.

Der Endpunkt (server/melden/melden.php) sammelt Meldungen als JSON Lines. Dieses Skript
macht daraus die Oberfläche, an der man arbeitet: **ein Issue je gemeldetem Wort**, nicht
je Meldung. Drei Kinder, die dasselbe Wort melden, ergeben ein Issue mit drei Belegen.
Entscheidung und Begründung: docs/adr/0002-melde-rueckkanal.md.

Es läuft **lokal**, aus zwei Gründen: `gh` ist hier schon angemeldet (kein Token, das
irgendwo liegen müsste), und der Lemma-Text steht nur im Checkout — der Endpunkt kennt
bloß Ids, und der Webhost soll den Korpus nie zu sehen bekommen.

Es hält **keinen Zustand**: jeder Lauf liest, was in GitHub schon steht, und trägt nur
Fehlendes nach. Erkannt wird das an Markern im Text (`<!-- ms-report… -->`) — derselbe
Schlüssel, mit dem der Endpunkt Doppelmeldungen erkennt. Beliebig oft wiederholbar.

Die `reports.jsonl` liegt über dem Docroot, ist also über keine URL abrufbar — sie kommt
per SFTP/FTP herunter, und der übliche Weg ist `--from-file`. `--from-url` ist für den
Fall, dass später eine geschützte Ansichtsseite dazukommt (ADR 0002, Variante A).

    tools/report/to_issues.py --from-file reports.jsonl --dry-run
    tools/report/to_issues.py --from-file reports.jsonl
    tools/report/to_issues.py --from-url https://…/ansicht.php?format=jsonl --user ich
    tools/report/to_issues.py --self-test
"""

from __future__ import annotations

import argparse
import base64
import getpass
import json
import pathlib
import shutil
import subprocess
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone

DEFAULT_REPO = "pesse/monster-slam-content"
DEFAULT_LABEL = "meldung"
DEFAULT_LIMIT = 500

## Zieltyp -> Kategorie-Verzeichnis unter data/language, aus dem die Id aufgelöst wird.
## Muss zu TARGET_TYPES in server/melden/melden.php passen.
CATEGORY_OF = {"lexeme": "lexemes", "sentence": "sentences"}

## Der Marker, an dem ein Issue seinem Ziel zugeordnet wird.
TARGET_MARKER = "<!-- ms-report-target: %s|%s -->"
## Der Marker je einzelner Meldung — Schlüssel wie im Endpunkt: label|target_id|at.
REPORT_MARKER = "<!-- ms-report: %s -->"


# --- reine Hilfsfunktionen (unter --self-test geprüft) ----------------------------------

def report_key(report: dict) -> str:
    """Der Schlüssel einer Meldung. Der Endpunkt legt ihn als `key` ab; fehlt er (Datei
    von Hand ergänzt), wird er genauso zusammengesetzt.

    Ohne Ziel-Id gibt es keinen Schlüssel: `mia||t` sähe für zwei verschiedene Wörter
    gleich aus, und der Lauf hielte die zweite Meldung für schon eingetragen. Lieber
    laut scheitern — `load_reports` lässt solche Zeilen ohnehin nicht durch."""
    key = str(report.get("key", "")).strip()
    if key:
        return key
    target_id = str(report.get("target_id", "")).strip()
    if not target_id:
        raise ValueError("Meldung ohne target_id und ohne key: %r" % report)
    return "%s|%s|%s" % (report.get("label", ""), target_id, report.get("at", ""))


def group_key(report: dict) -> tuple[str, str]:
    return str(report.get("target_type", "")), str(report.get("target_id", ""))


def target_of_body(body: str) -> tuple[str, str] | None:
    """Liest die Ziel-Zuordnung aus einem Issue-Text, oder None wenn keine drinsteht."""
    start = body.find("<!-- ms-report-target: ")
    if start < 0:
        return None
    end = body.find(" -->", start)
    if end < 0:
        return None
    raw = body[start + len("<!-- ms-report-target: "):end]
    if "|" not in raw:
        return None
    target_type, target_id = raw.split("|", 1)
    return target_type.strip(), target_id.strip()


def keys_in(text: str) -> set[str]:
    """Alle Meldungs-Marker in einem Text (Issue-Body oder Kommentar)."""
    found = set()
    needle = "<!-- ms-report: "
    position = text.find(needle)
    while position >= 0:
        end = text.find(" -->", position)
        if end < 0:
            break
        found.add(text[position + len(needle):end].strip())
        position = text.find(needle, end)
    return found


def report_time(report: dict) -> datetime:
    """Empfangszeit als vergleichbarer Zeitpunkt. `ts` ist die verlässliche Quelle — sie
    kommt vom Server; `at` ist die Uhr auf dem Spielerrechner und hat keine Zeitzone."""
    ts = report.get("ts")
    if isinstance(ts, (int, float)) and ts > 0:
        return datetime.fromtimestamp(float(ts), tz=timezone.utc)
    received = str(report.get("received_at", ""))
    try:
        return datetime.fromisoformat(received.replace("Z", "+00:00"))
    except ValueError:
        return datetime.fromtimestamp(0, tz=timezone.utc)


def human_time(report: dict) -> str:
    return report_time(report).strftime("%d.%m.%Y %H:%M UTC")


def title_for(target_type: str, target_id: str, entry: dict | None) -> str:
    """Titel eines Issues. Die Id steht immer drin — daran findet man es wieder."""
    if entry is None:
        return "Meldung: %s (Id im Checkout nicht gefunden)" % target_id
    if target_type == "lexeme":
        naming = " → ".join(x for x in [
            str(entry.get("lemma_de", "")).strip(),
            str(entry.get("lemma_en", "")).strip()] if x)
    else:
        naming = str(entry.get("source_text", "")).strip()
    naming = naming if len(naming) <= 80 else naming[:77] + "…"
    return "Meldung: %s — „%s“" % (target_id, naming) if naming \
        else "Meldung: %s" % target_id


def render_report(report: dict) -> str:
    """Ein Beleg: wer, wann, was — plus der Marker, an dem er wiedererkannt wird."""
    origin = []
    if report.get("app_version"):
        origin.append("App %s" % report["app_version"])
    if report.get("pack_id"):
        pack = str(report["pack_id"])
        if report.get("pack_version"):
            pack += " %s" % report["pack_version"]
        origin.append("Pack %s" % pack)
    suffix = "  ·  %s" % ", ".join(origin) if origin else ""
    return "**%s**, %s%s\n\n> %s\n\n%s" % (
        report.get("label", "?"), human_time(report), suffix,
        str(report.get("comment", "")).replace("\n", "\n> "),
        REPORT_MARKER % report_key(report))


def render_issue_body(target_type: str, target_id: str, entry: dict | None,
                      reports: list[dict]) -> str:
    lines = [TARGET_MARKER % (target_type, target_id), ""]
    lines.append("**Ziel:** `%s`" % target_id)
    if entry is not None and target_type == "lexeme":
        detail = " · ".join(x for x in [
            str(entry.get("type", "")), "Buch %s" % entry.get("book", "")
            if entry.get("book") else "", "Unit %s" % entry.get("unit", "")
            if entry.get("unit") else ""] if x)
        if detail:
            lines.append("**Eintrag:** %s" % detail)
    elif entry is None:
        lines.append("**Achtung:** diese Id gibt es im aktuellen Checkout nicht "
                     "(umbenannt, entfernt, oder aus einem anderen Pack).")
    learnable = {str(r.get("learnable_id", "")) for r in reports if r.get("learnable_id")}
    if learnable:
        lines.append("**Aufgabe:** %s" % ", ".join("`%s`" % x for x in sorted(learnable)))
    lines.append("")
    lines.append("---")
    lines.append("")
    for report in reports:
        lines.append(render_report(report))
        lines.append("")
    return "\n".join(lines).rstrip() + "\n"


# --- Ein- und Ausgabe -------------------------------------------------------------------

def load_reports(text: str) -> tuple[list[dict], int]:
    """JSON Lines lesen. Eine kaputte Zeile ist kein Grund abzubrechen — sie wird gezählt
    und genannt, der Rest geht durch."""
    reports: list[dict] = []
    broken = 0
    for line in text.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            entry = json.loads(line)
        except json.JSONDecodeError:
            broken += 1
            continue
        if not isinstance(entry, dict) or not entry.get("target_id") \
                or not entry.get("target_type"):
            broken += 1
            continue
        reports.append(entry)
    return reports, broken


def fetch_url(url: str, user: str | None) -> str:
    request = urllib.request.Request(url, headers={"Accept": "application/x-ndjson"})
    if user:
        if ":" not in user:
            user = "%s:%s" % (user, getpass.getpass("Passwort für %s: " % user))
        token = base64.b64encode(user.encode("utf-8")).decode("ascii")
        request.add_header("Authorization", "Basic %s" % token)
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return response.read().decode("utf-8")
    except urllib.error.HTTPError as error:
        raise SystemExit("Abruf fehlgeschlagen: HTTP %d %s" % (error.code, error.reason))
    except urllib.error.URLError as error:
        raise SystemExit("Abruf fehlgeschlagen: %s" % error.reason)


def load_catalog(root: pathlib.Path, category: str) -> dict[str, dict]:
    """Id -> Eintrag aus data/language/<category>. Fehlt das Submodule, bleibt der
    Katalog leer und die Issues tragen nur Ids — unschön, aber kein Abbruch."""
    directory = root / category
    catalog: dict[str, dict] = {}
    if not directory.is_dir():
        return catalog
    for path in sorted(directory.rglob("*.json")):
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            print("  ! unlesbar: %s" % path, file=sys.stderr)
            continue
        for entry in (data if isinstance(data, list) else [data]):
            if isinstance(entry, dict) and entry.get("id"):
                catalog[str(entry["id"])] = entry
    return catalog


def gh(args: list[str], dry_run: bool = False) -> str:
    """`gh` aufrufen. Mit `dry_run` wird nur gezeigt, was passieren würde."""
    if dry_run:
        print("  [dry-run] gh %s" % " ".join(args))
        return ""
    result = subprocess.run(["gh", *args], capture_output=True, text=True)
    if result.returncode != 0:
        raise SystemExit("gh %s\n%s" % (" ".join(args), result.stderr.strip()))
    return result.stdout


def ensure_labels(repo: str, labels: list[str], dry_run: bool) -> None:
    """Ein Issue mit unbekanntem Label lässt `gh issue create` scheitern — also erst
    nachsehen, was es gibt, und Fehlendes anlegen."""
    existing = {item["name"] for item in json.loads(
        gh(["label", "list", "--repo", repo, "--limit", "200", "--json", "name"]) or "[]")}
    for label in labels:
        if label not in existing:
            print("  Label anlegen: %s" % label)
            gh(["label", "create", label, "--repo", repo,
                "--description", "Nutzer-Meldung aus dem Spiel", "--color", "D93F0B"],
               dry_run)


def existing_issues(repo: str, label: str, limit: int) -> dict[tuple[str, str], dict]:
    raw = gh(["issue", "list", "--repo", repo, "--label", label, "--state", "all",
              "--limit", str(limit), "--json", "number,title,body,state,closedAt"])
    issues = json.loads(raw or "[]")
    if len(issues) >= limit:
        # Sonst gilt ein vorhandenes Issue als nicht vorhanden und der Lauf legt Duplikate an.
        raise SystemExit(
            "gh issue list hat das Limit von %d erreicht — mit --limit erhöhen. "
            "Abgebrochen, bevor Duplikate entstehen." % limit)
    found: dict[tuple[str, str], dict] = {}
    for issue in issues:
        target = target_of_body(str(issue.get("body", "")))
        if target is not None:
            found[target] = issue
    return found


def issue_keys(repo: str, number: int) -> set[str]:
    """Welche Meldungen an diesem Issue schon hängen — Body plus alle Kommentare."""
    raw = gh(["issue", "view", str(number), "--repo", repo, "--json", "body,comments"])
    data = json.loads(raw or "{}")
    keys = keys_in(str(data.get("body", "")))
    for comment in data.get("comments", []) or []:
        keys |= keys_in(str(comment.get("body", "")))
    return keys


def missing_reports(items: list[dict], have: set[str]) -> list[dict]:
    """Die Belege, die an diesem Issue noch nicht hängen."""
    return [item for item in items if report_key(item) not in have]


def needs_reopen(issue: dict, missing: list[dict]) -> bool:
    """Nach dem Schließen gemeldet: entweder hat die Korrektur nicht gewirkt, oder es ist
    ein neues Problem. Beides gehört wieder auf den Tisch.

    Eine Meldung, die *älter* ist als der Schluss, tut das nicht — sie lag nur lange in der
    Warteschlange eines Spielers und ist von der Korrektur schon erledigt."""
    if str(issue.get("state", "")).upper() != "CLOSED":
        return False
    closed = closed_at(issue)
    if closed is None:
        return False
    return any(report_time(item) > closed for item in missing)


def closed_at(issue: dict) -> datetime | None:
    raw = str(issue.get("closedAt") or "")
    if not raw:
        return None
    try:
        return datetime.fromisoformat(raw.replace("Z", "+00:00"))
    except ValueError:
        return None


# --- Ablauf -----------------------------------------------------------------------------

def run(args: argparse.Namespace) -> int:
    if shutil.which("gh") is None:
        raise SystemExit("`gh` nicht gefunden. GitHub CLI installieren und `gh auth login`.")

    text = pathlib.Path(args.from_file).read_text(encoding="utf-8") if args.from_file \
        else fetch_url(args.from_url, args.user)
    reports, broken = load_reports(text)
    if broken:
        print("%d unbrauchbare Zeile(n) übersprungen." % broken, file=sys.stderr)
    if not reports:
        print("Keine Meldungen.")
        return 0

    groups: dict[tuple[str, str], list[dict]] = {}
    for report in reports:
        groups.setdefault(group_key(report), []).append(report)
    for items in groups.values():
        items.sort(key=report_time)
    order = sorted(groups, key=lambda key: report_time(groups[key][0]))

    # Nur die Arten, die wirklich gemeldet wurden: keinen Satz-Korpus lesen, für den es
    # keine Meldung gibt, und im Repo kein Label anlegen, das niemand trägt.
    types = sorted({target_type for target_type, _ in groups})
    language_root = pathlib.Path(args.lexemes)
    catalogs = {target_type: load_catalog(language_root, CATEGORY_OF[target_type])
                for target_type in types}

    print("%d Meldung(en) zu %d Ziel(en) · Repo %s" % (len(reports), len(groups), args.repo))
    known = existing_issues(args.repo, args.label, args.limit)
    ensure_labels(args.repo, [args.label] + ["%s:%s" % (args.label, t) for t in types],
                  args.dry_run)

    created = commented = reopened = unchanged = 0
    for target in order:
        target_type, target_id = target
        items = groups[target]
        entry = catalogs.get(target_type, {}).get(target_id)
        issue = known.get(target)

        if issue is None:
            title = title_for(target_type, target_id, entry)
            print("+ neu: %s (%d Beleg(e))" % (title, len(items)))
            gh(["issue", "create", "--repo", args.repo, "--title", title,
                "--body", render_issue_body(target_type, target_id, entry, items),
                "--label", args.label, "--label", "%s:%s" % (args.label, target_type)],
               args.dry_run)
            created += 1
            continue

        number = int(issue["number"])
        missing = missing_reports(items, issue_keys(args.repo, number))
        if not missing:
            unchanged += 1
            continue

        print("~ #%d: %d Beleg(e) nachtragen" % (number, len(missing)))
        for item in missing:
            gh(["issue", "comment", str(number), "--repo", args.repo,
                "--body", render_report(item)], args.dry_run)
        commented += 1

        if needs_reopen(issue, missing):
            print("  ↺ #%d wieder öffnen (Meldung ist jünger als der Schluss)" % number)
            gh(["issue", "reopen", str(number), "--repo", args.repo], args.dry_run)
            gh(["issue", "comment", str(number), "--repo", args.repo, "--body",
                "Wieder geöffnet: es gibt eine Meldung, die jünger ist als das Schließen "
                "dieses Issues."], args.dry_run)
            reopened += 1

    print("\n--- %d neu, %d ergänzt, %d wieder geöffnet, %d unverändert%s" % (
        created, commented, reopened, unchanged, "  (dry-run)" if args.dry_run else ""))
    return 0


def self_test() -> int:
    assert report_key({"key": "mia|lex.x|2026-01-01T00:00:00"}) == "mia|lex.x|2026-01-01T00:00:00"
    assert report_key({"label": "mia", "target_id": "lex.x", "at": "t"}) == "mia|lex.x|t"

    body = render_issue_body("lexeme", "lex.x", {"lemma_de": "Beispiel", "lemma_en": "example",
                                                 "type": "noun", "book": "a2", "unit": "3"},
                             [{"label": "mia", "target_id": "lex.x", "comment": "falsch",
                               "at": "t", "ts": 1, "app_version": "0.3.1", "pack_id": "p",
                               "pack_version": "v7", "learnable_id": "task.x"}])
    assert target_of_body(body) == ("lexeme", "lex.x"), target_of_body(body)
    assert keys_in(body) == {"mia|lex.x|t"}, keys_in(body)
    assert "Pack p v7" in body and "task.x" in body

    # Ein Issue ohne Marker (von Hand angelegt) darf nicht als Treffer gelten.
    assert target_of_body("nur Text") is None
    assert target_of_body("<!-- ms-report-target: kaputt -->") is None
    assert keys_in("nichts") == set()
    # Mehrere Belege in einem Text werden alle gefunden.
    two = render_report({"label": "a", "target_id": "lex.x", "at": "1", "comment": "x"}) \
        + "\n" + render_report({"label": "b", "target_id": "lex.x", "at": "2", "comment": "y"})
    assert keys_in(two) == {"a|lex.x|1", "b|lex.x|2"}, keys_in(two)

    # Ein Marker ohne Ziel-Id wäre zweideutig — das muss scheitern, nicht durchlaufen.
    try:
        report_key({"label": "mia", "at": "t"})
        raise AssertionError("report_key ohne target_id muss scheitern")
    except ValueError:
        pass

    assert "Id im Checkout nicht gefunden" in title_for("lexeme", "lex.weg", None)
    assert title_for("lexeme", "lex.x", {"lemma_de": "Beispiel", "lemma_en": "example"}) \
        == "Meldung: lex.x — „Beispiel → example“"
    assert title_for("sentence", "sen.x", {"source_text": "Ein Satz."}) \
        == "Meldung: sen.x — „Ein Satz.“"
    # Sehr langer Text wird gekürzt, die Id bleibt vollständig.
    long_title = title_for("sentence", "sen.y", {"source_text": "z" * 200})
    assert len(long_title) < 120 and "sen.y" in long_title

    reports, broken = load_reports(
        '{"target_type":"lexeme","target_id":"lex.a","ts":2}\n'
        'kaputt\n'
        '{"target_type":"lexeme"}\n'
        '\n'
        '{"target_type":"lexeme","target_id":"lex.b","ts":1}\n')
    assert len(reports) == 2 and broken == 2, (len(reports), broken)
    assert report_time(reports[0]) > report_time(reports[1])
    assert report_time({"received_at": "2026-09-02T18:04:12+00:00"}).year == 2026
    assert report_time({}).year == 1970

    # --- Abgleich mit einem Issue, das schon da ist ---
    def report(label, at, ts):
        return {"label": label, "target_id": "lex.x", "at": at, "ts": ts, "comment": "x"}

    alt = report("mia", "1", 1_756_000_000)   # 24.08.2025
    neu = report("leo", "2", 1_757_000_000)   # 04.09.2025
    have = keys_in(render_report(alt))
    assert missing_reports([alt], have) == []
    assert missing_reports([alt, neu], have) == [neu]

    offen = {"state": "OPEN", "closedAt": ""}
    zu = {"state": "CLOSED", "closedAt": "2025-09-01T00:00:00Z"}
    assert not needs_reopen(offen, [neu])
    assert needs_reopen(zu, [neu]), "Meldung nach dem Schluss muss wieder öffnen"
    # Lange in der Warteschlange gelegen, vor dem Schluss gemeldet: erledigt, bleibt zu.
    assert not needs_reopen(zu, [alt])
    # Ohne Schlusszeitpunkt gibt es nichts zu vergleichen: der Beleg wird kommentiert,
    # das Issue bleibt zu. Sichtbar ist die Meldung dann trotzdem.
    assert not needs_reopen({"state": "CLOSED", "closedAt": ""}, [neu])

    print("to_issues: Selbsttest bestanden")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    source = parser.add_mutually_exclusive_group()
    source.add_argument("--from-file", help="JSON-Lines-Datei mit den Meldungen")
    source.add_argument("--from-url", help="URL, die die JSON Lines liefert")
    parser.add_argument("--user", help="Benutzer[:Passwort] für --from-url (Basic-Auth)")
    parser.add_argument("--repo", default=DEFAULT_REPO)
    parser.add_argument("--label", default=DEFAULT_LABEL)
    parser.add_argument("--lexemes", default="data/language",
                        help="Wurzel der Sprachdaten für die Id-Auflösung")
    parser.add_argument("--limit", type=int, default=DEFAULT_LIMIT,
                        help="Obergrenze für `gh issue list`; wird sie erreicht, bricht der Lauf ab")
    parser.add_argument("--dry-run", action="store_true",
                        help="nur zeigen, was passieren würde")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    if args.self_test:
        return self_test()
    if not args.from_file and not args.from_url:
        parser.error("--from-file oder --from-url angeben (oder --self-test)")
    return run(args)


if __name__ == "__main__":
    sys.exit(main())
