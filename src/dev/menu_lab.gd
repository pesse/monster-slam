extends Node
## Werkbank: das Hauptmenü samt Kulisse als Bild, zum Abgleich mit dem Entwurf
## (assets/ui/main_menu/sources/approved-concept.png).
##
##     GODOT_WINDOW=1 tools/godot.sh res://scenes/dev/menu_lab.tscn -- --shoot
##         speichert reports/menu/menu_<breite>x<höhe>.png und beendet sich.
##     … -- --shoot --size=1920x1080     anderes Fenster (Bezugsgröße nach Menügröße, UiScale)
##     … -- --shoot --backdrop           nur die Kulisse, ohne Menü
##     … -- --shoot --intro              „Wer spielt?" statt des Menüs
##     … -- --shoot --intro --slide=0.5  mitten im Schieben (0 = „Wer spielt?", 1 = Menü,
##                                       2 = Bibliothek)
##     … -- --shoot --library            die Bibliothek (kein Buch herausgenommen)
##     … -- --shoot --library --book=<id> … mit diesem Buch herausgenommen
##     … -- --shoot --to-library         schiebt wie „Spielen" in die Bibliothek
##     … -- --shoot --intro --to-menu    schiebt wie „Weiter" ins Menü (ohne Profilwechsel)
##     … -- --shoot --stats              drückt „Statistik": das Fenster über der Kulisse
##     … -- --shoot --stats=close        … und schließt es wieder; druckt, wer den Fokus hat
##     … -- --shoot --content            drückt „Inhalte": das Fenster über der Kulisse
##     … -- --shoot --spells             drückt „Zauber": der Laden über der Kulisse (auf einer
##                                       Karte über die Knopfreihe der Plakette)
##     … -- --shoot … --stock=<id>:<n>,…  Vorrat für das Bild, nur im Speicher
##                                       (z. B. --stock=spell.frost:3,,spell.mend:1)
##     … -- --shoot --settings[=<reiter>] drückt „Einstellungen", Reiter 1–3 (Profil, Melden,
##                                       Protokoll)
##     … -- --shoot --handbook[=<datei>[#<anker>]]  das Handbuch über dem Menü, auf einem
##                                       Kapitel (z. B. 18-wie-das-spiel-lernt.md#weiteres)
##     … -- --shoot --hint=<knoten>      die Karte an diesem Knoten (Name, eindeutig im Baum)
##     … -- --shoot --badge-hint         die Karte am Medaillon der Plakette (Level, XP, Punkte)
##     … -- --shoot --map=book [--book=<id>]            die Buchkarte
##     … -- --shoot --map=area [--book=<id>] [--unit=N] die Gebietskarte einer Unit
##     … -- --shoot --map=area --stats   … mit dem Statistik-Fenster der Plakette darüber
##     … -- --shoot --updates            beide Update-Hinweise sichtbar (App und Inhalte)
##     … -- --shoot … --hour=<h>         Sonne fest auf diese Stunde (6–18, SunCycle) statt
##                                       nach der Uhr — für Vergleichsbilder des Lichts
##     … -- --timelapse=<n>              Zeitraffer: die Sonne läuft n-mal so schnell wie nach
##                                       der Uhr (dort ein Tag je Stunde; 60 = ein Tag je
##                                       Minute), ab --hour oder ab der Uhrzeit
##
## Ohne --shoot bleibt das Fenster offen und lässt sich bedienen; unten rechts steht die
## Uhrzeit der Sonne (auf den Bildern nicht).
##     … -- --shoot … --name=<Name> --gold=<n>       Name und Gold der Plakette, nur im Speicher
##                                       (für Bilder ohne echten Profilnamen und Debug-Gold)
##
## Das Menü liest das aktive Profil nur (Name, Gold, Level); geschrieben wird nichts.
## Headless gibt es keinen Renderer — deshalb GODOT_WINDOW=1.

const MENU_SCENE := "res://scenes/ui/profile_menu.tscn"
const BACKDROP_SCENE := "res://scenes/ui/menu_backdrop.tscn"
const SHOT_DIR := "res://reports/menu"
## So lange steht das Bild, bevor es gespeichert wird: Einblenden und ein Stück Idle.
const SETTLE := 2.0

@onready var _clock: Control = %Clock
@onready var _clock_text: Label = %ClockText

## Die Sonne der Kulisse, falls die gezeigte Szene eine hat (Karten haben keine).
var _cycle: SunCycle
## Wie viel schneller als nach der Uhr sie läuft; 0 = sie folgt der Uhr oder steht.
var _timelapse := 0.0


