extends PanelContainer
## Wellenabschluss in zwei Stufen: Ergebnis (Statistik + Schatzkiste) → nächste Welle mit
## Sitzungsbilanz. Regeln zu Kiste, Trostgold, Bilanz und fester Größe: `docs/ARCHITECTURE.md`.
## Jedes umbrechende Label braucht hier `custom_minimum_size.x` (CONVENTIONS „Fallen“).
## Enter und Rücktaste drücken auf den Knopf rechts bzw. „◂ Zurück“, erst nach
## `enter_grace_ms`; die Knöpfe haben `FOCUS_NONE`, sonst holt das Antwortfeld den Klick.

## Der Spieler hat die nächste Welle gestartet, mit der gewählten Stufe `difficulty` (1..5).
signal next_wave_requested(difficulty: int)

## Der Spieler will zurück ins Menü, auf die Karte oder zur Liste (verlässt die Partie).
signal back_to_menu_requested

## Der Spieler will die Antworten der Welle noch einmal sehen; zurück geht es mit `resume()`.
signal review_requested

## Der Spieler will vor der nächsten Welle Zauber kaufen; zurück geht es mit `resume()`.
signal shop_requested

## Die Schatzkiste ist offen; `gold` verbucht der Empfänger, nicht der Screen.
signal reward_collected(gold: int)
## Das Trostgold einer Welle ohne Kiste; keine geöffnete Kiste.
signal consolation_collected(gold: int)

const LINE_SCENE := preload("res://scenes/ui/record_row.tscn")
## So viele Aufgaben nennt die Sitzungsbilanz beim Namen; der Rest steht als Zahl da.
const BALANCE_WORDS := 4
## Der Rückweg eines Laufs von der Karte, der gerastet wird.
const REST_TEXT := "⟵ Rasten"
## Aufforderung an der Kiste, solange sie zu ist.
const CHEST_HINT := "2 Sekunden auf die Kiste drücken\n(oder Leertaste halten)"
## Steht statt des Kistennamens, wenn kein Monster besiegt wurde; der Titel bricht nicht um.
const CONSOLATION_TITLE := "Kein Monster besiegt –\naller Anfang ist schwer"
## So lange (ms) nach einem Stufenwechsel zählt Enter noch nicht, damit das Enter der
## letzten Antwort nicht durchklickt. Variable für Tests.
var enter_grace_ms := 400

enum Stage {
	RESULT,  ## Ergebnis der Welle: Zahlen und Schatzkiste.
	NEXT,    ## Schwierigkeit wählen und starten — oder ins Menü.
}

@onready var _title: Label = %Title
@onready var _pages: PageStack = %Pages
@onready var _lines: VBoxContainer = %Lines
@onready var _result_page: VBoxContainer = %ResultPage
@onready var _next_page: VBoxContainer = %NextPage
@onready var _reward: VBoxContainer = %Reward
@onready var _chest: TreasureChest = %Chest
@onready var _chest_row: Control = %ChestRow
@onready var _chest_name: Label = %ChestName
@onready var _reward_line: Label = %RewardLine
@onready var _result_continue: Button = %ResultContinue
@onready var _stage_back: Button = %StageBack
@onready var _balance: VBoxContainer = %Balance
@onready var _balance_lines: VBoxContainer = %BalanceLines
@onready var _balance_template: Label = %BalanceLineTemplate
@onready var _defeat_label: Label = %DefeatLabel
@onready var _diff_label: Label = %DiffLabel
@onready var _choice_row: HBoxContainer = %ChoiceRow
@onready var _start_button: Button = %StartButton
@onready var _menu_button: Button = %MenuButton
@onready var _shop_row: Control = %ShopRow
@onready var _choice_buttons: Array = %ChoiceRow.get_children()

var _stage: Stage = Stage.RESULT
## Index in ChoiceRow; die Knöpfe stehen für die Stufen 1..5.
var _selected_choice: int = 2
var _won: bool = true
var _wave_number: int = 0
var _chest_gold: int = 0
var _stage_since_ms: int = 0
var _can_review: bool = false


