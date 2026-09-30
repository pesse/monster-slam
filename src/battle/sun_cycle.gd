class_name SunCycle
extends Node
## Die Sonne zieht nach der Uhr über den Himmel: morgens tief, mittags hoch, abends wieder
## tief, und dazwischen wandert sie um SWEEP Grad weiter — im Bild von links nach rechts:
## morgens fallen lange Schatten nach rechts, mittags kurze nach hinten (die Sonne steht
## hinter der Kamera), abends lange nach links. Die Himmelsrichtung zählt nicht, nur der Blick.
## Ein Tag im Spiel dauert ein Viertel des echten (DAY_SPEED), es gibt keine Nacht: nach dem
## Abend springt sie auf den Morgen.
##
## Ein SunCycle-Knoten im Baum stellt jedes Bild `sun` und den globalen Shader-Parameter
## `sun_sin` (project.godot), nach dem der Bodenshader flachen Boden gleich hell hält, egal
## wie hoch die Sonne steht. Die Modelle werden bei tiefer Sonne dunkler — gewollt.
##
## Gezählt wird nach der Wanduhr, nicht nach dem skalierten delta: die Zeitlupe (SlowMotion)
## hält die Sonne nicht an. Solange `hold` gesetzt ist (im Kampf: während einer Welle), geht
## sie nur vorwärts — der Sprung auf den Morgen wartet, bis die Welle vorbei ist.

## So viel schneller als der echte Tag läuft der im Spiel.
const DAY_SPEED := 4.0
## Höhe über dem Horizont morgens und abends, und mittags (Grad).
const LOW := 10.0
const HIGH := 55.0
## So weit wandert die Richtung vom Morgen bis zum Abend (Grad), mittags steht sie auf `noon_yaw`.
const SWEEP := 180.0
## Die Uhrzeit, die der Anfang und das Ende eines Tages im Spiel zeigen — nur zum Anzeigen.
const DAWN_HOUR := 6.0
const DUSK_HOUR := 18.0

## Die Sonne, die dieser Knoten stellt.
var sun: DirectionalLight3D
## Richtung der Sonne mittags (rotation_degrees.y) — die Blickrichtung der Kamera.
var noon_yaw := 0.0
## Aus: `phase` steht, bis jemand es setzt (Werkbank, Bilderläufe).
var follow_clock := true
## Die Grenzen, hier veränderbar, damit die Werkbank sie am Bild ausprobieren kann.
var low := LOW
var high := HIGH
var sweep := SWEEP
## Wie weit der Tag ist: 0 = Morgen, 0.5 = Mittag, gegen 1 = Abend.
var phase := 0.5
## Gesetzt: kein Sprung auf den Morgen, die Sonne bleibt am Abend stehen.
var hold := false
## Zu diesem Anteil (0..1) scheint die Sonne aus `rest` statt aus dem Tag — drinnen (die
## Bibliothek im Hauptmenü) hängt das Licht nicht an der Uhrzeit.
var rest := Basis.IDENTITY
var rest_weight := 0.0


## Stellt `sun` in den Tag, gesehen von `view` (der Kamera, oder ihrem Drehpunkt).
static func attach(parent: Node, light: DirectionalLight3D, view: Node3D) -> SunCycle:
	var cycle := SunCycle.new()
	cycle.sun = light
	cycle.noon_yaw = yaw_of(view)
	cycle.name = "SunCycle"
	parent.add_child(cycle)
	return cycle


## Der Tag nach der Uhr dieses Rechners: um Mitternacht beginnt einer, alle sechs Stunden
## der nächste.
static func clock_phase(unix_local: float) -> float:
	return fposmod(unix_local * DAY_SPEED / 86400.0, 1.0)


static func local_unix() -> float:
	return Time.get_unix_time_from_system() + Time.get_time_zone_from_system().get("bias", 0) * 60.0


## Wohin `node` schaut (-z), als Drehung um die Hochachse — auch für einen Knoten, der
## zusätzlich geneigt oder gerollt steht.
static func yaw_of(node: Node3D) -> float:
	var forward := -node.global_transform.basis.z
	return rad_to_deg(atan2(-forward.x, -forward.z))


func elevation_at(p: float) -> float:
	return low + (high - low) * sin(PI * p)


func yaw_at(p: float) -> float:
	# Wachsender Winkel: von links hinter der Kamera nach rechts. Morgens scheint sie (Richtung
	# noon_yaw − 90°) quer von links durchs Bild, abends (noon_yaw + 90°) von rechts.
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


## Geht auf `p` weiter. Während `hold` nur vorwärts: nach dem Sprung auf den Morgen wäre `p`
## kleiner — dann bleibt die Sonne am Abend stehen.
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
	RenderingServer.global_shader_parameter_set(&"sun_sin", sin(deg_to_rad(e)))
