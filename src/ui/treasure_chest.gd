class_name TreasureChest
extends Control
## Schatzkiste, die man aufdrücken muss: `hold_time` lang mit der Maus auf der Kiste oder
## mit `ui_accept` halten, dabei wackelt sie immer heftiger, dann springt der Deckel auf und
## eine Münze je Goldstück fliegt heraus. Loslassen setzt zurück. Die Kiste ist ein
## KayKit-Modell in einem SubViewport mit eigener Welt; ohne Modell (`use_model = false`)
## zeichnet sie sich selbst. Sie verbucht nichts, sie meldet nur `opened`.

## Der Deckel ist ab (beim Platzen, nicht nach dem Münzflug); `gold` ist zu verbuchen.
signal opened(gold: int)
## Das Aufdrücken hat begonnen bzw. wurde vor dem Ende losgelassen (für Hinweistexte).
signal hold_started
signal hold_cancelled

const COIN_SCENE := preload("res://scenes/ui/day_coin.tscn")

## Haltezeit im Spiel, s. Die Werkbank verstellt `hold_time`.
const HOLD_TIME := 2.0
## Wackel-Frequenz (Hz) und Höchstauslenkung (Grad, Skalenanteil, Hüpfen in
## Modell-Einheiten); die Auslenkung wächst mit dem Fortschritt.
const WOBBLE_HZ := 4.5
const WOBBLE_MAX_DEG := 9.0
const WOBBLE_MAX_SCALE := 0.08
const WOBBLE_HOP := 0.12

## Dauer des Münzflugs und des Deckelaufschlags, s.
const COIN_FLIGHT := 1.0
const LID_TIME := 0.4
## Versatz zwischen zwei Münzen (s) und die Gesamtzeit, auf die er gedeckelt ist (s).
const COIN_STAGGER := 0.03
const COIN_STAGGER_TOTAL := 0.5
## Der Münzflug in Modell-Einheiten: Startpunkt im Kistenmaul, Gipfelhöhe (min, max),
## Streubreite und Umdrehungen (min, max). Gefallen wird unter die Bildkante (`_floor_y`).
const COIN_MOUTH := Vector3(0.0, 0.62, 0.0)
const COIN_RISE := Vector2(1.1, 2.4)
const COIN_SPREAD := 2.0
const COIN_TURNS := Vector2(1.5, 3.5)
## So weit (Modell-Einheiten, im Bild) fällt eine Münze unter die Kante, ganz hinaus.
const COIN_CLEARANCE := 0.4

# --- Modell -------------------------------------------------------------------

const MODEL_DIR := "res://assets/models/props"
## Ein Modell für alle Güten; `chest_gold` aus dem Pack enthält schon einen Münzhaufen.
const CHEST_MODEL := "chest"
const COIN_MODEL := "coin"

