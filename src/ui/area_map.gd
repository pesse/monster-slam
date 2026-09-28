class_name AreaMap
extends Control
## Gebietskarte: die Level einer Unit — T1 … T4, Gesamt, Boss (ADR 0006, MapLevel).
##
## Jeder Ort zeigt die Stufe 0..4 seines Levels aus der Meisterung (FortressTier), der Boss
## seine Medaille aus den gezählten Siegen (BossRecord). Alle Level sind frei wählbar; nur
## ein Boss ohne Sätze ist gesperrt und sagt warum. Ein Klick setzt das Level in
## RunRequest und startet den Kampf — der kommt über RunRequest.return_scene hierher zurück.

const BATTLE_SCENE := "res://scenes/battle/battle.tscn"
const BOSS_SCENE := "res://scenes/battle/boss_fight.tscn"
const BossFight := preload("res://src/battle/boss_fight.gd")

@onready var _canvas: MapCanvas = %Canvas
@onready var _title: Label = %Title
@onready var _book: Label = %Book
## Festungsanzeige und daneben der Schalter für die Ich-Sicht: blenden zusammen ein.
@onready var _fortress: Control = %BottomRight
@onready var _fortress_title: Label = %FortressTitle
@onready var _fortress_bar: ProgressBar = %FortressBar
@onready var _fortress_next: Label = %FortressNext

var _levels: Array = []


func _ready() -> void:
	(%BackButton as Button).pressed.connect(_back)
	_canvas.node_selected.connect(_on_level_selected)
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
		var layout := MapLayout.data(MapSelection.book)
		_canvas.zoom_back_to(MapLayout.area_points(layout, MapSelection.unit)
				.get(str(RunRequest.level().get("key", "")), Vector2.INF))
		await _canvas.zoom_finished
	_fill()
	_canvas.appear()
	create_tween().tween_property(_fortress, "modulate:a", 1.0, MapCanvas.APPEAR_TIME)


## Der Schalter für die Ich-Sicht (nur das Auge, links an der Festungsanzeige und so hoch
## wie sie) steht nur da, wenn der Späherblick gelernt ist (im Debug-Build immer,
## RunRequest.first_person_selectable) — vor dem ersten Bild entschieden, damit die Ecke
## nicht nachträglich wächst. Er gilt für die
## Wellenkämpfe; der Boss bleibt, wie er ist (RunRequest.first_person).
func _setup_first_person_toggle() -> void:
	var toggle := %FirstPersonToggle as Button
	toggle.visible = RunRequest.first_person_selectable()
	toggle.button_pressed = RunRequest.wants_first_person()
	toggle.toggled.connect(RunRequest.want_first_person)
	Hints.attach(toggle, "Ich-Sicht",
			"Du stehst selbst auf dem Feld: WASD zum Laufen, die Maus zum Umsehen, Enter öffnet die Eingabe.",
			"Getroffen wird nur ein Monster, das du gerade siehst. Der Boss bleibt, wie er ist.")


## Der Kopf weicht den Orten aus, bevor er zu sehen ist — die Größen stehen erst nach
## einem Frame Layout fest.
func _place_header() -> void:
	var header: Control = %Header
	header.modulate.a = 0.0
	await get_tree().process_frame
	_canvas.place_header(header, MapLayout.area_points(MapLayout.data(MapSelection.book),
			MapSelection.unit).values())
	header.modulate.a = 1.0


## Was vor dem Zoom dasteht: Bild und Überschrift, ohne Orte und Festung. Nichts davon
## rechnet.
func _show_image() -> void:
	_book.text = ContentRegistry.book_label(MapSelection.book)
	_title.text = "Unit %d" % MapSelection.unit
	_fortress.modulate.a = 0.0
	_canvas.setup(MapLayout.unit_texture(MapSelection.book, MapSelection.unit), [], [], hint_lines)


func _fill() -> void:
	var book := MapSelection.book
	var unit := MapSelection.unit
	_levels = MapLevel.levels_for(book, unit, ContentRegistry.parts_for(book, unit))
	var lexemes := ContentRegistry.lexemes.values()
	var mastered := PlayerProgress.mastered_lexemes()
	var units := FortressTier.unit_tiers(lexemes, mastered)
	var parts := FortressTier.part_tiers(lexemes, mastered, ContentRegistry.part_of)
	var fortress := fortress_state(units.get("%s/%d" % [book, unit], {}))
	_fortress_title.text = str(fortress["title"])
	_fortress_bar.value = float(fortress["share"])
	_fortress_next.text = str(fortress["next"])
	var wins := int(BossRecord.wins(UserSettings.active_profile()).get("%s/%d" % [book, unit], 0))
	var layout := MapLayout.data(book)
	_canvas.setup(MapLayout.unit_texture(book, unit),
			nodes_for(_levels, units, parts, wins, has_boss_sentences(book, unit),
				MapLayout.area_points(layout, unit)),
			MapLayout.area_path(layout, unit), hint_lines)


## Die Orte der Gebietskarte, einer je Level.
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


## Die Festung in der Ecke: sie gilt für die ganze Unit, in jedem ihrer Level dieselbe —
## deshalb steht sie dort und nicht an den Orten. `share` ist der Weg von der erreichten
## zur nächsten Stufe (0..1), auf der höchsten Stufe voll.
static func fortress_state(group: Dictionary) -> Dictionary:
	var done := int(group.get("done", 0))
	var total := int(group.get("total", 0))
	var tier := int(group.get("tier", 0))
	var title := "Festung · Stufe %d" % tier
	var next := FortressTier.next_threshold(done, total)
	if next.is_empty():
		return {"title": title, "next": "Höchste Stufe" if total > 0 else "", "share": 1.0 if total > 0 else 0.0}
	var needed := int(next["needed"])
	var from := 0
	if tier > 0:
		@warning_ignore("integer_division")
		from = (int(FortressTier.THRESHOLDS_PERCENT[tier - 1]) * total + 99) / 100
	var span := maxi(1, done + needed - from)
	return {
		"title": title,
		"next": "noch %d %s bis Stufe %d" % [needed, "Wort" if needed == 1 else "Wörter", int(next["tier"])],
		"share": clampf(float(done - from) / float(span), 0.0, 1.0),
	}


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


## Zurück zur Buchkarte, als Zoom heraus — die Umkehrung des Wegs herein.
func _back() -> void:
	if _canvas.is_zooming():
		return
	_canvas.zoom_out()
	await _canvas.zoom_finished
	MapSelection.zoom_out = true
	get_tree().change_scene_to_file(MapSelection.BOOK_SCENE)


func _on_level_selected(key: String) -> void:
	for level in _levels:
		if str(level["key"]) != key:
			continue
		if _canvas.is_zooming():
			return
		RunRequest.start_level(level)
		# Hinein ins Level, wie von der Buch- in die Gebietskarte; der Kampf setzt fort.
		_canvas.zoom_into(key)
		await _canvas.zoom_finished
		var boss := str(level["kind"]) == MapLevel.KIND_BOSS
		get_tree().change_scene_to_file(BOSS_SCENE if boss else BATTLE_SCENE)
		return
