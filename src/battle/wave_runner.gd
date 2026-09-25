extends Node3D
## Fährt eine einzelne Welle in 3D: spawnt Monster aus der Wave-Definition, gleicht
## Spielerantworten gegen aktive Monster ab und erkennt das Wellenende.
## Nutzt ausschließlich bestehende Autoloads + AnswerEvaluator — rein additiv.

const MONSTER_SCENE := preload("res://scenes/entities/monster.tscn")
const MENU_SCENE := "res://scenes/ui/profile_menu.tscn"
const GOAL_Z := 6.5           # Festungsfront (Monster-Ziel)
const SPAWN_Z := -24.0        # Spawn am hinteren Ende der Bahn (längerer Anmarsch)
const LANE_HALF_WIDTH := 7.0
## Bildmitte auf der Bahn (z). Der Boden richtet sich danach, nicht umgekehrt.
const VIEW_CENTER_Z := -5.5

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

var _cam_base: Vector3
var _shake_left: float = 0.0
var _shake_mag: float = SHAKE_MAGNITUDE
var _rng := RandomNumberGenerator.new()

var _fortress: Node3D = null
## Festungsstufe DES LAUFS: die schwächste Unit im gespielten Bereich (FortressTier.run_tier).
## Das Debug-Panel baut nur das Bild um und fasst diesen Wert nicht an.
var _fortress_tier: int = -1
var _cutscene: bool = false   # läuft gerade die Ausbau-Cutscene? (unterdrückt Kamera-Wackeln)

@onready var _monsters: Node3D = $Monsters
@onready var _camera: Camera3D = $CameraPivot/Camera3D
@onready var _end_label: Label = $UI/EndLabel
@onready var _flash: ColorRect = $UI/Flash
@onready var _stats: PanelContainer = $UI/WaveStats
@onready var _leak_reveal: Control = $UI/LeakReveal
@onready var _answer_input: LineEdit = $UI/AnswerInput
@onready var _slow_motion: SlowMotion = $SlowMotion
@onready var _fast_resolve_button: Button = $UI/FastResolveButton
@onready var _fast_resolve_confirm: ConfirmDialog = $UI/FastResolveConfirm
@onready var _celebration: MasteryCelebration = $UI/MasteryCelebration


func _ready() -> void:
	_rng.randomize()
	_setup_view()
	_setup_ground()
	_decorate()
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
	Hints.attach(_fast_resolve_button, "Schnell auflösen",
			"Spult den Rest der Welle vor, wenn du die Wörter gerade nicht weißt.",
			"Die Monster treffen die Festung trotzdem, danach werden ihre Wörter aufgelöst.")
	# Startschwierigkeit aus den persistenten Einstellungen des aktiven Profils.
	_difficulty = UserSettings.default_difficulty()
	_start_next_wave()


## Prozedurales Low-Poly-Terrain: flaches Innenfeld (Spielfläche/Props/Festung),
## sanfte facettierte Hügel am Rand, dezente Grün-Variation je Facette. Flat-Shading
## über manuell gesetzte Face-Normalen — passt zum Stil von Burg/Skeletten.
##
## Der Boden reicht bis an den BILDRAND und nicht nur bis an das Spielfeld: eine grüne
## Insel vor der Hintergrundfarbe sieht aus, als schwebte sie. Wie weit das ist, wird
## aus der Kamera gerechnet (`visible_ground_area`) und steht nicht als zweite
## Konstante daneben — sonst hinkt das Terrain jeder Änderung an Zoom oder Blickwinkel
## hinterher. Gespielt wird davon nichts: die Bahn bleibt SPAWN_Z..GOAL_Z bei
## ±LANE_HALF_WIDTH, und das Innenfeld bleibt flach (siehe terrain_height).
const TERRAIN_STEP := 3.0
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

func _setup_ground() -> void:
	_terrain_noise = terrain_noise(_rng.randi())
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var ground := $Ground as MeshInstance3D
	ground.mesh = build_terrain(_camera, _terrain_noise)
	ground.material_override = mat


