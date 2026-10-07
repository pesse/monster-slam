class_name AreaMap
extends Control
## Gebietskarte: die Level einer Unit — T1 … T4, Gesamt, Boni, Boss (ADR 0006, MapLevel).
##
## Jeder Ort zeigt die Stufe 0..4 seines Levels aus der Meisterung (FortressTier), der Boss
## seine Medaille aus den gezählten Siegen (BossRecord). Alle Level sind frei wählbar; nur
## ein Boss ohne Sätze ist gesperrt und sagt warum. Ein Klick markiert einen Ort
## (MapLevel.toggle): mehrere Teile und Boni zusammen, Gesamt und Boss allein. „Spielen" unten
## rechts setzt die Auswahl als ein Level in RunRequest (MapLevel.combine) und startet den
## Kampf — der kommt über RunRequest.return_scene hierher zurück.
##
## Ein begonnener Lauf des Buchs (RunSave, ADR 0020): liegt er in dieser Unit, sind seine
## Orte beim Öffnen markiert, und „Spielen" heißt „Fortsetzen", solange sie alle markiert
## sind — weitere Orte der Unit dürfen dazukommen, der Lauf wird erweitert
## (RunSave.continues). Fehlt einer, oder liegt die Auswahl in einer anderen Unit des Buchs,
## startet ein neuer Lauf und fragt vorher, denn der begonnene geht dabei verloren. Das „✕"
## daneben verwirft ihn, damit sich dieselbe Auswahl auch frisch spielen lässt. Ein Boss
## gehört zu keinem Lauf: er startet ohne Rückfrage, und der begonnene bleibt liegen.

const BATTLE_SCENE := "res://scenes/battle/battle.tscn"
const BOSS_SCENE := "res://scenes/battle/boss_fight.tscn"
const BossFight := preload("res://src/battle/boss_fight.gd")

@onready var _canvas: MapCanvas = %Canvas
@onready var _title: Label = %Title
@onready var _book: Label = %Book
## Ein Schild unten in der Mitte (Vorlage `assets/ui/fortress/`): links der Ort (Buch,
## Unit), dann der Weg zur nächsten Stufe, rechts das Medaillon mit der Festung, wie sie im
## Kampf steht (Bilder aus `src/dev/fortress_icons.gd`), und ihrer Stufe. Der Ort steht mit
## dem Bild da; Festung, Medaillon und unten rechts Ich-Sicht und „Spielen" blenden erst
## nach der Rechnung ein — ausgeblendet, nicht versteckt, damit das Schild seine Größe
## behält. Der Balken ist breiter als jede Zeile darunter, deshalb ändert auch der Text
## die Breite nicht.
@onready var _fortress: Control = %Fortress
@onready var _medal: Control = %Medal
@onready var _actions: Control = %BottomRight
@onready var _fortress_bar: ProgressBar = %FortressBar
@onready var _fortress_image: TextureRect = %FortressImage
@onready var _fortress_level: Label = %FortressLevel
@onready var _play: Button = %PlayButton
@onready var _discard_run: Button = %DiscardRunButton
@onready var _confirm: ConfirmDialog = %Confirm

var _levels: Array = []
## Die markierten Orte (Schlüssel aus MapLevel.levels_for), in Spielreihenfolge.
var _selected: Array = []
## Der begonnene Lauf dieses Buchs (RunSave), oder leer.
var _saved: Dictionary = {}
## Was die offene Rückfrage bei „Ja" tut.
var _on_confirmed: Callable
## Wurde beim Öffnen ein unspielbarer begonnener Lauf verworfen? (`_check_saved`)
var _pending_notice := false


