extends GdUnitTestSuite
## Die Regeln der Fähigkeitsbäume: Verzweigung, Voraussetzungen, Kosten, Boni.
##
## Geprüft wird an einem ERFUNDENEN Baum, nicht an den ausgelieferten Daten: die Regeln
## sollen gelten, wenn die Bäume später wachsen, und ein Test, der an den echten Zahlen
## hängt, fällt bei jeder Balance-Änderung grundlos um. Was die echten Daten angeht,
## prüft tests/skill_data_test.gd.
##
## SkillTree ist statisch und zustandslos — kein Autoload, keine Szene, kein Aufräumen.

## Ein Baum mit Wurzel und zwei Ästen, so wie alle ausgelieferten gebaut sind.
const TREE := "tree.test"

var _entries: Array = []


func before_test() -> void:
	_entries = [
		{"id": TREE, "kind": "tree", "order": 2, "name": "Prüfbaum"},
		{"id": "tree.other", "kind": "tree", "order": 1, "name": "Anderer"},
		_node("root", 1, 0, 1, [], {"heal_per_correct": 1}),
		_node("left", 2, 0, 1, ["skill.test.root"], {"heal_per_correct": 1}),
		_node("right", 2, 1, 1, ["skill.test.root"], {"fortress_armor": 10}),
		_node("left2", 3, 0, 2, ["skill.test.left"], {"heal_per_correct": 2}),
		_node("right2", 3, 1, 3, ["skill.test.right"], {"fortress_armor": 25}),
	]


func _node(name: String, tier: int, branch: int, cost: int, requires: Array,
		effects: Dictionary) -> Dictionary:
	return {
		"id": "skill.test.%s" % name, "kind": "skill", "tree": TREE,
		"tier": tier, "branch": branch, "name": name.capitalize(),
		"cost": cost, "requires": requires, "effects": effects,
	}


func _ids(nodes: Array) -> Array:
	var out: Array = []
	for node in nodes:
		out.append(str((node as Dictionary).get("id", "")))
	return out


# --- Aufbau ------------------------------------------------------------------

## Bäume kommen in ihrer `order`, nicht in der Reihenfolge der Dateien — sonst hinge die
## Anordnung im Screen davon ab, wie das Dateisystem sortiert.
func test_trees_come_in_their_order() -> void:
	assert_array(_ids(SkillTree.trees(_entries))).is_equal(["tree.other", TREE])


## Die Knoten selbst sind keine Bäume: ein Screen, der beides mischt, zeichnet Überschriften
## als Karten.
func test_only_tree_heads_are_trees() -> void:
	assert_int(SkillTree.trees(_entries).size()).is_equal(2)


## DAS Merkmal der Bäume: eine Stufe trägt mehrere Knoten nebeneinander. Die Wurzel steht
## allein, darunter liegen die Äste — nach `branch` sortiert, damit ein Ast über alle
## Stufen hinweg in derselben Spalte bleibt.
func test_a_tier_carries_the_branches_side_by_side() -> void:
	var tiers := SkillTree.tiers_of(_entries, TREE)
	assert_int(tiers.size()).is_equal(3)
	assert_array(_ids(tiers[0])).is_equal(["skill.test.root"])
	assert_array(_ids(tiers[1])).is_equal(["skill.test.left", "skill.test.right"])
	assert_array(_ids(tiers[2])).is_equal(["skill.test.left2", "skill.test.right2"])


## Ein zweiter Baum darf daneben stehen, ohne sich einzumischen.
func test_tiers_of_ignores_other_trees() -> void:
	assert_array(SkillTree.tiers_of(_entries, "tree.other")).is_empty()


# --- Voraussetzungen ---------------------------------------------------------

## Eine Wurzel hat keine Vorstufe.
func test_a_root_is_learnable_right_away() -> void:
	var root := SkillTree.node_by_id(_entries, "skill.test.root")
	assert_bool(SkillTree.can_unlock(root, PackedStringArray(), 1)).is_true()


func test_a_branch_needs_its_root() -> void:
	var left := SkillTree.node_by_id(_entries, "skill.test.left")
	assert_bool(SkillTree.can_unlock(left, PackedStringArray(), 9)).is_false()
	assert_bool(SkillTree.can_unlock(left, PackedStringArray(["skill.test.root"]), 9)).is_true()


## Der Kern der Verzweigung: ein Ast lässt sich ausbauen, ohne den anderen anzufassen —
## und der Knoten des einen Astes schaltet den anderen NICHT frei. Ohne das wäre der
## Baum eine Kette mit zwei Spalten.
func test_one_branch_does_not_unlock_the_other() -> void:
	var learned := PackedStringArray(["skill.test.root", "skill.test.left"])
	var left2 := SkillTree.node_by_id(_entries, "skill.test.left2")
	var right2 := SkillTree.node_by_id(_entries, "skill.test.right2")
	assert_bool(SkillTree.can_unlock(left2, learned, 9)).is_true()
	assert_bool(SkillTree.can_unlock(right2, learned, 9)).is_false()


