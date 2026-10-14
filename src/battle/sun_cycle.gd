class_name SunCycle
extends Node
## Die Sonne zieht nach der Wanduhr über den Himmel, relativ zum Blick der Kamera: morgens
## tief von links, mittags hoch hinter der Kamera, abends tief von rechts. Ein Tag dauert
## eine echte Stunde, nach dem Abend springt sie auf den Morgen. Stellt jedes Bild `sun` und
## die globalen Shader-Parameter `sun_sin` (hält flachen Boden gleich hell) und `sun_tint`
## (Farbe der tiefen Sonne für den Bodenshader).

## So viel schneller als der echte Tag läuft der im Spiel.
const DAY_SPEED := 24.0
## Höhe über dem Horizont morgens und abends, und mittags (Grad).
const LOW := 5.0
const HIGH := 45.0
## So weit wandert die Richtung vom Morgen bis zum Abend (Grad), mittags steht sie auf `noon_yaw`.
const SWEEP := 180.0
## Farbe der Sonne mittags und ganz tief (morgens, abends) — mal `color`.
const NOON_TINT := Color(1.0, 0.97, 0.9)
const GOLDEN := Color(1.0, 0.72, 0.42)
## Die Uhrzeit, die der Anfang und das Ende eines Tages im Spiel zeigen — nur zum Anzeigen.
const DAWN_HOUR := 6.0
const DUSK_HOUR := 18.0

## Die Sonne, die dieser Knoten stellt.
var sun: DirectionalLight3D
## Richtung der Sonne mittags (rotation_degrees.y) — die Blickrichtung der Kamera.
var noon_yaw := 0.0
## Farbe der Sonne ohne Tageszeit (BattleTheme.sun_color); spätere Änderungen hierher.
var color := Color.WHITE
## Aus: `phase` steht, bis jemand es setzt.
var follow_clock := true
## Die Grenzen, veränderbar für die Werkbank.
var low := LOW
var high := HIGH
var sweep := SWEEP
## Wie weit der Tag ist: 0 = Morgen, 0.5 = Mittag, gegen 1 = Abend.
var phase := 0.5
## Gesetzt: kein Sprung auf den Morgen, die Sonne bleibt am Abend stehen.
var hold := false
## Zu diesem Anteil (0..1) scheint die Sonne aus `rest` statt aus dem Tag (drinnen).
var rest := Basis.IDENTITY
var rest_weight := 0.0


## Stellt `sun` in den Tag, gesehen von `view` (der Kamera, oder ihrem Drehpunkt).
static func attach(parent: Node, light: DirectionalLight3D, view: Node3D) -> SunCycle:
	var cycle := SunCycle.new()
	cycle.sun = light
	cycle.color = light.light_color
	cycle.noon_yaw = yaw_of(view)
	cycle.name = "SunCycle"
	parent.add_child(cycle)
	return cycle


## Der Tag nach der Uhr dieses Rechners, jede volle Stunde ein neuer.
static func clock_phase(unix_local: float) -> float:
	return fposmod(unix_local * DAY_SPEED / 86400.0, 1.0)


static func local_unix() -> float:
	return Time.get_unix_time_from_system() + Time.get_time_zone_from_system().get("bias", 0) * 60.0


## Wohin `node` schaut (-z), als Drehung um die Hochachse, auch geneigt oder gerollt.
static func yaw_of(node: Node3D) -> float:
	var forward := -node.global_transform.basis.z
	return rad_to_deg(atan2(-forward.x, -forward.z))


func elevation_at(p: float) -> float:
	return low + (high - low) * sin(PI * p)


## Ton der Sonne bei Höhe `e`: GOLDEN am Horizont (`low`), NOON_TINT ganz oben (`high`).
## Drinnen (`rest_weight`) ohne Tageszeit, also weiß.
func tint_at(e: float) -> Color:
	var low_sun := 1.0 - clampf(inverse_lerp(low, high, e), 0.0, 1.0)
	return NOON_TINT.lerp(GOLDEN, low_sun).lerp(Color.WHITE, rest_weight)


func yaw_at(p: float) -> float:
	# Morgens noon_yaw − 90° (von links), abends noon_yaw + 90° (von rechts).
	return noon_yaw + (p - 0.5) * sweep


## Die Uhrzeit, die `p` zeigt (DAWN_HOUR bis DUSK_HOUR).
static func hour_of(p: float) -> float:
	return lerpf(DAWN_HOUR, DUSK_HOUR, p)


static func phase_of(hour: float) -> float:
	return clampf(inverse_lerp(DAWN_HOUR, DUSK_HOUR, hour), 0.0, 0.9999)


func _ready() -> void:
	if follow_clock:
		phase = clock_phase(local_unix())
	apply()


func _process(_delta: float) -> void:
	if follow_clock:
		advance(clock_phase(local_unix()))


## Geht auf `p` weiter, während `hold` nur vorwärts.
func advance(p: float) -> void:
	if hold and p < phase:
		return
	phase = p
	apply()


## Stellt die Sonne auf `phase`.
func apply() -> void:
	var e := elevation_at(phase)
	if sun != null:
		sun.rotation_degrees = Vector3(-e, yaw_at(phase), 0.0)
		if rest_weight > 0.0:
			var day := sun.basis.get_rotation_quaternion()
			sun.basis = Basis(day.slerp(rest.get_rotation_quaternion(), rest_weight))
		sun.light_color = color * tint_at(e)
	RenderingServer.global_shader_parameter_set(&"sun_tint", tint_at(e))
	RenderingServer.global_shader_parameter_set(&"sun_sin", sin(deg_to_rad(e)))
