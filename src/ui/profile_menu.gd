class_name ProfileMenu
extends Control
## Start-Screen (run/main_scene) mit drei Seiten in derselben Kulisse: „Wer spielt?"
## (profile_pick.tscn), das Hauptmenü und die Bibliothek (book_select.tscn). „Weiter" schiebt
## die Profilwahl nach links hinaus und das Menü von rechts herein, „Spielen" ebenso das Menü
## und die Bibliothek; die Kamera der Kulisse fährt mit — zur Bibliothek durch die Mauer in
## den Turm. „Zurück" und „Profil wechseln" schieben zurück. Wer aus einem anderen Screen
## hierher zurückkehrt, landet gleich im Menü (`intro_done`), aus der Buchkarte in der
## Bibliothek (MapSelection.to_shelf).
##
## Das Medaillon (ProfileBadge) gibt es einmal für Menü und Bibliothek: es liegt über den
## Seiten (BadgeLayer), fährt mit dem Menü herein und bleibt zwischen Menü und Bibliothek
## stehen; auf dem Weg in die Bibliothek wird es kompakt. Im Menü hält ein leerer Platz
## (BadgeSlot) ihm die Spalte frei.
##
## Das Layout liegt in profile_menu.tscn (im Editor sichtbar, Entwurf unter
## assets/ui/main_menu/sources/); hier wird nur bedient und angezeigt. Hinter dem Menü
## steht die 3D-Kulisse (menu_backdrop.tscn). Einstellungen (Profil, Standard-Schwierigkeit, Reset) liegen im
## Einstellungs-Fenster (settings_menu), der Lernstand im Statistik-Fenster (stats_screen).
##
## Unten rechts steht immer „Auf Updates prüfen" mit der laufenden Version (Issue #53): ein
## Klick prüft beide Kanäle laut (UpdateService.check, ContentService.refresh). Was es gibt,
## erscheint wie nach der stillen Startprüfung als Abzeichen darüber; der Link selbst sagt
## nur, ob er sucht, ob alles aktuell ist oder ob die Prüfung nicht durchkam.

const SESSION_SETUP_SCENE := "res://scenes/ui/session_setup.tscn"
const SETTINGS_SCENE := "res://scenes/ui/settings_menu.tscn"
const CONTENT_SCENE := "res://scenes/ui/content_manager.tscn"
## So lange blendet die Kulisse auf (s).
const VEIL_FADE := 0.6
## So lange schiebt die Seite (s) zwischen „Wer spielt?" und Menü, und so lange zwischen
## Menü und Bibliothek — dort ist der Weg weiter, durch die Mauer in den Turm.
const SLIDE_TIME := 0.8
const LIBRARY_SLIDE_TIME := 1.3
## So lange blendet der Schatten hinter den Menüknöpfen auf, wenn das Menü angekommen ist (s).
const SHADE_FADE := 0.4
const INTRO := 0.0
const MENU := 1.0
## „Spielen" führt über die Karte (ADR 0006); das freie Zusammenstellen der Runde ist der
## unauffällige Expertenmodus darunter.
const LIBRARY := 2.0

## Ob in diesem Programmlauf schon jemand „Wer spielt?" beantwortet hat. Statisch, weil
## jeder Rückweg aus Kampf, Karte oder Einstellungen diese Szene neu lädt.
static var intro_done := false

@onready var _badge: ProfileBadge = %ProfileBadge
@onready var _update_button: Button = %UpdateButton
@onready var _content_button: Button = %ContentButton
@onready var _content_update_button: Button = %ContentUpdateButton
@onready var _update_check: Button = %UpdateCheckButton
@onready var _play_button: Button = %PlayButton
@onready var _play_hint: Label = %PlayHint
@onready var _intro: ProfilePick = %Intro
@onready var _menu_page: Control = %MenuPage
@onready var _library: BookSelect = %Library
@onready var _backdrop: MenuBackdrop = $Backdrop
@onready var _shade: Control = %Shade

var _page := MENU
## Ob in diesem Besuch geklickt wurde — erst dann sagt der Link „Alles aktuell" oder benennt
## einen Fehlschlag; die stille Startprüfung behelligt niemanden.
var _checked := false
var _slide: Tween


