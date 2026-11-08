class_name MapAmbience
extends Control
## Was sich auf einer Gebietskarte bewegt (MapLayout.ambience, ARCHITECTURE „Karte und
## Laufanfrage“). Je Fläche ein Kind mit eigenem Material (Maske als Uniform); die Quellen einer
## Art teilen eins, Versatz und Stärke stecken in der Farbe ihres Rechtecks (r, g).

const SHADERS := {
	"water": preload("res://assets/shaders/map_water.gdshader"),
	"falls": preload("res://assets/shaders/map_falls.gdshader"),
	"mist": preload("res://assets/shaders/map_mist.gdshader"),
	"smoke": preload("res://assets/shaders/map_smoke.gdshader"),
	"ember": preload("res://assets/shaders/map_ember.gdshader"),
	"torch": preload("res://assets/shaders/map_torch.gdshader"),
	"volcano": preload("res://assets/shaders/map_volcano.gdshader"),
}
const OVERLAY_SHADER := preload("res://assets/shaders/map_mask_overlay.gdshader")
## Größe einer Quelle bei `size` 1, in Bildhöhen (Breite, Höhe). TORCH_BASE: Lage der Quelle
## im Rechteck der Fackel von oben (Anteil), wie BASE in map_torch.gdshader.
const SPOT_SIZE := {"smoke": Vector2(0.07, 0.2), "ember": Vector2(0.05, 0.05),
		"torch": Vector2(0.03, 0.06), "volcano": Vector2(0.2, 0.36)}
const TORCH_BASE := 0.8
## Lage des Kraters im Rechteck des Vulkans von oben, wie BASE in map_volcano.gdshader.
const VOLCANO_BASE := 0.9
## Ein Klick auf eine Quelle facht sie an (`stir`): so lange (s) …
const STIR_TIME := {"smoke": 2.5, "ember": 1.6, "torch": 1.6, "volcano": 4.5}
## … und so viel größer (Faktor bei voller Stärke); der Vulkan bricht stattdessen aus.
const STIR_GROW := {"smoke": 1.0, "ember": 0.8, "torch": 0.9, "volcano": 0.0}
## Trefferrand um das Rechteck einer Quelle (px).
const STIR_HIT := 6.0
const OUTLINE_COLOR := Color(0.4, 0.9, 1.0, 0.9)
## Wie die Werkbank die Masken tönt.
const MASK_TINT := {"water": Color(0.2, 0.75, 1.0, 0.45), "falls": Color(0.9, 1.0, 1.0, 0.55),
		"mist": Color(0.85, 0.5, 1.0, 0.4)}

## Die Werkbank zeigt die Masken der Flächen getönt und die Quellen als Punkte.
var show_outline := false:
	set(value):
		show_outline = value
		refresh()

var _canvas: MapCanvas
var _entries: Array = []
var _texture: Texture2D
var _masks: Dictionary = {}
var _layer_entries: Dictionary = {}
var _outline: Control
var _fish: MapFish
## Index in `_entries` -> Beginn des Anfachens (s, `_now`).
var _stirred: Dictionary = {}
## Uhr (s); Tests setzen sie fest, sonst die Laufzeit.
var now_override := -1.0:
	set(value):
		now_override = value
		if _fish != null:
			_fish.now_override = value


func _init(canvas: MapCanvas) -> void:
	_canvas = canvas
	name = "Ambience"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_behind_parent = true
	set_anchors_preset(Control.PRESET_FULL_RECT)


