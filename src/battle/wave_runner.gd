extends Node3D
## Der Wellenkampf in 3D: spawnt Monster, gleicht Spielerantworten gegen aktive Monster ab
## und erkennt das Wellenende.

const MONSTER_SCENE := preload("res://scenes/entities/monster.tscn")
const FIRST_PERSON_SCENE := preload("res://scenes/battle/first_person_view.tscn")
const GOAL_Z := 16.5          # Festungsfront (Monster-Ziel)
const SPAWN_Z := -24.0        # Spawn am hinteren Ende der Bahn (längerer Anmarsch)
const LANE_HALF_WIDTH := 8.0
const TYPING_POLL := 0.1       # s, so oft prüft der Spawn, ob die lange Antwort erledigt ist
## Bildmitte auf der Bahn (z); der Boden richtet sich danach. Eingestellt in battle_theme_lab.
const VIEW_CENTER_Z := -3.5

const SHAKE_DURATION := 0.35
const SHAKE_MAGNITUDE := 0.35 # in 3D-Einheiten
## Heranfahrt im Standbild (SpellingFreeze): Bildwinkel bzw. Bildgröße als Faktor und
## Anteil der Drehung bzw. des Wegs zum Ziel.
const SPELLING_FOV := 0.6
const SPELLING_TURN := 0.6
const SPELLING_ISO_SIZE := 0.6
const SPELLING_ISO_PAN := 0.6
const FLASH_CORRECT := Color(0.3, 1.0, 0.45)
const FLASH_WRONG := Color(1.0, 0.3, 0.3)

var _evaluator := AnswerEvaluator.new()
var _generator := WaveGenerator.new()
var _active: Array[Monster] = []
var _total: int = 0
var _spawned: int = 0
var _finished: bool = false
## Kein Spawn möglich: keine Welle, der Hinweis steht, Escape führt zurück.
var _no_content: bool = false

var _difficulty: int = 3           # 1..5, vom Spieler gewählt
var _wave_number: int = 1          # laufende Nummer (Anzeige + Skalierung)
var _wave_correct: int = 0         # richtig besiegte Monster dieser Welle
var _wave_leaked: int = 0          # an der Festung durchgelassene Monster dieser Welle
var _wave_leaked_tasks: Array[Dictionary] = []  # deren Aufgaben (prompt + accepted_answers), für die Auflösung
var _wave_played_tasks: Array[Dictionary] = []  # alle gespielten Aufgaben der Welle, richtig und falsch
var _score_at_start: int = 0       # Punktestand zu Wellenbeginn (für "+X" im Screen)
var _wave_xp: int = 0              # in dieser Welle verdiente Erfahrung (für den Screen)
var _level_at_start: int = 1       # Spielerlevel zu Wellenbeginn (für "Aufgestiegen!")
var _last_won: bool = true         # Ausgang der zuletzt beendeten Welle
# Bricht Spawn-Coroutinen einer alten Welle ab; _finished allein setzt die neue zurück.
var _wave_gen: int = 0
## Läuft der Rest der Welle gerade im Zeitraffer (siehe _fast_resolve_wave)?
var _fast_resolving: bool = false
## Während einer Feier abgeschickte Antworten, danach der Reihe nach ausgewertet.
var _held_answers: Array[String] = []
## Monster, nach deren Zerplatzen das Standbild der Schreibweise kommt: Instanz-Id ->
## [richtige Form, markierte Stellen]. Mit Pfeil oder Sturmangriff platzt es erst später.
var _spelling_due: Dictionary = {}
## Gezeigte Grundwörter der Welle: Lexem-id → Spawn-Nummer (WaveGenerator.pick()).
var _wave_shown: Dictionary = {}
## Neue Aufgaben mit Lösung auf dem Schild und ihre Wiederholung (ADR 0027), je Lauf.
var _intro := Introductions.new()
## Monster mit nicht gemeisterter Aufgabe seit `_open_from` (Spawn-Nummer: Wellenbeginn
## oder Fortsetzung); WaveGenerator.open_due() sagt, ob pick() Offenes vorziehen muss.
var _wave_open: int = 0
var _open_from: int = 0
## Testliste (TestPlaylist): Grundwörter der vorigen Welle und Reihenfolge dieser.
var _previous_shown: Dictionary = {}
var _playlist_order: Array = []

var _cam_base: Vector3
var _shake_left: float = 0.0
var _shake_mag: float = SHAKE_MAGNITUDE
var _rng := RandomNumberGenerator.new()

var _fortress: Node3D = null
## Festungsstufe des Laufs: die schwächste Unit im gespielten Bereich (FortressTier.run_tier).
var _fortress_tier: int = -1
var _cutscene: bool = false   # läuft gerade die Ausbau-Cutscene? (unterdrückt Kamera-Wackeln)
## Die Ich-Sicht, oder null für die Iso-Kamera; die einzige Auskunft über die Sicht.
var _fp: FirstPersonView = null
## Lässt sich die Sicht in diesem Kampf wechseln? Einmal am Anfang gefragt.
var _view_selectable := false
## Die gelernten Boni des Laufs, für eine später entstehende Ich-Sicht.
var _skill_bonuses: Dictionary = {}
## Das Environment der Iso-Sicht; die Ich-Sicht nebelt eine Kopie.
var _iso_env: Environment = null
## Die Grasbüschel der Streudeko: aus Augenhöhe stehen sie kleiner (GRASS_SCALE_FIRST_PERSON).
var _grass: Array[Node3D] = []
## Laufende Sturmangriffe, fliegende Pfeile und Steine: so lange wartet das Wellenende.
var _underway := 0
## Explosionen, die noch zu sehen sind: auch darauf wartet das Wellenende (`_settle`).
var _settling := 0
## Wachkatapult gelernt (Bollwerk, `auto_catapult`).
var _catapult := false
## Zeitwandler (SkillTree.monster_pace / spawn_gap_scale): Faktor auf Lauftempo und
## Spawn-Abstand. Punkte bleiben unberührt.
var _monster_pace := 1.0
var _spawn_gap_scale := 1.0
## Das Monster mit langer Antwort, auf das der nächste Spawn wartet (ADR 0026).
var _typing_monster: Monster = null
## Die Katapulte der Festung (FortressModel.catapults), erst ab FortressModel.CATAPULT_TIER.
var _catapults: Array[Node3D] = []
## Höhe (m), an der ein Fehlschuss vorbeizielt: die Körpermitte.
const ARROW_AIM_Y := 1.2
## Explosionspfeil: Größe des Knalls (Blast) und Radius (m), in dem die Nachbarn zucken.
const BLAST_SCALE := 1.0
const BLAST_FLINCH_RADIUS := 5.0
## So lange (s) ist eine Explosion zu sehen, bevor das Wellenende sie verdecken darf.
const EXPLOSION_SETTLE := 0.9
const BLAST_SETTLE := 1.2
## Wachkatapult: Wurf zufällig so lange (s) nach dem Spawn.
const CATAPULT_DELAY_MIN := 1.0
const CATAPULT_DELAY_MAX := 3.0
## Flugzeit des Steins je Meter (s) mit Grenzen; Scheitelhöhe als Anteil der Strecke.
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
## Hinter dem Schleier wird noch vorgewärmt; solange bricht Escape nicht ab.
var _warming := false
## Kampfzeit der laufenden Welle (SessionLog); steht zwischen den Wellen.
var _battle_clock := BattleClock.new()
@onready var _end_label: Label = $UI/EndLabel
@onready var _flash: ColorRect = $UI/Flash
@onready var _stats: PanelContainer = $UI/WaveStats
@onready var _leak_reveal: Control = $UI/LeakReveal
@onready var _answer_input: LineEdit = $UI/AnswerInput
@onready var _slow_motion: SlowMotion = $SlowMotion
@onready var _fast_resolve_button: Button = $UI/FastResolveButton
@onready var _fast_resolve_confirm: ConfirmDialog = $UI/FastResolveConfirm
## Rückfrage vor dem Abbruch eines Laufs, der etwas wert ist (ADR 0020, `_request_abort`).
@onready var _abort_confirm: ConfirmDialog = $UI/AbortConfirm
@onready var _pause_overlay: PauseOverlay = $UI/PauseOverlay
@onready var _pause_button: Button = $UI/PauseButton
@onready var _view_button: Button = $UI/ViewButton
@onready var _word_plates: WordPlates = $UI/WordPlates
## Seit wann der Spieler pausiert hat (Echtzeit, ms); -1 ohne Spielerpause.
var _paused_since_ms := -1
@onready var _celebration: MasteryCelebration = $UI/MasteryCelebration
@onready var _spelling: SpellingFreeze = $UI/SpellingFreeze
@onready var _level_flare: LevelFlare = $UI/HUD.level_flare
@onready var _spell_slots: SpellSlots = $UI/SpellSlots
@onready var _spell_banner: SpellBanner = $UI/SpellBanner
## Was ein Zauber aus dem Vorrat tut (ADR 0014); wie es aussieht, macht `_spell_fx`.
var _spells := SpellCaster.new()
## Setzt dieser Kampf einen begonnenen Lauf fort (RunSave, ADR 0020)?
var _resumed := false
## Die gerastete Welle (RunSave.open_wave), bis `_start_next_wave` sie nimmt.
var _open_wave: Dictionary = {}
## Beginn des Laufs (SessionLog `started_at`), bei einem fortgesetzten der des ersten Teils.
var _run_started_at := 0
## Hat die Abbruch-Rückfrage selbst pausiert? Dann hebt „Weiterspielen“ die Pause auf.
var _abort_paused_here := false
var _spell_fx := SpellFx.new()
## Der wievielte Blitz des laufenden Donnerschlags als nächster fällt (`_strike`).
var _strike_index := 0
## Kleine Erfolge; gezeigt von der Meister-Feier.
var _badges := Badges.new()
## Tiefster HP-Stand der laufenden Welle — für das Comeback.
var _wave_low_hp := 0
## Monster.seconds_left des Treffers, der das Feld zuletzt geleert hat (Badges.wave_won).
var _last_left := INF
## Sind die Plaketten der gewonnenen Welle schon gemeldet? _check_end kommt zweimal.
var _wave_badges_done := false
## Ob der Ausgang schon gespeichert hat (Rückweg oder Abbruch) — sonst verwirft _exit_tree.
var _saved_on_exit := false
## Die nächste Beispiel-Plakette des Debug-Panels.
var _debug_badge := 0


