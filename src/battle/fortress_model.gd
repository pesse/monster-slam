class_name FortressModel
extends RefCounted
## Die Festung aus Teilen des Hexagon-Packs, eine Anordnung je Stufe (0..4); höhere Stufen
## zeigen mehr. Die Angriffsfront liegt auf -z, Burg und Nebengebäude laufen nach +z aus dem
## Bild. Auch die Bilder der Festungsanzeige entstehen hieraus.

const HEX_DIR := "res://assets/models/hexagon"
const SCALE := 5.0
## Maßstab, für den die Abstände in `build` gesetzt sind; bei anderem SCALE wachsen sie mit.
const LAYOUT_SCALE := 3.0
## Halbe Tiefe der Mauerteile in Modelleinheiten; hält die Vorderkante bei jeder Größe fest.
const WALL_HALF_DEPTH := 0.4
## Gierwinkel (Grad) der Mauerteile: im Pack liegen die Zinnen auf +z, die Feindseite ist -z.
const WALL_YAW := 180.0
## Ab dieser Stufe tragen die Ecktürme Katapulte, nur dann wirft das Wachkatapult.
const CATAPULT_TIER := 4
## Die beweglichen Teile des Katapultturms im Modell des Packs, und wo am Arm der Löffel
## sitzt (in Modelleinheiten, -z am Arm).
const CATAPULT_TURRET := "catapult_turret_blue"
const CATAPULT_ARM := "catapult_arm_blue"
const CATAPULT_BUCKET := Vector3(0.0, 0.05, -0.6)
## Ein Wurf: zum Ziel drehen, Arm hochschlagen, kurz oben halten, langsam zurück (s, Grad).
const CATAPULT_TURN_TIME := 0.25
const CATAPULT_SWING_TIME := 0.14
const CATAPULT_SWING_DEG := 110.0
const CATAPULT_HOLD_TIME := 0.12
const CATAPULT_RETURN_TIME := 0.7
## Abnutzung (BattleTheme.fortress_wear).
const WEAR_SHADER := preload("res://assets/shaders/fortress_wear.gdshader")
## Je Atlas und Grad der Abnutzung ein Material, geteilt von allen Teilen.
static var _wear_materials := {}


## Setzt die Teile der Stufe unter `parent`; `front_z` ist die Mauerfront, `ground_y(x, z)`
## die Geländehöhe, `wear` (0..1) die Abnutzung des Themas.
static func build(parent: Node3D, tier: int, front_z: float, ground_y: Callable,
		scale: float = SCALE, wear := 0.0) -> void:
	var k := scale / LAYOUT_SCALE
	var fz := front_z + WALL_HALF_DEPTH * (scale - LAYOUT_SCALE)
	var seg := 2.0 * scale   # Weltbreite eines Mauersegments
	var put := _Put.new(parent, ground_y, scale, wear)

	if tier <= 0:
		# Baustelle: Turmstumpf + Baugerüst, nach hinten (+z) weg von der Front, noch im Bild.
		put.at("building_tower_base_blue", 0.0, fz + 3.5 * k)
		put.at("building_scaffolding", seg * 0.7, fz + 3.5 * k)
		return

	if tier >= 2:
		put.at("wall_straight", -seg, fz, WALL_YAW)
		put.at("wall_straight_gate", 0.0, fz, WALL_YAW)
		put.at("wall_straight", seg, fz, WALL_YAW)
		var end_tower := "building_tower_catapult_blue" if tier >= CATAPULT_TIER else "building_tower_B_blue"
		# Wie die Mauer gedreht: das Katapult des Pakets wirft nach +z, hier zum Feind.
		put.at(end_tower, -seg * 1.5, fz, WALL_YAW)
		put.at(end_tower, seg * 1.5, fz, WALL_YAW)

	# Zentrum: erst ein Turm (Stufe 1/2), ab Stufe 3 die große Burg.
	if tier >= 3:
		put.at("building_castle_blue", 0.0, fz + 3.0 * k)
	elif tier == 2:
		put.at("building_tower_A_blue", 0.0, fz + 1.0 * k)  # hinter der Mauer
	else:
		# Stufe 1 ohne Mauer: Turm an den hinteren Rand (+z), weg von der Front.
		put.at("building_tower_A_blue", 0.0, fz + 3.0 * k)

	if tier >= 4:
		put.at("building_barracks_blue", -seg * 1.3, fz + 4.5 * k, 20.0)
		put.at("building_blacksmith_blue", seg * 1.3, fz + 4.5 * k, -20.0)
		put.at("building_home_A_blue", -seg * 0.6, fz + 6.5 * k)
		put.at("building_home_B_blue", seg * 0.6, fz + 6.5 * k)
		put.at("building_church_blue", 0.0, fz + 8.0 * k)
		put.at("building_windmill_blue", -seg * 1.9, fz + 2.5 * k)


