class_name CatapultStone
extends Node3D
## Ein Stein des Wachkatapults (Bollwerk), ein facettierter Brocken; den Aufschlag zeigt
## `Blast`. Fliegt anders als der Pfeil in Spielzeit: das Katapult hält auf den Ort vor, an
## dem das Monster beim Einschlag steht, das stimmt nur mit derselben Uhr.

## Radius in m.
const RADIUS := 0.75
const COLOR := Color(0.52, 0.53, 0.56)
## Umdrehungen je Sekunde um eine schräge Achse.
const SPIN := 1.3

var _rock: MeshInstance3D


func _ready() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = RADIUS
	sphere.height = RADIUS * 1.7
	sphere.radial_segments = 7
	sphere.rings = 3
	# Flache Facetten: ohne geteilte Ecken bekommt jedes Dreieck seine eigene Normale.
	var st := SurfaceTool.new()
	st.create_from(sphere, 0)
	st.deindex()
	st.generate_normals()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR
	mat.roughness = 0.95
	_rock = MeshInstance3D.new()
	_rock.mesh = st.commit()
	_rock.material_override = mat
	add_child(_rock)


## Fliegt von hier nach `to`, auf einem Bogen `lift` hoch über der Geraden (dieselbe
## Bahn wie der Pfeil, `Arrow.path_point`), in `time` Sekunden, und kehrt dort zurück.
func fly(to: Vector3, lift: float, time: float) -> void:
	var from := global_position
	var axis := Vector3(1.0, 0.3, 0.2).normalized()
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		global_position = Arrow.path_point(from, to, lift, t)
		_rock.transform.basis = Basis(axis, t * time * SPIN * TAU), 0.0, 1.0, time)
	await tw.finished
