class_name SkillGraph
extends Control
## Das gezeichnete Netz der Fähigkeitsbäume: runde Knoten, Verbindungslinien, Zoom mit
## dem Mausrad und Ziehen mit der Maus.
##
## Gezeichnet statt gebaut: neun Karten wären neun Controls, aber neun Zustände (drei
## Bäume mal vier Zustände) wären auch neun Theme-Variationen — und die Farbe eines Baums
## soll aus seiner JSON kommen (`color`), nicht aus dem Theme. Mit `_draw()` ist ein
## vierter Baum eine Datei in data/skills/ und sonst nichts.
##
## WO ein Knoten liegt, rechnet `SkillTree.layout()` — reine Zahlen, für sich prüfbar
## (tests/skill_graph_layout_test.gd). Dieses Control macht daraus Pixel und nimmt
## Eingaben entgegen; es entscheidet nichts über Kosten, Voraussetzungen oder Käufe.
##
## Jeder Baum hat seinen EIGENEN Anfangspunkt — es gibt keine gemeinsame Mitte, an der
## alles hängt. Verbindungslinien laufen deshalb vorerst nur innerhalb eines Baums; dass
## später Linien zwischen Bäumen dazukommen, ändert hier nur, welche `requires` gefunden
## werden, nicht die Art zu zeichnen.

## Ein Knoten wurde angeklickt oder mit Enter bestätigt (leer: daneben geklickt). Was das
## bedeutet, entscheidet der Screen — dieses Control lernt nichts.
signal node_selected(id: String)

## Zoom oder Ausschnitt haben sich geändert — für die Prozentanzeige der Werkzeugleiste.
signal view_changed()

const MIN_ZOOM := 0.35
const MAX_ZOOM := 2.0

## Faktor je Rasterschritt des Mausrads. 1.12 sind rund 20 Schritte über den ganzen
## Bereich — fein genug zum Zielen, grob genug, um nicht zu kurbeln.
const ZOOM_STEP := 1.12

## Ab wie vielen Pixeln ein Druck ein Ziehen ist. Ohne diese Schwelle verschöbe jeder
## Klick das Netz um ein, zwei Pixel und wäre danach kein Klick mehr.
const DRAG_SLOP := 4.0

## Rand zwischen Netz und Kante beim Einpassen.
const FIT_PAD := 24.0

## Strichstärken der Verbindungen: eine gelernte Kante ist dicker, nicht nur heller —
## Farbe allein trägt auf dunklem Grund zu wenig.
const EDGE_WIDTH := 2.0
const EDGE_WIDTH_LEARNED := 4.0

## Deckkraft von Füllung und Rand des gemeinsamen Hofes. Bewusst schwach: er soll den
## Blick auf den Anfang lenken und nicht mit den Knoten darauf konkurrieren.
const ROOT_HALO_FILL_ALPHA := 0.05
const ROOT_HALO_RING_ALPHA := 0.2

## --- Medaillons (assets/ui/skill_tree/README.md) ---
## Die Medaillon-Textur ist 256 px breit, ihr Ring reicht außen bis 111 px und innen bis
## 90 px vom Mittelpunkt (gemessen mit `skill_tree_lab -- --medallion`). Gezeichnet wird sie
## so groß, dass der Ring außen auf `SkillTree.NODE_RADIUS` liegt.
const MEDALLION_OUTER := 111.0 / 128.0
const MEDALLION_INNER := 90.0 / 128.0
## Das Icon im Medaillon: 52 von 80 px, wie im Einbaupaket empfohlen.
const ICON_SHARE := 52.0 / 80.0
## Schloss statt Icon, etwas kleiner — es ist ein Zustand und kein Motiv.
const LOCK_SHARE := 0.42
## Haken unten rechts, 20 von 80 px.
const CHECK_SHARE := 20.0 / 80.0

