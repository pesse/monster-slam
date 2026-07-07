extends GdUnitTestSuite
## TaskResolver reicht die Wortart (Lexem-"type") als task["lexeme_type"] durch, damit
## das Monster seine Wortart-Outline einfärben kann (siehe WordTypePalette).

var _resolver: TaskResolver


func before_test() -> void:
	_resolver = TaskResolver.new()


func test_resolve_passes_lexeme_type_through() -> void:
	var definition := {"task_type": "translate", "direction": "de_to_en", "difficulty": 1}
	var source := {"id": "lex.test.katze", "type": "noun", "lemma_de": "die Katze", "lemma_en": "cat"}
	var task := _resolver.resolve(definition, source)
	assert_str(str(task.get("lexeme_type", ""))).is_equal("noun")


func test_resolve_defaults_lexeme_type_to_empty() -> void:
	# Lexem ohne "type" -> leerer String (WordTypePalette fällt dann auf FALLBACK zurück).
	var definition := {"task_type": "translate", "direction": "de_to_en", "difficulty": 1}
	var source := {"id": "lex.test.notype", "lemma_de": "das Ding", "lemma_en": "thing"}
	var task := _resolver.resolve(definition, source)
	assert_str(str(task.get("lexeme_type", "MISSING"))).is_equal("")
