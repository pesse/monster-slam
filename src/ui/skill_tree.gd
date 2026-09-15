extends Control
## Der Fähigkeitsbaum-Screen: das Netz aller Bäume, der Punktestand und der Ausbau.
##
## Vom Start-Screen aus erreichbar (profile_menu), neben Statistik und Einstellungen.
## Unter der Kopfzeile nichts als das gezeichnete Netz (`SkillGraph`, zoombar mit dem
## Mausrad) — es gibt keine Tafel am Rand mehr, die daneben dasselbe noch einmal erklärt.
##
## Alles, was zu einem Knoten zu sagen ist, steht am ZEIGER: `SkillTooltip` folgt der Maus,
## ohne Verzögerung, und trägt Name, Wirkung und Zustand. Über dem NAMEN eines Baums zeigt
## dieselbe Karte den Stand des ganzen Baums — das, was früher am rechten Rand stand. Und
## ein Klick fragt nach, statt sofort zu buchen (`ConfirmDialog`): ein ausgegebener
## Skillpunkt kommt nur gegen Gold zurück, das ist keine Entscheidung für einen
## unbeabsichtigten Klick.
##
## Die REGELN stehen woanders: `SkillTree` in src/progression/ (statisch) rechnet Stufen,
## Voraussetzungen, Kosten, Plätze und Boni — bis hin zu den Zeilen, die in der Karte
## stehen (`state_label`, `tree_status`); `SkillBook` hält das Gelernte. Dieser Screen weiß
## von beiden nur, was er zum Anzeigen braucht, und entscheidet nichts selbst.

const MENU_SCENE := "res://scenes/ui/profile_menu.tscn"

## Abstand der Auskunftskarte zum Mauszeiger. Weit genug, dass der Zeiger nicht auf dem
## Text steht, nah genug, dass beides ein Blick ist.
const HOVER_GAP := Vector2(18, 18)

@onready var _graph: SkillGraph = %Graph
@onready var _points_label: Label = %PointsLabel
@onready var _empty_hint: Label = %EmptyHint
@onready var _fit_button: Button = %FitButton
@onready var _respec_button: Button = %RespecButton
@onready var _hover: SkillTooltip = %Hover
@onready var _confirm: ConfirmDialog = %Confirm

## Das Buch, aus dem gelesen und in das gebucht wird — im Spiel das Autoload `SkillBook`.
## Ein Test schiebt hier eine eigene Instanz mit erfundenem Baum unter und hängt damit
## weder am echten Profil des Spielers noch an der Balance der ausgelieferten Bäume
## (tests/skill_tree_screen_test.gd). Gesetzt wird es VOR dem Einhängen in den Baum.
var book: Node = null

## Worauf die offene Rückfrage hinausläuft: `{"kind": "learn", "id": …}` oder
## `{"kind": "respec"}`. Der Dialog kennt seinen Inhalt nicht — er fragt und meldet, und
## was dann geschieht, steht hier. Leer heißt: es ist keine Frage offen.
var _pending: Dictionary = {}


func _ready() -> void:
	if book == null:
		book = SkillBook
	(%BackButton as Button).pressed.connect(func() -> void:
			get_tree().change_scene_to_file(MENU_SCENE))
	_fit_button.pressed.connect(func() -> void: _graph.fit())
	_respec_button.pressed.connect(_on_respec_pressed)
	_graph.node_selected.connect(_on_node_selected)
	_graph.hover_changed.connect(_on_hover_changed)
	_confirm.confirmed.connect(_on_confirmed)
	_confirm.cancelled.connect(func() -> void: _pending = {})
	_hover.hide()
	# Die Breite der Karte EINMAL setzen und danach nie wieder: ein umbrechendes Label
	# meldet seine Höhe für die Breite, die es gerade hat. Ohne diese eine Zeile käme beim
	# ersten Überfahren die Höhe für einen Pixel Breite heraus — dieselbe Falle wie bei
	# `RevealCard.set_width()` (CLAUDE.md).
	_hover.size = _hover.get_combined_minimum_size()
	# Beide Stände hängen am Signal, statt nachzufragen: das Gelernte ändert sich hier,
	# das Gold beim Umlernen — und der Umlern-Knopf trägt beides in seinem Tooltip.
	book.changed.connect(_rebuild)
	Wallet.changed.connect(func(_gold: int) -> void: _refresh_respec())
	_rebuild()


## Trägt den ganzen Stand neu ein. Ein gelernter Knoten verschiebt die Zustände seines
## ganzen Astes und den Punktestand jedes anderen Knotens — einzeln nachzuführen hieße,
## diese Abhängigkeit ein zweites Mal hinzuschreiben.
##
## Der AUSSCHNITT bleibt dabei stehen: `SkillGraph.setup()` passt nur ein, solange niemand
## gezoomt oder geschoben hat. Nach einem Kauf soll das Netz nicht springen.
func _rebuild() -> void:
	var entries: Array = book.entries()
	_graph.setup(entries, book.unlocked, book.available())
	_empty_hint.visible = SkillTree.trees(entries).is_empty()
	# Die Karte trägt einen Stand, den es gerade nicht mehr gibt. Beim nächsten
	# Mausschubser ist sie wieder da, dann mit dem neuen.
	_hover.hide()
	_refresh_points(book.available())
	_refresh_respec()


func _refresh_points(points: int) -> void:
	if points > 0:
		_points_label.text = "⭐ %d Skillpunkt%s" % [points, "" if points == 1 else "e"]
	else:
		_points_label.text = "⭐ 0 — jedes Level bringt einen"


# --- Die Auskunft am Zeiger ---------------------------------------------------

