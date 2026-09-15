extends GdUnitTestSuite
## Der Fähigkeiten-Screen: er baut sich, zeichnet das Netz, erklärt sich am Zeiger, fragt
## vor dem Buchen nach und passt in die Grundauflösung.
##
## Geprüft wird an einem ERFUNDENEN Baum: der Screen bekommt ein SkillBook untergeschoben,
## dessen `entries()` feste Knoten liefert. Sonst hinge der Test an der Balance der
## ausgelieferten Bäume — und an dem, was auf dem Rechner an Packs installiert ist.
##
## Was er NICHT prüft: das Buchen selbst (tests/skill_book_test.gd), die Regeln
## (tests/skill_tree_test.gd) und die Plätze im Netz (tests/skill_graph_layout_test.gd).
## Hier geht es um das, was man sieht und anfassen kann.

const SCREEN_SCENE := preload("res://scenes/ui/skill_tree.tscn")
const TEST_PROFILE := "zz-skill-screen"

## Wurzel, zwei Äste, und im rechten Ast eine Spitze für 3 Punkte.
class FixedBook extends "res://src/progression/skill_book.gd":
	func entries() -> Array:
		return [
			{"id": "tree.t", "kind": "tree", "order": 1, "name": "Prüfbaum",
				"description": "Ein Baum zum Messen.", "color": "#5fd08a"},
			{"id": "s.root", "kind": "skill", "tree": "tree.t", "tier": 1, "branch": 0,
				"name": "Wurzel", "icon": "🌱", "description": "Fängt an.", "cost": 1,
				"requires": [], "effects": {"heal_per_correct": 1}},
			{"id": "s.left", "kind": "skill", "tree": "tree.t", "tier": 2, "branch": 0,
				"name": "Links", "icon": "⬅", "description": "Geht links weiter.",
				"cost": 1, "requires": ["s.root"], "effects": {"heal_per_correct": 1}},
			{"id": "s.right", "kind": "skill", "tree": "tree.t", "tier": 2, "branch": 1,
				"name": "Rechts", "icon": "➡", "description": "Geht rechts weiter.",
				"cost": 3, "requires": ["s.root"], "effects": {"fortress_armor": 25}},
		]


var _book: FixedBook
var _xp_before: int = 0
var _level_before: int = 1
var _level_profile_before: String = ""
var _gold_before: int = 0
var _wallet_profile_before: String = ""


func before_test() -> void:
	_xp_before = PlayerLevel.total_xp
	_level_before = PlayerLevel.level
	_level_profile_before = PlayerLevel.player_id
	_gold_before = Wallet.gold
	_wallet_profile_before = Wallet.player_id
	PlayerLevel.player_id = TEST_PROFILE
	# Die WERTE mitzurücksetzen ist nicht nur Hygiene: `available()` geht an das Autoload,
	# und das trägt beim Testlauf die echte Erfahrung des Entwicklerprofils. Ohne diese
	# zwei Zeilen fiel „ohne Punkte ist der Knoten zu teuer" um, sobald jemand im Spiel
	# ein paar Level gesammelt hatte — ein Test, der am Spielstand des Rechners hängt.
	PlayerLevel.total_xp = 0
	PlayerLevel.level = 1
	Wallet.player_id = TEST_PROFILE
	Wallet.gold = 0
	_remove_files()
	_book = auto_free(FixedBook.new())
	_book.player_id = TEST_PROFILE


func after_test() -> void:
	_remove_files()
	PlayerLevel.player_id = _level_profile_before
	PlayerLevel.total_xp = _xp_before
	PlayerLevel.level = _level_before
	Wallet.player_id = _wallet_profile_before
	Wallet.gold = _gold_before


func _remove_files() -> void:
	for kind: String in ["skills", "wallet", "level"]:
		DirAccess.remove_absolute("user://progress/%s_%s.json" % [TEST_PROFILE, kind])


func _give_points(count: int) -> void:
	PlayerLevel.total_xp = Experience.total_xp_for_level(count + 1)
	PlayerLevel.level = Experience.level_for(PlayerLevel.total_xp)


## Der Screen mit untergeschobenem SkillBook. Die Ersetzung steht VOR dem add_child:
## `_ready()` liest schon daraus.
func _screen() -> Control:
	var screen := auto_free(SCREEN_SCENE.instantiate()) as Control
	screen.set("book", _book)
	add_child(screen)
	return screen


