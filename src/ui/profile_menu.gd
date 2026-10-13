class_name ProfileMenu
extends Control
## Start-Screen (run/main_scene): drei Seiten in einer 3D-Kulisse — „Wer spielt?" (0),
## Hauptmenü (1), Bibliothek (2) — zwischen denen geschoben wird; die Kamera fährt mit.
## Wer zurückkehrt, landet im Menü (`intro_done`), aus der Buchkarte in der Bibliothek
## (MapSelection.to_shelf). Das Medaillon (ProfileBadge) liegt einmal über allen Seiten
## (BadgeLayer). Layout in profile_menu.tscn.

const SESSION_SETUP_SCENE := "res://scenes/ui/session_setup.tscn"
const SETTINGS_SCENE := "res://scenes/ui/settings_menu.tscn"
const CONTENT_SCENE := "res://scenes/ui/content_manager.tscn"
## Aufblenden der Kulisse (s).
const VEIL_FADE := 0.6
## Schiebezeit (s) zwischen „Wer spielt?" und Menü bzw. zwischen Menü und Bibliothek.
const SLIDE_TIME := 0.8
const LIBRARY_SLIDE_TIME := 1.3
## Aufblenden des Schattens hinter den Menüknöpfen (s).
const SHADE_FADE := 0.4
const INTRO := 0.0
const MENU := 1.0
const LIBRARY := 2.0

## Ob in diesem Programmlauf schon jemand „Wer spielt?" beantwortet hat. Statisch, weil
## jeder Rückweg diese Szene neu lädt.
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
## Ob in diesem Besuch geklickt wurde; erst dann meldet der Link Ergebnis oder Fehlschlag.
var _checked := false
var _slide: Tween
## Hinweise zum Spielstand, die noch kommen, der gerade gezeigte, und was danach folgt.
var _save_notices: Array = []
var _save_notice := {}
var _after_save_notices := Callable()


func _ready() -> void:
	_play_button.pressed.connect(_open_library)
	(%SaveNotice as ConfirmDialog).confirmed.connect(_on_save_notice_closed.bind(true))
	(%SaveNotice as ConfirmDialog).cancelled.connect(_on_save_notice_closed.bind(false))
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
	# Eine Installation im Fenster meldet kein Signal.
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
	# Still prüfen, Fehler nur in der Konsole; UpdateService prüft beim Start selbst.
	ContentService.refresh()
	if MapSelection.to_shelf:
		MapSelection.to_shelf = false
		_library.enter()
		_show_page(LIBRARY)
		_settle()
		# Die Buchkarte deckt schon den Bildschirm; die Kulisse braucht keinen Schleier.
		(%Veil as Control).visible = false
		_library.return_from_book()
		_show_save_notices()
		return
	_show_page(MENU if intro_done else INTRO)
	_settle()
	_unveil()
	_show_save_notices(_show_stats_notice)


## Was der SaveCoordinator über den Spielstand zu sagen hat (ADR 0024), einer nach dem
## anderen; danach `then`. Ein gesperrtes Profil fragt, ob es leer weitergehen soll.
func _show_save_notices(then := Callable()) -> void:
	_save_notices.append_array(SaveCoordinator.take_notices())
	if then.is_valid():
		_after_save_notices = then
	if not (%SaveNotice as Control).visible:
		_next_save_notice()


func _next_save_notice() -> void:
	if _save_notices.is_empty():
		var then := _after_save_notices
		_after_save_notices = Callable()
		if then.is_valid():
			then.call()
		return
	_save_notice = _save_notices.pop_front()
	var text := SaveNotices.text(_save_notice,
			UserSettings.display_name(str(_save_notice.get("profile", ""))))
	if text.is_empty():
		_next_save_notice()
		return
	var dialog := %SaveNotice as ConfirmDialog
	if str(text["keep"]).is_empty():
		dialog.inform(text["title"], text["body"], text["action"])
	else:
		dialog.ask(text["title"], text["body"], text["action"], text["keep"])


func _on_save_notice_closed(accepted: bool) -> void:
	if accepted and _save_notice.get("kind") == "blocked":
		SaveCoordinator.start_blank()
		_badge.refresh()
	_next_save_notice.call_deferred()


