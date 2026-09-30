extends GdUnitTestSuite
## Die Rüstungszeile der Festungstafel: da, wenn der Bollwerk-Baum gelernt ist, und sonst
## nicht — und in keinem Fall ändert die Tafel ihre Größe.
##
## Die Tafel hat Platz für zwei Zeilen (Rüstung über HP). Ohne Rüstung steht die HP-Zeile
## mittig in derselben Tafel: wüchse sie mit der Rüstung, spränge die Namensplakette
## darunter, und rechts daneben steht die Wellentafel (tests/hud_header_test.gd).

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


func _armor_row(hud: Control) -> Control:
	return hud.get_node("%ArmorRow") as Control


func _fortress_size(hud: Control) -> Vector2:
	return (hud.get_node("%FortressPanel") as Control).size


## Der Normalfall: ohne gelernten Baum gibt es keine Leiste. Eine leere wäre ein
## Versprechen auf etwas, das es nicht gibt.
func test_without_the_skill_there_is_no_armor_bar() -> void:
	GameState.apply_skills({})
	assert_bool(_armor_row(_hud()).visible).is_false()


func test_with_the_skill_the_bar_shows_the_full_supply() -> void:
	GameState.apply_skills({"fortress_armor": 40})
	var hud := _hud()
	var bar := _armor_bar(hud)
	assert_bool(_armor_row(hud).visible).is_true()
	assert_float(bar.max_value).is_equal(40.0)
	assert_float(bar.value).is_equal(40.0)
	assert_str((hud.get_node("%ArmorText") as Label).text).is_equal("40 / 40")


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


## Mit und ohne Rüstung dieselbe Tafel — auch mit dreistelligem Vorrat.
func test_the_armor_row_does_not_resize_the_fortress_plate() -> void:
	GameState.apply_skills({})
	var bare := _hud()
	GameState.apply_skills({"fortress_armor": 999})
	var armored := _hud()
	for i in 4:
		await get_tree().process_frame
	assert_bool(_armor_row(armored).visible).is_true()
	assert_vector(_fortress_size(armored)).is_equal(_fortress_size(bare))
