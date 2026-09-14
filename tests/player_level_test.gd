extends GdUnitTestSuite
## Erfahrung und Level des Profils: verbuchen, aufsteigen, sichern, Profilwechsel.
##
## Geprüft auf einer EIGENEN Instanz mit eigenem Profil, nicht am Autoload — dessen Datei
## ist die echte Erfahrung des Spielers. Die Instanz liegt nicht im Szenenbaum, also läuft
## kein _ready(): kein Zugriff auf UserSettings, keine Kopplung an den Profilwechsel.
## Dasselbe Muster wie tests/wallet_test.gd.

const PLAYER_LEVEL := preload("res://src/progression/player_level.gd")
const TEST_PROFILE := "zz-level-test"
const OTHER_PROFILE := "zz-level-test-other"

var _level: Node


func before_test() -> void:
	_level = auto_free(PLAYER_LEVEL.new())
	_level.player_id = TEST_PROFILE
	_remove_files()


func after_test() -> void:
	_remove_files()


func _remove_files() -> void:
	for profile in [TEST_PROFILE, OTHER_PROFILE]:
		DirAccess.remove_absolute("user://progress/%s_level.json" % profile)


func test_a_new_profile_starts_at_level_one() -> void:
	_level.load_level()
	assert_int(_level.total_xp).is_equal(0)
	assert_int(_level.level).is_equal(1)
	assert_int(_level.skill_points()).is_equal(0)


func test_gaining_experience_adds_up() -> void:
	_level.gain(12)
	_level.gain(30)
	assert_int(_level.total_xp).is_equal(42)
	assert_int(_level.level).is_equal(1)


## Eine Welle ohne besiegtes Monster bringt 0 — nichts zu tun, kein Signal.
func test_gaining_nothing_changes_nothing() -> void:
	var seen: Array = []
	_level.changed.connect(func(total_xp: int, _lvl: int) -> void: seen.append(total_xp))
	_level.gain(0)
	_level.gain(-5)
	assert_int(_level.total_xp).is_equal(0)
	assert_array(seen).is_empty()


## Der Aufstieg meldet sich getrennt von der Änderung: er will gefeiert werden, eine
## Änderung nur angezeigt.
func test_reaching_the_threshold_reports_a_level_up() -> void:
	var ups: Array = []
	_level.leveled_up.connect(func(lvl: int, points: int) -> void: ups.append([lvl, points]))
	_level.gain(99)
	assert_array(ups).is_empty()
	_level.gain(1)
	assert_int(_level.level).is_equal(2)
	assert_array(ups).is_equal([[2, 1]])


## Jedes Levelup gibt einen Skillpunkt — auch wenn zwei auf einmal fallen (ein großer
## Betrag am Ende einer langen Welle darf keinen Punkt schlucken).
func test_two_levels_at_once_give_two_skill_points() -> void:
	var ups: Array = []
	_level.leveled_up.connect(func(lvl: int, points: int) -> void: ups.append([lvl, points]))
	_level.gain(300)
	assert_int(_level.level).is_equal(3)
	assert_int(_level.skill_points()).is_equal(2)
	# EINE Meldung mit dem erreichten Level, nicht eine je Stufe: gemeldet wird der neue
	# Stand, nicht der Weg dorthin.
	assert_array(ups).is_equal([[3, 2]])


## Verdiente Erfahrung wird SOFORT gesichert: sie fällt mitten in der Welle an, und ein
## Absturz auf dem Weg zum Wellenende darf sie nicht kosten.
func test_experience_survives_a_reload() -> void:
	_level.gain(350)
	var reloaded: Node = auto_free(PLAYER_LEVEL.new())
	reloaded.player_id = TEST_PROFILE
	reloaded.load_level()
	assert_int(reloaded.total_xp).is_equal(350)
	assert_int(reloaded.level).is_equal(3)
	assert_int(reloaded.skill_points()).is_equal(2)


## Jedes Profil lernt für sich — Erfahrung ist Spielerbesitz, nicht Gerätebesitz.
func test_each_profile_keeps_its_own_experience() -> void:
	_level.gain(120)
	_level.switch_to(OTHER_PROFILE)
	assert_int(_level.total_xp).is_equal(0)
	assert_int(_level.level).is_equal(1)
	_level.gain(7)
	_level.switch_to(TEST_PROFILE)
	assert_int(_level.total_xp).is_equal(120)
	assert_int(_level.level).is_equal(2)


## Das Level kommt aus der Erfahrung und nicht aus der Datei: ein von Hand hochgesetztes
## Level wäre ein Level ohne Erfahrung dahinter.
func test_the_level_is_recomputed_from_the_experience() -> void:
	var file := FileAccess.open("user://progress/%s_level.json" % TEST_PROFILE, FileAccess.WRITE)
	file.store_string('{"total_xp": 100, "level": 42, "skill_points": 41}')
	file.close()
	_level.load_level()
	assert_int(_level.level).is_equal(2)
	assert_int(_level.skill_points()).is_equal(1)


## Eine verbogene Datei macht keine negative Erfahrung.
func test_a_negative_file_value_loads_as_zero() -> void:
	var file := FileAccess.open("user://progress/%s_level.json" % TEST_PROFILE, FileAccess.WRITE)
	file.store_string('{"total_xp": -99}')
	file.close()
	_level.load_level()
	assert_int(_level.total_xp).is_equal(0)
	assert_int(_level.level).is_equal(1)


## Die Erfahrung heißt überall gleich, deshalb steht ihr Text hier.
func test_label_names_the_unit() -> void:
	assert_str(_level.label(340)).is_equal("340 XP")
	_level.gain(12)
	assert_str(_level.label()).is_equal("12 XP")
