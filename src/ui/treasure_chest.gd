class_name TreasureChest
extends Control
## Schatzkiste, die man aufdrücken muss: zwei Sekunden lang draufhalten, dabei wackelt sie
## immer heftiger, dann springt der Deckel ab und das Gold fliegt heraus.
##
## Das Halten ist Absicht und kein Widerstand: ein Klick wäre in der Sekunde vorbei, in
## der der Blick noch auf der Statistik liegt. Zwei Sekunden Wackeln sind lang genug, dass
## das Aufgehen ein Ereignis ist — und sie sind der Grund, aus dem die Kiste überhaupt
## eine eigene Stufe im Wellenabschluss bekommt (siehe WaveStats).
##
## Gehalten wird mit der Maus AUF der Kiste oder mit Leertaste/Enter (`ui_accept`) — das
## Spiel wird mit der Tastatur gespielt, und der Griff zur Maus soll nicht die einzige
## Möglichkeit sein. Losgelassen wird zurückgesetzt, nicht weitergezählt: „gedrückt
## halten" heißt gedrückt halten.
##
## Die Kiste ist ein KayKit-Modell in einem SubViewport (siehe assets/models/CREDITS.md):
## dasselbe Pack, aus dem die Festung und die Fässer im Kampf kommen, mit demselben
## Texturatlas — die Kiste im Wellenabschluss sieht damit aus wie die Kisten im Spiel.
## Der Deckel ist im Modell ein eigener Knoten mit dem Scharnier als Ursprung, also lässt
## er sich einfach aufdrehen und wegschleudern; eine eingebackene Animation gibt es nicht
## und wird auch nicht gebraucht.
##
## `own_world_3d` ist gesetzt: der Wellenabschluss hängt IM Kampf, und ohne eigene Welt
## stünde die Kiste zwischen den Skeletten und ihr Licht in der Schlacht.
##
## Daneben gibt es die Kiste weiter GEZEICHNET (`use_model = false`, `_draw_chest`). Das
## ist kein Altbestand: in der Werkbank stehen beide Fassungen zum Vergleich, und fehlt
## das Modell einmal, zeichnet die Kiste sich eben selbst statt leer zu bleiben.
##
## Die herausfliegenden Münzen sind Modelle aus demselben Pack (`coin.gltf`) und fliegen
## IN dieser Welt: eine je Goldstück, taumelnd aus dem Kistenmaul heraus und unten aus
## dem Bild. Sie brauchen mehr Platz als die Kiste — deshalb ist der Ausschnitt GRÖSSER
## als das Widget (siehe STAGE_PAD und _layout_stage).
##
## Die gezeichnete Kiste behält ihre gezeichneten Münzen (day_coin.tscn, Zustand EARNED):
## ohne 3D-Welt gibt es nichts, worin ein Modell fliegen könnte.
##
## Die Kiste verbucht NICHTS. Sie sagt per `opened` nur, dass sie offen ist und wie viel
## drin war; das Gold bucht der Aufrufer (WaveRunner -> Wallet), die Zahl zeigt der
## Aufrufer. So ist dieselbe Kiste später auch am Tagesziel oder nach einem Boss zu haben.

## Der Deckel ist ab: `gold` ist der Inhalt, den der Aufrufer jetzt verbuchen darf.
## Kommt beim PLATZEN, nicht am Ende des Münzflugs — die Zahl soll neben den fliegenden
## Münzen stehen, nicht nach ihnen.
signal opened(gold: int)
## Das Aufdrücken hat begonnen bzw. wurde vor dem Ende losgelassen (für Hinweistexte).
signal hold_started
signal hold_cancelled

const COIN_SCENE := preload("res://scenes/ui/day_coin.tscn")

## So lange muss gedrückt werden. Der Wert im Spiel; `hold_time` ist die Stellschraube
## daneben, damit die Werkbank (scenes/dev/chest_lab.tscn) ihn ausprobieren kann, ohne
## dass eine Konstante zur Variablen mit zwei Bedeutungen wird.
const HOLD_TIME := 2.0
## Wackel-Frequenz (Hz) und Höchstauslenkung. Die Auslenkung wächst mit dem Fortschritt:
## am Anfang zittert die Kiste nur, am Ende schlägt sie aus.
const WOBBLE_HZ := 4.5
const WOBBLE_MAX_DEG := 9.0
const WOBBLE_MAX_SCALE := 0.08
## Das Modell hüpft beim Wackeln zusätzlich ein Stück (Modell-Einheiten) — eine reine
## Drehung sieht am Boden festgeschraubt aus, und die Kiste will raus.
const WOBBLE_HOP := 0.12