func _ready() -> void:
	var size := _arg("size")
	if not size.is_empty():
		var parts := size.split("x")
		get_window().size = Vector2i(int(parts[0]), int(parts[1]))
	var path := BACKDROP_SCENE if _has_arg("backdrop") else MENU_SCENE
	var map := _arg("map")
	if not map.is_empty():
		var books := ContentRegistry.all_books()
		MapSelection.book = _arg("book") if not _arg("book").is_empty() \
				else (str(books[0]) if not books.is_empty() else "")
		MapSelection.unit = int(_arg("unit")) if not _arg("unit").is_empty() else 1
		path = MapSelection.AREA_SCENE if map == "area" else MapSelection.BOOK_SCENE
	if not _arg("name").is_empty():
		# Nur im Speicher: ohne _save() bleibt settings.cfg, wie es ist.
		UserSettings._config.set_value("names", UserSettings.active_profile(), _arg("name"))
	if not _arg("gold").is_empty():
		Wallet.unlimited_gold = false
		Wallet.gold = int(_arg("gold"))
	if _has_arg("stock") or not _arg("stock").is_empty():
		# Nur im Speicher wie Name und Gold: ohne buy/take schreibt Inventory nichts.
		Inventory.slots.clear()
		for part in _arg("stock").split(","):
			var bits := part.split(":")
			Inventory.slots.append({} if bits.size() < 2 \
					else {"id": bits[0], "count": int(bits[1])})
	ProfileMenu.intro_done = not _has_arg("intro")
	var screen := (load(path) as PackedScene).instantiate()
	add_child(screen)
	var slide := _arg("slide")
	if screen is ProfileMenu and not slide.is_empty():
		for page in ["%Intro", "%MenuPage", "%Library"]:
			screen.get_node(page).visible = true
		if float(slide) > ProfileMenu.MENU:
			(screen.get_node("%Library") as BookSelect).enter()
		(screen as ProfileMenu).call("_show_page", float(slide))
	if not _arg("book").is_empty():
		MapSelection.book = _arg("book")
	if screen is ProfileMenu and _has_arg("library"):
		(screen as ProfileMenu).call("_open_library")
		var library := screen.get_node("%Library") as BookSelect
		var book := library.call("_book_of", MapSelection.book) as Book3D
		if book != null:
			library.call("_select", book.get_index())
	if screen is ProfileMenu and _has_arg("to-library"):
		get_tree().create_timer(0.5).timeout.connect(
				func(): (screen as ProfileMenu).call("_open_library"))
	if screen is ProfileMenu and _has_arg("to-menu"):
		get_tree().create_timer(0.5).timeout.connect(
				func(): (screen as ProfileMenu).call("_slide_to", ProfileMenu.MENU))
	if screen is ProfileMenu and (_has_arg("stats") or not _arg("stats").is_empty()):
		get_tree().create_timer(0.5).timeout.connect(
				func(): (screen.get_node("%StatsButton") as Button).pressed.emit())
		if _arg("stats") == "close":
			get_tree().create_timer(1.2).timeout.connect(func():
				var window := screen.get_node_or_null("StatsScreen")
				print("menu_lab: Fenster offen: ", window != null)
				if window != null:
					window.call("close")
				await get_tree().process_frame
				print("menu_lab: Fokus bei ", get_viewport().gui_get_focus_owner(),
						", Fenster noch da: ", is_instance_valid(window) and window.is_inside_tree()))
	if not (screen is ProfileMenu) and (_has_arg("stats") or not _arg("stats").is_empty()):
		var stats_button := screen.find_child("ProfileBadge", true, false) \
				.get_node("%StatsButton") as Button
		get_tree().create_timer(0.5).timeout.connect(func(): stats_button.pressed.emit())
	if _has_arg("spells"):
		var spell_button := screen.get_node("%SpellButton") as Button \
				if screen is ProfileMenu \
				else screen.find_child("ProfileBadge", true, false).get_node("%SpellButton") as Button
		get_tree().create_timer(0.5).timeout.connect(func(): spell_button.pressed.emit())
	if screen is ProfileMenu and _has_arg("updates"):
		_force_updates(screen)
		# Nach dem Menü verbunden, läuft also nach dessen Abzeichen: die echte Prüfung
		# beim Laden blendet die Knöpfe sonst wieder aus.
		UpdateService.changed.connect(_force_updates.bind(screen))
		ContentService.changed.connect(_force_updates.bind(screen))
	if screen is ProfileMenu and _has_arg("content"):
		get_tree().create_timer(0.5).timeout.connect(
				func(): (screen.get_node("%ContentButton") as Button).pressed.emit())
	if screen is ProfileMenu and (_has_arg("settings") or not _arg("settings").is_empty()):
		get_tree().create_timer(0.5).timeout.connect(func():
			(screen.get_node("%SettingsButton") as Button).pressed.emit()
			var tab := int(_arg("settings")) if not _arg("settings").is_empty() else 1
			var window := screen.get_node("SettingsMenu")
			(window.get_node("%Tabs").get_child(tab - 1) as Button).button_pressed = true)
	if _has_arg("handbook") or not _arg("handbook").is_empty():
		var target := _arg("handbook").split("#")
		get_tree().create_timer(0.5).timeout.connect(func():
			Handbook.open(target[0] if target[0] != "" else Handbook.INDEX,
					target[1] if target.size() > 1 else ""))
	_cycle = screen.find_child("SunCycle", true, false) as SunCycle
	if _cycle != null:
		if not _arg("hour").is_empty():
			_cycle.follow_clock = false
			_cycle.phase = SunCycle.phase_of(float(_arg("hour")))
			_cycle.apply()
		if not _arg("timelapse").is_empty():
			_timelapse = maxf(float(_arg("timelapse")), 0.0)
			_cycle.follow_clock = false
	_clock.visible = _cycle != null and not _has_arg("shoot")
	if _has_arg("shoot"):
		_shoot.call_deferred()


