class_name HintCard
extends PanelContainer
## Die Karte am Zeiger — im ganzen Spiel dieselbe.
##
## Sie kennt vier Teile und sonst nichts: Überschrift, Text, Liste, Nachsatz — dazu
## höchstens ein Bild unter der Überschrift (die Vorschau einer Gebietskarte), ein kleines
## Zeichen vor ihr und eine farbige Unterzeile (Zweig und Zustand eines Fähigkeitsknotens).
## Was leer ist, steht nicht da. Die Liste ist eine echte Tabelle (Zeichen | Bezeichnung | Wert) und
## kein Text mit „·" dazwischen: eine Aufzählung liest man Zeile für Zeile, und die Werte
## sollen untereinander stehen, damit man sie vergleichen kann. Sie weiß nicht, ob sie einen Fähigkeitsknoten, eine Wortzeile oder eine
## Schatzkiste erklärt — das ist genau der Grund, aus dem es sie nur einmal gibt. Was in
## ihr steht, entscheidet die Stelle, die sie anmeldet (`Hints.attach`); Regeln wie
## `SkillTree.state_label` bleiben dort, wo sie hingehören.
##
## Gehalten wird sie vom Autoload `Hints`, das sie über allem einblendet und dem Zeiger
## nachführt. Godots eigener Tooltip erscheint verzögert, bleibt stehen, wo er aufgegangen
## ist, und bringt die Typografie der Engine mit — diese Karte erscheint sofort, folgt dem
## Zeiger und kommt aus dem Theme.
##
## Aussehen (assets/ui/skill_tree/tooltip/): eine deckende Füllung (`panel`), darüber der
## Rahmen (`frame`, ein eigener Theme-Eintrag von `HintCard`) und ein Pfeil, der auf den
## Mauszeiger zeigt. Wo er sitzt, entscheidet `Hints` (`point_at`) — die Karte weiß nicht,
## wo die Maus ist.

## So breit wie ihr Text, höchstens so breit: gut ein Viertel der Grundauflösung (1152).
## Darüber wird aus einer Auskunft am Zeiger ein Absatz quer über das Bild.
const MAX_WIDTH := 320.0
## Und mindestens so breit: „Umlernen" allein wäre sonst ein Stummel, und beim Streichen
## über ein Netz zappelte die Karte bei jedem Knoten auf eine andere Breite.
const MIN_WIDTH := 140.0

## Größe, in der der Pfeil gezeichnet wird: seine Textur (64 × 36) auf fünf Achtel — in
## voller Größe wäre er bei einer Karte von 140 px Breite ein Dach über der halben Karte.
const POINTER_SIZE := Vector2(40, 22)
## So weit reicht der Fuß des Pfeils in die Karte hinein. Er deckt dort die Randlinie des
## Rahmens ab, sonst liefe sie quer unter dem Pfeil durch.
const POINTER_INSET := 8.0
## Näher als so an eine Ecke kommt der Pfeil nicht: die Ecken des Rahmens sind abgeschrägt.
const POINTER_MARGIN := 24.0
## Kantenlänge eines Zeichens in der Liste, wenn es ein Bild ist.
const LIST_ICON := 20.0

@onready var _title: Label = %Title
@onready var _body: Label = %Body
@onready var _note: Label = %Note
@onready var _list: GridContainer = %List
@onready var _image: TextureRect = %Image
@onready var _icon: TextureRect = %Icon
@onready var _subtitle: Label = %Subtitle
@onready var _rule: HSeparator = %Rule

## Wo der Pfeil sitzt: waagerecht in Kartenkoordinaten, und ob oben (Karte unter dem
## Zeiger) oder unten (Karte darüber). NaN heißt: kein Pfeil.
var _pointer_x := NAN
var _pointer_up := true


## Trägt die vier Teile ein und stellt die Karte auf die Breite ein, die ihr Text braucht.
##
## Nur an einer EINGEHÄNGTEN Karte aufrufen: `update_minimum_size()` steigt ohne Baum aus,
## und dann misst `_fit()` einen alten Stand. `Hints` hängt sie beim Start ein, also immer
## erfüllt — deshalb gibt es hier kein Merken-und-später-eintragen mehr.
##
## `list` ist ein Array von Zeilen, jede `[zeichen, bezeichnung, wert]`; ein leeres Zeichen
## lässt die Spalte in dieser Zeile frei, die Bezeichnungen stehen trotzdem untereinander.
##
## Ein Bild macht die Karte so breit, wie sie werden darf (`MAX_WIDTH`): eine Vorschau in
## Textbreite wäre eine Briefmarke.
##
## `icon` steht vor der Überschrift, `subtitle` darunter — in `tint` gefärbt, weil die
## Farbe eines Fähigkeitsbaums aus seinen Daten kommt und nicht aus dem Theme. Gefärbt
## wird über `self_modulate` auf weißer Schrift (`HintSubtitle`), nicht über einen
## Theme-Override. Mit einer Unterzeile trennt ein Strich den Kopf vom Text.
func fill(title: String, body := "", note := "", list := [], image: Texture2D = null,
		icon: Texture2D = null, subtitle := "", tint := Color.WHITE) -> void:
	# Eine leere Zeile verschwindet, statt eine leere Zeile zu hinterlassen: die Karte für
	# eine Münze ist eine Zeile hoch und kein Kasten mit Luft.
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
	_fit()


## Die Zellen kommen bei jedem Aufruf neu: eine Karte zeigt mal zwei, mal sechs Zeilen.
## `remove_child` vor `queue_free`, sonst misst `_fit()` die alten Zellen noch mit.
func _fill_list(list: Array) -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	for row in list:
		for i in 3:
			# Das Zeichen darf ein Bild sein (Stern, Haken, Schloss) — dann steht es in
			# fester Größe da, damit die Bezeichnungen trotzdem in einer Flucht beginnen.
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


