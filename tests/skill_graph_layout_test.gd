extends GdUnitTestSuite
## Wo die Knoten im Netz liegen — reine Zahlen, kein Screen.
##
## Das Netz hat keine Positionen in der JSON: `SkillTree.layout()` rechnet sie aus `tier`
## und `branch`. Damit ist ein vierter Baum eine Datei in data/skills/ und sonst nichts —
## aber nur, solange die Rechnung mitwächst. Genau das prüft diese Suite: dass Bäume sich
## nicht überlappen, dass jeder seinen EIGENEN Anfangspunkt hat und dass beides auch bei
## sechs Bäumen noch gilt.
##
## Geprüft an erfundenen Bäumen, nicht an den ausgelieferten: sonst hinge die Aussage
## „zwei Bäume überlappen sich nicht" an drei bestimmten Bäumen und fiele beim nächsten
## Ast um.


## `count` Bäume mit je einer Wurzel und zwei Ästen über drei Stufen — der Zuschnitt, auf
## den der Screen gebaut ist.
func _forest(count: int) -> Array:
	var out: Array = []
	for t in count:
		var tree_id := "tree.%d" % t
		out.append({"id": tree_id, "kind": "tree", "order": t, "name": "Baum %d" % t})
		out.append({"id": "%s.root" % tree_id, "kind": "skill", "tree": tree_id,
			"tier": 1, "branch": 0, "name": "Wurzel", "cost": 1, "requires": []})
		for branch in 2:
			out.append({"id": "%s.mid%d" % [tree_id, branch], "kind": "skill",
				"tree": tree_id, "tier": 2, "branch": branch, "name": "Mitte",
				"cost": 1, "requires": ["%s.root" % tree_id]})
			out.append({"id": "%s.tip%d" % [tree_id, branch], "kind": "skill",
				"tree": tree_id, "tier": 3, "branch": branch, "name": "Spitze",
				"cost": 2, "requires": ["%s.mid%d" % [tree_id, branch]]})
	return out


## Die Positionen nur der Knoten (ohne die Anfangspunkte der Bäume).
func _skill_places(entries: Array) -> Dictionary:
	var places := SkillTree.layout(entries)
	var out: Dictionary = {}
	for entry in entries:
		var node := entry as Dictionary
		if str(node.get("kind", "")) == "skill":
			out[str(node.get("id", ""))] = places[str(node.get("id", ""))]
	return out


# --- Vollständigkeit ----------------------------------------------------------

## Jeder Knoten UND jeder Baum-Kopf bekommt einen Platz. Ein Knoten ohne Platz würde
## stillschweigend auf dem Ursprung liegen — also mitten in einem anderen Baum.
func test_every_node_and_every_tree_gets_a_place() -> void:
	var entries := _forest(3)
	var places := SkillTree.layout(entries)
	for entry in entries:
		var id := str((entry as Dictionary).get("id", ""))
		assert_bool(places.has(id)).override_failure_message(
				"'%s' hat keinen Platz" % id).is_true()


func test_an_empty_forest_places_nothing() -> void:
	assert_dict(SkillTree.layout([])).is_empty()
	assert_bool(SkillTree.bounds({}).has_area()).is_false()


# --- Die Form eines Baums -----------------------------------------------------

## Eine Stufe weiter heißt weiter außen. Das ist die Leserichtung des Netzes: innen fängt
## man an, außen stehen die teuren Knoten.
func test_a_later_tier_sits_further_out() -> void:
	var places := SkillTree.layout(_forest(1))
	var root: Vector2 = places["tree.0.root"]
	var mid: Vector2 = places["tree.0.mid0"]
	var tip: Vector2 = places["tree.0.tip0"]
	assert_float(root.length()).is_less(mid.length())
	assert_float(mid.length()).is_less(tip.length())


## Zwei Äste derselben Stufe stehen nebeneinander, nicht übereinander — sonst wäre der
## Baum eine Kette und die Verzweigung nicht zu sehen.
func test_two_branches_of_a_tier_pull_apart() -> void:
	var places := SkillTree.layout(_forest(1))
	assert_float((places["tree.0.mid0"] as Vector2).distance_to(places["tree.0.mid1"])
			).is_greater(SkillTree.NODE_RADIUS * 2.0)
	# Und weiter außen weiter auseinander: der Fächer geht auf.
	assert_float((places["tree.0.tip0"] as Vector2).distance_to(places["tree.0.tip1"])
			).is_greater((places["tree.0.mid0"] as Vector2).distance_to(places["tree.0.mid1"]))