func _process(delta: float) -> void:
	if _cycle == null:
		return
	if _timelapse > 0.0:
		# Nach der Uhr ein Tag je Stunde (SunCycle.clock_phase); hier n-mal so schnell.
		var step := delta * _timelapse * SunCycle.DAY_SPEED / 86400.0
		_cycle.advance(fposmod(_cycle.phase + step, 1.0))
	var hour := SunCycle.hour_of(_cycle.phase)
	var mode := "nach der Uhr" if _cycle.follow_clock \
			else ("Zeitraffer ×%s" % String.num(_timelapse) if _timelapse > 0.0 else "fest")
	_clock_text.text = "%02d:%02d · %s" % [int(hour), int(fmod(hour, 1.0) * 60.0), mode]


## Beide Update-Hinweise sichtbar, mit Beispieltext — nur das Bild, ohne echtes Update.
func _force_updates(screen: Node) -> void:
	var update := screen.get_node("%UpdateButton") as Button
	update.text = "⬆ Update auf 9.9.9"
	update.visible = true
	var content := screen.get_node("%ContentUpdateButton") as Button
	content.text = ProfileMenu.content_update_text(2)
	content.visible = true


func _shoot() -> void:
	await get_tree().create_timer(SETTLE).timeout
	if _has_arg("badge-hint"):
		var medallion := get_tree().root.find_child("Medallion", true, false) as Control
		if medallion != null:
			Hints.probe(medallion)
	if not _arg("hint").is_empty():
		var target := get_tree().root.find_child(_arg("hint"), true, false) as Control
		if target != null:
			Hints.probe(target)
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path(SHOT_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	var img := get_viewport().get_texture().get_image()
	var what := "backdrop" if _has_arg("backdrop") else ("intro" if _has_arg("intro") else "menu")
	if _has_arg("library"):
		what = "library"
	if not _arg("map").is_empty():
		what = "map_" + _arg("map")
	if _has_arg("to-library"):
		what += "_to_library"
	if _has_arg("to-menu"):
		what += "_to_menu"
	if not _arg("slide").is_empty():
		what += "_slide" + _arg("slide")
	if _has_arg("stats") or not _arg("stats").is_empty():
		what += "_stats" + ("_closed" if _arg("stats") == "close" else "")
	if _has_arg("badge-hint"):
		what += "_badge_hint"
	if not _arg("hint").is_empty():
		what += "_hint_" + _arg("hint")
	if _has_arg("handbook") or not _arg("handbook").is_empty():
		what += "_handbook" + ("_" + _arg("handbook").get_slice(".", 0).left(2) \
				if not _arg("handbook").is_empty() else "")
	if not _arg("hour").is_empty():
		what += "_h" + _arg("hour")
	if _has_arg("content"):
		what += "_content"
	if _has_arg("spells"):
		what += "_spells"
	if _has_arg("updates"):
		what += "_updates"
	if _has_arg("settings") or not _arg("settings").is_empty():
		what += "_settings" + _arg("settings")
	var file := "%s/%s_%dx%d.png" % [dir, what,
			img.get_width(), img.get_height()]
	img.save_png(file)
	print("menu_lab: ", file)
	get_tree().quit()


func _has_arg(arg_name: String) -> bool:
	return OS.get_cmdline_user_args().has("--" + arg_name)


func _arg(arg_name: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % arg_name):
			return a.get_slice("=", 1)
	return ""
