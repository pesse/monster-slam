extends GdUnitTestSuite
## Die Schatzkiste: aufdrücken, loslassen, platzen.
##
## Geprüft über die öffentlichen begin_hold/hold/cancel_hold — `_process` entscheidet im
## Spiel nur, ob gerade gedrückt wird, und der Test soll nicht zwei Sekunden warten oder
## eine Maus haben müssen. Der Szenen-Test baut die Kiste einmal auf, damit ein Tippfehler
## in der handgeschriebenen .tscn auffällt.

const CHEST_SCENE := preload("res://scenes/ui/treasure_chest.tscn")

var _chest: TreasureChest
var _opened: Array = []


func before_test() -> void:
	_chest = auto_free(CHEST_SCENE.instantiate()) as TreasureChest
	add_child(_chest)  # löst _ready aus
	_opened = []
	_chest.opened.connect(func(gold: int) -> void: _opened.append(gold))
	_chest.present(ChestReward.Tier.SILVER, 9)


func test_a_presented_chest_is_closed() -> void:
	assert_bool(_chest.is_open()).is_false()
	assert_float(_chest.progress()).is_equal_approx(0.0, 0.001)


## Die ganze Haltezeit muss zusammenkommen: ein Klick öffnet nichts.
func test_a_short_press_does_not_open_the_chest() -> void:
	_chest.begin_hold()
	_chest.hold(TreasureChest.HOLD_TIME * 0.5)
	assert_bool(_chest.is_open()).is_false()
	assert_array(_opened).is_empty()


func test_holding_long_enough_opens_the_chest_and_reports_the_gold() -> void:
	_chest.begin_hold()
	_chest.hold(TreasureChest.HOLD_TIME)
	assert_bool(_chest.is_open()).is_true()
	assert_array(_opened).is_equal([9])


## Loslassen setzt zurück und zählt nicht weiter — „gedrückt halten" heißt gedrückt
## halten, sonst wäre es Klicksammeln.
func test_releasing_early_resets_the_progress() -> void:
	_chest.begin_hold()
	_chest.hold(TreasureChest.HOLD_TIME * 0.8)
	_chest.cancel_hold()
	assert_float(_chest.progress()).is_equal_approx(0.0, 0.001)
	_chest.begin_hold()
	_chest.hold(TreasureChest.HOLD_TIME * 0.5)
	assert_bool(_chest.is_open()).is_false()


## Der Deckel geht nur einmal ab: ein weiterer Griff an die offene Kiste bringt kein
## zweites Mal Gold.
func test_an_open_chest_cannot_be_opened_again() -> void:
	_chest.begin_hold()
	_chest.hold(TreasureChest.HOLD_TIME)
	_chest.begin_hold()
	_chest.hold(TreasureChest.HOLD_TIME)
	assert_array(_opened).is_equal([9])


## Aus der Kiste fliegt genau eine Münze je Goldstück: der Haufen in der Luft ist der
## Fund, und eine gedeckelte Zahl hätte gelogen.
func test_exactly_one_coin_per_gold_flies_out() -> void:
	_chest.present(ChestReward.Tier.GOLD, 100)
	_chest.begin_hold()
	_chest.hold(TreasureChest.HOLD_TIME)
	assert_int(_chest.coins_in_flight()).is_equal(100)
	_chest.present(ChestReward.Tier.WOOD, 1)
	_chest.begin_hold()
	_chest.hold(TreasureChest.HOLD_TIME)
	assert_int(_chest.coins_in_flight()).is_equal(1)


## Eine leere Kiste lässt nichts fliegen — im Spiel kommt sie nicht vor (ChestReward gibt
## mindestens ein Gold aus, sobald es Punkte gab), über die Werkbank aber schon.
func test_an_empty_chest_flies_no_coins() -> void:
	_chest.present(ChestReward.Tier.WOOD, 0)
	_chest.begin_hold()
	_chest.hold(TreasureChest.HOLD_TIME)
	assert_int(_chest.coins_in_flight()).is_equal(0)
	assert_array(_opened).is_equal([0])


## Dieselbe Kiste dient der nächsten Welle wieder: present() stellt eine geschlossene
## hin und räumt die Münzen der vorigen weg.
func test_present_puts_a_fresh_closed_chest_up() -> void:
	_chest.begin_hold()
	_chest.hold(TreasureChest.HOLD_TIME)
	_chest.present(ChestReward.Tier.BRONZE, 4)
	assert_bool(_chest.is_open()).is_false()
	assert_float(_chest.progress()).is_equal_approx(0.0, 0.001)


