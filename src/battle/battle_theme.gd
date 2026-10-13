class_name BattleTheme
extends Resource
## Wie das Schlachtfeld einer Unit aussieht (docs/ARCHITECTURE.md, „Karte und
## Laufanfrage“). Die Vorgaben hier sind das Aussehen ohne Thema; eine `.tres` setzt nur,
## was abweicht. Auf das Spiel wirkt nichts davon.

const DIR := "res://assets/battle_themes"
## Die zwei Töne, zwischen denen der Boden fleckig streut.
@export var ground_low := Color(0.22, 0.34, 0.15)
@export var ground_high := Color(0.42, 0.56, 0.28)
## Farbe, zu der die Hügel mit der Höhe hin kippen (höchstens zu HILL_MIX_MAX).
@export var hill := Color(0.44, 0.44, 0.30)
## Kuppen ab `peak_height` (m) bekommen diese Farbe, etwa Schnee. INF heißt: keine.
@export var peak := Color(0.92, 0.94, 0.98)
@export var peak_height := INF
## Flecken in Kuppenfarbe auch in der Ebene, wo der Streuwert `t` (0..1) darüber liegt
## (0.7 ≈ ein Drittel der Fläche), mit weichem Rand (PATCH_BLEND). Über 1 heißt: keine.
@export var patches := 2.0
## Dritter Bodenton in größeren Flecken und sein Flächenanteil (0 = keine), im Bodenshader.
@export var ground_patch := Color(0.5, 0.46, 0.27)
@export_range(0.0, 1.0) var ground_patch_amount := 0.3
## Art des Wegs zum Tor (BattlePath).
@export_enum("trail", "road", "boardwalk", "cobble") var path := "trail"
## Grundfarbe des Wegs.
@export var path_color := Color(0.48, 0.38, 0.24)
## Detailtextur des Wegs wie `ground_texture`. Leer: die der Wegart (BattlePath.TEXTURES).
@export var path_texture := ""
@export_range(0.0, 1.0) var path_texture_strength := 0.9
## Bewuchs (GroundCover): Dichte der Halmbüschel (0 = keine, 1 = karg, 3 = dichte Wiese),
## Blütenfarben und Anteil der Büschel mit Blüten.
@export_range(0.0, 4.0) var cover := 1.0
## Farbe der Büschel. Ohne (Alpha 0) die des Bodens darunter, etwas heller.
@export var cover_color := Color(0.0, 0.0, 0.0, 0.0)
@export var cover_flowers: Array[Color] = []
@export_range(0.0, 1.0) var cover_flower_amount := 0.08
## Sträucher um die Bäume: Farbe und Anteil von GroundCover.BUSHES_PER_TREE (0 = keine).
@export var bush_color := Color(0.2, 0.36, 0.13)
@export_range(0.0, 1.0) var bushes := 0.6
## Detailtextur des Bodens: graue Kachel unter `assets/textures/ground/` (ohne Endung).
## Leer: der Boden bleibt glatt.
@export var ground_texture := ""
## Wie stark die Textur wirkt (0..1).
@export_range(0.0, 1.0) var ground_texture_strength := 0.6
## Hintergrund; in der Ich-Sicht der Horizont, dessen Farbe der Nebel annimmt.
@export var background := Color(0.09, 0.08, 0.13)
@export var ambient := Color(0.5, 0.52, 0.62)
@export var ambient_energy := 1.0
@export var sun_color := Color(1.0, 1.0, 1.0)
@export var sun_energy := 1.0
## Farbkorrektur des ganzen Bilds (Environment.adjustment_*).
@export_range(0.0, 2.0) var saturation := 1.08
@export_range(0.5, 2.0) var contrast := 1.08
@export_range(0.5, 1.5) var brightness := 1.0
## Dunst der Draufsicht: Dichte (0 = klare Luft, 0.02 ≈ Rauch über einer Stadt) und Farbe,
## ohne (Alpha 0) die des Hintergrunds. Am Boden dichter (`HAZE_HEIGHT`).
@export_range(0.0, 0.1) var haze := 0.0
@export var haze_color := Color(0.0, 0.0, 0.0, 0.0)
## Thema, dessen Licht dieses übernimmt. Leer: das eigene. Nur eine Stufe tief.
@export var light_from := ""
## Wie stark Bäume und Gras im Wind schwanken (Wind.sway), 1 = wie in Wind.SWAY, 0 = still.
@export_range(0.0, 3.0) var wind := 1.0
## Anteil der Sonne, den ein Wolkenschatten nimmt. 0 = wolkenlos.
@export_range(0.0, 1.0) var clouds := 0.6
## Was in der Luft treibt: eine Art aus AmbientParticles.KINDS ("leaves", "snow",
## "pollen", "fireflies"), leer heißt nichts.
@export var particles := ""
## Ab und zu rollt ein verdorrter Busch durchs Bild (Tumbleweeds).
@export var tumbleweeds := false

