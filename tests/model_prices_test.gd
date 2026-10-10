extends GdUnitTestSuite
## Preistabelle (ADR 0023, §7): Kosten werden aus Token gerechnet, je Zeitpunkt aus der
## Zeile, die damals galt.


func test_opus_costs_follow_the_table() -> void:
	var entry := {"at": 1791526650, "model": "claude-opus-5-5",
			"in": 1000000, "out": 1000000, "cr": 1000000, "cw": 1000000}
	var row := ModelPrices.row("claude-opus-5-5", 1791526650)
	var expected := float(row["in"]) + float(row["out"]) + float(row["cache_read"]) \
			+ float(row["cache_write"])
	assert_float(ModelPrices.cost_usd(entry)).is_equal_approx(expected, 0.000001)


func test_a_typical_submission_costs_cents() -> void:
	var entry := {"at": 1791526650, "model": "claude-opus-5-5", "in": 1500, "out": 800,
			"cr": 0, "cw": 0}
	var cost := ModelPrices.cost_usd(entry)
	assert_float(cost).is_greater(0.0)
	assert_float(cost).is_less(0.1)


func test_unknown_model_costs_nothing_and_says_so() -> void:
	assert_bool(ModelPrices.known("zz-model")).is_false()
	assert_float(ModelPrices.cost_usd({"model": "zz-model", "in": 1000})).is_equal(0.0)
	assert_bool(ModelPrices.known(CloudModelBackend.MODEL)).is_true()


func test_an_entry_before_the_first_row_uses_the_first_row() -> void:
	assert_dict(ModelPrices.row("claude-opus-5-5", 0)).is_equal(
			ModelPrices.TABLE["claude-opus-5-5"][0])


func test_rows_are_sorted_and_complete() -> void:
	for model in ModelPrices.TABLE:
		var last := -1
		for r in ModelPrices.TABLE[model]:
			for field in ["from", "in", "out", "cache_read", "cache_write"]:
				assert_bool((r as Dictionary).has(field)).append_failure_message(
						"%s: Feld %s fehlt" % [model, field]).is_true()
			var from := ModelPrices._from_unix(str(r["from"]))
			assert_int(from).is_greater(last)
			last = from
