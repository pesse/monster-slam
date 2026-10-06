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

## Füllung nach dem Anteil gemeisterter Wörter (bzw. Aufgaben eines Bonus): dunkel, ab
## FILL_PERCENT[n] Bronze, Silber, Gold. Bewusst NICHT die Festungsstufe — die gibt es für
## einen Teil oder einen Bonus gar nicht. Farben aus dem Code und nicht aus dem Theme, aus
## demselben Grund wie in SkillGraph: es sind Zustände einer Zeichnung, keine Typografie.
const FILL_PERCENT := [25, 60, 100]
const FILL_COLORS := [
	Color(0.18, 0.2, 0.26),
	Color(0.55, 0.34, 0.17),
	Color(0.52, 0.56, 0.62),
	Color(0.76, 0.58, 0.14),
]
const BOSS_COLOR := Color(0.45, 0.12, 0.14)
## Ringfarbe je Medaille 1..3: Bronze, Silber, Gold.
const MEDAL_COLORS := [Color(0.72, 0.45, 0.2), Color(0.8, 0.83, 0.88), Color(1.0, 0.8, 0.2)]
## Der Fortschrittsring füllt sich in Gold mit dem Anteil gemeisterter Wörter. Er ist der
## Meisterungsstand und NICHT die Festungsstufe (ADR 0009): die ist bei 75 % voll, der Ring
## erst bei 100 % — das letzte Viertel bleibt sichtbar etwas wert.
const RING_GOLD := Color(1.0, 0.8, 0.2)
## Heller Ton, zu dem ein gemeisterter Ring pulsiert.
const RING_SHINE := Color(1.0, 0.95, 0.68)
## Ein gemeisterter Ort pulsiert in diesem Takt (Hz) und sprüht Funken: so viele zugleich,
## jeder so lange (s) unterwegs.
const PULSE_HZ := 0.45
const SPARKLES := 10
const SPARKLE_LIFE := 1.6
## Dazu ziehen so viele Funken in den Ort hinein, jeder so lange (s).
const MOTES := 8
const MOTE_LIFE := 1.3
## Strahlen hinter einem gemeisterten Ort, und wie schnell sie kreisen (Umdrehungen/s).
const RAYS := 10
const RAY_SPEED := 0.05
## Ein Glanzlicht läuft so schnell um den vollen Ring (Umdrehungen/s).
const GLINT_SPEED := 0.55
## Ein gemeisterter Bonus-Stern hat dieselben Funken wie der Ring, nur weniger.
const STAR_SPARKLES := 4
const STAR_MOTES := 3
## Die Markierung (`set_selected`) wippt in diesem Takt (Hz) über dem Ort.
const BOB_HZ := 1.2
## Füllung eines gesperrten Ortes — grau statt in der Farbe seiner Stufe.
const DISABLED_COLOR := Color(0.34, 0.35, 0.38)
const BLANK_COLOR := Color(0.16, 0.21, 0.18)
const BLANK_EDGE := Color(0.55, 0.62, 0.5, 0.35)
const PATH_COLOR := Color(0.98, 0.92, 0.75, 0.85)
const SHADOW := Color(0, 0, 0, 0.45)
const PLATE := Color(0.05, 0.06, 0.08, 0.72)