## Debug-Nahtstellen der Werkbank (scenes/dev/chest_lab.tscn): Münzzahl und Haltezeit
## von Hand. Sie stehen hier mit im Test, weil eine Nahtstelle ohne Prüfung beim nächsten
## Umbau still verschwindet.

## Die Münzzahl ist das Gold — ungedeckelt, und unter Null gibt es keine Münzen.
func test_coin_count_is_the_gold_itself() -> void:
	assert_int(TreasureChest.coin_count(1)).is_equal(1)
	assert_int(TreasureChest.coin_count(9)).is_equal(9)
	assert_int(TreasureChest.coin_count(500)).is_equal(500)
	assert_int(TreasureChest.coin_count(0)).is_equal(0)
	assert_int(TreasureChest.coin_count(-3)).is_equal(0)


func test_a_given_coin_count_wins_over_the_gold() -> void:
	_chest.present(ChestReward.Tier.GOLD, 200, 3)
	_chest.begin_hold()
	_chest.hold(TreasureChest.HOLD_TIME)
	assert_int(_chest.coins_in_flight()).is_equal(3)


func test_the_hold_time_is_adjustable() -> void:
	_chest.hold_time = 0.5
	_chest.begin_hold()
	_chest.hold(0.4)
	assert_bool(_chest.is_open()).is_false()
	_chest.hold(0.2)
	assert_bool(_chest.is_open()).is_true()


## Modell statt Zeichnung (KayKit, siehe assets/models/CREDITS.md).

func _lid_of(node: Node) -> Node3D:
	for child in node.get_children():
		if child is Node3D and child.name.ends_with("_lid"):
			return child as Node3D
		var deeper := _lid_of(child)
		if deeper != null:
			return deeper
	return null


## Jede Güte bekommt ein Modell, und in jedem steckt ein eigener Deckel-Knoten. Ohne den
## gäbe es nichts aufzuklappen — und er heißt je Variante anders, also ist die Suche über
## den Namen der Teil, der leise brechen kann.
func test_every_tier_shows_a_model_with_its_own_lid() -> void:
	for tier in ChestReward.TIER_NAMES.size():
		_chest.present(tier, 5)
		var model := _chest.model()
		assert_object(model).is_not_null()
		assert_object(_lid_of(model)).override_failure_message(
				"Güte %d: kein Deckel-Knoten im Modell" % tier).is_not_null()


## Das Scharnier ist der Ursprung des Deckels: er sitzt oben am hinteren Rand, nicht im
## Modellursprung. Nur deshalb sieht eine Drehung um die X-Achse wie Aufklappen aus.
func test_the_lid_sits_on_its_hinge() -> void:
	_chest.present(ChestReward.Tier.WOOD, 5)
	var lid := _lid_of(_chest.model())
	assert_float(lid.position.y).is_greater(0.1)
	assert_float(lid.position.z).is_less(-0.1)


## Beim Platzen dreht der Deckel auf und hebt sich dabei ab.
func test_the_lid_swings_open_and_lifts_off() -> void:
	_chest.present(ChestReward.Tier.WOOD, 5)
	var lid := _lid_of(_chest.model())
	var closed := lid.position
	_chest.begin_hold()
	_chest.hold(TreasureChest.HOLD_TIME)
	_chest._set_lid(1.0)  # der Tween braucht sonst LID_TIME Sekunden
	assert_float(lid.rotation_degrees.x).is_less(-TreasureChest.LID_OPEN_DEG * 0.9)
	assert_float(lid.position.y).is_greater(closed.y)


## Jede Güte bekommt einen eigenen Beschlag, und das Holz bleibt bei allen dasselbe. Die
## Farbe kommt aus dem Atlas-Feld (TIER_METAL) und nicht aus einem Filter — geprüft wird
## also, in welchen Feldern die UV-Koordinaten des Modells liegen.
## Alle Atlas-Felder, die die Meshes unter `node` benutzen — der Knoten selbst zählt mit,
## denn beim Münz-Modell ist die Wurzel schon das Mesh.
func _uv_cells(node: Node) -> Dictionary:
	var cells := {}
	var mesh := node as MeshInstance3D
	if mesh != null and mesh.mesh != null and mesh.mesh.get_surface_count() > 0:
		for uv in mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV] as PackedVector2Array:
			cells[TreasureChest.cell_of(uv)] = true
	for child in node.get_children():
		cells.merge(_uv_cells(child))
	return cells


