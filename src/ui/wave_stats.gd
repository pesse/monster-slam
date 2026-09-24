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
## also kein Gold): eine leere Kiste ist keine Belohnung. An ihrem Platz steht dann ein
## Trostwort mit einem Goldstück (ChestReward.CONSOLATION_GOLD), das ohne Zutun verbucht
## wird — es gibt nichts zu öffnen. Nach einer Niederlage gibt es die Kiste trotzdem — verdient ist verdient, der Lauf endet danach in Stufe 2 ohne Wahl.
##
## **Die Größe des Screens steht fest**, solange er sichtbar ist: die Seiten liegen in
## einem PageStack (Mindestgröße = größte Seite, auch unsichtbar), und innerhalb der
## Ergebnisseite wird nichts ein- oder ausgeblendet, sondern nur gesperrt und beschriftet.
## Der Screen hängt in der Bildmitte — jede Größenänderung verschiebt auch die Knöpfe.
##
## **Jedes umbrechende Label braucht hier eine Mindestbreite** (`custom_minimum_size.x`).
## Ein Label mit `autowrap_mode` meldet als Mindestbreite 1 Pixel und dazu die Höhe, die
## der Text bei EINEM Pixel Breite braucht; korrigiert wird das erst, wenn es einmal eine
## echte Breite zugeteilt bekommen hat — und die bekommt es auf einer unsichtbaren Seite
## nie. Der PageStack rechnet unsichtbare Seiten aber mit, und der Screen wird nicht
## gescrollt: das Niederlage-Label ohne Mindestbreite machte den Abschluss 1878 statt 542
## Pixel hoch, und weil er in der Bildmitte hängt, lagen Kiste und Menü-Knopf außerhalb
## des Bildes — die Niederlage war eine Sackgasse
## (`test_the_defeat_screen_fits_into_the_base_resolution`).
##
## **Stufe 2 trägt die Sitzungsbilanz** (Issue #12, `_show_balance`): was der Lauf bis
## hier gebracht hat — Wellen, Antworten, neu gemeisterte und zurückeroberte Aufgaben mit
## Wortlaut. Nach einer Niederlage ist das der Abschluss des Laufs; nach einem Sieg steht
## sie über der Schwierigkeitswahl, damit sie auch beim Rückweg ins Menü zu sehen war.
## Kein dritter Screen: die Seite war nach einer Niederlage fast leer, und ein
## Zwischenschritt vor dem Menü hätte den Ausgang verzögert. Die Wortliste ist gedeckelt
## (`BALANCE_WORDS` plus „und N weitere"), und jede Zeile ist einzeilig mit fester Breite
## und Auslassung (Vorlage `BalanceLineTemplate`) — sonst wüchse die unsichtbare Seite mit
## einem langen Wort und schöbe über den PageStack auch Stufe 1 aus dem Bild.
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
## bucht nicht selbst, der Empfänger (WaveRunner -> Wallet) tut es. Den Gesamtstand
## zeigt er bewusst nicht: „Insgesamt 3 Gold" nach einer mageren Welle frustriert nur.
signal reward_collected(gold: int)
## Das Trostgold einer Welle ohne Kiste (siehe CONSOLATION_TITLE). Ein eigenes Signal,
## weil es keine geöffnete Kiste ist — Wallet zählt die Kisten mit.
signal consolation_collected(gold: int)

## Deltas der Schwierigkeitswahl, in Reihenfolge der Buttons in ChoiceRow (wave_stats.tscn).
const CHOICE_DELTAS := [-2, -1, 0, 1, 2]
## So viele Aufgaben nennt die Sitzungsbilanz beim Namen; der Rest steht als Zahl da.
## Gedeckelt, weil der Screen nicht scrollt (siehe Kopf).
const BALANCE_WORDS := 4
## Index der Standardauswahl ("Gleich").
const DEFAULT_CHOICE := 2
## Aufforderung an der Kiste, solange sie zu ist.
const CHEST_HINT := "2 Sekunden auf die Kiste drücken\n(oder Leertaste halten)"
## Steht statt des Kistennamens, wenn kein Monster besiegt wurde. Zweizeilig, weil der
## Titel nicht umbricht und die Spalte sonst den Screen verbreitern würde.
const CONSOLATION_TITLE := "Kein Monster besiegt –\naller Anfang ist schwer"

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
@onready var _balance: VBoxContainer = %Balance
@onready var _balance_lines: VBoxContainer = %BalanceLines
@onready var _balance_template: Label = %BalanceLineTemplate
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
	_update_choice_highlight()


