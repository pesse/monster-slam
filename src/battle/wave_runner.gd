extends Node3D
## Fährt eine einzelne Welle in 3D: spawnt Monster aus der Wave-Definition, gleicht
## Spielerantworten gegen aktive Monster ab und erkennt das Wellenende.
## Nutzt ausschließlich bestehende Autoloads + AnswerEvaluator — rein additiv.

const MONSTER_SCENE := preload("res://scenes/entities/monster.tscn")
const FIRST_PERSON_SCENE := preload("res://scenes/battle/first_person_view.tscn")
const GOAL_Z := 16.5          # Festungsfront (Monster-Ziel)
const SPAWN_Z := -24.0        # Spawn am hinteren Ende der Bahn (längerer Anmarsch)
const LANE_HALF_WIDTH := 8.0
## Bildmitte auf der Bahn (z). Der Boden richtet sich danach, nicht umgekehrt. Festung,
## Bahn und Bild sind in battle_theme_lab zusammen eingestellt (Regler); dort ändern.
const VIEW_CENTER_Z := -3.5

const SHAKE_DURATION := 0.35
const SHAKE_MAGNITUDE := 0.35 # in 3D-Einheiten
const FLASH_CORRECT := Color(0.3, 1.0, 0.45)
const FLASH_WRONG := Color(1.0, 0.3, 0.3)

var _evaluator := AnswerEvaluator.new()
var _generator := WaveGenerator.new()
var _active: Array[Monster] = []
var _total: int = 0
var _spawned: int = 0
var _finished: bool = false
## Kein Spawn möglich (keine Inhalte / Auswahl trifft nichts): es läuft keine Welle,
## der Hinweis steht, und Escape ist der einzige (aber vorhandene) Weg zurück.
var _no_content: bool = false

# Prozedurale Wellen (nicht mehr aus Content-Dateien): Schwierigkeit + Wellennummer
# steuern Erzeugung und Tempo. Der Spieler wählt die Schwierigkeit auf dem Statistik-Screen.
var _difficulty: int = 3           # 1..5, vom Spieler gewählt
var _wave_number: int = 1          # laufende Nummer (Anzeige + Skalierung)
var _wave_correct: int = 0         # richtig besiegte Monster dieser Welle
var _wave_leaked: int = 0          # an der Festung durchgelassene Monster dieser Welle
var _wave_leaked_tasks: Array[Dictionary] = []  # deren Aufgaben (prompt + accepted_answers), für die Auflösung
var _wave_played_tasks: Array[Dictionary] = []  # ALLE gespielten Aufgaben (richtig + falsch), fürs freie Durchblättern im Reveal
var _score_at_start: int = 0       # Punktestand zu Wellenbeginn (für "+X" im Screen)
var _wave_xp: int = 0              # in dieser Welle verdiente Erfahrung (für den Screen)
var _level_at_start: int = 1       # Spielerlevel zu Wellenbeginn (für "Aufgestiegen!")
var _last_won: bool = true         # Ausgang der zuletzt beendeten Welle
# Generation-Zähler: bricht Spawn-Coroutinen einer alten Welle ab, sobald eine neue
# startet (der _finished-Check allein reicht nicht, da die neue Welle _finished=false setzt).
var _wave_gen: int = 0
## Läuft der Rest der Welle gerade im Zeitraffer (siehe _fast_resolve_wave)?
var _fast_resolving: bool = false
## Während der Meister-Feier abgeschickte Antworten: sie werden nach der Feier in dieser
## Reihenfolge ausgewertet, damit keine verloren geht (siehe _on_answer_submitted).
var _held_answers: Array[String] = []
## In dieser Welle schon gezeigte Grundwörter: Lexem-id -> Spawn-Nummer der letzten
## Zeigung. WaveGenerator.pick() nimmt sie erst, wenn der Pool erschöpft ist (Issue #24).
## Gilt nur für die laufende Welle und wird nicht gespeichert.
var _wave_shown: Dictionary = {}

var _cam_base: Vector3
var _shake_left: float = 0.0
var _shake_mag: float = SHAKE_MAGNITUDE
var _rng := RandomNumberGenerator.new()

var _fortress: Node3D = null
## Festungsstufe DES LAUFS: die schwächste Unit im gespielten Bereich (FortressTier.run_tier).
## Das Debug-Panel baut nur das Bild um und fasst diesen Wert nicht an.
var _fortress_tier: int = -1
var _cutscene: bool = false   # läuft gerade die Ausbau-Cutscene? (unterdrückt Kamera-Wackeln)
## Die Ich-Sicht (Späher-Baum, RunRequest.first_person), oder null für die Iso-Kamera.
var _fp: FirstPersonView = null
## Spielt dieser Lauf aus der Ich-Sicht? Einmal am Anfang gefragt: schon die Streudeko
## richtet sich danach, bevor die Ich-Sicht steht.
var _first_person_run := false
## Laufende Sturmangriffe, fliegende Pfeile und Steine: so lange wartet das Wellenende.
var _underway := 0
## Wachkatapult gelernt (Bollwerk, `auto_catapult`): Monster mit gemeisterter Aufgabe
## werden abgeschossen.
var _catapult := false
## Die Katapulte der Festung (FortressModel.catapults) — erst ab FortressModel.CATAPULT_TIER
## gibt es welche, und nur dann wirft das Wachkatapult.
var _catapults: Array[Node3D] = []
## Woran ein Fehlschuss vorbeizielt: die Körpermitte, wie beim Blick (_in_view). Ein
## Treffer geht in den Kopf (Monster.head_height).
const ARROW_AIM_Y := 1.2
## Explosionspfeil: so groß der Knall (Blast), und bis hierhin zucken die Nachbarn.
const BLAST_SCALE := 1.0
const BLAST_FLINCH_RADIUS := 5.0
## Wachkatapult (Bollwerk): so lange nach dem Spawn wirft es, zufällig dazwischen — bis
## dahin kann der Spieler das Monster auch selbst treffen.
const CATAPULT_DELAY_MIN := 1.0
const CATAPULT_DELAY_MAX := 3.0
## Flugzeit des Steins je Meter, mit Unter- und Obergrenze, und wie hoch er steigt (Anteil
## der Strecke).
const CATAPULT_TIME_PER_M := 0.035
const CATAPULT_TIME_MIN := 0.8
const CATAPULT_TIME_MAX := 1.5
const CATAPULT_LIFT := 0.3
## Worauf der Stein zielt: die Körpermitte, nicht die Füße.
const CATAPULT_AIM := Vector3(0.0, 1.0, 0.0)

@onready var _monsters: Node3D = $Monsters
@onready var _camera: Camera3D = $CameraPivot/Camera3D
@onready var _scene_zoom: SceneZoom = $SceneZoom
## Der Zoom hinaus läuft: ein zweites Escape wechselt nicht noch einmal.
var _leaving := false
## Hinter dem Schleier wird noch vorgewärmt — solange bricht Escape nicht ab, sonst liefe
## das Einblenden danach über das Ausblenden.
var _warming := false
@onready var _end_label: Label = $UI/EndLabel
@onready var _flash: ColorRect = $UI/Flash
@onready var _stats: PanelContainer = $UI/WaveStats
@onready var _leak_reveal: Control = $UI/LeakReveal
@onready var _answer_input: LineEdit = $UI/AnswerInput
@onready var _slow_motion: SlowMotion = $SlowMotion
@onready var _fast_resolve_button: Button = $UI/FastResolveButton
@onready var _fast_resolve_confirm: ConfirmDialog = $UI/FastResolveConfirm
@onready var _celebration: MasteryCelebration = $UI/MasteryCelebration
@onready var _level_flare: LevelFlare = $UI/HUD.level_flare


func _ready() -> void:
	_rng.randomize()
	_first_person_run = RunRequest.first_person()
	_setup_view()
	# Der Kampf kommt aus der Ferne heran (SceneZoom, wie die Karten): das Gelände wird für
	# den weitesten Blick gebaut, sonst sähe man beim Heranzoomen seinen Rand.
	var view_size := _camera.size
	# Die Teilchen in der Luft füllen, was im Kampf zu sehen ist — nicht den weiten Blick
	# des Heranzoomens, sonst stünden sie dort dünner.
	var air_area := visible_ground_area(_camera)
	_camera.size = view_size / SceneZoom.FROM
	# Das Thema VOR Boden und Ich-Sicht: der Boden nimmt seine Farben, der Nebel der
	# Ich-Sicht die Hintergrundfarbe des schon gefärbten Environments.
	_theme = BattleTheme.for_level(RunRequest.level())
	_theme.apply($WorldEnvironment as WorldEnvironment, $Sun as DirectionalLight3D)
	GraphicsQuality.apply_environment($WorldEnvironment as WorldEnvironment)
	_setup_ground()
	_decorate()
	add_child(Wind.new())
	_sun_cycle = SunCycle.attach(self, $Sun as DirectionalLight3D, $CameraPivot as Node3D)
	var air := AmbientParticles.build(_theme.particles, air_area, _leaf_crowns) \
			if GraphicsQuality.particles() else null
	if air != null:
		add_child(air)
	var petals := AmbientParticles.blossoms(_blossom_crowns) if GraphicsQuality.particles() else null
	if petals != null:
		add_child(petals)
	if _theme.tumbleweeds and GraphicsQuality.particles():
		var weeds := Tumbleweeds.make(air_area, _ground_y, _cover_site().keep_out, _rng.randi())
		# Nur in der Iso-Sicht sagt der Ausschnitt etwas; in der Ich-Sicht gilt die Fläche.
		weeds.on_screen = func(x: float, z: float) -> bool:
			return _fp != null or tile_on_screen(_camera, x, z)
		add_child(weeds)
	_build_fortress()
	_cam_base = _camera.position
	GameState.reset()
	# Gelernte Skills UNMITTELBAR nach dem reset(): der Reset stellt die Grundwerte her,
	# erst danach dürfen die Boni darauf. Ein Dictionary für beide Empfänger, damit es
	# EINE Quelle der Boni gibt und nicht zwei, die auseinanderlaufen können.
	# Die Festungsstufe kommt in DASSELBE Dictionary: auch sie hebt nur das Maximum, und
	# eine additive Summe aus einer Quelle kann nicht auseinanderlaufen.
	var skill_bonuses := SkillBook.bonuses().duplicate()
	skill_bonuses["max_health"] = int(skill_bonuses.get("max_health", 0)) \
			+ FortressTier.health_bonus(_fortress_tier)
	GameState.apply_skills(skill_bonuses)
	_slow_motion.apply_skills(skill_bonuses)
	_catapult = float(skill_bonuses.get("auto_catapult", 0.0)) > 0.0
	if _first_person_run:
		_setup_first_person(skill_bonuses)
	# Der Lauf beginnt hier, nicht mit der ersten Welle: alles, was über die Wellen hinweg
	# zählt (Sitzungs-Log, GameState-Zähler), hängt an diesem Punkt.
	EventBus.run_started.emit()
	EventBus.answer_submitted.connect(_on_answer_submitted)
	# Die Festung wächst mit dem Lernfortschritt, aber erst NACH einer gewonnenen Welle
	# (siehe _finish_wave) – nicht mitten im Kampf.
	var debug_panel := $UI/DebugPanel
	if debug_panel.has_signal("fortress_tier_selected"):
		debug_panel.fortress_tier_selected.connect(_on_debug_tier_selected)
	if debug_panel.has_signal("celebration_requested"):
		debug_panel.celebration_requested.connect(_on_debug_celebration)
	if debug_panel.has_signal("level_up_requested"):
		debug_panel.level_up_requested.connect(_level_flare.play)
	if _stats.has_signal("next_wave_requested"):
		_stats.next_wave_requested.connect(_on_next_wave_requested)
	if _stats.has_signal("back_to_menu_requested"):
		_stats.back_to_menu_requested.connect(_on_back_to_menu)
	if _stats.has_signal("reward_collected"):
		_stats.reward_collected.connect(_on_reward_collected)
	if _stats.has_signal("consolation_collected"):
		_stats.consolation_collected.connect(func(gold: int) -> void: Wallet.earn(gold))
	_fast_resolve_button.pressed.connect(_on_fast_resolve_pressed)
	_fast_resolve_confirm.confirmed.connect(_fast_resolve_wave)
	_fast_resolve_confirm.cancelled.connect(_on_fast_resolve_cancelled)
	_celebration.started.connect(_on_celebration_started)
	_celebration.finished.connect(_on_celebration_finished)
	# Startschwierigkeit aus den persistenten Einstellungen des aktiven Profils.
	_difficulty = UserSettings.default_difficulty()
	_start_next_wave()
	# Hinter dem geschlossenen Schleier einmal alles zeigen, was sonst beim ersten Treffer
	# oder der ersten Meisterung Shader übersetzt und das Bild anhält (FxWarmup). Das erste
	# Monster kommt frühestens nach einem Spawn-Intervall, dann ist das längst vorbei.
	_scene_zoom.hold()
	_warming = true
	await _warm_up()
	_warming = false
	_scene_zoom.reveal(func(k: float) -> void:
		_camera.size = view_size / lerpf(SceneZoom.FROM, 1.0, k))


