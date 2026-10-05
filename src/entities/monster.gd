class_name Monster
extends Node3D
## Ein normales Monster in 3D: trägt eine aufgelöste Aufgabe (den Prompt zeigt sein
## Wortschild, siehe WordPlates) und bewegt sich entlang +Z auf die Festung zu. Präsentation +
## Bewegung; Kampf-/Wellenlogik liegt im WaveRunner. Das Monster kennt die Aufgabe
## nur als { prompt, accepted_answers, learnable_id, ... } (siehe TaskResolver).

## Wird ausgelöst, wenn dieses Monster die Festung erreicht (Node-Handling im WaveRunner).
signal reached_goal(monster: Monster)
## Das Schild soll jetzt auch die Alternativen der Aufgabe zeigen (Zauber, ADR 0014) —
## nach `delay` Sekunden, wenn der Lichtvorhang des Zaubers es erreicht (SpellFx).
signal alts_revealed(delay: float)

var monster_def: Dictionary = {}
var task: Dictionary = {}

## Aus der monster_task_rule abgeleitet und vom WaveGenerator gesetzt.
var damage: int = 10
var reward: int = 10
## Erfahrung für dieses Monster, vom WaveGenerator aus seiner Schwierigkeit bestimmt
## (Experience.for_monster) und beim SPAWN festgelegt: nach dem Treffer ist die
## Confidence schon angehoben, und dann wäre nicht mehr zu sehen, ob die Aufgabe vorher
## gemeistert war. Verbucht wird sie im WaveRunner (PlayerLevel).
var xp: int = Experience.MONSTER_XP_MIN

## Zeitpunkt des Spawns (ms) für die Antwortzeit-Messung; vom WaveRunner gesetzt.
var spawned_at_ms: int = 0

## Ich-Sicht: das Wortschild steht in der größeren Ausführung — dort muss es auf jede
## Entfernung lesbar sein. Vor add_child setzen.
var screen_sized_label := false

## Die Gruppe, aus der WordPlates die Schilder baut.
const PLATE_GROUP := &"word_plate"

var _speed: float = 2.0
## Anteil des eigenen Tempos, mit dem es läuft — unter 1 nach einem Zauber (`slow_to`).
## Das Tempo selbst bleibt die Schwierigkeit; das hier bremst nur.
var pace := 1.0
## Zeigt das Schild die Alternativen der Aufgabe (`reveal_alts`)?
var alts_shown := false
## Wie lange es noch eingefroren ist (s Spielzeit).
var _frozen_left := 0.0
## Das Eis, solange es eingefroren ist, und der Schlamm, solange es gebremst ist — das Bild
## der Zauber am Monster (FrostShell, SlowAura).
var _frost: FrostShell
var _aura: SlowAura
var _anim: AnimationPlayer
var _outline: ShaderMaterial
var _outline_color := Color.WHITE
var _target_z: float = 0.0
var _done: bool = false
## Was sichtbar ist — das Modell oder der Platzhalter. `flinch` wackelt nur daran, damit
## Position, Schild und Bahn unberührt bleiben.
var _body: Node3D
var _flinch: Tween = null

## So färbt sich der Rand, solange es eingefroren ist.
const FROZEN_OUTLINE := Color(0.62, 0.86, 1.0)

## Wortart-Outline: Inverted-Hull-Shader, Farbe je Wortart (siehe WordTypePalette).
const OUTLINE_SHADER := preload("res://assets/shaders/monster_outline.gdshader")
const OUTLINE_WORLD_WIDTH := 0.12   # gewünschte Rand-Dicke in Welteinheiten
const OUTLINE_GLOW_STRENGTH := 1.0  # Emission-Faktor; genau 1.0 => kein Kanal-Clipping,
                                    # Outline-Farbe == Legenden-Farbe. Der Glow-Halo kommt
                                    # aus dem WorldEnvironment (niedrige HDR-Schwelle).

@onready var _plate_anchor: Marker3D = $PlateAnchor
@onready var _placeholder: MeshInstance3D = $Placeholder


## Muss VOR add_child aufgerufen werden, damit _ready Label/Modell korrekt setzt.
## `speed_units` ist die vom WaveGenerator aus der Schwierigkeit (Grundschwierigkeit
## der Aufgabe + Confidence + Wellenfaktor) berechnete Geschwindigkeit; sie wird hier
## auf 3D-Einheiten/s heruntergerechnet. Geschwindigkeit IST Schwierigkeit — das Monster
## selbst trägt kein eigenes Tempo mehr.
func setup(def: Dictionary, task_data: Dictionary, target_z: float, speed_units: float) -> void:
	monster_def = def
	task = task_data
	_speed = speed_units / 20.0
	_target_z = target_z


func _ready() -> void:
	add_to_group(PLATE_GROUP)
	_apply_model()


## Was auf dem Wortschild steht.
func prompt() -> String:
	return str(task.get("prompt", "?"))


## Die Farbe der Wortart, wie die Outline am Modell (WordTypePalette).
func word_color() -> Color:
	return WordTypePalette.color_for(str(task.get("lexeme_type", "")))


## Die Alternativen der Aufgabe („go, auch: walk"), wie sie das Reveal zeigt. Nur
## Übersetzungen haben welche.
func alts() -> Array:
	return task.get("prompt_alt", []) as Array


