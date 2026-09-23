extends GdUnitTestSuite
## Die Rüstungsleiste der Kopfleiste: da, wenn der Bollwerk-Baum gelernt ist, und sonst
## nicht — und in keinem Fall breiter.
##
## Die Kopfleiste ist in der BREITE knapp (tests/hud_header_test.gd: 1152 Pixel, und die
## vier Tafeln passen nur gerade). Die Rüstung kommt deshalb als Streifen ÜBER den
## Lebensbalken und nicht als Zahl daneben. Dieser Test hält beides fest: dass sie
## erscheint, und dass sie die Reihe nicht wachsen lässt.

const HUD_SCENE := preload("res://scenes/ui/hud.tscn")


func before_test() -> void:
	GameState.reset()


func after_test() -> void:
	GameState.reset()


## Ein HUD im Szenenbaum. Es liest beim Bauen den aktuellen GameState — der muss also
## VOR dem Aufruf stehen.
func _hud() -> Control:
	var layer: CanvasLayer = auto_free(CanvasLayer.new())
	add_child(layer)
	var hud := auto_free(HUD_SCENE.instantiate()) as Control
	layer.add_child(hud)
	return hud


func _armor_bar(hud: Control) -> ProgressBar:
	return hud.get_node("%ArmorBar") as ProgressBar


## Breite der Reihe plus der Rand, den der MarginContainer links und rechts abzieht
## (dieselbe Messung wie in tests/hud_header_test.gd).
func _needed_width(hud: Control) -> float:
	var margin := hud.get_node("Margin") as MarginContainer
	var row := hud.get_node("Margin/Row") as HBoxContainer
	return row.get_combined_minimum_size().x \
			+ float(margin.get_theme_constant("margin_left")) \
			+ float(margin.get_theme_constant("margin_right"))


## Der Normalfall: ohne gelernten Baum gibt es keine Leiste. Eine leere wäre ein
## Versprechen auf etwas, das es nicht gibt.
func test_without_the_skill_there_is_no_armor_bar() -> void:
	GameState.apply_skills({})
	assert_bool(_armor_bar(_hud()).visible).is_false()


func test_with_the_skill_the_bar_shows_the_full_supply() -> void:
	GameState.apply_skills({"fortress_armor": 40})
	var bar := _armor_bar(_hud())
	assert_bool(bar.visible).is_true()
	assert_float(bar.max_value).is_equal(40.0)
	assert_float(bar.value).is_equal(40.0)


## Der Anteil ist die Auskunft, die die Leiste ohne Zahl geben muss: „noch Polster" oder
## „gleich geht es ans Leben".
func test_the_bar_empties_with_the_armor() -> void:
	GameState.apply_skills({"fortress_armor": 40})
	var bar := _armor_bar(_hud())
	EventBus.fortress_damaged.emit(30)
	assert_float(bar.value).is_equal(10.0)
	EventBus.fortress_damaged.emit(30)
	assert_float(bar.value).is_equal(0.0)


## Die Instandsetzung am Wellenstart hebt sie wieder an — und das HUD zeigt es sofort, ohne
## dass jemand es anstößt (der Wellenstart hängt am selben Signal wie der Fortschrittsbalken).
func test_a_new_wave_refills_the_bar() -> void:
	GameState.apply_skills({"fortress_armor": 40, "armor_regen": 15})
	var bar := _armor_bar(_hud())
	EventBus.fortress_damaged.emit(40)
	EventBus.wave_started.emit("procedural_2")
	assert_float(bar.value).is_equal(15.0)


## DER Grund für die gestapelte Anordnung: die Rüstung kostet Höhe, nicht Breite. Ginge
## sie neben den Lebensbalken, schöbe sie die Tafel mit Kills und Gold aus dem Bild —
## genau das, was tests/hud_header_test.gd verhindert.
func test_the_armor_bar_does_not_widen_the_header() -> void:
	GameState.apply_skills({})
	var bare := _hud()
	GameState.apply_skills({"fortress_armor": 999})
	var armored := _hud()
	for i in 4:
		await get_tree().process_frame
	assert_bool(_armor_bar(armored).visible).is_true()
	assert_float(_needed_width(armored)).is_equal(_needed_width(bare))
