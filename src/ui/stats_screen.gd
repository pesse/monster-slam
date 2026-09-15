extends Control
## Statistik-Screen: Zahlen zum Lernstand, Lernkurve, Listen, Fortschritt, Wortliste.
##
## Ausgelagert aus dem Einstellungs-Screen. Dort hing die Statistik zwischen
## Profilauswahl, Reset und Melde-Token — sie ist aber der motivierende Teil und
## verdient einen eigenen Screen, direkt vom Start-Screen (profile_menu) aus erreichbar.
##
## Das Layout liegt in stats_screen.tscn (im Editor gestaltbar), die Zeilen-Vorlagen in
## stat_row.tscn und progress_row.tscn, die Tages-Leiste in coin_strip.tscn, der
## Zeichen-Control der Kurve in stats_chart.gd; hier wird nur befüllt.
##
## Drei Reiter: „Überblick" trägt die Abschnitte, die zum Weiterspielen motivieren
## (Tages-Serie #6, Kennzahlen #5, Lernkurve #7, frisch gemeistert und Comeback #9,
## Fahndungsliste #5), „Fortschritt" die Balken pro Unit und Thema (#8) — die wachsen mit
## dem Katalog und schöben im Überblick alles andere aus dem Bild —, „Wörter" die
## vollständige Liste. Ein Balken lässt sich aufklappen und zeigt dann die Wörter SEINER
## Gruppe mit Prozentstand: „18 von 24" sagt nicht, welche sechs fehlen, und im Reiter
## „Wörter" stehen sie zwischen allen anderen. Was noch fehlt (Kampf-Rekorde), liegt in SessionLog bereit.

const MENU_SCENE := "res://scenes/ui/profile_menu.tscn"
const ROW_SCENE := preload("res://scenes/ui/stat_row.tscn")
const PROGRESS_ROW_SCENE := preload("res://scenes/ui/progress_row.tscn")
## Für die Schwellen und Richtungen der Meisterung in den statischen Funktionen —
## der Autoload PlayerProgress ist dasselbe Skript, aber nicht statisch erreichbar.
const PROGRESS := preload("res://src/learning/player_progress.gd")

## So viele Wörter stehen auf der Fahndungsliste. Kurz halten: eine lange Liste ist
## keine Fahndung mehr, sondern die Wortliste im zweiten Reiter.
const WANTED_COUNT := 5
## So viele Einträge zeigen „Frisch gemeistert" und „Comeback" — aus demselben Grund
## gekappt wie die Fahndungsliste.
const LIST_COUNT := 5
## „Frisch" ist die letzte Woche.
const FRESH_DAYS := 7
## Ab so vielen Fehlversuchen ist eine wiedergewonnene Aufgabe ein Comeback.
const COMEBACK_MISSES := 3

@onready var _streak_label: Label = %StreakLabel
@onready var _coin_label: Label = %CoinLabel
@onready var _coin_strip: CoinStrip = %CoinStrip
@onready var _stat_lines: VBoxContainer = %StatLines
@onready var _curve: StatsChart = %Curve
@onready var _curve_caption: Label = %CurveCaption
@onready var _fresh_list: VBoxContainer = %FreshList
@onready var _comeback_list: VBoxContainer = %ComebackList
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
	_refresh_lists()
	_refresh_wanted()
	_refresh_progress()
	_refresh_words()


## Tages-Serie und Tages-Leiste (Issue #6).
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
	_coin_label.text = "🪙 An %d Tag%s geübt" % [total, "" if total == 1 else "en"]
	if SessionLog.played_today():
		_coin_label.text += " — heute ist dabei."
	else:
		_coin_label.text += " — heute fehlt noch."


