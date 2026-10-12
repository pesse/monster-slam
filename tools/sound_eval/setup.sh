#!/usr/bin/env bash
# Richtet sound-eval unter WSL/Linux ein: uv (user-lokal), Python 3.12, PyTorch (CUDA oder CPU),
# CLAP-Abhängigkeiten; lädt das Modell und prüft alles mit `sound-eval doctor --smoke`.
#   tools/sound_eval/setup.sh            # GPU, wenn nvidia-smi eine findet, sonst CPU
#   tools/sound_eval/setup.sh --cpu      # CPU erzwingen
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH="$HOME/.local/bin:$PATH"
export UV_PROJECT_ENVIRONMENT="${UV_PROJECT_ENVIRONMENT:-$HOME/.cache/sound-eval/venv}"

if ! command -v uv >/dev/null; then
  echo "uv fehlt – installiere nach ~/.local/bin (nur für diesen Benutzer) …"
  curl -LsSf https://astral.sh/uv/install.sh | sh
fi

variant=cpu
if [[ "${1:-}" != "--cpu" ]] && command -v nvidia-smi >/dev/null && nvidia-smi -L >/dev/null 2>&1; then
  variant=cu128  # CUDA 12.8: nötig für RTX 50xx (sm_120), läuft auch auf älteren Karten ab Turing
  echo "GPU gefunden: $(nvidia-smi -L | head -1)"
fi
echo "PyTorch-Variante: $variant, venv: $UV_PROJECT_ENVIRONMENT"
uv sync --project "$here" --extra "$variant" --extra dev
"$here/sound-eval" doctor --smoke