const COIN_FLIGHT := 1.0
const LID_TIME := 0.4
## Versatz zwischen zwei Münzen beim Herausfliegen und die Gesamtzeit, über die er sich
## verteilen darf. Der Versatz macht aus dem Schwung eine Garbe statt einer Wand; die
## Deckelung hält den großen Fund bei einem Platzen: 60 Münzen à 0,03 s wären knapp zwei
## Sekunden Nachschub, also ein Rinnsal.
const COIN_STAGGER := 0.03
const COIN_STAGGER_TOTAL := 0.5
## Der Münzflug in Modell-Einheiten: aus dem Kistenmaul heraus, Gipfel und Streuung,
## Umdrehungen unterwegs. Gefallen wird nicht auf einen Wert, sondern UNTER die Kante des
## Bildfelds (siehe _floor_y): eine Münze, die im Bild liegen bleibt, wäre kein Fund
## mehr, sondern Müll auf dem Tisch.
const COIN_MOUTH := Vector3(0.0, 0.62, 0.0)
const COIN_RISE := Vector2(1.1, 2.4)
const COIN_SPREAD := 2.0
const COIN_TURNS := Vector2(1.5, 3.5)

# --- Modell -------------------------------------------------------------------

const MODEL_DIR := "res://assets/models/props"
## EINE Kiste für alle Güten. `chest_gold` aus dem Pack ist keine goldene Kiste, sondern
## dieselbe Kiste mit einem Münzhaufen darin (1052 ihrer 1571 Vertices) — und dieser
## Haufen sind bei uns die fliegenden Münzen, er darf also nicht schon in der Kiste
## liegen. Die große Variante (`chest_large*`) fehlt aus einem anderen Grund: mit offenem
## Deckel passt sie nicht in den Ausschnitt, kleingerechnet ist sie nicht von dieser zu
## unterscheiden.
const CHEST_MODEL := "chest"
const COIN_MODEL := "coin"

## Der Beschlag der Güte kommt aus dem ATLAS, nicht aus einem Farbfilter.
##
## Der Texturatlas des Packs ist ein Raster aus 8×4 Farbfeldern, jedes ein senkrechter
## Verlauf von hell nach dunkel (die eingebackene Beleuchtung). Die Kiste benutzt genau
## zwei davon: Feld (1,0) für den grauen Beschlag, Feld (4,0) für das Holz — und KEIN
## Dreieck liegt in beiden. Verschiebt man die UV-Koordinaten der Beschlag-Vertices um
## ein ganzes Feld weiter, bekommt der Beschlag eine andere Farbe, das Holz behält seine,
## und der Verlauf bleibt erhalten, weil die Felder deckungsgleich im Raster liegen.
##
## Das ist der Grund, aus dem hier kein `material_override` mehr steht: ein Filter auf
## dem geteilten Atlas-Material hätte Holz und Beschlag gemeinsam getroffen (und mit dem
## Material auch die Fässer im Kampf).
const ATLAS_CELLS := Vector2i(8, 4)
const METAL_CELL := Vector2i(1, 0)
## Beschlag je Güte (Reihenfolge von ChestReward.Tier): dunkler Stahl, Kupfer, helles
## Silber, Gold. Das Gold ist Feld (7,2) — dasselbe Feld, aus dem die Münze ihre Farbe
## nimmt. Der Beschlag der Goldkiste hat also genau die Farbe dessen, was herausfliegt.
const TIER_METAL := [
	Vector2i(1, 0),
	Vector2i(6, 0),
	Vector2i(0, 1),
	Vector2i(7, 2),
]
## Kamera: dieselbe Blickrichtung wie im Kampf (orthografisch, von schräg oben), damit
## die Kiste nicht wie aus einem anderen Spiel aussieht. `CAM_SIZE` ist die Höhe des
## Bildfelds in Modell-Einheiten, `CAM_HEIGHT` der Punkt, auf den die Kamera zielt.
##
## Die Werte sind nicht nach Augenmaß gesetzt, sondern so, dass die Kiste MIT offenem
## Deckel im Widget bleibt (siehe tests/treasure_chest_test.gd). Ein aufgeklappter
## Deckel braucht die doppelte Höhe der zugesperrten Kiste — deshalb sitzt die Kiste im
## unteren Drittel; der Platz darüber ist der, durch den die Münzen fliegen.
##
## `CAM_SIZE` bezieht sich auf die HÖHE DES WIDGETS. Der gerenderte Ausschnitt ist um
## STAGE_PAD größer, das Bildfeld der Kamera also um denselben Faktor — sonst würde die
## Kiste kleiner, sobald man den Münzen mehr Platz gibt.
const CAM_PITCH := -22.0
const CAM_YAW := 35.0
const CAM_SIZE := 2.9
const CAM_DIST := 8.0
const CAM_HEIGHT := 0.88
const SUN_ROT := Vector3(-55.0, -35.0, 0.0)
const FILL_ROT := Vector3(-20.0, 150.0, 0.0)
## So weit steht der 3D-Ausschnitt je Seite über das Widget hinaus, als Anteil der
## Widget-Größe. Ein Control wird von Godot nicht beschnitten, ein SubViewport schon hart
## an seiner Kante — ohne dieses Polster wären die Münzen im Kistenfenster gefangen.
## Gezeichnet wird darin nur die Kiste und was fliegt; der Rest ist durchsichtig.
const STAGE_PAD := Vector2(0.5, 0.75)
## So weit dreht der Deckel auf, und so weit hebt er sich dabei vom Scharnier ab
## (Modell-Einheiten). Bewusst zurückhaltend: der Deckel soll aufschlagen und im Bild
## BLEIBEN. Der SubViewport schneidet hart an der Kante ab, ein weggeschleuderter Deckel
## wäre also kein Abflug, sondern ein Abschnitt — das Platzen machen Licht und Münzen.
const LID_OPEN_DEG := 70.0
const LID_FLY := 0.15

