class_name MapAmbience
extends Control
## Was sich auf einer Gebietskarte bewegt: Wasser kräuselt sich, Wasserfälle laufen, Nebel
## zieht, aus Glut steigt Rauch (map.json `ambience`, MapLayout.ambience).
##
## Eine Ebene von MapCanvas zwischen Bild und Orten: sie liegt wie das Bild hinter der
## Zeichnung der Karte (`show_behind_parent`), Weg und Orte stehen darüber. Bewegt wird nur
## im Shader (TIME) — die Ebene zeichnet sich neu, wenn die Karte es tut (Größe, Zoom), und
## braucht kein `_process`.
##
## Je Fläche ein eigenes Kind mit eigenem Material, denn ihre Maske steht als Uniform darin
## (map_ambience.gdshaderinc); gezeichnet wird das ganze Kartenbild, der Shader verwirft,
## was die Maske nicht trifft. Die Quellen einer Art teilen ein Kind und ein Material;
## Versatz und Stärke jeder Quelle reisen in der Farbe ihres Rechtecks mit (r, g).

const SHADERS := {
	"water": preload("res://assets/shaders/map_water.gdshader"),
	"falls": preload("res://assets/shaders/map_falls.gdshader"),
	"mist": preload("res://assets/shaders/map_mist.gdshader"),
	"smoke": preload("res://assets/shaders/map_smoke.gdshader"),
	"ember": preload("res://assets/shaders/map_ember.gdshader"),
	"torch": preload("res://assets/shaders/map_torch.gdshader"),
}
const OVERLAY_SHADER := preload("res://assets/shaders/map_mask_overlay.gdshader")
## Größe einer Quelle bei `size` 1, in Bildhöhen (Breite, Höhe). Rauch steht auf der
## Quelle, die Glut sitzt mittig darauf, die Flamme der Fackel steigt aus ihr auf
## (TORCH_BASE: wo die Quelle im Rechteck liegt, von oben; wie BASE in map_torch.gdshader).
const SPOT_SIZE := {"smoke": Vector2(0.07, 0.2), "ember": Vector2(0.05, 0.05),
		"torch": Vector2(0.03, 0.06)}
const TORCH_BASE := 0.8
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
## Je Kind die Einträge, die es zeichnet.
var _layer_entries: Dictionary = {}
var _outline: Control


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
	var spots := {}
	for entry: Dictionary in entries:
		var kind := str(entry["kind"])
		if kind in MapLayout.AREA_KINDS:
			if texture != null and masks.has(entry.get("mask")):
				_add_layer(_area_material(entry), [entry])
		else:
			if not spots.has(kind):
				spots[kind] = []
			(spots[kind] as Array).append(entry)
	# Rauch über der Glut, aus der er steigt.
	for kind in ["ember", "torch", "smoke"]:
		if spots.has(kind):
			_add_layer(_spot_material(kind), spots[kind])
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
	if kind == "torch":
		mat.set_shader_parameter("rect_aspect", SPOT_SIZE[kind].x / SPOT_SIZE[kind].y)
	return mat


func _draw_layer(layer: Control) -> void:
	var rect := MapCanvas.map_rect(_canvas.size, _canvas.aspect(), _canvas.cover)
	if rect.size.x <= 0.0:
		return
	layer.draw_set_transform_matrix(_canvas.view_transform())
	for entry: Dictionary in _layer_entries[layer]:
		if str(entry["kind"]) in MapLayout.AREA_KINDS:
			layer.draw_texture_rect(_texture, rect, false)
		else:
			layer.draw_rect(spot_rect(entry, rect), Color(seed_of(entry["at"]),
					float(entry.get("intensity", 1.0)) / MapLayout.INTENSITY_MAX, 0.0, 1.0))


## Das Rechteck einer Quelle auf dem Control, wenn das Bild in `rect` steht.
static func spot_rect(entry: Dictionary, rect: Rect2) -> Rect2:
	var kind := str(entry["kind"])
	var extent: Vector2 = SPOT_SIZE[kind] * float(entry.get("size", 1.0)) * rect.size.y
	var at: Vector2 = rect.position + (entry["at"] as Vector2) * rect.size
	# Rauch und Flamme steigen aus der Quelle auf; die Glut leuchtet um sie herum.
	var top: float = at.y - extent.y * float({"smoke": 1.0, "torch": TORCH_BASE}.get(kind, 0.5))
	return Rect2(Vector2(at.x - extent.x * 0.5, top), extent)


## Ein fester Versatz 0..1 je Quelle, aus ihrer Lage: jede flackert und zieht anders.
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
