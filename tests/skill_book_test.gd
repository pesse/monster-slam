extends GdUnitTestSuite
## Die gelernten Skills des Profils: kaufen, sichern, wechseln, umlernen.
##
## Geprüft auf einer EIGENEN Instanz mit eigenem Profil, nicht am Autoload — dessen Datei
## ist das echte Gelernte des Spielers. Die Instanz liegt nicht im Szenenbaum, also läuft
## kein _ready(): kein Zugriff auf UserSettings, keine Kopplung an den Profilwechsel.
## Dasselbe Muster wie tests/player_level_test.gd und tests/wallet_test.gd.
##
## Wallet und PlayerLevel lassen sich nicht ebenso ersetzen — `respec()` und `available()`
## gehen an die Autoloads. Deshalb bekommen BEIDE für die Dauer des Tests ein `zz-`Profil:
## ein `Wallet.spend` sichert sofort, und das ginge sonst in die echte Geldbörse des
## Spielers. Stand und Profil kommen in after_test zurück, die Wegwerf-Dateien fallen weg.
##
## Die KNOTEN kommen nicht aus der Registry, sondern aus einem erfundenen Baum (`FixedBook`
## überschreibt `entries()`). Sonst hinge jeder Test hier an der Balance der ausgelieferten
## Bäume und fiele bei der nächsten Justierung um.

const TEST_PROFILE := "zz-skill-test"
const OTHER_PROFILE := "zz-skill-test-other"


## SkillBook mit festen Knoten: ein Baum, eine Wurzel, zwei Äste. Der rechte Ast endet auf
## einem Knoten für 3 Punkte — der „große Skill", der auf seine Punkte warten muss.
class FixedBook extends "res://src/progression/skill_book.gd":
	func entries() -> Array:
		return [
			{"id": "tree.t", "kind": "tree", "order": 1, "name": "Prüfbaum"},
			{"id": "s.root", "kind": "skill", "tree": "tree.t", "tier": 1, "branch": 0,
				"name": "Wurzel", "cost": 1, "requires": [],
				"effects": {"heal_per_correct": 1}},
			{"id": "s.left", "kind": "skill", "tree": "tree.t", "tier": 2, "branch": 0,
				"name": "Links", "cost": 1, "requires": ["s.root"],
				"effects": {"heal_per_correct": 1}},
			{"id": "s.right", "kind": "skill", "tree": "tree.t", "tier": 2, "branch": 1,
				"name": "Rechts", "cost": 3, "requires": ["s.root"],
				"effects": {"fortress_armor": 25}},
		]


var _book: FixedBook
var _xp_before: int = 0
var _level_before: int = 1
var _level_profile_before: String = ""
var _gold_before: int = 0
var _wallet_profile_before: String = ""


func before_test() -> void:
	_xp_before = PlayerLevel.total_xp
	_level_before = PlayerLevel.level
	_level_profile_before = PlayerLevel.player_id
	_gold_before = Wallet.gold
	_wallet_profile_before = Wallet.player_id
	PlayerLevel.player_id = TEST_PROFILE
	# Die WERTE mitzurücksetzen ist nicht nur Hygiene: `available()` geht an das Autoload,
	# und das trägt beim Testlauf die echte Erfahrung des Entwicklerprofils. Ohne diese
	# zwei Zeilen fiel „ohne Punkte ist der Knoten zu teuer" um, sobald jemand im Spiel
	# ein paar Level gesammelt hatte — ein Test, der am Spielstand des Rechners hängt.
	PlayerLevel.total_xp = 0
	PlayerLevel.level = 1
	Wallet.player_id = TEST_PROFILE
	Wallet.gold = 0
	_remove_files()
	_book = auto_free(FixedBook.new())
	_book.player_id = TEST_PROFILE


func after_test() -> void:
	_remove_files()
	PlayerLevel.player_id = _level_profile_before
	PlayerLevel.total_xp = _xp_before
	PlayerLevel.level = _level_before
	Wallet.player_id = _wallet_profile_before
	Wallet.gold = _gold_before


func _remove_files() -> void:
	for profile: String in [TEST_PROFILE, OTHER_PROFILE]:
		for kind: String in ["skills", "wallet", "level"]:
			DirAccess.remove_absolute("user://progress/%s_%s.json" % [profile, kind])


## Setzt die verdienten Punkte über die Erfahrung: `skill_points()` ist daraus gerechnet,
## ein direkt gesetzter Punktestand wäre keiner.
func _give_points(count: int) -> void:
	PlayerLevel.total_xp = Experience.total_xp_for_level(count + 1)
	PlayerLevel.level = Experience.level_for(PlayerLevel.total_xp)