## Der Beschlag der Güte kommt aus dem Texturatlas: ein Raster aus 8×4 Feldern, jedes ein
## senkrechter Verlauf. Die Kiste benutzt Feld (1,0) für den Beschlag und (4,0) für das
## Holz, kein Dreieck liegt in beiden. Rücken die UV-Koordinaten der Beschlag-Vertices um
## ganze Felder weiter, wechselt nur der Beschlag die Farbe, der Verlauf bleibt. Ein Filter
## auf dem geteilten Atlas-Material träfe auch Holz und alle anderen Modelle des Packs.
const ATLAS_CELLS := Vector2i(8, 4)
const METAL_CELL := Vector2i(1, 0)
## Beschlag je Güte (Reihenfolge von ChestReward.Tier): Stahl, Kupfer, Silber, Gold. Das
## Gold (7,2) ist das Feld der Münze.
const TIER_METAL := [
	Vector2i(1, 0),
	Vector2i(6, 0),
	Vector2i(0, 1),
	Vector2i(7, 2),
]
## Kamera wie im Kampf (orthografisch, Grad). `CAM_SIZE`: Bildfeldhöhe über der
## Widget-Höhe in Modell-Einheiten (siehe `_cam_size`), `CAM_HEIGHT` der Zielpunkt. Die
## Kiste bleibt mit offenem Deckel im Widget (tests/treasure_chest_test.gd).
const CAM_PITCH := -22.0
const CAM_YAW := 35.0
const CAM_SIZE := 2.9
const CAM_DIST := 8.0
const CAM_HEIGHT := 0.88
const SUN_ROT := Vector3(-55.0, -35.0, 0.0)
const FILL_ROT := Vector3(-20.0, 150.0, 0.0)
## So weit steht der 3D-Ausschnitt je Seite über das Widget hinaus, als Anteil der
## Widget-Größe: ein SubViewport schneidet hart an seiner Kante, die Münzen brauchen Platz.
const STAGE_PAD := Vector2(0.5, 0.75)
## Öffnungswinkel des Deckels (Grad) und Abheben vom Scharnier (Modell-Einheiten). Klein
## genug, dass der Deckel im Ausschnitt bleibt.
const LID_OPEN_DEG := 70.0
const LID_FLY := 0.15

enum State {
	CLOSED,   ## Wartet auf das Aufdrücken.
	HOLDING,  ## Wird gerade gedrückt, wackelt.
	OPENED,   ## Deckel ab, Münzen fliegen bzw. sind geflogen.
}

## Farben je Güte für die gezeichnete Kiste, in der Reihenfolge von ChestReward.Tier:
## [Korpus, Deckel, Beschlag].
const PALETTES := [
	[Color(0.42, 0.28, 0.16), Color(0.52, 0.35, 0.2), Color(0.58, 0.47, 0.32)],
	[Color(0.36, 0.24, 0.15), Color(0.45, 0.3, 0.18), Color(0.78, 0.48, 0.22)],
	[Color(0.28, 0.29, 0.34), Color(0.35, 0.36, 0.42), Color(0.8, 0.83, 0.88)],
	[Color(0.38, 0.29, 0.13), Color(0.47, 0.36, 0.16), Color(0.98, 0.84, 0.38)],
]
## Fortschrittsbalken unter der Kiste: Spur und Füllung.
const TRACK := Color(0.25, 0.25, 0.3)
const FILL := Color(1.0, 0.8, 0.35)
## Licht, das beim Platzen aus der Kiste kommt.
const GLOW := Color(1.0, 0.9, 0.55)
## Anteil von COIN_FLIGHT, über den das Licht verblasst.
const GLOW_SHARE := 0.6

## Haltezeit dieser Kiste. Voreingestellt ist HOLD_TIME; die Werkbank verstellt sie.
var hold_time: float = HOLD_TIME
## Modell oder Zeichnung; wirkt beim nächsten `present()`.
var use_model := true

var _state: State = State.CLOSED
var _tier: int = ChestReward.Tier.WOOD
var _gold: int = 0
var _hold: float = 0.0
## Deckel-Abflug 0..1 und Lichtring 0..1, von Tweens getrieben (siehe _burst).
var _lid: float = 0.0
var _burst_t: float = 0.0
var _mouse_held := false
## > 0: von Hand gesetzte Münzzahl (Werkbank), sonst aus dem Gold gerechnet.
var _coins_override := -1

@onready var _stage: SubViewportContainer = %Stage
@onready var _view: SubViewport = %View
@onready var _pivot: Node3D = %Pivot
## Münzschichten (3D-Modelle oder 2D-Zeichnungen), immer nur eine belegt.
@onready var _coins_3d: Node3D = %Coins3D
@onready var _coin_layer: Control = %Coins

var _model: Node3D = null
var _lid_node: Node3D = null
var _lid_home := Vector3.ZERO
## Alle Tweens der aktuellen Kiste; `present()` bricht sie ab.
var _tweens: Array[Tween] = []


