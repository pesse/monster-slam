class_name SpellFx
extends Node3D
## Das Bild der Zauber auf dem Feld (ADR 0014). Was ein Zauber TUT, steht im SpellCaster;
## hier steht nur, wie es aussieht und klingt. Kampf (WaveRunner) und Werkbank
## (battle_theme_lab, Reiter Zauber) nutzen denselben Knoten, damit die Werkbank zeigt, was
## der Kampf zeigt.
##
## Was am Monster hängt, macht das Monster selbst: die Eishülle (FrostShell) beim Einfrieren
## und den Schlamm (SlowAura) beim Bremsen. Hier entsteht, was zum Feld gehört:
## - Drittes Auge, Orakelblick: ein Lichtvorhang fährt von der Festung zum Spawn; ein Schild
##   geht auf, wenn er sein Monster erreicht (`reveal_delay`).
## - Sumpf: unter jedem Monster spritzt es grün auf. Schwere Luft zusätzlich Bodennebel über
##   dem Feld, solange die Welle läuft (`haze`), und jedes neue Monster spritzt beim
##   Erscheinen (`on_spawn`).
## - Frost: ein Eisring läuft von der Festung über das Feld, Schnee fällt, das Bild wird kalt.
## - Donnerschlag: das Bild verdunkelt sich (Anlauf), dann schlägt nacheinander auf jedes
##   Monster ein Blitz ein — Plasma, Brandfleck, Wackeln (`bolt`).
## - Lebensquell, Eisenhaut: eine Lichtsäule mit aufsteigenden Funken an der Festung.
## Alle Zauber leuchten dazu kurz in ihrer Farbe über dem ganzen Bild (`veil`, damit es auch
## die Ich-Sicht sieht, die der Festung den Rücken zukehrt); das Banner mit Bild und Namen
## macht die SpellBanner.
##
## Zeiten laufen nach Spielzeit wie bei den anderen Effekten: in der Zeitlupe dehnt sich auch
## der Zauber, in der Pause steht er.

const SHOCKWAVE_SHADER := preload("res://assets/shaders/shockwave.gdshader")
const SPARK_SHADER := preload("res://assets/shaders/spark.gdshader")
const FOG_SHADER := preload("res://assets/shaders/ground_fog.gdshader")
const CURTAIN_SHADER := preload("res://assets/shaders/light_curtain.gdshader")
const MARK_SHADER := preload("res://assets/shaders/ground_mark.gdshader")

## Die Farbe je Wirkung — dieselbe wie der Schein im Icon (assets/ui/spells/).
const COLORS := {
	"reveal_alts": Color(0.72, 0.45, 1.0),
	"slow": Color(0.55, 0.85, 0.2),
	"freeze": Color(0.62, 0.86, 1.0),
	"strike": Color(0.6, 0.78, 1.0),
	"heal": Color(1.0, 0.35, 0.4),
	"armor": Color(0.85, 0.9, 1.0),
}
## Schwere Luft: blaugrauer Dunst.
const HAZE_COLOR := Color(0.55, 0.6, 0.72)
## Höhen der Nebelschichten (m); oben dünner. Unter der Augenhöhe der Ich-Sicht.
## Viele dünne Schichten statt weniger dichter: wo eine Schicht ein Monster schneidet, bleibt
## die Stufe klein.
const HAZE_LAYERS := [0.1, 0.28, 0.46, 0.64, 0.82, 1.0]
const HAZE_DENSITY := [0.42, 0.36, 0.3, 0.24, 0.16, 0.09]
## Der Ton je Wirkung. Noch ohne eigenen Ton: Schwere Luft (klingt wie Sumpf), Lebensquell
## und der Donnerschlag (Bestand); bestellt in assets/audio/sfx/SPELLS_BRIEF.md.
const SOUNDS := {
	"reveal_alts": &"spell_reveal",
	"slow": &"spell_slow",
	"freeze": &"spell_freeze",
	"heal": &"slow_mo_out",
	"armor": &"spell_armor",
}

