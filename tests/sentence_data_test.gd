extends GdUnitTestSuite
## Die ausgelieferten SÄTZE selbst — nicht die Regeln (die prüfen
## tests/sentence_card_test.gd und tests/sentence_selector_test.gd an erfundenen Sätzen),
## sondern der Lösungsschlüssel in den Daten.
##
## ADR 0004 verlangt diese Prüfungen, BEVOR der erste Satz ausgeliefert wird — aus dem
## Grund, aus dem tests/skill_data_test.gd unbekannte Effektschlüssel abfängt: ein Fehler
## im Schlüssel kostet keine Fehlermeldung. Er kostet eine falsche Rückmeldung an ein
## Kind, und die teuerste davon ist der Tadel für eine richtige Antwort.
##
## Gelesen wird DIREKT aus dem Submodule (`LanguageData.entries`) und NICHT über die
## ContentRegistry: die lässt einen installierten Pack bei gleicher Id gewinnen, und ein
## liegengebliebener Pack in `user://content` verdeckte damit genau die Dateien, die hier
## committet werden. Diese Suite prüft, was ausgeliefert werden SOLL. Ohne ausgecheckten
## Submodule wird sie sichtbar übersprungen statt still grün (siehe LanguageData).

var _sentences: Array = []
var _lexemes: Dictionary = {}
## lexeme_id -> Array der bekannten Schreibweisen (Lemma, Alternativen, lexeme_forms).
var _forms: Dictionary = {}
var _evaluator := AnswerEvaluator.new()


func before_test() -> void:
	if LanguageData.missing():
		return
	_sentences = LanguageData.entries("sentences")
	_lexemes = {}
	_forms = {}
	for lexeme in LanguageData.entries("lexemes"):
		var id := str((lexeme as Dictionary).get("id", ""))
		_lexemes[id] = lexeme
		var known: Array = []
		for candidate in [lexeme.get("lemma_en", "")] + Array(lexeme.get("lemma_en_alt", [])):
			if not str(candidate).strip_edges().is_empty():
				known.append(str(candidate))
		_forms[id] = known
	for form in LanguageData.entries("lexeme_forms"):
		var lexeme_id := str((form as Dictionary).get("lexeme_id", ""))
		if _forms.has(lexeme_id):
			(_forms[lexeme_id] as Array).append(str((form as Dictionary).get("value", "")))


## Die eine Regel, um derentwillen das ADR den Lösungsschlüssel in die Daten legt: keine
## Stolperstelle darf auf eine akzeptierte Lösung passen. Sonst steht irgendwann ein Satz
## im Pack, der eine richtige Antwort tadelt.
func test_no_pitfall_matches_an_accepted_solution(
		do_skip := LanguageData.missing(), skip_reason := LanguageData.REASON) -> void:
	for sentence in _sentences:
		for solution in SentenceCard.solutions(sentence):
			var trap := SentenceCard.pitfall_for(
					sentence, _evaluator.tokens(str(solution)), _evaluator)
			assert_bool(trap.is_empty()).override_failure_message(
					"'%s': die Stolperstelle %s passt auf die richtige Lösung „%s“"
					% [sentence.get("id", "?"), trap.get("contains", []), solution]
			).is_true()


## Ein must_contain-Lexem, das es nicht gibt, fordert ein Wort, das niemand kennt — der
## Satz wäre dann nie zu lösen.
func test_every_required_lexeme_is_in_the_stock(
		do_skip := LanguageData.missing(), skip_reason := LanguageData.REASON) -> void:
	for sentence in _sentences:
		for required in sentence.get("must_contain", []):
			var lexeme_id := str((required as Dictionary).get("lexeme_id", ""))
			assert_bool(_lexemes.has(lexeme_id)).override_failure_message(
					"'%s' fordert das unbekannte Lexem '%s'"
					% [sentence.get("id", "?"), lexeme_id]).is_true()


## Die hinterlegten Formen müssen zum Bestand passen (Lemma, Alternativen, lexeme_forms).
## Eine erfundene Form fiele nicht auf: sie stünde nur nie in einer Antwort, und der Satz
## gölte als ungelöst. Fehlt eine Form wirklich, gehört sie in `lexeme_forms` — dorthin,
## wo auch die Vokabelaufgaben sie finden, und nicht als Sonderfall in den Satz.
func test_every_required_form_is_a_form_of_that_lexeme(
		do_skip := LanguageData.missing(), skip_reason := LanguageData.REASON) -> void:
	for sentence in _sentences:
		for required in sentence.get("must_contain", []):
			var lexeme_id := str((required as Dictionary).get("lexeme_id", ""))
			var known: Array = _forms.get(lexeme_id, [])
			for form in Array((required as Dictionary).get("forms", [])):
				assert_bool(_evaluator.evaluate_answers(known, str(form))
				).override_failure_message(
						"'%s': „%s“ ist keine Form von '%s' (bekannt: %s)"
						% [sentence.get("id", "?"), form, lexeme_id, known]).is_true()


## Die Kehrseite der ersten Regel: eine akzeptierte Lösung, die das geforderte Wort nicht
## enthält, würde von der Prüfkarte zwar als Treffer durchgehen — aber sobald jemand sie
## umformuliert, tadelte die Karte etwas, das die Daten selbst für richtig erklären.
func test_every_accepted_solution_contains_the_required_words(
		do_skip := LanguageData.missing(), skip_reason := LanguageData.REASON) -> void:
	for sentence in _sentences:
		if Array(sentence.get("must_contain", [])).is_empty():
			continue
		for solution in SentenceCard.solutions(sentence):
			var missing := SentenceCard.missing_words(
					sentence, _evaluator.tokens(str(solution)), _evaluator)
			assert_array(missing).override_failure_message(
					"'%s': in der richtigen Lösung „%s“ fehlt %s"
					% [sentence.get("id", "?"), solution, missing]).is_empty()