enum State {
	CLOSED,   ## Wartet auf das Aufdrücken.
	HOLDING,  ## Wird gerade gedrückt, wackelt.
	OPENED,   ## Deckel ab, Münzen fliegen bzw. sind geflogen.
}

## Farben je Güte für die GEZEICHNETE Kiste, in der Reihenfolge von ChestReward.Tier:
## [Korpus, Deckel, Beschlag]. Das Gold der Goldkiste ist dasselbe wie das der Münze
## (DayCoin.FACE_GOLD) — eine goldene Kiste voll Gold soll wie aus einem Stück aussehen.
const PALETTES := [
	[Color(0.42, 0.28, 0.16), Color(0.52, 0.35, 0.2), Color(0.58, 0.47, 0.32)],
	[Color(0.36, 0.24, 0.15), Color(0.45, 0.3, 0.18), Color(0.78, 0.48, 0.22)],
	[Color(0.28, 0.29, 0.34), Color(0.35, 0.36, 0.42), Color(0.8, 0.83, 0.88)],
	[Color(0.38, 0.29, 0.13), Color(0.47, 0.36, 0.16), Color(0.98, 0.84, 0.38)],
]
## Fortschrittsbalken unter der Kiste: gedämpfte Spur, bernsteinfarbene Füllung wie die
## Hinweistexte im Menü.
const TRACK := Color(0.25, 0.25, 0.3)
const FILL := Color(1.0, 0.8, 0.35)
## Licht, das beim Platzen aus der Kiste kommt.
const GLOW := Color(1.0, 0.9, 0.55)

## Haltezeit dieser Kiste. Voreingestellt ist HOLD_TIME; die Werkbank verstellt sie.
var hold_time: float = HOLD_TIME
## Modell oder Zeichnung. Umschaltbar für den Vergleich in der Werkbank; wirkt beim
## nächsten `present()`.
var use_model := true

var _state: State = State.CLOSED
var _tier: int = ChestReward.Tier.WOOD
var _gold: int = 0
var _hold: float = 0.0
## Deckel-Abflug 0..1 und Lichtring 0..1, von Tweens getrieben (siehe _burst).
var _lid: float = 0.0
var _burst_t: float = 0.0
var _mouse_held := false
## > 0: von Hand gesetzte Münzzahl (Werkbank), sonst aus dem Gold gerechnet.
var _coins_override := -1

@onready var _stage: SubViewportContainer = %Stage
@onready var _view: SubViewport = %View
@onready var _pivot: Node3D = %Pivot
## Zwei Münzschichten, von denen immer nur eine belegt ist: Modelle in der 3D-Welt,
## Zeichnungen in der 2D-Schicht darüber (für die gezeichnete Kiste).
@onready var _coins_3d: Node3D = %Coins3D
@onready var _coin_layer: Control = %Coins

var _model: Node3D = null
var _lid_node: Node3D = null
var _lid_home := Vector3.ZERO
## Alles, was für die AKTUELLE Kiste läuft: Deckel, Licht, Münzflüge. `present()` bricht
## sie ab, sonst zieht der Lichtring der vorigen Kiste über die neue hinweg — und ein
## Tween auf einer schon weggeräumten Münze meldet sich in der Konsole.
var _tweens: Array[Tween] = []