## Einmal je Rechner, bevor die erste Statistik hinausgeht (ADR 0021), nur in einer Fassung
## mit Schlüssel. Auch Escape gilt als gesehen.
func _show_stats_notice() -> void:
	if not StatsUploader.configured() or UserSettings.stats_notice_seen():
		return
	var notice := %StatsNotice as ConfirmDialog
	notice.inform("Spieldaten für die Entwicklung",
			"Dieses Spiel ist in einer sehr frühen Entwicklungsphase. Damit es besser wird, schickt es nach jedem "
			+ "Lauf anonymisierte Spieldaten verschlüsselt an unseren Server in Deutschland: Fortschritt, Gold, Erfahrung, "
			+ "welche Wörter wie oft richtig waren und wie lange die Antworten dauerten.\n\n"
			+ "Niemals gespeichert wird: Namen und getippte Antworten. Nur wer ein Wort bewusst "
			+ "meldet, kann einen Kommentar mitschicken – auch dann bleibt das anonym. "
			+ "Jedes Profil bekommt eine zufällige Nummer, die nicht mit einem Namen verknüpft werden kann.\n\n"
			+ "Genaueres steht im Handbuch unter „Spieldaten“.", "Verstanden")
	notice.confirmed.connect(StatsUploader.notice_acknowledged, CONNECT_ONE_SHOT)
	notice.cancelled.connect(StatsUploader.notice_acknowledged, CONNECT_ONE_SHOT)


## Schaltet auf das Profil `id` und schiebt ins Menü.
func _play_as(id: String) -> void:
	intro_done = true
	# Die Profildaten schalten über UserSettings.active_profile_changed selbst um.
	UserSettings.set_active_profile(id)
	_badge.refresh()
	_slide_to(MENU)
	_show_save_notices()


## Öffnet ein Fenster über dem Menü (über die Plakette); die Kulisse bleibt stehen.
func _open_window(path: String, opener: Control) -> void:
	_badge.open_window(path, opener)


func _back_to_intro() -> void:
	_intro.refresh()
	_slide_to(INTRO)


func _open_library() -> void:
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
	# Während der Fahrt sind alle Seiten auf dem Weg sichtbar, aber keine bedienbar.
	get_viewport().gui_release_focus()
	for i in _pages().size():
		var page := _pages()[i]
		page.visible = i >= floorf(minf(_page, target)) and i <= ceilf(maxf(_page, target))
		page.process_mode = Node.PROCESS_MODE_DISABLED
	(%BadgeLayer as Control).process_mode = Node.PROCESS_MODE_DISABLED
	# Der Schatten endet mitten im Bild; er kommt erst in _settle zurück.
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


## `page` wie INTRO/MENU/LIBRARY, auch dazwischen. Über Anker, damit Fenstergrößen nichts
## verrutschen.
func _show_page(page: float) -> void:
	_page = page
	var slide := %Slide as Control
	slide.anchor_left = -page
	slide.anchor_right = 1.0 - page
	# Das Medaillon fährt nur zwischen „Wer spielt?" und Menü mit.
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


## Blendet die Kulisse erst nach zwei gezeichneten Bildern auf, wenn ihre Shader übersetzt
## sind (docs/CONVENTIONS.md „Fallen").
func _unveil() -> void:
	var veil := %Veil as ColorRect
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	if not is_inside_tree():
		return
	create_tween().tween_property(veil, "modulate:a", 0.0, VEIL_FADE)


## Das Abzeichen erscheint nur, wenn es etwas zu tun gibt, nie bei einem Fehlschlag.
func _refresh_update_badge() -> void:
	_update_button.visible = UpdateService.state in [
		UpdateService.State.AVAILABLE,
		UpdateService.State.READY,
	]
	if UpdateService.state == UpdateService.State.READY:
		_update_button.text = "⬆ Update %s bereit" % UpdateService.version
	else:
		_update_button.text = "⬆ Update auf %s" % UpdateService.version


## Sperrt „Spielen", solange keine Vokabeln installiert sind. Ungefiltert geprüft, damit
## eine zu enge Filterauswahl nicht den Weg zu ihrer Lockerung sperrt.
func _refresh_play_gate() -> void:
	var playable := WaveGenerator.new().has_playable({})
	_play_button.disabled = not playable
	_play_hint.visible = not playable


## Zeigt an, wenn sich Inhalte aktualisieren lassen; „Programm zu alt" zählt nicht mit.
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


## Zwei Zeilen: Zustand der Prüfung, darunter die laufende Version. Ein Fund steht als
## Abzeichen darüber, nicht hier.
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
