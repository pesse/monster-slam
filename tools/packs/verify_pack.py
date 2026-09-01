#!/usr/bin/env python3
"""Prueft einen Content-Pack und listet seinen Inhalt — Referenzimplementierung des Formats.

Absichtlich unabhaengig von build_packs.py geschrieben: das Format hat drei
Implementierungen (Erzeuger, dieser Pruefer, src/content/pack_crypto.gd), und ein
Missverstaendnis in einer davon soll hier auffallen.

Nutzung:
    verify_pack.py language-basic.zip
    verify_pack.py language-access2.enc --code GEHEIM
    verify_pack.py language-access2.enc --code GEHEIM --extract /tmp/pack
"""

from __future__ import annotations

import argparse
import hashlib
import hmac
import io
import struct
import sys
import zipfile
from pathlib import Path

MAGIC = b"MSPACK"
SUPPORTED_FORMAT = 1
KDF_PBKDF2 = 1
HEADER_LEN = 108
MAC_OFFSET = 76


def fail(message: str) -> None:
    print(f"FEHLER: {message}", file=sys.stderr)
    raise SystemExit(1)


def decrypt(blob: bytes, code: str) -> bytes:
    from cryptography.hazmat.primitives import padding
    from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes

    if len(blob) < HEADER_LEN:
        fail(f"Pack ist zu kurz ({len(blob)} statt mindestens {HEADER_LEN} Bytes).")
    if blob[0:6] != MAGIC:
        fail("Datei ist kein geschuetzter Pack.")
    if blob[6] != SUPPORTED_FORMAT:
        fail(f"Pack-Format {blob[6]} wird nicht unterstuetzt.")
    if blob[7] != KDF_PBKDF2:
        fail(f"Unbekanntes Schluesselverfahren ({blob[7]}).")

    iterations = struct.unpack(">I", blob[8:12])[0]
    salt = blob[12:28]
    verifier = blob[28:60]
    iv = blob[60:76]
    tag = blob[76:108]
    ciphertext = blob[HEADER_LEN:]

    master = hashlib.pbkdf2_hmac("sha256", code.encode("utf-8"), salt, iterations, 32)
    enc_key = hmac.new(master, b"monster-slam:enc", hashlib.sha256).digest()
    mac_key = hmac.new(master, b"monster-slam:mac", hashlib.sha256).digest()
    expected_verifier = hmac.new(master, b"monster-slam:verify", hashlib.sha256).digest()

    if not hmac.compare_digest(expected_verifier, verifier):
        fail("Falscher Zugangscode.")
    # Vor dem Entschluesseln: ein veraenderter Kopf (etwa herabgesetzte Iterationen) darf
    # nicht erst nach dem Entpacken auffallen.
    expected_tag = hmac.new(mac_key, blob[:MAC_OFFSET] + ciphertext, hashlib.sha256).digest()
    if not hmac.compare_digest(expected_tag, tag):
        fail("Pack ist beschaedigt oder wurde veraendert.")

    decryptor = Cipher(algorithms.AES(enc_key), modes.CBC(iv)).decryptor()
    padded = decryptor.update(ciphertext) + decryptor.finalize()
    unpadder = padding.PKCS7(128).unpadder()
    print(f"  Kopf ok: {iterations} Iterationen, Verifier und MAC stimmen.")
    return unpadder.update(padded) + unpadder.finalize()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("pack", type=Path)
    parser.add_argument("--code", default="")
    parser.add_argument("--extract", type=Path)
    args = parser.parse_args()

    blob = args.pack.read_bytes()
    print(f"{args.pack.name}  ({len(blob)} Bytes, sha256 {hashlib.sha256(blob).hexdigest()[:12]}…)")

    if blob[0:6] == MAGIC:
        if not args.code:
            fail("Geschuetzter Pack — --code fehlt.")
        zip_bytes = decrypt(blob, args.code)
    else:
        if args.code:
            print("  Hinweis: offener Pack, --code wird nicht gebraucht.")
        zip_bytes = blob

    with zipfile.ZipFile(io.BytesIO(zip_bytes)) as archive:
        names = sorted(archive.namelist())
        for name in names:
            info = archive.getinfo(name)
            print(f"  {name:52s} {info.file_size:7d} B")
        print(f"  {len(names)} Datei(en)")
        if args.extract:
            args.extract.mkdir(parents=True, exist_ok=True)
            archive.extractall(args.extract)
            print(f"  entpackt nach {args.extract}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
