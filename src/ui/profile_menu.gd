extends Control
## Hauptmenü: Titel, wer spielt, und Einstieg ins Spiel. Gestartet wird in „Wer spielt?"
## (profile_pick, run/main_scene); „Profil wechseln" führt dorthin zurück.
##
## Das Layout liegt in profile_menu.tscn (im Editor sichtbar); hier wird nur bedient und
## angezeigt. Einstellungen (Profil, Standard-Schwierigkeit, Reset) liegen im
## settings_menu-Screen, der Lernstand im stats_screen-Screen.

const SESSION_SETUP_SCENE := "res://scenes/ui/session_setup.tscn"
const SETTINGS_SCENE := "res://scenes/ui/settings_menu.tscn"
const STATS_SCENE := "res://scenes/ui/stats_screen.tscn"
const SKILL_SCENE := "res://scenes/ui/skill_tree.tscn"
const CONTENT_SCENE := "res://scenes/ui/content_manager.tscn"
const PICK_SCENE := "res://scenes/ui/profile_pick.tscn"
## „▶ Spielen" führt über die Karte (ADR 0006); das freie Zusammenstellen der Runde ist der
## unauffällige Expertenmodus darunter.
const BOOKS_SCENE := "res://scenes/ui/book_select.tscn"

@onready var _gold_label: Label = %GoldLabel
@onready var _level_label: Label = %LevelLabel
@onready var _update_button: Button = %UpdateButton
@onready var _content_button: Button = %ContentButton
@onready var _play_button: Button = %PlayButton
@onready var _play_hint: Label = %PlayHint


func _ready() -> void:
	_play_button.pressed.connect(func(): get_tree().change_scene_to_file(BOOKS_SCENE))
	(%ExpertButton as Button).pressed.connect(
			func(): get_tree().change_scene_to_file(SESSION_SETUP_SCENE))
	(%SkillButton as Button).pressed.connect(func(): get_tree().change_scene_to_file(SKILL_SCENE))
	(%StatsButton as Button).pressed.connect(func(): get_tree().change_scene_to_file(STATS_SCENE))
	(%SettingsButton as Button).pressed.connect(func(): get_tree().change_scene_to_file(SETTINGS_SCENE))
	(%SwitchButton as Button).pressed.connect(func(): get_tree().change_scene_to_file(PICK_SCENE))
	_update_button.pressed.connect((%UpdateDialog as Control).open)
	_content_button.pressed.connect(func(): get_tree().change_scene_to_file(CONTENT_SCENE))
	UpdateService.changed.connect(_refresh_update_badge)
	ContentService.changed.connect(_refresh_content_badge)
	Wallet.changed.connect(func(_gold): _refresh_gold())
	PlayerLevel.changed.connect(func(_total_xp, _level): _refresh_level())
	# Ausgegebene Punkte verändern dieselbe Zeile wie verdiente.
	SkillBook.changed.connect(_refresh_level)
	(%ProfileLabel as Label).text = "👤 %s" % UserSettings.display_name()
	_refresh_gold()
	_refresh_level()
	_refresh_update_badge()
	_refresh_content_badge()
	_refresh_play_gate()
	# Beide Kanäle still prüfen: das Abzeichen soll dastehen, ohne dass jemand nachsieht.
	# Netzfehler bleiben in der Konsole (siehe UpdateService._fail / ContentService._fail).
	ContentService.refresh()


## Der Goldstand des aktiven Profils. Er steht auf dem Start-Screen und nicht nur in der
## Statistik: Gold wird ausgegeben, und der Laden wird von hier aus erreichbar sein.
func _refresh_gold() -> void:
	_gold_label.text = "💰 %s" % Wallet.label()


## Level, Stand im Level und OFFENE Skillpunkte. Leiser als der Goldstand (Hint): die
## Entscheidung fällt nicht hier, sondern im Fähigkeiten-Screen. Gezeigt wird der offene
## Stand (verdient minus ausgegeben, siehe SkillBook.available) und nicht der verdiente —
## eine Zahl, die nach dem Ausgeben stehen bleibt, wäre eine Aufforderung ins Leere.
func _refresh_level() -> void:
	var progress := PlayerLevel.progress()
	var text := "⭐ Level %d  ·  %d/%d XP" % [
		int(progress["level"]), int(progress["xp_in_level"]), int(progress["xp_for_level_up"])]
	var points := SkillBook.available()
	if SkillBook.unlimited_points:
		text += "  ·  ∞ Skillpunkte (Debug)"
	elif points > 0:
		text += "  ·  %d Skillpunkt%s offen" % [points, "" if points == 1 else "e"]
	_level_label.text = text


## Das Abzeichen erscheint nur, wenn es etwas zu tun gibt. Ein Fehlschlag der Prüfung wird
## hier NICHT gezeigt — die Startprüfung soll niemanden mit einem Netzproblem behelligen,
## das ihn nicht betrifft.
func _refresh_update_badge() -> void:
	_update_button.visible = UpdateService.state in [
		UpdateService.State.AVAILABLE,
		UpdateService.State.READY,
	]
	if UpdateService.state == UpdateService.State.READY:
		_update_button.text = "⬆ Update %s bereit" % UpdateService.version
	else:
		_update_button.text = "⬆ Update auf %s" % UpdateService.version


## Ohne Vokabeln gibt es nichts zu spielen: der Kampf hätte keine Monster, kein
## Wellenende und (vor dem Abbruch per Escape) keinen Rückweg. Der Knopf sperrt also,
## bis Inhalte da sind, und sagt wohin.
##
## Bewusst UNGEFILTERT geprüft (leerer Pool = keine Einschränkung) und nicht mit der
## Profil-Auswahl: sonst sperrt eine zu enge Filterauswahl genau den Weg zum Screen,
## auf dem man sie wieder lockern könnte. Die Auswahl prüft das Session-Setup selbst.
func _refresh_play_gate() -> void:
	var playable := WaveGenerator.new().has_playable({})
	_play_button.disabled = not playable
	_play_hint.visible = not playable


## Zeigt an, wenn Inhalte nachzuziehen sind. „Programm zu alt" zählt hier nicht mit — dagegen
## hilft das Update-Abzeichen, nicht dieses.
func _refresh_content_badge() -> void:
	var count := ContentService.attention_count()
	_content_button.text = "📚 Inhalte (%d neu)" % count if count > 0 else "📚 Inhalte"