func _graph(screen: Control) -> SkillGraph:
	return screen.get_node("%Graph") as SkillGraph


func _card(screen: Control) -> SkillTooltip:
	return screen.get_node("%Hover") as SkillTooltip


func _dialog(screen: Control) -> ConfirmDialog:
	return screen.get_node("%Confirm") as ConfirmDialog


func _dialog_title(screen: Control) -> String:
	return (_dialog(screen).get_node("%Title") as Label).text


func _dialog_body(screen: Control) -> String:
	return (_dialog(screen).get_node("%Body") as Label).text


func _say_yes(screen: Control) -> void:
	(_dialog(screen).get_node("%ActionButton") as Button).pressed.emit()


func _say_no(screen: Control) -> void:
	(_dialog(screen).get_node("%CancelButton") as Button).pressed.emit()


## Klickt einen Knoten so an, wie der Spieler es tut: Druck und Loslassen auf seinem Kreis.
func _click(screen: Control, at: Vector2) -> void:
	var graph := _graph(screen)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		graph._gui_input(event)


func _click_node(screen: Control, id: String) -> void:
	_click(screen, _graph(screen).screen_position(id))


## Der ganze Weg zum gelernten Knoten: anklicken und die Rückfrage bejahen.
func _learn(screen: Control, id: String) -> void:
	_click_node(screen, id)
	_say_yes(screen)


## Fährt mit der Maus über einen Punkt der Zeichenfläche. `global_position` ist das, woran
## der Screen die Karte ausrichtet — im Spiel liegt die Fläche nicht im Nullpunkt.
func _move(screen: Control, at: Vector2) -> void:
	var graph := _graph(screen)
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = graph.global_position + at
	graph._gui_input(event)


func _move_to(screen: Control, id: String) -> SkillTooltip:
	_move(screen, _graph(screen).screen_position(id))
	return _card(screen)


func _card_text(screen: Control, id: String, part: String) -> String:
	return (_move_to(screen, id).get_node("%" + part) as Label).text


# --- Aufbau ------------------------------------------------------------------

func test_the_screen_finds_its_unique_names() -> void:
	var screen := _screen()
	assert_object(screen.get_node("%BackButton")).is_not_null()
	assert_object(screen.get_node("%PointsLabel")).is_not_null()
	assert_object(screen.get_node("%Graph")).is_not_null()
	assert_object(screen.get_node("%FitButton")).is_not_null()
	assert_object(screen.get_node("%RespecButton")).is_not_null()
	assert_object(screen.get_node("%Hover")).is_not_null()
	assert_object(screen.get_node("%Confirm")).is_not_null()


## Jeder Knoten des Baums liegt im Netz und ist mit der Maus zu treffen — keiner fällt
## beim Zeichnen unter den Tisch.
func test_every_node_is_on_the_canvas() -> void:
	var screen := _screen()
	await get_tree().process_frame
	var graph := _graph(screen)
	for id: String in ["s.root", "s.left", "s.right"]:
		assert_str(graph.id_at(graph.screen_position(id))).override_failure_message(
				"'%s' ist im Netz nicht zu treffen" % id).is_equal(id)


## Der Name eines Baums lässt sich zwar überfahren, aber nicht lernen: er ist kein Knoten.
## Ein Klick darauf öffnet deshalb keine Rückfrage.
func test_the_tree_name_opens_no_dialog() -> void:
	_give_points(5)
	var screen := _screen()
	await get_tree().process_frame
	assert_str(_graph(screen).id_at(_graph(screen).screen_position("tree.t"))
			).is_equal("tree.t")
	_click_node(screen, "tree.t")
	assert_bool(_dialog(screen).visible).is_false()
	assert_array(Array(_book.unlocked)).is_empty()


# --- Auskunft am Zeiger -------------------------------------------------------

## Die Karte ist da, SOBALD die Maus da ist: kein Warten, kein Frame dazwischen. Deshalb
## steht in diesem Test kein `await` — genau das ist die Zusage.
func test_the_card_appears_without_delay() -> void:
	_give_points(1)
	var screen := _screen()
	await get_tree().process_frame
	var card := _move_to(screen, "s.root")
	assert_bool(card.visible).is_true()
	assert_str((card.get_node("%Name") as Label).text).contains("Wurzel").contains("🌱")
	assert_str((card.get_node("%Description") as Label).text).contains("Fängt an")
	assert_str((card.get_node("%Status") as Label).text).contains("Lernen")


