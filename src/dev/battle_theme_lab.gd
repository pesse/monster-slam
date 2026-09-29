extends Node3D
## Werkbank: das Schlachtfeld in jedem BattleTheme, ohne einen Kampf zu starten.
##
## Ein echter Kampf spielt im Entwicklungsprofil und schreibt Lernstand und Spur (siehe
## CLAUDE.md). Hier steht nur, was man SIEHT: Kamera und Boden aus denselben statischen
## Funktionen wie im WaveRunner, dazu Streudeko und die Burg zum Vergleich der Farben.
##
##     GODOT_WINDOW=1 tools/godot.sh res://scenes/dev/battle_theme_lab.tscn
##         ←/→ wechselt das Thema.
##     GODOT_WINDOW=1 tools/godot.sh res://scenes/dev/battle_theme_lab.tscn -- --shoot
##         speichert jedes Thema als reports/battle_themes/<name>.png und beendet sich.
##         --theme=<name> beschränkt auf ein Thema.
##     … -- --specimens
##         Nahaufnahme der Deko jedes Themas neben den gekauften Vergleichsstücken, in der
##         Größe ihres Platzes, als reports/battle_themes/specimens_<name>.png.
##     … -- --bow
##         Die Ich-Sicht mit dem Bogen: gesenkt, gespannt, ein Treffer und ein Fehlschuss im
##         Flug, als reports/battle_themes/bow_<schritt>.png.
##     … -- --hitches [--warm]
##         Misst den längsten Frame beim ERSTEN Auftritt jedes Kampfeffekts (Explosion,
##         „+XP", Monster, Meister-Feier) und gibt ihn in ms aus; --warm wärmt vorher vor
##         wie der Kampf (FxWarmup). Ein Lauf je Messung — ein zweiter Effekt im selben Lauf
##         wäre schon warm.
##     … -- --monsters [--tier=<0..4>]
##         Stellt Monster vor die Mauer — Größenvergleich mit der Festung (Vorgabe Vollausbau).
##     … -- --fps [--theme=<name>] [--windowed]
##         Misst im Vollbild und ohne VSync die mittlere Bildzeit mit allem an, jeweils ohne
##         eine Zutat (MSAA, Wolken, Teilchen, Wind, Schatten, Glow) und ohne alles — die
##         Grundlage für die Stufen in GraphicsQuality. Ein Thema je Lauf (das erste).
##
## Headless gibt es keinen Renderer — deshalb GODOT_WINDOW=1.

const WaveRunnerScript := preload("res://src/battle/wave_runner.gd")
const BATTLE_SCENE := "res://scenes/battle/battle.tscn"
const CELEBRATION_SCENE := preload("res://scenes/ui/mastery_celebration.tscn")
const SHOT_DIR := "res://reports/battle_themes"
## Fester Samen: dieselben Hügel und dieselbe Deko in jedem Thema, damit Bilder vergleichbar
## sind.
const SEED := 4711

## Skalierung je Deko-Platz, wie im WaveRunner (_decorate, _decorate_outskirts).
const SLOT_SCALE := {"trees": [0.8, 1.4], "rocks": [1.6, 3.2], "grass": [1.2, 2.0],
		"props": [1.0, 1.0], "landmarks": [0.8, 1.2]}
## Die gekauften Vergleichsstücke vor jeder Nahaufnahme, mit ihrem Platz.
const REFERENCE := [["props/tree.glb", "trees"], ["props/rock.glb", "rocks"],
		["props/pillar.gltf", "landmarks"]]

@onready var _pivot: Node3D = $CameraPivot
@onready var _camera: Camera3D = $CameraPivot/Camera3D
@onready var _sun: DirectionalLight3D = $Sun
@onready var _world: WorldEnvironment = $WorldEnvironment
@onready var _ground: MeshInstance3D = $Ground
@onready var _label: Label = $UI/Name

var _names: Array[String] = []
var _index := 0
var _decor: Node3D
var _scene_env: Environment
var _air: CPUParticles3D
var _wind_strength := 1.0
var _theme: BattleTheme
var _noise: FastNoiseLite


