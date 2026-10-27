extends Control
## Statistik-Fenster über dem Hauptmenü (geöffnet von `ProfileBadge`); das Layout liegt in
## stats_screen.tscn, hier wird nur befüllt. Fünf Reiter, siehe Handbuch Kapitel 12:
## „Fortschritt“ zählt Wörter (mastered_lexemes), „Aufgaben“ learnable_ids (mastered_count).
## Die Sprachwahl filtert alles, was an Wörtern hängt; Profilwerte und die Sitzung
## (SessionLog kennt keine Sprache) zählen immer alle Sprachen.

const MENU_SCENE := "res://scenes/ui/profile_menu.tscn"
const ROW_SCENE := preload("res://scenes/ui/stat_row.tscn")
const RECORD_ROW_SCENE := preload("res://scenes/ui/record_row.tscn")
const PROGRESS_ROW_SCENE := preload("res://scenes/ui/progress_row.tscn")
const CHIP_SCENE := preload("res://scenes/ui/badge_chip.tscn")
const BADGE_ROW_SCENE := preload("res://scenes/ui/badge_row.tscn")
const ACHIEVEMENT_ROW_SCENE := preload("res://scenes/ui/achievement_row.tscn")
## Für Schwellen und Richtungen in den statischen Funktionen; der Autoload ist nicht statisch erreichbar.
const PROGRESS := preload("res://src/learning/player_progress.gd")

## Einblenden (s).
const FADE_IN := 0.15
## Länge der Fahndungsliste.
const WANTED_COUNT := 5
## Länge von „Frisch gemeistert“ und „Comeback“.
const LIST_COUNT := 5
## Zeitraum für „frisch“ (Tage).
const FRESH_DAYS := 7
## Ab so vielen Fehlversuchen ist eine wiedergewonnene Aufgabe ein Comeback.
const COMEBACK_MISSES := 3
## Ab diesem HP-Stand trägt der schonendste Lauf das Schild. Ein fester Betrag, weil die
## Sitzungen ihr Maximum nicht mitschreiben.
const SPOTLESS_FORTRESS_HP := 90
## Unter diesem Abstand (Prozentpunkte) steht der Trendpfeil waagrecht.
const TREND_STEADY_POINTS := 3

## Reihenfolge der Wort- und Aufgabenlisten, in der Reihenfolge der Knöpfe in `SortBar`.
enum SortMode { BEST_FIRST, WEAKEST_FIRST, ALPHABETICAL }
## Gilt, solange das Spiel läuft; nicht gespeichert.
static var _sort_mode := SortMode.BEST_FIRST
## Die gewählten Sprachen (leer = alle), flüchtig wie `_sort_mode`.
static var _languages: Array = []

const LANGUAGE_HINT := "Ein Klick schaltet die Sprache an oder aus, mehrere zugleich gehen. " \
		+ "Gilt für alles, was an Wörtern hängt: gemeistert, fällig, Lernkurve, " \
		+ "die Wortlisten, „Insgesamt“, „Fortschritt“ und „Aufgaben“. " \
		+ "Level, Gold, Rekorde, Tages-Serie, Plaketten, Erfolge und die Genauigkeit der " \
		+ "Sitzung zählen immer alle Sprachen."

## Das Fenster will zu. Ohne Verbindung geht `close` selbst ins Startmenü.
signal closed()

## Nur für die Werkbank: versteckte Erfolge als offene Karten mit Namen statt nur gezählt.
var reveal_hidden := false

@onready var _streak_label: Label = %StreakLabel
@onready var _streak_note: Label = %StreakNote
@onready var _coin_strip: CoinStrip = %CoinStrip
@onready var _accuracy_label: Label = %AccuracyLabel
@onready var _accuracy_which: Label = %AccuracyWhich
@onready var _accuracy_trend: Label = %AccuracyTrend
@onready var _battle_label: Label = %BattleLabel
@onready var _battle_note: Label = %BattleNote
@onready var _total_lines: VBoxContainer = %TotalLines
@onready var _record_list: VBoxContainer = %RecordList
@onready var _curve: StatsChart = %Curve
@onready var _curve_caption: Label = %CurveCaption
@onready var _fresh_list: VBoxContainer = %FreshList
@onready var _comeback_list: VBoxContainer = %ComebackList
@onready var _wanted_list: VBoxContainer = %WantedList
@onready var _day_badge_title: Label = %DayBadgeTitle
@onready var _day_badge_row: HBoxContainer = %DayBadgeRow
@onready var _day_badge_empty: Label = %DayBadgeEmpty
@onready var _daily_list: VBoxContainer = %DailyList
## Nur gelesen; gespeichert wird im Kampf.
var _badges := Badges.new()
## SessionLog.correct_by_day(), je `_refresh` einmal.
var _correct_by_day := {}
## Kampfzeit (ms) je Tagesindex, für Monatsreihe und Tagesband.
var _battle_by_day := {}
## Fächert die Aufgaben eines Wortes auf (learnables_of); spawnt nichts.
var _generator := WaveGenerator.new()
var _resolver := TaskResolver.new()