## Und sie folgt dem Zeiger, statt an einer festen Stelle zu kleben.
func test_the_card_follows_the_pointer() -> void:
	_give_points(1)
	var screen := _screen()
	await get_tree().process_frame
	var graph := _graph(screen)
	var at := graph.screen_position("s.root")
	_move(screen, at)
	var first := _card(screen).global_position
	_move(screen, at + Vector2(12, 9))
	assert_vector(_card(screen).global_position).is_not_equal(first)
	assert_float(_card(screen).global_position.distance_to(
			graph.global_position + at + Vector2(12, 9))).is_less(120.0)


## Am Rand klappt sie auf die andere Seite des Zeigers: eine halb abgeschnittene Auskunft
## ist keine.
func test_the_card_stays_inside_the_screen() -> void:
	_give_points(1)
	var screen := _screen()
	await get_tree().process_frame
	assert_float(screen.size.x).is_greater(0.0)
	var graph := _graph(screen)
	# Den Knoten erst überfahren, dann den Zeiger in die Ecke ziehen: die Karte hängt am
	# zuletzt gemeldeten Knoten, ihre Lage am zuletzt gemeldeten Punkt.
	_move(screen, graph.screen_position("s.root"))
	_graph(screen)._set_hovered("s.root", screen.size - Vector2(2, 2))
	var card := _card(screen)
	assert_float(card.global_position.x).is_greater_equal(0.0)
	assert_float(card.global_position.y).is_greater_equal(0.0)
	assert_float(card.global_position.x + card.size.x).is_less_equal(screen.size.x)
	assert_float(card.global_position.y + card.size.y).is_less_equal(screen.size.y)


## Neben dem Netz gibt es nichts zu erklären — und beim Ziehen wandert alles unter dem
## Zeiger durch, da wäre eine mitlaufende Karte nur Flackern.
func test_the_card_goes_away_beside_the_net_and_while_dragging() -> void:
	_give_points(1)
	var screen := _screen()
	await get_tree().process_frame
	var graph := _graph(screen)
	_move(screen, graph.screen_position("s.root"))
	_move(screen, Vector2(2, 2))
	assert_bool(_card(screen).visible).is_false()
	_move(screen, graph.screen_position("s.root"))
	assert_bool(_card(screen).visible).is_true()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_MIDDLE
	press.pressed = true
	press.position = graph.screen_position("s.root")
	graph._gui_input(press)
	_move(screen, graph.screen_position("s.root") + Vector2(30, 30))
	assert_bool(_card(screen).visible).is_false()


## Ohne Punkte ist die Wurzel zu teuer — aber nicht gesperrt: sie braucht nichts.
func test_without_points_the_card_names_the_price() -> void:
	var screen := _screen()
	await get_tree().process_frame
	assert_str(_card_text(screen, "s.root", "Status")).contains("1 Skillpunkt")


## Ein gesperrter Knoten nennt seine Vorstufe BEIM NAMEN. Im Netz hängt an einem Knoten
## mehr als eine Linie; „gesperrt" allein sagt nicht, welche zuerst dran ist.
func test_a_locked_node_names_its_requirement() -> void:
	_give_points(5)
	var screen := _screen()
	await get_tree().process_frame
	assert_str(_card_text(screen, "s.left", "Status")).contains("🔒").contains("Wurzel")


func test_a_learned_node_says_so() -> void:
	_give_points(2)
	var screen := _screen()
	await get_tree().process_frame
	_learn(screen, "s.root")
	assert_str(_card_text(screen, "s.root", "Status")).contains("Gelernt")
	assert_str(_card_text(screen, "s.left", "Status")).contains("Lernen")


## Über dem NAMEN eines Baums steht sein Stand — das, was früher am rechten Bildrand
## stand: wie weit er ausgebaut ist und was er dafür bringt.
func test_the_card_of_a_tree_name_shows_its_progress() -> void:
	_give_points(2)
	var screen := _screen()
	await get_tree().process_frame
	assert_str(_card_text(screen, "tree.t", "Name")).contains("Prüfbaum")
	assert_str(_card_text(screen, "tree.t", "Status")).contains("0/3")
	_learn(screen, "s.root")
	assert_str(_card_text(screen, "tree.t", "Status")).contains("1/3").contains("HP")


