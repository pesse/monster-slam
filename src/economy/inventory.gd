extends Node
## Vorrat an Zaubern des Profils (Autoload `Inventory`, docs/adr/0014-zauber-zum-verbrauchen.md).
## Zauber werden im Laden mit Gold gekauft und verbrauchen sich im Kampf; der Vorrat gehört
## zum Profil. Gespeichert werden nur die Plätze, je `{id, count}` oder `{}`. Ein leer
## gewordener Platz rückt nicht nach, damit die Taste eines Zaubers gleich bleibt. Die Zahl
## der Plätze wird gerechnet (`slot_count()`); Inhalt jenseits davon bleibt gespeichert.
## Datei: user://progress/<player_id>_inventory.json, über den SaveCoordinator (ADR 0024).

const SAVE_DIR := "user://progress"
const BASE_SLOTS := 4

## Der Vorrat hat sich geändert (Kauf, Einsatz, Profilwechsel).
signal changed()

var player_id: String = "default"
## Die Plätze; jeder ist `{"id": String, "count": int}` oder `{}`.
var slots: Array[Dictionary] = []
## Wer bezahlt: das Autoload `Wallet`, im Test eine eigene Instanz.
var wallet: Node
## Zusätzliche Plätze für Tests; -1 heißt: aus SkillBook.bonuses().
var extra_slots := -1


func _ready() -> void:
	wallet = Wallet
	player_id = UserSettings.active_profile()
	load_inventory()
	SaveCoordinator.register(self)
	UserSettings.active_profile_changed.connect(switch_to)


## Wie viele Plätze gerade zählen (Taste 1 bis slot_count()).
func slot_count() -> int:
	var extra := extra_slots if extra_slots >= 0 \
			else int(SkillBook.bonuses().get("item_slots", 0))
	return BASE_SLOTS + maxi(0, extra)


## Der Inhalt von Platz `index` (`{}`, wenn leer oder es den Platz nicht gibt).
func slot(index: int) -> Dictionary:
	if index < 0 or index >= mini(slots.size(), slot_count()):
		return {}
	return slots[index]


## Wie viele `id` im Vorrat liegen (über alle zählenden Plätze).
func count_of(id: String) -> int:
	var n := 0
	for i in mini(slots.size(), slot_count()):
		if str(slots[i].get("id", "")) == id:
			n += int(slots[i].get("count", 0))
	return n


## Der Platz, auf den ein weiterer `id` käme: sein Stapel, sonst der erste freie; -1, wenn
## keiner frei ist.
func slot_for(id: String) -> int:
	var free := -1
	for i in slot_count():
		var entry: Dictionary = slots[i] if i < slots.size() else {}
		if str(entry.get("id", "")) == id:
			return i
		if entry.is_empty() and free < 0:
			free = i
	return free


## True, wenn `spell` jetzt gekauft werden könnte: Platz da und Gold genug.
func can_buy(spell: Dictionary) -> bool:
	return slot_for(str(spell.get("id", ""))) >= 0 \
			and wallet.can_afford(maxi(0, int(spell.get("price", 0))))


## Kauft einen `spell` (Eintrag aus ContentRegistry.spells). False ohne freien Platz oder
## Gold; dann bleibt alles, wie es war.
func buy(spell: Dictionary) -> bool:
	var id := str(spell.get("id", ""))
	var at := slot_for(id)
	if id == "" or at < 0:
		return false
	var price := maxi(0, int(spell.get("price", 0)))
	# `Wallet.spend(0)` lehnt ab, ein Zauber für 0 Gold ist trotzdem zu haben.
	if price > 0 and not wallet.spend(price):
		return false
	while slots.size() <= at:
		slots.append({})
	slots[at] = {"id": id, "count": int(slots[at].get("count", 0)) + 1}
	_save()
	changed.emit()
	return true


## Nimmt einen Zauber von Platz `index` und gibt seine Id zurück ("" bei leerem Platz).
func take(index: int) -> String:
	var entry := slot(index)
	if entry.is_empty():
		return ""
	var left := int(entry.get("count", 0)) - 1
	slots[index] = {} if left <= 0 else {"id": entry["id"], "count": left}
	_save()
	changed.emit()
	return str(entry["id"])


func switch_to(id: String) -> void:
	player_id = id
	reload()


## Lädt den Vorrat des Profils neu und meldet ihn (Profilwechsel, verworfene Welle).
func reload() -> void:
	load_inventory()
	changed.emit()


# --- Persistenz ---------------------------------------------------------------

func _save_path() -> String:
	return "%s/%s_inventory.json" % [SAVE_DIR, player_id]


func save_path() -> String:
	return _save_path()


func save_suffix() -> String:
	return "_inventory"


func save_payload() -> Dictionary:
	return {"player_id": player_id, "slots": slots.duplicate(true)}


func _save() -> void:
	SaveCoordinator.mark_dirty(self)


## Lädt den Vorrat des aktuellen Profils; ohne Datei leer. Ein unbrauchbarer Platz wird leer,
## der Rest bleibt.
func load_inventory() -> void:
	slots.clear()
	var read := SaveStore.read(_save_path())
	if int(read["status"]) == SaveStore.Status.MISSING:
		return
	var parsed: Variant = read["data"]
	if int(read["status"]) != SaveStore.Status.OK or not ((parsed as Dictionary).get("slots") is Array):
		push_warning("Inventory: ungültiger Vorrat '%s'" % _save_path())
		return
	for raw: Variant in (parsed as Dictionary)["slots"]:
		var entry: Dictionary = raw if raw is Dictionary else {}
		var id := str(entry.get("id", ""))
		var count := int(entry.get("count", 0))
		slots.append({"id": id, "count": count} if id != "" and count > 0 else {})
