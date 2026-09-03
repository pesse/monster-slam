class_name StatsChart
extends Control
## Minimaler Linien-Chart mit Godot-Bordmitteln (Issue #7): eine Wertereihe, gezeichnet
## in `_draw()`, ohne Diagramm-Bibliothek und ohne Addon.
##
## Bewusst ein eigenständiger Control und nicht Teil des Statistik-Screens: die Lernkurve
## ist die erste Reihe, die hier gezeichnet wird, aber nicht die letzte (Genauigkeit,
## Wellen pro Sitzung …). Deshalb kennt er nur Zahlen und zwei Beschriftungen — was die
## Reihe bedeutet, weiß der Screen.
##
## Die Höhe steht in der Szene (custom_minimum_size), damit sie im Editor änderbar bleibt.
## Die Rechnung (Achsen-Maximum, Punktlage) steht in statischen Funktionen, damit sie ohne
## Szene und Zeichenaufruf prüfbar ist (siehe tests/stats_chart_test.gd).

## Platz für die Beschriftungen: links das Achsen-Maximum, unten die Zeitspanne.
const PAD_LEFT := 40.0
const PAD_RIGHT := 8.0
const PAD_TOP := 10.0
const PAD_BOTTOM := 20.0

const LINE_COLOR := Color(0.45, 0.85, 0.55)
const AREA_COLOR := Color(0.45, 0.85, 0.55, 0.16)
const GRID_COLOR := Color(0.32, 0.32, 0.38)
const LABEL_COLOR := Color(0.75, 0.75, 0.75)
const LABEL_SIZE := 12

var _values: Array = []
var _first_label := ""
var _last_label := ""


## Setzt die Reihe (Werte in Zeit-Reihenfolge, ältester zuerst) und die Beschriftungen
## der beiden Enden der Zeitachse.
func show_series(values: Array, first_label := "", last_label := "") -> void:
	_values = values.duplicate()
	_first_label = first_label
	_last_label = last_label
	queue_redraw()


## Oberes Achsen-Ende: der Höchstwert, aufgerundet auf eine ablesbare Zahl. Nie 0 — sonst
## teilt die Punktlage durch null und eine leere Kurve hätte keine Fläche.
static func axis_max(values: Array) -> int:
	var top := 0
	for value in values:
		top = maxi(top, int(value))
	if top <= 0:
		return 1
	var step := 1
	if top > 100:
		step = 50
	elif top > 50:
		step = 10
	elif top > 5:
		step = 5
	return int(ceil(float(top) / float(step))) * step


## Bildschirmpunkte der Reihe innerhalb von `plot` (dem Feld ohne die Beschriftungen).
## Ein einzelner Wert sitzt am linken Rand; bei leerer Reihe gibt es keine Punkte.
static func plot_points(values: Array, plot: Rect2, max_value: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	if values.is_empty() or max_value <= 0 or plot.size.x <= 0.0 or plot.size.y <= 0.0:
		return points
	var span := maxi(1, values.size() - 1)
	for i in values.size():
		var ratio := clampf(float(values[i]) / float(max_value), 0.0, 1.0)
		points.append(Vector2(
			plot.position.x + plot.size.x * float(i) / float(span),
			plot.end.y - plot.size.y * ratio))
	return points


## Das Feld für die Kurve: die Fläche des Controls ohne den Platz der Beschriftungen.
func _plot_rect() -> Rect2:
	return Rect2(
		Vector2(PAD_LEFT, PAD_TOP),
		Vector2(size.x - PAD_LEFT - PAD_RIGHT, size.y - PAD_TOP - PAD_BOTTOM))


func _draw() -> void:
	var plot := _plot_rect()
	if plot.size.x <= 0.0 or plot.size.y <= 0.0:
		return
	var font := get_theme_default_font()
	var top_value := axis_max(_values)

	# Grundlinie und obere Hilfslinie — zwei Linien genügen, um die Kurve einzuordnen.
	draw_line(Vector2(plot.position.x, plot.end.y), plot.end, GRID_COLOR, 1.0)
	draw_line(plot.position, Vector2(plot.end.x, plot.position.y), GRID_COLOR, 1.0)
	draw_string(font, Vector2(0.0, plot.position.y + float(LABEL_SIZE) * 0.5),
			str(top_value), HORIZONTAL_ALIGNMENT_LEFT, PAD_LEFT - 4.0, LABEL_SIZE, LABEL_COLOR)
	draw_string(font, Vector2(0.0, plot.end.y), "0",
			HORIZONTAL_ALIGNMENT_LEFT, PAD_LEFT - 4.0, LABEL_SIZE, LABEL_COLOR)

	var points := plot_points(_values, plot, top_value)
	if points.size() >= 2:
		# Fläche unter der Kurve: lässt das Steigen auch bei flachem Verlauf lesen.
		var area := PackedVector2Array([Vector2(points[0].x, plot.end.y)])
		area.append_array(points)
		area.append(Vector2(points[points.size() - 1].x, plot.end.y))
		draw_colored_polygon(area, AREA_COLOR)
		draw_polyline(points, LINE_COLOR, 2.0, true)
	if points.size() == 1:
		draw_line(points[0], Vector2(plot.end.x, points[0].y), LINE_COLOR, 2.0)
	if not points.is_empty():
		draw_circle(points[points.size() - 1], 3.5, LINE_COLOR)

	var baseline := size.y - 4.0
	if not _first_label.is_empty():
		draw_string(font, Vector2(plot.position.x, baseline), _first_label,
				HORIZONTAL_ALIGNMENT_LEFT, plot.size.x * 0.5, LABEL_SIZE, LABEL_COLOR)
	if not _last_label.is_empty():
		draw_string(font, Vector2(plot.position.x + plot.size.x * 0.5, baseline), _last_label,
				HORIZONTAL_ALIGNMENT_RIGHT, plot.size.x * 0.5, LABEL_SIZE, LABEL_COLOR)
