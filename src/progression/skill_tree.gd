class_name SkillTree
extends RefCounted
## Die Regeln der Fähigkeitsbäume: Kosten, Lernbarkeit, Wirkung und Platz eines Knotens.
## Reine Rechnung ohne Zustand über übergebene Einträge (ContentRegistry.skills.values());
## das Gelernte hält SkillBook. Skills sind dauerhaft und kosten Skillpunkte (ADR 0003).

## Was der Spieler mit einem Knoten tun kann; die Rangfolge steht in `state_of`.
enum State {
	LEARNED,        ## schon gelernt
	AVAILABLE,      ## Vorstufe erfüllt, Punkte reichen
	TOO_EXPENSIVE,  ## Vorstufe erfüllt, Punkte reichen nicht
	LOCKED,         ## Vorstufe fehlt
}

## Gold je zurückgegebenem Skillpunkt beim Umlernen.
const RESPEC_GOLD_PER_POINT := 25

## Gold je verlerntem Knoten (er selbst und alles, was über ihm hängt). Liegt unter
## RESPEC_GOLD_PER_POINT, damit einzeln verlernen nie teurer ist als alles umlernen.
const FORGET_GOLD_PER_NODE := 15

## Untergrenze des Zeitlupen-Faktors: bei `Engine.time_scale` 0 käme der Lauf nie zum Ende.
const MIN_SLOW_FACTOR := 0.05

## Untergrenze des Lauftempos der Monster (`monster_speed`), Anteil.
const MIN_MONSTER_PACE := 0.5

## --- Wo ein Knoten im Netz steht ------------------------------------------------
## Jeder Baum hat einen eigenen Anfangspunkt und fächert nach außen auf. Die Plätze werden
## aus `tier` und `branch` gerechnet, nicht in der JSON gespeichert. Einzelne Knoten setzt
## man von Hand (scenes/dev/skill_tree_lab.tscn, gespeichert in SkillLayout.PATH).

## Abstand des Wurzelknotens von der Mitte des Netzes, px.
const ANCHOR_RADIUS := 150.0

## Abstand einer Stufe zur nächsten, px.
const TIER_STEP := 120.0

## Radius eines gezeichneten Knotens, px. Das Layout wird gegen ihn geprüft.
const NODE_RADIUS := 34.0

## Anteil seines Sektors, den ein Baum auffächert. Unter 0.5, damit zwischen zwei Bäumen
## mehr Platz ist als innerhalb eines Baums.
const FAN_SHARE := 0.4

## Luft zwischen Anfangsknoten und dem Rand des gemeinsamen Hofes, px.
const ROOT_HALO_PAD := 16.0

## Obergrenze des Fächers, rad.
const MAX_FAN := PI * 70.0 / 180.0

## Luft zwischen dem äußersten Knoten eines Baums und seinem Namen auf der Fächerachse, px.
const TITLE_GAP := 32.0

## Streckung der Plätze je Achse, damit das Netz die 16:9-Fläche füllt; die Knoten bleiben
## rund. Senkrecht unter 0.85 rückt ein Knotenname an die nächste Stufe heran.
const STRETCH := Vector2(1.25, 0.85)


## Die Effekt-Schlüssel, die es gibt. Alle Werte addieren sich auf den Grundwert.
const EFFECT_KEYS: Array[String] = [
	"heal_per_correct",
	"fortress_armor",
	"armor_regen",
	"max_health",
	"slow_factor",
	"first_person",
	"walk_speed",
	"charge",
	"bow",
	"explosive_arrow",
	"auto_catapult",
	"fortress_tier_drop",
	"monster_speed",
	"spawn_gap",
	"item_slots",
]


## Die Baum-Köpfe (kind == "tree"), nach `order`, bei Gleichstand nach Id.
static func trees(entries: Array) -> Array:
	var out: Array = []
	for entry in entries:
		if str((entry as Dictionary).get("kind", "")) == "tree":
			out.append(entry)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("order", 0)) != int(b.get("order", 0)):
			return int(a.get("order", 0)) < int(b.get("order", 0))
		return str(a.get("id", "")) < str(b.get("id", "")))
	return out


