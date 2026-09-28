class_name OffscreenMarkers
extends Control
## Pfeile am Bildrand für Monster, die in der Ich-Sicht gerade nicht im Bild sind. Ohne sie
## weiß der Spieler nicht, wohin er sich drehen muss — und treffen kann er nur, was er sieht
## (FirstPersonView.sees). Farbe je Wortart wie die Outline am Monster (WordTypePalette).
##
## Nur Anzeige: liest die Kamera und die Liste der aktiven Monster, schreibt nichts.

const ARROW := 20.0

var _camera: Camera3D = null
var _monsters := Callable()


## `monsters` liefert die aktiven Monster (Array[Monster]) — eine Callable statt einer
## Kopie, weil die Liste sich mit jedem Spawn und Treffer ändert.
func track(camera: Camera3D, monsters: Callable) -> void:
	_camera = camera
	_monsters = monsters


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if _camera == null or not _monsters.is_valid():
		return
	var rect := Rect2(Vector2.ZERO, size).grow(-ARROW * 2.0)
	# Ungetypt durchlaufen: ein eben freigegebenes Monster in einer getypten Variablen wäre
	# ein Laufzeitfehler, bevor is_instance_valid es aussortieren kann.
	for entry in _monsters.call():
		if not is_instance_valid(entry):
			continue
		var monster := entry as Monster
		var point := monster.global_position + Vector3(0.0, 1.5, 0.0)
		if FirstPersonView.sees(_camera, point):
			continue
		var dir := edge_direction(_camera, point)
		var tip := edge_point(rect, dir)
		var color := WordTypePalette.color_for(str(monster.task.get("lexeme_type", "")))
		var side := Vector2(-dir.y, dir.x) * ARROW * 0.6
		draw_colored_polygon(PackedVector2Array([tip, tip - dir * ARROW + side,
				tip - dir * ARROW - side]), color)


## Richtung vom Bildmittelpunkt zum Punkt, in Bildkoordinaten (y nach unten). Ein Punkt
## HINTER der Kamera zeigt zur Seite, auf der er liegt, statt gespiegelt nach vorn.
static func edge_direction(camera: Camera3D, point: Vector3) -> Vector2:
	var local := camera.global_transform.affine_inverse() * point
	var dir := Vector2(local.x, -local.y)
	if local.z > 0.0:
		# Hinter dem Rücken: die Höhe sagt nichts, links oder rechts ist die Auskunft.
		dir = Vector2(signf(local.x) if not is_zero_approx(local.x) else 1.0, 0.3)
	if dir.is_zero_approx():
		return Vector2.DOWN
	return dir.normalized()


## Der Punkt, an dem ein Strahl aus der Mitte von `rect` in Richtung `dir` den Rand trifft.
static func edge_point(rect: Rect2, dir: Vector2) -> Vector2:
	var center := rect.get_center()
	var half := rect.size * 0.5
	var tx := INF if is_zero_approx(dir.x) else half.x / absf(dir.x)
	var ty := INF if is_zero_approx(dir.y) else half.y / absf(dir.y)
	return center + dir * minf(tx, ty)
