extends GdUnitTestSuite
## Die Plakette oben rechts in Menü und Bibliothek: sie zeigt das aktive Profil, schreibt
## nichts und erklärt ihren Knopf über `Hints`.

const BADGE_SCENE := preload("res://scenes/ui/profile_badge.tscn")


func _badge() -> ProfileBadge:
	var badge := auto_free(BADGE_SCENE.instantiate()) as ProfileBadge
	add_child(badge)
	return badge


func test_it_shows_name_gold_and_level_of_the_active_profile() -> void:
	var badge := _badge()
	assert_str((badge.get_node("%ProfileLabel") as Label).text).is_equal(
			UserSettings.display_name())
	assert_str((badge.get_node("%GoldLabel") as Label).text).is_equal(Wallet.digits())
	assert_str((badge.get_node("%LevelLabel") as Label).text).is_equal(
			str(int(PlayerLevel.progress()["level"])))


func test_the_medallion_names_xp_and_open_skill_points() -> void:
	var badge := _badge()
	var hint := Hints.hint_of(badge.get_node("%Medallion") as Control)
	assert_str(str(hint.get("body", ""))).contains("XP")
	assert_str(str(hint.get("note", ""))).is_equal(
			ProfileBadge.points_text(SkillBook.available(), SkillBook.unlimited_points))
	assert_str(ProfileBadge.points_text(1)).is_equal("1 Skillpunkt offen")
	assert_str(ProfileBadge.points_text(3)).is_equal("3 Skillpunkte offen")
	assert_str(ProfileBadge.points_text(3, true)).is_equal("∞ Skillpunkte (Debug)")


func test_the_switch_is_a_button_that_explains_itself() -> void:
	var badge := _badge()
	var fired := [0]
	badge.switch_pressed.connect(func() -> void: fired[0] += 1)
	var button := badge.get_node("%SwitchButton") as BaseButton
	assert_str(str(Hints.hint_of(button).get("title", ""))).is_equal("Profil wechseln")
	button.pressed.emit()
	assert_int(fired[0]).is_equal(1)


## Die Plakette passt in die Spalte des Menüs und kommt nicht über den alten Platz hinaus.
func test_it_keeps_its_size() -> void:
	var badge := _badge()
	assert_float(badge.custom_minimum_size.x).is_less_equal(352.0)
	assert_float(badge.custom_minimum_size.y).is_less_equal(176.0)


func test_gold_digits_group_by_thousands() -> void:
	assert_str(Wallet.digits(0)).is_equal("0")
	assert_str(Wallet.digits(1250)).is_equal("1.250")
	assert_str(Wallet.digits(999999)).is_equal("999.999")


## Im Hauptmenü stehen Fähigkeiten und Statistik als eigene Knöpfe; außerhalb (kompakt)
## bleibt nur der Ring, kleiner zur rechten oberen Ecke hin. Daneben stehen Profil
## wechseln, Fähigkeiten und Statistik; Name und Gold sagt die Karte am Ring.
func test_compact_keeps_the_ring_with_three_buttons_beside_it() -> void:
	var badge := _badge()
	var actions := badge.get_node("%Actions") as Control
	assert_bool(actions.visible).is_false()
	assert_float(badge.scale.x).is_equal(1.0)
	badge.compact = 1.0
	assert_bool(actions.visible).is_true()
	for part in ["%Plates", "%ProfileLabel", "%GoldLabel", "%SwitchButton"]:
		assert_bool((badge.get_node(part) as Control).visible).is_false()
	var medallion := badge.get_node("%Medallion") as Control
	var slot := badge.get_node("%ActionsSlot") as Control
	assert_float(slot.position.x + actions.position.x + actions.size.x) \
			.is_less_equal(medallion.position.x)
	assert_float(badge.scale.x).is_equal_approx(badge.compact_scale, 0.001)
	assert_float(badge.scale.y).is_equal_approx(badge.compact_scale, 0.001)
	assert_vector(badge.pivot_offset).is_equal(Vector2(badge.custom_minimum_size.x, 0.0))
	var hint := Hints.hint_of(medallion)
	assert_str(str(hint.get("title", ""))).contains(UserSettings.display_name())
	assert_str(str(hint.get("note", ""))).contains(Wallet.label())
	for pair in [["%CompactSwitchButton", "Profil wechseln"], ["%SkillsButton", "Fähigkeiten"],
			["%StatsButton", "Statistik"]]:
		assert_str(str(Hints.hint_of(badge.get_node(pair[0]) as Control).get("title", ""))) \
				.is_equal(pair[1])
	var fired := [0]
	badge.switch_pressed.connect(func() -> void: fired[0] += 1)
	(badge.get_node("%CompactSwitchButton") as BaseButton).pressed.emit()
	assert_int(fired[0]).is_equal(1)


## Buch- und Gebietskarte tragen dieselbe Plakette, von Anfang an kompakt.
func test_the_maps_carry_the_compact_badge() -> void:
	for path in [MapSelection.BOOK_SCENE, MapSelection.AREA_SCENE]:
		var screen := auto_free((load(path) as PackedScene).instantiate()) as Control
		var badge := screen.get_node("%ProfileBadge") as ProfileBadge
		assert_float(badge.compact).is_equal(1.0)
