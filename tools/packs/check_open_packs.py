#!/usr/bin/env python3
"""Prueft fertige, offen verteilte Packs auf geschuetztes Material.

Dritte Sicherung, unabhaengig von den beiden im Build: die Pfadregeln entscheiden ueber
Dateien, `check_no_protected_books` sieht in die Lexeme hinein — dieser Schritt sieht in das
FERTIGE ZIP. Er faengt damit auch einen Fehler im Build selbst ab.

Nutzung:
    check_open_packs.py --config packs.yaml dist/*.zip
"""

from __future__ import annotations

import argparse
import json
import sys
import zipfile
from pathlib import Path

import yaml


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, required=True)
    parser.add_argument("packs", type=Path, nargs="*")
    args = parser.parse_args()

    cfg = yaml.safe_load(args.config.read_text(encoding="utf-8"))
    books = [str(b) for b in cfg.get("protected_books", [])]
    if not books:
        print("Keine protected_books deklariert — nichts zu pruefen.")
        return 0

    problems: list[str] = []
    for path in args.packs:
        with zipfile.ZipFile(path) as archive:
            for name in archive.namelist():
                # Erstens am Namen: die Dateien sind nach ihrer Herkunft benannt.
                if any(book in name for book in books):
                    problems.append(f"{path.name}: Dateiname '{name}'")
                    continue
                # Zweitens am Inhalt: ein `book`-Feld verraet Lehrbuchmaterial auch dann,
                # wenn die Datei unauffaellig heisst.
                if not name.startswith("lexemes/"):
                    continue
                data = json.loads(archive.read(name))
                for entry in data if isinstance(data, list) else [data]:
                    if str(entry.get("book", "")) in books:
                        problems.append(
                            f"{path.name}: '{name}' enthaelt Eintrag "
                            f"'{entry.get('id', '?')}' aus '{entry['book']}'"
                        )

    if problems:
        for problem in problems:
            print(f"::error::Offener Pack enthaelt geschuetztes Material — {problem}")
        return 1
    print(f"{len(args.packs)} offene(r) Pack(s) frei von Lehrbuchmaterial.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
