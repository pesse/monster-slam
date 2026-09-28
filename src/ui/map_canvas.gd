class_name MapCanvas
extends Control
## Eine Landkarte: ein Bild in seinem Seitenverhältnis, darauf ein Weg und Orte (ADR 0006).
##
## Buchkarte und Gebietskarte sind dasselbe Control mit anderen Orten. Gezeichnet statt
## gebaut, wie SkillGraph: ein Ort hat Stufe, Fortschritt, Medaille und
## Sperre — als Controls wären das Theme-Variationen für Zustände einer Zeichnung.
##
## Das Bild steht im Seitenverhältnis des Bildes da (ohne Bild 16:9): ganz, mit Rand
## (die Werkbank), oder mit `cover` randlos über die ganze Fläche, dann an den Seiten
## beschnitten (die Screens). Die Orte liegen in Anteilen des Bildes (0..1) und wandern
## mit, wenn sich die Größe ändert. Fehlt das Bild, steht eine
## schlichte Fläche da; fehlt einem Ort sein Punkt, legt `default_positions` ALLE Orte aus
## — halb von Hand, halb automatisch gäbe einen Weg, der kreuz und quer läuft.
##
## Dieses Control entscheidet nichts: was ein Klick bedeutet, sagt der Screen.

## Ein Ort wurde angeklickt — `key` wie in `setup` übergeben.
signal node_selected(key: String)
## Ein Zoom (`zoom_into`, `zoom_from`, `zoom_out`, `zoom_back_to`) ist fertig.
signal zoom_finished

const ASPECT := 16.0 / 9.0
const NODE_RADIUS := 30.0
## Kleinere Orte für die Gebietskarte: dort sitzen sie auf den Plätzen des Bildes.
const AREA_NODE_RADIUS := 11.0
## So lange wächst ein Ort unter dem Zeiger auf `hover_radius` und schrumpft wieder.
const HOVER_TIME := 0.12
## Kleinster Trefferradius — ein kleiner Ort soll trotzdem gut zu treffen sein.
const MIN_HIT_RADIUS := 16.0
## Zoom beim Wechsel von der Buch- in die Gebietskarte: so weit hinein, so lange.
const ZOOM_IN := 4.0
const ZOOM_IN_TIME := 0.35
## Die Gebietskarte kommt aus dieser Größe auf volle Größe.
const ZOOM_FROM := 0.6
const ZOOM_FROM_TIME := 0.3
## Längster Schritt, den ein Zoom in einem Frame macht. Der Frame, in dem die nächste
## Karte aufgebaut wird, dauert länger als die anderen; ohne Deckel spränge der Zoom um
## genau diese Zeit weiter — das war der Ruckler beim Hineinzoomen.
const MAX_ZOOM_STEP := 1.0 / 30.0
## Die Orte springen nach dem Zoom einer nach dem anderen auf (`appear`): so lange je Ort,
## und so viel später als sein Vorgänger.
const APPEAR_TIME := 0.25
const APPEAR_STAGGER := 0.06
const RING_WIDTH := 5.0
const PATH_WIDTH := 6.0
const DASH := 14.0
## Zwischenpunkte je Wegabschnitt, wenn der Weg zur Kurve geglättet wird.
const SMOOTH_STEPS := 12
## Orte je Reihe, wenn die Karte sie selbst auslegt.
const PER_ROW := 6

## Füllung je Stufe 0..4: Baustelle, Holz, Stein, Burg, Vollausbau. Farben aus dem Code
## und nicht aus dem Theme, aus demselben Grund wie in SkillGraph: es sind Zustände einer
## Zeichnung, keine Typografie.
const TIER_COLORS := [
	Color(0.18, 0.2, 0.26),
	Color(0.45, 0.32, 0.2),
	Color(0.42, 0.46, 0.52),
	Color(0.28, 0.42, 0.7),
	Color(0.75, 0.58, 0.18),
]
const BOSS_COLOR := Color(0.45, 0.12, 0.14)
## Ringfarbe je Medaille 1..3: Bronze, Silber, Gold.
const MEDAL_COLORS := [Color(0.72, 0.45, 0.2), Color(0.8, 0.83, 0.88), Color(1.0, 0.8, 0.2)]
## Füllung eines gesperrten Ortes — grau statt in der Farbe seiner Stufe.
const DISABLED_COLOR := Color(0.34, 0.35, 0.38)
const BLANK_COLOR := Color(0.16, 0.21, 0.18)
const BLANK_EDGE := Color(0.55, 0.62, 0.5, 0.35)
const PATH_COLOR := Color(0.98, 0.92, 0.75, 0.85)
const SHADOW := Color(0, 0, 0, 0.45)
const PLATE := Color(0.05, 0.06, 0.08, 0.72)