## Befüllt den Screen mit den Statistiken einer Welle und zeigt ihn an (Stufe 1).
## Erwartete Felder in `data`: won, wave_number, difficulty, correct, leaked, total,
## accuracy, fortress_health, mastered, fortress_tier,
## xp_gained, levels_gained, optional chest = { tier, gold, name } (siehe
## ChestReward.for_wave) und optional session = Sitzungsbilanz (siehe RunBalance.build;
## leer oder fehlend = keine Bilanz).
func show_stats(data: Dictionary) -> void:
	_won = bool(data.get("won", true))
	_wave_number = int(data.get("wave_number", 0))

	for child in _lines.get_children():
		_lines.remove_child(child)
		child.queue_free()
	_add_line("Richtig besiegt: %d von %d" % [int(data.get("correct", 0)), int(data.get("total", 0))])
	_add_line("Durchgelassen: %d" % int(data.get("leaked", 0)))
	_add_line("Genauigkeit: %d %%" % int(round(float(data.get("accuracy", 0.0)))))
	# Keine Punkte (ein interner Wert, aus dem die Kiste rechnet) — dafür, was in dieser
	# Sitzung gemeistert wurde, und nur wenn es etwas gibt. Die Zahl kommt aus der
	# Sitzungsbilanz, damit Stufe 1 und Stufe 2 nicht zweierlei zählen.
	var session_mastered := int((data.get("session", {}) as Dictionary).get("mastered", 0))
	if session_mastered > 0:
		_add_line("🏅 In dieser Sitzung gemeistert: %d" % session_mastered)
	_add_line("Festung: %d HP" % int(data.get("fortress_health", 0)))
	_add_line("Gemeisterte Aufgaben: %d  (Festungsstufe %d)" % [
		int(data.get("mastered", 0)), int(data.get("fortress_tier", 0))])
	_add_line("Schwierigkeit: %d / 5" % int(data.get("difficulty", 3)))
	# Erfahrung: der Zuwachs kommt aus der Welle, der Stand aus dem Profil (PlayerLevel)
	# — dieselbe Aufteilung wie beim Gold. Verbucht ist er längst (WaveRunner._defeat);
	# hier wird nur gelesen.
	var progress := PlayerLevel.progress()
	_add_line("Erfahrung: +%d XP  (Level %d, %d/%d)" % [
		int(data.get("xp_gained", 0)), int(progress["level"]),
		int(progress["xp_in_level"]), int(progress["xp_for_level_up"])])
	# Der Aufstieg bekommt eine eigene Zeile, aber nur wenn es einen gab: eine
	# Sichtbarkeits-Entscheidung ist hier erlaubt, solange sie VOR dem Anzeigen fällt
	# (danach steht die Größe des Screens fest — siehe Kopf).
	var levels := int(data.get("levels_gained", 0))
	if levels > 0:
		_add_line("⭐ Level %d erreicht — %d Skillpunkt%s" % [
			int(progress["level"]), PlayerLevel.skill_points(),
			"" if PlayerLevel.skill_points() == 1 else "e"])

	# Kiste: die zweite Entscheidung über den Inhalt der Ergebnisseite (nach der
	# Aufstiegs-Zeile), und wie jene fällt sie HIER — vor dem Anzeigen. Ab dann bleibt
	# die Seite in ihrer Größe stehen.
	var chest: Dictionary = data.get("chest", {})
	_chest_gold = int(chest.get("gold", 0))
	var consolation := int(chest.get("consolation", 0)) if _chest_gold <= 0 else 0
	_reward.visible = _chest_gold > 0 or consolation > 0
	_chest_row.visible = _chest_gold > 0
	if consolation > 0:
		_chest_name.text = CONSOLATION_TITLE
		_reward_line.text = "+%s" % Wallet.label(consolation)
	else:
		_chest_name.text = str(chest.get("name", ChestReward.TIER_NAMES[0]))
		_reward_line.text = CHEST_HINT
	_chest.present(int(chest.get("tier", ChestReward.Tier.WOOD)), _chest_gold)
	_update_reward_gate()
	if consolation > 0:
		consolation_collected.emit(consolation)

	# Gefallene Festung = Ende des Laufs. Es gibt keine nächste Welle, also auch keine
	# Schwierigkeitswahl und keinen Startknopf — nur den Weg ins Menü. Damit muss der
	# Wellenstart die HP auch nie „retten": ein neuer Lauf beginnt über GameState.reset().
	_diff_label.visible = _won
	_choice_row.visible = _won
	_start_button.visible = _won
	_defeat_label.visible = not _won
	# Die Bilanz ist die dritte Inhalts-Entscheidung, und auch sie fällt hier: sie liegt
	# auf der noch unsichtbaren Stufe 2, zählt über den PageStack aber schon jetzt zur
	# Größe des Screens.
	_show_balance(data.get("session", {}))

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


# --- Sitzungsbilanz -----------------------------------------------------------

func _show_balance(balance: Dictionary) -> void:
	for child in _balance_lines.get_children():
		_balance_lines.remove_child(child)
		child.queue_free()
	_balance.visible = not balance.is_empty()
	if balance.is_empty():
		return
	var cleared := int(balance.get("waves_cleared", 0))
	# Die erreichte Welle nur, wenn sie über die geräumten hinausgeht — nach einer
	# Niederlage; nach einem Sieg wäre „3 geräumt (Welle 3)" dieselbe Zahl zweimal.
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
	# Genau BALANCE_WORDS Zeilen für Wörter, nie eine mehr: bei einem Überhang nimmt
	# „und N weitere" die letzte Zeile, statt eine fünfte anzuhängen.
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
	# Der eindeutige Name gehört der Vorlage; eine Kopie mit demselben Namen wäre ein
	# zweiter %BalanceLineTemplate.
	label.unique_name_in_owner = false
	label.text = text
	label.visible = true
	_balance_lines.add_child(label)


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
	# Verbucht wird im WaveRunner, nicht hier: der Screen meldet nur.
	reward_collected.emit(gold)


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
