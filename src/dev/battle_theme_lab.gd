extends Node3D
## Werkbank: das Schlachtfeld in jedem BattleTheme, ohne einen Kampf zu starten.
##
## Ein echter Kampf spielt im Entwicklungsprofil und schreibt Lernstand und Spur (siehe
## CLAUDE.md). Hier steht nur, was man SIEHT: Kamera und Boden aus denselben statischen
## Funktionen wie im WaveRunner, dazu Streudeko und die Burg zum Vergleich der Farben.
##
##     GODOT_WINDOW=1 tools/godot.sh res://scenes/dev/battle_theme_lab.tscn
##         ←/→ wechselt das Thema (in der Iso-Sicht), 0–4 die Festungsstufe, V schaltet
##         zwischen Iso- und Ich-Sicht. In der Ich-Sicht läuft man mit WASD/Pfeilen über
##         das ganze Gelände und schaut mit der Maus; Alt gibt die Maus frei.
##         M (oder der Knopf) schickt ein Monster im Grundtempo vom Spawn zur Mauer; dort
##         explodiert es wie im Kampf, ohne der Festung etwas zu melden (keine Spur).
##         K (oder der Knopf) wirft mit dem Wachkatapult (nur Stufe 4) auf das jüngste Monster, ohne eins
##         auf eine Stelle der Bahn — nur das Bild.
##         T (oder der Knopf) lässt sofort einen Steppenläufer rollen, wenn das Thema welche hat.
##         G (oder „Grafik" im Reiter Ansicht) schaltet die Grafikstufe durch (Schön, Mittel,
##         Schnell) — nur hier, die Einstellung des Geräts bleibt; --quality=fine|medium|fast
##         wählt den Anfang, auch für die Bildläufe. Ohne gilt die des Geräts.
##         „Regler ▸" (oder R) klappt die Regler auf, halb durchsichtig, in fünf Reitern:
##         Ansicht (Thema, Stufe, Sicht, Bildmitte, Ausschnitt, Neigung), Bahn (Festungsgröße,
##         Festungsfront, Spawn, Bahnbreite, Monstertempo), Licht (Schattentiefe, Bias,
##         Normal-Bias, Weichheit; Tageszeit, Uhr, Zeitraffer und die Grenzen des SunCycle)
##         HUD (das Kampf-HUD zeigen; „Aufsteigen" lässt das Level-Badge aufleuchten,
##         die Felder darunter setzen HP, Rüstung, XP-Ring, Zählerzeile und Wellenfortschritt
##         — nur GameState im Speicher und die Anzeige, nichts im Profil) und Bewuchs
##         (Dichte, Klumpen, Helligkeit, Größe der Büschel, Sträucher; die oberen drei
##         gelten dem Thema und stehen nach dem Wechsel auf dessen Werten) —
##         Namen wie die Konstanten im Spiel. „Werte kopieren" legt sie als Konstanten in die
##         Zwischenablage und schreibt sie in die Konsole. Der flache Boden wächst nicht mit
##         der Festungsgröße (FLAT_HALF_X ist eine Konstante des WaveRunners).
##         --tier=<0..4>, --view=first, --hour=<6..18> (Tageszeit) und --size=<m> (Ausschnitt)
##         wählen den Anfang.
##     GODOT_WINDOW=1 tools/godot.sh res://scenes/dev/battle_theme_lab.tscn -- --shoot
##         speichert jedes Thema als reports/battle_themes/<name>.png und beendet sich.
##         --theme=<name>[,<name>…] beschränkt auf diese Themen, --hour=<6..18> stellt die Tageszeit.
##     … -- --specimens
##         Nahaufnahme der Deko jedes Themas neben den gekauften Vergleichsstücken, in der
##         Größe ihres Platzes, als reports/battle_themes/specimens_<name>.png.
##     … -- --bow
##         Die Ich-Sicht mit dem Bogen: gesenkt, gespannt, ein Treffer und ein Fehlschuss im
##         Flug, als reports/battle_themes/bow_<schritt>.png.
##     … -- --blast
##         Der Explosionspfeil (Blast) aus der Ich-Sicht auf ein Monster mit zwei Nachbarn,
##         in Schritten nach dem Aufprall, als reports/battle_themes/blast_<ms>.png. Jeder
##         Schritt ist ein eigener Knall — das Speichern eines Bilds dauert länger als der.
##     … -- --catapult
##         Das Wachkatapult auf Stufe 4: Kranz dreht sich, Arm schlägt aus, der Stein fliegt
##         auf ein Monster und platzt, in Schritten nach dem Abschuss, als
##         reports/battle_themes/catapult_<ms>.png. Jeder Schritt ist ein eigener Wurf.
##         Reiter Schreibweise: richtige Form und getippte Antwort (oder ein Beispiel) —
##         darunter steht, wie der Kampf sie wertet. „Abspielen" (oder Enter im Feld
##         „Getippt") lässt bei einem nachsichtigen oder unvollständigen Treffer ein Monster
##         platzen und zeigt das Standbild wie im Kampf (ADR 0010), in der gerade
##         eingestellten Sicht.
##     … -- --spelling
##         Das Standbild der Schreibweise (SpellingFreeze) nach einer Explosion, in beiden
##         Sichten ganz herangefahren, als reports/battle_themes/spelling_<sicht>.png, dazu
##         eine unvollständige Antwort als spelling_missing.png.
##     … -- --hitches [--warm]
##         Misst den längsten Frame beim ERSTEN Auftritt jedes Kampfeffekts (Explosion,
##         „+XP", Monster, Meister-Feier) und gibt ihn in ms aus; --warm wärmt vorher vor
##         wie der Kampf (FxWarmup). Ein Lauf je Messung — ein zweiter Effekt im selben Lauf
##         wäre schon warm.
##     … -- --monsters [--tier=<0..4>]
##         Stellt Monster vor die Mauer — Größenvergleich mit der Festung (Vorgabe Vollausbau).
##     … -- --fortress
##         Jede Festungsstufe in beiden Sichten (Ich-Sicht vor der Mauer, zur Festung
##         gedreht) als reports/battle_themes/fortress_<stufe>_<sicht>.png.
##     … -- --hud [--theme=<name>]
##         Das Kampf-HUD (Kopfleiste, Antwortfeld, Legende, Auflösen-Knopf, Zaubervorrat) über dem ersten
##         Thema mit Beispielwerten: voll (Rüstung, Meisterungen) und schmal (ohne beides,
##         langer Name, geschlossene Eingabe der Ich-Sicht), als
##         reports/battle_themes/hud_<fall>.png. Werte stehen nur im Speicher.
##     … -- --levelup
##         Das Aufleuchten des Level-Badges in Schritten nach dem Aufstieg, als
##         reports/battle_themes/levelup_<ms>.png. Jeder Schritt ist ein eigener Aufstieg.
##     … -- --plates
##         Sieben Monster dicht beieinander auf der Bahn, in beiden Sichten — die Wortschilder
##         dürfen sich nicht überdecken, jedes dritte zeigt Alternativen (Zauber, ADR 0014) —
##         als reports/battle_themes/plates_<sicht>.png.
##     … -- --spells [--spell=<name>] [--view=first]
##         Jeder Zauber (Reiter Zauber, SpellFx) auf ein Feld mit sechs Monstern, in Schritten
##         nach dem Wirken, als reports/battle_themes/spell_<name>_<ms>.png; Frost dazu mit
##         Rissen und beim Auftauen (auf 3 s verkürzt). Jeder Schritt ist ein eigener Zauber.
##         Im Fenster: Reiter Zauber — „Feld füllen" stellt sechs Monster auf die Bahn,
##         „Zaubern" wirkt den gewählten Zauber auf alle, die laufen (ohne Vorrat, ohne Spur;
##         Lebensquell und Eisenhaut nehmen der Festung vorher etwas, nur im Speicher), „Feld
##         leeren" räumt auf und beendet, was für die ganze Welle gilt (Nebel und Bremse von
##         Schwere Luft, Alternativen des Orakelblicks) — bis dahin bekommt es auch jedes neue
##         Monster, wie im Kampf.
##     … -- --fps [--theme=<name>] [--windowed]
##         Misst im Vollbild und ohne VSync die mittlere Bildzeit mit allem an, jeweils ohne
##         eine Zutat (MSAA, Wolken, Teilchen, Wind, Schatten, Glow, Farbgebung, Weg+Flecken)
##         und ohne alles — die Grundlage für die Stufen in GraphicsQuality. Ein Thema je
##         Lauf (das erste).
##
## Headless gibt es keinen Renderer — deshalb GODOT_WINDOW=1.

const WaveRunnerScript := preload("res://src/battle/wave_runner.gd")
const BATTLE_SCENE := "res://scenes/battle/battle.tscn"
const CELEBRATION_SCENE := preload("res://scenes/ui/mastery_celebration.tscn")
const SHOT_DIR := "res://reports/battle_themes"
## Fester Samen: dieselben Hügel und dieselbe Deko in jedem Thema, damit Bilder vergleichbar
## sind.
const SEED := 4711
## Die Grafikstufen in der Reihenfolge von G, mit Namen wie in den Einstellungen.
const QUALITY_ORDER: Array[GraphicsQuality.Level] = [GraphicsQuality.Level.FINE,
		GraphicsQuality.Level.MEDIUM, GraphicsQuality.Level.FAST]
const QUALITY_NAMES := {GraphicsQuality.Level.FINE: "Schön", GraphicsQuality.Level.MEDIUM: "Mittel",
		GraphicsQuality.Level.FAST: "Schnell"}
const QUALITY_ARGS := {"fine": GraphicsQuality.Level.FINE, "medium": GraphicsQuality.Level.MEDIUM,
		"fast": GraphicsQuality.Level.FAST}

## Skalierung je Deko-Platz, wie im WaveRunner (_decorate, _decorate_outskirts).
const SLOT_SCALE := {"trees": [0.8, 1.4], "rocks": [1.6, 3.2], "grass": [1.2, 2.0],
		"props": [1.0, 1.0], "landmarks": [0.8, 1.2]}
## Die gekauften Vergleichsstücke vor jeder Nahaufnahme, mit ihrem Platz.
const REFERENCE := [["props/tree.glb", "trees"], ["props/rock.glb", "rocks"],
		["props/pillar.gltf", "landmarks"]]
## Reiter Schreibweise: [richtig, getippt] — jede Art Nachsicht einmal, zwei unvollständige
## Antworten, dazu ein exakter und ein falscher Treffer, die kein Standbild auslösen. Einzelne Wörter, keine Wortliste.
const SPELLING_EXAMPLES := [
	["l'élève", "l eleve"], ["l'école", "ecole"], ["été", "ete"], ["la forêt", "la foret"],
	["Noël", "noel"], ["ils reçoivent", "ils recoivent"], ["le cœur", "le coeur"],
	["à côté", "a cote"], ["aujourd'hui", "aujourdhui"], ["est-ce que", "est ce que"],
	["north-east", "north east"], ["That's fine by me.", "thats fine by me"],
	["die Meinung (zu etwas)", "meinung zu"], ["criticize sb. (for)", "criticize"],
	["le café", "le café"], ["l'école", "lecola"],
]

@onready var _pivot: Node3D = $CameraPivot
@onready var _camera: Camera3D = $CameraPivot/Camera3D
@onready var _sun: DirectionalLight3D = $Sun
@onready var _world: WorldEnvironment = $WorldEnvironment
@onready var _ground: MeshInstance3D = $Ground
@onready var _label: Label = %Name
@onready var _theme_select: OptionButton = %ThemeSelect
@onready var _tier_select: OptionButton = %TierSelect
@onready var _view_select: OptionButton = %ViewSelect

