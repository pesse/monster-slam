extends Node
## Vorrat an Zaubern des Profils (Autoload `Inventory`, docs/adr/0014-zauber-zum-verbrauchen.md).
##
## Zauber kauft man im Laden mit Gold, und sie verbrauchen sich im Kampf. Der Vorrat gehört
## wie das Gold zum PROFIL und nicht zum Lauf: eine gefallene Festung kostet nur, was
## eingesetzt wurde.
##
## Gespeichert werden nur die Plätze in ihrer Reihenfolge, je Platz `{id, count}` oder `{}`.
## Gleiche Zauber stapeln sich ohne Obergrenze; ein neuer Zauber braucht einen freien Platz.
## Ein leer gewordener Platz rückt nicht nach — die Taste eines Zaubers (1 bis n) bleibt
## dieselbe, solange er da ist. Wie viele Plätze es gibt, wird gerechnet
## (`slot_count()`: BASE_SLOTS plus `item_slots` aus SkillBook.bonuses()) und steht nicht
## in der Datei. Liegt etwas auf einem Platz jenseits der Zahl (Skills zurückgesetzt),
## bleibt es gespeichert und kommt mit dem Platz zurück.
##
## Persistenz: JSON unter user://progress/<player_id>_inventory.json, gesichert bei jeder
## Änderung wie die Geldbörse — ein gekaufter Zauber darf einen Absturz überstehen.

const SAVE_DIR := "user://progress"
const BASE_SLOTS := 4

## Der Vorrat hat sich geändert (Kauf, Einsatz, Profilwechsel).
signal changed()

var player_id: String = "default"
## Die Plätze; jeder ist `{"id": String, "count": int}` oder `{}`.
var slots: Array[Dictionary] = []
## Wer bezahlt — das Autoload `Wallet`, im Test eine eigene Instanz.
var wallet: Node
## Zusätzliche Plätze; ohne Wert gilt SkillBook.bonuses(). Für Tests.
var extra_slots := -1


func _ready() -> void:
	wallet = Wallet
	player_id = UserSettings.active_profile()
	load_inventory()
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


## Kauft einen `spell` (Eintrag aus ContentRegistry.spells). False, wenn kein Platz frei
## ist oder das Gold nicht reicht — dann bleibt alles, wie es war.
func buy(spell: Dictionary) -> bool:
	var id := str(spell.get("id", ""))
	var at := slot_for(id)
	if id == "" or at < 0:
		return false
	var price := maxi(0, int(spell.get("price", 0)))
	# `Wallet.spend(0)` lehnt ab — ein Zauber für 0 Gold ist trotzdem zu haben.
	if price > 0 and not wallet.spend(price):
		return false
	while slots.size() <= at:
		slots.append({})
	slots[at] = {"id": id, "count": int(slots[at].get("count", 0)) + 1}
	_save()
	changed.emit()
	return true


## Nimmt einen Zauber von Platz `index` und gibt seine Id zurück ("" bei leerem Platz).
## Der Platz bleibt stehen, wenn er leer wird (siehe Kopf).
func take(index: int) -> String:
	var entry := slot(index)
	if entry.is_empty():
		return ""
	var left := int(entry.get("count", 0)) - 1
	slots[index] = {} if left <= 0 else {"id": entry["id"], "count": left}
	_save()
	changed.emit()
	return str(entry["id"])


## Speichert den Vorrat und wechselt zum Profil `id` (lädt dessen Vorrat).
func switch_to(id: String) -> void:
	_save()
	player_id = id
	slots.clear()
	load_inventory()
	changed.emit()


# --- Persistenz ---------------------------------------------------------------

func _save_path() -> String:
	return "%s/%s_inventory.json" % [SAVE_DIR, player_id]


func _save() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var file := FileAccess.open(_save_path(), FileAccess.WRITE)
	if file == null:
		push_warning("Inventory: konnte '%s' nicht schreiben" % _save_path())
		return
	file.store_string(JSON.stringify({"player_id": player_id, "slots": slots}, "\t"))
	file.close()


## Lädt den Vorrat des aktuellen Profils. Keine Datei heißt „neues Profil": leerer Vorrat.
## Ein Platz mit unbrauchbarem Inhalt wird leer, statt den Rest zu verwerfen.
func load_inventory() -> void:
	slots.clear()
	if not FileAccess.file_exists(_save_path()):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_save_path()))
	if not (parsed is Dictionary) or not ((parsed as Dictionary).get("slots") is Array):
		push_warning("Inventory: ungültiger Vorrat '%s'" % _save_path())
		return
	for raw: Variant in (parsed as Dictionary)["slots"]:
		var entry: Dictionary = raw if raw is Dictionary else {}
		var id := str(entry.get("id", ""))
		var count := int(entry.get("count", 0))
		slots.append({"id": id, "count": count} if id != "" and count > 0 else {})
