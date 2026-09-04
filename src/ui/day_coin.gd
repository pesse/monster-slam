class_name DayCoin
extends Control
## Die Münze der Tages-Leiste: geübt (gold), verpasst (grau), heute noch offen oder ein
## leerer Platz für einen Tag, der erst kommt. Sie markiert einen TAG und ist keine
## Währung — das Gold der Geldbörse (Wallet) zählt in Beträgen, nicht in Tagen.
##
## Gezeichnet statt als Sprite, weil es kein Münz-Asset gibt und ein späteres Einsammeln
## so ein Tween über Größe und Position ist — ohne Asset-Pipeline und in jeder Größe
## scharf. Die Größe steht in day_coin.tscn (im Editor änderbar), hier nur die Zustände.
##
## Dieselbe Zeichnung fliegt als verdiente Münze aus der Schatzkiste (siehe
## TreasureChest): Gold sieht im Spiel überall gleich aus. Der Vorrat der Leiste selbst
## ist SessionLog.played_day_count().

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
## Leerer Platz: nur ein dünner Ring, damit der Monat als Rahmen sichtbar ist, ohne dass
## künftige Tage wie versäumte aussehen.
const SLOT := Color(0.3, 0.3, 0.34)
## Bernstein wie die Hinweistexte im Startmenü: markiert den heutigen Tag.
const TODAY_RING := Color(1.0, 0.8, 0.35)

var state: State = State.MISSED
var is_today := false


func setup(new_state: State, today: bool, hover_text: String) -> void:
	state = new_state
	is_today = today
	tooltip_text = hover_text
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
		# Geprägter Innenring — lässt die Scheibe als Münze lesen und nicht als Punkt.
		draw_arc(center, radius * 0.5, 0.0, TAU, 24, RIM_GOLD, 1.5, true)
	if is_today:
		draw_arc(center, radius, 0.0, TAU, 32, TODAY_RING, 2.0, true)
