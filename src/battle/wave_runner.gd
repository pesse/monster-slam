extends Node3D
## Fährt eine einzelne Welle in 3D: spawnt Monster aus der Wave-Definition, gleicht
## Spielerantworten gegen aktive Monster ab und erkennt das Wellenende.
## Nutzt ausschließlich bestehende Autoloads + AnswerEvaluator — rein additiv.

const MONSTER_SCENE := preload("res://scenes/entities/monster.tscn")
const GOAL_Z := 6.5           # Festungsfront (Monster-Ziel)
const SPAWN_Z := -24.0        # Spawn am hinteren Ende der Bahn (längerer Anmarsch)
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

# Prozedurale Wellen (nicht mehr aus Content-Dateien): Schwierigkeit + Wellennummer
# steuern Erzeugung und Tempo. Der Spieler wählt die Schwierigkeit auf dem Statistik-Screen.
var _difficulty: int = 3           # 1..5, vom Spieler gewählt
var _wave_number: int = 1          # laufende Nummer (Anzeige + Skalierung)
var _wave_correct: int = 0         # richtig besiegte Monster dieser Welle
var _wave_leaked: int = 0          # an der Festung durchgelassene Monster dieser Welle
var _score_at_start: int = 0       # Punktestand zu Wellenbeginn (für "+X" im Screen)
var _last_won: bool = true         # Ausgang der zuletzt beendeten Welle
# Generation-Zähler: bricht Spawn-Coroutinen einer alten Welle ab, sobald eine neue
# startet (der _finished-Check allein reicht nicht, da die neue Welle _finished=false setzt).
var _wave_gen: int = 0

var _cam_base: Vector3
var _shake_left: float = 0.0
var _shake_mag: float = SHAKE_MAGNITUDE
var _rng := RandomNumberGenerator.new()

var _fortress: Node3D = null
var _fortress_tier: int = -1
var _cutscene: bool = false   # läuft gerade die Ausbau-Cutscene? (unterdrückt Kamera-Wackeln)

@onready var _monsters: Node3D = $Monsters
@onready var _camera: Camera3D = $CameraPivot/Camera3D
@onready var _end_label: Label = $UI/EndLabel
@onready var _flash: ColorRect = $UI/Flash
@onready var _stats: PanelContainer = $UI/WaveStats
@onready var _answer_input: LineEdit = $UI/AnswerInput


func _ready() -> void:
	_rng.randomize()
	_setup_view()
	_setup_ground()
	_decorate()
	_build_fortress()
	_cam_base = _camera.position
	GameState.reset()
	EventBus.answer_submitted.connect(_on_answer_submitted)
	# Die Festung wächst mit dem Lernfortschritt, aber erst NACH einer gewonnenen Welle
	# (siehe _finish_wave) – nicht mehr mitten im Kampf.
	var debug_panel := $UI/DebugPanel
	if debug_panel.has_signal("fortress_tier_selected"):
		debug_panel.fortress_tier_selected.connect(_on_debug_tier_selected)
	if _stats.has_signal("next_wave_requested"):
		_stats.next_wave_requested.connect(_on_next_wave_requested)
	if _stats.has_signal("back_to_menu_requested"):
		_stats.back_to_menu_requested.connect(_on_back_to_menu)
	# Startschwierigkeit aus den persistenten Einstellungen des aktiven Profils.
	_difficulty = UserSettings.default_difficulty()
	_start_next_wave()