func _ready() -> void:
	(%BackButton as Button).pressed.connect(_back)
	var badge := %ProfileBadge as ProfileBadge
	badge.switch_pressed.connect(MapSelection.to_profile_pick.bind(self))
	# Im Fähigkeitsbaum kann der Späherblick dazugekommen (oder verlernt) sein.
	badge.window_closed.connect(func():
			(%FirstPersonToggle as Button).visible = RunRequest.first_person_selectable())
	_canvas.node_selected.connect(_on_level_clicked)
	_play.pressed.connect(_start)
	_discard_run.pressed.connect(_ask_discard)
	_confirm.confirmed.connect(func() -> void:
		if _on_confirmed.is_valid():
			_on_confirmed.call())
	Hints.attach(_discard_run, "Begonnenen Lauf verwerfen",
			"Danach beginnt „Spielen“ auch mit denselben Orten einen neuen Lauf.")
	# Die Level sitzen klein auf den Plätzen des Bildes und wachsen unter dem Zeiger; das
	# Bild zeigt seinen Weg selbst, die Hinweiskarte sagt, was ein Ort ist.
	_canvas.node_radius = MapCanvas.AREA_NODE_RADIUS
	_canvas.hover_radius = MapCanvas.NODE_RADIUS
	_canvas.path_over_image = false
	_canvas.show_captions = false
	_canvas.cover = true
	# Aus dem Kampf zurück: dort steht, welche Unit gespielt wurde. Nur dann — das Level
	# bleibt nach dem Kampf in RunRequest stehen, und der Zoom aus der Buchkarte hat seine
	# Unit schon in MapSelection gesetzt.
	if MapSelection.zoom_out and RunRequest.is_level():
		MapSelection.book = str(RunRequest.level().get("book", MapSelection.book))
		MapSelection.unit = int(RunRequest.level().get("unit", MapSelection.unit))
	_show_image()
	_setup_first_person_toggle()
	# Nicht abgewartet: der Zoom soll nicht auf den Kopf warten.
	_place_header()
	# Erst der Zoom, dann die Rechnung: während das Bild heranfährt, rechnet nichts, und
	# erst danach springen die Orte auf und die Festung blendet ein.
	if MapSelection.zoom_in:
		MapSelection.zoom_in = false
		_canvas.zoom_from()
		await _canvas.zoom_finished
	elif MapSelection.zoom_out:
		# Aus dem Kampf zurück: die Karte kommt aus dem Level heraus, das gespielt wurde.
		MapSelection.zoom_out = false
		var points := MapLayout.area_points(MapLayout.data(MapSelection.book), MapSelection.unit)
		_canvas.zoom_back_to(MapCanvas.centroid(played_keys().map(
				func(k): return points.get(str(k), Vector2.INF))))
		await _canvas.zoom_finished
	_fill()
	_check_saved()
	_canvas.appear()
	for part: Control in [_fortress, _medal, _actions]:
		create_tween().tween_property(part, "modulate:a", 1.0, MapCanvas.APPEAR_TIME)


## Der Schalter für die Ich-Sicht (nur das Auge, links an der Festungsanzeige und so hoch
## wie sie) steht nur da, wenn der Späherblick gelernt ist (im Debug-Build immer,
## RunRequest.first_person_selectable) — vor dem ersten Bild entschieden, damit die Ecke
## nicht nachträglich wächst. Er gilt für die
## Wellenkämpfe; ist der Boss markiert, ist er gesperrt (RunRequest.first_person).
func _setup_first_person_toggle() -> void:
	var toggle := %FirstPersonToggle as Button
	toggle.visible = RunRequest.first_person_selectable()
	toggle.button_pressed = RunRequest.wants_first_person()
	toggle.toggled.connect(RunRequest.want_first_person)
	_lock_first_person(false)


## Sperrt den Schalter, solange der Boss markiert ist — der Bosskampf hat keine Ich-Sicht.
## Gesperrt, nicht versteckt: die Ecke behält ihre Größe.
func _lock_first_person(locked: bool) -> void:
	var toggle := %FirstPersonToggle as Button
	toggle.disabled = locked
	if locked:
		Hints.attach(toggle, "Ich-Sicht", "Im Bosskampf gibt es keine Ich-Sicht.")
	else:
		Hints.attach(toggle, "Ich-Sicht",
				"Du stehst selbst auf dem Feld: WASD zum Laufen, die Maus zum Umsehen, Enter öffnet die Eingabe.")