## So lange fährt der Lichtvorhang von der Festung bis zum Spawn (s).
const SWEEP_TIME := 0.9
## Donnerschlag: so lange verdunkelt sich das Bild, bevor der erste Blitz fällt, und so viel
## später fällt jeder weitere (s).
const STRIKE_WINDUP := 0.35
const STRIKE_STAGGER := 0.09
## Wie lange ein Brandfleck liegt (s).
const SCORCH_TIME := 5.0
## So lange läuft das Bild eines Zaubers, bis das Wellenende es nicht mehr verdeckt (s):
## je Wirkung ab dem Wirken, beim Donnerschlag ab dem letzten Einschlag (Blitz, Plasma,
## Aufhellen). Der Brandfleck und der Nebel zählen nicht, sie liegen nur.
const SETTLE := {
	"reveal_alts": SWEEP_TIME + 0.6,
	"slow": 1.0,
	"freeze": 1.2,
	"heal": 1.5,
	"armor": 1.5,
}
const STRIKE_SETTLE := 1.1

## Das letzte laufende Zauberbild ist durch (`is_busy` wieder false). Das Wellenende wartet
## darauf (WaveRunner._check_end), damit die Abrechnung den Zauber nicht verdeckt.
signal settled

## Die Fläche über dem Bild, die sich verdunkelt und aufleuchtet (eine ColorRect über dem
## Feld, unter dem HUD). Ohne sie bleibt das Bild, wie es ist.
var veil: ColorRect
## Lässt die Kamera wackeln: `shake.call(stärke)`.
var shake := func(_magnitude: float) -> void: pass
## Die Mauerfront (Ziel der Monster), der Spawn, die halbe Breite der Bahn und die Mitte
## der Festung.
var front_z := 16.5
var back_z := -24.0
var half_width := 8.0
var fortress := Vector3(0.0, 0.0, 20.0)

var _haze: Node3D
var _haze_mats: Array[ShaderMaterial] = []
var _busy := 0
var _veil_tween: Tween


## Der Moment des Zaubers auf `field` (die Monster auf dem Feld). Vor `SpellCaster.cast`:
## der Donnerschlag braucht seinen Anlauf, bevor `bolt` die Blitze schickt.
func play(spell: Dictionary, field: Array[Monster]) -> void:
	var effect := str(spell.get("effect", ""))
	var whole_wave := str((spell.get("params", {}) as Dictionary).get("scope", "field")) == "wave"
	var color: Color = COLORS.get(effect, Color.WHITE)
	if SOUNDS.has(effect):
		Sfx.play(SOUNDS[effect])
	if SETTLE.has(effect):
		_hold(SETTLE[effect])
	match effect:
		"reveal_alts":
			_sweep(color, whole_wave)
			_veil(color, 0.18, 0.08, 0.1, 0.6)
		"slow":
			for monster in field:
				_splash(monster.position, color)
			if whole_wave:
				haze(true)
			_veil(HAZE_COLOR if whole_wave else color, 0.22, 0.1, 0.2, 0.8)
		"freeze":
			_ring(Vector3(0.0, 0.1, front_z), color, (front_z - back_z) * 1.7, 0.9)
			_snow()
			_veil(color, 0.35, 0.06, 0.25, 0.9)
			shake.call(0.3)
		"strike":
			# Bis der erste Blitz fällt; danach hält jeder Blitz selbst (`bolt`).
			_hold(STRIKE_WINDUP)
			# Anlauf: das Bild wird dunkel, die Erde grollt.
			_veil(Color(0.03, 0.04, 0.12), 0.65, STRIKE_WINDUP, 0.0, 0.0)
			shake.call(0.25)
		"heal", "armor":
			_restore(color)
			_veil(color, 0.22, 0.08, 0.15, 0.9)


## Läuft noch ein Zauberbild, das das Wellenende abwarten soll?
func is_busy() -> bool:
	return _busy > 0


## Hält `is_busy` `seconds` lang (Spielzeit: in der Pause steht auch das Bild).
func _hold(seconds: float) -> void:
	_busy += 1
	await get_tree().create_timer(seconds, false).timeout
	_busy -= 1
	if _busy == 0:
		settled.emit()


## Wann das Schild von `monster` aufgeht: wenn der Lichtvorhang es erreicht (s).
func reveal_delay(monster: Monster) -> float:
	return clampf(inverse_lerp(front_z, back_z, monster.position.z), 0.0, 1.0) * SWEEP_TIME


