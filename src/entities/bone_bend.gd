class_name BoneBend
extends SkeletonModifier3D
## Dreht einzelne Knochen nach der Animation ein Stück weiter, je in ihrem eigenen Raum.
## Wie stark, steht in `influence` (SkeletonModifier3D) — 0 lässt die Animation, wie sie ist.

## Knochenname → Zusatzdrehung (Euler, rad).
var bends: Dictionary = {}


func _process_modification_with_delta(_delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	for bone_name: String in bends:
		var bone := skeleton.find_bone(bone_name)
		if bone < 0:
			continue
		skeleton.set_bone_pose_rotation(bone,
				skeleton.get_bone_pose_rotation(bone) * Quaternion.from_euler(bends[bone_name]))