## Die Ringfarbe kommt vom BAUM, der Zustand nur von ihrer Stärke: gedämpft für gesperrt
## und zu teuer, hell für lernbar und gelernt. Gelernt tönt zusätzlich die Mitte, als
## Verlauf: am Ring kräftig, zur Mitte hin schwach — der Knoten hebt sich ab, und das Icon
## steht trotzdem frei. Der Haken macht den Zustand eindeutig.
const RING_BRIGHT := 1.3
const RING_DIM := 0.55
const LEARNED_TINT_EDGE := 0.6
const LEARNED_TINT_CENTRE := 0.0
## Ab hier (Anteil des Radius) steigt der Verlauf erst an: nur ein Saum am Ring, sonst
## verdeckte das Icon den Übergang und es sähe wieder wie eine Fläche aus.
const LEARNED_TINT_START := 0.55
## Das Icon eines zu teuren Knotens: da, aber zurückgenommen.
const ICON_DIM := Color(0.6, 0.6, 0.65, 1)

## Schrift im Netz wächst und schrumpft mit dem Zoom, aber nicht unter diesen Anteil ihrer
## Größe im Theme. Eingepasst steht das Netz in der Grundauflösung bei rund 60 % — die Namen
## wären dann 8 px hoch und nicht mehr zu lesen. Zwischen den Knoten ist Platz genug, dass
## sie etwas größer sein dürfen als ihr Maßstab.
const MIN_LABEL_SCALE := 0.8

## Tastatur: ein Pfeil springt zum nächsten Knoten, der in dieser Richtung liegt. „In der
## Richtung" heißt: höchstens 60° neben ihr (cos 60° = 0.5).
const STEP_CONE := 0.5
## So viel Rand bleibt, wenn ein angesprungener Knoten ins Bild geschoben wird.
const FOCUS_PAD := 48.0
## Ecken der Hof-Ellipse — rund genug, dass man keine sieht.
const HALO_SEGMENTS := 72

## Der Verlauf der Tönung, weiß und einmal gebaut; die Baumfarbe kommt als modulate dazu.
static var _learned_tint: GradientTexture2D = null

var _entries: Array = []
var _unlocked: PackedStringArray = PackedStringArray()
var _points: int = 0

## Id -> Position im Netz (Ursprung in der Mitte), aus SkillTree.layout().
var _places: Dictionary = {}
var _selected: String = ""

var _zoom: float = 1.0
## Wo der Ursprung des Netzes im Control liegt.
var _origin: Vector2 = Vector2.ZERO

## Solange der Spieler nichts verschoben hat, passt sich das Netz jeder Größenänderung neu
## ein. Danach nicht mehr: ein Fensterwechsel darf den gewählten Ausschnitt nicht
## zurücksetzen.
var _touched := false

var _press_at: Vector2 = Vector2.ZERO
var _pressed := false
var _dragging := false

## Der Knoten unter dem Zeiger — für den hellen Ring, an dem man sieht, was man trifft.
var _hovered: String = ""

## Der Knoten, auf dem die Tastatur steht, und ob sie zuletzt benutzt wurde. Der Ring dafür
## erscheint erst nach dem ersten Pfeil: wer mit der Maus kommt, soll nicht einen
## leuchtenden Knoten sehen, den er nie gewählt hat.
var _focused: String = ""
var _keyboard := false

## Der Zoom nach dem letzten Einpassen — die 100 % der Prozentanzeige.
var _fit_zoom: float = 1.0


func _ready() -> void:
	resized.connect(func() -> void:
		if not _touched:
			fit())
	mouse_exited.connect(func() -> void: _set_hovered(""))
	focus_exited.connect(func() -> void:
		_keyboard = false
		queue_redraw())