## Der Kopf weicht den Orten aus, bevor er zu sehen ist — die Größen stehen erst nach
## einem Frame Layout fest.
func _place_header() -> void:
	var header: Control = %Header
	header.modulate.a = 0.0
	await get_tree().process_frame
	# Der Weg zurück steht unten links neben dem Schild; nach oben nur, wenn dort ein Ort liegt.
	_canvas.place_header(header, MapLayout.area_points(MapLayout.data(MapSelection.book),
			MapSelection.unit).values(), true)
	header.modulate.a = 1.0


## Was vor dem Zoom dasteht: Bild und Überschrift, ohne Orte und Festung. Nichts davon
## rechnet.
func _show_image() -> void:
	_book.text = ContentRegistry.book_label(MapSelection.book)
	_title.text = BookNaming.unit_label(MapSelection.book, MapSelection.unit)
	for part: Control in [_fortress, _medal, _actions]:
		part.modulate.a = 0.0
	_canvas.setup(MapLayout.unit_texture(MapSelection.book, MapSelection.unit), [], [], hint_lines)
	var ambience := MapLayout.ambience(MapLayout.data(MapSelection.book), MapSelection.unit)
	_canvas.set_ambience(ambience, MapLayout.ambience_masks(MapSelection.book, MapSelection.unit, ambience))


func _fill() -> void:
	var book := MapSelection.book
	var unit := MapSelection.unit
	var layout := MapLayout.data(book)
	_levels = levels_of(book, unit, layout)
	var lexemes := ContentRegistry.lexemes.values()
	var mastered := PlayerProgress.mastered_lexemes()
	var drop := FortressTier.drop_of(SkillBook.bonuses())
	var units := FortressTier.unit_tiers(lexemes, mastered, drop)
	var parts := FortressTier.part_tiers(lexemes, mastered, ContentRegistry.part_of, drop)
	var fortress := fortress_state(units.get("%s/%d" % [book, unit], {}), drop)
	_fortress_bar.value = float(fortress["share"])
	(%Before as Label).text = str(fortress["before"])
	(%Count as Label).text = str(fortress["count"])
	(%After as Label).text = str(fortress["after"])
	_fortress_level.text = str(fortress["tier"])
	_fortress_image.texture = fortress_image(int(fortress["tier"]))
	var wins := int(BossRecord.wins(UserSettings.active_profile()).get("%s/%d" % [book, unit], 0))
	var nodes := nodes_for(_levels, units, parts, wins, has_boss_sentences(book, unit),
			MapLayout.area_points(layout, unit), bonus_counts(ContentRegistry.bonuses_of(book, unit)))
	_canvas.setup(MapLayout.unit_texture(book, unit), nodes, MapLayout.area_path(layout, unit),
			hint_lines)
	_load_saved()
	_select(_initial_selection(nodes))


## Was markiert ist, wenn die Karte aufgeht: die Auswahl des letzten Laufs, wenn er in
## dieser Unit war — so spielt „Spielen" nach dem Kampf dasselbe noch einmal. Sonst nichts.
func _initial_selection(nodes: Array) -> Array:
	var saved := _saved_keys()
	if not saved.is_empty():
		return saved
	if not RunRequest.is_level():
		return []
	var last := RunRequest.level()
	if str(last.get("book", "")) != MapSelection.book or int(last.get("unit", 0)) != MapSelection.unit:
		return []
	var open := {}
	for node in nodes:
		if not bool(node.get("disabled", false)):
			open[str(node["key"])] = true
	return played_keys().filter(func(k): return open.has(str(k)))


