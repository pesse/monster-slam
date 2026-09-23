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
## (Tages-Serie #6, Kennzahlen #5, Kampf-Rekorde #11, Lernkurve #7, frisch gemeistert und
## Comeback #9, Fahndungsliste #5), „Fortschritt" die Balken pro Unit und Thema (#8) — die
## wachsen mit dem Katalog und schöben im Überblick alles andere aus dem Bild —, „Aufgaben" die
## vollständige Liste der Learnables. Ein Balken lässt sich aufklappen und zeigt dann die
## WÖRTER seiner Gruppe mit Prozentstand: „18 von 24" sagt nicht, welche sechs fehlen,
## und im Reiter „Aufgaben" stehen sie als zwei bis sechs Zeilen zwischen allen anderen.
##
## Die beiden Maße auseinanderzuhalten ist der Sinn der Reiter-Namen: „Aufgaben" zählt
## learnable_ids (Richtung, Form, Relation — das Maß von mastered_count), „Fortschritt"
## zählt Wörter (beide Übersetzungsrichtungen — das Maß von mastered_lexemes).

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
## Beschriftung der beiden Übersetzungsrichtungen im Mouseover einer Wortzeile.
const DIRECTION_LABELS := {"de_to_en": "de→en", "en_to_de": "en→de"}
## Ab diesem HP-Stand trägt der schonendste Lauf seine Auszeichnung. Ein fester Betrag
## und kein Anteil des Maximums: wer sein Maximum über die Fähigkeiten angehoben hat, hat
## sich das Polster verdient — und die Sitzungen schreiben ihr Maximum nicht mit.
const SPOTLESS_FORTRESS_HP := 90

@onready var _streak_label: Label = %StreakLabel
@onready var _coin_label: Label = %CoinLabel
@onready var _coin_strip: CoinStrip = %CoinStrip
@onready var _stat_lines: VBoxContainer = %StatLines
@onready var _record_list: VBoxContainer = %RecordList
@onready var _curve: StatsChart = %Curve
@onready var _curve_caption: Label = %CurveCaption
@onready var _fresh_list: VBoxContainer = %FreshList
@onready var _comeback_list: VBoxContainer = %ComebackList
@onready var _wanted_list: VBoxContainer = %WantedList
## Fächert die Aufgaben eines Wortes auf (learnables_of) und benennt sie — dieser Screen
## spawnt nichts, er liest nur dieselbe Auffächerung wie der Wave-Pool.
var _generator := WaveGenerator.new()
var _resolver := TaskResolver.new()

@onready var _unit_list: VBoxContainer = %UnitList
@onready var _tag_list: VBoxContainer = %TagList
@onready var _task_list: VBoxContainer = %TaskList


func _ready() -> void:
	(%BackButton as Button).pressed.connect(func(): get_tree().change_scene_to_file(MENU_SCENE))
	_refresh()


func _refresh() -> void:
	_refresh_streak()
	_refresh_numbers()
	_refresh_records()
	_refresh_curve()
	_refresh_lists()
	_refresh_wanted()
	_refresh_progress()
	_refresh_tasks()


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


## Kampf-Rekorde über alle Sitzungen (Issue #11).
##
## Der Angeber-Anteil: Bestwerte, die kein Lernziel sind. Sie stehen bei den Kennzahlen
## und nicht zwischen den Wortlisten — dort geht es um Wörter, hier um Zahlen.
func _refresh_records() -> void:
	_clear(_record_list)
	var rows := record_rows(SessionLog.records())
	if rows.is_empty():
		_add_line(_record_list, "Noch kein Lauf gespielt — die Bestwerte kommen mit der ersten Welle.")
		return
	for row in rows:
		_add_row(_record_list, str(row["label"]), str(row["value"]),
				str(row["mark"]), str(row["hint"]))


## Die Kampf-Rekorde als fertige Zeilen (Bezeichnung, Wert, Zeichen, Hinweis) aus den
## Bestwerten von SessionLog.records().
##
## Statisch und über das Dictionary statt über das Autoload — dieselbe Aufteilung wie bei
## wanted_rows(): so ist die Auswahl mit erfundenen Bestwerten prüfbar, ohne den echten
## Verlauf des Spielers anzufassen.
##
## Ohne Sitzung gibt es keine Zeilen: „0 Monster besiegt, nie unter 0 HP" wäre kein
## leerer Block, sondern ein falscher.
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
	# Der schonendste Lauf ist der HÖCHSTE der lauf-eigenen Tiefstände, nicht der tiefste
	# Stand überhaupt. Fehlt er (abgebrochene Läufe schreiben ihn nicht mit), bleibt die
	# Zeile weg, statt einen erfundenen Stand zu behaupten.
	var floor_hp := int(records.get("best_fortress_floor", -1))
	if floor_hp >= 0:
		rows.append({
			"label": "Schonendster Lauf",
			"value": "nie unter %d HP" % floor_hp,
			"mark": "🛡️" if floor_hp >= SPOTLESS_FORTRESS_HP else "",
			"hint": "tiefster HP-Stand deines saubersten Laufs; das Schild gibt es ab %d HP" % SPOTLESS_FORTRESS_HP,
		})
	return rows


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
	var pool := ContentRegistry.lexemes_scoped(UserSettings.selected_scope(), []) \
			.filter(PROGRESS.masterable)
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
## Die ÜBRIGEN Aufgaben zum Wort (Formen, Gegenteile, Synonyme, Verwechslungen) zählen
## bewusst NICHT in die Meisterung — sie hängen an Zusatzdaten, die nur ein Teil der
## Wörter hat, und eine nachgetragene Relation nähme dem Spieler sonst rückwirkend ein
## gemeistertes Wort weg. Sie fahren als `extras` mit und stehen in der Zeile als
## Sternchen: ein Wort kann sitzen UND noch etwas zu holen haben.
##
## Sortiert: das Schwächste zuerst, wie überall in diesem Screen. Noch nie geübte Wörter
## stehen alphabetisch am Ende — sie sind kein Lernstand, sondern das, was noch aussteht,
## und oben verdrängten sie genau die Wörter, an denen gerade etwas zu holen ist.
##
## `conf` liefert die Confidence einer Aufgabe und -1 für „kein Record" (im Spiel
## PlayerProgress.confidence mit -1 als Vorgabe), `learnables` alle learnable_ids zu einem
## Lexem (WaveGenerator.learnables_of). Als Callables übergeben — wie book_label bei
## unit_rows —, damit die Regeln ohne Autoload prüfbar bleiben.
static func word_rows(lexemes: Array, conf: Callable, learnables := Callable()) -> Array:
	var rows: Array = []
	for entry in lexemes:
		var id := str(entry.get("id", ""))
		var directions: Array = []
		var weakest := 1.0
		var seen := false
		for direction in PROGRESS.LEXEME_MASTERY_DIRECTIONS:
			var value := float(conf.call("translate:%s:%s" % [direction, id]))
			directions.append({"direction": direction, "confidence": value})
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
			"directions": directions,
			"extras": extra_rows(entry, conf, learnables),
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


