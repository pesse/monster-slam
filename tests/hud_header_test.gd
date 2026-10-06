extends GdUnitTestSuite
## Die Kopfleiste passt in die Grundauflösung — auch spät im Spiel.
##
## Sie besteht aus zwei Tafeln: links die Festung (mit Porträt und Namensplakette), rechts
## die Welle. Beide haben eine feste Breite aus dem Grafikpaket (`assets/ui/gameplay/`);
## wächst eine davon mit ihrem Inhalt, läuft sie in die andere oder aus dem Bild. Im
## Vollbild fällt das zuerst auf: `canvas_items`/`expand` skaliert mit der knapperen Achse
## und dehnt die andere, das Vollbild auf 16:9 ist damit der schmalste Fall.
##
## Geprüft wird gegen die Grundauflösung aus den Projekteinstellungen, nicht gegen eine
## hier hingeschriebene Zahl.

const HUD_SCENE := preload("res://scenes/ui/hud.tscn")

## Ein später Spielstand: Level 27, dreistellige Kills und Meisterungen, eine hohe Welle,
## Rüstung und HP dreistellig, Gold wie im Debug-Build. Die Zahlen sind das, was in der Kopfleiste wächst.
const LATE_GAME := {
	"27": "%LevelText", "288 / 288": "%HpText", "150 / 150": "%ArmorText",
	"Welle 48": "%WaveTitle", "48 / 48": "%WaveText", "999": "%Kills",
	"998": "%Mastered", "999.999.999": "%Gold",
}


func _hud(player_name: String) -> Control:
	var layer: CanvasLayer = auto_free(CanvasLayer.new())
	add_child(layer)
	var hud := auto_free(HUD_SCENE.instantiate()) as Control
	layer.add_child(hud)
	# Die Werte kommen im Spiel aus GameState/PlayerLevel; hier wird das Layout
	# gemessen, nicht das Verbuchen — deshalb direkt in die Labels.
	hud.call("set_player_name", player_name)
	for text in LATE_GAME:
		(hud.get_node(str(LATE_GAME[text])) as Label).text = text
	# Rüstung und Meisterungen stehen nur da, wenn es sie gibt — gemessen wird der breite Fall.
	for node in ["%ArmorRow", "%Book", "%Mastered"]:
		(hud.get_node(node) as Control).visible = true
	return hud


func _base_size() -> Vector2:
	return Vector2(float(ProjectSettings.get_setting("display/window/size/viewport_width", 1152)),
			float(ProjectSettings.get_setting("display/window/size/viewport_height", 648)))


func _rect(hud: Control, node: String) -> Rect2:
	return (hud.get_node(node) as Control).get_global_rect()


func test_the_late_game_does_not_widen_the_plates() -> void:
	var hud := _hud("Maximiliane")
	for i in 4:
		await get_tree().process_frame
	for node in ["%FortressPanel", "%EncounterPanel"]:
		var panel := hud.get_node(node) as Control
		assert_float(panel.size.x).override_failure_message(
				"%s wächst mit dem Inhalt: %.0f statt %.0f" % [node, panel.size.x,
				panel.custom_minimum_size.x]).is_equal(panel.custom_minimum_size.x)
		assert_float(panel.size.y).is_equal(panel.custom_minimum_size.y)


func test_the_plates_fit_side_by_side() -> void:
	var hud := _hud("Bartholomäus-Maximilian von Hohenstein")
	for i in 4:
		await get_tree().process_frame
	var left := _rect(hud, "%FortressPanel").merge(_rect(hud, "%NamePanel"))
	var right := _rect(hud, "%EncounterPanel")
	# Das HUD füllt das Fenster; kopflos ist es so breit wie die Grundauflösung.
	assert_float(hud.size.x).is_equal(_base_size().x)
	assert_float(left.position.x).is_greater_equal(0.0)
	assert_float(right.end.x).is_less_equal(_base_size().x)
	assert_float(left.end.x).is_less(right.position.x)


## Der Profilname ist der einzige Teil der Kopfleiste, dessen Breite der Spieler
## bestimmt. Die Plakette wächst mit ihm, aber nur bis zur Breite der Festungstafel —
## danach wird abgekürzt, die Schrift bleibt.
func test_the_name_plate_follows_the_name_up_to_the_fortress_width() -> void:
	var short_hud := _hud("Sam")
	var long_hud := _hud("Bartholomäus-Maximilian von Hohenstein")
	for i in 4:
		await get_tree().process_frame
	var fortress := _rect(long_hud, "%FortressPanel").size.x
	var short_plate := _rect(short_hud, "%NamePanel").size.x
	var long_plate := _rect(long_hud, "%NamePanel").size.x
	assert_float(short_plate).is_less(long_plate)
	assert_float(long_plate).is_less_equal(fortress)
