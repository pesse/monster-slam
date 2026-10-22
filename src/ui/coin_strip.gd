class_name CoinStrip
extends VBoxContainer
## Monatsreihe der Statistik: ein Medaillon je Tag, auf geübten Tagen eine Münze (Issue #6,
## keine Währung). Die Pfeile blättern bis zum Monat der ersten Sitzung zurück, ein Klick wählt
## einen Tag (`day_selected`). Zustandsfolge und Monatsrechnung sind statisch, damit sie ohne
## Uhr prüfbar sind.

const DAY_SCENE := preload("res://scenes/ui/stats_day.tscn")
## Sekunden je Tag; Mittag als Versatz, damit ein Tagesindex sicher in seinem Tag landet.
const DAY_SECONDS := 86400
const NOON_SECONDS := 43200
## Wochentagskürzel in Godots Zählung (0 = Sonntag), für die Karte am Zeiger.
const WEEKDAYS := ["So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"]
const MONTH_NAMES := ["Januar", "Februar", "März", "April", "Mai", "Juni", "Juli",
		"August", "September", "Oktober", "November", "Dezember"]

## Ein Tag wurde gewählt (lokaler Tagesindex), auch beim Blättern; -1 heißt keiner.
signal day_selected(day_index: int)

## Tagesindizes mit Plaketten (Index -> true); sie tragen die kleine Plakette.
var badge_days: Dictionary = {}
## Kampfzeit (ms) je Tagesindex (SessionLog.battle_ms_by_day), für die Karte am Zeiger.
var battle_ms: Dictionary = {}
## Der gewählte Tag; -1 vor dem ersten `refresh`.
var selected_day := -1
## Wie viele Monate vor dem laufenden gezeigt werden.
var _months_back := 0

@onready var _month: Label = %Month
@onready var _caption: Label = %Caption
@onready var _coins: HBoxContainer = %Coins
@onready var _prev: Button = %PrevMonth
@onready var _next: Button = %NextMonth


func _ready() -> void:
	_prev.pressed.connect(_turn.bind(1))
	_next.pressed.connect(_turn.bind(-1))
	Hints.attach(_prev, "Monat davor")
	Hints.attach(_next, "Monat danach")


## Baut die Leiste für den gezeigten Monat neu und gibt zurück, an wie vielen Tagen
## geübt wurde. Tagesindizes aus SessionLog, wie die Tages-Serie. Ohne gewählten Tag gilt heute.
func refresh() -> int:
	var today_index: int = SessionLog.local_day(int(Time.get_unix_time_from_system()))
	if selected_day < 0:
		selected_day = today_index
	var sessions := SessionLog.sessions()
	var first_played := today_index if sessions.is_empty() \
			else SessionLog.local_day(int((sessions[0] as Dictionary).get("started_at", 0)))
	var oldest := months_between(first_played, today_index)
	_months_back = clampi(_months_back, 0, oldest)
	var first_index := month_start(today_index, _months_back)
	var first := Time.get_datetime_dict_from_unix_time(first_index * DAY_SECONDS + NOON_SECONDS)
	var month: int = int(first["month"])
	var day_count := days_in_month(int(first["year"]), month)

	var played := {}
	# Ein Tag Luft an beiden Enden: die Grenzen sind Sekunden, die Indizes ganze Tage.
	for index in SessionLog.played_days(
			(first_index - 1) * DAY_SECONDS, (first_index + day_count + 1) * DAY_SECONDS):
		played[int(index)] = true

	# Gleich aus dem Baum, damit `select` nur die neuen Tage zählt.
	for child in _coins.get_children():
		_coins.remove_child(child)
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
		var with_badges := badge_days.has(day_index)
		day.setup(day_state, is_today, i + 1, date_label(day_index),
				state_text(day_state, is_today, with_badges, int(battle_ms.get(day_index, 0))),
				with_badges)
		day.selected = day_index == selected_day
		if day_state != DayCoin.State.FUTURE:
			day.chosen.connect(select.bind(day_index))

	var today := Time.get_datetime_dict_from_unix_time(today_index * DAY_SECONDS + NOON_SECONDS)
	_month.text = MONTH_NAMES[month - 1] if int(first["year"]) == int(today["year"]) \
			else "%s %d" % [MONTH_NAMES[month - 1], int(first["year"])]
	_caption.text = "•  %d von %d Tagen geübt" % [earned, day_count]
	_prev.disabled = _months_back >= oldest
	_next.disabled = _months_back == 0
	return earned


