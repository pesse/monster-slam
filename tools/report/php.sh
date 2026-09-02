#!/usr/bin/env bash
# PHP für den Melde-Endpunkt — ohne PHP auf dem Rechner.
#
# Ruft `php "$@"` auf: nativ, wenn eine Installation da ist (so läuft es in der CI),
# sonst im Container aus .devcontainer/Dockerfile über podman oder docker. Damit ist der
# Aufruf überall derselbe:
#
#   tools/report/php.sh server/melden/verify_token.php --self-test
#   tools/report/php.sh server/melden/test_endpoint.php
#
# PHP_BIN=... erzwingt eine bestimmte Installation, MS_PHP_ENGINE=podman|docker eine
# bestimmte Container-Laufzeit.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
IMAGE="${MS_PHP_IMAGE:-localhost/monster-slam-php:8.3}"

if [[ -n "${PHP_BIN:-}" ]]; then
	exec "$PHP_BIN" "$@"
fi
if command -v php >/dev/null 2>&1; then
	exec php "$@"
fi

engine="${MS_PHP_ENGINE:-}"
if [[ -z "$engine" ]]; then
	for candidate in podman docker; do
		if command -v "$candidate" >/dev/null 2>&1; then
			engine="$candidate"
			break
		fi
	done
fi
if [[ -z "$engine" ]]; then
	echo "tools/report/php.sh: kein php, kein podman, kein docker." >&2
	echo "  Entweder .devcontainer öffnen ('Reopen in Container') oder podman installieren." >&2
	exit 127
fi

# Erst bauen, wenn das Abbild fehlt — der Bau dauert, der Lauf danach nicht.
if ! "$engine" image exists "$IMAGE" 2>/dev/null && ! "$engine" image inspect "$IMAGE" >/dev/null 2>&1; then
	echo ">> $engine build $IMAGE (einmalig)" >&2
	"$engine" build -t "$IMAGE" -f "$ROOT/.devcontainer/Dockerfile" "$ROOT/.devcontainer" >&2
fi

opts=(--rm --interactive --volume "$ROOT:/work" --workdir /work)
if [[ "$engine" == "podman" ]]; then
	# Rootless podman bildet den Host-Nutzer sonst auf root im Container ab; dann gehören
	# im gebundenen Verzeichnis erzeugte Dateien hinterher root.
	opts+=(--userns=keep-id)
fi
[[ -t 0 ]] && opts+=(--tty)

exec "$engine" run "${opts[@]}" "$IMAGE" php "$@"
