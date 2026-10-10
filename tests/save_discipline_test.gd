extends GdUnitTestSuite
## Den Spielstand schreibt nur SaveStore (ADR 0024). Ein `FileAccess.WRITE` leert die Datei
## vor dem Schreiben — so ging der Spielstand verloren, der zu diesem ADR führte.
##
## Wer neu direkt schreibt, trägt die Datei hier ein und sagt im Kommentar, warum es kein
## Spielstand ist.

const ALLOWED := {
	"res://src/core/save_store.gd": "der eine Schreibweg",
	"res://src/core/backups.gd": "Kopien in einen neuen Sicherungsordner, Manifest zuletzt",
	"res://src/core/lexeme_flags.gd": "Meldungen, kein Spielstand",
	"res://src/content/content_service.gd": "heruntergeladene Packs",
	"res://src/content/model_service.gd": "heruntergeladene Modelle",
	"res://src/content/pack_installer.gd": "entpackte Packs",
	"res://src/learning/trace_log.gd": "Spur, wird nur angehängt",
	"res://src/progression/skill_layout.gd": "Werkbank, schreibt nach res://",
	"res://src/ui/map_layout.gd": "Werkbank, schreibt nach res://",
}
const WRITES := ["FileAccess.WRITE", "FileAccess.READ_WRITE", "FileAccess.WRITE_READ"]


func test_only_known_files_write_directly() -> void:
	var offenders: Array = []
	for path in _scripts("res://src"):
		if path.begins_with("res://src/dev/") or ALLOWED.has(path):
			continue
		var text := FileAccess.get_file_as_string(path)
		for needle: String in WRITES:
			if text.contains(needle):
				offenders.append(path)
				break
	assert_array(offenders).is_empty()


func _scripts(dir: String) -> Array:
	var out: Array = []
	for name in DirAccess.get_files_at(dir):
		if name.ends_with(".gd"):
			out.append(dir.path_join(name))
	for sub in DirAccess.get_directories_at(dir):
		out.append_array(_scripts(dir.path_join(sub)))
	return out
