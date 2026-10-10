extends GdUnitTestSuite
## Die Kategorie `writing` (ADR 0023) steht an allen vier Stellen, die ADR 0003 verlangt:
## ContentRegistry, PackInstaller, tools/packs/build_packs.py und die `roots` in
## data/language/packs.yaml. Dass Registry und Installer insgesamt übereinstimmen, prüft
## tests/content_registry_roots_test.gd; build_packs.py vergleicht sich selbst mit dem
## Installer. Hier steht nur, dass die neue Kategorie wirklich überall angekommen ist.

const BUILD_PACKS := "res://tools/packs/build_packs.py"
const PACKS_YAML := "res://data/language/packs.yaml"


func test_registry_and_installer_know_writing() -> void:
	assert_array(ContentRegistry.categories()).contains(["writing"])
	assert_array(Array(ContentRegistry.LANGUAGE_CATEGORIES)).contains(["writing"])
	assert_array(Array(PackInstaller.CATEGORIES)).contains(["writing"])


func test_the_pack_build_knows_writing() -> void:
	var source := FileAccess.get_file_as_string(BUILD_PACKS)
	var block := RegEx.create_from_string("CATEGORIES = \\{([^}]*)\\}").search(source)
	assert_object(block).is_not_null()
	assert_str(block.get_string(1)).contains("\"writing\"")


func test_the_pack_config_scans_writing_in_the_language_root(
		do_skip := LanguageData.missing(), skip_reason := LanguageData.REASON) -> void:
	var yaml := FileAccess.get_file_as_string(PACKS_YAML)
	var roots := RegEx.create_from_string("(?s)roots:\\s*\\n\\s*language:(.*?)\\n\\s*game:")\
			.search(yaml)
	assert_object(roots).is_not_null()
	assert_str(roots.get_string(1)).contains("- writing")


func test_writing_tasks_filters_by_book_unit_and_kind() -> void:
	var saved := ContentRegistry.writing.duplicate()
	ContentRegistry.writing.clear()
	ContentRegistry.writing["writing.zz.b"] = {"id": "writing.zz.b", "kind": "summary",
			"book": "zz-book", "unit": 1}
	ContentRegistry.writing["writing.zz.a"] = {"id": "writing.zz.a", "kind": "summary",
			"book": "zz-book", "unit": 1}
	ContentRegistry.writing["writing.zz.m"] = {"id": "writing.zz.m", "kind": "mediation",
			"book": "zz-book", "unit": 1}
	ContentRegistry.writing["writing.zz.u2"] = {"id": "writing.zz.u2", "kind": "summary",
			"book": "zz-book", "unit": 2}
	var ids: Array = ContentRegistry.writing_tasks("zz-book", 1).map(func(t): return t["id"])
	var mediation: Array = ContentRegistry.writing_tasks("zz-book", 1, "mediation")
	ContentRegistry.writing.clear()
	ContentRegistry.writing.merge(saved)
	assert_array(ids).is_equal(["writing.zz.a", "writing.zz.b"])
	assert_int(mediation.size()).is_equal(1)
	assert_array(ContentRegistry.writing_tasks("zz-other", 1)).is_empty()