## Wählt einen Tag des gezeigten Monats und meldet ihn.
func select(day_index: int) -> void:
	selected_day = day_index
	for day: StatsDay in _coins.get_children():
		day.selected = day.get_index() == day_index - _first_shown()
	day_selected.emit(day_index)


## Blättert `months` Monate zurück (negativ: vor). Gewählt ist danach heute im laufenden
## Monat, sonst der letzte geübte Tag des Monats oder keiner.
func _turn(months: int) -> void:
	_months_back += months
	refresh()
	var today_index: int = SessionLog.local_day(int(Time.get_unix_time_from_system()))
	var pick := today_index if _months_back == 0 else -1
	if pick < 0:
		for day: StatsDay in _coins.get_children():
			if day.state == DayCoin.State.EARNED:
				pick = _first_shown() + day.get_index()
	select(pick)
	# Der gedrückte Knopf kann gesperrt sein und verlöre den Fokus ins Leere.
	if (_prev if months > 0 else _next).disabled:
		(_next if months > 0 else _prev).grab_focus()


func _first_shown() -> int:
	return month_start(SessionLog.local_day(int(Time.get_unix_time_from_system())), _months_back)


## Tagesindex des Ersten im Monat, der `months_back` Monate vor dem von `today_index` liegt.
static func month_start(today_index: int, months_back: int) -> int:
	var d := Time.get_datetime_dict_from_unix_time(today_index * DAY_SECONDS + NOON_SECONDS)
	var months := int(d["year"]) * 12 + int(d["month"]) - 1 - months_back
	var unix := Time.get_unix_time_from_datetime_dict({"year": floori(months / 12.0),
			"month": months % 12 + 1, "day": 1, "hour": 12, "minute": 0, "second": 0})
	return floori(float(unix) / DAY_SECONDS)


## Wie viele Monatswechsel zwischen zwei Tagesindizes liegen (0 im selben Monat).
static func months_between(from_index: int, to_index: int) -> int:
	var a := Time.get_datetime_dict_from_unix_time(from_index * DAY_SECONDS + NOON_SECONDS)
	var b := Time.get_datetime_dict_from_unix_time(to_index * DAY_SECONDS + NOON_SECONDS)
	return maxi(0, (int(b["year"]) - int(a["year"])) * 12 + int(b["month"]) - int(a["month"]))


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


## „12 Min.“, „1 Std. 5 Min.“ aus Millisekunden; unter einer Minute „unter 1 Min.“.
static func duration_text(ms: int) -> String:
	if ms <= 0:
		return "0 Min."
	var minutes := floori(ms / 60000.0)
	if minutes == 0:
		return "unter 1 Min."
	if minutes < 60:
		return "%d Min." % minutes
	if minutes % 60 == 0:
		return "%d Std." % floori(minutes / 60.0)
	return "%d Std. %d Min." % [floori(minutes / 60.0), minutes % 60]


## Der Stand eines Tages in Worten, ohne Datum (das ist die Überschrift der Hinweiskarte).
## `battle` ist die Kampfzeit des Tages (ms).
static func state_text(day_state: DayCoin.State, today := false, badges := false,
		battle := 0) -> String:
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
	if badges:
		text += "  •  mit Plaketten"
	if battle > 0:
		text += "  •  %s im Kampf" % duration_text(battle)
	return text + "  •  Heute" if today else text