## Der `index`-te Blitz des Donnerschlags auf `monster`. Es steht schon (halt) und gilt als
## erledigt; wenn der Blitz einschlägt, ruft `landed` den Aufrufer, der es freigibt.
func bolt(monster: Monster, index: int, landed: Callable) -> void:
	_busy += 1
	var at := monster.position
	var tint := Color(0.45, 0.62, 1.0)
	await get_tree().create_timer(STRIKE_WINDUP + index * STRIKE_STAGGER, false).timeout
	var line := LightningBolt.new()
	line.setup(at + Vector3(0.0, 0.6, 0.0), tint)
	add_child(line)
	var fx := Blast.new()
	fx.setup(tint, 1.0, true)
	fx.position = at
	add_child(fx)
	_scorch(at)
	# Jeder Einschlag hellt das dunkle Bild auf; der erste am stärksten.
	_veil(Color(0.7, 0.8, 1.0), 0.5 if index == 0 else 0.3, 0.0, 0.03, 0.45 if index == 0 else 0.25)
	shake.call(1.1 if index == 0 else 0.6)
	Sfx.play(&"fortress_hit" if index == 0 else &"monster_kill")
	landed.call()
	_busy -= 1
	_hold(STRIKE_SETTLE)


## Ein Monster erscheint und bekommt, was für die ganze Welle gewirkt wurde (`effects`, aus
## SpellCaster.on_spawn): unter Schwere Luft spritzt es dort auf, mit dem Ton des Sumpfs, nur
## leiser — er kommt mit jedem Monster. Der Orakelblick braucht nichts: das Schild springt
## ohnehin auf (WordPlate).
func on_spawn(monster: Monster, effects: PackedStringArray) -> void:
	if effects.has("slow"):
		_splash(monster.position, COLORS["slow"])
		Sfx.play(&"spell_slow_spawn")


## Schwere Luft: Dunst über dem Feld an (`on`) oder aus. Bleibt bis zum Ende der Welle.
func haze(on: bool) -> void:
	if on and _haze == null:
		_haze = _haze_layers()
		_haze_mats.assign(_haze.get_meta("materials"))
		add_child(_haze)
		_haze_fade(0.0, 1.0, 2.0)
	elif not on and _haze != null:
		var old := _haze
		_haze = null
		_haze_fade(1.0, 0.0, 1.2).tween_callback(old.queue_free)


func _haze_fade(from: float, to: float, time: float) -> Tween:
	var mats := _haze_mats.duplicate()
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void:
		for mat: ShaderMaterial in mats:
			mat.set_shader_parameter("fade", v), from, to, time)
	return tw


## Je ein Stück von allem, was hier entsteht — für FxWarmup, damit der erste Zauber im Kampf
## nicht auf seine Shader wartet. FxWarmup stellt sie bei `at` auf und gibt sie selbst wieder
## frei; der Blitz steht im Ursprung der Welt und zielt deshalb selbst auf `at`.
static func specimens(at: Vector3) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var bolt_line := LightningBolt.new()
	bolt_line.setup(at)
	out.append(bolt_line)
	var plasma := Blast.new()
	plasma.setup(COLORS["strike"], 1.0, true)
	out.append(plasma)
	var shell := FrostShell.new()
	out.append(shell)
	out.append(SlowAura.new())
	var curtain := MeshInstance3D.new()
	curtain.mesh = _curtain_quad(4.0, 4.0)
	var curtain_mat := _curtain_material(COLORS["reveal_alts"], 1.0)
	curtain_mat.set_shader_parameter("fade", 1.0)
	curtain.material_override = curtain_mat
	out.append(curtain)
	var fx := SpellFx.new()
	var fog := fx._haze_layers()
	fog.position = at
	out.append(fog)
	fx.free()
	return out


## Der Lichtvorhang von „Drittes Auge"/„Orakelblick": quer über die Bahn, von der Mauer bis
## zum Spawn. Der Orakelblick ist höher und heller und zieht Gold mit.
func _sweep(color: Color, whole_wave: bool) -> void:
	var height := 11.0 if whole_wave else 7.0
	var curtain := MeshInstance3D.new()
	curtain.mesh = _curtain_quad((half_width + 6.0) * 2.0, height)
	var mat := _curtain_material(color.lerp(Color(1.0, 0.85, 0.4), 0.3) if whole_wave else color,
			4.5 if whole_wave else 3.5)
	curtain.material_override = mat
	curtain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	curtain.position = Vector3(0.0, height * 0.5, front_z)
	add_child(curtain)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(curtain, "position:z", back_z, SWEEP_TIME).set_trans(Tween.TRANS_SINE)
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("fade", v), 0.0, 1.0, 0.12)
	tw.chain().tween_method(func(v: float) -> void: mat.set_shader_parameter("fade", v),
			1.0, 0.0, 0.35)
	tw.chain().tween_callback(curtain.queue_free)
	# Funken, die der Vorhang hinter sich lässt.
	var p := _motes(color, 70, 1.4)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(half_width + 2.0, 0.3, (front_z - back_z) * 0.5)
	p.position = Vector3(0.0, 0.5, (front_z + back_z) * 0.5)
	p.explosiveness = 0.0
	p.lifetime = 1.2
	p.one_shot = true
	add_child(p)
	_free_later(p, 2.6)


