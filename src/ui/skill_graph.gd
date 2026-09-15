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

## Ein Knoten wurde angeklickt (leer: daneben geklickt). Was das bedeutet, entscheidet der
## Screen — dieses Control lernt nichts.
signal node_selected(id: String)

## Der Zeiger steht über `id` (leer: über nichts), und zwar an `at` in Bildschirm-
## Koordinaten. Die Auskunftskarte hängt NICHT hier, sondern beim Screen: dieses
## Control beschneidet seine Zeichnung (`clip_contents`), eine Karte am Rand wäre
## also halb weg.
signal hover_changed(id: String, at: Vector2)

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
const ROOT_HALO_FILL_ALPHA := 0.12
const ROOT_HALO_RING_ALPHA := 0.35

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


func _ready() -> void:
	resized.connect(func() -> void:
		if not _touched:
			fit())
	mouse_exited.connect(func() -> void: _set_hovered("", Vector2.ZERO))


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
		_origin = size * 0.5
		queue_redraw()
		return
	var room := size - Vector2.ONE * FIT_PAD * 2.0
	_zoom = clampf(minf(room.x / box.size.x, room.y / box.size.y), MIN_ZOOM, MAX_ZOOM)
	# Die Mitte des Netzes auf die Mitte der Fläche: `box` liegt nicht symmetrisch um den
	# Ursprung, sobald ein Baum mehr Stufen hat als der andere.
	_origin = size * 0.5 - box.get_center() * _zoom
	queue_redraw()


# --- Eingabe ------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
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
	if not _dragging:
		_set_hovered(id_at(motion.position), motion.global_position)
		return
	# Beim Ziehen wandert das ganze Netz unter dem Zeiger durch. Eine Karte, die dabei
	# mitliefe und bei jedem Pixel ihren Inhalt wechselte, wäre nur Flackern.
	_set_hovered("", Vector2.ZERO)
	_touched = true
	_origin += motion.relative
	queue_redraw()
	accept_event()


func _on_button(button: InputEventMouseButton) -> void:
	match button.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			if button.pressed:
				_zoom_at(button.position, ZOOM_STEP)
				_set_hovered(id_at(button.position), button.global_position)
				accept_event()
		MOUSE_BUTTON_WHEEL_DOWN:
			if button.pressed:
				_zoom_at(button.position, 1.0 / ZOOM_STEP)
				_set_hovered(id_at(button.position), button.global_position)
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


## Gezeichnet wird nur neu, wenn sich der Knoten ÄNDERT — gemeldet wird jede
## Bewegung: die Karte folgt dem Zeiger und braucht dafür jede neue Position.
func _set_hovered(id: String, at: Vector2) -> void:
	if _hovered != id:
		_hovered = id
		queue_redraw()
	hover_changed.emit(_hovered, at)


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
	var font_size := int(get_theme_font_size("font_size", "SectionTitle") * _zoom)
	if font_size <= 0:
		return Rect2()
	var text := str(tree.get("name", ""))
	var width := get_theme_default_font().get_string_size(
			text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	# `draw_string` setzt den Text auf die GRUNDLINIE — das Feld liegt also darüber.
	var at := _to_screen(_places.get(str(tree.get("id", "")), Vector2.ZERO))
	return Rect2(at - Vector2(width * 0.5, float(font_size)),
			Vector2(width, float(font_size) * 1.3))


## Wo ein Knoten gerade auf der Fläche liegt — die Umkehrung von `id_at`, gebraucht zum
## Zielen (und im Test zum Klicken).
func screen_position(id: String) -> Vector2:
	return _to_screen(_places.get(id, Vector2.ZERO))


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
	var radius := SkillTree.root_halo_radius() * _zoom
	var at := _to_screen(Vector2.ZERO)
	var tone := get_theme_color("font_color", "Hint")
	var fill := tone
	fill.a = ROOT_HALO_FILL_ALPHA
	var ring := tone
	ring.a = ROOT_HALO_RING_ALPHA
	draw_circle(at, radius, fill)
	draw_arc(at, radius, 0.0, TAU, 64, ring, 2.0 * _zoom, true)


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
	var font_size := int(get_theme_font_size("font_size", "SectionTitle") * _zoom)
	var at := _to_screen(_places.get(str(tree.get("id", "")), Vector2.ZERO))
	var tint := color
	if str(tree.get("id", "")) == _hovered:
		tint = color.lightened(0.35)
	draw_string(get_theme_default_font(), Vector2(rect.position.x, at.y),
			str(tree.get("name", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, tint)


func _draw_node(node: Dictionary, color: Color) -> void:
	var id := str(node.get("id", ""))
	var at := _to_screen(_places.get(id, Vector2.ZERO))
	var radius := SkillTree.NODE_RADIUS * _zoom
	var state := SkillTree.state_of(node, _unlocked, _points)

	var fill := Color(0.09, 0.11, 0.16)
	var ring := color.darkened(0.5)
	var ring_width := 2.0
	match state:
		SkillTree.State.LEARNED:
			fill = color.darkened(0.45)
			ring = color
			ring_width = 4.0
		SkillTree.State.AVAILABLE:
			ring = color
			ring_width = 3.0
		SkillTree.State.TOO_EXPENSIVE:
			ring = color.darkened(0.3)
		SkillTree.State.LOCKED:
			fill = Color(0.07, 0.08, 0.11)
			ring = Color(0.32, 0.34, 0.4)

	draw_circle(at, radius, fill)
	draw_arc(at, radius, 0.0, TAU, 40, ring, ring_width * _zoom, true)
	if id == _selected or id == _hovered:
		# Die Auswahl ist heller als das bloße Überfahren: beides ist ein Ring, damit der
		# Knoten selbst nicht seine Farbe wechselt und dabei seinen Zustand verschweigt.
		var alpha := 0.85 if id == _selected else 0.45
		draw_arc(at, radius + 6.0 * _zoom, 0.0, TAU, 40, Color(1, 1, 1, alpha),
				2.0 * _zoom, true)

	var font := get_theme_default_font()
	var icon_size := int(get_theme_font_size("font_size", "SkillIcon") * _zoom)
	var icon := SkillTree.icon_of(node) if state != SkillTree.State.LOCKED else "🔒"
	if icon_size > 0:
		# Grundlinie statt Mitte: draw_string setzt den Text auf die Grundlinie, ein
		# zentrierter Kreis braucht ihn rund ein Drittel der Größe tiefer.
		draw_string(font, at - Vector2(radius, 0.0) + Vector2(0.0, icon_size * 0.35),
				icon, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, icon_size,
				Color(0.95, 0.96, 1.0) if state != SkillTree.State.LOCKED
				else Color(0.55, 0.58, 0.64))

	_draw_name(node, at, radius, state)
	if state != SkillTree.State.LEARNED:
		_draw_cost(node, at, radius, color)


func _draw_name(node: Dictionary, at: Vector2, radius: float, state: SkillTree.State) -> void:
	var font := get_theme_default_font()
	var font_size := int(get_theme_font_size("font_size", "Hint") * _zoom)
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