var _names: Array[String] = []
var _index := 0
var _decor: Node3D
var _scene_env: Environment
var _air: CPUParticles3D
var _petals: CPUParticles3D
var _weeds: Tumbleweeds
var _wind_strength := 1.0
var _theme: BattleTheme
var _noise: FastNoiseLite
var _path: BattlePath
## Fußpunkte der Bäume (für die Sträucher, GroundCover) und Dichte der Büschel.
var _tree_feet: Array[Vector3] = []
var _leaf_crowns: Array[AABB] = []
var _blossom_crowns: Array[AABB] = []
var _cover_density := GraphicsQuality.cover()
## Stellschrauben des Bewuchses (Reiter Bewuchs); das Spiel nimmt die Vorgaben.
var _tuning := GroundCover.Tuning.new()
## Grafikstufe der Werkbank (G), unabhängig von der des Geräts.
var _quality := GraphicsQuality.level()
var _tier := 4
## Die Ich-Sicht, oder null für die Iso-Kamera.
var _fp: FirstPersonView
## Die Maße, die die Werkbank verschieben lässt — in Weltkoordinaten des Kampfs.
var _goal_z: float = WaveRunnerScript.GOAL_Z
var _spawn_z: float = WaveRunnerScript.SPAWN_Z
var _view_z: float = WaveRunnerScript.VIEW_CENTER_Z
var _lane_half: float = WaveRunnerScript.LANE_HALF_WIDTH
var _fortress_scale: float = FortressModel.SCALE
var _monster_speed: float = WaveGenerator.REFERENCE_SPEED
## Ausschnitt und Neigung der Iso-Kamera, wie WaveRunner.setup_view sie setzt (in _ready gelesen).
var _cam_size := 32.0
var _pitch := 30.0
## Schattenkarte, wie WaveRunner.setup_view sie setzt (in _ready gelesen). Wirkt ohne Umbau.
var _shadow_distance: float = WaveRunnerScript.SHADOW_DISTANCE
var _shadow_bias := 0.1
var _normal_bias := 1.0
var _shadow_blur := 1.0
## Die Sonne wie im Kampf, aber steht mittags, bis die Uhr oder der Zeitraffer sie zieht —
## die Bilderläufe bleiben so vergleichbar.
var _sun_cycle: SunCycle
## Stunden im Spiel je Sekunde; 0 = steht.
var _sun_speed := 0.0
## Die gespawnten Monster — eigener Knoten, damit sie einen Umbau der Deko überstehen.
var _walkers: Node3D
## Reiter Zauber: dasselbe Bild wie im Kampf (SpellFx), die Wirkung aus dem SpellCaster.
var _spell_fx: SpellFx
var _caster := SpellCaster.new()
var _strike_index := 0
var _spell_list: Array = []
## Das Kampf-HUD für den Aufstieg (L), oder null, solange es nicht gebraucht wurde.
var _hud: Control
## Das Level, das das HUD zeigt — nur hier, PlayerLevel bleibt unberührt.
var _shown_level := 1
## Das Standbild des Reiters Schreibweise, oder null, solange es nicht gebraucht wurde.
var _spelling: SpellingFreeze


func _ready() -> void:
	_scene_env = _battle_environment()
	WaveRunnerScript.setup_view(_pivot, _camera, _sun)
	_cam_size = _camera.size
	_pitch = -_pivot.rotation_degrees.x
	_shadow_bias = _sun.shadow_bias
	_normal_bias = _sun.shadow_normal_bias
	_shadow_blur = _sun.shadow_blur
	add_child(Wind.new())
	# Die Wortschilder wie im Kampf, unter den Reglern.
	var plates := (load("res://scenes/ui/word_plates.tscn") as PackedScene).instantiate()
	$UI.add_child(plates)
	$UI.move_child(plates, 0)
	_sun_cycle = SunCycle.new()
	_sun_cycle.sun = _sun
	_sun_cycle.noon_yaw = SunCycle.yaw_of(_pivot)
	_sun_cycle.follow_clock = false
	add_child(_sun_cycle)
	for file in DirAccess.get_files_at(BattleTheme.DIR):
		if file.ends_with(".tres"):
			_names.append(file.get_basename())
	_names.sort()
	var only := _arg("theme")
	if not only.is_empty():
		_names = _names.filter(func(n: String) -> bool: return only.split(",").has(n))
	if _names.is_empty():
		push_error("battle_theme_lab: kein Thema gefunden")
		get_tree().quit(1)
		return
	if not _arg("tier").is_empty():
		_tier = clampi(int(_arg("tier")), 0, 4)
	if not _arg("size").is_empty():
		_cam_size = float(_arg("size"))
	if not _arg("hour").is_empty():
		_sun_cycle.phase = SunCycle.phase_of(float(_arg("hour")))
	if QUALITY_ARGS.has(_arg("quality")):
		_quality = QUALITY_ARGS[_arg("quality")]
	_fill_controls()
	_setup_spells()
	_show(0)
	if _arg("view") == "first":
		_set_first_person(true)
	if _has_arg("bow"):
		_shoot_bow.call_deferred()
	elif _has_arg("blast"):
		_shoot_blast.call_deferred()
	elif _has_arg("catapult"):
		_shoot_catapult.call_deferred()
	elif _has_arg("hud"):
		_shoot_hud.call_deferred()
	elif _has_arg("levelup"):
		_shoot_level_up.call_deferred()
	elif _has_arg("plates"):
		_shoot_plates.call_deferred()
	elif _has_arg("pitch"):
		_shoot_pitch.call_deferred()
	elif _has_arg("fps"):
		_measure_fps.call_deferred()
	elif _has_arg("spelling"):
		_shoot_spelling.call_deferred()
	elif _has_arg("spells"):
		_shoot_spells.call_deferred()
	elif _has_arg("hitches"):
		_measure_hitches.call_deferred()
	elif _has_arg("specimens"):
		_shoot_specimens.call_deferred()
	elif _has_arg("fortress"):
		_shoot_fortress.call_deferred()
	elif _has_arg("shoot"):
		_shoot_all.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		if key.keycode == KEY_V:
			_set_first_person(_fp == null)
			return
		if key.keycode == KEY_R:
			%MenuToggle.button_pressed = not %MenuToggle.button_pressed
			return
		if key.keycode == KEY_M:
			_spawn_monster()
			return
		if key.keycode == KEY_K:
			_throw_at_lane()
			return
		if key.keycode == KEY_T:
			_roll_tumbleweed()
			return
		if key.keycode == KEY_G:
			_set_quality(QUALITY_ORDER[(QUALITY_ORDER.find(_quality) + 1) % QUALITY_ORDER.size()])
			return
		if key.keycode >= KEY_0 and key.keycode <= KEY_4:
			_set_tier(key.keycode - KEY_0)
			return
	# In der Ich-Sicht laufen die Pfeile.
	if _fp != null:
		return
	if event.is_action_pressed("ui_right"):
		_show((_index + 1) % _names.size())
	elif event.is_action_pressed("ui_left"):
		_show((_index - 1 + _names.size()) % _names.size())


## Die Regler, zugeklappt hinter „Regler ▸"; in den Bildläufen stünden sie nur im Bild.
func _fill_controls() -> void:
	for n in _names:
		_theme_select.add_item(n)
	for t in 5:
		_tier_select.add_item("Stufe %d" % t)
	for q in QUALITY_ORDER:
		%QualitySelect.add_item(QUALITY_NAMES[q], q)
	%QualitySelect.select(%QualitySelect.get_item_index(_quality))
	%QualitySelect.item_selected.connect(func(i: int) -> void:
		_set_quality(%QualitySelect.get_item_id(i) as GraphicsQuality.Level))
	_view_select.add_item("Iso")
	_view_select.add_item("Ich-Sicht")
	_theme_select.item_selected.connect(_show)
	_tier_select.item_selected.connect(_set_tier)
	_view_select.item_selected.connect(func(i: int) -> void: _set_first_person(i == 1))
	%SpawnButton.pressed.connect(_spawn_monster)
	%CatapultButton.pressed.connect(_throw_at_lane)
	%TumbleweedButton.pressed.connect(_roll_tumbleweed)
	%GoalSpin.value = _goal_z
	%SpawnSpin.value = _spawn_z
	%ViewSpin.value = _view_z
	%LaneSpin.value = _lane_half
	%ScaleSpin.value = _fortress_scale
	%SpeedSpin.value = _monster_speed
	%SizeSpin.value = _cam_size
	%PitchSpin.value = _pitch
	# Das Tempo wirkt erst auf das nächste Monster, ein Umbau braucht es nicht.
	%SpeedSpin.value_changed.connect(func(v: float) -> void: _monster_speed = v)
	for spin: SpinBox in [%GoalSpin, %SpawnSpin, %ViewSpin, %LaneSpin, %ScaleSpin, %SizeSpin, %PitchSpin]:
		spin.value_changed.connect(_on_layout_changed)
	%ShadowDistanceSpin.value = _shadow_distance
	%ShadowBiasSpin.value = _shadow_bias
	%NormalBiasSpin.value = _normal_bias
	%ShadowBlurSpin.value = _shadow_blur
	%SunTimeSpin.value = SunCycle.hour_of(_sun_cycle.phase)
	# Die echte Uhrzeit steht auf jetzt; wer sie verstellt, sieht die Sonne des Spiels zu
	# dieser Stunde (und die Tageszeit im Spiel springt mit).
	%RealTimeSpin.set_value_no_signal(_real_hour_now())
	%RealTimeSpin.value_changed.connect(func(hour: float) -> void:
		_sun_cycle.phase = SunCycle.clock_phase(hour * 3600.0)
		%SunTimeSpin.set_value_no_signal(SunCycle.hour_of(_sun_cycle.phase))
		_apply_light())
	%SunSpeedSpin.value = _sun_speed
	%SunLowSpin.value = _sun_cycle.low
	%SunHighSpin.value = _sun_cycle.high
	%SunSweepSpin.value = _sun_cycle.sweep
	%SunYawSpin.value = _sun_cycle.noon_yaw
	for spin: SpinBox in [%ShadowDistanceSpin, %ShadowBiasSpin, %NormalBiasSpin, %ShadowBlurSpin,
			%SunTimeSpin, %SunSpeedSpin, %SunLowSpin, %SunHighSpin, %SunSweepSpin, %SunYawSpin]:
		spin.value_changed.connect(_on_light_changed)
	%ClockCheck.toggled.connect(func(on: bool) -> void:
		_sun_cycle.follow_clock = on
		%SunTimeSpin.editable = not on
		%RealTimeSpin.editable = not on
		%SunSpeedSpin.editable = not on)
	%CopyButton.pressed.connect(_copy_layout)
	_fill_cover_controls()
	_fill_grading_controls()
	_fill_spelling_controls()
	%HudCheck.toggled.connect(_show_hud)
	%LevelUpButton.pressed.connect(_level_up)
	%KillsSpin.value_changed.connect(func(_v: float) -> void: _show_tally())
	%MasteredSpin.value_changed.connect(func(_v: float) -> void: _show_tally())
	for spin: SpinBox in [%WaveNumberSpin, %WaveResolvedSpin, %WaveTotalSpin, %HpSpin,
			%HpMaxSpin, %ArmorSpin, %ArmorMaxSpin, %XpSpin]:
		spin.value_changed.connect(func(_v: float) -> void: _show_tally())
	%MenuToggle.toggled.connect(func(on: bool) -> void:
		%Menu.visible = on
		%MenuToggle.text = "Regler ▾" if on else "Regler ▸")
	var batch := ["shoot", "specimens", "bow", "blast", "catapult", "hitches", "fps", "fortress",
			"levelup", "spelling", "spells"].any(_has_arg)
	%MenuToggle.visible = not batch