## Die Orte, die der letzte Lauf gespielt hat (MapLevel.combine: `keys`, ältere nur `key`).
static func played_keys() -> Array:
	var last := RunRequest.level()
	if last.has("keys"):
		return Array(last["keys"])
	var key := str(last.get("key", ""))
	return [] if key.is_empty() else [key]


## Die Level der Unit samt ihren Boni, die ihren Titel aus der Karte haben (BonusLevel.title).
static func levels_of(book: String, unit: int, layout: Dictionary) -> Array:
	var bonuses: Array = []
	for bonus in ContentRegistry.bonuses_of(book, unit):
		var named: Dictionary = bonus.duplicate()
		named["title"] = BonusLevel.title(bonus, layout)
		bonuses.append(named)
	return MapLevel.levels_for(book, unit, part_count(book, unit, layout), bonuses)


## Stand je Bonus: Scope-Schlüssel -> { done, total } (BonusLevel.counts) aus dem Lernstand.
static func bonus_counts(bonuses: Array) -> Dictionary:
	var out := {}
	for bonus in bonuses:
		out[str(bonus["key"])] = BonusLevel.counts(bonus, PlayerProgress.is_mastered)
	return out


## Wie viele Teil-Level die Unit zeigt: so viele, wie der Inhalt hat, oder — wenn die Karte
## mehr Stationen hat — so viele wie die Karte. Die leeren stehen dann gesperrt da.
static func part_count(book: String, unit: int, layout: Dictionary) -> int:
	var parts := ContentRegistry.parts_for(book, unit)
	if parts <= 0:
		return 0
	return maxi(parts, MapLayout.area_parts(layout, unit))


## Die Orte der Gebietskarte, einer je Level. Ein Teil ohne Wörter ist gesperrt.
## `bonuses` ist der Stand je Bonus (bonus_counts).
static func nodes_for(levels: Array, units: Dictionary, parts: Dictionary, wins: int,
		boss_ready: bool, points: Dictionary, bonuses: Dictionary = {}) -> Array:
	var out: Array = []
	for level in levels:
		var kind := str(level["kind"])
		var counts := MapLevel.counts_of(level, units, parts, bonuses)
		var node := {
			"key": str(level["key"]), "kind": kind, "unit": int(level["unit"]),
			"unit_label": BookNaming.unit_label(str(level["book"]), int(level["unit"])),
			"pos": points.get(str(level["key"]), Vector2.INF),
			"caption": str(level["label"]),
			"tier": MapLevel.tier_of(level, units, parts),
			"done": int(counts["done"]), "total": int(counts["total"]),
		}
		match kind:
			MapLevel.KIND_PART:
				node["glyph"] = BookNaming.part_glyph(str(level["book"]), int(level["unit"]),
						int(level["part"]))
				if int(counts["total"]) == 0:
					node["disabled"] = true
			MapLevel.KIND_ALL:
				node["glyph"] = "★"
			MapLevel.KIND_BONUS:
				node["glyph"] = "+"
				node["caption"] = "Bonus"
				node["title"] = str(level["label"])
			MapLevel.KIND_BOSS:
				node["glyph"] = "💀"
				node["boss"] = true
				node["wins"] = wins
				node["medal"] = BossRecord.medal(wins)
				node["disabled"] = not boss_ready
		out.append(node)
	return out


