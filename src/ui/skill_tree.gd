extends Control
## Der Fähigkeitsbaum-Screen: ein Fenster über dem Hauptmenü (geöffnet von `ProfileBadge`)
## mit dem Netz aller Bäume (`SkillGraph`), dem Punktestand und dem Ausbau. Die Karte am
## Zeiger liefert `_hint_at`; ein Klick fragt über `ConfirmDialog` nach. Die Regeln rechnet
## `SkillTree` (src/progression/), das Gelernte hält `SkillBook`; hier wird nichts entschieden.

const MENU_SCENE := "res://scenes/ui/profile_menu.tscn"

## Einblenden (s).
const FADE_IN := 0.15

## Das Fenster will zu. Ohne Verbindung geht `close` selbst ins Startmenü.
signal closed()

@onready var _graph: SkillGraph = %Graph
@onready var _points_label: Label = %PointsLabel
@onready var _empty_hint: Label = %EmptyHint
@onready var _fit_button: Button = %FitButton
@onready var _zoom_in: Button = %ZoomInButton
@onready var _zoom_out: Button = %ZoomOutButton
@onready var _zoom_label: Label = %ZoomLabel
@onready var _respec_button: Button = %RespecButton
@onready var _confirm: ConfirmDialog = %Confirm

## Das Buch, aus dem gelesen und in das gebucht wird; im Spiel das Autoload `SkillBook`,
## im Test eine eigene Instanz. Vor dem Einhängen in den Baum setzen.
var book: Node = null

## Die offene Rückfrage: `{"kind": "learn"|"forget", "id": …}` oder `{"kind": "respec"}`;
## leer, wenn keine offen ist.
var _pending: Dictionary = {}


func _ready() -> void:
	if book == null:
		book = SkillBook
	(%CloseButton as BaseButton).pressed.connect(close)
	_fit_button.pressed.connect(func() -> void: _graph.fit())
	_zoom_in.pressed.connect(func() -> void: _graph.zoom_by(SkillGraph.ZOOM_STEP))
	_zoom_out.pressed.connect(func() -> void: _graph.zoom_by(1.0 / SkillGraph.ZOOM_STEP))
	_graph.view_changed.connect(func() -> void:
			_zoom_label.text = "%d %%" % _graph.zoom_percent())
	_respec_button.pressed.connect(_on_respec_pressed)
	_graph.node_selected.connect(_on_node_selected)
	_confirm.confirmed.connect(_on_confirmed)
	_confirm.cancelled.connect(func() -> void: _pending = {})
	Hints.attach_live(_graph, _hint_at)
	Hints.attach(_fit_button, "Ansicht einpassen", "Mausrad zoomt, Ziehen verschiebt")
	Hints.attach(_zoom_in, "Näher heran")
	Hints.attach(_zoom_out, "Weiter weg")
	Hints.attach(%CloseButton as Control, "Schließen", "", "Esc")
	# Gold ändert Preis und Sperre des Umlern-Knopfs.
	book.changed.connect(_rebuild)
	Wallet.changed.connect(func(_gold: int) -> void:
			_refresh_respec()
			Hints.refresh())
	_rebuild()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, FADE_IN)
	_graph.grab_focus.call_deferred()


func close() -> void:
	if closed.get_connections().is_empty():
		get_tree().change_scene_to_file(MENU_SCENE)
		return
	closed.emit()


## Eine offene Rückfrage fängt Escape selbst (`ConfirmDialog._input`).
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


## Trägt den ganzen Stand neu ein, weil ein gelernter Knoten die Zustände seines ganzen
## Astes verschiebt. Der Ausschnitt bleibt (`SkillGraph.setup`).
func _rebuild() -> void:
	var entries: Array = book.entries()
	_graph.setup(entries, book.unlocked, book.available())
	_empty_hint.visible = SkillTree.trees(entries).is_empty()
	Hints.refresh()
	_refresh_points(book.available())
	_refresh_respec()


