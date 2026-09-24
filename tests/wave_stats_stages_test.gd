extends GdUnitTestSuite
## Der Wellenabschluss in zwei Stufen: Ergebnis (Statistik + Schatzkiste) → nächste Welle.
##
## Geprüft wird der Ablauf, nicht das Aussehen: welche Stufe wann sichtbar ist, dass an
## einer ungeöffneten Kiste kein Weg vorbeiführt, dass die Kiste ausfällt, wenn nichts zu
## holen ist — und dass der Screen beim Weiterblättern seine Größe behält.
##
## Wallet ist Autoload und damit die echte Geldbörse des Spielers: dieser Test darf sie
## nur lesen. Er kommt deshalb ohne earn() aus — das Signal reicht als Beweis.

const STATS_SCENE := preload("res://scenes/ui/wave_stats.tscn")

var _stats: PanelContainer


func before_test() -> void:
	_stats = auto_free(STATS_SCENE.instantiate()) as PanelContainer
	add_child(_stats)


func _wave_data(extra := {}) -> Dictionary:
	var data := {
		"won": true, "wave_number": 2, "difficulty": 3,
		"correct": 5, "leaked": 0, "total": 5, "accuracy": 100.0,
		"score_gained": 60, "score_total": 60, "fortress_health": 100,
		"mastered": 1, "fortress_tier": 1,
		"chest": ChestReward.for_wave(60, 5, 0),
	}
	data.merge(extra, true)
	return data


func _visible(node_name: String) -> bool:
	return (_stats.get_node("%" + node_name) as Control).visible


func _button(node_name: String) -> Button:
	return _stats.get_node("%" + node_name) as Button


func test_statistics_and_chest_share_the_first_stage() -> void:
	_stats.show_stats(_wave_data())
	assert_bool(_visible("ResultPage")).is_true()
	assert_bool(_visible("NextPage")).is_false()
	# Zahlen links, Kiste rechts — beides ist das Ergebnis derselben Welle. Acht Zeilen
	# ohne Aufstieg (der bringt eine neunte, siehe wave_stats.gd).
	assert_int((_stats.get_node("%Lines") as VBoxContainer).get_child_count()).is_equal(8)
	assert_bool(_visible("Reward")).is_true()


## Der Aufstieg bekommt eine eigene Zeile, aber nur wenn es einen gab: die Zeile ist die
## Feier, und ohne Aufstieg gibt es nichts zu feiern. Entschieden wird das in show_stats
## — vor dem Anzeigen, denn ab dann steht die Größe des Screens fest.
func test_the_level_up_line_appears_only_after_a_level_up() -> void:
	var lines := _stats.get_node("%Lines") as VBoxContainer
	_stats.show_stats(_wave_data({"xp_gained": 40, "levels_gained": 0}))
	var without := lines.get_child_count()
	_stats.show_stats(_wave_data({"xp_gained": 40, "levels_gained": 1}))
	assert_int(lines.get_child_count()).is_equal(without + 1)


## Solange die Kiste zu ist, sind Weiter und Menü GESPERRT (nicht ausgeblendet — ein
## verschwindender Knopf würde den Screen springen lassen).
func test_a_closed_chest_locks_the_way_on() -> void:
	_stats.show_stats(_wave_data())
	assert_bool(_button("ResultContinue").disabled).is_true()
	assert_bool(_button("MenuButton").disabled).is_true()


func test_opening_the_chest_reports_the_gold_and_unlocks_the_way_on() -> void:
	var collected: Array = []
	_stats.reward_collected.connect(func(gold: int) -> void: collected.append(gold))
	var data := _wave_data()
	_stats.show_stats(data)
	var chest := _stats.get_node("%Chest") as TreasureChest
	chest.begin_hold()
	chest.hold(TreasureChest.HOLD_TIME)
	assert_array(collected).is_equal([int(data["chest"]["gold"])])
	assert_bool(_button("ResultContinue").disabled).is_false()
	assert_bool(_button("MenuButton").disabled).is_false()
	# Die Aufforderung an der Kiste wird zur Quittung — dieselbe Zeile, neuer Text.
	assert_str((_stats.get_node("%RewardLine") as Label).text).contains("+")
	_button("ResultContinue").pressed.emit()
	assert_bool(_visible("NextPage")).is_true()


## Ohne besiegtes Monster gibt es keine Kiste, aber an ihrem Platz ein Trostwort mit einem
## Goldstück — ohne etwas zu öffnen, der Weg weiter ist also offen.
func test_a_wave_without_gold_has_a_consolation_instead_of_a_chest() -> void:
	var collected: Array[int] = []
	_stats.consolation_collected.connect(func(gold: int) -> void: collected.append(gold))
	_stats.show_stats(_wave_data({
		"correct": 0, "leaked": 3, "score_gained": 0,
		"chest": ChestReward.for_wave(0, 0, 3),
	}))
	assert_bool(_visible("Reward")).is_true()
	assert_bool(_visible("ChestRow")).is_false()
	assert_str((_stats.get_node("%ChestName") as Label).text).contains("aller Anfang ist schwer")
	assert_str((_stats.get_node("%RewardLine") as Label).text).is_equal("+1 Gold")
	assert_array(collected).is_equal([ChestReward.CONSOLATION_GOLD])
	assert_bool(_button("ResultContinue").disabled).is_false()
	assert_bool(_button("MenuButton").disabled).is_false()


