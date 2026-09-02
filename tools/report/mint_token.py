#!/usr/bin/env python3
"""Melde-Token prägen (siehe docs/adr/0002-melde-rueckkanal.md).

Ein Token nennt die Person und beweist sich selbst:

    label = kurzer Name des Melders, [a-z0-9-], z.B. "mia"
    mac   = Crockford-Base32( HMAC-SHA256(secret, "<key_version>:<label>")[:10] )
    Token = "<label>.<mac>"        z.B.  mia.K7Q29FTX3M5R8W1E

Das Geheimnis liegt ausschliesslich auf dem Server (server/melden/README.md); hier wird
es nur zum Praegen gelesen und nie geschrieben. Zweitimplementierung dieses Formats ist
server/melden/token.php -- eine Aenderung hier ist eine Aenderung an beiden Stellen, und
`--self-test` haelt die Vektoren fest, gegen die sich beide messen.

    python3 tools/report/mint_token.py --new-secret
    MONSTER_SLAM_REPORT_SECRET=<hex> python3 tools/report/mint_token.py mia leo
    python3 tools/report/mint_token.py --self-test
"""

from __future__ import annotations

import argparse
import hashlib
import hmac
import os
import re
import secrets
import sys

# Crockford-Base32: ohne I, L, O, U -- damit ein abgetipptes Token nicht an einer
# verwechselten Ziffer scheitert.
ALPHABET = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
MAC_BYTES = 10          # 80 Bit -> genau 16 Zeichen, ohne Rest und ohne Padding
MAC_CHARS = 16
LABEL_RE = re.compile(r"^[a-z0-9][a-z0-9-]{0,23}$")

# Verbindliche Vektoren fuer beide Implementierungen. Das Geheimnis ist ein Testwert.
VECTORS = [
    # (secret_hex, key_version, label, token)
    ("00" * 32, 1, "mia", "mia.6FRQ4TRQV7AY862H"),
    ("00" * 32, 2, "mia", "mia.RTJTYE45FF3327KK"),
    ("0f1e2d3c4b5a69788796a5b4c3d2e1f00f1e2d3c4b5a69788796a5b4c3d2e1f0", 1, "leo",
     "leo.D8E81TJPZRJE9MJ6"),
]


def b32(raw: bytes) -> str:
    """Crockford-Base32, MSB zuerst. Nur fuer Laengen, die auf 5 Bit aufgehen."""
    bits = int.from_bytes(raw, "big")
    width = len(raw) * 8
    if width % 5 != 0:
        raise ValueError("Laenge %d Bit geht nicht auf 5 Bit auf" % width)
    chars = []
    for shift in range(width - 5, -1, -5):
        chars.append(ALPHABET[(bits >> shift) & 0x1F])
    return "".join(chars)


def mac(secret_hex: str, key_version: int, label: str) -> str:
    secret = bytes.fromhex(secret_hex)
    message = ("%d:%s" % (key_version, label)).encode("utf-8")
    return b32(hmac.new(secret, message, hashlib.sha256).digest()[:MAC_BYTES])


def token(secret_hex: str, key_version: int, label: str) -> str:
    if not LABEL_RE.match(label):
        raise SystemExit("Label '%s' passt nicht auf %s" % (label, LABEL_RE.pattern))
    return "%s.%s" % (label, mac(secret_hex, key_version, label))


def grouped(tok: str) -> str:
    """Zum Vorlesen/Abtippen: der MAC-Teil in Vierergruppen."""
    label, _, m = tok.partition(".")
    return "%s.%s" % (label, "-".join(m[i:i + 4] for i in range(0, len(m), 4)))


def read_secret(args: argparse.Namespace) -> str:
    raw = ""
    if args.secret_file:
        with open(args.secret_file, "r", encoding="utf-8") as handle:
            raw = handle.read()
    elif args.secret:
        raw = args.secret
    else:
        raw = os.environ.get("MONSTER_SLAM_REPORT_SECRET", "")
    raw = raw.strip()
    if not raw:
        raise SystemExit(
            "Kein Geheimnis. --secret, --secret-file oder MONSTER_SLAM_REPORT_SECRET setzen "
            "(--new-secret erzeugt eines)."
        )
    if len(raw) != 64 or any(c not in "0123456789abcdefABCDEF" for c in raw):
        raise SystemExit("Geheimnis muss 64 Hex-Zeichen sein (32 Byte), ist: %d Zeichen" % len(raw))
    return raw.lower()


def self_test() -> int:
    bad = 0
    for secret_hex, key_version, label, expected in VECTORS:
        got = token(secret_hex, key_version, label)
        ok = got == expected
        bad += 0 if ok else 1
        print("%s  v%d %-6s %s%s" % (
            "ok  " if ok else "FEHL", key_version, label, got,
            "" if ok else "   erwartet: %s" % expected))
    # Eigenschaften, die das Format zusagt.
    assert len(mac("00" * 32, 1, "mia")) == MAC_CHARS
    assert all(c in ALPHABET for c in mac("00" * 32, 1, "mia"))
    assert mac("00" * 32, 1, "mia") != mac("00" * 32, 2, "mia"), "key_version muss wirken"
    assert mac("00" * 32, 1, "mia") != mac("11" * 32, 1, "mia"), "secret muss wirken"
    print("--- %d Vektoren, %d Abweichungen" % (len(VECTORS), bad))
    return 1 if bad else 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("labels", nargs="*", help="Melder-Kuerzel, z.B. mia leo")
    parser.add_argument("--secret", help="Geheimnis als 64 Hex-Zeichen")
    parser.add_argument("--secret-file", help="Datei mit dem Geheimnis")
    parser.add_argument("--key-version", type=int, default=1)
    parser.add_argument("--new-secret", action="store_true",
                        help="Neues Geheimnis erzeugen und ausgeben (nicht speichern)")
    parser.add_argument("--self-test", action="store_true",
                        help="Format gegen die Vektoren pruefen")
    args = parser.parse_args()

    if args.self_test:
        return self_test()

    if args.new_secret:
        print(secrets.token_hex(32))
        print("# In server/melden/../ms-secret.php eintragen, NICHT committen.", file=sys.stderr)
        return 0

    if not args.labels:
        parser.error("Kein Label angegeben (oder --new-secret / --self-test)")

    secret_hex = read_secret(args)
    for label in args.labels:
        print("%-8s %s" % (label, grouped(token(secret_hex, args.key_version, label))))
    return 0


if __name__ == "__main__":
    sys.exit(main())
