extends GdUnitTestSuite
## Ein Wort, das im Buch keinen eigenen Eintrag hat, stellt keine Übersetzungsaufgabe.
##
## `excluded_task_types` am Lexem nimmt einzelne Aufgabenarten heraus. Der Fall, für den
## es da ist: zwei Lexeme einer Unit teilen sich den deutschen Prompt, und das BUCH bietet
## keine Unterscheidung an (das eine steht nur im Wortfamilien-Kasten des anderen). Eine
## Glosse wäre erfunden, ein `lemma_en_alt` würde die Unit-Vorgabe aufweichen — also
## bleibt das Wort im Bestand (en→de-Lesen, Relationen), stellt aber keine Ratefrage.
##
## Das trifft ZWEI Stellen, und beide müssen es tun: der Wave-Pool darf die Aufgabe nicht
## spawnen, und der Fortschrittsbalken darf das Wort nicht in seinen Nenner nehmen — sonst
## stünde die Unit dauerhaft auf „N-1 von N", genau der stehende Balken, gegen den es die
## Regel gibt.

const PROGRESS := preload("res://src/learning/player_progress.gd")


static func _lexeme(id: String, excluded: Array = []) -> Dictionary:
	var entry := {"id": id, "lemma_en": id, "lemma_de": id.to_upper(), "type": "noun",
			"book": "access9", "unit": 1, "tags": []}
	if not excluded.is_empty():
		entry["excluded_task_types"] = excluded
	return entry


## Die eine Stelle, die sagt, welche Aufgaben es zu einem Wort gibt: ohne das Feld beide
## Richtungen, mit dem Feld keine.
func test_the_excluded_task_type_produces_no_learnable() -> void:
	var gen := WaveGenerator.new()
	var plain := gen.learnables_of(_lexeme("a"))
	assert_array(plain).contains(["translate:de_to_en:a", "translate:en_to_de:a"])

	var excluded := gen.learnables_of(_lexeme("b", ["translate"]))
	for id in excluded:
		assert_str(str(id)).override_failure_message(
				"Ausgeschlossene Aufgabenart trotzdem im Pool: %s" % id).not_starts_with("translate:")


## Andere Aufgabenarten bleiben unberührt — ausgeschlossen wird die genannte, nicht das Wort.
func test_only_the_named_task_type_falls_away() -> void:
	var gen := WaveGenerator.new()
	var lex := _lexeme("c", ["conjugation"])
	assert_array(gen.learnables_of(lex)).contains(["translate:de_to_en:c", "translate:en_to_de:c"])


## Der Nenner des Fortschrittsbalkens: ein Wort ohne Übersetzungsaufgabe erreicht die
## Meisterung nie und gehört deshalb in keinen der beiden Werte.
func test_a_word_without_a_translation_task_is_not_masterable() -> void:
	assert_bool(PROGRESS.masterable(_lexeme("a"))).is_true()
	assert_bool(PROGRESS.masterable(_lexeme("b", ["translate"]))).is_false()
	# Ein Ausschluss, der die Übersetzung nicht meint, ändert am Balken nichts.
	assert_bool(PROGRESS.masterable(_lexeme("c", ["conjugation"]))).is_true()
