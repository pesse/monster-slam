extends GdUnitTestSuite
## Testlisten eines Profils: speichern, ersetzen, löschen; Scope und Richtungsfilter.

const PROFILE := "zz-test-lists"


func before_test() -> void:
	DirAccess.remove_absolute(TestLists.path(PROFILE))


func after_test() -> void:
	DirAccess.remove_absolute(TestLists.path(PROFILE))


func test_store_assigns_an_id_and_replaces_by_id() -> void:
	var list := TestLists.blank("access2", "Arbeit")
	list["lexeme_ids"] = ["lex.a", "lex.b"]
	var stored := TestLists.store(list, PROFILE)
	assert_str(str(stored["id"])).is_not_empty()
	stored["name"] = "Arbeit 2"
	TestLists.store(stored, PROFILE)
	assert_int(TestLists.lists(PROFILE).size()).is_equal(1)
	assert_str(str(TestLists.find(str(stored["id"]), PROFILE)["name"])).is_equal("Arbeit 2")
	assert_int(TestLists.lists_of("access3", PROFILE).size()).is_equal(0)
	TestLists.remove(str(stored["id"]), PROFILE)
	assert_array(TestLists.lists(PROFILE)).is_empty()


func test_run_scope_takes_the_narrowest_key_and_the_chosen_form_bonuses() -> void:
	var lexemes := {"a": {"id": "a", "unit": 5}, "b": {"id": "b", "unit": 5},
			"c": {"id": "c", "unit": 6}}
	var narrowest := func(entry): return {"a": "bk/5/1", "b": "bk/5/1", "c": "bk/6/2"}[entry["id"]]
	var list := {"lexeme_ids": ["a", "b", "c", "gone"], "form_bonuses": ["bonus:bk/6/3/perfect"]}
	assert_array(TestLists.run_scope(list, lexemes, narrowest)).is_equal(
			["bk/5/1", "bk/6/2", "bonus:bk/6/3/perfect"])
	assert_int(TestLists.main_unit(list, lexemes)).is_equal(5)


func test_direction_filter() -> void:
	assert_bool(TestLists.direction_allows("", "en_to_de")).is_true()
	assert_bool(TestLists.direction_allows("from_de", "de_to_en")).is_true()
	assert_bool(TestLists.direction_allows("from_de", "en")).is_true()
	assert_bool(TestLists.direction_allows("from_de", "la_to_de")).is_false()
	assert_bool(TestLists.direction_allows("to_de", "la_to_de")).is_true()
	assert_bool(TestLists.direction_allows("to_de", "de_to_la")).is_false()
