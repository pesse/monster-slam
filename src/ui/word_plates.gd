class_name WordPlates
extends Control
## Die Wortschilder aller Monster, als 2D-Ebene über dem Kampf. Jedes Bild bekommt jedes
## Schild seinen Wunschplatz über dem Kopf seines Monsters; berühren sich zwei, rückt das
## spätere nach oben, bis es frei ist.
##
## 2D und nicht 3D: ein `Label3D` weiß nichts von den anderen, und in der Welt lässt sich
## „nicht überdecken" nicht ausdrücken. Hier ist es ein Rechteckvergleich im Bild.
##
## Reihenfolge: das Monster, das der Festung am nächsten ist, zuerst — es ist am
## dringendsten und behält seinen Platz. Ein verdrängtes Schild gleitet an seinen Platz
## (sonst zappelte es, wenn zwei Monster aneinander vorbeilaufen), und ist es ein Stück
## weg, führt eine dünne Linie vom Zipfel zum Kopf.
##
## Frei bleibt, was die Oberfläche belegt: Kopfleiste, Antwortfeld, Legende, Knopf. Diese
## Knoten stehen in der Gruppe KEEP_CLEAR_GROUP und zählen wie schon gelegte Schilder —
## ein Streifen über die ganze Breite wäre zu grob, die Kopfleiste belegt nur die Ecken.
##
## Die Monster melden sich nicht an: sie stehen in der Gruppe `Monster.PLATE_GROUP`, und
## die Ebene gleicht jedes Bild ab. So braucht weder der WaveRunner noch eine Werkbank
## eine Verbindung — und ein befreites Monster nimmt sein Schild einfach mit.

const PLATE_SCENE := preload("res://scenes/ui/word_plate.tscn")

## Abstand zwischen zwei Schildern, die sich ausweichen.
const GAP := 4.0
## Knoten der Oberfläche, über denen kein Schild stehen darf (in ihren .tscn gesetzt).
const KEEP_CLEAR_GROUP := &"word_plate_keep_clear"
## Abstand zum Bildrand.
const EDGE := 8.0
## Wie schnell ein verdrängtes Schild an seinen Platz gleitet (1/s).
const EASE := 14.0
## Ab dieser Verschiebung führt eine Linie vom Zipfel zum Kopf.
const LEADER_MIN := 6.0
const LEADER_COLOR := Color(0.78, 0.84, 0.94, 0.8)
## Seitlich ausweichen kostet so viel mehr als nach oben.
const SIDEWAYS_COST := 1.5
## Nach unten (Richtung Kopf und Monster) kostet so viel mehr als nach oben. Gebraucht wird
## es, wenn die Köpfe über dem freien Bereich liegen (Ich-Sicht, nahe Monster) und die
## oberste Reihe voll ist.
const DOWN_COST := 2.0
## Der Platz aus dem letzten Bild kostet nur diesen Anteil — ein Schild wechselt erst, wenn
## ein anderer Platz deutlich besser ist.
const KEEP_DISCOUNT := 0.5
## Kein Platz aus dem letzten Bild (neues oder eben wieder sichtbares Schild).
const NO_PREVIOUS := Vector2(INF, INF)

var _plates := {}  # Monster -> WordPlate
## Kopfpunkte der sichtbaren Schilder aus dem letzten Bild (für die Linien).
var _heads := {}  # WordPlate -> Vector2
var _last_ms := 0


func _process(_delta: float) -> void:
	# Echte Zeit statt `delta`: in der Zeitlupe sollen die Schilder nicht mitschleichen.
	var now := Time.get_ticks_msec()
	var dt := clampf((now - _last_ms) / 1000.0, 0.0, 0.1) if _last_ms > 0 else 0.0
	_last_ms = now
	_sync()
	var camera := get_viewport().get_camera_3d()
	var shown: Array = []
	for monster: Monster in _plates:
		var plate := _plates[monster] as WordPlate
		var at := monster.plate_anchor()
		# Ein Schild nur für ein Monster im Bild (Monster.in_view) — sonst klemmte eines neben
		# dem Bild sein Schild an den Rand, und die Antwort darauf ginge in der Ich-Sicht ins Leere.
		if camera == null or not monster.is_visible_in_tree() or not monster.in_view(camera):
			plate.visible = false
			continue
		var head := camera.unproject_position(at)
		var box := plate.plate_size()
		shown.append({"plate": plate, "head": head, "depth": monster.global_position.z,
				"wanted": Rect2(head - Vector2(box.x / 2.0, box.y), box)})
	shown.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["depth"] > b["depth"])
	var wanted: Array[Rect2] = []
	var previous: Array[Vector2] = []
	for entry in shown:
		wanted.append(entry["wanted"])
		var plate := entry["plate"] as WordPlate
		previous.append(plate.push if plate.visible else NO_PREVIOUS)
	var bounds := Rect2(Vector2(EDGE, EDGE), size - Vector2(2.0 * EDGE, 2.0 * EDGE))
	var placed := layout(wanted, previous, bounds, GAP, _keep_clear())
	_heads.clear()
	for i in shown.size():
		var plate := shown[i]["plate"] as WordPlate
		var goal: Vector2 = placed[i].position - wanted[i].position
		# Ein neues Schild steht sofort an seinem Platz, gleiten nur spätere Wechsel.
		plate.push = goal if not plate.visible else plate.push.lerp(goal, 1.0 - exp(-EASE * dt))
		plate.position = wanted[i].position + plate.push
		plate.visible = true
		# Das dringendste Schild zuletzt zeichnen: wo Platz fehlt, liegt es oben.
		move_child(plate, get_child_count() - 1 - i)
		_heads[plate] = shown[i]["head"]
	queue_redraw()