func _ready() -> void:
	# Die Kiste ist das anklickbare Element; Viewport und Münzschicht dürfen den Griff
	# nicht abfangen, sonst reißt eine im Weg liegende Münze das Halten ab (mouse_filter
	# steht in der Szene).
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_setup_view()
	_layout_stage()


## Kamera und Licht per Code, damit die .tscn keine Transform-Basis-Mathematik enthalten
## muss (wie in WaveRunner._setup_view).
func _setup_view() -> void:
	var cam_pivot := %CamPivot as Node3D
	cam_pivot.rotation_degrees = Vector3(CAM_PITCH, CAM_YAW, 0.0)
	cam_pivot.position = Vector3(0.0, CAM_HEIGHT, 0.0)
	var cam := %Cam as Camera3D
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = _cam_size()
	cam.position = Vector3(0.0, 0.0, CAM_DIST)
	(%Sun as DirectionalLight3D).rotation_degrees = SUN_ROT
	(%Fill as DirectionalLight3D).rotation_degrees = FILL_ROT


## Legt den 3D-Ausschnitt um STAGE_PAD über das Widget hinaus. Anker bleiben auf Vollbild,
## verschoben wird über die Offsets — so überlebt das Polster jeden Layout-Durchgang des
## übergeordneten Containers. Die Größe des SubViewports wird zusätzlich von Hand gesetzt:
## der Container tut das selbst erst bei seiner nächsten Größenänderung, und Tests (wie
## der Rahmen-Test) messen sofort.
func _layout_stage() -> void:
	if _stage == null:
		return
	var pad := (size * STAGE_PAD).round()
	_stage.offset_left = -pad.x
	_stage.offset_top = -pad.y
	_stage.offset_right = pad.x
	_stage.offset_bottom = pad.y
	# Vor dem ersten Layout-Durchgang ist die Größe noch 0 — ein SubViewport will mehr.
	_view.size = Vector2i((size + pad * 2.0).max(Vector2.ONE))


## Das Polster je Seite in Pixeln — die Nullstelle des Widgets im Ausschnitt.
func stage_pad() -> Vector2:
	return (size * STAGE_PAD).round()


## Höhe des Bildfelds in Modell-Einheiten. Wächst mit dem Polster, damit die Kiste im
## Widget immer gleich groß bleibt (siehe CAM_SIZE).
func _cam_size() -> float:
	return CAM_SIZE * (1.0 + 2.0 * STAGE_PAD.y)


## Unter dieser Höhe ist eine Münze aus dem Bild gefallen. Aus dem Bildfeld gerechnet und
## nicht als Konstante daneben: sonst hängen zwei Zahlen aneinander, von denen die eine
## still falsch wird, wenn man an der anderen dreht.
func _floor_y() -> float:
	return CAM_HEIGHT - _cam_size() * 0.5 - 0.4


## Stellt eine Kiste der Güte `tier` mit `gold` Inhalt hin — geschlossen und wartend.
## Mehrfach aufrufbar: dieselbe Kiste dient der nächsten Welle wieder.
##
## `coins` > 0 setzt die Zahl der herausfliegenden Münzen von Hand, statt eine je Gold
## zu nehmen (siehe coin_count). Das braucht die Werkbank, um den Effekt einzeln zu
## beurteilen; im Spiel bleibt es beim Standard -1.
func present(tier: int, gold: int, coins := -1) -> void:
	_kill_tweens()
	_clear_coins()
	_tier = clampi(tier, 0, TIER_METAL.size() - 1)
	_gold = maxi(0, gold)
	_coins_override = coins
	_state = State.CLOSED
	_hold = 0.0
	_lid = 0.0
	_burst_t = 0.0
	_mouse_held = false
	_build_model()
	_apply_wobble()
	tooltip_text = "%s — zum Öffnen 2 Sekunden gedrückt halten" % ChestReward.TIER_NAMES[_tier]
	set_process(true)
	queue_redraw()


func is_open() -> bool:
	return _state == State.OPENED


## Haltefortschritt 0..1 — die Anzeige zeichnet er selbst, der Wert ist für Tests und
## Hinweistexte.
func progress() -> float:
	return clampf(_hold / maxf(0.01, hold_time), 0.0, 1.0)


## Zahl der gerade fliegenden Münzen — Modelle wie Zeichnungen. Immer nur eine der beiden
## Schichten ist belegt (siehe _coins_3d), die Summe ist also die Zahl im Flug.
func coins_in_flight() -> int:
	return _coins_3d.get_child_count() + _coin_layer.get_child_count()


