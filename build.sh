#!/usr/bin/env bash
# Baut Monster Slam als Windows-EXE (self-contained, PCK eingebettet).
#
# Einzige Versionsquelle ist project.godot (config/version). Das Skript liest
# die Version dort aus, synchronisiert die Metadaten-Felder in
# export_presets.cfg und schreibt exports/MonsterSlam-<version>.exe.
#
# Nutzung:
#   ./build.sh
#
# Godot-Pfad bei Bedarf per Umgebungsvariable überschreiben:
#   GODOT="/pfad/zu/Godot_console.exe" ./build.sh
set -euo pipefail

# In das Projektverzeichnis wechseln (Verzeichnis dieses Skripts).
cd "$(dirname "$0")"

PRESET="Windows Desktop"

# Version aus project.godot lesen (Zeile:  config/version="0.1.0").
VERSION="$(grep -oP '^config/version="\K[^"]+' project.godot || true)"
if [[ -z "$VERSION" ]]; then
	echo "FEHLER: config/version in project.godot nicht gefunden." >&2
	exit 1
fi

OUT="exports/MonsterSlam-${VERSION}.exe"

# Version an alle abgeleiteten Stellen schreiben (idempotent, dasselbe Skript nutzt die CI).
bash tools/release/set_version.sh "$VERSION" "$OUT"

mkdir -p exports

echo ">> Baue $OUT  (Version $VERSION)"
# Über tools/godot.sh, nicht direkt: der Wrapper kennt den Godot-Pfad, die
# Windows-Schreibweise des Projektpfads und nimmt hinterher die Einrückungsschäden
# zurück, die der Editor an offenen Dateien anrichtet.
tools/godot.sh --export-release "$PRESET" "$OUT" \
	| grep -iE "error|warn|rcedit|template|\[ done \]|zurückgesetzt|BEHALTEN" || true

if [[ ! -f "$OUT" ]]; then
	echo "FEHLER: Export fehlgeschlagen — $OUT wurde nicht erzeugt." >&2
	exit 1
fi

SIZE="$(du -h "$OUT" | cut -f1)"
echo ">> Fertig: $OUT ($SIZE)"