## Das Rauschen des Terrains — EINE Stelle, damit Boden und Streudeko dieselben Hügel
## sehen und ein Test dieselben bauen kann wie das Spiel.
static func terrain_noise(seed_value: int) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.06
	return noise


## Baut den sichtbaren Boden für DIESE Kamera. Statisch und ohne Szene, damit
## `tests/battle_ground_test.gd` genau das Mesh prüfen kann, das im Spiel steht.
static func build_terrain(camera: Camera3D, noise: FastNoiseLite) -> ArrayMesh:
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
				_add_terrain_tri(st, noise, a, b, c)
				_add_terrain_tri(st, noise, a, c, d)
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


static func terrain_height(x: float, z: float, noise: FastNoiseLite) -> float:
	# Innenfeld flach halten (bis knapp hinter den Spawn); nur außerhalb sanfte Hügel.
	var edge := maxf(absf(x) - 9.0, -z + SPAWN_Z)
	if edge <= 0.0:
		return 0.0
	var n := noise.get_noise_2d(x, z) * 0.5 + 0.5
	return clampf(edge, 0.0, TERRAIN_EDGE_MAX) * (0.3 + 0.7 * n) * TERRAIN_HEIGHT_SCALE


static func _add_terrain_tri(st: SurfaceTool, noise: FastNoiseLite, a: Vector3, b: Vector3, c: Vector3) -> void:
	var n := (b - a).cross(c - a).normalized()
	if n.y < 0.0:
		n = -n
	# EINE Farbe pro Dreieck (aus dem Zentrum) -> echte flache Low-Poly-Facetten.
	var col := _terrain_color((a + b + c) / 3.0, noise)
	for v in [a, b, c]:
		st.set_color(col)
		st.set_normal(n)
		st.add_vertex(v)


static func _terrain_color(center: Vector3, noise: FastNoiseLite) -> Color:
	var t := noise.get_noise_2d(center.x * 2.3 + 100.0, center.z * 2.3) * 0.5 + 0.5
	var col := Color(0.22, 0.34, 0.15).lerp(Color(0.42, 0.56, 0.28), t)
	if center.y > 0.4:
		col = col.lerp(Color(0.44, 0.44, 0.30), clampf(center.y / 3.0, 0.0, 0.55))
	return col


## Bodenhöhe des Terrains an (x,z) — damit Streudeko auf den Hügeln aufsitzt.
func _ground_y(x: float, z: float) -> float:
	return terrain_height(x, z, _terrain_noise) if _terrain_noise != null else 0.0


## Platziert ein Modell (filename inkl. Endung) auf Terrain-Höhe mit zufälliger
## Drehung; Position/Skalierung kommen vom Aufrufer.
func _scatter(parent: Node3D, filename: String, x: float, z: float, scale: float) -> void:
	_place_model(parent, filename, Vector3(x, _ground_y(x, z), z), _rng.randf_range(0.0, 360.0), Vector3.ONE * scale)


