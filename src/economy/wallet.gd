extends Node
## Geldbörse des Profils (Autoload `Wallet`).
##
## Gold ist die erste Währung des Spiels: verdient wird es als Schatzkiste am Ende einer
## Welle (siehe ChestReward und TreasureChest), ausgegeben später im Laden. Der Stand
## gehört zum PROFIL und nicht zum Lauf — deshalb steht er hier und nicht in GameState:
## eine gefallene Festung kostet den Lauf, nicht das Erspielte.
##
## Die drei Ebenen daneben: PlayerProgress hält den Lernstand pro Aufgabe, SessionLog den
## Verlauf je Lauf, GameState den Zustand des laufenden Laufs. Die Geldbörse ist die
## vierte und die einzige, die etwas ausgeben kann.
##
## Persistenz: JSON unter user://progress/<player_id>_wallet.json — dieselbe Ablage wie
## Fortschritt und Sitzungen, `user://` ist der einzige beschreibbare Ort. Gesichert wird
## SOFORT bei jeder Änderung und nicht erst am Laufende: verdientes Gold darf ein
## Absturz nicht kosten, und die Änderungen sind selten genug (eine Kiste je Welle),
## dass das nicht auffällt.

const SAVE_DIR := "user://progress"

## Der Goldstand hat sich geändert (neuer Stand). Die Anzeigen hängen daran, statt
## nachzufragen — der Stand ändert sich an mehreren Stellen (Kiste, später Laden).
signal changed(gold: int)

## Aktueller Goldstand des Profils.
var gold: int = 0
## Insgesamt je verdientes Gold — die Lebensleistung, unabhängig vom Ausgegebenen.
## Ausgaben ziehen von `gold` ab, nicht hiervon (Grundlage späterer Auszeichnungen).
var total_earned: int = 0
## Zahl der geöffneten Schatzkisten (Statistik; eine Kiste kann unterschiedlich viel
## Gold enthalten, deshalb ist das nicht aus `total_earned` ableitbar).
var chests_opened: int = 0
var player_id: String = "default"


func _ready() -> void:
	player_id = UserSettings.active_profile()
	load_wallet()
	# Profilwechsel mitschalten, damit Gold nicht im falschen Profil landet — dasselbe
	# Muster wie im SessionLog (der Wechsel wird an drei Stellen im UI ausgelöst).
	UserSettings.active_profile_changed.connect(switch_to)


## Bucht verdientes Gold. Nicht-positive Beträge sind kein Fehler, sondern nichts zu tun
## (eine Welle ohne besiegtes Monster) — ein `changed` dafür würde Anzeigen grundlos
## neu bauen.
func earn(amount: int, from_chest := false) -> void:
	if amount <= 0:
		return
	gold += amount
	total_earned += amount
	if from_chest:
		chests_opened += 1
	_save()
	changed.emit(gold)


## Gibt Gold aus, wenn es reicht; sonst bleibt der Stand unberührt und es kommt `false`
## zurück. Der Aufrufer entscheidet, was er dem Spieler dazu sagt — hier wird nur
## gerechnet.
func spend(amount: int) -> bool:
	if amount <= 0 or amount > gold:
		return false
	gold -= amount
	_save()
	changed.emit(gold)
	return true


## True, wenn der Stand für `amount` reicht (für das Ausgrauen von Kaufknöpfen).
func can_afford(amount: int) -> bool:
	return gold >= amount


## Goldstand als Text mit Tausenderpunkten: „1.240 Gold". Steht hier und nicht in jedem
## Screen, damit die Währung überall gleich aussieht.
func label(amount := -1) -> String:
	var value := amount if amount >= 0 else gold
	var digits := str(value)
	var out := ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			out += "."
		out += digits[i]
	return "%s Gold" % out


## Speichert den Stand und wechselt zum Profil `id` (lädt dessen Geldbörse).
func switch_to(id: String) -> void:
	_save()
	player_id = id
	gold = 0
	total_earned = 0
	chests_opened = 0
	load_wallet()


# --- Persistenz ---------------------------------------------------------------

func _save_path() -> String:
	return "%s/%s_wallet.json" % [SAVE_DIR, player_id]


func _save() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var payload := {
		"player_id": player_id,
		"gold": gold,
		"total_earned": total_earned,
		"chests_opened": chests_opened,
	}
	var file := FileAccess.open(_save_path(), FileAccess.WRITE)
	if file == null:
		push_warning("Wallet: konnte '%s' nicht schreiben" % _save_path())
		return
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()


## Lädt den Stand des aktuellen Profils. Keine Datei heißt „neues Profil": leere
## Geldbörse, kein Fehler.
func load_wallet() -> void:
	if not FileAccess.file_exists(_save_path()):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_save_path()))
	if not (parsed is Dictionary):
		push_warning("Wallet: ungültige Geldbörse '%s'" % _save_path())
		return
	var payload: Dictionary = parsed
	# maxi(0, …): eine handgeschriebene negative Zahl in der Datei wäre eine Schuld, die
	# das Spiel nicht kennt.
	gold = maxi(0, int(payload.get("gold", 0)))
	total_earned = maxi(0, int(payload.get("total_earned", gold)))
	chests_opened = maxi(0, int(payload.get("chests_opened", 0)))
