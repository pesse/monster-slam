@tool
class_name OverlapRow
extends Container
## Legt die Kinder in ihrer Mindestgröße nebeneinander, jedes um `overlap` px in das vorige
## geschoben und senkrecht mittig, für ineinandergreifende Rahmen. Vorn liegt, was im Baum
## später kommt; `order` ändert nur die Plätze von links. Kein `z_index`: der hebt das Teil
## auch über Fenster darüber. `overlap` misst die Grafik und gehört nicht zur Abstands-Skala.

@export var overlap := 24:
	set(value):
		overlap = value
		queue_sort()

## Namen der Kinder in ihrer Reihenfolge von links; leer heißt Baumreihenfolge. Nicht
## genannte Kinder folgen dahinter.
@export var order: PackedStringArray = []:
	set(value):
		order = value
		update_minimum_size()
		queue_sort()


func _get_minimum_size() -> Vector2:
	var total := Vector2.ZERO
	var count := 0
	for child in _parts():
		var min_size := child.get_combined_minimum_size()
		total.x += min_size.x
		total.y = maxf(total.y, min_size.y)
		count += 1
	total.x -= overlap * maxi(0, count - 1)
	return total


func _notification(what: int) -> void:
	if what != NOTIFICATION_SORT_CHILDREN:
		return
	var x := 0.0
	for child in _parts():
		var min_size := child.get_combined_minimum_size()
		fit_child_in_rect(child, Rect2(Vector2(x, (size.y - min_size.y) * 0.5), min_size))
		x += min_size.x - overlap


func _parts() -> Array[Control]:
	var out: Array[Control] = []
	for child in get_children():
		if child is Control and (child as Control).visible and not (child as Control).top_level:
			out.append(child)
	if order.is_empty():
		return out
	var rank := func(c: Control) -> int:
		var at := order.find(String(c.name))
		return at if at >= 0 else order.size() + c.get_index()
	out.sort_custom(func(a: Control, b: Control) -> bool: return rank.call(a) < rank.call(b))
	return out