## Setzt den Inhalt: Knoten, Gelerntes und die offenen Punkte. Der Ausschnitt bleibt, wo
## er ist — nach einem Kauf soll das Netz nicht springen. Nur beim ersten Mal (und solange
## der Spieler nichts verschoben hat) wird eingepasst.
func setup(entries: Array, unlocked: PackedStringArray, points: int) -> void:
	_entries = entries
	_unlocked = unlocked
	_points = points
	_places = SkillTree.layout(entries)
	if not _places.has(_selected):
		_selected = ""
	if not _places.has(_focused):
		_focused = ""
	if not _touched:
		fit()
	queue_redraw()


## Der gerade gewählte Knoten (leer: keiner).
func selected_id() -> String:
	return _selected


func select(id: String) -> void:
	var wanted := id if _places.has(id) else ""
	if wanted != _selected:
		_selected = wanted
		queue_redraw()
	# Gemeldet wird JEDER Klick, auch der auf den schon gewählten Knoten. Seit die Frage in
	# einem Dialog steht, ist ein Klick keine Auswahl mehr, sondern ein Antrag — und wer
	# abbricht, muss denselben Knoten ein zweites Mal anklicken können.
	node_selected.emit(_selected)


## Passt das ganze Netz in die sichtbare Fläche ein. Auch der Weg zurück, wenn man sich
## verzoomt hat — der Screen hängt ihn an einen Knopf.
func fit() -> void:
	_touched = false
	var box := SkillTree.bounds(_places)
	if box.size.x <= 0.0 or box.size.y <= 0.0 or size.x <= 0.0 or size.y <= 0.0:
		_zoom = 1.0
		_fit_zoom = _zoom
		_origin = size * 0.5
		queue_redraw()
		view_changed.emit()
		return
	var room := size - Vector2.ONE * FIT_PAD * 2.0
	_zoom = clampf(minf(room.x / box.size.x, room.y / box.size.y), MIN_ZOOM, MAX_ZOOM)
	_fit_zoom = _zoom
	# Die Mitte des Netzes auf die Mitte der Fläche: `box` liegt nicht symmetrisch um den
	# Ursprung, sobald ein Baum mehr Stufen hat als der andere.
	_origin = size * 0.5 - box.get_center() * _zoom
	queue_redraw()
	view_changed.emit()


## Zoomt um die Mitte der Fläche — für die Knöpfe −/+ der Werkzeugleiste.
func zoom_by(factor: float) -> void:
	_zoom_at(size * 0.5, factor)


## Der Zoom in Prozent des eingepassten: „Einpassen" ist 100 %. Ein absoluter Wert sagte
## dem Spieler nichts — das eingepasste Netz stünde je nach Fenster bei 60 oder 90 %.
func zoom_percent() -> int:
	return int(round(_zoom / maxf(_fit_zoom, 0.001) * 100.0))


# --- Eingabe ------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventJoypadButton \
			or event is InputEventJoypadMotion:
		_on_key(event)
		return
	var button := event as InputEventMouseButton
	if button != null:
		_on_button(button)
		return
	var motion := event as InputEventMouseMotion
	if motion == null:
		return
	# Das Ziehen fängt erst jenseits der Schwelle an. Ohne sie verschöbe jeder Klick das
	# Netz um ein, zwei Pixel — und wäre danach kein Klick mehr, sondern ein Zug.
	if _pressed and not _dragging \
			and _press_at.distance_to(motion.position) > DRAG_SLOP:
		_dragging = true
	if _keyboard:
		_keyboard = false
		queue_redraw()
	if not _dragging:
		_set_hovered(id_at(motion.position))
		return
	_set_hovered("")
	_touched = true
	_origin += motion.relative
	queue_redraw()
	view_changed.emit()
	accept_event()