## Die Festung im Schild: sie gilt für die ganze Unit, in jedem ihrer Level dieselbe —
## deshalb steht sie dort und nicht an den Orten. `share` ist der Weg von der erreichten
## zur nächsten Stufe (0..1), auf der höchsten Stufe voll. Die Zeile unter dem Balken in
## drei Stücken, damit die Zahl golden stehen kann: „Noch" · `count` · „Wörter bis Stufe 2".
## `drop` wie bei FortressTier.unit_tiers, mit dem auch `group` gezählt ist.
static func fortress_state(group: Dictionary, drop: int = 0) -> Dictionary:
	var done := int(group.get("done", 0))
	var total := int(group.get("total", 0))
	var tier := int(group.get("tier", 0))
	var next := FortressTier.next_threshold(done, total, drop)
	if next.is_empty():
		return {"tier": tier, "before": "Höchste Stufe" if total > 0 else "", "count": "",
				"after": "", "share": 1.0 if total > 0 else 0.0}
	var needed := int(next["needed"])
	var from := 0
	if tier > 0:
		from = FortressTier.words_for(tier, total, drop)
	var span := maxi(1, done + needed - from)
	return {
		"tier": tier,
		"before": "Noch",
		"count": str(needed),
		"after": "%s bis Stufe %d" % ["Wort" if needed == 1 else "Wörter", int(next["tier"])],
		"share": clampf(float(done - from) / float(span), 0.0, 1.0),
	}


## Das Bild der Festung einer Stufe (72 px, so groß wie im Medaillon); über der höchsten die
## höchste.
static func fortress_image(tier: int) -> Texture2D:
	return load("res://assets/ui/fortress/tiers/tier_%d.webp" % clampi(tier, 0, FortressTier.THRESHOLDS_PERCENT.size())) as Texture2D


## Die Karte am Zeiger für ein Level.
static func hint_lines(node: Dictionary) -> Dictionary:
	var unit_label := str(node.get("unit_label", ""))
	var title := "%s · %s" % [unit_label, str(node.get("caption", ""))]
	if bool(node.get("boss", false)):
		if bool(node.get("disabled", false)):
			return {"title": title, "body": "Für %s gibt es noch keine Sätze." % unit_label}
		var wins := int(node.get("wins", 0))
		var medal := int(node.get("medal", 0))
		var body := "Der Satzmeister prüft ganze Sätze aus %s." % unit_label
		if wins == 0:
			body += "\nNoch nicht besiegt."
		else:
			body += "\n👑 %d× besiegt · %s" % [wins, BossRecord.MEDAL_NAMES[medal]]
			if medal < BossRecord.MEDAL_WINS.size():
				body += " (%s ab %d Siegen)" % [BossRecord.MEDAL_NAMES[medal + 1],
						int(BossRecord.MEDAL_WINS[medal])]
		return {"title": title, "body": body}
	var done := int(node.get("done", 0))
	var total := int(node.get("total", 0))
	if str(node.get("kind", "")) == MapLevel.KIND_BONUS:
		var body := "%d von %d Aufgaben gemeistert" % [done, total]
		body += "\nAlles gemeistert ✨" if done >= total else "\nZählt nicht zur Festung."
		return {"title": "%s · Bonus: %s" % [unit_label, str(node.get("title", ""))], "body": body}
	if bool(node.get("disabled", false)):
		return {"title": title, "body": "Für %s gibt es noch keine Wörter." % str(node.get("caption", ""))}
	var body := ""
	if str(node.get("kind", "")) == MapLevel.KIND_ALL:
		# Gesamt ist die ganze Unit, ihre Stufe steht oben im Kopf.
		body = "Alle Wörter aus %s · %d von %d gemeistert" % [unit_label, done, total]
	else:
		# Der Ring ist der Meisterungsstand, nicht die Festungsstufe (MapCanvas.RING_GOLD).
		var missing := total - done
		body = "%d von %d Wörtern gemeistert" % [done, total]
		body += "\nAlles gemeistert ✨" if missing <= 0 else "\nNoch %d %s bis zum goldenen Ring" % [
				missing, "Wort" if missing == 1 else "Wörter"]
	return {"title": title, "body": body}


