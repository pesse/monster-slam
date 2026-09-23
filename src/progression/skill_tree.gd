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

## Was der Spieler mit einem Knoten tun kann. Die Reihenfolge der Prüfung steckt in
## `state_of` und ist eine Regel, keine Anzeige-Entscheidung — deshalb steht sie hier und
## nicht im Screen.
enum State {
	LEARNED,        ## schon gelernt
	AVAILABLE,      ## Vorstufe erfüllt, Punkte reichen
	TOO_EXPENSIVE,  ## Vorstufe erfüllt, Punkte reichen nicht
	LOCKED,         ## Vorstufe fehlt
}

## Gold je zurückgegebenem Skillpunkt beim Umlernen. Kein Punkt geht verloren — bezahlt
## wird mit der anderen Währung, damit die Entscheidung revidierbar bleibt, ohne folgenlos
## zu sein.
const RESPEC_GOLD_PER_POINT := 25

## Untergrenze des Zeitlupen-Faktors. `Engine.time_scale` auf 0 wäre ein eingefrorenes
## Spiel: die Monster stünden still, aber auch die Haltedauer liefe weiter — der Lauf
## käme nie zum Ende. Der Baum darf also beliebig tief gehen, nur nicht bis zum Stillstand.
const MIN_SLOW_FACTOR := 0.05

## --- Wo ein Knoten im Netz steht ------------------------------------------------
##
## Der Screen zeichnet kein Raster aus Karten, sondern ein Netz: jeder Baum hat seinen
## EIGENEN Anfangspunkt, seine Knoten fächern von dort nach außen auf. Gerechnet wird das
## aus `tier` und `branch` — es steht KEINE Position in der JSON. Ein neuer Ast bleibt
## damit ein Eintrag in den Daten, und ein vierter Baum verschiebt die drei vorhandenen
## automatisch, statt dass jemand Koordinaten nachträgt.
##
## Die Rechnung steht hier und nicht im Screen, weil sie prüfbar sein muss: dass sich zwei
## Bäume nicht überlappen, ist eine Aussage über Zahlen und nicht über Pixel auf einem
## Bildschirm (tests/skill_graph_layout_test.gd).

## Abstand des Wurzelknotens von der Mitte des Netzes.
const ANCHOR_RADIUS := 150.0

## Abstand einer Stufe zur nächsten, nach außen.
const TIER_STEP := 120.0

## Radius eines gezeichneten Knotens. Steht hier, weil das Layout gegen ihn geprüft wird:
## zwei Knoten näher als zwei Radien wären zwei Knoten, die sich berühren.
const NODE_RADIUS := 34.0

## Anteil seines Sektors, den ein Baum auffächert. Bei drei Bäumen bekommt jeder 120°,
## davon 48° Fächer und 72° Abstand zum Nachbarn. Ein ANTEIL und keine feste Gradzahl,
## damit der Abstand zwischen den Bäumen auch beim vierten und fünften erhalten bleibt,
## statt aufgebraucht zu werden. Unter 0.5, damit zwischen zwei Bäumen immer mehr Platz
## ist als innerhalb eines Baums — daran erkennt man, was zusammengehört, noch bevor man
## die Farbe sieht.
const FAN_SHARE := 0.4

## Luft zwischen dem äußeren Rand eines Anfangsknotens und dem gemeinsamen Hof, auf dem
## alle Bäume beginnen. Der Hof umschließt die Anfangsknoten GANZ — er liegt hinter ihnen
## und nicht als Ring durch sie hindurch.
const ROOT_HALO_PAD := 16.0

## Obergrenze des Fächers. Ohne sie zöge ein einzelner Baum seine Äste über einen halben
## Kreis auseinander, nur weil niemand daneben steht.
const MAX_FAN := PI * 70.0 / 180.0

## Luft zwischen dem äußersten Knoten eines Baums und seiner Beschriftung. Der Name steht
## AUSSERHALB des Fächers auf dessen Achse, nicht an seinem Anfang: innen laufen die
## Linien zusammen, dort liegen bei mehreren Bäumen auch die Namen der Nachbarn — außen
## ist nichts. Der Abstand nimmt zusätzlich mit, dass unter jedem Knoten sein eigener Name
## hängt (`SkillGraph._draw_name`).
const TITLE_GAP := 56.0


