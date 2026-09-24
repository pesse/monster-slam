class_name UnitPath
extends Control
## Der Pfad EINES Buchs auf der Landkarte: ein Knoten je Unit, in Schlangenlinie über die
## Breite verlegt, mit Festungsstufe und Fortschrittsring (Issue #21).
##
## Gezeichnet statt gebaut, wie SkillGraph: ein Buch hat zwanzig Units, und zwanzig Karten
## mit je fünf Zuständen wären zwanzig Controls mit fünf Theme-Variationen. WO ein Knoten
## liegt, rechnet `layout()` — reine Zahlen, für sich prüfbar
## (tests/unit_path_layout_test.gd); in der Szene stehen keine Positionen.
##
## Dieses Control entscheidet nichts: was ein Klick bedeutet, sagt der Screen (UnitMap).

## Ein Knoten wurde angeklickt — `key` ist der Unit-Schlüssel „<book>/<unit>".
signal unit_selected(key: String)

const NODE_RADIUS := 28.0
## Abstand zweier Knotenmitten in einer Reihe und zwischen zwei Reihen. Unter jedem Knoten
## steht seine Stufe; die Reihe darunter muss daran vorbeikommen.
const STEP_X := 96.0
const STEP_Y := 104.0
## Rand zwischen Knoten und Kante — Radius, Auswahlring und die Beschriftung darunter.
const PAD := 48.0
## Platz unter der letzten Reihe für die Beschriftung „Stufe N".
const LABEL_ROOM := 24.0

const PATH_WIDTH := 6.0
const RING_WIDTH := 5.0

## Füllung je Festungsstufe 0..4: Baustelle, Holz, Stein, Burg, Vollausbau. Farben aus dem
## Code und nicht aus dem Theme, aus demselben Grund wie in SkillGraph: es sind Zustände
## einer Zeichnung, keine Typografie.
const TIER_COLORS := [
	Color(0.18, 0.2, 0.26),
	Color(0.45, 0.32, 0.2),
	Color(0.42, 0.46, 0.52),
	Color(0.28, 0.42, 0.7),
	Color(0.75, 0.58, 0.18),
]

## Die Units dieses Buchs in Reihenfolge: { key, unit, done, total, tier }.
var _units: Array = []
var _places: Array = []
var _hovered: int = -1


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	resized.connect(_relayout)
	mouse_exited.connect(func() -> void: _set_hovered(-1))


## Setzt die Units und meldet die Auskunft am Zeiger an. `hint` liefert für einen Eintrag
## aus `units` die Karte (Title/Body/Note, siehe Hints.attach) — die Worte gehören dem
## Screen, dieses Control kennt nur Knoten.
func setup(units: Array, hint: Callable) -> void:
	_units = units
	Hints.attach_live(self, func(local: Vector2) -> Dictionary:
		var i := index_at(local)
		return hint.call(_units[i]) if i >= 0 else {})
	_relayout()


## Die Knotenmitten für `count` Knoten in einer Fläche der Breite `width`: Reihen von
## links nach rechts, jede zweite zurück (Serpentine), damit der Pfad ohne Sprung weiter-
## läuft. So viele Knoten je Reihe, wie mit STEP_X zwischen die Ränder passen; die Reihen
## stehen mittig, der Pfad biegt also nicht an der Kante um.
static func layout(count: int, width: float) -> Array:
	var per_row := per_row_for(width)
	var span := float(per_row - 1) * STEP_X
	var left := (width - span) * 0.5
	var out: Array = []
	for i in count:
		@warning_ignore("integer_division")
		var row := i / per_row
		var col := i % per_row
		if row % 2 == 1:
			col = per_row - 1 - col
		out.append(Vector2(left + float(col) * STEP_X, PAD + float(row) * STEP_Y))
	return out


## Wie viele Knoten in eine Reihe der Breite `width` passen — mindestens einer.
static func per_row_for(width: float) -> int:
	return maxi(1, int(floor((width - 2.0 * PAD) / STEP_X)) + 1)


