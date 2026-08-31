#!/usr/bin/env bash
# Trägt eine Version an allen Stellen ein, die sie führen müssen.
#
# Einzige Quelle der Wahrheit ist `config/version` in project.godot; im Release-Workflow
# wird sie aus dem Tag gespeist. export_presets.cfg ist danach nur noch Ableitung — dieses
# Skript hält sie synchron, damit lokaler Build und CI nicht auseinanderlaufen.
#
# Nutzung:
#   set_version.sh <version> [<ausgabe-exe>]
set -euo pipefail

cd "$(dirname "$0")/../.."

VERSION="${1:?Version fehlt}"
OUT="${2:-}"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-].+)?$ ]]; then
	echo "FEHLER: '$VERSION' ist keine gültige Version." >&2
	exit 1
fi

sed -i -E "s|^config/version=\".*\"|config/version=\"${VERSION}\"|" project.godot

# EXE-Metadaten wollen vier Stellen (0.2.0 -> 0.2.0.0).
PE_VERSION="${VERSION%%-*}"
while [[ "$(tr -cd '.' <<<"$PE_VERSION" | wc -c)" -lt 3 ]]; do
	PE_VERSION="${PE_VERSION}.0"
done

if [[ -f export_presets.cfg ]]; then
	sed -i \
		-e "s|^application/file_version=.*|application/file_version=\"${PE_VERSION}\"|" \
		-e "s|^application/product_version=.*|application/product_version=\"${PE_VERSION}\"|" \
		export_presets.cfg
	if [[ -n "$OUT" ]]; then
		sed -i -e "s|^export_path=.*|export_path=\"${OUT}\"|" export_presets.cfg
	fi
fi

echo ">> Version $VERSION (PE ${PE_VERSION}${OUT:+, Ziel $OUT})"