## Größe der Orte; alles am Ort (Ring, Punkte, Schrift) wächst und schrumpft mit.
var node_radius := NODE_RADIUS
## Den gestrichelten Weg auch über ein Bild zeichnen? Die Gebietskarten zeigen ihren Weg
## selbst, dort stünde er doppelt.
var path_over_image := true
## Beschriftung unter den Orten.
var show_captions := true
## Auf diese Größe wächst ein Ort unter dem Zeiger; 0 = er bleibt, wie er ist.
var hover_radius := 0.0
## Das Bild randlos über die ganze Fläche (beschnitten) statt ganz mit Rand.
var cover := false

var _texture: Texture2D
## Die Orte: { key, pos (Vector2 in 0..1 oder INF), glyph, caption, tier, done, total,
## medal, boss, disabled }.
var _nodes: Array = []
## Wegpunkte in 0..1; leer = die Orte der Reihe nach verbinden.
var _path: Array = []
var _centers: Array = []
var _hovered := -1
## Je Ort, wie weit er zur Hover-Größe gewachsen ist (0..1).
var _grow: Array = []
## Zoom der ganzen Karte um `_focus` (Anteil des Bildes); während des Zooms ruht die Maus.
var _zoom := 1.0
var _focus := Vector2(0.5, 0.5)
var _zooming := false
## Der laufende Zoom: von/nach (Zoom und Deckkraft), Dauer, Anteil 0..1, Kurve.
var _zoom_run := {}
## Zeit seit `appear`, oder < 0: alle Orte stehen da.
var _appear_t := -1.0


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	resized.connect(_relayout)
	mouse_exited.connect(func() -> void: _set_hovered(-1))
	set_process(false)


## Fährt in den Ort `key` hinein und blendet aus; danach kommt `zoom_finished`. Für den
## Wechsel in die nächste Karte — die Karte selbst bleibt dabei stehen, wie sie ist.
func zoom_into(key: String) -> void:
	_focus = _pos_of(key, _focus)
	_start_zoom(1.0, ZOOM_IN, 1.0, 0.0, ZOOM_IN_TIME, Tween.EASE_IN)


## Kommt aus der Mitte auf volle Größe und blendet ein — die Fortsetzung von `zoom_into`.
func zoom_from() -> void:
	_focus = Vector2(0.5, 0.5)
	_start_zoom(ZOOM_FROM, 1.0, 0.0, 1.0, ZOOM_FROM_TIME, Tween.EASE_OUT)


## Zieht sich zur Mitte zusammen und blendet aus — zurück zur Karte darüber.
func zoom_out() -> void:
	_focus = Vector2(0.5, 0.5)
	_start_zoom(1.0, ZOOM_FROM, 1.0, 0.0, ZOOM_FROM_TIME, Tween.EASE_IN)


## Kommt aus dem Punkt `at` (Anteil des Bildes) heraus auf volle Größe und blendet ein —
## die Fortsetzung von `zoom_out`, die Umkehrung von `zoom_into`. Ein Punkt und kein Ort:
## die Orte kommen erst nach dem Zoom (`appear`).
func zoom_back_to(at: Vector2) -> void:
	_focus = at if at.is_finite() else Vector2(0.5, 0.5)
	_start_zoom(ZOOM_IN, 1.0, 0.0, 1.0, ZOOM_IN_TIME, Tween.EASE_OUT)


## Lässt die Orte aus `setup` aufspringen, der Reihe nach. Die Screens rufen es nach dem
## Zoom: erst steht das Bild, dann wird gerechnet, dann kommen die Orte.
func appear() -> void:
	_appear_t = 0.0
	set_process(true)
	queue_redraw()


