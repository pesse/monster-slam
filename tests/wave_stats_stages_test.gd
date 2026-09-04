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
	# Zahlen links, Kiste rechts — beides ist das Ergebnis derselben Welle.
	assert_int((_stats.get_node("%Lines") as VBoxContainer).get_child_count()).is_equal(7)
	assert_bool(_visible("Reward")).is_true()


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


## Ohne besiegtes Monster gibt es nichts zu holen: die Kiste bleibt weg, und der Weg
## weiter ist offen.
func test_a_wave_without_gold_has_no_chest() -> void:
	_stats.show_stats(_wave_data({
		"correct": 0, "leaked": 3, "score_gained": 0,
		"chest": ChestReward.for_wave(0, 0, 3),
	}))
	assert_bool(_visible("Reward")).is_false()
	assert_bool(_button("ResultContinue").disabled).is_false()
	assert_bool(_button("MenuButton").disabled).is_false()


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
