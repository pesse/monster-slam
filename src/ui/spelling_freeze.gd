class_name SpellingFreeze
extends Control
## Das Standbild nach einem nachsichtigen Treffer (ADR 0008, ADR 0010): die Antwort zählte,
## war aber anders geschrieben („ecole" für „l'école"). Das Monster ist schon zerplatzt,
## dann steht das Bild, die Kamera fährt auf die Stelle zu, ein heller Schleier legt sich
## darüber und in der Mitte steht die richtige Schreibweise mit markierten Fehlern. Danach
## fährt die Kamera zurück und der Kampf läuft weiter.
##
## Wie die Meister-Feier meldet die Szene über `started`, wie lange sie steht — das
## Anhalten macht der WaveRunner über die Baum-Pause, Engine.time_scale bleibt SlowMotion.
## Die Kamera bewegt der WaveRunner: er übergibt `play` eine Funktion, die für k von 0
## (Spielbild) bis 1 (ganz herangefahren) die Kamera setzt.
##
## Über einem Akzent steht klein sein Name, französisch wie im Unterricht („accent aigu").
## Fehlende Bindestriche und Apostrophe sind keine Akzente und bleiben ohne Namen.
##
## Keine Taste beendet das Bild vorzeitig: das Kind soll nichts tun müssen, um weiterzuspielen.
## Was es währenddessen tippt, hebt der WaveRunner auf wie bei der Feier.

signal started(duration_ms: int)
signal finished()

## So lange läuft die Explosion noch, bevor das Bild steht — sonst friert ein Bild ohne
## Trümmer ein. Echtzeit, auch in der Zeitlupe.
const LEAD_MS := 150
const ZOOM_IN_MS := 220
const HOLD_MS := 900
const ZOOM_OUT_MS := 250

const ACCENT_NAME_SCENE := preload("res://scenes/ui/accent_name.tscn")
## Die Namen der Zeichen, die der nachsichtige Vergleich faltet (AnswerEvaluator._DIACRITICS).
const ACCENT_NAMES := {
	"é": "accent aigu", "á": "accent aigu", "í": "accent aigu", "ó": "accent aigu",
	"ú": "accent aigu",
	"è": "accent grave", "à": "accent grave", "ù": "accent grave",
	"ê": "accent circonflexe", "â": "accent circonflexe", "î": "accent circonflexe",
	"ô": "accent circonflexe", "û": "accent circonflexe",
	"ë": "tréma", "ï": "tréma", "ÿ": "tréma",
	"ç": "cédille",
	"œ": "e dans l'o", "æ": "e dans l'a",
}
## Abstand zweier Namen in einer Zeile; rücken sie näher, kommt der zweite eine Zeile höher.
const NAME_GAP := 8.0

## Wartende Standbilder als [Form, Stellen, Kamerafahrt]. Kommen zwei kurz nacheinander
## (ein Pfeil war noch unterwegs), folgt das zweite direkt; `finished` kommt nach dem letzten.
var _queue: Array = []
var _running := false

@onready var _word: RichTextLabel = %Word
@onready var _names: Control = %Names


func is_busy() -> bool:
	return _running or not _queue.is_empty()


## Wie lange das Bild steht (ohne den Vorlauf).
static func duration_ms() -> int:
	return ZOOM_IN_MS + HOLD_MS + ZOOM_OUT_MS


func play(canonical: String, marks: PackedInt32Array, zoom := Callable()) -> void:
	_queue.append([canonical, marks, zoom])
	if not _running:
		_run()


func _run() -> void:
	_running = true
	while not _queue.is_empty():
		var next: Array = _queue.pop_front()
		await _show(next[0], next[1], next[2])
	visible = false
	_running = false
	finished.emit()


