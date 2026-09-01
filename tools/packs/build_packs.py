#!/usr/bin/env python3
"""Baut die verteilbaren Content-Packs und das dazugehoerige index.json.

Gegenstueck ist src/content/pack_installer.gd im Spiel; das Containerformat ist in
docs/PACK_FORMAT.md beschrieben, die unabhaengige Zweitimplementierung steht in
verify_pack.py.

Der Zuschnitt ist fail-closed: jede JSON-Datei unter den deklarierten Roots muss auf
GENAU einen Pack passen. Passt eine Datei auf keinen oder auf mehrere, bricht der Build ab,
statt Material mit ungeklaerter Herkunft in einen offen verteilten Pack zu lassen.

Nutzung:
    build_packs.py --config packs.yaml --source language=. --source game=../monster-slam/data --out dist
    build_packs.py --config packs.yaml --source ... --dry-run    # nur pruefen, ohne Secrets
"""

from __future__ import annotations

import argparse
import hashlib
import hmac
import io
import json
import os
import re
import struct
import sys
import zipfile
from pathlib import Path

import yaml

# --- Containerformat (siehe docs/PACK_FORMAT.md) ---------------------------------------

MAGIC = b"MSPACK"
FORMAT_VERSION = 1
KDF_PBKDF2 = 1
# 600_000 ist die OWASP-Empfehlung fuer PBKDF2-HMAC-SHA256 und kostet in GDScript rund
# 0,9 s — die Obergrenze dessen, was beim Entsperren zumutbar ist. Der Wert steht im Kopf
# und ist damit spaeter erhoehbar, ohne alte Packs unlesbar zu machen.
KDF_ITERATIONS = 600_000
SALT_LEN = 16
VERIFIER_LEN = 32
IV_LEN = 16
MAC_LEN = 32
HEADER_LEN = 6 + 1 + 1 + 4 + SALT_LEN + VERIFIER_LEN + IV_LEN + MAC_LEN  # = 108
# Der MAC deckt alles vor sich selbst plus den Ciphertext ab.
MAC_OFFSET = HEADER_LEN - MAC_LEN

LABEL_ENC = b"monster-slam:enc"
LABEL_MAC = b"monster-slam:mac"
LABEL_VERIFY = b"monster-slam:verify"

# `schemaVersion` 2 = Eintraege tragen `minVersion`. Rein additiv.
INDEX_SCHEMA_VERSION = 2

# Verzeichnisse, in die ein Pack schreiben darf — muss mit _by_category in
# src/core/content_registry.gd und CATEGORIES in src/content/pack_installer.gd
# uebereinstimmen. `check_categories_match_installer()` prueft das gegen den Quelltext,
# damit die Liste nicht auseinanderlaeuft: was hier steht und dort nicht, liefert der Pack
# aus und der Installer verwirft es stillschweigend.
CATEGORIES = {
    "lexemes",
    "lexeme_forms",
    "lexeme_relations",
    "sentences",
    "sentence_lexemes",
    "task_definitions",
    "monster_task_rules",
    "monsters",
    "bosses",
    "skills",
    "waves",
}


class BuildError(Exception):
    """Ein Grund, den Build abzubrechen — wird als Fehlermeldung ausgegeben."""


# --- Konfiguration ---------------------------------------------------------------------


def load_config(path: Path) -> dict:
    cfg = yaml.safe_load(path.read_text(encoding="utf-8"))
    for key in ("roots", "packs", "min_app_version"):
        if key not in cfg:
            raise BuildError(f"{path}: '{key}' fehlt.")
    check_version("min_app_version", cfg["min_app_version"])
    for pack_id, pack in cfg["packs"].items():
        if "min_app_version" in pack:
            check_version(f"Pack '{pack_id}': min_app_version", pack["min_app_version"])
        for key in ("name", "root", "distribution", "license", "include"):
            if key not in pack:
                raise BuildError(f"Pack '{pack_id}': '{key}' fehlt.")
        if pack["distribution"] not in ("open", "protected"):
            raise BuildError(f"Pack '{pack_id}': distribution muss open oder protected sein.")
        if pack["root"] not in cfg["roots"]:
            raise BuildError(f"Pack '{pack_id}': unbekannter root '{pack['root']}'.")
        if pack["distribution"] == "open" and pack["license"] not in cfg.get("open_licenses", []):
            raise BuildError(
                f"Pack '{pack_id}' ist offen verteilt, aber '{pack['license']}' steht nicht "
                "in open_licenses."
            )
        if pack["distribution"] == "protected" and "password_env" not in pack:
            raise BuildError(f"Pack '{pack_id}': geschuetzt, aber ohne password_env.")
    return cfg