## Abnutzung der Festung (FortressModel): 0 wie im Pack, 1 verrußt und fleckig.
@export_range(0.0, 1.0) var fortress_wear := 0.0

## Die Deko je Platz: Modelle unter `assets/models/`, zufällig gezogen; Größe und Menge
## gehören dem Platz. Leer heißt: dort nichts.
@export var trees: Array[String] = ["props/tree.glb"]
## Felsen auf dem Feld und im Umland.
@export var rocks: Array[String] = ["props/rock.glb"]
## Büschel auf dem Feld.
@export var grass: Array[String] = ["props/grass.glb"]
## Kram am Feldrand.
@export var props: Array[String] = ["props/barrel_large.gltf", "props/crates_stacked.gltf"]
## Wenige große Stücke (Ruinen, Felsnadeln) an den Seitenstreifen und im Umland.
@export var landmarks: Array[String] = []

## Unter dieser Höhe (m) wird der Dunst dichter (Environment.fog_height), und wie sehr.
const HAZE_HEIGHT := 3.0
const HAZE_HEIGHT_DENSITY := 0.25
## Höchster Anteil der Hügelfarbe.
const HILL_MIX_MAX := 0.55
## Über wie viel Höhe (m) eine Kuppe von Boden zu voller Kuppenfarbe übergeht.
const PEAK_BLEND := 0.8
## Halbe Breite des Übergangs am Rand eines Flecks, in Einheiten von `t`.
const PATCH_BLEND := 0.12
const MODEL_DIR := "res://assets/models"
const GROUND_TEXTURE_DIR := "res://assets/textures/ground"
const GROUND_SHADER := preload("res://assets/shaders/battle_ground.gdshader")


## Das Thema des Levels, oder die Vorgabe (Expertenmodus, Unit ohne Eintrag).
static func for_level(level: Dictionary) -> BattleTheme:
	if level.is_empty():
		return BattleTheme.new()
	return for_unit(str(level.get("book", "")), int(level.get("unit", 0)), str(level.get("key", "")))


## Das Thema am Stop `key` der Unit; ohne eigenen Eintrag das der ganzen Unit.
static func for_unit(book: String, unit: int, key := "") -> BattleTheme:
	var theme_name := name_for(book, unit, key)
	return named(theme_name) if not theme_name.is_empty() else BattleTheme.new()


## Der Name aus `themes` in map.json, oder "" ohne Eintrag.
static func name_for(book: String, unit: int, key := "") -> String:
	return name_in(MapLayout.data(book).get("themes", {}), unit, key)


## Der Name für Unit und Stop aus einem `themes`-Block.
static func name_in(themes: Variant, unit: int, key := "") -> String:
	if not themes is Dictionary:
		return ""
	var entry: Variant = (themes as Dictionary).get(str(unit), "")
	if entry is Dictionary:
		return str((entry as Dictionary).get(key, (entry as Dictionary).get("default", "")))
	return str(entry)


## Das Thema `theme_name`, oder die Vorgabe, wenn es die Datei nicht gibt.
static func named(theme_name: String) -> BattleTheme:
	var loaded := _load(theme_name)
	if loaded == null:
		return BattleTheme.new()
	if loaded.light_from.is_empty():
		return loaded
	var light := _load(loaded.light_from)
	if light == null:
		return loaded
	# Auf einer Kopie: das geladene Thema ist geteilt und käme sonst anders beleuchtet wieder.
	var out := loaded.duplicate() as BattleTheme
	out.background = light.background
	out.ambient = light.ambient
	out.ambient_energy = light.ambient_energy
	out.sun_color = light.sun_color
	out.sun_energy = light.sun_energy
	out.saturation = light.saturation
	out.contrast = light.contrast
	out.brightness = light.brightness
	out.haze = light.haze
	out.haze_color = light.haze_color
	return out


static func _load(theme_name: String) -> BattleTheme:
	var path := "%s/%s.tres" % [DIR, theme_name]
	if not ResourceLoader.exists(path):
		push_warning("BattleTheme: kein Thema '%s'" % theme_name)
		return null
	return load(path) as BattleTheme


## Alle Deko-Modelle des Themas, ohne Doppel.
func decor_models() -> Array[String]:
	var out: Array[String] = []
	for slot: Array[String] in [trees, rocks, grass, props, landmarks]:
		for model in slot:
			if not out.has(model):
				out.append(model)
	return out


