extends GdUnitTestSuite
## Datenvalidierung der Lexeme.
##
## Lemmata dürfen keine " / "-getrennten Inline-Varianten enthalten (z. B.
## "jeder / jede / jedes"). Solche Strings werden bei der Antwort-Auswertung als EIN
## wörtlicher String behandelt und sind praktisch unlösbar. Mehrfachformen gehören in
## die strukturierten Arrays lemma_de_alt / lemma_en_alt (siehe docs/TESTING.md).

const LEXEME_DIR := "res://data/language/lexemes"
const VARIANT_SEP := " / "


func test_lexemes_have_no_inline_slash_variants() -> void:
	var violations: Array[String] = []
	for path in _json_files(LEXEME_DIR):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		assert_that(parsed).override_failure_message("Ungültiges JSON: %s" % path).is_not_null()
		var entries: Array = parsed if parsed is Array else [parsed]
		for entry in entries:
			if entry is Dictionary:
				_collect_violations(entry, violations)

	assert_array(violations).override_failure_message(
		"Inline-' / '-Varianten gefunden (bitte lemma_*_alt-Arrays nutzen):\n  - %s"
			% "\n  - ".join(violations)
	).is_empty()


func _collect_violations(entry: Dictionary, violations: Array[String]) -> void:
	var id := str(entry.get("id", "?"))
	for field in ["lemma_de", "lemma_en"]:
		if entry.has(field) and VARIANT_SEP in str(entry[field]):
			violations.append('%s: %s = "%s"' % [id, field, entry[field]])
	for field in ["lemma_de_alt", "lemma_en_alt"]:
		for value in entry.get(field, []):
			if VARIANT_SEP in str(value):
				violations.append('%s: %s enthält "%s"' % [id, field, value])


func _json_files(dir_path: String) -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return result
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		var full := "%s/%s" % [dir_path, file_name]
		if dir.current_is_dir():
			result.append_array(_json_files(full))
		elif file_name.ends_with(".json"):
			result.append(full)
		file_name = dir.get_next()
	dir.list_dir_end()
	return result
