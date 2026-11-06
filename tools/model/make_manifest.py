#!/usr/bin/env python3
"""Baut das `model.json`, mit dem das Spiel den Sprachmodell-Zusatz holt.

Das Spiel spiegelt weder llama.cpp noch die Gewichte — beide liegen dauerhaft im Netz.
Was wir liefern müssen, ist nicht die Datei, sondern die Zusicherung, WELCHE Datei gemeint
ist. Genau das steht in diesem Manifest, und genau daran hängt die Sicherheit des ganzen
Weges (siehe ADR 0004, Nachtrag „Stufe 1 auf eigenen Beinen").

Deshalb wird hier nicht abgeschrieben, sondern gerechnet: das Skript lädt jeden Teil
einmal herunter und bildet die Prüfsumme selbst. Eine von einer Webseite kopierte Prüfsumme
sichert nur zu, dass der Download zu der Webseite passt.

Nutzung:

    tools/model/make_manifest.py \\
        --program https://github.com/ggml-org/llama.cpp/releases/download/bXXXX/llama-bXXXX-bin-win-cpu-x64.zip \\
        --program-linux https://github.com/ggml-org/llama.cpp/releases/download/bXXXX/llama-bXXXX-bin-ubuntu-x64.tar.gz \\
        --weights https://huggingface.co/<repo>/resolve/<commit>/<datei>.gguf \\
        --out model.json

`parts` ist der Windows-Block, den auch ältere Fassungen lesen. Weitere Plattformen stehen
unter `platforms` (ADR 0030); die Gewichte werden dafür nur einmal gemessen.

Die Ausgabe gehört neben `index.json` in das Release `packs` des Transport-Repos — dieselbe
Stelle, aus der die Content-Packs kommen. Ein anderes Modell ist damit eine Datei und kein
App-Release.

Bei den Gewichten die URL bitte auf einen COMMIT festnageln (`/resolve/<commit>/`) und
nicht auf `main`: ein beweglicher Zeiger macht die Prüfsumme über Nacht falsch, und dann
lehnt das Spiel den Download ab, ohne dass jemand etwas geändert hätte.
"""

import argparse
import hashlib
import json
import sys
import urllib.request

CHUNK = 1 << 20


def measure(url: str) -> tuple[str, int]:
    """Lädt die Datei einmal und gibt (sha256, bytes) zurück — ohne sie zu behalten."""
    digest = hashlib.sha256()
    size = 0
    with urllib.request.urlopen(url) as response:
        while True:
            chunk = response.read(CHUNK)
            if not chunk:
                break
            digest.update(chunk)
            size += len(chunk)
            print(f"\r  {size / (1024 * 1024):.0f} MB", end="", file=sys.stderr)
    print("", file=sys.stderr)
    return digest.hexdigest(), size


_measured: dict[str, tuple[str, int]] = {}


def part(file_name: str, url: str, unzip: bool) -> dict:
    print(f"{file_name} <- {url}", file=sys.stderr)
    if url not in _measured:
        _measured[url] = measure(url)
    sha256, size = _measured[url]
    entry = {"file": file_name, "url": url, "sha256": sha256, "bytes": size}
    if unzip:
        entry["unzip"] = True
    return entry


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--program", required=True,
                        help="ZIP eines llama.cpp-Releases (enthält llama-server.exe und DLLs)")
    parser.add_argument("--program-linux",
                        help="tar.gz des Ubuntu-x64-Builds von llama.cpp (llama-server und .so)")
    parser.add_argument("--weights", required=True, help="GGUF-Datei, auf einen Commit festgenagelt")
    parser.add_argument("--name", default="Sprachmodell für Bosskämpfe")
    parser.add_argument("--note", default="")
    parser.add_argument("--min-app-version", default="0.10.0")
    parser.add_argument("--out", default="model.json")
    args = parser.parse_args()

    manifest = {
        "name": args.name,
        "min_app_version": args.min_app_version,
        "parts": [
            part("llama-server.exe", args.program, unzip=True),
            part("model.gguf", args.weights, unzip=False),
        ],
    }
    if args.program_linux:
        manifest["platforms"] = {
            "linux-x86_64": [
                part("llama-server", args.program_linux, unzip=True),
                part("model.gguf", args.weights, unzip=False),
            ],
        }
    if args.note:
        manifest["note"] = args.note

    with open(args.out, "w", encoding="utf-8") as out:
        json.dump(manifest, out, indent=2, ensure_ascii=False)
        out.write("\n")

    total = sum(p["bytes"] for p in manifest["parts"])
    print(f">> {args.out} — {total / (1024 ** 3):.1f} GB insgesamt", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