## Die Aufgaben eines Wortes NEBEN den beiden Übersetzungsrichtungen, gemeisterte zuerst:
## { id, confidence, mastered }. Die Richtungen fallen hier raus, weil sie schon der
## Prozentstand der Zeile sind — doppelt gezählt wäre jedes Wort mindestens zweisternig.
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


## Dieselben Zeilen, fertig für StatRow: { label, value, mark, hint_list }.
##
## In der Markierung steht der Haken für das Wort und je ein Sternchen für jede weitere
## Aufgabe dazu — ausgefüllt, wenn sie sitzt. Was die Zeichen im Einzelnen heißen, steht
## im Mouseover (`hint_list`): die Zeile bleibt schmal genug für eine lange Liste, und wer es
## genau wissen will, hält drauf. `describe` benennt eine Aufgabe (TaskResolver
## .describe_learnable); ohne sie steht die rohe learnable_id da.
static func word_lines(lexemes: Array, conf: Callable, learnables := Callable(),
		describe := Callable()) -> Array:
	var lines: Array = []
	for row in word_rows(lexemes, conf, learnables):
		var value := float(row["confidence"])
		var mastered: bool = value >= PROGRESS.MASTERY_CONFIDENCE
		var extras: Array = row["extras"]
		var mark := "✓" if mastered else ""
		for extra in extras:
			mark += "★" if bool(extra["mastered"]) else "☆"
		lines.append({
			"label": str(row["label"]),
			# Ein nie geübtes Wort steht nicht mit „0 %" da: 0 % ist ein gemessener Stand,
			# und gemessen wurde hier nichts.
			"value": "noch nicht geübt" if value < 0.0 else "%d %%" % int(round(value * 100.0)),
			"mark": mark,
			"hint_list": word_hint(row, describe),
		})
	return lines


## Die Liste der Karte am Zeiger für eine Wortzeile: je Richtung eine Zeile und darunter
## je Sternchen eine. Sie sagt genau das, was die Zeichen verschweigen — welche Aufgabe das
## Sternchen meint und wie weit sie ist. Zeilen `[zeichen, bezeichnung, wert]`, damit die
## Karte sie als Tabelle setzt und die Prozente untereinander stehen (`HintCard`).
##
## Das WORT steht nicht darin: es ist die Überschrift der Karte (`StatRow.setup`), und
## zweimal dasselbe zu lesen ist keine Auskunft.
static func word_hint(row: Dictionary, describe := Callable()) -> Array:
	var lines: Array = []
	for direction in row.get("directions", []):
		var value := float(direction["confidence"])
		lines.append(["✓" if value >= PROGRESS.MASTERY_CONFIDENCE else "",
				"Übersetzung " + str(DIRECTION_LABELS.get(str(direction["direction"]),
						str(direction["direction"]))),
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
				func(): return word_lines(lexemes, PlayerProgress.confidence.bind(-1.0),
						_generator.learnables_of, _resolver.describe_learnable))


## Alle geübten AUFGABEN, schwächste Confidence zuerst (die Sortierung liefert
## PlayerProgress). Der Haken markiert die gemeisterten.
##
## Eine Zeile je learnable_id, nicht je Wort: ein Wort hat beide Übersetzungsrichtungen
## und dazu seine Formen und Relationen. Deshalb heißt der Reiter „Aufgaben" — als
## „Wörter" stand dieselbe Vokabel mehrfach mit verschiedenen Ständen darin, und der
## Haken behauptete etwas anderes als der Haken im Fortschritt (dort: das WORT sitzt).
func _refresh_tasks() -> void:
	_clear(_task_list)
	var rows := PlayerProgress.records_for_display()
	if rows.is_empty():
		_add_line(_task_list, "Noch keine Aufgabe geübt.")
		return
	for row in rows:
		_add_row(_task_list, str(row["label"]), _percent(row),
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


func _add_row(box: VBoxContainer, name_text: String, value_text: String, mark_text := "",
		hint := "") -> void:
	var row := ROW_SCENE.instantiate() as StatRow
	box.add_child(row)
	row.setup(name_text, value_text, mark_text, hint)
