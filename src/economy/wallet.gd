extends Node
## Geldbörse des Profils (Autoload `Wallet`).
## Gold wird als Schatzkiste am Ende einer Welle verdient (ChestReward) und im Laden
## ausgegeben. Der Stand gehört zum Profil, nicht zum Lauf. Datei:
## user://progress/<player_id>_wallet.json, gespeichert über den SaveCoordinator (ADR 0024).

const SAVE_DIR := "user://progress"

## Der Goldstand hat sich geändert (neuer Stand).
signal changed(gold: int)

var gold: int = 0
## Insgesamt je verdientes Gold, Ausgaben ziehen nur von `gold` ab.
var total_earned: int = 0
## Zahl der geöffneten Schatzkisten; nicht aus `total_earned` ableitbar.
var chests_opened: int = 0
var player_id: String = "default"

## Debug-Build: jeder Kauf geht, nichts wird abgezogen. Nur das Autoload setzt das; verdient
## und gespeichert wird weiter das echte Gold.
var unlimited_gold := false


func _ready() -> void:
	unlimited_gold = OS.is_debug_build()
	player_id = UserSettings.active_profile()
	load_wallet()
	SaveCoordinator.register(self)
	UserSettings.active_profile_changed.connect(switch_to)


## Bucht verdientes Gold. Nicht-positive Beträge werden ignoriert.
func earn(amount: int, from_chest := false) -> void:
	if amount <= 0:
		return
	gold += amount
	total_earned += amount
	if from_chest:
		chests_opened += 1
	_save()
	changed.emit(gold)


## Gibt Gold aus, wenn es reicht; sonst `false` und keine Änderung.
func spend(amount: int) -> bool:
	if amount > 0 and unlimited_gold:
		return true
	if amount <= 0 or amount > gold:
		return false
	gold -= amount
	_save()
	changed.emit(gold)
	return true


func can_afford(amount: int) -> bool:
	return unlimited_gold or gold >= amount


## Der im Debug-Build angezeigte Stand; gerechnet wird mit `unlimited_gold`.
const DEBUG_SHOWN := 999_999_999


## Goldstand als Text mit Tausenderpunkten: „1.240 Gold“. Ohne Betrag der eigene Stand,
## im Debug-Build mit „(Debug)“.
func label(amount := -1) -> String:
	if amount < 0 and unlimited_gold:
		return "%s Gold (Debug)" % digits()
	return "%s Gold" % digits(amount)


## Nur die Zahl mit Tausenderpunkten.
func digits(amount := -1) -> String:
	var value := amount if amount >= 0 else (DEBUG_SHOWN if unlimited_gold else gold)
	var text := str(value)
	var out := ""
	for i in text.length():
		if i > 0 and (text.length() - i) % 3 == 0:
			out += "."
		out += text[i]
	return out


func switch_to(id: String) -> void:
	player_id = id
	reload()


## Lädt den Stand des Profils neu und meldet ihn (Profilwechsel, verworfene Welle).
func reload() -> void:
	gold = 0
	total_earned = 0
	chests_opened = 0
	load_wallet()
	changed.emit(gold)


# --- Persistenz ---------------------------------------------------------------

func _save_path() -> String:
	return "%s/%s_wallet.json" % [SAVE_DIR, player_id]


func save_path() -> String:
	return _save_path()


func save_suffix() -> String:
	return "_wallet"


func save_payload() -> Dictionary:
	return {
		"player_id": player_id,
		"gold": gold,
		"total_earned": total_earned,
		"chests_opened": chests_opened,
	}


func _save() -> void:
	SaveCoordinator.mark_dirty(self)


## Lädt den Stand des aktuellen Profils; ohne Datei eine leere Geldbörse.
func load_wallet() -> void:
	var read := SaveStore.read(_save_path())
	if int(read["status"]) == SaveStore.Status.MISSING:
		return
	if int(read["status"]) != SaveStore.Status.OK:
		push_warning("Wallet: ungültige Geldbörse '%s'" % _save_path())
		return
	var payload: Dictionary = read["data"]
	# Negative Werte aus einer von Hand bearbeiteten Datei gelten als 0.
	gold = maxi(0, int(payload.get("gold", 0)))
	total_earned = maxi(0, int(payload.get("total_earned", gold)))
	chests_opened = maxi(0, int(payload.get("chests_opened", 0)))
