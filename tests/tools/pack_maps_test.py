#!/usr/bin/env python3
"""Karten-Packs im Build (ADR 0031): Roots mit `scan`, Bilder im Pack, Begleit-Packs.

Baut je Test einen kleinen Baum mit einem Sprach-Root und einem Karten-Root.

    python3 tests/tools/pack_maps_test.py
"""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

import yaml

REPO = Path(__file__).resolve().parents[2]
TOOLS = REPO / "tools" / "packs"
sys.path.insert(0, str(TOOLS))

import build_packs as bp  # noqa: E402

CONFIG = {
    "roots": {
        "language": ["lexemes"],
        "maps": {"scan": ["maps/*/map.json", "maps/*/*.webp"]},
    },
    "min_app_version": "0.0.1",
    "open_licenses": ["own"],
    "protected_books": ["zzbook"],
    "packs": {
        "zz-language": {
            "name": "Sprache", "root": "language", "distribution": "open", "license": "own",
            "include": ["lexemes/*.json"],
        },
        "zz-maps": {
            "name": "Karten", "root": "maps", "distribution": "open", "license": "own",
            "companion_of": "zz-language", "include": ["maps/zzbook/map.json", "maps/zzbook/*.webp"],
        },
    },
}


class PackMapsTest(unittest.TestCase):
    def setUp(self) -> None:
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name)
        self.config = json.loads(json.dumps(CONFIG))
        self.put("language/lexemes/zz.json", json.dumps([{"id": "lex.zz.1"}]))
        self.put("maps/maps/zzbook/map.json", json.dumps({"units": {}}))
        self.put("maps/maps/zzbook/unit1.webp", b"RIFF\x00\x00\x00\x00WEBP")
        # Was neben den Karten liegt und in keinen Pack gehoert.
        self.put("maps/maps/zzbook/unit1.png", b"png")
        self.put("maps/maps/zzbook/unit1-route.json", "{}")
        self.put("maps/maps/zzbook/drafts/unit1.webp", b"draft")

    def put(self, rel: str, content) -> None:
        path = self.root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        if isinstance(content, bytes):
            path.write_bytes(content)
        else:
            path.write_text(content, encoding="utf-8")

    def write_config(self) -> Path:
        path = self.root / "packs.yaml"
        path.write_text(yaml.safe_dump(self.config, allow_unicode=True), encoding="utf-8")
        return path

    def build(self) -> int:
        args = [
            sys.executable, str(TOOLS / "build_packs.py"), "--config", str(self.write_config()),
            "--source", f"language={self.root / 'language'}",
            "--source", f"maps={self.root / 'maps'}", "--out", str(self.root / "dist"),
        ]
        return subprocess.run(args, capture_output=True, text=True).returncode

    def assign(self) -> dict:
        cfg = bp.load_config(self.write_config())
        sources = {name: self.root / name for name in cfg["roots"]}
        per_pack = bp.assign(cfg, sources)
        bp.check_references(cfg, sources, per_pack)
        return per_pack

    def test_scan_nimmt_nur_karte_und_bilder(self) -> None:
        self.assertEqual(
            self.assign()["zz-maps"], ["maps/zzbook/map.json", "maps/zzbook/unit1.webp"]
        )

    def test_unbeanspruchtes_bild_bricht_ab(self) -> None:
        self.put("maps/maps/other/book.webp", b"x")
        with self.assertRaises(bp.BuildError) as caught:
            self.assign()
        self.assertIn("maps/other/book.webp", str(caught.exception))

    def test_begleiter_braucht_einen_bekannten_pack(self) -> None:
        self.config["packs"]["zz-maps"]["companion_of"] = "zz-fehlt"
        with self.assertRaises(bp.BuildError):
            bp.load_config(self.write_config())

    def test_begleiter_steht_im_index_unter_companions(self) -> None:
        self.assertEqual(self.build(), 0)
        index = json.loads((self.root / "dist" / "index.json").read_text(encoding="utf-8"))
        self.assertEqual([p["id"] for p in index["packs"]], ["zz-language"])
        self.assertEqual([p["id"] for p in index["companions"]], ["zz-maps"])
        self.assertEqual(index["companions"][0]["companionOf"], "zz-language")
        with zipfile.ZipFile(self.root / "dist" / "zz-maps.zip") as archive:
            self.assertEqual(
                archive.read("maps/zzbook/unit1.webp"), b"RIFF\x00\x00\x00\x00WEBP"
            )

    def test_offene_karten_mit_buchnamen_bestehen_die_pruefung(self) -> None:
        self.assertEqual(self.build(), 0)
        result = subprocess.run(
            [sys.executable, str(TOOLS / "check_open_packs.py"), "--config",
             str(self.root / "packs.yaml"), str(self.root / "dist" / "zz-maps.zip")],
            capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 0, result.stdout)

    def test_andere_datei_mit_buchnamen_unter_maps_faellt_auf(self) -> None:
        bad = self.root / "bad.zip"
        with zipfile.ZipFile(bad, "w") as archive:
            archive.writestr("maps/zzbook/notes.txt", "x")
        self.write_config()
        result = subprocess.run(
            [sys.executable, str(TOOLS / "check_open_packs.py"), "--config",
             str(self.root / "packs.yaml"), str(bad)],
            capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 1)


if __name__ == "__main__":
    unittest.main()
