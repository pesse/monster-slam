class_name Monster
extends Node3D
## Ein normales Monster in 3D: trägt eine aufgelöste Aufgabe (siehe TaskResolver), deren
## Prompt sein Wortschild zeigt (WordPlates), und läuft entlang +Z auf die Festung zu.
## Nur Darstellung und Bewegung; die Kampflogik liegt im WaveRunner.

## Das Monster hat die Festung erreicht.
signal reached_goal(monster: Monster)
## Das Schild soll die Alternativen der Aufgabe zeigen (ADR 0014), nach `delay` Sekunden.
signal alts_revealed(delay: float)
## Das Schild soll den ersten Buchstaben der Lösung zeigen, nach `delay` Sekunden.
signal initial_revealed(delay: float)

var monster_def: Dictionary = {}
var task: Dictionary = {}

## Aus der monster_task_rule abgeleitet, vom WaveGenerator gesetzt; nach dem Schrumpfpilz
## schon mit `damage_share` gerechnet.
var damage: int = 10
## Anteil des vollen Schadens nach dem Schrumpfpilz (`weaken`).
var damage_share := 1.0
var _full_damage := -1
var reward: int = 10
## Erfahrung für dieses Monster, beim Spawn festgelegt (Experience.for_monster): nach dem
## Treffer ist die Confidence schon angehoben.
var xp: int = Experience.MONSTER_XP_MIN

## Zeitpunkt des Spawns (ms) für die Antwortzeit-Messung.
var spawned_at_ms: int = 0

## Ich-Sicht: das Wortschild in der größeren Ausführung. Vor add_child setzen.
var screen_sized_label := false

## Die Aufgabe ist schon gemeistert: halb durchsichtig, ohne Rand. Vor add_child setzen.
var mastered := false

## Die Gruppe, aus der WordPlates die Schilder baut.
const PLATE_GROUP := &"word_plate"

var _speed: float = 2.0
## Anteil des eigenen Tempos, unter 1 nach einem Zauber (`slow_to`).
var pace := 1.0
## Zeigt das Schild die Alternativen der Aufgabe (`show_alts`)?
var alts_shown := false
## Zeigt das Schild den ersten Buchstaben der Lösung (`show_initial`)?
var initial_shown := false
## Wie lange es noch eingefroren ist (s Spielzeit).
var _frozen_left := 0.0
## Bumerang (`send_back`): Wartezeit bis zum Abflug (s), Restflugzeit (s), Ziel-z und
## Fluggeschwindigkeit (m/s).
var _back_wait := 0.0
var _back_left := 0.0
var _back_to := 0.0
var _back_speed := 0.0
## Bild der Zauber am Monster, solange sie wirken.
var _frost: FrostShell
var _aura: SlowAura
var _anim: AnimationPlayer
var _outline: ShaderMaterial
var _outline_color := Color.WHITE
var _target_z: float = 0.0
var _done: bool = false
## Das sichtbare Modell oder der Platzhalter; `flinch` bewegt nur ihn.
var _body: Node3D
var _flinch: Tween = null

## Deckkraft des Körpers eines gemeisterten Monsters.
const MASTERED_ALPHA := 0.5
## Durchsichtige Kopien der Modell-Materialien, je Original eine (geladene Materialien sind
## geteilt, siehe CONVENTIONS „Fallen“).
static var _faded := {}

## Randfarbe, solange es eingefroren ist.
const FROZEN_OUTLINE := Color(0.62, 0.86, 1.0)

## Wortart-Outline: Inverted-Hull-Shader, Farbe je Wortart (WordTypePalette).
const OUTLINE_SHADER := preload("res://assets/shaders/monster_outline.gdshader")
const OUTLINE_WORLD_WIDTH := 0.12   # Rand-Dicke in m
const OUTLINE_GLOW_STRENGTH := 1.0  # Emission-Faktor; genau 1.0, damit die Randfarbe der Legende entspricht

@onready var _plate_anchor: Marker3D = $PlateAnchor
@onready var _placeholder: MeshInstance3D = $Placeholder


## Vor add_child aufrufen. `speed_units` ist das Tempo aus dem WaveGenerator (die
## Schwierigkeit); 20 dieser Einheiten sind ein Meter.
func setup(def: Dictionary, task_data: Dictionary, target_z: float, speed_units: float) -> void:
	monster_def = def
	task = task_data
	_speed = speed_units / 20.0
	_target_z = target_z


func _ready() -> void:
	add_to_group(PLATE_GROUP)
	_apply_model()


func prompt() -> String:
	return str(task.get("prompt", "?"))


func word_color() -> Color:
	return WordTypePalette.color_for(str(task.get("lexeme_type", "")))