func _refresh_numbers() -> void:
	_clear(_stat_lines)
	# Der Goldstand zuerst: er ist das einzige, was man ausgeben kann, und die Kisten
	# sagen, wie oft es dafür schon einen Grund gab.
	_add_line(_stat_lines, "💰 %s  (%d Schatzkiste%s geöffnet)" % [
		Wallet.label(), Wallet.chests_opened, "" if Wallet.chests_opened == 1 else "n"])
	# Danach das Level: es sagt, wie lange schon gespielt wird, und führt die Skillpunkte
	# mit. Gezeigt wird der OFFENE Stand (verdient minus ausgegeben) und dazu, wohin man
	# damit geht — ein Punktestand ohne Weg wäre eine offene Frage.
	var progress := PlayerLevel.progress()
	var points := SkillBook.available()
	_add_line(_stat_lines, "⭐ Level %d  (%d/%d XP, insgesamt %s)  ·  %d Skillpunkt%s%s" % [
		int(progress["level"]), int(progress["xp_in_level"]), int(progress["xp_for_level_up"]),
		PlayerLevel.label(), points, "" if points == 1 else "e",
		" offen — im Start-Screen unter „🌳 Fähigkeiten“" if points > 0 else ""])
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


## „Frisch gemeistert": Aufgaben, deren erste Meisterung im Zeitraum ab `since` (unix)
## liegt — jüngste zuerst, gekappt auf `limit`.
##
## Records ohne Zeitstempel (mastered_at = 0, Altbestand von vor der Zeitmessung) bleiben
## außen vor: ihre Meisterung liegt vor dem Messbeginn und wäre hier ein Eintrag vom
## 01.01.1970. Dieselbe Regel wie in PlayerProgress.mastered_since.
static func fresh_rows(rows: Array, since: int, limit := LIST_COUNT) -> Array:
	var fresh: Array = []
	for row in rows:
		var at := int(row.get("mastered_at", 0))
		if at > 0 and at >= since:
			fresh.append(row)
	fresh.sort_custom(func(a, b): return int(a["mastered_at"]) > int(b["mastered_at"]))
	return fresh.slice(0, limit)


## „Comeback": Aufgaben, die mindestens `min_misses` Mal entwischt sind und jetzt trotzdem
## sitzen — die mit den meisten Fehlversuchen zuerst, bei gleichem Stand die jüngste
## Meisterung. Gekappt auf `limit`.
##
## Ohne Zeitfenster, anders als bei „frisch gemeistert": ein zurückgeholtes Wort bleibt
## eine Auszeichnung, auch wenn es vier Wochen her ist. Der Altbestand ohne Zeitstempel
## darf hier deshalb mitkommen — die Sortierung nimmt ihn nur nach hinten.
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


## Die beiden Listen, die genau das belohnen, was belohnt werden soll (Issue #9).
##
## Mit Wortlaut und nicht als Zahl — der Wiedererkennungswert ist der Punkt, „71 %
## Genauigkeit" sagt darüber nichts. Beide Listen haben einen freundlichen Leertext statt
## einer leeren Fläche; beim Comeback ist leer der Normalfall.
func _refresh_lists() -> void:
	var rows := PlayerProgress.records_for_display()
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


## „heute" / „gestern" / „vor 3 Tagen" für einen Meisterungs-Zeitpunkt. Lokale Tage wie
## in der Tages-Serie (SessionLog.local_day), damit nicht zwei Tagesgrenzen im Screen
## gelten. Bei „frisch gemeistert" liegt der Zeitpunkt höchstens eine Woche zurück.
func _when(unix: int) -> String:
	var days := SessionLog.local_day(int(Time.get_unix_time_from_system())) - SessionLog.local_day(unix)
	if days <= 0:
		return "heute"
	if days == 1:
		return "gestern"
	return "vor %d Tagen" % days


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
			"lexemes": group["lexemes"],
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
			"lexemes": group["lexemes"],
		})
	return rows


## Zählt ein Lexem in die Gruppe `key`: eines mehr insgesamt, und eines mehr gemeistert,
## wenn es in der Menge steht (siehe PlayerProgress.mastered_lexemes).
static func _count_into(groups: Dictionary, key: String, entry: Dictionary, mastered: Dictionary) -> void:
	if not groups.has(key):
		groups[key] = {"done": 0, "total": 0, "lexemes": []}
	groups[key]["total"] += 1
	groups[key]["lexemes"].append(entry)
	if mastered.has(str(entry.get("id", ""))):
		groups[key]["done"] += 1