## Pfeile springen von Knoten zu Knoten, Enter bestätigt — dieselbe Aktion wie ein Klick.
## Der erste Pfeil setzt nur auf: er wählt den Anfangsknoten, der der Mitte der Fläche am
## nächsten liegt, statt schon irgendwohin zu springen.
func _on_key(event: InputEvent) -> void:
	for pair: Array in [["ui_left", Vector2.LEFT], ["ui_right", Vector2.RIGHT],
			["ui_up", Vector2.UP], ["ui_down", Vector2.DOWN]]:
		if event.is_action_pressed(str(pair[0]), true):
			_keyboard = true
			_set_focused(_step(pair[1]) if not _focused.is_empty() else _nearest(size * 0.5))
			accept_event()
			return
	if event.is_action_pressed("ui_accept") and _keyboard and not _focused.is_empty():
		select(_focused)
		accept_event()


## Der Knoten, auf dem die Tastatur steht (leer: keiner).
func focused_id() -> String:
	return _focused


func _set_focused(id: String) -> void:
	if id.is_empty():
		return
	_focused = id
	_keep_in_view(id)
	queue_redraw()


## Der nächste Knoten von `_focused` aus in Richtung `dir`. Gewertet wird die Entfernung,
## verlängert um die Abweichung von der Richtung — sonst gewänne ein naher Knoten schräg
## daneben gegen den, der genau in der Richtung liegt. Gibt es keinen, bleibt es beim alten.
func _step(dir: Vector2) -> String:
	var from := screen_position(_focused)
	var best := _focused
	var best_score := INF
	for id in _skill_ids():
		if id == _focused:
			continue
		var offset := screen_position(id) - from
		if offset.length() < 0.001:
			continue
		var along := offset.normalized().dot(dir)
		if along < STEP_CONE:
			continue
		var score := offset.length() * (2.0 - along)
		if score < best_score:
			best_score = score
			best = id
	return best


## Der Knoten, der `point` am nächsten liegt.
func _nearest(point: Vector2) -> String:
	var best := ""
	var best_gap := INF
	for id in _skill_ids():
		var gap := screen_position(id).distance_to(point)
		if gap < best_gap:
			best_gap = gap
			best = id
	return best


func _skill_ids() -> Array[String]:
	var out: Array[String] = []
	for id: String in _places:
		if SkillTree.node_by_id(_entries, id).get("kind", "") == "skill":
			out.append(id)
	return out


## Schiebt den Ausschnitt so weit, dass `id` mit etwas Rand im Bild liegt. Nur so weit wie
## nötig: ein Sprung zum Nachbarn soll das Netz nicht jedes Mal neu zentrieren.
func _keep_in_view(id: String) -> void:
	var at := screen_position(id)
	var pad := FOCUS_PAD + SkillTree.NODE_RADIUS * _zoom
	var inner := Rect2(Vector2.ONE * pad, size - Vector2.ONE * pad * 2.0)
	if inner.size.x <= 0.0 or inner.size.y <= 0.0 or inner.has_point(at):
		return
	var shift := Vector2(
			clampf(at.x, inner.position.x, inner.end.x) - at.x,
			clampf(at.y, inner.position.y, inner.end.y) - at.y)
	_origin += shift
	_touched = true
	view_changed.emit()


func _on_button(button: InputEventMouseButton) -> void:
	match button.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			if button.pressed:
				_zoom_at(button.position, ZOOM_STEP)
				_set_hovered(id_at(button.position))
				accept_event()
		MOUSE_BUTTON_WHEEL_DOWN:
			if button.pressed:
				_zoom_at(button.position, 1.0 / ZOOM_STEP)
				_set_hovered(id_at(button.position))
				accept_event()
		MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE:
			if button.pressed:
				_pressed = true
				_dragging = button.button_index == MOUSE_BUTTON_MIDDLE
				_press_at = button.position
			else:
				# Ein Klick, der kein Zug war, wählt — auch daneben: dann fällt die
				# Auswahl weg, und der Screen zeigt wieder seinen Hinweis.
				if not _dragging and button.button_index == MOUSE_BUTTON_LEFT:
					select(id_at(button.position))
				_pressed = false
				_dragging = false
			accept_event()


