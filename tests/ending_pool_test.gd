extends GdUnitTestSuite
## Endungen im Aufgabenpool (ADR 0032): eine Aufgabe je Endung mit einem Trägerwort, das
## Perfekt erst mit eingeführtem Perfekt, eine ausgeschriebene Zelle gehört zum Wort, die
## Obergrenze je Welle und die Auswahl einer Testliste.
##
## Testlexeme mit `zz-`Ids in einem eigenen Buch, danach wieder entfernt.

const BOOK := "zz-endbuch"
const GENERATOR := preload("res://src/battle/wave_generator.gd")

const LEXEMES := {
	"zz-lex.la.end.rex": {"type": "noun", "unit": 1, "part": 1, "lemma_la": "rēx", "lemma_de": "der König"},
	"zz-lex.la.end.mittere": {"type": "verb", "unit": 1, "part": 1, "lemma_la": "mittere", "lemma_de": "schicken"},
	"zz-lex.la.end.ducere": {"type": "verb", "unit": 1, "part": 1, "lemma_la": "dūcere", "lemma_de": "führen",
			"irregular": true},
}
const FORMS := {
	"zz-form.rex.gen": ["zz-lex.la.end.rex", "la_genitive", "rēgis", 0, 0],
	"zz-form.rex.gender": ["zz-lex.la.end.rex", "la_gender", "m", 0, 0],
	"zz-form.mittere.pres1": ["zz-lex.la.end.mittere", "la_present_1sg", "mittō", 0, 0],
	"zz-form.mittere.perf": ["zz-lex.la.end.mittere", "la_perfect", "mīsī", 2, 5],
	"zz-form.ducere.pres1": ["zz-lex.la.end.ducere", "la_present_1sg", "dūcō", 0, 0],
	"zz-form.ducere.imp": ["zz-lex.la.end.ducere", "la_imp_sg", "dūc", 0, 0],
}
## Die Definitionen kommen aus dem game-Pack; ohne ihn fehlen sie hier.
const DEFINITIONS := {
	"zz-def.ending.decl": {"ending_table": "decl", "allowed_types": ["noun"]},
	"zz-def.ending.pres": {"ending_table": "pres", "allowed_types": ["verb"]},
	"zz-def.ending.imp": {"ending_table": "imp", "allowed_types": ["verb"]},
	"zz-def.ending.perf": {"ending_table": "perf", "allowed_types": ["verb"]},
}

var _saved_definitions := {}


func before_test() -> void:
	for id in LEXEMES:
		var entry: Dictionary = LEXEMES[id].duplicate()
		entry.merge({"id": id, "language": "la", "book": BOOK})
		ContentRegistry.lexemes[id] = entry
	for id in FORMS:
		var f: Array = FORMS[id]
		var form := {"id": id, "lexeme_id": f[0], "language": "la", "form_type": f[1], "value": f[2]}
		if int(f[3]) > 0:
			form.merge({"unit": f[3], "part": f[4]})
		ContentRegistry.lexeme_forms[id] = form
	# Nur die Endungen dieses Tests, damit der Katalog nichts dazumischt.
	_saved_definitions = ContentRegistry.task_definitions.duplicate()
	ContentRegistry.task_definitions.clear()
	for id in DEFINITIONS:
		var definition: Dictionary = DEFINITIONS[id].duplicate()
		definition.merge({"id": id, "language": "la", "task_type": "ending", "direction": "la",
				"difficulty": 2})
		ContentRegistry.task_definitions[id] = definition
	_reindex()


func after_test() -> void:
	for id in LEXEMES:
		ContentRegistry.lexemes.erase(id)
	for id in FORMS:
		ContentRegistry.lexeme_forms.erase(id)
	ContentRegistry.task_definitions.clear()
	ContentRegistry.task_definitions.merge(_saved_definitions)
	_reindex()


func _reindex() -> void:
	ContentRegistry._index_parts()
	ContentRegistry._index_bonuses()
	ContentRegistry._index_form_requirements()
	ContentRegistry.generation += 1


func _candidates(pool: Dictionary) -> Array:
	return GENERATOR.new()._candidates(pool)


func _units(pool: Dictionary) -> Array:
	return _candidates(pool).map(func(c): return Endings.unit_of(c["learnable_id"]))