## Randomisierte Streudekoration (jeder Start anders): Bäume an den Seitenstreifen
## (halten den Lauf-Korridor frei), Steine/Grasbüschel übers Feld, ein paar
## Requisiten und Fackelsäulen. Alles hinter der Festung (z < 5). Fortress bleibt fix.
func _decorate() -> void:
	var d := Node3D.new()
	d.name = "Decor"
	add_child(d)

	var z_back := SPAWN_Z - 2.0    # bis knapp hinter den Spawn
	var z_front := GOAL_Z - 2.0    # bis kurz vor die Festung

	# Bäume nur an den Seitenstreifen (|x| groß), damit die Bahn frei bleibt
	for i in _rng.randi_range(8, 14):
		var sx := (1.0 if _rng.randf() < 0.5 else -1.0) * _rng.randf_range(9.5, 12.5)
		_scatter(d, "tree.glb", sx, _rng.randf_range(z_back, z_front), _rng.randf_range(0.85, 1.2))

	# Steine über das Feld verteilt
	for i in _rng.randi_range(5, 10):
		_scatter(d, "rock.glb", _rng.randf_range(-10.0, 10.0), _rng.randf_range(z_back, z_front), _rng.randf_range(1.6, 2.6))

	# Grasbüschel
	for i in _rng.randi_range(22, 34):
		_scatter(d, "grass.glb", _rng.randf_range(-11.0, 11.0), _rng.randf_range(z_back, z_front + 0.5), _rng.randf_range(1.2, 2.0))

	# Fässer/Kisten an den Rändern
	for i in _rng.randi_range(3, 6):
		var bx := (1.0 if _rng.randf() < 0.5 else -1.0) * _rng.randf_range(8.5, 10.5)
		var kind := "barrel_large.gltf" if _rng.randf() < 0.5 else "crates_stacked.gltf"
		_scatter(d, kind, bx, _rng.randf_range(SPAWN_Z + 4.0, GOAL_Z - 3.0), 1.0)

	# Zwei Fackelsäulen am hinteren Rand (Spawn-Seite)
	for side: float in [-1.0, 1.0]:
		var px := side * _rng.randf_range(9.5, 11.5)
		var pz := _rng.randf_range(SPAWN_Z + 1.0, SPAWN_Z + 5.0)
		var gy := _ground_y(px, pz)
		_place_model(d, "pillar.gltf", Vector3(px, gy, pz), 0.0, Vector3.ONE)
		_place_model(d, "torch_lit.gltf", Vector3(px, gy + 4.0, pz), 0.0, Vector3.ONE)

	_decorate_outskirts(d)


## Das Innenfeld: Bahn plus Festung im Vollausbau (Kirche und Nebengebäude liegen am
## weitesten hinten). Hier steht keine Streudeko — es ist die Fläche, auf der gespielt
## wird, und der Boden darunter ist flach (siehe terrain_height).
const FIELD_HALF_X := 11.0
const FIELD_Z_BACK := SPAWN_Z - 3.0
const FIELD_Z_FRONT := GOAL_Z + 11.0
## Zugabe in Bildeinheiten um den Bildstreifen des Innenfelds: die Modelle sind breiter
## und höher als der Punkt, an dem sie stehen.
const FIELD_CLEARANCE := 4.0


## Das Umland: Bäume und Felsen über den Teil des Bodens, der seit der Erweiterung bis
## an den Bildrand reicht. Ohne sie wäre die zusätzliche Fläche eine grüne Leere — mit
## ihnen liest sie sich als Landschaft, in der das Spielfeld liegt. Gras kommt hier
## nicht vor: ein Büschel ist auf die Entfernung ein Pixel und kostet trotzdem einen
## Knoten.
func _decorate_outskirts(d: Node3D) -> void:
	var area := visible_ground_area(_camera)
	var field := _field_span()
	for i in _rng.randi_range(55, 80):
		var p := _outskirts_point(area, field)
		if p != Vector2.INF:
			_scatter(d, "tree.glb", p.x, p.y, _rng.randf_range(0.8, 1.4))
	for i in _rng.randi_range(18, 30):
		var p := _outskirts_point(area, field)
		if p != Vector2.INF:
			_scatter(d, "rock.glb", p.x, p.y, _rng.randf_range(1.8, 3.2))


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
const HEX_DIR := "hexagon"
const FORTRESS_SCALE := 3.0

func _build_fortress() -> void:
	_fortress_tier = _current_fortress_tier()
	_spawn_fortress(_fortress_tier)


## Die Festungsstufe für den gewählten Bereich: die Units kommen aus Scope und Themen des
## Session-Setups (dieselben Achsen wie WaveGenerator.pool_from_settings), gewertet wird
## jede Unit als Ganzes über den ganzen Katalog (siehe FortressTier.run_tier).
func _current_fortress_tier() -> int:
	var scoped := ContentRegistry.lexemes_scoped(
			UserSettings.selected_scope(), UserSettings.selected_tags())
	var units := FortressTier.unit_tiers(
			ContentRegistry.lexemes.values(), PlayerProgress.mastered_lexemes())
	return FortressTier.run_tier(scoped, units)