## Die Alternativen der Aufgabe („go, auch: walk“); Übersetzungen haben welche, ein
## Buchsatz sein Stichwort.
func alts() -> Array:
	return task.get("prompt_alt", []) as Array


## Die Lösung, die auf dem Schild einer neuen Aufgabe steht (ADR 0027), sonst leer.
func help_answer() -> String:
	if not bool(task.get("help", false)):
		return ""
	var answers: Array = task.get("accepted_answers", [])
	return str(answers[0]) if not answers.is_empty() else ""


## Der erste Buchstabe der ersten Lösung (AnswerEvaluator.initial), leer ohne Lösung.
func initial() -> String:
	var answers: Array = task.get("accepted_answers", [])
	return AnswerEvaluator.initial(str(answers[0])) if not answers.is_empty() else ""


## Hätte das Schild einen ersten Buchstaben aufzudecken? Nicht, wenn er schon steht, es keine
## Lösung gibt oder die ganze Lösung auf dem Schild steht (ADR 0027).
func can_show_initial() -> bool:
	return not initial_shown and not initial().is_empty() and help_answer().is_empty()


## Zeigt den ersten Buchstaben der Lösung nach `delay` Sekunden. False, wenn es nichts
## aufzudecken gibt (`can_show_initial`).
func show_initial(delay := 0.0) -> bool:
	if not can_show_initial():
		return false
	initial_shown = true
	initial_revealed.emit(delay)
	return true


## Wie die Zeile der Alternativen beginnt: „auch“, beim Buchsatz „Wort“.
func alt_label() -> String:
	return str(task.get("alt_label", "auch"))


## Zeigt die Alternativen nach `delay` Sekunden. False, wenn es keine gibt oder sie schon stehen.
func show_alts(delay := 0.0) -> bool:
	if alts_shown or alts().is_empty():
		return false
	alts_shown = true
	alts_revealed.emit(delay)
	return true


## Mindestens so weit (m) muss ein Monster vor `to_z` stehen, damit der Bumerang es zurückholt.
const SEND_BACK_MIN := 2.0
## Der Flug zurück: so hoch hüpft es (m), einmal um die eigene Achse.
const SEND_BACK_HOP := 1.2


## Würde der Bumerang es zurück nach `to_z` holen? Nicht, wenn es schon fliegt oder dort steht.
func can_send_back(to_z: float) -> bool:
	return not _done and _back_wait <= 0.0 and _back_left <= 0.0 \
			and position.z > to_z + SEND_BACK_MIN


## Fliegt nach `wait` Sekunden mit `speed` (m/s) zurück nach `to_z`; bis dahin läuft es weiter.
## False, wenn es nichts zurückzuholen gibt (`can_send_back`).
func send_back(to_z: float, wait: float, speed: float) -> bool:
	if not can_send_back(to_z) or speed <= 0.0:
		return false
	_back_to = to_z
	_back_speed = speed
	_back_wait = wait
	if wait <= 0.0:
		_fly_back()
	return true


func is_flying_back() -> bool:
	return _back_left > 0.0


func _fly_back() -> void:
	_back_wait = 0.0
	_back_left = maxf(0.0, position.z - _back_to) / _back_speed
	if _back_left <= 0.0 or _body == null:
		return
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_body, "rotation:y", _body.rotation.y + TAU, _back_left)
	tw.tween_property(self, "position:y", SEND_BACK_HOP, _back_left / 2.0) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(self, "position:y", 0.0, _back_left / 2.0) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## Geschrumpft (`weaken`): Körper und Schildhöhe, als Anteil; Dauer des Schrumpfens (s).
const SHRUNK_SCALE := 0.75
const SHRINK_TIME := 0.5


## Macht nur noch `share` des vollen Schadens und schrumpft; es gilt der kleinere Anteil.
## False, wenn es schon so schwach ist.
func weaken(share: float) -> bool:
	if _done or share >= damage_share:
		return false
	if _full_damage < 0:
		_full_damage = damage
		_shrink()
	damage_share = share
	damage = maxi(1, roundi(_full_damage * share))
	return true


func _shrink() -> void:
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _body != null:
		tw.tween_property(_body, "scale", _body.scale * SHRUNK_SCALE, SHRINK_TIME)
	tw.tween_property(_plate_anchor, "position:y", _plate_anchor.position.y * SHRUNK_SCALE,
			SHRINK_TIME)


## Bremst auf `factor` des eigenen Tempos; es gilt die stärkere Bremse. False, wenn es schon
## so langsam ist.
func slow_to(factor: float) -> bool:
	if factor >= pace:
		return false
	pace = clampf(factor, 0.0, 1.0)
	_update_animation()
	if _aura == null:
		_aura = SlowAura.new()
		add_child(_aura)
	return true