func _ready() -> void:
	_play_button.pressed.connect(_open_library)
	_library.setup(_backdrop)
	_library.back_requested.connect(func(): _slide_to(MENU))
	(%ExpertButton as Button).pressed.connect(
			func(): get_tree().change_scene_to_file(SESSION_SETUP_SCENE))
	(%SkillButton as Button).pressed.connect(_open_window.bind(ProfileBadge.SKILL_SCENE, %SkillButton))
	(%SpellButton as Button).pressed.connect(_open_window.bind(ProfileBadge.SHOP_SCENE, %SpellButton))
	(%StatsButton as Button).pressed.connect(_open_window.bind(ProfileBadge.STATS_SCENE, %StatsButton))
	(%SettingsButton as Button).pressed.connect(_open_window.bind(SETTINGS_SCENE, %SettingsButton))
	(%QuitButton as Button).pressed.connect(get_tree().quit)
	Hints.attach(%QuitButton, "Beenden", "Schließt das Spiel.")
	_badge.switch_pressed.connect(_back_to_intro)
	# Was ein Fenster geändert haben kann und kein Signal meldet: ob es nach einer
	# Installation etwas zu spielen gibt (Inhalte).
	_badge.window_closed.connect(_refresh_play_gate)
	_intro.picked.connect(_play_as)
	_update_button.pressed.connect((%UpdateDialog as Control).open)
	_content_button.pressed.connect(_open_window.bind(CONTENT_SCENE, _content_button))
	# Fokus danach auf „Inhalte": der Hinweis ist nach dem Aktualisieren verschwunden.
	_content_update_button.pressed.connect(_open_window.bind(CONTENT_SCENE, _content_button))
	UpdateService.changed.connect(_refresh_update_badge)
	ContentService.changed.connect(_refresh_content_badge)
	_update_check.pressed.connect(_on_update_check)
	UpdateService.changed.connect(_refresh_update_check)
	ContentService.changed.connect(_refresh_update_check)
	Hints.attach(_update_check, "Auf Updates prüfen",
			"Schaut nach einer neuen Fassung des Spiels und nach neuen Vokabel-Packs. Was es "
			+ "gibt, erscheint darüber als Knopf.", "beim Start schaut das Spiel auch selbst")
	_refresh_update_check()
	_refresh_update_badge()
	_refresh_content_badge()
	_refresh_play_gate()
	# Beide Kanäle still prüfen: das Abzeichen soll dastehen, ohne dass jemand nachsieht.
	# Netzfehler bleiben in der Konsole (siehe UpdateService._fail / ContentService._fail_refresh).
	ContentService.refresh()
	if MapSelection.to_shelf:
		MapSelection.to_shelf = false
		_library.enter()
		_show_page(LIBRARY)
		_settle()
		# Die Buchkarte deckt schon den Bildschirm; die Kulisse braucht keinen Schleier.
		(%Veil as Control).visible = false
		_library.return_from_book()
		return
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
	_badge.refresh()
	_slide_to(MENU)


## Fähigkeiten, Statistik, Inhalte und Einstellungen öffnen als Fenster über dem Menü, nicht
## als eigener Screen: die Kulisse bleibt stehen. Geöffnet wird über die Plakette — dieselbe
## Stelle, an der sie in Bibliothek und Karte Fähigkeiten und Statistik öffnet.
func _open_window(path: String, opener: Control) -> void:
	_badge.open_window(path, opener)


func _back_to_intro() -> void:
	_intro.refresh()
	_slide_to(INTRO)


func _open_library() -> void:
	# Die Bücher stehen, bevor die Seite hereinfährt — nichts baut sich im Bild auf.
	_library.enter()
	_badge.refresh()
	_slide_to(LIBRARY)


func _pages() -> Array[Control]:
	return [_intro, _menu_page, _library]


func _slide_to(target: float) -> void:
	if _slide != null:
		_slide.kill()
	if _page >= LIBRARY - 0.01 and target < LIBRARY:
		_library.leave()
	# Alle Seiten auf dem Weg stehen während der Fahrt; bedienbar ist keine, bis sie
	# angekommen ist.
	get_viewport().gui_release_focus()
	for i in _pages().size():
		var page := _pages()[i]
		page.visible = i >= floorf(minf(_page, target)) and i <= ceilf(maxf(_page, target))
		page.process_mode = Node.PROCESS_MODE_DISABLED
	(%BadgeLayer as Control).process_mode = Node.PROCESS_MODE_DISABLED
	# Der Schatten links hinter den Knöpfen endet mitten im Bild; mitgeschoben sähe er
	# aus wie eine Kante. Er kommt erst, wenn das Menü steht (_settle).
	_shade.modulate.a = 0.0
	_slide = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_slide.tween_method(_show_page, _page, target, _slide_time(_page, target))
	_slide.tween_callback(_settle)