## Gibt die Unit dem Satzmeister mindestens einen Satz?
static func has_boss_sentences(book: String, unit: int) -> bool:
	var boss := ContentRegistry.get_entry("bosses", BossFight.BOSS_ID)
	if boss.is_empty():
		return false
	var base := SentenceSelector.pool_for_scope(["%s/%d" % [book, unit]], [])
	return not SentenceSelector.new().candidates(SentenceSelector.pool_for_boss(boss, 0, base)).is_empty()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_back()
	elif event.is_action_pressed("ui_accept") and not _play.disabled:
		get_viewport().set_input_as_handled()
		_start()


## Zurück zur Buchkarte, als Zoom heraus — die Umkehrung des Wegs herein.
func _back() -> void:
	if _canvas.is_zooming():
		return
	_canvas.zoom_out()
	await _canvas.zoom_finished
	MapSelection.zoom_out = true
	get_tree().change_scene_to_file(MapSelection.BOOK_SCENE)


func _on_level_clicked(key: String) -> void:
	if _canvas.is_zooming():
		return
	_select(MapLevel.toggle(_levels, _selected, key))


## Markiert `keys` auf der Karte und stellt „Spielen" danach: gesperrt ohne Auswahl, die
## Karte am Knopf sagt, was gespielt wird. Der Knopf bleibt dabei stehen, wie er ist.
func _select(keys: Array) -> void:
	_selected = keys
	_canvas.set_selected(keys)
	var level := MapLevel.combine(_levels, keys)
	_play.disabled = level.is_empty()
	var boss := not level.is_empty() and str(level["kind"]) == MapLevel.KIND_BOSS
	_lock_first_person(boss)
	var resumes := _resumes(keys)
	_play.text = "Fortsetzen" if resumes else "Spielen"
	_discard_run.visible = resumes
	var note := ""
	if boss and not _saved.is_empty():
		note = "Dein begonnener Lauf (%s) bleibt liegen." % saved_label(_saved)
	elif not _saved.is_empty() and not resumes:
		note = "Begonnener Lauf: %s" % saved_label(_saved)
	if level.is_empty():
		Hints.attach(_play, "Spielen", "Wähle auf der Karte, was du spielen willst.",
				"Mehrere Teile und Boni lassen sich zusammen markieren; Gesamt und Boss stehen allein.")
	elif resumes:
		var added := _added_labels(keys)
		Hints.attach(_play, "Fortsetzen", "Der begonnene Lauf geht weiter: %s." % saved_label(_saved),
				"" if added.is_empty() else "Neu dabei: %s" % ", ".join(added))
	else:
		Hints.attach(_play, "Spielen", "%s · %s" % [
				BookNaming.unit_label(MapSelection.book, MapSelection.unit), str(level["label"])],
				note)


## Setzt „Spielen" mit dieser Auswahl den begonnenen Lauf fort — mit denselben Orten oder
## erweitert um weitere?
func _resumes(keys: Array) -> bool:
	return RunSave.continues(_saved, MapSelection.unit, keys, _levels)


## Die Namen der Orte, um die die Auswahl den begonnenen Lauf erweitert.
func _added_labels(keys: Array) -> Array:
	var added := RunSave.added(_saved, keys, _levels)
	return _levels.filter(func(l): return str(l["key"]) in added) \
			.map(func(l): return str(l["label"]))


## Die gespeicherten Orte, wenn der begonnene Lauf in dieser Unit liegt.
func _saved_keys() -> Array:
	if _saved.is_empty() or int((_saved["level"] as Dictionary).get("unit", 0)) != MapSelection.unit:
		return []
	return Array((_saved["level"] as Dictionary).get("keys", []))


## „Unit 4, Welle 23" — wo der begonnene Lauf steht.
static func saved_label(state: Dictionary) -> String:
	var level: Dictionary = state.get("level", {})
	return "%s, Welle %d" % [BookNaming.unit_label(str(level.get("book", "")),
			int(level.get("unit", 0))), int(state.get("next_wave", 1))]