@onready var _unit_list: VBoxContainer = %UnitList
@onready var _task_list: VBoxContainer = %TaskList
@onready var _sort_bars: Array[SortBar] = [%WordSort as SortBar, %TaskSort as SortBar]
@onready var _language_bar: LanguageBar = %LanguageBar
## Überschrift -> Text ohne Sprache; diese Abschnitte folgen der Sprachwahl.
@onready var _filtered_titles := {
	%CurveTitle: "Lernkurve", %FreshTitle: "Frisch gemeistert", %ComebackTitle: "Comeback",
	%WantedTitle: "Fahndungsliste", %TotalTitle: "Insgesamt",
}
var _book_languages := {}
## Gefilterte Sprachen; leer, solange alle gewählt sind. Dann zählt auch, was keiner
## Sprache zugeordnet ist.
var _filter: Array = []
var _language_choices: Array = []
## Reiter → Abschnitt im Handbuch für das „?“ im Titelband.
@onready var _handbook_sections := {
	%OverviewTab: "Reiter „Überblick“",
	%ProgressTab: "Reiter „Fortschritt“: gezählt werden Wörter",
	%TaskTab: "Reiter „Aufgaben“: gezählt werden Aufgaben",
	%BadgeTab: "Reiter „Plaketten“",
	%AchievementTab: "Reiter „Erfolge“",
}
@onready var _pages := {
	%OverviewTab: %OverviewPage,
	%ProgressTab: %ProgressPage,
	%TaskTab: %TaskPage,
	%BadgeTab: %BadgePage,
	%AchievementTab: %AchievementPage,
}


func _ready() -> void:
	(%CloseButton as BaseButton).pressed.connect(close)
	Hints.attach(%CloseButton as Control, "Schließen", "", "Esc")
	for tab: Button in _pages:
		tab.toggled.connect(func(on: bool) -> void:
			if on:
				_show_page(tab))
	for bar in _sort_bars:
		bar.set_mode(_sort_mode)
		bar.changed.connect(_on_sort_changed)
	_setup_languages()
	_coin_strip.day_selected.connect(_show_day)
	Hints.attach(%StreakCard as Control, "Tage in Folge",
			"Jeder Tag mit mindestens einem Lauf zählt. Heute ist keine Lücke, solange der "
			+ "Tag läuft — die Serie reißt erst, wenn ein ganzer Tag fehlt.")
	Hints.attach(%PointsRow as Control, "Skillpunkte",
			"Ein Punkt je Level. Ausgeben im Hauptmenü unter „Fähigkeiten“.")
	_refresh()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, FADE_IN)
	(%OverviewTab as Control).grab_focus.call_deferred()


func close() -> void:
	if closed.get_connections().is_empty():
		get_tree().change_scene_to_file(MENU_SCENE)
		return
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


## Beide Leisten zeigen dieselbe Wahl; aufgeklappte Wortlisten bauen sich neu auf.
func _on_sort_changed(mode: int) -> void:
	_sort_mode = mode as SortMode
	for bar in _sort_bars:
		bar.set_mode(mode)
	for row in _unit_list.get_children():
		if row is ProgressRow:
			(row as ProgressRow).refill()
	_refresh_tasks()


## Baut die Sprachwahl vor dem Anzeigen. Mit nur einer Sprache bleibt die Leiste weg.
func _setup_languages() -> void:
	for book in ContentRegistry.all_books():
		_book_languages[book] = ContentRegistry.book_language(book)
	_language_choices = language_choices(_book_languages.keys(), func(b): return _book_languages[b])
	var languages := _language_choices
	if languages.size() < 2:
		_language_bar.visible = false
		return
		# Was es nicht mehr gibt, fällt aus der Wahl; bleibt nichts, gelten alle.
	var kept := _languages.filter(func(lang): return lang in languages)
	_language_bar.setup(languages, LANGUAGE_HINT)
	_language_bar.set_languages(kept if not kept.is_empty() else languages)
	_language_bar.changed.connect(_on_languages_changed)
	_filter = language_filter(_language_bar.selected(), languages)


## Je Sprache mit mindestens einem Buch eine, in der Reihenfolge von BookSelect.shelf_rows.
static func language_choices(books: Array, book_language: Callable) -> Array:
	var out: Array = []
	for row in BookSelect.shelf_rows(books, book_language):
		var lang := str(book_language.call((row as Array)[0]))
		if not lang.is_empty():
			out.append(lang)
	return out


func _on_languages_changed(languages: Array) -> void:
	_languages = languages
	_filter = language_filter(languages, _language_choices)
	_refresh()


## Leer, wenn alle Sprachen gewählt sind, sonst die Wahl.
static func language_filter(selected: Array, choices: Array) -> Array:
	return [] if choices.all(func(lang): return lang in selected) else selected.duplicate()


func _show_page(tab: Button) -> void:
	for each: Button in _pages:
		(_pages[each] as Control).visible = each == tab
	(%HandbookLink as HandbookLink).section = _handbook_sections[tab]


func _refresh() -> void:
	for title: Label in _filtered_titles:
		title.text = filtered_title(str(_filtered_titles[title]), _filter)
	_correct_by_day = SessionLog.correct_by_day()
	_battle_by_day = SessionLog.battle_ms_by_day()
	_refresh_streak()
	_refresh_accuracy()
	_refresh_battle()
	_refresh_numbers()
	_refresh_totals()
	_refresh_records()
	_refresh_curve()
	_refresh_lists()
	_refresh_wanted()
	_refresh_progress()
	_refresh_tasks()
	_refresh_badges()
	_refresh_achievements()


## „Lernkurve · Französisch, Latein“; ohne Filter ohne Namen.
static func filtered_title(title: String, languages: Array) -> String:
	if languages.is_empty():
		return title
	return "%s · %s" % [title, ", ".join(languages.map(Lexeme.language_name))]


## Tages-Serie und Monatsreihe. Der laufende Tag ist keine Lücke (SessionLog.current_streak).
func _refresh_streak() -> void:
	var streak := SessionLog.current_streak()
	_coin_strip.badge_days = badge_days(_badges.all_days(), _correct_by_day)
	_coin_strip.battle_ms = _battle_by_day
	_coin_strip.refresh()
	_show_day(_coin_strip.selected_day)
	_streak_label.text = "%d Tag%s" % [streak, "" if streak == 1 else "e"]
	if SessionLog.played_today():
		_streak_note.text = "Heute ist dabei"
	elif streak == 0:
		_streak_note.text = "Heute ist ein guter Tag dafür"
	else:
		_streak_note.text = "Heute fehlt noch — ein Lauf hält die Serie"