func _draw() -> void:
	for plate: WordPlate in _heads:
		if plate.push.length() > LEADER_MIN:
			draw_line(plate.tip(), _heads[plate], LEADER_COLOR, 2.0, true)


## Legt die Schilder der Reihe nach. Jedes nimmt den freien Platz, der seinem Wunschplatz
## am nächsten ist: den Wunschplatz selbst, seinen Platz aus dem letzten Bild (`previous`,
## Versatz gegenüber dem Wunschplatz, oder NO_PREVIOUS) oder einen Platz über, unter, links
## oder rechts neben einem schon gelegten Schild oder einer freizuhaltenden Fläche
## (`blocked`, wird wie ein gelegtes Schild behandelt, aber nicht zurückgegeben). Seitlich und nach unten kostet mehr als
## nach oben (der Zipfel soll über dem Kopf bleiben), der alte Platz weniger (Ruhe). Ist nichts frei, bleibt es
## am Wunschplatz — lieber überlappen als aus dem Bild laufen.
static func layout(wanted: Array[Rect2], previous: Array[Vector2], bounds: Rect2,
		gap: float, blocked: Array[Rect2] = []) -> Array[Rect2]:
	var placed: Array[Rect2] = blocked.duplicate()
	for i in wanted.size():
		var want := _clamped(wanted[i], bounds)
		var spots: Array[Vector2] = [want.position]
		var old: Vector2 = previous[i] if i < previous.size() else NO_PREVIOUS
		if old != NO_PREVIOUS:
			spots.append(wanted[i].position + old)
		var w := want.size
		for other in placed:
			spots.append(Vector2(want.position.x, other.position.y - gap - w.y))
			spots.append(Vector2(other.position.x - gap - w.x, want.position.y))
			spots.append(Vector2(other.end.x + gap, want.position.y))
			spots.append(Vector2(other.position.x - gap - w.x, other.position.y))
			spots.append(Vector2(other.end.x + gap, other.position.y))
			spots.append(Vector2(want.position.x, other.end.y + gap))
			spots.append(Vector2(other.position.x, other.end.y + gap))
		var best := want
		var best_cost := INF
		for j in spots.size():
			var r := _clamped(Rect2(spots[j], w), bounds)
			if _hits(r, placed, gap):
				continue
			var d := r.position - wanted[i].position
			var cost := absf(d.x) * SIDEWAYS_COST + absf(d.y) * (DOWN_COST if d.y > 0.0 else 1.0)
			if j == 1 and old != NO_PREVIOUS:
				cost *= KEEP_DISCOUNT
			if cost < best_cost:
				best_cost = cost
				best = r
		placed.append(best)
	return placed.slice(blocked.size())


static func _clamped(r: Rect2, bounds: Rect2) -> Rect2:
	r.position.x = clampf(r.position.x, bounds.position.x, maxf(bounds.position.x, bounds.end.x - r.size.x))
	r.position.y = clampf(r.position.y, bounds.position.y, maxf(bounds.position.y, bounds.end.y - r.size.y))
	return r


static func _hits(r: Rect2, placed: Array[Rect2], gap: float) -> bool:
	for other in placed:
		if r.grow(gap / 2.0).intersects(other.grow(gap / 2.0)):
			return true
	return false

func _keep_clear() -> Array[Rect2]:
	var out: Array[Rect2] = []
	var to_local := get_global_transform().affine_inverse()
	for node in get_tree().get_nodes_in_group(KEEP_CLEAR_GROUP):
		var control := node as Control
		if control != null and control.is_visible_in_tree():
			out.append(to_local * control.get_global_rect())
	return out


## Die Sicht hat gewechselt (WaveRunner._toggle_view): jedes Schild neu, in der Größe, die
## `Monster.screen_sized_label` jetzt sagt. Gebaut werden sie im nächsten Bild von `_sync`.
func restyle() -> void:
	for plate: WordPlate in _plates.values():
		plate.queue_free()
	_plates.clear()
	_heads.clear()
	queue_redraw()


func _sync() -> void:
	# Ungetypt: ein befreites Monster ließe sich keiner Monster-Variablen zuweisen.
	for key in _plates.keys():
		if not is_instance_valid(key) or not (key as Node).is_inside_tree():
			(_plates[key] as WordPlate).queue_free()
			_plates.erase(key)
	for node in get_tree().get_nodes_in_group(Monster.PLATE_GROUP):
		var monster := node as Monster
		if monster == null or _plates.has(monster):
			continue
		var plate := PLATE_SCENE.instantiate() as WordPlate
		plate.visible = false
		add_child(plate)
		plate.setup(monster, monster.screen_sized_label)
		_plates[monster] = plate