func _ready() -> void:
	for i in _choice_buttons.size():
		(_choice_buttons[i] as Button).pressed.connect(_on_choice_pressed.bind(i))
	_start_button.pressed.connect(_on_start_pressed)
	_menu_button.pressed.connect(func(): back_to_menu_requested.emit())
	# Ein Level von der Karte führt auf die Karte zurück (RunRequest.return_scene).
	if RunRequest.is_level():
		_menu_button.text = "⟵ Zurück zur Karte"
	elif RunRequest.is_test():
		_menu_button.text = "⟵ Zurück zur Liste"
	_result_continue.pressed.connect(func(): _goto_stage(Stage.NEXT))
	_stage_back.pressed.connect(_on_stage_back)
	(%ShopButton as Button).pressed.connect(func(): shop_requested.emit())
	Hints.attach(%ShopButton as Control, "Zauberladen", "kaufen mit Gold, bevor die Welle kommt")
	_chest.opened.connect(_on_chest_opened)
	_update_choice_highlight()


## Befüllt den Screen mit den Statistiken einer Welle und zeigt ihn an (Stufe 1).
## Erwartete Felder in `data`: won, wave_number, difficulty, correct, leaked, total,
## accuracy, fortress_health, mastered, fortress_tier, xp_gained, levels_gained; optional
## review (gibt es Antworten zum Zurückblättern?), chest (`ChestReward.for_wave`) und
## session (`RunBalance.build`, leer = keine Bilanz).
func show_stats(data: Dictionary) -> void:
	_won = bool(data.get("won", true))
	_can_review = bool(data.get("review", false))
	_wave_number = int(data.get("wave_number", 0))

	for child in _lines.get_children():
		_lines.remove_child(child)
		child.queue_free()
	_add_line("Richtig besiegt", "%d von %d" % [int(data.get("correct", 0)), int(data.get("total", 0))])
	_add_line("Durchgelassen", str(int(data.get("leaked", 0))))
	_add_line("Genauigkeit", "%d %%" % int(round(float(data.get("accuracy", 0.0)))))
	# Aus der Sitzungsbilanz, damit Stufe 1 und 2 dasselbe zählen.
	var session_mastered := int((data.get("session", {}) as Dictionary).get("mastered", 0))
	if session_mastered > 0:
		_add_line("In dieser Sitzung gemeistert", str(session_mastered), "🏅")
	_add_line("Festung", "%d HP" % int(data.get("fortress_health", 0)))
	_add_line("Gemeisterte Aufgaben", str(int(data.get("mastered", 0))), "",
			"Festungsstufe %d" % int(data.get("fortress_tier", 0)))
	_add_line("Schwierigkeit", "%d / 5" % int(data.get("difficulty", 3)))
	# Der Zuwachs kommt aus der Welle, der Stand aus `PlayerLevel`; verbucht ist er schon.
	var progress := PlayerLevel.progress()
	_add_line("Erfahrung", "+%d XP" % int(data.get("xp_gained", 0)), "",
			"Level %d, %d / %d XP bis Level %d" % [int(progress["level"]),
			int(progress["xp_in_level"]), int(progress["xp_for_level_up"]),
			int(progress["level"]) + 1])
	# Inhaltsentscheidungen (Aufstieg, Kiste, Bilanz) fallen hier vor dem Anzeigen, danach
	# steht die Größe fest. Genannt werden die offenen Skillpunkte, nicht die verdienten.
	var levels := int(data.get("levels_gained", 0))
	if levels > 0:
		_add_line("Level %d erreicht" % int(progress["level"]), "", "⭐",
				ProfileBadge.points_text(SkillBook.available(), SkillBook.unlimited_points))

	var chest: Dictionary = data.get("chest", {})
	_chest_gold = int(chest.get("gold", 0))
	var consolation := int(chest.get("consolation", 0)) if _chest_gold <= 0 else 0
	_reward.visible = _chest_gold > 0 or consolation > 0
	_chest_row.visible = _chest_gold > 0
	if consolation > 0:
		_chest_name.text = CONSOLATION_TITLE
		_show_reward_gold(consolation)
	else:
		_chest_name.text = str(chest.get("name", ChestReward.TIER_NAMES[0]))
		_reward_line.text = CHEST_HINT
		_reward_line.theme_type_variation = &"StatGoldNote"
	_chest.present(int(chest.get("tier", ChestReward.Tier.WOOD)), _chest_gold)
	_update_reward_gate()
	if consolation > 0:
		consolation_collected.emit(consolation)

	# Gefallene Festung = Ende des Laufs: keine Schwierigkeitswahl, nur der Weg zurück.
	_diff_label.visible = _won
	_choice_row.visible = _won
	_shop_row.visible = _won
	_defeat_label.visible = not _won
	_label_menu_button()
	_show_balance(data.get("session", {}))

	# Vorgewählt ist die Stufe der eben gespielten Welle.
	_selected_choice = clampi(int(data.get("difficulty", 3)), 1, _choice_buttons.size()) - 1
	_update_choice_highlight()
	_goto_stage(Stage.RESULT)
	visible = true