## Tage mit mindestens einer Plakette (Index -> true): gespeicherte und gerechnete Treffer.
static func badge_days(stored: Dictionary, correct_by_day: Dictionary) -> Dictionary:
	var out := {}
	for day: int in stored:
		if not (stored[day] as Array).is_empty():
			out[day] = true
	for day: int in correct_by_day:
		if Badges.reached_tier(Badges.HIT_STEPS, int(correct_by_day[day])) > 0:
			out[day] = true
	return out


## Das Band unter der Monatsreihe: die Plaketten des gewählten Tages. Die Höhe des Bandes
## steht fest (stats_screen.tscn).
func _show_day(day: int) -> void:
	for child in _day_badge_row.get_children():
		if child is BadgeChip:
			_day_badge_row.remove_child(child)
			child.queue_free()
	var today := SessionLog.local_day(int(Time.get_unix_time_from_system()))
	if day < 0:
		_day_badge_title.text = "Plaketten"
		_day_badge_empty.text = "Ein Klick auf einen Tag zeigt seine Plaketten."
		_day_badge_empty.visible = true
		return
	_day_badge_title.text = day_title(day == today, CoinStrip.date_label(day),
			int(_battle_by_day.get(day, 0)))
	var summary := Badges.day_summary(_badges.day_list(day), int(_correct_by_day.get(day, 0)))
	for entry: Dictionary in summary:
		var id := str(entry["id"])
		var count := int(entry["count"])
		var text := Badges.describe(id, int(entry["tier"]))
		_add_chip(_day_badge_row, Badges.make(id, int(entry["tier"])),
				"×%d" % count if count > 1 else "", str(text["title"]), str(text["body"]),
				"%d-mal an diesem Tag" % count if count > 1 else "")
	_day_badge_empty.visible = summary.is_empty()
	_day_badge_empty.text = day_empty_text(day == today, _correct_by_day.has(day))


## Überschrift des Tagesbands: „Plaketten · heute · 12 Min. im Kampf“.
static func day_title(today: bool, date: String, battle_ms: int) -> String:
	var text := "Plaketten · " + ("heute" if today else date)
	return text + " · %s im Kampf" % CoinStrip.duration_text(battle_ms) if battle_ms > 0 else text


## Was das Band ohne Plakette sagt.
static func day_empty_text(today: bool, played: bool) -> String:
	if today:
		return "Heute noch keine Plakette – im Kampf gibt es welche."
	return "An diesem Tag gab es keine Plakette." if played else "An diesem Tag nicht geübt."


func _add_chip(box: Container, badge: Dictionary, caption: String, title: String,
		body: String, note := "") -> BadgeChip:
	var chip := CHIP_SCENE.instantiate() as BadgeChip
	box.add_child(chip)
	chip.setup(badge, caption, title, body, note)
	return chip


## Reiter „Plaketten“: wie oft es jede Plakette im Kampf schon gab.
func _refresh_badges() -> void:
	_clear(_daily_list)
	var tally := Badges.tally(_badges.all_days(), _correct_by_day)
	for id: String in Badges.DAY_ORDER:
		var t: Dictionary = tally[id]
		if int(t["days"]) == 0:
			continue
		var tiered := id in ["hits", "kept"]
		var row := _add_badge_row(_daily_list, tally_title(id), tally_line(id, t))
		for tier in (range(1, Badges.TIER_NAMES.size() + 1) if tiered else [0]):
			var n := int((t["tiers"] as Array)[tier - 1]) if tiered else int(t["count"])
			if n == 0:
				continue
			var text := Badges.describe(id, tier)
			row.add_chip().setup(Badges.make(id, tier), "%d×" % n, str(text["title"]),
					str(text["body"]), ("an %d Tag%s" % [n, "" if n == 1 else "en"]) if tiered else "")
	if _daily_list.get_child_count() == 0:
		_add_line(_daily_list, "Noch keine Plakette – im Kampf gibt es welche.")


## Reiter „Erfolge“: freigeschaltete (jüngste zuerst), offene mit Stand, versteckte nur gezählt.
func _refresh_achievements() -> void:
	var languages := Achievements.languages()
	var catalog := Achievements.catalog(languages)
	var sorted := achievement_rows(catalog, AchievementBook.unlocked(),
			Achievements.live_facts(languages), reveal_hidden)
	var done: Array = sorted["unlocked"]
	(%AchievementCount as Label).text = "%d von %d Erfolgen" % [done.size(), catalog.size()]
	(%AchievementBar as ProgressBar).value = float(done.size()) / float(maxi(1, catalog.size()))
	_clear(%UnlockedList)
	_clear(%LockedList)
	for row: Dictionary in done:
		_add_achievement(%UnlockedList, row["entry"], int(row["at"]))
	if done.is_empty():
		_add_line(%UnlockedList, "Noch kein Erfolg – im Kampf und beim Lernen kommen sie von selbst.")
	for row: Dictionary in sorted["locked"]:
		_add_achievement(%LockedList, row["entry"], 0, row["progress"])
	var hidden := int(sorted["hidden"])
	if hidden > 0:
		_add_achievement(%LockedList, {"icon": Achievements.HIDDEN_ICON,
				"title": "%d versteckte%s Erfolg%s" % [hidden, "r" if hidden == 1 else "",
						"" if hidden == 1 else "e"],
				"body": "Was es dafür gibt, verrät niemand – du merkst es, wenn es so weit ist."}, 0)
	(%LockedRule as Control).visible = hidden > 0 or not (sorted["locked"] as Array).is_empty()


func _add_achievement(box: VBoxContainer, entry: Dictionary, unlocked_at: int,
		progress: Array = [0, 0]) -> void:
	var row := ACHIEVEMENT_ROW_SCENE.instantiate() as AchievementRow
	box.add_child(row)
	row.setup(entry, unlocked_at, progress)