## Die Bezeichnungen der Liste — die mittlere Spalte, die einzige, die umbrechen darf.
## Zeichen und Werte sind kurz und bleiben einzeilig, damit sie in einer Flucht stehen.
func _list_names() -> Array:
	var names := []
	var cells := _list.get_children()
	for i in range(1, cells.size(), 3):
		names.append(cells[i])
	return names


## Breite der Liste ohne ihre mittlere Spalte: Zeichen, Werte und die zwei Abstände.
func _list_frame_width() -> float:
	var cells := _list.get_children()
	var mark := 0.0
	var value := 0.0
	for i in range(0, cells.size(), 3):
		mark = maxf(mark, (cells[i] as Control).get_combined_minimum_size().x)
		value = maxf(value, (cells[i + 2] as Control).get_combined_minimum_size().x)
	return mark + value + 2.0 * _list.get_theme_constant("h_separation")


## Die Breitenregel, in der einzigen Reihenfolge, in der sie funktioniert.
##
## Ein `Label` mit `autowrap_mode` meldet als Mindestbreite 1 Pixel und dazu die Höhe, die
## der Text bei EINEM Pixel Breite braucht (CLAUDE.md, dieselbe Falle wie bei
## `RevealCard.set_width()`). Man kann also nicht in einem Zug fragen, wie breit der Text
## gern wäre und wie hoch er dann wird. Zum MESSEN wird der Umbruch deshalb abgeschaltet.
func _fit() -> void:
	var labels := [_title, _subtitle, _body, _note]
	var names := _list_names()
	# 1. Ohne Umbruch messen — und die Breite des VORIGEN Aufrufs vorher weg. Ohne diese
	#    Null wäre jede Karte so breit wie die breiteste, die je zu sehen war.
	for label: Label in labels + names:
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.custom_minimum_size.x = 0.0
	_image.custom_minimum_size = Vector2.ZERO
	# Gemessen wird an der Tafel, der Innenabstand aus `PanelContainer/styles/panel` steckt
	# also schon drin. Mehrzeilige Hinweise messen sich über ihre längste Zeile.
	var outer := clampf(get_combined_minimum_size().x, MIN_WIDTH, MAX_WIDTH)
	if _image.visible:
		outer = MAX_WIDTH
	var inner := outer - get_theme_stylebox("panel").get_minimum_size().x
	if _image.visible:
		var picture := _image.texture.get_size()
		_image.custom_minimum_size = Vector2(inner, inner * picture.y / maxf(picture.x, 1.0))
	# 2. Umbruch wieder an und die Breite in die Labels DRÜCKEN, bevor jemand nach der
	#    Höhe fragt. `size.x` löst den Umbruch aus, `custom_minimum_size.x` hält ihn, wenn
	#    der Container gleich neu sortiert — beides, nicht eins von beidem.
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
	# Die Bezeichnungen der Liste bekommen, was neben Zeichen und Werten übrig bleibt —
	# damit rücken die Werte zugleich an den rechten Rand, in eine Flucht.
	var name_width := maxf(0.0, inner - _list_frame_width())
	for label: Label in names:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = name_width
		label.size.x = name_width
	# 3. Den Umbruch JETZT erzwingen. `get_minimum_size()` rechnet ihn NICHT nach — es gibt
	#    den Stand der letzten Umbruchrechnung zurück, und die lief noch mit der Breite von
	#    vorhin. `get_line_count()` bricht dagegen sofort um; ohne diese Schleife meldete
	#    die Karte die Höhe für die Breite der VORIGEN Karte (beim ersten Mal: für einen
	#    Pixel, also 2056 statt 133).
	for label: Label in labels + names:
		label.get_line_count()
	# 4. Erst jetzt die Höhe lesen: sie ist für DIESE Breite gerechnet.
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


## Wo die Spitze gerade liegt (Kartenkoordinaten) — für den Test, dass sie auf die Maus
## zeigt. NaN ohne Pfeil.
func pointer_tip() -> Vector2:
	if is_nan(_pointer_x):
		return Vector2(NAN, NAN)
	return Vector2(_pointer_x, -pointer_reach() if _pointer_up else size.y + pointer_reach())


## Der Rahmen liegt über der Füllung (die zeichnet `PanelContainer` selbst) und unter dem
## Inhalt — Kinder werden nach dem Elternknoten gezeichnet. Die halbdurchsichtige Mitte der
## Rahmentextur bleibt weg (`draw_center = false` im Theme): die Füllung ist deckend.
##
## Der Pfeil kommt zuletzt: erst eine Dreiecksfläche in der Farbe der Füllung, dann die
## Textur darüber. Sein Fuß reicht in die Karte und deckt die Randlinie dort ab.
func _draw() -> void:
	draw_style_box(get_theme_stylebox("frame"), Rect2(Vector2.ZERO, size))
	if is_nan(_pointer_x):
		return
	var texture := get_theme_icon("pointer_up" if _pointer_up else "pointer_down")
	var half := POINTER_SIZE.x * 0.5
	var tip := pointer_tip()
	var base_y := POINTER_INSET if _pointer_up else size.y - POINTER_INSET
	var fill := get_theme_stylebox("panel") as StyleBoxFlat
	if fill != null:
		draw_colored_polygon(PackedVector2Array([
				Vector2(_pointer_x - half, base_y), tip, Vector2(_pointer_x + half, base_y)]),
				fill.bg_color)
	var top := tip.y if _pointer_up else base_y
	draw_texture_rect(texture, Rect2(Vector2(_pointer_x - half, top), POINTER_SIZE), false)