# --- Klick und Rückfrage ------------------------------------------------------

## Ein Klick BUCHT nicht, er fragt: ein ausgegebener Punkt kommt nur gegen Gold zurück.
## Der Dialog nennt dabei den Knoten und den Preis.
func test_a_click_asks_before_it_spends() -> void:
	_give_points(2)
	var screen := _screen()
	await get_tree().process_frame
	_click_node(screen, "s.root")
	assert_bool(_dialog(screen).visible).is_true()
	assert_str(_dialog_title(screen)).contains("Wurzel")
	assert_str(_dialog_body(screen)).contains("Fängt an").contains("1 Skillpunkt")
	assert_array(Array(_book.unlocked)).is_empty()
	# Und die Karte ist weg: sie stünde sonst über dem abgedunkelten Bild.
	assert_bool(_card(screen).visible).is_false()


func test_confirming_learns_the_node() -> void:
	_give_points(2)
	var screen := _screen()
	await get_tree().process_frame
	_click_node(screen, "s.root")
	_say_yes(screen)
	assert_array(Array(_book.unlocked)).is_equal(["s.root"])
	assert_bool(_dialog(screen).visible).is_false()


func test_cancelling_leaves_everything_alone() -> void:
	_give_points(2)
	var screen := _screen()
	await get_tree().process_frame
	_click_node(screen, "s.root")
	_say_no(screen)
	assert_array(Array(_book.unlocked)).is_empty()
	assert_bool(_dialog(screen).visible).is_false()


## Nach einem Abbruch muss derselbe Knoten wieder fragen. Ein Klick ist keine Auswahl mehr,
## sondern ein Antrag — und ein zurückgezogener Antrag lässt sich neu stellen.
func test_the_same_node_asks_again_after_a_cancel() -> void:
	_give_points(2)
	var screen := _screen()
	await get_tree().process_frame
	_click_node(screen, "s.root")
	_say_no(screen)
	_click_node(screen, "s.root")
	assert_bool(_dialog(screen).visible).is_true()


## Wo es nichts zu entscheiden gibt, kommt kein Dialog: warum, steht schon in der Karte,
## und ein Fenster, das nur „geht nicht" sagt, ist ein Klick zum Wegklicken.
func test_a_node_one_cannot_learn_opens_nothing() -> void:
	_give_points(5)
	var screen := _screen()
	await get_tree().process_frame
	# Gesperrt: die Wurzel fehlt.
	_click_node(screen, "s.left")
	assert_bool(_dialog(screen).visible).is_false()
	# Gelernt: es gibt nichts mehr zu kaufen.
	_learn(screen, "s.root")
	_click_node(screen, "s.root")
	assert_bool(_dialog(screen).visible).is_false()


func test_a_too_expensive_node_opens_nothing() -> void:
	_give_points(2)
	var screen := _screen()
	await get_tree().process_frame
	_learn(screen, "s.root")
	# Drei Punkte kostet die Spitze, einer ist noch da — erfüllt, aber unbezahlbar.
	_click_node(screen, "s.right")
	assert_bool(_dialog(screen).visible).is_false()


func test_a_click_beside_the_net_opens_nothing() -> void:
	_give_points(2)
	var screen := _screen()
	await get_tree().process_frame
	_click(screen, Vector2(2, 2))
	assert_bool(_dialog(screen).visible).is_false()


## Der Punktestand oben zählt die OFFENEN Punkte mit.
func test_the_counter_follows_the_purchase() -> void:
	_give_points(2)
	var screen := _screen()
	var label := screen.get_node("%PointsLabel") as Label
	assert_str(label.text).contains("2")
	_learn(screen, "s.root")
	assert_str(label.text).contains("1")


# --- Die Werkzeuge am Rand ----------------------------------------------------