func _ready() -> void:
	_rng.randomize()
	_view_selectable = RunRequest.first_person_selectable()
	_setup_view()
	# Gelände für den weitesten Blick (SceneZoom), Teilchen nur für den Kampfblick.
	var view_size := _camera.size
	var air_area := visible_ground_area(_camera)
	_camera.size = view_size / SceneZoom.FROM
	# Das Thema vor Boden und Ich-Sicht: beide nehmen seine Farben.
	_theme = BattleTheme.for_level(RunRequest.theme_level())
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
	# Den Speicherstand schon hier: eine gerastete Welle steht mit ihrer alten Festung da.
	var resume := RunRequest.take_resume()
	_build_fortress(int(RunSave.open_wave(resume).get("fortress_tier", -1)))
	_cam_base = _camera.position
	GameState.reset()
	# Skills direkt nach reset(); ein Dictionary für alle, mit dem HP-Bonus der Festungsstufe.
	var skill_bonuses := SkillBook.bonuses().duplicate()
	skill_bonuses["max_health"] = int(skill_bonuses.get("max_health", 0)) \
			+ FortressTier.health_bonus(_fortress_tier)
	GameState.apply_skills(skill_bonuses)
	_slow_motion.apply_skills(skill_bonuses)
	if UserSettings.typing_standstill():
		_slow_motion.stand_still()
	_catapult = float(skill_bonuses.get("auto_catapult", 0.0)) > 0.0
	_monster_pace = SkillTree.monster_pace(skill_bonuses)
	_spawn_gap_scale = SkillTree.spawn_gap_scale(skill_bonuses)
	_skill_bonuses = skill_bonuses
	if RunRequest.first_person():
		_setup_first_person()
	# Gespeichert wird ab hier nur an der Wellengrenze (ADR 0024).
	SaveCoordinator.hold()
	SaveCoordinator.register(_badges)
	# Der Lauf beginnt hier, nicht mit der ersten Welle.
	EventBus.run_started.emit()
	EventBus.answer_submitted.connect(_on_answer_submitted)
	var debug_panel := $UI/DebugPanel
	if debug_panel.has_signal("fortress_tier_selected"):
		debug_panel.fortress_tier_selected.connect(_on_debug_tier_selected)
	if debug_panel.has_signal("celebration_requested"):
		debug_panel.celebration_requested.connect(_on_debug_celebration)
	if debug_panel.has_signal("badge_requested"):
		debug_panel.badge_requested.connect(_on_debug_badge)
	if debug_panel.has_signal("level_up_requested"):
		debug_panel.level_up_requested.connect(_level_flare.play)
	if _stats.has_signal("next_wave_requested"):
		_stats.next_wave_requested.connect(_on_next_wave_requested)
	if _stats.has_signal("back_to_menu_requested"):
		_stats.back_to_menu_requested.connect(_on_back_to_menu)
	if _stats.has_signal("review_requested"):
		_stats.review_requested.connect(_on_review_requested)
	if _stats.has_signal("reward_collected"):
		_stats.reward_collected.connect(_on_reward_collected)
	if _stats.has_signal("consolation_collected"):
		_stats.consolation_collected.connect(func(gold: int) -> void:
				Wallet.earn(gold)
				SaveCoordinator.commit("chest"))
	_fast_resolve_button.pressed.connect(_on_fast_resolve_pressed)
	_fast_resolve_confirm.confirmed.connect(_fast_resolve_wave)
	_fast_resolve_confirm.cancelled.connect(_on_fast_resolve_cancelled)
	_pause_overlay.toggle_requested.connect(_on_pause_key)
	# Esc in der Pause beendet den Kampf mit derselben Rückfrage.
	_pause_overlay.leave_requested.connect(_request_abort)
	_abort_confirm.confirmed.connect(_on_abort_confirmed)
	_abort_confirm.cancelled.connect(_on_abort_cancelled)
	_pause_button.pressed.connect(_toggle_pause)
	_view_button.pressed.connect(_toggle_view)
	_view_button.set_pressed_no_signal(_fp != null)
	_celebration.started.connect(_on_celebration_started)
	_celebration.finished.connect(_on_celebration_finished)
	_celebration.cut_short.connect(func(remaining_ms: int) -> void:
		for monster in _active:
			monster.spawned_at_ms -= remaining_ms)
	_spelling.started.connect(_on_spelling_started)
	_spelling.finished.connect(_on_spelling_finished)
	_spells.strike = _strike
	_spells.reveal_delay = _spell_fx.reveal_delay
	_spells.start_z = SPAWN_Z
	_spell_fx.settled.connect(_check_end)
	_spell_fx.veil = $UI/SpellVeil as ColorRect
	_spell_fx.shake = _shake
	_spell_fx.front_z = GOAL_Z
	_spell_fx.back_z = SPAWN_Z
	_spell_fx.half_width = LANE_HALF_WIDTH
	_spells.back_speed = _spell_fx.sweep_speed()
	_spell_fx.fortress = Vector3(0.0, 0.0, GOAL_Z + 2.0 * FORTRESS_GROW)
	add_child(_spell_fx)
	_difficulty = UserSettings.default_difficulty()
	_resume_run(resume)
	add_child(_battle_clock)
	_battle_clock.hold(true)
	_start_next_wave()
	# Hinter dem Schleier vorwärmen (FxWarmup).
	_scene_zoom.hold()
	_warming = true
	await _warm_up()
	_warming = false
	_battle_clock.hold(false)
	_scene_zoom.reveal(func(k: float) -> void:
		_camera.size = view_size / lerpf(SceneZoom.FROM, 1.0, k))


## Vorwärmen (FxWarmup); die feste Bildgröße der Ich-Sicht ist eine eigene Shader-Variante.
func _warm_up() -> void:
	var xp := xp_label(FxWarmup.GLYPHS)
	_screen_size_in_first_person(xp, POPUP_SCREEN_SCALE)
	var at := FxWarmup.point_in_view(get_viewport().get_camera_3d(),
			Vector3(0.0, 1.0, VIEW_CENTER_Z))
	_celebration.warm_up()
	AchievementToast.warm_up()
	_spelling.warm_up()
	_level_flare.warm_up()
	var extras: Array[Node3D] = [xp]
	# Pfeil und Schild der Ich-Sicht auch von oben, wenn die Sicht umschaltbar ist.
	var explosive := FirstPersonView.explodes_for(_skill_bonuses)
	if _fp != null or _view_selectable:
		var arrow := Arrow.new()
		arrow.trail = true
		extras.append(arrow)
		if _fp == null:
			var fp_xp := xp_label(FxWarmup.GLYPHS)
			_size_for_first_person(fp_xp, POPUP_SCREEN_SCALE)
			extras.append(fp_xp)
		if explosive:
			var ember := Arrow.new()
			ember.trail = true
			ember.glowing = true
			extras.append(ember)
			extras.append(Blast.new())
	if _theme.tumbleweeds:
		extras.append(Tumbleweeds.specimen())
	if _catapult:
		extras.append(CatapultStone.new())
	if not ((_fp != null or _view_selectable) and explosive):
		extras.append(Blast.new())
	# Zauber (ADR 0014) gibt es in jedem Kampf.
	extras.append_array(SpellFx.specimens(at))
	await FxWarmup.run(self, at, FxWarmup.monster_defs(), extras, _fp != null)
	_celebration.cool_down()
	AchievementToast.cool_down()
	_spelling.cool_down()
	_level_flare.cool_down()


## Zurück auf die Karte oder ins Menü, als Zoom hinaus (MapSelection.zoom_out).
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


# Terrain: flaches Innenfeld, Hügel am Rand, bis an den Bildrand (`visible_ground_area`).

## Rasterweite (m).
const TERRAIN_STEP := 1.5
## Abstand vom Innenfeld (m), ab dem die Hügel nicht weiter wachsen, und ihr Höhenfaktor.
const TERRAIN_EDGE_MAX := 8.0
const TERRAIN_HEIGHT_SCALE := 0.6
const TERRAIN_HEIGHT_MAX := TERRAIN_EDGE_MAX * TERRAIN_HEIGHT_SCALE
## Breitestes Seitenverhältnis, für das der Boden reicht (`keep_aspect` hält die Höhe).
const VIEW_MAX_ASPECT := 2.4
## Zugabe in Bildeinheiten beim Aussortieren unsichtbarer Kacheln, für Hügelhöhe und
## Wackeln (SHAKE_MAGNITUDE).
const VIEW_MARGIN := TERRAIN_HEIGHT_MAX + SHAKE_MAGNITUDE

var _terrain_noise: FastNoiseLite
## Farben von Boden und Licht für die Unit des Laufs.
var _theme: BattleTheme
## Stellt die Sonne nach der Uhr; hält während einer Welle den Sprung auf den Morgen an.
var _sun_cycle: SunCycle
## Der Weg zum Tor; die Streudeko hält ihn frei.
var _path: BattlePath
## Fußpunkte der gestreuten Bäume, für die Sträucher darum (GroundCover).
var _tree_feet: Array[Vector3] = []
## Wie viele Feuer der Deko noch ein Licht bekommen.
var _fire_lights := GraphicsQuality.fire_lights()
## Kronen der Laubbäume darunter, aus denen das Laub fällt (AmbientParticles).
var _leaf_crowns: Array[AABB] = []
var _blossom_crowns: Array[AABB] = []

func _setup_ground() -> void:
	_terrain_noise = terrain_noise(_rng.randi())
	_path = BattlePath.make(_theme.path, GOAL_Z, _rng)
	var ground := $Ground as MeshInstance3D
	ground.mesh = build_terrain(_camera, _terrain_noise, _theme)
	dress_ground(ground, _theme, _path)


## Material und Schatten des Bodens. Er wirft keinen Schatten, so reicht ein kleiner Bias.
static func dress_ground(ground: MeshInstance3D, theme: BattleTheme, path: BattlePath = null,
		quality := GraphicsQuality.level()) -> void:
	ground.material_override = theme.ground_material(path)
	if not GraphicsQuality.clouds(quality):
		(ground.material_override as ShaderMaterial).set_shader_parameter("clouds", 0.0)
	if not GraphicsQuality.patches(quality):
		(ground.material_override as ShaderMaterial).set_shader_parameter("patch_amount", 0.0)
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Das Rauschen des Terrains, für Boden, Streudeko und Tests dasselbe.
static func terrain_noise(seed_value: int) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.06
	return noise


## Baut den sichtbaren Boden für diese Kamera. Ohne Thema gilt die Vorgabe von BattleTheme.
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
			# Das Sichtfeld ist eine Raute im x/z-Raster (45° Gierwinkel).
			if tile_on_screen(camera, x, z):
				var a := _terrain_point(x, z, noise)
				var b := _terrain_point(x, z + TERRAIN_STEP, noise)
				var c := _terrain_point(x + TERRAIN_STEP, z + TERRAIN_STEP, noise)
				var d := _terrain_point(x + TERRAIN_STEP, z, noise)
				# Im Uhrzeigersinn von oben, Godots Vorderseite; sonst zeigte die Normale nach unten.
				_add_terrain_tri(st, noise, theme, a, c, b)
				_add_terrain_tri(st, noise, theme, a, d, c)
			z += TERRAIN_STEP
		x += TERRAIN_STEP
	return st.commit()


## x/z-Bereich, in dem der Boden im Bild liegen kann: Bildecken auf y=0 geschnitten, aufs
## Kachelraster gerundet. Braucht eine eingerichtete Kamera (`setup_view`).
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


## Liegt die Kachel mit der Ecke (x,z) im Bild? Nicht über `unproject_position`, das rechnet
## die Fenstergröße ein.
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


## Halbe Breite des flachen Bodens (m).
const FLAT_HALF_X := 9.0 * FORTRESS_GROW


## Rückweichen des Hügelfußes (m, höchstens) und Frequenz seiner Bögen (1/m).
const TERRAIN_FOOT_SHIFT := 6.0
const TERRAIN_FOOT_WAVE := 0.045


static func terrain_height(x: float, z: float, noise: FastNoiseLite) -> float:
	# Innenfeld flach (so breit wie die Festung, bis hinter den Spawn), außen Hügel. Der Fuß
	# weicht nur nach außen zurück; hinter dem Spawn zählt der Abstand zur Ecke (rund).
	# Die Versätze 200/400 entkoppeln die Rauschproben der Kanten.
	var ex := absf(x) - FLAT_HALF_X - _foot_shift(z * signf(x) + 200.0, noise)
	var ez := -z + SPAWN_Z - _foot_shift(x + 400.0, noise)
	var edge := Vector2(maxf(ex, 0.0), maxf(ez, 0.0)).length() if ex > 0.0 and ez > 0.0 \
			else maxf(ex, ez)
	if edge <= 0.0:
		return 0.0
	var n := noise.get_noise_2d(x, z) * 0.5 + 0.5
	return clampf(edge, 0.0, TERRAIN_EDGE_MAX) * (0.3 + 0.7 * n) * TERRAIN_HEIGHT_SCALE