## Vorwärmen (FxWarmup) mit den Schildern und der Feier des Kampfs, in der Ich-Sicht auch
## in deren fester Bildgröße — das ist eine eigene Shader-Variante.
func _warm_up() -> void:
	var xp := xp_label(FxWarmup.GLYPHS)
	_screen_size_in_first_person(xp, POPUP_SCREEN_SCALE)
	var form := form_label(FxWarmup.GLYPHS)
	_screen_size_in_first_person(form, 1.4)
	var at := FxWarmup.point_in_view(get_viewport().get_camera_3d(),
			Vector3(0.0, 1.0, VIEW_CENTER_Z))
	_celebration.warm_up()
	_level_flare.warm_up()
	var extras: Array[Node3D] = [xp, form]
	# Der Pfeil fliegt erst nach der ersten Antwort; der Bogen hängt schon an der Kamera.
	if _fp != null:
		var arrow := Arrow.new()
		arrow.trail = true
		extras.append(arrow)
		if _fp.explosive:
			var ember := Arrow.new()
			ember.trail = true
			ember.glowing = true
			extras.append(ember)
			extras.append(Blast.new())
	if _theme.tumbleweeds:
		extras.append(Tumbleweeds.specimen())
	if _catapult:
		extras.append(CatapultStone.new())
		if _fp == null or not _fp.explosive:
			extras.append(Blast.new())
	await FxWarmup.run(self, at, FxWarmup.monster_defs(), extras, _fp != null)
	_celebration.cool_down()
	_level_flare.cool_down()


## Zurück auf die Karte (oder ins Menü), als Zoom hinaus — die Umkehrung des Wegs herein.
## Die Karte setzt ihn fort (MapSelection.zoom_out).
func _leave_battle() -> void:
	if _leaving:
		return
	_leaving = true
	_set_view_active(false)
	MapSelection.zoom_out = RunRequest.is_level()
	var view_size := _camera.size
	_scene_zoom.cover(func(k: float) -> void:
		_camera.size = view_size / lerpf(1.0, SceneZoom.FROM, k))
	await _scene_zoom.finished
	get_tree().change_scene_to_file(RunRequest.return_scene())


## Prozedurales Terrain: flaches Innenfeld (Spielfläche/Props/Festung), sanfte Hügel am
## Rand, weiche Farbflecken (Farben aus dem BattleTheme der Unit). Glatt schattiert über
## Normalen aus der Höhenfunktion — den Low-Poly-Stil tragen Burg, Monster und Deko.
##
## Der Boden reicht bis an den BILDRAND und nicht nur bis an das Spielfeld: eine grüne
## Insel vor der Hintergrundfarbe sieht aus, als schwebte sie. Wie weit das ist, wird
## aus der Kamera gerechnet (`visible_ground_area`) und steht nicht als zweite
## Konstante daneben — sonst hinkt das Terrain jeder Änderung an Zoom oder Blickwinkel
## hinterher. Gespielt wird davon nichts: die Bahn bleibt SPAWN_Z..GOAL_Z bei
## ±LANE_HALF_WIDTH, und das Innenfeld bleibt flach (siehe terrain_height).
## Rasterweite. Der Boden ist GLATT schattiert (Normalen und Farben je Ecke, nicht je
## Dreieck) — den Low-Poly-Stil tragen die Modelle; ein facettierter Boden sah daneben
## nach Scherben aus, am deutlichsten beim Schnee der Tundra. 1.5 hält die Hügel rund.
const TERRAIN_STEP := 1.5
## Abstand vom Innenfeld, ab dem die Hügel nicht weiter wachsen, und ihr Höhenfaktor.
## Bis zu einem `edge` von 4 ist das die alte Kurve am Spielfeldrand; darüber liegt nur
## noch Kulisse, die kräftiger rollen darf, weil dort nichts steht und nichts läuft.
const TERRAIN_EDGE_MAX := 8.0
const TERRAIN_HEIGHT_SCALE := 0.6
const TERRAIN_HEIGHT_MAX := TERRAIN_EDGE_MAX * TERRAIN_HEIGHT_SCALE
## Breitestes Seitenverhältnis, für das der Boden reicht. Die Orthogonal-Kamera hält
## ihre HÖHE (`keep_aspect`), die Breite wächst mit dem Fenster — ein 21:9-Schirm sieht
## am weitesten nach außen, das Vollbild auf 16:9 am wenigsten (siehe CLAUDE.md).
const VIEW_MAX_ASPECT := 2.4
## Zugabe in Bildeinheiten beim Aussortieren unsichtbarer Kacheln — gerechnet, nicht
## geschätzt: aussortiert wird auf der Ebene y=0, ein Hügel HEBT die Kachel im Bild
## (die Höhe geht voll in die Bildhöhe ein, in die Bildbreite gar nicht), und das
## Kamera-Wackeln schiebt den Ausschnitt um bis zu SHAKE_MAGNITUDE. Zu knapp bemessen
## heißt: am unteren Bildrand fehlt genau die Kachel, deren Hügel hereinragt.
const VIEW_MARGIN := TERRAIN_HEIGHT_MAX + SHAKE_MAGNITUDE

var _terrain_noise: FastNoiseLite
## Farben von Boden und Licht für die Unit des Laufs (BattleTheme, aus map.json).
var _theme: BattleTheme
## Stellt die Sonne nach der Uhr; hält während einer Welle den Sprung auf den Morgen an.
var _sun_cycle: SunCycle
## Der Weg zum Tor; die Streudeko hält ihn frei.
var _path: BattlePath
## Fußpunkte der gestreuten Bäume, für die Sträucher darum (GroundCover).
var _tree_feet: Array[Vector3] = []
## Kronen der Laubbäume darunter, aus denen das Laub fällt (AmbientParticles).
var _leaf_crowns: Array[AABB] = []
var _blossom_crowns: Array[AABB] = []

func _setup_ground() -> void:
	_terrain_noise = terrain_noise(_rng.randi())
	_path = BattlePath.make(_theme.path, GOAL_Z, _rng)
	var ground := $Ground as MeshInstance3D
	ground.mesh = build_terrain(_camera, _terrain_noise, _theme)
	dress_ground(ground, _theme, _path)


## Material und Schatten des Bodens — statisch, damit die Werkbank ihn genauso anzieht.
## Wolkenschatten und Bodenflecken nur, wenn die Grafikstufe sie zeigt (GraphicsQuality).
## Der Boden wirft selbst keinen Schatten: die Hügel schattiert der Bodenshader über ihre
## Neigung, und ohne Selbstschatten reicht ein kleiner Bias (setup_view), ohne dass der
## Boden Streifen bekommt.
static func dress_ground(ground: MeshInstance3D, theme: BattleTheme, path: BattlePath = null,
		quality := GraphicsQuality.level()) -> void:
	ground.material_override = theme.ground_material(path)
	if not GraphicsQuality.clouds(quality):
		(ground.material_override as ShaderMaterial).set_shader_parameter("clouds", 0.0)
	if not GraphicsQuality.patches(quality):
		(ground.material_override as ShaderMaterial).set_shader_parameter("patch_amount", 0.0)
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Das Rauschen des Terrains — EINE Stelle, damit Boden und Streudeko dieselben Hügel
## sehen und ein Test dieselben bauen kann wie das Spiel.
static func terrain_noise(seed_value: int) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.06
	return noise


## Baut den sichtbaren Boden für DIESE Kamera. Statisch und ohne Szene, damit
## `tests/battle_ground_test.gd` genau das Mesh prüfen kann, das im Spiel steht.
## Ohne Thema gilt die Vorgabe von BattleTheme.
static func build_terrain(camera: Camera3D, noise: FastNoiseLite, theme: BattleTheme = null) -> ArrayMesh:
	if theme == null:
		theme = BattleTheme.new()
	var area := visible_ground_area(camera)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var x := area.position.x
	while x < area.end.x - 0.001:
		var z := area.position.y
		while z < area.end.y - 0.001:
			# Das Sichtfeld ist eine Raute im x/z-Raster (45° Gierwinkel): über die Hälfte
			# des umschließenden Rechtecks liegt außerhalb und wird gar nicht erst gebaut.
			if tile_on_screen(camera, x, z):
				var a := _terrain_point(x, z, noise)
				var b := _terrain_point(x, z + TERRAIN_STEP, noise)
				var c := _terrain_point(x + TERRAIN_STEP, z + TERRAIN_STEP, noise)
				var d := _terrain_point(x + TERRAIN_STEP, z, noise)
				# Im Uhrzeigersinn von oben gesehen — das ist in Godot die Vorderseite. Andersherum
				# dreht die Materialeinstellung cull_disabled die Normale nach unten: der Boden
				# bekommt dann kein Sonnenlicht und zeigt keine Schatten.
				_add_terrain_tri(st, noise, theme, a, c, b)
				_add_terrain_tri(st, noise, theme, a, d, c)
			z += TERRAIN_STEP
		x += TERRAIN_STEP
	return st.commit()


## x/z-Bereich, in dem der Boden überhaupt im Bild liegen kann: die vier Ecken des
## Bildrechtecks als Strahlen auf die Ebene y=0 geschnitten, nach außen auf das
## Kachelraster gerundet. Setzt eine eingerichtete Kamera voraus (`setup_view`).
static func visible_ground_area(camera: Camera3D) -> Rect2:
	var basis := camera.global_transform.basis
	var origin := camera.global_position
	var forward := -basis.z
	var half_h := camera.size * 0.5 + VIEW_MARGIN
	var half_w := half_h * VIEW_MAX_ASPECT
	var lo := Vector2.INF
	var hi := -Vector2.INF
	for su: float in [-1.0, 1.0]:
		for sv: float in [-1.0, 1.0]:
			var corner := origin + basis.x * (su * half_w) + basis.y * (sv * half_h)
			# Die Kamera blickt nach unten (forward.y < 0), also trifft jede Ecke die Ebene.
			var hit := corner + forward * (corner.y / -forward.y)
			lo = lo.min(Vector2(hit.x, hit.z))
			hi = hi.max(Vector2(hit.x, hit.z))
	lo = (lo / TERRAIN_STEP).floor() * TERRAIN_STEP
	hi = (hi / TERRAIN_STEP).ceil() * TERRAIN_STEP
	return Rect2(lo, hi - lo)


