class_name BattleTheme
extends Resource
## Wie das Schlachtfeld einer Unit aussieht: Farben von Boden und Licht, dazu die Deko.
##
## Die Gebietskarte zeigt je Unit eine eigene Landschaft (Wiese, Wüste, Gletscher …), und
## der Kampf soll in derselben stehen. Ein Thema ist eine `.tres` unter
## `assets/battle_themes/`; welche Unit welches Thema hat, steht in `map.json` des Buchs:
##
##     { "units": …, "areas": …, "themes": { "2": "desert", … } }
##
## Die Vorgaben hier SIND das Aussehen ohne Thema (Expertenmodus, Unit ohne Eintrag) —
## eine `.tres` setzt nur, was abweicht. Gespielt wird davon nichts: Bahn, Hügelform und
## Festung sind in jedem Thema dieselben, und die Deko steht an denselben Stellen.

const DIR := "res://assets/battle_themes"
## Höhe der Sonne über dem Horizont; `WaveRunner.setup_view` stellt sie so.
const SUN_ELEVATION := 55.0

## Die zwei Töne, zwischen denen der Boden fleckig streut.
@export var ground_low := Color(0.22, 0.34, 0.15)
@export var ground_high := Color(0.42, 0.56, 0.28)
## Farbe, zu der die Hügel mit der Höhe hin kippen (höchstens zu HILL_MIX_MAX).
@export var hill := Color(0.44, 0.44, 0.30)
## Kuppen ab `peak_height` bekommen diese Farbe — Schnee im Gebirge. INF heißt: keine.
@export var peak := Color(0.92, 0.94, 0.98)
@export var peak_height := INF
## Flecken in Kuppenfarbe auch in der Ebene: überall, wo der Streuwert `t` darüber liegt
## (0..1, also 0.7 ≈ ein Drittel der Fläche), mit weichem Rand (PATCH_BLEND). Über 1 heißt:
## keine — Schnee liegt dann nur auf den Kuppen, und um das flache Feld stünde er als Ring.
@export var patches := 2.0
## Detailtextur des Bodens: Name einer grauen Kachel unter `assets/textures/ground/` (ohne
## Endung), die die Bodenfarben in der Helligkeit moduliert. Leer, oder die Datei fehlt
## noch: der Boden bleibt glatt wie ohne Thema. Was dort liegen soll, steht im BRIEF.md.
@export var ground_texture := ""
## Wie stark die Textur wirkt (0..1).
@export_range(0.0, 1.0) var ground_texture_strength := 0.6
## Hintergrund. In der Draufsicht verdeckt ihn der Boden; in der Ich-Sicht ist er der
## Horizont, und der Nebel nimmt seine Farbe an (WaveRunner._setup_first_person).
@export var background := Color(0.09, 0.08, 0.13)
@export var ambient := Color(0.5, 0.52, 0.62)
@export var ambient_energy := 1.0
@export var sun_color := Color(1.0, 1.0, 1.0)
@export var sun_energy := 1.0

## Die Deko je Platz: Modelle unter `assets/models/` (etwa "props/tree.glb"), aus denen der
## Kampf zufällig zieht. Größe und Menge gehören dem PLATZ, nicht dem Modell — ein Modell
## für einen Platz ist dafür bemessen (src/dev/model_forge.gd). Leer heißt: dort nichts.
## Bäume an den Seitenstreifen und im Umland.
@export var trees: Array[String] = ["props/tree.glb"]
## Felsen auf dem Feld und im Umland.
@export var rocks: Array[String] = ["props/rock.glb"]
## Büschel auf dem Feld.
@export var grass: Array[String] = ["props/grass.glb"]
## Kram am Feldrand.
@export var props: Array[String] = ["props/barrel_large.gltf", "props/crates_stacked.gltf"]
## Wenige große Stücke (Ruinen, Felsnadeln) an den Seitenstreifen und im Umland.
@export var landmarks: Array[String] = []

## Wie weit ein Hügel höchstens zur Hügelfarbe kippt — der Rest bleibt Bodenfarbe.
const HILL_MIX_MAX := 0.55
## Über wie viel Höhe eine Kuppe von Boden zu voller Kuppenfarbe übergeht.
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
	return for_unit(str(level.get("book", "")), int(level.get("unit", 0)))


