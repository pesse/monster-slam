class_name MapLayout
extends RefCounted
## Bilder und Punkte der Karten (docs/adr/0006-buchzentrierte-karte.md).
##
## Je Buch ein Verzeichnis unter assets/maps/<book>/:
##
##     book.webp         die Buchkarte — die Units sind ihre Gebiete
##     unit<n>.webp      die Gebietskarte einer Unit — dort liegen ihre Level
##     map.json          wo die Punkte liegen, in Anteilen des Bildes (0..1)
##
## Das Seitenverhältnis gibt das Bild vor (MapCanvas), gedacht ist 16:9.
##
##     { "units": { "2": {"x": 0.41, "y": 0.62}, …, "path": [{x, y}, …] },
##       "areas": { "2": { "t1": {x, y}, …, "all": {x, y}, "boss": {x, y},
##                         "path": [{x, y}, …] } } }
##
## Die Dateien liegen im Export und nicht im Pack: Bild und Punkte gehören zusammen, und
## ein Pack trägt nur JSON. Eine Unit, die ein Content-Update bringt, bevor es ihr Bild
## gibt, bleibt trotzdem spielbar — MapCanvas legt die Punkte dann selbst aus.
##
## Punkte setzt man in der Werkbank scenes/dev/map_lab.tscn, nicht von Hand.

const ROOT := "res://assets/maps"
## WebP zuerst: die PNGs daneben sind die Quellen, aus denen export_webp.py die Bilder macht.
const EXTENSIONS := ["webp", "png", "jpg"]

## Geladene Bilder, über den Szenenwechsel hinaus gehalten: der Ressourcen-Cache von Godot
## vergisst ein Bild, sobald niemand es mehr hält — und der Zoom von der Buch- in die
## Gebietskarte wechselt die Szene.
static var _cache := {}
## Pfade, die im Hintergrund laden (ResourceLoader.load_threaded_request).
static var _pending := {}


static func dir_of(book: String) -> String:
	return "%s/%s" % [ROOT, book]


static func json_path(book: String) -> String:
	return "%s/map.json" % dir_of(book)


## Der Inhalt von map.json, oder {} ohne Datei.
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


## Wegpunkte der Gebietskarte, oder [] — dann verbindet der Weg die Level direkt.
static func area_path(content: Dictionary, unit: int) -> Array:
	return _path_of(_area(content, unit))


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