func test_every_tier_gets_its_own_metal() -> void:
	var wood := Vector2i(4, 0)  # das Holzfeld des Packs, es darf sich nie verschieben
	for tier in ChestReward.TIER_NAMES.size():
		_chest.present(tier, 5)
		var cells := _uv_cells(_chest.model())
		var metal: Vector2i = TreasureChest.TIER_METAL[tier]
		assert_bool(cells.has(metal)).override_failure_message(
				"Güte %d: kein Vertex im Beschlag-Feld %s (gefunden: %s)"
				% [tier, metal, cells.keys()]).is_true()
		assert_bool(cells.has(wood)).override_failure_message(
				"Güte %d: das Holz ist mit verschoben worden" % tier).is_true()
		assert_int(cells.size()).override_failure_message(
				"Güte %d benutzt %s statt genau zwei Felder" % [tier, cells.keys()]).is_equal(2)


## Der Beschlag der Goldkiste hat genau die Farbe der Münzen, die herausfliegen: dasselbe
## Atlas-Feld. Das ist der Grund, aus dem die Kiste ohne Füllung auskommt.
func test_the_gold_chest_wears_the_colour_of_its_coins() -> void:
	var coin := (load("res://assets/models/props/coin.gltf") as PackedScene).instantiate()
	var cells := _uv_cells(coin)
	coin.free()
	assert_array(cells.keys()).contains([TreasureChest.TIER_METAL[ChestReward.Tier.GOLD]])


## Das Mesh aus dem Pack darf die Umfärbung nicht abbekommen: Godot hält geladene
## Ressourcen im Cache, eine Änderung daran träfe jede weitere Kiste — und jedes andere
## Teil des Packs, das dasselbe Mesh benutzt.
func test_the_metal_recolour_leaves_the_shared_mesh_alone() -> void:
	_chest.present(ChestReward.Tier.GOLD, 5)
	var fresh := (load("res://assets/models/props/chest.gltf") as PackedScene).instantiate()
	var cells := _uv_cells(fresh)
	fresh.free()
	assert_bool(cells.has(TreasureChest.METAL_CELL)).override_failure_message(
			"das Mesh im Ressourcen-Cache wurde umgefärbt: %s" % [cells.keys()]).is_true()


## Die gezeichnete Kiste bleibt erreichbar — für den Vergleich in der Werkbank und als
## Rückfall, wenn das Modell fehlt.
func test_the_drawn_chest_is_still_available() -> void:
	_chest.use_model = false
	_chest.present(ChestReward.Tier.GOLD, 5)
	assert_object(_chest.model()).is_null()
	assert_bool((_chest.get_node("%Stage") as Control).visible).is_false()
	_chest.begin_hold()
	_chest.hold(TreasureChest.HOLD_TIME)
	assert_bool(_chest.is_open()).is_true()
	assert_int(_chest.coins_in_flight()).is_equal(5)


## Eigene 3D-Welt: der Wellenabschluss hängt im Kampf, und ohne das stünde die Kiste
## zwischen den Skeletten und ihr Licht in der Schlacht.
func test_the_stage_keeps_its_own_world() -> void:
	assert_bool((_chest.get_node("%View") as SubViewport).own_world_3d).is_true()
	assert_bool((_chest.get_node("%View") as SubViewport).transparent_bg).is_true()


## Die Kamera muss die Kiste zeigen, und zwar ganz — auch mit aufgeklapptem Deckel, der
## fast die doppelte Höhe braucht. Gemessen wird gegen das WIDGET und nicht gegen den
## Ausschnitt: der ist seit den fliegenden Münzen größer als das Widget (STAGE_PAD), die
## Kiste selbst soll aber in ihrem Platz im Layout bleiben und nicht über die Nachbarn
## ragen. Geprüft an den echten Eckpunkten der Meshes (nicht an ihrer AABB, die zu grob
## ist): jeder Punkt landet über cam.unproject_position im Widget-Rechteck.
##
## Deshalb steht das hier und nicht im Auge des Betrachters: CAM_SIZE, CAM_HEIGHT,
## STAGE_PAD und LID_OPEN_DEG hängen zusammen, und wer einen davon anfasst, merkt es
## sofort.
func _screen_bounds(chest: TreasureChest) -> Rect2:
	var cam := chest.get_node("%Cam") as Camera3D
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for mesh: MeshInstance3D in chest.model().find_children("*", "MeshInstance3D", true, false):
		var verts: PackedVector3Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for v in verts:
			var point := cam.unproject_position(mesh.global_transform * v)
			lo = lo.min(point)
			hi = hi.max(point)
	return Rect2(lo, hi - lo)