## Wie groß der Ort `i` beim Aufspringen gerade ist, 0..1 mit etwas Überschwingen.
func appear_scale(i: int) -> float:
	if _appear_t < 0.0:
		return 1.0
	var x := clampf((_appear_t - float(i) * APPEAR_STAGGER) / APPEAR_TIME, 0.0, 1.0)
	if x <= 0.0 or x >= 1.0:
		return x
	# Ease-out-back: kurz über das Ziel hinaus und zurück — ein Aufspringen, kein Einblenden.
	var c := 1.70158
	return 1.0 + (c + 1.0) * pow(x - 1.0, 3.0) + c * pow(x - 1.0, 2.0)


func is_zooming() -> bool:
	return _zooming


func _pos_of(key: String, fallback: Vector2) -> Vector2:
	for node in _nodes:
		if str(node["key"]) == key:
			return node["pos"]
	return fallback


## Gerechnet in `_process` statt als Tween, damit ein langer Frame den Zoom nicht
## überspringt (MAX_ZOOM_STEP).
func _start_zoom(from: float, to: float, alpha_from: float, alpha_to: float, time: float,
		easing: Tween.EaseType) -> void:
	_zooming = true
	_set_hovered(-1)
	_zoom_run = {"from": from, "to": to, "alpha_from": alpha_from, "alpha_to": alpha_to,
			"time": time, "t": 0.0, "ease_in": easing == Tween.EASE_IN}
	_zoom = from
	modulate.a = alpha_from
	set_process(true)
	queue_redraw()


func _step_zoom(delta: float) -> void:
	var run := _zoom_run
	run["t"] = minf(1.0, float(run["t"]) + minf(delta, MAX_ZOOM_STEP) / float(run["time"]))
	var t := float(run["t"])
	var k := t * t * t if bool(run["ease_in"]) else 1.0 - pow(1.0 - t, 3.0)
	_zoom = lerpf(float(run["from"]), float(run["to"]), k)
	modulate.a = lerpf(float(run["alpha_from"]), float(run["alpha_to"]), k)
	if t >= 1.0:
		_zoom_run = {}
		_zooming = false
		zoom_finished.emit()


## Setzt Bild, Orte und Weg und meldet die Auskunft am Zeiger an. `hint` liefert für einen
## Ort die Karte (Title/Body/Note, siehe Hints.attach).
func setup(texture: Texture2D, nodes: Array, path: Array, hint: Callable) -> void:
	_texture = texture
	_nodes = nodes
	_path = path
	var missing := nodes.any(func(n): return (n.get("pos", Vector2.INF) as Vector2) == Vector2.INF)
	if missing:
		var auto := default_positions(nodes.size())
		for i in nodes.size():
			nodes[i]["pos"] = auto[i]
		_path = []
	Hints.attach_live(self, func(local: Vector2) -> Dictionary:
		if _zooming:
			return {}
		var i := index_at(local)
		return hint.call(_nodes[i]) if i >= 0 else {})
	_relayout()


## Das Rechteck, in dem das Bild steht, mittig in `area` im Seitenverhältnis `ratio`: so
## groß wie möglich darin, oder mit `fill` so klein wie möglich darüber.
static func map_rect(area: Vector2, ratio := ASPECT, fill := false) -> Rect2:
	if area.x <= 0.0 or area.y <= 0.0:
		return Rect2()
	var width := maxf(area.x, area.y * ratio) if fill else minf(area.x, area.y * ratio)
	var height := width / ratio
	return Rect2((area - Vector2(width, height)) * 0.5, Vector2(width, height))


## Punkte in 0..1 für `count` Orte ohne eigene Position: Reihen zu höchstens PER_ROW, jede
## zweite zurück (Serpentine), in einer Reihe leicht auf und ab, damit es nach Weg aussieht
## und nicht nach Tabelle.
static func default_positions(count: int) -> Array:
	var out: Array = []
	if count <= 0:
		return out
	var rows := ceili(float(count) / float(PER_ROW))
	var per_row := ceili(float(count) / float(rows))
	for i in count:
		@warning_ignore("integer_division")
		var row := i / per_row
		var col := i % per_row
		if row % 2 == 1:
			col = per_row - 1 - col
		var x := 0.5 if per_row == 1 else 0.12 + 0.76 * float(col) / float(per_row - 1)
		var y := 0.5 if rows == 1 else 0.22 + 0.56 * float(row) / float(rows - 1)
		y += (0.07 if col % 2 == 0 else -0.07) / float(rows)
		out.append(Vector2(x, y))
	return out


