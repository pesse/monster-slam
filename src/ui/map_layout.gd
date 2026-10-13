class_name MapLayout
extends RefCounted
## Bilder und Punkte der Karten unter assets/maps/<book>/ (ADR 0006): `book.webp`,
## `unit<n>.webp`, Masken `unit<n>_<mask>.webp` und `map.json` (Punkte in Anteilen 0..1,
## gesetzt in scenes/dev/map_lab.tscn). Aufbau von `map.json`:
##
##     { "units": { "2": {"x": 0.41, "y": 0.62}, …, "path": [{x, y}, …] },
##       "areas": { "2": { "t1": {x, y}, …, "all": {x, y}, "boss": {x, y}, "path": […] } },
##       "themes": { "2": "desert", "3": { "default": "outback", "t3": "homestead" } },
##       "ambience": { "2": [ {"kind": "water", "style": "rings"}, {"kind": "mist", "mask": "mist2"},
##                            {"kind": "smoke", "x": …, "y": …, "size": 1.0, "intensity": 1.5} ] } }
##
## Zu `ambience` siehe docs/ARCHITECTURE.md „Karte und Laufanfrage“.

const ROOT := "res://assets/maps"
## WebP zuerst: die PNGs daneben sind die Quellen und gehen nicht in den Export.
const EXTENSIONS := ["webp", "png", "jpg"]
## Bewegte Flächen der Gebietskarte, je eine Maske.
const AREA_KINDS := ["water", "falls", "mist"]
## Bewegte Quellen, je ein Punkt.
const SPOT_KINDS := ["smoke", "ember", "torch"]
## Formen je Art, die erste ist die ohne Angabe.
const STYLES := {"water": ["field", "rings"]}
## Höchste Intensität eines Effekts (1 ist normal).
const INTENSITY_MAX := 2.0
## Weitere Einstellungen je Flächen-Art: `key` ist das Uniform des Shaders, `default` sein
## Wert dort, `style` beschränkt den Regler auf eine Form. Die Werkbank baut daraus ihre Regler.
const PARAMS := {
	"water": [
		{"key": "wave_size", "label": "Wellengröße", "min": 0.4, "max": 3.0, "step": 0.05, "default": 1.0},
		{"key": "speed", "label": "Tempo", "min": 0.0, "max": 3.0, "step": 0.05, "default": 1.0},
		{"key": "direction", "label": "Richtung (°)", "min": -180.0, "max": 180.0, "step": 5.0, "default": 0.0},
		{"key": "glint", "label": "Glanz", "min": 0.0, "max": 1.0, "step": 0.05, "default": 0.3},
		{"key": "ring_rate", "label": "Ringe je Sekunde", "min": 0.05, "max": 1.5, "step": 0.05,
				"default": 0.35, "style": "rings"},
		{"key": "ring_size", "label": "Ringgröße", "min": 0.4, "max": 3.0, "step": 0.05,
				"default": 1.0, "style": "rings"},
	],
	"falls": [
		{"key": "speed", "label": "Tempo", "min": 0.0, "max": 3.0, "step": 0.05, "default": 1.0},
		{"key": "foam", "label": "Gischt", "min": 0.0, "max": 1.0, "step": 0.05, "default": 0.5},
	],
	"mist": [
		{"key": "density", "label": "Dichte der Schwaden", "min": 0.0, "max": 1.0, "step": 0.05, "default": 0.85},
		{"key": "haze", "label": "Schleier", "min": 0.0, "max": 1.0, "step": 0.05, "default": 0.22},
		{"key": "puff_size", "label": "Schwadengröße", "min": 0.3, "max": 3.0, "step": 0.05, "default": 1.0},
		{"key": "speed", "label": "Zug", "min": 0.0, "max": 4.0, "step": 0.05, "default": 1.0},
		{"key": "direction", "label": "Richtung (°)", "min": -180.0, "max": 180.0, "step": 5.0, "default": 14.0},
	],
}
## Breite einer Maske (px); die Höhe folgt dem Seitenverhältnis des Bildes.
const MASK_WIDTH := 1024