## Der helle Ring um den Knoten unter dem Zeiger. Gezeichnet wird nur neu, wenn sich der
## Knoten ÄNDERT.
##
## Die Auskunftskarte hängt nicht mehr daran: `Hints` fragt jeden Frame, was unter dem
## Zeiger liegt, und der Screen antwortet für diese Fläche (`SkillTree._hint_at`). Dieses
## Control beschneidet seine Zeichnung (`clip_contents`), eine Karte darin wäre am Rand
## ohnehin halb weg.
func _set_hovered(id: String) -> void:
	if _hovered == id:
		return
	_hovered = id
	queue_redraw()


## Ob gerade geschoben wird. Öffentlich, weil die Auskunft am Zeiger es wissen muss und
## der Graph sie nicht selbst stellt: beim Ziehen wandert das ganze Netz unter dem Zeiger
## durch, und eine Karte, die dabei bei jedem Pixel ihren Inhalt wechselt, ist Flackern.
func is_panning() -> bool:
	return _dragging


## Zoomt um einen Punkt der Fläche herum: was unter dem Mauszeiger liegt, bleibt dort.
## Ohne das wandert das Netz beim Zoomen aus dem Bild, und man zoomt mit einer Hand und
## schiebt mit der anderen hinterher.
func _zoom_at(point: Vector2, factor: float) -> void:
	var before := clampf(_zoom, MIN_ZOOM, MAX_ZOOM)
	var after := clampf(before * factor, MIN_ZOOM, MAX_ZOOM)
	if is_equal_approx(before, after):
		return
	var graph_point := (point - _origin) / before
	_zoom = after
	_origin = point - graph_point * after
	_touched = true
	queue_redraw()
	view_changed.emit()


## Der aktuelle Zoomfaktor (für Anzeige und Test).
func zoom() -> float:
	return _zoom


## Die Id des Knotens unter `point` (Koordinaten dieses Controls), sonst leer. Geprüft
## wird gegen den gezeichneten Radius, nicht gegen ein Rechteck: die Knoten sind rund, und
## zwischen zwei nahen Knoten soll die Lücke auch eine sein.
func id_at(point: Vector2) -> String:
	for id: String in _places:
		if SkillTree.node_by_id(_entries, id).get("kind", "") != "skill":
			continue
		if _to_screen(_places[id]).distance_to(point) <= SkillTree.NODE_RADIUS * _zoom:
			return id
	# Danach die Namen der Bäume. Sie sind nichts zum Lernen, aber etwas zum Nachsehen:
	# ihre Karte trägt den Stand des ganzen Baums — das, was früher am rechten Bildrand
	# stand. Der Screen unterscheidet die beiden Fälle an `kind`.
	for tree in SkillTree.trees(_entries):
		if _title_rect(tree as Dictionary).has_point(point):
			return str((tree as Dictionary).get("id", ""))
	return ""