## Das gerade gezeigte Modell — null, wenn gezeichnet wird. Für Tests und Werkbank.
func model() -> Node3D:
	return _model


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT:
		return
	_mouse_held = button.pressed
	accept_event()


## Der Zeiger verlässt die Kiste, während gedrückt wird: das ist ein Loslassen. Sonst
## könnte man die Maus wegziehen und die Kiste ginge trotzdem auf.
func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_mouse_held = false
	elif what == NOTIFICATION_RESIZED:
		_layout_stage()
		queue_redraw()


func _process(delta: float) -> void:
	# Unsichtbare Knoten laufen weiter: ohne diesen Riegel würde eine gedrückte Leertaste
	# irgendwo im Wellenabschluss die noch nicht gezeigte Kiste aufdrücken.
	if not is_visible_in_tree():
		return
	if _state == State.OPENED:
		set_process(false)
		return
	var down := _mouse_held or Input.is_action_pressed("ui_accept")
	if _state == State.CLOSED:
		if down:
			begin_hold()
		return
	if down:
		hold(delta)
	else:
		cancel_hold()


# --- Aufdrücken ---------------------------------------------------------------
#
# Öffentlich, damit das Aufdrücken ohne Maus, ohne Fenster und ohne zwei Sekunden
# Wartezeit prüfbar ist (siehe tests/treasure_chest_test.gd). `_process` entscheidet nur,
# ob gerade gedrückt wird.

func begin_hold() -> void:
	if _state != State.CLOSED:
		return
	_state = State.HOLDING
	_hold = 0.0
	hold_started.emit()


## Schiebt den Haltefortschritt um `delta` Sekunden weiter und öffnet die Kiste, sobald
## HOLD_TIME erreicht ist.
func hold(delta: float) -> void:
	if _state != State.HOLDING:
		return
	_hold += delta
	_apply_wobble()
	queue_redraw()
	if _hold >= maxf(0.01, hold_time):
		_burst()


func cancel_hold() -> void:
	if _state != State.HOLDING:
		return
	_state = State.CLOSED
	_hold = 0.0
	_apply_wobble()
	queue_redraw()
	hold_cancelled.emit()


