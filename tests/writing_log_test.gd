extends GdUnitTestSuite
## Abgaben beim Schreib-Boss (ADR 0023, §7): gespeichert wird der Verbrauch, gerechnet
## werden die Kosten. Auf einem `zz-`-Profil, die Datei wird weggeräumt.

const PROFILE := "zz-writing-log-test"


func before_test() -> void:
	_remove()


func after_test() -> void:
	_remove()


func _remove() -> void:
	DirAccess.remove_absolute(WritingLog.path(PROFILE))


func _entry(at: int, tokens_in := 1000, tokens_out := 500) -> Dictionary:
	return {"at": at, "boss": "boss.rambler", "task": "writing.zz.summary_01", "round": 1,
			"model": "claude-opus-5-5", "in": tokens_in, "out": tokens_out, "cr": 0, "cw": 0,
			"s": 5.5, "met": ["intro", "length"], "words": 100}


func test_empty_without_file() -> void:
	assert_array(WritingLog.entries(PROFILE)).is_empty()
	assert_float(WritingLog.cost_usd([])).is_equal(0.0)


func test_record_appends_in_order() -> void:
	WritingLog.record(_entry(100), PROFILE)
	WritingLog.record(_entry(200), PROFILE)
	var all := WritingLog.entries(PROFILE)
	assert_int(all.size()).is_equal(2)
	assert_int(int(all[0]["at"])).is_equal(100)
	assert_int(int(all[1]["at"])).is_equal(200)
	assert_str(str(all[1]["model"])).is_equal("claude-opus-5-5")


func test_only_contract_fields_are_stored() -> void:
	var entry := _entry(100)
	entry["text"] = "Der Text des Kindes"
	entry["key"] = "sk-ant-geheim"
	entry["cost"] = 0.5
	WritingLog.record(entry, PROFILE)
	var raw := FileAccess.get_file_as_string(WritingLog.path(PROFILE))
	assert_bool(raw.contains("Der Text")).is_false()
	assert_bool(raw.contains("sk-ant")).is_false()
	# Kein Betrag — der wird gerechnet.
	assert_bool(raw.contains("cost")).is_false()


func test_missing_time_means_now() -> void:
	var entry := _entry(0)
	entry.erase("at")
	var before := int(Time.get_unix_time_from_system())
	WritingLog.record(entry, PROFILE)
	assert_int(int(WritingLog.entries(PROFILE)[0]["at"])).is_greater_equal(before)


func test_cost_is_the_sum_of_model_prices() -> void:
	var list := [_entry(100), _entry(200, 2000, 100)]
	var expected := ModelPrices.cost_usd(list[0]) + ModelPrices.cost_usd(list[1])
	assert_float(WritingLog.cost_usd(list)).is_equal_approx(expected, 0.0000001)
	assert_float(WritingLog.cost_usd(list)).is_greater(0.0)


func test_since_keeps_entries_from_the_start_on() -> void:
	var list := [_entry(100), _entry(200), _entry(300)]
	assert_int(WritingLog.since(list, 200).size()).is_equal(2)
	assert_int(WritingLog.since(list, 301).size()).is_equal(0)


func test_recent_cost_counts_only_the_last_days() -> void:
	var now := int(Time.get_unix_time_from_system())
	WritingLog.record(_entry(now - 40 * 86400), PROFILE)
	WritingLog.record(_entry(now - 86400), PROFILE)
	assert_float(WritingLog.recent_cost_usd(PROFILE)).is_equal_approx(
			ModelPrices.cost_usd(_entry(now - 86400)), 0.0000001)