## Friert `seconds` lang ein (Spielzeit). Ein zweites Einfrieren verlängert nur bis zum
## längeren der beiden.
func freeze(seconds: float) -> void:
	if _done:
		return
	_frozen_left = maxf(_frozen_left, seconds)
	_update_animation()
	if _frost == null:
		_frost = FrostShell.new()
		_frost.setup(body_box())
		add_child(_frost)


func is_frozen() -> bool:
	return _frozen_left > 0.0


## Spielzeit (s) bis zum Einschlag bei gleichbleibendem Tempo, Eis eingerechnet; INF, wenn
## es steht oder schon angekommen ist.
func seconds_left() -> float:
	if _done or _speed * pace <= 0.0:
		return INF
	var from := _back_to if is_flying_back() else position.z
	return maxf(0.0, _target_z - from) / (_speed * pace) + _frozen_left + _back_left


func _update_animation() -> void:
	if _anim != null:
		_anim.speed_scale = 0.0 if is_frozen() else pace
	if _outline != null:
		_outline.set_shader_parameter("outline_color",
				FROZEN_OUTLINE if is_frozen() else _outline_color)


## Der Punkt über dem Kopf, auf den der Zipfel des Wortschilds zeigt.
func plate_anchor() -> Vector3:
	return _plate_anchor.global_position


## Im Bild ist der Körper oder das Schild über ihm. Danach trifft eine Antwort in der Ich-Sicht.
func in_view(camera: Camera3D) -> bool:
	# 1.2 m: etwa die Körpermitte.
	return FirstPersonView.sees(camera, global_position + Vector3(0.0, 1.2, 0.0)) \
			or FirstPersonView.sees(camera, plate_anchor())


## Lädt das Modell aus "model" (GLTF/GLB/scn); fehlt es, bleibt der Platzhalter sichtbar.
## Optional: "model_scale" (Standard 1.0) und "model_yaw" (Grad, Drehung in Laufrichtung).
func _apply_model() -> void:
	var path := str(monster_def.get("model", ""))
	var color := WordTypePalette.color_for(str(task.get("lexeme_type", "")))
	if path == "" or not ResourceLoader.exists(path):
		# Kein Modell: die Platzhalter-Kapsel bekommt dieselbe Wortart-Outline.
		_body = _placeholder
		_dress(_placeholder, color, 1.0)
		return
	var packed: PackedScene = load(path)
	var inst := packed.instantiate() as Node3D
	var model_scale := float(monster_def.get("model_scale", 1.0))
	inst.scale = Vector3.ONE * model_scale
	inst.rotation_degrees.y = float(monster_def.get("model_yaw", 0.0))
	add_child(inst)
	_body = inst
	_placeholder.visible = false
	_dress(inst, color, model_scale)
	_setup_animation(inst)


## Wortart-Rand oder, gemeistert, durchsichtig ohne Rand. Ohne Rand bleibt `_outline` leer.
func _dress(root: Node3D, color: Color, model_scale: float) -> void:
	if mastered:
		_fade(root)
	else:
		_apply_outline(root, color, model_scale)


func _fade(root: Node3D) -> void:
	var meshes: Array = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		meshes.append(root)
	for node in meshes:
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(i) as BaseMaterial3D
			if mat != null:
				mi.set_surface_override_material(i, faded(mat))


## Die durchsichtige Kopie von `mat`. Der Tiefen-Vorlauf hält die Teile des Modells in der
## richtigen Reihenfolge, sonst schiene der Rücken durch die Brust.
static func faded(mat: BaseMaterial3D) -> BaseMaterial3D:
	if not _faded.has(mat):
		var copy := mat.duplicate() as BaseMaterial3D
		copy.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
		copy.albedo_color.a = MASTERED_ALPHA
		_faded[mat] = copy
	return _faded[mat]


## Legt die Wortart-Outline als material_overlay auf alle Meshes unter `root`. Eine eigene
## ShaderMaterial-Instanz je Monster; die Welt-Dicke rechnet model_scale heraus.
func _apply_outline(root: Node3D, color: Color, model_scale: float) -> void:
	var mat := ShaderMaterial.new()
	_outline = mat
	_outline_color = color
	mat.shader = OUTLINE_SHADER
	mat.set_shader_parameter("outline_color", color)
	mat.set_shader_parameter("outline_width", OUTLINE_WORLD_WIDTH / maxf(model_scale, 0.001))
	mat.set_shader_parameter("glow_strength", OUTLINE_GLOW_STRENGTH)
	if root is MeshInstance3D:
		(root as MeshInstance3D).material_overlay = mat
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_overlay = mat