func _ready() -> void:
	# Viewport und Münzschicht ignorieren die Maus (in der Szene gesetzt), sonst risse eine
	# Münze im Weg das Halten ab.
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_setup_view()
	_layout_stage()


## Kamera und Licht per Code, damit die .tscn keine Transform-Basen enthält.
func _setup_view() -> void:
	var cam_pivot := %CamPivot as Node3D
	cam_pivot.rotation_degrees = Vector3(CAM_PITCH, CAM_YAW, 0.0)
	cam_pivot.position = Vector3(0.0, CAM_HEIGHT, 0.0)
	var cam := %Cam as Camera3D
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = _cam_size()
	cam.position = Vector3(0.0, 0.0, CAM_DIST)
	(%Sun as DirectionalLight3D).rotation_degrees = SUN_ROT
	(%Fill as DirectionalLight3D).rotation_degrees = FILL_ROT


## Legt den 3D-Ausschnitt um STAGE_PAD über das Widget hinaus, über die Offsets bei
## Vollbild-Ankern. Die SubViewport-Größe wird von Hand gesetzt, weil der Container sie
## erst bei seiner nächsten Größenänderung nachzieht.
func _layout_stage() -> void:
	if _stage == null:
		return
	var pad := (size * STAGE_PAD).round()
	_stage.offset_left = -pad.x
	_stage.offset_top = -pad.y
	_stage.offset_right = pad.x
	_stage.offset_bottom = pad.y
	# Vor dem ersten Layout-Durchgang ist die Größe noch 0.
	_view.size = Vector2i((size + pad * 2.0).max(Vector2.ONE))


## Das Polster je Seite in Pixeln — die Nullstelle des Widgets im Ausschnitt.
func stage_pad() -> Vector2:
	return (size * STAGE_PAD).round()


## Höhe des Bildfelds in Modell-Einheiten, mit dem Polster gewachsen.
func _cam_size() -> float:
	return CAM_SIZE * (1.0 + 2.0 * STAGE_PAD.y)


## Auf dieser Höhe ist eine Münze über `x`/`z` aus dem Bild gefallen. Gerechnet über die
## Bildachse der schrägen Kamera, nicht über die Welthöhe: Δy rückt im Bild nur um
## Δy·cos(Neigung), und `x`/`z` verschieben zusätzlich.
func _floor_y(x: float, z: float) -> float:
	var up := Basis.from_euler(Vector3(deg_to_rad(CAM_PITCH), deg_to_rad(CAM_YAW), 0.0)).y
	var goal := -_cam_size() * 0.5 - COIN_CLEARANCE
	# Bildhöhe eines Punkts p: (p - Ziel)·up. Nach y aufgelöst.
	return CAM_HEIGHT + (goal - up.x * x - up.z * z) / up.y


## Stellt eine Kiste der Güte `tier` mit `gold` Inhalt hin, geschlossen und wartend.
## Mehrfach aufrufbar. `coins` > 0 setzt die Zahl der Münzen von Hand statt `coin_count`.
func present(tier: int, gold: int, coins := -1) -> void:
	_kill_tweens()
	_clear_coins()
	_tier = clampi(tier, 0, TIER_METAL.size() - 1)
	_gold = maxi(0, gold)
	_coins_override = coins
	_state = State.CLOSED
	_hold = 0.0
	_lid = 0.0
	_burst_t = 0.0
	_mouse_held = false
	_build_model()
	_apply_wobble()
	Hints.attach(self, str(ChestReward.TIER_NAMES[_tier]),
			"zum Öffnen 2 Sekunden gedrückt halten")
	set_process(true)
	queue_redraw()


func is_open() -> bool:
	return _state == State.OPENED


## Haltefortschritt 0..1.
func progress() -> float:
	return clampf(_hold / maxf(0.01, hold_time), 0.0, 1.0)


## Zahl der gerade fliegenden Münzen, Modelle wie Zeichnungen.
func coins_in_flight() -> int:
	return _coins_3d.get_child_count() + _coin_layer.get_child_count()


