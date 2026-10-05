class_name SpellBanner
extends Control
## Bild und Name eines Zaubers, groß über dem Feld, wenn er gewirkt wird (ADR 0014,
## scenes/ui/spell_banner.tscn): springt auf, steht kurz und steigt verblassend weg. Der
## Name leuchtet in der Farbe des Zaubers (SpellFx.COLORS). Was auf dem Feld geschieht,
## macht SpellFx.
##
## Echtzeit: in der Zeitlupe des Tippens soll das Banner nicht kleben bleiben.

const POP := 0.22
const HOLD := 0.45
const FADE := 0.45
const RISE := 24.0

@onready var _box: Control = %Box
@onready var _picture: TextureRect = %Picture
@onready var _glyph: Label = %Glyph
@onready var _name: Label = %Name

var _tween: Tween
var _rest_y := 0.0


func _ready() -> void:
	_rest_y = _box.position.y


func play(spell: Dictionary) -> void:
	SpellIcons.show(spell, _picture, _glyph)
	_name.text = str(spell.get("name", ""))
	var color: Color = SpellFx.COLORS.get(str(spell.get("effect", "")), Color.WHITE)
	_name.self_modulate = color.lerp(Color.WHITE, 0.35)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	visible = true
	_box.position.y = _rest_y
	_box.pivot_offset = _box.size / 2.0
	_box.scale = Vector2.ONE * 0.4
	_box.modulate = Color(1.8, 1.8, 1.8, 0.0)
	_tween = create_tween().set_ignore_time_scale(true)
	_tween.set_parallel(true)
	_tween.tween_property(_box, "scale", Vector2.ONE, POP).set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT)
	_tween.tween_property(_box, "modulate", Color.WHITE, POP * 1.5)
	_tween.chain().tween_interval(HOLD)
	_tween.chain().tween_property(_box, "modulate:a", 0.0, FADE)
	_tween.parallel().tween_property(_box, "position:y", _rest_y - RISE, FADE)
	_tween.chain().tween_callback(func() -> void: visible = false)


## Ob gerade ein Banner steht — für die Werkbank.
func is_busy() -> bool:
	return visible