func test_one_candidate_per_ending() -> void:
	var units := _units({"scope": [BOOK + "/1/1"]})
	var unique := {}
	for unit in units:
		unique[unit] = true
	assert_int(unique.size()).is_equal(units.size())
	assert_array(units).contains(["decl.3.gen_pl", "pres.cons.3pl", "imp.cons.pl"])


func test_the_perfect_comes_with_its_lesson() -> void:
	assert_array(_units({"scope": [BOOK + "/1/1"]})).not_contains(["perf.2sg"])
	assert_array(_units({"scope": [BOOK]})).contains(["perf.2sg", "perf.3pl"])


## dūc steht am Wort; als Träger des Imperativ Singular taugt dūcere nicht, für den Plural schon.
func test_a_written_out_cell_belongs_to_the_word() -> void:
	for _i in 20:
		for c in _candidates({"scope": [BOOK + "/1/1"]}):
			if Endings.unit_of(c["learnable_id"]) == "imp.cons.sg":
				assert_str(c["extra"]["carrier_id"]).is_equal("zz-lex.la.end.mittere")


func test_the_task_shows_the_dictionary_form_and_asks_the_cell() -> void:
	var resolver := TaskResolver.new()
	resolver.scope = [BOOK + "/1/1"]
	for c in _candidates({"scope": [BOOK + "/1/1"]}):
		if Endings.unit_of(c["learnable_id"]) == "decl.3.abl_pl":
			var task := resolver.resolve(c["definition"], c["source"], c["extra"])
			assert_str(task["prompt"]).is_equal("rēx, rēgis m → Abl. Pl.")
			assert_array(task["accepted_answers"]).is_equal(["rēgibus"])
			assert_str(task["learnable_id"]).is_equal("ending:la:decl.3.abl_pl")
			assert_str(task["source_id"]).is_equal("ending:la:decl.3.abl_pl")
			assert_str(task["carrier_id"]).is_equal("zz-lex.la.end.rex")
			return
	fail("keine Endung decl.3.abl_pl")


func test_a_test_list_plays_only_its_ending_groups() -> void:
	var pool := {"scope": [BOOK + "/1/1"], "lexeme_ids": ["zz-lex.la.end.rex"],
			"book": BOOK, "ending_groups": []}
	assert_array(_units(pool).filter(func(u): return not u.is_empty())).is_empty()
	pool["ending_groups"] = ["pres.cons"]
	var units := _units(pool).filter(func(u): return not u.is_empty())
	assert_array(units).is_not_empty()
	for unit in units:
		assert_str(LatinMorphology.group_of(unit)).is_equal("pres.cons")


## Kein Wort der Liste trägt das Perfekt: die Träger kommen aus dem ganzen Buch.
func test_a_test_list_finds_carriers_in_the_book() -> void:
	var pool := {"scope": [], "lexeme_ids": [], "book": BOOK, "ending_groups": ["perf"]}
	assert_array(_units(pool)).contains(["perf.2sg"])


func test_at_most_every_fourth_monster_carries_an_ending() -> void:
	var endings := 0
	var pattern: Array = []
	for spawned in 12:
		var allowed := GENERATOR.endings_allowed(endings, spawned)
		pattern.append(allowed)
		if allowed:
			endings += 1
	assert_array(pattern).is_equal([false, false, false, true, false, false, false, true,
			false, false, false, true])


func test_the_language_of_an_ending() -> void:
	assert_str(Lexeme.language_of_learnable("ending:la:decl.3.gen_pl", {}, func(_b): return ""))\
			.is_equal("la")


## Jedes lateinische Nomen und Verb trägt Endungen, außer es ist unregelmäßig, hat keine
## 1. Person (unpersönlich). So fällt ein Wort auf, dessen Klasse die Regel nicht findet.
func test_every_latin_word_in_the_catalog_finds_its_class() -> void:
	var missing: Array = []
	for id in ContentRegistry.lexemes:
		var entry: Dictionary = ContentRegistry.lexemes[id]
		if str(id).begins_with("zz-") or Lexeme.language(entry) != "la" \
				or bool(entry.get("irregular", false)):
			continue
		var type := str(entry.get("type", ""))
		if type == "verb" and ContentRegistry.forms_for(str(id), "la_present_1sg").is_empty():
			continue
		if not type in ["noun", "verb"]:
			continue
		var table := "decl" if type == "noun" else "pres"
		if Endings.carrier_cells(entry, table, []).is_empty():
			missing.append(Lexeme.foreign(entry))
	assert_array(missing).override_failure_message("ohne Klasse: %s" % ", ".join(missing)) \
			.is_empty()


