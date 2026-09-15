extends Control
## Der Fähigkeitsbaum-Screen: alle Bäume, ihre Knoten und der Punktestand.
##
## Vom Start-Screen aus erreichbar (profile_menu), neben Statistik und Einstellungen.
## Das Layout liegt in skill_tree.tscn, die Karte in skill_node.tscn; hier wird nur
## gebaut und gebucht. Die REGELN stehen woanders: `SkillTree` in src/progression/
## (statisch, siehe dort) rechnet Stufen, Voraussetzungen und Kosten, `SkillBook` hält
## das Gelernte. Dieser Screen weiß von beiden nur, was er zum Zeichnen braucht.
##
## Gezeichnet wird EINE Zeile je Stufe, darin die Äste nebeneinander und nach `branch`
## sortiert. Die Wurzel steht damit allein in der Mitte, die Äste darunter — und ein
## dritter Ast ist später ein Eintrag in der JSON und keine Zeile Code hier. Verbindungs-
## linien gibt es nicht: was woran hängt, sagt die gesperrte Karte selbst („🔒 braucht
## Verband"), und das ist auch dann noch lesbar, wenn ein Baum breiter wird.

const MENU_SCENE := "res://scenes/ui/profile_menu.tscn"
const NODE_SCENE := preload("res://scenes/ui/skill_node.tscn")

@onready var _points_label: Label = %PointsLabel
@onready var _empty_hint: Label = %EmptyHint
@onready var _trees: VBoxContainer = %Trees
@onready var _respec_button: Button = %RespecButton

## Das Buch, aus dem gelesen und in das gebucht wird — im Spiel das Autoload `SkillBook`.
## Ein Test schiebt hier eine eigene Instanz mit erfundenem Baum unter und hängt damit
## weder am echten Profil des Spielers noch an der Balance der ausgelieferten Bäume
## (tests/skill_tree_screen_test.gd). Gesetzt wird es VOR dem Einhängen in den Baum.
var book: Node = null

## Zweiter Druck auf denselben Knopf führt das Umlernen aus. Ein Dialog wäre der zweite
## Weg, dasselbe zu fragen; umbeschriften statt einblenden ist das Muster des Hauses
## (siehe die zugesperrte Schatzkiste in CLAUDE.md).
var _respec_armed := false


func _ready() -> void:
	if book == null:
		book = SkillBook
	(%BackButton as Button).pressed.connect(func() -> void:
			get_tree().change_scene_to_file(MENU_SCENE))
	_respec_button.pressed.connect(_on_respec_pressed)
	# Beide Stände hängen am Signal, statt nachzufragen: das Gelernte ändert sich hier,
	# das Gold beim Umlernen — und der Knopf trägt beides in seiner Beschriftung.
	book.changed.connect(_rebuild)
	Wallet.changed.connect(func(_gold: int) -> void: _refresh_respec())
	_rebuild()


## Baut alle Bäume neu. Ein gelernter Knoten verschiebt die Zustände der ganzen Stufe
## darunter (und den Punktestand jeder anderen Karte) — einzelne Karten nachzuführen
## hieße, diese Abhängigkeit ein zweites Mal hinzuschreiben.
func _rebuild() -> void:
	_respec_armed = false
	for child in _trees.get_children():
		_trees.remove_child(child)
		child.queue_free()
	var entries: Array = book.entries()
	var trees := SkillTree.trees(entries)
	_empty_hint.visible = trees.is_empty()
	for tree in trees:
		_add_tree(entries, tree)
	_refresh_points()
	_refresh_respec()


