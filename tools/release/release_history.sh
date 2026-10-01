#!/usr/bin/env bash
# Wählt die Releases, deren Notes der Update-Dialog zeigt: alle der letzten 7 Tage vor dem
# aktuellen, mindestens aber die letzten 3 (der aktuelle zählt mit). Wer mehrere Releases
# übersprungen hat, liest so, was sich seitdem geändert hat — nicht nur das letzte.
#
# Eingabe ist die GitHub-API-Liste der Releases (`gh api …/releases`, ein JSON-Array).
# Der aktuelle Release kommt aus dem Workflow-Ereignis und ersetzt einen gleichnamigen
# Eintrag der Liste: die API kann ihn kurz nach dem Veröffentlichen noch nicht kennen.
# Entwürfe, Vorabfassungen und alles nach dem aktuellen bleiben draußen — ein erneut
# gestarteter alter Release nimmt keine späteren Notes mit.
#
# Ausgabe: JSON-Array [{version, pub_date, notes}], neuester zuerst.
#
# Nutzung:
#   release_history.sh <releases.json> <tag> <published_at> <notes-datei> <out>
set -euo pipefail

if [[ $# -ne 5 ]]; then
	sed -n '2,15p' "$0" >&2
	exit 2
fi

RELEASES="$1"
TAG="$2"
PUBLISHED="$3"
NOTES_FILE="$4"
OUT="$5"

WINDOW_DAYS=7
MIN_RELEASES=3

command -v jq >/dev/null || { echo "FEHLER: jq fehlt." >&2; exit 1; }

jq \
	--arg tag "$TAG" \
	--arg published "$PUBLISHED" \
	--arg notes "$(cat "$NOTES_FILE")" \
	--argjson window "$((WINDOW_DAYS * 86400))" \
	--argjson min "$MIN_RELEASES" \
	'
	($published | fromdateiso8601) as $now
	| [ .[]
		| select(.draft == false and .prerelease == false and .published_at != null)
		| select(.tag_name != $tag)
		| select((.published_at | fromdateiso8601) <= $now)
		| { tag: .tag_name, pub_date: .published_at, notes: (.body // "") } ]
	| . + [ { tag: $tag, pub_date: $published, notes: $notes } ]
	| sort_by(.pub_date | fromdateiso8601) | reverse
	| to_entries
	| map(select(.key < $min or ($now - (.value.pub_date | fromdateiso8601)) <= $window))
	| map(.value | { version: (.tag | ltrimstr("v")), pub_date, notes })
	' "$RELEASES" > "$OUT"

echo ">> $OUT  ($(jq length "$OUT") Releases)"
