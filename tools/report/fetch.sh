#!/usr/bin/env bash
# Holt die Meldungen (ADR 0002, ADR 0022) vom Server nach stats-data/reports.jsonl
# (gitignored) und reicht sie auf Wunsch an tools/report/to_issues.py weiter.
#
#   REPORT_SFTP=strato tools/report/fetch.sh               # nur holen
#   REPORT_SFTP=strato tools/report/fetch.sh --dry-run     # holen, Issues zeigen
#   REPORT_SFTP=strato tools/report/fetch.sh --issues      # holen, Issues anlegen
#
# Alle Argumente außer --issues gehen unverändert an to_issues.py (--limit, --repo, …).
# Ohne REPORT_SFTP gilt STATS_SFTP. REPORT_REMOTE_FILE nennt die Datei auf dem Server,
# relativ zum SFTP-Start (Vorgabe: ms-reports/reports.jsonl, über dem Docroot und über keine
# URL erreichbar — geholt wird nur per SFTP).
#
# Holt jedes Mal die ganze Datei: to_issues.py hält keinen Zustand und trägt nur nach, was
# im Content-Repo noch fehlt.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET="$ROOT/stats-data"
REMOTE="${REPORT_REMOTE_FILE:-ms-reports/reports.jsonl}"
HOST="${REPORT_SFTP:-${STATS_SFTP:-}}"

if [[ -z "$HOST" ]]; then
	echo "tools/report/fetch.sh: REPORT_SFTP=benutzer@host (oder ein ssh-Alias) fehlt." >&2
	exit 2
fi

mkdir -p "$TARGET"
tmp="$(mktemp -d "$TARGET/.fetch.XXXXXX")"
trap 'rm -rf -- "$tmp"' EXIT

# Erst vollständig holen, dann tauschen: ein abgebrochener Abruf hinterlässt keine halbe
# Datei, die to_issues.py für vollständig hielte.
if ! sftp -q -b - "$HOST" >/dev/null <<SFTP
lcd $tmp
get $REMOTE
SFTP
then
	echo "tools/report/fetch.sh: nichts geholt — noch keine Meldungen, oder stimmt REPORT_REMOTE_FILE ($REMOTE)?" >&2
	exit 1
fi
mv -- "$tmp/$(basename "$REMOTE")" "$TARGET/reports.jsonl"
echo "tools/report/fetch.sh: $(wc -l < "$TARGET/reports.jsonl") Meldung(en) nach $TARGET/reports.jsonl"

if [[ $# -eq 0 ]]; then
	exit 0
fi
args=()
for arg in "$@"; do
	[[ "$arg" == "--issues" ]] || args+=("$arg")
done
cd "$ROOT"
exec python3 tools/report/to_issues.py --from-file "$TARGET/reports.jsonl" "${args[@]}"