## Das Seitenverhältnis der Karte: das des Bildes, ohne Bild ASPECT.
func aspect() -> float:
	if _texture == null or _texture.get_height() <= 0:
		return ASPECT
	return float(_texture.get_width()) / float(_texture.get_height())


## Wo ein Ort auf dem Control liegt, für einen Anteil `at` des Bildes.
func to_local_point(at: Vector2) -> Vector2:
	var rect := map_rect(size, aspect(), cover)
	return rect.position + at * rect.size


## Liegt einer der Punkte `points` (Anteile des Bildes) unter `rect` (global)? Mit dem
## Rand eines gewachsenen Ortes: auch unter dem Zeiger soll kein Ort darunter verschwinden.
func covers(rect: Rect2, points: Array) -> bool:
	var local := Rect2(rect.position - global_position, rect.size).grow(maxf(hover_radius, node_radius))
	for at in points:
		if at is Vector2 and (at as Vector2).is_finite() and local.has_point(to_local_point(at)):
			return true
	return false


## Stellt den Kopf eines Screens (`header`, oben links in seinem Eltern-Control) nach unten
## links, wenn oben ein Ort darunter läge und unten keiner. Vor dem Einblenden aufrufen,
## nach einem Frame Layout: danach bleibt der Kopf, wo er ist.
func place_header(header: Control, points: Array) -> void:
	var top := header.get_global_rect()
	var parent := header.get_parent() as Control
	var bottom := Rect2(Vector2(top.position.x, parent.get_global_rect().end.y - top.size.y), top.size)
	if covers(top, points) and not covers(bottom, points):
		header.grow_vertical = Control.GROW_DIRECTION_BEGIN
		header.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE)


## Der Anteil des Bildes unter `local` — die Umkehrung, für die Werkbank.
func to_map_point(local: Vector2) -> Vector2:
	var rect := map_rect(size, aspect(), cover)
	if rect.size.x <= 0.0:
		return Vector2.ZERO
	return ((local - rect.position) / rect.size).clamp(Vector2.ZERO, Vector2.ONE)


func _relayout() -> void:
	_centers.clear()
	for node in _nodes:
		_centers.append(to_local_point(node["pos"]))
	_grow.resize(_centers.size())
	for i in _grow.size():
		if _grow[i] == null:
			_grow[i] = 0.0
	queue_redraw()


## Wie groß der Ort `i` gerade ist — zwischen node_radius und hover_radius.
func radius_of(i: int) -> float:
	if hover_radius <= node_radius or i < 0 or i >= _grow.size():
		return node_radius
	var t := float(_grow[i])
	return lerpf(node_radius, hover_radius, t * t * (3.0 - 2.0 * t))


## Der Index des Ortes unter `point`, sonst -1.
func index_at(point: Vector2) -> int:
	for i in _centers.size():
		if (_centers[i] as Vector2).distance_to(point) <= maxf(radius_of(i), MIN_HIT_RADIUS):
			return i
	return -1


## Wo ein Ort liegt, für Tests.
func node_position(index: int) -> Vector2:
	return _centers[index] if index >= 0 and index < _centers.size() else Vector2.INF


func _gui_input(event: InputEvent) -> void:
	if _zooming:
		return
	var motion := event as InputEventMouseMotion
	if motion != null:
		_set_hovered(index_at(motion.position))
		return
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT and not button.pressed:
		var i := index_at(button.position)
		if i >= 0 and not bool(_nodes[i].get("disabled", false)):
			node_selected.emit(str(_nodes[i]["key"]))
			accept_event()


func _set_hovered(index: int) -> void:
	if _hovered == index:
		return
	_hovered = index
	if hover_radius > node_radius:
		set_process(true)
	queue_redraw()


