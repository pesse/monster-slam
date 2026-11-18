extends GdUnitTestSuite
## Lateinische Formen nach der Regel (ADR 0032): Klasse aus Lemma, Genitiv und Genus bzw.
## Infinitiv und 1. Person, Stamm aus dem Genitiv, Lerneinheit je Endung. Einzelne
## Schulgrammatik-Wörter als Beispiele.

const MORPH := preload("res://src/learning/latin_morphology.gd")


func _forms(cells: Array) -> Dictionary:
	var out := {}
	for c in cells:
		out[str(c["cell"])] = str(c["form"])
	return out


func _units(cells: Array) -> Dictionary:
	var out := {}
	for c in cells:
		out[str(c["cell"])] = str(c["unit"])
	return out


func test_third_declension_takes_its_stem_from_the_genitive() -> void:
	var f := _forms(MORPH.noun_cells("rēx", "rēgis", "m"))
	assert_dict(f).is_equal({
		"decl.dat_sg": "rēgī", "decl.acc_sg": "rēgem", "decl.abl_sg": "rēge",
		"decl.nom_pl": "rēgēs", "decl.gen_pl": "rēgum", "decl.dat_pl": "rēgibus",
		"decl.acc_pl": "rēgēs", "decl.abl_pl": "rēgibus",
	})
	assert_str(_forms(MORPH.noun_cells("māter", "mātris", "f"))["decl.gen_pl"]).is_equal("mātrum")


func test_the_genus_does_not_choose_the_declension() -> void:
	assert_str(MORPH.noun_class("māter", "mātris", "f")["class"]).is_equal("3")
	assert_str(MORPH.noun_class("nauta", "nautae", "m")["class"]).is_equal("a")


func test_a_genitive_on_ei_is_not_always_the_e_declension() -> void:
	assert_str(MORPH.noun_class("deus", "deī", "m")["class"]).is_equal("o")
	assert_str(MORPH.noun_class("rēs", "reī", "f")["class"]).is_equal("e")


func test_a_neuter_repeats_its_nominative_in_the_accusative() -> void:
	var f := _forms(MORPH.noun_cells("corpus", "corporis", "n"))
	assert_str(f["decl.acc_sg"]).is_equal("corpus")
	assert_str(f["decl.nom_pl"]).is_equal("corpora")
	assert_str(f["decl.abl_sg"]).is_equal("corpore")


func test_i_stems_follow_from_the_lemma() -> void:
	assert_str(_forms(MORPH.noun_cells("urbs", "urbis", "f"))["decl.gen_pl"]).is_equal("urbium")
	assert_str(_forms(MORPH.noun_cells("nox", "noctis", "f"))["decl.gen_pl"]).is_equal("noctium")
	assert_str(_forms(MORPH.noun_cells("nāvis", "nāvis", "f"))["decl.gen_pl"]).is_equal("nāvium")
	assert_str(_forms(MORPH.noun_cells("pater", "patris", "m"))["decl.gen_pl"]).is_equal("patrum")
	assert_str(_forms(MORPH.noun_cells("vōx", "vōcis", "f"))["decl.gen_pl"]).is_equal("vōcum")
	var mare := _forms(MORPH.noun_cells("mare", "maris", "n"))
	assert_str(mare["decl.abl_sg"]).is_equal("marī")
	assert_str(mare["decl.nom_pl"]).is_equal("maria")
	assert_str(mare["decl.gen_pl"]).is_equal("marium")


func test_without_genitive_a_and_o_come_from_ending_and_genus() -> void:
	var f := _forms(MORPH.noun_cells("amīcus", "", "m"))
	assert_str(f["decl.gen_sg"]).is_equal("amīcī")
	assert_str(f["decl.acc_pl"]).is_equal("amīcōs")
	assert_str(_forms(MORPH.noun_cells("dōnum", "", "n"))["decl.nom_pl"]).is_equal("dōna")
	assert_str(_forms(MORPH.noun_cells("porta", "", "f"))["decl.abl_sg"]).is_equal("portā")
	assert_array(MORPH.noun_cells("homō", "", "m")).is_empty()


func test_a_shown_genitive_is_not_asked() -> void:
	assert_bool(_forms(MORPH.noun_cells("amīcus", "amīcī", "m")).has("decl.gen_sg")).is_false()


func test_a_plural_word_has_only_plural_cells() -> void:
	var f := _forms(MORPH.noun_cells("arma", "armōrum", "n"))
	assert_array(f.keys()).contains_exactly_in_any_order(
			["decl.dat_pl", "decl.acc_pl", "decl.abl_pl", "decl.gen_pl"])
	assert_str(f["decl.dat_pl"]).is_equal("armīs")
	assert_str(_forms(MORPH.noun_cells("precēs", "precum", "f"))["decl.abl_pl"]).is_equal("precibus")


func test_the_five_conjugations() -> void:
	assert_str(_forms(MORPH.verb_cells("amāre", "amō"))["pres.3sg"]).is_equal("amat")
	assert_str(_forms(MORPH.verb_cells("amāre", "amō"))["impf.1pl"]).is_equal("amābāmus")
	assert_str(_forms(MORPH.verb_cells("monēre", "moneō"))["pres.3pl"]).is_equal("monent")
	assert_str(_forms(MORPH.verb_cells("audīre", "audiō"))["pres.3pl"]).is_equal("audiunt")
	assert_str(_forms(MORPH.verb_cells("audīre", "audiō"))["impf.1sg"]).is_equal("audiēbam")
	assert_str(_forms(MORPH.verb_cells("mittere", "mittō"))["pres.1pl"]).is_equal("mittimus")
	assert_str(_forms(MORPH.verb_cells("mittere", "mittō"))["imp.pl"]).is_equal("mittite")
	assert_str(_forms(MORPH.verb_cells("capere", "capiō"))["pres.3pl"]).is_equal("capiunt")
	assert_str(_forms(MORPH.verb_cells("capere", "capiō"))["imp.sg"]).is_equal("cape")