## Deckel ab: Licht, Münzflug, Meldung an den Aufrufer.
func _burst() -> void:
	_state = State.OPENED
	_hold = hold_time
	_apply_wobble()
	# Derselbe knappe Schlag wie ein erledigtes Monster — bis es einen eigenen
	# Kistenklang gibt, ist das der vorhandene „etwas platzt"-Laut im Spiel.
	Sfx.play(&"monster_kill")
	var tw := _new_tween()
	tw.set_parallel(true)
	# BACK schießt über und federt zurück: der Deckel schlägt auf, statt sanft zu öffnen.
	tw.tween_method(_set_lid, 0.0, 1.0, LID_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_method(_set_burst, 0.0, 1.0, COIN_FLIGHT * 0.6)
	_fly_coins()
	opened.emit(_gold)


## Deckelstellung 0..1: beim Modell dreht der eigene Deckel-Knoten um sein Scharnier auf
## und fliegt dabei weg, bei der Zeichnung fährt derselbe Wert die gezeichnete Klappe.
func _set_lid(value: float) -> void:
	_lid = value
	if _lid_node != null:
		_lid_node.rotation.x = deg_to_rad(-LID_OPEN_DEG * value)
		_lid_node.position = _lid_home + Vector3(0.0, LID_FLY * value, -LID_FLY * 0.35 * value)
	queue_redraw()


func _set_burst(value: float) -> void:
	_burst_t = value
	queue_redraw()


# --- Modell aufbauen ----------------------------------------------------------

## Hängt das Modell der aktuellen Güte unter den Pivot. Fehlt die Datei oder ist die
## Zeichnung gewählt, bleibt der Viewport aus und `_draw` übernimmt.
func _build_model() -> void:
	_lid_node = null
	if _model != null:
		_pivot.remove_child(_model)
		# Sofort und nicht per queue_free(): _lid_node zeigt eine Zeile höher schon auf
		# null, und der Deckel-Tween ist in present() abgebrochen.
		_model.free()
		_model = null
	_stage.visible = use_model
	if not use_model:
		return
	var path := "%s/%s.gltf" % [MODEL_DIR, CHEST_MODEL]
	if not ResourceLoader.exists(path):
		_stage.visible = false
		return
	_model = (load(path) as PackedScene).instantiate() as Node3D
	_pivot.add_child(_model)
	_lid_node = _find_lid(_model)
	if _lid_node != null:
		_lid_home = _lid_node.position
	_recolor_metal(_model, TIER_METAL[_tier])


## Der Deckel heißt im Pack wie das Modell mit `_lid` hinten dran (`chest_lid`) und hängt
## unter dem Korpus. Über den Namen gesucht und nicht über die Reihenfolge: die Reihenfolge
## der Kinder ist eine Eigenschaft des Exports, der Name eine des Packs.
func _find_lid(node: Node) -> Node3D:
	for child in node.get_children():
		if child is Node3D and child.name.ends_with("_lid"):
			return child as Node3D
		var deeper := _find_lid(child)
		if deeper != null:
			return deeper
	return null


## Gibt dem Beschlag die Farbe der Güte, indem seine UV-Koordinaten ein Atlas-Feld weiter
## rücken (siehe TIER_METAL). Das Holz bleibt unberührt, weil kein Dreieck in beiden
## Feldern liegt.
func _recolor_metal(node: Node, cell: Vector2i) -> void:
	if cell != METAL_CELL:
		var mesh := node as MeshInstance3D
		if mesh != null and mesh.mesh != null:
			mesh.mesh = _mesh_with_metal_cell(mesh.mesh, cell)
	for child in node.get_children():
		_recolor_metal(child, cell)


## Kopie des Meshes, in der die Beschlag-Vertices auf `cell` zeigen.
##
## `surface_get_arrays` gibt die Daten als KOPIE heraus, und das neue Mesh ist ein eigenes
## ArrayMesh — das Mesh aus dem Pack bleibt also unangetastet. Es muss auch: Godot hält
## geladene Ressourcen im Cache, eine Änderung daran träfe jede weitere Kiste und jedes
## andere Teil, das dasselbe Mesh benutzt.
func _mesh_with_metal_cell(source: Mesh, cell: Vector2i) -> ArrayMesh:
	var shift := Vector2(cell - METAL_CELL) / Vector2(ATLAS_CELLS)
	var out := ArrayMesh.new()
	for s in source.get_surface_count():
		var arrays := source.surface_get_arrays(s)
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		for i in uvs.size():
			if cell_of(uvs[i]) == METAL_CELL:
				uvs[i] += shift
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out.surface_set_material(s, source.surface_get_material(s))
	return out


## Atlas-Feld, in dem eine UV-Koordinate liegt. Öffentlich für den Test, der nachrechnet,
## welche Farbe der Beschlag je Güte bekommt.
static func cell_of(uv: Vector2) -> Vector2i:
	return Vector2i(int(uv.x * float(ATLAS_CELLS.x)), int(uv.y * float(ATLAS_CELLS.y)))


## Wackeln des Modells: drehen, kippen, hüpfen und größer werden, alles mit dem
## Fortschritt wachsend. Im gezeichneten Fall macht das `_draw` selbst.
func _apply_wobble() -> void:
	if _pivot == null:
		return
	if _state != State.HOLDING:
		_pivot.rotation = Vector3.ZERO
		_pivot.position = Vector3.ZERO
		_pivot.scale = Vector3.ONE
		return
	var p := progress()
	var swing := sin(_hold * TAU * WOBBLE_HZ)
	_pivot.rotation_degrees = Vector3(
		sin(_hold * TAU * WOBBLE_HZ * 0.5) * WOBBLE_MAX_DEG * 0.4 * p,
		swing * WOBBLE_MAX_DEG * 1.6 * p,
		0.0)
	_pivot.position = Vector3(0.0, absf(swing) * WOBBLE_HOP * p, 0.0)
	_pivot.scale = Vector3.ONE * (1.0 + WOBBLE_MAX_SCALE * p)


# --- Münzen -------------------------------------------------------------------

## Eine Münze je Goldstück, aus der Kiste heraus. Steht ein Modell, fliegen Modelle in
## der 3D-Welt; zeichnet sich die Kiste selbst, fliegen die gezeichneten Münzen.
func _fly_coins() -> void:
	var count := _coins_override if _coins_override > 0 else coin_count(_gold)
	if count <= 0:
		return
	if _model != null:
		_fly_coins_3d(count)
	else:
		_fly_coins_2d(count)


## Der Flug in der 3D-Welt: aus dem Kistenmaul hoch und auseinander, dabei taumelnd, dann
## unter die Kante des Bildfelds. Alle Münzen teilen Mesh und Material des Packs, es gibt
## also nichts zu kopieren — die Zahl der Münzen kostet Knoten und Tweens, nicht Material.
func _fly_coins_3d(count: int) -> void:
	var path := "%s/%s.gltf" % [MODEL_DIR, COIN_MODEL]
	if not ResourceLoader.exists(path):
		_fly_coins_2d(count)
		return
	var scene := load(path) as PackedScene
	var step := minf(COIN_STAGGER, COIN_STAGGER_TOTAL / float(count))
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in count:
		var coin := scene.instantiate() as Node3D
		_coins_3d.add_child(coin)
		coin.position = COIN_MOUTH + Vector3(
				rng.randf_range(-0.2, 0.2), 0.0, rng.randf_range(-0.15, 0.15))
		# Aufgestellt: die Münze liegt im Modell flach, als Scheibe ist sie zu erkennen.
		coin.rotation = Vector3(PI * 0.5, rng.randf() * TAU, 0.0)
		# Fächer über die ganze Breite, aber immer nach OBEN aus der Kiste heraus.
		var side := (float(i) + rng.randf()) / float(count) - 0.5
		var peak := coin.position + Vector3(
				side * COIN_SPREAD,
				rng.randf_range(COIN_RISE.x, COIN_RISE.y),
				rng.randf_range(-0.3, 0.3))
		var gone := Vector3(peak.x + side * COIN_SPREAD * 0.35, _floor_y(), peak.z)
		var delay := step * float(i)
		var tw := _new_tween()
		tw.tween_property(coin, "position", peak, COIN_FLIGHT * 0.45) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).set_delay(delay)
		tw.tween_property(coin, "position", gone, COIN_FLIGHT * 0.75) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		var turn := Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(COIN_TURNS.x, COIN_TURNS.y), 0.0)
		var spin := _new_tween()
		spin.tween_property(coin, "rotation", coin.rotation + turn * TAU, COIN_FLIGHT * 1.2) \
				.set_delay(delay)