## Liegt die Kachel mit der Ecke (x,z) im Bild? Gerechnet in Bildkoordinaten der
## Kamera (u nach rechts, v nach oben) statt über `unproject_position`, das die
## Fenstergröße einrechnet — der Boden soll für JEDES Fenster reichen.
static func tile_on_screen(camera: Camera3D, x: float, z: float) -> bool:
	var basis := camera.global_transform.basis
	var origin := camera.global_position
	var half_h := camera.size * 0.5 + VIEW_MARGIN
	var half_w := half_h * VIEW_MAX_ASPECT
	var lo := Vector2.INF
	var hi := -Vector2.INF
	for cx: float in [x, x + TERRAIN_STEP]:
		for cz: float in [z, z + TERRAIN_STEP]:
			var r := Vector3(cx, 0.0, cz) - origin
			lo = lo.min(Vector2(r.dot(basis.x), r.dot(basis.y)))
			hi = hi.max(Vector2(r.dot(basis.x), r.dot(basis.y)))
	return hi.x >= -half_w and lo.x <= half_w and hi.y >= -half_h and lo.y <= half_h


static func _terrain_point(x: float, z: float, noise: FastNoiseLite) -> Vector3:
	return Vector3(x, terrain_height(x, z, noise), z)


## Halbe Breite des flachen Bodens.
const FLAT_HALF_X := 9.0 * FORTRESS_GROW


## Um so viel weicht der Hügelfuß höchstens nach außen zurück (TERRAIN_FOOT_WAVE Meter je
## Bogen) — sonst stünde das flache Feld als Rechteck in der Landschaft.
const TERRAIN_FOOT_SHIFT := 6.0
const TERRAIN_FOOT_WAVE := 0.045


static func terrain_height(x: float, z: float, noise: FastNoiseLite) -> float:
	# Innenfeld flach halten (bis knapp hinter den Spawn); nur außerhalb sanfte Hügel. So
	# breit wie die Festung, sonst stünden ihre Ecktürme am Hang. Der Hügelfuß weicht in
	# Bögen nach außen zurück, nie nach innen — das Feld bleibt mindestens so groß. Die
	# Ecke hinter dem Spawn ist rund: außerhalb des Rechtecks zählt der Abstand zur Ecke.
	var ex := absf(x) - FLAT_HALF_X - _foot_shift(z * signf(x) + 200.0, noise)
	var ez := -z + SPAWN_Z - _foot_shift(x + 400.0, noise)
	var edge := Vector2(maxf(ex, 0.0), maxf(ez, 0.0)).length() if ex > 0.0 and ez > 0.0 \
			else maxf(ex, ez)
	if edge <= 0.0:
		return 0.0
	var n := noise.get_noise_2d(x, z) * 0.5 + 0.5
	return clampf(edge, 0.0, TERRAIN_EDGE_MAX) * (0.3 + 0.7 * n) * TERRAIN_HEIGHT_SCALE


## Wie weit der Hügelfuß an der Stelle `t` (längs seiner Kante) zurückweicht, 0 bis
## TERRAIN_FOOT_SHIFT.
static func _foot_shift(t: float, noise: FastNoiseLite) -> float:
	var n := noise.get_noise_2d(t * TERRAIN_FOOT_WAVE / noise.frequency, 777.0) * 0.5 + 0.5
	return TERRAIN_FOOT_SHIFT * smoothstep(0.2, 0.8, n)


static func _add_terrain_tri(st: SurfaceTool, noise: FastNoiseLite, theme: BattleTheme, a: Vector3, b: Vector3, c: Vector3) -> void:
	# Farbe und Normale je ECKE, aus Rauschen und Höhenfunktion an genau diesem Punkt:
	# Nachbardreiecke teilen sie, dazwischen wird weich gemischt — keine Kanten im Boden.
	for v: Vector3 in [a, b, c]:
		st.set_color(_terrain_color(v, noise, theme))
		st.set_normal(terrain_normal(v.x, v.z, noise))
		st.add_vertex(v)


static func _terrain_color(p: Vector3, noise: FastNoiseLite, theme: BattleTheme) -> Color:
	return theme.ground_color(BattleTheme.ground_t(noise, p.x, p.z), p.y)


## Normale der Höhenfunktion bei (x,z), über zentrale Differenzen. Aus der Funktion und
## nicht aus den Dreiecken: so ist sie an jeder Ecke dieselbe, egal zu welchem Dreieck sie
## gehört, und der Knick am Rand des flachen Innenfelds wird über TERRAIN_STEP verrundet.
static func terrain_normal(x: float, z: float, noise: FastNoiseLite) -> Vector3:
	var e := TERRAIN_STEP * 0.5
	var dx := terrain_height(x + e, z, noise) - terrain_height(x - e, z, noise)
	var dz := terrain_height(x, z + e, noise) - terrain_height(x, z - e, noise)
	return Vector3(-dx, 2.0 * e, -dz).normalized()


## Bodenhöhe des Terrains an (x,z) — damit Streudeko auf den Hügeln aufsitzt.
func _ground_y(x: float, z: float) -> float:
	return terrain_height(x, z, _terrain_noise) if _terrain_noise != null else 0.0


## Platziert eines der Modelle eines Deko-Platzes (`BattleTheme.trees` …, Pfade unter
## assets/models/) auf Terrain-Höhe mit zufälliger Drehung; ein leerer Platz stellt nichts
## hin, und auf dem Weg (BattlePath) steht nichts. Position/Skalierung kommen vom Aufrufer.
## Bäume merken sich ihren Fuß (`_tree_feet`): um sie wachsen Sträucher (GroundCover).
func _scatter(parent: Node3D, slot: Array[String], x: float, z: float, scale: float) -> void:
	if slot.is_empty() or (_path != null and _path.blocks(x, z, 0.4 * scale)):
		return
	var model := slot[_rng.randi() % slot.size()]
	var at := Vector3(x, _ground_y(x, z), z)
	var inst := _place_model(parent, model.get_file(), at,
			_rng.randf_range(0.0, 360.0), Vector3.ONE * scale, model.get_base_dir())
	Wind.sway(inst, model, _theme.wind)
	if slot == _theme.trees:
		_tree_feet.append(at)
		if AmbientParticles.LEAF_TREES.has(model.get_file().get_basename()):
			_leaf_crowns.append(AmbientParticles.crown_of(inst))
		elif AmbientParticles.BLOSSOM_TREES.has(model.get_file().get_basename()):
			_blossom_crowns.append(AmbientParticles.crown_of(inst))


const GRASS_SCALE_FIRST_PERSON := 0.4

## Randomisierte Streudekoration (jeder Start anders): Bäume an den Seitenstreifen
## (halten den Lauf-Korridor frei), Steine/Grasbüschel übers Feld, ein paar
## Requisiten und Fackelsäulen. Alles hinter der Festung (z < 5). Fortress bleibt fix.
## WELCHE Modelle, sagt das Thema (BattleTheme); wo und wie groß, steht hier.
func _decorate() -> void:
	var d := Node3D.new()
	d.name = "Decor"
	add_child(d)

	var z_back := SPAWN_Z - 2.0    # bis knapp hinter den Spawn
	# Bis kurz vor die Festung. Ihre Ecktürme ragen weiter vor als die Mauer, und mehr, je
	# größer sie steht — ein Baum am Seitenstreifen stünde sonst im Turm.
	var z_front := GOAL_Z - 3.0 * FORTRESS_GROW

	# Bäume nur an den Seitenstreifen (|x| groß), damit die Bahn frei bleibt
	for i in _rng.randi_range(8, 14):
		var sx := (1.0 if _rng.randf() < 0.5 else -1.0) * _rng.randf_range(9.5, 12.5)
		_scatter(d, _theme.trees, sx, _rng.randf_range(z_back, z_front), _rng.randf_range(0.85, 1.2))

	# Steine über das Feld verteilt
	for i in _rng.randi_range(5, 10):
		_scatter(d, _theme.rocks, _rng.randf_range(-10.0, 10.0), _rng.randf_range(z_back, z_front), _rng.randf_range(1.6, 2.6))

	# Grasbüschel. Für die Draufsicht bemessen — aus Augenhöhe stünden sie als Hecke
	# zwischen Spieler und Monstern, deshalb in der Ich-Sicht deutlich kleiner.
	var grass_scale := GRASS_SCALE_FIRST_PERSON if _first_person_run else 1.0
	for i in _rng.randi_range(22, 34):
		_scatter(d, _theme.grass, _rng.randf_range(-11.0, 11.0), _rng.randf_range(z_back, z_front + 0.5), _rng.randf_range(1.2, 2.0) * grass_scale)

	# Fässer/Kisten an den Rändern
	for i in _rng.randi_range(3, 6):
		var bx := (1.0 if _rng.randf() < 0.5 else -1.0) * _rng.randf_range(8.5, 10.5)
		_scatter(d, _theme.props, bx, _rng.randf_range(SPAWN_Z + 4.0, GOAL_Z - 3.0), 1.0)

	# Wahrzeichen (Ruinen, Felsnadeln): ein, zwei an den Seitenstreifen, wo man sie sieht
	for i in _rng.randi_range(1, 2):
		var lx := (1.0 if _rng.randf() < 0.5 else -1.0) * _rng.randf_range(10.0, 12.5)
		_scatter(d, _theme.landmarks, lx, _rng.randf_range(z_back, z_front), _rng.randf_range(0.8, 1.0))

	# Zwei Fackelsäulen am hinteren Rand (Spawn-Seite)
	for side: float in [-1.0, 1.0]:
		var px := side * _rng.randf_range(9.5, 11.5)
		var pz := _rng.randf_range(SPAWN_Z + 1.0, SPAWN_Z + 5.0)
		var gy := _ground_y(px, pz)
		_place_model(d, "pillar.gltf", Vector3(px, gy, pz), 0.0, Vector3.ONE)
		_place_model(d, "torch_lit.gltf", Vector3(px, gy + 4.0, pz), 0.0, Vector3.ONE)

	_decorate_outskirts(d)
	GroundCover.grow(d, _theme, _cover_site(), GraphicsQuality.cover(), _rng)


## Wo der Bewuchs wächst: der sichtbare Boden ohne Weg und ohne die Burg hinter der Mauer.
func _cover_site() -> GroundCover.Site:
	var site := GroundCover.Site.new()
	site.area = visible_ground_area(_camera)
	site.on_screen = func(x: float, z: float) -> bool: return tile_on_screen(_camera, x, z)
	site.height = _ground_y
	site.t_at = func(x: float, z: float) -> float: return BattleTheme.ground_t(_terrain_noise, x, z)
	site.path = _path
	site.keep_out = Rect2(-FIELD_HALF_X, GOAL_Z - 0.5, 2.0 * FIELD_HALF_X, FIELD_Z_FRONT - GOAL_Z + 0.5)
	site.trees = _tree_feet
	return site


## Das Innenfeld: Bahn plus Festung im Vollausbau (Kirche und Nebengebäude liegen am
## weitesten hinten). Hier steht keine Streudeko — es ist die Fläche, auf der gespielt
## wird, und der Boden darunter ist flach (siehe terrain_height).
## Breite und Tiefe wachsen mit der Festung (FortressModel.grow), damit die Streudeko auch
## um eine größere Burg herum Platz lässt.
const FORTRESS_GROW := FortressModel.SCALE / FortressModel.LAYOUT_SCALE
const FIELD_HALF_X := 11.0 * FORTRESS_GROW
const FIELD_Z_BACK := SPAWN_Z - 3.0
const FIELD_Z_FRONT := GOAL_Z + 11.0 * FORTRESS_GROW
## Zugabe in Bildeinheiten um den Bildstreifen des Innenfelds: die Modelle sind breiter
## und höher als der Punkt, an dem sie stehen.
const FIELD_CLEARANCE := 4.0


## Radius eines Hains im Umland.
const GROVE_RADIUS := 5.0