## Ordnet den Katalog für den Reiter: {unlocked: [{entry, at}] jüngste zuerst, locked:
## [{entry, progress}] in Katalogfolge, hidden: Zahl der noch versteckten}. `unlocked` wie
## AchievementBook.unlocked, `facts` wie Achievements.live_facts; `reveal` zählt keine als versteckt.
static func achievement_rows(catalog: Array, unlocked: Dictionary, facts: Dictionary,
		reveal := false) -> Dictionary:
	var done: Array = []
	var open: Array = []
	var hidden := 0
	for entry: Dictionary in catalog:
		var id := str(entry["id"])
		if unlocked.has(id):
			done.append({"entry": entry, "at": int(unlocked[id]), "i": done.size()})
		elif bool(entry.get("hidden", false)) and not reveal:
			hidden += 1
		else:
			open.append({"entry": entry, "progress": Achievements.progress(entry, facts)})
	# Nachgetragene tragen denselben Zeitpunkt; dann gilt die Katalogfolge.
	done.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["at"]) > int(b["at"]) or (int(a["at"]) == int(b["at"]) and int(a["i"]) < int(b["i"])))
	return {"unlocked": done, "locked": open, "hidden": hidden}


func _add_badge_row(box: VBoxContainer, title: String, detail: String) -> BadgeRow:
	var row := BADGE_ROW_SCENE.instantiate() as BadgeRow
	box.add_child(row)
	row.setup(title, detail)
	return row


## Name einer Art in der Sammlung.
static func tally_title(id: String) -> String:
	match id:
		"hits":
			return "Treffer an einem Tag"
		"kept":
			return "Von gestern behalten"
	return str(Badges.describe(id, 0)["title"])


## Stand einer Art in der Sammlung, `t` aus Badges.tally (mindestens ein Tag).
static func tally_line(id: String, t: Dictionary) -> String:
	var days := int(t["days"])
	var line := "An %d Tag%s" % [days, "" if days == 1 else "en"]
	if id in Badges.PER_WAVE:
		line = "%d-mal, an %d Tag%s" % [int(t["count"]), days, "" if days == 1 else "en"]
	return "%s, zuletzt %s" % [line, short_date(int(t["last"]) * CoinStrip.DAY_SECONDS
			+ CoinStrip.NOON_SECONDS)]


func _refresh_numbers() -> void:
	var progress := PlayerLevel.progress()
	var in_level := int(progress["xp_in_level"])
	var for_level := int(progress["xp_for_level_up"])
	(%LevelLabel as Label).text = "Level %d" % int(progress["level"])
	(%XpBar as ProgressBar).value = float(in_level) / float(maxi(for_level, 1))
	(%XpLabel as Label).text = "%d / %d XP" % [in_level, for_level]
	(%XpTotal as Label).text = "Insgesamt " + PlayerLevel.label()
	(%GoldValue as Label).text = Wallet.digits()
	(%GoldText as Label).text = "Gold (Debug)" if Wallet.unlimited_gold else "Gold"
	(%ChestsValue as Label).text = str(Wallet.chests_opened)
	(%ChestsText as Label).text = "Schatzkiste%s geöffnet" % ("" if Wallet.chests_opened == 1 else "n")
		# Der offene Stand (verdient minus ausgegeben).
	var points := SkillBook.available()
	(%PointsValue as Label).text = str(points)
	(%PointsText as Label).text = "Skillpunkt%s offen" % ("" if points == 1 else "e")
	(%MasteredValue as Label).text = str(PlayerProgress.mastered_count(
			PROGRESS.MASTERY_CONFIDENCE, _filter))
	(%DueValue as Label).text = str(PlayerProgress.due_count(_filter))


func _refresh_accuracy() -> void:
	var lines := accuracy_lines(SessionLog.session_accuracy())
	_accuracy_label.text = str(lines["title"])
	_accuracy_which.text = str(lines["which"]) + ("" if _filter.is_empty() else " · alle Sprachen")
	_accuracy_trend.text = str(lines["detail"])


## Die Kampfzeit-Karte oben: alles zusammen, darunter der heutige Tag.
func _refresh_battle() -> void:
	var lines := battle_lines(SessionLog.battle_ms_total(), int(_battle_by_day.get(
			SessionLog.local_day(int(Time.get_unix_time_from_system())), 0)))
	_battle_label.text = str(lines["title"])
	_battle_note.text = str(lines["detail"])
	Hints.attach(%BattleCard as Control, "Kampfzeit",
			"So lange liefen deine Wellen und Bosskämpfe wirklich — ohne Pause, ohne Feiern "
			+ "und ohne die Zeit zwischen den Wellen. Wie viel auf einen Tag fällt, zeigt "
			+ "die Monatsreihe.")


## Kopfzahl und Unterzeile der Kampfzeit-Karte aus Gesamt- und heutiger Zeit (ms).
static func battle_lines(total_ms: int, today_ms: int) -> Dictionary:
	if total_ms <= 0:
		return {"title": "Noch kein Kampf",
				"detail": "Nach der ersten Welle steht hier, wie lange du gekämpft hast."}
	return {
		"title": CoinStrip.duration_text(total_ms),
		"detail": "Heute %s" % CoinStrip.duration_text(today_ms) if today_ms > 0
				else "Heute noch nicht gekämpft",
	}