## Baut die Ebene für `entries` (MapLayout.ambience) über dem Bild `texture` neu; `masks`
## sind die der Flächen (mask -> Texture2D, MapLayout.ambience_masks). Flächen lesen das
## Bild — ohne Bild oder ohne Maske gibt es nur die Quellen.
func setup(entries: Array, texture: Texture2D, masks: Dictionary = {}) -> void:
	_entries = entries
	_texture = texture
	_masks = masks
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_layer_entries.clear()
	_stirred.clear()
	_fish = null
	var spots := {}
	for entry: Dictionary in entries:
		var kind := str(entry["kind"])
		if kind in MapLayout.AREA_KINDS:
			if texture != null and masks.has(entry.get("mask")):
				_add_layer(_area_material(entry), [entry])
				if kind == "water" and _fish == null:
					_fish = MapFish.new(_canvas, masks[entry["mask"]])
					_fish.now_override = now_override
		else:
			if not spots.has(kind):
				spots[kind] = []
			(spots[kind] as Array).append(entry)
	# Rauch über der Glut, aus der er steigt.
	for kind in ["ember", "torch", "smoke", "volcano"]:
		if spots.has(kind):
			_add_layer(_spot_material(kind), spots[kind])
	if _fish != null:
		add_child(_fish)
	_outline = Control.new()
	_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var overlay := ShaderMaterial.new()
	overlay.shader = OVERLAY_SHADER
	_outline.material = overlay
	_outline.set_anchors_preset(Control.PRESET_FULL_RECT)
	_outline.draw.connect(_draw_outline)
	add_child(_outline)
	refresh()


## Wie viele Ebenen (Kinder mit Material) es gibt — für Tests.
func layer_count() -> int:
	return _layer_entries.size()


func refresh() -> void:
	for child in get_children():
		(child as CanvasItem).queue_redraw()


## Ein Klick an `local` (Koordinaten des Canvas) neben die Orte: fängt einen springenden
## Fisch, facht eine Quelle an oder lässt einen Fisch aus dem Wasser springen. True, wenn
## etwas geschah; gemeldet wird über EventBus.secret_found.
func poke(local: Vector2) -> bool:
	if _fish != null and _fish.catch_at(local):
		return true
	var i := spot_at(local)
	if i >= 0:
		stir(i)
		return true
	return _fish != null and _fish.jump_at(local)


## Die Quelle unter `local` (Index in den Einträgen), die nächste, wenn es mehrere sind; -1.
func spot_at(local: Vector2) -> int:
	var rect := MapCanvas.map_rect(_canvas.size, _canvas.aspect(), _canvas.cover)
	if rect.size.x <= 0.0:
		return -1
	var point := _canvas.view_transform().affine_inverse() * local
	var best := -1
	var best_d := INF
	for i in _entries.size():
		var entry: Dictionary = _entries[i]
		if str(entry["kind"]) in MapLayout.AREA_KINDS:
			continue
		var box := spot_rect(entry, rect)
		if not box.grow(STIR_HIT).has_point(point):
			continue
		var d := point.distance_to(rect.position + (entry["at"] as Vector2) * rect.size)
		if d < best_d:
			best = i
			best_d = d
	return best


## Facht die Quelle `i` an; läuft sie schon, beginnt sie von vorn.
func stir(i: int) -> void:
	_stirred[i] = _now()
	EventBus.secret_found.emit(str(_entries[i]["kind"]))
	refresh()


## Wie weit die Quelle `i` gerade angefacht ist (0..1, 0 = ruhig): schnell hoch, langsam
## zurück. Für den Vulkan der Verlauf des Ausbruchs.
func stir_of(i: int) -> float:
	if not _stirred.has(i):
		return 0.0
	var kind := str(_entries[i]["kind"])
	var t := (_now() - float(_stirred[i])) / float(STIR_TIME[kind])
	if t >= 1.0:
		return 0.0
	if kind == "volcano":
		return maxf(t, 0.001)
	return smoothstep(0.0, 0.12, t) * (1.0 - smoothstep(0.35, 1.0, t))


## Bewegt sich gerade etwas, das ein Klick ausgelöst hat? Räumt Fertiges ab.
func is_busy() -> bool:
	var now := _now()
	for i in _stirred.keys():
		if now - float(_stirred[i]) >= float(STIR_TIME[str(_entries[i]["kind"])]):
			_stirred.erase(i)
	return not _stirred.is_empty() or (_fish != null and _fish.is_busy())


func fish_layer() -> MapFish:
	return _fish


func _now() -> float:
	return now_override if now_override >= 0.0 else Time.get_ticks_msec() / 1000.0


