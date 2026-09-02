#!/usr/bin/env bash
# Ruft Godot headless auf diesem Projekt auf und räumt hinterher auf, was der Editor
# dabei anrichtet.
#
# Warum es dieses Skript gibt: Godot merkt sich in .godot/editor/script_editor_cache.cfg,
# welche Dateien im Skripteditor offen sind, und lädt sie bei jedem Lauf mit — auch
# headless. Beim Speichern normalisiert er ihre Einrückung auf Tabs
# (text_editor/behavior/indent/type=0 plus dem Standard convert_indent_on_save=true).
# Für .gd ist das gewollt. Für alles andere nicht:
#
#   * in Markdown werden aus eingerückten Fortsetzungszeilen Codeblöcke,
#   * in Spieldaten-JSON ändern sich zehn Zeilen ohne inhaltlichen Grund,
#   * und betroffen ist auch data/language/README.md — also das private Submodule.
#
# Offen sind hier u.a. README.md, docs/*.md, data/skills/*.json, data/waves/*.json und
# data/bosses/*.json. Das ist keine hypothetische Liste: genau diese Dateien tauchten
# nach Godot-Läufen mehrfach unbestellt in `git status` auf.
#
# Das Skript merkt sich deshalb, was VOR dem Lauf schon geändert war, und setzt danach
# genau die Dateien zurück, die beides erfüllen: vorher sauber, und der Unterschied
# besteht ausschließlich aus führendem Leerraum. Alles andere bleibt unangetastet und
# wird gemeldet — eine echte Änderung darf dieses Skript niemals wegwerfen.
#
# Nutzung:
#   tools/godot.sh --import
#   tools/godot.sh --quit-after 60
#   tools/godot.sh -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://tests
#
# --headless und --path setzt das Skript selbst (inklusive der Windows-Schreibweise des
# Pfades, die Godot unter WSL braucht). Godot-Pfad per GODOT=... überschreibbar.
set -uo pipefail

cd "$(dirname "$0")/.."

GODOT="${GODOT:-/mnt/c/dev/_tools/godot/Godot_v4.7-stable_win64_console.exe}"
if [[ ! -x "$GODOT" ]]; then
	echo "FEHLER: Godot-Konsolen-Build nicht gefunden: $GODOT" >&2
	echo "        Der GUI-Build (.exe ohne _console) gibt nichts auf stdout aus." >&2
	exit 1
fi
WIN_PATH="${GODOT_WIN_PATH:-$(wslpath -m "$PWD" 2>/dev/null || echo "$PWD")}"

# Alle gegenüber HEAD geänderten, versionierten Pfade eines Repos (inkl. Submodul-Zeiger).
changed_in() { git -C "$1" diff --name-only HEAD 2>/dev/null; }

# Setzt in $1 die Dateien zurück, die vorher sauber waren ($2 = Liste) und sich nur in
# der Einrückung unterscheiden. Gibt zurück, was zurückgesetzt bzw. behalten wurde.
tidy_repo() {
	local repo="$1" before="$2" f n_rev=0
	while IFS= read -r f; do
		[[ -z "$f" ]] && continue
		grep -qxF -- "$f" <<<"$before" && continue      # war schon vorher geändert
		local full="$repo/$f"
		if [[ -d "$full" ]]; then                       # Submodul: dort separat aufräumen
			continue
		fi
		[[ -f "$full" ]] || continue                    # gelöscht/umbenannt: Finger weg
		# Nur-Einrückung? Beide Fassungen ohne führenden Leerraum vergleichen.
		if diff -q \
			<(git -C "$repo" show "HEAD:$f" 2>/dev/null | sed 's/^[[:space:]]*//') \
			<(sed 's/^[[:space:]]*//' "$full") >/dev/null 2>&1
		then
			git -C "$repo" checkout -- "$f" && { echo "   zurückgesetzt: $repo/$f"; n_rev=$((n_rev+1)); }
		else
			echo "   BEHALTEN (echte Änderung): $repo/$f"
		fi
	done < <(changed_in "$repo")
	return $n_rev
}

before_main="$(changed_in .)"
before_sub=""
[[ -d data/language/.git || -f data/language/.git ]] && before_sub="$(changed_in data/language)"

"$GODOT" --headless --path "$WIN_PATH" "$@" 2>&1 | tr -d '\r'
rc=${PIPESTATUS[0]}

echo ">> Nacharbeit: Einrückungsschäden des Editors zurücknehmen"
tidy_repo "." "$before_main"
if [[ -n "$before_sub" || -d data/language/.git || -f data/language/.git ]]; then
	tidy_repo "data/language" "$before_sub"
fi

exit "$rc"