## Der gezeichnete Flug: derselbe Bogen in 2D, für die gezeichnete Kiste. Die Münzen
## verblassen hier statt aus dem Bild zu fallen — die Schicht ist so groß wie das Widget.
func _fly_coins_2d(count: int) -> void:
	var center := size * 0.5
	# Bei vielen Münzen rücken sie zusammen, damit die Garbe nicht länger wird als der
	# Flug selbst (siehe COIN_STAGGER_TOTAL).
	var step := minf(COIN_STAGGER, COIN_STAGGER_TOTAL / float(count))
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in count:
		var coin := COIN_SCENE.instantiate() as DayCoin
		_coin_layer.add_child(coin)
		coin.setup(DayCoin.State.EARNED, false, "")
		coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var coin_size := coin.custom_minimum_size
		coin.position = center - coin_size * 0.5
		# Fächer über die ganze Breite, aber immer nach OBEN aus der Kiste heraus.
		var spread := (float(i) + rng.randf()) / float(count) - 0.5
		var peak := coin.position + Vector2(spread * size.x * 1.4, -size.y * rng.randf_range(0.5, 1.0))
		var fall := peak + Vector2(spread * size.x * 0.4, size.y * rng.randf_range(0.6, 1.1))
		var tw := _new_tween()
		tw.tween_property(coin, "position", peak, COIN_FLIGHT * 0.45) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT) \
				.set_delay(step * float(i))
		tw.tween_property(coin, "position", fall, COIN_FLIGHT * 0.55) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		var fade := _new_tween()
		fade.tween_property(coin, "modulate:a", 0.0, COIN_FLIGHT * 0.4) \
				.set_delay(step * float(i) + COIN_FLIGHT * 0.6)


## Ein Tween, den `present()` wieder loswird (siehe _tweens).
func _new_tween() -> Tween:
	var tw := create_tween()
	_tweens.append(tw)
	return tw


func _kill_tweens() -> void:
	for tw in _tweens:
		if tw != null and tw.is_valid():
			tw.kill()
	_tweens.clear()


## Die Münzen der vorigen Kiste sofort weg — nicht per queue_free() zum Frame-Ende
## vormerken: bis dahin hingen sie noch in der Schicht und wären mitgezählt. Ihre Tweens
## sind vorher abgebrochen (siehe _kill_tweens), also hält sie niemand mehr.
func _clear_coins() -> void:
	for layer: Node in [_coins_3d, _coin_layer]:
		for child in layer.get_children():
			layer.remove_child(child)
			child.free()


## So viele Münzen fliegen für `gold` heraus: genau eine je Goldstück. Der Haufen in der
## Luft IST der Fund — eine gedeckelte Zahl hätte gelogen, sobald die Wellen größer
## werden, und die Zahl der Münzen ist das erste, was man an der Kiste abliest.
static func coin_count(gold: int) -> int:
	return maxi(0, gold)


