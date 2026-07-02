extends Node3D
## Fährt eine einzelne Welle in 3D: spawnt Monster aus der Wave-Definition, gleicht
## Spielerantworten gegen aktive Monster ab und erkennt das Wellenende.
## Nutzt ausschließlich bestehende Autoloads + AnswerEvaluator — rein additiv.

const MONSTER_SCENE := preload("res://scenes/entities/monster.tscn")
const GOAL_Z := 6.5           # Festungsfront (Monster-Ziel)
const SPAWN_Z := -11.0        # Spawn am hinteren Ende der Bahn
const LANE_HALF_WIDTH := 7.0

const SHAKE_DURATION := 0.35
const SHAKE_MAGNITUDE := 0.35 # in 3D-Einheiten
const FLASH_CORRECT := Color(0.3, 1.0, 0.45)
const FLASH_WRONG := Color(1.0, 0.3, 0.3)

var _evaluator := AnswerEvaluator.new()
var _generator := WaveGenerator.new()
var _active: Array[Monster] = []
var _total: int = 0
var _spawned: int = 0
var _finished: bool = false

var _cam_base: Vector3
var _shake_left: float = 0.0
var _shake_mag: float = SHAKE_MAGNITUDE
var _rng := RandomNumberGenerator.new()

var _fortress: Node3D = null
var _fortress_tier: int = -1

@onready var _monsters: Node3D = $Monsters
@onready var _camera: Camera3D = $CameraPivot/Camera3D
@onready var _end_label: Label = $UI/EndLabel
@onready var _flash: ColorRect = $UI/Flash


func _ready() -> void:
	_rng.randomize()
	_setup_view()
	_setup_ground()
	_decorate()
	_build_fortress()
	_cam_base = _camera.position
	GameState.reset()
	EventBus.answer_submitted.connect(_on_answer_submitted)
	# Festung wächst mit dem Lernfortschritt: nach jeder verbuchten Antwort prüfen,
	# ob eine höhere Stufe erreicht wurde.
	EventBus.item_reviewed.connect(_on_item_reviewed)
	var debug_panel := $UI/DebugPanel
	if debug_panel.has_signal("fortress_tier_selected"):
		debug_panel.fortress_tier_selected.connect(_on_debug_tier_selected)
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
	noise.seed = _rng.randi()
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


## Platziert ein Modell (filename inkl. Endung) auf Terrain-Höhe mit zufälliger
## Drehung; Position/Skalierung kommen vom Aufrufer.
func _scatter(parent: Node3D, filename: String, x: float, z: float, scale: float) -> void:
	_place_model(parent, filename, Vector3(x, _ground_y(x, z), z), _rng.randf_range(0.0, 360.0), Vector3.ONE * scale)


## Randomisierte Streudekoration (jeder Start anders): Bäume an den Seitenstreifen
## (halten den Lauf-Korridor frei), Steine/Grasbüschel übers Feld, ein paar
## Requisiten und Fackelsäulen. Alles hinter der Festung (z < 5). Fortress bleibt fix.
func _decorate() -> void:
	var d := Node3D.new()
	d.name = "Decor"
	add_child(d)

	# Bäume nur an den Seitenstreifen (|x| groß), damit die Bahn frei bleibt
	for i in _rng.randi_range(5, 9):
		var sx := (1.0 if _rng.randf() < 0.5 else -1.0) * _rng.randf_range(9.5, 12.5)
		_scatter(d, "tree.glb", sx, _rng.randf_range(-13.0, 4.0), _rng.randf_range(0.85, 1.2))

	# Steine über das Feld verteilt
	for i in _rng.randi_range(3, 7):
		_scatter(d, "rock.glb", _rng.randf_range(-10.0, 10.0), _rng.randf_range(-13.0, 4.0), _rng.randf_range(1.6, 2.6))

	# Grasbüschel
	for i in _rng.randi_range(14, 22):
		_scatter(d, "grass.glb", _rng.randf_range(-11.0, 11.0), _rng.randf_range(-13.0, 4.5), _rng.randf_range(1.2, 2.0))

	# Fässer/Kisten an den Rändern
	for i in _rng.randi_range(2, 4):
		var bx := (1.0 if _rng.randf() < 0.5 else -1.0) * _rng.randf_range(8.5, 10.5)
		var kind := "barrel_large.gltf" if _rng.randf() < 0.5 else "crates_stacked.gltf"
		_scatter(d, kind, bx, _rng.randf_range(-10.0, 2.0), 1.0)

	# Zwei Fackelsäulen an zufälligen hinteren Randpositionen
	for side: float in [-1.0, 1.0]:
		var px := side * _rng.randf_range(9.5, 11.5)
		var pz := _rng.randf_range(-12.0, -8.0)
		var gy := _ground_y(px, pz)
		_place_model(d, "pillar.gltf", Vector3(px, gy, pz), 0.0, Vector3.ONE)
		_place_model(d, "torch_lit.gltf", Vector3(px, gy + 4.0, pz), 0.0, Vector3.ONE)


