#!/usr/bin/env bash
# Schreibt stats_key.cfg ins Projekt, damit der Export den Statistik-Kanal einschaltet
# (ADR 0021, src/stats/stats_uploader.gd). Ohne die Datei ist der Kanal in der EXE aus.
#
#   STATS_URL=https://…/statistik/statistik.php STATS_APP_KEY=app-1.XXXX-… tools/stats/write_key.sh
#
# Der Schlüssel wird mit tools/report/mint_token.py geprägt (Label app-<n>). Er steht im
# GitHub-Secret STATS_APP_KEY, die URL in der Repo-Variablen STATS_URL. Lokal reicht eine
# einmal geschriebene stats_key.cfg (gitignored), build.sh nimmt sie mit.
#
# Fehlt eins von beiden, schreibt das Skript nichts, entfernt eine alte Datei nicht und
# endet trotzdem mit 0: eine Fassung ohne Statistik ist ein gültiger Build.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="$ROOT/stats_key.cfg"
KEY_VERSION="${STATS_KEY_VERSION:-1}"

if [[ -z "${STATS_URL:-}" || -z "${STATS_APP_KEY:-}" ]]; then
	echo "tools/stats/write_key.sh: STATS_URL oder STATS_APP_KEY fehlt — Statistik bleibt aus." >&2
	exit 0
fi
if [[ ! "$STATS_APP_KEY" =~ ^app-[a-z0-9-]+\.[0-9A-Z-]+$ ]]; then
	echo "tools/stats/write_key.sh: STATS_APP_KEY sieht nicht wie ein App-Schlüssel aus (app-1.XXXX-…)." >&2
	exit 1
fi
if [[ "$STATS_URL" != https://* ]]; then
	echo "tools/stats/write_key.sh: STATS_URL muss mit https:// beginnen." >&2
	exit 1
fi

cat > "$OUT" <<CFG
[stats]

url="$STATS_URL"
key="$STATS_APP_KEY"
key_version=$KEY_VERSION
CFG
echo "tools/stats/write_key.sh: $OUT geschrieben."
