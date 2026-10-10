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
## Fortschritt und Sitzungen, `user://` ist der einzige beschreibbare Ort. Gespeichert wird
## über den SaveCoordinator (ADR 0024): im Kampf an der Wellengrenze und nach der Kiste,
## im Menü (Laden, Verlernen) am Ende des Frames, zusammen mit dem, was der Kauf sonst
## geändert hat.

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

## Debug-Build: jeder Kauf geht, und nichts wird abgezogen — zum Ausprobieren von Laden und
## Bäumen, ohne erst Kisten zu sammeln. Nur das Autoload setzt das (in `_ready`); eine
## Instanz im Test rechnet mit dem echten Stand. Verdient und gespeichert wird weiter
## das echte Gold.
var unlimited_gold := false


func _ready() -> void:
	unlimited_gold = OS.is_debug_build()
	player_id = UserSettings.active_profile()
	load_wallet()
	SaveCoordinator.register(self)
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
	if amount > 0 and unlimited_gold:
		return true
	if amount <= 0 or amount > gold:
		return false
	gold -= amount
	_save()
	changed.emit(gold)
	return true


## True, wenn der Stand für `amount` reicht (für das Ausgrauen von Kaufknöpfen).
func can_afford(amount: int) -> bool:
	return unlimited_gold or gold >= amount


## Was der Debug-Build als eigenen Stand zeigt: eine Zahl, die wie Gold aussieht und in
## jede Plakette passt — kein „∞". Nur Anzeige; gerechnet wird mit `unlimited_gold`.
const DEBUG_SHOWN := 999_999_999


## Goldstand als Text mit Tausenderpunkten: „1.240 Gold". Steht hier und nicht in jedem
## Screen, damit die Währung überall gleich aussieht. Ohne Betrag der eigene Stand —
## im Debug-Build „999.999.999 Gold (Debug)".
func label(amount := -1) -> String:
	if amount < 0 and unlimited_gold:
		return "%s Gold (Debug)" % digits()
	return "%s Gold" % digits(amount)


## Nur die Zahl mit Tausenderpunkten — für Stellen, an denen das Gold schon als Münze
## dasteht (die Plakette im Menü). Im Debug-Build „999.999.999".
func digits(amount := -1) -> String:
	var value := amount if amount >= 0 else (DEBUG_SHOWN if unlimited_gold else gold)
	var text := str(value)
	var out := ""
	for i in text.length():
		if i > 0 and (text.length() - i) % 3 == 0:
			out += "."
		out += text[i]
	return out


## Wechselt zum Profil `id` (lädt dessen Geldbörse). Gespeichert ist der alte Stand schon
## (SaveCoordinator); eine Instanz ohne ihn schreibt bei jeder Änderung sofort.
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


## Lädt den Stand des aktuellen Profils. Keine Datei heißt „neues Profil": leere
## Geldbörse, kein Fehler.
func load_wallet() -> void:
	var read := SaveStore.read(_save_path())
	if int(read["status"]) == SaveStore.Status.MISSING:
		return
	if int(read["status"]) != SaveStore.Status.OK:
		push_warning("Wallet: ungültige Geldbörse '%s'" % _save_path())
		return
	var payload: Dictionary = read["data"]
	# maxi(0, …): eine handgeschriebene negative Zahl in der Datei wäre eine Schuld, die
	# das Spiel nicht kennt.
	gold = maxi(0, int(payload.get("gold", 0)))
	total_earned = maxi(0, int(payload.get("total_earned", gold)))
	chests_opened = maxi(0, int(payload.get("chests_opened", 0)))
