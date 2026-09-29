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
