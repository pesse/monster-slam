#!/usr/bin/env python3
"""Abgeschlossenheits-Gate in tools/packs/build_packs.py (Issue #15).

Ein Pack muss fuer sich allein aufgehen: jede Id, auf die ein Objekt zeigt, liegt im selben
Pack. Die Fixture unter tests/fixtures/packs/references/ ist abgeschlossen; jeder Test
kopiert sie in ein Wegwerf-Verzeichnis und bricht sie an genau einer Stelle auf.

    python3 tests/tools/pack_references_test.py
"""

from __future__ import annotations

import contextlib
import io
import json
import shutil
import sys
import tempfile
import unittest
import unittest.mock
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
FIXTURE = REPO / "tests" / "fixtures" / "packs" / "references"
sys.path.insert(0, str(REPO / "tools" / "packs"))

import build_packs as bp  # noqa: E402

# Je Kante der Datei, in der die Fixture sie traegt, und das Objekt darin.
EDGES = {
    ("lexeme_forms", "lexeme_id"): ("language/lexeme_forms/zz_refs_a.json", "form.zz.a.bigger", "zz-refs-a"),
    ("lexeme_relations", "from_lexeme_id"): ("language/lexeme_relations/zz_refs_a.json", "rel.zz.a.big.small", "zz-refs-a"),
    ("lexeme_relations", "to_lexeme_id"): ("language/lexeme_relations/zz_refs_a.json", "rel.zz.a.big.small", "zz-refs-a"),
    ("sentence_lexemes", "sentence_id"): ("language/sentence_lexemes/zz_refs_a.json", "sl.zz.a.1.big", "zz-refs-a"),
    ("sentence_lexemes", "lexeme_id"): ("language/sentence_lexemes/zz_refs_a.json", "sl.zz.a.1.big", "zz-refs-a"),
    ("waves", "boss"): ("game/waves/zz_refs.json", "wave.zz_refs.boss", "zz-refs-game"),
    ("monster_task_rules", "monster_type"): ("game/monster_task_rules/zz_refs.json", "rule.zz_refs", "zz-refs-game"),
}


class PackReferencesTest(unittest.TestCase):
    def setUp(self) -> None:
        self.fresh()

    def fresh(self) -> None:
        """Eine unberuehrte Kopie der Fixture, weggeraeumt am Testende."""
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name)
        shutil.copytree(FIXTURE, self.root, dirs_exist_ok=True)

    # --- Helfer ----------------------------------------------------------------------

    def edit(self, rel: str, entry_id: str, **fields) -> None:
        path = self.root / rel
        data = json.loads(path.read_text(encoding="utf-8"))
        for entry in data if isinstance(data, list) else [data]:
            if entry.get("id") == entry_id:
                for key, value in fields.items():
                    if value is None:
                        entry.pop(key, None)
                    else:
                        entry[key] = value
        path.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")

    def check(self) -> None:
        cfg = bp.load_config(self.root / "packs.yaml")
        sources = {name: self.root / name for name in cfg["roots"]}
        bp.check_references(cfg, sources, bp.assign(cfg, sources))

    def fails_with(self) -> str:
        with self.assertRaises(bp.BuildError) as caught:
            self.check()
        return str(caught.exception)

    # --- Faelle ----------------------------------------------------------------------

    def test_the_fixture_is_closed(self) -> None:
        self.check()

    def test_the_dry_run_passes_on_the_fixture(self) -> None:
        argv = ["build_packs.py", "--config", str(self.root / "packs.yaml"),
                "--source", f"language={self.root / 'language'}",
                "--source", f"game={self.root / 'game'}", "--dry-run"]
        with unittest.mock.patch.object(sys, "argv", argv), \
                contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(bp.main(), 0)

    def test_every_declared_edge_is_covered_by_the_fixture(self) -> None:
        declared = {(category, field) for category, field, _, _ in bp.REFERENCES}
        self.assertEqual(declared, set(EDGES))
        for category, _, target, _ in bp.REFERENCES:
            self.assertIn(category, bp.CATEGORIES)
            self.assertIn(target, bp.CATEGORIES)

    def test_a_dangling_id_names_pack_file_object_and_target(self) -> None:
        for (category, field), (rel, entry_id, pack_id) in EDGES.items():
            with self.subTest(edge=f"{category}.{field}"):
                self.fresh()
                self.edit(rel, entry_id, **{field: "zz.missing"})
                message = self.fails_with()
                self.assertIn(pack_id, message)
                self.assertIn(Path(rel).relative_to(Path(rel).parts[0]).as_posix(), message)
                self.assertIn(entry_id, message)
                self.assertIn("zz.missing", message)

    def test_an_id_from_another_pack_does_not_count(self) -> None:
        # Im Gesamtbestand gibt es das Ziel — wer nur zz-refs-b installiert, hat es nicht.
        self.edit("language/lexeme_relations/zz_refs_b.json", "rel.zz.b.fast.slow",
                  to_lexeme_id="lex.zz.a.small")
        message = self.fails_with()
        self.assertIn("zz-refs-b", message)
        self.assertIn("lex.zz.a.small", message)

    def test_a_missing_required_field_fails(self) -> None:
        self.edit("language/lexeme_forms/zz_refs_a.json", "form.zz.a.bigger", lexeme_id=None)
        self.assertIn("lexeme_id fehlt", self.fails_with())

    def test_a_wave_without_boss_is_fine(self) -> None:
        self.edit("game/waves/zz_refs.json", "wave.zz_refs.boss", boss=None)
        self.check()

    def test_all_packs_are_reported_in_one_run(self) -> None:
        self.edit("language/lexeme_relations/zz_refs_b.json", "rel.zz.b.fast.slow",
                  to_lexeme_id="zz.missing.b")
        self.edit("game/monster_task_rules/zz_refs.json", "rule.zz_refs",
                  monster_type="zz.missing.game")
        message = self.fails_with()
        self.assertIn("zz.missing.b", message)
        self.assertIn("zz.missing.game", message)


if __name__ == "__main__":
    unittest.main()
