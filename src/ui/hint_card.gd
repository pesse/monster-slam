class_name HintCard
extends PanelContainer
## Die Karte am Zeiger, geführt vom Autoload `Hints`. Was leer ist, steht nicht da. Rahmen
## und Pfeil (assets/ui/tooltip/) sind nur die Goldkontur; die Füllung (Theme-Farbe `fill`)
## zeichnet die Karte selbst, `panel` trägt nur den Innenabstand.

## Breite der Karte (px): so breit wie ihr Text, in diesen Grenzen.
const MAX_WIDTH := 320.0
const MIN_WIDTH := 140.0

## Gezeichnete Größe des Pfeils (px), seine Textur auf fünf Achtel.
const POINTER_SIZE := Vector2(40, 22)
## So weit reicht der Fuß des Pfeils in die Karte hinein (px).
const POINTER_INSET := 8.0
## Mindestabstand des Pfeils zu einer Ecke (px).
const POINTER_MARGIN := 24.0
## Die Goldlinie in `frame.webp` (px, an der Textur gemessen): Mitte der Linie und
## Eckenabschrägung. Die Füllung folgt der Mitte, dort deckt das Gold ihre Kante.
const FRAME_LINE := 1.0
const FRAME_CHAMFER := 11.0
## Pfeil, Mitte der Schenkel: Spitze und Enden in Texturpixeln von `pointer_up`
## (`pointer_down` gespiegelt).
const POINTER_TEXTURE := Vector2(64, 36)
const POINTER_APEX := Vector2(31.5, 3.5)
const POINTER_ARM_LEFT := Vector2(4.0, 27.5)
const POINTER_ARM_RIGHT := Vector2(59.0, 27.5)
## Kantenlänge eines Bild-Zeichens in der Liste (px).
const LIST_ICON := 20.0
## Ein Preis im Kopf: Zeichen und Zahl (`fill`, `prices`).
const PRICE_SCENE := preload("res://scenes/ui/hint_price.tscn")

@onready var _title: Label = %Title
@onready var _body: Label = %Body
@onready var _note: Label = %Note
@onready var _list: GridContainer = %List
@onready var _image: TextureRect = %Image
@onready var _icon: TextureRect = %Icon
@onready var _subtitle: Label = %Subtitle
@onready var _rule: HSeparator = %Rule
@onready var _prices: HBoxContainer = %Prices

## Wo der Pfeil sitzt: waagerecht in Kartenkoordinaten, und ob oben (Karte unter dem
## Zeiger) oder unten (Karte darüber). NaN heißt: kein Pfeil.
var _pointer_x := NAN
var _pointer_up := true


## Trägt die Teile ein und stellt die Karte auf die Breite ihres Texts ein. Nur an einer
## eingehängten Karte aufrufen, sonst misst `_fit()` einen alten Stand.
## `list`: Zeilen `[zeichen, bezeichnung, wert]`; das Zeichen darf leer oder ein Bild sein.
## Ein Bild macht die Karte MAX_WIDTH breit. `subtitle` wird über `self_modulate` in `tint`
## gefärbt (Farbe aus Daten). `prices`: rechts im Kopf, je `[zeichen, zahl]`.
func fill(title: String, body := "", note := "", list := [], image: Texture2D = null,
		icon: Texture2D = null, subtitle := "", tint := Color.WHITE, prices := []) -> void:
	_title.text = title
	_title.visible = not title.is_empty()
	_body.text = body
	_body.visible = not body.is_empty()
	_note.text = note
	_note.visible = not note.is_empty()
	_image.texture = image
	_image.visible = image != null
	_icon.texture = icon
	_icon.visible = icon != null
	_subtitle.text = subtitle
	_subtitle.visible = not subtitle.is_empty()
	_subtitle.self_modulate = tint
	_rule.visible = not subtitle.is_empty()
	_fill_list(list)
	_fill_prices(prices)
	_fit()