## Lässt die Orte zu ihrer Größe wachsen oder schrumpfen; ruht, sobald alle angekommen sind.
func _process(delta: float) -> void:
	if not _zoom_run.is_empty():
		_step_zoom(delta)
	var moving := _zooming
	if _appear_t >= 0.0:
		_appear_t += minf(delta, MAX_ZOOM_STEP)
		if _appear_t >= APPEAR_TIME + APPEAR_STAGGER * float(maxi(_centers.size() - 1, 0)):
			_appear_t = -1.0
		moving = true
	for i in _grow.size():
		var target := 1.0 if i == _hovered else 0.0
		var now := move_toward(float(_grow[i]), target, delta / HOVER_TIME)
		_grow[i] = now
		moving = moving or now != target
	queue_redraw()
	if not moving:
		set_process(false)


func _draw() -> void:
	var rect := map_rect(size, aspect(), cover)
	if rect.size.x <= 0.0:
		return
	var base := Transform2D()
	if _zoom != 1.0:
		var focus := to_local_point(_focus)
		base = Transform2D(0.0, Vector2(_zoom, _zoom), 0.0, focus * (1.0 - _zoom))
		draw_set_transform_matrix(base)
	if _texture != null:
		draw_texture_rect(_texture, rect, false)
	else:
		# Ohne Bild eine schlichte Fläche mit Rand — die Karte soll als Karte lesbar bleiben,
		# bis ihr Bild da ist.
		draw_rect(rect, BLANK_COLOR)
		draw_rect(rect.grow(-8.0), BLANK_EDGE, false, 2.0)
	if _texture == null or path_over_image:
		_draw_path()
	for i in _centers.size():
		if i != _hovered:
			_draw_appearing(i, base)
	# Der Ort unter dem Zeiger zuletzt: groß geworden, liegt er über seinen Nachbarn.
	if _hovered >= 0 and _hovered < _centers.size():
		_draw_appearing(_hovered, base)


## Ein Ort, beim Aufspringen um seine Mitte skaliert — alles an ihm wächst mit.
func _draw_appearing(i: int, base: Transform2D) -> void:
	var grow := appear_scale(i)
	if grow <= 0.01:
		return
	if grow == 1.0:
		_draw_node(i)
		return
	var at: Vector2 = _centers[i]
	draw_set_transform_matrix(base * Transform2D(0.0, Vector2(grow, grow), 0.0, at * (1.0 - grow)))
	_draw_node(i)
	draw_set_transform_matrix(base)


func _draw_path() -> void:
	var points: Array = []
	if _path.is_empty():
		points = _centers
	else:
		for at in _path:
			points.append(to_local_point(at))
	var line := smooth_path(points)
	if line.size() < 2:
		return
	draw_polyline(line, SHADOW, PATH_WIDTH + 4.0, true)
	for dash in dashes(line, DASH):
		draw_line(dash[0], dash[1], PATH_COLOR, PATH_WIDTH, true)