# --- Kaufen ------------------------------------------------------------------

func test_a_new_profile_has_learned_nothing() -> void:
	_book.load_skills()
	assert_array(Array(_book.unlocked)).is_empty()
	assert_int(_book.respec_cost()).is_equal(0)


func test_learning_spends_a_point() -> void:
	_give_points(2)
	assert_int(_book.available()).is_equal(2)
	assert_bool(_book.unlock("s.root")).is_true()
	assert_int(_book.available()).is_equal(1)
	assert_bool(_book.is_unlocked("s.root")).is_true()


## Ohne Vorstufe geht nichts — und es kostet auch nichts.
func test_a_branch_without_its_root_stays_closed() -> void:
	_give_points(5)
	assert_bool(_book.unlock("s.left")).is_false()
	assert_int(_book.available()).is_equal(5)


## Ein großer Skill kostet mehrere Punkte und wartet, bis sie da sind.
func test_a_big_skill_waits_for_its_points() -> void:
	_give_points(2)
	_book.unlock("s.root")
	assert_bool(_book.unlock("s.right")).is_false()
	_give_points(4)
	assert_bool(_book.unlock("s.right")).is_true()
	assert_int(_book.available()).is_equal(0)


## Eine Id, die es nicht gibt, ist kein Absturz, sondern ein `false`.
func test_an_unknown_id_is_refused() -> void:
	_give_points(5)
	assert_bool(_book.unlock("s.nope")).is_false()


## Ein Doppelklick kostet keinen zweiten Punkt.
func test_learning_twice_changes_nothing() -> void:
	_give_points(3)
	_book.unlock("s.root")
	assert_bool(_book.unlock("s.root")).is_false()
	assert_int(_book.available()).is_equal(2)


## Die Anzeigen hängen am Signal, statt nachzufragen — ein abgelehnter Kauf meldet nichts.
func test_only_a_real_change_is_reported() -> void:
	var seen := [0]
	_book.changed.connect(func() -> void: seen[0] += 1)
	_give_points(1)
	assert_bool(_book.unlock("s.left")).is_false()
	assert_int(seen[0]).is_equal(0)
	_book.unlock("s.root")
	assert_int(seen[0]).is_equal(1)


# --- Boni --------------------------------------------------------------------

## Was gelernt ist, wirkt — aufsummiert, und die ungelernten Schlüssel stehen trotzdem da.
func test_the_bonuses_follow_the_learned_nodes() -> void:
	_give_points(5)
	_book.unlock("s.root")
	_book.unlock("s.left")
	assert_float(_book.bonuses()["heal_per_correct"]).is_equal(2.0)
	assert_float(_book.bonuses()["fortress_armor"]).is_equal(0.0)


# --- Persistenz --------------------------------------------------------------

## Ein Kauf ist eine Entscheidung des Spielers — die darf ein Absturz nicht zurücknehmen.
func test_learned_skills_survive_a_reload() -> void:
	_give_points(3)
	_book.unlock("s.root")
	_book.unlock("s.left")
	var reloaded: FixedBook = auto_free(FixedBook.new())
	reloaded.player_id = TEST_PROFILE
	reloaded.load_skills()
	assert_array(Array(reloaded.unlocked)).is_equal(["s.root", "s.left"])


## Gespeichert wird NUR die Liste: der Punktestand steht zum Mitlesen daneben, gelesen
## wird er nicht — sonst gäbe es zwei Wahrheiten.
func test_the_spent_points_are_recomputed_from_the_list() -> void:
	_write_file('{"unlocked": ["s.root"], "spent_points": 99}')
	_give_points(4)
	_book.load_skills()
	assert_int(_book.available()).is_equal(3)


## Eine von Hand verdoppelte Zeile soll keine Punkte kosten, die es nicht gibt.
func test_a_duplicated_entry_is_counted_once() -> void:
	_write_file('{"unlocked": ["s.root", "s.root"]}')
	_give_points(4)
	_book.load_skills()
	assert_array(Array(_book.unlocked)).is_equal(["s.root"])
	assert_int(_book.available()).is_equal(3)


func _write_file(content: String) -> void:
	DirAccess.make_dir_recursive_absolute("user://progress")
	var file := FileAccess.open("user://progress/%s_skills.json" % TEST_PROFILE,
			FileAccess.WRITE)
	file.store_string(content)
	file.close()


