class_name WordPlate
extends Control
## Ein Wortschild über einem Monster: Plakette mit dem Prompt und darunter der Zipfel, der
## auf den Kopf zeigt (Grafiken `assets/ui/gameplay/frames/word_plate_{rim,base}.webp` und
## `word_plate_pointer_{rim,base}.webp`, zusammengesetzt in `word_plate.gdshader`). Wo es steht,
## entscheidet `WordPlates`; das Schild kennt nur seinen Inhalt und seine Größe.
##
## Der Zipfel ist eine eigene Grafik und wird nicht gestreckt. Er sitzt mittig unter der
## Plakette und überlappt ihre Unterkante um 2 Texturpixel (README des Pakets).

const POINTER_SIZE := Vector2(24.0, 12.0)
const POINTER_OVERLAP := 2.0
const TEXT_LIGHTEN := 0.35

var monster: Monster
## Geglättete Verschiebung gegenüber dem Wunschplatz über dem Kopf.
var push := Vector2.ZERO

@onready var _frame: PanelContainer = $Frame
@onready var _text: Label = %Text
@onready var _pointer: TextureRect = $Pointer


## `large`: die Größe der Ich-Sicht, in der das Schild vor der Nase lesbar bleiben muss.
func setup(of: Monster, large: bool) -> void:
	monster = of
	if large:
		_frame.theme_type_variation = &"HudWordPlateLarge"
		_text.theme_type_variation = &"HudPlateTextLarge"
	_text.text = of.prompt()
	# Die Wortart in Rand und Schrift, wie die Outline am Modell. Der Rand nimmt die Farbe
	# voll an (word_plate.gdshader), die Schrift aufgehellt — auf der dunklen Fläche wäre
	# etwa das Nomen-Blau sonst zu schwach.
	var color := of.word_color()
	_frame.self_modulate = color
	_pointer.self_modulate = color
	_text.self_modulate = color.lerp(Color.WHITE, TEXT_LIGHTEN)
	_fit()


## Plakette und Zipfel zusammen; der Zipfel hängt unten über den Rand hinaus.
func plate_size() -> Vector2:
	return size + Vector2(0.0, _pointer_height())


func _pointer_height() -> float:
	return _pointer.size.y - POINTER_OVERLAP * _scale()


func _scale() -> float:
	var style := _frame.get_theme_stylebox("panel") as FrameStyle
	return style.scale if style != null else 1.0


func _fit() -> void:
	var frame := _frame.get_combined_minimum_size()
	_frame.position = Vector2.ZERO
	_frame.size = frame
	size = frame
	var k := _scale()
	_pointer.size = POINTER_SIZE * k
	_pointer.position = Vector2((frame.x - _pointer.size.x) / 2.0, frame.y - POINTER_OVERLAP * k)


## Die Spitze des Zipfels, in Koordinaten des Elternknotens.
func tip() -> Vector2:
	return position + Vector2(size.x / 2.0, plate_size().y)