## Das Umland: Bäume und Felsen über den Teil des Bodens, der seit der Erweiterung bis
## an den Bildrand reicht. Ohne sie wäre die zusätzliche Fläche eine grüne Leere — mit
## ihnen liest sie sich als Landschaft, in der das Spielfeld liegt. Gras kommt hier
## nicht vor: ein Büschel ist auf die Entfernung ein Pixel und kostet trotzdem einen
## Knoten.
func _decorate_outskirts(d: Node3D) -> void:
	var area := visible_ground_area(_camera)
	var field := _field_span()
	# Bäume stehen meist in Hainen, ein paar einzeln dazwischen: gleichmäßig verstreut
	# läse sich das Umland als Baumschule.
	for i in _rng.randi_range(10, 15):
		var centre := _outskirts_point(area, field)
		if centre == Vector2.INF:
			continue
		for k in _rng.randi_range(3, 6):
			var p := centre + Vector2.from_angle(_rng.randf_range(0.0, TAU)) * _rng.randf_range(0.0, GROVE_RADIUS)
			if not _blocks_field(p.x, p.y, field) and tile_on_screen(_camera, p.x, p.y):
				_scatter(d, _theme.trees, p.x, p.y, _rng.randf_range(0.8, 1.4))
	for i in _rng.randi_range(12, 20):
		var p := _outskirts_point(area, field)
		if p != Vector2.INF:
			_scatter(d, _theme.trees, p.x, p.y, _rng.randf_range(0.8, 1.4))
	for i in _rng.randi_range(18, 30):
		var p := _outskirts_point(area, field)
		if p != Vector2.INF:
			_scatter(d, _theme.rocks, p.x, p.y, _rng.randf_range(1.8, 3.2))
	for i in _rng.randi_range(3, 6):
		var p := _outskirts_point(area, field)
		if p != Vector2.INF:
			_scatter(d, _theme.landmarks, p.x, p.y, _rng.randf_range(0.8, 1.2))


## Zufälliger Punkt im Umland, oder Vector2.INF wenn keiner gefunden wurde. Verworfen
## wird statt gerechnet: das Umland ist ein Rechteck mit einem Loch, und ein paar
## Fehlversuche sind billiger als eine Formel, die bei jeder Änderung am Loch nachzieht.
func _outskirts_point(area: Rect2, field: Dictionary) -> Vector2:
	for attempt in 16:
		var x := _rng.randf_range(area.position.x, area.end.x)
		var z := _rng.randf_range(area.position.y, area.end.y)
		if _blocks_field(x, z, field) or not tile_on_screen(_camera, x, z):
			continue
		return Vector2(x, z)
	return Vector2.INF


## Bildstreifen (`u_min`/`u_max`) und kleinste Tiefe (`depth`) des Innenfelds. Beides
## aus den vier Ecken gerechnet — bei 45° Gierwinkel liegt das Feld im Bild schräg, ein
## x/z-Rechteck sagt darüber nichts.
func _field_span() -> Dictionary:
	var u_min := INF
	var u_max := -INF
	var depth := INF
	for x: float in [-FIELD_HALF_X, FIELD_HALF_X]:
		for z: float in [FIELD_Z_BACK, FIELD_Z_FRONT]:
			u_min = minf(u_min, _screen_u(x, z))
			u_max = maxf(u_max, _screen_u(x, z))
			depth = minf(depth, _view_depth(x, z))
	return {"u_min": u_min, "u_max": u_max, "depth": depth}


## Waagerechte Bildkoordinate eines Bodenpunkts. Die Höhe geht nicht ein: die
## Bildachse `basis.x` der Iso-Kamera liegt waagerecht in der Welt.
func _screen_u(x: float, z: float) -> float:
	return (Vector3(x, 0.0, z) - _camera.global_position).dot(_camera.global_transform.basis.x)


## Abstand eines Bodenpunkts längs der Blickrichtung. Kleiner heißt näher an der Kamera.
func _view_depth(x: float, z: float) -> float:
	return (Vector3(x, 0.0, z) - _camera.global_position).dot(-_camera.global_transform.basis.z)


## Würde etwas bei (x,z) das Innenfeld verstellen? Drei Fälle, und nur der mittlere ist
## nicht offensichtlich: auf dem Feld selbst geht nichts; seitlich neben dem Bildstreifen
## des Feldes geht alles, auch ganz vorn; und im Streifen geht nur, was HINTER dem Feld
## liegt. Ein Baum davor verdeckt sonst genau die Festung, die er einrahmen soll — und
## das fällt erst im Vollausbau auf, wenn die Burg hoch genug dafür ist.
func _blocks_field(x: float, z: float, field: Dictionary) -> bool:
	if absf(x) <= FIELD_HALF_X and z >= FIELD_Z_BACK and z <= FIELD_Z_FRONT:
		return true
	var u := _screen_u(x, z)
	if u < field["u_min"] - FIELD_CLEARANCE or u > field["u_max"] + FIELD_CLEARANCE:
		return false
	return _view_depth(x, z) < field["depth"] + FIELD_CLEARANCE


## Festung = modular aus dem KayKit Medieval Hexagon Pack (CC0, Kay Lousberg)
## zusammengesetzt und stufenweise mit dem Lernfortschritt gewachsen. Modelle unter
## assets/models/hexagon/ (blaue Farbvariante, passend zu den Sample-Renders).
const FORTRESS_SCALE := FortressModel.SCALE
const WALL_YAW := FortressModel.WALL_YAW   # für battle_theme_lab

func _build_fortress() -> void:
	_fortress_tier = _current_fortress_tier()
	_spawn_fortress(_fortress_tier)


## Die Festungsstufe für den gewählten Bereich: die Units kommen aus Scope und Themen des
## Laufs (RunRequest, dieselben Achsen wie der Aufgaben-Pool), gewertet wird jede Unit als
## Ganzes über den ganzen Katalog (siehe FortressTier.run_tier).
func _current_fortress_tier() -> int:
	var scoped := ContentRegistry.lexemes_scoped(RunRequest.scope(), RunRequest.tags())
	var units := FortressTier.unit_tiers(
			ContentRegistry.lexemes.values(), PlayerProgress.mastered_lexemes())
	return FortressTier.run_tier(scoped, units)


## Baut die Festung passend zur Stufe (0..4) neu auf; die Anordnung steht in
## FortressModel, die Mauerfront ist die Ziel-Linie der Monster.
func _spawn_fortress(tier: int) -> void:
	var fort := Node3D.new()
	fort.name = "Fortress"
	add_child(fort)
	_fortress = fort
	print("[FORTRESS] Stufe %d (+%d HP)" % [tier, FortressTier.health_bonus(tier)])
	FortressModel.build(fort, tier, GOAL_Z, _ground_y)
	_catapults = FortressModel.catapults(fort)


## Baut die Festung neu auf, mit kurzem Bau-Effekt als Feedback. Nur das Bild — die
## Stufe des Laufs setzt _finish_wave.
func _rebuild_fortress(tier: int) -> void:
	if is_instance_valid(_fortress):
		_fortress.queue_free()
	_spawn_fortress(tier)
	_spawn_explosion(Vector3(0.0, 1.5, GOAL_Z + 2.0 * FORTRESS_GROW), Color(1.0, 0.9, 0.4), 2.0)