## Rückweichen des Hügelfußes an der Stelle `t` längs seiner Kante, 0 bis TERRAIN_FOOT_SHIFT.
static func _foot_shift(t: float, noise: FastNoiseLite) -> float:
	var n := noise.get_noise_2d(t * TERRAIN_FOOT_WAVE / noise.frequency, 777.0) * 0.5 + 0.5
	return TERRAIN_FOOT_SHIFT * smoothstep(0.2, 0.8, n)


static func _add_terrain_tri(st: SurfaceTool, noise: FastNoiseLite, theme: BattleTheme, a: Vector3, b: Vector3, c: Vector3) -> void:
	# Farbe und Normale je Ecke aus der Funktion, damit Nachbardreiecke sie teilen.
	for v: Vector3 in [a, b, c]:
		st.set_color(_terrain_color(v, noise, theme))
		st.set_normal(terrain_normal(v.x, v.z, noise))
		st.add_vertex(v)


static func _terrain_color(p: Vector3, noise: FastNoiseLite, theme: BattleTheme) -> Color:
	return theme.ground_color(BattleTheme.ground_t(noise, p.x, p.z), p.y)


## Normale der Höhenfunktion bei (x,z), über zentrale Differenzen.
static func terrain_normal(x: float, z: float, noise: FastNoiseLite) -> Vector3:
	var e := TERRAIN_STEP * 0.5
	var dx := terrain_height(x + e, z, noise) - terrain_height(x - e, z, noise)
	var dz := terrain_height(x, z + e, noise) - terrain_height(x, z - e, noise)
	return Vector3(-dx, 2.0 * e, -dz).normalized()


## Bodenhöhe des Terrains an (x,z).
func _ground_y(x: float, z: float) -> float:
	return terrain_height(x, z, _terrain_noise) if _terrain_noise != null else 0.0


## Platziert eines der Modelle eines Deko-Platzes (`BattleTheme.trees` …) auf Terrain-Höhe
## mit zufälliger Drehung; nicht auf dem Weg. Bäume merken sich ihren Fuß (`_tree_feet`).
func _scatter(parent: Node3D, slot: Array[String], x: float, z: float, scale: float) -> Node3D:
	# 0.4 m Radius je Einheit der Skalierung hält den Weg frei.
	if slot.is_empty() or (_path != null and _path.blocks(x, z, 0.4 * scale)):
		return null
	var model := slot[_rng.randi() % slot.size()]
	var at := Vector3(x, _ground_y(x, z), z)
	var inst := _place_model(parent, model.get_file(), at,
			_rng.randf_range(0.0, 360.0), Vector3.ONE * scale, model.get_base_dir())
	Wind.sway(inst, model, _theme.wind)
	_fire_lights -= Fire.kindle(inst, _fire_lights)
	if slot == _theme.trees:
		_tree_feet.append(at)
		if AmbientParticles.LEAF_TREES.has(model.get_file().get_basename()):
			_leaf_crowns.append(AmbientParticles.crown_of(inst))
		elif AmbientParticles.BLOSSOM_TREES.has(model.get_file().get_basename()):
			_blossom_crowns.append(AmbientParticles.crown_of(inst))
	return inst


const GRASS_SCALE_FIRST_PERSON := 0.4

## Zufällige Streudeko vor der Festung. Welche Modelle, sagt das Thema; wo und wie groß (m),
## steht hier.
func _decorate() -> void:
	var d := Node3D.new()
	d.name = "Decor"
	add_child(d)

	var z_back := SPAWN_Z - 2.0    # bis knapp hinter den Spawn
	# Bis kurz vor die Festung; ihre Ecktürme ragen mit ihrer Größe weiter vor.
	var z_front := GOAL_Z - 3.0 * FORTRESS_GROW

	for i in _rng.randi_range(8, 14):
		var sx := (1.0 if _rng.randf() < 0.5 else -1.0) * _rng.randf_range(9.5, 12.5)
		_scatter(d, _theme.trees, sx, _rng.randf_range(z_back, z_front), _rng.randf_range(0.85, 1.2))

	for i in _rng.randi_range(5, 10):
		_scatter(d, _theme.rocks, _rng.randf_range(-10.0, 10.0), _rng.randf_range(z_back, z_front), _rng.randf_range(1.6, 2.6))

	# Grasbüschel, für die Draufsicht bemessen; die Ich-Sicht macht sie kleiner (_scale_grass).
	for i in _rng.randi_range(22, 34):
		var tuft := _scatter(d, _theme.grass, _rng.randf_range(-11.0, 11.0), _rng.randf_range(z_back, z_front + 0.5), _rng.randf_range(1.2, 2.0))
		if tuft != null:
			_grass.append(tuft)

	for i in _rng.randi_range(3, 6):
		var bx := (1.0 if _rng.randf() < 0.5 else -1.0) * _rng.randf_range(8.5, 10.5)
		_scatter(d, _theme.props, bx, _rng.randf_range(SPAWN_Z + 4.0, GOAL_Z - 3.0), 1.0)

	for i in _rng.randi_range(1, 2):
		var lx := (1.0 if _rng.randf() < 0.5 else -1.0) * _rng.randf_range(10.0, 12.5)
		_scatter(d, _theme.landmarks, lx, _rng.randf_range(z_back, z_front), _rng.randf_range(0.8, 1.0))

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


## Das Innenfeld ohne Streudeko: Bahn plus Festung im Vollausbau (m).
const FORTRESS_GROW := FortressModel.SCALE / FortressModel.LAYOUT_SCALE
const FIELD_HALF_X := 11.0 * FORTRESS_GROW
const FIELD_Z_BACK := SPAWN_Z - 3.0
const FIELD_Z_FRONT := GOAL_Z + 11.0 * FORTRESS_GROW
## Zugabe in Bildeinheiten um den Bildstreifen des Innenfelds, für die Breite der Modelle.
const FIELD_CLEARANCE := 4.0


## Radius eines Hains im Umland (m).
const GROVE_RADIUS := 5.0


## Das Umland bis zum Bildrand, ohne Gras (ein Büschel wäre dort ein Knoten für ein Pixel).
func _decorate_outskirts(d: Node3D) -> void:
	var area := visible_ground_area(_camera)
	var field := _field_span()
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


## Zufälliger Punkt im Umland (Verwerfungsverfahren, 16 Versuche), oder Vector2.INF.
func _outskirts_point(area: Rect2, field: Dictionary) -> Vector2:
	for attempt in 16:
		var x := _rng.randf_range(area.position.x, area.end.x)
		var z := _rng.randf_range(area.position.y, area.end.y)
		if _blocks_field(x, z, field) or not tile_on_screen(_camera, x, z):
			continue
		return Vector2(x, z)
	return Vector2.INF


## Bildstreifen (`u_min`/`u_max`) und kleinste Tiefe (`depth`) des Innenfelds.
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


## Waagerechte Bildkoordinate eines Bodenpunkts; `basis.x` liegt waagerecht.
func _screen_u(x: float, z: float) -> float:
	return (Vector3(x, 0.0, z) - _camera.global_position).dot(_camera.global_transform.basis.x)


## Abstand eines Bodenpunkts längs der Blickrichtung. Kleiner heißt näher an der Kamera.
func _view_depth(x: float, z: float) -> float:
	return (Vector3(x, 0.0, z) - _camera.global_position).dot(-_camera.global_transform.basis.z)


## Würde etwas bei (x,z) das Innenfeld verstellen? Auf ihm oder im Bild davor.
func _blocks_field(x: float, z: float, field: Dictionary) -> bool:
	if absf(x) <= FIELD_HALF_X and z >= FIELD_Z_BACK and z <= FIELD_Z_FRONT:
		return true
	var u := _screen_u(x, z)
	if u < field["u_min"] - FIELD_CLEARANCE or u > field["u_max"] + FIELD_CLEARANCE:
		return false
	return _view_depth(x, z) < field["depth"] + FIELD_CLEARANCE


## Festung aus dem KayKit Medieval Hexagon Pack (CC0, Kay Lousberg), siehe FortressModel.
const FORTRESS_SCALE := FortressModel.SCALE
const WALL_YAW := FortressModel.WALL_YAW   # für battle_theme_lab

## `cap` (ab 0): die Stufe, mit der eine gerastete Welle begonnen hat. Ein Wachstum seitdem
## kommt wie sonst am Ende der Welle (`_finish_wave`).
func _build_fortress(cap := -1) -> void:
	_fortress_tier = _current_fortress_tier()
	if cap >= 0:
		_fortress_tier = mini(_fortress_tier, cap)
	_spawn_fortress(_fortress_tier)


## Die Festungsstufe für Scope und Tags des Laufs (FortressTier.run_tier). Ein Bonus zählt
## nur über bonus_units (ADR 0013).
func _current_fortress_tier() -> int:
	var scope := RunRequest.scope()
	var plain := scope.filter(func(key): return not str(key).begins_with(ContentRegistry.BONUS_PREFIX))
	var scoped: Array = [] if plain.is_empty() and not scope.is_empty() \
			else ContentRegistry.lexemes_scoped(plain, RunRequest.tags())
	var units := FortressTier.unit_tiers(ContentRegistry.lexemes.values(),
			PlayerProgress.mastered_lexemes(), FortressTier.drop_of(SkillBook.bonuses()))
	return FortressTier.run_tier(scoped, units, ContentRegistry.bonus_units(RunRequest.scope()))


## Baut die Festung zur Stufe (0..4) neu auf; die Mauerfront ist die Ziel-Linie der Monster.
func _spawn_fortress(tier: int) -> void:
	var fort := Node3D.new()
	fort.name = "Fortress"
	add_child(fort)
	_fortress = fort
	print("[FORTRESS] Stufe %d (+%d HP)" % [tier, FortressTier.health_bonus(tier)])
	FortressModel.build(fort, tier, GOAL_Z, _ground_y, FortressModel.SCALE, _theme.fortress_wear)
	_catapults = FortressModel.catapults(fort)


## Baut die Festung mit kurzem Bau-Effekt neu auf. Nur das Bild.
func _rebuild_fortress(tier: int) -> void:
	if is_instance_valid(_fortress):
		_fortress.queue_free()
	_spawn_fortress(tier)
	_spawn_explosion(Vector3(0.0, 1.5, GOAL_Z + 2.0 * FORTRESS_GROW), Color(1.0, 0.9, 0.4), 2.0)


