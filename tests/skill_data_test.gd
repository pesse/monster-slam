extends GdUnitTestSuite
## Die ausgelieferten Fähigkeitsbäume selbst — nicht die Regeln (die prüft
## tests/skill_tree_test.gd an einem erfundenen Baum), sondern die Daten unter
## data/skills/.
##
## Das ist die Stelle, an der ein neuer Ast still danebengeht: ein `requires`, das auf eine
## Id zeigt, die es nicht gibt, ein vergessenes `branch` oder ein Tippfehler im
## Effekt-Schlüssel kosten keine Fehlermeldung — der Knoten ist dann einfach nie lernbar
## oder wirkungslos. Wächst der Baum, wächst diese Prüfung mit, ohne dass jemand sie
## anfassen muss.
##
## Geprüft wird über ContentRegistry, also auf demselben Weg, den das Spiel nimmt — aber
## nur, was aus DIESEM Repo kommt (ContentRegistry.DATA_ROOT). Neben den Bäumen kann in
## derselben Kategorie Fremdes liegen: auf einem Rechner mit einem Pack von VOR der
## Umbenennung stehen dort noch die alten Zauber (docs/adr/0003-skills-und-spells.md).
## Tests müssen neben echten Packs gelten, deshalb prüft diese Suite die eigenen Daten und
## `test_foreign_entries_are_ignored` die Gleichgültigkeit gegenüber dem Rest.

var _entries: Array = []
var _nodes: Array = []


func before_test() -> void:
	_entries = []
	_nodes = []
	for entry in ContentRegistry.skills.values():
		var id := str((entry as Dictionary).get("id", ""))
		if ContentRegistry.origin("skills", id) != ContentRegistry.DATA_ROOT:
			continue
		_entries.append(entry)
		if str((entry as Dictionary).get("kind", "")) == "skill":
			_nodes.append(entry)


## Ohne Bäume hätte jede weitere Prüfung nichts zu tun und wäre still grün.
func test_the_trees_are_there() -> void:
	assert_int(SkillTree.trees(_entries).size()).is_greater_equal(3)
	assert_int(_nodes.size()).is_greater_equal(9)


## Jeder Eintrag der Kategorie ist entweder ein Baum-Kopf oder ein Knoten. Ein drittes
## `kind` wäre etwas, das niemand zeichnet.
func test_every_entry_is_a_tree_or_a_skill() -> void:
	for entry in _entries:
		var kind := str((entry as Dictionary).get("kind", ""))
		assert_bool(kind in ["tree", "skill"]).override_failure_message(
				"Eintrag '%s' hat kind '%s'" % [entry.get("id", "?"), kind]).is_true()


## Ein Knoten ohne Baum-Kopf würde nirgends gezeichnet.
func test_every_skill_belongs_to_a_declared_tree() -> void:
	var tree_ids: Array = []
	for tree in SkillTree.trees(_entries):
		tree_ids.append(str((tree as Dictionary).get("id", "")))
	for node in _nodes:
		assert_bool(str(node.get("tree", "")) in tree_ids).override_failure_message(
				"'%s' zeigt auf einen Baum, den es nicht gibt" % node.get("id", "?")
		).is_true()


## Stufe und Ast entscheiden, wo ein Knoten im Screen steht. Fehlt `branch`, landen zwei
## Äste übereinander in derselben Spalte — sichtbar erst im Spiel, nicht beim Laden.
func test_every_skill_has_a_place_a_price_and_an_effect() -> void:
	for node in _nodes:
		var id := str(node.get("id", "?"))
		assert_bool(node.has("tier")).override_failure_message("'%s' ohne tier" % id).is_true()
		assert_bool(node.has("branch")).override_failure_message("'%s' ohne branch" % id).is_true()
		assert_int(int(node.get("tier", 0))).override_failure_message(
				"'%s' hat tier %s" % [id, node.get("tier")]).is_greater_equal(1)
		assert_int(SkillTree.cost(node)).override_failure_message(
				"'%s' kostet nichts" % id).is_greater_equal(1)
		assert_bool((node.get("effects", {}) as Dictionary).is_empty()
				).override_failure_message("'%s' hat keine Wirkung" % id).is_false()
		assert_str(str(node.get("name", ""))).override_failure_message(
				"'%s' ohne Namen" % id).is_not_empty()
		assert_str(str(node.get("description", ""))).override_failure_message(
				"'%s' ohne Beschreibung" % id).is_not_empty()


## Ein unbekannter Schlüssel wird von SkillTree.bonuses verworfen — der Knoten wäre also
## bezahlt und wirkungslos.
func test_every_effect_key_is_known() -> void:
	for node in _nodes:
		for key in (node.get("effects", {}) as Dictionary):
			assert_bool(str(key) in SkillTree.EFFECT_KEYS).override_failure_message(
					"'%s' nennt den unbekannten Effekt '%s'" % [node.get("id", "?"), key]
			).is_true()