## Der Weg als weiche Kurve durch alle Punkte (Catmull-Rom): aus wenigen Wegpunkten wird
## ein gewundener Pfad statt eines Zickzacks.
static func smooth_path(points: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	if points.size() < 3:
		for at in points:
			out.append(at)
		return out
	for i in points.size() - 1:
		var p0: Vector2 = points[maxi(i - 1, 0)]
		var p1: Vector2 = points[i]
		var p2: Vector2 = points[i + 1]
		var p3: Vector2 = points[mini(i + 2, points.size() - 1)]
		for step in SMOOTH_STEPS:
			var t := float(step) / float(SMOOTH_STEPS)
			out.append(0.5 * (2.0 * p1 + (p2 - p0) * t
					+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t
					+ (3.0 * p1 - p0 - 3.0 * p2 + p3) * t * t * t))
	out.append(points[-1])
	return out


## Striche der Länge `dash` mit gleich großen Lücken, über die ganze Linie durchgezählt —
## je Abschnitt neu angefangen, zerfiele das Muster einer Kurve in Krümel.
static func dashes(line: PackedVector2Array, dash: float) -> Array:
	var out: Array = []
	var walked := 0.0
	for i in range(1, line.size()):
		var from := line[i - 1]
		var to := line[i]
		var length := from.distance_to(to)
		var at := 0.0
		while at < length:
			var phase := fmod(walked + at, dash * 2.0)
			var step := minf(length - at, (dash if phase < dash else dash * 2.0) - phase)
			if phase < dash:
				out.append([from.lerp(to, at / length), from.lerp(to, (at + step) / length)])
			at += step
		walked += length
	return out


func _draw_node(i: int) -> void:
	var node: Dictionary = _nodes[i]
	var at: Vector2 = _centers[i]
	var disabled := bool(node.get("disabled", false))
	var boss := bool(node.get("boss", false))
	var tier := clampi(int(node.get("tier", 0)), 0, TIER_COLORS.size() - 1)
	var medal := clampi(int(node.get("medal", 0)), 0, MEDAL_COLORS.size())
	var total := int(node.get("total", 0))
	var done := int(node.get("done", 0))
	var dim := 0.45 if disabled else 1.0
	var r := radius_of(i)
	var k := r / NODE_RADIUS
	var ring := maxf(RING_WIDTH * k, 2.5)

	draw_circle(at + Vector2(0, 4.0 * k), r + 2.0 * k, SHADOW)
	var fill: Color = BOSS_COLOR if boss else TIER_COLORS[tier]
	if boss and medal > 0:
		fill = (MEDAL_COLORS[medal - 1] as Color).darkened(0.35)
	if disabled:
		fill = DISABLED_COLOR
	# Gesperrt heißt grau, nicht durchsichtig: der Weg läuft sonst sichtbar durch den Ort.
	draw_circle(at, r, fill)
	var track := Color(0.07, 0.08, 0.11)
	draw_arc(at, r, 0.0, TAU, 48, track, ring, true)
	if boss:
		if medal > 0:
			draw_arc(at, r, 0.0, TAU, 48, MEDAL_COLORS[medal - 1], ring + 1.0, true)
	elif total > 0 and done > 0:
		# Der Ring zeigt den Weg durchs Level, die Füllung die erreichte Stufe: zwischen zwei
		# Stufen soll man sehen, dass sich etwas tut.
		var share := float(done) / float(total)
		draw_arc(at, r, -PI * 0.5, -PI * 0.5 + TAU * share, 48,
				get_theme_color("font_color", "Accent"), ring, true)
	if i == _hovered and not disabled:
		draw_arc(at, r + 6.0 * k, 0.0, TAU, 48, Color(1, 1, 1, 0.8), 2.0, true)

	var font := get_theme_default_font()
	var glyph_size := maxi(roundi(get_theme_font_size("font_size", "SectionTitle") * k), 11)
	draw_string(font, at + Vector2(-r, glyph_size * 0.35), str(node.get("glyph", "")),
			HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, glyph_size, Color(0.97, 0.97, 1.0, dim))
	if boss and medal > 0:
		draw_string(font, at + Vector2(-r, -r - 4.0 * k), "👑",
				HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, glyph_size)
	if show_captions:
		_draw_caption(at, r, str(node.get("caption", "")), dim)
	# Gesamt ist die ganze Unit und hat keine Sterne ("stars": false).
	if not boss and bool(node.get("stars", true)):
		_draw_stars(at, r, tier, dim)


## Die Beschriftung unter dem Ort, auf einer dunklen Platte — das Bild darunter ist bunt.
func _draw_caption(at: Vector2, r: float, text: String, dim: float) -> void:
	if text.is_empty():
		return
	var font := get_theme_default_font()
	var font_size := get_theme_font_size("font_size", "Caption")
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 16.0
	var top := at.y + r + 20.0 * r / NODE_RADIUS
	var plate := Rect2(at.x - width * 0.5, top, width, font_size + 8.0)
	draw_rect(plate, Color(PLATE, PLATE.a * dim))
	draw_string(font, Vector2(plate.position.x, top + font_size + 2.0), text,
			HORIZONTAL_ALIGNMENT_CENTER, width, font_size, Color(0.95, 0.96, 1.0, dim))


## Die Stufe als vier kleine Punkte zwischen Ort und Beschriftung: gefüllt bis zur Stufe.
func _draw_stars(at: Vector2, r: float, tier: int, dim: float) -> void:
	var gold: Color = MEDAL_COLORS[2]
	var k := r / NODE_RADIUS
	var y := at.y + r + 11.0 * k
	for s in FortressTier.MAX_TIER:
		var x := at.x + (float(s) - 1.5) * maxf(11.0 * k, 7.0)
		var lit := s < tier
		draw_circle(Vector2(x, y), maxf(4.0 * k, 2.5), Color(gold, dim) if lit else Color(0.1, 0.1, 0.12, 0.8 * dim))
