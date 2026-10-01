extends GdUnitTestSuite
## Umhängen in der Skilltree-Werkbank (src/dev/skill_rewire.gd): der Ast rückt mit, die
## Datenregeln bleiben erfüllt, und Speichern ändert an unberührten Dateien kein Byte.

const REWIRE := preload("res://src/dev/skill_rewire.gd")


func _skill(id: String, tree: String, tier: int, branch: int, requires: Array = []) -> Dictionary:
	return {"id": id, "kind": "skill", "tree": tree, "tier": tier, "branch": branch,
			"requires": requires}


## a(1) ─ b(2) ─ c(3) ─ d(4)          x(1) ─ y(2)
##      └ e(2, Ast 1)
func _forest() -> Array:
	return [
		_skill("a", "t1", 1, 0),
		_skill("b", "t1", 2, 0, ["a"]),
		_skill("c", "t1", 3, 0, ["b"]),
		_skill("d", "t1", 4, 0, ["c"]),
		_skill("e", "t1", 2, 1, ["a"]),
		_skill("x", "t2", 1, 0),
		_skill("y", "t2", 2, 0, ["x"]),
	]


func test_the_node_sits_one_tier_behind_its_new_parent() -> void:
	var entries := _forest()
	var result := REWIRE.reparent(entries, "d", "e")
	assert_bool(result["ok"]).is_true()
	var d := SkillTree.node_by_id(entries, "d")
	assert_array(d["requires"]).is_equal(["e"])
	assert_int(d["tier"]).is_equal(3)
	# Stufe 3 Ast 0 hat c — d weicht auf den Ast seiner Vorstufe aus.
	assert_int(d["branch"]).is_equal(1)
	assert_array(result["moved"]).contains(["d"])


func test_the_branch_above_moves_along() -> void:
	var entries := _forest()
	assert_bool(REWIRE.reparent(entries, "c", "y")["ok"]).is_true()
	var c := SkillTree.node_by_id(entries, "c")
	var d := SkillTree.node_by_id(entries, "d")
	assert_str(c["tree"]).is_equal("t2")
	assert_int(c["tier"]).is_equal(3)
	assert_str(d["tree"]).is_equal("t2")
	assert_int(d["tier"]).is_equal(4)
	assert_array(d["requires"]).is_equal(["c"])


func test_a_branch_moving_inward_shifts_down() -> void:
	var entries := _forest()
	assert_bool(REWIRE.reparent(entries, "c", "a")["ok"]).is_true()
	assert_int(SkillTree.node_by_id(entries, "c")["tier"]).is_equal(2)
	assert_int(SkillTree.node_by_id(entries, "d")["tier"]).is_equal(3)
	assert_bool(_places_unique(entries)).is_true()


func test_a_cycle_is_refused() -> void:
	var entries := _forest()
	var before := str(entries)
	var result := REWIRE.reparent(entries, "b", "d")
	assert_bool(result["ok"]).is_false()
	assert_str(str(entries)).is_equal(before)


func test_a_root_and_a_self_link_are_refused() -> void:
	var entries := _forest()
	assert_bool(REWIRE.reparent(entries, "a", "y")["ok"]).is_false()
	assert_bool(REWIRE.reparent(entries, "b", "b")["ok"]).is_false()
	assert_bool(REWIRE.reparent(entries, "b", "a")["ok"]).is_false()
	assert_bool(REWIRE.reparent(entries, "b", "zz")["ok"]).is_false()


## f hängt an d (im Ast) und an g (außerhalb, Stufe 4).
func _forest_with_a_double_link() -> Array:
	var entries := _forest()
	entries.append(_skill("g", "t1", 4, 1, ["e"]))
	entries.append(_skill("f", "t1", 5, 0, ["d", "g"]))
	return entries


func test_a_second_requirement_keeps_the_node_behind_both() -> void:
	var entries := _forest_with_a_double_link()
	assert_bool(REWIRE.reparent(entries, "c", "a")["ok"]).is_true()
	# Der Ast rückt eine Stufe nach innen, f bliebe aber nicht hinter g (Stufe 4).
	assert_int(SkillTree.node_by_id(entries, "d")["tier"]).is_equal(3)
	assert_int(SkillTree.node_by_id(entries, "f")["tier"]).is_equal(5)
	assert_bool(_places_unique(entries)).is_true()


func test_a_branch_with_a_foreign_link_stays_in_its_tree() -> void:
	var entries := _forest_with_a_double_link()
	var before := str(entries)
	assert_bool(REWIRE.reparent(entries, "c", "y")["ok"]).is_false()
	assert_str(str(entries)).is_equal(before)


## Die Werkbank schreibt nur, was sich geändert hat — und der Text einer unberührten Datei
## ist genau der im Repo. Sonst wäre jedes Speichern ein Diff über alle Skill-Dateien.
func test_the_shipped_files_survive_a_round_trip() -> void:
	var files := REWIRE.load_files()
	assert_dict(files).is_not_empty()
	for path: String in files:
		assert_str(REWIRE.to_text(files[path])).override_failure_message(
				"Speichern änderte " + path).is_equal(FileAccess.get_file_as_string(path))


func _places_unique(entries: Array) -> bool:
	var seen := {}
	for entry in entries:
		var key := "%s/%d/%d" % [entry["tree"], int(entry["tier"]), int(entry["branch"])]
		if seen.has(key):
			return false
		seen[key] = true
	return true