func _refresh_totals() -> void:
	_clear(_total_lines)
	var days := SessionLog.played_day_count()
	_add_line(_total_lines, "Geübt an %d Tag%s%s" % [days, "" if days == 1 else "en",
			"" if _filter.is_empty() else " (alle Sprachen)"])
	_add_line(_total_lines, "Gesamt-Genauigkeit: %d %%" % int(round(
			PlayerProgress.overall_accuracy(_filter) * 100.0)))
	_add_line(_total_lines, "Gesehene Wörter: %d    Versuche: %d" % [
		PlayerProgress.seen_count(_filter), PlayerProgress.total_attempts(_filter)])
	var streak := _add_line(_total_lines, "Längste Wort-Serie: %d" % PlayerProgress.best_streak_overall(_filter))
	_attach_hint(streak, "Längste Wort-Serie",
			"So oft hast du eine einzelne Aufgabe hintereinander richtig beantwortet — "
			+ "am besten Wort gemessen, über alle Sitzungen und Tage hinweg. Ein Fehler "
			+ "bei genau diesem Wort setzt seine Serie auf 0.",
			"Nicht die Tages-Serie oben und nicht die Serie ohne Durchlass bei den Rekorden.")


## Kopfzahl, Unterzeile und Trendzeile aus SessionLog.accuracy_trend():
## { title, which, detail }. Ohne Vorsitzung kein Pfeil; unter der Mindestzahl an
## Antworten „3 von 4 richtig“ statt Prozent.
static func accuracy_lines(summary: Dictionary) -> Dictionary:
	var answers := int(summary.get("answers", 0))
	if answers == 0:
		return {
			"title": "Noch keine Sitzung",
			"which": "Genauigkeit",
			"detail": "Nach dem ersten Lauf steht hier, wie viele deiner Antworten gesessen haben.",
		}
	var which := "Diese Sitzung" if bool(summary.get("live", false)) else "Letzte Sitzung"
	var accuracy := float(summary.get("accuracy", -1.0))
	if accuracy < 0.0:
		return {
			"title": "%d von %d richtig" % [int(summary.get("correct", 0)), answers],
			"which": which,
			"detail": "Zu wenige Antworten für eine Quote — ab %d gibt es eine." % SessionLog.MIN_ACCURACY_ANSWERS,
		}
	var title := "%d %% richtig" % int(round(accuracy * 100.0))
	var baseline := float(summary.get("baseline", -1.0))
	if baseline < 0.0:
		return {"title": title, "which": which,
				"detail": "Noch kein Vergleich — der kommt mit der nächsten Sitzung."}
	var against := "den %d Tagen davor" % SessionLog.ACCURACY_WINDOW_DAYS \
			if str(summary.get("baseline_kind", "")) == "week" else "der Sitzung davor"
	var base_text := "%d %%" % int(round(baseline * 100.0))
		# Auf die angezeigten Prozente gerechnet, damit „84 % gegen 80 %“ nicht „3 Punkte“ heißt.
	var delta := int(round(accuracy * 100.0)) - int(round(baseline * 100.0))
	if absi(delta) < TREND_STEADY_POINTS:
		return {"title": title + "  →", "which": which,
				"detail": "So gut wie in %s (%s)." % [against, base_text]}
	if delta > 0:
		return {"title": title + "  ↑", "which": which,
				"detail": "%d Punkte über %s (%s)." % [delta, against, base_text]}
	return {"title": title + "  ↓", "which": which,
			"detail": "%d Punkte unter %s (%s) — schwere Wörter drücken die Quote, das ist kein Rückschritt." % [-delta, against, base_text]}


func _refresh_records() -> void:
	_clear(_record_list)
	var rows := record_rows(SessionLog.records())
	if rows.is_empty():
		_add_line(_record_list, "Noch kein Lauf gespielt — die Bestwerte kommen mit der ersten Welle.")
		return
	for i in rows.size():
		if i > 0:
			var line := HSeparator.new()
			line.theme_type_variation = &"StatRule"
			_record_list.add_child(line)
		var row: Dictionary = rows[i]
		var record := RECORD_ROW_SCENE.instantiate() as StatRow
		_record_list.add_child(record)
		record.setup(str(row["label"]), str(row["value"]), str(row["mark"]), str(row["hint"]))


## Die Kampf-Rekorde als Zeilen { label, value, mark, hint } aus SessionLog.records().
## Ohne Sitzung leer.
static func record_rows(records: Dictionary) -> Array:
	if int(records.get("sessions", 0)) == 0:
		return []
	var rows: Array = [
		{
			"label": "Höchste geräumte Welle",
			"value": "%d" % int(records.get("highest_wave_cleared", 0)),
			"mark": "",
			"hint": "Wellen laufen strikt in Folge — zugleich die Wellenzahl deines besten Laufs",
		},
		{
			"label": "Längste Serie ohne Durchlass",
			"value": "%d Monster" % int(records.get("best_no_leak_streak", 0)),
			"mark": "",
			"hint": "erledigte Monster am Stück; ein aufgefangener Treffer bricht sie trotzdem",
		},
		{
			"label": "Monster besiegt",
			"value": "%d" % int(records.get("monsters_defeated", 0)),
			"mark": "",
			"hint": "über alle Läufe zusammen",
		},
	]
	# Der höchste der lauf-eigenen Tiefstände. Abgebrochene Läufe schreiben ihn nicht mit,
	# dann fehlt die Zeile.
	var floor_hp := int(records.get("best_fortress_floor", -1))
	if floor_hp >= 0:
		rows.append({
			"label": "Schonendster Lauf",
			"value": "nie unter %d HP" % floor_hp,
			"mark": "🛡️" if floor_hp >= SPOTLESS_FORTRESS_HP else "",
			"hint": "tiefster HP-Stand deines saubersten Laufs; das Schild gibt es ab %d HP" % SPOTLESS_FORTRESS_HP,
		})
	return rows