def check_version(label: str, value) -> None:
    """Die App liest nur ein Zahlentripel; alles andere laesst dort die Schranke greifen."""
    parts = str(value).split(".")
    if len(parts) != 3 or not all(p.isdigit() for p in parts):
        raise BuildError(f"{label}: '{value}' ist keine dreistellige Version.")


def min_app_version(cfg: dict, pack: dict) -> str:
    return pack.get("min_app_version") or cfg["min_app_version"]


# --- Zuordnung Datei -> Pack -----------------------------------------------------------


def scan_root(base: Path, subdirs: list[str]) -> set[str]:
    """Alle JSON-Dateien eines Roots als root-relative Posix-Pfade."""
    found: set[str] = set()
    for subdir in subdirs:
        directory = base / subdir
        if not directory.is_dir():
            # Fehlt ein Verzeichnis, ist das kein Fehler: nicht jede Kategorie ist gefuellt.
            continue
        for path in directory.rglob("*.json"):
            found.add(path.relative_to(base).as_posix())
    return found


def match_pack(base: Path, patterns: list[str]) -> set[str]:
    matched: set[str] = set()
    for pattern in patterns:
        for path in base.glob(pattern):
            if path.is_file():
                matched.add(path.relative_to(base).as_posix())
    return matched


def assign(cfg: dict, sources: dict[str, Path]) -> dict[str, list[str]]:
    """Datei -> Pack, fail-closed. Rueckgabe: pack_id -> sortierte Dateiliste."""
    per_pack: dict[str, list[str]] = {}
    # root -> {relpath: [pack_ids]}
    claims: dict[str, dict[str, list[str]]] = {root: {} for root in cfg["roots"]}

    for pack_id, pack in cfg["packs"].items():
        root = pack["root"]
        base = sources[root]
        files = match_pack(base, pack["include"])
        per_pack[pack_id] = sorted(files)
        for rel in files:
            claims[root].setdefault(rel, []).append(pack_id)

    problems: list[str] = []
    for root, subdirs in cfg["roots"].items():
        present = scan_root(sources[root], subdirs)
        claimed = set(claims[root])
        for rel in sorted(present - claimed):
            problems.append(f"  {root}/{rel} — passt auf keinen Pack")
        for rel in sorted(claimed - present):
            owners = ", ".join(claims[root][rel])
            problems.append(
                f"  {root}/{rel} — von {owners} erfasst, liegt aber ausserhalb der "
                f"deklarierten Verzeichnisse ({', '.join(subdirs)})"
            )
        for rel, owners in sorted(claims[root].items()):
            if len(owners) > 1:
                problems.append(f"  {root}/{rel} — mehrfach erfasst: {', '.join(owners)}")

    if problems:
        raise BuildError(
            "Zuordnung nicht eindeutig (fail-closed):\n" + "\n".join(problems)
        )
    return per_pack


