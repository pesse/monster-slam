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


## Innerhalb einer Unit muss ein deutsches Lemma eindeutig sein.
##
## Der de→en-Prompt zeigt NUR das deutsche Lemma (TaskResolver._resolve_translate),
## akzeptiert aber ausschließlich das englische Wort SEINES Lexems. Teilen sich zwei
## Lexeme derselben Unit den Prompt, ist die Aufgabe geraten — und weil ein WORT erst in
## BEIDEN Richtungen als gemeistert gilt (PlayerProgress.LEXEME_MASTERY_DIRECTIONS),
## bleibt der Fortschrittsbalken der Unit stehen, obwohl der Spieler alles kann. Die
## Gegenrichtung hat das Problem nicht: der englische Prompt nennt ein Wort.
##
## Aufgelöst wird das mit einer Glosse in Klammern — „der Hals (Rachen)" neben
## „der Hals (vorne)" —, NICHT mit einem zusätzlichen lemma_en_alt oder einer
## Synonym-Relation: die Unit gibt EINE Übersetzung vor, und die soll sie auch verlangen.
##
## Gemessen wird am Schnitt der VOLLSTÄNDIGEN Varianten des AnswerEvaluator, nicht an
## einer eigenen Normalisierung daneben. Das ist genau der Unterschied, den der Spieler
## sieht: „der Hals (Rachen)" und „der Hals" passen weiterhin aufeinander (unvollständig,
## damit die kurze en→de-Antwort gültig bleibt), „der Hals (Rachen)" und
## „der Hals (vorne)" teilen aber keine vollständige Schreibweise mehr.
func test_no_two_lexemes_of_a_unit_share_a_german_prompt() -> void:
	var violations := _prompt_collisions()
	assert_array(violations).override_failure_message(
		"Mehrdeutige deutsche Prompts innerhalb einer Unit — Glosse in Klammern ergänzen. "
		+ "lemma_en_alt nur, wo das BUCH die beiden gleichsetzt:\n  - %s" % "\n  - ".join(violations)
	).is_empty()


## Kollidierende Prompts derselben Unit als lesbare Zeilen.
##
## Über Unit-Grenzen hinweg wird NICHT geprüft: dort kollidieren zwei Prompts nur, wenn
## beide Units zugleich im Scope stehen, und das Buch darf in einer späteren Unit eine
## andere Übersetzung desselben deutschen Worts vorgeben.
##
## Lexeme ohne Buch/Unit bleiben außen vor: sie gehören zu keiner Unit, tragen also auch
## keinen Balken, und ihre Qualität ist eine eigene Frage. Ebenso Lexeme, die gar keine
## Übersetzungsaufgabe stellen (`excluded_task_types`) — sie zeigen den Prompt nie.
func _prompt_collisions() -> Array[String]:
	var evaluator := AnswerEvaluator.new()
	# Vollständige Variante des deutschen Prompts -> Einträge, die sie tragen.
	var by_prompt := {}
	for entry in _book_lexemes():
		if "translate" in entry.get("excluded_task_types", []):
			continue
		for form in _complete_variants(evaluator, str(entry.get("lemma_de", ""))):
			if not by_prompt.has(form):
				by_prompt[form] = []
			(by_prompt[form] as Array).append(entry)

	var seen := {}
	var violations: Array[String] = []
	for form in by_prompt:
		var group: Array = by_prompt[form]
		for i in range(group.size()):
			for j in range(i + 1, group.size()):
				var a: Dictionary = group[i]
				var b: Dictionary = group[j]
				if _unit_of(a) != _unit_of(b):
					continue
				# Gibt es EINE Antwort, die beide gelten lassen, ist der Prompt nicht
				# mehrdeutig, sondern die Aufgabe bleibt lösbar — eine Dublette, oder ein
				# Paar, das das Buch selbst gleichsetzt (dann steht es in lemma_en_alt).
				if _answers_overlap(evaluator, a, b):
					continue
				var key := "%s|%s" % [a.get("id", "?"), b.get("id", "?")]
				if seen.has(key):
					continue
				seen[key] = true
				violations.append('%s: "%s" -> %s / %s' % [_unit_of(a),
						a.get("lemma_de", ""), a.get("lemma_en", ""), b.get("lemma_en", "")])
	violations.sort()
	return violations


## Die Schreibweisen eines Lemmas, bei denen nichts weggelassen wurde (AnswerEvaluator
## .variants). Eine weggelassene Klammergruppe zählt NICHT — sonst hebt jede Glosse die
## Unterscheidung wieder auf, die sie gerade eingeführt hat.
func _complete_variants(evaluator: AnswerEvaluator, lemma: String) -> Array[String]:
	var result: Array[String] = []
	var forms := evaluator.variants(lemma)
	for form in forms:
		if bool(forms[form]):
			result.append(str(form))
	return result


## Gibt es eine Antwort, die BEIDE Lexeme vollständig gelten lassen? Gefragt wird über die
## akzeptierten Antworten (lemma_en + lemma_en_alt), also über das, was der TaskResolver
## der de→en-Aufgabe mitgibt — nicht nur über das primäre Lemma.
func _answers_overlap(evaluator: AnswerEvaluator, a: Dictionary, b: Dictionary) -> bool:
	var answers_b := _english_answers(b)
	for answer in _english_answers(a):
		if bool(evaluator.evaluate(answers_b, answer)["complete"]):
			return true
	return false


func _english_answers(entry: Dictionary) -> Array:
	var out: Array = [str(entry.get("lemma_en", ""))]
	out.append_array(entry.get("lemma_en_alt", []))
	return out


func _unit_of(entry: Dictionary) -> String:
	return "%s/%d" % [entry.get("book", "?"), int(entry.get("unit", 0))]


## Alle Lexeme MIT Buch und Unit, über alle Dateien.
func _book_lexemes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for path in _json_files(LEXEME_DIR):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		var entries: Array = parsed if parsed is Array else [parsed]
		for entry in entries:
			if entry is Dictionary and not str(entry.get("book", "")).is_empty() \
					and entry.has("unit"):
				result.append(entry)
	return result


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
