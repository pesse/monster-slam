extends GdUnitTestSuite
## Die Kopfleiste passt in die Grundauflösung — auch spät im Spiel.
##
## Sie steht in einer Reihe über die ganze Breite und wird nicht gescrollt: was breiter
## ist als das Bild, hängt rechts heraus, und rechts steht die Tafel mit Kills und Meisterungen.
## Genau das war im Vollbild zu sehen. Im Fenster fiel es nicht auf, weil ein maximiertes
## Fenster (16:9-Bildschirm minus Titelleiste) dem Spiel MEHR Breite gibt als die
## Grundauflösung: `canvas_items`/`expand` skaliert mit der knapperen Achse und dehnt die
## andere. Das Vollbild ist damit der schmalste Fall, nicht der breiteste.
##
## Geprüft wird die Mindestbreite der Reihe gegen die Grundauflösung aus den
## Projekteinstellungen, nicht gegen eine hier hingeschriebene Zahl.

const HUD_SCENE := preload("res://scenes/ui/hud.tscn")

## Ein später Spielstand: Level 27, dreistellige Kills und Meisterungen. Die Zahlen
## sind das, was in der Kopfleiste wächst — der Rest steht fest.
##
## Die Rüstung des Bollwerk-Baums steht hier NICHT als Text: sie hat keinen, und dieser
## Test ist der Grund. Ein „🛡90" am HP-Text kostete die Reihe 1153 Pixel, ein dreistelliger
## Wert 1159 — die Rüstungsleiste liegt deshalb ÜBER dem Lebensbalken und trägt die
## Auskunft allein (siehe tests/hud_armor_test.gd).
const LATE_GAME := {
	"⭐ 27": "%LevelText", "2340/2700": "%XpText", "288/288": "%HpText",
	"48/48": "%WaveText", "💀 999": "%Kills", "🏅 999": "%Mastered",
}


func _hud(player_name: String) -> Control:
	var layer: CanvasLayer = auto_free(CanvasLayer.new())
	add_child(layer)
	var hud := auto_free(HUD_SCENE.instantiate()) as Control
	layer.add_child(hud)
	# Die Werte kommen im Spiel aus GameState/PlayerLevel; hier wird das Layout
	# gemessen, nicht das Verbuchen — deshalb direkt in die Labels.
	(hud.get_node("%PlayerName") as Label).text = player_name
	for text in LATE_GAME:
		(hud.get_node(str(LATE_GAME[text])) as Label).text = text
	# Die Meisterungen stehen nur da, wenn es welche gibt — gemessen wird der breite Fall.
	(hud.get_node("%Mastered") as Label).visible = true
	return hud


## Breite der Reihe plus der Rand, den der MarginContainer links und rechts abzieht.
func _needed_width(hud: Control) -> float:
	var margin := hud.get_node("Margin") as MarginContainer
	var row := hud.get_node("Margin/Row") as HBoxContainer
	return row.get_combined_minimum_size().x \
			+ float(margin.get_theme_constant("margin_left")) \
			+ float(margin.get_theme_constant("margin_right"))


func test_the_header_fits_the_base_resolution() -> void:
	var hud := _hud("👤 Maximiliane")
	for i in 4:
		await get_tree().process_frame
	var base_width := float(ProjectSettings.get_setting("display/window/size/viewport_width", 1152))
	assert_float(_needed_width(hud)).is_less_equal(base_width)


## Der Profilname ist der einzige Teil der Kopfleiste, dessen Breite der Spieler
## bestimmt. Er steht deshalb in einem Feld fester Breite und wird abgekürzt — sonst
## schiebt ein langer Name die Tafel mit Kills und Meisterungen wieder aus dem Bild.
func test_a_long_player_name_does_not_widen_the_header() -> void:
	var short_hud := _hud("👤 Sam")
	var long_hud := _hud("👤 Bartholomäus-Maximilian")
	for i in 4:
		await get_tree().process_frame
	assert_float(_needed_width(long_hud)).is_equal(_needed_width(short_hud))