func _fill_prices(prices: Array) -> void:
	for child in _prices.get_children():
		_prices.remove_child(child)
		child.queue_free()
	for price in prices:
		var item := PRICE_SCENE.instantiate() as HBoxContainer
		(item.get_node("Mark") as TextureRect).texture = price[0] as Texture2D
		(item.get_node("Value") as Label).text = str(price[1])
		_prices.add_child(item)
	_prices.visible = not prices.is_empty()


## Baut die Zellen neu; `remove_child` vor `queue_free`, sonst misst `_fit()` sie noch mit.
func _fill_list(list: Array) -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	for row in list:
		for i in 3:
			# Ein Bild-Zeichen in fester Größe, damit die Bezeichnungen fluchten.
			if i == 0 and i < row.size() and row[i] is Texture2D:
				var mark := TextureRect.new()
				mark.texture = row[i]
				mark.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
				mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				mark.custom_minimum_size = Vector2.ONE * LIST_ICON
				mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
				_list.add_child(mark)
				continue
			var cell := Label.new()
			cell.theme_type_variation = &"Hint"
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.text = str(row[i]) if i < row.size() else ""
			if i == 2:
				cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			_list.add_child(cell)
	_list.visible = not list.is_empty()


func _list_names() -> Array:
	var names := []
	var cells := _list.get_children()
	for i in range(1, cells.size(), 3):
		names.append(cells[i])
	return names


func _list_values() -> Array:
	var values := []
	var cells := _list.get_children()
	for i in range(2, cells.size(), 3):
		values.append(cells[i])
	return values


## Breite der Zeichen-Spalte samt der zwei Abstände.
func _list_mark_width() -> float:
	var cells := _list.get_children()
	var mark := 0.0
	for i in range(0, cells.size(), 3):
		mark = maxf(mark, (cells[i] as Control).get_combined_minimum_size().x)
	return mark + 2.0 * _list.get_theme_constant("h_separation")


func _list_value_width() -> float:
	return _widest(_list_values())


func _list_name_width() -> float:
	return _widest(_list_names())


func _widest(labels: Array) -> float:
	var widest := 0.0
	for label: Label in labels:
		widest = maxf(widest, label.get_combined_minimum_size().x)
	return widest


## Die Breitenregel, in dieser Reihenfolge. Zum Messen wird der Umbruch abgeschaltet
## (umbrechende Labels: CONVENTIONS „Fallen“).
func _fit() -> void:
	var labels := [_title, _subtitle, _body, _note]
	var names := _list_names()
	var values := _list_values()
	# 1. Ohne Umbruch messen, die Breite des vorigen Aufrufs vorher weg.
	for label: Label in labels + names + values:
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.custom_minimum_size.x = 0.0
	_image.custom_minimum_size = Vector2.ZERO
	var outer := clampf(get_combined_minimum_size().x, MIN_WIDTH, MAX_WIDTH)
	if _image.visible:
		outer = MAX_WIDTH
	var inner := outer - get_theme_stylebox("panel").get_minimum_size().x
	if _image.visible:
		var picture := _image.texture.get_size()
		_image.custom_minimum_size = Vector2(inner, inner * picture.y / maxf(picture.x, 1.0))
	# 2. Umbruch an und die Breite setzen: `size.x` löst den Umbruch aus,
	#    `custom_minimum_size.x` hält ihn beim nächsten Sortieren; beides nötig.
	# Überschrift und Unterzeile teilen sich die Breite mit dem Zeichen davor.
	var head := inner
	if _icon.visible:
		head -= _icon.custom_minimum_size.x \
				+ float((_icon.get_parent() as BoxContainer).get_theme_constant("separation"))
	for label: Label in labels:
		var width := head if label == _title or label == _subtitle else inner
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = width
		label.size.x = width
	# Die Bezeichnungen bekommen, was neben Zeichen und Werten übrig bleibt. Passt nicht
	# alles ungebrochen, nehmen die Werte höchstens die Hälfte und brechen selbst um.
	var mark_width := _list_mark_width()
	var value_width := _list_value_width()
	if mark_width + _list_name_width() + value_width > inner:
		value_width = minf(value_width, maxf(0.0, inner / 2.0 - mark_width))
	if value_width < _list_value_width():
		for label: Label in values:
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.custom_minimum_size.x = value_width
			label.size.x = value_width
	var name_width := maxf(0.0, inner - mark_width - value_width)
	for label: Label in names:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = name_width
		label.size.x = name_width
	# 3. Den Umbruch erzwingen: `get_minimum_size()` liefert den Stand der letzten
	#    Umbruchrechnung, `get_line_count()` bricht sofort um.
	for label: Label in labels + names + values:
		label.get_line_count()
	# 4. Erst jetzt ist die Höhe für diese Breite gerechnet.
	size = Vector2(outer, get_combined_minimum_size().y)
	queue_redraw()