## Pfeil über einem markierten Ort (`set_selected`). Weiß und nicht Gold: Gold ist der
## Fortschritt, die Markierung soll damit nicht verwechselt werden.
const SELECTED_COLOR := Color(1.0, 1.0, 1.0)
## So weit wächst ein markierter Ort zur Hover-Größe (0..1): sichtbar größer, ohne dass
## mehrere markierte Nachbarn ineinanderlaufen.
const SELECTED_GROW := 0.5

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
## Die Orte: { key, pos (Vector2 in 0..1 oder INF), glyph, caption, done, total, medal,
## boss, disabled, bonus }. `bonus` ist je Bonus der Unit sein Anteil 0..1 — ein Stern unter
## dem Ort, der erst bei 1 leuchtet.
var _nodes: Array = []
## Wegpunkte in 0..1; leer = die Orte der Reihe nach verbinden.
var _path: Array = []
var _centers: Array = []
var _hovered := -1
## Die markierten Orte (Schlüssel → true): sie bleiben groß, ein Pfeil wippt über ihnen.
var _selected := {}
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
## Uhr für Pulsieren, Funken und den wippenden Pfeil.
var _time := 0.0
## Bewegt sich etwas auch ohne Zeiger (gemeisterter Ort, leuchtender Stern, Markierung)?
## Dann läuft `_process` weiter; sonst ruht die Karte.
var _alive := false
## Weicher, runder Fleck für Schein und Funken — ein Verlauf statt harter Kreise.
var _glow: Texture2D
## Dunkle Leiste hinter den Bonus-Sternen — vor dem bunten Bild sähe man sie sonst nicht.
## Ebene über den Orten, additiv gemischt wie die Meisterungs-Feier: Funken, Glanzlicht und
## Schein des Rings addieren Licht, statt das Bild zu übermalen. Zeichnet `_draw_fx`.
var _fx: Control
## Die Zoom-Transformation des letzten `_draw` — die Effektebene zeichnet darin mit.
var _base := Transform2D()
## Das Bild liegt in einer eigenen Ebene hinter der Zeichnung der Karte, damit das, was sich
## darauf bewegt (`_ambience`), zwischen Bild und Orten liegen kann.
var _image: Control
var _ambience: MapAmbience


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	resized.connect(_relayout)
	mouse_exited.connect(func() -> void: _set_hovered(-1))
	_image = Control.new()
	_image.name = "Image"
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_image.show_behind_parent = true
	_image.set_anchors_preset(Control.PRESET_FULL_RECT)
	_image.draw.connect(_draw_image)
	add_child(_image)
	_ambience = MapAmbience.new(self)
	add_child(_ambience)
	_fx = Control.new()
	_fx.name = "Fx"
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_fx.material = additive
	_fx.draw.connect(_draw_fx)
	add_child(_fx)
	set_process(false)


## Fährt in den Ort `key` hinein und blendet aus; danach kommt `zoom_finished`. Für den
## Wechsel in die nächste Karte — die Karte selbst bleibt dabei stehen, wie sie ist.
func zoom_into(key: String) -> void:
	zoom_into_all([key])


## Wie `zoom_into`, in die Mitte mehrerer Orte — für eine Auswahl aus mehreren Teilen.
func zoom_into_all(keys: Array) -> void:
	var at := centroid(keys.map(func(k): return _pos_of(str(k), Vector2.INF)))
	if at.is_finite():
		_focus = at
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


## Die Mitte der endlichen Punkte in `points`, ohne einen davon Vector2.INF.
static func centroid(points: Array) -> Vector2:
	var sum := Vector2.ZERO
	var count := 0
	for at in points:
		if at is Vector2 and (at as Vector2).is_finite():
			sum += at
			count += 1
	return sum / float(count) if count > 0 else Vector2.INF


## Markiert die Orte `keys` (die übrigen nicht mehr); die Markierung überdauert ein neues
## `setup`.
func set_selected(keys: Array) -> void:
	_selected.clear()
	for key in keys:
		_selected[str(key)] = true
	_update_alive()
	if hover_radius > node_radius or _alive:
		set_process(true)
	queue_redraw()


func _update_alive() -> void:
	_alive = not _selected.is_empty() or _nodes.any(shines)


## Leuchtet etwas an diesem Ort: der Ring voll, oder ein Bonus-Stern gemeistert?
static func shines(node: Dictionary) -> bool:
	if bool(node.get("disabled", false)) or bool(node.get("boss", false)):
		return false
	if is_mastered(node):
		return true
	return (node.get("bonus", []) as Array).any(func(share): return float(share) >= 1.0)


## Ist der Ring voll — alles gemeistert?
static func is_mastered(node: Dictionary) -> bool:
	var total := int(node.get("total", 0))
	return total > 0 and int(node.get("done", 0)) >= total


func is_selected(key: String) -> bool:
	return _selected.has(key)


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
	# Was sich bewegt, gehört zum alten Bild; wer es will, setzt es danach (`set_ambience`).
	if _ambience != null:
		_ambience.setup([], texture)
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
	_update_alive()
	if _alive:
		set_process(true)
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


