class_name FortressModel
extends RefCounted
## Die Festung aus Teilen des Hexagon-Packs, eine Anordnung je Stufe (0..4). Additiv: höhere
## Stufen zeigen mehr Türme, Mauern und Nebengebäude. Nur die -z-Front (Angriffsfront) liegt
## im Kampfbild, Burg und Nebengebäude laufen nach hinten (+z) aus dem sichtbaren Feld.
##
## Zwei Nutzer: der Kampf (`WaveRunner`, auf dem Gelände) und die Werkbank
## `src/dev/fortress_icons.gd`, die daraus die Bilder der Festungsanzeige rendert — so zeigt
## die Karte dieselbe Festung, die im Kampf steht.

const HEX_DIR := "res://assets/models/hexagon"
const SCALE := 5.0
## Maßstab, für den die Abstände in `build` gesetzt sind. Bei einem anderen SCALE wachsen sie
## mit (`grow`), so dass die Festung als Ganzes größer wird und nicht auseinanderfällt.
const LAYOUT_SCALE := 3.0
## Halbe Tiefe der Mauerteile in Modelleinheiten. Die Mauer rückt um den Zuwachs nach hinten:
## ihre Vorderkante bleibt, wo die Monster ankommen, egal wie groß die Festung ist.
const WALL_HALF_DEPTH := 0.4
## Gierwinkel der Mauerteile: im Pack liegen die Zinnen auf +z, hier gehören sie auf die
## Feindseite (-z), der Wehrgang dahinter zu den Verteidigern. Die Teile sind mittig, die
## Drehung verschiebt nichts.
const WALL_YAW := 180.0
## Ab dieser Stufe tragen die Ecktürme Katapulte — und nur dann wirft das Wachkatapult
## (Bollwerk): es hilft beim letzten Stück einer Unit, nicht am Anfang.
const CATAPULT_TIER := 4
## Die beweglichen Teile des Katapultturms im Modell des Packs, und wo am Arm der Löffel
## sitzt (in Modelleinheiten, -z am Arm).
const CATAPULT_TURRET := "catapult_turret_blue"
const CATAPULT_ARM := "catapult_arm_blue"
const CATAPULT_BUCKET := Vector3(0.0, 0.05, -0.6)
## Ein Wurf: zum Ziel drehen, Arm hochschlagen (so weit, dass der Löffel über den Scheitel
## kippt), kurz oben halten, langsam zurück.
const CATAPULT_TURN_TIME := 0.25
const CATAPULT_SWING_TIME := 0.14
const CATAPULT_SWING_DEG := 110.0
const CATAPULT_HOLD_TIME := 0.12
const CATAPULT_RETURN_TIME := 0.7


## Setzt die Teile der Stufe unter `parent`; `front_z` ist die Mauerfront, `ground_y(x, z)`
## gibt die Höhe des Geländes (ohne Gelände: `func(_x, _z): return 0.0`). `scale` weicht nur
## in der Werkbank von SCALE ab (battle_theme_lab, Regler Festungsgröße).
static func build(parent: Node3D, tier: int, front_z: float, ground_y: Callable,
		scale: float = SCALE) -> void:
	var k := scale / LAYOUT_SCALE
	var fz := front_z + WALL_HALF_DEPTH * (scale - LAYOUT_SCALE)
	var seg := 2.0 * scale   # Weltbreite eines Mauersegments
	var put := _Put.new(parent, ground_y, scale)

	if tier <= 0:
		# Baustelle: Turmstumpf + Baugerüst. Kleine Stufe an den hinteren Rand
		# (Verteidiger-Rückseite = +z, näher zur Kamera) gezogen, weg von der
		# Monster-Front, aber noch komplett im Bild.
		put.at("building_tower_base_blue", 0.0, fz + 3.5 * k)
		put.at("building_scaffolding", seg * 0.7, fz + 3.5 * k)
		return

	# Ab Stufe 2: Wehrmauer mit Tor + Ecktürmen.
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

	# Vollausbau: Nebengebäude hinter der Mauer + Fahnen auf den Ecktürmen.
	if tier >= 4:
		put.at("building_barracks_blue", -seg * 1.3, fz + 4.5 * k, 20.0)
		put.at("building_blacksmith_blue", seg * 1.3, fz + 4.5 * k, -20.0)
		put.at("building_home_A_blue", -seg * 0.6, fz + 6.5 * k)
		put.at("building_home_B_blue", seg * 0.6, fz + 6.5 * k)
		put.at("building_church_blue", 0.0, fz + 8.0 * k)
		put.at("building_windmill_blue", -seg * 1.9, fz + 2.5 * k)
		var flag_y := 2.2 * scale
		for sx: float in [-seg * 1.5, seg * 1.5]:
			var flag := put.at("flag_blue", sx, fz)
			if flag != null:
				flag.position.y += flag_y


## Die Katapulte unter `parent`, die sich bewegen lassen: der Drehkranz jedes
## Katapultturms (ab CATAPULT_TIER). Das Modell des Packs bringt Kranz und Wurfarm als eigene
## Knoten mit — gedreht wird dort, nicht am Turm.
static func catapults(parent: Node) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for node in parent.find_children(CATAPULT_TURRET, "Node3D", true, false):
		if node.get_node_or_null(CATAPULT_ARM) is Node3D:
			out.append(node as Node3D)
	return out


## Ein Wurf: der Kranz dreht sich zu `target`, der Arm schlägt hoch, und im Scheitel kehrt
## es mit dem Punkt zurück, an dem der Stein den Löffel verlässt. Der Arm schwingt danach
## von selbst zurück. In Spielzeit wie die Monster: in der Zeitlupe wirft es langsamer, und
## der Vorhalt (WaveRunner.catapult_lead) stimmt trotzdem. Gewartet wird auf einen Timer und nicht auf den Tween: fällt der Turm mitten im Wurf weg
## (Festungsausbau), bleibt der Stein sonst für immer im Löffel.
static func fire(turret: Node3D, target: Vector3) -> Vector3:
	var arm := turret.get_node(CATAPULT_ARM) as Node3D
	# Der Pack wirft nach +z seines Kranzes: die Richtung zum Ziel im Raum des Turms. Der
	# kürzere Weg herum, sonst dreht er sich bei jedem zweiten Wurf einmal ganz.
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


## Wie viel größer als LAYOUT_SCALE die Festung steht — für alles, was an ihrer Größe hängt
## (flaches Innenfeld, Kamerafahrt beim Ausbau).
static func grow() -> float:
	return SCALE / LAYOUT_SCALE


## Setzt ein Modell (ohne .gltf-Endung) auf die Geländehöhe; null, wenn es fehlt.
class _Put:
	var _parent: Node3D
	var _ground_y: Callable
	var _scale: float

	func _init(parent: Node3D, ground_y: Callable, scale: float) -> void:
		_parent = parent
		_ground_y = ground_y
		_scale = scale

	func at(model: String, x: float, z: float, yaw := 0.0) -> Node3D:
		var path := "%s/%s.gltf" % [HEX_DIR, model]
		if not ResourceLoader.exists(path):
			return null
		var inst := (load(path) as PackedScene).instantiate() as Node3D
		inst.position = Vector3(x, float(_ground_y.call(x, z)), z)
		inst.rotation_degrees.y = yaw
		inst.scale = Vector3.ONE * _scale
		_parent.add_child(inst)
		return inst
