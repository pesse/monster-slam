class_name ProfileMenu
extends Control
## Start-Screen (run/main_scene) mit zwei Seiten vor derselben Kulisse: erst „Wer spielt?"
## (profile_pick.tscn), dann das Hauptmenü. „Weiter" schiebt die Profilwahl nach links
## hinaus und das Menü von rechts herein, die Kamera der Kulisse fährt mit; „Profil
## wechseln" schiebt zurück. Wer aus einem anderen Screen hierher zurückkehrt, landet
## gleich im Menü (`intro_done`).
##
## Das Layout liegt in profile_menu.tscn (im Editor sichtbar, Entwurf unter
## assets/ui/main_menu/sources/); hier wird nur bedient und angezeigt. Hinter dem Menü
## steht die 3D-Kulisse (menu_backdrop.tscn). Einstellungen (Profil, Standard-Schwierigkeit, Reset) liegen im
## settings_menu-Screen, der Lernstand im stats_screen-Screen.

const SESSION_SETUP_SCENE := "res://scenes/ui/session_setup.tscn"
const SETTINGS_SCENE := "res://scenes/ui/settings_menu.tscn"
const STATS_SCENE := "res://scenes/ui/stats_screen.tscn"
const SKILL_SCENE := "res://scenes/ui/skill_tree.tscn"
const CONTENT_SCENE := "res://scenes/ui/content_manager.tscn"
## „Lernen" führt über die Karte (ADR 0006); das freie Zusammenstellen der Runde ist der
## unauffällige Expertenmodus darunter.
const BOOKS_SCENE := "res://scenes/ui/book_select.tscn"
## So lange blendet die Kulisse auf (s).
const VEIL_FADE := 0.6
## So lange schiebt die Seite (s).
const SLIDE_TIME := 0.8
## So lange blendet der Schatten hinter den Menüknöpfen auf, wenn das Menü angekommen ist (s).
const SHADE_FADE := 0.4
const INTRO := 0.0
const MENU := 1.0

## Ob in diesem Programmlauf schon jemand „Wer spielt?" beantwortet hat. Statisch, weil
## jeder Rückweg aus Kampf, Karte oder Einstellungen diese Szene neu lädt.
static var intro_done := false

@onready var _gold_label: Label = %GoldLabel
@onready var _level_label: Label = %LevelLabel
@onready var _xp_bar: ProgressBar = %XpBar
@onready var _xp_label: Label = %XpLabel
@onready var _points_label: Label = %PointsLabel
@onready var _update_button: Button = %UpdateButton
@onready var _content_button: Button = %ContentButton
@onready var _play_button: Button = %PlayButton
@onready var _play_hint: Label = %PlayHint
@onready var _intro: ProfilePick = %Intro
@onready var _menu_page: Control = %MenuPage
@onready var _backdrop: MenuBackdrop = $Backdrop
@onready var _shade: Control = %Shade

var _page := MENU
var _slide: Tween


func _ready() -> void:
	_play_button.pressed.connect(func(): get_tree().change_scene_to_file(BOOKS_SCENE))
	(%ExpertButton as Button).pressed.connect(
			func(): get_tree().change_scene_to_file(SESSION_SETUP_SCENE))
	(%SkillButton as Button).pressed.connect(func(): get_tree().change_scene_to_file(SKILL_SCENE))
	(%StatsButton as Button).pressed.connect(func(): get_tree().change_scene_to_file(STATS_SCENE))
	(%SettingsButton as Button).pressed.connect(func(): get_tree().change_scene_to_file(SETTINGS_SCENE))
	(%SwitchButton as Button).pressed.connect(_back_to_intro)
	_intro.picked.connect(_play_as)
	_update_button.pressed.connect((%UpdateDialog as Control).open)
	_content_button.pressed.connect(func(): get_tree().change_scene_to_file(CONTENT_SCENE))
	UpdateService.changed.connect(_refresh_update_badge)
	ContentService.changed.connect(_refresh_content_badge)
	Wallet.changed.connect(func(_gold): _refresh_gold())
	PlayerLevel.changed.connect(func(_total_xp, _level): _refresh_level())
	# Ausgegebene Punkte verändern dieselbe Zeile wie verdiente.
	SkillBook.changed.connect(_refresh_level)
	(%ProfileLabel as Label).text = UserSettings.display_name()
	_refresh_gold()
	_refresh_level()
	_refresh_update_badge()
	_refresh_content_badge()
	_refresh_play_gate()
	# Beide Kanäle still prüfen: das Abzeichen soll dastehen, ohne dass jemand nachsieht.
	# Netzfehler bleiben in der Konsole (siehe UpdateService._fail / ContentService._fail).
	ContentService.refresh()
	_show_page(MENU if intro_done else INTRO)
	_settle()
	_unveil()