## Geladene Bilder, über den Szenenwechsel hinaus gehalten: Godots Ressourcen-Cache vergisst
## ein Bild, sobald niemand es mehr hält.
static var _cache := {}
## Pfade, die im Hintergrund laden (ResourceLoader.load_threaded_request).
static var _pending := {}


static func dir_of(book: String) -> String:
	return "%s/%s" % [ROOT, book]


static func json_path(book: String) -> String:
	return "%s/map.json" % dir_of(book)


static func data(book: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(json_path(book))
	if text.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}


## Schreibt map.json — nur aus der Werkbank im Editor-Lauf, im Export ist res:// read-only.
static func save(book: String, content: Dictionary) -> Error:
	DirAccess.make_dir_recursive_absolute(dir_of(book))
	var file := FileAccess.open(json_path(book), FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(content, "\t", false) + "\n")
	file.close()
	return OK


## Das Bild `name` (ohne Endung) eines Buchs, oder null.
static func texture(book: String, name: String) -> Texture2D:
	var path := texture_path(book, name)
	if path.is_empty():
		return null
	if not _cache.has(path):
		# Läuft das Bild schon im Hintergrund, wartet `load_threaded_get` nur den Rest ab.
		var loaded: Resource = ResourceLoader.load_threaded_get(path) if _pending.has(path) else load(path)
		_pending.erase(path)
		_cache[path] = loaded as Texture2D
	return _cache[path]


## Der Pfad des Bildes `name`, oder "" ohne Bild.
static func texture_path(book: String, name: String) -> String:
	for ext in EXTENSIONS:
		var path := "%s/%s.%s" % [dir_of(book), name, ext]
		if ResourceLoader.exists(path):
			return path
	return ""


## Stößt das Laden der Gebietskarten im Hintergrund an; `texture` holt sie später ab.
static func preload_unit_textures(book: String, units: Array) -> void:
	for unit in units:
		var path := texture_path(book, "unit%d" % int(unit))
		if path.is_empty() or _cache.has(path) or _pending.has(path):
			continue
		if ResourceLoader.load_threaded_request(path) == OK:
			_pending[path] = true


static func book_texture(book: String) -> Texture2D:
	return texture(book, "book")


static func unit_texture(book: String, unit: int) -> Texture2D:
	return texture(book, "unit%d" % unit)


## {x, y} -> Vector2, oder Vector2.INF, wenn es kein Punkt ist.
static func point(value: Variant) -> Vector2:
	if not value is Dictionary or not (value as Dictionary).has("x") or not (value as Dictionary).has("y"):
		return Vector2.INF
	return Vector2(float(value["x"]), float(value["y"]))


static func to_json_point(at: Vector2) -> Dictionary:
	return {"x": snappedf(at.x, 0.001), "y": snappedf(at.y, 0.001)}


## Die Punkte der Units auf der Buchkarte: "<unit>" -> Vector2.
static func unit_points(content: Dictionary) -> Dictionary:
	return _points_of(_units(content))


## Wegpunkte der Buchkarte, oder [] — dann verbindet der Weg die Units direkt.
static func book_path(content: Dictionary) -> Array:
	return _path_of(_units(content))


## Die Punkte der Level einer Unit: "t1" … "boss" -> Vector2.
static func area_points(content: Dictionary, unit: int) -> Dictionary:
	return _points_of(_area(content, unit))


## Die höchste Teilnummer, für die die Gebietskarte einen Punkt hat („t6“ -> 6), 0 ohne.
static func area_parts(content: Dictionary, unit: int) -> int:
	var highest := 0
	for key in _points_of(_area(content, unit)):
		var name := str(key)
		if name.begins_with("t") and name.substr(1).is_valid_int():
			highest = maxi(highest, int(name.substr(1)))
	return highest


## Wegpunkte der Gebietskarte, oder [] — dann verbindet der Weg die Level direkt.
static func area_path(content: Dictionary, unit: int) -> Array:
	return _path_of(_area(content, unit))