## Das gerade gezeigte Modell, null, wenn gezeichnet wird.
func model() -> Node3D:
	return _model


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT:
		return
	_mouse_held = button.pressed
	accept_event()


## Verlässt der Zeiger die Kiste, gilt das als Loslassen.
func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_mouse_held = false
	elif what == NOTIFICATION_RESIZED:
		_layout_stage()
		queue_redraw()


func _process(delta: float) -> void:
	# Unsichtbar läuft `_process` weiter; eine gedrückte Taste darf die Kiste dann nicht öffnen.
	if not is_visible_in_tree():
		return
	if _state == State.OPENED:
		set_process(false)
		return
	var down := _mouse_held or Input.is_action_pressed("ui_accept")
	if _state == State.CLOSED:
		if down:
			begin_hold()
		return
	if down:
		hold(delta)
	else:
		cancel_hold()


# --- Aufdrücken ---------------------------------------------------------------
#
# Öffentlich für Tests; `_process` entscheidet nur, ob gerade gedrückt wird.

func begin_hold() -> void:
	if _state != State.CLOSED:
		return
	_state = State.HOLDING
	_hold = 0.0
	hold_started.emit()


## Schiebt den Haltefortschritt um `delta` s weiter; bei `hold_time` platzt die Kiste.
func hold(delta: float) -> void:
	if _state != State.HOLDING:
		return
	_hold += delta
	_apply_wobble()
	queue_redraw()
	if _hold >= maxf(0.01, hold_time):
		_burst()


func cancel_hold() -> void:
	if _state != State.HOLDING:
		return
	_state = State.CLOSED
	_hold = 0.0
	_apply_wobble()
	queue_redraw()
	hold_cancelled.emit()