## Cutscene beim Festungsausbau: Zoom, Blitz, Banner, zurück. Ohne Kamera-Wackeln.
func _play_upgrade_cutscene(tier: int, bonus: int) -> void:
	_rebuild_fortress(tier)
	# Überlappende Cutscenes vermeiden: nur die erste inszeniert, weitere bauen still um.
	if _cutscene:
		return
	_cutscene = true
	_shake_left = 0.0                 # laufendes Wackeln stoppen, sonst kämpft es mit der Fahrt
	if _fp != null:
		# Ich-Sicht: keine Fahrt, Blitz und Banner stehen so lange wie die Fahrt der Iso-Kamera.
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

	_spawn_explosion(Vector3(0.0, 2.0, GOAL_Z + 2.0 * FORTRESS_GROW), Color(1.0, 0.85, 0.3), 3.0)
	_show_upgrade_banner(tier, bonus)

	var tw_in := create_tween()
	tw_in.set_parallel(true)
	tw_in.tween_property(pivot, "position", focus, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw_in.tween_property(_camera, "size", size_base * minf(0.42 * FORTRESS_GROW, 1.0), 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw_in.finished
	await get_tree().create_timer(1.1).timeout

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


## Debug-Panel: zeigt eine Ausbaustufe, ohne die Stufe des Laufs zu ändern.
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


## Abstand der Iso-Kamera vom Drehpunkt (m). Ändert das Bild nicht (orthografisch), muss
## aber groß genug sein, dass kein Hügel vor die Nahebene ragt (`tests/battle_ground_test.gd`).
const CAMERA_DISTANCE := 64.0
## Tiefe der Schattenkarte ab Kamera (m), zugleich `far`. Muss hinter den Boden reichen
## (etwa 110 m); größer heißt weichere Schatten.
const SHADOW_DISTANCE := 400.0


func _setup_view() -> void:
	setup_view($CameraPivot as Node3D, _camera, $Sun as DirectionalLight3D)


## Orthografische Iso-Kamera und Sonne; statisch, damit ein Test dieselbe Kamera aufbaut.
static func setup_view(pivot: Node3D, camera: Camera3D, sun: DirectionalLight3D) -> void:
	pivot.rotation_degrees = Vector3(-30.0, 45.0, 0.0)
	# Auf die Bahn zentriert; die Festung steht am Rand.
	pivot.position = Vector3(0.0, 0.0, VIEW_CENTER_Z)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 34.0
	camera.position = Vector3(0.0, 0.0, CAMERA_DISTANCE)
	# Mittags, hinter der Kamera; danach stellt sie SunCycle.
	sun.rotation_degrees = Vector3(-SunCycle.HIGH, pivot.rotation_degrees.y, 0.0)
	# Eine Schattenkarte statt PSSM: die Staffelung liefert mit dieser Orthogonal-Kamera gar
	# keinen Schatten.
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = SHADOW_DISTANCE
	# Die Karte spannt sich über die ganze Tiefe bis `far`; beim Standard (4000 m) ist sie
	# zu grob für Schatten.
	camera.far = SHADOW_DISTANCE
	# Klein, weil der Boden keinen Schatten wirft (dress_ground).
	sun.shadow_bias = 0.1
	sun.shadow_normal_bias = 1.0


## Knochenhaufen: wer hineinläuft, bleibt stehen.
func _physics_process(_delta: float) -> void:
	for hit: Array in _spells.block(_active):
		_spell_fx.pile_hit(hit[1])


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


## Escape bricht den Kampf ab (bei offener Eingabe schließt AnswerInput erst diese). In
## `_input`, weil eine LineEdit Escape sonst verbraucht. Ziffern zaubern nur bei
## geschlossener Eingabe.
func _input(event: InputEvent) -> void:
	var slot := spell_key(event)
	if slot >= 0 and not _answer_input.is_typing():
		get_viewport().set_input_as_handled()
		_use_spell(slot)
		return
	if view_key(event) and not _answer_input.is_typing():
		get_viewport().set_input_as_handled()
		_toggle_view()
		return
	var fast := fast_resolve_key(event)
	if fast != 0 and (fast == 2 or not _answer_input.is_typing()):
		get_viewport().set_input_as_handled()
		_on_fast_resolve_key()
		return
	if not event.is_action_pressed("ui_cancel"):
		return
	# Nach dem Wellenende führen Auflösung und Statistik zurück, nur der Hinweis braucht das.
	if _finished and not _no_content:
		return
	if _warming:
		return
	# accept_event() gibt es nur an Control, der WaveRunner ist ein Node3D.
	get_viewport().set_input_as_handled()
	_request_abort()


## Platz des Zaubervorrats zu `event`: Ziffern 1–9 als 0–8, sonst -1.
static func spell_key(event: InputEvent) -> int:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return -1
	if key.keycode >= KEY_1 and key.keycode <= KEY_9:
		return key.keycode - KEY_1
	if key.keycode >= KEY_KP_1 and key.keycode <= KEY_KP_9:
		return key.keycode - KEY_KP_1
	return -1


## Setzt den Zauber auf Platz `index` ein (ADR 0014), nur solange gekämpft wird. Hätte er
## nichts bewirkt, bleibt er im Vorrat und der Platz zittert.
func _use_spell(index: int) -> void:
	if index >= Inventory.slot_count():
		return
	if _finished or _fast_resolving or _warming or _leaving \
			or _celebration.is_busy() or _spelling.is_busy():
		return
	var id := str(Inventory.slot(index).get("id", ""))
	var spell := ContentRegistry.get_entry("spells", id)
	var to_come := maxi(0, _total - _spawned)
	if spell.is_empty() or not _spells.can_cast(spell, _active, to_come):
		_spell_slots.refuse(index)
		return
	Inventory.take(index)
	# Vor der Wirkung, damit die Spur den Zauber vor seinen Folgen führt.
	EventBus.spell_activated.emit(id)
	_spell_slots.pulse(index)
	_spell_banner.play(spell)
	_spell_fx.play(spell, _active)
	_strike_index = 0
	_spells.cast(spell, _active, to_come)


## Donnerschlag: das Monster ist erledigt, nicht beantwortet, wie beim Katapult. Vom Feld
## ist es sofort; das Wellenende wartet auf den Blitz (`_underway`).
func _strike(monster: Monster) -> void:
	if not _active.has(monster):
		return
	_active.erase(monster)
	monster.halt()
	EventBus.monster_struck.emit(monster.task)
	_underway += 1
	_spell_fx.bolt(monster, _strike_index, func() -> void:
		_underway -= 1
		if is_instance_valid(monster):
			for other in _active:
				if other.position.distance_to(monster.position) <= BLAST_FLINCH_RADIUS:
					other.flinch(monster.global_position)
			monster.queue_free()
		_check_end())
	_strike_index += 1


## Nimmt ein Monster unbeantwortet vom Feld (Katapult): ohne Lernstand, Erfahrung, Punkte.
func _dismiss(monster: Monster) -> void:
	_active.erase(monster)
	monster.halt()
	_blast_at(monster)
	monster.queue_free()


## Escape mitten in der Welle (ADR 0020): ein Lauf von der Karte ab Welle 2 rastet nach
## einer Rückfrage (`_rest_in_wave`), sonst endet der Kampf sofort, ohne _finish_wave. Was
## die angefangene Welle verdient hat, verfällt dann (ADR 0024).
func _request_abort() -> void:
	if _leaving or _abort_confirm.visible:
		return
	var from_pause := _paused_since_ms >= 0
	var rests := escape_rests(RunRequest.keeps_run(), _wave_number)
	# Läuft die Welle schon aus, rastet gleich ihr Abschluss.
	if rests and (_fast_resolving or (_spawned >= _total and _active.is_empty())):
		return
	if not rests:
		# Der Zoom hinaus braucht den laufenden Baum, also erst die Pause aufheben.
		if from_pause:
			_toggle_pause()
		_abort_battle()
		return
	_abort_paused_here = not from_pause and _toggle_pause()
	_answer_input.visible = false
	_set_view_active(false)
	var remaining := maxi(0, _total - _spawned) + _active.size()
	_abort_confirm.ask("Rasten?",
			("Dein Lauf wird gespeichert (Welle %d). Setzt du ihn auf der Karte fort, geht "
			+ "die Welle mit den übrigen %d Monstern weiter.") % [_wave_number, remaining],
			"Rasten", "Weiterspielen")


## Rastet Escape mitten in der Welle? Nur ein Lauf von der Karte, ab der zweiten Welle.
static func escape_rests(is_level: bool, wave_number: int) -> bool:
	return is_level and wave_number > 1


func _on_abort_confirmed() -> void:
	if _paused_since_ms >= 0:
		_toggle_pause()
	_rest_in_wave()


## Rasten mitten in der Welle (ADR 0020): eine künstliche Wellengrenze. Gespeichert wird wie
## an ihrem Ende, dazu, was sie schon hinter sich hat (`_open_wave_state`).
func _rest_in_wave() -> void:
	var wave := _open_wave_state()
	_finished = true
	_battle_clock.stop()
	_wave_gen += 1   # bindet laufende Spawn-Coroutinen ab (siehe _run_spawn_batch)
	_rest(_wave_number, wave)
	_report_run_ended()
	SaveCoordinator.commit("wave_rest")
	_saved_on_exit = true
	_slow_motion.stop()
	_leave_battle()


func _on_abort_cancelled() -> void:
	if _abort_paused_here:
		_abort_paused_here = false
		_toggle_pause()
	elif _paused_since_ms < 0 and not _finished and not _fast_resolving:
		_answer_input.visible = true
		_set_view_active(true)


func _abort_battle() -> void:
	_finished = true
	_battle_clock.stop()
	SaveCoordinator.discard_uncommitted()
	_report_run_ended()
	SaveCoordinator.commit("run_abort")
	_saved_on_exit = true
	_wave_gen += 1   # bindet laufende Spawn-Coroutinen ab (siehe _run_spawn_batch)
	_slow_motion.stop()
	_leave_battle()


## Die Ich-Sicht fängt die Maus nur, solange gekämpft wird.
func _set_view_active(on: bool) -> void:
	if _fp != null:
		_fp.set_active(on)


func _exit_tree() -> void:
	# Die Pause einer Feier darf nicht in die nächste Szene mit.
	get_tree().paused = false
	# Auch an Rückweg und Abbruch vorbei kommt keine halbe Welle auf die Platte.
	if not _saved_on_exit:
		SaveCoordinator.discard_uncommitted()
	SaveCoordinator.unregister(_badges)
	SaveCoordinator.release()


## Strg+P immer, das nackte P nur, solange nicht getippt wird.
func _on_pause_key(bare: bool) -> void:
	if bare and _answer_input.is_typing():
		return
	if _abort_confirm.visible:
		return
	if _toggle_pause():
		_pause_overlay.consume()


## Pausiert oder setzt fort; false, wenn gerade keine Pause möglich ist. Die Pausenzeit
## zählt nicht als Bedenkzeit der Monster.
func _toggle_pause() -> bool:
	if _paused_since_ms >= 0:
		var duration := Time.get_ticks_msec() - _paused_since_ms
		_paused_since_ms = -1
		for monster in _active:
			monster.spawned_at_ms += duration
		_pause_overlay.hide_pause()
		get_tree().paused = false
		_answer_input.visible = true
		_fast_resolve_button.disabled = false
		_view_button.disabled = false
		_set_view_active(true)
		return true
	# Feier, Standbild, Rückfrage und Wellenende geben den Baum selbst wieder frei.
	if _finished or _warming or _leaving or _fast_resolving or get_tree().paused \
			or _fast_resolve_confirm.visible:
		return false
	_paused_since_ms = Time.get_ticks_msec()
	get_tree().paused = true
	_answer_input.visible = false
	_fast_resolve_button.disabled = true
	_view_button.disabled = true
	_set_view_active(false)
	_pause_overlay.show_pause()
	return true


## „Schnell auflösen“ fragt erst nach. Solange die Frage steht, ist die Eingabe weg, sonst
## holte sie sich den Fokus und Enter. Das Spiel läuft dabei weiter.
func _on_fast_resolve_pressed() -> void:
	if _finished or _fast_resolving:
		return
	_answer_input.visible = false
	_set_view_active(false)
	_fast_resolve_confirm.ask("Schnell auflösen?",
			"Die übrigen Monster laufen im Zeitraffer durch und treffen die Festung wie sonst "
			+ "auch. Ihre Wörter zählen als nicht gewusst und werden danach aufgelöst.",
			"Auflösen")


## Ob `event` „Schnell auflösen“ fragt: 2 für Strg+F, 1 für das nackte F, sonst 0.
static func fast_resolve_key(event: InputEvent) -> int:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != KEY_F \
			or key.alt_pressed or key.shift_pressed or key.meta_pressed:
		return 0
	return 2 if key.ctrl_pressed else 1


## Die Taste wirkt nur, wenn der Knopf gerade drückbar wäre und nicht schon gefragt wird.
func _on_fast_resolve_key() -> void:
	if not _fast_resolve_button.visible or _fast_resolve_button.disabled \
			or _fast_resolve_confirm.visible or _warming or _leaving or _cutscene \
			or get_tree().paused:
		return
	_on_fast_resolve_pressed()


func _on_fast_resolve_cancelled() -> void:
	if not _finished and not _fast_resolving:
		_answer_input.visible = true
		_set_view_active(true)


## Spult den Rest der Welle vor und tut sonst nichts: jedes Monster kommt über den
## gewohnten Weg an, mit vollem Schaden. Das Tempo setzt _finish_wave zurück.
func _fast_resolve_wave() -> void:
	if _finished or _fast_resolving:
		return
	_fast_resolving = true
	_answer_input.visible = false
	_fast_resolve_button.disabled = true
	_pause_button.disabled = true
	_view_button.disabled = true
	# Ich-Sicht: die Frage hat die Maus freigegeben, zurück zum Laufen.
	_set_view_active(true)
	EventBus.wave_fast_resolved.emit(maxi(0, _total - _spawned), _active.size())
	_slow_motion.fast_forward()


## Startet die nächste prozedural erzeugte Welle mit der gewählten Schwierigkeit.
func _start_next_wave() -> void:
	_wave_gen += 1
	var gen := _wave_gen
	_clear_active_monsters()
	_total = 0
	_spawned = 0
	_finished = false
	_no_content = false
	_wave_correct = 0
	_wave_leaked = 0
	_previous_shown = _wave_shown.duplicate()
	_wave_shown.clear()
	_intro.new_wave()
	_wave_open = 0
	_open_from = 0
	_wave_leaked_tasks.clear()
	_wave_played_tasks.clear()
	_score_at_start = GameState.score
	# Nur der Stand zu Wellenbeginn, für den Zuwachs im Abschluss.
	_wave_xp = 0
	_level_at_start = PlayerLevel.level
	_end_label.visible = false
	_stats.hide_stats()
	_answer_input.visible = true
	_fast_resolving = false
	_held_answers.clear()
	# Ein Pfeil zu einem Monster mit Standbild kann die Feier über das Wellenende gehalten haben.
	_spelling_due.clear()
	_celebration.release()
	_badges.new_wave()
	_wave_low_hp = GameState.fortress_health
	_last_left = INF
	_wave_badges_done = false
	_fast_resolve_button.visible = true
	_fast_resolve_button.disabled = false
	_spells.reset_wave()
	_spell_fx.haze(false)
	_spell_fx.clear_piles()
	_spell_slots.visible = true
	_pause_button.visible = true
	_pause_button.disabled = false
	_view_button.visible = _view_selectable
	_view_button.disabled = false
	_set_view_active(true)

	GameState.current_wave = "procedural_%d" % _wave_number
	GameState.wave_number = _wave_number
	# Tempo = Schwierigkeit × profilweite Grund-Geschwindigkeit (Barrierefreiheit / Grundtempo).
	_generator.speed_scale = _difficulty_to_speed(_difficulty) * UserSettings.base_speed()
	_generator.damage_scale = WaveGenerator.wave_damage_scale(_wave_number)
	var spawns := _generate_wave(_difficulty, _wave_number)
	# Ohne Spielbares gar nicht anfangen: ein Spawn ohne Plan zählt nicht, die Welle endete nie.
	if _nothing_playable(spawns):
		_show_no_content()
		return
	_plan_playlist(spawns)
	for entry in spawns:
		_total += int(entry.get("count", 0))
	var open := _open_wave
	_open_wave = {}
	var armor := GameState.fortress_armor
	if not open.is_empty():
		_continue_wave(open, spawns)
	# Die Festungs-HP bleiben dabei, sie gelten über die Wellen hinweg.
	EventBus.wave_started.emit(GameState.current_wave)
	_battle_clock.start()
	if not open.is_empty():
		GameState.continue_wave(_spawned, armor)
	# Kein Sprung auf den Morgen, solange Monster laufen (_finish_wave gibt ihn frei).
	if _sun_cycle != null:
		_sun_cycle.hold = true
	EventBus.wave_totals.emit(_total)
	for entry in spawns:
		_run_spawn_batch(entry, gen)


## Setzt eine gerastete Welle fort (ADR 0020): es kommen nur ihre übrigen Monster, ihr
## Abschluss zählt weiter, wo er stand. Die erledigten gelten als erschienen (`_spawned`).
func _continue_wave(open: Dictionary, spawns: Array) -> void:
	var remaining := maxi(1, int(open.get("remaining", 1)))
	_total = maxi(remaining, int(open.get("total", remaining)))
	_spawned = _total - remaining
	_open_from = _spawned
	spawns[0]["count"] = remaining
	_wave_correct = int(open.get("correct", 0))
	_wave_leaked = int(open.get("leaked", 0))
	_score_at_start = GameState.score - int(open.get("score_gained", 0))
	_wave_xp = int(open.get("xp", 0))
	_level_at_start = int(open.get("level_at_start", _level_at_start))
	_wave_low_hp = mini(_wave_low_hp, int(open.get("low_hp", _wave_low_hp)))
	_spells.wave_pace = clampf(float(open.get("pace", 1.0)), 0.0, 1.0)
	_spells.wave_alts = bool(open.get("alts", false))
	_spells.wave_damage = clampf(float(open.get("damage", 1.0)), 0.0, 1.0)
	_spells.bones_left = maxi(0, int(open.get("bones", 0)))
	_spells.bones_hold = float(open.get("bones_hold", _spells.bones_hold))
	for at in open.get("piles", []):
		if at is Array and at.size() == 2:
			var spot := Vector3(float(at[0]), 0.0, float(at[1]))
			_spells.piles.append({"at": spot, "held": []})
			_spell_fx.pile(spot, false)
	if _spells.wave_pace < 1.0:
		_spell_fx.haze(true)
	for task in open.get("played", []):
		if task is Dictionary:
			_wave_played_tasks.append(task)
			if bool(task.get("leaked", false)):
				_wave_leaked_tasks.append(task)


## Stand der angefangenen Welle fürs Rasten (RunSave.build, Feld `wave`). Monster auf dem
## Feld zählen nicht als erledigt, sie kommen mit neuem Wort wieder.
func _open_wave_state() -> Dictionary:
	var played: Array = []
	for task in _wave_played_tasks:
		played.append(task)
	return {
		"remaining": maxi(0, _total - _spawned) + _active.size(),
		"total": _total,
		"correct": _wave_correct,
		"leaked": _wave_leaked,
		"score_gained": GameState.score - _score_at_start,
		"xp": _wave_xp,
		"level_at_start": _level_at_start,
		"low_hp": _wave_low_hp,
		"fortress_tier": _fortress_tier,
		"pace": _spells.wave_pace,
		"alts": _spells.wave_alts,
		"damage": _spells.wave_damage,
		"bones": _spells.bones_left,
		"bones_hold": _spells.bones_hold,
		"piles": _spells.piles.map(func(pile: Dictionary) -> Array:
			return [pile["at"].x, pile["at"].z]),
		"played": played,
	}


## Testliste: die Reihenfolge der Wörter in dieser Welle (TestPlaylist). Eine neue Runde
## beginnt nur an einer Wellengrenze, wenn der Beutel leer ist.
func _plan_playlist(spawns: Array) -> void:
	_playlist_order = []
	if not RunRequest.is_test() or spawns.is_empty():
		return
	var words := {}
	for c in _generator.candidates(spawns[0].get("task_pool", {})):
		var source := str(c["source"].get("id", ""))
		if not words.has(source):
			words[source] = []
		words[source].append(c["learnable_id"])
	var list := RunRequest.test_list()
	var round_start := int(list.get("round_started_at", 0))
	var open := TestPlaylist.unplayed(words, PlayerProgress.last_seen_at,
			PlayerProgress.last_correct, round_start)
	if open.is_empty() or round_start <= 0:
		list["round_started_at"] = int(Time.get_unix_time_from_system())
		RunRequest.update_test(TestLists.store(list, UserSettings.active_profile()))
		open = words.keys()
	_playlist_order = TestPlaylist.wave_order(open, words.keys(), _previous_shown)


## Schwierigkeit 1..5 → Tempo-Faktor 0.6 .. 1.4 auf die Basis-Geschwindigkeit.
func _difficulty_to_speed(difficulty: int) -> float:
	return 0.6 + 0.2 * float(clampi(difficulty, 1, 5) - 1)


## Die Spawn-Batches einer Welle: Array von {count, interval (s), task_pool}.
func _generate_wave(difficulty: int, wave_number: int) -> Array:
	# Je Welle ein Monster mehr, je Stufe über/unter 3 zwei mehr/weniger, mindestens 2.
	var count := maxi(2, 2 + wave_number + (difficulty - 3) * 2)
	var interval := maxf(1.5, 4.0 - 0.3 * difficulty)  # härter ⇒ schnellere Folge
	interval *= _spawn_gap_scale
	return [{
		"count": count,
		"interval": interval,
		# Dieselbe Funktion fragen die Menüs, damit Pool und Sperre nicht auseinanderlaufen.
		"task_pool": RunRequest.task_pool(),
	}]


## True, wenn kein Batch der Welle eine spielbare Aufgabe hergibt.
func _nothing_playable(spawns: Array) -> bool:
	for entry in spawns:
		if _generator.has_playable(entry.get("task_pool", {})):
			return false
	return true


## Nichts zu spielen: Hinweis statt Kampf, ohne _finish_wave (keine Welle zu verbuchen).
func _show_no_content() -> void:
	_no_content = true
	_finished = true
	_set_view_active(false)
	_answer_input.visible = false
	_fast_resolve_button.visible = false
	_pause_button.visible = false
	_view_button.visible = false
	_stats.hide_stats()
	_end_label.text = "Keine spielbaren Aufgaben.\n\nFilter prüfen oder über „Inhalte“\neinen Vokabel-Pack installieren.\n\n[Esc] zurück ins Menü"
	_end_label.visible = true
	push_warning("WaveRunner: keine spielbare Aufgabe im Pool — Welle nicht gestartet")


## Entfernt noch aktive Monster vom Feld.
func _clear_active_monsters() -> void:
	for monster in _active:
		if is_instance_valid(monster):
			monster.queue_free()
	_active.clear()


## Coroutine; `gen` bindet sie an ihre Welle, eine neue Welle bricht sie ab.
func _run_spawn_batch(entry: Dictionary, gen: int) -> void:
	var count := int(entry.get("count", 0))
	var interval := float(entry.get("interval", 2.0))
	var gap := 0.0
	for i in count:
		# process_always = false: in der Baum-Pause läuft der Timer nicht weiter.
		await get_tree().create_timer(interval, false).timeout
		var waited := interval
		while waited < gap and _typing_monster in _active:
			await get_tree().create_timer(TYPING_POLL, false).timeout
			waited += TYPING_POLL
		if _finished or not is_inside_tree() or gen != _wave_gen:
			return
		gap = _spawn(entry)


## Gibt zurück, wie lange der nächste Spawn mindestens warten soll (Tippzeit, ADR 0026).
func _spawn(entry: Dictionary) -> float:
	# Sichtbare Grundwörter ausschließen: dieselbe Vokabel nie zweimal auf dem Feld.
	var active_sources := {}
	for m in _active:
		active_sources[str(m.task.get("source_id", ""))] = true
	var plan: Dictionary = _generator.pick(entry.get("task_pool", {}), active_sources, _wave_shown,
			_playlist_order, _open_due(), _intro)
	if plan.is_empty():
		# Kein Plan heißt „nichts Spielbares im Pool“ (pick() lässt die active_sources-Sperre
		# zuletzt fallen). Der Spawn fällt aus dem Soll, sonst wartete _check_end() ewig.
		push_warning("WaveRunner: keine spielbare Aufgabe für Pool %s" % str(entry.get("task_pool", {})))
		_total = maxi(0, _total - 1)
		EventBus.wave_totals.emit(_total)
		_check_end()
		return 0.0

	var monster := MONSTER_SCENE.instantiate() as Monster
	# Der Zeitwandler-Skill bremst erst hier, hinter der Formel: `plan["reward"]` und
	# `plan["xp"]` bleiben, was `t - c` sagt.
	monster.setup(plan["monster_def"], plan["task"], GOAL_Z, plan["speed"] * _monster_pace)
	monster.mastered = bool(plan.get("mastered", false))
	monster.damage = plan["damage"]
	monster.reward = plan["reward"]
	monster.xp = plan["xp"]
	monster.spawned_at_ms = Time.get_ticks_msec()
	monster.screen_sized_label = _fp != null
	monster.position = Vector3(randf_range(-LANE_HALF_WIDTH, LANE_HALF_WIDTH), 0.0, SPAWN_Z)
	monster.reached_goal.connect(_on_monster_reached_goal)
	_monsters.add_child(monster)
	_active.append(monster)
	_spell_fx.on_spawn(monster, _spells.on_spawn(monster))
	_wave_shown[str(plan["task"].get("source_id", ""))] = _spawned
	_intro.note_spawn(plan["task"])
	_spawned += 1
	EventBus.monster_spawned.emit(plan["monster_def"], plan["task"])
	var mastered := PlayerProgress.is_mastered(str(plan["task"].get("learnable_id", "")))
	if not mastered:
		_wave_open += 1
	if _catapult and _fortress_tier >= FortressModel.CATAPULT_TIER and mastered:
		_catapult_later(monster, _wave_gen)
	_typing_monster = monster if float(plan.get("gap", 0.0)) > 0.0 else null
	return float(plan.get("gap", 0.0)) * _spawn_gap_scale


## Muss der nächste Spawn offen sein? Eine Testliste behält ihre Reihenfolge.
func _open_due() -> bool:
	return _playlist_order.is_empty() \
			and WaveGenerator.open_due(_wave_open, _spawned - _open_from)


func _on_answer_submitted(text: String) -> void:
	if _finished:
		return
	# In der Feier steht das Spiel: die Antwort aufheben, nicht in der Pause auswerten.
	if _celebration.is_playing() or _spelling.is_busy():
		_held_answers.append(text)
		return
	var targets := _hittable()
	var answers: Array = []
	for monster in targets:
		answers.append(monster.task.get("accepted_answers", []))
	var hit := best_hit(_evaluator, answers, text)
	if int(hit["index"]) >= 0:
		_score_hit(targets[int(hit["index"])], text, hit["verdict"])
		return
	# Falscheingabe: kein Lernstand-Eintrag, sie gehört zu keiner Aufgabe (gescheitert wird
	# an der Festung). Die Spur bekommt sie mit den Aufgaben auf dem Feld.
	EventBus.answer_judged.emit(text, {
		"matched": false, "complete": false, "learnable_id": "", "source_id": "",
		"response_time_ms": 0, "canonical": "", "candidates": _active_learnable_ids(),
		"unseen": _unseen_learnable_ids(),
	})
	if _fp != null and _fp.weapon == FirstPersonView.Weapon.BOW:
		_miss_with_arrow()
	else:
		_wrong_feedback()


## Welches Monster eine Antwort trifft: `answers` hält je Monster seine accepted_answers.
## Rückgabe {index, verdict}, index -1 ohne Treffer. Rang: vollständig vor unvollständig,
## darin exakt vor nachsichtig (ADR 0008), bei Gleichstand das erste.
static func best_hit(evaluator: AnswerEvaluator, answers: Array, text: String) -> Dictionary:
	var best := {"index": -1, "verdict": {}}
	var best_rank := -1
	for i in answers.size():
		var verdict := evaluator.evaluate(answers[i], text, true)
		if not bool(verdict["matched"]):
			continue
		var rank := 2 * int(bool(verdict["complete"])) + int(bool(verdict["exact"]))
		if rank > best_rank:
			best = {"index": i, "verdict": verdict}
			best_rank = rank
		if rank == 3:
			break
	return best


## Die learnable_ids der Aufgaben auf dem Feld, nur für die Spur.
func _active_learnable_ids() -> Array:
	var ids: Array = []
	for monster in _active:
		ids.append(str(monster.task.get("learnable_id", "")))
	return ids


## Die Monster, die eine Antwort treffen kann: alle, in der Ich-Sicht nur die im Bild.
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


## Für die Spur: die Aufgaben auf dem Feld, aber außerhalb des Bildes. Leer ohne Ich-Sicht.
func _unseen_learnable_ids() -> Array:
	var ids: Array = []
	if _fp == null:
		return ids
	for monster in _active:
		if not _in_view(monster):
			ids.append(str(monster.task.get("learnable_id", "")))
	return ids


## Baut die Ich-Sicht auf (ARCHITECTURE „Ich-Sicht (Späher-Baum)“). Die Iso-Kamera
## bleibt in der Szene, Boden und Deko sind für ihren Blick gebaut.
func _setup_first_person() -> void:
	_fp = FIRST_PERSON_SCENE.instantiate() as FirstPersonView
	_fp.speed = FirstPersonView.speed_for(_skill_bonuses)
	_fp.weapons = FirstPersonView.weapons_for(_skill_bonuses)
	_fp.explosive = FirstPersonView.explodes_for(_skill_bonuses)
	_fp.bounds = Rect2(-FIELD_HALF_X + 1.0, SPAWN_Z - 1.0,
			2.0 * (FIELD_HALF_X - 1.0), GOAL_Z - 1.5 - (SPAWN_Z - 1.0))
	_fp.position = Vector3(0.0, 0.0, GOAL_Z - 2.0)
	_fp.answer_input = _answer_input
	add_child(_fp)
	(_fp.get_node("Overlay/Markers") as OffscreenMarkers).track(_fp.camera,
			func() -> Array[Monster]: return _active)
	# Kopie: geladene Ressourcen sind geteilt, der Nebel käme sonst in die nächste Iso-Sicht.
	var world := $WorldEnvironment as WorldEnvironment
	_iso_env = world.environment
	var env := _iso_env.duplicate() as Environment
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = env.background_color
	env.fog_depth_begin = FirstPersonView.FOG_BEGIN
	env.fog_depth_end = FirstPersonView.FOG_END
	world.environment = env
	_answer_input.first_person = true
	_answer_input.weapon_switch = _fp.weapons.size() > 1
	_scale_grass(GRASS_SCALE_FIRST_PERSON)


## Zurück auf die Iso-Kamera; die Maus gibt die Ich-Sicht beim Verlassen selbst frei.
func _teardown_first_person() -> void:
	_camera.make_current()
	_fp.set_active(false)
	_fp.queue_free()
	_fp = null
	($WorldEnvironment as WorldEnvironment).environment = _iso_env
	_answer_input.first_person = false
	_answer_input.weapon_switch = false
	_scale_grass(1.0 / GRASS_SCALE_FIRST_PERSON)


func _scale_grass(factor: float) -> void:
	for tuft in _grass:
		if is_instance_valid(tuft):
			tuft.scale *= factor


## Wechselt zwischen Iso- und Ich-Sicht; false, wenn gerade nicht gewechselt werden darf.
## Nicht, solange ein Pfeil, Anlauf oder Stein unterwegs ist: der hängt an seiner Sicht.
## Der Wechsel gilt auch für den nächsten Kampf (RunRequest).
func _toggle_view() -> bool:
	if not _view_selectable or _finished or _warming or _leaving or _fast_resolving \
			or _cutscene or _underway > 0 or _paused_since_ms >= 0 or get_tree().paused \
			or _fast_resolve_confirm.visible or _answer_input.is_typing():
		_view_button.set_pressed_no_signal(_fp != null)
		return false
	if _fp == null:
		_setup_first_person()
		_fp.set_active(true)
	else:
		_teardown_first_person()
	_shake_left = 0.0
	_camera.position = _cam_base
	var large := _fp != null
	for monster in _active:
		monster.screen_sized_label = large
	_word_plates.restyle()
	_view_button.set_pressed_no_signal(large)
	RunRequest.want_first_person(large)
	return true


## Ob `event` die Sicht wechselt: V ohne Strg und Alt, nur bei geschlossener Eingabe.
static func view_key(event: InputEvent) -> bool:
	var key := event as InputEventKey
	return key != null and key.pressed and not key.echo and key.keycode == KEY_V \
			and not key.ctrl_pressed and not key.alt_pressed and not key.meta_pressed


## Treffer verbuchen. `verdict` ist das Urteil des AnswerEvaluator, leer für einen Treffer
## ohne Abzug. Ein nachsichtiges Urteil kostet nichts, zeigt aber nach dem Zerplatzen die
## richtige Form im Standbild (SpellingFreeze, ADR 0010), erst danach eine Meister-Feier.
func _score_hit(monster: Monster, text: String = "", verdict: Dictionary = {}) -> void:
	var complete := bool(verdict.get("complete", true))
	var exact := bool(verdict.get("exact", true))
	var full_form := "" if complete and exact else str(verdict.get("canonical", ""))
	var rt := Time.get_ticks_msec() - monster.spawned_at_ms
	var task_id := str(monster.task.get("learnable_id", ""))
	if not full_form.is_empty():
		# Vor record(): eine Meisterung durch diese Antwort feiert erst nach dem Standbild.
		_celebration.hold()
		_spelling_due[monster.get_instance_id()] = [full_form,
				AnswerEvaluator.spelling_marks(full_form, text),
				AnswerEvaluator.missing_marks(full_form, text)]
	_last_left = monster.seconds_left() if _spawned >= _total and _active.size() == 1 else INF
	if bool(monster.task.get("help", false)):
		_score_copy(monster, text, complete, exact, full_form, rt)
		return
	# Der Stand davor: record() überschreibt, woran Revanche und Co. hängen.
	var badge_ctx := _badges.before_hit(task_id)
	var newly_mastered := PlayerProgress.record(task_id, true, rt,
			float(monster.task.get("initial_confidence", -1.0)))
	EventBus.item_reviewed.emit(task_id, true, rt)
	# Nach record(): Mithörer lesen die neue Confidence, die alte steht in der Spawn-Zeile.
	EventBus.answer_judged.emit(text, {
		"matched": true, "complete": complete, "exact": exact, "learnable_id": task_id,
		"source_id": str(monster.task.get("source_id", "")), "response_time_ms": rt,
		"canonical": full_form, "candidates": _active_learnable_ids(),
		"hint": monster.initial_shown,
	})
	# Nach answer_judged, damit die Spur erst die Antwort und dann die Meisterung zeigt.
	if newly_mastered:
		EventBus.task_mastered.emit(task_id)
		var lexeme_id := PlayerProgress.mastered_lexeme_of(task_id)
		if not lexeme_id.is_empty():
			EventBus.lexeme_mastered.emit(lexeme_id)
	# Nach der Meisterung: ihre Feier geht vor.
	_announce_badges(_badges.after_hit(badge_ctx))
	if _badges.revenges_this_wave >= Achievements.REVENGES:
		AchievementBook.unlock("revenge_3")
	_finish_hit(monster)


## Die Lösung stand auf dem Schild (ADR 0027): Abtippen ist kein Abruf und kommt nicht in
## den Lernstand, keine Plakette. Die Aufgabe kommt bald ohne Lösung wieder.
func _score_copy(monster: Monster, text: String, complete: bool, exact: bool, full_form: String,
		rt: int) -> void:
	var task_id := str(monster.task.get("learnable_id", ""))
	_intro.note_copied(monster.task)
	EventBus.answer_judged.emit(text, {
		"matched": true, "complete": complete, "exact": exact, "learnable_id": task_id,
		"source_id": str(monster.task.get("source_id", "")), "response_time_ms": rt,
		"canonical": full_form, "candidates": _active_learnable_ids(), "help": true,
	})
	_finish_hit(monster)


## Das Bild eines Treffers, je nach Waffe.
func _finish_hit(monster: Monster) -> void:
	var weapon := _fp.weapon if _fp != null else FirstPersonView.Weapon.NONE
	if weapon == FirstPersonView.Weapon.CHARGE:
		_defeat_by_charge(monster)
	elif weapon == FirstPersonView.Weapon.BOW:
		_defeat_by_arrow(monster)
	else:
		_defeat(monster)
	_flash_feedback(FLASH_CORRECT)


## Eine Meister-Feier pausiert den Baum; nur process_mode ALWAYS läuft weiter (Feier,
## Eingabe, Sfx). Die Feier zählt nicht als Bedenkzeit der Monster (Antwortzeit ist
## Echtzeit). Bei mehreren Feiern kommt `started` je Feier, `finished` nach der letzten.
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


## Das Standbild, falls _score_hit eines vorgemerkt hat. `key` und `at` stammen von vor dem
## Zerplatzen.
func _spell_out(key: int, at: Vector3) -> void:
	if not _spelling_due.has(key):
		return
	var due: Array = _spelling_due[key]
	_spelling_due.erase(key)
	var target := at + Vector3(0.0, 1.0, 0.0)
	_spelling.play(str(due[0]), due[1],
			spelling_zoom(_fp.camera if _fp != null else _camera, target), due[2])


## Die Kamerafahrt des Standbilds: k = 0 Spielbild, k = 1 ganz herangefahren. Den
## Ausgangsstand nimmt sie beim ersten Aufruf, k = 0 stellt ihn genau wieder her. `turn`:
## Anteil der Drehung zum Ziel in der Ich-Sicht. Statisch für die Werkbank (`--spelling`).
static func spelling_zoom(camera: Camera3D, target: Vector3, turn := SPELLING_TURN) -> Callable:
	var start := {}
	if camera.projection != Camera3D.PROJECTION_ORTHOGONAL:
		return func(k: float) -> void:
			if start.is_empty():
				start["fov"] = camera.fov
				start["from"] = camera.global_basis.get_rotation_quaternion()
				var look := Basis.looking_at(target - camera.global_position, Vector3.UP)
				start["to"] = (start["from"] as Quaternion).slerp(
						look.get_rotation_quaternion(), turn)
			camera.fov = lerpf(start["fov"], float(start["fov"]) * SPELLING_FOV, k)
			camera.global_basis = Basis((start["from"] as Quaternion).slerp(start["to"], k))
	return func(k: float) -> void:
		if start.is_empty():
			start["size"] = camera.size
			start["pos"] = camera.global_position
			# Wohin die Bildmitte auf der Höhe des Ziels zeigt: von dort zum Ziel wird geschwenkt.
			var forward := -camera.global_basis.z
			var t := (target.y - camera.global_position.y) / forward.y if absf(forward.y) > 0.001 else 0.0
			start["pan"] = (target - (camera.global_position + forward * t)) * SPELLING_ISO_PAN
		camera.size = lerpf(start["size"], float(start["size"]) * SPELLING_ISO_SIZE, k)
		camera.global_position = (start["pos"] as Vector3) + (start["pan"] as Vector3) * k


## Das Standbild hält den Kampf an wie eine Feier, außer die Festung fiel in seinem Vorlauf.
func _on_spelling_started(duration_ms: int) -> void:
	if _finished:
		return
	_on_celebration_started(duration_ms)


## Das Standbild ist vorbei: weiter mit dem Kampf oder der anstehenden Feier derselben Antwort.
func _on_spelling_finished() -> void:
	get_tree().paused = false
	# Fliegt noch ein Pfeil zu einem Monster mit Standbild, wartet dessen Feier mit.
	if _spelling_due.is_empty():
		_celebration.release()
	if _celebration.is_playing() or _finished:
		return
	var held := _held_answers.duplicate()
	_held_answers.clear()
	for text in held:
		_on_answer_submitted(text)
	_check_end()


## Debug-Panel: feiert mit dem Wort des ersten Monsters, an Lernstand und Spur vorbei.
## Nicht in der Pause: die Feier gäbe am Ende den Baum frei.
func _on_debug_celebration(word: bool) -> void:
	if _paused_since_ms >= 0:
		return
	var task: Dictionary = _active[0].task if not _active.is_empty() else {}
	if word:
		_celebration.celebrate(MasteryCelebration.Kind.WORD, str(task.get("source_id", "")))
	else:
		_celebration.celebrate(MasteryCelebration.Kind.TASK, str(task.get("learnable_id", "")))


## Meldet Plaketten der Spur und der Feier; true, wenn welche da waren.
func _announce_badges(badges: Array) -> bool:
	for badge: Dictionary in badges:
		EventBus.badge_earned.emit(str(badge["id"]), int(badge["tier"]))
		_celebration.announce(badge)
	return not badges.is_empty()


## Debug-Panel: zeigt reihum je eine Plakette jeder Art, ohne Spur und Datei.
func _on_debug_badge() -> void:
	if _paused_since_ms >= 0:
		return
	var samples := Badges.samples()
	_celebration.announce(samples[_debug_badge % samples.size()])
	_debug_badge += 1


func _shake(magnitude: float = SHAKE_MAGNITUDE) -> void:
	if _cutscene:
		return
	_shake_left = SHAKE_DURATION
	_shake_mag = magnitude


func _flash_feedback(color: Color) -> void:
	_flash.color = Color(color.r, color.g, color.b, 0.35)
	_flash.modulate = Color(1, 1, 1, 1)
	create_tween().tween_property(_flash, "modulate:a", 0.0, 0.4)


## Momentaufnahme der Aufgabe eines Monsters für die Auflösung nach der Welle.
## `leaked`: durchgelassen; source_id/learnable_id zum Flaggen im Reveal.
func _task_snapshot(monster: Monster, leaked: bool) -> Dictionary:
	return {
		"prompt": String(monster.task.get("prompt", "")),
		"prompt_alt": (monster.task.get("prompt_alt", []) as Array).duplicate(),
		"answers": (monster.task.get("accepted_answers", []) as Array).duplicate(),
		"lexeme_type": String(monster.task.get("lexeme_type", "")),
		"task_type": String(monster.task.get("task_type", "")),
		"meaning": String(monster.task.get("meaning", "")),
		"source_id": String(monster.task.get("source_id", "")),
		"learnable_id": String(monster.task.get("learnable_id", "")),
		"leaked": leaked,
	}


func _defeat(monster: Monster) -> void:
	_book_defeat(monster)
	var key := monster.get_instance_id()
	var at := monster.global_position
	_burst(monster)
	_spell_out(key, at)
	_check_end()


## Sturmangriff (Späher-Baum): gebucht wird sofort, nur das Bild wartet auf den Aufprall.
## Das Monster bleibt stehen und ist aus _active heraus. Das Wellenende wartet den Aufprall ab.
func _defeat_by_charge(monster: Monster) -> void:
	_book_defeat(monster)
	monster.halt()
	_underway += 1
	var key := monster.get_instance_id()
	var at := monster.global_position
	await _fp.charge_at(at)
	_underway -= 1
	if is_instance_valid(monster):
		_shake(0.6)
		_burst(monster, 2.2)
	_spell_out(key, at)
	_check_end()


## Bogen (Späher-Baum): wie der Sturmangriff, das Monster platzt, wenn der Pfeil ankommt.
func _defeat_by_arrow(monster: Monster) -> void:
	_book_defeat(monster)
	monster.halt()
	_underway += 1
	# In den Kopf: man zielt auf das Schild darüber.
	var key := monster.get_instance_id()
	var at := monster.global_position
	await _fp.shoot_at(at + Vector3(0.0, monster.head_height(), 0.0))
	_underway -= 1
	if is_instance_valid(monster):
		if _fp.explosive:
			_shake(0.7)
			_blast(monster)
		else:
			_shake(0.3)
			_burst(monster, 2.0)
	_spell_out(key, at)
	_check_end()


## Ein Fehlschuss: knapp am Monster nahe der Bildmitte vorbei, die Rückmeldung beim Einstecken.
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


## Das Bild zum Treffer mit dem Explosionspfeil. Die Nachbarn zucken nur, besiegt ist allein
## das getroffene Monster.
func _blast(monster: Monster) -> void:
	_blast_at(monster)
	_leave(monster)


## Nur der Knall in der Wortfarbe, für Explosionspfeil und Wachkatapult.
func _blast_at(monster: Monster) -> void:
	var fx := Blast.new()
	fx.setup(monster.word_color(), BLAST_SCALE)
	fx.position = monster.position
	add_child(fx)
	_settle(BLAST_SETTLE)
	for other in _active:
		if other.position.distance_to(monster.position) <= BLAST_FLINCH_RADIUS:
			other.flinch(monster.global_position)


## Wachkatapult (Bollwerk): ein Monster mit gemeisterter Aufgabe wird nach einer zufälligen
## Weile abgeschossen. Trifft der Spieler vorher, zählt sein Treffer. Ein Katapulttreffer
## ist nicht beantwortet: kein Lernstand, keine Erfahrung, keine Punkte, keine Auflösung
## (monster_catapulted statt monster_defeated).
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
		_shake(0.5)
		Sfx.play(&"monster_kill")
		EventBus.monster_catapulted.emit(monster.task)
		_dismiss(monster)
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


## Wohin das Katapult zielt: wo das Monster nach Drehen, Ausschlagen und Flug steht. Die
## Flugzeit hängt am Ziel, zweimal nachrechnen reicht.
static func catapult_lead(from: Vector3, at: Vector3, velocity: Vector3) -> Vector3:
	var windup := FortressModel.CATAPULT_TURN_TIME + FortressModel.CATAPULT_SWING_TIME
	var target := at
	for i in 3:
		target = at + velocity * (windup + catapult_flight_time(from, target))
	return target


## Das Katapult, das dem Ziel am nächsten steht, oder null. Es wirft über FortressModel.fire.
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
	if _spells.leave_pile(monster.position):
		_spell_fx.pile(Vector3(monster.position.x, 0.0, monster.position.z))
	# Nicht in _spawn_explosion(): Festungsausbau und Aufschlag klingen anders.
	Sfx.play(&"monster_kill")
	# Erfahrung statt Punkte, in der Farbe ihres Rings im HUD.
	_spawn_xp_popup(monster.position + Vector3(0.0, 2.0, 0.0), monster.xp)
	monster.queue_free()


## Was ein besiegtes Monster zählt. Ohne Bild — das kommt aus _burst.
func _book_defeat(monster: Monster) -> void:
	_active.erase(monster)
	_wave_correct += 1
	_wave_played_tasks.append(_task_snapshot(monster, false))
	# Erfahrung gehört zum Profil (PlayerLevel), gespeichert wird an der Wellengrenze.
	# Der Zähler daneben ist nur für den Wellenabschluss.
	PlayerLevel.gain(monster.xp)
	_wave_xp += monster.xp
	var info := monster.monster_def.duplicate()
	info["reward"] = monster.reward
	EventBus.monster_defeated.emit(info, true)


## „+XP“ an der Trefferstelle: poppt auf, steigt und blendet aus.
func _spawn_xp_popup(pos: Vector3, amount: int) -> void:
	var label := xp_label("+%d XP" % amount)
	_screen_size_in_first_person(label, POPUP_SCREEN_SCALE)
	label.position = pos
	label.scale = Vector3.ONE * 0.4
	add_child(label)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "scale", Vector3.ONE * 1.15, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "position:y", pos.y + 4.0, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "modulate:a", 0.0, 0.5).set_delay(0.7)
	tw.chain().tween_callback(label.queue_free)


## Das Schild des „+XP“-Popups, ohne Bewegung; FxWarmup zeichnet damit vor.
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


## Wie groß „+XP" in der Ich-Sicht steht (gegenüber FP_TEXT_PIXEL_SIZE).
const POPUP_SCREEN_SCALE := 2.0

## Bildgröße eines Textes der Größe 64 in der Ich-Sicht (Label3D.fixed_size, je Bildhöhe).
const FP_TEXT_PIXEL_SIZE := 0.0009

## In der Ich-Sicht feste Bildgröße, sonst füllte der Text aus der Nähe das Bild. `scale`
## ist die Größe gegenüber FP_TEXT_PIXEL_SIZE.
func _screen_size_in_first_person(label: Label3D, scale: float) -> void:
	if _fp != null:
		_size_for_first_person(label, scale)


func _size_for_first_person(label: Label3D, scale: float) -> void:
	label.fixed_size = true
	label.pixel_size = FP_TEXT_PIXEL_SIZE * scale * 64.0 / float(label.font_size)


func _spawn_explosion(pos: Vector3, color: Color, scale: float) -> void:
	var fx := Explosion.new()
	fx.setup(color, scale)
	fx.position = pos
	add_child(fx)
	_settle(EXPLOSION_SETTLE)


## Hält das Wellenende `seconds` lang auf (Spielzeit) und fragt danach erneut.
func _settle(seconds: float) -> void:
	_settling += 1
	await get_tree().create_timer(seconds, false).timeout
	_settling -= 1
	_check_end()


## Das Monster hat die Festung erreicht und sich selbst freigegeben.
func _on_monster_reached_goal(monster: Monster) -> void:
	if not _active.has(monster):
		return
	_active.erase(monster)
	_wave_leaked += 1
	# Vor dem Niederlage-Check, damit auch das letzte Monster in der Auflösung steht.
	var snapshot := _task_snapshot(monster, true)
	_wave_leaked_tasks.append(snapshot)
	_wave_played_tasks.append(snapshot)
	_spawn_explosion(monster.position + Vector3(0.0, 1.0, 0.0), Color(1.0, 0.45, 0.12), 2.6)
	_shake(0.9)
	# Tiefer als der Kill-Sound (600 statt 809 Hz Schwerpunkt), damit beide unterscheidbar sind.
	Sfx.play(&"fortress_hit")
	var task_id := str(monster.task.get("learnable_id", ""))
	PlayerProgress.record(task_id, false, 0, float(monster.task.get("initial_confidence", -1.0)))
	# 0 ms: ein durchgelassenes Monster hat keine gemessene Antwortzeit.
	EventBus.item_reviewed.emit(task_id, false, 0)
	EventBus.fortress_damaged.emit(monster.damage)
	_wave_low_hp = mini(_wave_low_hp, GameState.fortress_health)
	if GameState.fortress_health <= 0:
		_finish_wave(false)
		return
	_reveal_leak(monster)
	_check_end()


## Standbild wie bei einem Schreibfehler (ADR 0010, ADR 0027): Aufgabe und Lösung, solange
## das Monster an der Mauer platzt. Nicht beim Vorspulen. Die Ich-Sicht dreht sich dabei
## nicht: die Mauer liegt meist hinter dem Spieler.
func _reveal_leak(monster: Monster) -> void:
	var answers: Array = monster.task.get("accepted_answers", [])
	if _fast_resolving or answers.is_empty():
		return
	var target := monster.global_position + Vector3(0.0, 1.0, 0.0)
	_spelling.play(str(answers[0]), PackedInt32Array(),
			spelling_zoom(_fp.camera if _fp != null else _camera, target, 0.0), PackedInt32Array(),
			monster.prompt())


func _check_end() -> void:
	if _finished:
		return
	# Ein Sturmangriff oder Pfeil ist noch unterwegs: sein Aufprall ruft hierher zurück.
	if _underway > 0:
		return
	# Erst feiern, dann abrechnen: _on_celebration_finished ruft hierher zurück.
	if _celebration.is_busy() or _spelling.is_busy():
		return
	# Ein Zauber oder eine Explosion läuft noch: SpellFx.settled bzw. _settle ruft zurück.
	if _spell_fx.is_busy() or _settling > 0:
		return
	if _spawned >= _total and _active.is_empty():
		# Die Plaketten der gewonnenen Welle feiern noch im Kampf, danach zurück hierher.
		if not _wave_badges_done:
			_wave_badges_done = true
			var low := float(_wave_low_hp) / float(maxi(1, GameState.fortress_max_health))
			if _announce_badges(_badges.wave_won(low, _last_left)):
				return
		EventBus.wave_cleared.emit(GameState.current_wave)
		_finish_wave(true)


## Beendet die Welle und zeigt den Statistik-Screen (Sieg oder Niederlage).
func _finish_wave(won: bool) -> void:
	if _finished:
		return
	_finished = true
	_last_won = won
	_battle_clock.stop()
	# Die Wellengrenze (ADR 0024). Nach wave_cleared, damit das Sitzungs-Log die Welle zählt.
	SaveCoordinator.commit("wave_end")
	if _sun_cycle != null:
		_sun_cycle.hold = false
	_set_view_active(false)
	_answer_input.visible = false
	_fast_resolve_button.visible = false
	_spell_slots.visible = false
	_spells.reset_wave()
	_spell_fx.haze(false)
	_spell_fx.clear_piles()
	_pause_button.visible = false
	_view_button.visible = false
	# Eine offene Rückfrage erledigt sich: nach dem Wellenende führt Stufe 2 weiter.
	_fast_resolve_confirm.hide()
	_abort_confirm.hide()
	_abort_paused_here = false
	# Cutscene, Auflösung und Statistik immer in Normaltempo.
	_slow_motion.stop()
	# Vor der Cutscene: die Fanfare kündigt den Festungsausbau an, statt mit ihm zu kollidieren.
	Sfx.play(&"wave_cleared" if won else &"fortress_destroyed")
	# Festungsausbau nach gewonnener Welle, vor der Statistik. Die HP wachsen vor der
	# Cutscene, das Banner nennt sie schon.
	if won:
		var new_tier := _current_fortress_tier()
		if new_tier > _fortress_tier:
			var bonus := FortressTier.health_bonus(new_tier - _fortress_tier)
			_fortress_tier = new_tier
			GameState.grow_fortress(bonus)
			await _play_upgrade_cutscene(new_tier, bonus)
	# Auflösung vor der Statistik, bei Sieg wie Niederlage, mit der vollen Liste.
	if not _wave_played_tasks.is_empty():
		await _leak_reveal.play(_wave_played_tasks)
	var total := _wave_correct + _wave_leaked
	var accuracy := 100.0 * float(_wave_correct) / float(max(1, total))
	# Belohnung (ChestReward): die Punkte tragen die Schwierigkeit, die Güte der Kiste kommt
	# aus der Genauigkeit. Gerechnet wird hier, nicht im Screen.
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
		# Nur der Zuwachs dieser Welle; den Gesamtstand liest der Screen bei PlayerLevel.
		"review": not _wave_played_tasks.is_empty(),
		"xp_gained": _wave_xp,
		"levels_gained": PlayerLevel.level - _level_at_start,
		# Sitzungsbilanz für Stufe 2: jetzt, denn SessionLog.end() leert die Sitzung.
		"session": RunBalance.build(SessionLog.current(),
				PlayerProgress.records_for_display(), _wave_number),
	})