func test_the_open_chest_stays_inside_the_widget() -> void:
	# 220×170 ist die Kiste im Wellenabschluss, 340×260 die in der Werkbank.
	for vp: Vector2i in [Vector2i(220, 170), Vector2i(340, 260)]:
		_chest.size = Vector2(vp)  # zieht Ausschnitt und Bildfeld nach (_layout_stage)
		# Das Widget liegt um das Polster versetzt im Ausschnitt.
		var widget := Rect2(_chest.stage_pad(), Vector2(vp))
		for tier in ChestReward.TIER_NAMES.size():
			_chest.present(tier, 5)
			for lid_at: float in [0.0, 0.5, 1.0, 1.1]:  # 1.1: das Überschwingen von TRANS_BACK
				_chest._set_lid(lid_at)
				var box := _screen_bounds(_chest)
				assert_bool(widget.encloses(box)).override_failure_message(
						"Güte %d, Deckel %.1f: %s liegt nicht in %s" % [tier, lid_at, box, widget]).is_true()


## Der Ausschnitt ist größer als das Widget, sonst wären die Münzen im Kistenfenster
## gefangen: ein Control beschneidet seine Kinder nicht, ein SubViewport schon.
func test_the_stage_reaches_beyond_the_widget() -> void:
	_chest.size = Vector2(220, 170)
	var view := _chest.get_node("%View") as SubViewport
	assert_vector(_chest.stage_pad()).is_greater(Vector2.ZERO)
	assert_int(view.size.x).is_greater(220)
	assert_int(view.size.y).is_greater(170)


## Die Münzen sind Modelle und fliegen IN der Welt der Kiste, nicht als Zeichnung darüber.
func test_the_coins_fly_as_models() -> void:
	_chest.present(ChestReward.Tier.GOLD, 7)
	_chest.begin_hold()
	_chest.hold(TreasureChest.HOLD_TIME)
	var layer := _chest.get_node("%Coins3D") as Node3D
	assert_int(layer.get_child_count()).is_equal(7)
	assert_int((_chest.get_node("%Coins") as Control).get_child_count()).is_equal(0)
	for coin in layer.get_children():
		assert_object(coin).is_instanceof(Node3D)
		assert_int((coin as Node3D).find_children("*", "MeshInstance3D", true, false).size()) \
				.override_failure_message("Münze ohne Mesh").is_greater(0)


## Der Bogen muss IM gerenderten Ausschnitt liegen. Sonst würde eine Münze mitten im Flug
## an der Viewport-Kante abgeschnitten — und das Polster (STAGE_PAD) wäre umsonst. Am
## weitesten außen liegt der Gipfel, also wird der geprüft, links und rechts.
func test_the_coin_arc_stays_in_the_picture() -> void:
	_chest.size = Vector2(220, 170)
	var cam := _chest.get_node("%Cam") as Camera3D
	var view := _chest.get_node("%View") as SubViewport
	var picture := Rect2(Vector2.ZERO, Vector2(view.size))
	for side: float in [-0.5, 0.5]:
		for depth: float in [-0.3, 0.3]:
			var peak := TreasureChest.COIN_MOUTH + Vector3(
					side * TreasureChest.COIN_SPREAD, TreasureChest.COIN_RISE.y, depth)
			var at := cam.unproject_position(peak)
			assert_bool(picture.has_point(at)).override_failure_message(
					"Gipfel %s liegt auf %s, außerhalb von %s" % [peak, at, picture]).is_true()


## Gefallen wird unter die Kante des Bildfelds: eine Münze, die im Bild liegen bleibt,
## wäre kein Fund mehr, sondern Müll auf dem Tisch.
func test_the_coins_fall_out_of_the_picture() -> void:
	var bottom := TreasureChest.CAM_HEIGHT - _chest._cam_size() * 0.5
	assert_float(_chest._floor_y()).is_less(bottom)
