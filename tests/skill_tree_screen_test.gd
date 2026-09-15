extends GdUnitTestSuite
## Der Fähigkeiten-Screen: er baut sich, findet seine Knoten, zeichnet die Äste
## nebeneinander und passt in die Grundauflösung.
##
## Geprüft wird an einem ERFUNDENEN Baum: der Screen bekommt ein SkillBook untergeschoben,
## dessen `entries()` feste Knoten liefert. Sonst hinge der Test an der Balance der
## ausgelieferten Bäume — und an dem, was auf dem Rechner an Packs installiert ist.
##
## Was er NICHT prüft: das Buchen selbst (tests/skill_book_test.gd) und die Regeln
## (tests/skill_tree_test.gd). Hier geht es um das, was man sieht.

const SCREEN_SCENE := preload("res://scenes/ui/skill_tree.tscn")
const TEST_PROFILE := "zz-skill-screen"

## Wurzel, zwei Äste, und im rechten Ast eine Spitze für 3 Punkte.
class FixedBook extends "res://src/progression/skill_book.gd":
	func entries() -> Array:
		return [
			{"id": "tree.t", "kind": "tree", "order": 1, "name": "Prüfbaum",
				"description": "Ein Baum zum Messen."},
			{"id": "s.root", "kind": "skill", "tree": "tree.t", "tier": 1, "branch": 0,
				"name": "Wurzel", "description": "Fängt an.", "cost": 1, "requires": [],
				"effects": {"heal_per_correct": 1}},
			{"id": "s.left", "kind": "skill", "tree": "tree.t", "tier": 2, "branch": 0,
				"name": "Links", "description": "Geht links weiter.", "cost": 1,
				"requires": ["s.root"], "effects": {"heal_per_correct": 1}},
			{"id": "s.right", "kind": "skill", "tree": "tree.t", "tier": 2, "branch": 1,
				"name": "Rechts", "description": "Geht rechts weiter.", "cost": 3,
				"requires": ["s.root"], "effects": {"fortress_armor": 25}},
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
## `_ready()` baut den Baum schon auf.
func _screen() -> Control:
	var screen := auto_free(SCREEN_SCENE.instantiate()) as Control
	screen.set("book", _book)
	add_child(screen)
	return screen


## Alle Karten des Screens, in der Reihenfolge, in der sie stehen.
func _cards(screen: Control) -> Array[SkillNode]:
	var out: Array[SkillNode] = []
	var stack: Array[Node] = [screen]
	while not stack.is_empty():
		var node: Node = stack.pop_front()
		if node is SkillNode:
			out.append(node)
		for child in node.get_children():
			stack.append(child)
	return out


func _card(screen: Control, id: String) -> SkillNode:
	for card in _cards(screen):
		if card.id == id:
			return card
	return null


func _button_of(card: SkillNode) -> Button:
	return card.get_node("%Action") as Button


# --- Aufbau ------------------------------------------------------------------

func test_the_screen_finds_its_unique_names() -> void:
	var screen := _screen()
	assert_object(screen.get_node("%BackButton")).is_not_null()
	assert_object(screen.get_node("%PointsLabel")).is_not_null()
	assert_object(screen.get_node("%Trees")).is_not_null()
	assert_object(screen.get_node("%RespecButton")).is_not_null()


## Jeder Knoten des Baums bekommt eine Karte — keiner fällt beim Zeichnen unter den Tisch.
func test_every_node_gets_a_card() -> void:
	var screen := _screen()
	var ids: Array = []
	for card in _cards(screen):
		ids.append(card.id)
	assert_array(ids).contains_exactly_in_any_order(["s.root", "s.left", "s.right"])


## DAS Merkmal der Bäume: die Äste stehen in EINER Zeile nebeneinander, die Wurzel allein
## darüber. Eine Kette zweier Spalten wäre kein Baum.
func test_a_tier_draws_its_branches_side_by_side() -> void:
	var screen := _screen()
	var root_row := _card(screen, "s.root").get_parent()
	var left_row := _card(screen, "s.left").get_parent()
	assert_int(root_row.get_child_count()).is_equal(1)
	assert_object(_card(screen, "s.right").get_parent()).is_same(left_row)
	assert_int(left_row.get_child_count()).is_equal(2)


## Die Reihenfolge in der Zeile kommt aus `branch` — ein Ast bleibt über alle Stufen
## hinweg in derselben Spalte.
func test_the_branches_keep_their_column() -> void:
	var screen := _screen()
	assert_int(_card(screen, "s.left").get_index()).is_less(
			_card(screen, "s.right").get_index())


# --- Die vier Zustände --------------------------------------------------------

## Ohne Punkte ist die Wurzel zu teuer — aber nicht gesperrt: sie braucht nichts.
func test_without_points_the_root_is_too_expensive() -> void:
	var screen := _screen()
	var button := _button_of(_card(screen, "s.root"))
	assert_bool(button.disabled).is_true()
	assert_str(button.text).contains("1 P.")


func test_with_points_the_root_can_be_learned() -> void:
	_give_points(1)
	var screen := _screen()
	assert_bool(_button_of(_card(screen, "s.root")).disabled).is_false()


## Ein gesperrter Knoten nennt seine Vorstufe BEIM NAMEN. Mit zwei Ästen nebeneinander
## ist sonst nicht zu sehen, welcher woran hängt.
func test_a_locked_node_names_its_requirement() -> void:
	_give_points(5)
	var screen := _screen()
	assert_str(_button_of(_card(screen, "s.left")).text).contains("Wurzel")


## Der Kauf geht über den Knopf und baut den Screen neu: die Wurzel ist danach gelernt,
## der Ast darunter offen.
func test_learning_redraws_the_tree() -> void:
	_give_points(2)
	var screen := _screen()
	_button_of(_card(screen, "s.root")).pressed.emit()
	assert_array(Array(_book.unlocked)).is_equal(["s.root"])
	assert_str(_button_of(_card(screen, "s.root")).text).contains("Gelernt")
	assert_bool(_button_of(_card(screen, "s.left")).disabled).is_false()
	# Drei Punkte kostet die Spitze, einer ist noch da — erfüllt, aber unbezahlbar.
	assert_str(_button_of(_card(screen, "s.right")).text).contains("3 P.")
	assert_bool(_button_of(_card(screen, "s.right")).disabled).is_true()


## Der Punktestand oben zählt die OFFENEN Punkte mit.
func test_the_points_label_counts_down() -> void:
	_give_points(2)
	var screen := _screen()
	var label := screen.get_node("%PointsLabel") as Label
	assert_str(label.text).contains("2")
	_button_of(_card(screen, "s.root")).pressed.emit()
	assert_str(label.text).contains("1")


# --- Umlernen ----------------------------------------------------------------

## Zwei Stufen an EINEM Knopf statt eines Dialogs: der erste Druck fragt nach, der zweite
## führt aus. Umbeschriften statt einblenden — dasselbe Prinzip wie bei der Schatzkiste.
func test_respec_asks_before_it_acts() -> void:
	_give_points(2)
	Wallet.gold = 10_000
	var screen := _screen()
	_button_of(_card(screen, "s.root")).pressed.emit()
	var respec := screen.get_node("%RespecButton") as Button
	assert_bool(respec.disabled).is_false()
	respec.pressed.emit()
	assert_str(respec.text).contains("Wirklich")
	assert_array(Array(_book.unlocked)).is_equal(["s.root"])
	respec.pressed.emit()
	assert_array(Array(_book.unlocked)).is_empty()
	assert_int(Wallet.gold).is_equal(10_000 - SkillTree.RESPEC_GOLD_PER_POINT)


## Ohne Gelerntes gibt es nichts zurückzunehmen — der Knopf ist gesperrt und sagt warum,
## statt zu verschwinden.
func test_respec_without_skills_is_disabled_but_speaks() -> void:
	var screen := _screen()
	var respec := screen.get_node("%RespecButton") as Button
	assert_bool(respec.disabled).is_true()
	assert_str(respec.text).contains("nichts gelernt")


## Reicht das Gold nicht, steht der Preis trotzdem da: der Knopf ist kein Rätsel.
func test_respec_without_gold_names_the_price() -> void:
	_give_points(2)
	Wallet.gold = 0
	var screen := _screen()
	_button_of(_card(screen, "s.root")).pressed.emit()
	var respec := screen.get_node("%RespecButton") as Button
	assert_bool(respec.disabled).is_true()
	assert_str(respec.text).contains(str(SkillTree.RESPEC_GOLD_PER_POINT))


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
