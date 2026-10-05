extends Node3D
## Werkbank: wie das Skelett im Hauptmenü sein Schwert hält (scenes/dev/sword_lab.tscn).
##
## Die Kulisse (MenuBackdrop) steht still: kein Spaziergang, keine Kamerafahrt. Gespielt
## wird die gewählte Animation auf der Stelle, angehalten lässt sie sich mit dem Regler
## „Zeitpunkt" durchfahren. Oberarm und Handgelenk sind die Zusatzdrehungen beim Gehen
## (MenuBackdrop.WALK_ARM), der Griff die Lage des Schwerts in der Hand (SWORD_TURN, gilt
## auch im Stehen). „Werte kopieren" legt beide Konstanten in die Zwischenablage und
## schreibt sie in die Konsole — sie werden in menu_backdrop.gd übernommen, nicht hier.
##
##     GODOT_WINDOW=1 tools/godot.sh res://scenes/dev/sword_lab.tscn
##         Leertaste hält an, ←/→ wechselt den Blick, Mausrad oder +/− ändert den Abstand,
##         C kopiert, R setzt auf die Werte im Spiel zurück, Escape beendet.
##     … -- --shoot=<pfad.png>   speichert ein Bild und beendet sich.

const ANIMS := [["Gehen", &"move/Walking_A"], ["Stehen", &"general/Idle_A"],
		["Umschauen", &"general/Idle_B"]]
## Blickrichtung um das Skelett (Grad, 0 = von vorn, 90 = von seiner rechten Seite).
const VIEWS := [["Schräg rechts", 45.0], ["Vorn", 0.0], ["Rechts (Schwerthand)", 90.0],
		["Hinten", 180.0], ["Links", -90.0]]
## Ein Schritt am Mausrad oder mit +/− (m).
const DIST_STEP := 0.25
## Wohin die Kamera schaut, über den Füßen (m).
const LOOK_HEIGHT := 0.95
const CAMERA_HEIGHT := 1.1
## Schiebt das Bild seitlich, damit das Skelett rechts neben den Reglern steht (je m Abstand).
const SHIFT_PER_METRE := -0.22

@onready var _backdrop: MenuBackdrop = %Backdrop
@onready var _anim_select: OptionButton = %AnimSelect
@onready var _pause: CheckButton = %PauseToggle
@onready var _time: HSlider = %TimeSlider
@onready var _view_select: OptionButton = %ViewSelect
@onready var _dist: HSlider = %DistSlider
@onready var _dist_caption: Label = %DistCaption
@onready var _influence: HSlider = %InfluenceSlider
@onready var _output: Label = %Output

var _anim: AnimationPlayer
var _room: Window


func _ready() -> void:
	_room = get_window()
	LabRoom.enlarge(_room)
	# Die Kulisse soll stillstehen; ihr _ready hat Animationen, Schwert und Modifier schon
	# aufgebaut.
	_backdrop.set_process(false)
	_anim = _backdrop._anim
	_backdrop._walk_arm.influence = 1.0
	for a in ANIMS:
		_anim_select.add_item(a[0])
	for v in VIEWS:
		_view_select.add_item(v[0])
	_anim_select.item_selected.connect(func(_i: int) -> void: _play())
	_pause.toggled.connect(_on_pause)
	_time.value_changed.connect(func(_v: float) -> void: _seek())
	_view_select.item_selected.connect(func(_i: int) -> void: _place_camera())
	_dist.value_changed.connect(func(_v: float) -> void: _place_camera())
	_influence.value_changed.connect(func(_v: float) -> void: _apply())
	for spin in _spins():
		spin.value_changed.connect(func(_v: float) -> void: _apply())
	(%CopyButton as Button).pressed.connect(_copy)
	(%ResetButton as Button).pressed.connect(_reset)
	_reset()
	_play()
	_place_camera()
	var shot := _arg("shoot")
	if shot != "":
		_shoot.call_deferred(shot)


func _exit_tree() -> void:
	LabRoom.restore(_room)