func _add_layer(material_of: ShaderMaterial, entries: Array) -> void:
	var layer := Control.new()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.material = material_of
	layer.draw.connect(_draw_layer.bind(layer))
	_layer_entries[layer] = entries
	add_child(layer)


func _area_material(entry: Dictionary) -> ShaderMaterial:
	var kind := str(entry["kind"])
	var mat := ShaderMaterial.new()
	mat.shader = SHADERS[kind]
	mat.set_shader_parameter("mask", _masks[entry["mask"]])
	mat.set_shader_parameter("aspect", _canvas.aspect())
	mat.set_shader_parameter("intensity", float(entry.get("intensity", 1.0)))
	for param: Dictionary in MapLayout.PARAMS.get(kind, []):
		mat.set_shader_parameter(param["key"], float(entry.get(param["key"], param["default"])))
	if MapLayout.STYLES.has(kind):
		mat.set_shader_parameter("style", maxi(0, (MapLayout.STYLES[kind] as Array).find(entry.get("style"))))
	return mat


func _spot_material(kind: String) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SHADERS[kind]
	if kind in ["torch", "volcano"]:
		mat.set_shader_parameter("rect_aspect", SPOT_SIZE[kind].x / SPOT_SIZE[kind].y)
	return mat


func _draw_layer(layer: Control) -> void:
	var rect := MapCanvas.map_rect(_canvas.size, _canvas.aspect(), _canvas.cover)
	if rect.size.x <= 0.0:
		return
	layer.draw_set_transform_matrix(_canvas.view_transform())
	for entry: Dictionary in _layer_entries[layer]:
		var kind := str(entry["kind"])
		if kind in MapLayout.AREA_KINDS:
			layer.draw_texture_rect(_texture, rect, false)
			continue
		# Angefacht: größer und so stark wie möglich; der Vulkan liest den Ausbruch aus b.
		var stir := stir_of(_entries.find(entry))
		var grow := 1.0 + stir * float(STIR_GROW[kind])
		var strength := float(entry.get("intensity", 1.0)) / MapLayout.INTENSITY_MAX
		if kind != "volcano":
			strength = lerpf(strength, 1.0, stir)
		layer.draw_rect(spot_rect(entry, rect, grow), Color(seed_of(entry["at"]), strength,
				stir if kind == "volcano" else 0.0, 1.0))


## Das Rechteck einer Quelle auf dem Control, wenn das Bild in `rect` steht, `grow`-fach.
static func spot_rect(entry: Dictionary, rect: Rect2, grow := 1.0) -> Rect2:
	var kind := str(entry["kind"])
	var extent: Vector2 = SPOT_SIZE[kind] * float(entry.get("size", 1.0)) * grow * rect.size.y
	var at: Vector2 = rect.position + (entry["at"] as Vector2) * rect.size
	# Rauch, Flamme und Ausbruch steigen aus der Quelle auf; die Glut leuchtet um sie herum.
	var top: float = at.y - extent.y * float({"smoke": 1.0, "torch": TORCH_BASE,
			"volcano": VOLCANO_BASE}.get(kind, 0.5))
	return Rect2(Vector2(at.x - extent.x * 0.5, top), extent)


## Ein fester Versatz 0..1 je Quelle, aus ihrer Lage (übliches Shader-Hash).
static func seed_of(at: Vector2) -> float:
	return fposmod(sin(at.dot(Vector2(12.9898, 78.233))) * 43758.5453, 1.0)


func _draw_outline() -> void:
	if not show_outline:
		return
	var rect := MapCanvas.map_rect(_canvas.size, _canvas.aspect(), _canvas.cover)
	_outline.draw_set_transform_matrix(_canvas.view_transform())
	for entry: Dictionary in _entries:
		var kind := str(entry["kind"])
		if kind in MapLayout.AREA_KINDS:
			if _masks.has(entry.get("mask")):
				_outline.draw_texture_rect(_masks[entry["mask"]], rect, false, MASK_TINT[kind])
		else:
			_outline.draw_rect(spot_rect(entry, rect), OUTLINE_COLOR, false, 1.0)
			_outline.draw_circle(rect.position + (entry["at"] as Vector2) * rect.size, 4.0, OUTLINE_COLOR)