## Hängt einen Baum in den Screen. Gebaut wird VON OBEN NACH UNTEN, also jeder Container
## erst eingehängt und dann gefüllt: eine Karte bekommt ihren Inhalt über `setup()`, und
## das greift auf ihre Kindknoten zu — die stehen erst nach `_ready()` bereit, und
## `_ready()` läuft erst, wenn der Knoten im Szenenbaum hängt.
func _add_tree(entries: Array, tree: Dictionary) -> void:
	var box := VBoxContainer.new()
	box.theme_type_variation = &"Tight"
	_trees.add_child(box)

	var title := Label.new()
	title.theme_type_variation = &"SectionTitle"
	title.text = str(tree.get("name", tree.get("id", "")))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var hint := Label.new()
	hint.theme_type_variation = &"Hint"
	hint.text = str(tree.get("description", ""))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)

	# Der Punktestand gilt für den ganzen Aufbau: er ändert sich erst mit dem nächsten
	# Kauf, und der baut ohnehin alles neu.
	var points: int = book.available()
	for tier in SkillTree.tiers_of(entries, str(tree.get("id", ""))):
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_child(row)
		for node in tier:
			_add_card(row, entries, node, points)


func _add_card(row: HBoxContainer, entries: Array, node: Dictionary, points: int) -> void:
	var card := NODE_SCENE.instantiate() as SkillNode
	card.learn_requested.connect(_on_learn_requested)
	row.add_child(card)
	var state := _state_of(entries, node, points)
	var missing := ""
	if state == SkillNode.State.LOCKED:
		var learned: PackedStringArray = book.unlocked
		missing = SkillTree.missing_requirement(entries, node, learned)
	card.setup(node, state, missing)


## Der Zustand einer Karte — in genau dieser Reihenfolge: gelernt schlägt gesperrt,
## gesperrt schlägt zu teuer. Sonst stünde an einem Knoten ohne Vorstufe „2 P. nötig",
## und der Spieler suchte die Punkte statt der Vorstufe.
func _state_of(entries: Array, node: Dictionary, points: int) -> SkillNode.State:
	var learned: PackedStringArray = book.unlocked
	if str(node.get("id", "")) in learned:
		return SkillNode.State.LEARNED
	if not SkillTree.requirements_met(node, learned):
		return SkillNode.State.LOCKED
	if SkillTree.cost(node) > points:
		return SkillNode.State.TOO_EXPENSIVE
	return SkillNode.State.AVAILABLE


func _on_learn_requested(id: String) -> void:
	# Der Kauf kann scheitern (Punkte inzwischen weg) — dann meldet SkillBook nichts und
	# es bleibt alles stehen. Geprüft wird dort, nicht hier: eine zweite Prüfung an der
	# Oberfläche könnte von der ersten abweichen.
	book.unlock(id)


func _refresh_points() -> void:
	var points: int = book.available()
	if points > 0:
		_points_label.text = "⭐ %d Skillpunkt%s zu vergeben" % [
			points, "" if points == 1 else "e"]
	else:
		_points_label.text = "Keine offenen Skillpunkte — jedes Level bringt einen neuen."


## Der Umlern-Knopf trägt seinen Zustand im Text: was es kostet, warum es nicht geht, und
## nach dem ersten Druck die Rückfrage.
func _refresh_respec() -> void:
	var cost: int = book.respec_cost()
	if cost <= 0:
		_respec_button.disabled = true
		_respec_button.text = "Umlernen — noch nichts gelernt"
		return
	if not Wallet.can_afford(cost):
		_respec_button.disabled = true
		_respec_button.text = "Umlernen kostet %s — du hast %s" % [
			Wallet.label(cost), Wallet.label()]
		return
	_respec_button.disabled = false
	if _respec_armed:
		_respec_button.text = "Wirklich? Alles Gelernte zurücksetzen für %s" % Wallet.label(cost)
	else:
		_respec_button.text = "Umlernen (%s)" % Wallet.label(cost)


func _on_respec_pressed() -> void:
	if not _respec_armed:
		_respec_armed = true
		_refresh_respec()
		return
	# Gelingt es, meldet SkillBook `changed` und _rebuild() nimmt die Rückfrage zurück.
	book.respec()