## Deckel ab: Licht, Münzflug, Meldung an den Aufrufer.
func _burst() -> void:
	_state = State.OPENED
	_hold = hold_time
	_apply_wobble()
	Sfx.play(&"monster_kill")
	var tw := _new_tween()
	tw.set_parallel(true)
	tw.tween_method(_set_lid, 0.0, 1.0, LID_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_method(_set_burst, 0.0, 1.0, COIN_FLIGHT * GLOW_SHARE)
	_fly_coins()
	opened.emit(_gold)


## Deckelstellung 0..1, für Modell und Zeichnung.
func _set_lid(value: float) -> void:
	_lid = value
	if _lid_node != null:
		_lid_node.rotation.x = deg_to_rad(-LID_OPEN_DEG * value)
		# Beim Abheben rückt der Deckel um gut ein Drittel davon nach hinten.
		_lid_node.position = _lid_home + Vector3(0.0, LID_FLY * value, -LID_FLY * 0.35 * value)
	queue_redraw()


func _set_burst(value: float) -> void:
	_burst_t = value
	queue_redraw()


# --- Modell aufbauen ----------------------------------------------------------

## Hängt das Modell der aktuellen Güte unter den Pivot; ohne Modell zeichnet `_draw`.
func _build_model() -> void:
	_lid_node = null
	if _model != null:
		_pivot.remove_child(_model)
		# Sofort freigeben: `_lid_node` ist schon null, die Tweens sind abgebrochen.
		_model.free()
		_model = null
	_stage.visible = use_model
	if not use_model:
		return
	var path := "%s/%s.gltf" % [MODEL_DIR, CHEST_MODEL]
	if not ResourceLoader.exists(path):
		_stage.visible = false
		return
	_model = (load(path) as PackedScene).instantiate() as Node3D
	_pivot.add_child(_model)
	_lid_node = _find_lid(_model)
	if _lid_node != null:
		_lid_home = _lid_node.position
	_recolor_metal(_model, TIER_METAL[_tier])


## Der Deckel (`chest_lid`), über den Namen gesucht: die Reihenfolge hängt vom Export ab.
func _find_lid(node: Node) -> Node3D:
	for child in node.get_children():
		if child is Node3D and child.name.ends_with("_lid"):
			return child as Node3D
		var deeper := _find_lid(child)
		if deeper != null:
			return deeper
	return null


## Gibt dem Beschlag die Farbe der Güte (siehe ATLAS_CELLS).
func _recolor_metal(node: Node, cell: Vector2i) -> void:
	if cell != METAL_CELL:
		var mesh := node as MeshInstance3D
		if mesh != null and mesh.mesh != null:
			mesh.mesh = _mesh_with_metal_cell(mesh.mesh, cell)
	for child in node.get_children():
		_recolor_metal(child, cell)


## Kopie des Meshes, in der die Beschlag-Vertices auf `cell` zeigen. `surface_get_arrays`
## liefert eine Kopie und das Ergebnis ist ein eigenes ArrayMesh: das geladene Mesh ist
## geteilt und bleibt unangetastet (CONVENTIONS „Fallen“).
func _mesh_with_metal_cell(source: Mesh, cell: Vector2i) -> ArrayMesh:
	var shift := Vector2(cell - METAL_CELL) / Vector2(ATLAS_CELLS)
	var out := ArrayMesh.new()
	for s in source.get_surface_count():
		var arrays := source.surface_get_arrays(s)
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		for i in uvs.size():
			if cell_of(uvs[i]) == METAL_CELL:
				uvs[i] += shift
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out.surface_set_material(s, source.surface_get_material(s))
	return out


## Atlas-Feld, in dem eine UV-Koordinate liegt.
static func cell_of(uv: Vector2) -> Vector2i:
	return Vector2i(int(uv.x * float(ATLAS_CELLS.x)), int(uv.y * float(ATLAS_CELLS.y)))


## Wackeln des Modells, mit dem Fortschritt wachsend. Gekippt wird mit halber Frequenz
## und 0,4-facher, gedreht mit 1,6-facher Auslenkung.
func _apply_wobble() -> void:
	if _pivot == null:
		return
	if _state != State.HOLDING:
		_pivot.rotation = Vector3.ZERO
		_pivot.position = Vector3.ZERO
		_pivot.scale = Vector3.ONE
		return
	var p := progress()
	var swing := sin(_hold * TAU * WOBBLE_HZ)
	_pivot.rotation_degrees = Vector3(
		sin(_hold * TAU * WOBBLE_HZ * 0.5) * WOBBLE_MAX_DEG * 0.4 * p,
		swing * WOBBLE_MAX_DEG * 1.6 * p,
		0.0)
	_pivot.position = Vector3(0.0, absf(swing) * WOBBLE_HOP * p, 0.0)
	_pivot.scale = Vector3.ONE * (1.0 + WOBBLE_MAX_SCALE * p)


# --- Münzen -------------------------------------------------------------------

## Eine Münze je Goldstück, als Modell in der 3D-Welt oder gezeichnet.
func _fly_coins() -> void:
	var count := _coins_override if _coins_override > 0 else coin_count(_gold)
	if count <= 0:
		return
	if _model != null:
		_fly_coins_3d(count)
	else:
		_fly_coins_2d(count)


## Der Flug in der 3D-Welt. Streuung in Modell-Einheiten, Teilzeiten als Anteile von
## `COIN_FLIGHT`.
func _fly_coins_3d(count: int) -> void:
	var path := "%s/%s.gltf" % [MODEL_DIR, COIN_MODEL]
	if not ResourceLoader.exists(path):
		_fly_coins_2d(count)
		return
	var scene := load(path) as PackedScene
	var step := minf(COIN_STAGGER, COIN_STAGGER_TOTAL / float(count))
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in count:
		var coin := scene.instantiate() as Node3D
		_coins_3d.add_child(coin)
		coin.position = COIN_MOUTH + Vector3(
				rng.randf_range(-0.2, 0.2), 0.0, rng.randf_range(-0.15, 0.15))
		# Aufgestellt: die Münze liegt im Modell flach.
		coin.rotation = Vector3(PI * 0.5, rng.randf() * TAU, 0.0)
		# Fächer über die ganze Breite, immer nach oben aus der Kiste heraus.
		var side := (float(i) + rng.randf()) / float(count) - 0.5
		var peak := coin.position + Vector3(
				side * COIN_SPREAD,
				rng.randf_range(COIN_RISE.x, COIN_RISE.y),
				rng.randf_range(-0.3, 0.3))
		var gone_x := peak.x + side * COIN_SPREAD * 0.35
		var gone := Vector3(gone_x, _floor_y(gone_x, peak.z), peak.z)
		var delay := step * float(i)
		var tw := _new_tween()
		tw.tween_property(coin, "position", peak, COIN_FLIGHT * 0.45) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).set_delay(delay)
		tw.tween_property(coin, "position", gone, COIN_FLIGHT * 0.75) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(coin.queue_free)
		var turn := Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(COIN_TURNS.x, COIN_TURNS.y), 0.0)
		var spin := _new_tween()
		spin.tween_property(coin, "rotation", coin.rotation + turn * TAU, COIN_FLIGHT * 1.2) \
				.set_delay(delay)


