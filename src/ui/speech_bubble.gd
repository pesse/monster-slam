class_name SpeechBubble
extends PanelContainer
## Eine Sprechblase: der Kasten kommt aus dem Theme (`BossBubble`, `PlayerBubble`), die
## Spitze zeichnet die Blase selbst, in Füllung und Rand ihres eigenen Panel-Stils.
##
## Die Spitze zeigt entweder in eine feste Richtung (`tail_direction`) oder auf einen Punkt
## am Bildschirm (`point_at`) — im Bosskampf auf den Kopf des Skeletts, das dabei hin und
## her läuft. Die Blase selbst bleibt, wo das Layout sie hinstellt; nur die Spitze wandert.
##
## `pop()` lässt sie kurz aufploppen. Das geht über `scale`, nicht über die Größe: das
## Layout rechnet mit der Blase, als stünde sie still.

## Wie weit die Spitze aus dem Kasten ragt.
@export var tail_length := 28.0
## Wie breit sie am Kasten ansetzt.
@export var tail_width := 32.0
## Wohin sie zeigt, solange niemand `point_at` gerufen hat.
@export var tail_direction := Vector2.DOWN

var _target := Vector2.INF
var _pop: Tween


## Richtet die Spitze auf einen Punkt in globalen Canvas-Koordinaten.
func point_at(global_point: Vector2) -> void:
	if global_point.is_equal_approx(_target):
		return
	_target = global_point
	queue_redraw()


## Kurzes Aufploppen, zur Spitze hin verankert — so sieht es aus, als käme die Blase aus
## dem Mund dessen, der spricht.
func pop() -> void:
	if _pop != null:
		_pop.kill()
	var tail := _tail()
	pivot_offset = tail[1] if not tail.is_empty() else size / 2.0
	scale = Vector2.ONE * 0.8
	_pop = create_tween()
	_pop.tween_property(self, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Ein Zappeln, solange der Sprecher nachdenkt. `on` = false stellt die Blase gerade.
func wobble(on: bool) -> void:
	if _pop != null:
		_pop.kill()
	pivot_offset = size / 2.0
	if not on:
		_pop = create_tween()
		_pop.tween_property(self, "scale", Vector2.ONE, 0.15)
		return
	_pop = create_tween().set_loops()
	_pop.tween_property(self, "scale", Vector2(1.02, 0.98), 0.3).set_trans(Tween.TRANS_SINE)
	_pop.tween_property(self, "scale", Vector2(0.98, 1.02), 0.3).set_trans(Tween.TRANS_SINE)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var tail := _tail()
	if tail.is_empty():
		return
	var box := get_theme_stylebox("panel") as StyleBoxFlat
	if box == null:
		return
	draw_colored_polygon(PackedVector2Array(tail), box.bg_color)
	var border := float(box.border_width_bottom)
	if border > 0.0:
		draw_polyline(PackedVector2Array(tail), box.border_color, border, true)


## Die Spitze als [Ansatz links, Spitze, Ansatz rechts] in lokalen Koordinaten — oder leer,
## wenn das Ziel im Kasten liegt.
func _tail() -> Array:
	var box := Rect2(Vector2.ZERO, size)
	if box.size.x <= 0.0 or box.size.y <= 0.0:
		return []
	var dir := tail_direction.normalized()
	var aim := box.get_center() + dir * (box.size.length() + tail_length)
	if _target != Vector2.INF:
		aim = get_global_transform().affine_inverse() * _target
		if box.has_point(aim):
			return []
	# Welche Kante: die, über die das Ziel am weitesten hinausliegt.
	var out := Vector2(
			maxf(box.position.x - aim.x, aim.x - box.end.x),
			maxf(box.position.y - aim.y, aim.y - box.end.y))
	var margin := tail_width + 16.0
	var base: Vector2
	var along: Vector2
	if out.y >= out.x:
		var y := box.end.y if aim.y > box.end.y else box.position.y
		base = Vector2(clampf(aim.x, margin, maxf(margin, box.size.x - margin)), y)
		along = Vector2.RIGHT
	else:
		var x := box.end.x if aim.x > box.end.x else box.position.x
		base = Vector2(x, clampf(aim.y, margin, maxf(margin, box.size.y - margin)))
		along = Vector2.DOWN
	# Ein Stück in den Kasten hinein ansetzen, damit der Rand des Kastens an der Spitze
	# verschwindet — die Füllung der Spitze deckt ihn zu.
	var inward := (box.get_center() - base).normalized() * 3.0
	var half := along * tail_width / 2.0
	var tip := base + (aim - base).limit_length(tail_length)
	return [base - half + inward, tip, base + half + inward]