func _process(_delta: float) -> void:
	if not _pause.button_pressed and _anim.current_animation_length > 0.0:
		_time.set_value_no_signal(_anim.current_animation_position / _anim.current_animation_length)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		match (event as InputEventMouseButton).button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_dist.value -= DIST_STEP
			MOUSE_BUTTON_WHEEL_DOWN:
				_dist.value += DIST_STEP
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match (event as InputEventKey).keycode:
		KEY_SPACE:
			_pause.button_pressed = not _pause.button_pressed
		KEY_LEFT, KEY_RIGHT:
			var step := 1 if (event as InputEventKey).keycode == KEY_RIGHT else -1
			_view_select.select(posmod(_view_select.selected + step, VIEWS.size()))
			_place_camera()
		KEY_PLUS, KEY_KP_ADD:
			_dist.value -= DIST_STEP
		KEY_MINUS, KEY_KP_SUBTRACT:
			_dist.value += DIST_STEP
		KEY_C:
			_copy()
		KEY_R:
			_reset()
		KEY_ESCAPE:
			get_tree().quit()
		_:
			return
	get_viewport().set_input_as_handled()


func _spins() -> Array[SpinBox]:
	var spins: Array[SpinBox] = []
	for key in ["Arm", "Wrist", "Grip"]:
		for axis in ["X", "Y", "Z"]:
			spins.append(get_node("%" + key + axis) as SpinBox)
	return spins


func _set_row(key: String, radians: Vector3) -> void:
	var deg := Vector3(rad_to_deg(radians.x), rad_to_deg(radians.y), rad_to_deg(radians.z))
	for i in 3:
		(get_node("%" + key + "XYZ"[i]) as SpinBox).set_value_no_signal(snappedf(deg[i], 0.1))


func _row(key: String) -> Vector3:
	var deg := Vector3.ZERO
	for i in 3:
		deg[i] = (get_node("%" + key + "XYZ"[i]) as SpinBox).value
	return deg * PI / 180.0


## Die Werte, die im Spiel stehen.
func _reset() -> void:
	_set_row("Arm", MenuBackdrop.WALK_ARM["upperarm.r"])
	_set_row("Wrist", MenuBackdrop.WALK_ARM["wrist.r"])
	_set_row("Grip", MenuBackdrop.SWORD_TURN)
	_apply()


func _apply() -> void:
	_backdrop._walk_arm.bends = {"upperarm.r": _row("Arm"), "wrist.r": _row("Wrist")}
	_backdrop._sword.rotation = _row("Grip")
	var walking := _anim.current_animation == ANIMS[0][1]
	_backdrop._walk_arm.influence = _influence.value if walking else 0.0
	_output.text = _constants()


func _play() -> void:
	_anim.play(ANIMS[_anim_select.selected][1], 0.0)
	if _pause.button_pressed:
		_anim.pause()
		_seek()
	_apply()


func _on_pause(on: bool) -> void:
	if on:
		_anim.pause()
	else:
		_anim.play()


func _seek() -> void:
	if _anim.current_animation_length > 0.0:
		_anim.seek(_time.value * _anim.current_animation_length, true)


func _place_camera() -> void:
	var monster := _backdrop._monster
	var yaw := deg_to_rad(float(VIEWS[_view_select.selected][1]))
	# Das Skelett schaut entlang +z seines Körpers; seine rechte Hand liegt bei -x.
	var offset := Vector3(-sin(yaw), 0.0, cos(yaw)) * _dist.value
	offset.y = CAMERA_HEIGHT
	var camera := _backdrop.camera()
	camera.global_position = monster.global_position + monster.global_basis * offset
	camera.look_at(monster.global_position + Vector3(0.0, LOOK_HEIGHT, 0.0))
	camera.h_offset = SHIFT_PER_METRE * _dist.value
	_dist_caption.text = "Abstand %.1f m (Mausrad, +/−)" % _dist.value


func _constants() -> String:
	return "const SWORD_TURN := %s\nconst WALK_ARM := {\"upperarm.r\": %s, \"wrist.r\": %s}" % [
		_vec(_row("Grip")), _vec(_row("Arm")), _vec(_row("Wrist"))]


func _vec(radians: Vector3) -> String:
	var parts: PackedStringArray = []
	for i in 3:
		var deg := snappedf(rad_to_deg(radians[i]), 0.1)
		parts.append("0.0" if is_zero_approx(deg) else "deg_to_rad(%s)" % _num(deg))
	return "Vector3(%s)" % ", ".join(parts)


func _num(value: float) -> String:
	var text := str(value)
	return text if "." in text else text + ".0"


func _copy() -> void:
	DisplayServer.clipboard_set(_constants())
	print(_constants())


func _shoot(path: String) -> void:
	for i in 10:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()


func _arg(arg_name: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + arg_name + "="):
			return a.substr(arg_name.length() + 3)
	return ""