## Die Höhe, die `count` Knoten bei `width` brauchen.
static func height_for(count: int, width: float) -> float:
	if count <= 0:
		return 0.0
	var rows := ceili(float(count) / float(per_row_for(width)))
	return PAD * 2.0 + float(rows - 1) * STEP_Y + LABEL_ROOM


func _relayout() -> void:
	_places = layout(_units.size(), size.x)
	# Die Breite gibt der Container vor, die Höhe folgt aus ihr. Solange noch keine Breite
	# angekommen ist, rechnet die Mindesthöhe mit einer Reihe je Knoten — lieber zu hoch
	# als ein Pfad, der über den nächsten Abschnitt ragt (siehe CLAUDE.md, „Fallen").
	custom_minimum_size.y = height_for(_units.size(), size.x)
	queue_redraw()


## Der Index des Knotens unter `point`, sonst -1. Geprüft wird gegen den Radius: die Knoten
## sind rund.
func index_at(point: Vector2) -> int:
	for i in _places.size():
		if (_places[i] as Vector2).distance_to(point) <= NODE_RADIUS:
			return i
	return -1


## Wo ein Knoten liegt — die Umkehrung von `index_at`, für den Test.
func node_position(index: int) -> Vector2:
	return _places[index] if index >= 0 and index < _places.size() else Vector2.INF


func _gui_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		_set_hovered(index_at(motion.position))
		return
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT and not button.pressed:
		var i := index_at(button.position)
		if i >= 0:
			unit_selected.emit(str(_units[i]["key"]))
			accept_event()


func _set_hovered(index: int) -> void:
	if _hovered == index:
		return
	_hovered = index
	queue_redraw()


func _draw() -> void:
	if _places.size() != _units.size() or _places.is_empty():
		return
	var line := get_theme_color("font_color", "Hint")
	line.a = 0.35
	for i in range(1, _places.size()):
		draw_line(_places[i - 1], _places[i], line, PATH_WIDTH, true)
	for i in _places.size():
		_draw_node(i)


func _draw_node(i: int) -> void:
	var unit: Dictionary = _units[i]
	var at: Vector2 = _places[i]
	var tier := clampi(int(unit.get("tier", 0)), 0, TIER_COLORS.size() - 1)
	var total := int(unit.get("total", 0))
	var done := int(unit.get("done", 0))
	var accent := get_theme_color("font_color", "Accent")

	draw_circle(at, NODE_RADIUS, TIER_COLORS[tier])
	# Der Fortschrittsring zeigt den Weg durch die Unit, die Füllung die erreichte Stufe:
	# zwischen zwei Stufen soll man sehen, dass sich etwas tut.
	var track := Color(0.07, 0.08, 0.11)
	draw_arc(at, NODE_RADIUS, 0.0, TAU, 48, track, RING_WIDTH, true)
	if total > 0 and done > 0:
		var share := float(done) / float(total)
		draw_arc(at, NODE_RADIUS, -PI * 0.5, -PI * 0.5 + TAU * share, 48, accent,
				RING_WIDTH, true)
	if i == _hovered:
		draw_arc(at, NODE_RADIUS + 6.0, 0.0, TAU, 48, Color(1, 1, 1, 0.6), 2.0, true)

	var font := get_theme_default_font()
	var title_size := get_theme_font_size("font_size", "SectionTitle")
	# draw_string setzt auf die Grundlinie: rund ein Drittel der Größe tiefer ist Mitte.
	draw_string(font, at + Vector2(-NODE_RADIUS, title_size * 0.35), str(unit.get("unit", "")),
			HORIZONTAL_ALIGNMENT_CENTER, NODE_RADIUS * 2.0, title_size, Color(0.95, 0.96, 1.0))
	var caption_size := get_theme_font_size("font_size", "Caption")
	draw_string(font, at + Vector2(-STEP_X * 0.5, NODE_RADIUS + caption_size + 4.0),
			"Stufe %d" % tier, HORIZONTAL_ALIGNMENT_CENTER, STEP_X, caption_size,
			get_theme_color("font_color", "Hint"))