## Die Tabelle färbt nur, was ein Wort der Auswahl trägt; der Stand hängt an der Lerneinheit.
func test_the_table_shows_the_state_of_each_ending() -> void:
	var present := Endings.present_units(ContentRegistry.lexemes_scoped([BOOK + "/1/1"], []),
			[BOOK + "/1/1"])
	var mastered := Endings.learnable_id("la", "decl.3.gen_pl")
	var sheet := EndingTable.sheet("decl", present,
			func(id): return 0.9 if id == mastered else -1.0, func(id): return id == mastered)
	var gen_pl: Dictionary = sheet["rows"][5]
	assert_str(gen_pl["label"]).is_equal("Gen. Pl.")
	var states: Array = gen_pl["cells"].map(func(c): return c["state"])
	# a, o, o n., 3., 3. n., 3. i, 3. i n., u, e
	assert_array(states).is_equal(["absent", "absent", "absent", "mastered", "mastered",
			"absent", "absent", "absent", "absent"])
	assert_str(sheet["rows"][1]["cells"][3]["state"]).is_equal("new")
	assert_dict(EndingTable.summary(present, func(id): return id == mastered)) \
			.contains_keys(["done", "total"])
	assert_int(int(EndingTable.summary(present, func(id): return id == mastered)["done"])).is_equal(1)


## Die Abfragewahl der Karte: ohne Grundformen nur Endungen, ohne Deklinationen keine Fälle.
func test_a_level_asks_only_what_was_chosen() -> void:
	var scope := [BOOK + "/1/1"]
	var only_conj := _candidates({"scope": scope, "content": [WaveGenerator.CONTENT_CONJ]})
	assert_array(only_conj).is_not_empty()
	for c in only_conj:
		assert_str(WaveGenerator.content_of(c["definition"])).is_equal(WaveGenerator.CONTENT_CONJ)
	var no_decl := _units({"scope": scope,
			"content": [WaveGenerator.CONTENT_WORDS, WaveGenerator.CONTENT_CONJ]})
	assert_array(no_decl.filter(func(u): return str(u).begins_with("decl."))).is_empty()
	assert_array(no_decl).contains(["pres.cons.3pl"])


## Eine ausgeschriebene Zelle wie dūc gehört zur Konjugation, Genitiv und Perfekt bleiben
## Grundformen: ohne Endungen fragt ein Level auch dūc nicht.
func test_a_written_out_cell_counts_to_its_table() -> void:
	var forms := func(form_type: String) -> Dictionary:
		return {"task_type": "forms", "requires_form": form_type}
	assert_str(WaveGenerator.content_of(forms.call("la_imp_sg"))).is_equal(WaveGenerator.CONTENT_CONJ)
	assert_str(WaveGenerator.content_of(forms.call("la_dat_pl"))).is_equal(WaveGenerator.CONTENT_DECL)
	for form_type in ["la_genitive", "la_present_1sg", "la_perfect", "la_gender", "la_ppp", ""]:
		assert_str(WaveGenerator.content_of(forms.call(form_type))).is_equal(WaveGenerator.CONTENT_WORDS)
	assert_str(WaveGenerator.content_of({"task_type": "translate"})).is_equal(WaveGenerator.CONTENT_WORDS)


## Eine Liste ohne Endungen fragt dūc nicht; mit einer Konjugationsgruppe des Imperativs schon.
func test_a_test_list_asks_written_out_cells_only_with_their_table() -> void:
	var imp := {"task_type": "forms", "requires_form": "la_imp_sg"}
	assert_bool(WaveGenerator.test_asks_form(imp, [])).is_false()
	assert_bool(WaveGenerator.test_asks_form(imp, ["decl.3", "pres.cons"])).is_false()
	assert_bool(WaveGenerator.test_asks_form(imp, ["imp"])).is_true()
	assert_bool(WaveGenerator.test_asks_form(
			{"task_type": "forms", "requires_form": "la_abl_sg"}, ["decl.o"])).is_true()
	assert_bool(WaveGenerator.test_asks_form(
			{"task_type": "forms", "requires_form": "la_perfect"}, [])).is_true()
