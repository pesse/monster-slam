class_name WordPlate
extends Control
## Ein Wortschild über einem Monster: Plakette mit dem Prompt und darunter der Zipfel, der
## auf den Kopf zeigt (zusammengesetzt in `word_plate.gdshader`). Wo es steht, entscheidet
## `WordPlates`.

## Zipfel in Texturpixeln, ungestreckt; überlappt die Unterkante der Plakette.
const POINTER_SIZE := Vector2(24.0, 12.0)
const POINTER_OVERLAP := 2.0
## Anteil, um den die Schrift von der Wortartfarbe zu Weiß aufgehellt wird.
const TEXT_LIGHTEN := 0.35
## Gemeistert (`Monster.mastered`): Rand und Schrift ziehen zu diesem Grau und dunkeln nach.
const MASTERED_GRAY := Color(0.62, 0.64, 0.68)
const MASTERED_RIM_GRAY := 0.6
const MASTERED_RIM_DARKEN := 0.25
const MASTERED_TEXT_GRAY := 0.7
const MASTERED_TEXT_DARKEN := 0.1
const MASTERED_MARK := "✓ "
## Die Lösung einer neuen Aufgabe (ADR 0027), heller als das Wort.
const HELP_INK := Color(1.0, 0.95, 0.7)
## Das Abzeichen „neu“ an der linken oberen Ecke: Höhe in Texturpixeln der Plakette (mit
## FrameStyle.scale skaliert, Breite nach Seitenverhältnis) und wie weit es links und oben
## übersteht, als Anteil seiner Größe.
const BADGE_HEIGHT := 34.0
const BADGE_OVERHANG := Vector2(0.25, 0.55)
## Längere Aufgaben (Buchsätze) brechen auf dieser Breite um, px; die Ich-Sicht ist größer.
const WRAP_CHARS := 32
const WRAP_WIDTH := 280.0
const LARGE_WRAP_FACTOR := 1.5
## So leuchtet ein Schild auf, das der Zauber aufdeckt (überhellt): violett bei den
## Alternativen, golden beim ersten Buchstaben (Farben wie SpellFx.COLORS).
const REVEAL_GLOW := Color(1.6, 1.25, 2.0)
const INITIAL_GLOW := Color(2.0, 1.6, 0.9)
## Hinter dem ersten Buchstaben der Lösung.
const INITIAL_TAIL := "…"
## Startgröße des Aufspringens und Dauer von Rückfedern und Ausleuchten, s.
const REVEAL_SCALE := 1.35
const REVEAL_SETTLE := 0.35
const REVEAL_FADE := 0.6

var monster: Monster
## Geglättete Verschiebung gegenüber dem Wunschplatz über dem Kopf.
var push := Vector2.ZERO

@onready var _frame: PanelContainer = $Frame
@onready var _text: Label = %Text
## Die Lösung einer neuen Aufgabe (ADR 0027) von Anfang an, sonst nach dem Zauber ihr
## erster Buchstabe.
@onready var _help: Label = %Help
@onready var _badge: TextureRect = $Badge
## Die Alternativen der Aufgabe in einer weiteren Zeile, erst nach dem Zauber (ADR 0014).
@onready var _alt: Label = %Alt
@onready var _pointer: TextureRect = $Pointer


