extends Node
## Werkbank für die Bühne des Schreib-Kampfs (scenes/dev/rambler_lab.tscn): The Rambler
## (RamblerStage) ohne Kampf, jede Methode der Bühne auf einer Taste und einem Knopf.
##
##     GODOT_WINDOW=1 tools/godot.sh res://scenes/dev/rambler_lab.tscn
##         F Fokus vorn/hinten, S reden, D/H den gewählten Stapel fallen lassen/halten,
##         1–9 lässt Stapel 1–9 fallen, Umschalt+1–9 lässt ihn halten, G freuen,
##         X besiegt, R neuer Kampf (mit der eingestellten Anzahl), W vorwärmen,
##         O legt eine Overlay-Probe über Mitte und rechte Hälfte, M zeigt, wo der Mund
##         im Bild ist (mouth_on_screen), Tab blendet die Knöpfe aus.
##     GODOT_WINDOW=1 tools/godot.sh res://scenes/dev/rambler_lab.tscn -- --shoot[=<dir>]
##         spielt die Zustände der Reihe nach durch (hinten sechs Bilder im Abstand von
##         2,5 s, um das Wandern zu sehen), speichert je ein Bild in 1152×648 als
##         <dir>/rambler_<schritt>.png (Vorgabe reports/rambler/) und beendet sich.
##
## Liegt unter scenes/dev/ und src/dev/ und ist damit im Export ausgeschlossen. Sie
## verbucht nichts und schreibt nichts ins Profil.

const SHOT_DIR := "res://reports/rambler"

@onready var _stage: RamblerStage = %Stage
@onready var _probe: Control = %Probe
@onready var _mouth: Control = %Mouth
@onready var _panel: Control = %Panel
@onready var _index: SpinBox = %IndexSpin
@onready var _count: SpinBox = %CountSpin
@onready var _focus_button: Button = %FocusButton

var _front := true


func _ready() -> void:
	_focus_button.pressed.connect(_toggle_focus)
	(%SpeakButton as Button).pressed.connect(_stage.speak)
	(%DropButton as Button).pressed.connect(func(): _stage.drop_stack(int(_index.value)))
	(%HoldButton as Button).pressed.connect(func(): _stage.hold_stack(int(_index.value)))
	(%GloatButton as Button).pressed.connect(_stage.gloat)
	(%FallButton as Button).pressed.connect(_stage.fall)
	(%RestoreButton as Button).pressed.connect(_restore)
	(%WarmButton as Button).pressed.connect(_stage.warm_up)
	(%ProbeButton as Button).toggled.connect(func(on: bool): _probe.visible = on)
	(%MouthButton as Button).toggled.connect(func(on: bool): _mouth.visible = on)
	(%HideButton as Button).pressed.connect(func(): _panel.visible = false)
	var shoot: Variant = _arg("shoot")
	if shoot != null:
		_shoot.call_deferred(str(shoot))


func _process(_delta: float) -> void:
	if _mouth.visible:
		var at := _stage.mouth_on_screen()
		if at.is_finite():
			_mouth.position = at - _mouth.size * 0.5


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode >= KEY_1 and key.keycode <= KEY_9:
		var index := key.keycode - KEY_1
		if key.shift_pressed:
			_stage.hold_stack(index)
		else:
			_stage.drop_stack(index)
		return
	match key.keycode:
		KEY_F: _toggle_focus()
		KEY_S: _stage.speak()
		KEY_D: _stage.drop_stack(int(_index.value))
		KEY_H: _stage.hold_stack(int(_index.value))
		KEY_G: _stage.gloat()
		KEY_X: _stage.fall()
		KEY_R: _restore()
		KEY_W: _stage.warm_up()
		KEY_O: (%ProbeButton as Button).button_pressed = not _probe.visible
		KEY_M: (%MouthButton as Button).button_pressed = not _mouth.visible
		KEY_TAB: _panel.visible = not _panel.visible


func _toggle_focus() -> void:
	_front = not _front
	_stage.set_focus(_front)
	_focus_button.text = "F  Fokus: %s" % ("vorn" if _front else "hinten")


func _restore() -> void:
	_stage.stack_count = int(_count.value)
	_stage.restore_all()


## Der Wert von `--name=wert` aus den Nutzerargumenten, "" bei `--name`, null ohne.
func _arg(arg_name: String) -> Variant:
	for a in OS.get_cmdline_user_args():
		if a == "--" + arg_name:
			return ""
		if a.begins_with("--%s=" % arg_name):
			return a.get_slice("=", 1)
	return null


func _shoot(dir_arg: String) -> void:
	get_window().size = Vector2i(1152, 648)
	_panel.visible = false
	var dir := ProjectSettings.globalize_path(SHOT_DIR) if dir_arg.is_empty() else dir_arg
	DirAccess.make_dir_recursive_absolute(dir)
	_stage.warm_up()
	await _wait(1.6)
	await _save(dir, "01_front_idle")
	_stage.speak()
	_mouth.visible = true
	await _wait(0.45)
	await _save(dir, "02_front_speak")
	_mouth.visible = false
	_toggle_focus()
	# Hinten wandert er: mehrere Bilder über die Zeit, die Kamera steht still.
	for i in 6:
		await _wait(2.5)
		await _save(dir, "03_back_wander_%d" % i)
	_probe.visible = true
	await _save(dir, "04_back_overlay")
	_probe.visible = false
	_toggle_focus()
	await _wait(1.6)
	_stage.drop_stack(1)
	await _wait(0.22)
	await _save(dir, "05_drop_falling")
	await _wait(1.6)
	await _save(dir, "06_drop_after")
	_stage.hold_stack(2)
	await _wait(0.12)
	await _save(dir, "07_hold")
	await _wait(0.6)
	_stage.gloat()
	await _wait(0.35)
	await _save(dir, "08_gloat")
	_stage.drop_stack(0)
	_stage.drop_stack(3)
	await _wait(2.5)
	await _save(dir, "09_three_dropped")
	_toggle_focus()
	await _wait(1.8)
	_probe.visible = true
	await _save(dir, "10_back_hurt_overlay")
	_probe.visible = false
	_toggle_focus()
	await _wait(1.3)
	_stage.fall()
	await _wait(2.5)
	await _save(dir, "11_fallen")
	_restore()
	await _wait(1.0)
	await _save(dir, "12_restored")
	get_tree().quit()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _save(dir: String, step: String) -> void:
	await RenderingServer.frame_post_draw
	var path := "%s/rambler_%s.png" % [dir, step]
	get_viewport().get_texture().get_image().save_png(path)
	print("rambler_lab: ", path)
