class_name CoinStrip
extends VBoxContainer
## Monatsreihe der Statistik: ein Medaillon je Tag, auf geübten Tagen eine Münze (Issue #6,
## keine Währung). Zustandsfolge und Monatslänge sind statisch, damit sie ohne Uhr prüfbar sind.

const DAY_SCENE := preload("res://scenes/ui/stats_day.tscn")
## Sekunden je Tag; Mittag als Versatz, damit ein Tagesindex sicher in seinem Tag landet.
const DAY_SECONDS := 86400
const NOON_SECONDS := 43200
## Wochentagskürzel in Godots Zählung (0 = Sonntag), für die Karte am Zeiger.
const WEEKDAYS := ["So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"]
const MONTH_NAMES := ["Januar", "Februar", "März", "April", "Mai", "Juni", "Juli",
		"August", "September", "Oktober", "November", "Dezember"]

@onready var _month: Label = %Month
@onready var _caption: Label = %Caption
@onready var _coins: HBoxContainer = %Coins


## Baut die Leiste für den laufenden Monat neu und gibt zurück, an wie vielen Tagen
## geübt wurde. Tagesindizes aus SessionLog, wie die Tages-Serie.
func refresh() -> int:
	var today_index: int = SessionLog.local_day(int(Time.get_unix_time_from_system()))
	var today := Time.get_datetime_dict_from_unix_time(today_index * DAY_SECONDS + NOON_SECONDS)
	var month: int = int(today["month"])
	var first_index: int = today_index - (int(today["day"]) - 1)
	var day_count := days_in_month(int(today["year"]), month)

	var played := {}
	# Ein Tag Luft an beiden Enden: die Grenzen sind Sekunden, die Indizes ganze Tage.
	for index in SessionLog.played_days(
			(first_index - 1) * DAY_SECONDS, (first_index + day_count + 1) * DAY_SECONDS):
		played[int(index)] = true

	for child in _coins.get_children():
		child.queue_free()
	var earned := 0
	var day_states := states(played, today_index, first_index, day_count)
	for i in day_states.size():
		var day_index := first_index + i
		var day_state: DayCoin.State = day_states[i]
		if day_state == DayCoin.State.EARNED:
			earned += 1
		var day := DAY_SCENE.instantiate() as StatsDay
		_coins.add_child(day)
		var is_today := day_index == today_index
		day.setup(day_state, is_today, i + 1, date_label(day_index),
				state_text(day_state, is_today))

	_month.text = MONTH_NAMES[month - 1]
	_caption.text = "•  %d von %d Tagen geübt" % [earned, day_count]
	return earned


## Zustandsfolge des Monats, Tag 1 zuerst. Heute ohne Sitzung ist OPEN, nicht MISSED: der
## Tag läuft noch. Die Tage danach sind FUTURE.
static func states(played: Dictionary, today_index: int, first_index: int, day_count: int) -> Array:
	var out: Array = []
	for i in day_count:
		var day_index := first_index + i
		if played.has(day_index):
			out.append(DayCoin.State.EARNED)
		elif day_index == today_index:
			out.append(DayCoin.State.OPEN)
		elif day_index > today_index:
			out.append(DayCoin.State.FUTURE)
		else:
			out.append(DayCoin.State.MISSED)
	return out


## Länge eines Monats in Tagen, mit gregorianischer Schaltjahr-Regel.
static func days_in_month(year: int, month: int) -> int:
	if month == 2:
		var leap := year % 4 == 0 and (year % 100 != 0 or year % 400 == 0)
		return 29 if leap else 28
	return 30 if month in [4, 6, 9, 11] else 31


## Datum eines lokalen Tagesindex als „Mo, 1. September“ (Umkehrung von SessionLog.local_day).
static func date_label(day_index: int) -> String:
	var d := Time.get_datetime_dict_from_unix_time(day_index * DAY_SECONDS + NOON_SECONDS)
	return "%s, %d. %s" % [WEEKDAYS[int(d["weekday"])], int(d["day"]),
			MONTH_NAMES[int(d["month"]) - 1]]


## Der Stand eines Tages in Worten, ohne Datum (das ist die Überschrift der Hinweiskarte).
static func state_text(day_state: DayCoin.State, today := false) -> String:
	var text: String
	match day_state:
		DayCoin.State.EARNED:
			text = "✓ Geübt"
		DayCoin.State.OPEN:
			return "Heute — noch nicht geübt"
		DayCoin.State.FUTURE:
			return "Kommt noch"
		_:
			text = "Nicht geübt"
	return text + "  •  Heute" if today else text