func _refresh_points(points: int) -> void:
	if bool(book.get("unlimited_points")):
		_points_label.text = "∞ Skillpunkte (Debug)"
	elif points > 0:
		_points_label.text = "%d Skillpunkt%s" % [points, "" if points == 1 else "e"]
	else:
		_points_label.text = "0 — jedes Level bringt einen"


# --- Die Auskunft am Zeiger ---------------------------------------------------

## Was die Karte über einem Punkt des Netzes zeigt, oder nichts: über einem Knoten seine
## Wirkung und was ein Klick täte, über dem Namen eines Baums dessen Stand. Leer beim
## Ziehen und bei offener Rückfrage.
func _hint_at(local: Vector2) -> Dictionary:
	if _graph.is_panning() or _confirm.visible:
		return {}
	var entries: Array = book.entries()
	var node := SkillTree.node_by_id(entries, _graph.id_at(local))
	if node.is_empty():
		return {}
	var id := str(node.get("id", ""))
	if str(node.get("kind", "")) == "tree":
		return {
			"title": str(node.get("name", "")),
			"body": str(node.get("description", "")),
			"note": SkillTree.tree_status(entries, book.unlocked, id),
		}
	var points: int = book.available()
	# Der Preis eines Klicks steht im Kopf: ungelernt Skillpunkte, gelernt das Gold fürs
	# Verlernen.
	var prices: Array = [[SkillIcons.skill_point(), str(SkillTree.cost(node))]]
	var note := ""
	if book.is_unlocked(id):
		var forget: int = book.forget_cost(id)
		prices = [[SkillIcons.gold(), Wallet.digits(forget)]]
		note = _forget_note(id)
	var tree := SkillTree.node_by_id(entries, str(node.get("tree", "")))
	var state := SkillTree.state_of(node, book.unlocked, points)
	var picture := SkillIcons.of(id)
	return {
		"title": str(node.get("name", "")) if picture != null \
				else "%s %s" % [SkillTree.icon_of(node), str(node.get("name", ""))],
		"icon": picture,
		"subtitle": "%s · %s" % [str(tree.get("name", "")), SkillTree.state_name(state)],
		"tint": SkillTree.color_of(tree),
		"body": str(node.get("description", "")),
		"list": _facts(entries, node),
		"note": note,
		"prices": prices,
	}


## Die Voraussetzungen als Zeilen der Karte: Haken für erfüllt, Schloss für fehlend.
func _facts(entries: Array, node: Dictionary) -> Array:
	var rows: Array = []
	for required in node.get("requires", []):
		var id := str(required)
		var name := str(SkillTree.node_by_id(entries, id).get("name", id))
		rows.append([SkillIcons.check() if book.is_unlocked(id) else SkillIcons.lock(),
				"Voraussetzung", name])
	return rows


## Nachsatz an einem gelernten Knoten, nur wenn das Gold fürs Verlernen nicht reicht.
func _forget_note(id: String) -> String:
	var cost: int = book.forget_cost(id)
	if Wallet.can_afford(cost):
		return ""
	return "Verlernen kostet %s — du hast %s" % [Wallet.label(cost), Wallet.label()]


# --- Klick und Rückfrage ------------------------------------------------------

## Ein Klick ins Netz. Gefragt wird nur bei einem lernbaren Knoten und bei einem gelernten,
## dessen Verlernen bezahlbar ist; sonst sagt die Karte schon, warum nicht.
func _on_node_selected(id: String) -> void:
	if id.is_empty():
		return
	var entries: Array = book.entries()
	var node := SkillTree.node_by_id(entries, id)
	if node.is_empty() or str(node.get("kind", "")) != "skill":
		return
	var points: int = book.available()
	var state := SkillTree.state_of(node, book.unlocked, points)
	if state == SkillTree.State.LEARNED:
		_ask_forget(node)
		return
	if state != SkillTree.State.AVAILABLE:
		return
	var cost := SkillTree.cost(node)
	var left := points - cost
	_pending = {"kind": "learn", "id": id}
	Hints.refresh()
	if bool(book.get("unlimited_points")):
		_confirm.ask("„%s“ lernen?" % str(node.get("name", id)),
				"%s\n\nIm Debug-Build sind die Skillpunkte unbegrenzt."
				% str(node.get("description", "")),
				"Lernen · %d P." % cost)
		return
	_confirm.ask(
			"„%s“ lernen?" % str(node.get("name", id)),
			"%s\n\nDas kostet %d Skillpunkt%s, danach %s noch %d offen. Zurückholen lässt "
			% [str(node.get("description", "")), cost, "" if cost == 1 else "e",
				"ist" if left == 1 else "sind", left]
			+ "sich ein ausgegebener Punkt nur gegen Gold.",
			"Lernen · %d P." % cost)