func _ready() -> void:
	_scene_env = _battle_environment()
	WaveRunnerScript.setup_view(_pivot, _camera, _sun)
	add_child(Wind.new())
	for file in DirAccess.get_files_at(BattleTheme.DIR):
		if file.ends_with(".tres"):
			_names.append(file.get_basename())
	_names.sort()
	var only := _arg("theme")
	if not only.is_empty():
		_names = _names.filter(func(n: String) -> bool: return n == only)
	if _names.is_empty():
		push_error("battle_theme_lab: kein Thema gefunden")
		get_tree().quit(1)
		return
	_show(0)
	if _has_arg("bow"):
		_shoot_bow.call_deferred()
	elif _has_arg("fps"):
		_measure_fps.call_deferred()
	elif _has_arg("hitches"):
		_measure_hitches.call_deferred()
	elif _has_arg("specimens"):
		_shoot_specimens.call_deferred()
	elif _has_arg("shoot"):
		_shoot_all.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_right"):
		_show((_index + 1) % _names.size())
	elif event.is_action_pressed("ui_left"):
		_show((_index - 1 + _names.size()) % _names.size())


func _show(index: int) -> void:
	_index = index
	var theme := BattleTheme.named(_names[index])
	_world.environment = _scene_env
	theme.apply(_world, _sun)
	var noise := WaveRunnerScript.terrain_noise(SEED)
	# Wie im Kampf für den weitesten Blick gebaut (SceneZoom kommt aus der Ferne) — sonst
	# ragt am unteren Rand der Hintergrund unter den Hügeln hervor.
	var view_size := _camera.size
	_camera.size = view_size / SceneZoom.FROM
	_ground.mesh = WaveRunnerScript.build_terrain(_camera, noise, theme)
	_camera.size = view_size
	WaveRunnerScript.dress_ground(_ground, theme)
	_wind_strength = theme.wind
	_theme = theme
	_noise = noise
	_build_decor(noise, theme)
	if _air != null:
		_air.free()
	_air = AmbientParticles.build(theme.particles, WaveRunnerScript.visible_ground_area(_camera))
	if _air != null:
		add_child(_air)
	_label.text = "%s  (%d/%d)" % [_names[index], index + 1, _names.size()]
	if not theme.ground_texture.is_empty():
		var missing := not ResourceLoader.exists(theme.ground_texture_path())
		_label.text += "  · %s%s" % [theme.ground_texture, " (fehlt)" if missing else ""]