## Ein gesperrter Knoten nennt seine Vorstufe beim NAMEN, nicht bei der Id: mit zwei Ästen
## nebeneinander ist sonst nicht zu sehen, welcher woran hängt.
func test_the_missing_requirement_is_named() -> void:
	var left := SkillTree.node_by_id(_entries, "skill.test.left")
	assert_str(SkillTree.missing_requirement(_entries, left, PackedStringArray())).is_equal("Root")
	assert_str(SkillTree.missing_requirement(_entries, left,
			PackedStringArray(["skill.test.root"]))).is_empty()


## Zweimal dasselbe lernen gibt es nicht — sonst kostete ein Doppelklick zwei Punkte.
func test_a_learned_skill_is_not_learnable_again() -> void:
	var root := SkillTree.node_by_id(_entries, "skill.test.root")
	assert_bool(SkillTree.can_unlock(root, PackedStringArray(["skill.test.root"]), 9)).is_false()


# --- Punkte ------------------------------------------------------------------

## Große Skills kosten mehrere Punkte — und reichen die Punkte nicht, ist der Knoten
## trotz erfüllter Vorstufe nicht lernbar.
func test_a_big_skill_needs_its_points() -> void:
	var right2 := SkillTree.node_by_id(_entries, "skill.test.right2")
	var learned := PackedStringArray(["skill.test.root", "skill.test.right"])
	assert_int(SkillTree.cost(right2)).is_equal(3)
	assert_bool(SkillTree.can_unlock(right2, learned, 2)).is_false()
	assert_bool(SkillTree.can_unlock(right2, learned, 3)).is_true()


func test_spent_adds_up_the_costs() -> void:
	assert_int(SkillTree.spent(_entries, PackedStringArray())).is_equal(0)
	assert_int(SkillTree.spent(_entries,
			PackedStringArray(["skill.test.root", "skill.test.right", "skill.test.right2"])
	)).is_equal(5)


## Eine Id, die die Inhalte nicht kennen (Pack deinstalliert), zählt weder als Ausgabe
## noch als Bonus — sonst wären das bezahlte Punkte für nichts.
func test_an_unknown_id_costs_nothing_and_does_nothing() -> void:
	var ghost := PackedStringArray(["skill.test.root", "skill.from.a.removed.pack"])
	assert_int(SkillTree.spent(_entries, ghost)).is_equal(1)
	assert_float(SkillTree.bonuses(_entries, ghost)["heal_per_correct"]).is_equal(1.0)


# --- Boni --------------------------------------------------------------------

## Alle Werte sind ADDITIV — es gibt keine Frage „welcher Knoten gewinnt", nur eine Summe.
func test_bonuses_are_summed_per_effect() -> void:
	var learned := PackedStringArray([
		"skill.test.root", "skill.test.left", "skill.test.left2",
		"skill.test.right", "skill.test.right2"])
	var bonuses := SkillTree.bonuses(_entries, learned)
	assert_float(bonuses["heal_per_correct"]).is_equal(4.0)
	assert_float(bonuses["fortress_armor"]).is_equal(35.0)


## Jeder bekannte Schlüssel kommt vor, auch ohne gelernten Knoten: die Anwender lesen ihn
## mit `get(key, 0)` und sollen keinen Sonderfall für „noch nichts gelernt" brauchen.
func test_every_effect_key_is_present_even_when_nothing_is_learned() -> void:
	var bonuses := SkillTree.bonuses(_entries, PackedStringArray())
	for key in SkillTree.EFFECT_KEYS:
		assert_bool(bonuses.has(key)).is_true()
		assert_float(bonuses[key]).is_equal(0.0)


## Ein Tippfehler in den Daten wirkt nicht versehentlich woanders — er wirkt gar nicht.
func test_an_unknown_effect_key_is_ignored() -> void:
	var entries: Array = [{
		"id": "skill.typo", "kind": "skill", "tree": TREE, "tier": 1, "branch": 0,
		"cost": 1, "requires": [], "effects": {"heal_per_corect": 5},
	}]
	assert_float(SkillTree.bonuses(entries, PackedStringArray(["skill.typo"]))
			["heal_per_correct"]).is_equal(0.0)


# --- Umlernen ----------------------------------------------------------------

func test_respec_is_priced_per_point() -> void:
	assert_int(SkillTree.respec_cost(6)).is_equal(6 * SkillTree.RESPEC_GOLD_PER_POINT)


## Ohne ausgegebene Punkte gibt es nichts zurückzunehmen — und nichts zu bezahlen.
func test_respec_without_spent_points_is_free() -> void:
	assert_int(SkillTree.respec_cost(0)).is_equal(0)
	assert_int(SkillTree.respec_cost(-3)).is_equal(0)