## Schaltet auf das Profil `id` und schiebt ins Menü.
func _play_as(id: String) -> void:
	intro_done = true
	UserSettings.set_active_profile(id)
	PlayerProgress.switch_to(id)
	# Geldbörse, Erfahrung und Fähigkeiten schalten über
	# UserSettings.active_profile_changed selbst um (siehe Wallet._ready / PlayerLevel._ready).
	(%ProfileLabel as Label).text = UserSettings.display_name()
	_refresh_gold()
	_refresh_level()
	_slide_to(MENU)


func _back_to_intro() -> void:
	_intro.refresh()
	_slide_to(INTRO)


func _slide_to(target: float) -> void:
	if _slide != null:
		_slide.kill()
	# Beide Seiten stehen während der Fahrt; bedienbar ist keine, bis sie angekommen ist.
	get_viewport().gui_release_focus()
	_intro.visible = true
	_menu_page.visible = true
	_intro.process_mode = Node.PROCESS_MODE_DISABLED
	_menu_page.process_mode = Node.PROCESS_MODE_DISABLED
	# Der Schatten links hinter den Knöpfen endet mitten im Bild; mitgeschoben sähe er
	# aus wie eine Kante. Er kommt erst, wenn das Menü steht (_settle).
	_shade.modulate.a = 0.0
	_slide = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_slide.tween_method(_show_page, _page, target, SLIDE_TIME * absf(target - _page))
	_slide.tween_callback(_settle)


## `page` 0 = „Wer spielt?", 1 = Menü. Über die Anker und nicht in Pixeln, damit eine
## Größenänderung des Fensters die Seiten nicht verrutscht.
func _show_page(page: float) -> void:
	_page = page
	var slide := %Slide as Control
	slide.anchor_left = -page
	slide.anchor_right = 1.0 - page
	_backdrop.page = page


## Die Seite außerhalb des Bildes ist aus — sonst fände die Tastatur dort Knöpfe.
func _settle() -> void:
	var on_intro := _page < 0.5
	_intro.visible = on_intro
	_menu_page.visible = not on_intro
	_intro.process_mode = Node.PROCESS_MODE_INHERIT
	_menu_page.process_mode = Node.PROCESS_MODE_INHERIT
	if on_intro:
		_intro.focus_next()
	elif _shade.modulate.a < 1.0:
		create_tween().tween_property(_shade, "modulate:a", 1.0, SHADE_FADE)


## Der erste Auftritt der Kulisse übersetzt ihre Shader und hält das Bild kurz an
## (CLAUDE.md „Fallen"). Das Menü steht sofort; die Kulisse blendet danach auf, statt
## halb gezeichnet zu ruckeln.
func _unveil() -> void:
	var veil := %Veil as ColorRect
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	if not is_inside_tree():
		return
	create_tween().tween_property(veil, "modulate:a", 0.0, VEIL_FADE)


## Der Goldstand des aktiven Profils. Er steht auf dem Start-Screen und nicht nur in der
## Statistik: Gold wird ausgegeben, und der Laden wird von hier aus erreichbar sein.
func _refresh_gold() -> void:
	_gold_label.text = "💰 %s" % Wallet.label()


## Level und Stand im Level auf der Plakette, darunter die OFFENEN Skillpunkte. Leiser als
## der Goldstand (MenuNote): die Entscheidung fällt nicht hier, sondern im
## Fähigkeiten-Screen. Gezeigt wird der offene Stand (verdient minus ausgegeben, siehe
## SkillBook.available) und nicht der verdiente — eine Zahl, die nach dem Ausgeben stehen
## bleibt, wäre eine Aufforderung ins Leere.
func _refresh_level() -> void:
	var progress := PlayerLevel.progress()
	var in_level := int(progress["xp_in_level"])
	var for_up := int(progress["xp_for_level_up"])
	_level_label.text = "Level %d" % int(progress["level"])
	_xp_bar.max_value = maxi(for_up, 1)
	_xp_bar.value = in_level
	_xp_label.text = "%d / %d XP" % [in_level, for_up]
	var points := SkillBook.available()
	if SkillBook.unlimited_points:
		_points_label.text = "∞ Skillpunkte (Debug)"
	elif points > 0:
		_points_label.text = "%d Skillpunkt%s offen" % [points, "" if points == 1 else "e"]
	_points_label.visible = SkillBook.unlimited_points or points > 0


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
	_content_button.text = "INHALTE (%d NEU)" % count if count > 0 else "INHALTE"
