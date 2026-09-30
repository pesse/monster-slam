extends GdUnitTestSuite
## Die Wortschilder der Monster überdecken sich nicht (WordPlates).
##
## Die Platzsuche ist eine reine Funktion auf Rechtecken und wird hier ohne Kampf, Welle
## und Kamera geprüft; ein Test führt den Weg vom Monster in der Gruppe bis zum Schild.

const MONSTER_SCENE := preload("res://scenes/entities/monster.tscn")
const PLATES_SCENE := preload("res://scenes/ui/word_plates.tscn")
const BOUNDS := Rect2(8.0, 112.0, 1136.0, 420.0)
const GAP := 4.0
const NONE := WordPlates.NO_PREVIOUS


func _none(count: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for i in count:
		out.append(NONE)
	return out


func _assert_apart(placed: Array[Rect2]) -> void:
	for i in placed.size():
		assert_bool(BOUNDS.encloses(placed[i])).override_failure_message(
				"Schild %d liegt außerhalb: %s" % [i, placed[i]]).is_true()
		for j in range(i + 1, placed.size()):
			assert_bool(placed[i].intersects(placed[j])).override_failure_message(
					"Schild %d und %d überdecken sich: %s, %s" % [i, j, placed[i], placed[j]]).is_false()


func test_plates_that_do_not_touch_stay_where_they_are() -> void:
	var wanted: Array[Rect2] = [Rect2(100, 200, 120, 30), Rect2(400, 200, 120, 30)]
	var placed := WordPlates.layout(wanted, _none(2), BOUNDS, GAP)
	assert_array(placed).is_equal(wanted)


## Der erste ist der dringendste (der Festung am nächsten) und behält seinen Platz.
func test_the_first_plate_keeps_its_place_and_the_second_moves_up() -> void:
	var wanted: Array[Rect2] = [Rect2(300, 300, 120, 30), Rect2(310, 305, 120, 30)]
	var placed := WordPlates.layout(wanted, _none(2), BOUNDS, GAP)
	assert_object(placed[0]).is_equal(wanted[0])
	assert_float(placed[1].end.y).is_less_equal(placed[0].position.y - GAP)
	_assert_apart(placed)


## Ein dichter Haufen, auch mit langen Schildern: alle im freien Bereich, keines über
## einem anderen.
func test_a_crowd_does_not_overlap() -> void:
	var wanted: Array[Rect2] = []
	for i in 7:
		wanted.append(Rect2(500 + i * 6, 250 + i * 4, 90 + (i % 3) * 120, 30))
	_assert_apart(WordPlates.layout(wanted, _none(7), BOUNDS, GAP))


## Die Köpfe liegen über dem freien Bereich (Ich-Sicht, nahe Monster): die oberste Reihe
## füllt sich, danach geht es nach unten weiter — nicht übereinander.
func test_heads_above_the_top_spill_downwards() -> void:
	var wanted: Array[Rect2] = []
	for i in 7:
		wanted.append(Rect2(300 + i * 40, -80, 250 + (i % 2) * 150, 51))
	_assert_apart(WordPlates.layout(wanted, _none(7), BOUNDS, GAP))


## Ruhe: ist der Platz aus dem letzten Bild noch frei und nur etwas schlechter als der beste
## (hier 50 statt 34 px über dem Wunschplatz), bleibt das Schild dort.
func test_a_free_previous_place_is_kept() -> void:
	var wanted: Array[Rect2] = [Rect2(300, 300, 120, 30), Rect2(300, 300, 120, 30)]
	var higher := Vector2(0, -50)
	var previous: Array[Vector2] = [NONE, higher]
	var placed := WordPlates.layout(wanted, previous, BOUNDS, GAP)
	assert_vector(placed[1].position).is_equal(wanted[1].position + higher)


## Ist ein anderer Platz deutlich besser, wechselt es doch.
func test_a_much_worse_previous_place_is_left() -> void:
	var wanted: Array[Rect2] = [Rect2(300, 300, 120, 30), Rect2(300, 300, 120, 30)]
	var previous: Array[Vector2] = [NONE, Vector2(124, 0)]
	var placed := WordPlates.layout(wanted, previous, BOUNDS, GAP)
	assert_vector(placed[1].position).is_equal(wanted[1].position + Vector2(0, -34))


## Ein Monster in der Gruppe bekommt ein Schild mit seinem Prompt, der Rand in der Farbe seiner
## Wortart; geht es, geht das Schild.
func test_a_monster_brings_and_takes_its_plate() -> void:
	var world: Node3D = auto_free(Node3D.new())
	add_child(world)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 10, 20)
	world.add_child(camera)
	camera.look_at(Vector3.ZERO)
	camera.make_current()
	var layer: CanvasLayer = auto_free(CanvasLayer.new())
	add_child(layer)
	var plates := PLATES_SCENE.instantiate() as WordPlates
	layer.add_child(plates)
	var monster := MONSTER_SCENE.instantiate() as Monster
	monster.setup({}, {"prompt": "house", "lexeme_type": "verb"}, 1000.0, 0.0)
	world.add_child(monster)
	for i in 3:
		await get_tree().process_frame
	var shown := plates.get_children().filter(func(n: Node) -> bool: return (n as Control).visible)
	assert_int(shown.size()).is_equal(1)
	assert_str((shown[0].get_node("%Text") as Label).text).is_equal("house")
	assert_object((shown[0].get_node("Frame") as Control).self_modulate).is_equal(
			WordTypePalette.color_for("verb"))
	monster.free()
	for i in 3:
		await get_tree().process_frame
	assert_int(plates.get_child_count()).is_equal(0)


## Die Kopfleiste belegt nur die Ecken: zwischen ihnen darf ein Schild bis an den Bildrand
## stehen und muss nicht unter den Kopf rutschen (so geschehen bei Monstern weit hinten).
func test_the_top_between_the_header_plates_is_free() -> void:
	var screen := Rect2(8, 8, 1136, 632)
	var header: Array[Rect2] = [Rect2(12, 16, 440, 100), Rect2(816, 16, 320, 68)]
	var wanted: Array[Rect2] = [Rect2(600, 60, 120, 30), Rect2(610, 50, 90, 30)]
	var placed := WordPlates.layout(wanted, _none(2), screen, GAP, header)
	assert_object(placed[0]).is_equal(wanted[0])
	assert_float(placed[1].end.y).is_less_equal(placed[0].position.y - GAP)


## Über einem Teil der Oberfläche steht kein Schild; zurück kommen nur die Schilder.
func test_a_plate_moves_off_the_hud() -> void:
	var screen := Rect2(8, 8, 1136, 632)
	var input: Array[Rect2] = [Rect2(206, 540, 681, 55)]
	var wanted: Array[Rect2] = [Rect2(400, 560, 120, 30)]
	var placed := WordPlates.layout(wanted, _none(1), screen, GAP, input)
	assert_int(placed.size()).is_equal(1)
	assert_bool(placed[0].intersects(input[0])).is_false()
	assert_float(placed[0].end.y).is_less_equal(input[0].position.y)