func test_dare_keeps_its_short_a() -> void:
	var f := _forms(MORPH.verb_cells("dare", "dō"))
	assert_str(f["pres.2sg"]).is_equal("dās")
	assert_str(f["pres.1pl"]).is_equal("damus")
	assert_str(f["impf.1sg"]).is_equal("dabam")
	assert_str(f["imp.sg"]).is_equal("dā")
	assert_str(f["imp.pl"]).is_equal("date")
	assert_str(_units(MORPH.verb_cells("dare", "dō"))["pres.1pl"]).is_equal("pres.a.1pl")


func test_the_perfect_needs_the_perfect_stem() -> void:
	assert_bool(_forms(MORPH.verb_cells("mittere", "mittō")).has("perf.2sg")).is_false()
	var f := _forms(MORPH.verb_cells("mittere", "mittō", "mīsī"))
	assert_str(f["perf.2sg"]).is_equal("mīsistī")
	assert_str(f["perf.3pl"]).is_equal("mīsērunt")
	assert_str(_units(MORPH.verb_cells("mittere", "mittō", "mīsī"))["perf.3pl"]).is_equal("perf.3pl")


func test_verbs_outside_the_rule_have_no_cells() -> void:
	assert_array(MORPH.verb_cells("esse", "sum")).is_empty()
	assert_array(MORPH.verb_cells("licēre", "")).is_empty()


## Eine Endung, die zwei Klassen gemeinsam haben, ist eine Lerneinheit.
func test_shared_endings_are_one_unit() -> void:
	var capere := _units(MORPH.verb_cells("capere", "capiō"))
	assert_str(capere["pres.2sg"]).is_equal("pres.cons.2sg")
	assert_str(capere["pres.3pl"]).is_equal("pres.i.3pl")
	assert_str(capere["impf.1sg"]).is_equal("impf.i.1sg")
	assert_str(capere["imp.sg"]).is_equal("imp.cons.sg")
	var corpus := _units(MORPH.noun_cells("corpus", "corporis", "n"))
	assert_str(corpus["decl.gen_pl"]).is_equal("decl.3.gen_pl")
	assert_str(corpus["decl.nom_pl"]).is_equal("decl.3_n.nom_pl")
	var mare := _units(MORPH.noun_cells("mare", "maris", "n"))
	assert_str(mare["decl.gen_pl"]).is_equal("decl.3_i.gen_pl")
	assert_str(mare["decl.acc_sg"]).is_equal("decl.3_n.acc_sg")
	assert_str(_units(MORPH.noun_cells("dōnum", "", "n"))["decl.dat_pl"]).is_equal("decl.o.dat_pl")


func test_groups_and_labels() -> void:
	assert_str(MORPH.group_of("decl.3_i.gen_pl")).is_equal("decl.3")
	assert_str(MORPH.group_of("pres.cons.2sg")).is_equal("pres.cons")
	assert_str(MORPH.group_of("imp.a.sg")).is_equal("imp")
	assert_str(MORPH.group_of("perf.3pl")).is_equal("perf")
	assert_str(MORPH.group_label("pres.a")).is_equal("Präsens, a-Konjugation")
	assert_str(MORPH.cell_label("impf.3pl")).is_equal("3. Pl. Imperfekt")
	assert_str(MORPH.unit_label("decl.3_i.gen_pl")).is_equal("3. Deklination, i-Stamm: Gen. Pl.")
	for group in MORPH.all_groups():
		for unit in MORPH.units_of_group(group):
			assert_str(MORPH.group_of(unit)).is_equal(group)
	assert_array(MORPH.units_of_group("decl.3")).contains(["decl.3_i.gen_pl", "decl.3_in.abl_sg"])
	assert_array(MORPH.units_of_group("perf")).has_size(5)


func test_form_types_of_written_out_cells() -> void:
	assert_str(MORPH.form_type_of("decl.gen_sg")).is_equal("la_genitive")
	assert_str(MORPH.form_type_of("decl.abl_pl")).is_equal("la_abl_pl")
	assert_str(MORPH.form_type_of("pres.2sg")).is_equal("la_pres_2sg")
	assert_str(MORPH.form_type_of("imp.sg")).is_equal("la_imp_sg")



func test_the_table_shows_shared_endings_in_every_column() -> void:
	assert_str(MORPH.unit_at("decl", "3_i", 5)).is_equal("decl.3_i.gen_pl")
	assert_str(MORPH.unit_at("decl", "3_n", 0)).is_equal("decl.3.gen_sg")
	assert_str(MORPH.unit_at("perf", "a", 4)).is_equal("perf.3pl")
	assert_str(MORPH.ending_text("decl", "a", 5)).is_equal("-ārum")
	assert_str(MORPH.ending_text("decl", "o_n", 2)).is_equal("= Nom.")
	assert_str(MORPH.ending_text("perf", "cons", 0)).is_equal("-istī")
