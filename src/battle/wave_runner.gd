extends Node3D
## Fährt eine einzelne Welle in 3D: spawnt Monster aus der Wave-Definition, gleicht
## Spielerantworten gegen aktive Monster ab und erkennt das Wellenende.
## Nutzt ausschließlich bestehende Autoloads + AnswerEvaluator — rein additiv.

const MONSTER_SCENE := preload("res://scenes/entities/monster.tscn")
const GOAL_Z := 6.5           # Festungsfront (Monster-Ziel)
const SPAWN_Z := -11.0        # Spawn am hinteren Ende der Bahn
const LANE_HALF_WIDTH := 7.0
const FORTRESS_HIT := 10

const SHAKE_DURATION := 0.35
const SHAKE_MAGNITUDE := 0.35 # in 3D-Einheiten
const FLASH_CORRECT := Color(0.3, 1.0, 0.45)
const FLASH_WRONG := Color(1.0, 0.3, 0.3)

var _evaluator := AnswerEvaluator.new()
var _active: Array[Monster] = []
var _total: int = 0
var _spawned: int = 0
var _finished: bool = false

var _cam_base: Vector3
var _shake_left: float = 0.0

@onready var _monsters: Node3D = $Monsters
@onready var _camera: Camera3D = $CameraPivot/Camera3D
@onready var _end_label: Label = $UI/EndLabel
@onready var _flash: ColorRect = $UI/Flash


func _ready() -> void:
	_setup_view()
	_setup_ground()
	_decorate()
	_build_fortress()
	_cam_base = _camera.position
	GameState.reset()
	EventBus.answer_submitted.connect(_on_answer_submitted)
	start_wave("wave.tutorial_1")


## Prozedurales Low-Poly-Terrain: flaches Innenfeld (Spielfläche/Props/Festung),
## sanfte facettierte Hügel am Rand, dezente Grün-Variation je Facette. Flat-Shading
## über manuell gesetzte Face-Normalen — passt zum Stil von Burg/Skeletten.
const TERRAIN_HALF_X := 13.0
const TERRAIN_HALF_Z := 15.0
const TERRAIN_STEP := 3.0

var _terrain_noise: FastNoiseLite

func _setup_ground() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 1337
	noise.frequency = 0.06
	_terrain_noise = noise
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var x := -TERRAIN_HALF_X
	while x < TERRAIN_HALF_X - 0.001:
		var z := -TERRAIN_HALF_Z
		while z < TERRAIN_HALF_Z - 0.001:
			var a := _terrain_point(x, z, noise)
			var b := _terrain_point(x, z + TERRAIN_STEP, noise)
			var c := _terrain_point(x + TERRAIN_STEP, z + TERRAIN_STEP, noise)
			var d := _terrain_point(x + TERRAIN_STEP, z, noise)
			_add_terrain_tri(st, noise, a, b, c)
			_add_terrain_tri(st, noise, a, c, d)
			z += TERRAIN_STEP
		x += TERRAIN_STEP
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var ground := $Ground as MeshInstance3D
	ground.mesh = st.commit()
	ground.material_override = mat


func _terrain_point(x: float, z: float, noise: FastNoiseLite) -> Vector3:
	return Vector3(x, _terrain_height(x, z, noise), z)


func _terrain_height(x: float, z: float, noise: FastNoiseLite) -> float:
	# Innenfeld flach halten; nur außerhalb sanfte Hügel.
	var edge := maxf(absf(x) - 9.0, -z - 11.0)
	if edge <= 0.0:
		return 0.0
	var n := noise.get_noise_2d(x, z) * 0.5 + 0.5
	return clampf(edge, 0.0, 4.0) * (0.3 + 0.7 * n) * 0.6


func _add_terrain_tri(st: SurfaceTool, noise: FastNoiseLite, a: Vector3, b: Vector3, c: Vector3) -> void:
	var n := (b - a).cross(c - a).normalized()
	if n.y < 0.0:
		n = -n
	# EINE Farbe pro Dreieck (aus dem Zentrum) -> echte flache Low-Poly-Facetten.
	var col := _terrain_color((a + b + c) / 3.0, noise)
	for v in [a, b, c]:
		st.set_color(col)
		st.set_normal(n)
		st.add_vertex(v)


func _terrain_color(center: Vector3, noise: FastNoiseLite) -> Color:
	var t := noise.get_noise_2d(center.x * 2.3 + 100.0, center.z * 2.3) * 0.5 + 0.5
	var col := Color(0.22, 0.34, 0.15).lerp(Color(0.42, 0.56, 0.28), t)
	if center.y > 0.4:
		col = col.lerp(Color(0.44, 0.44, 0.30), clampf(center.y / 3.0, 0.0, 0.55))
	return col


