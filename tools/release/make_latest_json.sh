#!/usr/bin/env bash
# Erzeugt das Update-Manifest latest.json zu den gebauten Fassungen: Prüfsummen,
# Signaturen, Release-Notes.
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
# Je Plattform ein Block in `platforms` (Schlüssel siehe UpdateService.PLATFORM_*), jeder
# mit eigener Prüfsumme und Signatur. Ältere Clients lesen nur ihren eigenen Schlüssel.
#
# Nutzung:
#   make_latest_json.sh <version> <notes-datei> <privater-schlüssel> <out> <history.json|""> \
#       <plattform> <datei> <download-url> [<plattform> <datei> <download-url> …]
set -euo pipefail

if [[ $# -lt 8 || $(( ($# - 5) % 3 )) -ne 0 ]]; then
	sed -n '2,22p' "$0" >&2
	exit 2
fi

VERSION="$1"
NOTES_FILE="$2"
KEY="$3"
OUT="$4"
HISTORY="$5"
shift 5

for tool in openssl jq sha256sum; do
	command -v "$tool" >/dev/null || { echo "FEHLER: $tool fehlt." >&2; exit 1; }
done
if [[ -n "$HISTORY" ]]; then
	jq -e 'type == "array"' "$HISTORY" >/dev/null \
		|| { echo "FEHLER: '$HISTORY' ist kein JSON-Array." >&2; exit 1; }
fi

PUB="$(mktemp)"
trap 'rm -f "$PUB" "$PUB.sig"' EXIT
openssl rsa -in "$KEY" -pubout -out "$PUB" 2>/dev/null

PLATFORMS='{}'
while [[ $# -gt 0 ]]; do
	PLATFORM="$1"
	FILE="$2"
	URL="$3"
	shift 3
	[[ -f "$FILE" ]] || { echo "FEHLER: '$FILE' existiert nicht." >&2; exit 1; }

	SHA="$(sha256sum "$FILE" | cut -d' ' -f1)"

	# -A: einzeilig. Godots Marshalls.base64_to_raw() erwartet keine Zeilenumbrüche.
	SIG="$(openssl dgst -sha256 -sign "$KEY" "$FILE" | openssl base64 -A)"

	# Gegenprobe mit dem öffentlichen Teil desselben Schlüssels: ein unbrauchbares Manifest
	# soll hier auffallen und nicht erst im Spiel.
	printf '%s' "$SIG" | openssl base64 -d -A > "$PUB.sig"
	openssl dgst -sha256 -verify "$PUB" -signature "$PUB.sig" "$FILE" >/dev/null \
		|| { echo "FEHLER: eigene Signatur für '$FILE' verifiziert nicht." >&2; exit 1; }

	PLATFORMS="$(jq -c --arg key "$PLATFORM" --arg url "$URL" --arg sha256 "$SHA" --arg signature "$SIG" \
		'. + {($key): {url: $url, sha256: $sha256, signature: $signature}}' <<<"$PLATFORMS")"
	echo ">> $PLATFORM: $(basename "$FILE")  (sha256 ${SHA:0:12}…)"
done

jq -n \
	--arg version "$VERSION" \
	--arg notes "$(cat "$NOTES_FILE")" \
	--arg pub_date "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
	--argjson history "$(if [[ -n "$HISTORY" ]]; then cat "$HISTORY"; else echo '[]'; fi)" \
	--argjson platforms "$PLATFORMS" \
	'{
		version: $version,
		notes: $notes,
		pub_date: $pub_date,
		history: $history,
		platforms: $platforms
	}' > "$OUT"

echo ">> $OUT  (Version $VERSION)"
