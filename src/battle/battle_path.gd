class_name BattlePath
extends RefCounted
## Der Weg über das Schlachtfeld: vom hinteren Bildrand in sanften Bögen über die Bahn bis
## ins Festungstor. Er ist Bildgestaltung, kein Spielfeld: die Monster laufen über die ganze
## Bahn, der Weg führt nur das Auge zur Festung. Deshalb hat jeder Kampf einen.
##
## WIE er aussieht (Trampelpfad, Weg, Bohlenweg, Pflaster) und welche Farbe er hat, sagt das
## Thema (`BattleTheme.path`, `path_color`); WO er liegt, steht hier. Gezeichnet wird er im
## Bodenshader (battle_ground.gdshader), der dieselbe Mittellinie rechnet wie `centre_x` —
## die Form steht deshalb zweimal, die Zahlen nur hier (`apply_to`). Die Streudeko fragt
## `blocks`, damit kein Fels mitten auf dem Weg liegt.

## Die Arten in der Reihenfolge, in der der Shader sie nummeriert (path_kind), mit halber
## Breite in Metern. Pflaster und Weg sind breiter, ein Trampelpfad schmal.
const KINDS := {"trail": 1.6, "road": 2.0, "boardwalk": 1.5, "cobble": 2.2}
## Detailtextur je Art (assets/textures/ground/), wenn das Thema keine eigene nennt. Bohlenweg
## und Pflaster fehlen: deren Bretter und Steine zeichnet der Shader.
const TEXTURES := {"trail": "dry_earth", "road": "gravel"}
## So weit vor dem Tor läuft der Weg gerade auf die Torachse (x = 0) zu, und über diese
## Länge geht er aus dem Bogen in die Gerade über.
const STRAIGHT := 4.0
const STRAIGHT_BLEND := 10.0
## Der Verlauf ist eine Summe aus zwei Bögen und einer Schräge, alle drei je Kampf
## gewürfelt: so kommt der Weg mal in einem langen Schwung, mal in kurzen Kehren, mal schräg
## aus einer hinteren Ecke. Ausschlag und Länge des großen und des kleinen Bogens:
const BIG_AMPLITUDE := Vector2(1.5, 2.6)
const BIG_WAVELENGTH := Vector2(34.0, 56.0)
## Zusammen höchstens etwa 1 m quer je m längs: darauf baut der Shader, der weitab vom Weg
## nichts rechnet (path_at).
const SMALL_AMPLITUDE := Vector2(0.3, 0.8)
const SMALL_WAVELENGTH := Vector2(14.0, 22.0)
## Höchste Schräge (Meter quer je Meter längs), gezählt ab dem Anfang der Geraden vor dem
## Tor. Mit den Bögen zusammen bleibt der Weg am Spawn in der Bahn (LANE_HALF_WIDTH).
const DRIFT := 0.06

var kind := "trail"
## Ausschlag, Länge und Phase je Bogen.
var big := Vector3(2.5, 44.0, 0.0)
var small := Vector3(0.6, 15.0, 0.0)
var drift := 0.0
## Mauerfront mit dem Tor — dort endet der Weg.
var gate_z := 16.5


## Ein Weg der Art `path_kind` (BattleTheme.path) mit gewürfeltem Verlauf vor dem Tor bei
## `gate`. Eine unbekannte Art wird zum Trampelpfad: einen Weg gibt es immer.
static func make(path_kind: String, gate: float, rng: RandomNumberGenerator) -> BattlePath:
	var path := BattlePath.new()
	path.kind = path_kind if KINDS.has(path_kind) else "trail"
	path.gate_z = gate
	path.big = Vector3(rng.randf_range(BIG_AMPLITUDE.x, BIG_AMPLITUDE.y),
			rng.randf_range(BIG_WAVELENGTH.x, BIG_WAVELENGTH.y), rng.randf_range(0.0, TAU))
	path.small = Vector3(rng.randf_range(SMALL_AMPLITUDE.x, SMALL_AMPLITUDE.y),
			rng.randf_range(SMALL_WAVELENGTH.x, SMALL_WAVELENGTH.y), rng.randf_range(0.0, TAU))
	path.drift = rng.randf_range(-DRIFT, DRIFT)
	return path


func half_width() -> float:
	return float(KINDS[kind])


## Mitte des Wegs bei `z`. Dieselbe Formel steht in battle_ground.gdshader (path_centre).
func centre_x(z: float) -> float:
	var straight := 1.0 - smoothstep(gate_z - STRAIGHT - STRAIGHT_BLEND, gate_z - STRAIGHT, z)
	var x := big.x * sin(TAU * z / big.y + big.z) + small.x * sin(TAU * z / small.y + small.z) \
			+ drift * (gate_z - STRAIGHT - z)
	return x * straight


## Abstand von (x,z) zur Mittellinie, quer zum Weg gemessen.
func distance(x: float, z: float) -> float:
	var slope := centre_x(z + 0.5) - centre_x(z - 0.5)
	return absf(x - centre_x(z)) / sqrt(1.0 + slope * slope)


## Läge etwas bei (x,z) mit dem Radius `margin` auf dem Weg? Hinter dem Tor gibt es keinen.
func blocks(x: float, z: float, margin := 0.5) -> bool:
	return z < gate_z + 1.0 and distance(x, z) < half_width() + margin


## Form und Art an das Bodenmaterial.
func apply_to(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("path_kind", KINDS.keys().find(kind))
	mat.set_shader_parameter("path_half_width", half_width())
	mat.set_shader_parameter("path_big", big)
	mat.set_shader_parameter("path_small", small)
	mat.set_shader_parameter("path_drift", drift)
	mat.set_shader_parameter("path_gate_z", gate_z)
	mat.set_shader_parameter("path_straight", Vector2(gate_z - STRAIGHT - STRAIGHT_BLEND, gate_z - STRAIGHT))