## Sumpf: der Schlamm spritzt unter dem Monster auf.
func _splash(at: Vector3, color: Color) -> void:
	_ring(at + Vector3(0.0, 0.08, 0.0), color, 9.0, 0.6)
	var p := _motes(color, 40, 0.9)
	p.scale_amount_min = 0.14
	p.scale_amount_max = 0.26
	p.position = at + Vector3(0.0, 0.2, 0.0)
	p.direction = Vector3.UP
	p.spread = 40.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 6.0
	p.gravity = Vector3(0.0, -14.0, 0.0)
	add_child(p)
	_free_later(p, 1.2)


## Lebensquell, Eisenhaut: Lichtsäule an der Festung, Funken steigen auf, ein Ring läuft.
func _restore(color: Color) -> void:
	var column := MeshInstance3D.new()
	var tube := CylinderMesh.new()
	tube.top_radius = 7.0
	tube.bottom_radius = 7.0
	tube.height = 18.0
	tube.cap_top = false
	tube.cap_bottom = false
	tube.radial_segments = 48
	column.mesh = tube
	var mat := _curtain_material(color, 3.5)
	mat.set_shader_parameter("side_fade", 0.0)
	mat.set_shader_parameter("streaks", 40.0)
	column.material_override = mat
	column.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	column.position = fortress + Vector3(0.0, 9.0, 0.0)
	add_child(column)
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("fade", v), 0.0, 1.0, 0.15)
	tw.tween_interval(0.5)
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("fade", v), 1.0, 0.0, 0.9)
	tw.tween_callback(column.queue_free)
	_ring(fortress + Vector3(0.0, 0.15, 0.0), color, 30.0, 0.8)
	var p := _motes(color, 160, 1.8)
	p.scale_amount_min = 0.12
	p.scale_amount_max = 0.22
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(7.0, 0.5, 6.0)
	p.position = fortress + Vector3(0.0, 0.5, 0.0)
	p.direction = Vector3.UP
	p.spread = 12.0
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 8.0
	p.gravity = Vector3(0.0, 1.5, 0.0)
	p.explosiveness = 0.4
	add_child(p)
	_free_later(p, 2.6)


## Frost: Schnee über dem ganzen Feld.
func _snow() -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.5
	p.amount = 320
	p.lifetime = 2.4
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(half_width + 6.0, 2.0, (front_z - back_z) * 0.5)
	p.position = Vector3(0.0, 8.0, (front_z + back_z) * 0.5)
	p.direction = Vector3.DOWN
	p.spread = 25.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.0
	p.gravity = Vector3(0.0, -3.0, 0.0)
	p.scale_amount_min = 0.16
	p.scale_amount_max = 0.3
	p.mesh = _spark_quad(Color(0.9, 0.96, 1.0), 1.2, 2.2)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.set_color(1, Color(1, 1, 1, 0))
	ramp.add_point(0.15, Color(1, 1, 1, 1))
	ramp.add_point(0.8, Color(1, 1, 1, 0.8))
	p.color_ramp = ramp
	p.emitting = true
	add_child(p)
	_free_later(p, 3.6)


## Ein dunkler Brandfleck, der noch kurz blau glimmt und dann vergeht.
func _scorch(at: Vector3) -> void:
	var mark := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 4.5
	quad.orientation = PlaneMesh.FACE_Y
	var mat := ShaderMaterial.new()
	mat.shader = MARK_SHADER
	mat.set_shader_parameter("color", Color(0.04, 0.04, 0.05, 0.85))
	mat.set_shader_parameter("glow_color", Vector3(0.45, 0.65, 1.0))
	mat.set_shader_parameter("glow", 3.0)
	mat.set_shader_parameter("seed", randf())
	mark.mesh = quad
	mark.material_override = mat
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mark.position = at + Vector3(0.0, 0.04, 0.0)
	mark.rotation.y = randf() * TAU
	add_child(mark)
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("glow", v), 3.0, 0.0, 1.2)
	tw.tween_interval(SCORCH_TIME - 2.4)
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("fade", v), 1.0, 0.0, 1.2)
	tw.tween_callback(mark.queue_free)


