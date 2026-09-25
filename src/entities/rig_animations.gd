class_name RigAnimations
extends RefCounted
## Die geteilten Animationen des KayKit-Rigs „Medium“ (assets/models/animations/).
##
## Die Skelette bringen keine eigenen Animationen mit; sie liegen in zwei Rig-Dateien mit
## demselben „Rig_Medium/Skeleton3D“-Aufbau. Jede Datei wird einmal geladen und ihre
## Library zwischen allen Figuren geteilt — wer daran etwas ändert (etwa `loop_mode`),
## ändert es für alle (CLAUDE.md „Geladene Ressourcen sind geteilt“).

const GENERAL := "res://assets/models/animations/Rig_Medium_General.glb"
const MOVEMENT := "res://assets/models/animations/Rig_Medium_MovementBasic.glb"

static var _cache: Dictionary = {}


## Idle, Hit, Death, Spawn, Throw …
static func general() -> AnimationLibrary:
	return _library(GENERAL)


## Walking, Running, Jump …
static func movement() -> AnimationLibrary:
	return _library(MOVEMENT)


static func _library(path: String) -> AnimationLibrary:
	if _cache.has(path):
		return _cache[path]
	if not ResourceLoader.exists(path):
		return null
	var scene: PackedScene = load(path)
	var inst := scene.instantiate()
	var src := inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var lib: AnimationLibrary = null
	if src != null and not src.get_animation_library_list().is_empty():
		lib = src.get_animation_library(src.get_animation_library_list()[0])
	inst.free()
	_cache[path] = lib
	return lib


## Hängt einen AnimationPlayer an `model_root`, dessen root_node auf das Modell zeigt, und
## gibt ihm die Libraries unter den Namen aus `libraries` (Name → Library).
static func attach_player(model_root: Node3D, libraries: Dictionary) -> AnimationPlayer:
	var anim := AnimationPlayer.new()
	model_root.add_child(anim)
	anim.root_node = anim.get_path_to(model_root)
	for lib_name in libraries:
		var lib: AnimationLibrary = libraries[lib_name]
		if lib != null:
			anim.add_animation_library(lib_name, lib)
	return anim
