extends Control
## Statistik-Screen: Zahlen zum Lernstand, Fahndungsliste, Wortliste (Issue #5).
##
## Ausgelagert aus dem Einstellungs-Screen. Dort hing die Statistik zwischen
## Profilauswahl, Reset und Melde-Token — sie ist aber der motivierende Teil und
## verdient einen eigenen Screen, direkt vom Start-Screen (profile_menu) aus erreichbar.
##
## Das Layout liegt in stats_screen.tscn (im Editor gestaltbar), die Zeilen-Vorlage in
## stat_row.tscn, die Tages-Leiste in coin_strip.tscn; hier wird nur befüllt. Die
## weiteren Verlaufs-Statistiken (Lernkurve, Fortschritt pro Unit, Kampf-Rekorde) kommen
## als weitere Abschnitte in den Reiter „Überblick"; die Daten dafür liegen in SessionLog
## und PlayerProgress bereit.

const MENU_SCENE := "res://scenes/ui/profile_menu.tscn"
const ROW_SCENE := preload("res://scenes/ui/stat_row.tscn")
const PROGRESS_ROW_SCENE := preload("res://scenes/ui/progress_row.tscn")

## So viele Wörter stehen auf der Fahndungsliste. Kurz halten: eine lange Liste ist
## keine Fahndung mehr, sondern die Wortliste im zweiten Reiter.
const WANTED_COUNT := 5

@onready var _streak_label: Label = %StreakLabel
@onready var _coin_label: Label = %CoinLabel
@onready var _coin_strip: CoinStrip = %CoinStrip
@onready var _stat_lines: VBoxContainer = %StatLines
@onready var _curve: StatsChart = %Curve
@onready var _curve_caption: Label = %CurveCaption
@onready var _wanted_list: VBoxContainer = %WantedList
@onready var _unit_list: VBoxContainer = %UnitList
@onready var _tag_list: VBoxContainer = %TagList
@onready var _word_list: VBoxContainer = %WordList


func _ready() -> void:
	(%BackButton as Button).pressed.connect(func(): get_tree().change_scene_to_file(MENU_SCENE))
	_refresh()


func _refresh() -> void:
	_refresh_streak()
	_refresh_numbers()
	_refresh_curve()
	_refresh_wanted()
	_refresh_progress()
	_refresh_words()


## Tages-Serie und Goldstück-Leiste (Issue #6).
##
## Die Leiste zeigt einen wachsenden Vorrat statt eines Monatsrasters: ein Kalender führt
## vor allem Lücken vor und liest sich wie eine Buchhaltung. Die Bilanzzeile darunter
## nennt den Gesamtvorrat und sagt bei offenem Tag, dass heute noch eines zu holen ist —
## der laufende Tag ist keine Lücke (SessionLog.current_streak zählt ihn auch nicht als
## solche), das soll man lesen können und nicht an der Zahl ablesen müssen.
func _refresh_streak() -> void:
	var streak := SessionLog.current_streak()
	_coin_strip.refresh()

	if streak == 0:
		_streak_label.text = "Noch keine Serie — heute ist ein guter Tag dafür."
	elif streak == 1:
		_streak_label.text = "🔥 1 Tag in Folge geübt"
	else:
		_streak_label.text = "🔥 %d Tage in Folge geübt" % streak

	var total := SessionLog.played_day_count()
	_coin_label.text = "🪙 %d Goldstück%s gesammelt" % [total, "" if total == 1 else "e"]
	if SessionLog.played_today():
		_coin_label.text += " — das von heute ist drin."
	else:
		_coin_label.text += " — heute wartet noch eines."


func _refresh_numbers() -> void:
	_clear(_stat_lines)
	_add_line(_stat_lines, "Gemeisterte Aufgaben: %d  (Festungsstufe %d)" % [
		PlayerProgress.mastered_count(), PlayerProgress.fortress_tier()])
	_add_line(_stat_lines, "Gesamt-Genauigkeit: %d %%" % int(round(PlayerProgress.overall_accuracy() * 100.0)))
	_add_line(_stat_lines, "Gesehene Wörter: %d    Versuche: %d" % [
		PlayerProgress.seen_count(), PlayerProgress.total_attempts()])
	_add_line(_stat_lines, "Beste Serie: %d" % PlayerProgress.best_streak_overall())
	_add_line(_stat_lines, "Heute fällig: %d" % PlayerProgress.due_count())


## Lernkurve „gemeisterte Aufgaben" (Issue #7).
##
## Gezeichnet wird die kumulierte Zahl je Wochenende (PlayerProgress.mastery_curve) —
## eine Linie, die nicht zurückgeht. Die Bilanzzeile darunter sagt, was im Zeitraum
## dazugekommen ist: eine Kurve ohne Zahl liest sich, aber man nimmt nichts mit.
func _refresh_curve() -> void:
	var curve := PlayerProgress.mastery_curve()
	var values: Array = []
	for point in curve:
		values.append(int(point["count"]))
	# Anfang der Zeitachse ist der BEGINN der ersten Woche, nicht ihr Ende.
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