## Stellt den Kopf eines Screens (`header`, oben links in seinem Eltern-Control) in die
## Ecke, in der kein Ort darunter liegt. `prefer_bottom` sagt, welche Ecke er nimmt, wenn
## beide frei oder beide belegt sind: sonst oben links, mit `prefer_bottom` unten links —
## die andere Ecke nur, wenn die bevorzugte belegt ist und sie nicht. Vor dem Einblenden
## aufrufen, nach einem Frame Layout: danach bleibt der Kopf, wo er ist.
func place_header(header: Control, points: Array, prefer_bottom := false) -> void:
	var top := header.get_global_rect()
	var parent := header.get_parent() as Control
	var bottom := Rect2(Vector2(top.position.x, parent.get_global_rect().end.y - top.size.y), top.size)
	var down := covers(top, points) and not covers(bottom, points)
	if prefer_bottom:
		down = not (covers(bottom, points) and not covers(top, points))
	if down:
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


## Lässt die Orte zu ihrer Größe wachsen oder schrumpfen; ruht, sobald alle angekommen sind
## und nichts leuchtet.
func _process(delta: float) -> void:
	_time += delta
	if not _zoom_run.is_empty():
		_step_zoom(delta)
	var moving := _zooming
	if _appear_t >= 0.0:
		_appear_t += minf(delta, MAX_ZOOM_STEP)
		if _appear_t >= APPEAR_TIME + APPEAR_STAGGER * float(maxi(_centers.size() - 1, 0)):
			_appear_t = -1.0
		moving = true
	for i in _grow.size():
		var target := 0.0
		if i == _hovered:
			target = 1.0
		elif _selected.has(str(_nodes[i]["key"])):
			target = SELECTED_GROW
		var now := move_toward(float(_grow[i]), target, delta / HOVER_TIME)
		_grow[i] = now
		moving = moving or now != target
	queue_redraw()
	if not moving and not _alive:
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
	_base = base
	if _fx != null:
		_fx.queue_redraw.call_deferred()
		_image.queue_redraw.call_deferred()
		_ambience.refresh.call_deferred()
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
	var medal := clampi(int(node.get("medal", 0)), 0, MEDAL_COLORS.size())
	var total := int(node.get("total", 0))
	var done := int(node.get("done", 0))
	var mastered := not boss and not disabled and is_mastered(node)
	var dim := 0.45 if disabled else 1.0
	var r := radius_of(i)
	var k := r / NODE_RADIUS
	var ring := _ring_width(r, mastered)
	var ring_r := _ring_radius(r, mastered)
	var pulse := _pulse(i)

	var shares: Array = [] if boss or disabled else node.get("bonus", [])
	# Ein weicher Schatten um den Ort und unter seinen Sternen: hebt sie vom unruhigen Bild ab
	# und gibt Tiefe. Zuerst gezeichnet — Schein, Ring und Sterne liegen darüber.
	var outside := ring_r + ring * 0.5
	_draw_soft_spot(i, at + Vector2(0, 3.0 * k), Vector2(outside * 1.75, outside * 1.75), 0.45)
	_draw_star_shadow(at, ring_r + ring * 0.5, k, shares, i)

	if mastered:
		_draw_rays(at, ring_r, maxf(r * 2.8, 52.0), float(i))
		var glow := maxf(r * 3.6, 56.0) * (1.0 + 0.12 * pulse)
		_draw_halo(at, glow, Color(RING_GOLD, 0.45 + 0.25 * pulse))
	draw_circle(at + Vector2(0, 4.0 * k), ring_r + ring * 0.5, SHADOW)
	var fill: Color = FILL_COLORS[fill_level(done, total)]
	if boss:
		fill = BOSS_COLOR if medal == 0 else (MEDAL_COLORS[medal - 1] as Color).darkened(0.35)
	if disabled:
		fill = DISABLED_COLOR
	# Gesperrt heißt grau, nicht durchsichtig: der Weg läuft sonst sichtbar durch den Ort.
	draw_circle(at, r, fill)
	var track := Color(0.07, 0.08, 0.11)
	draw_arc(at, ring_r - 0.5, 0.0, TAU, 48, track, ring + 3.0, true)
	if boss:
		if medal > 0:
			draw_arc(at, ring_r, 0.0, TAU, 48, MEDAL_COLORS[medal - 1], ring, true)
	elif mastered:
		# Alles gemeistert: ein breiter, massiver Ring — dunkle Außenkante, Gold, helle
		# Innenkante wie ein gegossener Reif — der zum hellen Gold pulsiert.
		draw_arc(at, ring_r, 0.0, TAU, 64, RING_GOLD.lerp(RING_SHINE, pulse * 0.6), ring, true)
		draw_arc(at, ring_r + ring * 0.32, 0.0, TAU, 64, Color(0.62, 0.42, 0.06), ring * 0.28, true)
		draw_arc(at, ring_r - ring * 0.3, 0.0, TAU, 64, Color(1.0, 0.98, 0.85), ring * 0.22, true)
	elif total > 0 and done > 0 and not disabled:
		# Der Ring füllt sich im Uhrzeigersinn von oben mit dem Anteil gemeisterter Wörter.
		var share := float(done) / float(total)
		draw_arc(at, ring_r, -PI * 0.5, -PI * 0.5 + TAU * share, 48, RING_GOLD, ring, true)
	if i == _hovered and not disabled:
		draw_arc(at, ring_r + ring * 0.5 + 4.0, 0.0, TAU, 48, Color(1, 1, 1, 0.8), 2.0, true)

	var font := get_theme_default_font()
	var glyph_size := maxi(roundi(get_theme_font_size("font_size", "SectionTitle") * k), 11)
	draw_string(font, at + Vector2(-r, glyph_size * 0.35), str(node.get("glyph", "")),
			HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, glyph_size, Color(0.97, 0.97, 1.0, dim))
	var top := at.y - ring_r - ring * 0.5
	if boss and medal > 0:
		draw_string(font, at + Vector2(-r, -r - 4.0 * k), "👑",
				HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, glyph_size)
		top -= glyph_size
	if _selected.has(str(node["key"])) and not disabled:
		_draw_pointer(Vector2(at.x, top), k)
	var below := ring_r + ring * 0.5
	_draw_star_row(at, below, k, shares, i)
	if not shares.is_empty():
		below += 2.0 + _star_size(k) * 2.0 + _star_size(k) * 0.3
	if show_captions:
		_draw_caption(at, below + 4.0 * k, str(node.get("caption", "")), dim)