## Baut die Festung passend zur Stufe (0..4) neu auf. Additiv: höhere Stufen zeigen
## mehr Türme/Mauern/Nebengebäude. Nur die -z-Front (Angriffsfront) liegt im Bild,
## Burg + Nebengebäude laufen nach hinten (+z) aus dem sichtbaren Feld.
func _spawn_fortress(tier: int) -> void:
	var fort := Node3D.new()
	fort.name = "Fortress"
	add_child(fort)
	_fortress = fort

	var fz := GOAL_Z              # Mauerfront = Ziel-Linie der Monster
	var seg := 2.0 * FORTRESS_SCALE   # Weltbreite eines Mauersegments

	print("[FORTRESS] Stufe %d (+%d HP)" % [tier, FortressTier.health_bonus(tier)])

	if tier <= 0:
		# Baustelle: Turmstumpf + Baugerüst. Kleine Stufe an den hinteren Rand
		# (Verteidiger-Rückseite = +z, näher zur Kamera) gezogen, weg von der
		# Monster-Front, aber noch komplett im Bild.
		_hex(fort, "building_tower_base_blue", 0.0, fz + 3.5)
		_hex(fort, "building_scaffolding", seg * 0.7, fz + 3.5)
		return

	# Ab Stufe 2: Wehrmauer mit Tor + Ecktürmen.
	if tier >= 2:
		_hex(fort, "wall_straight", -seg, fz)
		_hex(fort, "wall_straight_gate", 0.0, fz)
		_hex(fort, "wall_straight", seg, fz)
		var end_tower := "building_tower_catapult_blue" if tier >= 4 else "building_tower_B_blue"
		_hex(fort, end_tower, -seg * 1.5, fz)
		_hex(fort, end_tower, seg * 1.5, fz)

	# Zentrum: erst ein Turm (Stufe 1/2), ab Stufe 3 die große Burg.
	if tier >= 3:
		_hex(fort, "building_castle_blue", 0.0, fz + 3.0)
	elif tier == 2:
		_hex(fort, "building_tower_A_blue", 0.0, fz + 1.0)  # hinter der Mauer
	else:
		# Stufe 1 ohne Mauer: Turm an den hinteren Rand (+z), weg von der Front.
		_hex(fort, "building_tower_A_blue", 0.0, fz + 3.0)

	# Vollausbau: Nebengebäude hinter der Mauer + Fahnen auf den Ecktürmen.
	if tier >= 4:
		_hex(fort, "building_barracks_blue", -seg * 1.3, fz + 4.5, 20.0)
		_hex(fort, "building_blacksmith_blue", seg * 1.3, fz + 4.5, -20.0)
		_hex(fort, "building_home_A_blue", -seg * 0.6, fz + 6.5)
		_hex(fort, "building_home_B_blue", seg * 0.6, fz + 6.5)
		_hex(fort, "building_church_blue", 0.0, fz + 8.0)
		_hex(fort, "building_windmill_blue", -seg * 1.9, fz + 2.5)
		var flag_y := 2.2 * FORTRESS_SCALE
		for sx: float in [-seg * 1.5, seg * 1.5]:
			var flag := _hex(fort, "flag_blue", sx, fz)
			if flag != null:
				flag.position.y += flag_y


## Platziert ein Hexagon-Pack-Modell (ohne .gltf-Endung) auf Terrain-Höhe, skaliert
## mit FORTRESS_SCALE. Gibt die Instanz zurück (null wenn Modell fehlt).
func _hex(parent: Node3D, model: String, x: float, z: float, yaw := 0.0, extra := 1.0) -> Node3D:
	return _place_model(parent, "%s.gltf" % model, Vector3(x, _ground_y(x, z), z), yaw, Vector3.ONE * FORTRESS_SCALE * extra, HEX_DIR)