func _show(canonical: String, marks: PackedInt32Array, zoom: Callable) -> void:
	# Inhalt VOR dem Einblenden: ein sichtbares Overlay in der Bildmitte ändert seine Größe nicht.
	_word.text = markup(canonical, marks, get_theme_color("font_color", &"SpellingMark"))
	_place_names(canonical, marks)
	modulate.a = 0.0
	visible = true
	await get_tree().create_timer(LEAD_MS / 1000.0, true, false, true).timeout
	started.emit(duration_ms())
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(self, "modulate:a", 1.0, ZOOM_IN_MS / 1000.0)
	if zoom.is_valid():
		tw.parallel().tween_method(zoom, 0.0, 1.0, ZOOM_IN_MS / 1000.0) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_interval(HOLD_MS / 1000.0)
	tw.tween_property(self, "modulate:a", 0.0, ZOOM_OUT_MS / 1000.0)
	if zoom.is_valid():
		tw.parallel().tween_method(zoom, 1.0, 0.0, ZOOM_OUT_MS / 1000.0) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished


## Vorwärmen (FxWarmup): Schleier und Schrift samt Markierung einmal zeigen, damit ihre
## Shader und Zeichen nicht erst beim ersten Fehler entstehen. Danach cool_down().
func warm_up() -> void:
	if is_busy():
		return
	_word.text = markup(FxWarmup.GLYPHS, PackedInt32Array([0]),
			get_theme_color("font_color", &"SpellingMark"))
	_clear_names()
	var label := ACCENT_NAME_SCENE.instantiate() as Label
	label.text = FxWarmup.GLYPHS
	_names.add_child(label)
	modulate.a = 1.0
	visible = true


func cool_down() -> void:
	if not is_busy():
		visible = false


## Die Namen der markierten Akzente als Gruppen { name, first, last } (Indizes in `text`).
## Derselbe Akzent mit höchstens einem Buchstaben dazwischen („été") ist EIN Name über
## beiden — zweimal „accent aigu" nebeneinander läse sich nicht.
static func accent_groups(text: String, marks: PackedInt32Array) -> Array:
	var groups: Array = []
	for i in marks:
		var name := str(ACCENT_NAMES.get(text[i].to_lower(), ""))
		if name.is_empty():
			continue
		if not groups.is_empty() and groups[-1]["name"] == name and i - int(groups[-1]["last"]) <= 2:
			groups[-1]["last"] = i
		else:
			groups.append({"name": name, "first": i, "last": i})
	return groups


## Setzt die Namen über ihre Buchstaben. Gemessen mit der Schrift des Wortes; das Wort steht
## zentriert in derselben Breite wie die Namenszeile.
func _place_names(text: String, marks: PackedInt32Array) -> void:
	_clear_names()
	var font := _word.get_theme_font(&"normal_font")
	var font_size := _word.get_theme_font_size(&"normal_font_size")
	var width := _names.custom_minimum_size.x
	var measure := func(part: String) -> float:
		return font.get_string_size(part, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var left := (width - float(measure.call(text))) / 2.0
	var row_ends: Array[float] = [-INF, -INF]
	for group in accent_groups(text, marks):
		var x0 := left + float(measure.call(text.substr(0, int(group["first"]))))
		var x1 := left + float(measure.call(text.substr(0, int(group["last"]) + 1)))
		var label := ACCENT_NAME_SCENE.instantiate() as Label
		label.text = str(group["name"])
		_names.add_child(label)
		var label_size := label.get_combined_minimum_size()
		var from := (x0 + x1 - label_size.x) / 2.0
		var row := 0 if from >= row_ends[0] + NAME_GAP else 1
		label.position = Vector2(from, _names.custom_minimum_size.y - label_size.y * (row + 1))
		row_ends[row] = from + label_size.x


func _clear_names() -> void:
	for child in _names.get_children():
		_names.remove_child(child)
		child.free()


## BBCode für `text` mit den Zeichen an `marks` farbig und unterstrichen. Eckige Klammern
## im Wort werden maskiert, sonst läsen sie sich als Tags.
static func markup(text: String, marks: PackedInt32Array, mark_color: Color) -> String:
	var out := ""
	var hex := mark_color.to_html(false)
	for i in text.length():
		var c := text[i]
		var shown := "[lb]" if c == "[" else c
		if marks.has(i):
			out += "[color=#%s][u]%s[/u][/color]" % [hex, shown]
		else:
			out += shown
	return out
