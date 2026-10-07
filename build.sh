#!/usr/bin/env bash
# Baut Monster Slam als Windows-EXE (self-contained, PCK eingebettet) und als macOS-App
# (universal, ad hoc signiert, als ZIP).
#
# Einzige Versionsquelle ist project.godot (config/version). Das Skript liest
# die Version dort aus, synchronisiert die Metadaten-Felder in
# export_presets.cfg und schreibt
#   exports/MonsterSlam-<version>.exe
#   exports/MonsterSlam-<version>-macos.zip
#
# Nutzung:
#   ./build.sh            # beide
#   ./build.sh windows    # nur die EXE
#   ./build.sh macos      # nur die macOS-App
#
# Godot-Pfad bei Bedarf per Umgebungsvariable überschreiben:
#   GODOT="/pfad/zu/Godot_console.exe" ./build.sh
set -euo pipefail

# In das Projektverzeichnis wechseln (Verzeichnis dieses Skripts).
cd "$(dirname "$0")"

TARGET="${1:-all}"
case "$TARGET" in
	all | windows | macos) ;;
	*)
		echo "FEHLER: unbekanntes Ziel '$TARGET' (all, windows, macos)." >&2
		exit 2
		;;
esac

# Version aus project.godot lesen (Zeile:  config/version="0.1.0").
VERSION="$(grep -oP '^config/version="\K[^"]+' project.godot || true)"
if [[ -z "$VERSION" ]]; then
	echo "FEHLER: config/version in project.godot nicht gefunden." >&2
	exit 1
fi

OUT_WINDOWS="exports/MonsterSlam-${VERSION}.exe"
OUT_MACOS="exports/MonsterSlam-${VERSION}-macos.zip"

# Version an alle abgeleiteten Stellen schreiben (idempotent, dasselbe Skript nutzt die CI).
bash tools/release/set_version.sh "$VERSION" "$OUT_WINDOWS" "$OUT_MACOS"

mkdir -p exports

# Statistik-Kanal (ADR 0021): nur mit stats_key.cfg (tools/stats/write_key.sh) sendet die
# Fassung. Fehlt sie, ist das kein Fehler — aber man soll es wissen, bevor man verteilt.
if [[ ! -f stats_key.cfg ]]; then
	echo ">> Hinweis: stats_key.cfg fehlt — diese Fassung sendet keine Statistik." >&2
fi

# export <preset> <ausgabe>
export_preset() {
	local preset="$1" out="$2"
	echo ">> Baue $out  (Version $VERSION)"
	# Über tools/godot.sh, nicht direkt: der Wrapper kennt den Godot-Pfad, die
	# Windows-Schreibweise des Projektpfads und nimmt hinterher die Einrückungsschäden
	# zurück, die der Editor an offenen Dateien anrichtet.
	tools/godot.sh --export-release "$preset" "$out" \
		| grep -iE "error|warn|rcedit|template|codesign|\[ done \]|zurückgesetzt|BEHALTEN" || true

	if [[ ! -f "$out" ]]; then
		echo "FEHLER: Export fehlgeschlagen — $out wurde nicht erzeugt." >&2
		exit 1
	fi
	echo ">> Fertig: $out ($(du -h "$out" | cut -f1))"
}

if [[ "$TARGET" != macos ]]; then
	export_preset "Windows Desktop" "$OUT_WINDOWS"
fi
if [[ "$TARGET" != windows ]]; then
	export_preset "macOS" "$OUT_MACOS"
fi