## Reiter Licht, Thema: Dunst und Farbkorrektur. Wirkt sofort aufs Bild, ohne die Deko neu
## zu bauen. Ein Thema mit `light_from` zeigt die Werte seiner Quelle — dort gehören sie hin.
func _fill_grading_controls() -> void:
	var knobs := {
		%HazeSpin: func(v: float) -> void: _theme.haze = v,
		%BrightnessSpin: func(v: float) -> void: _theme.brightness = v,
		%SaturationSpin: func(v: float) -> void: _theme.saturation = v,
	}
	for spin: SpinBox in knobs:
		var apply: Callable = knobs[spin]
		spin.value_changed.connect(func(v: float) -> void:
			apply.call(v)
			_apply_grading())


func _apply_grading() -> void:
	_apply_fog()
	var env := _world.environment
	env.adjustment_brightness = _theme.brightness
	env.adjustment_saturation = _theme.saturation


## Reiter Bewuchs: drei Werte des Themas, der Rest sind die Konstanten von GroundCover.
## Jede Änderung baut die Deko neu (gleicher Samen, also dieselben Bäume).
func _fill_cover_controls() -> void:
	var knobs := {
		%CoverSpin: func(v: float) -> void: _theme.cover = v,
		%FlowersSpin: func(v: float) -> void: _theme.cover_flower_amount = v,
		%BushesSpin: func(v: float) -> void: _theme.bushes = v,
		%TuftDensitySpin: func(v: float) -> void: _tuning.tuft_density = v,
		%ClumpFromSpin: func(v: float) -> void: _tuning.clump_from = v,
		%ClumpFullSpin: func(v: float) -> void: _tuning.clump_full = v,
		%TuftLiftSpin: func(v: float) -> void: _tuning.tuft_lift = v,
		%TuftSizeMinSpin: func(v: float) -> void: _tuning.tuft_scale.x = v,
		%TuftSizeMaxSpin: func(v: float) -> void: _tuning.tuft_scale.y = v,
		%BushesPerTreeSpin: func(v: float) -> void: _tuning.bushes_per_tree = int(v),
		%BushRingSpin: func(v: float) -> void: _tuning.bush_ring = v,
		%BushScaleSpin: func(v: float) -> void: _tuning.bush_scale = v,
	}
	%TuftDensitySpin.value = _tuning.tuft_density
	%ClumpFromSpin.value = _tuning.clump_from
	%ClumpFullSpin.value = _tuning.clump_full
	%TuftLiftSpin.value = _tuning.tuft_lift
	%TuftSizeMinSpin.value = _tuning.tuft_scale.x
	%TuftSizeMaxSpin.value = _tuning.tuft_scale.y
	%BushesPerTreeSpin.value = _tuning.bushes_per_tree
	%BushRingSpin.value = _tuning.bush_ring
	%BushScaleSpin.value = _tuning.bush_scale
	for spin: SpinBox in knobs:
		var apply: Callable = knobs[spin]
		spin.value_changed.connect(func(v: float) -> void:
			apply.call(v)
			_build_decor(_noise, _theme))


## Reiter Schreibweise: ein Beispiel füllt beide Felder, jede Änderung zeigt sofort das Urteil.
func _fill_spelling_controls() -> void:
	for pair: Array in SPELLING_EXAMPLES:
		%SpellPreset.add_item("%s  ←  %s" % pair)
	%SpellPreset.item_selected.connect(func(i: int) -> void:
		%SpellWord.text = SPELLING_EXAMPLES[i][0]
		%SpellTyped.text = SPELLING_EXAMPLES[i][1]
		_judge_spelling())
	%SpellWord.text = SPELLING_EXAMPLES[0][0]
	%SpellTyped.text = SPELLING_EXAMPLES[0][1]
	%SpellWord.text_changed.connect(func(_t: String) -> void: _judge_spelling())
	%SpellTyped.text_changed.connect(func(_t: String) -> void: _judge_spelling())
	%SpellTyped.text_submitted.connect(func(_t: String) -> void: _play_spelling())
	%SpellPlayButton.pressed.connect(_play_spelling)
	_judge_spelling()


## Wie der Kampf die Antwort wertet (WaveRunner.best_hit, nachsichtig).
func _spelling_verdict() -> Dictionary:
	return AnswerEvaluator.new().evaluate([%SpellWord.text], %SpellTyped.text, true)


## Ob der Kampf das Standbild zeigte: ein Treffer, der nicht exakt oder nicht vollständig war.
static func _spelling_shown(verdict: Dictionary) -> bool:
	return bool(verdict["matched"]) and not (bool(verdict["exact"]) and bool(verdict["complete"]))


## Das Urteil unter den Feldern; nur ein nachsichtiger oder unvollständiger Treffer gibt
## das Standbild.
func _judge_spelling() -> void:
	var verdict := _spelling_verdict()
	var text := "Falsch — kein Standbild"
	if bool(verdict["matched"]) and not _spelling_shown(verdict):
		text = "Exakt — kein Standbild"
	elif bool(verdict["matched"]):
		var form := str(verdict["canonical"])
		var marks := AnswerEvaluator.spelling_marks(form, %SpellTyped.text)
		var missing := AnswerEvaluator.missing_marks(form, %SpellTyped.text)
		var parts: Array[String] = []
		for i in marks:
			parts.append(form[i])
		var gaps: Array[String] = []
		for i in missing:
			gaps.append(form[i])
		var names: Array[String] = []
		for group: Dictionary in SpellingFreeze.accent_groups(form, marks):
			names.append(str(group["name"]))
		text = "Nachsichtig — rot: %s" % (" ".join(parts) if not parts.is_empty() else "nichts")
		if not gaps.is_empty():
			text += "\nFehlt (blau): " + "".join(gaps)
		if not names.is_empty():
			text += "\nÜber dem Wort: " + ", ".join(names)
	%SpellVerdict.text = text


## Ein Monster platzt vor der Festung, dann das Standbild wie im Kampf: der Baum hält an,
## solange es steht (WaveRunner._on_spelling_started). Nur bei einem nachsichtigen oder
## unvollständigen Treffer.
func _play_spelling() -> void:
	_judge_spelling()
	var verdict := _spelling_verdict()
	if not _spelling_shown(verdict):
		return
	if _spelling == null:
		_spelling = (load("res://scenes/ui/spelling_freeze.tscn") as PackedScene).instantiate()
		$UI.add_child(_spelling)
		# Die Regler treten zurück, solange es steht — sonst stünden sie im Bild.
		_spelling.started.connect(func(_ms: int) -> void:
			get_tree().paused = true
			%Menu.visible = false)
		_spelling.finished.connect(func() -> void:
			get_tree().paused = false
			%Menu.visible = %MenuToggle.button_pressed)
	if _spelling.is_busy():
		return
	var form := str(verdict["canonical"])
	var marks := AnswerEvaluator.spelling_marks(form, %SpellTyped.text)
	var missing := AnswerEvaluator.missing_marks(form, %SpellTyped.text)
	var at := Vector3(2.0, 0.0, _goal() - 12.0)
	var monster := FxWarmup.MONSTER_SCENE.instantiate() as Monster
	monster.setup(FxWarmup.monster_defs()[0], {"prompt": %SpellTyped.text,
			"lexeme_type": "noun"}, 1000.0, 0.0)
	monster.screen_sized_label = _fp != null
	monster.position = at
	add_child(monster)
	monster.halt()
	await get_tree().create_timer(0.6).timeout
	var fx := Explosion.new()
	# Wie WaveRunner._burst nach einem Treffer.
	fx.setup(Color(0.7, 1.0, 0.4), 1.5)
	fx.position = at + Vector3(0.0, 1.0, 0.0)
	add_child(fx)
	Sfx.play(&"monster_kill")
	monster.queue_free()
	var camera := _fp.camera if _fp != null else _camera
	_spelling.play(form, marks, WaveRunnerScript.spelling_zoom(camera, at + Vector3(0.0, 1.0, 0.0)),
			missing)


## Wie viel gerade wächst, unter den Reglern.
func _count_cover() -> void:
	var parts: Array[String] = []
	for kind: String in ["Tufts", "Flowers", "Bushes"]:
		var mmi := _decor.get_node_or_null(kind) as MultiMeshInstance3D
		parts.append("%s %d" % [kind, mmi.multimesh.instance_count if mmi != null else 0])
	%CoverCount.text = "  ".join(parts)


## Grafikstufe der Werkbank wechseln und das Thema damit neu aufbauen.
func _set_quality(level: GraphicsQuality.Level) -> void:
	_quality = level
	%QualitySelect.select(%QualitySelect.get_item_index(level))
	_show(_index)


## Ein Monster wie im Kampf (WaveRunner._spawn_next) im Grundtempo des WaveGenerators. Sein
## Ziel liegt weit hinter der Mauer: erreicht es die Festung, meldet es das dem EventBus, und
## die Spur schriebe mit — deshalb nimmt es `_process` kurz davor vom Feld.
func _spawn_monster() -> void:
	var defs := FxWarmup.monster_defs()
	if defs.is_empty():
		return
	if _walkers == null:
		_walkers = Node3D.new()
		add_child(_walkers)
	var monster := FxWarmup.MONSTER_SCENE.instantiate() as Monster
	# Mit Alternativen, damit „Drittes Auge" etwas aufzudecken hat (Reiter Zauber).
	monster.setup(defs.pick_random(), {"prompt": "house", "prompt_alt": ["home", "building"],
			"lexeme_type": WordTypePalette.COLORS.keys().pick_random()}, _goal() + 1000.0,
			_monster_speed)
	monster.screen_sized_label = _fp != null
	monster.position = Vector3(randf_range(-_lane_half, _lane_half), 0.0, WaveRunnerScript.SPAWN_Z)
	_walkers.add_child(monster)
	# Was für die ganze Welle gewirkt wurde (Schwere Luft, Orakelblick), wie im Kampf.
	_spell_fx.on_spawn(monster, _caster.on_spawn(monster))


func _process(delta: float) -> void:
	_run_sun(delta)
	if _walkers == null:
		return
	for monster: Node3D in _walkers.get_children():
		if monster.position.z >= _goal() and not monster.is_queued_for_deletion():
			# Wie WaveRunner._on_monster_reached_goal, ohne Schaden und Spur.
			var fx := Explosion.new()
			fx.setup(Color(1.0, 0.45, 0.12), 2.6)
			fx.position = monster.position + Vector3(0.0, 1.0, 0.0)
			add_child(fx)
			Sfx.play(&"fortress_hit")
			monster.queue_free()


## Zeitraffer: `_sun_speed` Stunden je Sekunde, nach dem Abend wieder der Morgen. Mit der
## Uhr zieht SunCycle selbst; die Anzeige der Tageszeit läuft in beiden Fällen mit.
func _run_sun(delta: float) -> void:
	if not _sun_cycle.follow_clock and _sun_speed > 0.0:
		var day := SunCycle.DUSK_HOUR - SunCycle.DAWN_HOUR
		_sun_cycle.phase = fposmod(_sun_cycle.phase + _sun_speed * delta / day, 1.0)
		_sun_cycle.apply()
	if _sun_cycle.follow_clock or _sun_speed > 0.0:
		%SunTimeSpin.set_value_no_signal(SunCycle.hour_of(_sun_cycle.phase))
	if _sun_cycle.follow_clock:
		%RealTimeSpin.set_value_no_signal(_real_hour_now())