## Der Drehkranz jedes Katapultturms unter `parent`. Kranz und Wurfarm sind eigene Knoten
## im Modell des Packs; gedreht wird dort, nicht am Turm.
static func catapults(parent: Node) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for node in parent.find_children(CATAPULT_TURRET, "Node3D", true, false):
		if node.get_node_or_null(CATAPULT_ARM) is Node3D:
			out.append(node as Node3D)
	return out


## Ein Wurf zu `target` in Spielzeit. Kehrt im Scheitel mit dem Punkt zurück, an dem der
## Stein den Löffel verlässt; der Arm schwingt danach von selbst zurück. Gewartet wird auf
## einen Timer statt auf den Tween, weil der Turm mitten im Wurf wegfallen kann.
static func fire(turret: Node3D, target: Vector3) -> Vector3:
	var arm := turret.get_node(CATAPULT_ARM) as Node3D
	# Der Pack wirft nach +z seines Kranzes. Der kürzere Weg herum, sonst dreht er sich
	# bei jedem zweiten Wurf einmal ganz.
	var local := (turret.get_parent() as Node3D).to_local(target) - turret.position
	var yaw := turret.rotation.y + wrapf(atan2(local.x, local.z) - turret.rotation.y, -PI, PI)
	var tw := turret.create_tween()
	tw.tween_property(turret, "rotation:y", yaw, CATAPULT_TURN_TIME) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(arm, "rotation:x", deg_to_rad(CATAPULT_SWING_DEG), CATAPULT_SWING_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(arm, "rotation:x", 0.0, CATAPULT_RETURN_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(CATAPULT_HOLD_TIME)
	var tree := turret.get_tree()
	var release := turret.global_position + Vector3.UP * CATAPULT_BUCKET.length()
	await tree.create_timer(CATAPULT_TURN_TIME + CATAPULT_SWING_TIME, false).timeout
	if is_instance_valid(arm) and arm.is_inside_tree():
		release = arm.global_transform * CATAPULT_BUCKET
	return release


## Wie viel größer als LAYOUT_SCALE die Festung steht.
static func grow() -> float:
	return SCALE / LAYOUT_SCALE


## Setzt ein Modell (ohne .gltf-Endung) auf die Geländehöhe; null, wenn es fehlt.
class _Put:
	var _parent: Node3D
	var _ground_y: Callable
	var _scale: float
	var _wear: float

	func _init(parent: Node3D, ground_y: Callable, scale: float, wear: float) -> void:
		_parent = parent
		_ground_y = ground_y
		_scale = scale
		_wear = wear

	func at(model: String, x: float, z: float, yaw := 0.0) -> Node3D:
		var path := "%s/%s.gltf" % [HEX_DIR, model]
		if not ResourceLoader.exists(path):
			return null
		var inst := (load(path) as PackedScene).instantiate() as Node3D
		inst.position = Vector3(x, float(_ground_y.call(x, z)), z)
		inst.rotation_degrees.y = yaw
		inst.scale = Vector3.ONE * _scale
		if _wear > 0.0:
			FortressModel.wear_down(inst, _wear)
		_parent.add_child(inst)
		return inst


## Legt das Material der Abnutzung `wear` als Override über alle Meshes von `part`.
static func wear_down(part: Node3D, wear: float) -> void:
	for mi: MeshInstance3D in part.find_children("*", "MeshInstance3D", true, false):
		var atlas := _atlas_of(mi)
		if atlas == null:
			continue
		var key := "%s|%.3f" % [atlas.resource_path, wear]
		if not _wear_materials.has(key):
			var mat := ShaderMaterial.new()
			mat.shader = WEAR_SHADER
			mat.set_shader_parameter("atlas", atlas)
			mat.set_shader_parameter("wear", wear)
			_wear_materials[key] = mat
		mi.material_override = _wear_materials[key]


static func _atlas_of(mi: MeshInstance3D) -> Texture2D:
	if mi.mesh == null or mi.mesh.get_surface_count() == 0:
		return null
	var mat := mi.get_active_material(0) as BaseMaterial3D
	return mat.albedo_texture if mat != null else null