## Zwei Zeichen statt zweier Beschriftungen — und beide erklären sich beim Überfahren.
## Ein Knopf, auf dem nur „⛶" steht und der nichts dazu sagt, ist ein Rätsel.
func test_the_tools_explain_themselves() -> void:
	var screen := _screen()
	var fit := screen.get_node("%FitButton") as Button
	var respec := screen.get_node("%RespecButton") as Button
	assert_str(fit.text).is_not_empty()
	assert_str(fit.tooltip_text).contains("einpassen")
	assert_str(respec.text).is_not_empty()
	assert_str(respec.tooltip_text).contains("Umlernen")


## Und sie erscheinen ohne Wartezeit: dieselbe Zusage wie bei der Karte am Knoten, nur
## dass Godots eigene Tooltips dafür eine Projekteinstellung brauchen.
func test_tooltips_appear_without_delay() -> void:
	assert_float(float(ProjectSettings.get_setting(
			"gui/timers/tooltip_delay_sec", 0.5))).is_equal(0.0)


# --- Zoom und Ausschnitt ------------------------------------------------------

## Zoom mit dem Mausrad — nach oben näher, nach unten weiter weg.
func test_the_wheel_zooms() -> void:
	var screen := _screen()
	await get_tree().process_frame
	var graph := _graph(screen)
	# Erst heraus und dann wieder hinein: der Screen startet eingepasst, und das kann
	# schon der größte erlaubte Zoom sein — dann hätte ein erster Schritt hinein nichts
	# zu zeigen.
	var fitted := graph.zoom()
	_wheel(graph, MOUSE_BUTTON_WHEEL_DOWN)
	var out := graph.zoom()
	assert_float(out).is_less(fitted)
	_wheel(graph, MOUSE_BUTTON_WHEEL_UP)
	assert_float(graph.zoom()).is_greater(out)


## Was unter dem Zeiger liegt, bleibt unter dem Zeiger. Ohne das wandert das Netz beim
## Zoomen aus dem Bild, und man zoomt mit einer Hand und schiebt mit der anderen hinterher.
func test_zooming_keeps_the_point_under_the_cursor() -> void:
	var screen := _screen()
	await get_tree().process_frame
	var graph := _graph(screen)
	var at := graph.screen_position("s.root")
	_wheel(graph, MOUSE_BUTTON_WHEEL_UP, at)
	assert_float(graph.screen_position("s.root").distance_to(at)).is_less(1.0)


## Der Zoom hat Grenzen: beliebig weit heraus wäre ein Punkt, beliebig weit hinein ein
## Farbfeld.
func test_the_zoom_stays_within_its_limits() -> void:
	var screen := _screen()
	await get_tree().process_frame
	var graph := _graph(screen)
	for i in 60:
		_wheel(graph, MOUSE_BUTTON_WHEEL_UP)
	assert_float(graph.zoom()).is_less_equal(SkillGraph.MAX_ZOOM)
	for i in 120:
		_wheel(graph, MOUSE_BUTTON_WHEEL_DOWN)
	assert_float(graph.zoom()).is_greater_equal(SkillGraph.MIN_ZOOM)


## „Ansicht einpassen" holt das ganze Netz zurück ins Bild, egal wie weit man sich
## verzoomt hat.
func test_fitting_brings_the_whole_net_back() -> void:
	var screen := _screen()
	await get_tree().process_frame
	var graph := _graph(screen)
	for i in 20:
		_wheel(graph, MOUSE_BUTTON_WHEEL_UP)
	(screen.get_node("%FitButton") as Button).pressed.emit()
	for id: String in ["s.root", "s.left", "s.right", "tree.t"]:
		var at := graph.screen_position(id)
		assert_bool(Rect2(Vector2.ZERO, graph.size).has_point(at)
				).override_failure_message("'%s' liegt nach dem Einpassen außerhalb" % id
				).is_true()


## Ein Kauf verschiebt den Ausschnitt NICHT: wer hineingezoomt hat, um einen Ast zu lesen,
## soll nach dem Klick noch denselben Ast sehen.
func test_learning_leaves_the_viewport_alone() -> void:
	_give_points(2)
	var screen := _screen()
	await get_tree().process_frame
	var graph := _graph(screen)
	_wheel(graph, MOUSE_BUTTON_WHEEL_UP)
	var zoom_before := graph.zoom()
	var at_before := graph.screen_position("s.root")
	_learn(screen, "s.root")
	assert_array(Array(_book.unlocked)).is_equal(["s.root"])
	assert_float(graph.zoom()).is_equal(zoom_before)
	assert_float(graph.screen_position("s.root").distance_to(at_before)).is_less(0.001)