## Das Feld, in dem der Name eines Baums steht. Gerechnet und nicht beim Zeichnen gemerkt:
## `id_at` darf nicht davon abhängen, dass vorher einmal gezeichnet wurde.
func _title_rect(tree: Dictionary) -> Rect2:
	var font_size := int(get_theme_font_size("font_size", "SectionTitle") * _label_scale())
	if font_size <= 0:
		return Rect2()
	var text := str(tree.get("name", ""))
	var width := get_theme_default_font().get_string_size(
			text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	# `draw_string` setzt den Text auf die GRUNDLINIE — das Feld liegt also darüber.
	var place: Vector2 = _places.get(str(tree.get("id", "")), Vector2.ZERO)
	var at := _to_screen(place)
	var box := Rect2(at - Vector2(width * 0.5, float(font_size)),
			Vector2(width, float(font_size) * 1.3))
	# Der Platz ist der innere Rand des Namens, nicht seine Mitte: das Feld rückt entlang
	# der Achse seines Baums nach außen. Sonst wüchse ein langer Name — oder die
	# Mindestschrift bei kleinem Zoom — zurück in die Knoten seines eigenen Baums.
	var axis := place.normalized()
	return Rect2(box.position + axis * box.size * 0.5, box.size)


## Wo ein Knoten gerade auf der Fläche liegt — die Umkehrung von `id_at`, gebraucht zum
## Zielen (und im Test zum Klicken).
## Bei einem Baum ist das die Mitte seines Namens, nicht dessen Platz (der ist der innere Rand).
func screen_position(id: String) -> Vector2:
	var node := SkillTree.node_by_id(_entries, id)
	if node.get("kind", "") == "tree":
		return _title_rect(node).get_center()
	return _to_screen(_places.get(id, Vector2.ZERO))


## Maßstab der Schrift im Netz (siehe `MIN_LABEL_SCALE`).
func _label_scale() -> float:
	return maxf(_zoom, MIN_LABEL_SCALE)


func _to_screen(point: Vector2) -> Vector2:
	return point * _zoom + _origin


# --- Zeichnen -----------------------------------------------------------------

## Gezeichnet wird mit dem Zoom im Radius und in der Schriftgröße, nicht über
## `draw_set_transform`: eine skalierte Zeichnung macht aus dem Text eine vergrößerte
## Textur, und bei doppeltem Zoom wären die Namen unscharf.
func _draw() -> void:
	if _places.is_empty():
		return
	_draw_root_halo()
	for tree in SkillTree.trees(_entries):
		_draw_tree(tree as Dictionary)


func _draw_tree(tree: Dictionary) -> void:
	var tree_id := str(tree.get("id", ""))
	var color := SkillTree.color_of(tree)
	var nodes: Array = []
	for tier in SkillTree.tiers_of(_entries, tree_id):
		nodes.append_array(tier as Array)

	# Erst alle Linien, dann alle Knoten: sonst läge eine Linie über dem Kreis, aus dem
	# sie kommt.
	for entry in nodes:
		var node := entry as Dictionary
		var to: Vector2 = _places.get(str(node.get("id", "")), Vector2.ZERO)
		for required in node.get("requires", []):
			if not _places.has(str(required)):
				continue
			_draw_edge(_places[str(required)], to, color,
					str(node.get("id", "")) in _unlocked, str(required) in _unlocked)

	_draw_tree_title(tree, color)
	for entry in nodes:
		_draw_node(entry as Dictionary, color)


## Der GEMEINSAME Hof, auf dem alle Bäume anfangen — ein Kreis um die Mitte, hinter allen
## Anfangsknoten. Die Anfangspunkte bleiben getrennt; was sie teilen, ist der Anfang.
##
## Deshalb ist er neutral gefärbt und nicht in einer Baumfarbe: er gehört keinem Baum. Er
## wird als ERSTES gezeichnet, vor jedem Baum — sonst läge er über den Linien und Knoten
## des Baums, der vor ihm an der Reihe war.
func _draw_root_halo() -> void:
	var axes := SkillTree.root_halo_size() * _zoom
	var at := _to_screen(Vector2.ZERO)
	var tone := get_theme_color("font_color", "Hint")
	var fill := tone
	fill.a = ROOT_HALO_FILL_ALPHA
	var ring := tone
	ring.a = ROOT_HALO_RING_ALPHA
	# Eine Ellipse, weil das Netz gestreckt ist (`SkillTree.STRETCH`). Als Vieleck statt
	# über eine skalierte Zeichnung: die verzöge auch die Strichstärke des Randes.
	var outline := PackedVector2Array()
	for i in HALO_SEGMENTS + 1:
		outline.append(at + Vector2.from_angle(TAU * float(i) / HALO_SEGMENTS) * axes)
	draw_colored_polygon(outline.slice(0, HALO_SEGMENTS), fill)
	draw_polyline(outline, ring, 2.0 * _zoom, true)


## Radial: innen LEARNED_TINT_CENTRE bis LEARNED_TINT_START, dann steigend bis
## LEARNED_TINT_EDGE am Rand, dahinter nichts — die
## Ecken des Rechtecks bleiben leer (ohne den letzten Punkt füllte der Verlauf sie mit).
static func _learned_tint_texture() -> GradientTexture2D:
	if _learned_tint == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1.0, 1.0, 1.0, LEARNED_TINT_CENTRE))
		gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
		gradient.add_point(LEARNED_TINT_START, Color(1.0, 1.0, 1.0, LEARNED_TINT_CENTRE))
		gradient.add_point(0.96, Color(1.0, 1.0, 1.0, LEARNED_TINT_EDGE))
		_learned_tint = GradientTexture2D.new()
		_learned_tint.gradient = gradient
		_learned_tint.fill = GradientTexture2D.FILL_RADIAL
		_learned_tint.fill_from = Vector2(0.5, 0.5)
		_learned_tint.fill_to = Vector2(1.0, 0.5)
		_learned_tint.width = 128
		_learned_tint.height = 128
	return _learned_tint


