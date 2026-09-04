class_name PageStack
extends Container
## Container für Seiten, von denen immer nur EINE sichtbar ist — und der trotzdem so
## groß bleibt, wie die größte Seite ihn braucht.
##
## Der Grund: ein VBox/Panel rechnet seine Mindestgröße nur aus den SICHTBAREN Kindern.
## Beim Weiterblättern sprang der Wellenabschluss deshalb in der Größe (und damit, weil
## er in der Bildmitte hängt, auch in der Position) — der Knopf, auf den man gerade
## geklickt hat, war hinterher woanders.
##
## Hier zählen alle Kinder mit, auch die unsichtbaren: `_get_minimum_size` nimmt das
## Maximum, `fit_child_in_rect` legt jedes Kind über die volle Fläche. Das hält die
## Größe an der größten Seite fest, ohne sie als Pixelzahl in die Szene zu schreiben —
## eine Zeile mehr Statistik oder eine größere Schrift verschiebt sie mit.
##
## Sichtbar/unsichtbar schaltet der Aufrufer (siehe WaveStats._goto_stage): welche Seite
## dran ist, weiß der Stapel nicht.


func _ready() -> void:
	_watch_children()
	# Seiten, die erst zur Laufzeit dazukommen, ebenfalls beobachten.
	child_entered_tree.connect(func(_node: Node) -> void: _watch_children())


## Auf Größenänderungen der Kinder hören: die Statistik-Seite bekommt ihre Zeilen erst
## beim Befüllen (show_stats), ihre Mindestgröße steht also nicht schon beim Laden fest.
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
		# Bewusst OHNE Sichtbarkeitsprüfung — genau das ist der Zweck des Stapels.
		out = out.max(page.get_combined_minimum_size())
	return out


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		for child in get_children():
			var page := child as Control
			if page != null:
				fit_child_in_rect(page, Rect2(Vector2.ZERO, size))