func _wheel(graph: SkillGraph, button: int, at := Vector2(10, 10)) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	event.position = at
	graph._gui_input(event)


# --- Umlernen ----------------------------------------------------------------

## Dieselbe Rückfrage wie beim Lernen, und sie nennt beides: die Punkte, die zurückkommen,
## und das Gold, das es kostet.
func test_respec_asks_before_it_acts() -> void:
	_give_points(2)
	Wallet.gold = 10_000
	var screen := _screen()
	await get_tree().process_frame
	_learn(screen, "s.root")
	var respec := screen.get_node("%RespecButton") as Button
	assert_bool(respec.disabled).is_false()
	respec.pressed.emit()
	assert_bool(_dialog(screen).visible).is_true()
	assert_str(_dialog_body(screen)).contains("1 Skillpunkt").contains(
			str(SkillTree.RESPEC_GOLD_PER_POINT))
	assert_array(Array(_book.unlocked)).is_equal(["s.root"])
	_say_yes(screen)
	assert_array(Array(_book.unlocked)).is_empty()
	assert_int(Wallet.gold).is_equal(10_000 - SkillTree.RESPEC_GOLD_PER_POINT)


func test_cancelling_the_respec_keeps_the_skills() -> void:
	_give_points(2)
	Wallet.gold = 10_000
	var screen := _screen()
	await get_tree().process_frame
	_learn(screen, "s.root")
	(screen.get_node("%RespecButton") as Button).pressed.emit()
	_say_no(screen)
	assert_array(Array(_book.unlocked)).is_equal(["s.root"])
	assert_int(Wallet.gold).is_equal(10_000)


## Ohne Gelerntes gibt es nichts zurückzunehmen — der Knopf ist gesperrt und sagt im
## Tooltip warum, statt zu verschwinden.
func test_respec_without_skills_is_disabled_but_speaks() -> void:
	var screen := _screen()
	var respec := screen.get_node("%RespecButton") as Button
	assert_bool(respec.disabled).is_true()
	assert_str(respec.tooltip_text).contains("nichts gelernt")


## Reicht das Gold nicht, steht der Preis trotzdem da: der Knopf ist kein Rätsel.
func test_respec_without_gold_names_the_price() -> void:
	_give_points(2)
	Wallet.gold = 0
	var screen := _screen()
	await get_tree().process_frame
	_learn(screen, "s.root")
	var respec := screen.get_node("%RespecButton") as Button
	assert_bool(respec.disabled).is_true()
	assert_str(respec.tooltip_text).contains(str(SkillTree.RESPEC_GOLD_PER_POINT))


# --- Maß ----------------------------------------------------------------------

## Der Screen passt in die Grundauflösung — das Vollbild ist der schmalste Fall, nicht
## der breiteste (siehe tests/hud_header_test.gd und CLAUDE.md).
func test_the_screen_fits_the_base_resolution() -> void:
	_give_points(9)
	var screen := _screen()
	for i in 4:
		await get_tree().process_frame
	var base := Vector2(
			float(ProjectSettings.get_setting("display/window/size/viewport_width", 1152)),
			float(ProjectSettings.get_setting("display/window/size/viewport_height", 648)))
	var needed := (screen.get_node("Margin") as Control).get_combined_minimum_size()
	# Achsen einzeln: assert_vector(...).is_less_equal(...) vergleicht lexikografisch, zu
	# hoch rutschte über die Breite durch.
	assert_float(needed.x).is_less_equal(base.x)
	assert_float(needed.y).is_less_equal(base.y)


## Auch die Rückfrage muss hineinpassen: sie hängt in der Bildmitte, und was über den Rand
## ragt, ist nicht wegzuklicken.
func test_the_dialog_fits_the_base_resolution() -> void:
	_give_points(2)
	var screen := _screen()
	await get_tree().process_frame
	_click_node(screen, "s.root")
	for i in 4:
		await get_tree().process_frame
	var panel := _dialog(screen).get_node("Center/Panel") as Control
	var needed := panel.get_combined_minimum_size()
	assert_float(needed.x).is_less_equal(1152.0)
	assert_float(needed.y).is_less_equal(648.0)
