extends GdUnitTestSuite
## Geldbörse: verdienen, ausgeben, sichern, Profilwechsel.
##
## Geprüft auf einer EIGENEN Wallet-Instanz mit eigenem Profil, nicht am Autoload —
## dessen Datei ist das echte Gold des Spielers. Die Instanz liegt nicht im Szenenbaum,
## also läuft kein _ready(): kein Zugriff auf UserSettings, keine Kopplung an den
## Profilwechsel. Dasselbe Muster wie tests/session_log_test.gd.

const WALLET := preload("res://src/economy/wallet.gd")
const TEST_PROFILE := "zz-wallet-test"
const OTHER_PROFILE := "zz-wallet-test-other"

var _wallet: Node


func before_test() -> void:
	_wallet = auto_free(WALLET.new())
	_wallet.player_id = TEST_PROFILE
	_remove_files()


func after_test() -> void:
	_remove_files()


func _remove_files() -> void:
	for profile in [TEST_PROFILE, OTHER_PROFILE]:
		DirAccess.remove_absolute("user://progress/%s_wallet.json" % profile)


func test_a_new_profile_starts_without_gold() -> void:
	_wallet.load_wallet()
	assert_int(_wallet.gold).is_equal(0)
	assert_int(_wallet.total_earned).is_equal(0)


func test_earning_raises_balance_and_lifetime_total() -> void:
	_wallet.earn(12)
	_wallet.earn(8)
	assert_int(_wallet.gold).is_equal(20)
	assert_int(_wallet.total_earned).is_equal(20)


## Kisten werden gezählt, aber nur wenn es welche waren: dieselbe Menge Gold kann aus
## unterschiedlich vielen Kisten kommen, also ist die Zahl nicht ableitbar.
func test_only_chests_count_as_chests() -> void:
	_wallet.earn(10, true)
	_wallet.earn(10)
	assert_int(_wallet.chests_opened).is_equal(1)


## Eine Welle ohne besiegtes Monster bringt 0 — das ist nichts zu tun und kein Fehler.
func test_earning_nothing_changes_nothing() -> void:
	var seen: Array = []
	_wallet.changed.connect(func(gold: int) -> void: seen.append(gold))
	_wallet.earn(0)
	_wallet.earn(-5)
	assert_int(_wallet.gold).is_equal(0)
	assert_array(seen).is_empty()


func test_spending_takes_gold_and_reports_success() -> void:
	_wallet.earn(30)
	assert_bool(_wallet.spend(10)).is_true()
	assert_int(_wallet.gold).is_equal(20)


## Was nicht da ist, wird nicht ausgegeben — und der Stand bleibt unberührt. Ohne den
## Riegel wären Schulden möglich, die das Spiel nicht kennt.
func test_spending_more_than_owned_fails_without_changing_anything() -> void:
	_wallet.earn(5)
	assert_bool(_wallet.spend(6)).is_false()
	assert_int(_wallet.gold).is_equal(5)
	assert_bool(_wallet.can_afford(6)).is_false()


## Ausgeben senkt den Stand, nicht die Lebensleistung.
func test_spending_leaves_the_lifetime_total_alone() -> void:
	_wallet.earn(40)
	_wallet.spend(25)
	assert_int(_wallet.total_earned).is_equal(40)


## Verdientes Gold wird SOFORT gesichert: ein Absturz nach der Kiste darf sie nicht
## rückgängig machen.
func test_gold_survives_a_reload() -> void:
	_wallet.earn(17, true)
	var reloaded: Node = auto_free(WALLET.new())
	reloaded.player_id = TEST_PROFILE
	reloaded.load_wallet()
	assert_int(reloaded.gold).is_equal(17)
	assert_int(reloaded.chests_opened).is_equal(1)


## Jedes Profil hat seine eigene Geldbörse — Gold ist Spielerbesitz, nicht Gerätebesitz.
func test_each_profile_keeps_its_own_gold() -> void:
	_wallet.earn(50)
	_wallet.switch_to(OTHER_PROFILE)
	assert_int(_wallet.gold).is_equal(0)
	_wallet.earn(7)
	_wallet.switch_to(TEST_PROFILE)
	assert_int(_wallet.gold).is_equal(50)


## Eine von Hand verbogene Datei macht keine Schulden.
func test_a_negative_file_value_loads_as_zero() -> void:
	var file := FileAccess.open("user://progress/%s_wallet.json" % TEST_PROFILE, FileAccess.WRITE)
	file.store_string('{"gold": -99}')
	file.close()
	_wallet.load_wallet()
	assert_int(_wallet.gold).is_equal(0)


## Die Währung sieht überall gleich aus, deshalb steht ihr Text in der Geldbörse.
func test_label_groups_thousands() -> void:
	assert_str(_wallet.label(7)).is_equal("7 Gold")
	assert_str(_wallet.label(1240)).is_equal("1.240 Gold")
	assert_str(_wallet.label(1234567)).is_equal("1.234.567 Gold")