## Baut die Festung neu auf, mit kurzem Bau-Effekt als Feedback. Nur das Bild — die
## Stufe des Laufs setzt _finish_wave.
func _rebuild_fortress(tier: int) -> void:
	if is_instance_valid(_fortress):
		_fortress.queue_free()
	_spawn_fortress(tier)
	_spawn_explosion(Vector3(0.0, 1.5, GOAL_Z + 2.0), Color(1.0, 0.9, 0.4), 2.0)


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

	var pivot := $CameraPivot as Node3D
	var pivot_base := pivot.position
	var size_base := _camera.size
	# Ziel: Festungsmitte im Bild, deutlich herangezoomt (kleinere ortho-Größe = näher).
	var focus := Vector3(0.0, pivot_base.y, GOAL_Z + 3.0)

	# Festlicher goldener Blitz an der Festung + Banner.
	_spawn_explosion(Vector3(0.0, 2.0, GOAL_Z + 2.0), Color(1.0, 0.85, 0.3), 3.0)
	_show_upgrade_banner(tier, bonus)

	# Heranfahren + kräftig hineinzoomen.
	var tw_in := create_tween()
	tw_in.set_parallel(true)
	tw_in.tween_property(pivot, "position", focus, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw_in.tween_property(_camera, "size", size_base * 0.42, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
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


func _setup_view() -> void:
	setup_view($CameraPivot as Node3D, _camera, $Sun as DirectionalLight3D)


## Orthografische Iso-Kamera + Sonne. Per Code, damit die .tscn keine
## Transform-Basis-Mathematik enthalten muss — und statisch, damit ein Test dieselbe
## Kamera aufbauen kann, gegen die der Boden gerechnet wird.
static func setup_view(pivot: Node3D, camera: Camera3D, sun: DirectionalLight3D) -> void:
	pivot.rotation_degrees = Vector3(-30.0, 45.0, 0.0)
	# Auf die Bahn zentrieren, damit der längere Anmarsch komplett im Bild bleibt und
	# die Festung mit ihren Nebengebäuden trotzdem ganz darauf steht.
	pivot.position = Vector3(0.0, 0.0, VIEW_CENTER_Z)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 32.0
	camera.position = Vector3(0.0, 0.0, 32.0)
	sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)


func _process(delta: float) -> void:
	if _cutscene:
		return
	if _shake_left <= 0.0:
		return
	_shake_left = max(0.0, _shake_left - delta)
	if _shake_left == 0.0:
		_camera.position = _cam_base
	else:
		var mag := _shake_mag * (_shake_left / SHAKE_DURATION)
		_camera.position = _cam_base + Vector3(randf_range(-mag, mag), randf_range(-mag, mag), 0.0)


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
	get_tree().change_scene_to_file(MENU_SCENE)


## Die Pause gehört zum Kampf: ein Szenenwechsel mitten in einer Feier darf sie nicht
## ins Menü mitnehmen.
func _exit_tree() -> void:
	get_tree().paused = false


## „Schnell auflösen" fragt erst nach. Solange die Frage steht, ist die Eingabe weg: sie
## holt sich sonst jeden Frame den Fokus zurück, und Enter ginge an sie statt an „Abbrechen".
## Das Spiel läuft dabei weiter — ein Pausieren hielten die Spawn-Timer ohnehin nicht an.
func _on_fast_resolve_pressed() -> void:
	if _finished or _fast_resolving:
		return
	_answer_input.visible = false
	_fast_resolve_confirm.ask("Schnell auflösen?",
			"Die übrigen Monster laufen im Zeitraffer durch und treffen die Festung wie sonst "
			+ "auch. Ihre Wörter zählen als nicht gewusst und werden danach aufgelöst.",
			"Auflösen")


func _on_fast_resolve_cancelled() -> void:
	if not _finished and not _fast_resolving:
		_answer_input.visible = true


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

	GameState.current_wave = "procedural_%d" % _wave_number
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
		"task_pool": WaveGenerator.pool_from_settings(difficulty),
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
	_answer_input.visible = false
	_fast_resolve_button.visible = false
	_stats.hide_stats()
	_end_label.text = "Keine spielbaren Aufgaben.\n\nFilter prüfen oder über „📚 Inhalte“\neinen Vokabel-Pack installieren.\n\n[Esc] zurück ins Menü"
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
	var plan: Dictionary = _generator.pick(entry.get("task_pool", {}), active_sources)
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
	monster.position = Vector3(randf_range(-LANE_HALF_WIDTH, LANE_HALF_WIDTH), 0.0, SPAWN_Z)
	monster.reached_goal.connect(_on_monster_reached_goal)
	_monsters.add_child(monster)
	_active.append(monster)
	_spawned += 1
	EventBus.monster_spawned.emit(plan["monster_def"], plan["task"])


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
	for monster in _active:
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
	})
	_flash_feedback(FLASH_WRONG)
	_shake()
	Sfx.play(&"wrong_answer")