## Was sich auf der Gebietskarte einer Unit bewegt: { kind, mask, intensity, style } und die
## Werte aus `PARAMS` für eine Fläche, { kind, at: Vector2, size, intensity } für eine Quelle.
## Was nicht passt, fällt weg; von zwei Flächen mit derselben Maske gilt die erste.
static func ambience(content: Dictionary, unit: int) -> Array:
	var all: Variant = content.get("ambience", {})
	if not all is Dictionary:
		return []
	var raw: Variant = (all as Dictionary).get(str(unit), [])
	var out: Array = []
	if not raw is Array:
		return out
	var areas := {}
	for entry in raw:
		var parsed := ambience_entry(entry)
		if parsed.is_empty() or areas.has(parsed.get("mask")):
			continue
		if parsed.has("mask"):
			areas[parsed["mask"]] = true
		out.append(parsed)
	return out


## Ein Eintrag aus `ambience`, gelesen; {} wenn er nicht taugt.
static func ambience_entry(entry: Variant) -> Dictionary:
	if not entry is Dictionary:
		return {}
	var kind := str((entry as Dictionary).get("kind", ""))
	var intensity := clampf(float(entry.get("intensity", 1.0)), 0.0, INTENSITY_MAX)
	if kind in AREA_KINDS:
		var styles: Array = STYLES.get(kind, [""])
		var style := str(entry.get("style", styles[0]))
		var mask := str(entry.get("mask", kind))
		if not is_mask_of(mask, kind):
			return {}
		var out := {"kind": kind, "mask": mask, "intensity": intensity,
				"style": style if style in styles else styles[0]}
		for param: Dictionary in PARAMS.get(kind, []):
			out[param["key"]] = clampf(float(entry.get(param["key"], param["default"])),
					param["min"], param["max"])
		return out
	if kind in SPOT_KINDS:
		var at := point(entry)
		if not _inside(at):
			return {}
		return {"kind": kind, "at": at, "size": clampf(float(entry.get("size", 1.0)), 0.2, 4.0),
				"intensity": intensity}
	return {}


## Ob `mask` ein Name für eine Maske der Art `kind` ist: die Art selbst oder mit Nummer.
static func is_mask_of(mask: String, kind: String) -> bool:
	return mask == kind or (mask.begins_with(kind) and mask.trim_prefix(kind).is_valid_int()
			and int(mask.trim_prefix(kind)) >= 2)


## Die Datei einer Maske, wie für `texture` (ohne Endung).
static func mask_name(unit: int, mask: String) -> String:
	return "unit%d_%s" % [unit, mask]


static func mask_path(book: String, unit: int, mask: String) -> String:
	return "%s/%s.webp" % [dir_of(book), mask_name(unit, mask)]


## Die Masken der Flächen in `entries` (aus `ambience`): mask -> Texture2D, nur die es gibt.
static func ambience_masks(book: String, unit: int, entries: Array) -> Dictionary:
	var out := {}
	for entry: Dictionary in entries:
		if entry.has("mask"):
			var mask := texture(book, mask_name(unit, entry["mask"]))
			if mask != null:
				out[entry["mask"]] = mask
	return out


static func _inside(at: Vector2) -> bool:
	return at.is_finite() and at.x >= 0.0 and at.y >= 0.0 and at.x <= 1.0 and at.y <= 1.0


## Alle Punkte eines Abschnitts außer dem Weg: key -> Vector2.
static func _points_of(section: Dictionary) -> Dictionary:
	var out := {}
	for key in section:
		if key == "path":
			continue
		var at := point(section[key])
		if at != Vector2.INF:
			out[str(key)] = at
	return out


static func _path_of(section: Dictionary) -> Array:
	var out: Array = []
	var raw: Variant = section.get("path", [])
	if raw is Array:
		for value in raw:
			var at := point(value)
			if at != Vector2.INF:
				out.append(at)
	return out


static func _units(content: Dictionary) -> Dictionary:
	var units: Variant = content.get("units", {})
	return units if units is Dictionary else {}


static func _area(content: Dictionary, unit: int) -> Dictionary:
	var areas: Variant = content.get("areas", {})
	if not areas is Dictionary:
		return {}
	var area: Variant = (areas as Dictionary).get(str(unit), {})
	return area if area is Dictionary else {}
