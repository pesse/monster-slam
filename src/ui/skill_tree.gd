extends Control
## Der Fähigkeitsbaum-Screen: das Netz aller Bäume, der Punktestand und der Ausbau.
##
## Ein FENSTER über dem Start-Screen (profile_menu), kein eigener Screen: das Menü öffnet es
## als Overlay, der Hintergrund bleibt stehen und nimmt keine Eingaben an. ✕ oder Escape
## schließt (`closed`), das Menü gibt den Fokus an seinen Knopf zurück. Entwurf:
## assets/ui/skill_tree/concept/ — dort steht auch, worin die Umsetzung vom Bild abweicht.
##
## Unter der Kopfzeile nichts als das gezeichnete Netz (`SkillGraph`, zoombar mit dem
## Mausrad) — es gibt keine Tafel am Rand mehr, die daneben dasselbe noch einmal erklärt.
## Unten links die Legende, unten rechts die Werkzeuge (−, Zoom, +, Einpassen, Umlernen).
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
## stehen (`state_name`, `tree_status`); `SkillBook` hält das Gelernte. Dieser Screen weiß
## von beiden nur, was er zum Anzeigen braucht, und entscheidet nichts selbst.

const MENU_SCENE := "res://scenes/ui/profile_menu.tscn"

## So lange blendet das Fenster auf (s).
const FADE_IN := 0.15

## Das Fenster will zu. Wer es geöffnet hat, nimmt es weg; hängt niemand daran (der Screen
## läuft allein, etwa aus dem Editor), geht es zurück ins Startmenü.
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
	# Die Fläche sucht ihre Treffer selbst, also antwortet sie auch selbst: `Hints` fragt
	# bei jeder Bewegung nach, was an diesem Punkt zu sagen ist.
	Hints.attach_live(_graph, _hint_at)
	Hints.attach(_fit_button, "Ansicht einpassen", "Mausrad zoomt, Ziehen verschiebt")
	Hints.attach(_zoom_in, "Näher heran")
	Hints.attach(_zoom_out, "Weiter weg")
	Hints.attach(%CloseButton as Control, "Schließen", "", "Esc")
	# Beide Stände hängen am Signal, statt nachzufragen: das Gelernte ändert sich hier,
	# das Gold beim Umlernen — und der Umlern-Knopf trägt beides in seinem Tooltip.
	book.changed.connect(_rebuild)
	Wallet.changed.connect(func(_gold: int) -> void:
			_refresh_respec()
			Hints.refresh())
	_rebuild()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, FADE_IN)
	# Pfeile und Enter gehen sofort ans Netz — ohne dass erst jemand hineinklicken muss.
	_graph.grab_focus.call_deferred()


## Schließt das Fenster: meldet es dem, der es geöffnet hat (das Menü nimmt es weg), oder
## geht allein zurück ins Startmenü.
func close() -> void:
	if closed.get_connections().is_empty():
		get_tree().change_scene_to_file(MENU_SCENE)
		return
	closed.emit()


## Escape schließt — außer eine Rückfrage ist offen: die fängt die Taste selbst
## (`ConfirmDialog._input`), und hier kommt dann nichts mehr an.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


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
	# Der Stern steht als Bild davor (PointsIcon).
	if bool(book.get("unlimited_points")):
		_points_label.text = "∞ Skillpunkte (Debug)"
	elif points > 0:
		_points_label.text = "%d Skillpunkt%s" % [points, "" if points == 1 else "e"]
	else:
		_points_label.text = "0 — jedes Level bringt einen"


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
	if str(node.get("kind", "")) == "tree":
		return {
			"title": str(node.get("name", "")),
			"body": str(node.get("description", "")),
			"note": SkillTree.tree_status(entries, book.unlocked, id),
		}
	var points: int = book.available()
	# Was ein Klick kostet, steht als Zeichen im Kopf: ungelernt die Skillpunkte, gelernt
	# das Gold fürs Verlernen. Einen Satz gibt es nur noch, wenn das Gold nicht reicht —
	# Zustand und Vorstufe sagen Unterzeile und Liste schon.
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
		# Ohne Bild trägt der Name das Zeichen aus den Daten, wie im Netz selbst.
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


## Die Voraussetzungen als Zeilen der Karte, jede mit ihrem Zeichen: Haken für eine
## erfüllte Vorstufe, Schloss für eine fehlende. Der Preis steht im Kopf (`prices`).
func _facts(entries: Array, node: Dictionary) -> Array:
	var rows: Array = []
	for required in node.get("requires", []):
		var id := str(required)
		var name := str(SkillTree.node_by_id(entries, id).get("name", id))
		rows.append([SkillIcons.check() if book.is_unlocked(id) else SkillIcons.lock(),
				"Voraussetzung", name])
	return rows


## Der Nachsatz an einem gelernten Knoten: nur, wenn das Gold fürs Verlernen nicht
## reicht — sonst sagt der Preis im Kopf alles.
func _forget_note(id: String) -> String:
	var cost: int = book.forget_cost(id)
	if Wallet.can_afford(cost):
		return ""
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