## `large`: Schildgröße der Ich-Sicht.
func setup(of: Monster, large: bool) -> void:
	monster = of
	if large:
		_frame.theme_type_variation = &"HudWordPlateLarge"
		_text.theme_type_variation = &"HudPlateTextLarge"
		_alt.theme_type_variation = &"HudPlateAltLarge"
		_help.theme_type_variation = &"HudPlateAltLarge"
	_text.text = (MASTERED_MARK if of.mastered else "") + of.prompt()
	if _text.text.length() > WRAP_CHARS:
		_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_text.custom_minimum_size.x = WRAP_WIDTH * (LARGE_WRAP_FACTOR if large else 1.0)
	_alt.text = alt_line(of.alts(), of.alt_label())
	_alt.visible = of.alts_shown
	_help.text = of.help_answer()
	_help.visible = not _help.text.is_empty()
	_badge.visible = _help.visible
	if of.initial_shown:
		_help.text = initial_line(of.initial())
		_help.visible = true
	of.alts_revealed.connect(_on_alts_revealed)
	of.initial_revealed.connect(_on_initial_revealed)
	# Wortartfarbe in Rand und Schrift; die Schrift aufgehellt für die dunkle Fläche.
	var color := of.word_color()
	var rim := color
	var ink := color.lerp(Color.WHITE, TEXT_LIGHTEN)
	if of.mastered:
		rim = color.lerp(MASTERED_GRAY, MASTERED_RIM_GRAY).darkened(MASTERED_RIM_DARKEN)
		ink = color.lerp(MASTERED_GRAY, MASTERED_TEXT_GRAY).darkened(MASTERED_TEXT_DARKEN)
	_frame.self_modulate = rim
	_pointer.self_modulate = rim
	_text.self_modulate = ink
	_alt.self_modulate = _text.self_modulate
	_help.self_modulate = HELP_INK
	_fit()


## Der Zauber deckt auf: nach `delay` (s) springt das Schild mit der zweiten Zeile auf und
## leuchtet kurz. Ohne Verzögerung steht die Zeile sofort da.
func _on_alts_revealed(delay: float) -> void:
	_reveal(_alt, delay, REVEAL_GLOW)


func _on_initial_revealed(delay: float) -> void:
	_help.text = initial_line(monster.initial())
	_reveal(_help, delay, INITIAL_GLOW)


func _reveal(line: Label, delay: float, glow: Color) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay, false).timeout
		if not is_instance_valid(monster):
			return
	line.visible = true
	_fit()
	pivot_offset = Vector2(size.x / 2.0, plate_size().y)
	scale = Vector2.ONE * REVEAL_SCALE
	modulate = glow
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector2.ONE, REVEAL_SETTLE).set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate", Color.WHITE, REVEAL_FADE)


## Die zweite Zeile: „auch: walk, run“, beim Buchsatz „Wort: victim“.
static func alt_line(alts: Array, label := "auch") -> String:
	return "%s: %s" % [label, ", ".join(alts.map(func(a: Variant) -> String: return str(a)))]


## Die Zeile nach der Flüstermuschel: „g…“.
static func initial_line(initial: String) -> String:
	return initial + INITIAL_TAIL


## Plakette und Zipfel zusammen; der Zipfel hängt unten über den Rand hinaus.
func plate_size() -> Vector2:
	return size + Vector2(0.0, _pointer_height())


func _pointer_height() -> float:
	return _pointer.size.y - POINTER_OVERLAP * _scale()


func _scale() -> float:
	var style := _frame.get_theme_stylebox("panel") as FrameStyle
	return style.scale if style != null else 1.0


func _fit() -> void:
	# Ein umbrechendes Label misst seine Höhe an der eigenen Breite (CONVENTIONS „Fallen“).
	if _text.autowrap_mode != TextServer.AUTOWRAP_OFF:
		_text.size = Vector2(_text.custom_minimum_size.x, 0.0)
		_text.update_minimum_size()
	var frame := _frame.get_combined_minimum_size()
	_frame.position = Vector2.ZERO
	_frame.size = frame
	size = frame
	var k := _scale()
	_pointer.size = POINTER_SIZE * k
	_pointer.position = Vector2((frame.x - _pointer.size.x) / 2.0, frame.y - POINTER_OVERLAP * k)
	var tex := _badge.texture.get_size()
	_badge.size = Vector2(tex.x / tex.y, 1.0) * BADGE_HEIGHT * k
	_badge.position = -_badge.size * BADGE_OVERHANG


## Die Spitze des Zipfels, in Koordinaten des Elternknotens.
func tip() -> Vector2:
	return position + Vector2(size.x / 2.0, plate_size().y)
