extends GdUnitTestSuite
## Monats-Leiste der Goldstücke: Zustandsfolge, Monatslänge, Aufbau der Szene (Issue #6).
##
## Geprüft wird an den statischen Funktionen mit erfundenen Tagesindizes — ohne SessionLog,
## ohne Systemuhr und damit ohne Abhängigkeit davon, wann der Test läuft. Der Szenen-Test
## baut die Leiste einmal auf: er soll Tippfehler in den Knotennamen der handgeschriebenen
## .tscn auffallen lassen.

const COIN_STRIP := preload("res://src/ui/coin_strip.gd")
const COIN_STRIP_SCENE := preload("res://scenes/ui/coin_strip.tscn")

## Erster und heutiger Tag eines erfundenen Monats: heute ist der 10. eines 30-Tage-Monats.
const FIRST := 20000
const TODAY := FIRST + 9


func test_played_days_become_gold() -> void:
	var states := COIN_STRIP.states({FIRST: true, FIRST + 2: true}, TODAY, FIRST, 30)
	assert_int(states.size()).is_equal(30)
	assert_int(states[0]).is_equal(DayCoin.State.EARNED)
	assert_int(states[2]).is_equal(DayCoin.State.EARNED)
	assert_int(states[1]).is_equal(DayCoin.State.MISSED)


## Heute ohne Sitzung ist offen, nicht verpasst — der Tag läuft noch, genau wie ihn die
## Tages-Serie nicht als Lücke zählt.
func test_today_without_a_session_is_open() -> void:
	assert_int(COIN_STRIP.states({}, TODAY, FIRST, 30)[9]).is_equal(DayCoin.State.OPEN)


func test_today_with_a_session_is_gold() -> void:
	assert_int(COIN_STRIP.states({TODAY: true}, TODAY, FIRST, 30)[9]).is_equal(DayCoin.State.EARNED)


## Die Tage nach heute sind leere Plätze, keine versäumten — sonst stünde der Monat schon
## am 1. als fast vollständig verpasst da.
func test_days_after_today_are_empty_slots() -> void:
	var states := COIN_STRIP.states({}, TODAY, FIRST, 30)
	assert_int(states[10]).is_equal(DayCoin.State.FUTURE)
	assert_int(states[29]).is_equal(DayCoin.State.FUTURE)
	assert_int(states.count(DayCoin.State.FUTURE)).is_equal(20)
	assert_int(states.count(DayCoin.State.MISSED)).is_equal(9)


## Tage außerhalb des Monats zählen nicht mit; die Leiste ist der Monat, nicht die
## Gesamtbilanz (die steht als Zahl daneben, siehe SessionLog.played_day_count).
func test_days_outside_the_month_are_ignored() -> void:
	var states := COIN_STRIP.states({FIRST - 3: true, FIRST + 1: true}, TODAY, FIRST, 30)
	assert_int(states.count(DayCoin.State.EARNED)).is_equal(1)


func test_month_lengths() -> void:
	assert_int(COIN_STRIP.days_in_month(2026, 1)).is_equal(31)
	assert_int(COIN_STRIP.days_in_month(2026, 4)).is_equal(30)
	assert_int(COIN_STRIP.days_in_month(2026, 9)).is_equal(30)
	assert_int(COIN_STRIP.days_in_month(2026, 12)).is_equal(31)


func test_february_follows_the_gregorian_leap_rule() -> void:
	assert_int(COIN_STRIP.days_in_month(2026, 2)).is_equal(28)
	assert_int(COIN_STRIP.days_in_month(2024, 2)).is_equal(29)
	assert_int(COIN_STRIP.days_in_month(1900, 2)).is_equal(28)
	assert_int(COIN_STRIP.days_in_month(2000, 2)).is_equal(29)


## Das Datum eines Tagesindex ist die Umkehrung von SessionLog.local_day: einen Tag
## weiter heißt ein Kalendertag weiter, und der Wochentag rückt um eins vor.
func test_date_label_advances_by_one_day() -> void:
	# 1.9.2026 war ein Dienstag (Tagesindex 20697 in UTC-Rechnung).
	var index := 20697
	assert_str(COIN_STRIP.date_label(index)).is_equal("Di, 1.9.")
	assert_str(COIN_STRIP.date_label(index + 1)).is_equal("Mi, 2.9.")


## Die Szene muss sich bauen lassen, ihre Knoten finden und für jeden Tag des laufenden
## Monats ein Goldstück anlegen.
func test_scene_builds_one_coin_per_day_of_the_month() -> void:
	var strip: VBoxContainer = auto_free(COIN_STRIP_SCENE.instantiate())
	add_child(strip)
	assert_object(strip.get_node("%Coins")).is_not_null()
	assert_object(strip.get_node("%Caption")).is_not_null()
	strip.refresh()
	var now := Time.get_datetime_dict_from_system()
	var expected: int = COIN_STRIP.days_in_month(int(now["year"]), int(now["month"]))
	assert_int(strip.get_node("%Coins").get_child_count()).is_equal(expected)
	remove_child(strip)
