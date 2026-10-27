class_name BonePile
extends Node3D
## Ein Knochenhaufen auf dem Feld (Zauber Knochenhaufen, ADR 0014): springt aus dem
## besiegten Monster auf, klappert, wenn eines hineinläuft (`rattle`), und sinkt am Ende der
## Welle in den Boden (`crumble`). Was er aufhält, entscheidet der SpellCaster.

const MODEL := preload("res://assets/models/forge/bone_pile.glb")

## Größe des Modells (1.6 m breit) im Kampf, neben Monstern mit model_scale 2.4.
const SIZE := 2.0

## So lange springt der Haufen auf (s), so hoch fliegen die Knochen dabei (m).
const POP_TIME := 0.35
const POP_HOP := 0.6
## So lange sinkt er am Ende ein (s).
const SINK_TIME := 0.8

var _model: Node3D
var _rattle: Tween


func _ready() -> void:
	_model = MODEL.instantiate()
	_model.scale = Vector3.ONE * SIZE
	_model.rotation.y = randf_range(-0.5, 0.5)
	add_child(_model)


## Springt aus dem Monster auf: wächst aus der Mitte und landet mit einem Hüpfer.
func pop() -> void:
	scale = Vector3.ONE * 0.2
	_model.position.y = POP_HOP
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector3.ONE, POP_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_model, "position:y", 0.0, POP_TIME) \
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


## Ein Monster ist hineingelaufen: der Haufen wackelt kurz.
func rattle() -> void:
	if _rattle != null and _rattle.is_valid():
		_rattle.kill()
	_rattle = create_tween()
	for k in 4:
		var side := 0.12 * (1.0 - k / 4.0) * (1.0 if k % 2 == 0 else -1.0)
		_rattle.tween_property(_model, "rotation:z", side, 0.06)
	_rattle.tween_property(_model, "rotation:z", 0.0, 0.06)


## Sinkt in den Boden und gibt sich frei.
func crumble() -> void:
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "position:y", position.y - 0.9, SINK_TIME)
	tw.tween_property(self, "scale", Vector3(1.2, 0.4, 1.2), SINK_TIME)
	tw.chain().tween_callback(queue_free)
