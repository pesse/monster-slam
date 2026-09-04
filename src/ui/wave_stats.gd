extends PanelContainer
## Wellenabschluss in zwei Stufen: Ergebnis (Statistik + Schatzkiste) → nächste Welle.
##
## Die Auflösung der Vokabeln (LeakReveal) gehört zum Ergebnis, liegt aber in einem
## eigenen Overlay und läuft VOR diesem Screen ab (siehe WaveRunner._finish_wave).
##
## Warum die Schwierigkeitswahl eine eigene Stufe hat: sie will eine Entscheidung, das
## Ergebnis will gelesen werden. Zusammen auf einer Seite hieß es, die Zahlen zu
## überfliegen und auf „Nächste Welle" zu klicken. Statistik und Kiste dagegen gehören
## zusammen — beides ist das Ergebnis derselben Welle, links die Zahlen, rechts der Lohn.
##
## Die Kiste fällt aus, wenn die Welle nichts eingebracht hat (kein besiegtes Monster,
## also kein Gold): eine leere Kiste ist keine Belohnung. Nach einer Niederlage gibt es
## sie trotzdem — verdient ist verdient, der Lauf endet danach in Stufe 2 ohne Wahl.
##
## **Die Größe des Screens steht fest**, solange er sichtbar ist: die Seiten liegen in
## einem PageStack (Mindestgröße = größte Seite, auch unsichtbar), und innerhalb der
## Ergebnisseite wird nichts ein- oder ausgeblendet, sondern nur gesperrt und beschriftet.
## Der Screen hängt in der Bildmitte — jede Größenänderung verschiebt auch die Knöpfe.
##
## Das Layout liegt in wave_stats.tscn; hier nur die Befüllung (show_stats), der
## Stufenwechsel und die Auswahl-Logik. Interaktive Controls haben focus_mode=FOCUS_NONE
## (in der Szene gesetzt), sonst reißt die Antwort-LineEdit (die sich per _process den
## Fokus zurückholt) den Klick weg.

## Der Spieler hat die nächste Welle gestartet; übergeben wird die Änderung der
## Schwierigkeit RELATIV zur aktuellen (-2..+2), nicht ein absoluter Wert.
signal next_wave_requested(difficulty_delta: int)

## Der Spieler will zurück zum Profil-/Statistik-Menü (verlässt die laufende Partie).
signal back_to_menu_requested

## Die Schatzkiste ist offen: `gold` ist verdient und will verbucht werden. Der Screen
## bucht nicht selbst — er zeigt nur, was der Empfänger (WaveRunner -> Wallet) daraus
## macht, und liest den neuen Stand über Wallet.changed zurück.
signal reward_collected(gold: int)

## Deltas der Schwierigkeitswahl, in Reihenfolge der Buttons in ChoiceRow (wave_stats.tscn).
const CHOICE_DELTAS := [-2, -1, 0, 1, 2]
## Index der Standardauswahl ("Gleich").
const DEFAULT_CHOICE := 2
## Aufforderung an der Kiste, solange sie zu ist.
const CHEST_HINT := "2 Sekunden auf die Kiste drücken\n(oder Leertaste halten)"

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
@onready var _chest_name: Label = %ChestName
@onready var _reward_line: Label = %RewardLine
@onready var _gold_label: Label = %GoldLabel
@onready var _result_continue: Button = %ResultContinue
@onready var _defeat_label: Label = %DefeatLabel
@onready var _diff_label: Label = %DiffLabel
@onready var _choice_row: HBoxContainer = %ChoiceRow
@onready var _start_button: Button = %StartButton
@onready var _menu_button: Button = %MenuButton
@onready var _choice_buttons: Array = %ChoiceRow.get_children()

var _stage: Stage = Stage.RESULT
var _selected_choice: int = DEFAULT_CHOICE
var _won: bool = true
var _wave_number: int = 0
var _chest_gold: int = 0


func _ready() -> void:
	for i in _choice_buttons.size():
		(_choice_buttons[i] as Button).pressed.connect(_on_choice_pressed.bind(i))
	_start_button.pressed.connect(_on_start_pressed)
	_menu_button.pressed.connect(func(): back_to_menu_requested.emit())
	_result_continue.pressed.connect(func(): _goto_stage(Stage.NEXT))
	_chest.opened.connect(_on_chest_opened)
	# Der Goldstand kommt aus der Geldbörse und nicht aus dem, was die Kiste gerade
	# hergegeben hat: sie ist die eine Quelle, und sie meldet sich, wenn sich was ändert.
	Wallet.changed.connect(_on_wallet_changed)
	_update_choice_highlight()


