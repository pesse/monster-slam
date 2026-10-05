extends GdUnitTestSuite
## Zaubervorrat (Inventory, ADR 0014): kaufen, stapeln, Plätze, einsetzen, sichern.
##
## Auf EIGENEN Instanzen von Vorrat und Geldbörse mit `zz-`-Profil, nicht an den Autoloads —
## deren Dateien sind Vorrat und Gold des Spielers. Nicht im Szenenbaum, also kein _ready().

const INVENTORY := preload("res://src/economy/inventory.gd")
const WALLET := preload("res://src/economy/wallet.gd")
const TEST_PROFILE := "zz-inventory-test"
const OTHER_PROFILE := "zz-inventory-test-other"

const FROST := {"id": "zz.spell.frost", "price": 15}
const MEND := {"id": "zz.spell.mend", "price": 12}
const FREE := {"id": "zz.spell.free", "price": 0}

var _inv: Node
var _wallet: Node


func before_test() -> void:
	_wallet = auto_free(WALLET.new())
	_wallet.player_id = TEST_PROFILE
	_wallet.gold = 1000
	_inv = auto_free(INVENTORY.new())
	_inv.player_id = TEST_PROFILE
	_inv.wallet = _wallet
	_inv.extra_slots = 0
	_remove_files()


func after_test() -> void:
	_remove_files()


func _remove_files() -> void:
	for profile in [TEST_PROFILE, OTHER_PROFILE]:
		DirAccess.remove_absolute("user://progress/%s_inventory.json" % profile)
		DirAccess.remove_absolute("user://progress/%s_wallet.json" % profile)


func _spell(n: int) -> Dictionary:
	return {"id": "zz.spell.%d" % n, "price": 1}


func test_buying_costs_the_price() -> void:
	assert_bool(_inv.buy(FROST)).is_true()
	assert_int(_wallet.gold).is_equal(985)
	assert_int(_inv.count_of("zz.spell.frost")).is_equal(1)


## Gleiche Zauber stapeln sich auf einem Platz, ohne Obergrenze.
func test_the_same_spell_stacks() -> void:
	for i in 12:
		_inv.buy(FROST)
	assert_int(_inv.count_of("zz.spell.frost")).is_equal(12)
	assert_dict(_inv.slot(0)).is_equal({"id": "zz.spell.frost", "count": 12})
	assert_dict(_inv.slot(1)).is_empty()


func test_without_gold_nothing_changes() -> void:
	_wallet.gold = 10
	assert_bool(_inv.can_buy(FROST)).is_false()
	assert_bool(_inv.buy(FROST)).is_false()
	assert_int(_wallet.gold).is_equal(10)
	assert_int(_inv.count_of("zz.spell.frost")).is_equal(0)


## `Wallet.spend(0)` lehnt ab; ein Zauber für 0 Gold gibt es trotzdem.
func test_a_free_spell_can_be_had() -> void:
	assert_bool(_inv.buy(FREE)).is_true()
	assert_int(_inv.count_of("zz.spell.free")).is_equal(1)


## Ein neuer Zauber braucht einen freien Platz; ein vorhandener stapelt weiter.
func test_a_new_spell_needs_a_free_slot() -> void:
	for n in INVENTORY.BASE_SLOTS:
		assert_bool(_inv.buy(_spell(n))).is_true()
	var gold: int = _wallet.gold
	assert_bool(_inv.can_buy(MEND)).is_false()
	assert_bool(_inv.buy(MEND)).is_false()
	assert_int(_wallet.gold).is_equal(gold)
	assert_bool(_inv.buy(_spell(0))).is_true()


## Ein leer gewordener Platz rückt nicht nach: die Taste der anderen bleibt.
func test_an_emptied_slot_keeps_its_place() -> void:
	_inv.buy(FROST)
	_inv.buy(MEND)
	assert_str(_inv.take(0)).is_equal("zz.spell.frost")
	assert_dict(_inv.slot(0)).is_empty()
	assert_str(str(_inv.slot(1).get("id", ""))).is_equal("zz.spell.mend")
	assert_str(_inv.take(0)).is_empty()
	# Der freie Platz nimmt den nächsten neuen Zauber.
	_inv.buy(FREE)
	assert_str(str(_inv.slot(0).get("id", ""))).is_equal("zz.spell.free")


func test_taking_counts_down() -> void:
	_inv.buy(FROST)
	_inv.buy(FROST)
	assert_str(_inv.take(0)).is_equal("zz.spell.frost")
	assert_int(_inv.count_of("zz.spell.frost")).is_equal(1)


## Mehr Plätze kommen aus dem Fähigkeitsbaum; fallen sie weg, bleibt ihr Inhalt
## gespeichert und kommt mit dem Platz zurück.
func test_extra_slots_come_and_go_without_loss() -> void:
	_inv.extra_slots = 2
	assert_int(_inv.slot_count()).is_equal(INVENTORY.BASE_SLOTS + 2)
	for n in INVENTORY.BASE_SLOTS + 2:
		_inv.buy(_spell(n))
	_inv.extra_slots = 0
	var last := "zz.spell.%d" % (INVENTORY.BASE_SLOTS + 1)
	assert_int(_inv.count_of(last)).is_equal(0)
	assert_dict(_inv.slot(INVENTORY.BASE_SLOTS)).is_empty()
	_inv.extra_slots = 2
	assert_int(_inv.count_of(last)).is_equal(1)


func test_the_stock_survives_a_restart() -> void:
	_inv.buy(FROST)
	_inv.buy(MEND)
	_inv.take(0)
	var again: Node = auto_free(INVENTORY.new())
	again.player_id = TEST_PROFILE
	again.extra_slots = 0
	again.load_inventory()
	assert_dict(again.slot(0)).is_empty()
	assert_dict(again.slot(1)).is_equal({"id": "zz.spell.mend", "count": 1})


## Ein kaputter Platz in der Datei wird leer, der Rest bleibt.
func test_a_broken_slot_becomes_empty() -> void:
	DirAccess.make_dir_recursive_absolute(INVENTORY.SAVE_DIR)
	var file := FileAccess.open("user://progress/%s_inventory.json" % TEST_PROFILE, FileAccess.WRITE)
	file.store_string(JSON.stringify({"slots": [{"id": "", "count": 3}, "unsinn",
			{"id": "zz.spell.frost", "count": 2}, {"id": "zz.spell.mend", "count": -1}]}))
	file.close()
	_inv.load_inventory()
	assert_dict(_inv.slot(0)).is_empty()
	assert_dict(_inv.slot(1)).is_empty()
	assert_dict(_inv.slot(2)).is_equal({"id": "zz.spell.frost", "count": 2})
	assert_dict(_inv.slot(3)).is_empty()


func test_a_profile_switch_loads_the_other_stock() -> void:
	_inv.buy(FROST)
	_inv.switch_to(OTHER_PROFILE)
	assert_int(_inv.count_of("zz.spell.frost")).is_equal(0)
	_inv.switch_to(TEST_PROFILE)
	assert_int(_inv.count_of("zz.spell.frost")).is_equal(1)