## Ein Schlüssel ohne Musterlösung hätte nichts, woran er hängt.
func test_every_sentence_has_a_reference_translation(
		do_skip := LanguageData.missing(), skip_reason := LanguageData.REASON) -> void:
	for sentence in _sentences:
		assert_str(str(sentence.get("reference_translation", ""))).override_failure_message(
				"'%s' hat keine Musterlösung" % sentence.get("id", "?")).is_not_empty()


## Eine Stolperstelle ohne Bestandteile passt nie, eine ohne Rückmeldung sagt nichts —
## beides ist ein Eintrag, der aussieht, als täte er etwas.
func test_every_pitfall_has_parts_and_something_to_say(
		do_skip := LanguageData.missing(), skip_reason := LanguageData.REASON) -> void:
	for sentence in _sentences:
		for trap in sentence.get("pitfalls", []):
			var id := str(sentence.get("id", "?"))
			assert_array(Array((trap as Dictionary).get("contains", []))
			).override_failure_message("'%s' hat eine Stolperstelle ohne Bestandteile" % id
			).is_not_empty()
			assert_str(str((trap as Dictionary).get("feedback", ""))
			).override_failure_message("'%s' hat eine Stolperstelle ohne Rückmeldung" % id
			).is_not_empty()


## Nur Tags aus dem Katalog. Ein Tag, den GrammarRules nicht kennt, bekommt keine Regel,
## und der Golem zieht nur, was er beim Namen kennt — Schreibvarianten wie früher
## (`simple_past` neben `past_simple`) fielen still durch beide Raster.
func test_every_grammar_tag_is_in_the_catalog(
		do_skip := LanguageData.missing(), skip_reason := LanguageData.REASON) -> void:
	for sentence in _sentences:
		for tag in sentence.get("grammar_tags", []):
			assert_bool(GrammarRules.RULES.has(str(tag))).override_failure_message(
					"'%s' trägt den Tag '%s', den GrammarRules.RULES nicht kennt"
					% [sentence.get("id", "?"), tag]).is_true()


## Tag, deutscher Satz und Musterlösung tragen dieselbe Form (prompt-eval, Befund
## „war geschlossen“ vom 25.09.2026): ein Past Perfect ohne „hatte“/„war“ im Deutschen oder
## ohne „had“ in der Musterlösung behauptet eine Form, die der Satz nicht hat — und das
## Modell erklärt dann einen Fehler, den es nicht gibt. Grob, aber es fängt genau diesen Fall.
func test_a_past_perfect_is_one_in_both_languages(
		do_skip := LanguageData.missing(), skip_reason := LanguageData.REASON) -> void:
	var german := RegEx.create_from_string("\\b(hatte|hattest|hatten|hattet|war|warst|waren|wart)\\b")
	for sentence in _sentences:
		if not ("past_perfect" in Array(sentence.get("grammar_tags", []))):
			continue
		var id := str(sentence.get("id", "?"))
		assert_object(german.search(str(sentence.get("source_text", "")).to_lower())
		).override_failure_message("'%s': past_perfect ohne „hatte“/„war“ im Deutschen" % id
		).is_not_null()
		assert_bool("had" in _evaluator.tokens(str(sentence.get("reference_translation", "")))
		).override_failure_message("'%s': past_perfect ohne „had“ in der Musterlösung" % id
		).is_true()


## Dasselbe fürs Passiv: der deutsche Satz steht im Vorgangspassiv mit „werden“, sonst
## verlangt die Musterlösung ein Passiv, das der Satz nicht fordert.
func test_a_passive_is_one_in_german(
		do_skip := LanguageData.missing(), skip_reason := LanguageData.REASON) -> void:
	var german := RegEx.create_from_string("\\b(wird|wirst|werden|wurde|wurden|wurdest|worden)\\b")
	for sentence in _sentences:
		if not ("passive" in Array(sentence.get("grammar_tags", []))):
			continue
		assert_object(german.search(str(sentence.get("source_text", "")).to_lower())
		).override_failure_message("'%s': passive ohne „werden“ im Deutschen"
				% sentence.get("id", "?")).is_not_null()


## Und der Satz, um dessentwillen diese Suite überhaupt läuft. Alle Prüfungen oben laufen
## über eine Liste — eine leere Liste macht jede davon still grün. Also steht hier, dass
## die Liste nicht leer ist UND dass darin Sätze mit Schlüssel stehen.
func test_the_stock_carries_keyed_sentences(
		do_skip := LanguageData.missing(), skip_reason := LanguageData.REASON) -> void:
	assert_array(_sentences).override_failure_message(
			"Keine Sätze unter res://data/language/sentences — es wurde nichts geprüft."
	).is_not_empty()
	var keyed := _sentences.filter(func(s):
		return not Array((s as Dictionary).get("accepted", [])).is_empty())
	assert_int(keyed.size()).override_failure_message(
			"%d Sätze, aber keiner mit `accepted` — der Lösungsschlüssel aus ADR 0004 ist "
			% _sentences.size() + "nirgends angekommen."
	).is_greater(0)