## Ein flacher, weicher Fleck unter der Sternreihe, wie ein Schatten am Boden.
func _draw_star_shadow(at: Vector2, below: float, k: float, shares: Array, seed: int) -> void:
	if shares.is_empty():
		return
	var outer := _star_size(k)
	var first := _star_center(at, below, k, 0, shares.size())
	var last := _star_center(at, below, k, shares.size() - 1, shares.size())
	_draw_soft_spot(seed, (first + last) * 0.5 + Vector2(0, outer * 0.2),
			Vector2((last.x - first.x) * 0.5 + outer * 2.6, outer * 2.0), 0.45)


## Die Bonus-Sterne unter einem Ort: grau, bis der Bonus gemeistert ist, dann golden.
func _draw_star_row(at: Vector2, below: float, k: float, shares: Array, seed: int) -> void:
	if shares.is_empty():
		return
	var outer := _star_size(k)
	for s in shares.size():
		var center := _star_center(at, below, k, s, shares.size())
		var shape := star_points(center, outer, outer * 0.45)
		var lit := float(shares[s]) >= 1.0
		var closed := shape.duplicate()
		closed.append(shape[0])
		if lit:
			_draw_halo(center, outer * 2.8, Color(RING_GOLD, 0.35 + 0.15 * _pulse(seed * 7 + s)))
			draw_colored_polygon(shape, RING_GOLD)
			draw_polyline(closed, Color(1.0, 0.95, 0.7), 1.2, true)
		else:
			draw_colored_polygon(shape, Color(0.22, 0.23, 0.26))
			draw_polyline(closed, Color(0.6, 0.62, 0.66), 1.2, true)


## Die Stufe der Füllung 0..3 (dunkel, Bronze, Silber, Gold) für `done` von `total`. In
## Ganzzahlen verglichen wie FortressTier.tier_for: 1 von 4 sind genau 25 %.
static func fill_level(done: int, total: int) -> int:
	if total <= 0:
		return 0
	var level := 0
	for pct in FILL_PERCENT:
		if done * 100 >= int(pct) * total:
			level += 1
	return level


## Breite und Radius des Rings um einen Ort vom Radius `r`. Er liegt außen um die Füllung,
## durch eine dunkle Fuge getrennt — eine goldene Füllung soll ihn nicht verschlucken —
## und wird gemeistert breiter.
func _ring_width(r: float, mastered: bool) -> float:
	var ring := maxf(RING_WIDTH * r / NODE_RADIUS, 3.5)
	return ring * 1.6 if mastered else ring


