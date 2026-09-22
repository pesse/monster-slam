extends GdUnitTestSuite
## Der Schwierigkeitsriegel darf keine Lernrichtung aus dem Pool nehmen.
##
## `difficulty_max` (die gewählte Wellenschwierigkeit) filtert die task_definitions über
## ihre Grundschwierigkeit. `def.translate.en_de` hat difficulty 2 und fiel damit auf
## Stufe 1 komplett heraus — und weil ein WORT erst als gemeistert gilt, wenn BEIDE
## Übersetzungsrichtungen sitzen (PlayerProgress.LEXEME_MASTERY_DIRECTIONS), stand der
## Fortschrittsbalken jeder Unit dort dauerhaft auf „0 von N". Die Statistik rechnete
## richtig; die Richtung kam nie an.
##
## Geprüft wird an der statischen Regel (WaveGenerator.definition_allowed) und danach am
## ausgelieferten Kandidatensatz — die Regel allein sagt nichts, wenn die Daten sie
## umgehen.

const GENERATOR := preload("res://src/battle/wave_generator.gd")

## Die beiden Übersetzungs-Definitionen, wie sie in data/task_definitions liegen.
const DEF_DE_EN := {"task_type": "translate", "direction": "de_to_en", "difficulty": 1}
const DEF_EN_DE := {"task_type": "translate", "direction": "en_to_de", "difficulty": 2}
const DEF_CONJ := {"task_type": "conjugation", "direction": "en", "difficulty": 3}


# --- Die Regel für sich -------------------------------------------------------

## Der Kern des Fehlers: auf Stufe 1 muss en→de trotz difficulty 2 im Pool bleiben.
func test_the_difficulty_gate_never_drops_a_translation_direction() -> void:
	for level in range(1, 6):
		assert_bool(GENERATOR.definition_allowed(DEF_DE_EN, [], "", level)) \
			.override_failure_message("de→en fehlt auf Stufe %d" % level).is_true()
		assert_bool(GENERATOR.definition_allowed(DEF_EN_DE, [], "", level)) \
			.override_failure_message("en→de fehlt auf Stufe %d" % level).is_true()


## Für alles andere staffelt der Riegel weiter — das ist sein Zweck.
func test_the_difficulty_gate_still_holds_back_the_extra_tasks() -> void:
	assert_bool(GENERATOR.definition_allowed(DEF_CONJ, [], "", 2)).is_false()
	assert_bool(GENERATOR.definition_allowed(DEF_CONJ, [], "", 3)).is_true()
	# 0 heißt „kein Limit".
	assert_bool(GENERATOR.definition_allowed(DEF_CONJ, [], "", 0)).is_true()


## Die Aufgabentyp-Auswahl aus dem Session-Setup bleibt eine Auswahl: wer „translate"
## abwählt, bekommt keine Übersetzung — auch nicht über CORE_TASK_TYPES.
func test_the_task_type_selection_still_wins_over_the_core_types() -> void:
	assert_bool(GENERATOR.definition_allowed(DEF_DE_EN, ["conjugation"], "", 0)).is_false()
	assert_bool(GENERATOR.definition_allowed(DEF_DE_EN, ["translate"], "", 0)).is_true()


func test_an_explicit_direction_still_filters() -> void:
	assert_bool(GENERATOR.definition_allowed(DEF_EN_DE, [], "de_to_en", 0)).is_false()
	assert_bool(GENERATOR.definition_allowed(DEF_EN_DE, [], "en_to_de", 0)).is_true()


# --- Die ausgelieferten Daten -------------------------------------------------

## Dieselbe Aussage über den echten Kandidatensatz: auf JEDER Stufe kommen beide
## Richtungen aus dem Pool. Ohne Sprachdaten gibt es keine Lexeme, über die sich eine
## Definition auffächern ließe (LanguageData).
func test_both_directions_are_in_the_pool_on_every_difficulty(
		do_skip := LanguageData.missing(), skip_reason := LanguageData.REASON) -> void:
	var generator := WaveGenerator.new()
	var scope := _first_unit_scope()
	assert_array(scope).override_failure_message("Kein Buch mit Unit im Katalog").is_not_empty()
	for level in range(1, 6):
		var directions := {}
		for candidate in generator._candidates({"scope": scope, "difficulty_max": level}):
			var definition: Dictionary = candidate["definition"]
			if str(definition.get("task_type", "")) == "translate":
				directions[str(definition.get("direction", ""))] = true
		for direction in PlayerProgress.LEXEME_MASTERY_DIRECTIONS:
			assert_bool(directions.has(direction)) \
				.override_failure_message("Richtung %s fehlt auf Stufe %d" % [direction, level]) \
				.is_true()


## Die erste Unit des ersten Buchs als Scope — klein genug für fünf Durchläufe und
## unabhängig davon, welche Bücher gerade installiert sind.
func _first_unit_scope() -> Array:
	for book in ContentRegistry.all_books():
		for unit in ContentRegistry.units_for(book):
			return ["%s/%d" % [book, int(unit)]]
	return []
