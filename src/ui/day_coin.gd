class_name DayCoin
extends Control
## Die gezeichnete Münze der Tages-Leiste: geübt, verpasst, heute offen oder künftig. Sie
## markiert einen Tag, keine Währung. Dieselbe Zeichnung fliegt aus der Schatzkiste.

enum State {
	EARNED,   ## An diesem Tag wurde geübt.
	MISSED,   ## Vergangener Tag ohne Sitzung.
	OPEN,     ## Heute — noch zu holen.
	FUTURE,   ## Tag im laufenden Monat, der noch kommt: leerer Platz.
}

const RIM_GOLD := Color(0.72, 0.54, 0.13)
const FACE_GOLD := Color(0.98, 0.84, 0.38)
const RIM_GREY := Color(0.2, 0.2, 0.23)
const FACE_GREY := Color(0.29, 0.29, 0.33)
## Ring eines künftigen Tags.
const SLOT := Color(0.3, 0.3, 0.34)
## Ring des heutigen Tags.
const TODAY_RING := Color(1.0, 0.8, 0.35)

var state: State = State.MISSED
var is_today := false


## `title`/`note` werden zur Karte am Zeiger; leer heißt keine Karte.
func setup(new_state: State, today: bool, title := "", note := "") -> void:
	state = new_state
	is_today = today
	Hints.attach(self, title, note)
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - 2.0
	if radius <= 0.0:
		return
	if state == State.FUTURE:
		draw_arc(center, radius * 0.8, 0.0, TAU, 24, SLOT, 1.5, true)
		return
	var earned := state == State.EARNED
	draw_circle(center, radius, RIM_GOLD if earned else RIM_GREY)
	draw_circle(center, radius * 0.78, FACE_GOLD if earned else FACE_GREY)
	if earned:
		# Geprägter Innenring.
		draw_arc(center, radius * 0.5, 0.0, TAU, 24, RIM_GOLD, 1.5, true)
	if is_today:
		draw_arc(center, radius, 0.0, TAU, 32, TODAY_RING, 2.0, true)
