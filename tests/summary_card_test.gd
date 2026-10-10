extends GdUnitTestSuite
## Stufe 0 des Schreib-Bosses — die Offline-Prüfung einer Summary
## (src/learning/summary_card.gd, docs/adr/0023-schreib-boss.md).
##
## Geprüft wird an einer ERFUNDENEN Vorlage (tests/fixtures/writing/summary_fixture.json),
## nicht am Bestand: hier stehen die Regeln, und sie sollen auch ohne Submodule gelten.

const FIXTURE := "res://tests/fixtures/writing/summary_fixture.json"

## Eine Summary, wie sie sein soll: Einleitung mit Titel und Autor, Präsens, eigene Worte,
## keine Meinung, im Zielbereich.
const GOOD := "In the short story \"The Lighthouse Cat\" by Mara Linden, an old lighthouse keeper called Tom and his cat Pepper look after the lamp on Gull Island. One stormy night the lamp stops working while a fishing boat is sailing towards the rocks. Tom is too old to go down the wet steps quickly, so Pepper runs downstairs and brings back the rope of an old lantern. Together they pull it up, and Tom holds the light in the window. Finally the boat turns away and reaches the harbour safely. The next day the fishermen thank Tom, but he says that the cat deserves the thanks. Since then everybody on the island knows Pepper as the Lighthouse Cat."

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


func test_a_good_summary_passes_every_offline_check() -> void:
	var card := SummaryCard.check(_task, GOOD)
	assert_bool(bool(card["intro"])).is_true()
	assert_array(card["quotes"]).is_empty()
	assert_array(card["opinion"]).is_empty()
	assert_bool(bool(card["length_ok"])).is_true()
	assert_array(card["connectors"]).contains(["while", "so", "finally", "but"])


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


func test_the_intro_names_title_and_author_in_the_first_sentence() -> void:
	var check := func(text: String) -> bool: return bool(SummaryCard.check(_task, text)["intro"])
	assert_bool(check.call("The story The Lighthouse Cat by Mara Linden is about a cat.")).is_true()
	# Groß/Klein, typografische Anführungszeichen, Titel ohne Artikel, Autor mit Nachnamen.
	assert_bool(check.call("In “lighthouse cat” by LINDEN, a cat saves a boat.")).is_true()
	assert_bool(check.call("In The Lighthouse Cat a cat saves a boat.")).is_false()
	assert_bool(check.call("A cat saves a boat. The Lighthouse Cat by Mara Linden is short."))\
			.is_false()
	assert_bool(check.call("")).is_false()


func test_direct_speech_is_found_but_a_quoted_title_is_not() -> void:
	var text := "In \"The Lighthouse Cat\" by Mara Linden, Tom says: “Thank her.” Then he smiles."
	var quotes: Array = SummaryCard.check(_task, text)["quotes"]
	assert_array(quotes).contains_exactly(["“Thank her.”"])


func test_five_copied_words_count_as_a_quote() -> void:
	var text := "That night the RAIN hit the  glass like little stones, and Tom is afraid."
	var quotes: Array = SummaryCard.check(_task, text)["quotes"]
	assert_array(quotes).contains_exactly(["the RAIN hit the  glass like little stones"])
	# Vier Wörter am Stück sind noch eine Allerweltswendung.
	var four: Array = SummaryCard.check(_task, "Then the rain hit the roof.")["quotes"]
	assert_array(four).is_empty()


func test_opinion_phrases_are_found_in_the_original_spelling() -> void:
	var text := "Tom is brave. I think the cat is cool, and in my opinion I DON’T like Tom."
	var opinion: Array = SummaryCard.check(_task, text)["opinion"]
	assert_array(opinion).contains_exactly(["I think", "in my opinion", "I DON’T like"])


## Die längste Wendung gewinnt, jeder Konnektor steht einmal, in Textreihenfolge.
func test_connectors_prefer_the_longest_phrase() -> void:
	var text := "Even though it rains, Tom goes up. However, the lamp breaks. However, the cat helps."
	var found: Array = SummaryCard.check(_task, text)["connectors"]
	assert_array(found).contains_exactly(["even though", "however"])


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