## Ein Ast bleibt auf seiner Linie: Mitte und Spitze desselben Astes stehen auf demselben
## Strahl, damit die Verbindungslinie gerade nach außen zeigt und nicht quer.
func test_a_branch_keeps_its_direction() -> void:
	var places := SkillTree.layout(_forest(1))
	var mid: Vector2 = places["tree.0.mid0"]
	var tip: Vector2 = places["tree.0.tip0"]
	assert_float(absf(mid.angle() - tip.angle())).is_less(0.001)


## Eine Stufe mit nur EINEM Knoten steht mittig im Fächer ihres Baums — die Wurzel hängt
## nicht an einem der beiden Äste.
func test_a_single_node_tier_sits_on_the_axis() -> void:
	var places := SkillTree.layout(_forest(1))
	var root: Vector2 = places["tree.0.root"]
	var mid0: Vector2 = places["tree.0.mid0"]
	var mid1: Vector2 = places["tree.0.mid1"]
	assert_float(absf(root.angle_to(mid0)) - absf(root.angle_to(mid1))
			).is_between(-0.001, 0.001)


# --- Getrennte Anfangspunkte --------------------------------------------------

## Jeder Baum hat seinen EIGENEN Anfangspunkt: es gibt keinen gemeinsamen Knoten in der
## Mitte, an dem alle hängen. Zwei Wurzeln dürfen deshalb nie am selben Fleck liegen — und
## zwei Namen auch nicht.
func test_every_tree_starts_at_its_own_point() -> void:
	var places := SkillTree.layout(_forest(3))
	for group: Array in [["tree.0.root", "tree.1.root", "tree.2.root"],
			["tree.0", "tree.1", "tree.2"]]:
		for i in group.size():
			for j in range(i + 1, group.size()):
				var gap: float = (places[group[i]] as Vector2).distance_to(places[group[j]])
				assert_float(gap).override_failure_message(
						"'%s' und '%s' liegen am selben Fleck" % [group[i], group[j]]
				).is_greater(SkillTree.NODE_RADIUS * 2.0)


## Der NAME eines Baums steht außen, jenseits seines äußersten Knotens auf der Achse des
## Fächers. Nicht am Anfang: dort laufen die Linien zusammen, dort liegen bei mehreren
## Bäumen auch die Namen der Nachbarn — und ein Name über einem Knoten verdeckt genau das,
## was er benennen soll.
func test_a_tree_label_sits_beyond_its_outermost_node() -> void:
	var places := SkillTree.layout(_forest(3))
	var label: Vector2 = places["tree.0"]
	for id: String in ["tree.0.root", "tree.0.mid0", "tree.0.tip1"]:
		assert_float(label.length()).override_failure_message(
				"Der Name steht nicht weiter außen als '%s'" % id
		).is_greater((places[id] as Vector2).length())


## Und er berührt keinen Knoten — auch keinen aus einem Nachbarbaum, und auch nicht bei
## sechs Bäumen, wo die Sektoren schmal werden.
func test_a_tree_label_touches_no_node() -> void:
	for count in [1, 2, 3, 4, 6]:
		var entries := _forest(count)
		var places := SkillTree.layout(entries)
		var nodes := _skill_places(entries)
		for tree in SkillTree.trees(entries):
			var tree_id := str((tree as Dictionary).get("id", ""))
			var label: Vector2 = places[tree_id]
			for id: String in nodes:
				var gap: float = label.distance_to(nodes[id])
				assert_float(gap).override_failure_message(
						"Bei %d Bäumen liegt der Name von '%s' nur %.1f px von '%s' weg"
						% [count, tree_id, gap, id]
				).is_greater(SkillTree.NODE_RADIUS)


# --- Die Bäume bleiben auseinander --------------------------------------------

