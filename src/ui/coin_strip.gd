class_name CoinStrip
extends VBoxContainer
## Monatsreihe der Statistik: ein Medaillon je Tag des laufenden Monats — auf geübten Tagen
## liegt die Münze darauf, heute trägt einen leisen Ring, die Tage danach sind leere Plätze
## (Issue #6, Entwurf `assets/ui/statistics/concept/statistics-v3.webp`).
##
## Eine Reihe und kein Wochenraster: ein Kalender zeigt vor allem die Lücken und liest sich
## wie eine Buchhaltung. Die Reihe zeigt einen Vorrat, der wächst. Der Monat als Rahmen
## (statt der letzten N Tage) gibt ihm ein Ziel: „4 von 30 Tagen geübt".
##
## Die Münzen sind MARKEN für geübte Tage und keine Währung — Gold als Währung liegt in
## der Geldbörse (Wallet) und wird in Schatzkisten verdient.
##
## Das Layout liegt in coin_strip.tscn, der Tag in stats_day.tscn; hier wird nur gerechnet
## und befüllt. Die Zustandsfolge und die Monatslänge stehen als statische Funktionen,
## damit sie ohne Szene, Autoload und Systemuhr prüfbar sind (siehe tests/coin_strip_test.gd).

const DAY_SCENE := preload("res://scenes/ui/stats_day.tscn")
## Wochentagskürzel in Godots Zählung (0 = Sonntag), für die Karte am Zeiger.
const WEEKDAYS := ["So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"]
const MONTH_NAMES := ["Januar", "Februar", "März", "April", "Mai", "Juni", "Juli",
		"August", "September", "Oktober", "November", "Dezember"]

@onready var _month: Label = %Month
@onready var _caption: Label = %Caption
@onready var _coins: HBoxContainer = %Coins


## Baut die Leiste für den laufenden Monat neu und gibt zurück, an wie vielen Tagen
## darin geübt wurde. Die geübten Tage kommen als lokale Tagesindizes vom SessionLog —
## dieselbe Zeitrechnung wie die Tages-Serie, damit beide an derselben Tagesgrenze hängen.
func refresh() -> int:
	var today_index: int = SessionLog.local_day(int(Time.get_unix_time_from_system()))
	var today := Time.get_datetime_dict_from_unix_time(today_index * 86400 + 43200)
	var month: int = int(today["month"])
	var first_index: int = today_index - (int(today["day"]) - 1)
	var day_count := days_in_month(int(today["year"]), month)

	var played := {}
	# Ein Tag Luft an beiden Enden: die Grenzen sind Sekunden, die Indizes ganze Tage.
	for index in SessionLog.played_days(
			(first_index - 1) * 86400, (first_index + day_count + 1) * 86400):
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


## Zustandsfolge des Monats, Tag 1 zuerst.
##
## Heute ohne Sitzung ist OPEN und nicht MISSED — der Tag läuft noch, genau wie ihn die
## Tages-Serie nicht als Lücke zählt. Die Tage danach sind FUTURE: leere Plätze, keine
## versäumten. Der laufende Monat ist der Normalfall; für einen vergangenen Monat (ein
## Zurückblättern gibt es noch nicht) liegt `today_index` hinter dem Monat und alles ist
## verdient oder verpasst.
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


## Länge eines Monats in Tagen, mit der gregorianischen Schaltjahr-Regel (durch 4, aber
## nicht durch 100, außer durch 400).
static func days_in_month(year: int, month: int) -> int:
	if month == 2:
		var leap := year % 4 == 0 and (year % 100 != 0 or year % 400 == 0)
		return 29 if leap else 28
	return 30 if month in [4, 6, 9, 11] else 31


## Datum eines lokalen Tagesindex als „Mo, 1. September". Die Umrechnung ist die Umkehrung
## von SessionLog.local_day: dessen Zeitzonen-Versatz fällt hier wieder heraus.
static func date_label(day_index: int) -> String:
	var d := Time.get_datetime_dict_from_unix_time(day_index * 86400 + 43200)
	return "%s, %d. %s" % [WEEKDAYS[int(d["weekday"])], int(d["day"]),
			MONTH_NAMES[int(d["month"]) - 1]]


## Der Stand eines Tages in Worten. Das DATUM steht nicht darin: es ist die Überschrift der
## Karte am Zeiger (`StatsDay.setup`).
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