## Wie lange die Fahrt von `from` nach `to` dauert: je Abschnitt seine eigene Zeit.
static func _slide_time(from: float, to: float) -> float:
	var low := minf(from, to)
	var high := maxf(from, to)
	var outside := maxf(0.0, minf(high, MENU) - low)
	var inside := maxf(0.0, high - maxf(low, MENU))
	return SLIDE_TIME * outside + LIBRARY_SLIDE_TIME * inside


## `page` 0 = „Wer spielt?", 1 = Menü, 2 = Bibliothek. Über die Anker und nicht in Pixeln, damit eine
## Größenänderung des Fensters die Seiten nicht verrutscht.
func _show_page(page: float) -> void:
	_page = page
	var slide := %Slide as Control
	slide.anchor_left = -page
	slide.anchor_right = 1.0 - page
	# Das Medaillon steht mit dem Menü, ab dort still: von „Wer spielt?" kommt es mit herein.
	var layer := %BadgeLayer as Control
	var shift := maxf(0.0, MENU - page)
	layer.anchor_left = shift
	layer.anchor_right = 1.0 + shift
	layer.visible = page > INTRO
	_badge.compact = clampf(page - MENU, 0.0, 1.0)
	_backdrop.page = page


## Die Seite außerhalb des Bildes ist aus — sonst fände die Tastatur dort Knöpfe.
func _settle() -> void:
	var at := roundi(_page)
	for i in _pages().size():
		_pages()[i].visible = i == at
		_pages()[i].process_mode = Node.PROCESS_MODE_INHERIT
	(%BadgeLayer as Control).process_mode = Node.PROCESS_MODE_INHERIT
	if at == INTRO:
		_intro.focus_next()
	elif at == MENU and _shade.modulate.a < 1.0:
		create_tween().tween_property(_shade, "modulate:a", 1.0, SHADE_FADE)


## Der erste Auftritt der Kulisse übersetzt ihre Shader und hält das Bild kurz an
## (docs/CONVENTIONS.md „Fallen"). Das Menü steht sofort; die Kulisse blendet danach auf, statt
## halb gezeichnet zu ruckeln.
func _unveil() -> void:
	var veil := %Veil as ColorRect
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	if not is_inside_tree():
		return
	create_tween().tween_property(veil, "modulate:a", 0.0, VEIL_FADE)


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


## Zeigt an, wenn sich Inhalte aktualisieren lassen — derselbe Knopf wie beim App-Update,
## darunter. Er öffnet den Content-Manager, der die betroffenen Packs schon vorwählt.
## „Programm zu alt" zählt hier nicht mit — dagegen hilft das Update-Abzeichen, nicht dieses.
func _refresh_content_badge() -> void:
	var count := ContentService.update_count()
	_content_update_button.visible = count > 0
	_content_update_button.text = content_update_text(count)


func _on_update_check() -> void:
	_checked = true
	UpdateService.check(true)
	ContentService.refresh(true)
	_refresh_update_check()


## Der Link unten rechts: gesperrt, solange gesucht wird; danach sagt er, was herauskam.
func _refresh_update_check() -> void:
	var busy := UpdateService.state == UpdateService.State.CHECKING \
			or ContentService.state == ContentService.State.LOADING
	_update_check.disabled = busy
	var found := UpdateService.state in [UpdateService.State.AVAILABLE, UpdateService.State.READY] \
			or ContentService.update_count() > 0
	var failed := UpdateService.state == UpdateService.State.ERROR \
			or ContentService.state == ContentService.State.ERROR
	_update_check.text = update_check_text(busy, found, failed, _checked, SemVer.app_version())


## Zwei Zeilen wie „Eigene Runde / Expertenmodus" gegenüber: oben, was der Link tut oder was
## herauskam, unten die laufende Version. Ein Fund steht nicht hier, sondern als Abzeichen
## darüber — hier steht dann wieder das Angebot, noch einmal zu prüfen.
static func update_check_text(busy: bool, found: bool, failed: bool, checked: bool,
		version: String) -> String:
	var first := "Auf Updates prüfen"
	if busy:
		first = "Suche nach Updates …"
	elif checked and failed:
		first = "Prüfen ging nicht – nochmal"
	elif checked and not found:
		first = "Alles aktuell"
	return "%s\nVersion %s" % [first, version]


static func content_update_text(count: int) -> String:
	return "⬆ Inhalte aktualisieren" if count <= 1 else "⬆ %d Inhalte aktualisieren" % count