func _shoot_all() -> void:
	var dir := ProjectSettings.globalize_path(SHOT_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	for i in _names.size():
		_show(i)
		# Zwei Bilder abwarten: das erste nach dem Umbau zeigt noch Schatten des alten.
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var path := "%s/%s.png" % [dir, _names[i]]
		get_viewport().get_texture().get_image().save_png(path)
		print("battle_theme_lab: ", path)
	get_tree().quit()


func _shoot_bow() -> void:
	var dir := ProjectSettings.globalize_path(SHOT_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	var view := (load("res://scenes/battle/first_person_view.tscn") as PackedScene).instantiate() as FirstPersonView
	view.position = Vector3(0.0, 0.0, WaveRunnerScript.GOAL_Z - 2.0)
	add_child(view)
	# Beide Waffen gelernt, damit die Eingabe auch Tab nennt; der Bogen ist gewählt.
	view.weapons = FirstPersonView.weapons_for({"bow": 1.0, "charge": 1.0})
	view.weapon = FirstPersonView.Weapon.BOW
	# Eine echte, gesperrte Eingabe: gehoben wird der Bogen nur, solange sie offen ist.
	var input := (load("res://scenes/ui/answer_input.tscn") as PackedScene).instantiate() as LineEdit
	$UI.add_child(input)
	input.set("gated", true)
	input.set("weapon_switch", true)
	view.answer_input = input
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	var monster := FxWarmup.MONSTER_SCENE.instantiate() as Monster
	monster.setup(FxWarmup.monster_defs()[0], {"prompt": "house"}, 1000.0, 0.0)
	monster.screen_sized_label = true
	monster.position = Vector3(2.0, 0.0, WaveRunnerScript.GOAL_Z - 16.0)
	add_child(monster)
	monster.halt()
	var target := monster.global_position + Vector3(0.0, 1.2, 0.0)
	var head := monster.global_position + Vector3(0.0, monster.head_height(), 0.0)
	print("battle_theme_lab: Kopfhöhe ", monster.head_height())
	var shot := func(step: String) -> void:
		await RenderingServer.frame_post_draw
		var path := "%s/bow_%s.png" % [dir, step]
		get_viewport().get_texture().get_image().save_png(path)
		print("battle_theme_lab: ", path)
		# Das Speichern dauert: ohne diese Bilder ginge die Zeit dafür im nächsten Schritt
		# als ein großes delta auf, und Schwenk oder Flug wären schon vorbei.
		await get_tree().process_frame
		await get_tree().process_frame
	# Wie im Kampf: sonst übersetzt die Spur ihren Shader erst im ersten Flug, und das Bild
	# stünde genau dann.
	var warm := Arrow.new()
	warm.trail = true
	var fx_at := view.camera.global_position - view.camera.global_basis.z * 6.0
	await FxWarmup.run(self, fx_at, [], [warm])
	await get_tree().create_timer(1.2).timeout
	await shot.call("lowered")
	input.call("_input", enter)
	for i in 5:
		await get_tree().create_timer(0.08).timeout
		EventBus.typing_activity.emit()
	await get_tree().create_timer(0.4).timeout
	await shot.call("drawn")
	# Ein Bild zu speichern dauert länger als ein Flug: Schwenk und Flug aus zwei Schüssen.
	view.shoot_at(head)
	input.text_submitted.emit("")
	await get_tree().create_timer(0.03).timeout
	await shot.call("swing")
	await get_tree().create_timer(0.8).timeout
	input.call("_input", enter)
	for i in 5:
		EventBus.typing_activity.emit()
	await get_tree().create_timer(0.4).timeout
	view.shoot_at(head)
	input.text_submitted.emit("")
	await get_tree().create_timer(0.12).timeout
	await shot.call("flight")
	await get_tree().create_timer(0.8).timeout
	input.call("_input", enter)
	EventBus.typing_activity.emit()
	await get_tree().create_timer(0.4).timeout
	view.shoot_past(target)
	input.text_submitted.emit("")
	await get_tree().create_timer(0.15).timeout
	await shot.call("miss")
	await get_tree().create_timer(0.6).timeout
	await shot.call("stuck")
	get_tree().quit()


## Zutaten, die --fps einzeln abschaltet, mit ihrem Namen in der Ausgabe.
const FPS_PARTS := {"msaa": "MSAA", "clouds": "Wolken", "particles": "Teilchen",
		"wind": "Wind", "shadows": "Schatten", "glow": "Glow"}


func _measure_fps() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	if not _has_arg("windowed"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	await get_tree().create_timer(1.0).timeout
	var all_on := {}
	for part: String in FPS_PARTS:
		all_on[part] = true
	var runs: Array = [["alles an", all_on]]
	for part: String in FPS_PARTS:
		var cfg := all_on.duplicate()
		cfg[part] = false
		runs.append(["ohne " + FPS_PARTS[part], cfg])
	var all_off := {}
	for part: String in FPS_PARTS:
		all_off[part] = false
	runs.append(["alles aus", all_off])
	print("fps: %s, %s" % [_names[_index], get_viewport().get_visible_rect().size])
	var base := 0.0
	for run: Array in runs:
		_apply_parts(run[1])
		var ms := await _mean_frame_ms(3.0)
		if base == 0.0:
			base = ms
		print("fps: %-14s %6.2f ms  %5.0f fps  %+5.1f %%" % [run[0], ms, 1000.0 / ms,
				(ms - base) / base * 100.0])
	get_tree().quit()


func _apply_parts(cfg: Dictionary) -> void:
	get_viewport().msaa_3d = Viewport.MSAA_4X if cfg.msaa else Viewport.MSAA_DISABLED
	(_ground.material_override as ShaderMaterial).set_shader_parameter("clouds",
			_theme.clouds if cfg.clouds else 0.0)
	if _air != null:
		_air.emitting = cfg.particles
		_air.visible = cfg.particles
	_wind_strength = _theme.wind if cfg.wind else 0.0
	_build_decor(_noise, _theme)
	_sun.shadow_enabled = cfg.shadows
	_world.environment.glow_enabled = cfg.glow


## Mittlere Bildzeit über `seconds`, nach einer Sekunde Anlauf (Shader, neue Deko).
func _mean_frame_ms(seconds: float) -> float:
	await get_tree().create_timer(1.0).timeout
	var frames := 0
	var t0 := Time.get_ticks_usec()
	while Time.get_ticks_usec() - t0 < seconds * 1000000.0:
		await get_tree().process_frame
		frames += 1
	return (Time.get_ticks_usec() - t0) / 1000.0 / maxi(frames, 1)


func _measure_hitches() -> void:
	var celebration := CELEBRATION_SCENE.instantiate() as MasteryCelebration
	$UI.add_child(celebration)
	var at := Vector3(0.0, 1.0, WaveRunnerScript.VIEW_CENTER_Z)
	var baseline := await _worst_frame(func() -> void: pass, 60)
	print("hitches: Grundrauschen %.1f ms" % baseline)
	if _has_arg("warm"):
		var t0 := Time.get_ticks_usec()
		celebration.warm_up()
		await FxWarmup.run(self, at, FxWarmup.monster_defs(),
				[WaveRunnerScript.xp_label(FxWarmup.GLYPHS), WaveRunnerScript.form_label(FxWarmup.GLYPHS)])
		celebration.cool_down()
		print("hitches: Vorwärmen %.1f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
		await _worst_frame(func() -> void: pass, 60)
	var effects := {
		"Explosion": func() -> void:
			var fx := Explosion.new()
			fx.setup(Color(0.7, 1.0, 0.4), 1.5)
			fx.position = at
			add_child(fx),
		"+XP": func() -> void:
			var label := WaveRunnerScript.xp_label("+12 XP")
			label.position = at + Vector3(4.0, 1.0, 0.0)
			add_child(label),
		"Monster": func() -> void:
			var monster := FxWarmup.MONSTER_SCENE.instantiate() as Monster
			monster.setup(FxWarmup.monster_defs()[0], {"prompt": "house"}, 1000.0, 0.0)
			monster.position = at + Vector3(-4.0, 0.0, 0.0)
			add_child(monster),
		"Wort-Feier": func() -> void:
			celebration.celebrate(MasteryCelebration.Kind.WORD, ""),
	}
	for effect_name: String in effects:
		print("hitches: %s %.1f ms" % [effect_name, await _worst_frame(effects[effect_name], 20)])
	get_tree().quit()


## Löst `effect` aus und gibt den längsten der folgenden `count` Frames in ms zurück.
func _worst_frame(effect: Callable, count: int) -> float:
	await get_tree().process_frame
	effect.call()
	var worst := 0.0
	var last := Time.get_ticks_usec()
	for i in count:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		worst = maxf(worst, (now - last) / 1000.0)
		last = now
	return worst


## Das Environment der Kampfszene — gelesen, nicht nachgebaut, damit die Werkbank nicht
## still von der Szene abweicht.
func _battle_environment() -> Environment:
	var state := (load(BATTLE_SCENE) as PackedScene).get_state()
	for i in state.get_node_count():
		if state.get_node_type(i) != &"WorldEnvironment":
			continue
		for p in state.get_node_property_count(i):
			if state.get_node_property_name(i, p) == &"environment":
				return state.get_node_property_value(i, p) as Environment
	return Environment.new()


## Deko wie im Kampf, vereinfacht: Bäume und Felsen im Umland und an den Seitenstreifen,
## Gras auf dem Feld, die Burg an der Front.
func _build_decor(noise: FastNoiseLite, theme: BattleTheme) -> void:
	if _decor != null:
		_decor.free()
	_decor = Node3D.new()
	add_child(_decor)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var area := WaveRunnerScript.visible_ground_area(_camera)
	var half_x: float = WaveRunnerScript.FIELD_HALF_X
	for i in 90:
		var x := rng.randf_range(area.position.x, area.end.x)
		var z := rng.randf_range(area.position.y, area.end.y)
		var on_field := absf(x) < half_x and z > WaveRunnerScript.FIELD_Z_BACK \
				and z < WaveRunnerScript.FIELD_Z_FRONT
		if on_field or not WaveRunnerScript.tile_on_screen(_camera, x, z):
			continue
		var slot := "landmarks" if i % 15 == 1 else "rocks" if i % 3 == 0 else "trees"
		_place_from(theme, slot, x, z, noise, rng)
	for i in 28:
		var x := rng.randf_range(-11.0, 11.0)
		var z := rng.randf_range(WaveRunnerScript.SPAWN_Z, WaveRunnerScript.GOAL_Z - 2.0)
		_place_from(theme, "grass" if i % 4 != 0 else "rocks", x, z, noise, rng)
	for i in 12:
		var x := (1.0 if i % 2 == 0 else -1.0) * rng.randf_range(9.5, 12.5)
		var z := rng.randf_range(WaveRunnerScript.SPAWN_Z, WaveRunnerScript.GOAL_Z - 2.0)
		_place_from(theme, "landmarks" if i == 5 else "props" if i % 4 == 0 else "trees", x, z, noise, rng)
	# Die Festung, wie sie im Kampf steht (FortressModel), im Vollausbau oder --tier=<0..4>.
	var tier := int(_arg("tier")) if not _arg("tier").is_empty() else 4
	FortressModel.build(_decor, tier, WaveRunnerScript.GOAL_Z,
			func(x: float, z: float) -> float: return WaveRunnerScript.terrain_height(x, z, noise))
	if _has_arg("monsters"):
		_place_monsters()


## Zum Größenvergleich: drei Monster kurz vor der Mauer und eines weiter vorn auf der Bahn.
func _place_monsters() -> void:
	var defs := FxWarmup.monster_defs()
	var spots := [Vector3(-4.0, 0.0, WaveRunnerScript.GOAL_Z - 1.5), Vector3(0.5, 0.0, WaveRunnerScript.GOAL_Z - 2.0),
			Vector3(4.5, 0.0, WaveRunnerScript.GOAL_Z - 1.5), Vector3(-1.0, 0.0, WaveRunnerScript.GOAL_Z - 10.0)]
	for i in spots.size():
		var monster := FxWarmup.MONSTER_SCENE.instantiate() as Monster
		monster.setup(defs[i % defs.size()], {"prompt": "house"}, 1000.0, 0.0)
		monster.position = spots[i]
		_decor.add_child(monster)
		monster.halt()


## Eines der Modelle des Platzes `slot` im Thema, in der Größe des Platzes.
func _place_from(theme: BattleTheme, slot: String, x: float, z: float, noise: FastNoiseLite,
		rng: RandomNumberGenerator) -> void:
	var models: Array[String] = theme.get(slot)
	if models.is_empty():
		return
	var model := models[rng.randi() % models.size()]
	var span: Array = SLOT_SCALE[slot]
	_place(model, x, z, noise, rng.randf_range(0.0, 360.0), rng.randf_range(span[0], span[1]))


## Nahaufnahme: die gekauften Vergleichsstücke und die Deko des Themas in einer Reihe, jedes
## in der mittleren Größe seines Platzes, auf flachem Boden, schräg von vorn wie im Kampf.
func _shoot_specimens() -> void:
	var dir := ProjectSettings.globalize_path(SHOT_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	for i in _names.size():
		_show(i)
		var theme := BattleTheme.named(_names[i])
		_decor.free()
		_decor = Node3D.new()
		add_child(_decor)
		var row: Array = REFERENCE.duplicate()
		for slot: String in SLOT_SCALE:
			for model: String in theme.get(slot):
				if not model.begins_with("props/") and not row.any(func(r: Array) -> bool: return r[0] == model):
					row.append([model, slot])
		# Die Reihe läuft entlang der Bildwaagerechten, mitten im flachen Feld.
		var center := Vector3(0.0, 0.0, -9.0)
		var right := _camera.global_transform.basis.x
		right = Vector3(right.x, 0.0, right.z).normalized()
		var spacing := 3.4
		var noise := WaveRunnerScript.terrain_noise(SEED)
		for k in row.size():
			var p := center + right * (spacing * (k - (row.size() - 1) * 0.5))
			var span: Array = SLOT_SCALE[row[k][1]]
			_place(row[k][0], p.x, p.z, noise, 20.0, (span[0] + span[1]) * 0.5)
		_pivot.position = center + Vector3(0.0, 1.5, 0.0)
		var view_size := _camera.size
		_camera.size = maxf(15.0, spacing * row.size() * 0.62)
		_label.text = "Vergleich: %s" % _names[i]
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var path := "%s/specimens_%s.png" % [dir, _names[i]]
		get_viewport().get_texture().get_image().save_png(path)
		print("battle_theme_lab: ", path)
		_camera.size = view_size
		_pivot.position = Vector3(0.0, 0.0, WaveRunnerScript.VIEW_CENTER_Z)
	get_tree().quit()


## `model` ist ein Pfad unter assets/models/, wie in BattleTheme.
func _place(model: String, x: float, z: float, noise: FastNoiseLite, yaw: float, scale: float) -> void:
	var path := "%s/%s" % [BattleTheme.MODEL_DIR, model]
	if not ResourceLoader.exists(path):
		return
	var inst := (load(path) as PackedScene).instantiate() as Node3D
	inst.position = Vector3(x, WaveRunnerScript.terrain_height(x, z, noise), z)
	inst.rotation_degrees.y = yaw
	inst.scale = Vector3.ONE * scale
	_decor.add_child(inst)
	Wind.sway(inst, model, _wind_strength)


func _has_arg(key: String) -> bool:
	return OS.get_cmdline_user_args().has("--" + key)


func _arg(key: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % key):
			return a.get_slice("=", 1)
	return ""
