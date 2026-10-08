#!/usr/bin/env bash
# Holt die Statistik (ADR 0021) vom Server nach stats-data/ms-stats/ (gitignored).
#
#   STATS_SFTP=benutzer@ssh.strato.de tools/stats/fetch.sh
#   python3 tools/stats/report.py          # danach: stats-data/report.html
#
# STATS_REMOTE_DIR nennt den Ablageordner auf dem Server, relativ zum SFTP-Start
# (Vorgabe: ms-stats, also neben ms-secret.php über dem Docroot). Die Ablage ist über
# keine URL erreichbar — mit Absicht; geholt wird nur per SFTP.
#
# Holt jedes Mal alles neu: die Tages-Snapshots werden am selben Tag überschrieben und die
# Spur wird angehängt, ein Abgleich nach Namen sähe beides nicht. Ein paar MB je Profil.
# Die Zähler unter _rate/ bleiben auf dem Server.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET="$ROOT/stats-data"
REMOTE="${STATS_REMOTE_DIR:-ms-stats}"

if [[ -z "${STATS_SFTP:-}" ]]; then
	echo "tools/stats/fetch.sh: STATS_SFTP=benutzer@host fehlt." >&2
	exit 2
fi

mkdir -p "$TARGET"
tmp="$(mktemp -d "$TARGET/.fetch.XXXXXX")"
trap 'rm -rf -- "$tmp"' EXIT

# Erst vollständig in ein frisches Verzeichnis, dann tauschen: ein abgebrochener Abruf
# hinterlässt keinen halben Stand, den report.py für vollständig hielte.
sftp -q -b - "$STATS_SFTP" <<SFTP
lcd $tmp
get -r $REMOTE
SFTP

if [[ ! -d "$tmp/$(basename "$REMOTE")" ]]; then
	echo "tools/stats/fetch.sh: nichts geholt — stimmt STATS_REMOTE_DIR ($REMOTE)?" >&2
	exit 1
fi
rm -rf -- "$tmp/$(basename "$REMOTE")/_rate"
if [[ -d "$TARGET/ms-stats" ]]; then
	mv -- "$TARGET/ms-stats" "$tmp/old"
fi
mv -- "$tmp/$(basename "$REMOTE")" "$TARGET/ms-stats"
echo "tools/stats/fetch.sh: $(find "$TARGET/ms-stats" -mindepth 1 -maxdepth 1 -type d | wc -l) Profile nach $TARGET/ms-stats"
