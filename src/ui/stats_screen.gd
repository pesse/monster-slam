extends Control
## Statistik-Screen: Zahlen zum Lernstand, Fahndungsliste, Wortliste (Issue #5).
##
## Ausgelagert aus dem Einstellungs-Screen. Dort hing die Statistik zwischen
## Profilauswahl, Reset und Melde-Token — sie ist aber der motivierende Teil und
## verdient einen eigenen Screen, direkt vom Start-Screen (profile_menu) aus erreichbar.
##
## Das Layout liegt in stats_screen.tscn (im Editor gestaltbar), die Zeilen-Vorlage in
## stat_row.tscn; hier wird nur befüllt. Die Verlaufs-Statistiken (Tages-Serie,
## Lernkurve, Fortschritt pro Unit, Kampf-Rekorde) kommen als weitere Abschnitte in den
## Reiter „Überblick"; die Daten dafür liegen in SessionLog und PlayerProgress bereit.

const MENU_SCENE := "res://scenes/ui/profile_menu.tscn"
const ROW_SCENE := preload("res://scenes/ui/stat_row.tscn")

## So viele Wörter stehen auf der Fahndungsliste. Kurz halten: eine lange Liste ist
## keine Fahndung mehr, sondern die Wortliste im zweiten Reiter.
const WANTED_COUNT := 5

@onready var _stat_lines: VBoxContainer = %StatLines
@onready var _wanted_list: VBoxContainer = %WantedList
@onready var _word_list: VBoxContainer = %WordList


func _ready() -> void:
	(%BackButton as Button).pressed.connect(func(): get_tree().change_scene_to_file(MENU_SCENE))
	_refresh()


func _refresh() -> void:
	_refresh_numbers()
	_refresh_wanted()
	_refresh_words()


func _refresh_numbers() -> void:
	_clear(_stat_lines)
	_add_line(_stat_lines, "Gemeisterte Aufgaben: %d  (Festungsstufe %d)" % [
		PlayerProgress.mastered_count(), PlayerProgress.fortress_tier()])
	_add_line(_stat_lines, "Gesamt-Genauigkeit: %d %%" % int(round(PlayerProgress.overall_accuracy() * 100.0)))
	_add_line(_stat_lines, "Gesehene Wörter: %d    Versuche: %d" % [
		PlayerProgress.seen_count(), PlayerProgress.total_attempts()])
	_add_line(_stat_lines, "Beste Serie: %d" % PlayerProgress.best_streak_overall())
	_add_line(_stat_lines, "Heute fällig: %d" % PlayerProgress.due_count())


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