## Bodenhöhe des Terrains an (x,z) — damit Streudeko auf den Hügeln aufsitzt.
func _ground_y(x: float, z: float) -> float:
	return _terrain_height(x, z, _terrain_noise) if _terrain_noise != null else 0.0


## Platziert ein Modell (filename inkl. Endung) auf Terrain-Höhe.
func _scatter(parent: Node3D, filename: String, x: float, z: float, yaw: float, scale: float) -> void:
	_place_model(parent, filename, Vector3(x, _ground_y(x, z), z), yaw, Vector3.ONE * scale)


## Streudekoration im offenen Gelände: Bäume auf den Randhügeln, Grasbüschel und
## Steine über dem Feld, dazu ein paar Requisiten und zwei Fackelsäulen. Keine
## umschließenden Wände. Der Lauf-Korridor (x ~ -7..7) bleibt weitgehend frei.
func _decorate() -> void:
	var d := Node3D.new()
	d.name = "Decor"
	add_child(d)

	# Bäume am Rand / auf den Hügeln
	_scatter(d, "tree.glb", -11.5, -13.0, 0.0, 1.0)
	_scatter(d, "tree.glb", 11.5, -12.0, 40.0, 1.0)
	_scatter(d, "tree.glb", -12.5, -5.0, 200.0, 1.0)
	_scatter(d, "tree.glb", 12.0, -1.0, 120.0, 1.0)
	_scatter(d, "tree.glb", -12.0, 4.0, 300.0, 0.9)
	_scatter(d, "tree.glb", 12.0, 5.0, 60.0, 0.9)

	# Steine
	_scatter(d, "rock.glb", -6.5, -9.0, 15.0, 2.2)
	_scatter(d, "rock.glb", 6.0, -3.0, 80.0, 2.0)
	_scatter(d, "rock.glb", -4.5, 2.0, 200.0, 1.8)

	# Grasbüschel verstreut
	var tufts := [
		Vector2(-8, -10), Vector2(-3, -9), Vector2(4, -11), Vector2(8, -5),
		Vector2(-6, -2), Vector2(2, 0), Vector2(7, 2), Vector2(-9, 3),
		Vector2(0, -6), Vector2(-2, -12), Vector2(5, -7), Vector2(9, -1),
	]
	for p in tufts:
		_scatter(d, "grass.glb", p.x, p.y, p.x * 37.0, 1.6)

	# Requisiten
	_scatter(d, "barrel_large.gltf", -9.0, -6.0, 20.0, 1.0)
	_scatter(d, "crates_stacked.gltf", 9.0, -8.0, -15.0, 1.0)
	_scatter(d, "barrel_large.gltf", 9.5, 0.0, 0.0, 1.0)
	_scatter(d, "crates_stacked.gltf", -9.5, 1.0, 10.0, 1.0)

	# Fackelsäulen am hinteren Rand (auf Terrain-Höhe)
	for x in [-10.0, 10.0]:
		var gy := _ground_y(x, -11.0)
		_place_model(d, "pillar.gltf", Vector3(x, gy, -11.0), 0.0, Vector3.ONE)
		_place_model(d, "torch_lit.gltf", Vector3(x, gy + 4.0, -11.0), 0.0, Vector3.ONE)


## Festung = fertiges Burg-Modell (CC0, Quaternius), skaliert und mittig am
## vorderen Feldrand platziert. Fehlt die Datei, bleibt das Feld trotzdem spielbar.
func _build_fortress() -> void:
	var fort := Node3D.new()
	fort.name = "Fortress"
	add_child(fort)
	# Groß und zur Front geschoben: nur der vordere Teil (Angriffsfront) liegt im
	# Feld, der Rest läuft unten aus dem Bild.
	_place_model(fort, "castle.glb", Vector3(0.0, 0.4, GOAL_Z + 9.0), 0.0, Vector3.ONE * 8.0)


func _place_prop(parent: Node3D, name: String, pos: Vector3, yaw_deg: float, scale := Vector3.ONE) -> void:
	_place_model(parent, "%s.gltf" % name, pos, yaw_deg, scale)


func _place_model(parent: Node3D, filename: String, pos: Vector3, yaw_deg: float, scale := Vector3.ONE) -> void:
	var path := "res://assets/models/props/%s" % filename
	if not ResourceLoader.exists(path):
		return
	var inst := (load(path) as PackedScene).instantiate() as Node3D
	inst.position = pos
	inst.rotation_degrees.y = yaw_deg
	inst.scale = scale
	parent.add_child(inst)


