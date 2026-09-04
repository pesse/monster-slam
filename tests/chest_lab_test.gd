extends GdUnitTestSuite
## Die Schatzkisten-Werkbank (scenes/dev/chest_lab.tscn) muss sich bauen lassen und ihre
## Bedienelemente über die eindeutigen Namen finden — genau das geht in einer
## handgeschriebenen .tscn leicht schief, und eine kaputte Werkbank fällt sonst erst dann
## auf, wenn man sie zum Beurteilen der Kiste gerade braucht.
##
## Geprüft wird nur der Aufbau plus der Weg von der Wellen-Rechnung zur Kiste. Die
## Werkbank verbucht nichts, also kann der Test sie ohne Rücksicht bedienen.

const LAB_SCENE := preload("res://scenes/dev/chest_lab.tscn")

var _lab: Control


func before_test() -> void:
	_lab = auto_free(LAB_SCENE.instantiate()) as Control
	add_child(_lab)


func test_the_lab_builds_with_all_its_controls() -> void:
	for unique_name in ["Chest", "ChestTitle", "Status", "TierSelect", "GoldSpin",
			"CoinSpin", "ModelToggle", "HoldSlider", "HoldLabel", "PresentButton",
			"OpenButton",
			"ScoreSpin", "CorrectSpin", "LeakedSpin", "WaveButton", "WaveResult",
			"BackButton"]:
		assert_object(_lab.get_node("%" + unique_name)).override_failure_message(
				"Werkbank findet '%s' nicht" % unique_name).is_not_null()


## Alle Güten stehen zur Wahl — die Werkbank ist der Ort, an dem man sie vergleicht.
func test_every_tier_can_be_chosen() -> void:
	assert_int((_lab.get_node("%TierSelect") as OptionButton).item_count) \
			.is_equal(ChestReward.TIER_NAMES.size())


## Der Knopf lässt die Kiste ohne Drücken aufspringen — sonst wäre der Münzflug nur nach
## zwei Sekunden Halten zu sehen.
func test_the_open_button_bursts_the_chest() -> void:
	(_lab.get_node("%OpenButton") as Button).pressed.emit()
	assert_bool((_lab.get_node("%Chest") as TreasureChest).is_open()).is_true()


## Der Umschalter stellt die Kiste wirklich um — er ist der Grund, aus dem die
## gezeichnete Fassung überhaupt noch dasteht.
func test_the_toggle_switches_between_model_and_drawing() -> void:
	var chest := _lab.get_node("%Chest") as TreasureChest
	var toggle := _lab.get_node("%ModelToggle") as CheckButton
	assert_object(chest.model()).is_not_null()
	toggle.toggled.emit(false)
	assert_object(chest.model()).is_null()
	toggle.toggled.emit(true)
	assert_object(chest.model()).is_not_null()


## „Belohnung berechnen" nimmt die Rechnung des Spiels und stellt die Kiste daraus hin.
func test_the_wave_block_builds_the_chest_the_game_would_give() -> void:
	(_lab.get_node("%ScoreSpin") as SpinBox).value = 100.0
	(_lab.get_node("%CorrectSpin") as SpinBox).value = 8.0
	(_lab.get_node("%LeakedSpin") as SpinBox).value = 0.0
	(_lab.get_node("%WaveButton") as Button).pressed.emit()
	var expected := ChestReward.for_wave(100, 8, 0)
	assert_int((_lab.get_node("%TierSelect") as OptionButton).get_selected_id()) \
			.is_equal(int(expected["tier"]))
	assert_int(int((_lab.get_node("%GoldSpin") as SpinBox).value)).is_equal(int(expected["gold"]))
	assert_str((_lab.get_node("%ChestTitle") as Label).text).is_equal(str(expected["name"]))