func _ring_radius(r: float, mastered: bool) -> float:
	return r + 1.0 + _ring_width(r, mastered) * 0.5


## 0..1, langsam auf und ab — derselbe Takt für Schein und Ring eines Ortes, versetzt
## gegen die Nachbarn, damit die Karte nicht im Gleichschritt atmet.
func _pulse(seed: int) -> float:
	return 0.5 + 0.5 * sin(TAU * PULSE_HZ * _time + float(seed) * 1.7)


func _star_size(k: float) -> float:
	return maxf(12.0 * k, 8.0)


## Die Mitte des Bonus-Sterns `s` von `count` unter einem Ort (`below` Pixel unter der Mitte).
func _star_center(at: Vector2, below: float, k: float, s: int, count: int) -> Vector2:
	var outer := _star_size(k)
	return Vector2(at.x + (float(s) - float(count - 1) * 0.5) * outer * 2.4, at.y + below + 2.0 + outer)


## Langsam kreisende Strahlen hinter einem gemeisterten Ort: von `inner` bis `length`
## Pixel, innen golden, außen ausgeblendet.
func _draw_rays(at: Vector2, inner: float, length: float, seed: float) -> void:
	var turn := TAU * RAY_SPEED * _time + seed
	var half := PI / float(RAYS) * 0.35
	for n in RAYS:
		var angle := turn + TAU * float(n) / float(RAYS)
		var reach := length * (0.8 + 0.2 * sin(_time * 1.3 + float(n) * 2.0 + seed))
		var points := PackedVector2Array([
			at + Vector2.from_angle(angle - half) * inner,
			at + Vector2.from_angle(angle) * reach,
			at + Vector2.from_angle(angle + half) * inner,
		])
		draw_polygon(points, PackedColorArray([Color(RING_SHINE, 0.55), Color(RING_GOLD, 0.0),
				Color(RING_SHINE, 0.55)]))


## Ein weicher Schein um `at`, Durchmesser `diameter`, auf `item` (die Karte oder die
## Effektebene).
func _draw_halo(at: Vector2, diameter: float, color: Color, item: CanvasItem = self) -> void:
	item.draw_texture_rect(_glow_texture(),
			Rect2(at - Vector2(diameter, diameter) * 0.5, Vector2(diameter, diameter)), false, color)


func _glow_texture() -> Texture2D:
	if _glow == null:
		# Von Hand gerechnet: weiß, nach außen weich auslaufend (quadratisch, damit die Mitte
		# hell bleibt und der Rand ohne Kante verschwindet).
		var side := 64
		var image := Image.create(side, side, false, Image.FORMAT_RGBA8)
		var half := float(side) * 0.5
		for y in side:
			for x in side:
				var d := Vector2(float(x) + 0.5 - half, float(y) + 0.5 - half).length() / half
				var a := clampf(1.0 - d, 0.0, 1.0)
				image.set_pixel(x, y, Color(1, 1, 1, a * a))
		_glow = ImageTexture.create_from_image(image)
	return _glow


## Ein weicher dunkler Fleck um `center` mit den Halbachsen `size`: gestapelte Ellipsen,
## innen bis `strength` deckend, nach außen auslaufend.
func _draw_soft_spot(i: int, center: Vector2, size: Vector2, strength: float) -> void:
	const STEPS := 20
	var around := _node_transform(i)
	draw_set_transform_matrix(around * Transform2D(0.0, Vector2(1.0, size.y / size.x), 0.0, center))
	for n in STEPS:
		var t := float(n) / float(STEPS)
		draw_circle(Vector2.ZERO, size.x * (1.0 - t * 0.6), Color(0, 0, 0, strength / float(STEPS) * 3.0))
	draw_set_transform_matrix(around)


## Das Bild, in der Zoom-Transformation der Karte.
func _draw_image() -> void:
	var rect := map_rect(size, aspect(), cover)
	if rect.size.x <= 0.0:
		return
	_image.draw_set_transform_matrix(_base)
	if _texture != null:
		_image.draw_texture_rect(_texture, rect, false)
	else:
		# Ohne Bild eine schlichte Fläche mit Rand — die Karte soll als Karte lesbar bleiben,
		# bis ihr Bild da ist.
		_image.draw_rect(rect, BLANK_COLOR)
		_image.draw_rect(rect.grow(-8.0), BLANK_EDGE, false, 2.0)