## Orthografische Iso-Kamera + Sonne. Per Code, damit die .tscn keine
## Transform-Basis-Mathematik enthalten muss.
func _setup_view() -> void:
	($CameraPivot as Node3D).rotation_degrees = Vector3(-30.0, 45.0, 0.0)
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 24.0
	_camera.position = Vector3(0.0, 0.0, 32.0)
	($Sun as DirectionalLight3D).rotation_degrees = Vector3(-55.0, -35.0, 0.0)


func _process(delta: float) -> void:
	if _shake_left <= 0.0:
		return
	_shake_left = max(0.0, _shake_left - delta)
	if _shake_left == 0.0:
		_camera.position = _cam_base
	else:
		var mag := SHAKE_MAGNITUDE * (_shake_left / SHAKE_DURATION)
		_camera.position = _cam_base + Vector3(randf_range(-mag, mag), randf_range(-mag, mag), 0.0)


func start_wave(wave_id: String) -> void:
	var wave: Dictionary = ContentRegistry.waves.get(wave_id, {})
	if wave.is_empty():
		push_error("WaveRunner: unbekannte Welle '%s'" % wave_id)
		return
	GameState.current_wave = wave_id
	var spawns: Array = wave.get("spawns", [])
	for entry in spawns:
		_total += int(entry.get("count", 0))
	EventBus.wave_started.emit(wave_id)
	for entry in spawns:
		_run_spawn_batch(entry)


## Läuft als Coroutine — mehrere Batches spawnen dadurch nebenläufig im Takt.
func _run_spawn_batch(entry: Dictionary) -> void:
	var count := int(entry.get("count", 0))
	var interval := float(entry.get("interval", 2.0))
	for i in count:
		await get_tree().create_timer(interval).timeout
		if _finished or not is_inside_tree():
			return
		_spawn(entry)


func _spawn(entry: Dictionary) -> void:
	var def: Dictionary = ContentRegistry.monsters.get(entry.get("monster", ""), {})
	if def.is_empty():
		push_warning("WaveRunner: unbekanntes Monster '%s'" % entry.get("monster", ""))
		return
	var candidates: Array = ContentRegistry.vocabulary_by_tags(entry.get("vocab_tags", []))
	if candidates.is_empty():
		push_warning("WaveRunner: keine Vokabeln für Tags %s" % str(entry.get("vocab_tags", [])))
		return
	var vocab: Dictionary = candidates[randi() % candidates.size()]

	var monster := MONSTER_SCENE.instantiate() as Monster
	monster.setup(def, vocab, GOAL_Z)
	monster.position = Vector3(randf_range(-LANE_HALF_WIDTH, LANE_HALF_WIDTH), 0.0, SPAWN_Z)
	monster.reached_goal.connect(_on_monster_reached_goal)
	_monsters.add_child(monster)
	_active.append(monster)
	_spawned += 1
	EventBus.monster_spawned.emit(def)


func _on_answer_submitted(text: String) -> void:
	if _finished:
		return
	for monster in _active:
		if _evaluator.evaluate_vocab(monster.vocab, text):
			_defeat(monster)
			_flash_feedback(FLASH_CORRECT)
			return
	# Kein Treffer -> Falscheingabe: rotes Flash + Kamera-Wackeln.
	# Anknüpfpunkt fürs Lernsystem (Fehlversuch protokollieren).
	_flash_feedback(FLASH_WRONG)
	_shake()


func _shake() -> void:
	_shake_left = SHAKE_DURATION


func _flash_feedback(color: Color) -> void:
	_flash.color = Color(color.r, color.g, color.b, 0.35)
	_flash.modulate = Color(1, 1, 1, 1)
	create_tween().tween_property(_flash, "modulate:a", 0.0, 0.4)


func _defeat(monster: Monster) -> void:
	_active.erase(monster)
	EventBus.monster_defeated.emit(monster.monster_def, true)
	monster.queue_free()
	_check_end()


## Monster hat sich beim Erreichen der Festung selbst freigegeben.
func _on_monster_reached_goal(monster: Monster) -> void:
	if not _active.has(monster):
		return
	_active.erase(monster)
	EventBus.fortress_damaged.emit(FORTRESS_HIT)
	if GameState.fortress_health <= 0:
		_end("Niederlage – die Festung ist gefallen.")
		return
	_check_end()


func _check_end() -> void:
	if _finished:
		return
	if _spawned >= _total and _active.is_empty():
		EventBus.wave_cleared.emit(GameState.current_wave)
		_end("Welle geräumt!")


func _end(message: String) -> void:
	_finished = true
	_end_label.text = message
	_end_label.visible = true