## Stunde der echten Uhr dieses Rechners, mit Minuten als Bruch.
func _real_hour_now() -> float:
	return fposmod(SunCycle.local_unix(), 86400.0) / 3600.0


## Die Werkbank baut in einem Rahmen, in dem der Spawn auf WaveRunner.SPAWN_Z bleibt: die
## Hügel des Bodens hängen daran (terrain_height), so stimmen sie ohne einen Umbau des
## WaveRunners. Festung und Bildmitte rücken dafür um den Unterschied mit.
func _shift() -> float:
	return _spawn_z - WaveRunnerScript.SPAWN_Z


## Wie WaveRunner.FORTRESS_GROW, für die eingestellte Festungsgröße.
func _grow() -> float:
	return _fortress_scale / FortressModel.LAYOUT_SCALE


## Festungsfront im Rahmen der Werkbank.
func _goal() -> float:
	return _goal_z - _shift()


func _on_layout_changed(_value: float) -> void:
	_goal_z = %GoalSpin.value
	_spawn_z = %SpawnSpin.value
	_view_z = %ViewSpin.value
	_lane_half = %LaneSpin.value
	_fortress_scale = %ScaleSpin.value
	_cam_size = %SizeSpin.value
	_pitch = %PitchSpin.value
	_show(_index)


func _on_light_changed(_value: float) -> void:
	_shadow_distance = %ShadowDistanceSpin.value
	_shadow_bias = %ShadowBiasSpin.value
	_normal_bias = %NormalBiasSpin.value
	_shadow_blur = %ShadowBlurSpin.value
	_sun_speed = %SunSpeedSpin.value
	_sun_cycle.low = %SunLowSpin.value
	_sun_cycle.high = %SunHighSpin.value
	_sun_cycle.sweep = %SunSweepSpin.value
	_sun_cycle.noon_yaw = %SunYawSpin.value
	if not _sun_cycle.follow_clock:
		_sun_cycle.phase = SunCycle.phase_of(%SunTimeSpin.value)
	_apply_light()


## Sonne und Schattenkarte wie in WaveRunner.setup_view, mit den Werten der Regler. Die
## Karte spannt sich über die Tiefe der Iso-Kamera bis `far` — beides hängt zusammen wie dort.
func _apply_light() -> void:
	_sun_cycle.apply()
	_sun.directional_shadow_max_distance = _shadow_distance
	_camera.far = _shadow_distance
	_sun.shadow_bias = _shadow_bias
	_sun.shadow_normal_bias = _normal_bias
	_sun.shadow_blur = _shadow_blur


func _copy_layout() -> void:
	var text := "\n".join([
		"# src/battle/wave_runner.gd",
		"const GOAL_Z := %.1f" % _goal_z,
		"const SPAWN_Z := %.1f" % _spawn_z,
		"const VIEW_CENTER_Z := %.1f" % _view_z,
		"const LANE_HALF_WIDTH := %.1f" % _lane_half,
		"# setup_view: camera.size = %.1f, pivot.rotation_degrees.x = %.1f" % [_cam_size, -_pitch],
		"# src/battle/fortress_model.gd",
		"const SCALE := %.2f" % _fortress_scale,
		"# src/battle/wave_generator.gd",
		"const REFERENCE_SPEED := %.1f" % _monster_speed,
		"# src/battle/wave_runner.gd (Licht)",
		"const SHADOW_DISTANCE := %.1f" % _shadow_distance,
		"# setup_view: sun.shadow_bias = %.2f, sun.shadow_normal_bias = %.2f, sun.shadow_blur = %.2f"
				% [_shadow_bias, _normal_bias, _shadow_blur],
		"# src/battle/sun_cycle.gd",
		"const LOW := %.1f" % _sun_cycle.low,
		"const HIGH := %.1f" % _sun_cycle.high,
		"const SWEEP := %.1f" % _sun_cycle.sweep,
		"# noon_yaw = %.1f (Vorgabe: Blickrichtung der Kamera, %.1f)" % [_sun_cycle.noon_yaw, SunCycle.yaw_of(_pivot)],
		"# src/battle/ground_cover.gd",
		"const TUFT_DENSITY := %.2f" % _tuning.tuft_density,
		"const CLUMP_FROM := %.2f" % _tuning.clump_from,
		"const CLUMP_FULL := %.2f" % _tuning.clump_full,
		"const TUFT_LIFT := %.2f" % _tuning.tuft_lift,
		"const TUFT_SCALE := Vector2(%.1f, %.1f)" % [_tuning.tuft_scale.x, _tuning.tuft_scale.y],
		"const BUSHES_PER_TREE := %d" % _tuning.bushes_per_tree,
		"const BUSH_RING := Vector2(%.1f, %.2f)" % [GroundCover.BUSH_RING.x, _tuning.bush_ring],
		"const BUSH_SCALE := Vector2(%.1f, %.1f)" % [GroundCover.BUSH_SCALE.x, _tuning.bush_scale],
		"# assets/battle_themes/%s.tres" % _names[_index],
		"cover = %.2f" % _theme.cover,
		"cover_flower_amount = %.2f" % _theme.cover_flower_amount,
		"bushes = %.2f" % _theme.bushes,
		"# assets/battle_themes/%s.tres" % (_theme.light_from if not _theme.light_from.is_empty() else _names[_index]),
		"saturation = %.2f" % _theme.saturation,
		"brightness = %.2f" % _theme.brightness,
		"haze = %.4f" % _theme.haze,
	])
	DisplayServer.clipboard_set(text)
	print("battle_theme_lab: Bahn %.1f m\n%s" % [_goal_z - _spawn_z, text])


func _set_tier(tier: int) -> void:
	_tier = tier
	_build_decor(_noise, _theme)
	_update_label()


## Die Ich-Sicht des Kampfs (mit Nebel wie dort), frei über das ganze Gelände; aus heißt
## zurück zur Iso-Kamera.
func _set_first_person(on: bool) -> void:
	if _fp != null:
		_fp.free()
		_fp = null
	if on:
		_fp = (load("res://scenes/battle/first_person_view.tscn") as PackedScene).instantiate() as FirstPersonView
		var area := WaveRunnerScript.visible_ground_area(_camera)
		_fp.bounds = Rect2(area.position, area.size)
		_fp.position = Vector3(0.0, 0.0, _goal() - 22.0)
		add_child(_fp)
		_fp.call("_set_yaw", PI)   # zur Festung gedreht
		_fp.set_active(true)
	else:
		_camera.make_current()
	_apply_fog()
	_update_label()


## Nebel nur in der Ich-Sicht, wie im Kampf — auf einer Kopie, denn das Environment ist
## eine geteilte Ressource der Kampfszene.
func _apply_fog() -> void:
	var env := _world.environment
	if env == _scene_env:
		env = env.duplicate() as Environment
		_world.environment = env
	if _fp == null:
		_theme.apply_haze(env)
		return
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = env.background_color
	env.fog_depth_begin = FirstPersonView.FOG_BEGIN
	env.fog_depth_end = FirstPersonView.FOG_END


func _update_label() -> void:
	_label.text = "%s  (%d/%d)  · %s" % [_names[_index], _index + 1, _names.size(), QUALITY_NAMES[_quality]]
	if not _theme.ground_texture.is_empty():
		var missing := not ResourceLoader.exists(_theme.ground_texture_path())
		_label.text += "  · %s%s" % [_theme.ground_texture, " (fehlt)" if missing else ""]
	_theme_select.select(_index)
	%CoverSpin.set_value_no_signal(_theme.cover)
	%FlowersSpin.set_value_no_signal(_theme.cover_flower_amount)
	%BushesSpin.set_value_no_signal(_theme.bushes)
	%HazeSpin.set_value_no_signal(_theme.haze)
	%BrightnessSpin.set_value_no_signal(_theme.brightness)
	%SaturationSpin.set_value_no_signal(_theme.saturation)
	_tier_select.select(_tier)
	_view_select.select(1 if _fp != null else 0)
	%LaneLength.text = "Bahn %.1f m" % (_goal_z - _spawn_z)


func _show(index: int) -> void:
	_index = index
	var theme := BattleTheme.named(_names[index])
	_world.environment = _scene_env
	theme.apply(_world, _sun)
	GraphicsQuality.apply_environment(_world, _quality)
	get_viewport().msaa_3d = GraphicsQuality.msaa(_quality)
	_cover_density = GraphicsQuality.cover(_quality)
	_sun_cycle.color = theme.sun_color
	var noise := WaveRunnerScript.terrain_noise(SEED)
	# Wie im Kampf für den weitesten Blick gebaut (SceneZoom kommt aus der Ferne) — sonst
	# ragt am unteren Rand der Hintergrund unter den Hügeln hervor.
	_pivot.position.z = _view_z - _shift()
	_pivot.rotation_degrees.x = -_pitch
	_camera.size = _cam_size
	var view_size := _camera.size
	_camera.size = view_size / SceneZoom.FROM
	_ground.mesh = WaveRunnerScript.build_terrain(_camera, noise, theme)
	_camera.size = view_size
	var path_rng := RandomNumberGenerator.new()
	# Je Thema ein anderer Verlauf, aber bei jedem Lauf derselbe — wie im Kampf gewürfelt.
	path_rng.seed = SEED + index
	_path = BattlePath.make(theme.path, _goal(), path_rng)
	WaveRunnerScript.dress_ground(_ground, theme, _path, _quality)
	_apply_light()
	_wind_strength = theme.wind
	_theme = theme
	_noise = noise
	_build_decor(noise, theme)
	if _air != null:
		_air.free()
	_air = AmbientParticles.build(theme.particles, WaveRunnerScript.visible_ground_area(_camera), _leaf_crowns) \
			if GraphicsQuality.particles(_quality) else null
	if _air != null:
		add_child(_air)
	for old: Node in [_petals, _weeds]:
		if old != null:
			old.free()
	_petals = AmbientParticles.blossoms(_blossom_crowns) if GraphicsQuality.particles(_quality) else null
	if _petals != null:
		add_child(_petals)
	_weeds = null
	if theme.tumbleweeds and GraphicsQuality.particles(_quality):
		var half_x := 11.0 * _grow()
		_weeds = Tumbleweeds.make(WaveRunnerScript.visible_ground_area(_camera),
				func(x: float, z: float) -> float: return WaveRunnerScript.terrain_height(x, z, noise),
				Rect2(-half_x, _goal() - 0.5, 2.0 * half_x, 11.0 * _grow() + 0.5), SEED + index)
		_weeds.on_screen = func(x: float, z: float) -> bool:
			return _fp != null or WaveRunnerScript.tile_on_screen(_camera, x, z)
		add_child(_weeds)
		# In den Bildläufen steht einer mitten im Bild, sonst sähe man keinen.
		if _has_arg("shoot"):
			_weeds.roll()
			var weed := _weeds.get_child(0) as Node3D
			var mid := _weeds.area.get_center()
			var best := INF
			while _weeds.alive() > 0:
				var gap := Vector2(weed.position.x, weed.position.z).distance_to(mid)
				if gap > best:
					break
				best = gap
				_weeds.step(0.02)
			_weeds.set_process(false)
	_apply_fog()
	_update_label()