## Lernkurve: kumulierte gemeisterte Aufgaben je Wochenende (PlayerProgress.mastery_curve).
func _refresh_curve() -> void:
	var curve := PlayerProgress.mastery_curve(PROGRESS.CURVE_WEEKS, -1, _filter)
	var values: Array = []
	for point in curve:
		values.append(int(point["count"]))
	# Die Achse beginnt am Anfang der ersten Woche, nicht an ihrem Ende.
	var start := int(curve[0]["end"]) - 7 * 86400
	_curve.show_series(values, short_date(start), "heute")

	var first := int(values[0])
	var last := int(values[values.size() - 1])
	if last == 0:
		_curve_caption.text = "Noch keine gemeisterte Aufgabe — die erste hebt die Linie."
	elif last == first:
		_curve_caption.text = "%d gemeistert, alle vor diesem Zeitraum — die nächste hebt die Linie." % last
	else:
		_curve_caption.text = "%d dazugekommen in %d Wochen — jetzt %d gemeistert." % [
			last - first, curve.size(), last]


## Kurzes Datum „9.6." für die Achsen-Beschriftung.
static func short_date(unix: int) -> String:
	var d := Time.get_datetime_dict_from_unix_time(unix)
	return "%d.%d." % [int(d["day"]), int(d["month"])]


## „Frisch gemeistert“: Aufgaben mit erster Meisterung ab `since` (unix), jüngste zuerst,
## gekappt auf `limit`. Records ohne Zeitstempel (mastered_at = 0) bleiben außen vor, wie
## in PlayerProgress.mastered_since.
static func fresh_rows(rows: Array, since: int, limit := LIST_COUNT) -> Array:
	var fresh: Array = []
	for row in rows:
		var at := int(row.get("mastered_at", 0))
		if at > 0 and at >= since:
			fresh.append(row)
	fresh.sort_custom(func(a, b): return int(a["mastered_at"]) > int(b["mastered_at"]))
	return fresh.slice(0, limit)


## „Comeback“: mindestens `min_misses` Mal entwischt und jetzt gemeistert; meiste
## Fehlversuche zuerst, dann jüngste Meisterung. Ohne Zeitfenster.
static func comeback_rows(rows: Array, limit := LIST_COUNT, min_misses := COMEBACK_MISSES) -> Array:
	var comeback: Array = []
	for row in rows:
		if bool(row["mastered"]) and misses(row) >= min_misses:
			comeback.append(row)
	comeback.sort_custom(func(a, b):
		if misses(a) == misses(b):
			return int(a.get("mastered_at", 0)) > int(b.get("mastered_at", 0))
		return misses(a) > misses(b))
	return comeback.slice(0, limit)


func _refresh_lists() -> void:
	var rows := PlayerProgress.records_for_display(_filter)
	var since := int(Time.get_unix_time_from_system()) - FRESH_DAYS * 86400

	_clear(_fresh_list)
	var fresh := fresh_rows(rows, since)
	if fresh.is_empty():
		_add_line(_fresh_list, "Diese Woche noch keins — das nächste sitzt bald.")
	for row in fresh:
		_add_row(_fresh_list, str(row["label"]), _when(int(row["mastered_at"])), "✓")

	_clear(_comeback_list)
	var comeback := comeback_rows(rows)
	if comeback.is_empty():
		_add_line(_comeback_list, "Noch keins — dafür muss ein Wort erst dreimal entwischen.")
	for row in comeback:
		_add_row(_comeback_list, str(row["label"]), "%d× entwischt" % misses(row), "✓")


## „heute“ / „gestern“ / „vor 3 Tagen“, nach lokalen Tagen wie die Tages-Serie
## (SessionLog.local_day).
func _when(unix: int) -> String:
	var days := SessionLog.local_day(int(Time.get_unix_time_from_system())) - SessionLog.local_day(unix)
	if days <= 0:
		return "heute"
	if days == 1:
		return "gestern"
	return "vor %d Tagen" % days


## Die Fahndungsfälle: nur Aufgaben mit Fehlversuch (ein neues Wort hat schon vom Prior eine
## niedrige Confidence), schwächste Confidence zuerst, dann die meisten Fehlversuche.
static func wanted_rows(rows: Array, limit := WANTED_COUNT) -> Array:
	var wanted: Array = []
	for row in rows:
		if misses(row) > 0:
			wanted.append(row)
	wanted.sort_custom(func(a, b):
		if is_equal_approx(float(a["confidence"]), float(b["confidence"])):
			return misses(a) > misses(b)
		return float(a["confidence"]) < float(b["confidence"]))
	return wanted.slice(0, limit)


func _refresh_wanted() -> void:
	_clear(_wanted_list)
	var wanted := wanted_rows(PlayerProgress.records_for_display(_filter))
	if wanted.is_empty():
		_add_line(_wanted_list, "Noch ist dir kein Wort entwischt. 👏")
		return
	for row in wanted:
		_add_row(_wanted_list, str(row["label"]),
				"%d× entwischt" % misses(row), _percent(row))


## Fortschrittsbalken je Unit im Curriculum-Scope aus dem Session-Setup (ohne Auswahl der
## ganze Katalog). Die Themen-Auswahl zählt nicht mit (Handbuch Kapitel 12); die Sprachwahl
## lässt nur die Bücher ihrer Sprache stehen.
func _refresh_progress() -> void:
	var pool := ContentRegistry.lexemes_scoped(UserSettings.selected_scope(), []) \
			.filter(PROGRESS.masterable) \
			.filter(func(e): return _filter.is_empty() \
					or _book_languages.get(str(e.get("book", "")), "") in _filter)
	var mastered := PlayerProgress.mastered_lexemes()
	# Die Festungsstufe wertet die ganze Unit (FortressTier.run_tier), daher der Katalog.
	var tiers := FortressTier.unit_tiers(ContentRegistry.lexemes.values(), mastered,
			FortressTier.drop_of(SkillBook.bonuses()))
	var units := unit_rows(pool, mastered, ContentRegistry.book_label)
	for row in units:
		var tier := int((tiers.get(str(row["key"]), {}) as Dictionary).get("tier", 0))
		row["label"] = "%s  · 🏰 Stufe %d" % [row["label"], tier]
	units = with_bonus_rows(units, ContentRegistry.bonuses_of, PlayerProgress.is_mastered,
			func(book): return MapLayout.data(str(book)))
	_fill_progress(_unit_list, units, "Keine Units im gewählten Bereich.")


