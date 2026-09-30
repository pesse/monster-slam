class_name ReleaseNotes
extends RefCounted
## Setzt aus dem Update-Manifest die Notes zusammen, die der Dialog zeigt: alle Releases,
## die neuer sind als die installierte Fassung, neuester zuerst.
##
## `history` trägt die Releases der letzten 7 Tage, mindestens 3
## (tools/release/release_history.sh). Liegt die installierte Fassung weiter zurück, fehlt
## der Rest — das sagt ein Verweis auf die Release-Seite, statt still zu kürzen. Ein
## Manifest ohne `history` (bis 0.18.0 erzeugt) liefert nur `notes`.

const RELEASES_URL := "https://github.com/pesse/monster-slam/releases"


static func compose(manifest: Dictionary, installed: String) -> String:
	var fallback := str(manifest.get("notes", ""))
	var history: Variant = manifest.get("history", [])
	if not history is Array or (history as Array).is_empty():
		return fallback

	var missed: Array[Dictionary] = []
	for entry in history:
		if entry is Dictionary and SemVer.is_newer(str(entry.get("version", "")), installed):
			missed.append(entry)
	if missed.is_empty():
		return fallback
	missed.sort_custom(func(a, b): return SemVer.compare(str(a["version"]), str(b["version"])) > 0)

	# Eine einzige Fassung braucht keine Versionsüberschrift, die steht schon im Titel.
	if missed.size() == 1 and not _truncated(history, installed):
		return str(missed[0].get("notes", ""))

	var parts: PackedStringArray = []
	for entry in missed:
		parts.append("## Version %s\n\n%s" % [entry["version"], str(entry.get("notes", "")).strip_edges()])
	if _truncated(history, installed):
		parts.append("Ältere Änderungen stehen auf der [Release-Seite](%s)." % RELEASES_URL)
	return "\n\n".join(parts)


## True, wenn zwischen installierter Fassung und ältestem Eintrag Releases fehlen könnten.
## Ohne bekannte installierte Fassung (Editor ohne config/version) gibt es keinen Hinweis.
static func _truncated(history: Array, installed: String) -> bool:
	if installed.is_empty():
		return false
	var oldest := ""
	for entry in history:
		var v := str((entry as Dictionary).get("version", "")) if entry is Dictionary else ""
		if not v.is_empty() and (oldest.is_empty() or SemVer.compare(v, oldest) < 0):
			oldest = v
	return SemVer.is_newer(oldest, installed)