## Liest den begonnenen Lauf des Buchs, bevor die Orte markiert werden. Liegt er in dieser
## Unit und lässt sich nicht mehr spielen (ein Ort ist weg, die App zu alt), wird er
## verworfen, und die Karte sagt es — still verschwinden darf er nicht.
func _load_saved() -> void:
	_saved = RunSave.of_book(MapSelection.book, UserSettings.active_profile())
	if _saved_keys().is_empty() or not RunSave.resumable_level(_saved, _levels).is_empty():
		return
	RunSave.discard(MapSelection.book, UserSettings.active_profile())
	_saved = {}
	_pending_notice = true


## Sagt, dass ein begonnener Lauf verworfen wurde (`_load_saved`) — erst, wenn die Karte
## steht.
func _check_saved() -> void:
	if not _pending_notice:
		return
	_pending_notice = false
	_on_confirmed = Callable()
	_confirm.inform("Lauf verworfen",
			"Dein begonnener Lauf in dieser Unit lässt sich nicht mehr fortsetzen: die Inhalte "
			+ "haben sich geändert. Der nächste Lauf beginnt neu.")


func _ask_discard() -> void:
	if _saved.is_empty():
		return
	_on_confirmed = func() -> void:
		RunSave.discard(MapSelection.book, UserSettings.active_profile())
		_saved = {}
		_select(_selected)
	_confirm.ask("Lauf verwerfen?",
			"Dein begonnener Lauf (%s) geht verloren." % saved_label(_saved),
			"Verwerfen", "Behalten")


func _start() -> void:
	var level := MapLevel.combine(_levels, _selected)
	if level.is_empty() or _canvas.is_zooming() or _confirm.visible:
		return
	if str(level["kind"]) == MapLevel.KIND_BOSS:
		_launch(level)
	elif _resumes(_selected):
		var resume := _saved.duplicate(true)
		resume["added"] = RunSave.added(_saved, _selected, _levels)
		_launch(level, resume)
	elif not _saved.is_empty():
		_on_confirmed = func() -> void:
			RunSave.discard(MapSelection.book, UserSettings.active_profile())
			_saved = {}
			_launch(level)
		_confirm.ask("Neuer Lauf?",
				"Dies startet einen neuen Lauf. Dein begonnener Lauf (%s) geht verloren."
				% saved_label(_saved), "Neuer Lauf", "Zurück")
	else:
		_launch(level)


## Startet den Kampf mit `level`; `resume` ist der begonnene Lauf, den er fortsetzt.
func _launch(level: Dictionary, resume: Dictionary = {}) -> void:
	if level.is_empty():
		return
	RunRequest.start_level(level, resume)
	# Hinein ins Level, wie von der Buch- in die Gebietskarte; der Kampf setzt fort.
	_play.disabled = true
	_canvas.zoom_into_all(level["keys"])
	_fade_out_hud()
	await _canvas.zoom_finished
	await _present_dark()
	var boss := str(level["kind"]) == MapLevel.KIND_BOSS
	get_tree().change_scene_to_file(BOSS_SCENE if boss else BATTLE_SCENE)


## Kopfleiste und Schatten gehen mit der Karte ins Dunkel: der Kampf lädt und wärmt danach
## vor (FxWarmup), und so lange steht das letzte gezeichnete Bild — das muss ganz dunkel
## sein, nicht eine halb ausgeblendete Karte mit Kopfleiste.
func _fade_out_hud() -> void:
	var tw := create_tween().set_parallel(true)
	for node: CanvasItem in [$Hud, $Shade]:
		tw.tween_property(node, "modulate:a", 0.0, MapCanvas.ZOOM_IN_TIME) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)


## Wartet, bis das dunkle Bild wirklich gezeichnet ist. `change_scene_to_file` lädt sofort,
## noch im selben Frame — ohne das stünde während des Ladens das vorletzte Bild des Zooms.
func _present_dark() -> void:
	for node: CanvasItem in [$Hud, $Shade]:
		node.modulate.a = 0.0
	await get_tree().process_frame
	await get_tree().process_frame