def check_categories_match_installer() -> None:
    """Vergleicht CATEGORIES mit der Liste im Installer (dieselbe Repo-Kopie).

    Fehlt die Datei — z.B. weil das Werkzeug irgendwo einzeln liegt — wird nicht geprueft;
    besser keine Pruefung als eine, die am falschen Pfad scheitert.
    """
    source = Path(__file__).resolve().parents[2] / "src" / "content" / "pack_installer.gd"
    if not source.is_file():
        return
    text = source.read_text(encoding="utf-8")
    match = re.search(r"const CATEGORIES[^=]*=\s*\[(.*?)\]", text, re.DOTALL)
    if not match:
        return
    installer = set(re.findall(r'"([a-z_]+)"', match.group(1)))
    if installer != CATEGORIES:
        only_here = sorted(CATEGORIES - installer)
        only_there = sorted(installer - CATEGORIES)
        raise BuildError(
            "Kategorienlisten laufen auseinander — "
            f"nur in build_packs.py: {only_here or '-'}, "
            f"nur in pack_installer.gd: {only_there or '-'}. "
            "Beide Listen (und _by_category in content_registry.gd) angleichen."
        )


def check_paths(pack_id: str, files: list[str]) -> None:
    """Ein Pack darf nur in die Kategorieverzeichnisse schreiben."""
    for rel in files:
        head = rel.split("/")[0]
        if head not in CATEGORIES:
            raise BuildError(
                f"Pack '{pack_id}': '{rel}' liegt ausserhalb der Kategorieverzeichnisse."
            )


def check_no_protected_books(cfg: dict, base: Path, pack_id: str, files: list[str]) -> None:
    """Zweite, von den Pfadregeln unabhaengige Sicherung fuer offene Packs.

    Die Pfadregeln entscheiden ueber Dateien; diese Pruefung sieht in die Dateien hinein.
    Sie faengt den Fall ab, in dem Lehrbuchmaterial in eine Datei rutscht, die ein offener
    Pack einsammelt — buchgebundene Lexeme tragen immer ein `book`.
    """
    protected = set(cfg.get("protected_books", []))
    if not protected:
        return
    for rel in files:
        if not rel.startswith("lexemes/"):
            continue
        data = json.loads((base / rel).read_text(encoding="utf-8"))
        for entry in data if isinstance(data, list) else [data]:
            book = str(entry.get("book", ""))
            if book in protected:
                raise BuildError(
                    f"Pack '{pack_id}' ist offen verteilt, aber {rel} enthaelt Material aus "
                    f"'{book}' (Eintrag '{entry.get('id', '?')}')."
                )


# --- Packen ----------------------------------------------------------------------------


def content_version(base: Path, files: list[str]) -> str:
    """Version aus dem Inhalt: sie aendert sich genau dann, wenn sich der Inhalt aendert.

    Verglichen wird in der App nur auf Gleichheit ('installiert' vs. 'Update'), nie auf
    Groesse — deshalb braucht der Wert keine Ordnung, nur Eindeutigkeit.
    """
    digest = hashlib.sha256()
    for rel in files:
        digest.update(rel.encode("utf-8"))
        digest.update(hashlib.sha256((base / rel).read_bytes()).digest())
    return digest.hexdigest()[:12]


