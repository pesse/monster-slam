extends GdUnitTestSuite
## Wächter für die eine Art, im Spiel etwas zu erklären: `Hints.attach()`.
##
## Der Grund für den Test ist derselbe wie bei der Theme-Disziplin: eine Konvention, die
## nur in der Dokumentation steht, hält nicht. Godots eigener Tooltip erscheint verzögert,
## bleibt stehen, wo er aufgegangen ist, und bringt die Typografie der Engine mit.
## Nebeneinander wären es zwei Auskünfte mit zwei Aussehen — und die zweite fällt nicht
## dem auf, der sie einbaut, sondern dem, der spielt.
##
## Das ist zugleich der Nachfolger der Projekteinstellung `gui/timers/tooltip_delay_sec`:
## sie stand auf 0, weil die Zeichen am Rand des Fähigkeiten-Screens ihre Erklärung
## ausschließlich im Tooltip trugen. Beides gibt es nicht mehr. Statt eine Einstellung zu
## prüfen, die nichts mehr steuert, wird hier der Grund geprüft.

const ROOTS := {"res://scenes": ".tscn", "res://src": ".gd"}


static func _collect(root: String, suffix: String, out: Array) -> void:
	var dir := DirAccess.open(root)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var path := root.path_join(entry)
		if dir.current_is_dir():
			_collect(path, suffix, out)
		elif entry.ends_with(suffix):
			out.append(path)
		entry = dir.get_next()
	dir.list_dir_end()
	out.sort()


func test_nothing_uses_godots_own_tooltip() -> void:
	var found: Array = []
	for root: String in ROOTS:
		var files: Array = []
		_collect(root, str(ROOTS[root]), files)
		for path: String in files:
			var lines := FileAccess.get_file_as_string(path).split("\n")
			for i in lines.size():
				var line := str(lines[i]).strip_edges()
				if line.begins_with("tooltip_text") or line.contains(".tooltip_text"):
					found.append("%s:%d: %s" % [path, i + 1, line])
	assert_array(found).override_failure_message(
			"Diese Stellen benutzen Godots eigenen Tooltip statt `Hints.attach()`:\n  "
			+ "\n  ".join(found)).is_empty()