## Wählt die Fahndungsfälle aus den Zeilen von PlayerProgress.records_for_display():
## schwächste Confidence zuerst, bei gleicher Confidence die mit den meisten
## Fehlversuchen, gekappt auf `limit`.
##
## Bewusst nur Wörter mit mindestens einem Fehlversuch. Ein neues Wort hat von Haus aus
## eine niedrige Confidence (der CEFR/Frequenz-Prior, siehe WaveGenerator) und stünde
## sonst ganz oben, ohne je falsch beantwortet worden zu sein — ein Fahndungsfall ist es
## erst, wenn es einmal entwischt ist.
##
## Statisch und ohne Zugriff auf Autoloads oder Szene, damit die Regel für sich prüfbar
## bleibt (siehe tests/stats_screen_test.gd).
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
	var wanted := wanted_rows(PlayerProgress.records_for_display())
	if wanted.is_empty():
		_add_line(_wanted_list, "Noch ist dir kein Wort entwischt. 👏")
		return
	for row in wanted:
		_add_row(_wanted_list, str(row["label"]),
				"%d× entwischt" % misses(row), _percent(row))


## Fortschrittsbalken pro Unit und pro Thema (Issue #8).
##
## Der Bezugsrahmen ist der Curriculum-Scope aus dem Session-Setup: angezeigt werden nur
## Units und Themen, die darin überhaupt vorkommen. Ohne Auswahl ist es der ganze
## Katalog. Die Themen-Auswahl (die zweite Achse) bleibt hier bewusst außen vor — sonst
## stünde bei „Unit 6: 8 von 12" nur der ausgewählte Teil der Unit, und die Zahl wäre
## nicht die, nach der ein Elternteil oder eine Lehrkraft fragt.
func _refresh_progress() -> void:
	var pool := ContentRegistry.lexemes_scoped(UserSettings.selected_scope(), [])
	var mastered := PlayerProgress.mastered_lexemes()
	_fill_progress(_unit_list, unit_rows(pool, mastered, ContentRegistry.book_label),
			"Keine Units im gewählten Bereich.")
	_fill_progress(_tag_list, tag_rows(pool, mastered), "Noch keine Themen im gewählten Bereich.")


## Fortschrittszeilen je Unit: { label, done, total }, nach Buch und Unit sortiert.
## Lexeme ohne Buch/Unit (Grundwortschatz) haben keine Unit und bleiben außen vor.
## `book_label` benennt das Buch für die Anzeige (ContentRegistry.book_label).
##
## Statisch und ohne Autoload, damit die Zählung für sich prüfbar bleibt
## (siehe tests/mastered_lexemes_test.gd).
static func unit_rows(lexemes: Array, mastered: Dictionary, book_label: Callable) -> Array:
	var groups := {}
	for entry in lexemes:
		var book := str(entry.get("book", ""))
		if book.is_empty() or not entry.has("unit"):
			continue
		_count_into(groups, "%s/%04d" % [book, int(entry["unit"])], entry, mastered)
	var keys: Array = groups.keys()
	keys.sort()
	var rows: Array = []
	for key in keys:
		var parts := str(key).split("/")
		var group: Dictionary = groups[key]
		rows.append({
			"label": "%s, Unit %d" % [book_label.call(parts[0]), int(parts[1])],
			"done": int(group["done"]), "total": int(group["total"]),
		})
	return rows


## Fortschrittszeilen je Thema (Lexem-Tag), alphabetisch. Ein Lexem mit mehreren Tags
## zählt in jedem davon mit — die Themen sind keine Aufteilung, sondern Sichten.
static func tag_rows(lexemes: Array, mastered: Dictionary) -> Array:
	var groups := {}
	for entry in lexemes:
		for tag in entry.get("tags", []):
			_count_into(groups, str(tag), entry, mastered)
	var keys: Array = groups.keys()
	keys.sort()
	var rows: Array = []
	for key in keys:
		var group: Dictionary = groups[key]
		rows.append({
			"label": str(key), "done": int(group["done"]), "total": int(group["total"]),
		})
	return rows


## Zählt ein Lexem in die Gruppe `key`: eines mehr insgesamt, und eines mehr gemeistert,
## wenn es in der Menge steht (siehe PlayerProgress.mastered_lexemes).
static func _count_into(groups: Dictionary, key: String, entry: Dictionary, mastered: Dictionary) -> void:
	if not groups.has(key):
		groups[key] = {"done": 0, "total": 0}
	groups[key]["total"] += 1
	if mastered.has(str(entry.get("id", ""))):
		groups[key]["done"] += 1


func _fill_progress(box: VBoxContainer, rows: Array, empty_text: String) -> void:
	_clear(box)
	if rows.is_empty():
		_add_line(box, empty_text)
		return
	for row in rows:
		var bar := PROGRESS_ROW_SCENE.instantiate() as ProgressRow
		box.add_child(bar)
		bar.setup(str(row["label"]), int(row["done"]), int(row["total"]))


## Alle geübten Wörter, schwächste Confidence zuerst (die Sortierung liefert
## PlayerProgress). Der Haken markiert die gemeisterten.
func _refresh_words() -> void:
	_clear(_word_list)
	var rows := PlayerProgress.records_for_display()
	if rows.is_empty():
		_add_line(_word_list, "Noch keine Wörter geübt.")
		return
	for row in rows:
		_add_row(_word_list, str(row["label"]), _percent(row),
				"✓" if bool(row["mastered"]) else "")


## Fehlversuche einer Aufgabe: Versuche minus korrekte Antworten.
static func misses(row: Dictionary) -> int:
	return int(row["attempts"]) - int(row["correct"])


func _percent(row: Dictionary) -> String:
	return "%d %%" % int(round(float(row["confidence"]) * 100.0))


func _clear(box: VBoxContainer) -> void:
	for child in box.get_children():
		child.queue_free()


func _add_line(box: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	box.add_child(label)


func _add_row(box: VBoxContainer, name_text: String, value_text: String, mark_text := "") -> void:
	var row := ROW_SCENE.instantiate() as StatRow
	box.add_child(row)
	row.setup(name_text, value_text, mark_text)
