extends GdUnitTestSuite
## Sprachfilter der Statistik (Issue #45): die Sprache einer Aufgabe wird gerechnet, nicht
## gespeichert — aus der Richtung, sonst aus dem Buch ihres Lexems.
##
## Die Zähler laufen auf einer EIGENEN PlayerProgress-Instanz (nicht im Baum, kein _ready,
## nichts gespeichert); die Records sind Übersetzungen, deren Sprache ohne Katalog feststeht.

const PROGRESS := preload("res://src/learning/player_progress.gd")

## Erfundener Katalog: ein Buch je Sprache, ein Lexem ohne Buch.
const LEXEMES := {
	"lx_go": {"id": "lx_go", "book": "zz-en", "lemma_en": "go"},
	"lx_ire": {"id": "lx_ire", "book": "zz-la", "language": "la", "lemma_la": "ire"},
	"lx_loose": {"id": "lx_loose", "language": "fr", "lemma_fr": "aller"},
}
const BOOKS := {"zz-en": "en", "zz-la": "la"}

var _pp: Node


func before_test() -> void:
	_pp = auto_free(PROGRESS.new())
	_pp.player_id = "zz-language-filter-test"


func _lang(id: String) -> String:
	return Lexeme.language_of_learnable(id, LEXEMES, func(book): return BOOKS.get(book, ""))


func _rec(confidence: float, attempts: int, correct: int, best_streak: int) -> Dictionary:
	return {
		"confidence": confidence, "attempts": attempts, "correct_total": correct,
		"current_streak": 0, "best_streak": best_streak, "last_correct": true,
		"last_response_time_ms": 0, "last_seen_at": 0, "next_review_at": 0,
		"first_seen_at": 0, "mastered_at": 0,
	}


## Übersetzungen tragen die Sprache in der Richtung — auch ohne Lexem im Katalog.
func test_translations_take_the_language_from_the_direction() -> void:
	assert_str(_lang("translate:de_to_la:unbekannt")).is_equal("la")
	assert_str(_lang("translate:en_to_de:lx_go")).is_equal("en")


## Formen und Relationen erben die Sprache vom Buch ihres Lexems.
func test_forms_and_relations_take_the_language_from_the_book() -> void:
	assert_str(_lang("conjugation:lx_ire:perfect")).is_equal("la")
	assert_str(_lang("opposite:lx_go:lx_come")).is_equal("en")


## Ohne Buch gilt das Feld am Lexem; ohne Lexem gibt es keine Sprache.
func test_fallbacks() -> void:
	assert_str(_lang("forms:lx_loose:plural")).is_equal("fr")
	assert_str(_lang("conjugation:fehlt:past")).is_empty()
	assert_str(_lang("kaputt")).is_empty()


func test_counters_follow_the_language() -> void:
	_pp._records = {
		"translate:de_to_en:a": _rec(0.9, 4, 4, 4),
		"translate:en_to_de:a": _rec(0.5, 3, 1, 1),
		"translate:de_to_la:b": _rec(0.95, 6, 5, 7),
	}
	assert_int(_pp.mastered_count()).is_equal(2)
	assert_int(_pp.mastered_count(PROGRESS.MASTERY_CONFIDENCE, ["en"])).is_equal(1)
	assert_int(_pp.mastered_count(PROGRESS.MASTERY_CONFIDENCE, ["fr"])).is_equal(0)
	assert_int(_pp.seen_count(["en"])).is_equal(2)
	assert_int(_pp.seen_count(["la"])).is_equal(1)
	assert_int(_pp.total_attempts(["en"])).is_equal(7)
	assert_int(_pp.total_correct(["la"])).is_equal(5)
	assert_int(_pp.best_streak_overall()).is_equal(7)
	assert_int(_pp.best_streak_overall(["en"])).is_equal(4)
	assert_int(_pp.records_for_display(["la"]).size()).is_equal(1)
	assert_int(_pp.records_for_display().size()).is_equal(3)
	assert_int(_pp.seen_count(["en", "la"])).is_equal(3)
	assert_int(_pp.mastered_count_before(1, PROGRESS.MASTERY_CONFIDENCE, ["la"])).is_equal(1)