# --- Rahmen und Pfeil ---------------------------------------------------------

## Setzt den Pfeil: `x` waagerecht in Kartenkoordinaten, `up` oben (die Karte hängt unter
## dem Zeiger) oder unten (sie steht darüber). Die Spitze liegt `pointer_reach()` vor der
## Kante. Nicht näher als `POINTER_MARGIN` an eine Ecke.
func point_at(x: float, up: bool) -> void:
	_pointer_x = clampf(x, POINTER_MARGIN, maxf(POINTER_MARGIN, size.x - POINTER_MARGIN))
	_pointer_up = up
	queue_redraw()


## Wie weit die Spitze des Pfeils über die Kante der Karte hinausragt.
static func pointer_reach() -> float:
	return POINTER_SIZE.y - POINTER_INSET


## Wo die Spitze gerade liegt (Kartenkoordinaten), NaN ohne Pfeil.
func pointer_tip() -> Vector2:
	if is_nan(_pointer_x):
		return Vector2(NAN, NAN)
	return Vector2(_pointer_x, -pointer_reach() if _pointer_up else size.y + pointer_reach())


## Die Füllung unter dem Pfeil deckt die Randlinie zwischen seinen Schenkeln.
func _draw() -> void:
	var color := get_theme_color("fill")
	draw_colored_polygon(fill_outline(size), color)
	draw_style_box(get_theme_stylebox("frame"), Rect2(Vector2.ZERO, size))
	if is_nan(_pointer_x):
		return
	draw_colored_polygon(pointer_outline(), color)
	var texture := get_theme_icon("pointer_up" if _pointer_up else "pointer_down")
	var top := pointer_tip().y if _pointer_up else size.y - POINTER_INSET
	draw_texture_rect(texture, Rect2(Vector2(_pointer_x - POINTER_SIZE.x * 0.5, top),
			POINTER_SIZE), false)


## Die Fläche ohne Pfeil: Rechteck mit abgeschrägten Ecken auf der Mitte der Goldlinie.
static func fill_outline(card: Vector2) -> PackedVector2Array:
	var a := FRAME_LINE
	var c := FRAME_CHAMFER
	return PackedVector2Array([
		Vector2(a + c, a), Vector2(card.x - a - c, a), Vector2(card.x - a, a + c),
		Vector2(card.x - a, card.y - a - c), Vector2(card.x - a - c, card.y - a),
		Vector2(a + c, card.y - a), Vector2(a, card.y - a - c), Vector2(a, a + c),
	])


## Die Fläche unter dem Pfeil (Kartenkoordinaten): Dreieck auf der Mitte der Goldlinie.
func pointer_outline() -> PackedVector2Array:
	var scale := POINTER_SIZE / POINTER_TEXTURE
	var origin := Vector2(_pointer_x - POINTER_SIZE.x * 0.5, pointer_tip().y)
	var out := PackedVector2Array()
	for point in [POINTER_ARM_LEFT, POINTER_APEX, POINTER_ARM_RIGHT]:
		var p: Vector2 = point * scale
		if not _pointer_up:
			origin = Vector2(origin.x, size.y - POINTER_INSET)
			p.y = POINTER_SIZE.y - p.y
		out.append(origin + p)
	return out