## Festung = modular aus dem KayKit Medieval Hexagon Pack (CC0, Kay Lousberg)
## zusammengesetzt und stufenweise mit dem Lernfortschritt gewachsen. Modelle unter
## assets/models/hexagon/ (blaue Farbvariante, passend zu den Sample-Renders).
const HEX_DIR := "hexagon"
const FORTRESS_SCALE := 3.0

func _build_fortress() -> void:
	_fortress_tier = PlayerProgress.fortress_tier()
	_spawn_fortress(_fortress_tier)


## Baut die Festung passend zur Stufe (0..4) neu auf. Additiv: höhere Stufen zeigen
## mehr Türme/Mauern/Nebengebäude. Nur die -z-Front (Angriffsfront) liegt im Bild,
## Burg + Nebengebäude laufen nach hinten (+z) aus dem sichtbaren Feld.
func _spawn_fortress(tier: int) -> void:
	var fort := Node3D.new()
	fort.name = "Fortress"
	add_child(fort)
	_fortress = fort

	var fz := GOAL_Z              # Mauerfront = Ziel-Linie der Monster
	var seg := 2.0 * FORTRESS_SCALE   # Weltbreite eines Mauersegments

	print("[FORTRESS] Stufe %d (%d Aufgaben gemeistert)" % [tier, PlayerProgress.mastered_count()])

	if tier <= 0:
		# Baustelle: Turmstumpf + Baugerüst. Kleine Stufe an den hinteren Rand
		# (Verteidiger-Rückseite = +z, näher zur Kamera) gezogen, weg von der
		# Monster-Front, aber noch komplett im Bild.
		_hex(fort, "building_tower_base_blue", 0.0, fz + 3.5)
		_hex(fort, "building_scaffolding", seg * 0.7, fz + 3.5)
		return

	# Ab Stufe 2: Wehrmauer mit Tor + Ecktürmen.
	if tier >= 2:
		_hex(fort, "wall_straight", -seg, fz)
		_hex(fort, "wall_straight_gate", 0.0, fz)
		_hex(fort, "wall_straight", seg, fz)
		var end_tower := "building_tower_catapult_blue" if tier >= 4 else "building_tower_B_blue"
		_hex(fort, end_tower, -seg * 1.5, fz)
		_hex(fort, end_tower, seg * 1.5, fz)

	# Zentrum: erst ein Turm (Stufe 1/2), ab Stufe 3 die große Burg.
	if tier >= 3:
		_hex(fort, "building_castle_blue", 0.0, fz + 3.0)
	elif tier == 2:
		_hex(fort, "building_tower_A_blue", 0.0, fz + 1.0)  # hinter der Mauer
	else:
		# Stufe 1 ohne Mauer: Turm an den hinteren Rand (+z), weg von der Front.
		_hex(fort, "building_tower_A_blue", 0.0, fz + 3.0)

	# Vollausbau: Nebengebäude hinter der Mauer + Fahnen auf den Ecktürmen.
	if tier >= 4:
		_hex(fort, "building_barracks_blue", -seg * 1.3, fz + 4.5, 20.0)
		_hex(fort, "building_blacksmith_blue", seg * 1.3, fz + 4.5, -20.0)
		_hex(fort, "building_home_A_blue", -seg * 0.6, fz + 6.5)
		_hex(fort, "building_home_B_blue", seg * 0.6, fz + 6.5)
		_hex(fort, "building_church_blue", 0.0, fz + 8.0)
		_hex(fort, "building_windmill_blue", -seg * 1.9, fz + 2.5)
		var flag_y := 2.2 * FORTRESS_SCALE
		for sx: float in [-seg * 1.5, seg * 1.5]:
			var flag := _hex(fort, "flag_blue", sx, fz)
			if flag != null:
				flag.position.y += flag_y


## Platziert ein Hexagon-Pack-Modell (ohne .gltf-Endung) auf Terrain-Höhe, skaliert
## mit FORTRESS_SCALE. Gibt die Instanz zurück (null wenn Modell fehlt).
func _hex(parent: Node3D, model: String, x: float, z: float, yaw := 0.0, extra := 1.0) -> Node3D:
	return _place_model(parent, "%s.gltf" % model, Vector3(x, _ground_y(x, z), z), yaw, Vector3.ONE * FORTRESS_SCALE * extra, HEX_DIR)


## Baut die Festung bei einem Stufenanstieg neu auf, mit kurzem Bau-Effekt als Feedback.
func _rebuild_fortress(tier: int) -> void:
	_fortress_tier = tier
	if is_instance_valid(_fortress):
		_fortress.queue_free()
	_spawn_fortress(tier)
	_spawn_explosion(Vector3(0.0, 1.5, GOAL_Z + 2.0), Color(1.0, 0.9, 0.4), 2.0)


## Nach jeder verbuchten Antwort: Festung wachsen lassen, wenn eine höhere Stufe
## erreicht ist. Bewusst nur wachsend innerhalb eines Laufs (nie schrumpfen).
func _on_item_reviewed(_task_id: String, _correct: bool) -> void:
	var tier := PlayerProgress.fortress_tier()
	if tier > _fortress_tier:
		_rebuild_fortress(tier)