## Der Weg zurück auf Stufe 2. Ein Lauf von der Karte, dessen Festung steht, rastet dabei
## (ADR 0020, `WaveRunner.can_rest`), außer er spielt nur Boni.
func _label_menu_button() -> void:
	if RunRequest.keeps_run() and _won:
		_menu_button.text = REST_TEXT
		Hints.attach(_menu_button, "Rasten",
				"Der Lauf wird gespeichert, mit Festung und Welle. Auf der Karte geht er mit "
				+ "„Lauf fortsetzen“ weiter.")
	elif RunRequest.is_level():
		_menu_button.text = "⟵ Zurück zur Karte"
		Hints.attach(_menu_button, "")


func hide_stats() -> void:
	visible = false


## Zurück von den Antworten: derselbe Screen in derselben Stufe, nichts neu befüllt;
## die Enter-Schonfrist beginnt neu.
func resume() -> void:
	_stage_since_ms = Time.get_ticks_msec()
	visible = true


func stage() -> Stage:
	return _stage


# --- Stufen -------------------------------------------------------------------

func _goto_stage(next: Stage) -> void:
	_stage = next
	_stage_since_ms = Time.get_ticks_msec()
	_result_page.visible = next == Stage.RESULT
	_next_page.visible = next == Stage.NEXT
	# Beide Stufen teilen die Fußzeile: links zurück, rechts weiter.
	_result_continue.visible = next == Stage.RESULT
	_start_button.visible = next == Stage.NEXT and _won
	_stage_back.disabled = next == Stage.RESULT and not _can_review
	_title.text = _title_for(next)
	# Nur der Ergebnis-Titel ist grün/rot eingefärbt; die Folgestufe nimmt die Theme-Farbe.
	if next == Stage.RESULT:
		_title.add_theme_color_override("font_color",
				Color(0.3, 1.0, 0.45) if _won else Color(1.0, 0.35, 0.35))
	else:
		_title.remove_theme_color_override("font_color")


## `_input`, damit Enter nicht zuerst ein anderer Knoten bekommt.
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo \
			or not key.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_BACKSPACE]:
		return
	if Time.get_ticks_msec() - _stage_since_ms < enter_grace_ms:
		return
	var button := _stage_back if key.keycode == KEY_BACKSPACE else _forward_button()
	if not button.visible or button.disabled:
		return
	accept_event()
	button.pressed.emit()


## Der Knopf, auf den Enter drückt; nach einer Niederlage der Weg zurück.
func _forward_button() -> Button:
	if _stage == Stage.RESULT:
		return _result_continue
	return _start_button if _won else _menu_button


func _on_stage_back() -> void:
	if _stage == Stage.NEXT:
		_goto_stage(Stage.RESULT)
	else:
		review_requested.emit()


func _title_for(stage_value: Stage) -> String:
	if stage_value == Stage.NEXT:
		return "Nächste Welle" if _won else "Lauf beendet"
	return "Welle %d geräumt!" % _wave_number if _won \
			else "Festung gefallen (Welle %d)" % _wave_number