## Der gezeichnete Flug, Weiten als Anteil der Widget-Größe. Die Schicht ist so groß wie
## das Widget, deshalb verblassen die Münzen.
func _fly_coins_2d(count: int) -> void:
	var center := size * 0.5
	var step := minf(COIN_STAGGER, COIN_STAGGER_TOTAL / float(count))
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in count:
		var coin := COIN_SCENE.instantiate() as DayCoin
		_coin_layer.add_child(coin)
		coin.setup(DayCoin.State.EARNED, false)
		coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var coin_size := coin.custom_minimum_size
		coin.position = center - coin_size * 0.5
		# Fächer über die ganze Breite, immer nach oben aus der Kiste heraus.
		var spread := (float(i) + rng.randf()) / float(count) - 0.5
		var peak := coin.position + Vector2(spread * size.x * 1.4, -size.y * rng.randf_range(0.5, 1.0))
		var fall := peak + Vector2(spread * size.x * 0.4, size.y * rng.randf_range(0.6, 1.1))
		var tw := _new_tween()
		tw.tween_property(coin, "position", peak, COIN_FLIGHT * 0.45) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT) \
				.set_delay(step * float(i))
		tw.tween_property(coin, "position", fall, COIN_FLIGHT * 0.55) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		var fade := _new_tween()
		fade.tween_property(coin, "modulate:a", 0.0, COIN_FLIGHT * 0.4) \
				.set_delay(step * float(i) + COIN_FLIGHT * 0.6)
		fade.tween_callback(coin.queue_free)


func _new_tween() -> Tween:
	var tw := create_tween()
	_tweens.append(tw)
	return tw


func _kill_tweens() -> void:
	for tw in _tweens:
		if tw != null and tw.is_valid():
			tw.kill()
	_tweens.clear()


## Sofort statt per queue_free(), sonst zählten die Münzen bis zum Frame-Ende mit.
func _clear_coins() -> void:
	for layer: Node in [_coins_3d, _coin_layer]:
		for child in layer.get_children():
			layer.remove_child(child)
			child.free()


## So viele Münzen fliegen für `gold` heraus: genau eine je Goldstück, ungedeckelt.
static func coin_count(gold: int) -> int:
	return maxi(0, gold)


# --- Zeichnen -----------------------------------------------------------------
#
# Balken und Licht liegen hinter dem Viewport; den Korpus zeichnet nur, wer kein Modell hat.