## Die Zoom-Transformation, in der die Karte gerade steht — die Ebenen zeichnen darin mit.
func view_transform() -> Transform2D:
	return _base


## Was sich auf dem Bild bewegt (MapLayout.ambience), mit den Masken der Flächen
## (MapLayout.ambience_masks). Nach `setup` setzen: die Flächen lesen das Bild.
func set_ambience(entries: Array, masks: Dictionary = {}) -> void:
	_ambience.setup(entries, _texture, masks)


## Die Ebene mit dem, was sich bewegt — für Werkbank und Tests.
func ambience_layer() -> MapAmbience:
	return _ambience


## Die Transformation, in der Ort `i` gerade steht: Zoom der Karte und sein Aufspringen.
func _node_transform(i: int) -> Transform2D:
	var grow := appear_scale(i)
	var at: Vector2 = _centers[i]
	return _base * Transform2D(0.0, Vector2(grow, grow), 0.0, at * (1.0 - grow))


## Die additive Ebene: was an gemeisterten Orten und Sternen Licht abgibt.
func _draw_fx() -> void:
	for i in _centers.size():
		var node: Dictionary = _nodes[i]
		if not shines(node) or appear_scale(i) <= 0.01:
			continue
		_fx.draw_set_transform_matrix(_node_transform(i))
		var at: Vector2 = _centers[i]
		var r := radius_of(i)
		var k := r / NODE_RADIUS
		if is_mastered(node):
			var ring := _ring_width(r, true)
			var ring_r := _ring_radius(r, true)
			_draw_ring_bloom(at, ring_r, ring, _pulse(i))
			_draw_glint(at, ring_r, ring, float(i))
			_draw_motes(at, ring_r, maxf(r * 2.6, 48.0), i, MOTES, k)
			_draw_sparks(at, ring_r, maxf(r * 1.8, 34.0), i, SPARKLES, k)
		var shares: Array = node.get("bonus", [])
		var below := _ring_radius(r, is_mastered(node)) + _ring_width(r, is_mastered(node)) * 0.5
		for s in shares.size():
			if float(shares[s]) < 1.0:
				continue
			# Dieselben Funken wie am Ring, im Maß des Sterns: hinein und hinaus.
			var center := _star_center(at, below, k, s, shares.size())
			var outer := _star_size(k)
			_draw_motes(center, outer * 0.6, outer * 3.2, i * 7 + s, STAR_MOTES, k * 0.6)
			_draw_sparks(center, outer, outer * 2.4, i * 7 + s, STAR_SPARKLES, k * 0.6)
	_fx.draw_set_transform_matrix(Transform2D())


## Schein in Ringform: breite, schwache Bögen über dem vollen Ring — er strahlt.
func _draw_ring_bloom(at: Vector2, ring_r: float, ring: float, pulse: float) -> void:
	var strength := 0.6 + 0.4 * pulse
	for layer in [[2.0, 0.22], [3.6, 0.12], [5.5, 0.06]]:
		_fx.draw_arc(at, ring_r, 0.0, TAU, 64, Color(RING_GOLD, float(layer[1]) * strength),
				ring * float(layer[0]), true)


## Ein heller Lichtpunkt mit Schweif, der um den Ring läuft.
func _draw_glint(at: Vector2, ring_r: float, ring: float, seed: float) -> void:
	var head := TAU * GLINT_SPEED * _time + seed * 1.3
	var steps := 8
	for n in steps:
		var a := head - float(n) * 0.07
		var fade := 1.0 - float(n) / float(steps)
		_fx.draw_arc(at, ring_r, a - 0.07, a, 6, Color(1.0, 0.97, 0.85, 0.75 * fade), ring * 0.8, true)
	_draw_halo(at + Vector2.from_angle(head) * ring_r, ring * 3.0, Color(1.0, 0.97, 0.85, 0.8), _fx)