## Prozedurales Low-Poly-Terrain: flaches Innenfeld (Spielfläche/Props/Festung),
## sanfte facettierte Hügel am Rand, dezente Grün-Variation je Facette. Flat-Shading
## über manuell gesetzte Face-Normalen — passt zum Stil von Burg/Skeletten.
const TERRAIN_HALF_X := 13.0
const TERRAIN_Z_BACK := -28.0   # hinter dem Spawn (Hügel)
const TERRAIN_Z_FRONT := 17.0   # nur knapp hinter die Festung, sonst leere Fläche
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
		var z := TERRAIN_Z_BACK
		while z < TERRAIN_Z_FRONT - 0.001:
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
	# Innenfeld flach halten (bis knapp hinter den Spawn); nur außerhalb sanfte Hügel.
	var edge := maxf(absf(x) - 9.0, -z + SPAWN_Z)
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

	var z_back := SPAWN_Z - 2.0    # bis knapp hinter den Spawn
	var z_front := GOAL_Z - 2.0    # bis kurz vor die Festung

	# Bäume nur an den Seitenstreifen (|x| groß), damit die Bahn frei bleibt
	for i in _rng.randi_range(8, 14):
		var sx := (1.0 if _rng.randf() < 0.5 else -1.0) * _rng.randf_range(9.5, 12.5)
		_scatter(d, "tree.glb", sx, _rng.randf_range(z_back, z_front), _rng.randf_range(0.85, 1.2))

	# Steine über das Feld verteilt
	for i in _rng.randi_range(5, 10):
		_scatter(d, "rock.glb", _rng.randf_range(-10.0, 10.0), _rng.randf_range(z_back, z_front), _rng.randf_range(1.6, 2.6))

	# Grasbüschel
	for i in _rng.randi_range(22, 34):
		_scatter(d, "grass.glb", _rng.randf_range(-11.0, 11.0), _rng.randf_range(z_back, z_front + 0.5), _rng.randf_range(1.2, 2.0))

	# Fässer/Kisten an den Rändern
	for i in _rng.randi_range(3, 6):
		var bx := (1.0 if _rng.randf() < 0.5 else -1.0) * _rng.randf_range(8.5, 10.5)
		var kind := "barrel_large.gltf" if _rng.randf() < 0.5 else "crates_stacked.gltf"
		_scatter(d, kind, bx, _rng.randf_range(SPAWN_Z + 4.0, GOAL_Z - 3.0), 1.0)

	# Zwei Fackelsäulen am hinteren Rand (Spawn-Seite)
	for side: float in [-1.0, 1.0]:
		var px := side * _rng.randf_range(9.5, 11.5)
		var pz := _rng.randf_range(SPAWN_Z + 1.0, SPAWN_Z + 5.0)
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