## Ein Ring am Boden, der nach außen läuft (wie die Druckwelle des Blast).
func _ring(at: Vector3, color: Color, size: float, time: float) -> void:
	var ring := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size
	quad.orientation = PlaneMesh.FACE_Y
	var mat := ShaderMaterial.new()
	mat.shader = SHOCKWAVE_SHADER
	mat.set_shader_parameter("color", color)
	mat.set_shader_parameter("energy", 3.0)
	ring.mesh = quad
	ring.material_override = mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position = at
	add_child(ring)
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("progress", v), 0.0, 1.0, time)
	tw.tween_callback(ring.queue_free)


## Leuchtende Funken in `color`, die einmal ausgestoßen werden.
func _motes(color: Color, amount: int, lifetime: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = lifetime
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.5
	p.direction = Vector3.UP
	p.spread = 30.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 3.0
	p.gravity = Vector3(0.0, 0.5, 0.0)
	p.damping_min = 0.5
	p.damping_max = 1.5
	p.scale_amount_min = 0.07
	p.scale_amount_max = 0.14
	p.mesh = _spark_quad(color, 3.0, 3.5)
	p.particle_flag_align_y = true
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = ramp
	p.emitting = true
	return p


## Dunst für Schwere Luft: große, langsame Schwaden knapp über dem Boden der Bahn.
## Die Nebelschichten über dem ganzen Feld, je eine mit eigener Dichte. Ihre Materialien
## liegen als Meta „materials" am Knoten; `haze` blendet über sie ein und aus.
func _haze_layers() -> Node3D:
	var root := Node3D.new()
	var mats: Array[ShaderMaterial] = []
	var size := Vector2((half_width + 6.0) * 2.0, front_z - back_z + 10.0)
	for i in HAZE_LAYERS.size():
		var layer := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = size
		layer.mesh = plane
		var mat := ShaderMaterial.new()
		mat.shader = FOG_SHADER
		mat.set_shader_parameter("tint", Vector3(HAZE_COLOR.r, HAZE_COLOR.g, HAZE_COLOR.b))
		mat.set_shader_parameter("density", HAZE_DENSITY[i])
		mats.append(mat)
		layer.material_override = mat
		layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		layer.position = Vector3(0.0, HAZE_LAYERS[i], (front_z + back_z) * 0.5)
		root.add_child(layer)
	root.set_meta("materials", mats)
	return root


## Das Bild leuchtet in `color` auf: in `rise` auf `alpha`, hält `hold`, verlischt in `fall`.
## `fall` 0: bleibt stehen, bis der nächste Aufruf es ablöst (Anlauf des Donnerschlags).
func _veil(color: Color, alpha: float, rise: float, hold: float, fall: float) -> void:
	if veil == null:
		return
	if _veil_tween != null and _veil_tween.is_valid():
		_veil_tween.kill()
	var from := veil.color.a
	veil.color = Color(color, from)
	_veil_tween = create_tween()
	if rise > 0.0:
		_veil_tween.tween_property(veil, "color:a", alpha, rise)
	else:
		veil.color.a = alpha
	if fall > 0.0:
		_veil_tween.tween_interval(hold)
		_veil_tween.tween_property(veil, "color:a", 0.0, fall).set_trans(Tween.TRANS_QUAD) \
				.set_ease(Tween.EASE_OUT)


func _free_later(node: Node, seconds: float) -> void:
	get_tree().create_timer(seconds, false).timeout.connect(node.queue_free)


static func _curtain_quad(width: float, height: float) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(width, height)
	return quad


static func _curtain_material(color: Color, energy: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = CURTAIN_SHADER
	mat.set_shader_parameter("tint", Vector3(color.r, color.g, color.b))
	mat.set_shader_parameter("energy", energy)
	mat.set_shader_parameter("fade", 0.0)
	return mat


static func _spark_quad(color: Color, stretch: float, energy: float) -> QuadMesh:
	var quad := QuadMesh.new()
	var mat := ShaderMaterial.new()
	mat.shader = SPARK_SHADER
	mat.set_shader_parameter("tint", Vector3(color.r, color.g, color.b))
	mat.set_shader_parameter("stretch", stretch)
	mat.set_shader_parameter("energy", energy)
	quad.material = mat
	return quad