## Ein `requires`, das ins Leere zeigt, macht den Knoten unlernbar — und zwar stumm.
## Es muss zudem auf DENSELBEN Baum zeigen: eine Vorstufe aus einem anderen Baum stünde
## in keiner Stufe darüber und wäre für den Spieler nicht zu finden.
func test_every_requirement_points_into_the_same_tree() -> void:
	for node in _nodes:
		for required in node.get("requires", []):
			var target := SkillTree.node_by_id(_entries, str(required))
			assert_bool(target.is_empty()).override_failure_message(
					"'%s' braucht '%s' — gibt es nicht" % [node.get("id", "?"), required]
			).is_false()
			assert_str(str(target.get("tree", ""))).override_failure_message(
					"'%s' braucht '%s' aus einem anderen Baum" % [node.get("id", "?"), required]
			).is_equal(str(node.get("tree", "")))


## Eine Vorstufe steht ÜBER dem Knoten, nie daneben oder darunter — sonst zeigt der Screen
## eine Sperre, deren Auflösung weiter unten steht.
func test_a_requirement_sits_on_a_lower_tier() -> void:
	for node in _nodes:
		for required in node.get("requires", []):
			var target := SkillTree.node_by_id(_entries, str(required))
			assert_int(int(target.get("tier", 0))).override_failure_message(
					"'%s' braucht '%s' von derselben oder einer höheren Stufe"
					% [node.get("id", "?"), required]
			).is_less(int(node.get("tier", 0)))


## Jeder Baum hat genau eine Wurzel: mehrere Einstiege sind erlaubt, wenn sie einer
## späteren Erweiterung dienen — hier soll nur auffallen, wenn ein Baum GAR keinen hat
## und damit vollständig unerreichbar ist.
func test_every_tree_has_a_root() -> void:
	for tree in SkillTree.trees(_entries):
		var tree_id := str((tree as Dictionary).get("id", ""))
		var tiers := SkillTree.tiers_of(_entries, tree_id)
		assert_array(tiers).override_failure_message("Baum '%s' ist leer" % tree_id).is_not_empty()
		var roots := 0
		for node in _nodes:
			if str(node.get("tree", "")) == tree_id and (node.get("requires", []) as Array).is_empty():
				roots += 1
		assert_int(roots).override_failure_message(
				"Baum '%s' hat keinen Einstieg" % tree_id).is_greater_equal(1)


## Alle drei Bäume verzweigen sich — das ist der Zuschnitt, auf den der Screen gebaut ist
## (eine Zeile je Stufe, darin die Äste nebeneinander). Ein Baum, der als Kette gerät,
## würde hier auffallen, bevor er im Spiel langweilig aussieht.
func test_every_tree_actually_branches() -> void:
	for tree in SkillTree.trees(_entries):
		var tree_id := str((tree as Dictionary).get("id", ""))
		var widest := 0
		for tier in SkillTree.tiers_of(_entries, tree_id):
			widest = maxi(widest, (tier as Array).size())
		assert_int(widest).override_failure_message(
				"Baum '%s' hat keine Stufe mit zwei Ästen" % tree_id).is_greater_equal(2)


## Fremde Einträge in derselben Kategorie ändern nichts: die alten Zauber eines Packs von
## vor der Umbenennung tragen kein `kind`, und der Screen zeichnet nur, was `trees()` und
## `tiers_of()` durchlassen. Ohne diesen Filter stünden fünf Zauber ohne Baum im Screen.
func test_foreign_entries_are_ignored() -> void:
	var stranger := {"id": "spell.from.an.old.pack", "name": "Zeitlupe", "cooldown": 30.0}
	var mixed := _entries.duplicate()
	mixed.append(stranger)
	assert_int(SkillTree.trees(mixed).size()).is_equal(SkillTree.trees(_entries).size())
	for tree in SkillTree.trees(mixed):
		var tree_id := str((tree as Dictionary).get("id", ""))
		assert_array(SkillTree.tiers_of(mixed, tree_id)).is_equal(
				SkillTree.tiers_of(_entries, tree_id))


## Zwei Knoten derselben Stufe im selben Ast lägen im Screen übereinander.
func test_no_two_skills_share_a_place() -> void:
	var seen: Array[String] = []
	for node in _nodes:
		var place := "%s|%s|%s" % [node.get("tree", ""), node.get("tier", ""), node.get("branch", "")]
		assert_bool(place in seen).override_failure_message(
				"'%s' sitzt auf einem schon belegten Platz (%s)" % [node.get("id", "?"), place]
		).is_false()
		seen.append(place)