## Eine Kante hat drei Helligkeiten: der begangene Weg (beide Enden gelernt), der offene
## (die Vorstufe ist da) und der noch verschlossene. Damit sieht man den Ast, an dem man
## gerade baut, ohne ihn zu suchen.
func _draw_edge(from: Vector2, to: Vector2, color: Color, learned: bool,
		open_path: bool) -> void:
	var tint := color
	var width := EDGE_WIDTH
	if learned:
		width = EDGE_WIDTH_LEARNED
	elif open_path:
		tint = color.darkened(0.25)
		tint.a = 0.7
	else:
		tint = color.darkened(0.55)
		tint.a = 0.45
	draw_line(_to_screen(from), _to_screen(to), tint, width * _zoom, true)


## Der Name des Baums steht AUSSEN, jenseits seines äußersten Knotens auf der Achse des
## Fächers (`SkillTree.layout` gibt ihm dort seinen Platz). Nicht am Anfang: dort laufen
## die Linien zusammen, dort liegen bei mehreren Bäumen auch die Nachbarnamen, und ein
## Name über einem Knoten verdeckt genau das, was er benennen soll. Außen ist nichts.
func _draw_tree_title(tree: Dictionary, color: Color) -> void:
	var rect := _title_rect(tree)
	if rect.size.x <= 0.0:
		return
	var font_size := int(get_theme_font_size("font_size", "SectionTitle") * _label_scale())
	var tint := color
	if str(tree.get("id", "")) == _hovered:
		tint = color.lightened(0.35)
	draw_string(get_theme_default_font(),
			Vector2(rect.position.x, rect.position.y + float(font_size)),
			str(tree.get("name", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, tint)


func _draw_node(node: Dictionary, color: Color) -> void:
	var id := str(node.get("id", ""))
	var at := _to_screen(_places.get(id, Vector2.ZERO))
	var radius := SkillTree.NODE_RADIUS * _zoom
	var state := SkillTree.state_of(node, _unlocked, _points)
	var bright := state == SkillTree.State.LEARNED or state == SkillTree.State.AVAILABLE

	# Das Medaillon: silbern, mit der Farbe des Baums überzogen — hell oder gedämpft.
	var side := radius * 2.0 / MEDALLION_OUTER
	var rect := Rect2(at - Vector2.ONE * side * 0.5, Vector2.ONE * side)
	var ring := color * (RING_BRIGHT if bright else RING_DIM)
	ring.a = 1.0
	draw_texture_rect(SkillIcons.medallion(), rect, false, ring)
	if state == SkillTree.State.LEARNED:
		var inner := side * MEDALLION_INNER
		var tint := color
		tint.a = 1.0
		draw_texture_rect(_learned_tint_texture(),
				Rect2(at - Vector2.ONE * inner * 0.5, Vector2.ONE * inner), false, tint)

	if state == SkillTree.State.LOCKED:
		var lock_side := side * LOCK_SHARE
		draw_texture_rect(SkillIcons.lock(),
				Rect2(at - Vector2.ONE * lock_side * 0.5, Vector2.ONE * lock_side), false)
	else:
		_draw_icon(node, at, side * ICON_SHARE,
				ICON_DIM if state == SkillTree.State.TOO_EXPENSIVE else Color.WHITE)

	# Der goldene Ring liegt ÜBER dem Zustand und ersetzt ihn nicht: wer zielt, soll weiter
	# sehen, ob der Knoten gesperrt oder gelernt ist. Heller für den gewählten Knoten und
	# den der Tastatur, schwächer fürs bloße Überfahren.
	var ring_alpha := 0.0
	if id == _hovered:
		ring_alpha = 0.7
	if id == _selected or (_keyboard and has_focus() and id == _focused):
		ring_alpha = 1.0
	if ring_alpha > 0.0:
		draw_texture_rect(SkillIcons.focus_ring(), rect, false, Color(1, 1, 1, ring_alpha))

	if state == SkillTree.State.LEARNED:
		var check_side := side * CHECK_SHARE
		var corner := at + Vector2.ONE * radius * 0.7
		draw_texture_rect(SkillIcons.check(),
				Rect2(corner - Vector2.ONE * check_side * 0.5, Vector2.ONE * check_side), false)

	_draw_name(node, at, radius, state)
	if state != SkillTree.State.LEARNED:
		_draw_cost(node, at, radius, color)


## Das Motiv im Medaillon — das Bild aus `SkillIcons`, sonst das Zeichen aus den Daten.
func _draw_icon(node: Dictionary, at: Vector2, side: float, tone: Color) -> void:
	var picture := SkillIcons.of(str(node.get("id", "")))
	if picture != null:
		draw_texture_rect(picture, Rect2(at - Vector2.ONE * side * 0.5, Vector2.ONE * side),
				false, tone)
		return
	var icon_size := int(get_theme_font_size("font_size", "SkillIcon") * _zoom)
	if icon_size <= 0:
		return
	# Grundlinie statt Mitte: draw_string setzt den Text auf die Grundlinie, ein
	# zentrierter Kreis braucht ihn rund ein Drittel der Größe tiefer.
	draw_string(get_theme_default_font(),
			at - Vector2(side * 0.5, 0.0) + Vector2(0.0, icon_size * 0.35),
			SkillTree.icon_of(node), HORIZONTAL_ALIGNMENT_CENTER, side, icon_size, tone)


func _draw_name(node: Dictionary, at: Vector2, radius: float, state: SkillTree.State) -> void:
	var font := get_theme_default_font()
	var font_size := int(get_theme_font_size("font_size", "Hint") * _label_scale())
	if font_size <= 0:
		return
	var text := str(node.get("name", ""))
	var color := get_theme_color("font_color", "Hint")
	if state == SkillTree.State.LOCKED:
		color = color.darkened(0.35)
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
	draw_string(font, at + Vector2(-width * 0.5, radius + font_size * 1.1), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


## Die Kosten sitzen als Plakette am Kreis — nur an noch nicht gelernten Knoten: was
## bezahlt ist, hat keinen Preis mehr.
func _draw_cost(node: Dictionary, at: Vector2, radius: float, color: Color) -> void:
	var font := get_theme_default_font()
	var font_size := int(get_theme_font_size("font_size", "Caption") * _zoom)
	if font_size <= 0:
		return
	var badge := at + Vector2(radius * 0.72, -radius * 0.72)
	var badge_radius := radius * 0.38
	draw_circle(badge, badge_radius, Color(0.05, 0.06, 0.09))
	draw_arc(badge, badge_radius, 0.0, TAU, 24, color, 1.5 * _zoom, true)
	var text := str(SkillTree.cost(node))
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
	draw_string(font, badge + Vector2(-width * 0.5, font_size * 0.35), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