# --- Zeichnen -----------------------------------------------------------------
#
# Der Fortschrittsbalken und das Licht beim Platzen werden IMMER gezeichnet: sie liegen
# hinter dem (transparenten) Viewport. Der Korpus selbst nur, wenn kein Modell dasteht.

func _draw() -> void:
	var center := size * 0.5
	var p := progress()
	if _stage != null and _stage.visible:
		if _state == State.OPENED:
			_draw_glow(Vector2(center.x, center.y * 1.05), minf(size.x, size.y) * 0.28)
		else:
			_draw_progress(p)
		return
	# Nur die KISTE wackelt, der Fortschrittsbalken darunter nicht: ein mitschwingender
	# Balken ist nicht mehr zu lesen. Deshalb die Verschiebung im Zeichnen und nicht als
	# rotation/scale des Knotens — die nähme die Münzen und den Balken mit.
	var angle := 0.0
	var zoom := 1.0
	if _state == State.HOLDING:
		angle = sin(_hold * TAU * WOBBLE_HZ) * deg_to_rad(WOBBLE_MAX_DEG) * p
		zoom = 1.0 + WOBBLE_MAX_SCALE * p
	draw_set_transform(center, angle, Vector2.ONE * zoom)
	_draw_chest()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _state != State.OPENED:
		_draw_progress(p)


## Licht, das beim Platzen aus der Kiste kommt und mit dem Münzflug verblasst.
func _draw_glow(at: Vector2, radius: float) -> void:
	var r := radius * (1.0 + 1.4 * _burst_t)
	draw_circle(at, r, Color(GLOW, 0.35 * (1.0 - _burst_t)))
	draw_arc(at, r, 0.0, TAU, 32, Color(GLOW, 0.6 * (1.0 - _burst_t)), 2.0, true)


## Zeichnet die Kiste um den Ursprung (der ist per draw_set_transform die Mitte).
func _draw_chest() -> void:
	var palette: Array = PALETTES[_tier]
	var body_color: Color = palette[0]
	var lid_color: Color = palette[1]
	var fitting: Color = palette[2]

	var cw := minf(size.x * 0.78, size.y * 1.3)
	var ch := cw * 0.78
	var lid_h := ch * 0.4
	var top := -ch * 0.5
	var body := Rect2(-cw * 0.5, top + lid_h, cw, ch - lid_h)

	# Offene Kiste: erst das Licht aus dem Innenraum, dann der Korpus darüber.
	if _state == State.OPENED:
		_draw_glow(Vector2(0.0, top + lid_h), cw * 0.35)

	draw_rect(body, body_color)
	# Waagerechter Beschlag und senkrechter Riemen: erst die machen aus dem Kasten eine
	# Kiste.
	draw_rect(Rect2(body.position.x, body.position.y, body.size.x, body.size.y * 0.16), fitting)
	draw_rect(Rect2(-cw * 0.08, body.position.y, cw * 0.16, body.size.y), fitting)
	# Schloss.
	draw_rect(Rect2(-cw * 0.06, body.position.y + body.size.y * 0.3, cw * 0.12, ch * 0.16),
			Color(fitting, 0.9).lightened(0.2))

	# Deckel: fliegt beim Platzen nach oben weg und dreht sich dabei.
	var lid_rect := Rect2(-cw * 0.52, top, cw * 1.04, lid_h)
	if _lid <= 0.0:
		draw_rect(lid_rect, lid_color)
		draw_rect(Rect2(lid_rect.position.x, lid_rect.position.y + lid_h * 0.62,
				lid_rect.size.x, lid_h * 0.24), fitting)
		return
	var lift := -ch * 1.1 * _lid
	draw_set_transform(Vector2(cw * 0.15 * _lid, lift) + size * 0.5, -0.9 * _lid, Vector2.ONE)
	draw_rect(lid_rect, Color(lid_color, 1.0 - 0.7 * _lid))
	draw_rect(Rect2(lid_rect.position.x, lid_rect.position.y + lid_h * 0.62,
			lid_rect.size.x, lid_h * 0.24), Color(fitting, 1.0 - 0.7 * _lid))


## Fortschritt des Aufdrückens als Balken unter der Kiste. Er steht ruhig, während die
## Kiste wackelt — er ist die Auskunft, das Wackeln ist die Wirkung.
func _draw_progress(p: float) -> void:
	var track_h := 6.0
	var track_w := size.x * 0.6
	var origin := Vector2((size.x - track_w) * 0.5, size.y - track_h - 2.0)
	draw_rect(Rect2(origin, Vector2(track_w, track_h)), TRACK)
	if p > 0.0:
		draw_rect(Rect2(origin, Vector2(track_w * p, track_h)), FILL)