## Die Rückfrage vor dem Verlernen nennt jeden Knoten, der mitfällt, beim Namen.
func _ask_forget(node: Dictionary) -> void:
	var id := str(node.get("id", ""))
	var cost: int = book.forget_cost(id)
	if not Wallet.can_afford(cost):
		return
	var entries: Array = book.entries()
	var gone := SkillTree.forget_set(entries, id, book.unlocked)
	var spent := SkillTree.spent(entries, gone)
	var others: Array[String] = []
	for other in gone:
		if other != id:
			others.append("„%s“" % str(SkillTree.node_by_id(entries, other).get("name", other)))
	var along := ""
	if not others.is_empty():
		along = "Mit ihm %s auch %s — %s baut darauf auf.\n\n" % [
			"fällt" if others.size() == 1 else "fallen",
			_join_names(others),
			"das" if others.size() == 1 else "die"]
	_pending = {"kind": "forget", "id": id}
	Hints.refresh()
	_confirm.ask("„%s“ verlernen?" % str(node.get("name", id)),
			along + "Du bekommst %d Skillpunkt%s zurück und zahlst %s." % [
				spent, "" if spent == 1 else "e", Wallet.label(cost)],
			"Verlernen")


## „A“, „A und B“, „A, B und C“.
static func _join_names(names: Array[String]) -> String:
	if names.size() <= 1:
		return "".join(names)
	return ", ".join(names.slice(0, names.size() - 1)) + " und " + names[-1]


func _on_respec_pressed() -> void:
	var cost: int = book.respec_cost()
	if cost <= 0 or not Wallet.can_afford(cost):
		return
	# `respec_cost` ist Gold je ausgegebenem Punkt; die Punkte werden daraus zurückgerechnet.
	var spent := int(round(float(cost) / float(SkillTree.RESPEC_GOLD_PER_POINT)))
	_pending = {"kind": "respec"}
	Hints.refresh()
	_confirm.ask("Alles Gelernte zurücksetzen?",
			"Du bekommst %d Skillpunkt%s zurück und zahlst %s. Das Netz steht danach "
			% [spent, "" if spent == 1 else "e", Wallet.label(cost)]
			+ "wieder am Anfang.",
			"Umlernen")


## Ein gescheiterter Kauf (Punkte inzwischen weg) ändert nichts; geprüft wird in SkillBook.
func _on_confirmed() -> void:
	match str(_pending.get("kind", "")):
		"learn":
			book.unlock(str(_pending.get("id", "")))
		"forget":
			book.forget(str(_pending.get("id", "")))
		"respec":
			book.respec()
	_pending = {}


## Der Umlern-Knopf ist ein Zeichen; seine Karte nennt Preis oder Sperrgrund. Ein gesperrter
## Knopf zeigt seine Karte trotzdem (tests/hints_test.gd).
func _refresh_respec() -> void:
	var cost: int = book.respec_cost()
	if cost <= 0:
		_respec_button.disabled = true
		Hints.attach(_respec_button, "Umlernen", "noch nichts gelernt")
		return
	if not Wallet.can_afford(cost):
		_respec_button.disabled = true
		Hints.attach(_respec_button, "Umlernen", "kostet %s — du hast %s" % [
			Wallet.label(cost), Wallet.label()])
		return
	_respec_button.disabled = false
	Hints.attach(_respec_button, "Umlernen", "", Wallet.label(cost))
