extends GdUnitTestSuite
## Der Beutel einer Testliste (TestPlaylist): jedes Wort einmal je Runde, Fehler zurück in
## den Beutel, die vorige Welle hinten.


func _seen(times: Dictionary) -> Callable:
	return func(id): return int(times.get(id, 0))


func _correct(results: Dictionary) -> Callable:
	return func(id): return bool(results.get(id, false))


func test_a_word_is_played_once_its_latest_answer_since_round_start_was_right() -> void:
	var words := {"new": ["new.a"], "right": ["right.a", "right.b"], "wrong": ["wrong.a"],
			"old": ["old.a"], "fixed": ["fixed.a", "fixed.b"]}
	var seen := {"right.a": 150, "wrong.a": 150, "old.a": 50, "fixed.a": 120, "fixed.b": 160}
	var correct := {"right.a": true, "wrong.a": false, "old.a": true, "fixed.a": false,
			"fixed.b": true}
	var open := TestPlaylist.unplayed(words, _seen(seen), _correct(correct), 100)
	open.sort()
	# „old" war vor der Runde richtig, „wrong" zuletzt falsch, „fixed" zuletzt richtig.
	assert_array(open).is_equal(["new", "old", "wrong"])


func test_a_wrong_answer_after_a_right_one_puts_the_word_back() -> void:
	var words := {"w": ["w.a", "w.b"]}
	var open := TestPlaylist.unplayed(words, _seen({"w.a": 110, "w.b": 130}),
			_correct({"w.a": true, "w.b": false}), 100)
	assert_array(open).is_equal(["w"])


func test_wave_order_puts_the_bag_first_and_the_previous_wave_last() -> void:
	for i in 20:
		var order := TestPlaylist.wave_order(["a", "b", "c"], ["a", "b", "c", "d", "e"],
				{"a": 0, "d": 1})
		assert_array(order.slice(0, 3)).contains_exactly_in_any_order(["a", "b", "c"])
		assert_str(str(order[2])).is_equal("a")
		assert_array(order.slice(3)).is_equal(["e", "d"])


func test_arrange_follows_the_order_word_by_word() -> void:
	var listing := [
		{"source": {"id": "x"}, "learnable_id": "x.1", "repeat": false},
		{"source": {"id": "y"}, "learnable_id": "y.1", "repeat": false},
		{"source": {"id": "x"}, "learnable_id": "x.2", "repeat": false},
		{"source": {"id": "z"}, "learnable_id": "z.1", "repeat": true},
		{"source": {"id": "w"}, "learnable_id": "w.1", "repeat": false},
	]
	var out := TestPlaylist.arrange(listing, ["z", "y", "x"])
	# z war in dieser Welle schon dran, w hat keinen Platz in der Playlist.
	assert_array(out.map(func(c): return c["learnable_id"])).is_equal(
			["y.1", "x.1", "x.2", "w.1", "z.1"])