## Eine Zeile wie in den Rekorden der Statistik; `hint` steht als Karte am Zeiger.
func _add_line(name_text: String, value_text: String, mark := "", hint := "") -> void:
	if _lines.get_child_count() > 0:
		var rule := HSeparator.new()
		rule.theme_type_variation = &"StatRule"
		_lines.add_child(rule)
	var row := LINE_SCENE.instantiate() as StatRow
	_lines.add_child(row)
	row.setup(name_text, value_text, mark, hint)


## Die Zeilen der Ergebnisseite als „Bezeichnung: Wert“.
func line_texts() -> Array[String]:
	var texts: Array[String] = []
	for row in _lines.get_children():
		if row is StatRow:
			texts.append("%s: %s" % [(row.get_node("Name") as Label).text,
					(row.get_node("Value") as Label).text])
	return texts


# --- Sitzungsbilanz -----------------------------------------------------------

func _show_balance(balance: Dictionary) -> void:
	for child in _balance_lines.get_children():
		_balance_lines.remove_child(child)
		child.queue_free()
	_balance.visible = not balance.is_empty()
	if balance.is_empty():
		return
	var cleared := int(balance.get("waves_cleared", 0))
	# Die erreichte Welle nur, wenn sie über die geräumten hinausgeht (nach einer Niederlage).
	var reached := int(balance.get("wave_reached", cleared))
	_add_balance_line("Wellen geräumt: %d%s" % [cleared,
			"  (Welle %d erreicht)" % reached if reached > cleared else ""])
	_add_balance_line("Antworten: %d, davon %d richtig" % [
		int(balance.get("answers", 0)), int(balance.get("correct", 0))])
	var mastered := int(balance.get("mastered", 0))
	var comeback := int(balance.get("comeback", 0))
	if mastered == 0:
		_add_balance_line("Neu gemeistert: noch keine — die nächste sitzt bald.")
		return
	_add_balance_line("Neu gemeistert: %d%s" % [mastered,
			"  (davon %d zurückerobert)" % comeback if comeback > 0 else ""])
	var words: Array = balance.get("words", [])
	# Höchstens BALANCE_WORDS Zeilen; bei Überhang nimmt „und N weitere“ die letzte.
	var shown := words.size() if words.size() <= BALANCE_WORDS else BALANCE_WORDS - 1
	for i in shown:
		var word: Dictionary = words[i]
		if bool(word.get("comeback", false)):
			_add_balance_line("  ↺ %s  (%d× entwischt)" % [str(word["label"]), int(word.get("misses", 0))])
		else:
			_add_balance_line("  ✓ %s" % str(word["label"]))
	if words.size() > shown:
		_add_balance_line("  … und %d weitere" % (words.size() - shown))


## Jede Zeile aus der Vorlage in der Szene: feste Breite, einzeilig, mit Auslassung.
func _add_balance_line(text: String) -> void:
	var label := _balance_template.duplicate() as Label
	# Der eindeutige Name gehört der Vorlage.
	label.unique_name_in_owner = false
	label.text = text
	label.visible = true
	_balance_lines.add_child(label)


# --- Belohnung ----------------------------------------------------------------

## Der Betrag steht groß, der Hinweis davor klein (in großer Schrift bräche er dreizeilig um).
func _show_reward_gold(gold: int) -> void:
	_reward_line.text = "+%s" % Wallet.label(gold)
	_reward_line.theme_type_variation = &"StatGold"


## Solange die Kiste zu ist, sind Weiter und Menü gesperrt (`docs/ARCHITECTURE.md`).
func _update_reward_gate() -> void:
	var locked := _chest_gold > 0 and not _chest.is_open()
	_result_continue.disabled = locked
	_menu_button.disabled = locked


func _on_chest_opened(gold: int) -> void:
	_show_reward_gold(gold)
	_update_reward_gate()
	reward_collected.emit(gold)


# --- Schwierigkeitswahl -------------------------------------------------------

func _on_choice_pressed(index: int) -> void:
	_selected_choice = index
	_update_choice_highlight()


func _update_choice_highlight() -> void:
	for i in _choice_buttons.size():
		(_choice_buttons[i] as Button).set_pressed_no_signal(i == _selected_choice)


func _on_start_pressed() -> void:
	next_wave_requested.emit(_selected_choice + 1)
