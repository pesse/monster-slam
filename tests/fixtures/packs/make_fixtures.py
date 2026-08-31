#!/usr/bin/env python3
"""Erzeugt die Pack-Fixtures fuer tests/pack_*_test.gd.

Baut ueber build_packs.py, damit die Fixtures dasselbe Format haben wie die echten Packs —
ein Formatfehler soll in den Tests auffallen und nicht erst beim Ausrollen.

    python3 tests/fixtures/packs/make_fixtures.py
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[2] / "tools" / "packs"))

import build_packs as bp  # noqa: E402

CODE = "test-code"

V1 = {
    "lexemes/fixture.json": [
        {"id": "lex.fixture.thing", "lemma_en": "thing", "lemma_de": "Ding", "type": "noun"},
        {"id": "lex.fixture.small", "lemma_en": "small", "lemma_de": "klein", "type": "adjective"},
    ],
    "monsters/fixture.json": [{"id": "mon.fixture", "name": "Testmonster", "hp": 1}],
}

# Ueberschreibt einen eingebauten Eintrag aus data/monsters/basic_monsters.json — der Test
# der Vorrangregel in tests/content_registry_roots_test.gd braucht eine echte Kollision.
OVERRIDE = {
    "monsters/override.json": [
        {"id": "monster.skeleton_minion", "name": "Aus dem Pack", "hp": 42, "carries": "vocabulary"}
    ],
    "lexemes/extra.json": [
        {"id": "lex.fixture.extra", "lemma_en": "extra", "lemma_de": "zusaetzlich", "type": "noun"}
    ],
}

# Zweite Fassung: ein geaenderter Eintrag, eine zurueckgezogene Datei.
V2 = {
    "lexemes/fixture.json": [
        {"id": "lex.fixture.thing", "lemma_en": "thing", "lemma_de": "Sache", "type": "noun"},
        {"id": "lex.fixture.small", "lemma_en": "small", "lemma_de": "klein", "type": "adjective"},
    ],
}


def write_tree(base: Path, tree: dict) -> list[str]:
    for rel, payload in tree.items():
        path = base / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    return sorted(tree)


def main() -> int:
    staging = HERE / "_staging"
    for name, tree in (("v1", V1), ("v2", V2), ("override", OVERRIDE)):
        base = staging / name
        files = write_tree(base, tree)
        blob = bp.build_zip(base, files)
        (HERE / f"open_{name}.zip").write_bytes(blob)
        if name == "v1":
            (HERE / "protected_v1.enc").write_bytes(bp.encrypt(blob, CODE))
        print(f"  open_{name}.zip  {len(files)} Datei(en)  {len(blob)} B")
    # Ein Pack, der aus seinem Zielverzeichnis herausschreiben will.
    hostile = staging / "hostile"
    (hostile / "lexemes").mkdir(parents=True, exist_ok=True)
    (hostile / "lexemes" / "ok.json").write_text('{"id":"lex.fixture.ok"}\n', encoding="utf-8")
    blob = bp.build_zip(hostile, ["lexemes/ok.json"])
    import io
    import zipfile

    buffer = io.BytesIO(blob)
    with zipfile.ZipFile(buffer, "a") as archive:
        archive.writestr("../../settings.cfg", "[general]\n")
        archive.writestr("progress/default.json", "{}\n")
    (HERE / "hostile.zip").write_bytes(buffer.getvalue())
    print("  hostile.zip     3 Eintraege (2 unzulaessige Pfade)")
    print(f"\nZugangscode der Fixture: {CODE}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
