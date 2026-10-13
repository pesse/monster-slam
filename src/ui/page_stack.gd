class_name PageStack
extends Container
## Container für Seiten, von denen immer nur eine sichtbar ist; er bleibt so groß wie die
## größte, auch die unsichtbaren zählen mit (CONVENTIONS „Oberfläche“: ein Screen in der
## Bildmitte ändert seine Größe nicht). Welche Seite sichtbar ist, schaltet der Aufrufer.


func _ready() -> void:
	_watch_children()
	# Seiten, die erst zur Laufzeit dazukommen, ebenfalls beobachten.
	child_entered_tree.connect(func(_node: Node) -> void: _watch_children())


## Seiten können nach dem Laden noch wachsen, etwa beim Befüllen.
func _watch_children() -> void:
	for child in get_children():
		var page := child as Control
		if page != null and not page.minimum_size_changed.is_connected(_on_page_resized):
			page.minimum_size_changed.connect(_on_page_resized)


func _on_page_resized() -> void:
	update_minimum_size()
	queue_sort()


func _get_minimum_size() -> Vector2:
	var out := Vector2.ZERO
	for child in get_children():
		var page := child as Control
		if page == null:
			continue
		# Ohne Sichtbarkeitsprüfung, das ist der Zweck des Stapels.
		out = out.max(page.get_combined_minimum_size())
	return out


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		for child in get_children():
			var page := child as Control
			if page != null:
				fit_child_in_rect(page, Rect2(Vector2.ZERO, size))