## Funken, die vom Rand (`from` Pixel um die Mitte) nach außen schießen, mit Schweif, und
## verglühen. Ohne Zustand: Lage und Richtung folgen aus Uhr, Ort und Nummer, jeder
## Durchgang würfelt neu.
func _draw_sparks(at: Vector2, from: float, travel: float, seed: int, count: int, k: float) -> void:
	for j in count:
		var phase := _time / SPARKLE_LIFE + float(j) / float(count) + float(seed) * 0.37
		var cycle := floori(phase)
		var t := phase - float(cycle)
		var dir := Vector2.from_angle(TAU * _noise(seed * 131 + j * 17 + cycle * 7))
		# Schnell hinaus, dann langsamer: ease-out.
		var out := 1.0 - (1.0 - t) * (1.0 - t)
		var pos := at + dir * (from + travel * out) + Vector2(0.0, travel * 0.25 * t * t)
		var alpha := (1.0 - t) * minf(1.0, t * 8.0)
		var tail := maxf(10.0 * k, 6.0) * (1.0 - t)
		_fx.draw_line(pos - dir * tail, pos, Color(RING_SHINE, alpha * 0.8), maxf(2.0 * k, 1.5), true)
		_draw_halo(pos, maxf(14.0 * k, 9.0), Color(RING_SHINE, alpha), _fx)


## Funken, die von außen (`reach` Pixel) spiralförmig in den Ort (`into`) gezogen werden,
## immer schneller, und beim Ankommen aufblitzen.
func _draw_motes(at: Vector2, into: float, reach: float, seed: int, count: int, k: float) -> void:
	for j in count:
		var phase := _time / MOTE_LIFE + float(j) / float(count) + float(seed) * 0.61
		var cycle := floori(phase)
		var t := phase - float(cycle)
		var angle := TAU * _noise(seed * 977 + j * 31 + cycle * 13) + t * 1.2
		var pos := at + Vector2.from_angle(angle) * lerpf(reach, into, t * t)
		var alpha := t / 0.8 if t < 0.8 else (1.0 - t) / 0.2 * 1.6
		var size := maxf(12.0 * k, 7.0) * (0.6 + 0.6 * t)
		_draw_halo(pos, size, Color(RING_SHINE, clampf(alpha, 0.0, 1.0) * 0.9), _fx)


## Eine feste Zufallszahl 0..1 für `n` — dieselbe in jedem Frame.
static func _noise(n: int) -> float:
	return fposmod(sin(float(n) * 12.9898) * 43758.5453, 1.0)


## Der Pfeil über einem markierten Ort; `top` ist die Oberkante des Ortes (samt Krone).
func _draw_pointer(top: Vector2, k: float) -> void:
	var h := maxf(14.0 * k, 11.0)
	var bob := (0.5 + 0.5 * sin(TAU * BOB_HZ * _time)) * maxf(4.0 * k, 3.0)
	var tip := top + Vector2(0.0, -maxf(5.0 * k, 3.0) - bob)
	var arrow := PackedVector2Array([tip, tip + Vector2(-h * 0.75, -h), tip + Vector2(h * 0.75, -h)])
	var shadow := PackedVector2Array()
	for p in arrow:
		shadow.append(p + Vector2(0.0, 2.0))
	draw_colored_polygon(shadow, SHADOW)
	draw_colored_polygon(arrow, SELECTED_COLOR)
	arrow.append(arrow[0])
	draw_polyline(arrow, Color(0.1, 0.1, 0.12), 1.5, true)


## Die Ecken eines fünfzackigen Sterns um `center`, Spitze oben.
static func star_points(center: Vector2, outer: float, inner: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for n in 10:
		var radius := outer if n % 2 == 0 else inner
		out.append(center + Vector2.from_angle(-PI * 0.5 + PI * float(n) / 5.0) * radius)
	return out


## Die Beschriftung `below` Pixel unter der Mitte des Ortes, auf einer dunklen Platte — das
## Bild darunter ist bunt.
func _draw_caption(at: Vector2, below: float, text: String, dim: float) -> void:
	if text.is_empty():
		return
	var font := get_theme_default_font()
	var font_size := get_theme_font_size("font_size", "Caption")
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 16.0
	var top := at.y + below
	var plate := Rect2(at.x - width * 0.5, top, width, font_size + 8.0)
	draw_rect(plate, Color(PLATE, PLATE.a * dim))
	draw_string(font, Vector2(plate.position.x, top + font_size + 2.0), text,
			HORIZONTAL_ALIGNMENT_CENTER, width, font_size, Color(0.95, 0.96, 1.0, dim))