func _draw() -> void:
	var center := size * 0.5
	var p := progress()
	if _stage != null and _stage.visible:
		if _state == State.OPENED:
			_draw_glow(Vector2(center.x, center.y * 1.05), minf(size.x, size.y) * 0.28)
		else:
			_draw_progress(p)
		return
	# Gewackelt wird im Zeichnen, damit Balken und Münzen ruhig bleiben.
	var angle := 0.0
	var zoom := 1.0
	if _state == State.HOLDING:
		angle = sin(_hold * TAU * WOBBLE_HZ) * deg_to_rad(WOBBLE_MAX_DEG) * p
		zoom = 1.0 + WOBBLE_MAX_SCALE * p
	draw_set_transform(center, angle, Vector2.ONE * zoom)
	_draw_chest()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _state != State.OPENED:
		_draw_progress(p)


## Licht, das beim Platzen aus der Kiste kommt und mit dem Münzflug verblasst.
func _draw_glow(at: Vector2, radius: float) -> void:
	var r := radius * (1.0 + 1.4 * _burst_t)
	draw_circle(at, r, Color(GLOW, 0.35 * (1.0 - _burst_t)))
	draw_arc(at, r, 0.0, TAU, 32, Color(GLOW, 0.6 * (1.0 - _burst_t)), 2.0, true)


## Zeichnet die Kiste um den Ursprung (per draw_set_transform die Mitte). Alle Maße sind
## Anteile der Kistenbreite `cw` bzw. -höhe `ch`.
func _draw_chest() -> void:
	var palette: Array = PALETTES[_tier]
	var body_color: Color = palette[0]
	var lid_color: Color = palette[1]
	var fitting: Color = palette[2]

	var cw := minf(size.x * 0.78, size.y * 1.3)
	var ch := cw * 0.78
	var lid_h := ch * 0.4
	var top := -ch * 0.5
	var body := Rect2(-cw * 0.5, top + lid_h, cw, ch - lid_h)

	# Offene Kiste: erst das Licht aus dem Innenraum, dann der Korpus darüber.
	if _state == State.OPENED:
		_draw_glow(Vector2(0.0, top + lid_h), cw * 0.35)

	draw_rect(body, body_color)
	# Waagerechter Beschlag und senkrechter Riemen.
	draw_rect(Rect2(body.position.x, body.position.y, body.size.x, body.size.y * 0.16), fitting)
	draw_rect(Rect2(-cw * 0.08, body.position.y, cw * 0.16, body.size.y), fitting)
	# Schloss.
	draw_rect(Rect2(-cw * 0.06, body.position.y + body.size.y * 0.3, cw * 0.12, ch * 0.16),
			Color(fitting, 0.9).lightened(0.2))

	# Deckel: fliegt beim Platzen nach oben weg und dreht sich dabei.
	var lid_rect := Rect2(-cw * 0.52, top, cw * 1.04, lid_h)
	if _lid <= 0.0:
		draw_rect(lid_rect, lid_color)
		draw_rect(Rect2(lid_rect.position.x, lid_rect.position.y + lid_h * 0.62,
				lid_rect.size.x, lid_h * 0.24), fitting)
		return
	var lift := -ch * 1.1 * _lid
	draw_set_transform(Vector2(cw * 0.15 * _lid, lift) + size * 0.5, -0.9 * _lid, Vector2.ONE)
	draw_rect(lid_rect, Color(lid_color, 1.0 - 0.7 * _lid))
	draw_rect(Rect2(lid_rect.position.x, lid_rect.position.y + lid_h * 0.62,
			lid_rect.size.x, lid_h * 0.24), Color(fitting, 1.0 - 0.7 * _lid))


## Fortschritt des Aufdrückens als Balken unter der Kiste, px.
func _draw_progress(p: float) -> void:
	var track_h := 6.0
	var track_w := size.x * 0.6
	var origin := Vector2((size.x - track_w) * 0.5, size.y - track_h - 2.0)
	draw_rect(Rect2(origin, Vector2(track_w, track_h)), TRACK)
	if p > 0.0:
		draw_rect(Rect2(origin, Vector2(track_w * p, track_h)), FILL)
