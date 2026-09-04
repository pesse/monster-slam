extends GdUnitTestSuite
## Der Seiten-Stapel: seine Mindestgröße ist die GRÖSSTE Seite, auch wenn die gerade
## unsichtbar ist.
##
## Der Grund für den Test: genau daran hängt, dass der Wellenabschluss beim Weiterblättern
## nicht in der Größe springt. Ein VBox/Panel rechnet nur mit den sichtbaren Kindern —
## dass hier alle zählen, ist die ganze Existenzberechtigung des Containers.

const PAGE_STACK := preload("res://src/ui/page_stack.gd")


func _stack(sizes: Array, visible_index: int) -> PageStack:
	var stack: PageStack = auto_free(PAGE_STACK.new())
	add_child(stack)
	for i in sizes.size():
		var page := Control.new()
		page.custom_minimum_size = sizes[i]
		page.visible = i == visible_index
		stack.add_child(page)
	return stack


func test_minimum_size_is_the_largest_page() -> void:
	var stack := _stack([Vector2(200, 100), Vector2(120, 300)], 0)
	assert_vector(stack.get_combined_minimum_size()).is_equal(Vector2(200, 300))


## Dieselbe Größe, egal welche Seite dran ist — sonst wäre der Stapel wirkungslos.
func test_the_size_does_not_depend_on_which_page_is_visible() -> void:
	var first := _stack([Vector2(200, 100), Vector2(120, 300)], 0)
	var second := _stack([Vector2(200, 100), Vector2(120, 300)], 1)
	assert_vector(second.get_combined_minimum_size()).is_equal(first.get_combined_minimum_size())


## Eine Seite, die zur Laufzeit wächst (die Statistik bekommt ihre Zeilen erst beim
## Befüllen), zieht die Mindestgröße mit.
func test_a_growing_page_raises_the_minimum() -> void:
	var stack := _stack([Vector2(200, 100)], 0)
	(stack.get_child(0) as Control).custom_minimum_size = Vector2(200, 480)
	assert_vector(stack.get_combined_minimum_size()).is_equal(Vector2(200, 480))


## Die Seiten liegen übereinander und bekommen die ganze Fläche — ein Stapel, kein Fluss.
func test_pages_fill_the_whole_stack() -> void:
	var stack := _stack([Vector2(200, 100), Vector2(120, 300)], 0)
	stack.size = Vector2(400, 500)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_vector((stack.get_child(0) as Control).size).is_equal(Vector2(400, 500))
	assert_vector((stack.get_child(1) as Control).size).is_equal(Vector2(400, 500))