## Zeigt die Alternativen am Schild, sichtbar nach `delay` Sekunden. False, wenn es keine
## gibt oder sie schon stehen.
func show_alts(delay := 0.0) -> bool:
	if alts_shown or alts().is_empty():
		return false
	alts_shown = true
	alts_revealed.emit(delay)
	return true


## Bremst auf `factor` des eigenen Tempos. Zwei Bremsen multiplizieren sich nicht: es
## gilt die stärkere. False, wenn es schon so langsam ist.
func slow_to(factor: float) -> bool:
	if factor >= pace:
		return false
	pace = clampf(factor, 0.0, 1.0)
	_update_animation()
	if _aura == null:
		_aura = SlowAura.new()
		add_child(_aura)
	return true


## Friert `seconds` lang ein (Spielzeit, steht also auch in der Pause). Ein zweites
## Einfrieren verlängert nicht über das längere hinaus.
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


func _update_animation() -> void:
	if _anim != null:
		_anim.speed_scale = 0.0 if is_frozen() else pace
	if _outline != null:
		_outline.set_shader_parameter("outline_color",
				FROZEN_OUTLINE if is_frozen() else _outline_color)


## Der Punkt über dem Kopf, auf den der Zipfel des Wortschilds zeigt.
func plate_anchor() -> Vector3:
	return _plate_anchor.global_position


## Im Bild heißt: der Körper oder das Schild über ihm. Aus der Nähe ist das Schild über
## dem Bildrand, von weit weg der Körper hinter dem Schild zu klein, um zu zählen. Danach
## trifft eine Antwort in der Ich-Sicht (WaveRunner._hittable) und steht ein Wortschild.
func in_view(camera: Camera3D) -> bool:
	return FirstPersonView.sees(camera, global_position + Vector3(0.0, 1.2, 0.0)) \
			or FirstPersonView.sees(camera, plate_anchor())


## Lädt das 3D-Modell aus dem "model"-Feld (GLTF/GLB/scn). Fehlt es oder existiert
## die Datei (noch) nicht, bleibt das Platzhalter-Mesh sichtbar.
## Optionale JSON-Felder: "model_scale" (Standard 1.0) und "model_yaw" (Grad,
## um das Modell in Laufrichtung zu drehen).
func _apply_model() -> void:
	var path := str(monster_def.get("model", ""))
	var color := WordTypePalette.color_for(str(task.get("lexeme_type", "")))
	if path == "" or not ResourceLoader.exists(path):
		# Kein Modell -> Platzhalter-Kapsel behält die Wortart-Outline (Konsistenz).
		_apply_outline(_placeholder, color, 1.0)
		_body = _placeholder
		return
	var packed: PackedScene = load(path)
	var inst := packed.instantiate() as Node3D
	var model_scale := float(monster_def.get("model_scale", 1.0))
	inst.scale = Vector3.ONE * model_scale
	inst.rotation_degrees.y = float(monster_def.get("model_yaw", 0.0))
	add_child(inst)
	_body = inst
	_placeholder.visible = false
	_apply_outline(inst, color, model_scale)
	_setup_animation(inst)


## Legt die Wortart-Outline als material_overlay auf alle MeshInstance3D unterhalb von
## `root`. Eine eigene ShaderMaterial-Instanz je Monster (kein geteiltes preload), damit
## jede Wortart ihre Farbe bekommt, ohne importierte GLB-Materialien anzufassen.
## Die Welt-Dicke bleibt trotz model_scale konstant, indem sie herausgerechnet wird.
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


## KayKit-Charaktere haben keine eigenen Animationen — sie kommen aus der geteilten
## Bewegungs-Library (RigAnimations); das Monster loopt "Walking_A".
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


## Ohne Modell (Platzhalter) oder ohne Maße: ungefähr die Kopfhöhe der Modelle.
const DEFAULT_HEAD_HEIGHT := 2.4
## Der Kopf sitzt so weit oben am Modell (Anteil der Höhe) — dorthin trifft ein Pfeil.
const HEAD_SHARE := 0.82


## Wie hoch über dem Boden der Kopf ist: aus der Hülle des Körpers (`body_box`).
func head_height() -> float:
	var box := body_box()
	return DEFAULT_HEAD_HEIGHT if box.size == Vector3.ZERO else box.end.y * HEAD_SHARE


## Die Hülle aller Meshes des Modells im Rahmen des Monsters, in Metern der Welt
## (model_scale steckt in den Transformen). Ein Skinned Mesh meldet die Hülle der Ruhepose —
## für Ziel und Eishülle genau genug. Ohne Modell: eine leere Hülle (Größe 0). Die Effekte
## am Monster (Eis, Schlamm) zählen nicht mit.
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


## Wie schnell und wohin es gerade läuft (Einheiten je Sekunde Spielzeit): geradeaus auf die
## Festung zu, oder gar nicht, wenn es steht. Das Wachkatapult hält damit vor.
func velocity() -> Vector3:
	return Vector3.ZERO if _done or is_frozen() else Vector3(0.0, 0.0, _speed * pace)


## Bleibt stehen, wo es ist, und erreicht die Festung nicht mehr — getroffen, aber das
## Platzen kommt später (Sturmangriff in der Ich-Sicht).
func halt() -> void:
	_done = true


## Neben einer Explosion (Blast) bei `from`: der Körper duckt sich, kippt vom Knall weg und
## federt zurück. Nur das Bild — Position, Tempo und Aufgabe bleiben, wie sie sind.
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


## Ein Schlag, der ausschwingt: kippt bis ~20° und staucht, dann gedämpft zurück.
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