## Die Knoten eines Baums, nach Stufen gebündelt: ein Array je vorhandener Stufe, darin
## nach `branch` sortiert.
static func tiers_of(entries: Array, tree_id: String) -> Array:
	var by_tier: Dictionary = {}
	for entry in entries:
		var node := entry as Dictionary
		if str(node.get("kind", "")) != "skill" or str(node.get("tree", "")) != tree_id:
			continue
		var tier := int(node.get("tier", 1))
		if not by_tier.has(tier):
			by_tier[tier] = []
		(by_tier[tier] as Array).append(node)
	var tiers: Array = by_tier.keys()
	tiers.sort()
	var out: Array = []
	for tier in tiers:
		var row: Array = by_tier[tier]
		row.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if int(a.get("branch", 0)) != int(b.get("branch", 0)):
				return int(a.get("branch", 0)) < int(b.get("branch", 0))
			return str(a.get("id", "")) < str(b.get("id", "")))
		out.append(row)
	return out


## Leer heißt „gibt es nicht“, etwa nach einer Pack-Deinstallation.
static func node_by_id(entries: Array, id: String) -> Dictionary:
	for entry in entries:
		if str((entry as Dictionary).get("id", "")) == id:
			return entry
	return {}


static func cost(node: Dictionary) -> int:
	return maxi(0, int(node.get("cost", 1)))


static func requirements_met(node: Dictionary, unlocked: PackedStringArray) -> bool:
	for required in node.get("requires", []):
		if str(required) not in unlocked:
			return false
	return true


## Name der ersten noch fehlenden Vorstufe, leer, wenn nichts fehlt.
static func missing_requirement(entries: Array, node: Dictionary,
		unlocked: PackedStringArray) -> String:
	for required in node.get("requires", []):
		if str(required) not in unlocked:
			var found := node_by_id(entries, str(required))
			return str(found.get("name", required))
	return ""


static func can_unlock(node: Dictionary, unlocked: PackedStringArray, points_left: int) -> bool:
	if str(node.get("id", "")) in unlocked:
		return false
	if not requirements_met(node, unlocked):
		return false
	return points_left >= cost(node)


## Der Zustand eines Knotens: gelernt schlägt gesperrt, gesperrt schlägt zu teuer.
static func state_of(node: Dictionary, unlocked: PackedStringArray, points_left: int) -> State:
	if str(node.get("id", "")) in unlocked:
		return State.LEARNED
	if not requirements_met(node, unlocked):
		return State.LOCKED
	if cost(node) > points_left:
		return State.TOO_EXPENSIVE
	return State.AVAILABLE


static func state_name(state: State) -> String:
	match state:
		State.LEARNED:
			return "Gelernt"
		State.AVAILABLE:
			return "Lernbar"
		State.TOO_EXPENSIVE:
			return "Zu teuer"
	return "Gesperrt"


## Summe der Kosten aller gelernten Knoten. Unbekannte Ids (Pack deinstalliert) zählen nicht.
static func spent(entries: Array, unlocked: PackedStringArray) -> int:
	var total := 0
	for id in unlocked:
		var node := node_by_id(entries, id)
		if not node.is_empty():
			total += cost(node)
	return total


## Summe der Boni aller gelernten Knoten: Effekt-Schlüssel -> Betrag, nur EFFECT_KEYS.
static func bonuses(entries: Array, unlocked: PackedStringArray) -> Dictionary:
	var out: Dictionary = {}
	for key in EFFECT_KEYS:
		out[key] = 0.0
	for id in unlocked:
		var node := node_by_id(entries, id)
		if node.is_empty():
			continue
		var effects: Dictionary = node.get("effects", {})
		for key in effects:
			if key in out:
				out[key] = float(out[key]) + float(effects[key])
	return out


## Faktor auf das Lauftempo der Monster, geklemmt auf MIN_MONSTER_PACE..1. Wirkt nach der
## Tempo-Formel des WaveGenerators und nicht auf Punkte und Erfahrung.
static func monster_pace(bonuses: Dictionary) -> float:
	return clampf(1.0 + float(bonuses.get("monster_speed", 0.0)), MIN_MONSTER_PACE, 1.0)