## „◂ Zurück“ auf dem Ergebnis: die Antworten der Welle noch einmal, ohne Durchlauf. Der
## Screen wird nur ausgeblendet, Kiste und Wahl bleiben.
func _on_review_requested() -> void:
	if _wave_played_tasks.is_empty():
		return
	_stats.hide_stats()
	await _leak_reveal.play(_wave_played_tasks, true)
	_stats.resume()


## Die Schatzkiste ist offen: Gold ins Wallet, sofort gespeichert, damit ein Absturz die
## Kiste nicht rückgängig macht.
func _on_reward_collected(gold: int) -> void:
	Wallet.earn(gold, true)
	SaveCoordinator.commit("chest")


## Die nächste Welle: `delta` (-2..+2) verschiebt die Schwierigkeit relativ, begrenzt auf 1..5.
func _on_next_wave_requested(delta: int) -> void:
	# Eine gefallene Festung beendet den Lauf, auch wenn der Knopf schon fehlt.
	if not _last_won:
		return
	_difficulty = clampi(_difficulty + delta, 1, 5)
	_wave_number += 1
	_start_next_wave()


## Vom Statistik-Screen ins Menü: rasten, Lauf beenden, Sitzungs-Log speichern.
func _on_back_to_menu() -> void:
	if can_rest(RunRequest.keeps_run(), _last_won):
		_rest(_wave_number + 1)
	_report_run_ended()
	SaveCoordinator.commit("run_end")
	_saved_on_exit = true
	_leave_battle()


