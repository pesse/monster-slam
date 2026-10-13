extends Node
## Die gelernten Skills des Profils (Autoload `SkillBook`).
## Hält genau eine Liste, die Ids der gelernten Knoten; Punkte und Boni rechnet SkillTree
## daraus. Gekauft wird mit Skillpunkten (PlayerLevel), verlernt gegen Gold (Wallet). Datei:
## user://progress/<player_id>_skills.json, gespeichert über den SaveCoordinator (ADR 0024).

const SAVE_DIR := "user://progress"

## Die gelernten Skills haben sich geändert (Kauf, Verlernen, Umlernen, Profilwechsel).
signal changed()

## Ids der gelernten Knoten, die einzige gespeicherte Größe.
var unlocked: PackedStringArray = PackedStringArray()
var player_id: String = "default"

## Debug-Build: unbegrenzt Punkte zum Ausprobieren. Nur das Autoload setzt das; Instanzen
## im Test rechnen mit den echten Punkten.
var unlimited_points := false
const UNLIMITED_POINTS := 999


func _ready() -> void:
	unlimited_points = OS.is_debug_build()
	player_id = UserSettings.active_profile()
	load_skills()
	SaveCoordinator.register(self)
	UserSettings.active_profile_changed.connect(switch_to)


## Die Knoten, aus denen gerechnet wird. Eine Funktion, weil die Registry nach jeder
## Pack-Installation neu lädt.
func entries() -> Array:
	return ContentRegistry.skills.values()


## Verdiente minus ausgegebene Punkte.
func available() -> int:
	if unlimited_points:
		return UNLIMITED_POINTS
	return PlayerLevel.skill_points() - SkillTree.spent(entries(), unlocked)


func is_unlocked(id: String) -> bool:
	return id in unlocked


## Lernt einen Skill, wenn Vorstufen und Punkte reichen; sonst `false` und keine Änderung.
func unlock(id: String) -> bool:
	var list := entries()
	var node := SkillTree.node_by_id(list, id)
	if node.is_empty():
		return false
	if not SkillTree.can_unlock(node, unlocked, available()):
		return false
	unlocked.append(id)
	_save()
	changed.emit()
	return true


## Verlernt einen Knoten gegen Gold, mit jedem gelernten Knoten, der über ihm hängt
## (`SkillTree.forget_set`). Reicht das Gold nicht oder ist er nicht gelernt: `false`.
func forget(id: String) -> bool:
	var list := entries()
	var gone := SkillTree.forget_set(list, id, unlocked)
	if gone.is_empty():
		return false
	var price := SkillTree.forget_cost(list, id, unlocked)
	# `Wallet.spend(0)` lehnt ab, also nur zahlen, wenn es etwas kostet.
	if price > 0 and not Wallet.spend(price):
		return false
	var kept := PackedStringArray()
	for other in unlocked:
		if other not in gone:
			kept.append(other)
	unlocked = kept
	_save()
	changed.emit()
	return true


func forget_cost(id: String) -> int:
	return SkillTree.forget_cost(entries(), id, unlocked)


## Gibt alle Punkte zurück gegen Gold je ausgegebenem Punkt (`RESPEC_GOLD_PER_POINT`).
func respec() -> bool:
	var spent := SkillTree.spent(entries(), unlocked)
	if spent <= 0:
		return false
	if not Wallet.spend(SkillTree.respec_cost(spent)):
		return false
	unlocked = PackedStringArray()
	_save()
	changed.emit()
	return true


func respec_cost() -> int:
	return SkillTree.respec_cost(SkillTree.spent(entries(), unlocked))


## Die Boni des Laufs: Effekt-Schlüssel -> Betrag, additiv auf die Grundwerte.
func bonuses() -> Dictionary:
	return SkillTree.bonuses(entries(), unlocked)


func switch_to(id: String) -> void:
	player_id = id
	reload()


## Lädt den Stand des Profils neu und meldet ihn.
func reload() -> void:
	unlocked = PackedStringArray()
	load_skills()
	changed.emit()


# --- Persistenz ---------------------------------------------------------------

func _save_path() -> String:
	return "%s/%s_skills.json" % [SAVE_DIR, player_id]


func save_path() -> String:
	return _save_path()


func save_suffix() -> String:
	return "_skills"


func save_payload() -> Dictionary:
	# `spent_points` nur zum Mitlesen; geladen wird nur `unlocked`.
	return {
		"player_id": player_id,
		"unlocked": Array(unlocked),
		"spent_points": SkillTree.spent(entries(), unlocked),
	}


func _save() -> void:
	SaveCoordinator.mark_dirty(self)


## Lädt den Stand des aktuellen Profils. Ohne Datei: nichts gelernt.
func load_skills() -> void:
	var read := SaveStore.read(_save_path())
	if int(read["status"]) == SaveStore.Status.MISSING:
		return
	if int(read["status"]) != SaveStore.Status.OK:
		push_warning("SkillBook: ungültige Datei '%s'" % _save_path())
		return
	var payload: Dictionary = read["data"]
	var list := PackedStringArray()
	for id in payload.get("unlocked", []):
		# Doppelte Einträge würden doppelt abgerechnet.
		if str(id) not in list:
			list.append(str(id))
	unlocked = list
