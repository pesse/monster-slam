@tool
class_name ProfileBadge
extends Control
## Wer spielt, oben rechts in Menü, Bibliothek und Karten: Avatar im Ring, Erfahrung als
## Bogen, Levelplakette, Name und Gold. `compact` (im Editor justierbar, gespeichert wird
## immer 0) lässt nur den Ring mit einer Knopfreihe stehen. Maße in Pixeln der Paket-Leinwand
## (`layout.json`) mal `SCALE`, ab `ORIGIN`; die Bilder unter `player_badge/menu/` sind dafür
## vorverkleinert (`src/dev/shrink_image.gd`), bei neuem `SCALE` neu erzeugen.

signal switch_pressed
## Ein Fenster aus `open_window` ist zu — der Screen prüft, was es geändert haben kann.
signal window_closed

const SKILL_SCENE := "res://scenes/ui/skill_tree.tscn"
const STATS_SCENE := "res://scenes/ui/stats_screen.tscn"
const SHOP_SCENE := "res://scenes/ui/spell_shop.tscn"
## So weit rutschen die Knöpfe hinter dem Ring hervor (px).
const ACTIONS_SLIDE := 32.0

const FRAME := preload("res://assets/ui/player_badge/menu/frame.webp")
const CANVAS := Vector2(1536, 1024)
const SCALE := 0.2
## Linke obere Ecke der Silhouette auf der Leinwand (am Render gemessen; `visible_bounds`
## in layout.json schneiden die Levelplakette ab).
const ORIGIN := Vector2(50, 160)
const RING_CENTER := Vector2(1133, 480)
const RING_RADIUS := 278.0
const RING_WIDTH := 34.0
const RING_COLOR := Color("43bafa")
## Halbe Lücke unten (Bogenmaß, von der Senkrechten gemessen): dort sitzt die Levelplakette.
const RING_GAP := PI / 4.0
## Außenradius des Metallrings und Rahmen der Levelplakette: was kompakt stehen bleibt.
const RING_OUTER := 318.0
const RING_SEGMENTS := 96
const PLATE_BOX := Rect2(1014, 654, 240, 180)

@onready var _name_label: Label = %ProfileLabel
@onready var _gold_label: Label = %GoldLabel
@onready var _level_label: Label = %LevelLabel
@onready var _actions: Control = %Actions
## Was nur zur vollen Plakette gehört und kompakt ausblendet.
@onready var _full_only: Array[Control] = [%Plates, %ProfileLabel, %GoldLabel, %SwitchButton]

## 0 = wie im Hauptmenü, 1 = kompakt; dazwischen mitten in der Fahrt.
@export_range(0.0, 1.0) var compact := 0.0:
	set(value):
		compact = clampf(value, 0.0, 1.0)
		if is_node_ready():
			_show_compact()
## So groß steht die kompakte Plakette, zur rechten oberen Ecke hin.
@export_range(0.3, 1.0, 0.01) var compact_scale := 0.65:
	set(value):
		compact_scale = value
		if is_node_ready():
			_show_compact()

var _ratio := 0.0
var _window: Node
## `compact` mit Ein- und Auslauf, so wie es gezeichnet wird.
var _t := 0.0
## `compact` der Vorschau, solange der Editor die Szene speichert.
var _preview := 0.0


func _ready() -> void:
	# Skaliert zur rechten oberen Ecke hin.
	pivot_offset = Vector2(custom_minimum_size.x, 0.0)
	if Engine.is_editor_hint():
		# Im Editor nur die Form: Profil, Gold und Hinweise gibt es dort nicht.
		_show_compact()
		return
	for button: Control in [%SwitchButton, %CompactSwitchButton]:
		(button as BaseButton).pressed.connect(switch_pressed.emit)
		Hints.attach(button, "Profil wechseln", "zurück zu „Wer spielt?“")
	(%SkillsButton as BaseButton).pressed.connect(
			func(): open_window(SKILL_SCENE, %SkillsButton as Control))
	(%StatsButton as BaseButton).pressed.connect(
			func(): open_window(STATS_SCENE, %StatsButton as Control))
	(%SpellButton as BaseButton).pressed.connect(
			func(): open_window(SHOP_SCENE, %SpellButton as Control))
	Hints.attach(%SkillsButton as Control, "Fähigkeiten")
	Hints.attach(%StatsButton as Control, "Statistik")
	Hints.attach(%SpellButton as Control, "Zauber", "kaufen mit Gold")
	_show_compact()
	PlayerLevel.changed.connect(func(_total_xp, _level): refresh())
	Wallet.changed.connect(func(_gold): refresh())
	SkillBook.changed.connect(refresh)
	refresh()