## Die Karte erscheint SOFORT und folgt der Maus — sie ist kein Godot-Tooltip mit
## Wartezeit, sondern ein eigenes Control, das der Graph über `hover_changed` ansteuert.
## Wer über ein Netz fährt, um es zu lesen, soll nicht auf jeden Knoten eine halbe Sekunde
## warten.
##
## Über einem KNOTEN steht, was er tut und was ein Klick täte; über dem NAMEN eines Baums
## steht sein Stand. Beide Zeilen kommen aus `SkillTree` — dieselbe Regel, ein Ort.
func _on_hover_changed(id: String, at: Vector2) -> void:
	if id.is_empty() or _confirm.visible:
		_hover.hide()
		return
	var entries: Array = book.entries()
	var node := SkillTree.node_by_id(entries, id)
	if node.is_empty():
		_hover.hide()
		return
	if str(node.get("kind", "")) == "tree":
		_hover.fill(node, SkillTree.tree_status(entries, book.unlocked, id))
	else:
		_hover.fill(node, SkillTree.state_label(entries, node, book.unlocked,
				book.available()))
	_hover.show()
	_place_hover(at)


## Neben den Zeiger, aber nie über den Bildrand hinaus: am rechten oder unteren Rand klappt
## die Karte auf die andere Seite des Zeigers. Eine halb abgeschnittene Auskunft ist keine.
func _place_hover(at: Vector2) -> void:
	# Nur die HÖHE wird nachgeführt (die Breite steht seit `_ready`): sie hängt daran, wie
	# oft der Text umbricht, und das ist bei jedem Knoten anders.
	_hover.size = Vector2(_hover.size.x, _hover.get_combined_minimum_size().y)
	var card := _hover.size
	var to := at + HOVER_GAP
	if to.x + card.x > size.x:
		to.x = at.x - HOVER_GAP.x - card.x
	if to.y + card.y > size.y:
		to.y = at.y - HOVER_GAP.y - card.y
	_hover.global_position = to.clamp(Vector2.ZERO, (size - card).max(Vector2.ZERO))


# --- Klick und Rückfrage ------------------------------------------------------

## Ein Klick ins Netz. Gefragt wird nur, wo es etwas zu entscheiden gibt: der Name eines
## Baums ist nichts zum Lernen, und ein gelernter, gesperrter oder unbezahlbarer Knoten
## führt zu keinem Dialog — warum, steht schon in der Karte, und ein Dialog, der nur
## „geht nicht“ sagt, ist ein Klick zum Wegklicken.
func _on_node_selected(id: String) -> void:
	if id.is_empty():
		return
	var entries: Array = book.entries()
	var node := SkillTree.node_by_id(entries, id)
	if node.is_empty() or str(node.get("kind", "")) != "skill":
		return
	var points: int = book.available()
	if SkillTree.state_of(node, book.unlocked, points) != SkillTree.State.AVAILABLE:
		return
	var cost := SkillTree.cost(node)
	var left := points - cost
	_pending = {"kind": "learn", "id": id}
	_hover.hide()
	_confirm.ask(
			"„%s“ lernen?" % str(node.get("name", id)),
			"%s\n\nDas kostet %d Skillpunkt%s, danach %s noch %d offen. Zurückholen lässt "
			% [str(node.get("description", "")), cost, "" if cost == 1 else "e",
				"ist" if left == 1 else "sind", left]
			+ "sich ein ausgegebener Punkt nur gegen Gold.",
			"Lernen · %d P." % cost)


func _on_respec_pressed() -> void:
	var cost: int = book.respec_cost()
	if cost <= 0 or not Wallet.can_afford(cost):
		return
	# Die zurückkommenden Punkte stehen nicht in `respec_cost`, sondern stecken darin: der
	# Preis ist Gold JE Punkt. Gerechnet statt daneben gezählt — sonst gäbe es hier eine
	# zweite Wahrheit über die Zahl der ausgegebenen Punkte.
	var spent := int(round(float(cost) / float(SkillTree.RESPEC_GOLD_PER_POINT)))
	_pending = {"kind": "respec"}
	_hover.hide()
	_confirm.ask("Alles Gelernte zurücksetzen?",
			"Du bekommst %d Skillpunkt%s zurück und zahlst %s. Das Netz steht danach "
			% [spent, "" if spent == 1 else "e", Wallet.label(cost)]
			+ "wieder am Anfang.",
			"Umlernen")


## Der Kauf kann scheitern (Punkte inzwischen weg) — dann meldet SkillBook nichts und es
## bleibt alles stehen. Geprüft wird dort, nicht hier: eine zweite Prüfung an der
## Oberfläche könnte von der ersten abweichen.
func _on_confirmed() -> void:
	match str(_pending.get("kind", "")):
		"learn":
			book.unlock(str(_pending.get("id", "")))
		"respec":
			book.respec()
	_pending = {}


## Der Umlern-Knopf ist ein Zeichen, also trägt sein TOOLTIP, was sonst auf ihm stünde:
## den Preis, oder den Grund, aus dem es gerade nicht geht. Gesperrt wird er trotzdem —
## ein Knopf, der sich drücken lässt und nichts tut, ist schlechter als einer, der grau
## ist und sagt warum.
func _refresh_respec() -> void:
	var cost: int = book.respec_cost()
	if cost <= 0:
		_respec_button.disabled = true
		_respec_button.tooltip_text = "Umlernen — noch nichts gelernt"
		return
	if not Wallet.can_afford(cost):
		_respec_button.disabled = true
		_respec_button.tooltip_text = "Umlernen kostet %s — du hast %s" % [
			Wallet.label(cost), Wallet.label()]
		return
	_respec_button.disabled = false
	_respec_button.tooltip_text = "Umlernen (%s)" % Wallet.label(cost)
