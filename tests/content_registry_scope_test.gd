extends GdUnitTestSuite
## Tests für den Curriculum-Scope der ContentRegistry (Bücher/Units) und den kombinierten
## Scope-UND-Themen-Filter lexemes_scoped(), der das Session-Setup speist.


func test_all_books_contains_access2(do_skip := LanguageData.missing(), skip_reason := LanguageData.REASON) -> void:
	assert_bool("access2" in ContentRegistry.all_books()).is_true()


func test_units_for_access2_contains_unit6(do_skip := LanguageData.missing(), skip_reason := LanguageData.REASON) -> void:
	assert_bool(6 in ContentRegistry.units_for("access2")).is_true()


func test_units_for_are_sorted_and_distinct(do_skip := LanguageData.missing(), skip_reason := LanguageData.REASON) -> void:
	var units := ContentRegistry.units_for("access2")
	var prev := -1
	var seen := {}
	for u in units:
		assert_bool(seen.has(u)).is_false()
		seen[u] = true
		assert_bool(prev < u).is_true()
		prev = u


func test_empty_scope_returns_all_lexemes(do_skip := LanguageData.missing(), skip_reason := LanguageData.REASON) -> void:
	# Leerer Scope + leere Tags = keine Einschränkung (auch Lexeme ohne Buch/Unit).
	var all := ContentRegistry.lexemes_scoped([], [])
	assert_int(all.size()).is_equal(ContentRegistry.lexemes.size())


func test_unit_scope_returns_only_that_unit(do_skip := LanguageData.missing(), skip_reason := LanguageData.REASON) -> void:
	var scoped := ContentRegistry.lexemes_scoped(["access2/6"], [])
	assert_bool(scoped.size() > 0).is_true()
	for entry in scoped:
		assert_str(str(entry.get("book", ""))).is_equal("access2")
		assert_int(int(entry.get("unit", -1))).is_equal(6)


func test_scope_excludes_non_curriculum_lexemes(do_skip := LanguageData.missing(), skip_reason := LanguageData.REASON) -> void:
	# Grundwortschatz ohne book/unit darf bei gesetztem Scope NICHT auftauchen.
	var scoped := ContentRegistry.lexemes_scoped(["access2/6"], [])
	var ids := scoped.map(func(e): return str(e.get("id", "")))
	assert_bool("lex.en.house" in ids).is_false()


func test_book_scope_matches_all_units_of_book(do_skip := LanguageData.missing(), skip_reason := LanguageData.REASON) -> void:
	# Der grobe Buch-Schlüssel matcht jede Unit des Buchs (hier nur Unit 6).
	var by_book := ContentRegistry.lexemes_scoped(["access2"], [])
	var by_unit := ContentRegistry.lexemes_scoped(["access2/6"], [])
	assert_int(by_book.size()).is_equal(by_unit.size())


func test_scope_and_tags_intersect(do_skip := LanguageData.missing(), skip_reason := LanguageData.REASON) -> void:
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


# --- Teile einer Unit (positionsbasiertes Viertel) -------------------------------

func test_a_unit_splits_into_part_count_parts(do_skip := LanguageData.missing(), skip_reason := LanguageData.REASON) -> void:
	assert_int(ContentRegistry.parts_for("access2", 6)).is_equal(ContentRegistry.PART_COUNT)


func test_an_unknown_unit_has_no_parts() -> void:
	assert_int(ContentRegistry.parts_for("nope", 1)).is_equal(0)


## Die Teile zerlegen die Unit vollständig und überschneidungsfrei — sonst fehlte je nach
## Auswahl eine Vokabel oder käme doppelt.
func test_the_parts_cover_the_unit_exactly(do_skip := LanguageData.missing(), skip_reason := LanguageData.REASON) -> void:
	var unit := ContentRegistry.lexemes_scoped(["access2/6"], [])
	var seen := {}
	for part in range(1, ContentRegistry.parts_for("access2", 6) + 1):
		for entry in ContentRegistry.lexemes_scoped(["access2/6/%d" % part], []):
			var id := str(entry.get("id", ""))
			assert_bool(seen.has(id)).is_false()
			seen[id] = true
	assert_int(seen.size()).is_equal(unit.size())


## Gleich große Viertel, Rest nach vorn: zwischen größtem und kleinstem Teil liegt
## höchstens eine Vokabel.
func test_the_parts_are_of_equal_size(do_skip := LanguageData.missing(), skip_reason := LanguageData.REASON) -> void:
	var sizes: Array = []
	for part in range(1, ContentRegistry.parts_for("access2", 6) + 1):
		sizes.append(ContentRegistry.lexemes_scoped(["access2/6/%d" % part], []).size())
	sizes.sort()
	assert_bool(sizes[0] > 0).is_true()
	assert_bool(sizes[-1] - sizes[0] <= 1).is_true()


## „Positionsbasiert" heißt: Teil 1 sind die ERSTEN Vokabeln der Unit in Bestandsreihenfolge
## (die Reihenfolge der Quelldatei), nicht eine beliebige Auswahl.
func test_part_one_holds_the_first_lexemes_of_the_unit(do_skip := LanguageData.missing(), skip_reason := LanguageData.REASON) -> void:
	var in_order: Array = []
	for id in ContentRegistry.lexemes:
		var entry: Dictionary = ContentRegistry.lexemes[id]
		if str(entry.get("book", "")) == "access2" and int(entry.get("unit", -1)) == 6:
			in_order.append(str(id))
	var first := ContentRegistry.lexemes_scoped(["access2/6/1"], [])
	var first_ids := first.map(func(e): return str(e.get("id", "")))
	assert_array(first_ids).contains_exactly_in_any_order(in_order.slice(0, first.size()))


## Ein Teil-Schlüssel ist eine echte Teilmenge der Unit — und die Unit zieht ihre Teile
## nicht mit in die Auswahl hinein, sondern deckt sie ab.
func test_a_part_is_a_subset_of_its_unit(do_skip := LanguageData.missing(), skip_reason := LanguageData.REASON) -> void:
	var part := ContentRegistry.lexemes_scoped(["access2/6/2"], [])
	var unit := ContentRegistry.lexemes_scoped(["access2/6"], [])
	assert_bool(part.size() > 0).is_true()
	assert_bool(part.size() < unit.size()).is_true()
	var unit_ids := unit.map(func(e): return str(e.get("id", "")))
	for entry in part:
		assert_bool(str(entry.get("id", "")) in unit_ids).is_true()


## Teile und Themen schneiden sich wie Units und Themen (die Auswahl bleibt zwei Achsen).
func test_part_and_tags_intersect(do_skip := LanguageData.missing(), skip_reason := LanguageData.REASON) -> void:
	var scoped := ContentRegistry.lexemes_scoped(["access2/6/1", "access2/6/2"], ["body"])
	for entry in scoped:
		assert_bool("body" in entry.get("tags", [])).is_true()
	assert_bool(scoped.size() <= ContentRegistry.lexemes_scoped(["access2/6"], ["body"]).size()).is_true()