## Farbe des Bodens an einer Ecke. `t` (0..1) streut zwischen den Bodentönen, `height` ist
## ihre Höhe (m). Muss stetig bleiben: jeder Sprung stünde als Linie im Gelände.
func ground_color(t: float, height: float) -> Color:
	var col := ground_low.lerp(ground_high, t)
	# Volle Hügelfarbe wäre bei 3 m erreicht, gedeckelt auf HILL_MIX_MAX.
	col = col.lerp(hill, clampf(height / 3.0, 0.0, HILL_MIX_MAX))
	if height > peak_height:
		col = col.lerp(peak, clampf((height - peak_height) / PEAK_BLEND, 0.0, 1.0))
	if patches <= 1.0 + PATCH_BLEND:
		col = col.lerp(peak, smoothstep(patches - PATCH_BLEND, patches + PATCH_BLEND, t))
	return col


## Anteil der Kuppenfarbe an dieser Stelle (0..1), wie in `ground_color`.
func ground_snow(t: float, height: float) -> float:
	var snow := 0.0
	if height > peak_height:
		snow = clampf((height - peak_height) / PEAK_BLEND, 0.0, 1.0)
	if patches <= 1.0 + PATCH_BLEND:
		snow = maxf(snow, smoothstep(patches - PATCH_BLEND, patches + PATCH_BLEND, t))
	return snow


## Der Streuwert `t` (0..1) des Bodens bei (x,z) aus dem Rauschen des Terrains.
static func ground_t(noise: FastNoiseLite, x: float, z: float) -> float:
	return noise.get_noise_2d(x * 2.3 + 100.0, z * 2.3) * 0.5 + 0.5


## Material des Bodens, mit `battle_path` samt Weg.
func ground_material(battle_path: BattlePath = null) -> Material:
	var mat := ShaderMaterial.new()
	mat.shader = GROUND_SHADER
	mat.set_shader_parameter("patch_color", Vector3(ground_patch.r, ground_patch.g, ground_patch.b))
	mat.set_shader_parameter("patch_amount", ground_patch_amount)
	if battle_path != null:
		battle_path.apply_to(mat)
		mat.set_shader_parameter("path_color", Vector3(path_color.r, path_color.g, path_color.b))
		var path_detail := _detail(path_texture if not path_texture.is_empty()
				else str(BattlePath.TEXTURES.get(battle_path.kind, "")))
		if path_detail != null:
			mat.set_shader_parameter("path_detail", path_detail)
		mat.set_shader_parameter("path_strength", path_texture_strength if path_detail != null else 0.0)
	var detail := _detail(ground_texture)
	if detail != null:
		mat.set_shader_parameter("detail", detail)
	mat.set_shader_parameter("strength", ground_texture_strength if detail != null else 0.0)
	# Der Shader beleuchtet selbst: Grundhelligkeit ist das Umgebungslicht, die Sonne nimmt weg.
	var amb := ambient.srgb_to_linear() * ambient_energy
	mat.set_shader_parameter("ambient_light", Vector3(amb.r, amb.g, amb.b))
	mat.set_shader_parameter("clouds", clouds)
	return mat


func ground_texture_path() -> String:
	return "%s/%s.png" % [GROUND_TEXTURE_DIR, ground_texture]


## Die Textur mit Mipmaps, sonst flimmert der Boden beim Wackeln.
func _detail(texture_name: String) -> Texture2D:
	var path := "%s/%s.png" % [GROUND_TEXTURE_DIR, texture_name]
	if texture_name.is_empty() or not ResourceLoader.exists(path):
		return null
	var tex := load(path) as Texture2D
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null:
		return tex
	if img.has_mipmaps():
		return tex
	# Die Image-Kopie gehört uns: der Cache bleibt, wie er ist.
	if img.is_compressed():
		img.decompress()
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Hintergrund, Umgebungslicht und Sonne, auf einer Kopie des geteilten Environments.
func apply(world: WorldEnvironment, sun: DirectionalLight3D) -> void:
	var env := world.environment.duplicate() as Environment
	env.background_color = background
	env.ambient_light_color = ambient
	env.ambient_light_energy = ambient_energy
	env.adjustment_saturation = saturation
	env.adjustment_contrast = contrast
	env.adjustment_brightness = brightness
	apply_haze(env)
	world.environment = env
	sun.light_color = sun_color
	sun.light_energy = sun_energy


## Der Dunst der Draufsicht auf `env` (eine eigene Kopie, nicht die der Szene).
func apply_haze(env: Environment) -> void:
	env.fog_enabled = haze > 0.0
	if not env.fog_enabled:
		return
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_density = haze
	env.fog_light_color = haze_color if haze_color.a > 0.0 else background
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.0
	env.fog_sky_affect = 0.0
	env.fog_height = HAZE_HEIGHT
	env.fog_height_density = HAZE_HEIGHT_DENSITY