## „Cutscene" beim Festungsausbau (nach gewonnener Welle, vor der Statistik): die
## Kamera zoomt kräftig auf die neu gebaute Festung, ein festlicher Blitz + Banner
## feiern die neue Stufe, danach fährt die Kamera zurück. Unterdrückt das Kamera-Wackeln.
func _play_upgrade_cutscene(tier: int) -> void:
	_rebuild_fortress(tier)
	# Überlappende Cutscenes vermeiden: nur die erste inszeniert, weitere bauen still um.
	if _cutscene:
		return
	_cutscene = true
	_shake_left = 0.0                 # laufendes Wackeln stoppen, sonst kämpft es mit der Fahrt

	var pivot := $CameraPivot as Node3D
	var pivot_base := pivot.position
	var size_base := _camera.size
	# Ziel: Festungsmitte im Bild, deutlich herangezoomt (kleinere ortho-Größe = näher).
	var focus := Vector3(0.0, pivot_base.y, GOAL_Z + 3.0)

	# Festlicher goldener Blitz an der Festung + Banner.
	_spawn_explosion(Vector3(0.0, 2.0, GOAL_Z + 2.0), Color(1.0, 0.85, 0.3), 3.0)
	_show_upgrade_banner(tier)

	# Heranfahren + kräftig hineinzoomen.
	var tw_in := create_tween()
	tw_in.set_parallel(true)
	tw_in.tween_property(pivot, "position", focus, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw_in.tween_property(_camera, "size", size_base * 0.42, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw_in.finished
	await get_tree().create_timer(1.1).timeout

	# Zurückfahren.
	var tw_out := create_tween()
	tw_out.set_parallel(true)
	tw_out.tween_property(pivot, "position", pivot_base, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw_out.tween_property(_camera, "size", size_base, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw_out.finished

	_cutscene = false


## Blendet für die Ausbau-Cutscene ein gerahmtes Banner ein (steigt auf + blendet aus).
func _show_upgrade_banner(tier: int) -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_END
	panel.offset_top = 110.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	($UI as CanvasLayer).add_child(panel)

	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 40)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	label.text = "🏰 Festung ausgebaut!\nStufe %d" % tier
	panel.add_child(label)

	panel.modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(panel, "modulate:a", 1.0, 0.3)
	tw.tween_property(panel, "offset_top", 90.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(1.0)
	tw.chain().tween_property(panel, "modulate:a", 0.0, 0.4)
	tw.chain().tween_callback(panel.queue_free)


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
	var pivot := $CameraPivot as Node3D
	pivot.rotation_degrees = Vector3(-30.0, 45.0, 0.0)
	# Auf die Mitte des Terrains zentrieren, damit der längere Anmarsch komplett
	# im Bild bleibt, ohne leere Fläche hinter der Festung.
	pivot.position = Vector3(0.0, 0.0, (TERRAIN_Z_BACK + TERRAIN_Z_FRONT) * 0.5)
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 32.0
	_camera.position = Vector3(0.0, 0.0, 32.0)
	($Sun as DirectionalLight3D).rotation_degrees = Vector3(-55.0, -35.0, 0.0)


func _process(delta: float) -> void:
	if _cutscene:
		return
	if _shake_left <= 0.0:
		return
	_shake_left = max(0.0, _shake_left - delta)
	if _shake_left == 0.0:
		_camera.position = _cam_base
	else:
		var mag := _shake_mag * (_shake_left / SHAKE_DURATION)
		_camera.position = _cam_base + Vector3(randf_range(-mag, mag), randf_range(-mag, mag), 0.0)


## Startet die nächste (prozedural erzeugte) Welle mit der aktuell gewählten Schwierigkeit.
## Ersetzt das frühere content-basierte start_wave(): Wellen sind nicht mehr vordefiniert,
## sondern werden aus Schwierigkeit + Wellennummer generiert.
func _start_next_wave() -> void:
	_wave_gen += 1
	var gen := _wave_gen
	# Wellen-Zustand zurücksetzen (auch bei Wiederholung nach Niederlage).
	_clear_active_monsters()
	_total = 0
	_spawned = 0
	_finished = false
	_wave_correct = 0
	_wave_leaked = 0
	_score_at_start = GameState.score
	_end_label.visible = false
	_stats.hide_stats()
	_answer_input.visible = true

	GameState.current_wave = "procedural_%d" % _wave_number
	_generator.speed_scale = _difficulty_to_speed(_difficulty)
	var spawns := _generate_wave(_difficulty, _wave_number)
	for entry in spawns:
		_total += int(entry.get("count", 0))
	# Löst den HP-Reset (GameState) + HUD-Refresh aus.
	EventBus.wave_started.emit(GameState.current_wave)
	# Gesamtzahl der Welle bekanntgeben -> GameState füllt wave_total/wave_resolved (HUD-Balken).
	EventBus.wave_totals.emit(_total)
	for entry in spawns:
		_run_spawn_batch(entry, gen)


## Schwierigkeit (1..5) -> Tempo-Multiplikator auf die Basis-Geschwindigkeit
## (Stufe 1..5 ⇒ 0.6 .. 1.4, also -40 % … +40 %).
func _difficulty_to_speed(difficulty: int) -> float:
	return 0.6 + 0.2 * float(clampi(difficulty, 1, 5) - 1)


## Erzeugt die Spawn-Batches einer Welle prozedural. Rückgabe: Array von Dicts der Form
## {count, interval, task_pool} — dasselbe Format, das _run_spawn_batch/_spawn erwarten.
func _generate_wave(difficulty: int, wave_number: int) -> Array:
	# Monsteranzahl wächst pro Welle UND mit der Schwierigkeit (Stufe 3 = neutral,
	# je Stufe darüber/darunter +/- 2 Monster). Mindestens 2 Monster pro Welle.
	var count := maxi(2, 2 + wave_number + (difficulty - 3) * 2)
	var interval := maxf(1.5, 4.0 - 0.3 * difficulty)  # härter ⇒ schnellere Folge
	return [{
		"count": count,
		"interval": interval,
		"task_pool": {
			"task_types": ["translate", "opposite", "synonym", "confusables"],
			# "basics" = kleiner Starter-Satz, "core" = produktiver Kernwortschatz
			# (en_klasse9). "receptive"-Wörter bleiben bewusst außen vor (nur verstehen).
			"tags": ["basics", "core"],
			"difficulty_max": clampi(difficulty, 1, 5),
		},
	}]


## Entfernt noch aktive Monster (z. B. Reste einer verlorenen Welle) vom Feld.
func _clear_active_monsters() -> void:
	for monster in _active:
		if is_instance_valid(monster):
			monster.queue_free()
	_active.clear()


## Läuft als Coroutine — mehrere Batches spawnen dadurch nebenläufig im Takt.
## `gen` bindet die Coroutine an ihre Welle: startet inzwischen eine neue Welle, bricht sie ab.
func _run_spawn_batch(entry: Dictionary, gen: int) -> void:
	var count := int(entry.get("count", 0))
	var interval := float(entry.get("interval", 2.0))
	for i in count:
		await get_tree().create_timer(interval).timeout
		if _finished or not is_inside_tree() or gen != _wave_gen:
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
			var task_id := str(monster.task.get("learnable_id", ""))
			PlayerProgress.record(task_id, true, rt, float(monster.task.get("initial_confidence", -1.0)))
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
	if _cutscene:
		return
	_shake_left = SHAKE_DURATION
	_shake_mag = magnitude


func _flash_feedback(color: Color) -> void:
	_flash.color = Color(color.r, color.g, color.b, 0.35)
	_flash.modulate = Color(1, 1, 1, 1)
	create_tween().tween_property(_flash, "modulate:a", 0.0, 0.4)


func _defeat(monster: Monster) -> void:
	_active.erase(monster)
	_wave_correct += 1
	_spawn_explosion(monster.position + Vector3(0.0, 1.0, 0.0), Color(0.7, 1.0, 0.4), 1.5)
	# Kleine aufsteigende „+Punkte"-Animation an der Stelle des Monsters.
	_spawn_score_popup(monster.position + Vector3(0.0, 2.0, 0.0), monster.reward)
	# Reward aus der monster_task_rule an GameState durchreichen (Score).
	var info := monster.monster_def.duplicate()
	info["reward"] = monster.reward
	EventBus.monster_defeated.emit(info, true)
	monster.queue_free()
	_check_end()


## Deutlich sichtbarer 3D-Text (+Punkte), der an der Trefferstelle aufpoppt, aufsteigt
## und ausblendet. Als Label3D (Billboard) im Stil der vorhandenen Monster-Beschriftungen.
func _spawn_score_popup(pos: Vector3, amount: int) -> void:
	var label := Label3D.new()
	label.text = "+%d" % amount
	label.font_size = 200
	label.pixel_size = 0.02
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = Color(1.0, 0.9, 0.25)
	label.outline_size = 32
	label.outline_modulate = Color(0.15, 0.08, 0.0, 1.0)
	label.position = pos
	label.scale = Vector3.ONE * 0.4
	add_child(label)
	var tw := create_tween()
	tw.set_parallel(true)
	# Kräftiger Pop beim Erscheinen.
	tw.tween_property(label, "scale", Vector3.ONE * 1.15, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Deutlich höher aufsteigen, über die volle Dauer.
	tw.tween_property(label, "position:y", pos.y + 4.0, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Erst gegen Ende ausblenden, damit die Zahl gut lesbar bleibt.
	tw.tween_property(label, "modulate:a", 0.0, 0.5).set_delay(0.7)
	tw.chain().tween_callback(label.queue_free)


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
	_wave_leaked += 1
	_spawn_explosion(monster.position + Vector3(0.0, 1.0, 0.0), Color(1.0, 0.45, 0.12), 2.6)
	_shake(0.9)
	# Monster durchgelassen = Aufgabe nicht rechtzeitig abgerufen -> als Fehler verbuchen.
	var task_id := str(monster.task.get("learnable_id", ""))
	PlayerProgress.record(task_id, false, 0, float(monster.task.get("initial_confidence", -1.0)))
	EventBus.item_reviewed.emit(task_id, false)
	EventBus.fortress_damaged.emit(monster.damage)
	if GameState.fortress_health <= 0:
		_finish_wave(false)
		return
	_check_end()


func _check_end() -> void:
	if _finished:
		return
	if _spawned >= _total and _active.is_empty():
		EventBus.wave_cleared.emit(GameState.current_wave)
		_finish_wave(true)


## Beendet die Welle und zeigt den Statistik-Screen (Sieg oder Niederlage).
func _finish_wave(won: bool) -> void:
	if _finished:
		return
	_finished = true
	_last_won = won
	_answer_input.visible = false
	# Festungsausbau erst jetzt (nach gewonnener Welle), als Cutscene VOR der Statistik.
	if won:
		var new_tier := PlayerProgress.fortress_tier()
		if new_tier > _fortress_tier:
			await _play_upgrade_cutscene(new_tier)
	var total := _wave_correct + _wave_leaked
	var accuracy := 100.0 * float(_wave_correct) / float(max(1, total))
	_stats.show_stats({
		"won": won,
		"wave_number": _wave_number,
		"difficulty": _difficulty,
		"correct": _wave_correct,
		"leaked": _wave_leaked,
		"total": total,
		"accuracy": accuracy,
		"score_gained": GameState.score - _score_at_start,
		"score_total": GameState.score,
		"fortress_health": GameState.fortress_health,
		"mastered": PlayerProgress.mastered_count(),
		"fortress_tier": PlayerProgress.fortress_tier(),
	})


## Spieler hat auf dem Statistik-Screen die nächste Welle gerufen. Die Wahl ist RELATIV:
## `delta` (-2..+2) verschiebt die aktuelle Schwierigkeit, begrenzt auf 1..5.
func _on_next_wave_requested(delta: int) -> void:
	_difficulty = clampi(_difficulty + delta, 1, 5)
	_wave_number += 1
	_start_next_wave()


## Spieler kehrt vom Statistik-Screen ins Menü zurück. Fortschritt explizit sichern
## (der Niederlage-Pfad emittiert kein wave_cleared) und die Menü-Szene laden.
func _on_back_to_menu() -> void:
	PlayerProgress.save_progress()
	get_tree().change_scene_to_file("res://scenes/ui/profile_menu.tscn")