## Befüllt den Screen mit den Statistiken einer Welle und zeigt ihn an (Stufe 1).
## Erwartete Felder in `data`: won, wave_number, difficulty, correct, leaked, total,
## accuracy, score_gained, score_total, fortress_health, mastered, fortress_tier und
## optional chest = { tier, gold, name } (siehe ChestReward.for_wave).
func show_stats(data: Dictionary) -> void:
	_won = bool(data.get("won", true))
	_wave_number = int(data.get("wave_number", 0))

	for child in _lines.get_children():
		_lines.remove_child(child)
		child.queue_free()
	_add_line("Richtig besiegt: %d von %d" % [int(data.get("correct", 0)), int(data.get("total", 0))])
	_add_line("Durchgelassen: %d" % int(data.get("leaked", 0)))
	_add_line("Genauigkeit: %d %%" % int(round(float(data.get("accuracy", 0.0)))))
	_add_line("Punkte: %d  (+%d)" % [int(data.get("score_total", 0)), int(data.get("score_gained", 0))])
	_add_line("Festung: %d HP" % int(data.get("fortress_health", 0)))
	_add_line("Gemeisterte Aufgaben: %d  (Festungsstufe %d)" % [
		int(data.get("mastered", 0)), int(data.get("fortress_tier", 0))])
	_add_line("Schwierigkeit: %d / 5" % int(data.get("difficulty", 3)))

	# Kiste: die einzige Sichtbarkeitsentscheidung der Ergebnisseite, und sie fällt HIER
	# — vor dem Anzeigen. Ab dann bleibt die Seite in ihrer Größe stehen.
	var chest: Dictionary = data.get("chest", {})
	_chest_gold = int(chest.get("gold", 0))
	_reward.visible = _chest_gold > 0
	_chest_name.text = str(chest.get("name", ChestReward.TIER_NAMES[0]))
	_reward_line.text = CHEST_HINT
	_chest.present(int(chest.get("tier", ChestReward.Tier.WOOD)), _chest_gold)
	_on_wallet_changed(Wallet.gold)
	_update_reward_gate()

	# Gefallene Festung = Ende des Laufs. Es gibt keine nächste Welle, also auch keine
	# Schwierigkeitswahl und keinen Startknopf — nur den Weg ins Menü. Damit muss der
	# Wellenstart die HP auch nie „retten": ein neuer Lauf beginnt über GameState.reset().
	_diff_label.visible = _won
	_choice_row.visible = _won
	_start_button.visible = _won
	_defeat_label.visible = not _won

	# Auswahl startet jedesmal bei "Gleich" – die Wahl ist relativ zur eben gespielten Welle.
	_selected_choice = DEFAULT_CHOICE
	_update_choice_highlight()
	_goto_stage(Stage.RESULT)
	visible = true


func hide_stats() -> void:
	visible = false


## Aktuelle Stufe — für Tests und für den WaveRunner, der wissen will, ob der Screen
## noch etwas vom Spieler will.
func stage() -> Stage:
	return _stage


# --- Stufen -------------------------------------------------------------------

func _goto_stage(next: Stage) -> void:
	_stage = next
	_result_page.visible = next == Stage.RESULT
	_next_page.visible = next == Stage.NEXT
	_title.text = _title_for(next)
	# Ergebnis-Titel einfärben (passt zu den grün/rot-Feedbackfarben des Spiels); die
	# Folgestufe nimmt die Theme-Farbe zurück — sie ist kein Urteil über die Welle, und
	# ein hart gesetztes Weiß wäre eine zweite Textfarbe neben dem Theme.
	if next == Stage.RESULT:
		_title.add_theme_color_override("font_color",
				Color(0.3, 1.0, 0.45) if _won else Color(1.0, 0.35, 0.35))
	else:
		_title.remove_theme_color_override("font_color")


func _title_for(stage_value: Stage) -> String:
	if stage_value == Stage.NEXT:
		return "Nächste Welle" if _won else "Lauf beendet"
	return "Welle %d geräumt!" % _wave_number if _won \
			else "Festung gefallen (Welle %d)" % _wave_number


func _add_line(text: String) -> void:
	var label := Label.new()
	label.text = text
	_lines.add_child(label)


# --- Belohnung ----------------------------------------------------------------

## Solange eine ungeöffnete Kiste dasteht, führt kein Weg an ihr vorbei: Weiter und Menü
## sind GESPERRT, nicht ausgeblendet. Das Gold soll niemand aus Versehen liegen lassen
## (zwei Sekunden Drücken sind kein Hindernis, ein weggeklickter Fund ist einer) — und
## ein verschwindender Knopf würde den Screen in der Größe springen lassen.
func _update_reward_gate() -> void:
	var locked := _chest_gold > 0 and not _chest.is_open()
	_result_continue.disabled = locked
	_menu_button.disabled = locked


func _on_chest_opened(gold: int) -> void:
	_reward_line.text = "+%s" % Wallet.label(gold)
	_update_reward_gate()
	# Erst melden, dann steht die Zahl in der Geldbörse: der neue Stand kommt über
	# Wallet.changed zurück (siehe _on_wallet_changed).
	reward_collected.emit(gold)


func _on_wallet_changed(gold: int) -> void:
	_gold_label.text = "Insgesamt %s" % Wallet.label(gold)


# --- Schwierigkeitswahl -------------------------------------------------------

func _on_choice_pressed(index: int) -> void:
	_selected_choice = index
	_update_choice_highlight()


## Markiert die gewählte Option (deaktivierter Button = optisch hervorgehoben).
func _update_choice_highlight() -> void:
	for i in _choice_buttons.size():
		(_choice_buttons[i] as Button).disabled = (i == _selected_choice)


func _on_start_pressed() -> void:
	next_wave_requested.emit(CHOICE_DELTAS[_selected_choice])