## Die learnable_ids der Aufgaben, die gerade auf dem Feld stehen — der Zusammenhang, in
## dem eine Eingabe beurteilt wurde. Nur fürs Protokoll; die Auswertung selbst läuft über
## die Monster-Liste.
func _active_learnable_ids() -> Array:
	var ids: Array = []
	for monster in _active:
		ids.append(str(monster.task.get("learnable_id", "")))
	return ids


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
	_active.erase(monster)
	_wave_correct += 1
	_wave_played_tasks.append(_task_snapshot(monster, false))
	_spawn_explosion(monster.position + Vector3(0.0, 1.0, 0.0), Color(0.7, 1.0, 0.4), 1.5)
	# Hier und nicht in _spawn_explosion(): denselben Effekt nutzen auch der Festungsausbau
	# und der Aufschlag eines durchgelassenen Monsters — die klingen nicht gleich.
	Sfx.play(&"monster_kill")
	# Aufsteigende „+XP"-Animation an der Stelle des Monsters. Erfahrung und nicht die
	# Punkte: sie ist der Lernfortschritt, und sie steht im HUD als Balken beim Namen —
	# die Zahl fliegt dorthin, wo sie sich sichtbar auswirkt. Gleiche Farbe wie der Balken.
	_spawn_xp_popup(monster.position + Vector3(0.0, 2.0, 0.0), monster.xp)
	# Erfahrung SOFORT verbuchen, wie das Gold in der Geldbörse: sie gehört zum Profil
	# (PlayerLevel), nicht zum Lauf, und ein Absturz mitten in der Welle darf sie nicht
	# kosten. Der Zähler daneben ist nur für den Wellenabschluss.
	PlayerLevel.gain(monster.xp)
	_wave_xp += monster.xp
	# Reward aus der monster_task_rule an GameState durchreichen (Score).
	var info := monster.monster_def.duplicate()
	info["reward"] = monster.reward
	EventBus.monster_defeated.emit(info, true)
	monster.queue_free()
	_check_end()


## Deutlich sichtbarer 3D-Text (+XP), der an der Trefferstelle aufpoppt, aufsteigt
## und ausblendet. Als Label3D (Billboard) im Stil der vorhandenen Monster-Beschriftungen.
func _spawn_xp_popup(pos: Vector3, amount: int) -> void:
	var label := Label3D.new()
	label.text = "+%d XP" % amount
	label.font_size = 200
	label.pixel_size = 0.02
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = Color(1.0, 0.9, 0.25)
	label.outline_size = 32
	label.outline_modulate = Color(0.15, 0.08, 0.0, 1.0)
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
	var label := Label3D.new()
	label.text = form
	label.font_size = 130
	label.pixel_size = 0.02
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = Color(0.85, 0.95, 1.0)
	label.outline_size = 28
	label.outline_modulate = Color(0.05, 0.1, 0.2, 1.0)
	label.position = pos
	add_child(label)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "position:y", pos.y + 2.0, 1.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "modulate:a", 0.0, 0.6).set_delay(1.2)
	tw.chain().tween_callback(label.queue_free)


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
	get_tree().change_scene_to_file(MENU_SCENE)


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
