class_name BookMap
extends Control
## Buchkarte: die Units eines Buchs als Gebiete auf seiner Landkarte (ADR 0006).
##
## Jeder Ort zeigt die Stufe der Unit (Füllung), den Weg zur nächsten (Ring) und die
## Medaille ihres Bosses. Ein Klick öffnet die Gebietskarte der Unit. Nichts ist
## gesperrt — die Reihenfolge legt nur der Weg auf der Karte nahe.
##
## Das Layout liegt in book_map.tscn, das Bild und die Punkte unter assets/maps/<book>/
## (MapLayout); gezeichnet wird in MapCanvas. Die Zahlen kommen aus FortressTier.unit_tiers
## — derselben Zählung wie Kampf und Statistik.

@onready var _canvas: MapCanvas = %Canvas
@onready var _title: Label = %Title
@onready var _empty_hint: Label = %EmptyHint


func _ready() -> void:
	(%BackButton as Button).pressed.connect(_back_to_shelf)
	_canvas.node_selected.connect(_on_unit_selected)
	_canvas.cover = true
	var books := ContentRegistry.all_books()
	if not MapSelection.book in books and not books.is_empty():
		MapSelection.book = books[0]
	_title.text = ContentRegistry.book_label(MapSelection.book)
	_canvas.setup(MapLayout.book_texture(MapSelection.book), [], [], func(_n): return {})
	# Aus einer Gebietskarte zurück: die Buchkarte kommt aus dieser Unit heraus — erst der
	# Zoom über das Bild, dann die Rechnung und die Orte, wie auf dem Weg hinein.
	if MapSelection.zoom_out:
		MapSelection.zoom_out = false
		var at: Vector2 = MapLayout.unit_points(MapLayout.data(MapSelection.book)) \
				.get(str(MapSelection.unit), Vector2.INF)
		_canvas.zoom_back_to(at)
		await _canvas.zoom_finished
	_fill()
	_canvas.appear()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_back_to_shelf()


## Zurück ins Regal: die Buchauswahl fliegt aus dem offenen Buch heraus und schlägt es zu.
func _back_to_shelf() -> void:
	MapSelection.to_shelf = true
	get_tree().change_scene_to_file(MapSelection.BOOKS_SCENE)


func _fill() -> void:
	var book := MapSelection.book
	var book_name := ContentRegistry.book_label(book)
	var tiers := FortressTier.unit_tiers(ContentRegistry.lexemes.values(),
			PlayerProgress.mastered_lexemes())
	var units: Array = book_units(tiers).get(book, [])
	_empty_hint.visible = units.is_empty()
	var layout := MapLayout.data(book)
	var nodes := nodes_for(book, units, MapLayout.unit_points(layout),
			BossRecord.wins(UserSettings.active_profile()))
	# Die Gebietskarten schon jetzt im Hintergrund laden, auch die gesperrter Units: die
	# Hinweiskarte zeigt sie als Vorschau, und der Zoom hinein soll nicht auf das Bild warten.
	MapLayout.preload_unit_textures(book, nodes.map(func(n): return int(n["unit"])))
	_canvas.setup(MapLayout.book_texture(book), nodes, MapLayout.book_path(layout),
			hint_lines.bind(book_name))


## Ordnet den Stand aus FortressTier.unit_tiers nach Büchern: book -> Units nach Nummer,
## je { key, unit, done, total, tier }. Statisch, damit die Reihenfolge prüfbar bleibt.
static func book_units(tiers: Dictionary) -> Dictionary:
	var out := {}
	for key in tiers:
		var group: Dictionary = tiers[key]
		var book := str(group["book"])
		if not out.has(book):
			out[book] = []
		out[book].append({
			"key": str(key), "unit": int(group["unit"]),
			"done": int(group["done"]), "total": int(group["total"]),
			"tier": int(group["tier"]),
		})
	for book in out:
		(out[book] as Array).sort_custom(func(a, b): return int(a["unit"]) < int(b["unit"]))
	return out


## Die Orte der Buchkarte: je Unit einer, mit Punkt aus map.json (oder INF) und der
## Medaille ihres Bosses. Eine Unit, die die Karte schon hat, der Inhalt aber noch nicht,
## steht grau und gesperrt da: man sieht, dass das Buch weitergeht.
static func nodes_for(book: String, units: Array, points: Dictionary, wins: Dictionary) -> Array:
	var out: Array = []
	var present := {}
	for unit in units:
		present[str(int(unit["unit"]))] = true
	for unit in units:
		var number := int(unit["unit"])
		var won := int(wins.get(str(unit["key"]), 0))
		out.append({
			"key": str(unit["key"]), "unit": number,
			"pos": points.get(str(number), Vector2.INF),
			"glyph": str(number), "caption": "Unit %d" % number,
			"tier": int(unit["tier"]), "done": int(unit["done"]), "total": int(unit["total"]),
			"wins": won, "medal": BossRecord.medal(won),
		})
	for number in points:
		if present.has(str(number)) or not str(number).is_valid_int():
			continue
		out.append({
			"key": "%s/%s" % [book, number], "unit": int(number), "pos": points[number],
			"glyph": str(number), "caption": "Unit %s" % number,
			"tier": 0, "done": 0, "total": 0, "disabled": true, "missing": true, "stars": false,
		})
	out.sort_custom(func(a, b): return int(a["unit"]) < int(b["unit"]))
	return out


## Die Karte am Zeiger für eine Unit: ihr Stand, wie oft ihr Boss besiegt ist, und ein
## Blick auf ihre Gebietskarte. Die Festungsstufe steht erst im Kopf der Gebietskarte.
static func hint_lines(unit: Dictionary, book_name: String) -> Dictionary:
	var book := str(unit.get("key", "")).get_slice("/", 0)
	var body := "%d von %d Wörtern gemeistert" % [int(unit["done"]), int(unit["total"])]
	if bool(unit.get("missing", false)):
		# Gesperrt, aber zu sehen: das Gebiet zeigt schon, wohin das Buch führt.
		body = "Für diese Unit gibt es noch keine Wörter."
	var wins := int(unit.get("wins", 0))
	if wins > 0:
		body += "\n👑 Boss %d× besiegt" % wins
	return {
		"title": "%s, Unit %d" % [book_name, int(unit["unit"])],
		"image": MapLayout.unit_texture(book, int(unit["unit"])) if not book.is_empty() else null,
		"body": body,
	}


func _on_unit_selected(key: String) -> void:
	if _canvas.is_zooming():
		return
	MapSelection.book = key.get_slice("/", 0)
	MapSelection.unit = int(key.get_slice("/", 1))
	# Hinein ins Gebiet: die Buchkarte fährt auf die Unit zu, die Gebietskarte setzt fort.
	_canvas.zoom_into(key)
	await _canvas.zoom_finished
	MapSelection.zoom_in = true
	get_tree().change_scene_to_file(MapSelection.AREA_SCENE)