## Die Effekt-Schlüssel, die es gibt. Steht hier und nicht verstreut in den Anwendern,
## damit ein Tippfehler in den Daten auffällt (tests/skill_data_test.gd) statt still
## wirkungslos zu bleiben. Alle Werte sind ADDITIV auf den Grundwert — es gibt keine
## Frage „welcher Knoten gewinnt", nur eine Summe.
const EFFECT_KEYS: Array[String] = [
	"heal_per_correct",
	"fortress_armor",
	"armor_regen",
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


## Der Zustand eines Knotens — in genau dieser Reihenfolge: gelernt schlägt gesperrt,
## gesperrt schlägt zu teuer. Sonst stünde an einem Knoten ohne Vorstufe „2 P. nötig", und
## der Spieler suchte die Punkte statt der Vorstufe.
static func state_of(node: Dictionary, unlocked: PackedStringArray, points_left: int) -> State:
	if str(node.get("id", "")) in unlocked:
		return State.LEARNED
	if not requirements_met(node, unlocked):
		return State.LOCKED
	if cost(node) > points_left:
		return State.TOO_EXPENSIVE
	return State.AVAILABLE


## Die Zustandszeile eines Knotens, wie sie im Tooltip und im Bestätigungs-Dialog steht.
## Sie gehört zu den REGELN und nicht zur Darstellung: dass ein gesperrter Knoten seine
## fehlende Vorstufe BEIM NAMEN nennt, ist eine Entscheidung über das Spiel und nicht über
## das Aussehen — im Netz hängt an einem Knoten mehr als eine Linie, und ein bloßes
## „gesperrt" sagt nicht, welche zuerst dran ist.
static func state_label(entries: Array, node: Dictionary, unlocked: PackedStringArray,
		points_left: int) -> String:
	match state_of(node, unlocked, points_left):
		State.LEARNED:
			return "✓ Gelernt"
		State.AVAILABLE:
			return "Klicken zum Lernen · %d P." % cost(node)
		State.TOO_EXPENSIVE:
			return "%d Skillpunkte nötig" % cost(node)
	return "🔒 braucht %s" % missing_requirement(entries, node, unlocked)


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


# --- Das Netz -----------------------------------------------------------------

## Wo jeder Knoten im Netz liegt: Id -> Position, Ursprung in der Mitte. Enthalten sind
## auch die BAUM-KÖPFE — deren Punkt ist der Anfangspunkt des Baums: er liegt zur Mitte
## hin vor der Wurzel und trägt im Screen den Namen.
##
## `tier` wird zum Radius, `branch` zum Winkel innerhalb des eigenen Fächers. Der Winkel
## kommt aus der POSITION in der Stufe und nicht aus dem Zahlenwert von `branch`: die
## Werte dürfen Lücken haben (ein Ast, der später dazwischenkommt), der Fächer soll
## trotzdem gleichmäßig bleiben.
static func layout(entries: Array) -> Dictionary:
	var out: Dictionary = {}
	var tree_list := trees(entries)
	var count := maxi(1, tree_list.size())
	var fan := minf(TAU / float(count) * FAN_SHARE, MAX_FAN)
	for i in tree_list.size():
		var tree_id := str((tree_list[i] as Dictionary).get("id", ""))
		# -PI/2: der erste Baum steht oben, die weiteren im Uhrzeigersinn daneben.
		var base := -PI * 0.5 + float(i) * TAU / float(count)
		# Der Platz des Baum-KOPFES ist der seines Namens, nicht der seines Anfangs: der
		# Kopf ist nichts, was man lernt. Wie weit außen er liegt, steht erst fest, wenn
		# die Stufen gezählt sind — deshalb unten.
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
				reach = maxf(reach, radius)
				out[str(node.get("id", ""))] = Vector2.from_angle(base + spread) * radius
		out[tree_id] = Vector2.from_angle(base) * (reach + NODE_RADIUS + TITLE_GAP)
	return out


## Radius des gemeinsamen Hofes um die Mitte. EIN Hof für alle Bäume: die Anfangspunkte
## sind getrennt, aber sie liegen alle auf demselben Abstand zur Mitte, und was sie
## verbindet, ist der Anfang selbst. Ein Hof je Baum hätte dreimal dasselbe gesagt.
##
## Der Radius steht hier und nicht im Screen, weil er eine Bedingung an das Layout ist:
## kein Knoten außer den Anfangsknoten darf hineinragen
## (tests/skill_graph_layout_test.gd).
static func root_halo_radius() -> float:
	return ANCHOR_RADIUS + NODE_RADIUS + ROOT_HALO_PAD


## Das Rechteck, in dem alle Knoten liegen — mit dem Knotenradius als Rand, damit ein
## Knoten am Rand nicht halb abgeschnitten wird. Leer, wenn es nichts zu zeichnen gibt.
static func bounds(positions: Dictionary) -> Rect2:
	if positions.is_empty():
		return Rect2()
	var box := Rect2(positions.values()[0], Vector2.ZERO)
	for point: Vector2 in positions.values():
		box = box.expand(point)
	return box.grow(NODE_RADIUS)


## Die Farbe eines Baums, aus seinem `color`-Feld (`"#5fd08a"`). Ohne Angabe ein neutrales
## Grau — ein Baum aus einem fremden Pack soll gezeichnet werden, nicht unsichtbar sein.
static func color_of(tree: Dictionary) -> Color:
	var raw := str(tree.get("color", ""))
	if raw.is_empty() or not Color.html_is_valid(raw):
		return Color(0.62, 0.66, 0.74)
	return Color.html(raw)


## Das Zeichen im Knoten. Ohne `icon` ein Stern — lieber ein sichtbarer Platzhalter als
## ein leerer Kreis, an dem niemand sieht, dass etwas fehlt.
static func icon_of(node: Dictionary) -> String:
	var icon := str(node.get("icon", ""))
	return icon if not icon.is_empty() else "\u2605"


# --- Was der Spieler davon hat ------------------------------------------------

## Der Stand EINES Baums: wie viele seiner Knoten gelernt sind, wie viele es gibt, und
## welche Boni dabei herauskommen. Steht hier und nicht im Screen, weil es dieselbe
## Rechnung ist wie `bonuses()` — nur auf einen Baum eingeschränkt.
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


## Der Stand eines Baums als EINE Zeile („2/5 gelernt · +2 HP je besiegtem Monster").
## Sie steht im Tooltip seines Namens und ist das, was früher am rechten Bildrand stand:
## wie weit der Baum ausgebaut ist und was er dafür bringt. Zusammengesetzt hier und
## nicht im Screen, weil beide Hälften schon hier gerechnet werden.
static func tree_status(entries: Array, unlocked: PackedStringArray,
		tree_id: String) -> String:
	var stand := tree_summary(entries, unlocked, tree_id)
	var line := "%d/%d gelernt" % [int(stand.get("learned", 0)), int(stand.get("total", 0))]
	var gains := effect_lines(stand.get("bonuses", {}))
	if gains.is_empty():
		return line
	return line + " · " + ", ".join(gains)


## Was ein Effektwert dem Spieler sagt. Die Sätze stehen bei den Schlüsseln, nicht im
## Screen: ein neuer Effekt bekommt seinen Namen und seine Beschriftung an derselben
## Stelle, sonst zeigt der Screen ihn als leere Zeile.
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
		"slow_hold_ms":
			return "+%s s Zeitlupe" % _decimal(value / 1000.0, 1)
		"slow_factor":
			return "Zeitlupe %s tiefer" % _decimal(absf(value), 2)
	return ""


## Alle Boni als lesbare Zeilen, in der Reihenfolge von EFFECT_KEYS. Ein Bonus von 0 fällt
## weg — „+0 Rüstung" ist keine Auskunft, sondern eine Zeile zum Überlesen.
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


## Zahl mit Komma statt Punkt — das Spiel spricht Deutsch.
static func _decimal(value: float, digits: int) -> String:
	return String.num(value, digits).replace(".", ",")