## Ob der Rückweg von Stufe 2 rastet (ADR 0020): nur ein Lauf von der Karte, dessen
## Festung steht. Expertenmodus und Testvorbereitung rasten nicht.
static func can_rest(is_level: bool, last_won: bool) -> bool:
	return is_level and last_won


## Legt den Lauf auf den Platz seines Buchs: an der Wellengrenze mit der nächsten Welle und
## der zuletzt gespielten Schwierigkeit, mitten in der Welle mit der angefangenen. Ein Lauf
## nur aus Boni rastet nicht (RunSave.keeps).
func _rest(next_wave: int, wave := {}) -> void:
	if not RunSave.keeps(RunRequest.level()):
		return
	RunSave.store(RunSave.build(RunRequest.level(), next_wave, _difficulty,
			GameState.run_snapshot(), _run_started_at, int(Time.get_unix_time_from_system()),
			wave), UserSettings.active_profile())
	EventBus.run_suspended.emit(next_wave, int(wave.get("remaining", 0)))


## Setzt einen Lauf fort (`state` aus RunRequest.take_resume) oder merkt sich einen neuen.
## Nach `apply_skills` und `run_started`, der Speicherstand ist danach verbraucht.
func _resume_run(state: Dictionary) -> void:
	_run_started_at = int(SessionLog.current().get("started_at", 0))
	if state.is_empty():
		return
	GameState.restore_run(state.get("run", {}))
	_wave_number = maxi(1, int(state.get("next_wave", 1)))
	_difficulty = clampi(int(state.get("difficulty", _difficulty)), 1, 5)
	_resumed = true
	_open_wave = RunSave.open_wave(state)
	_run_started_at = int(state.get("run_started_at", _run_started_at))
	var saved_level: Dictionary = state.get("level", {})
	RunSave.discard(str(saved_level.get("book", "")), int(saved_level.get("unit", 0)),
			UserSettings.active_profile())
	EventBus.run_resumed.emit(_wave_number, _run_started_at, Array(state.get("added", [])))


## Meldet das Ende des Laufs, bei Rückweg wie Abbruch; doppelt schadet nicht.
func _report_run_ended() -> void:
	EventBus.run_ended.emit({
		"wave_reached": _wave_number,
		"difficulty_last": _difficulty,
		"last_wave_won": _last_won,
	})