## „Cutscene" beim Festungsausbau (nach gewonnener Welle, vor der Statistik): die
## Kamera zoomt kräftig auf die neu gebaute Festung, ein festlicher Blitz + Banner
## feiern die neue Stufe, danach fährt die Kamera zurück. Unterdrückt das Kamera-Wackeln.
func _play_upgrade_cutscene(tier: int, bonus: int) -> void:
	_rebuild_fortress(tier)
	# Überlappende Cutscenes vermeiden: nur die erste inszeniert, weitere bauen still um.
	if _cutscene:
		return
	_cutscene = true
	_shake_left = 0.0                 # laufendes Wackeln stoppen, sonst kämpft es mit der Fahrt
	if _fp != null:
		# Aus der Ich-Sicht fährt keine Kamera: Blitz und Banner stehen, solange die Fahrt
		# der Iso-Kamera dauern würde.
		_fp.shake(Vector2.ZERO)
		_spawn_explosion(Vector3(0.0, 2.0, GOAL_Z + 2.0 * FORTRESS_GROW), Color(1.0, 0.85, 0.3), 3.0)
		_show_upgrade_banner(tier, bonus)
		await get_tree().create_timer(2.4).timeout
		_cutscene = false
		return

	var pivot := $CameraPivot as Node3D
	var pivot_base := pivot.position
	var size_base := _camera.size
	# Ziel: Festungsmitte im Bild, deutlich herangezoomt (kleinere ortho-Größe = näher).
	var focus := Vector3(0.0, pivot_base.y, GOAL_Z + 3.0 * FORTRESS_GROW)

	# Festlicher goldener Blitz an der Festung + Banner.
	_spawn_explosion(Vector3(0.0, 2.0, GOAL_Z + 2.0 * FORTRESS_GROW), Color(1.0, 0.85, 0.3), 3.0)
	_show_upgrade_banner(tier, bonus)

	# Heranfahren + kräftig hineinzoomen.
	var tw_in := create_tween()
	tw_in.set_parallel(true)
	tw_in.tween_property(pivot, "position", focus, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw_in.tween_property(_camera, "size", size_base * minf(0.42 * FORTRESS_GROW, 1.0), 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw_in.finished
	await get_tree().create_timer(1.1).timeout

	# Zurückfahren.
	var tw_out := create_tween()
	tw_out.set_parallel(true)
	tw_out.tween_property(pivot, "position", pivot_base, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw_out.tween_property(_camera, "size", size_base, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw_out.finished

	_cutscene = false


## Blendet für die Ausbau-Cutscene ein gerahmtes Banner ein (steigt auf + blendet aus).
func _show_upgrade_banner(tier: int, bonus: int) -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_END
	panel.offset_top = 110.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	($UI as CanvasLayer).add_child(panel)

	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 40)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	label.text = "🏰 Festung ausgebaut!\nStufe %d · +%d HP" % [tier, bonus]
	panel.add_child(label)

	panel.modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(panel, "modulate:a", 1.0, 0.3)
	tw.tween_property(panel, "offset_top", 90.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(1.0)
	tw.chain().tween_property(panel, "modulate:a", 0.0, 0.4)
	tw.chain().tween_callback(panel.queue_free)


## Debug-Panel (nur im Debug-Build vorhanden): erlaubt das direkte Setzen der
## Festungsstufe, um jede Ausbaustufe ohne Lernfortschritt begutachten zu können.
func _on_debug_tier_selected(tier: int) -> void:
	_rebuild_fortress(tier)


func _place_prop(parent: Node3D, name: String, pos: Vector3, yaw_deg: float, scale := Vector3.ONE) -> void:
	_place_model(parent, "%s.gltf" % name, pos, yaw_deg, scale)


func _place_model(parent: Node3D, filename: String, pos: Vector3, yaw_deg: float, scale := Vector3.ONE, subdir := "props") -> Node3D:
	var path := "res://assets/models/%s/%s" % [subdir, filename]
	if not ResourceLoader.exists(path):
		return null
	var inst := (load(path) as PackedScene).instantiate() as Node3D
	inst.position = pos
	inst.rotation_degrees.y = yaw_deg
	inst.scale = scale
	parent.add_child(inst)
	return inst


## Abstand der Iso-Kamera vom Drehpunkt. Das Bild ändert er nicht (orthografisch), nur was
## vor der Nahebene liegt: bei 32 ragten die Hügel am unteren Bildrand vor die Kamera und
## wurden abgeschnitten — darunter stand ein Streifen Hintergrund, der erst mit den hellen
## Hintergründen der BattleThemes auffiel. `tests/battle_ground_test.gd` hält das.
const CAMERA_DISTANCE := 64.0
## Tiefe der Schattenkarte ab Kamera, zugleich deren `far`. Muss hinter den Boden reichen
## (Kamera CAMERA_DISTANCE vor dem Drehpunkt, der Boden bis etwa 110 m tief). Darüber hinaus
## macht sie die Schatten weich: 140 ist scharf, 400 gewählt am Bild der Werkbank, ab 1000
## bleibt von einer Palme nur ein Fleck.
const SHADOW_DISTANCE := 400.0


func _setup_view() -> void:
	setup_view($CameraPivot as Node3D, _camera, $Sun as DirectionalLight3D)


## Orthografische Iso-Kamera + Sonne. Per Code, damit die .tscn keine
## Transform-Basis-Mathematik enthalten muss — und statisch, damit ein Test dieselbe
## Kamera aufbauen kann, gegen die der Boden gerechnet wird.
static func setup_view(pivot: Node3D, camera: Camera3D, sun: DirectionalLight3D) -> void:
	pivot.rotation_degrees = Vector3(-30.0, 45.0, 0.0)
	# Auf die Bahn zentrieren, damit der längere Anmarsch komplett im Bild bleibt; die
	# Festung steht am Rand, ihre Nebengebäude laufen links unten aus dem Bild.
	pivot.position = Vector3(0.0, 0.0, VIEW_CENTER_Z)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 34.0
	camera.position = Vector3(0.0, 0.0, CAMERA_DISTANCE)
	# Mittags, hinter der Kamera; von da an stellt sie SunCycle nach der Uhr (WaveRunner._ready).
	sun.rotation_degrees = Vector3(-SunCycle.HIGH, pivot.rotation_degrees.y, 0.0)
	# Schatten mit EINER Schattenkarte statt gestaffelter (PSSM): die Staffelung rechnet mit
	# einer Kamera, die in die Tiefe schaut, und liefert mit dieser Orthogonal-Kamera auf
	# CAMERA_DISTANCE gar keinen Schatten.
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = SHADOW_DISTANCE
	# Die eine Karte spannt sich bei einer Orthogonal-Kamera über deren ganze Tiefe bis
	# `far` — beim Standard (4000 m) war sie so grob, dass kein Schatten übrig blieb.
	camera.far = SHADOW_DISTANCE
	# Klein, weil der Boden keinen Schatten wirft (dress_ground); der Standard-Normalbias
	# (2.0) ließ von einem Baum nur einen Fleck am Fuß.
	sun.shadow_bias = 0.1
	sun.shadow_normal_bias = 1.0


func _process(delta: float) -> void:
	if _cutscene:
		return
	if _shake_left <= 0.0:
		return
	_shake_left = max(0.0, _shake_left - delta)
	var offset := Vector2.ZERO
	if _shake_left > 0.0:
		var mag := _shake_mag * (_shake_left / SHAKE_DURATION)
		offset = Vector2(randf_range(-mag, mag), randf_range(-mag, mag))
	if _fp != null:
		_fp.shake(offset)
	else:
		_camera.position = _cam_base + Vector3(offset.x, offset.y, 0.0)


## Escape bricht den laufenden Kampf ab. Bewusst `_input` und nicht `_unhandled_input`:
## die Antwort-Eingabe hält den Fokus, und eine LineEdit verbraucht Escape für das Ende
## ihres Editier-Zustands — dasselbe Muster wie im UpdateDialog.
func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	# Nach dem Wellenende führen Auflösung und Statistik-Screen selbst zurück; nur der
	# Hinweis ohne Inhalte braucht den Ausgang auch im beendeten Zustand.
	if _finished and not _no_content:
		return
	if _warming:
		return
	# set_input_as_handled() statt accept_event(): das gibt es nur an Control/Viewport,
	# der WaveRunner ist ein Node3D.
	get_viewport().set_input_as_handled()
	_abort_battle()


## Zurück ins Menü, ohne die Welle zu beenden.
##
## Bewusst NICHT über _finish_wave(): ein Abbruch ist keine Niederlage — keine Statistik,
## kein wave_cleared, kein Festungsausbau. Der Lernfortschritt dieser Welle wird nicht
## gespeichert; PlayerProgress schreibt erst bei wave_cleared bzw. beim Verlassen über den
## Statistik-Screen (_on_back_to_menu). Was schon beantwortet wurde, verfällt damit — das
## ist der Preis des Abbruchs und besser, als eine halbe Welle als Lernstand zu buchen.
##
## Auch keine Sitzungsbilanz (Issue #12): Escape heißt „sofort raus", und eine Bilanz
## dazwischen wäre ein Screen, der den Ausgang verzögert. Die Bilanz steht auf Stufe 2
## des Wellenabschlusses — wer sie sehen will, sieht sie dort nach jeder Welle.
func _abort_battle() -> void:
	_finished = true
	_report_run_ended()
	_wave_gen += 1   # bindet laufende Spawn-Coroutinen ab (siehe _run_spawn_batch)
	_slow_motion.stop()
	_leave_battle()


## Die Pause gehört zum Kampf: ein Szenenwechsel mitten in einer Feier darf sie nicht
## ins Menü mitnehmen.
## Die Ich-Sicht fängt die Maus nur, solange gekämpft wird. Ohne Ich-Sicht nichts.
func _set_view_active(on: bool) -> void:
	if _fp != null:
		_fp.set_active(on)


func _exit_tree() -> void:
	get_tree().paused = false


## „Schnell auflösen" fragt erst nach. Solange die Frage steht, ist die Eingabe weg: sie
## holt sich sonst jeden Frame den Fokus zurück, und Enter ginge an sie statt an „Abbrechen".
## Das Spiel läuft dabei weiter — ein Pausieren hielten die Spawn-Timer ohnehin nicht an.
func _on_fast_resolve_pressed() -> void:
	if _finished or _fast_resolving:
		return
	_answer_input.visible = false
	_set_view_active(false)
	_fast_resolve_confirm.ask("Schnell auflösen?",
			"Die übrigen Monster laufen im Zeitraffer durch und treffen die Festung wie sonst "
			+ "auch. Ihre Wörter zählen als nicht gewusst und werden danach aufgelöst.",
			"Auflösen")


func _on_fast_resolve_cancelled() -> void:
	if not _finished and not _fast_resolving:
		_answer_input.visible = true
		_set_view_active(true)


## Spult den Rest der Welle vor — und tut sonst NICHTS. Jedes Monster kommt über den
## gewohnten Weg an (_on_monster_reached_goal: Lernstand, Schaden, Auflösung), die Welle
## endet über _check_end bzw. an der gefallenen Festung. Voller Schaden mit Absicht: das
## Ergebnis ist das, was ohne Vorspulen auch passiert wäre, kein Ausweg aus einer
## verlorenen Welle. Zurückgesetzt wird das Tempo von _finish_wave (_slow_motion.stop()).
func _fast_resolve_wave() -> void:
	if _finished or _fast_resolving:
		return
	_fast_resolving = true
	_answer_input.visible = false
	_fast_resolve_button.disabled = true
	# Ich-Sicht: zurück zum Laufen — die Frage hat die Maus freigegeben, und eine Eingabe
	# gibt es im Zeitraffer nicht mehr.
	_set_view_active(true)
	EventBus.wave_fast_resolved.emit(maxi(0, _total - _spawned), _active.size())
	_slow_motion.fast_forward()


## Startet die nächste (prozedural erzeugte) Welle mit der aktuell gewählten Schwierigkeit.
## Ersetzt das frühere content-basierte start_wave(): Wellen sind nicht mehr vordefiniert,
## sondern werden aus Schwierigkeit + Wellennummer generiert.
func _start_next_wave() -> void:
	_wave_gen += 1
	var gen := _wave_gen
	# Wellen-Zustand zurücksetzen (auch bei Wiederholung nach Niederlage).
	_clear_active_monsters()
	_total = 0
	_spawned = 0
	_finished = false
	_no_content = false
	_wave_correct = 0
	_wave_leaked = 0
	_wave_shown.clear()
	_wave_leaked_tasks.clear()
	_wave_played_tasks.clear()
	_score_at_start = GameState.score
	# Erfahrung und Level sind Profilstände (PlayerLevel) — hier wird nur festgehalten,
	# wo die Welle angefangen hat, damit der Abschluss ihren Zuwachs zeigen kann.
	_wave_xp = 0
	_level_at_start = PlayerLevel.level
	_end_label.visible = false
	_stats.hide_stats()
	_answer_input.visible = true
	_fast_resolving = false
	_held_answers.clear()
	_fast_resolve_button.visible = true
	_fast_resolve_button.disabled = false
	_set_view_active(true)

	GameState.current_wave = "procedural_%d" % _wave_number
	GameState.wave_number = _wave_number
	# Tempo = Schwierigkeit × profilweite Grund-Geschwindigkeit (Barrierefreiheit / Grundtempo).
	_generator.speed_scale = _difficulty_to_speed(_difficulty) * UserSettings.base_speed()
	var spawns := _generate_wave(_difficulty, _wave_number)
	# Gar nicht erst anfangen, wenn der Pool nichts hergibt: ein Spawn ohne Plan zählt
	# nicht mit (_spawned), _check_end() wird nie wahr und das leere Schlachtfeld hätte
	# keinen Ausgang. Der Knopf im Menü sperrt schon — das hier ist die letzte Instanz.
	if _nothing_playable(spawns):
		_show_no_content()
		return
	for entry in spawns:
		_total += int(entry.get("count", 0))
	# Löst den Wellenstart in GameState + HUD-Refresh aus. Die Festungs-HP bleiben dabei
	# unangetastet — der Stand wird über die Wellen hinweg mitgenommen (siehe GameState).
	EventBus.wave_started.emit(GameState.current_wave)
	# Kein Sprung auf den Morgen, solange Monster laufen (_finish_wave gibt ihn frei).
	if _sun_cycle != null:
		_sun_cycle.hold = true
	# Gesamtzahl der Welle bekanntgeben -> GameState füllt wave_total/wave_resolved (HUD-Balken).
	EventBus.wave_totals.emit(_total)
	for entry in spawns:
		_run_spawn_batch(entry, gen)


## Schwierigkeit (1..5) -> Tempo-Multiplikator auf die Basis-Geschwindigkeit
## (Stufe 1..5 ⇒ 0.6 .. 1.4, also -40 % … +40 %).
func _difficulty_to_speed(difficulty: int) -> float:
	return 0.6 + 0.2 * float(clampi(difficulty, 1, 5) - 1)


## Erzeugt die Spawn-Batches einer Welle prozedural. Rückgabe: Array von Dicts der Form
## {count, interval, task_pool} — dasselbe Format, das _run_spawn_batch/_spawn erwarten.
func _generate_wave(difficulty: int, wave_number: int) -> Array:
	# Monsteranzahl wächst pro Welle UND mit der Schwierigkeit (Stufe 3 = neutral,
	# je Stufe darüber/darunter +/- 2 Monster). Mindestens 2 Monster pro Welle.
	var count := maxi(2, 2 + wave_number + (difficulty - 3) * 2)
	var interval := maxf(1.5, 4.0 - 0.3 * difficulty)  # härter ⇒ schnellere Folge
	return [{
		"count": count,
		"interval": interval,
		# Aufgabentypen, Wortarten, Scope und Tags kommen aus der Profil-Auswahl
		# (Session-Setup); leere Auswahl heißt dort "alle". Dieselbe Funktion fragen die
		# Menüs für ihre Verfügbarkeitsprüfung — Pool und Sperre dürfen nicht auseinanderlaufen.
		"task_pool": RunRequest.task_pool(),
	}]


## True, wenn KEIN Batch der Welle eine spielbare Aufgabe hergibt.
func _nothing_playable(spawns: Array) -> bool:
	for entry in spawns:
		if _generator.has_playable(entry.get("task_pool", {})):
			return false
	return true


## Nichts zu spielen: Hinweis statt Kampf, mit dem Weg zu den Inhalten und dem Rückweg
## ins Menü. Kein _finish_wave() — es gibt keine Welle, die zu verbuchen wäre.
func _show_no_content() -> void:
	_no_content = true
	_finished = true
	_set_view_active(false)
	_answer_input.visible = false
	_fast_resolve_button.visible = false
	_stats.hide_stats()
	_end_label.text = "Keine spielbaren Aufgaben.\n\nFilter prüfen oder über „Inhalte“\neinen Vokabel-Pack installieren.\n\n[Esc] zurück ins Menü"
	_end_label.visible = true
	push_warning("WaveRunner: keine spielbare Aufgabe im Pool — Welle nicht gestartet")


## Entfernt noch aktive Monster (z. B. Reste einer verlorenen Welle) vom Feld.
func _clear_active_monsters() -> void:
	for monster in _active:
		if is_instance_valid(monster):
			monster.queue_free()
	_active.clear()


## Läuft als Coroutine — mehrere Batches spawnen dadurch nebenläufig im Takt.
## `gen` bindet die Coroutine an ihre Welle: startet inzwischen eine neue Welle, bricht sie ab.
func _run_spawn_batch(entry: Dictionary, gen: int) -> void:
	var count := int(entry.get("count", 0))
	var interval := float(entry.get("interval", 2.0))
	for i in count:
		# process_always = false: in der Baum-Pause (Meister-Feier) läuft der Timer nicht
		# weiter, sonst erschienen danach mehrere Monster auf einmal.
		await get_tree().create_timer(interval, false).timeout
		if _finished or not is_inside_tree() or gen != _wave_gen:
			return
		_spawn(entry)


func _spawn(entry: Dictionary) -> void:
	# Der WaveGenerator wählt anhand des Spieler-Fortschritts eine Aufgabe aus dem
	# Pool, löst sie auf und bestimmt Darstellung (monster_task_rules) + Basiswerte.
	# Bereits sichtbare Grundwörter ausschließen, damit dieselbe Vokabel nie
	# gleichzeitig zweimal auf dem Feld steht.
	var active_sources := {}
	for m in _active:
		active_sources[str(m.task.get("source_id", ""))] = true
	var plan: Dictionary = _generator.pick(entry.get("task_pool", {}), active_sources, _wave_shown)
	if plan.is_empty():
		# Kein Plan heißt „im Pool ist nichts Spielbares" und NICHT „steht gerade alles
		# auf dem Feld": WaveGenerator.pick() lässt im zweiten Durchlauf die
		# active_sources-Sperre fallen. Der Spawn fällt also endgültig aus — dann muss er
		# aus dem Soll verschwinden, sonst wartet _check_end() für immer auf ihn.
		push_warning("WaveRunner: keine spielbare Aufgabe für Pool %s" % str(entry.get("task_pool", {})))
		_total = maxi(0, _total - 1)
		EventBus.wave_totals.emit(_total)
		_check_end()
		return

	var monster := MONSTER_SCENE.instantiate() as Monster
	monster.setup(plan["monster_def"], plan["task"], GOAL_Z, plan["speed"])
	monster.damage = plan["damage"]
	monster.reward = plan["reward"]
	monster.xp = plan["xp"]
	monster.spawned_at_ms = Time.get_ticks_msec()
	monster.screen_sized_label = _fp != null
	monster.position = Vector3(randf_range(-LANE_HALF_WIDTH, LANE_HALF_WIDTH), 0.0, SPAWN_Z)
	monster.reached_goal.connect(_on_monster_reached_goal)
	_monsters.add_child(monster)
	_active.append(monster)
	_wave_shown[str(plan["task"].get("source_id", ""))] = _spawned
	_spawned += 1
	EventBus.monster_spawned.emit(plan["monster_def"], plan["task"])
	if _catapult and _fortress_tier >= FortressModel.CATAPULT_TIER \
			and PlayerProgress.is_mastered(str(plan["task"].get("learnable_id", ""))):
		_catapult_later(monster, _wave_gen)


func _on_answer_submitted(text: String) -> void:
	if _finished:
		return
	# Während der Feier steht das Spiel; eine Antwort jetzt auszuwerten hieße, ein Monster
	# in der Pause zu besiegen und die nächste Feier anzustoßen. Aufheben statt verwerfen.
	if _celebration.is_playing():
		_held_answers.append(text)
		return
	# Zwei Durchläufe, weil die Auswertung Toleranz kennt (AnswerEvaluator): ein
	# vollständig passendes Monster muss gewinnen, sonst schnappt sich bei mehreren
	# Monstern auf dem Feld ein nur im Kern passendes den Treffer weg
	# ("take" gegen "take (on sth.)").
	var partial: Monster = null
	var partial_form := ""
	for monster in _hittable():
		var verdict := _evaluator.evaluate(monster.task.get("accepted_answers", []), text)
		if not bool(verdict["matched"]):
			continue
		if bool(verdict["complete"]):
			_score_hit(monster, text)
			return
		if partial == null:
			partial = monster
			partial_form = str(verdict["canonical"])
	if partial != null:
		# Richtig, aber etwas Optionales fehlte — die Vollform wird eingeblendet.
		_score_hit(partial, text, partial_form)
		return
	# Kein Treffer -> Falscheingabe: rotes Flash + Kamera-Wackeln.
	# Bewusst KEIN Fortschritts-Eintrag: eine Falscheingabe lässt sich keiner
	# konkreten Aufgabe zuordnen (mehrere Monster gleichzeitig). Ein echtes
	# Scheitern wird beim Erreichen der Festung verbucht (_on_monster_reached_goal).
	# PROTOKOLLIERT wird sie trotzdem, mit leerer learnable_id und den Aufgaben, die
	# gerade auf dem Feld standen: genau daran liest man später ab, warum eine Antwort
	# nicht genommen wurde (TraceLog).
	EventBus.answer_judged.emit(text, {
		"matched": false, "complete": false, "learnable_id": "", "source_id": "",
		"response_time_ms": 0, "canonical": "", "candidates": _active_learnable_ids(),
		"unseen": _unseen_learnable_ids(),
	})
	if _fp != null and _fp.weapon == FirstPersonView.Weapon.BOW:
		_miss_with_arrow()
	else:
		_wrong_feedback()


## Die learnable_ids der Aufgaben, die gerade auf dem Feld stehen — der Zusammenhang, in
## dem eine Eingabe beurteilt wurde. Nur fürs Protokoll; die Auswertung selbst läuft über
## die Monster-Liste.
func _active_learnable_ids() -> Array:
	var ids: Array = []
	for monster in _active:
		ids.append(str(monster.task.get("learnable_id", "")))
	return ids


## Die Monster, die eine Antwort treffen kann: alle — außer in der Ich-Sicht, dort nur
## die im Bild. Die einzige Regel, die die Ich-Sicht zum Kampf dazubringt.
func _hittable() -> Array[Monster]:
	if _fp == null:
		return _active
	var out: Array[Monster] = []
	for monster in _active:
		if _in_view(monster):
			out.append(monster)
	return out


func _in_view(monster: Monster) -> bool:
	return monster.in_view(_fp.camera)


## Für die Spur: welche Aufgaben standen auf dem Feld, aber außerhalb des Bildes? Daran
## liest man ab, dass eine richtige Antwort am Blick und nicht am Wort gescheitert ist.
## Leer außerhalb der Ich-Sicht.
func _unseen_learnable_ids() -> Array:
	var ids: Array = []
	if _fp == null:
		return ids
	for monster in _active:
		if not _in_view(monster):
			ids.append(str(monster.task.get("learnable_id", "")))
	return ids


## Baut die Ich-Sicht auf: Spieler vor dem Festungstor, Blick die Bahn hinunter, Nebel
## statt Weltrand. Die Iso-Kamera bleibt in der Szene — Boden und Deko sind für ihren
## (weitesten) Blick gebaut, und SceneZoom darf sie weiter bewegen, sie ist nur nicht
## mehr die aktive.
func _setup_first_person(bonuses: Dictionary) -> void:
	_fp = FIRST_PERSON_SCENE.instantiate() as FirstPersonView
	_fp.speed = FirstPersonView.speed_for(bonuses)
	_fp.weapons = FirstPersonView.weapons_for(bonuses)
	_fp.explosive = FirstPersonView.explodes_for(bonuses)
	_fp.bounds = Rect2(-FIELD_HALF_X + 1.0, SPAWN_Z - 1.0,
			2.0 * (FIELD_HALF_X - 1.0), GOAL_Z - 1.5 - (SPAWN_Z - 1.0))
	_fp.position = Vector3(0.0, 0.0, GOAL_Z - 2.0)
	_fp.answer_input = _answer_input
	add_child(_fp)
	(_fp.get_node("Overlay/Markers") as OffscreenMarkers).track(_fp.camera,
			func() -> Array[Monster]: return _active)
	# Kopie: das Environment ist eine Ressource der Szene und käme beim nächsten Kampf in
	# der Iso-Sicht mit Nebel wieder (geladene Ressourcen sind geteilt).
	var world := $WorldEnvironment as WorldEnvironment
	var env := world.environment.duplicate() as Environment
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = env.background_color
	env.fog_depth_begin = FirstPersonView.FOG_BEGIN
	env.fog_depth_end = FirstPersonView.FOG_END
	world.environment = env
	_answer_input.gated = true
	_answer_input.weapon_switch = _fp.weapons.size() > 1


## Treffer verbuchen. `full_form` != "" heißt: die Antwort war richtig, ließ aber einen
## optionalen Bestandteil weg ("criticize" statt "criticize sb. (for)"). Das kostet
## nichts — die vollständige Form wird nur zusätzlich eingeblendet, damit das Muster
## trotzdem einmal zu sehen war.
func _score_hit(monster: Monster, text: String = "", full_form: String = "") -> void:
	var rt := Time.get_ticks_msec() - monster.spawned_at_ms
	var task_id := str(monster.task.get("learnable_id", ""))
	var newly_mastered := PlayerProgress.record(task_id, true, rt,
			float(monster.task.get("initial_confidence", -1.0)))
	EventBus.item_reviewed.emit(task_id, true, rt)
	# Nach record(), damit ein Mithörer die Confidence DANACH liest — die davor steht in
	# der Spawn-Zeile des Protokolls.
	EventBus.answer_judged.emit(text, {
		"matched": true, "complete": full_form.is_empty(), "learnable_id": task_id,
		"source_id": str(monster.task.get("source_id", "")), "response_time_ms": rt,
		"canonical": full_form, "candidates": _active_learnable_ids(),
	})
	# Nach answer_judged, damit die Spur erst die Antwort und dann die Meisterung zeigt.
	if newly_mastered:
		EventBus.task_mastered.emit(task_id)
		var lexeme_id := PlayerProgress.mastered_lexeme_of(task_id)
		if not lexeme_id.is_empty():
			EventBus.lexeme_mastered.emit(lexeme_id)
	var pos := monster.position
	var weapon := _fp.weapon if _fp != null else FirstPersonView.Weapon.NONE
	if weapon == FirstPersonView.Weapon.CHARGE:
		_defeat_by_charge(monster)
	elif weapon == FirstPersonView.Weapon.BOW:
		_defeat_by_arrow(monster)
	else:
		_defeat(monster)
	_flash_feedback(FLASH_CORRECT)
	if not full_form.is_empty():
		_spawn_form_hint(pos + Vector3(0.0, 3.4, 0.0), full_form)


## Eine Meister-Feier beginnt: der Kampf pausiert (Baum-Pause). Monster, Animationen,
## Tweens und Spawn-Timer stehen; weiter laufen nur Knoten mit process_mode ALWAYS — die
## Feier selbst, die Antwort-Eingabe und Sfx. Engine.time_scale bleibt SlowMotion.
## Die Antwortzeit misst Echtzeit ab dem Erscheinen; ohne Ausgleich zählte die Feier bei
## jedem Monster auf dem Feld als Bedenkzeit mit. Stehen mehrere Feiern an, kommt
## `started` je Feier und `finished` nach der letzten.
func _on_celebration_started(duration_ms: int) -> void:
	get_tree().paused = true
	for monster in _active:
		monster.spawned_at_ms += duration_ms


func _on_celebration_finished() -> void:
	get_tree().paused = false
	var held := _held_answers.duplicate()
	_held_answers.clear()
	for text in held:
		_on_answer_submitted(text)
	_check_end()


## Debug-Panel: feiert mit dem Wort des ersten Monsters auf dem Feld (sonst ohne Wort),
## aber an der Meisterung vorbei — Lernstand und Spur bleiben unberührt.
func _on_debug_celebration(word: bool) -> void:
	var task: Dictionary = _active[0].task if not _active.is_empty() else {}
	if word:
		_celebration.celebrate(MasteryCelebration.Kind.WORD, str(task.get("source_id", "")))
	else:
		_celebration.celebrate(MasteryCelebration.Kind.TASK, str(task.get("learnable_id", "")))


func _shake(magnitude: float = SHAKE_MAGNITUDE) -> void:
	if _cutscene:
		return
	_shake_left = SHAKE_DURATION
	_shake_mag = magnitude


func _flash_feedback(color: Color) -> void:
	_flash.color = Color(color.r, color.g, color.b, 0.35)
	_flash.modulate = Color(1, 1, 1, 1)
	create_tween().tween_property(_flash, "modulate:a", 0.0, 0.4)


## Momentaufnahme der Aufgabe eines Monsters für die Nach-Wellen-Auflösung.
## `leaked` = wurde durchgelassen (falsch); source_id/learnable_id werden fürs
## Flaggen der Vokabel im Reveal benötigt.
func _task_snapshot(monster: Monster, leaked: bool) -> Dictionary:
	return {
		"prompt": String(monster.task.get("prompt", "")),
		"prompt_alt": (monster.task.get("prompt_alt", []) as Array).duplicate(),
		"answers": (monster.task.get("accepted_answers", []) as Array).duplicate(),
		"lexeme_type": String(monster.task.get("lexeme_type", "")),
		"meaning": String(monster.task.get("meaning", "")),
		"source_id": String(monster.task.get("source_id", "")),
		"learnable_id": String(monster.task.get("learnable_id", "")),
		"leaked": leaked,
	}


func _defeat(monster: Monster) -> void:
	_book_defeat(monster)
	_burst(monster)
	_check_end()


## Sturmangriff (Späher-Baum): gebucht wird SOFORT wie bei jedem Treffer — Lernstand,
## Erfahrung, Punkte, Spur —, nur das Bild wartet, bis der Spieler in das Monster gekracht
## ist. Das Monster bleibt stehen und ist nicht mehr auf dem Feld (_active): es kann die
## Festung nicht mehr erreichen und keine zweite Antwort fangen. Das Wellenende wartet den
## Aufprall ab, sonst stünde die Statistik vor dem Knall.
func _defeat_by_charge(monster: Monster) -> void:
	_book_defeat(monster)
	monster.halt()
	_underway += 1
	await _fp.charge_at(monster.global_position)
	_underway -= 1
	if is_instance_valid(monster):
		_shake(0.6)
		_burst(monster, 2.2)
	_check_end()


## Bogen (Späher-Baum): wie der Sturmangriff — gebucht wird sofort, das Monster bleibt
## stehen und platzt, wenn der Pfeil ankommt.
func _defeat_by_arrow(monster: Monster) -> void:
	_book_defeat(monster)
	monster.halt()
	_underway += 1
	# In den Kopf: das Ziel, das man sieht, ist das Schild darüber — und dort trifft es.
	await _fp.shoot_at(monster.global_position + Vector3(0.0, monster.head_height(), 0.0))
	_underway -= 1
	if is_instance_valid(monster):
		if _fp.explosive:
			_shake(0.7)
			_blast(monster)
		else:
			_shake(0.3)
			_burst(monster, 2.0)
	_check_end()


## Ein Fehlschuss mit dem Bogen: auf das Monster, das der Bildmitte am nächsten steht, und
## daran vorbei. Die Rückmeldung (rot, Wackeln, Klang) kommt, wenn der Pfeil steckt.
func _miss_with_arrow() -> void:
	var points: Array[Vector3] = []
	for monster in _hittable():
		points.append(monster.global_position + Vector3(0.0, ARROW_AIM_Y, 0.0))
	var eye := _fp.camera.global_position
	var at := FirstPersonView.nearest_to_view(eye, -_fp.camera.global_basis.z, points)
	await _fp.shoot_past(points[at] if at >= 0 else null)
	_wrong_feedback()


func _wrong_feedback() -> void:
	_flash_feedback(FLASH_WRONG)
	_shake()
	Sfx.play(&"wrong_answer")


## Das Bild zum Treffer: Explosion, Klang, „+XP" und das Monster geht.
func _burst(monster: Monster, size: float = 1.5) -> void:
	_spawn_explosion(monster.position + Vector3(0.0, 1.0, 0.0), Color(0.7, 1.0, 0.4), size)
	_leave(monster)


## Das Bild zum Treffer mit dem Explosionspfeil: Feuerball, Rauch und Trümmer in der
## Wortfarbe, und wer daneben steht, zuckt zusammen — nur das Bild, besiegt ist allein
## das getroffene Monster.
func _blast(monster: Monster) -> void:
	_blast_at(monster)
	_leave(monster)


## Nur der Knall: Blast in der Wortfarbe, und die Nachbarn zucken. Explosionspfeil und
## Wachkatapult teilen ihn.
func _blast_at(monster: Monster) -> void:
	var fx := Blast.new()
	fx.setup(monster.word_color(), BLAST_SCALE)
	fx.position = monster.position
	add_child(fx)
	for other in _active:
		if other.position.distance_to(monster.position) <= BLAST_FLINCH_RADIUS:
			other.flinch(monster.global_position)


## Wachkatapult (Bollwerk): ein Monster mit gemeisterter Aufgabe wird nach einer kurzen,
## zufälligen Weile abgeschossen. Es läuft dabei weiter, das Katapult hält auf den Ort vor,
## an dem es beim Einschlag sein wird (catapult_lead). Trifft der Spieler es vorher selbst,
## zählt sein Treffer, und der Stein schlägt ins Leere. Erledigt ist es danach, aber nicht
## beantwortet: kein Lernstand, keine Erfahrung, keine Punkte (monster_catapulted statt
## monster_defeated), und in der Auflösung nach der Welle steht es nicht.
func _catapult_later(monster: Monster, gen: int) -> void:
	# process_always = false: in der Meister-Feier wartet auch das Katapult.
	await get_tree().create_timer(randf_range(CATAPULT_DELAY_MIN, CATAPULT_DELAY_MAX), false).timeout
	if _finished or gen != _wave_gen or not is_instance_valid(monster) or not _active.has(monster):
		return
	var turret := _nearest_catapult(monster.global_position)
	if turret == null:
		return
	var target := catapult_lead(turret.global_position, monster.global_position + CATAPULT_AIM,
			monster.velocity())
	# Ist es beim Einschlag schon an der Mauer, kommt der Stein zu spät: kein Wurf.
	if target.z >= GOAL_Z:
		return
	_underway += 1
	var from := await FortressModel.fire(turret, target)
	var stone := CatapultStone.new()
	add_child(stone)
	stone.global_position = from
	var distance := from.distance_to(target)
	await stone.fly(target, distance * CATAPULT_LIFT, catapult_flight_time(from, target))
	stone.queue_free()
	_underway -= 1
	# Die Welle ist inzwischen vorbei (gefallene Festung): nichts mehr nachbuchen.
	if _finished or gen != _wave_gen:
		return
	if is_instance_valid(monster) and _active.has(monster):
		_active.erase(monster)
		monster.halt()
		_shake(0.5)
		_blast_at(monster)
		Sfx.play(&"monster_kill")
		EventBus.monster_catapulted.emit(monster.task)
		monster.queue_free()
	else:
		# Schon getroffen oder durchgekommen: der Stein schlägt trotzdem ein.
		var fx := Blast.new()
		fx.setup(Color(0.75, 0.72, 0.66), BLAST_SCALE * 0.6)
		fx.position = target - CATAPULT_AIM
		add_child(fx)
	_check_end()


## Wie lange ein Stein von `from` nach `to` fliegt.
static func catapult_flight_time(from: Vector3, to: Vector3) -> float:
	return clampf(from.distance_to(to) * CATAPULT_TIME_PER_M, CATAPULT_TIME_MIN, CATAPULT_TIME_MAX)


## Wohin das Katapult zielt, damit der Stein das Monster trifft: dorthin, wo es nach
## Drehen, Ausschlagen und Flug steht. Monster laufen geradeaus mit festem Tempo, also ist
## das eine Gerade; die Flugzeit hängt selbst am Ziel, zweimal nachrechnen reicht.
static func catapult_lead(from: Vector3, at: Vector3, velocity: Vector3) -> Vector3:
	var windup := FortressModel.CATAPULT_TURN_TIME + FortressModel.CATAPULT_SWING_TIME
	var target := at
	for i in 3:
		target = at + velocity * (windup + catapult_flight_time(from, target))
	return target


## Das Katapult, das dem Ziel am nächsten steht, oder null, wenn keins mehr steht. Es dreht
## sich zum Ziel und schlägt aus, der Stein fliegt im Scheitel des Wurfs los
## (FortressModel.fire).
func _nearest_catapult(target: Vector3) -> Node3D:
	var best: Node3D = null
	for turret in _catapults:
		if not is_instance_valid(turret) or not turret.is_inside_tree():
			continue
		if best == null or absf(turret.global_position.x - target.x) < absf(best.global_position.x - target.x):
			best = turret
	return best


## Was jeder Treffer nach seinem Knall tut: Klang, „+XP" und das Monster geht.
func _leave(monster: Monster) -> void:
	# Hier und nicht in _spawn_explosion(): denselben Effekt nutzen auch der Festungsausbau
	# und der Aufschlag eines durchgelassenen Monsters — die klingen nicht gleich.
	Sfx.play(&"monster_kill")
	# Aufsteigende „+XP"-Animation an der Stelle des Monsters. Erfahrung und nicht die
	# Punkte: sie ist der Lernfortschritt, und sie steht im HUD als Balken beim Namen —
	# die Zahl fliegt dorthin, wo sie sich sichtbar auswirkt. Gleiche Farbe wie der Balken.
	_spawn_xp_popup(monster.position + Vector3(0.0, 2.0, 0.0), monster.xp)
	monster.queue_free()


## Was ein besiegtes Monster zählt. Ohne Bild — das kommt aus _burst.
func _book_defeat(monster: Monster) -> void:
	_active.erase(monster)
	_wave_correct += 1
	_wave_played_tasks.append(_task_snapshot(monster, false))
	# Erfahrung SOFORT verbuchen, wie das Gold in der Geldbörse: sie gehört zum Profil
	# (PlayerLevel), nicht zum Lauf, und ein Absturz mitten in der Welle darf sie nicht
	# kosten. Der Zähler daneben ist nur für den Wellenabschluss.
	PlayerLevel.gain(monster.xp)
	_wave_xp += monster.xp
	# Reward aus der monster_task_rule an GameState durchreichen (Score).
	var info := monster.monster_def.duplicate()
	info["reward"] = monster.reward
	EventBus.monster_defeated.emit(info, true)


## Deutlich sichtbarer 3D-Text (+XP), der an der Trefferstelle aufpoppt, aufsteigt
## und ausblendet. Als Label3D (Billboard) im Stil der vorhandenen Monster-Beschriftungen.
func _spawn_xp_popup(pos: Vector3, amount: int) -> void:
	var label := xp_label("+%d XP" % amount)
	_screen_size_in_first_person(label, POPUP_SCREEN_SCALE)
	label.position = pos
	label.scale = Vector3.ONE * 0.4
	add_child(label)
	var tw := create_tween()
	tw.set_parallel(true)
	# Kräftiger Pop beim Erscheinen.
	tw.tween_property(label, "scale", Vector3.ONE * 1.15, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Deutlich höher aufsteigen, über die volle Dauer.
	tw.tween_property(label, "position:y", pos.y + 4.0, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Erst gegen Ende ausblenden, damit die Zahl gut lesbar bleibt.
	tw.tween_property(label, "modulate:a", 0.0, 0.5).set_delay(0.7)
	tw.chain().tween_callback(label.queue_free)


## Die vollständige Form nach einem nur im Kern richtigen Treffer. Bewusst ruhiger als
## das "+XP"-Popup (kein Pop, längere Standzeit): es ist ein Hinweis, kein Tadel.
func _spawn_form_hint(pos: Vector3, form: String) -> void:
	var label := form_label(form)
	_screen_size_in_first_person(label, 1.4)
	label.position = pos
	add_child(label)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "position:y", pos.y + 2.0, 1.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "modulate:a", 0.0, 0.6).set_delay(1.2)
	tw.chain().tween_callback(label.queue_free)


## Das Schild des „+XP"-Popups, ohne Bewegung. Eigene Funktion, damit das Vorwärmen
## (FxWarmup) dieselbe Schrift in derselben Größe zeichnet.
static func xp_label(text: String) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = 200
	label.pixel_size = 0.02
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = Color(1.0, 0.9, 0.25)
	label.outline_size = 32
	label.outline_modulate = Color(0.15, 0.08, 0.0, 1.0)
	return label


## Das Schild des Form-Hinweises, ohne Bewegung (wie xp_label).
static func form_label(text: String) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = 130
	label.pixel_size = 0.02
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = Color(0.85, 0.95, 1.0)
	label.outline_size = 28
	label.outline_modulate = Color(0.05, 0.1, 0.2, 1.0)
	return label


## Wie groß „+XP" in der Ich-Sicht steht (gegenüber FP_TEXT_PIXEL_SIZE).
const POPUP_SCREEN_SCALE := 2.0

## Bildgröße eines Textes der Größe 64 in der Ich-Sicht (Label3D.fixed_size rechnet damit
## je Bildhöhe) — so groß stand dort früher das Prompt-Schild.
const FP_TEXT_PIXEL_SIZE := 0.0009

## In der Ich-Sicht bekommt ein aufsteigender Text eine feste Bildgröße: in Weltgröße
## füllte er nach einem Sturmangriff aus der Nähe das ganze Bild. `scale` ist die Größe
## gegenüber FP_TEXT_PIXEL_SIZE.
func _screen_size_in_first_person(label: Label3D, scale: float) -> void:
	if _fp == null:
		return
	label.fixed_size = true
	label.pixel_size = FP_TEXT_PIXEL_SIZE * scale * 64.0 / float(label.font_size)


## Instanziiert einen kurzlebigen Explosionseffekt an der Weltposition.
func _spawn_explosion(pos: Vector3, color: Color, scale: float) -> void:
	var fx := Explosion.new()
	fx.setup(color, scale)
	fx.position = pos
	add_child(fx)


## Monster hat sich beim Erreichen der Festung selbst freigegeben.
func _on_monster_reached_goal(monster: Monster) -> void:
	if not _active.has(monster):
		return
	_active.erase(monster)
	_wave_leaked += 1
	# Durchgelassene Aufgabe für die Auflösung nach der Welle merken (vor dem
	# Niederlage-Check, damit auch das die Festung fällende Monster dabei ist).
	var snapshot := _task_snapshot(monster, true)
	_wave_leaked_tasks.append(snapshot)
	_wave_played_tasks.append(snapshot)
	_spawn_explosion(monster.position + Vector3(0.0, 1.0, 0.0), Color(1.0, 0.45, 0.12), 2.6)
	_shake(0.9)
	# Tiefer als der Kill-Sound (600 statt 809 Hz Schwerpunkt): gleiche Ereignisklasse,
	# gegenteilige Bedeutung — das muss man auch dann auseinanderhalten, wenn beides
	# kurz hintereinander kommt.
	Sfx.play(&"fortress_hit")
	# Monster durchgelassen = Aufgabe nicht rechtzeitig abgerufen -> als Fehler verbuchen.
	var task_id := str(monster.task.get("learnable_id", ""))
	PlayerProgress.record(task_id, false, 0, float(monster.task.get("initial_confidence", -1.0)))
	# 0 ms: ein durchgelassenes Monster hat keine gemessene Antwortzeit.
	EventBus.item_reviewed.emit(task_id, false, 0)
	EventBus.fortress_damaged.emit(monster.damage)
	if GameState.fortress_health <= 0:
		_finish_wave(false)
		return
	_check_end()


func _check_end() -> void:
	if _finished:
		return
	# Ein Sturmangriff oder Pfeil ist noch unterwegs: sein Aufprall ruft hierher zurück.
	if _underway > 0:
		return
	# Meistert das letzte Monster etwas, wird erst gefeiert und dann abgerechnet —
	# _on_celebration_finished ruft hierher zurück.
	if _celebration.is_busy():
		return
	if _spawned >= _total and _active.is_empty():
		EventBus.wave_cleared.emit(GameState.current_wave)
		_finish_wave(true)


## Beendet die Welle und zeigt den Statistik-Screen (Sieg oder Niederlage).
func _finish_wave(won: bool) -> void:
	if _finished:
		return
	_finished = true
	_last_won = won
	if _sun_cycle != null:
		_sun_cycle.hold = false
	_set_view_active(false)
	_answer_input.visible = false
	_fast_resolve_button.visible = false
	# Endet die Welle, während die Rückfrage offen ist, gibt es nichts mehr aufzulösen.
	_fast_resolve_confirm.hide()
	# Cutscene, Auflösung und Statistik immer in Normaltempo.
	_slow_motion.stop()
	# VOR der Cutscene: der Festungsausbau bringt seinen eigenen goldenen Blitz mit, die
	# Fanfare soll ihn ankündigen statt mit ihm zu kollidieren. Bei Niederlage legt sich
	# der Sting über die Festungsexplosion desselben Monsters — die trägt die Wucht,
	# dieser hier die Stimmung.
	Sfx.play(&"wave_cleared" if won else &"fortress_destroyed")
	# Festungsausbau erst jetzt (nach gewonnener Welle), als Cutscene VOR der Statistik.
	# Die HP wachsen VOR der Cutscene mit: das Banner nennt sie, und die Statistik danach
	# soll den neuen Stand zeigen. Der HUD-Balken zieht mit dem nächsten Wellenstart nach.
	if won:
		var new_tier := _current_fortress_tier()
		if new_tier > _fortress_tier:
			var bonus := FortressTier.health_bonus(new_tier - _fortress_tier)
			_fortress_tier = new_tier
			GameState.grow_fortress(bonus)
			await _play_upgrade_cutscene(new_tier, bonus)
	# Vokabeln mit korrekter Übersetzung auflösen (Sieg wie Niederlage), als
	# Zwischenschritt VOR der Statistik. Übergeben wird die volle Liste; das Reveal
	# animiert die durchgelassenen zuerst und lässt danach alle durchblättern.
	if not _wave_played_tasks.is_empty():
		await _leak_reveal.play(_wave_played_tasks)
	var total := _wave_correct + _wave_leaked
	var accuracy := 100.0 * float(_wave_correct) / float(max(1, total))
	# Belohnung der Welle: die Punkte tragen die Schwierigkeit der besiegten Monster
	# schon in sich (siehe ChestReward), die Güte der Kiste kommt aus der Genauigkeit.
	# Gerechnet wird hier und nicht im Screen: was eine Welle wert ist, gehört zum Lauf,
	# nicht zu seiner Anzeige.
	var score_gained := GameState.score - _score_at_start
	_stats.show_stats({
		"won": won,
		"wave_number": _wave_number,
		"difficulty": _difficulty,
		"correct": _wave_correct,
		"leaked": _wave_leaked,
		"total": total,
		"accuracy": accuracy,
		"score_gained": score_gained,
		"fortress_health": GameState.fortress_health,
		"mastered": PlayerProgress.mastered_count(),
		"fortress_tier": _fortress_tier,
		"chest": ChestReward.for_wave(score_gained, _wave_correct, _wave_leaked),
		# Erfahrung: der Zuwachs DIESER Welle und die Zahl der Aufstiege darin. Den
		# Gesamtstand liest der Screen bei PlayerLevel — verbucht ist er längst (siehe
		# _defeat), hier steht nur, was die Welle daran geändert hat.
		"xp_gained": _wave_xp,
		"levels_gained": PlayerLevel.level - _level_at_start,
		# Sitzungsbilanz für Stufe 2 (Issue #12). Gebaut JETZT und nicht beim Rückweg ins
		# Menü: SessionLog.end() leert die laufende Sitzung, und die Bilanz soll schon
		# dastehen, bevor jemand auf den Menü-Knopf drückt.
		"session": RunBalance.build(SessionLog.current(),
				PlayerProgress.records_for_display(), _wave_number),
	})


## Der Spieler hat die Schatzkiste aufgedrückt: das Gold gehört ihm. Verbucht wird hier
## und nicht im Screen — das Gold hängt am Profil (Wallet), und der Screen soll nichts
## schreiben, was er nur anzeigt. Die Geldbörse sichert sofort: ein Absturz auf dem Weg
## in die nächste Welle darf die Kiste nicht rückgängig machen.
func _on_reward_collected(gold: int) -> void:
	Wallet.earn(gold, true)


## Spieler hat auf dem Statistik-Screen die nächste Welle gerufen. Die Wahl ist RELATIV:
## `delta` (-2..+2) verschiebt die aktuelle Schwierigkeit, begrenzt auf 1..5.
func _on_next_wave_requested(delta: int) -> void:
	# Eine gefallene Festung beendet den Lauf: der Statistik-Screen blendet die
	# Schwierigkeitswahl und den Startknopf dann aus (wave_stats.gd). Der Riegel steht
	# hier nochmal, damit die Regel nicht allein an der Sichtbarkeit eines Knopfes hängt
	# — mit 0 HP wäre die Folgewelle ohnehin beim ersten Treffer wieder verloren.
	if not _last_won:
		return
	_difficulty = clampi(_difficulty + delta, 1, 5)
	_wave_number += 1
	_start_next_wave()


## Spieler kehrt vom Statistik-Screen ins Menü zurück. Fortschritt explizit sichern
## (der Niederlage-Pfad emittiert kein wave_cleared) und die Menü-Szene laden.
func _on_back_to_menu() -> void:
	PlayerProgress.save_progress()
	_report_run_ended()
	_leave_battle()


## Meldet das Ende des Laufs mit dem, was nur hier bekannt ist. Beide Ausgänge gehen
## darüber — der Rückweg über den Statistik-Screen und der Abbruch mitten in der Welle.
## Ein freiwilliger Ausstieg ist genauso ein Sitzungsende wie eine gefallene Festung;
## SessionLog.end() ist gegen doppelte Meldung abgesichert.
func _report_run_ended() -> void:
	EventBus.run_ended.emit({
		"wave_reached": _wave_number,
		"difficulty_last": _difficulty,
		"last_wave_won": _last_won,
	})