## Die Editor-Vorschau nicht speichern: profile_badge.tscn trägt die volle Plakette.
func _notification(what: int) -> void:
	if not Engine.is_editor_hint() or not is_inside_tree() \
			or get_tree().edited_scene_root != self:
		return
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		_preview = compact
		compact = 0.0
	elif what == NOTIFICATION_EDITOR_POST_SAVE:
		compact = _preview


## Liest Name, Gold und Erfahrung des aktiven Profils neu — nach einem Profilwechsel.
func refresh() -> void:
	_name_label.text = UserSettings.display_name()
	_gold_label.text = Wallet.digits()
	var progress := PlayerLevel.progress()
	var in_level := int(progress["xp_in_level"])
	var for_up := int(progress["xp_for_level_up"])
	var level := int(progress["level"])
	_level_label.text = str(level)
	_ratio = clampf(float(in_level) / float(maxi(for_up, 1)), 0.0, 1.0)
	var title := "Level %d" % level
	var note := points_text(SkillBook.available(), SkillBook.unlimited_points)
	if compact >= 0.5:
		# Ohne Schilder nennt der Hinweis am Ring Name und Gold.
		title = "%s · %s" % [UserSettings.display_name(), title]
		note = "%s\n%s" % [note, Wallet.label()]
	Hints.attach(%Medallion as Control, title, "%d / %d XP bis Level %d" % [
			in_level, for_up, level + 1], note)
	Hints.attach(%Plates as Control, UserSettings.display_name(), "", Wallet.label())
	queue_redraw()


## Öffnet die Szene `path` als Fenster über dem Screen der Plakette; beim Schließen geht
## der Fokus an `opener` zurück.
func open_window(path: String, opener: Control) -> void:
	if _window != null:
		return
	var host: Node = owner if owner != null else get_tree().current_scene
	_window = (load(path) as PackedScene).instantiate()
	host.add_child(_window)
	_window.connect("closed", func() -> void:
		_window.queue_free()
		_window = null
		# Den Profilnamen meldet kein Signal.
		refresh()
		window_closed.emit()
		if opener.focus_mode != Control.FOCUS_NONE and opener.is_visible_in_tree():
			opener.grab_focus())


func has_window() -> bool:
	return _window != null


## Solange ein Fenster offen ist, kommt keine Taste beim Screen dahinter an.
func _unhandled_input(_event: InputEvent) -> void:
	if _window != null:
		get_viewport().set_input_as_handled()


func _show_compact() -> void:
	var was_compact := _t >= 0.5
	_t = compact * compact * (3.0 - 2.0 * compact)
	scale = Vector2.ONE * lerpf(1.0, compact_scale, _t)
	for part in _full_only:
		part.modulate.a = 1.0 - _t
		part.visible = _t < 1.0
	_actions.modulate.a = _t
	_actions.position.x = ACTIONS_SLIDE * (1.0 - _t)
	_actions.visible = _t > 0.0
	if was_compact != (_t >= 0.5) and not Engine.is_editor_hint():
		refresh()
	queue_redraw()


## Die offenen Skillpunkte (verdient minus ausgegeben) als Nachsatz.
static func points_text(points: int, unlimited := false) -> String:
	if unlimited:
		return "∞ Skillpunkte (Debug)"
	return "%d Skillpunkt%s offen" % [points, "" if points == 1 else "e"]


## Ein Punkt der Leinwand im Control.
static func at(canvas_point: Vector2) -> Vector2:
	return (canvas_point - ORIGIN) * SCALE


func _draw() -> void:
	# Ring und Levelplakette bleiben immer; der ganze Rahmen blendet kompakt aus.
	var texel := FRAME.get_size() / CANVAS
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	for i in RING_SEGMENTS:
		var p := RING_CENTER + Vector2.from_angle(TAU * i / RING_SEGMENTS) * RING_OUTER
		points.append(at(p))
		uvs.append(p / CANVAS)
	draw_polygon(points, PackedColorArray([Color.WHITE]), uvs, FRAME)
	draw_texture_rect_region(FRAME, Rect2(at(PLATE_BOX.position), PLATE_BOX.size * SCALE),
			Rect2(PLATE_BOX.position * texel, PLATE_BOX.size * texel))
	if _t < 1.0:
		draw_texture_rect(FRAME, Rect2(at(Vector2.ZERO), CANVAS * SCALE), false,
				Color(1, 1, 1, 1.0 - _t))
	if _ratio > 0.0:
		# Von unten links im Uhrzeigersinn, wie XpRing; PI / 2 ist unten.
		var start := PI / 2.0 + RING_GAP
		draw_arc(at(RING_CENTER), RING_RADIUS * SCALE, start,
				start + (TAU - 2.0 * RING_GAP) * _ratio, 96, RING_COLOR, RING_WIDTH * SCALE, true)
