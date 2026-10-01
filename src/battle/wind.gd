class_name Wind
extends Node
## Wind in Bäumen und Gras des Kampfes, dazu die Zeit, nach der die Wolkenschatten ziehen.
##
## `sway` tauscht die Materialien eines Modells gegen den Windshader (assets/shaders/
## wind.gdshaderinc), der es genauso zeichnet, aber mit der Höhe biegt. Nur Modelle aus SWAY
## schwanken — Häuser, Zelte und Kakteen stehen im Platz `trees` mancher Themen und sollen
## stillstehen; ein neuer Baum ohne Eintrag steht still, bis er einen bekommt.
##
## Ein Wind-Knoten im Baum treibt `wind_time` (globaler Shader-Parameter, project.godot)
## mit dem skalierten delta: in der Zeitlupe (SlowMotion) wehen Bäume und Wolken langsamer.

const SHADER := preload("res://assets/shaders/wind.gdshader")
const SHADER_DOUBLE := preload("res://assets/shaders/wind_double.gdshader")
const SHADER_ALPHA := preload("res://assets/shaders/wind_alpha.gdshader")

## Ausschlag an der Spitze je Modell (Dateiname ohne Endung), als Anteil seiner Höhe.
const SWAY := {
	# Bäume
	"tree": 0.02, "pine": 0.015, "pine_snow": 0.012, "dead_tree": 0.008, "acacia": 0.015,
	"cypress": 0.02, "olive": 0.015, "blossom_tree": 0.02, "jungle_tree": 0.015,
	"palm": 0.03, "eucalyptus": 0.02, "pandanus": 0.025, "tree_fern": 0.03,
	"park_tree": 0.02, "stone_pine": 0.015, "autumn_red": 0.02, "autumn_orange": 0.02,
	"autumn_yellow": 0.02, "boab": 0.006, "vine_row": 0.015,
	# Gras
	"grass": 0.07, "dry_grass": 0.08, "fern": 0.05, "spinifex": 0.05, "reeds": 0.09,
	"flower_tuft": 0.07, "green_grass": 0.08, "dune_grass": 0.09, "wild_flowers": 0.07,
}

static var _time := 0.0
## Umgebautes Material je Ausgangsmaterial, Höhe und Ausschlag — geteilt über alle Instanzen
## und Kämpfe, damit ein Wald aus 80 Bäumen nicht 80 Materialien hat. Der Eintrag hält das
## Ausgangsmaterial mit fest: sonst könnte dessen Id nach dem Freigeben ein anderes treffen.
static var _cache := {}


func _process(delta: float) -> void:
	_time += delta
	RenderingServer.global_shader_parameter_set(&"wind_time", _time)


## Lässt `node` (ein instanziertes Modell `model`, Pfad wie in BattleTheme) im Wind
## schwanken, `strength` mal so stark wie in SWAY. Unbekannte Modelle bleiben, wie sie sind.
static func sway(node: Node3D, model: String, strength := 1.0) -> void:
	var amount: float = SWAY.get(model.get_file().get_basename(), 0.0) * strength
	if node == null or amount <= 0.0:
		return
	var meshes := node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		meshes.append(node)
	for mi: MeshInstance3D in meshes:
		if mi.mesh == null:
			continue
		var height := maxf(mi.mesh.get_aabb().end.y, 0.001)
		for s in mi.mesh.get_surface_count():
			var src := mi.get_surface_override_material(s)
			if src == null:
				src = mi.mesh.surface_get_material(s)
			if src is BaseMaterial3D:
				mi.set_surface_override_material(s, _windy(src as BaseMaterial3D, height, amount))


## Der Windshader mit den Werten von `src`. Das Ausgangsmaterial bleibt unberührt: es ist
## geladen und damit geteilt (CLAUDE.md, „Geladene Ressourcen sind geteilt").
static func _windy(src: BaseMaterial3D, height: float, amount: float) -> ShaderMaterial:
	var key := "%d/%.3f/%.4f" % [src.get_instance_id(), height, amount]
	if _cache.has(key):
		return _cache[key][1]
	var mat := ShaderMaterial.new()
	if src.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		mat.shader = SHADER_ALPHA
	elif src.cull_mode == BaseMaterial3D.CULL_DISABLED:
		mat.shader = SHADER_DOUBLE
	else:
		mat.shader = SHADER
	mat.set_shader_parameter("albedo", src.albedo_color)
	mat.set_shader_parameter("use_texture", src.albedo_texture != null)
	if src.albedo_texture != null:
		mat.set_shader_parameter("albedo_texture", src.albedo_texture)
	mat.set_shader_parameter("use_vertex_color", src.vertex_color_use_as_albedo)
	mat.set_shader_parameter("uv1_scale", src.uv1_scale)
	mat.set_shader_parameter("uv1_offset", src.uv1_offset)
	mat.set_shader_parameter("roughness", src.roughness)
	mat.set_shader_parameter("metallic", src.metallic)
	mat.set_shader_parameter("specular", src.metallic_specular)
	mat.set_shader_parameter("sway_height", height)
	mat.set_shader_parameter("sway", amount)
	_cache[key] = [src, mat]
	return mat
