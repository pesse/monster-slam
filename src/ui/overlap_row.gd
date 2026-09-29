@tool
class_name OverlapRow
extends Container
## Legt die Kinder in ihrer Mindestgröße nebeneinander, jedes um `overlap` Pixel in das
## vorige geschoben und senkrecht mittig. Für Rahmen, die ineinandergreifen (die
## Festungsanzeige der Gebietskarte): die Überlappung verdeckt die doppelte Kante, wo zwei
## Rahmen sich treffen. Vorn liegt, was später kommt — ein Kind, das vor seinem Nachfolger
## liegen soll, bekommt `z_index = 1`.
##
## Kein Abstand im Sinne der Abstands-Skala: `overlap` misst die Kante der Grafik, nicht
## Luft zwischen Inhalten.

@export var overlap := 24:
	set(value):
		overlap = value
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
	return out