## Fortschrittszeilen je Unit: { key, label, done, total, lexemes }, nach Buch und Unit
## sortiert, gezählt in FortressTier.unit_tiers. `book_label` ist ContentRegistry.book_label.
static func unit_rows(lexemes: Array, mastered: Dictionary, book_label: Callable) -> Array:
	var groups := FortressTier.unit_tiers(lexemes, mastered)
	var keys: Array = groups.keys()
	# Numerisch, sonst stünde Unit 10 vor Unit 2.
	keys.sort_custom(func(a, b):
		var ga: Dictionary = groups[a]
		var gb: Dictionary = groups[b]
		if ga["book"] != gb["book"]:
			return str(ga["book"]) < str(gb["book"])
		return int(ga["unit"]) < int(gb["unit"]))
	var rows: Array = []
	for key in keys:
		var group: Dictionary = groups[key]
		rows.append({
			"key": key,
			"label": "%s, %s" % [book_label.call(group["book"]),
					BookNaming.unit_label(str(group["book"]), int(group["unit"]))],
			"done": int(group["done"]), "total": int(group["total"]),
			"lexemes": group["lexemes"],
		})
	return rows


## Je Bonus der Unit eine Zeile darunter (ADR 0012): { key, label, done, total, bonus },
## gezählt in Aufgaben (BonusLevel.counts). Callables: ContentRegistry.bonuses_of, MapLayout.data.
static func with_bonus_rows(units: Array, bonuses_of: Callable, is_mastered: Callable,
		layout: Callable) -> Array:
	var out: Array = []
	for row in units:
		out.append(row)
		var key := str(row.get("key", ""))
		var book := key.get_slice("/", 0)
		for bonus in bonuses_of.call(book, int(key.get_slice("/", 1))):
			var counted := BonusLevel.counts(bonus, is_mastered)
			out.append({
				"key": str(bonus["key"]),
				"label": "Bonus: %s" % BonusLevel.title(bonus, layout.call(book)),
				"done": int(counted["done"]), "total": int(counted["total"]), "bonus": bonus,
			})
	return out


## Die Aufgaben eines Bonus mit Prozentstand, die sichersten zuerst.
static func bonus_lines(bonus: Dictionary, conf: Callable, describe: Callable) -> Array:
	var rows: Array = []
	for id in bonus.get("task_ids", []):
		rows.append({"id": str(id), "confidence": float(conf.call(str(id)))})
	rows.sort_custom(func(a, b): return float(a["confidence"]) > float(b["confidence"]))
	return rows.map(func(r): return {
		"label": str(describe.call(str(r["id"]))),
		"value": percent_label(float(r["confidence"])),
		"mark": "✓" if float(r["confidence"]) >= PROGRESS.MASTERY_CONFIDENCE else "",
	})


## Die Wörter einer Gruppe mit ihrem Prozentstand, sortiert nach `sort` (`sort_rows`).
## Der Prozentstand ist die schwächere Übersetzungsrichtung, bei unregelmäßigen Verben
## auch die Formen (`requirements`) — dieselbe Rechnung wie PlayerProgress.mastered_lexemes.
## Die übrigen Aufgaben zählen nicht in die Meisterung; sie fahren als `extras` mit.
## `conf` liefert die Confidence einer Aufgabe, -1 für „kein Record“; `learnables` alle
## learnable_ids eines Lexems (WaveGenerator.learnables_of).
static func word_rows(lexemes: Array, conf: Callable, learnables := Callable(),
		requirements: Dictionary = {}, sort := SortMode.BEST_FIRST) -> Array:
	var rows: Array = []
	for entry in lexemes:
		var id := str(entry.get("id", ""))
		var directions: Array = []
		var weakest := 1.0
		var seen := false
		for direction in Lexeme.mastery_directions(Lexeme.language(entry)):
			var value := float(conf.call("translate:%s:%s" % [direction, id]))
			directions.append({"direction": direction, "confidence": value})
			if value < 0.0:
				# Ohne Record zieht die Richtung auf 0, macht das Wort aber nicht zum geübten.
				value = 0.0
			else:
				seen = true
			weakest = minf(weakest, value)
		for required in requirements.get(id, []):
			if not str(required).begins_with("translate:"):
				weakest = minf(weakest, maxf(0.0, float(conf.call(required))))
		rows.append({
			"label": word_label(entry),
			"confidence": weakest if seen else -1.0,
			"directions": directions,
			"extras": extra_rows(entry, conf, learnables),
		})
	return sort_rows(rows, sort)


## Ordnet Zeilen mit `label` und `confidence` (-1 = nie geübt) nach `mode`. Nach Stand
## stehen nie geübte alphabetisch am Ende, gleiche Stände alphabetisch.
static func sort_rows(rows: Array, mode := SortMode.BEST_FIRST) -> Array:
	rows.sort_custom(func(a, b):
		var la := str(a["label"])
		var lb := str(b["label"])
		if mode == SortMode.ALPHABETICAL:
			return la.naturalnocasecmp_to(lb) < 0
		var ca := float(a["confidence"])
		var cb := float(b["confidence"])
		if (ca < 0.0) != (cb < 0.0):
			return cb < 0.0
		if ca == cb or ca < 0.0:
			return la.naturalnocasecmp_to(lb) < 0
		return ca > cb if mode == SortMode.BEST_FIRST else ca < cb)
	return rows


