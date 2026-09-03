extends GdUnitTestSuite
## Datenvalidierung der Lexeme.
##
## Lemmata dürfen keine " / "-getrennten Inline-Varianten enthalten (z. B.
## "jeder / jede / jedes"). Solche Strings werden bei der Antwort-Auswertung als EIN
## wörtlicher String behandelt und sind praktisch unlösbar. Mehrfachformen gehören in
## die strukturierten Arrays lemma_de_alt / lemma_en_alt (siehe docs/TESTING.md).

const LEXEME_DIR := "res://data/language/lexemes"


## Ohne Sprachdaten gibt es nichts zu validieren — die Suite entfällt dann (LanguageData).
## Als Suite, nicht je Test: bei einer Suite, deren einziger Test übersprungen wird, lässt
## gdUnit einen Orphan-Node zurück und der Lauf endet mit Exit-Code 101 (Warnung).
func before(do_skip := LanguageData.missing(), skip_reason := LanguageData.REASON) -> void:
	pass
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


## Klammern und Grammatik-Platzhalter ("criticize sb. (for)") macht der AnswerEvaluator
## optional. Damit das über den ganzen Bestand trägt, muss für jedes Lemma gelten:
## es passt vollständig auf sich selbst (sonst stimmt an der Notation etwas nicht, z. B.
## unbalancierte Klammern), und eine leere Eingabe passt NICHT (sonst wäre das Lemma
## nichts als Notation und würde beim Weglassen zu "" schrumpfen).
func test_lemmas_survive_the_optional_part_expansion() -> void:
	var evaluator := AnswerEvaluator.new()
	var violations: Array[String] = []
	for path in _json_files(LEXEME_DIR):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		var entries: Array = parsed if parsed is Array else [parsed]
		for entry in entries:
			if not (entry is Dictionary):
				continue
			var id := str(entry.get("id", "?"))
			for lemma in _all_lemmas(entry):
				var verdict := evaluator.evaluate([lemma], lemma)
				if not bool(verdict["complete"]):
					violations.append('%s: "%s" passt nicht vollständig auf sich selbst' % [id, lemma])
				if evaluator.evaluate_answers([lemma], ""):
					violations.append('%s: "%s" schrumpft auf eine leere Antwort' % [id, lemma])

	assert_array(violations).override_failure_message(
		"Lemmata mit unauswertbarer Notation:\n  - %s" % "\n  - ".join(violations)
	).is_empty()


func _all_lemmas(entry: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for field in ["lemma_de", "lemma_en"]:
		if entry.has(field):
			result.append(str(entry[field]))
	for field in ["lemma_de_alt", "lemma_en_alt"]:
		for value in entry.get(field, []):
			result.append(str(value))
	return result


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
