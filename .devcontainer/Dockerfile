# PHP-Werkbank für den Melde-Endpunkt (server/melden/).
#
# Absichtlich NICHT die Entwicklungsumgebung des Spiels: Godot läuft als Windows-Binary
# über tools/godot.sh und hat hier drin nichts zu suchen. Der Container existiert, damit
# der PHP-Teil geprüft werden kann, ohne PHP auf dem Rechner zu installieren.
#
# Dieselbe Fassung, die tools/report/php.sh für einen einzelnen Aufruf hochzieht — lokal
# und in der CI soll derselbe PHP-Stand rechnen.
FROM docker.io/library/php:8.3-cli-bookworm

# python3: die Gegenprobe des Token-Formats (tools/report/mint_token.py --self-test) muss
#          auch im Container laufen, sonst prüft man nur die eine Hälfte.
# jq:      reports.jsonl von Hand lesen.
# git:     damit der Container in VS Code brauchbar ist.
RUN apt-get update \
	&& apt-get install -y --no-install-recommends python3 jq git ca-certificates \
	&& rm -rf /var/lib/apt/lists/*

# Nicht-Root mit UID 1000 — dieselbe wie der WSL-Nutzer, damit im gebundenen Verzeichnis
# keine root-eigenen Dateien entstehen.
ARG USERNAME=dev
ARG USER_UID=1000
ARG USER_GID=1000
RUN groupadd --gid $USER_GID $USERNAME \
	&& useradd --uid $USER_UID --gid $USER_GID --create-home --shell /bin/bash $USERNAME

USER $USERNAME
WORKDIR /work
