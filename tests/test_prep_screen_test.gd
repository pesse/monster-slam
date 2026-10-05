extends GdUnitTestSuite
## Der Screen „Für eine Arbeit üben" mit dem Inhalt des Entwicklungslaufs: Zeilen, Filter,
## Markieren und der Pool, den die Liste spielt. Speichert nichts.

const SCREEN := preload("res://scenes/ui/test_prep.tscn")


func after_test() -> void:
	RunRequest.start_expert()


func _book() -> String:
	var books := ContentRegistry.all_books()
	return books[0] if not books.is_empty() else ""


func test_marked_words_make_the_pool_and_the_picks_follow_the_playlist() -> void:
	var book := _book()
	if book.is_empty():
		return
	MapSelection.book = book
	var screen: TestPrep = auto_free(SCREEN.instantiate())
	add_child(screen)
	await await_idle_frame()
	assert_int(screen._rows.size()).is_greater(0)
	# Eine Unit filtern und alles Sichtbare markieren.
	_check_unit(screen, 0)
	screen._mark_visible(true)
	var list := screen._current_list()
	var ids: Array = list["lexeme_ids"]
	assert_int(ids.size()).is_greater(0)
	assert_bool(screen._play.disabled).is_false()
	RunRequest.start_test(list)
	assert_bool(RunRequest.is_test()).is_true()
	var pool := RunRequest.task_pool()
	var gen := WaveGenerator.new()
	var words := {}
	for c in gen.candidates(pool):
		words[str(c["source"].get("id", ""))] = true
	for id in words:
		assert_bool(id in ids).override_failure_message("%s nicht in der Liste" % id).is_true()
	var order := TestPlaylist.wave_order(words.keys(), words.keys(), {})
	var shown := {}
	var got: Array = []
	var n := mini(5, order.size())
	for k in n:
		var plan := gen.pick(pool, {}, shown, order)
		var source := str(plan["task"].get("source_id", ""))
		shown[source] = k
		got.append(source)
	assert_array(got).is_equal(order.slice(0, n))


func test_filters_hide_rows() -> void:
	var book := _book()
	if book.is_empty():
		return
	MapSelection.book = book
	var screen: TestPrep = auto_free(SCREEN.instantiate())
	add_child(screen)
	await await_idle_frame()
	screen._search.text = "zzzz-kein-wort"
	screen._apply_filter()
	var visible := screen._rows.filter(func(r): return (r["item"] as TreeItem).visible)
	assert_array(visible).is_empty()


func test_the_count_names_marked_words_a_filter_hides() -> void:
	var book := _book()
	if book.is_empty():
		return
	MapSelection.book = book
	var screen: TestPrep = auto_free(SCREEN.instantiate())
	add_child(screen)
	await await_idle_frame()
	var word: Dictionary = screen._rows.filter(func(r): return r["kind"] == "word")[0]
	screen._set_mark(word, true)
	screen._apply_filter()
	assert_str(screen._count.text).not_contains("ausgeblendet")
	screen._search.text = "zzzz-kein-wort"
	screen._apply_filter()
	assert_str(screen._count.text).contains("(1 ausgeblendet)")


## Setzt das Häkchen der Unit an Stelle `index` im Baum, wie ein Klick.
func _check_unit(screen: TestPrep, index: int) -> void:
	var unit: TreeItem = screen._places._tree.get_root().get_child(index)
	unit.set_checked(0, true)
	unit.propagate_check(0, false)
	screen._places.changed.emit()


func test_the_place_tree_filters_by_units_and_none_means_all() -> void:
	var book := _book()
	if book.is_empty():
		return
	MapSelection.book = book
	var screen: TestPrep = auto_free(SCREEN.instantiate())
	add_child(screen)
	await await_idle_frame()
	var shown := func() -> int:
		return screen._rows.filter(func(r): return (r["item"] as TreeItem).visible).size()
	var all: int = shown.call()
	_check_unit(screen, 0)
	var one: int = shown.call()
	assert_int(one).is_greater(0).is_less(all + 1)
	var first: TreeItem = screen._places._tree.get_root().get_child(0)
	assert_int(screen._places.values().size()).is_equal(first.get_child_count())
	if screen._places._tree.get_root().get_child_count() > 1:
		_check_unit(screen, 1)
		assert_int(shown.call()).is_greater(one)
	screen._places.clear_checks()
	assert_int(shown.call()).is_equal(all)


func test_check_menu_takes_several_values() -> void:
	var menu: CheckMenu = auto_free(CheckMenu.new())
	add_child(menu)
	menu.label = "Stand"
	menu.set_options([{"text": "neu", "value": 1}, {"text": "unsicher", "value": 2}])
	assert_str(menu.text).is_equal("Stand ▾")
	menu._on_id_pressed(0)
	menu._on_id_pressed(1)
	assert_array(menu.values()).is_equal([1, 2])
	assert_str(menu.text).is_equal("neu +1 ▾")
	menu._on_id_pressed(0)
	assert_array(menu.values()).is_equal([2])
