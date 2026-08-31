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

GODOT="${GODOT:-/mnt/c/dev/_tools/godot/Godot_v4.7-stable_win64_console.exe}"
PRESET="Windows Desktop"
WIN_PATH="C:/dev/privat/monster-slam"

if [[ ! -x "$GODOT" ]]; then
	echo "FEHLER: Godot-Konsolen-Build nicht gefunden: $GODOT" >&2
	echo "        Pfad per  GODOT=... ./build.sh  setzen." >&2
	exit 1
fi

# Version aus project.godot lesen (Zeile:  config/version="0.1.0").
VERSION="$(grep -oP '^config/version="\K[^"]+' project.godot || true)"
if [[ -z "$VERSION" ]]; then
	echo "FEHLER: config/version in project.godot nicht gefunden." >&2
	exit 1
fi

OUT="exports/MonsterSlam-${VERSION}.exe"

# Version an alle abgeleiteten Stellen schreiben (idempotent, dasselbe Skript nutzt die CI).
tools/release/set_version.sh "$VERSION" "$OUT"

mkdir -p exports

echo ">> Baue $OUT  (Version $VERSION)"
"$GODOT" --headless --path "$WIN_PATH" \
	--export-release "$PRESET" "$OUT" 2>&1 | tr -d '\r' \
	| grep -iE "error|warn|rcedit|template|\[ done \]" || true

if [[ ! -f "$OUT" ]]; then
	echo "FEHLER: Export fehlgeschlagen — $OUT wurde nicht erzeugt." >&2
	exit 1
fi

SIZE="$(du -h "$OUT" | cut -f1)"
echo ">> Fertig: $OUT ($SIZE)"