## Faktor auf den Abstand zwischen zwei Spawns (`spawn_gap`, Anteil), nie unter 1.
static func spawn_gap_scale(bonuses: Dictionary) -> float:
	return maxf(1.0, 1.0 + float(bonuses.get("spawn_gap", 0.0)))


static func respec_cost(spent_points: int) -> int:
	return maxi(0, spent_points) * RESPEC_GOLD_PER_POINT


## Was mit einem Knoten verlernt wird: er und alles Gelernte, was darüber hängt, in der
## Reihenfolge von `unlocked`. Leer, wenn er nicht gelernt ist.
static func forget_set(entries: Array, id: String,
		unlocked: PackedStringArray) -> PackedStringArray:
	if id not in unlocked:
		return PackedStringArray()
	var gone := PackedStringArray([id])
	# Bis nichts mehr dazukommt: `requires` zeigt nach unten, die Liste ist nicht nach Stufen sortiert.
	var grew := true
	while grew:
		grew = false
		for other in unlocked:
			if other in gone:
				continue
			var node := node_by_id(entries, other)
			for required in node.get("requires", []):
				if str(required) in gone:
					gone.append(other)
					grew = true
					break
	var out := PackedStringArray()
	for other in unlocked:
		if other in gone:
			out.append(other)
	return out


static func forget_cost(entries: Array, id: String, unlocked: PackedStringArray) -> int:
	return forget_set(entries, id, unlocked).size() * FORGET_GOLD_PER_NODE


# --- Das Netz -----------------------------------------------------------------