## Jedes Profil lernt für sich — Gelerntes ist Spielerbesitz, nicht Gerätebesitz.
func test_each_profile_keeps_its_own_skills() -> void:
	_give_points(4)
	_book.unlock("s.root")
	_book.switch_to(OTHER_PROFILE)
	assert_array(Array(_book.unlocked)).is_empty()
	_book.switch_to(TEST_PROFILE)
	assert_array(Array(_book.unlocked)).is_equal(["s.root"])


# --- Umlernen ----------------------------------------------------------------

## Umlernen gibt alle Punkte zurück und kostet Gold — die Entscheidung bleibt revidierbar,
## ohne folgenlos zu sein.
func test_respec_returns_every_point_for_gold() -> void:
	_give_points(4)
	_book.unlock("s.root")
	_book.unlock("s.left")
	Wallet.gold = 10_000
	var price := _book.respec_cost()
	assert_int(price).is_equal(2 * SkillTree.RESPEC_GOLD_PER_POINT)
	assert_bool(_book.respec()).is_true()
	assert_array(Array(_book.unlocked)).is_empty()
	assert_int(_book.available()).is_equal(4)
	assert_int(Wallet.gold).is_equal(10_000 - price)


## Reicht das Gold nicht, bleibt alles, wie es war — kein halber Umbau.
func test_respec_without_gold_changes_nothing() -> void:
	_give_points(4)
	_book.unlock("s.root")
	Wallet.gold = 0
	assert_bool(_book.respec()).is_false()
	assert_array(Array(_book.unlocked)).is_equal(["s.root"])


## Ohne gelernte Skills gibt es nichts zurückzunehmen — und kein Gold wird genommen.
func test_respec_without_skills_costs_nothing() -> void:
	Wallet.gold = 500
	assert_bool(_book.respec()).is_false()
	assert_int(Wallet.gold).is_equal(500)


# --- Verlernen ---------------------------------------------------------------

## Ein einzelner Knoten gibt seine Punkte zurück und kostet Gold; der Rest bleibt.
func test_forgetting_a_leaf_keeps_the_rest() -> void:
	_give_points(5)
	_book.unlock("s.root")
	_book.unlock("s.left")
	_book.unlock("s.right")
	Wallet.gold = 1_000
	var price := _book.forget_cost("s.right")
	assert_int(price).is_equal(SkillTree.FORGET_GOLD_PER_NODE)
	assert_bool(_book.forget("s.right")).is_true()
	assert_array(Array(_book.unlocked)).is_equal(["s.root", "s.left"])
	assert_int(_book.available()).is_equal(3)
	assert_int(Wallet.gold).is_equal(1_000 - price)


## Die Wurzel nimmt ihre Äste mit — und die sind im Preis enthalten.
func test_forgetting_the_root_takes_its_branches() -> void:
	_give_points(5)
	_book.unlock("s.root")
	_book.unlock("s.left")
	Wallet.gold = 1_000
	assert_bool(_book.forget("s.root")).is_true()
	assert_array(Array(_book.unlocked)).is_empty()
	assert_int(Wallet.gold).is_equal(1_000 - 2 * SkillTree.FORGET_GOLD_PER_NODE)


## Reicht das Gold nicht, bleibt alles, wie es war — und es wird nichts gemeldet.
func test_forgetting_without_gold_changes_nothing() -> void:
	_give_points(3)
	_book.unlock("s.root")
	Wallet.gold = 0
	var seen := [0]
	_book.changed.connect(func() -> void: seen[0] += 1)
	assert_bool(_book.forget("s.root")).is_false()
	assert_array(Array(_book.unlocked)).is_equal(["s.root"])
	assert_int(seen[0]).is_equal(0)


## Was nicht gelernt ist, lässt sich nicht verlernen — und kein Gold wird genommen.
func test_forgetting_an_unlearned_node_costs_nothing() -> void:
	_give_points(3)
	_book.unlock("s.root")
	Wallet.gold = 500
	assert_bool(_book.forget("s.left")).is_false()
	assert_int(Wallet.gold).is_equal(500)


## Verlernt ist verlernt, auch nach einem Neustart.
func test_forgetting_survives_a_reload() -> void:
	_give_points(3)
	_book.unlock("s.root")
	_book.unlock("s.left")
	Wallet.gold = 1_000
	_book.forget("s.left")
	var reloaded: FixedBook = auto_free(FixedBook.new())
	reloaded.player_id = TEST_PROFILE
	reloaded.load_skills()
	assert_array(Array(reloaded.unlocked)).is_equal(["s.root"])
