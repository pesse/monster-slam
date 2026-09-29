extends GdUnitTestSuite
## Welche task_definitions in den Wave-Pool kommen.
##
## Die Wellen-Schwierigkeit filtert keine Aufgabenarten mehr. Früher nahm ein Riegel
## (`difficulty_max`) auf niedrigen Stufen alles heraus, dessen `difficulty` darüber lag:
## erst die Richtung en→de (kein Wort war mehr zu meistern), später bei Latein die
## Formaufgaben — beides, ohne dass der Spieler es sehen konnte. Es filtern nur die
## Auswahl des Expertenmodus (`task_types`) und eine ausdrückliche `direction`.
##
## Geprüft wird an der statischen Regel (WaveGenerator.definition_allowed) und danach am
## ausgelieferten Kandidatensatz — die Regel allein sagt nichts, wenn die Daten sie
## umgehen.

const GENERATOR := preload("res://src/battle/wave_generator.gd")

const DEF_DE_EN := {"task_type": "translate", "direction": "de_to_en", "difficulty": 1}
const DEF_EN_DE := {"task_type": "translate", "direction": "en_to_de", "difficulty": 2}
const DEF_CONJ := {"task_type": "conjugation", "direction": "en", "difficulty": 3}


# --- Die Regel für sich -------------------------------------------------------

## Ohne Auswahl kommt jede Definition in den Pool, gleich welche `difficulty` sie trägt.
func test_every_definition_is_allowed_without_a_selection() -> void:
	for definition in [DEF_DE_EN, DEF_EN_DE, DEF_CONJ]:
		assert_bool(GENERATOR.definition_allowed(definition, [], "")) \
			.override_failure_message("%s fehlt im Pool" % definition["task_type"]).is_true()


## Die Aufgabentyp-Auswahl aus dem Session-Setup bleibt eine Auswahl.
func test_the_task_type_selection_filters() -> void:
	assert_bool(GENERATOR.definition_allowed(DEF_DE_EN, ["conjugation"], "")).is_false()
	assert_bool(GENERATOR.definition_allowed(DEF_DE_EN, ["translate"], "")).is_true()
	assert_bool(GENERATOR.definition_allowed(DEF_CONJ, ["conjugation"], "")).is_true()


func test_an_explicit_direction_still_filters() -> void:
	assert_bool(GENERATOR.definition_allowed(DEF_EN_DE, [], "de_to_en")).is_false()
	assert_bool(GENERATOR.definition_allowed(DEF_EN_DE, [], "en_to_de")).is_true()


# --- Die ausgelieferten Daten -------------------------------------------------

## Der echte Kandidatensatz einer Unit enthält beide Übersetzungsrichtungen. Ohne
## Sprachdaten gibt es keine Lexeme, über die sich eine Definition auffächern ließe
## (LanguageData).
func test_both_directions_are_in_the_pool(
		do_skip := LanguageData.missing(), skip_reason := LanguageData.REASON) -> void:
	var generator := WaveGenerator.new()
	var scope := _first_unit_scope()
	assert_array(scope).override_failure_message("Kein Buch mit Unit im Katalog").is_not_empty()
	var directions := {}
	for candidate in generator._candidates({"scope": scope}):
		var definition: Dictionary = candidate["definition"]
		if str(definition.get("task_type", "")) == "translate":
			directions[str(definition.get("direction", ""))] = true
	for direction in Lexeme.mastery_directions("en"):
		assert_bool(directions.has(direction)) \
			.override_failure_message("Richtung %s fehlt im Pool" % direction).is_true()


## Die erste Unit des ersten Buchs als Scope — unabhängig davon, welche Bücher gerade
## installiert sind.
func _first_unit_scope() -> Array:
	for book in ContentRegistry.all_books():
		for unit in ContentRegistry.units_for(book):
			return ["%s/%d" % [book, int(unit)]]
	return []