## Die Aufgaben eines Wortes außer den Übersetzungsrichtungen, gemeisterte zuerst:
## { id, confidence, mastered }.
static func extra_rows(entry: Dictionary, conf: Callable, learnables: Callable) -> Array:
	if not learnables.is_valid():
		return []
	var out: Array = []
	for id in learnables.call(entry):
		if str(id).begins_with("translate:"):
			continue
		var value := float(conf.call(id))
		out.append({
			"id": str(id), "confidence": value,
			"mastered": value >= PROGRESS.MASTERY_CONFIDENCE,
		})
	out.sort_custom(func(a, b): return float(a["confidence"]) > float(b["confidence"]))
	return out


## Dieselben Zeilen für StatRow: { label, value, mark, hint_list }; je Zusatzaufgabe ★ (sitzt)
## oder ☆. `describe` ist TaskResolver.describe_learnable.
static func word_lines(lexemes: Array, conf: Callable, learnables := Callable(),
		describe := Callable(), requirements: Dictionary = {},
		sort := SortMode.BEST_FIRST) -> Array:
	var lines: Array = []
	for row in word_rows(lexemes, conf, learnables, requirements, sort):
		var value := float(row["confidence"])
		var mastered: bool = value >= PROGRESS.MASTERY_CONFIDENCE
		var extras: Array = row["extras"]
		var mark := "✓" if mastered else ""
		for extra in extras:
			mark += "★" if bool(extra["mastered"]) else "☆"
		lines.append({
			"label": str(row["label"]),
			# Nie geübt ist nicht „0 %“.
			"value": "noch nicht geübt" if value < 0.0 else "%d %%" % int(round(value * 100.0)),
			"mark": mark,
			"hint_list": word_hint(row, describe),
		})
	return lines


## Zeilen der Hinweiskarte für eine Wortzeile: `[zeichen, bezeichnung, wert]`, je Richtung
## und je Zusatzaufgabe eine. Das Wort selbst ist die Überschrift (`StatRow.setup`).
static func word_hint(row: Dictionary, describe := Callable()) -> Array:
	var lines: Array = []
	for direction in row.get("directions", []):
		var value := float(direction["confidence"])
		lines.append(["✓" if value >= PROGRESS.MASTERY_CONFIDENCE else "",
				"Übersetzung " + Lexeme.direction_label(str(direction["direction"]), "→"),
				percent_label(value)])
	for extra in row.get("extras", []):
		var name_text := str(extra["id"])
		if describe.is_valid():
			name_text = str(describe.call(str(extra["id"])))
		lines.append(["★" if bool(extra["mastered"]) else "☆", name_text,
				percent_label(float(extra["confidence"]))])
	return lines


## Prozent einer Aufgabe, oder „noch nicht geübt" für einen Stand, den es nicht gibt.
static func percent_label(confidence: float) -> String:
	if confidence < 0.0:
		return "noch nicht geübt"
	return "%d %%" % int(round(confidence * 100.0))


## Ein Wort in beiden Sprachen, „house — Haus“.
static func word_label(entry: Dictionary) -> String:
	var foreign := Lexeme.foreign(entry)
	var de := str(entry.get("lemma_de", ""))
	if foreign.is_empty() or de.is_empty():
		return foreign if de.is_empty() else de
	return "%s — %s" % [foreign, de]


func _fill_progress(box: VBoxContainer, rows: Array, empty_text: String) -> void:
	_clear(box)
	if rows.is_empty():
		_add_line(box, empty_text)
		return
	for row in rows:
		var bar := PROGRESS_ROW_SCENE.instantiate() as ProgressRow
		box.add_child(bar)
		if row.has("bonus"):
			var bonus: Dictionary = row["bonus"]
			bar.setup(str(row["label"]), int(row["done"]), int(row["total"]),
					func(): return bonus_lines(bonus, PlayerProgress.confidence.bind(-1.0),
							_resolver.describe_learnable), true)
			continue
		var lexemes: Array = row.get("lexemes", [])
		# Erst beim Aufklappen gerufen (ProgressRow).
		bar.setup(str(row["label"]), int(row["done"]), int(row["total"]),
				func(): return word_lines(lexemes, PlayerProgress.confidence.bind(-1.0),
						_generator.learnables_of, _resolver.describe_learnable,
						ContentRegistry.form_requirements(), _sort_mode))


## Alle geübten Aufgaben, eine Zeile je learnable_id, sortiert nach `sort_rows`.
func _refresh_tasks() -> void:
	_clear(_task_list)
	var rows := sort_rows(PlayerProgress.records_for_display(_filter), _sort_mode)
	if rows.is_empty():
		_add_line(_task_list, "Noch keine Aufgabe geübt.")
		return
	for row in rows:
		_add_row(_task_list, str(row["label"]), _percent(row),
				"✓" if bool(row["mastered"]) else "")


static func misses(row: Dictionary) -> int:
	return int(row["attempts"]) - int(row["correct"])


func _percent(row: Dictionary) -> String:
	return "%d %%" % int(round(float(row["confidence"]) * 100.0))


func _clear(box: VBoxContainer) -> void:
	for child in box.get_children():
		child.queue_free()


## Umbrechend, sonst drückt ein langer Leertext das Fenster breiter als das Bild.
func _add_line(box: VBoxContainer, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(label)
	return label


## Hinweiskarte für eine schlichte Zeile. Ein Label ignoriert die Maus von Haus aus, daher PASS.
func _attach_hint(label: Label, title: String, body: String, note := "") -> void:
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	Hints.attach(label, title, body, note)


func _add_row(box: VBoxContainer, name_text: String, value_text: String, mark_text := "",
		hint := "") -> void:
	var row := ROW_SCENE.instantiate() as StatRow
	box.add_child(row)
	row.setup(name_text, value_text, mark_text, hint)
