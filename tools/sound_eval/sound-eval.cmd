@echo off
rem Startet sound-eval unter Windows (venv in tools\sound_eval\.venv, angelegt von setup.ps1).
set "PATH=%USERPROFILE%\.local\bin;%PATH%"
uv run --quiet --no-sync --project "%~dp0." sound-eval %*
