extends Control
## Standalone visual component. The game connects signals and supplies profile data.
signal profile_switch_requested

@export var player_name: String = "Sam"
@export_range(0, 999999) var gold: int = 999999
@export_range(1, 99) var level: int = 99
@export var xp: int = 166
@export var xp_required: int = 400

const FRAME = preload("res://assets/ui/player_badge/frame.webp")
const LEVEL = preload("res://assets/ui/player_badge/level_overlay.webp")
const AVATAR = preload("res://assets/ui/main_menu/icons/profile.webp")
const SWITCH = preload("res://assets/ui/main_menu/icons/switch_profile.webp")
const DESIGN = Vector2(1536, 1024)
var switch_hover := false

func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_exited.connect(func(): switch_hover = false; queue_redraw())
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)

func set_profile(display_name: String, current_level: int, current_gold: int, current_xp: int, required_xp: int) -> void:
	player_name = display_name
	level = current_level
	gold = current_gold
	xp = current_xp
	xp_required = required_xp
	queue_redraw()

func _scale_factor() -> float:
	return minf(size.x / DESIGN.x, size.y / DESIGN.y)

func _draw() -> void:
	var s := _scale_factor()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))
	draw_texture(FRAME, Vector2.ZERO)
	var ratio := clampf(float(xp) / maxf(1.0, xp_required), 0.0, 1.0)
	if ratio > 0.0:
		draw_arc(Vector2(1133, 480), 278, -PI / 2.0 - TAU * ratio, -PI / 2.0, 160, Color("43bafa"), 34, true)
	draw_texture_rect(AVATAR, Rect2(932, 284, 400, 400), false)
	# Re-cover the arc/avatar at the level plaque, preserving foreground layering.
	draw_texture(LEVEL, Vector2(1010, 650))
	draw_texture_rect(SWITCH, Rect2(106, 388, 150, 150), false)
	var font := ThemeDB.fallback_font
	var name_text := player_name
	while font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 72).x > 430 and name_text.length() > 1:
		name_text = name_text.left(name_text.length() - 2) + "…"
	draw_string(font, Vector2(340, 485), name_text, HORIZONTAL_ALIGNMENT_LEFT, 440, 72, Color("edf0fa"))
	var digits := str(gold)
	var formatted := ""
	for i in range(digits.length()):
		if i > 0 and (digits.length() - i) % 3 == 0:
			formatted += "."
		formatted += digits[i]
	draw_string(font, Vector2(335, 715), formatted, HORIZONTAL_ALIGNMENT_RIGHT, 440, 76, Color("f4cc68"))
	draw_string(font, Vector2(1040, 785), str(level), HORIZONTAL_ALIGNMENT_CENTER, 180, 100, Color("edf0fa"))
	if switch_hover or has_focus():
		draw_arc(Vector2(183, 460), 98, 0, TAU, 64, Color("f4cc68"), 4, true)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var p: Vector2 = event.position / _scale_factor()
		switch_hover = Rect2(50, 330, 270, 245).has_point(p)
		tooltip_text = "Profil wechseln" if switch_hover else "%d / %d XP" % [xp, xp_required]
		queue_redraw()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if Rect2(50, 330, 270, 245).has_point(event.position / _scale_factor()):
			profile_switch_requested.emit()
			accept_event()
	if event.is_action_pressed("ui_accept") and has_focus():
		profile_switch_requested.emit()
		accept_event()