## Kein Knoten berührt einen anderen — nicht im eigenen Baum und erst recht nicht im
## Nachbarbaum. Das ist die Aussage, die den ganzen Aufbau trägt: sie wird gerechnet und
## nicht am Bildschirm beurteilt.
func test_no_two_nodes_touch() -> void:
	for count in [1, 2, 3, 4, 6]:
		var places := _skill_places(_forest(count))
		var ids: Array = places.keys()
		for i in ids.size():
			for j in range(i + 1, ids.size()):
				var gap: float = (places[ids[i]] as Vector2).distance_to(places[ids[j]])
				assert_float(gap).override_failure_message(
						"Bei %d Bäumen liegen '%s' und '%s' nur %.1f px auseinander"
						% [count, ids[i], ids[j], gap]
				).is_greater(SkillTree.NODE_RADIUS * 2.0)


## Zwei Bäume teilen sich keinen Sektor: der äußerste Knoten des einen steht weiter von
## dem des anderen weg als von seinen eigenen Nachbarn. Anders gesagt — man sieht, welcher
## Knoten zu welchem Baum gehört, ohne die Farbe zu brauchen.
func test_a_tree_stays_in_its_own_sector() -> void:
	var places := SkillTree.layout(_forest(3))
	var own: float = (places["tree.0.tip0"] as Vector2).distance_to(places["tree.0.tip1"])
	var foreign: float = (places["tree.0.tip1"] as Vector2).distance_to(places["tree.1.tip0"])
	assert_float(foreign).is_greater(own)


# --- Der Rahmen ---------------------------------------------------------------

## `bounds()` umschließt jeden Knoten samt seinem Radius — sonst schnitte das Einpassen im
## Screen den äußersten Knoten halb ab.
func test_the_bounds_hold_every_node_with_its_radius() -> void:
	var entries := _forest(3)
	var places := SkillTree.layout(entries)
	var box := SkillTree.bounds(places)
	# Die Kanten werden EINSCHLIESSLICH geprüft: der äußerste Knoten liegt genau auf dem
	# Rand, und `Rect2.has_point` zählt die rechte und untere Kante nicht mehr dazu.
	# Achsen einzeln: assert_vector(...).is_less_equal(...) vergleicht lexikografisch, ein
	# zu tiefer Knoten rutschte über die x-Achse durch (siehe CLAUDE.md).
	# Ein Hauch Spiel auf der Kante: `Rect2` rechnet in 32-Bit-Floats, GDScript in 64 —
	# der äußerste Knoten liegt GENAU auf dem Rand, und dort unterscheiden sich die beiden
	# Rechnungen um Bruchteile eines Pixels.
	var slack := 0.01
	for id: String in places:
		var at: Vector2 = places[id]
		var reach := SkillTree.NODE_RADIUS
		assert_float(box.position.x - slack).override_failure_message(
				"'%s' ragt links heraus" % id).is_less_equal(at.x - reach)
		assert_float(box.position.y - slack).override_failure_message(
				"'%s' ragt oben heraus" % id).is_less_equal(at.y - reach)
		assert_float(box.end.x + slack).override_failure_message(
				"'%s' ragt rechts heraus" % id).is_greater_equal(at.x + reach)
		assert_float(box.end.y + slack).override_failure_message(
				"'%s' ragt unten heraus" % id).is_greater_equal(at.y + reach)


## Der GEMEINSAME Hof trägt genau die Anfangsknoten: die liegen ganz darin, jeder andere
## Knoten ganz außerhalb. Sonst sähe es aus, als gehörte eine zweite Stufe noch zum
## Anfang — und beim vierten Baum fällt so etwas zuerst auf.
func test_the_shared_halo_holds_exactly_the_starting_nodes() -> void:
	var halo := SkillTree.root_halo_radius()
	for count in [1, 2, 3, 4, 6]:
		var places := _skill_places(_forest(count))
		for id: String in places:
			var reach: float = (places[id] as Vector2).length()
			if id.ends_with(".root"):
				assert_float(reach + SkillTree.NODE_RADIUS).override_failure_message(
						"Bei %d Bäumen ragt '%s' aus dem Hof heraus" % [count, id]
				).is_less_equal(halo)
			else:
				assert_float(reach - SkillTree.NODE_RADIUS).override_failure_message(
						"Bei %d Bäumen ragt '%s' in den Hof hinein" % [count, id]
				).is_greater(halo)