## Debug-Panel (nur im Debug-Build vorhanden): erlaubt das direkte Setzen der
## Festungsstufe, um jede Ausbaustufe ohne Lernfortschritt begutachten zu können.
func _on_debug_tier_selected(tier: int) -> void:
	_rebuild_fortress(tier)


func _place_prop(parent: Node3D, name: String, pos: Vector3, yaw_deg: float, scale := Vector3.ONE) -> void:
	_place_model(parent, "%s.gltf" % name, pos, yaw_deg, scale)


func _place_model(parent: Node3D, filename: String, pos: Vector3, yaw_deg: float, scale := Vector3.ONE, subdir := "props") -> Node3D:
	var path := "res://assets/models/%s/%s" % [subdir, filename]
	if not ResourceLoader.exists(path):
		return null
	var inst := (load(path) as PackedScene).instantiate() as Node3D
	inst.position = pos
	inst.rotation_degrees.y = yaw_deg
	inst.scale = scale
	parent.add_child(inst)
	return inst


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
		var mag := _shake_mag * (_shake_left / SHAKE_DURATION)
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
	# Der WaveGenerator wählt anhand des Spieler-Fortschritts eine Aufgabe aus dem
	# Pool, löst sie auf und bestimmt Darstellung (monster_task_rules) + Basiswerte.
	var plan: Dictionary = _generator.pick(entry.get("task_pool", {}))
	if plan.is_empty():
		push_warning("WaveRunner: keine spielbare Aufgabe für Pool %s" % str(entry.get("task_pool", {})))
		return

	var monster := MONSTER_SCENE.instantiate() as Monster
	monster.setup(plan["monster_def"], plan["task"], GOAL_Z, plan["speed"])
	monster.damage = plan["damage"]
	monster.reward = plan["reward"]
	monster.spawned_at_ms = Time.get_ticks_msec()
	monster.position = Vector3(randf_range(-LANE_HALF_WIDTH, LANE_HALF_WIDTH), 0.0, SPAWN_Z)
	monster.reached_goal.connect(_on_monster_reached_goal)
	_monsters.add_child(monster)
	_active.append(monster)
	_spawned += 1
	EventBus.monster_spawned.emit(plan["monster_def"])


func _on_answer_submitted(text: String) -> void:
	if _finished:
		return
	for monster in _active:
		if _evaluator.evaluate_answers(monster.task.get("accepted_answers", []), text):
			var rt := Time.get_ticks_msec() - monster.spawned_at_ms
			var task_id := str(monster.task.get("template_id", ""))
			PlayerProgress.record(task_id, true, rt)
			EventBus.item_reviewed.emit(task_id, true)
			_defeat(monster)
			_flash_feedback(FLASH_CORRECT)
			return
	# Kein Treffer -> Falscheingabe: rotes Flash + Kamera-Wackeln.
	# Bewusst KEIN Fortschritts-Eintrag: eine Falscheingabe lässt sich keiner
	# konkreten Aufgabe zuordnen (mehrere Monster gleichzeitig). Ein echtes
	# Scheitern wird beim Erreichen der Festung verbucht (_on_monster_reached_goal).
	_flash_feedback(FLASH_WRONG)
	_shake()


func _shake(magnitude: float = SHAKE_MAGNITUDE) -> void:
	_shake_left = SHAKE_DURATION
	_shake_mag = magnitude


func _flash_feedback(color: Color) -> void:
	_flash.color = Color(color.r, color.g, color.b, 0.35)
	_flash.modulate = Color(1, 1, 1, 1)
	create_tween().tween_property(_flash, "modulate:a", 0.0, 0.4)


func _defeat(monster: Monster) -> void:
	_active.erase(monster)
	_spawn_explosion(monster.position + Vector3(0.0, 1.0, 0.0), Color(0.7, 1.0, 0.4), 1.5)
	# Reward aus der monster_task_rule an GameState durchreichen (Score).
	var info := monster.monster_def.duplicate()
	info["reward"] = monster.reward
	EventBus.monster_defeated.emit(info, true)
	monster.queue_free()
	_check_end()


## Instanziiert einen kurzlebigen Explosionseffekt an der Weltposition.
func _spawn_explosion(pos: Vector3, color: Color, scale: float) -> void:
	var fx := Explosion.new()
	fx.setup(color, scale)
	fx.position = pos
	add_child(fx)


## Monster hat sich beim Erreichen der Festung selbst freigegeben.
func _on_monster_reached_goal(monster: Monster) -> void:
	if not _active.has(monster):
		return
	_active.erase(monster)
	_spawn_explosion(monster.position + Vector3(0.0, 1.0, 0.0), Color(1.0, 0.45, 0.12), 2.6)
	_shake(0.9)
	# Monster durchgelassen = Aufgabe nicht rechtzeitig abgerufen -> als Fehler verbuchen.
	var task_id := str(monster.task.get("template_id", ""))
	PlayerProgress.record(task_id, false)
	EventBus.item_reviewed.emit(task_id, false)
	EventBus.fortress_damaged.emit(monster.damage)
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