static func for_unit(book: String, unit: int) -> BattleTheme:
	var themes: Variant = MapLayout.data(book).get("themes", {})
	if not themes is Dictionary:
		return BattleTheme.new()
	var theme_name := str((themes as Dictionary).get(str(unit), ""))
	return named(theme_name) if not theme_name.is_empty() else BattleTheme.new()


## Das Thema `theme_name`, oder die Vorgabe, wenn es die Datei nicht gibt.
static func named(theme_name: String) -> BattleTheme:
	var path := "%s/%s.tres" % [DIR, theme_name]
	if not ResourceLoader.exists(path):
		push_warning("BattleTheme: kein Thema '%s'" % theme_name)
		return BattleTheme.new()
	var loaded := load(path) as BattleTheme
	return loaded if loaded != null else BattleTheme.new()


## Alle Deko-Modelle des Themas, ohne Doppel.
func decor_models() -> Array[String]:
	var out: Array[String] = []
	for slot: Array[String] in [trees, rocks, grass, props, landmarks]:
		for model in slot:
			if not out.has(model):
				out.append(model)
	return out


## Farbe des Bodens an einer Ecke. `t` (0..1) streut zwischen den Bodentönen, `height` ist
## ihre Höhe. Alles stetig in `t` und `height`: der Boden ist glatt schattiert, und jeder
## Sprung stünde als Linie im Gelände.
func ground_color(t: float, height: float) -> Color:
	var col := ground_low.lerp(ground_high, t)
	col = col.lerp(hill, clampf(height / 3.0, 0.0, HILL_MIX_MAX))
	if height > peak_height:
		col = col.lerp(peak, clampf((height - peak_height) / PEAK_BLEND, 0.0, 1.0))
	if patches <= 1.0 + PATCH_BLEND:
		col = col.lerp(peak, smoothstep(patches - PATCH_BLEND, patches + PATCH_BLEND, t))
	return col


## Material des Bodens: immer der Bodenshader; mit Detailtextur, wenn das Thema eine hat und
## die Datei da ist, sonst glatt.
func ground_material() -> Material:
	var mat := ShaderMaterial.new()
	mat.shader = GROUND_SHADER
	var detail := _ground_detail()
	if detail != null:
		mat.set_shader_parameter("detail", detail)
	mat.set_shader_parameter("strength", ground_texture_strength if detail != null else 0.0)
	# Der Shader beleuchtet selbst (light()): Grundhelligkeit ist das Umgebungslicht, die
	# Sonne nimmt davon nur weg (Schatten, abgewandte Hänge) oder legt wenig dazu.
	var amb := ambient.srgb_to_linear() * ambient_energy
	mat.set_shader_parameter("ambient_light", Vector3(amb.r, amb.g, amb.b))
	mat.set_shader_parameter("sun_sin", sin(deg_to_rad(SUN_ELEVATION)))
	return mat


func ground_texture_path() -> String:
	return "%s/%s.png" % [GROUND_TEXTURE_DIR, ground_texture]


## Die Textur MIT Mipmaps. Aus der Ferne liegen mehrere Texel auf einem Bildpunkt; ohne
## Mipmaps flimmert der Boden, sobald die Kamera wackelt. Der Import legt sie nur an, wenn
## man ihn darum bittet — hier hängt es nicht davon ab, wie die Datei importiert wurde.
func _ground_detail() -> Texture2D:
	if ground_texture.is_empty() or not ResourceLoader.exists(ground_texture_path()):
		return null
	var tex := load(ground_texture_path()) as Texture2D
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


## Hintergrund, Umgebungslicht und Sonne. Auf einer KOPIE des Environments: das der
## Szene ist eine geteilte Ressource und käme sonst beim nächsten Kampf gefärbt wieder.
func apply(world: WorldEnvironment, sun: DirectionalLight3D) -> void:
	var env := world.environment.duplicate() as Environment
	env.background_color = background
	env.ambient_light_color = ambient
	env.ambient_light_energy = ambient_energy
	world.environment = env
	sun.light_color = sun_color
	sun.light_energy = sun_energy