def build_zip(base: Path, files: list[str]) -> bytes:
    """Deterministisches ZIP: sortierte Namen, feste Zeitstempel."""
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w", zipfile.ZIP_DEFLATED) as archive:
        for rel in files:
            info = zipfile.ZipInfo(rel, date_time=(1980, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            archive.writestr(info, (base / rel).read_bytes())
    return buffer.getvalue()


def derive_keys(code: str, salt: bytes, iterations: int) -> tuple[bytes, bytes, bytes]:
    master = hashlib.pbkdf2_hmac("sha256", code.encode("utf-8"), salt, iterations, 32)
    mac = lambda label: hmac.new(master, label, hashlib.sha256).digest()  # noqa: E731
    return mac(LABEL_ENC), mac(LABEL_MAC), mac(LABEL_VERIFY)


def encrypt(plain: bytes, code: str) -> bytes:
    from cryptography.hazmat.primitives import padding
    from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes

    salt = os.urandom(SALT_LEN)
    iv = os.urandom(IV_LEN)
    enc_key, mac_key, verifier = derive_keys(code, salt, KDF_ITERATIONS)

    padder = padding.PKCS7(128).padder()
    padded = padder.update(plain) + padder.finalize()
    encryptor = Cipher(algorithms.AES(enc_key), modes.CBC(iv)).encryptor()
    ciphertext = encryptor.update(padded) + encryptor.finalize()

    head = (
        MAGIC
        + bytes([FORMAT_VERSION, KDF_PBKDF2])
        + struct.pack(">I", KDF_ITERATIONS)
        + salt
        + verifier
        + iv
    )
    assert len(head) == MAC_OFFSET, len(head)
    # Encrypt-then-MAC ueber Kopf UND Ciphertext: ein herabgesetzter Iterationswert im Kopf
    # laesst die Pruefung scheitern, statt still einen schwaecheren Schluessel zu erzwingen.
    tag = hmac.new(mac_key, head + ciphertext, hashlib.sha256).digest()
    return head + tag + ciphertext


# --- Hauptlauf -------------------------------------------------------------------------


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, default=Path("packs.yaml"))
    parser.add_argument(
        "--source",
        action="append",
        default=[],
        metavar="NAME=PFAD",
        help="Root-Zuordnung, mehrfach angebbar.",
    )
    parser.add_argument("--out", type=Path, default=Path("dist"))
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Nur Zuordnung und Gates pruefen — ohne Secrets, ohne Ausgabe.",
    )
    args = parser.parse_args()

    try:
        cfg = load_config(args.config)
        sources: dict[str, Path] = {}
        for spec in args.source:
            name, _, path = spec.partition("=")
            sources[name] = Path(path)
        missing = [r for r in cfg["roots"] if r not in sources]
        if missing:
            raise BuildError(f"Kein --source fuer: {', '.join(missing)}")
        for name, path in sources.items():
            if not path.is_dir():
                raise BuildError(f"--source {name}={path}: Verzeichnis fehlt.")

        check_categories_match_installer()
        per_pack = assign(cfg, sources)
        index = {"schemaVersion": INDEX_SCHEMA_VERSION, "packs": []}

        for pack_id, pack in cfg["packs"].items():
            base = sources[pack["root"]]
            files = per_pack[pack_id]
            if not files:
                raise BuildError(f"Pack '{pack_id}' waere leer.")
            check_paths(pack_id, files)
            protected = pack["distribution"] == "protected"
            if not protected:
                check_no_protected_books(cfg, base, pack_id, files)

            version = content_version(base, files)
            entry = {
                "id": pack_id,
                "name": pack["name"],
                "description": pack.get("description", ""),
                "license": pack["license"],
                "protected": protected,
                "version": version,
                "fileCount": len(files),
                "minVersion": min_app_version(cfg, pack),
            }

            if args.dry_run:
                print(f"  {pack_id:18s} {len(files):4d} Datei(en)  {version}  "
                      f"{'geschuetzt' if protected else 'offen'}")
                index["packs"].append(entry)
                continue

            blob = build_zip(base, files)
            if protected:
                code = os.environ.get(pack["password_env"], "")
                if not code:
                    raise BuildError(
                        f"Pack '{pack_id}': ${pack['password_env']} ist nicht gesetzt."
                    )
                blob = encrypt(blob, code)
            suffix = ".enc" if protected else ".zip"
            name = f"{pack_id}{suffix}"
            args.out.mkdir(parents=True, exist_ok=True)
            (args.out / name).write_bytes(blob)
            entry["file"] = name
            entry["size"] = len(blob)
            entry["sha256"] = hashlib.sha256(blob).hexdigest()
            entry["keyVersion"] = int(pack.get("key_version", 1)) if protected else None
            if entry["keyVersion"] is None:
                del entry["keyVersion"]
            index["packs"].append(entry)
            print(f"  {name:22s} {len(files):4d} Datei(en)  {len(blob)/1024:7.1f} KiB  {version}")

        if args.dry_run:
            print(f"\nZuordnung eindeutig, {len(index['packs'])} Pack(s).")
            return 0

        (args.out / "index.json").write_text(
            json.dumps(index, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
        )
        print(f"  index.json             {len(index['packs'])} Pack(s)")
        return 0
    except BuildError as err:
        print(f"FEHLER: {err}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