func _shoot_all() -> void:
	var dir := ProjectSettings.globalize_path(SHOT_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	for i in _names.size():
		_show(i)
		# Zwei Bilder abwarten: das erste nach dem Umbau zeigt noch Schatten des alten.
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var path := "%s/%s.png" % [dir, _names[i]]
		get_viewport().get_texture().get_image().save_png(path)
		print("battle_theme_lab: ", path)
	get_tree().quit()


func _shoot_fortress() -> void:
	var dir := ProjectSettings.globalize_path(SHOT_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	for tier in 5:
		_tier = tier
		_build_decor(_noise, _theme)
		for first in [false, true]:
			_set_first_person(first)
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var path := "%s/fortress_%d_%s.png" % [dir, tier, "first" if first else "iso"]
			get_viewport().get_texture().get_image().save_png(path)
			print("battle_theme_lab: ", path)
	get_tree().quit()


func _shoot_plates() -> void:
	var dir := ProjectSettings.globalize_path(SHOT_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	$UI/Margin.visible = false
	var defs := FxWarmup.monster_defs()
	# Platzhalter verschiedener Länge, keine Vokabeln.
	var prompts := ["Wort", "Platzhalter", "ein langer Platzhaltertext", "abc", "noch ein Wort",
			"Beispiel", "zwei Wörter"]
	var mid := (WaveRunnerScript.SPAWN_Z + _goal()) / 2.0
	var spots := [Vector3(-1.0, 0.0, mid), Vector3(0.5, 0.0, mid + 0.8), Vector3(1.5, 0.0, mid - 1.0),
			Vector3(-2.5, 0.0, mid + 2.0), Vector3(3.0, 0.0, mid + 0.3), Vector3(0.0, 0.0, mid - 2.5),
			Vector3(-0.5, 0.0, mid + 4.0)]
	for view in ["iso", "first"]:
		_set_first_person(view == "first")
		if _fp != null:
			_fp.position = Vector3(0.0, 0.0, mid - 12.0)
			_fp.call("_set_yaw", PI)
		var group := Node3D.new()
		add_child(group)
		for i in spots.size():
			var monster := FxWarmup.MONSTER_SCENE.instantiate() as Monster
			var types := WordTypePalette.COLORS.keys()
			# Jedes dritte zeigt Alternativen wie nach dem Zauber „Drittes Auge".
			var alts := ["Alternative", "noch eine"] if i % 3 == 0 else []
			monster.setup(defs[i % defs.size()], {"prompt": prompts[i], "prompt_alt": alts,
					"lexeme_type": types[i % types.size()]}, 1000.0, 0.0)
			monster.screen_sized_label = _fp != null
			monster.position = spots[i]
			group.add_child(monster)
			monster.halt()
			monster.show_alts()
		# Die Schilder gleiten an ihren Platz; eine halbe Sekunde reicht.
		for i in 30:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path := "%s/plates_%s.png" % [dir, view]
		get_viewport().get_texture().get_image().save_png(path)
		print("battle_theme_lab: ", path)
		group.free()
	get_tree().quit()


## Ein Bild für den Pitch: HUD, Monster mit lateinischen Wörtern und ein Treffer, als
## reports/battle_themes/pitch_<ms>.png. Werte stehen nur im Speicher, wie bei --hud.
func _shoot_pitch() -> void:
	var dir := ProjectSettings.globalize_path(SHOT_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	$UI/Margin.visible = false
	GameState.reset()
	GameState.fortress_max_health = 200
	GameState.fortress_health = 170
	GameState.fortress_armor_max = 100
	GameState.fortress_armor = 60
	GameState.wave_number = 3
	GameState.wave_total = 20
	GameState.wave_resolved = 9
	GameState.monsters_defeated = 41
	var pieces: Array[Node] = []
	for path in ["res://scenes/ui/hud.tscn", "res://scenes/ui/answer_input.tscn",
			"res://scenes/ui/word_type_legend.tscn"]:
		var piece := (load(path) as PackedScene).instantiate()
		$UI.add_child(piece)
		pieces.append(piece)
	var hud := pieces[0] as Control
	hud.call("set_player_name", "Felix")
	(hud.get_node("%XpRing") as XpRing).ratio = 0.7
	(hud.get_node("%LevelText") as Label).text = "7"
	(hud.get_node("%Mastered") as Label).text = "12 gemeistert"
	(pieces[1] as LineEdit).text = "Wass"
	var defs := FxWarmup.monster_defs()
	var words := [["villa", "noun"], ["servus", "noun"], ["laudare", "verb"], ["magnus", "adjective"],
			["aqua", "noun"], ["semper", "adverb"]]
	# Über die ganze Bahn verteilt, vom Spawn bis kurz vor die Mauer.
	var spots := [Vector3(-7.0, 0.0, _goal() - 33.0), Vector3(7.5, 0.0, _goal() - 31.0),
			Vector3(0.0, 0.0, _goal() - 26.0), Vector3(-7.5, 0.0, _goal() - 19.0),
			Vector3(7.5, 0.0, _goal() - 16.0), Vector3(-3.0, 0.0, _goal() - 8.0)]
	var types := WordTypePalette.COLORS.keys()
	for i in spots.size():
		var monster := FxWarmup.MONSTER_SCENE.instantiate() as Monster
		var type: String = words[i][1] if types.has(words[i][1]) else str(types[i % types.size()])
		monster.setup(defs[i % defs.size()], {"prompt": words[i][0], "lexeme_type": type}, 1000.0, 0.0)
		monster.position = spots[i]
		add_child(monster)
		monster.halt()
	var at := Vector3(-2.5, 0.0, _goal() - 17.0)
	await FxWarmup.run(self, at, [], [Blast.new()])
	await get_tree().create_timer(1.0).timeout
	for ms: int in [120]:
		var fx := Blast.new()
		fx.setup(WordTypePalette.color_for("noun"))
		fx.position = at
		add_child(fx)
		await get_tree().create_timer(ms / 1000.0).timeout
		await RenderingServer.frame_post_draw
		var path := "%s/pitch_%s_%s_%04d.png" % [dir, _names[0], _arg("hour"), ms]
		get_viewport().get_texture().get_image().save_png(path)
		print("battle_theme_lab: ", path)
		fx.queue_free()
		await get_tree().create_timer(0.8).timeout
	GameState.reset()
	get_tree().quit()


func _shoot_hud() -> void:
	var dir := ProjectSettings.globalize_path(SHOT_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	$UI/Margin.visible = false
	var cases := {
		"full": {"name": "Samuel Nitsche", "armor": 100, "mastered": true, "closed": false},
		"bare": {"name": "Bartholomäus-Maximilian von Hohenstein", "armor": 0,
				"mastered": false, "closed": true},
	}
	# Ein Vorrat für das Bild, nur im Speicher (ohne buy/take schreibt Inventory nichts).
	var stock := Inventory.slots.duplicate()
	Inventory.slots.assign([{"id": "spell.frost", "count": 3}, {},
			{"id": "spell.mend", "count": 12}, {"id": "spell.thunder", "count": 1}])
	for case in cases:
		var c: Dictionary = cases[case]
		GameState.reset()
		GameState.fortress_max_health = 100
		GameState.fortress_health = 80
		GameState.fortress_armor_max = int(c["armor"])
		GameState.fortress_armor = int(c["armor"] * 0.6)
		GameState.wave_number = 3
		GameState.wave_total = 20
		GameState.wave_resolved = 12
		GameState.monsters_defeated = 24
		var pieces: Array[Node] = []
		for path in ["res://scenes/ui/hud.tscn", "res://scenes/ui/answer_input.tscn",
				"res://scenes/ui/word_type_legend.tscn", "res://scenes/ui/fast_resolve_button.tscn",
				"res://scenes/ui/pause_button.tscn", "res://scenes/ui/pause_overlay.tscn",
				"res://scenes/ui/spell_slots.tscn"]:
			var piece := (load(path) as PackedScene).instantiate()
			$UI.add_child(piece)
			pieces.append(piece)
		var hud := pieces[0] as Control
		hud.call("set_player_name", str(c["name"]))
		(hud.get_node("%XpRing") as XpRing).ratio = 0.6
		(hud.get_node("%LevelText") as Label).text = "4"
		(hud.get_node("%Book") as Control).visible = bool(c["mastered"])
		(hud.get_node("%Mastered") as Control).visible = bool(c["mastered"])
		(hud.get_node("%Mastered") as Label).text = "8 gemeistert"
		# Die Eingabe fängt zu an; das erste Bild zeigt sie offen, das zweite zu mit der
		# Beschriftung der Ich-Sicht.
		pieces[1].set("first_person", bool(c["closed"]))
		if not bool(c["closed"]):
			pieces[1].call("_set_open", true)
		# Die Pause im zweiten Bild: abgedunkelt.
		if bool(c["closed"]):
			(pieces[5] as PauseOverlay).show_pause()
		for i in 3:
			await RenderingServer.frame_post_draw
		var path := "%s/hud_%s.png" % [dir, case]
		get_viewport().get_texture().get_image().save_png(path)
		print("battle_theme_lab: ", path)
		for piece in pieces:
			piece.queue_free()
		await get_tree().process_frame
	Inventory.slots.assign(stock)
	GameState.reset()
	get_tree().quit()


func _shoot_catapult() -> void:
	var dir := ProjectSettings.globalize_path(SHOT_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	$UI/Margin.visible = false
	_tier = 4
	_build_decor(_noise, _theme)
	var at := Vector3(6.0, 0.0, _goal() - 16.0)
	await FxWarmup.run(self, at + WaveRunnerScript.CATAPULT_AIM, [],
			[CatapultStone.new(), Blast.new()])
	await get_tree().create_timer(1.0).timeout
	var turrets := FortressModel.catapults(_decor)
	if turrets.is_empty():
		push_error("battle_theme_lab: kein Katapult auf Stufe 4")
		get_tree().quit(1)
		return
	for ms: int in [120, 300, 390, 550, 800, 1100, 1350, 1600, 2100]:
		# Jeder Schritt ein eigener Wurf auf ein eigenes Monster, das im Grundtempo läuft.
		var monster := _walker_at(at)
		var turret := _nearest_turret(turrets, monster.global_position)
		turret.rotation.y = 0.0
		(turret.get_node(FortressModel.CATAPULT_ARM) as Node3D).rotation.x = 0.0
		_throw(turret, monster, monster.global_position + WaveRunnerScript.CATAPULT_AIM)
		await get_tree().create_timer(ms / 1000.0).timeout
		await RenderingServer.frame_post_draw
		var path := "%s/catapult_%04d.png" % [dir, ms]
		get_viewport().get_texture().get_image().save_png(path)
		print("battle_theme_lab: ", path)
		# Der Wurf zu Ende, bevor der nächste anfängt.
		await get_tree().create_timer(2.5).timeout
		if is_instance_valid(monster):
			monster.queue_free()
	get_tree().quit()


## Ein Monster wie mit M, aber an einer festen Stelle der Bahn.
func _walker_at(at: Vector3) -> Monster:
	_spawn_monster()
	var monster := _walkers.get_child(_walkers.get_child_count() - 1) as Monster
	monster.position = at
	return monster


func _nearest_turret(turrets: Array[Node3D], at: Vector3) -> Node3D:
	var best := turrets[0]
	for t in turrets:
		if absf(t.global_position.x - at.x) < absf(best.global_position.x - at.x):
			best = t
	return best


## Taste T: ein Steppenläufer sofort, ohne auf den nächsten zu warten.
func _roll_tumbleweed() -> void:
	if _weeds == null:
		print("battle_theme_lab: hier rollen keine Steppenläufer (BattleTheme.tumbleweeds)")
		return
	_weeds.roll()


## Taste K: ein Wurf aus dem nächsten Katapult, auf das zuletzt geschickte Monster (mit
## Vorhalt, wie im Kampf) oder eine Stelle der Bahn. Unter Stufe 4 gibt es keine
## Katapulte, wie im Kampf.
func _throw_at_lane() -> void:
	var turrets := FortressModel.catapults(_decor)
	if turrets.is_empty():
		print("battle_theme_lab: Katapulte erst ab Stufe %d (Taste 4)" % FortressModel.CATAPULT_TIER)
		return
	var target := Vector3(randf_range(-6.0, 6.0), 0.0, _goal() - randf_range(8.0, 20.0)) \
			+ WaveRunnerScript.CATAPULT_AIM
	var monster: Monster = null
	if is_instance_valid(_walkers):
		for i in range(_walkers.get_child_count() - 1, -1, -1):
			var walker := _walkers.get_child(i) as Monster
			if walker != null and not walker.is_queued_for_deletion() \
					and not walker.has_meta(&"targeted"):
				monster = walker
				target = walker.global_position + WaveRunnerScript.CATAPULT_AIM
				break
	_throw(_nearest_turret(turrets, target), monster, target)


## Ein Wurf wie im Kampf (WaveRunner._catapult_later): mit Vorhalt auf `monster`, das beim
## Einschlag platzt, ohne Monster auf `at`. Keine Spur, kein Lernstand — nur das Bild.
func _throw(turret: Node3D, monster: Monster, at: Vector3) -> void:
	var target := at
	if monster != null:
		monster.set_meta(&"targeted", true)
		target = WaveRunnerScript.catapult_lead(turret.global_position, at, monster.velocity())
	var from := await FortressModel.fire(turret, target)
	var stone := CatapultStone.new()
	add_child(stone)
	stone.global_position = from
	await stone.fly(target, from.distance_to(target) * WaveRunnerScript.CATAPULT_LIFT,
			WaveRunnerScript.catapult_flight_time(from, target))
	stone.queue_free()
	var fx := Blast.new()
	if monster != null and is_instance_valid(monster) and not monster.is_queued_for_deletion():
		monster.halt()
		fx.setup(monster.word_color())
		fx.position = monster.position
		for other: Node in _walkers.get_children():
			var walker := other as Monster
			if walker != null and walker != monster and walker.position.distance_to(
					monster.position) <= WaveRunnerScript.BLAST_FLINCH_RADIUS:
				walker.flinch(monster.global_position)
		Sfx.play(&"monster_kill")
		monster.queue_free()
	else:
		fx.setup(Color(0.75, 0.72, 0.66), 0.6)
		fx.position = target - WaveRunnerScript.CATAPULT_AIM
	add_child(fx)


## Das HUD ein- oder ausblenden. Es liegt oben links wie die Regler — die rücken so lange
## nach unten links. Unter den Reglern eingehängt, damit sie bedienbar bleiben.
func _show_hud(on: bool) -> void:
	if on and _hud == null:
		_hud = (load("res://scenes/ui/hud.tscn") as PackedScene).instantiate() as Control
		$UI.add_child(_hud)
		$UI.move_child(_hud, $UI/Margin.get_index())
		_shown_level = int(PlayerLevel.progress()["level"])
		_show_tally.call_deferred()
	if _hud != null:
		_hud.visible = on
	%HudCheck.set_pressed_no_signal(on)
	($UI/Margin/Root as Control).size_flags_vertical = \
			Control.SIZE_SHRINK_END if on else Control.SIZE_FILL


## Die Werte aus dem Reiter HUD: Festung, Welle und Zähler gehen in GameState (nur im
## Speicher, wie beim Bilderlauf --hud), das HUD frischt sich selbst auf — so gelten seine
## Farbschwellen und Regeln. Nur Meisterungen (Sitzung) und XP-Ring (Profil) setzt die
## Werkbank direkt, statt Sitzung und Erfahrung anzufassen.
func _show_tally() -> void:
	_show_hud(true)
	GameState.fortress_max_health = maxi(1, int(%HpMaxSpin.value))
	GameState.fortress_health = mini(int(%HpSpin.value), GameState.fortress_max_health)
	GameState.fortress_armor_max = int(%ArmorMaxSpin.value)
	GameState.fortress_armor = mini(int(%ArmorSpin.value), GameState.fortress_armor_max)
	GameState.monsters_defeated = int(%KillsSpin.value)
	GameState.wave_number = int(%WaveNumberSpin.value)
	GameState.wave_total = int(%WaveTotalSpin.value)
	GameState.wave_resolved = mini(int(%WaveResolvedSpin.value), GameState.wave_total)
	_hud.call("_refresh")
	var mastered := int(%MasteredSpin.value)
	(_hud.get_node("%Book") as Control).visible = mastered > 0
	(_hud.get_node("%Mastered") as Control).visible = mastered > 0
	(_hud.get_node("%Mastered") as Label).text = "%d gemeistert" % mastered
	(_hud.get_node("%XpRing") as XpRing).ratio = %XpSpin.value / 100.0


## Ein Aufstieg, wie ihn das HUD auf PlayerLevel.leveled_up zeigt — aber ohne Erfahrung zu
## verbuchen: Zahl und Ring werden nur im HUD gesetzt.
func _level_up() -> void:
	_show_hud(true)
	_shown_level += 1
	(_hud.get_node("%LevelText") as Label).text = str(_shown_level)
	%XpSpin.value = 5
	(_hud.get("level_flare") as LevelFlare).play()


func _shoot_level_up() -> void:
	var dir := ProjectSettings.globalize_path(SHOT_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	_show_hud(true)
	await get_tree().create_timer(0.3).timeout
	for ms in [0, 60, 150, 300, 500, 800, 1200]:
		_level_up()
		if ms > 0:
			await get_tree().create_timer(ms / 1000.0).timeout
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var path := "%s/levelup_%d.png" % [dir, ms]
		image.get_region(Rect2i(0, 0, 320, 200)).save_png(path)
		print("battle_theme_lab: ", path)
		await get_tree().create_timer(1.5).timeout
	get_tree().quit()


func _shoot_blast() -> void:
	var dir := ProjectSettings.globalize_path(SHOT_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	var view := (load("res://scenes/battle/first_person_view.tscn") as PackedScene).instantiate() as FirstPersonView
	view.position = Vector3(0.0, 0.0, _goal() - 2.0)
	add_child(view)
	var at := Vector3(1.0, 0.0, _goal() - 14.0)
	var types := WordTypePalette.COLORS.keys()
	var neighbours: Array[Monster] = []
	for x: float in [-3.5, 4.5]:
		var monster := FxWarmup.MONSTER_SCENE.instantiate() as Monster
		monster.setup(FxWarmup.monster_defs()[0], {"prompt": "house",
				"lexeme_type": types.pick_random()}, 1000.0, 0.0)
		monster.screen_sized_label = true
		monster.position = at + Vector3(x, 0.0, -1.0)
		add_child(monster)
		monster.halt()
		neighbours.append(monster)
	await FxWarmup.run(self, view.camera.global_position - view.camera.global_basis.z * 6.0,
			[], [Blast.new()])
	await get_tree().create_timer(1.0).timeout
	for ms: int in [40, 120, 250, 450, 800, 1300, 2000]:
		var fx := Blast.new()
		fx.setup(WordTypePalette.color_for(str(types[0])))
		fx.position = at
		add_child(fx)
		for monster in neighbours:
			monster.flinch(at)
		await get_tree().create_timer(ms / 1000.0).timeout
		await RenderingServer.frame_post_draw
		var path := "%s/blast_%04d.png" % [dir, ms]
		get_viewport().get_texture().get_image().save_png(path)
		print("battle_theme_lab: ", path)
		fx.queue_free()
		await get_tree().create_timer(0.8).timeout
	get_tree().quit()


func _shoot_spelling() -> void:
	var dir := ProjectSettings.globalize_path(SHOT_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	var freeze := (load("res://scenes/ui/spelling_freeze.tscn") as PackedScene).instantiate() as SpellingFreeze
	$UI.add_child(freeze)
	# Wie im Kampf: das Standbild hält den Baum an, die Explosion steht.
	freeze.started.connect(func(_ms: int) -> void: get_tree().paused = true)
	freeze.finished.connect(func() -> void: get_tree().paused = false)
	# [Ich-Sicht, richtig, getippt, Name]
	var shots := [[false, "l'élève", "l eleve", "iso"], [true, "l'élève", "l eleve", "first"],
			[false, "die Meinung (zu etwas)", "meinung zu", "missing"]]
	for shot: Array in shots:
		var first: bool = shot[0]
		var word: String = shot[1]
		_set_first_person(first)
		await get_tree().create_timer(0.6).timeout
		var camera := _fp.camera if _fp != null else _camera
		var at := Vector3(2.0, 0.0, _goal() - 12.0)
		var fx := Blast.new()
		fx.setup(WordTypePalette.color_for("noun"))
		fx.position = at
		add_child(fx)
		freeze.play(word, AnswerEvaluator.spelling_marks(word, shot[2]),
				WaveRunnerScript.spelling_zoom(camera, at + Vector3(0.0, 1.0, 0.0)),
				AnswerEvaluator.missing_marks(word, shot[2]))
		await get_tree().create_timer(
				(SpellingFreeze.LEAD_MS + SpellingFreeze.ZOOM_IN_MS + 300) / 1000.0, true, false, true).timeout
		await RenderingServer.frame_post_draw
		var path := "%s/spelling_%s.png" % [dir, shot[3]]
		get_viewport().get_texture().get_image().save_png(path)
		print("battle_theme_lab: ", path)
		await freeze.finished
		fx.queue_free()
	get_tree().quit()


func _shoot_bow() -> void:
	var dir := ProjectSettings.globalize_path(SHOT_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	var view := (load("res://scenes/battle/first_person_view.tscn") as PackedScene).instantiate() as FirstPersonView
	view.position = Vector3(0.0, 0.0, _goal() - 2.0)
	add_child(view)
	# Beide Waffen gelernt, damit die Eingabe auch Tab nennt; der Bogen ist gewählt.
	view.weapons = FirstPersonView.weapons_for({"bow": 1.0, "charge": 1.0})
	view.weapon = FirstPersonView.Weapon.BOW
	# Eine echte Eingabe der Ich-Sicht: gehoben wird der Bogen nur, solange sie offen ist.
	var input := (load("res://scenes/ui/answer_input.tscn") as PackedScene).instantiate() as LineEdit
	$UI.add_child(input)
	input.set("first_person", true)
	input.set("weapon_switch", true)
	view.answer_input = input
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	var monster := FxWarmup.MONSTER_SCENE.instantiate() as Monster
	monster.setup(FxWarmup.monster_defs()[0], {"prompt": "house"}, 1000.0, 0.0)
	monster.screen_sized_label = true
	monster.position = Vector3(2.0, 0.0, _goal() - 16.0)
	add_child(monster)
	monster.halt()
	var target := monster.global_position + Vector3(0.0, 1.2, 0.0)
	var head := monster.global_position + Vector3(0.0, monster.head_height(), 0.0)
	print("battle_theme_lab: Kopfhöhe ", monster.head_height())
	var shot := func(step: String) -> void:
		await RenderingServer.frame_post_draw
		var path := "%s/bow_%s.png" % [dir, step]
		get_viewport().get_texture().get_image().save_png(path)
		print("battle_theme_lab: ", path)
		# Das Speichern dauert: ohne diese Bilder ginge die Zeit dafür im nächsten Schritt
		# als ein großes delta auf, und Schwenk oder Flug wären schon vorbei.
		await get_tree().process_frame
		await get_tree().process_frame
	# Wie im Kampf: sonst übersetzt die Spur ihren Shader erst im ersten Flug, und das Bild
	# stünde genau dann.
	var warm := Arrow.new()
	warm.trail = true
	var fx_at := view.camera.global_position - view.camera.global_basis.z * 6.0
	await FxWarmup.run(self, fx_at, [], [warm])
	await get_tree().create_timer(1.2).timeout
	await shot.call("lowered")
	input.call("_input", enter)
	for i in 5:
		await get_tree().create_timer(0.08).timeout
		EventBus.typing_activity.emit()
	await get_tree().create_timer(0.4).timeout
	await shot.call("drawn")
	# Ein Bild zu speichern dauert länger als ein Flug: Schwenk und Flug aus zwei Schüssen.
	view.shoot_at(head)
	input.text_submitted.emit("")
	await get_tree().create_timer(0.03).timeout
	await shot.call("swing")
	await get_tree().create_timer(0.8).timeout
	input.call("_input", enter)
	for i in 5:
		EventBus.typing_activity.emit()
	await get_tree().create_timer(0.4).timeout
	view.shoot_at(head)
	input.text_submitted.emit("")
	await get_tree().create_timer(0.12).timeout
	await shot.call("flight")
	await get_tree().create_timer(0.8).timeout
	input.call("_input", enter)
	EventBus.typing_activity.emit()
	await get_tree().create_timer(0.4).timeout
	view.shoot_past(target)
	input.text_submitted.emit("")
	await get_tree().create_timer(0.15).timeout
	await shot.call("miss")
	await get_tree().create_timer(0.6).timeout
	await shot.call("stuck")
	get_tree().quit()


## Zutaten, die --fps einzeln abschaltet, mit ihrem Namen in der Ausgabe.
const FPS_PARTS := {"msaa": "MSAA", "clouds": "Wolken", "particles": "Teilchen",
		"wind": "Wind", "shadows": "Schatten", "glow": "Glow", "grade": "Farbgebung",
		"ground": "Weg+Flecken", "cover": "Bewuchs"}


func _measure_fps() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	if not _has_arg("windowed"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	await get_tree().create_timer(1.0).timeout
	var all_on := {}
	for part: String in FPS_PARTS:
		all_on[part] = true
	var runs: Array = [["alles an", all_on]]
	for part: String in FPS_PARTS:
		var cfg := all_on.duplicate()
		cfg[part] = false
		runs.append(["ohne " + FPS_PARTS[part], cfg])
	var all_off := {}
	for part: String in FPS_PARTS:
		all_off[part] = false
	runs.append(["alles aus", all_off])
	print("fps: %s, %s" % [_names[_index], get_viewport().get_visible_rect().size])
	var base := 0.0
	for run: Array in runs:
		_apply_parts(run[1])
		var ms := await _mean_frame_ms(3.0)
		if base == 0.0:
			base = ms
		print("fps: %-14s %6.2f ms  %5.0f fps  %+5.1f %%" % [run[0], ms, 1000.0 / ms,
				(ms - base) / base * 100.0])
	get_tree().quit()


func _apply_parts(cfg: Dictionary) -> void:
	get_viewport().msaa_3d = Viewport.MSAA_4X if cfg.msaa else Viewport.MSAA_DISABLED
	(_ground.material_override as ShaderMaterial).set_shader_parameter("clouds",
			_theme.clouds if cfg.clouds else 0.0)
	for p: CPUParticles3D in [_air, _petals]:
		if p != null:
			p.emitting = cfg.particles
			p.visible = cfg.particles
	if _weeds != null:
		_weeds.visible = cfg.particles
	_wind_strength = _theme.wind if cfg.wind else 0.0
	_cover_density = GraphicsQuality.cover(_quality) if cfg.cover else 0.0
	_build_decor(_noise, _theme)
	_sun.shadow_enabled = cfg.shadows
	_world.environment.glow_enabled = cfg.glow
	_world.environment.tonemap_mode = _scene_env.tonemap_mode if cfg.grade else Environment.TONE_MAPPER_LINEAR
	_world.environment.adjustment_enabled = _scene_env.adjustment_enabled and cfg.grade
	var ground := _ground.material_override as ShaderMaterial
	ground.set_shader_parameter("patch_amount", _theme.ground_patch_amount if cfg.ground else 0.0)
	ground.set_shader_parameter("path_kind", BattlePath.KINDS.keys().find(_path.kind) if cfg.ground else -1)


## Mittlere Bildzeit über `seconds`, nach einer Sekunde Anlauf (Shader, neue Deko).
func _mean_frame_ms(seconds: float) -> float:
	await get_tree().create_timer(1.0).timeout
	var frames := 0
	var t0 := Time.get_ticks_usec()
	while Time.get_ticks_usec() - t0 < seconds * 1000000.0:
		await get_tree().process_frame
		frames += 1
	return (Time.get_ticks_usec() - t0) / 1000.0 / maxi(frames, 1)


func _measure_hitches() -> void:
	var celebration := CELEBRATION_SCENE.instantiate() as MasteryCelebration
	$UI.add_child(celebration)
	var at := Vector3(0.0, 1.0, _view_z - _shift())
	var baseline := await _worst_frame(func() -> void: pass, 60)
	print("hitches: Grundrauschen %.1f ms" % baseline)
	if _has_arg("warm"):
		var t0 := Time.get_ticks_usec()
		celebration.warm_up()
		await FxWarmup.run(self, at, FxWarmup.monster_defs(),
				[WaveRunnerScript.xp_label(FxWarmup.GLYPHS), Blast.new()])
		celebration.cool_down()
		print("hitches: Vorwärmen %.1f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
		await _worst_frame(func() -> void: pass, 60)
	var effects := {
		"Explosion": func() -> void:
			var fx := Explosion.new()
			fx.setup(Color(0.7, 1.0, 0.4), 1.5)
			fx.position = at
			add_child(fx),
		"Blast": func() -> void:
			var fx := Blast.new()
			fx.setup(Color(0.7, 1.0, 0.4))
			fx.position = at - Vector3(0.0, 1.0, 0.0)
			add_child(fx),
		"+XP": func() -> void:
			var label := WaveRunnerScript.xp_label("+12 XP")
			label.position = at + Vector3(4.0, 1.0, 0.0)
			add_child(label),
		"Monster": func() -> void:
			var monster := FxWarmup.MONSTER_SCENE.instantiate() as Monster
			monster.setup(FxWarmup.monster_defs()[0], {"prompt": "house"}, 1000.0, 0.0)
			monster.position = at + Vector3(-4.0, 0.0, 0.0)
			add_child(monster),
		"Wort-Feier": func() -> void:
			celebration.celebrate(MasteryCelebration.Kind.WORD, ""),
	}
	for effect_name: String in effects:
		print("hitches: %s %.1f ms" % [effect_name, await _worst_frame(effects[effect_name], 20)])
	get_tree().quit()


## Löst `effect` aus und gibt den längsten der folgenden `count` Frames in ms zurück.
func _worst_frame(effect: Callable, count: int) -> float:
	await get_tree().process_frame
	effect.call()
	var worst := 0.0
	var last := Time.get_ticks_usec()
	for i in count:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		worst = maxf(worst, (now - last) / 1000.0)
		last = now
	return worst


## Das Environment der Kampfszene — gelesen, nicht nachgebaut, damit die Werkbank nicht
## still von der Szene abweicht.
func _battle_environment() -> Environment:
	var state := (load(BATTLE_SCENE) as PackedScene).get_state()
	for i in state.get_node_count():
		if state.get_node_type(i) != &"WorldEnvironment":
			continue
		for p in state.get_node_property_count(i):
			if state.get_node_property_name(i, p) == &"environment":
				return state.get_node_property_value(i, p) as Environment
	return Environment.new()


## Deko wie im Kampf, vereinfacht: Bäume und Felsen im Umland und an den Seitenstreifen,
## Gras auf dem Feld, die Burg an der Front.
func _build_decor(noise: FastNoiseLite, theme: BattleTheme) -> void:
	_fire_lights = GraphicsQuality.fire_lights(_quality)
	if _decor != null:
		_decor.free()
	_decor = Node3D.new()
	add_child(_decor)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	_tree_feet.clear()
	_leaf_crowns.clear()
	_blossom_crowns.clear()
	var area := WaveRunnerScript.visible_ground_area(_camera)
	var half_x := 11.0 * _grow()   # WaveRunner.FIELD_HALF_X
	var z_front := _goal() + 11.0 * _grow()   # WaveRunner.FIELD_Z_FRONT
	var outside := func(x: float, z: float) -> bool:
		var on_field := absf(x) < half_x and z > WaveRunnerScript.FIELD_Z_BACK and z < z_front
		return not on_field and WaveRunnerScript.tile_on_screen(_camera, x, z)
	# Wie im Kampf (_decorate_outskirts): Bäume meist in Hainen, ein paar einzeln.
	for i in 60:
		var x := rng.randf_range(area.position.x, area.end.x)
		var z := rng.randf_range(area.position.y, area.end.y)
		if not outside.call(x, z):
			continue
		if i % 15 == 1:
			_place_from(theme, "landmarks", x, z, noise, rng)
		elif i % 2 == 0:
			_place_from(theme, "rocks", x, z, noise, rng)
		elif i % 3 == 0:
			_place_from(theme, "trees", x, z, noise, rng)
		else:
			for k in rng.randi_range(3, 6):
				var p := Vector2(x, z) + Vector2.from_angle(rng.randf_range(0.0, TAU)) \
						* rng.randf_range(0.0, WaveRunnerScript.GROVE_RADIUS)
				if outside.call(p.x, p.y):
					_place_from(theme, "trees", p.x, p.y, noise, rng)
	for i in 28:
		var x := rng.randf_range(-11.0, 11.0)
		var z := rng.randf_range(WaveRunnerScript.SPAWN_Z, _goal() - 2.0)
		_place_from(theme, "grass" if i % 4 != 0 else "rocks", x, z, noise, rng)
	for i in 12:
		var x := (1.0 if i % 2 == 0 else -1.0) * rng.randf_range(9.5, 12.5)
		# Wie im Kampf (_decorate): Abstand zu den Ecktürmen, der mit der Festung wächst.
		var z := rng.randf_range(WaveRunnerScript.SPAWN_Z,
				_goal() - 3.0 * _grow())
		_place_from(theme, "landmarks" if i == 5 else "props" if i % 4 == 0 else "trees", x, z, noise, rng)
	# Die Festung, wie sie im Kampf steht (FortressModel), in der gewählten Stufe.
	FortressModel.build(_decor, _tier, _goal(),
			func(x: float, z: float) -> float: return WaveRunnerScript.terrain_height(x, z, noise),
			_fortress_scale, theme.fortress_wear)
	var site := GroundCover.Site.new()
	site.area = area
	site.on_screen = func(x: float, z: float) -> bool: return WaveRunnerScript.tile_on_screen(_camera, x, z)
	site.height = func(x: float, z: float) -> float: return WaveRunnerScript.terrain_height(x, z, noise)
	site.t_at = func(x: float, z: float) -> float: return BattleTheme.ground_t(noise, x, z)
	site.path = _path
	site.keep_out = Rect2(-half_x, _goal() - 0.5, 2.0 * half_x, z_front - _goal() + 0.5)
	site.trees = _tree_feet
	GroundCover.grow(_decor, theme, site, _cover_density, rng, _tuning)
	_count_cover()
	if _has_arg("monsters"):
		_place_monsters()


## Zum Größenvergleich: drei Monster kurz vor der Mauer und eines weiter vorn auf der Bahn.
func _place_monsters() -> void:
	var defs := FxWarmup.monster_defs()
	var spots := [Vector3(-4.0, 0.0, _goal() - 1.5), Vector3(0.5, 0.0, _goal() - 2.0),
			Vector3(4.5, 0.0, _goal() - 1.5), Vector3(-1.0, 0.0, _goal() - 10.0)]
	for i in spots.size():
		var monster := FxWarmup.MONSTER_SCENE.instantiate() as Monster
		monster.setup(defs[i % defs.size()], {"prompt": "house"}, 1000.0, 0.0)
		monster.position = spots[i]
		_decor.add_child(monster)
		monster.halt()


## Eines der Modelle des Platzes `slot` im Thema, in der Größe des Platzes.
func _place_from(theme: BattleTheme, slot: String, x: float, z: float, noise: FastNoiseLite,
		rng: RandomNumberGenerator) -> void:
	var models: Array[String] = theme.get(slot)
	if models.is_empty() or _path.blocks(x, z, 0.4 * float(SLOT_SCALE[slot][1])):
		return
	var model := models[rng.randi() % models.size()]
	var span: Array = SLOT_SCALE[slot]
	var inst := _place(model, x, z, noise, rng.randf_range(0.0, 360.0), rng.randf_range(span[0], span[1]))
	if slot == "trees":
		_tree_feet.append(Vector3(x, WaveRunnerScript.terrain_height(x, z, noise), z))
		if inst != null and AmbientParticles.LEAF_TREES.has(model.get_file().get_basename()):
			_leaf_crowns.append(AmbientParticles.crown_of(inst))
		elif inst != null and AmbientParticles.BLOSSOM_TREES.has(model.get_file().get_basename()):
			_blossom_crowns.append(AmbientParticles.crown_of(inst))


## Nahaufnahme: die gekauften Vergleichsstücke und die Deko des Themas in einer Reihe, jedes
## in der mittleren Größe seines Platzes, auf flachem Boden, schräg von vorn wie im Kampf.
func _shoot_specimens() -> void:
	var dir := ProjectSettings.globalize_path(SHOT_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	for i in _names.size():
		_show(i)
		var theme := BattleTheme.named(_names[i])
		_decor.free()
		_decor = Node3D.new()
		add_child(_decor)
		_fire_lights = GraphicsQuality.fire_lights(_quality)
		var row: Array = REFERENCE.duplicate()
		for slot: String in SLOT_SCALE:
			for model: String in theme.get(slot):
				if not model.begins_with("props/") and not row.any(func(r: Array) -> bool: return r[0] == model):
					row.append([model, slot])
		# Die Reihe läuft entlang der Bildwaagerechten, mitten im flachen Feld.
		var center := Vector3(0.0, 0.0, -9.0)
		var right := _camera.global_transform.basis.x
		right = Vector3(right.x, 0.0, right.z).normalized()
		var spacing := 3.4
		var noise := WaveRunnerScript.terrain_noise(SEED)
		for k in row.size():
			var p := center + right * (spacing * (k - (row.size() - 1) * 0.5))
			var span: Array = SLOT_SCALE[row[k][1]]
			_place(row[k][0], p.x, p.z, noise, 20.0, (span[0] + span[1]) * 0.5)
		_pivot.position = center + Vector3(0.0, 1.5, 0.0)
		var view_size := _camera.size
		_camera.size = maxf(15.0, spacing * row.size() * 0.62)
		_label.text = "Vergleich: %s" % _names[i]
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var path := "%s/specimens_%s.png" % [dir, _names[i]]
		get_viewport().get_texture().get_image().save_png(path)
		print("battle_theme_lab: ", path)
		_camera.size = view_size
		_pivot.position = Vector3(0.0, 0.0, _view_z - _shift())
	get_tree().quit()


## Wie viele Feuer der Deko noch ein Licht bekommen, wie im Kampf.
var _fire_lights := 0


## `model` ist ein Pfad unter assets/models/, wie in BattleTheme.
func _place(model: String, x: float, z: float, noise: FastNoiseLite, yaw: float, scale: float) -> Node3D:
	var path := "%s/%s" % [BattleTheme.MODEL_DIR, model]
	if not ResourceLoader.exists(path):
		return null
	var inst := (load(path) as PackedScene).instantiate() as Node3D
	inst.position = Vector3(x, WaveRunnerScript.terrain_height(x, z, noise), z)
	inst.rotation_degrees.y = yaw
	inst.scale = Vector3.ONE * scale
	_decor.add_child(inst)
	Wind.sway(inst, model, _wind_strength)
	_fire_lights -= Fire.kindle(inst, _fire_lights)
	return inst


## Reiter Zauber: SpellFx wie im Kampf, die Zauber aus der Registry.
func _setup_spells() -> void:
	_spell_fx = SpellFx.new()
	_spell_fx.veil = $UI/SpellVeil as ColorRect
	_spell_fx.shake = _shake
	add_child(_spell_fx)
	_caster.reveal_delay = _spell_fx.reveal_delay
	_caster.strike = func(monster: Monster) -> void:
		monster.set_meta(&"struck", true)
		monster.halt()
		_spell_fx.bolt(monster, _strike_index, func() -> void:
			if is_instance_valid(monster):
				monster.queue_free())
		_strike_index += 1
	_spell_list = ContentRegistry.all("spells")
	for spell: Dictionary in _spell_list:
		%CastSelect.add_item(str(spell.get("name", spell.get("id", ""))))
	%CastButton.pressed.connect(func() -> void:
		if not _spell_list.is_empty():
			_cast_spell(_spell_list[%CastSelect.selected], %ShortFrostCheck.button_pressed))
	%FillFieldButton.pressed.connect(_fill_field)
	%ClearFieldButton.pressed.connect(_clear_field)


## Wirkt `spell` auf alle Monster, die laufen, wie WaveRunner._use_spell — ohne Vorrat und
## ohne Spur. Ein leeres Feld wird erst gefüllt. `short_frost`: Frost taut nach 3 s.
func _cast_spell(spell: Dictionary, short_frost := false) -> void:
	var effect := str(spell.get("effect", ""))
	if short_frost and effect == "freeze":
		spell = spell.duplicate(true)
		(spell["params"] as Dictionary)["duration"] = 3.0
	# Etwas zum Auffüllen, nur im Speicher (wie die Felder im Reiter HUD).
	if effect == "heal":
		GameState.fortress_health = maxi(1, GameState.fortress_max_health - 40)
	elif effect == "armor":
		GameState.fortress_armor_max = maxi(GameState.fortress_armor_max, 50)
		GameState.fortress_armor = 10
	if _field().is_empty() and effect in ["reveal_alts", "slow", "freeze", "strike"]:
		_fill_field()
	_spell_fx.front_z = _goal()
	_spell_fx.back_z = _spawn_z
	_spell_fx.half_width = _lane_half
	_spell_fx.fortress = Vector3(0.0, 0.0, _goal() + 2.0 * WaveRunnerScript.FORTRESS_GROW)
	var field := _field()
	($UI/SpellBanner as SpellBanner).play(spell)
	_spell_fx.play(spell, field)
	_strike_index = 0
	# Die Werkbank läuft wie eine Welle ohne Ende: es kommt immer noch etwas, „für die ganze
	# Welle" gilt also auch für die, die noch erscheinen — bis „Feld leeren".
	_caster.cast(spell, field, 1)
	if _hud != null:
		_show_tally()


## Die Monster, die noch laufen: nicht freigegeben, nicht vom Donnerschlag getroffen.
func _field() -> Array[Monster]:
	var out: Array[Monster] = []
	if _walkers == null:
		return out
	for node in _walkers.get_children():
		var monster := node as Monster
		if monster != null and not monster.is_queued_for_deletion() \
				and not monster.has_meta(&"struck"):
			out.append(monster)
	return out


## Sechs Monster verteilt über die Bahn, vorne dichter.
func _fill_field() -> void:
	var spots := [[-5.0, 0.15], [1.5, 0.25], [-1.5, 0.42], [4.5, 0.5], [-4.0, 0.7], [2.5, 0.85]]
	for spot: Array in spots:
		var z := lerpf(_goal() - 5.0, _spawn_z + 4.0, float(spot[1]))
		_walker_at(Vector3(float(spot[0]) * _lane_half / 8.0, 0.0, z))


func _clear_field() -> void:
	if _walkers != null:
		for node in _walkers.get_children():
			node.queue_free()
	_spell_fx.haze(false)
	_caster.reset_wave()


## Kamerawackeln wie im Kampf, nur kurz über den Versatz der Kamera, die gerade zeigt.
func _shake(magnitude: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var tw := create_tween()
	for i in 6:
		var k := magnitude * (1.0 - i / 6.0)
		tw.tween_property(cam, "h_offset", randf_range(-k, k), 0.05)
		tw.parallel().tween_property(cam, "v_offset", randf_range(-k, k), 0.05)
	tw.tween_property(cam, "h_offset", 0.0, 0.05)
	tw.parallel().tween_property(cam, "v_offset", 0.0, 0.05)


## Bildlauf --spells: jeder Zauber in Schritten nach dem Wirken, jeder Schritt ein eigener
## Zauber auf ein frisches Feld.
const SPELL_SHOTS := [150, 450, 1000]
const FROST_THAW_SHOTS := [2300, 3080]
## Schwere Luft: der Nebel, wenn er ganz da ist.
const HAZE_SHOTS := [3000, 4500]

func _shoot_spells() -> void:
	var dir := ProjectSettings.globalize_path(SHOT_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	$UI/Margin.visible = false
	var at := Vector3(0.0, 1.0, _goal() - 10.0)
	await FxWarmup.run(self, at, FxWarmup.monster_defs(), SpellFx.specimens(at),
			_fp != null)
	var only := _arg("spell")
	for spell: Dictionary in _spell_list:
		var name := str(spell.get("id", "")).trim_prefix("spell.")
		if only != "" and name != only:
			continue
		var steps: Array = SPELL_SHOTS.duplicate()
		if str(spell.get("effect", "")) == "freeze":
			steps.append_array(FROST_THAW_SHOTS)
		if str((spell.get("params", {}) as Dictionary).get("scope", "")) == "wave" \
				and str(spell.get("effect", "")) == "slow":
			steps.append_array(HAZE_SHOTS)
		for ms: int in steps:
			_clear_field()
			await get_tree().create_timer(0.2).timeout
			_fill_field()
			# Die Schilder gleiten an ihren Platz.
			await get_tree().create_timer(0.6).timeout
			_cast_spell(spell, true)
			await get_tree().create_timer(ms / 1000.0).timeout
			await RenderingServer.frame_post_draw
			var path := "%s/spell_%s_%04d.png" % [dir, name, ms]
			get_viewport().get_texture().get_image().save_png(path)
			print("battle_theme_lab: ", path)
			# Der Zauber zu Ende, bevor der nächste anfängt.
			await get_tree().create_timer(1.5).timeout
	get_tree().quit()


func _has_arg(key: String) -> bool:
	return OS.get_cmdline_user_args().has("--" + key)


func _arg(key: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % key):
			return a.get_slice("=", 1)
	return ""
