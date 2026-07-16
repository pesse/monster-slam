extends GdUnitTestSuite
## Tests für den Curriculum-Scope der ContentRegistry (Bücher/Units) und den kombinierten
## Scope-UND-Themen-Filter lexemes_scoped(), der das Session-Setup speist.


func test_all_books_contains_access2() -> void:
	assert_bool("access2" in ContentRegistry.all_books()).is_true()


func test_units_for_access2_contains_unit6() -> void:
	assert_bool(6 in ContentRegistry.units_for("access2")).is_true()


func test_units_for_are_sorted_and_distinct() -> void:
	var units := ContentRegistry.units_for("access2")
	var prev := -1
	var seen := {}
	for u in units:
		assert_bool(seen.has(u)).is_false()
		seen[u] = true
		assert_bool(prev < u).is_true()
		prev = u


func test_empty_scope_returns_all_lexemes() -> void:
	# Leerer Scope + leere Tags = keine Einschränkung (auch Lexeme ohne Buch/Unit).
	var all := ContentRegistry.lexemes_scoped([], [])
	assert_int(all.size()).is_equal(ContentRegistry.lexemes.size())


func test_unit_scope_returns_only_that_unit() -> void:
	var scoped := ContentRegistry.lexemes_scoped(["access2/6"], [])
	assert_bool(scoped.size() > 0).is_true()
	for entry in scoped:
		assert_str(str(entry.get("book", ""))).is_equal("access2")
		assert_int(int(entry.get("unit", -1))).is_equal(6)


func test_scope_excludes_non_curriculum_lexemes() -> void:
	# Grundwortschatz ohne book/unit darf bei gesetztem Scope NICHT auftauchen.
	var scoped := ContentRegistry.lexemes_scoped(["access2/6"], [])
	var ids := scoped.map(func(e): return str(e.get("id", "")))
	assert_bool("lex.en.house" in ids).is_false()


func test_book_scope_matches_all_units_of_book() -> void:
	# Der grobe Buch-Schlüssel matcht jede Unit des Buchs (hier nur Unit 6).
	var by_book := ContentRegistry.lexemes_scoped(["access2"], [])
	var by_unit := ContentRegistry.lexemes_scoped(["access2/6"], [])
	assert_int(by_book.size()).is_equal(by_unit.size())


func test_scope_and_tags_intersect() -> void:
	# Kernfall der Neuerung: Scope UND Thema -> nur Körperteile aus Unit 6.
	var scoped := ContentRegistry.lexemes_scoped(["access2/6"], ["body"])
	assert_bool(scoped.size() > 0).is_true()
	for entry in scoped:
		assert_str(str(entry.get("book", ""))).is_equal("access2")
		assert_bool("body" in entry.get("tags", [])).is_true()
	# Muss echte Teilmenge des reinen Unit-Scopes sein.
	assert_bool(scoped.size() < ContentRegistry.lexemes_scoped(["access2/6"], []).size()).is_true()


func test_unknown_scope_returns_empty() -> void:
	assert_int(ContentRegistry.lexemes_scoped(["nope/1"], []).size()).is_equal(0)
