#!/usr/bin/env bash
# Erzeugt das Update-Manifest latest.json zu einer gebauten EXE: Prüfsumme, Signatur,
# Release-Notes.
#
# `notes` trägt nur den aktuellen Release und bleibt für ältere Clients stehen; `history`
# (optional, aus release_history.sh) trägt die Notes der letzten Releases, damit der Dialog
# alles zeigt, was seit der installierten Fassung dazukam.
#
# Die Prüfsumme fängt den kaputten Download, die Signatur den manipulierten — sie allein
# wäre keine Sicherung, denn sie steht im selben Manifest wie die URL. Geprüft wird in der
# App gegen den öffentlichen Schlüssel in src/update/release_key.gd; wer den privaten Teil
# austauscht, muss beide Seiten austauschen.
#
# Nutzung:
#   make_latest_json.sh <exe> <version> <notes-datei> <privater-schlüssel> <download-url> <out> [<history.json>]
set -euo pipefail

if [[ $# -ne 6 && $# -ne 7 ]]; then
	sed -n '2,19p' "$0" >&2
	exit 2
fi

EXE="$1"
VERSION="$2"
NOTES_FILE="$3"
KEY="$4"
URL="$5"
OUT="$6"
HISTORY="${7:-}"

for tool in openssl jq sha256sum; do
	command -v "$tool" >/dev/null || { echo "FEHLER: $tool fehlt." >&2; exit 1; }
done
[[ -f "$EXE" ]] || { echo "FEHLER: '$EXE' existiert nicht." >&2; exit 1; }
if [[ -n "$HISTORY" ]]; then
	jq -e 'type == "array"' "$HISTORY" >/dev/null \
		|| { echo "FEHLER: '$HISTORY' ist kein JSON-Array." >&2; exit 1; }
fi

SHA="$(sha256sum "$EXE" | cut -d' ' -f1)"

# -A: einzeilig. Godots Marshalls.base64_to_raw() erwartet keine Zeilenumbrüche.
SIG="$(openssl dgst -sha256 -sign "$KEY" "$EXE" | openssl base64 -A)"

# Gegenprobe mit dem öffentlichen Teil desselben Schlüssels: ein unbrauchbares Manifest
# soll hier auffallen und nicht erst im Spiel.
PUB="$(mktemp)"
trap 'rm -f "$PUB"' EXIT
openssl rsa -in "$KEY" -pubout -out "$PUB" 2>/dev/null
printf '%s' "$SIG" | openssl base64 -d -A > "$PUB.sig"
openssl dgst -sha256 -verify "$PUB" -signature "$PUB.sig" "$EXE" >/dev/null \
	|| { echo "FEHLER: eigene Signatur verifiziert nicht." >&2; exit 1; }
rm -f "$PUB.sig"

jq -n \
	--arg version "$VERSION" \
	--arg notes "$(cat "$NOTES_FILE")" \
	--arg pub_date "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
	--arg url "$URL" \
	--arg sha256 "$SHA" \
	--arg signature "$SIG" \
	--argjson history "$(if [[ -n "$HISTORY" ]]; then cat "$HISTORY"; else echo '[]'; fi)" \
	'{
		version: $version,
		notes: $notes,
		pub_date: $pub_date,
		history: $history,
		platforms: {
			"windows-x86_64": { url: $url, sha256: $sha256, signature: $signature }
		}
	}' > "$OUT"

echo ">> $OUT  (Version $VERSION, sha256 ${SHA:0:12}…)"
