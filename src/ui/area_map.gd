class_name AreaMap
extends Control
## Gebietskarte: die Level einer Unit — T1 … T4, Gesamt, Boss (ADR 0006, MapLevel).
##
## Jeder Ort zeigt die Stufe 0..4 seines Levels aus der Meisterung (FortressTier), der Boss
## seine Medaille aus den gezählten Siegen (BossRecord). Alle Level sind frei wählbar; nur
## ein Boss ohne Sätze ist gesperrt und sagt warum. Ein Klick markiert einen Ort
## (MapLevel.toggle): mehrere Teile zusammen, Gesamt und Boss allein. „Spielen" unten
## rechts setzt die Auswahl als ein Level in RunRequest (MapLevel.combine) und startet den
## Kampf — der kommt über RunRequest.return_scene hierher zurück.

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

var _levels: Array = []
## Die markierten Orte (Schlüssel aus MapLevel.levels_for), in Spielreihenfolge.
var _selected: Array = []


func _ready() -> void:
	(%BackButton as Button).pressed.connect(_back)
	_canvas.node_selected.connect(_on_level_clicked)
	_play.pressed.connect(_start)
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
	_title.text = "Unit %d" % MapSelection.unit
	for part: Control in [_fortress, _medal, _actions]:
		part.modulate.a = 0.0
	_canvas.setup(MapLayout.unit_texture(MapSelection.book, MapSelection.unit), [], [], hint_lines)


func _fill() -> void:
	var book := MapSelection.book
	var unit := MapSelection.unit
	var layout := MapLayout.data(book)
	_levels = MapLevel.levels_for(book, unit, part_count(book, unit, layout))
	var lexemes := ContentRegistry.lexemes.values()
	var mastered := PlayerProgress.mastered_lexemes()
	var units := FortressTier.unit_tiers(lexemes, mastered)
	var parts := FortressTier.part_tiers(lexemes, mastered, ContentRegistry.part_of)
	var fortress := fortress_state(units.get("%s/%d" % [book, unit], {}))
	_fortress_bar.value = float(fortress["share"])
	(%Before as Label).text = str(fortress["before"])
	(%Count as Label).text = str(fortress["count"])
	(%After as Label).text = str(fortress["after"])
	_fortress_level.text = str(fortress["tier"])
	_fortress_image.texture = fortress_image(int(fortress["tier"]))
	var wins := int(BossRecord.wins(UserSettings.active_profile()).get("%s/%d" % [book, unit], 0))
	var nodes := nodes_for(_levels, units, parts, wins, has_boss_sentences(book, unit),
			MapLayout.area_points(layout, unit))
	_canvas.setup(MapLayout.unit_texture(book, unit), nodes, MapLayout.area_path(layout, unit),
			hint_lines)
	_select(_initial_selection(nodes))


## Was markiert ist, wenn die Karte aufgeht: die Auswahl des letzten Laufs, wenn er in
## dieser Unit war — so spielt „Spielen" nach dem Kampf dasselbe noch einmal. Sonst nichts.
func _initial_selection(nodes: Array) -> Array:
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


## Wie viele Teil-Level die Unit zeigt: so viele, wie der Inhalt hat, oder — wenn die Karte
## mehr Stationen hat — so viele wie die Karte. Die leeren stehen dann gesperrt da.
static func part_count(book: String, unit: int, layout: Dictionary) -> int:
	var parts := ContentRegistry.parts_for(book, unit)
	if parts <= 0:
		return 0
	return maxi(parts, MapLayout.area_parts(layout, unit))


## Die Orte der Gebietskarte, einer je Level. Ein Teil ohne Wörter ist gesperrt.
static func nodes_for(levels: Array, units: Dictionary, parts: Dictionary, wins: int,
		boss_ready: bool, points: Dictionary) -> Array:
	var out: Array = []
	for level in levels:
		var kind := str(level["kind"])
		var counts := MapLevel.counts_of(level, units, parts)
		var node := {
			"key": str(level["key"]), "kind": kind, "unit": int(level["unit"]),
			"pos": points.get(str(level["key"]), Vector2.INF),
			"caption": str(level["label"]),
			"tier": MapLevel.tier_of(level, units, parts),
			"done": int(counts["done"]), "total": int(counts["total"]),
		}
		match kind:
			MapLevel.KIND_PART:
				node["glyph"] = str(int(level["part"]))
				if int(counts["total"]) == 0:
					node["disabled"] = true
					node["stars"] = false
			MapLevel.KIND_ALL:
				node["glyph"] = "★"
				node["stars"] = false
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
static func fortress_state(group: Dictionary) -> Dictionary:
	var done := int(group.get("done", 0))
	var total := int(group.get("total", 0))
	var tier := int(group.get("tier", 0))
	var next := FortressTier.next_threshold(done, total)
	if next.is_empty():
		return {"tier": tier, "before": "Höchste Stufe" if total > 0 else "", "count": "",
				"after": "", "share": 1.0 if total > 0 else 0.0}
	var needed := int(next["needed"])
	var from := 0
	if tier > 0:
		@warning_ignore("integer_division")
		from = (int(FortressTier.THRESHOLDS_PERCENT[tier - 1]) * total + 99) / 100
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
	var unit := int(node.get("unit", 0))
	var title := "Unit %d · %s" % [unit, str(node.get("caption", ""))]
	if bool(node.get("boss", false)):
		if bool(node.get("disabled", false)):
			return {"title": title, "body": "Für diese Unit gibt es noch keine Sätze."}
		var wins := int(node.get("wins", 0))
		var medal := int(node.get("medal", 0))
		var body := "Der Satzmeister prüft ganze Sätze aus dieser Unit."
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
	if bool(node.get("disabled", false)):
		return {"title": title, "body": "Für diesen Teil gibt es noch keine Wörter."}
	var body := ""
	if str(node.get("kind", "")) == MapLevel.KIND_ALL:
		# Gesamt hat keine Sterne: es ist die ganze Unit, ihre Stufe steht oben im Kopf.
		body = "Alle Wörter der Unit · %d von %d gemeistert" % [done, total]
	else:
		var next := FortressTier.next_threshold(done, total)
		var needed := int(next.get("needed", 0))
		body = "⭐ %d von %d Sternen · %d von %d Wörtern gemeistert" % [
				int(node.get("tier", 0)), FortressTier.MAX_TIER, done, total]
		body += "\nAlle Sterne." if next.is_empty() else "\nNoch %d %s bis zum %d. Stern" % [
				needed, "Wort" if needed == 1 else "Wörter", int(next["tier"])]
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
	_lock_first_person(not level.is_empty() and str(level["kind"]) == MapLevel.KIND_BOSS)
	if level.is_empty():
		Hints.attach(_play, "Spielen", "Wähle auf der Karte, was du spielen willst.",
				"Mehrere Teile lassen sich zusammen markieren; Gesamt und Boss stehen allein.")
	else:
		Hints.attach(_play, "Spielen", "Unit %d · %s" % [MapSelection.unit, str(level["label"])])


func _start() -> void:
	var level := MapLevel.combine(_levels, _selected)
	if level.is_empty() or _canvas.is_zooming():
		return
	RunRequest.start_level(level)
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