## Die Wörter einer Gruppe mit ihrem Prozentstand — was hinter „18 von 24" steht.
##
## Der Prozentstand ist die SCHWÄCHERE der beiden Übersetzungsrichtungen, also dieselbe
## Rechnung, aus der die Meisterung kommt (PlayerProgress.mastered_lexemes: beide
## Richtungen ab MASTERY_CONFIDENCE). Der Durchschnitt wäre freundlicher und läge bei
## einer sitzenden und einer offenen Richtung bei 60 % — der Haken stünde dann an einer
## anderen Zahl als der angezeigten, und die Liste erklärte den Balken nicht mehr.
##
## Sortiert: das Schwächste zuerst, wie überall in diesem Screen. Noch nie geübte Wörter
## stehen alphabetisch am Ende — sie sind kein Lernstand, sondern das, was noch aussteht,
## und oben verdrängten sie genau die Wörter, an denen gerade etwas zu holen ist.
##
## `conf` liefert die Confidence einer Aufgabe und -1 für „kein Record" (im Spiel
## PlayerProgress.confidence mit -1 als Vorgabe). Als Callable übergeben — wie book_label
## bei unit_rows —, damit die Regel ohne Autoload prüfbar bleibt.
static func word_rows(lexemes: Array, conf: Callable) -> Array:
	var rows: Array = []
	for entry in lexemes:
		var id := str(entry.get("id", ""))
		var weakest := 1.0
		var seen := false
		for direction in PROGRESS.LEXEME_MASTERY_DIRECTIONS:
			var value := float(conf.call("translate:%s:%s" % [direction, id]))
			if value < 0.0:
				# Keine Aufgabe, kein Stand: die Richtung zieht den Wert auf 0, aber sie
				# macht das Wort noch nicht zu einem geübten.
				value = 0.0
			else:
				seen = true
			weakest = minf(weakest, value)
		rows.append({
			"label": word_label(entry),
			"confidence": weakest if seen else -1.0,
		})
	rows.sort_custom(func(a, b):
		var ca := float(a["confidence"])
		var cb := float(b["confidence"])
		if (ca < 0.0) != (cb < 0.0):
			return cb < 0.0
		if ca < 0.0:
			return str(a["label"]) < str(b["label"])
		return ca < cb)
	return rows


## Dieselben Zeilen, fertig für StatRow: { label, value, mark }.
static func word_lines(lexemes: Array, conf: Callable) -> Array:
	var lines: Array = []
	for row in word_rows(lexemes, conf):
		var value := float(row["confidence"])
		lines.append({
			"label": str(row["label"]),
			# Ein nie geübtes Wort steht nicht mit „0 %" da: 0 % ist ein gemessener Stand,
			# und gemessen wurde hier nichts.
			"value": "noch nicht geübt" if value < 0.0 else "%d %%" % int(round(value * 100.0)),
			"mark": "✓" if value >= PROGRESS.MASTERY_CONFIDENCE else "",
		})
	return lines


## Ein Wort in beiden Sprachen, „house — Haus". Beide, weil die Liste unter einer Unit
## zum Nachschlagen da ist und die Meisterung ohnehin beide Richtungen verlangt.
static func word_label(entry: Dictionary) -> String:
	var en := str(entry.get("lemma_en", ""))
	var de := str(entry.get("lemma_de", ""))
	if en.is_empty() or de.is_empty():
		return en if de.is_empty() else de
	return "%s — %s" % [en, de]


func _fill_progress(box: VBoxContainer, rows: Array, empty_text: String) -> void:
	_clear(box)
	if rows.is_empty():
		_add_line(box, empty_text)
		return
	for row in rows:
		var bar := PROGRESS_ROW_SCENE.instantiate() as ProgressRow
		box.add_child(bar)
		var lexemes: Array = row.get("lexemes", [])
		# Erst beim Aufklappen gerufen: siehe ProgressRow.
		bar.setup(str(row["label"]), int(row["done"]), int(row["total"]),
				func(): return word_lines(lexemes, PlayerProgress.confidence.bind(-1.0)))


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
