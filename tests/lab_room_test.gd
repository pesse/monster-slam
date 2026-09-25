extends GdUnitTestSuite
## Die Werkbänke dürfen größer sein als das Spiel — und sie müssen in das, was sie sich
## nehmen, auch hineinpassen.
##
## Der Anlass: `canvas_items`/`expand` skaliert das Bild, statt Platz zu geben. Wer eine
## überlaufende Werkbank durch Ziehen am Fensterrand retten will, zieht ins Leere; erst
## Fenster UND Bezugsgröße zusammen geben Raum. Genau das ist eine Aussage über Zahlen und
## gehört damit gerechnet und nicht am Bildschirm beurteilt — wie
## `test_the_defeat_screen_fits_into_the_base_resolution`.
##
## Geprüft wird gegen die MINDESTgröße: sie ist das, was die Werkbank braucht, egal wie
## lang ein Modell antwortet.

const LABS := [
	"res://scenes/dev/boss_lab.tscn",
	"res://scenes/dev/chest_lab.tscn",
]


## Die Werkbank ist ein Gast: sie nimmt sich das Fenster und gibt es zurück. Ohne das
## Zurückgeben stünde das Spiel nach einem Blick in die Werkbank verkleinert da.
func test_a_lab_takes_the_window_and_gives_it_back() -> void:
	var window := get_window()
	var before := window.content_scale_size
	var lab: Control = auto_free(load(LABS[0]).instantiate()) as Control
	add_child(lab)
	assert_vector(Vector2(window.content_scale_size)) \
			.is_equal(Vector2(LabRoom.fitting(window)))
	assert_int(window.content_scale_size.x).is_greater(LabRoom.game_size().x)
	remove_child(lab)
	assert_vector(Vector2(window.content_scale_size)).is_equal(Vector2(before))


## Auf einem kleinen Schirm ist ein Fenster, dessen untere Hälfte hinter der Taskleiste
## liegt, kein größeres Fenster — und kleiner als das Spiel wird es nie.
func test_the_room_never_falls_below_the_game() -> void:
	var fits := LabRoom.fitting(get_window())
	assert_int(fits.x).is_greater_equal(LabRoom.game_size().x)
	assert_int(fits.y).is_greater_equal(LabRoom.game_size().y)
	assert_int(fits.x).is_less_equal(LabRoom.SIZE.x)
	assert_int(fits.y).is_less_equal(LabRoom.SIZE.y)


## Und das, wofür der Platz da ist: jede Werkbank passt hinein. Die Achsen einzeln, weil
## `assert_vector(...).is_less_equal(...)` Vektoren lexikografisch vergleicht — zu hoch
## wäre sonst über die Breite durchgerutscht (dieselbe Falle wie beim Niederlage-Screen).
func test_every_lab_fits_into_the_room() -> void:
	for path in LABS:
		var lab: Control = auto_free(load(path).instantiate()) as Control
		add_child(lab)
		await get_tree().process_frame
		var needs := (lab.get_node("Margin") as Control).get_combined_minimum_size()
		assert_float(needs.x).override_failure_message(
				"%s braucht %d Pixel Breite, die Werkbank hat %d" % [
					path, needs.x, LabRoom.SIZE.x]).is_less_equal(float(LabRoom.SIZE.x))
		assert_float(needs.y).override_failure_message(
				"%s braucht %d Pixel Höhe, die Werkbank hat %d" % [
					path, needs.y, LabRoom.SIZE.y]).is_less_equal(float(LabRoom.SIZE.y))
		remove_child(lab)