## Mit Kiste kein Trostgold dazu, und die Kiste steht wieder da.
func test_a_chest_brings_no_consolation() -> void:
	var collected: Array[int] = []
	_stats.consolation_collected.connect(func(gold: int) -> void: collected.append(gold))
	_stats.show_stats(_wave_data({"chest": ChestReward.for_wave(0, 0, 3)}))
	_stats.show_stats(_wave_data())
	assert_bool(_visible("ChestRow")).is_true()
	assert_str((_stats.get_node("%ChestName") as Label).text).is_equal("Goldkiste")
	assert_array(collected).is_equal([ChestReward.CONSOLATION_GOLD])


## Auch eine verlorene Welle bringt die Kiste: verdient ist verdient.
func test_a_lost_wave_still_has_its_chest() -> void:
	_stats.show_stats(_wave_data({"won": false, "correct": 4, "leaked": 6, "score_gained": 40,
			"chest": ChestReward.for_wave(40, 4, 6)}))
	assert_bool(_visible("Reward")).is_true()


## Die nächste Welle wird erst aus der zweiten Stufe gerufen, und die Wahl ist relativ.
func test_the_next_wave_is_requested_with_a_relative_choice() -> void:
	var deltas: Array = []
	_stats.next_wave_requested.connect(func(delta: int) -> void: deltas.append(delta))
	_stats.show_stats(_wave_data({"chest": {}}))
	_button("ResultContinue").pressed.emit()
	var row := _stats.get_node("%ChoiceRow") as HBoxContainer
	(row.get_child(4) as Button).pressed.emit()
	_button("StartButton").pressed.emit()
	assert_array(deltas).is_equal([2])


## Eine neu gezeigte Welle beginnt wieder beim Ergebnis — sonst stünde nach dem
## Wellenende die Wahl der vorigen da.
func test_a_new_wave_starts_at_the_result_again() -> void:
	_stats.show_stats(_wave_data({"chest": {}}))
	_button("ResultContinue").pressed.emit()
	_stats.show_stats(_wave_data({"wave_number": 3}))
	assert_bool(_visible("ResultPage")).is_true()
	assert_bool((_stats.get_node("%Chest") as TreasureChest).is_open()).is_false()


## Der Kern der Sache: beim Weiterblättern darf sich die Größe nicht ändern. Der Screen
## hängt in der Bildmitte — jede Änderung verschiebt auch die Knöpfe.
func test_the_screen_keeps_its_size_across_stages() -> void:
	_stats.show_stats(_wave_data())
	var chest := _stats.get_node("%Chest") as TreasureChest
	chest.begin_hold()
	chest.hold(TreasureChest.HOLD_TIME)
	await get_tree().process_frame
	await get_tree().process_frame
	var before := _stats.size
	_button("ResultContinue").pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_vector(_stats.size).is_equal(before)


# --- Sitzungsbilanz (Issue #12) -------------------------------------------------

func _balance(words := 0, comebacks := 0) -> Dictionary:
	var list: Array = []
	for i in words:
		list.append({"label": "wort-%02d" % i, "misses": 4 if i < comebacks else 0,
				"comeback": i < comebacks})
	return {"waves_cleared": 3, "wave_reached": 4, "answers": 63, "correct": 51,
			"mastered": words, "comeback": comebacks, "words": list}


func _balance_texts() -> Array:
	return (_stats.get_node("%BalanceLines") as VBoxContainer).get_children() \
			.map(func(l): return (l as Label).text)


## Die Bilanz steht auf Stufe 2 — nach einem Sieg über der Wahl, damit sie auch beim
## Rückweg ins Menü schon zu sehen war.
func test_the_balance_sits_on_the_second_stage() -> void:
	_stats.show_stats(_wave_data({"chest": {}, "session": _balance(2)}))
	_button("ResultContinue").pressed.emit()
	assert_bool(_visible("Balance")).is_true()
	assert_bool(_visible("StartButton")).is_true()


## Ohne Sitzung (Tests, Werkbank) keine Bilanz — und keine leere Überschrift.
func test_without_a_session_there_is_no_balance() -> void:
	_stats.show_stats(_wave_data({"chest": {}}))
	assert_bool(_visible("Balance")).is_false()


func test_the_balance_names_counts_and_comebacks() -> void:
	_stats.show_stats(_wave_data({"session": _balance(2, 1)}))
	var texts := _balance_texts()
	assert_str(str(texts[0])).contains("3").contains("Welle 4")
	assert_str(str(texts[1])).contains("63").contains("51")
	assert_str(str(texts[2])).contains("2").contains("1 zurückerobert")
	assert_str(str(texts[3])).contains("wort-00").contains("4×")
	assert_str(str(texts[4])).contains("wort-01")


## Höchstens BALANCE_WORDS Zeilen für Wörter: der Überhang wird zur Zahl und nimmt die
## letzte Zeile, statt eine anzuhängen — der Screen scrollt nicht.
func test_a_long_word_list_is_capped() -> void:
	_stats.show_stats(_wave_data({"session": _balance(12)}))
	var texts := _balance_texts()
	var cap: int = _stats.BALANCE_WORDS
	# Drei Zählzeilen, dann die Wörter.
	assert_int(texts.size()).is_equal(3 + cap)
	assert_str(str(texts.back())).contains("%d weitere" % (12 - cap + 1))


## Genau BALANCE_WORDS Wörter passen ohne „weitere".
func test_a_full_list_needs_no_overflow_line() -> void:
	_stats.show_stats(_wave_data({"session": _balance(4)}))
	assert_int(_balance_texts().size()).is_equal(3 + 4)
	assert_str(str(_balance_texts().back())).not_contains("weitere")