func _setup_animation(model_root: Node3D) -> void:
	var lib := RigAnimations.movement()
	if lib == null:
		return
	var anim := RigAnimations.attach_player(model_root, {"": lib})
	_anim = anim
	for candidate in ["Walking_A", "Walking_B", "Walking_C", "Running_A"]:
		if lib.has_animation(candidate):
			lib.get_animation(candidate).loop_mode = Animation.LOOP_LINEAR
			anim.play(candidate)
			return


## Kopfhöhe ohne Modell oder Maße (m).
const DEFAULT_HEAD_HEIGHT := 2.4
## Höhe des Kopfes als Anteil der Modellhöhe; dorthin trifft ein Pfeil.
const HEAD_SHARE := 0.82


## Kopfhöhe über dem Boden (m), aus `body_box`.
func head_height() -> float:
	var box := body_box()
	return DEFAULT_HEAD_HEIGHT if box.size == Vector3.ZERO else box.end.y * HEAD_SHARE


## Die Hülle aller Meshes des Modells im Rahmen des Monsters (m, model_scale eingerechnet).
## Ein Skinned Mesh meldet die Ruhepose. Ohne Modell leer; Eis und Schlamm zählen nicht mit.
func body_box() -> AABB:
	var box := AABB()
	var found := false
	for node in find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi == _placeholder or mi.mesh == null or not mi.visible:
			continue
		if (_frost != null and _frost.is_ancestor_of(mi)) or (_aura != null and _aura.is_ancestor_of(mi)):
			continue
		var part := global_transform.affine_inverse() * mi.global_transform * mi.get_aabb()
		box = part if not found else box.merge(part)
		found = true
	if not found or box.end.y <= 0.0:
		return AABB()
	return box


## Geschwindigkeit in m je Sekunde Spielzeit; null, wenn es steht.
func velocity() -> Vector3:
	if is_flying_back():
		return Vector3(0.0, 0.0, -_back_speed)
	return Vector3.ZERO if _done or is_frozen() else Vector3(0.0, 0.0, _speed * pace)


## Bleibt stehen und erreicht die Festung nicht mehr; das Platzen kommt später.
func halt() -> void:
	_done = true


## Neben einer Explosion bei `from`: der Körper kippt 0,55 s lang vom Knall weg und federt
## zurück. Nur das Bild, Position und Tempo bleiben.
func flinch(from: Vector3) -> void:
	if _body == null:
		return
	var away := global_position - from
	away.y = 0.0
	var axis := Vector3.UP.cross(away.normalized()) if away.length_squared() > 0.0001 \
			else Vector3.RIGHT
	# Die Achse in den Rahmen des Monsters: der Körper hängt darunter.
	axis = (global_basis.inverse() * axis).normalized()
	var rest := _body.transform
	if _flinch != null and _flinch.is_valid():
		_flinch.kill()
	_flinch = create_tween()
	_flinch.tween_method(func(t: float) -> void: _lean(rest, axis, t), 0.0, 1.0, 0.55)


## Ein Schlag, der ausschwingt: 2,5 Halbschwingungen, Dämpfung 4, bis 22° Neigung und 18 %
## Stauchung.
func _lean(rest: Transform3D, axis: Vector3, t: float) -> void:
	# (1 - t): am Ende genau wieder in Ruhe, nicht nur fast.
	var swing := sin(t * PI * 2.5) * exp(-t * 4.0) * (1.0 - t)
	var squash := 1.0 - 0.18 * swing
	var basis := Basis(axis, deg_to_rad(22.0) * swing) \
			* Basis.from_scale(Vector3(1.0 / sqrt(squash), squash, 1.0 / sqrt(squash)))
	_body.transform = Transform3D(basis * rest.basis, rest.origin)


func _physics_process(delta: float) -> void:
	if _done:
		return
	if _back_wait > 0.0:
		_back_wait -= delta
		if _back_wait <= 0.0:
			_fly_back()
	if is_flying_back():
		var step := minf(delta, _back_left)
		position.z -= _back_speed * step
		_back_left -= step
		return
	if is_frozen():
		_frozen_left = maxf(0.0, _frozen_left - delta)
		if _frost != null:
			_frost.tick(_frozen_left)
		if not is_frozen():
			_update_animation()
			if _frost != null:
				_frost.shatter()
				_frost = null
		return
	position.z += _speed * pace * delta
	if position.z >= _target_z:
		_done = true
		EventBus.monster_reached_fortress.emit(monster_def, task, damage)
		reached_goal.emit(self)
		queue_free()
