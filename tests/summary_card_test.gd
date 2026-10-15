extends GdUnitTestSuite
## Was der Schreib-Boss offline rechnet: Wortzahl, Länge, Zitatsuche
## (src/learning/summary_card.gd, docs/adr/0023-schreib-boss.md).
##
## Geprüft wird an einer ERFUNDENEN Vorlage (tests/fixtures/writing/summary_fixture.json),
## nicht am Bestand: hier stehen die Regeln, und sie sollen auch ohne Submodule gelten.

const FIXTURE := "res://tests/fixtures/writing/summary_fixture.json"

var _task: Dictionary


func before() -> void:
	_task = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))


func test_the_fixture_is_a_complete_task() -> void:
	for field in ["id", "kind", "book", "unit", "title", "author", "genre", "text",
			"target_words", "key_points"]:
		assert_bool(_task.has(field)).override_failure_message("fehlt: " + field).is_true()
	var words := SummaryCard.split_words(str(_task["text"])).size()
	assert_int(words).is_between(250, 400)
	assert_int(Array(_task["key_points"]).size()).is_between(5, 6)


## Ein „doesn't“ ist ein Wort, Satzzeichen und Leerraum zählen nicht.
func test_words_are_counted_like_a_teacher_counts() -> void:
	var card := SummaryCard.check(_task, "  Tom doesn’t   give up -- he  is well-known now.  ")
	assert_int(int(card["words"])).is_equal(8)
	assert_int(int(SummaryCard.check(_task, "")["words"])).is_equal(0)


func test_length_is_checked_against_the_target_range() -> void:
	var short := SummaryCard.check(_task, "In The Lighthouse Cat by Mara Linden a cat helps.")
	assert_bool(bool(short["length_ok"])).is_false()
	var words := PackedStringArray()
	for i in 80:
		words.append("word")
	assert_bool(bool(SummaryCard.check(_task, " ".join(words))["length_ok"])).is_true()
	for i in 61:
		words.append("word")
	assert_bool(bool(SummaryCard.check(_task, " ".join(words))["length_ok"])).is_false()
	assert_bool(bool(SummaryCard.check(_task, "")["length_ok"])).is_false()


func test_locate_finds_a_phrase_in_the_original_text() -> void:
	var text := "Tom  doesn’t   WANT to go.\nBut the cat runs."
	var at := SummaryCard.locate(text, "tom doesn't want")
	assert_int(int(at["from"])).is_equal(0)
	assert_str(text.substr(int(at["from"]), int(at["to"]) - int(at["from"])))\
			.is_equal("Tom  doesn’t   WANT")
	var cat := SummaryCard.locate(text, "the CAT runs!")
	assert_str(text.substr(int(cat["from"]), int(cat["to"]) - int(cat["from"])))\
			.is_equal("the cat runs")
	assert_dict(SummaryCard.locate(text, "the dog runs")).is_empty()
	assert_dict(SummaryCard.locate(text, "")).is_empty()
