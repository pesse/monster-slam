extends CanvasLayer
## Die Auskunft am Zeiger: eine eigene Zeichenschicht über allem (`LAYER`) mit einer
## `HintCard`. Controls melden ihre Auskunft an (`attach`); jeden Frame wird der Zeiger
## gefragt (`gui_get_hovered_control()`) und von dort nach oben gesucht. Die eigene Schicht
## entgeht der Beschneidung durch ScrollContainer; das Fragen statt `mouse_entered` deckt
## Wegscrollen, Freigeben und Szenenwechsel ohne Abmelden ab.

## Meta-Schlüssel der Auskunft am Control; sie stirbt mit ihrem Knoten.
const META := &"hint"

const LAYER := 128

## Abstand der Pfeilspitze zur Maus (px); unten größer, das Zeigerbild reicht nach unten.
const TIP_GAP_BELOW := 22.0
const TIP_GAP_ABOVE := 6.0
## So weit links vom Zeiger beginnt die Karte (px).
const POINTER_LEAD := 32.0

@onready var _card: HintCard = %Card

## Was beim letzten Blick unter dem Zeiger lag; ohne Änderung wird nicht neu gebaut.
var _last_id: int = 0
var _last_at := Vector2.INF


func _ready() -> void:
	layer = LAYER
	_card.hide()


func _process(_delta: float) -> void:
	_look(false)


## Fragt sofort nach, was unter dem Zeiger liegt: für Inhalte, die sich ohne Bewegung ändern.
func refresh() -> void:
	_look(true)


## Hängt einem Control seine Auskunft an; ein durchweg leerer Hinweis nimmt sie ab. Sie gilt
## auch für alle Kinder. `list`: Zeilen `[zeichen, bezeichnung, wert]` (siehe `HintCard`).
func attach(target: Control, title: String, body := "", note := "", list := []) -> void:
	if title.is_empty() and body.is_empty() and note.is_empty() and list.is_empty():
		if target.has_meta(META):
			target.remove_meta(META)
		return
	target.set_meta(META, {"title": title, "body": body, "note": note, "list": list})


## Eine Fläche, die ihre Treffer selbst sucht: `provider(local: Vector2) -> Dictionary`
## liefert die Karte für einen Punkt in der Fläche. Nur so trägt sie Bilder (`image`,
## `icon`, Texture2D als Zeichen), `subtitle`/`tint` und `prices`. Leer heißt nichts, auch
## nicht beim Elternknoten.
func attach_live(target: Control, provider: Callable) -> void:
	target.set_meta(META, provider)


func hint_of(target: Control) -> Dictionary:
	if not target.has_meta(META):
		return {}
	var value: Variant = target.get_meta(META)
	return value if value is Dictionary else {}


## Die Karte selbst, für Tests.
func card() -> HintCard:
	return _card


## Tut so, als läge der Zeiger bei `at` über `control`, und stellt die Karte entsprechend.
## Die Naht für Tests (kopflos keine Mausereignisse, CONVENTIONS „Fallen“); gilt nur bis zum
## nächsten Frame.
func probe(control: Control, at := Vector2.INF) -> void:
	var point := at if at.is_finite() else control.get_global_rect().get_center()
	_show(_hint_under(control, point), point)


## Die Karte für ein fokussiertes Control; sie bleibt, bis sich der Zeiger bewegt.
func show_for(control: Control) -> void:
	probe(control)


func _look(forced: bool) -> void:
	var view := get_viewport()
	if view == null:
		return
	var over := view.gui_get_hovered_control()
	var at := view.get_mouse_position()
	var id := over.get_instance_id() if over != null else 0
	if not forced and id == _last_id and at == _last_at:
		return
	_last_id = id
	_last_at = at
	_show(_hint_under(over, at), at)


func _show(found: Dictionary, at: Vector2) -> void:
	if found.is_empty():
		_card.hide()
		return
	_card.fill(str(found.get("title", "")), str(found.get("body", "")),
			str(found.get("note", "")), found.get("list", []), found.get("image") as Texture2D,
			found.get("icon") as Texture2D, str(found.get("subtitle", "")),
			found.get("tint", Color.WHITE) as Color, found.get("prices", []))
	_place(at)
	_card.show()


## Vom Control unter dem Zeiger nach oben, bis eines eine Auskunft trägt; anders als Godots
## Suche ohne Abbruch an `MOUSE_FILTER_STOP`.
func _hint_under(node: Node, at: Vector2) -> Dictionary:
	var walk := node
	while walk != null:
		var control := walk as Control
		if control != null and control.has_meta(META):
			var value: Variant = control.get_meta(META)
			if value is Callable:
				# Aus `at` gerechnet statt `get_local_mouse_position()`, damit `probe` stimmt.
				var local: Vector2 = control.get_global_transform().affine_inverse() * at
				var answer: Variant = (value as Callable).call(local)
				return answer if answer is Dictionary else {}
			return value if value is Dictionary else {}
		walk = walk.get_parent()
	return {}


## Unter den Zeiger, nie über den Rand des sichtbaren Bildes: unten klappt die Karte über den
## Zeiger, rechts rückt sie nach links, der Pfeil wandert mit.
func _place(at: Vector2) -> void:
	var room := get_viewport().get_visible_rect().size
	var size := _card.size
	var reach := HintCard.pointer_reach()
	var to := Vector2(at.x - POINTER_LEAD, at.y + TIP_GAP_BELOW + reach)
	var below := true
	if to.y + size.y > room.y:
		to.y = at.y - TIP_GAP_ABOVE - reach - size.y
		below = false
	_card.position = to.clamp(Vector2.ZERO, (room - size).max(Vector2.ZERO))
	_card.point_at(at.x - _card.position.x, below)
