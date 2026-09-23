extends Control
## Der Fähigkeitsbaum-Screen: das Netz aller Bäume, der Punktestand und der Ausbau.
##
## Vom Start-Screen aus erreichbar (profile_menu), neben Statistik und Einstellungen.
## Unter der Kopfzeile nichts als das gezeichnete Netz (`SkillGraph`, zoombar mit dem
## Mausrad) — es gibt keine Tafel am Rand mehr, die daneben dasselbe noch einmal erklärt.
##
## Alles, was zu einem Knoten zu sagen ist, steht am ZEIGER: die Karte aus `Hints` folgt
## der Maus, ohne Verzögerung, und trägt Name, Wirkung und Zustand. Über dem NAMEN eines
## Baums zeigt dieselbe Karte den Stand des ganzen Baums — das, was früher am rechten Rand
## stand. Es ist dieselbe Karte, die im ganzen Spiel erklärt; dieser Screen liefert ihr nur
## den Inhalt für seine Fläche (`_hint_at`). Und
## ein Klick fragt nach, statt sofort zu buchen (`ConfirmDialog`): ein ausgegebener
## Skillpunkt kommt nur gegen Gold zurück, das ist keine Entscheidung für einen
## unbeabsichtigten Klick.
##
## Die REGELN stehen woanders: `SkillTree` in src/progression/ (statisch) rechnet Stufen,
## Voraussetzungen, Kosten, Plätze und Boni — bis hin zu den Zeilen, die in der Karte
## stehen (`state_label`, `tree_status`); `SkillBook` hält das Gelernte. Dieser Screen weiß
## von beiden nur, was er zum Anzeigen braucht, und entscheidet nichts selbst.

const MENU_SCENE := "res://scenes/ui/profile_menu.tscn"

@onready var _graph: SkillGraph = %Graph
@onready var _points_label: Label = %PointsLabel
@onready var _empty_hint: Label = %EmptyHint
@onready var _fit_button: Button = %FitButton
@onready var _respec_button: Button = %RespecButton
@onready var _confirm: ConfirmDialog = %Confirm

## Das Buch, aus dem gelesen und in das gebucht wird — im Spiel das Autoload `SkillBook`.
## Ein Test schiebt hier eine eigene Instanz mit erfundenem Baum unter und hängt damit
## weder am echten Profil des Spielers noch an der Balance der ausgelieferten Bäume
## (tests/skill_tree_screen_test.gd). Gesetzt wird es VOR dem Einhängen in den Baum.
var book: Node = null

## Worauf die offene Rückfrage hinausläuft: `{"kind": "learn", "id": …}`,
## `{"kind": "forget", "id": …}` oder `{"kind": "respec"}`. Der Dialog kennt seinen Inhalt nicht — er fragt und meldet, und
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
	_confirm.confirmed.connect(_on_confirmed)
	_confirm.cancelled.connect(func() -> void: _pending = {})
	# Die Fläche sucht ihre Treffer selbst, also antwortet sie auch selbst: `Hints` fragt
	# bei jeder Bewegung nach, was an diesem Punkt zu sagen ist.
	Hints.attach_live(_graph, _hint_at)
	Hints.attach(_fit_button, "Ansicht einpassen", "Mausrad zoomt, Ziehen verschiebt")
	# Beide Stände hängen am Signal, statt nachzufragen: das Gelernte ändert sich hier,
	# das Gold beim Umlernen — und der Umlern-Knopf trägt beides in seinem Tooltip.
	book.changed.connect(_rebuild)
	Wallet.changed.connect(func(_gold: int) -> void:
			_refresh_respec()
			Hints.refresh())
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
	# Die Karte trägt einen Stand, den es gerade nicht mehr gibt — ein gekaufter Knoten
	# verschiebt die Zustände seines ganzen Astes. Nachfragen statt verstecken: sie steht
	# sofort mit dem neuen da und nicht erst beim nächsten Mausschubser.
	Hints.refresh()
	_refresh_points(book.available())
	_refresh_respec()


func _refresh_points(points: int) -> void:
	if points > 0:
		_points_label.text = "⭐ %d Skillpunkt%s" % [points, "" if points == 1 else "e"]
	else:
		_points_label.text = "⭐ 0 — jedes Level bringt einen"


# --- Die Auskunft am Zeiger ---------------------------------------------------