## Id -> Position im Netz, Ursprung in der Mitte; Baum-Köpfe mit dem Platz ihres Namens.
## `tier` wird zum Radius, die Position in der Stufe (nicht der Wert von `branch`) zum
## Winkel. `overrides` (aus SkillLayout) setzt einzelne Plätze.
static func layout(entries: Array, overrides: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {}
	var tree_list := trees(entries)
	var count := maxi(1, tree_list.size())
	var fan := minf(TAU / float(count) * FAN_SHARE, MAX_FAN)
	for i in tree_list.size():
		var tree_id := str((tree_list[i] as Dictionary).get("id", ""))
		# -PI/2: der erste Baum steht oben, die weiteren im Uhrzeigersinn.
		var base := -PI * 0.5 + float(i) * TAU / float(count)
		var reach := ANCHOR_RADIUS
		for tier in tiers_of(entries, tree_id):
			var row: Array = tier
			for j in row.size():
				var node: Dictionary = row[j]
				var spread := 0.0
				if row.size() > 1:
					spread = (float(j) / float(row.size() - 1) - 0.5) * fan
				var steps := maxi(1, int(node.get("tier", 1))) - 1
				var radius := ANCHOR_RADIUS + float(steps) * TIER_STEP
				var id := str(node.get("id", ""))
				var at: Vector2 = overrides.get(id, Vector2.from_angle(base + spread) * radius * STRETCH)
				# Ungestreckter Abstand von der Mitte, auch für gesetzte Plätze.
				reach = maxf(reach, (at / STRETCH).length())
				out[id] = at
		# Der Abstand des Namens wird nicht gestreckt, nur der Platz des Knotens darunter.
		var axis := Vector2.from_angle(base)
		out[tree_id] = overrides.get(tree_id, axis * reach * STRETCH + axis * (NODE_RADIUS + TITLE_GAP))
	return out


## Halbachsen des gemeinsamen Hofes um die Anfangsknoten aller Bäume, px. Eine Ellipse wegen
## `STRETCH`. Kein anderer Knoten darf hineinragen (tests/skill_graph_layout_test.gd).
static func root_halo_size() -> Vector2:
	return ANCHOR_RADIUS * STRETCH + Vector2.ONE * (NODE_RADIUS + ROOT_HALO_PAD)


## Das Rechteck um alle Knoten, mit dem Knotenradius als Rand. Leer ohne Knoten.
static func bounds(positions: Dictionary) -> Rect2:
	if positions.is_empty():
		return Rect2()
	var box := Rect2(positions.values()[0], Vector2.ZERO)
	for point: Vector2 in positions.values():
		box = box.expand(point)
	return box.grow(NODE_RADIUS)


## Die Farbe eines Baums aus seinem `color`-Feld (`"#5fd08a"`), sonst neutrales Grau.
static func color_of(tree: Dictionary) -> Color:
	var raw := str(tree.get("color", ""))
	if raw.is_empty() or not Color.html_is_valid(raw):
		return Color(0.62, 0.66, 0.74)
	return Color.html(raw)


## Das Zeichen im Knoten, ohne `icon` ein Stern.
static func icon_of(node: Dictionary) -> String:
	var icon := str(node.get("icon", ""))
	return icon if not icon.is_empty() else "\u2605"


# --- Was der Spieler davon hat ------------------------------------------------

## { learned, total, bonuses } eines Baums.
static func tree_summary(entries: Array, unlocked: PackedStringArray,
		tree_id: String) -> Dictionary:
	var own: Array = []
	var total := 0
	for entry in entries:
		var node := entry as Dictionary
		if str(node.get("kind", "")) != "skill" or str(node.get("tree", "")) != tree_id:
			continue
		total += 1
		own.append(node)
	var learned := PackedStringArray()
	for node: Dictionary in own:
		if str(node.get("id", "")) in unlocked:
			learned.append(str(node.get("id", "")))
	return {
		"learned": learned.size(),
		"total": total,
		"bonuses": bonuses(own, learned),
	}


## Der Stand eines Baums als eine Zeile („2/5 gelernt · +2 HP je besiegtem Monster“).
static func tree_status(entries: Array, unlocked: PackedStringArray,
		tree_id: String) -> String:
	var stand := tree_summary(entries, unlocked, tree_id)
	var line := "%d/%d gelernt" % [int(stand.get("learned", 0)), int(stand.get("total", 0))]
	var gains := effect_lines(stand.get("bonuses", {}))
	if gains.is_empty():
		return line
	return line + " · " + ", ".join(gains)


## Was ein Effektwert dem Spieler sagt. Ein neuer Effekt-Schlüssel braucht hier seine Zeile.
static func effect_label(key: String, value: float) -> String:
	match key:
		"heal_per_correct":
			return "+%d HP je besiegtem Monster" % int(round(value))
		"fortress_armor":
			return "+%d Rüstung" % int(round(value))
		"armor_regen":
			return "+%d Rüstung zurück je Welle" % int(round(value))
		"max_health":
			return "+%d maximales Leben" % int(round(value))
		"slow_factor":
			return "Zeitlupe %s tiefer" % _decimal(absf(value), 2)
		"first_person":
			return "Ich-Sicht freigeschaltet"
		"walk_speed":
			return "+%d %% Laufgeschwindigkeit" % int(round(value * 100.0))
		"charge":
			return "Sturmangriff bei jedem Treffer"
		"bow":
			return "Bogen in der Ich-Sicht"
		"explosive_arrow":
			return "Pfeile explodieren beim Treffer"
		"auto_catapult":
			return "Katapulte räumen Gemeistertes ab"
		"fortress_tier_drop":
			return "Festungsstufe 4 schon ab %d %%" % (
					int(FortressTier.THRESHOLDS_PERCENT[-1]) - int(round(value)))
		"monster_speed":
			return "Monster %d %% langsamer" % int(round(absf(value) * 100.0))
		"spawn_gap":
			return "+%d %% Abstand zwischen den Monstern" % int(round(value * 100.0))
		"item_slots":
			return "+%d Zauberplätze" % int(round(value))
	return ""


## Alle Boni als lesbare Zeilen in der Reihenfolge von EFFECT_KEYS, ohne Nullwerte.
static func effect_lines(values: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for key in EFFECT_KEYS:
		var value := float(values.get(key, 0.0))
		if is_zero_approx(value):
			continue
		var line := effect_label(str(key), value)
		if not line.is_empty():
			out.append(line)
	return out


static func _decimal(value: float, digits: int) -> String:
	return String.num(value, digits).replace(".", ",")
