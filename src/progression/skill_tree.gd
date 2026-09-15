class_name SkillTree
extends RefCounted
## Die Regeln der Fähigkeitsbäume: was ein Knoten kostet, wann er lernbar ist und was das
## Gelernte im Lauf bewirkt.
##
## Reine Rechnung ohne Zustand, Szene und Autoload — deshalb statisch und für sich
## prüfbar (siehe tests/skill_tree_test.gd), genau wie Experience für die Erfahrung und
## ChestReward für das Gold. Wer die gelernten Knoten HÄLT, ist SkillBook; wer sie
## ANWENDET, sind GameState und SlowMotion.
##
## Jede Funktion bekommt die Einträge übergeben (ContentRegistry.skills.values()), statt
## sie selbst zu holen: so lässt sich jede Regel mit einer handvoll erfundener Knoten
## prüfen, ohne Autoload und ohne installierte Inhalte.
##
## Nicht zu verwechseln mit den ZAUBERN (data/spells/, ContentRegistry.spells): die sind
## aktiv, haben eine Abklingzeit und werden im Kampf ausgelöst. Skills sind dauerhaft und
## werden mit Skillpunkten gekauft (docs/adr/0003-skills-und-spells.md).

## Gold je zurückgegebenem Skillpunkt beim Umlernen. Kein Punkt geht verloren — bezahlt
## wird mit der anderen Währung, damit die Entscheidung revidierbar bleibt, ohne folgenlos
## zu sein.
const RESPEC_GOLD_PER_POINT := 25

## Untergrenze des Zeitlupen-Faktors. `Engine.time_scale` auf 0 wäre ein eingefrorenes
## Spiel: die Monster stünden still, aber auch die Haltedauer liefe weiter — der Lauf
## käme nie zum Ende. Der Baum darf also beliebig tief gehen, nur nicht bis zum Stillstand.
const MIN_SLOW_FACTOR := 0.05

## Die Effekt-Schlüssel, die es gibt. Steht hier und nicht verstreut in den Anwendern,
## damit ein Tippfehler in den Daten auffällt (tests/skill_data_test.gd) statt still
## wirkungslos zu bleiben. Alle Werte sind ADDITIV auf den Grundwert — es gibt keine
## Frage „welcher Knoten gewinnt", nur eine Summe.
const EFFECT_KEYS: Array[String] = [
	"heal_per_correct",
	"fortress_armor",
	"max_health",
	"slow_hold_ms",
	"slow_factor",
]


## Die Baum-Köpfe (kind == "tree"), in ihrer `order`. Bei gleichem `order` entscheidet die
## Id, damit die Reihenfolge nicht vom Zufall der Dateiliste abhängt.
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


## Die Knoten eines Baums, nach Stufen gebündelt: ein Array je Stufe, darin nach `branch`
## sortiert. Genau die Form, die der Screen zeichnet — eine Zeile je Stufe, darin die Äste
## nebeneinander.
##
## Gebündelt wird über die vorhandenen Stufen, nicht über 1..max: ein Baum darf später
## eine Stufe überspringen, ohne eine leere Zeile zu erzeugen.
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


## Sucht einen Knoten über seine Id. Ein leeres Dictionary heißt „gibt es nicht" — das ist
## kein Fehler, sondern der Normalfall nach einer Pack-Deinstallation.
static func node_by_id(entries: Array, id: String) -> Dictionary:
	for entry in entries:
		if str((entry as Dictionary).get("id", "")) == id:
			return entry
	return {}


static func cost(node: Dictionary) -> int:
	return maxi(0, int(node.get("cost", 1)))


## Sind alle Vorstufen gelernt? Ein Knoten ohne `requires` ist eine Wurzel.
static func requirements_met(node: Dictionary, unlocked: PackedStringArray) -> bool:
	for required in node.get("requires", []):
		if str(required) not in unlocked:
			return false
	return true


## Die erste noch fehlende Vorstufe — für die Beschriftung eines gesperrten Knotens
## („🔒 braucht Verband"). Leer, wenn nichts fehlt. Mit zwei Ästen nebeneinander ist sonst
## nicht zu sehen, welcher Knoten woran hängt.
static func missing_requirement(entries: Array, node: Dictionary,
		unlocked: PackedStringArray) -> String:
	for required in node.get("requires", []):
		if str(required) not in unlocked:
			var found := node_by_id(entries, str(required))
			return str(found.get("name", required))
	return ""


## Lernbar heißt: noch nicht gelernt, Vorstufen da, Punkte reichen.
static func can_unlock(node: Dictionary, unlocked: PackedStringArray, points_left: int) -> bool:
	if str(node.get("id", "")) in unlocked:
		return false
	if not requirements_met(node, unlocked):
		return false
	return points_left >= cost(node)


## Summe der Kosten aller gelernten Knoten. Gerechnet und nicht gespeichert — aus
## demselben Grund, aus dem PlayerLevel nur die Gesamt-Erfahrung sichert: ein zweiter
## Zähler könnte abweichen, und dann wäre nicht zu sagen, welcher stimmt.
##
## Eine Id, die die Einträge nicht kennen (Pack deinstalliert), zählt nicht mit — sie gibt
## auch keinen Bonus, also wäre sie sonst bezahlter Nichts.
static func spent(entries: Array, unlocked: PackedStringArray) -> int:
	var total := 0
	for id in unlocked:
		var node := node_by_id(entries, id)
		if not node.is_empty():
			total += cost(node)
	return total


## Alle Boni der gelernten Knoten, aufsummiert: Effekt-Schlüssel -> Betrag. Nur bekannte
## Schlüssel (EFFECT_KEYS) kommen durch; ein Tippfehler in den Daten wirkt damit nicht
## versehentlich woanders.
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


## Was das Umlernen kostet: Gold je zurückgegebenem Punkt. Ohne ausgegebene Punkte gibt es
## nichts zurückzunehmen und der Preis ist 0 — der Knopf sperrt dann ohnehin.
static func respec_cost(spent_points: int) -> int:
	return maxi(0, spent_points) * RESPEC_GOLD_PER_POINT