## Was über einem Punkt des Netzes zu sagen ist — oder nichts. Die Karte erscheint damit
## SOFORT und folgt der Maus; wer über ein Netz fährt, um es zu lesen, soll nicht auf jeden
## Knoten eine halbe Sekunde warten.
##
## Über einem KNOTEN steht, was er tut und was ein Klick täte; über dem NAMEN eines Baums
## steht sein Stand. Beide Zeilen kommen aus `SkillTree` — dieselbe Regel, ein Ort. Das
## Zeichen gehört zum Namen und nicht zur Karte: die kennt Zeichenketten, keine Knoten.
##
## Geschwiegen wird an zwei Stellen. Beim ZIEHEN wandert das ganze Netz unter dem Zeiger
## durch, eine mitlaufende Karte wäre nur Flackern. Und über einer offenen RÜCKFRAGE stünde
## sie über dem abgedunkelten Bild.
func _hint_at(local: Vector2) -> Dictionary:
	if _graph.is_panning() or _confirm.visible:
		return {}
	var entries: Array = book.entries()
	var node := SkillTree.node_by_id(entries, _graph.id_at(local))
	if node.is_empty():
		return {}
	var id := str(node.get("id", ""))
	var note := SkillTree.tree_status(entries, book.unlocked, id) \
			if str(node.get("kind", "")) == "tree" \
			else SkillTree.state_label(entries, node, book.unlocked, book.available())
	if book.is_unlocked(id):
		note += " · " + _forget_note(id)
	return {
		"title": "%s %s" % [SkillTree.icon_of(node), str(node.get("name", ""))],
		"body": str(node.get("description", "")),
		"note": note,
	}


## Die zweite Hälfte der Zeile an einem gelernten Knoten: was das Verlernen kostet, oder
## warum es gerade nicht geht. Der Preis steht hier und nicht in `state_label`, weil er am
## Gold hängt, und das kennen die Regeln nicht.
func _forget_note(id: String) -> String:
	var cost: int = book.forget_cost(id)
	if Wallet.can_afford(cost):
		return "Klicken zum Verlernen · %s" % Wallet.label(cost)
	return "Verlernen kostet %s — du hast %s" % [Wallet.label(cost), Wallet.label()]


# --- Klick und Rückfrage ------------------------------------------------------

## Ein Klick ins Netz. Gefragt wird nur, wo es etwas zu entscheiden gibt: der Name eines
## Baums ist nichts zum Lernen, und ein gesperrter oder unbezahlbarer Knoten führt zu
## keinem Dialog — warum, steht schon in der Karte, und ein Dialog, der nur „geht nicht“
## sagt, ist ein Klick zum Wegklicken. Ein GELERNTER Knoten fragt, ob er verlernt werden
## soll — sofern das Gold dafür reicht; sonst gilt dasselbe wie beim unbezahlbaren.
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
	_confirm.ask(
			"„%s“ lernen?" % str(node.get("name", id)),
			"%s\n\nDas kostet %d Skillpunkt%s, danach %s noch %d offen. Zurückholen lässt "
			% [str(node.get("description", "")), cost, "" if cost == 1 else "e",
				"ist" if left == 1 else "sind", left]
			+ "sich ein ausgegebener Punkt nur gegen Gold.",
			"Lernen · %d P." % cost)


## Die Rückfrage vor dem Verlernen nennt JEDEN Knoten, der mitfällt, beim Namen: dass die
## Äste darüber mitgehen, ist die eine Stelle, an der das Verlernen überraschen könnte.
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
	# Die zurückkommenden Punkte stehen nicht in `respec_cost`, sondern stecken darin: der
	# Preis ist Gold JE Punkt. Gerechnet statt daneben gezählt — sonst gäbe es hier eine
	# zweite Wahrheit über die Zahl der ausgegebenen Punkte.
	var spent := int(round(float(cost) / float(SkillTree.RESPEC_GOLD_PER_POINT)))
	_pending = {"kind": "respec"}
	Hints.refresh()
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
		"forget":
			book.forget(str(_pending.get("id", "")))
		"respec":
			book.respec()
	_pending = {}


## Der Umlern-Knopf ist ein Zeichen, also trägt seine KARTE, was sonst auf ihm stünde: den
## Preis, oder den Grund, aus dem es gerade nicht geht. Gesperrt wird er trotzdem — ein
## Knopf, der sich drücken lässt und nichts tut, ist schlechter als einer, der grau ist und
## sagt warum. Dass ein gesperrter Knopf überhaupt sprechen darf, hängt daran, dass
## `disabled` die Trefferprüfung nicht anfasst (tests/hints_test.gd).
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
