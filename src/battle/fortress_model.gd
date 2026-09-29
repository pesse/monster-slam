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
const SCALE := 4.0
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


## Setzt die Teile der Stufe unter `parent`; `front_z` ist die Mauerfront, `ground_y(x, z)`
## gibt die Höhe des Geländes (ohne Gelände: `func(_x, _z): return 0.0`).
static func build(parent: Node3D, tier: int, front_z: float, ground_y: Callable) -> void:
	var k := grow()
	var fz := front_z + WALL_HALF_DEPTH * (SCALE - LAYOUT_SCALE)
	var seg := 2.0 * SCALE   # Weltbreite eines Mauersegments
	var put := _Put.new(parent, ground_y)

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
		var end_tower := "building_tower_catapult_blue" if tier >= 4 else "building_tower_B_blue"
		put.at(end_tower, -seg * 1.5, fz)
		put.at(end_tower, seg * 1.5, fz)

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
		var flag_y := 2.2 * SCALE
		for sx: float in [-seg * 1.5, seg * 1.5]:
			var flag := put.at("flag_blue", sx, fz)
			if flag != null:
				flag.position.y += flag_y


## Wie viel größer als LAYOUT_SCALE die Festung steht — für alles, was an ihrer Größe hängt
## (flaches Innenfeld, Kamerafahrt beim Ausbau).
static func grow() -> float:
	return SCALE / LAYOUT_SCALE


## Setzt ein Modell (ohne .gltf-Endung) auf die Geländehöhe; null, wenn es fehlt.
class _Put:
	var _parent: Node3D
	var _ground_y: Callable

	func _init(parent: Node3D, ground_y: Callable) -> void:
		_parent = parent
		_ground_y = ground_y

	func at(model: String, x: float, z: float, yaw := 0.0) -> Node3D:
		var path := "%s/%s.gltf" % [HEX_DIR, model]
		if not ResourceLoader.exists(path):
			return null
		var inst := (load(path) as PackedScene).instantiate() as Node3D
		inst.position = Vector3(x, float(_ground_y.call(x, z)), z)
		inst.rotation_degrees.y = yaw
		inst.scale = Vector3.ONE * SCALE
		_parent.add_child(inst)
		return inst
