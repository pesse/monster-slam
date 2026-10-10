extends Node
## Erfahrung und Level des Profils (Autoload `PlayerLevel`).
##
## Verdient wird Erfahrung an besiegten Monstern (Experience.for_monster, verbucht im
## WaveRunner). Wie das Gold gehört sie zum PROFIL und nicht zum Lauf: eine gefallene
## Festung kostet den Lauf, nicht das Gelernte.
##
## Die Ebenen daneben: PlayerProgress hält den Lernstand pro Aufgabe, SessionLog den
## Verlauf je Lauf, GameState den Zustand des laufenden Laufs, Wallet das Gold. Dieses
## Autoload ist die fünfte und hält genau eine Zahl: die Gesamt-Erfahrung.
##
## GENAU EINE Zahl, und alles andere ist daraus gerechnet (Experience): Level,
## Levelfortschritt und Skillpunkte. Ein zweiter gespeicherter Zähler daneben könnte von
## der Erfahrung abweichen — und dann wäre nicht mehr zu sagen, welcher stimmt.
##
## `skill_points()` ist der VERDIENTE Stand. Was davon ausgegeben ist, weiß dieses
## Autoload nicht und soll es nicht wissen: es steht in SkillBook, und zwar auch dort
## nicht als Zähler, sondern gerechnet aus den gelernten Knoten (SkillTree.spent) —
## dieselbe Regel, eine Ebene höher. Die offenen Punkte sind `SkillBook.available()`.
##
## Persistenz: JSON unter user://progress/<player_id>_level.json — dieselbe Ablage wie
## Fortschritt, Sitzungen und Geldbörse. Gespeichert wird über den SaveCoordinator an der
## Wellengrenze, zusammen mit allem anderen (ADR 0024): die Erfahrung einer Welle, die
## abbricht, verfällt mit ihr. Früher wurde bei jedem Kill direkt überschrieben — ein
## Absturz dabei hat einen Spielstand von Level 26 auf Level 1 gesetzt.

const SAVE_DIR := "user://progress"

## Erfahrung hat sich geändert (neuer Gesamtstand, neues Level). Die Anzeigen hängen
## daran, statt nachzufragen — verdient wird an mehreren Stellen (Monster, später
## Tagesziel, Boss).
signal changed(total_xp: int, level: int)

## Aufstieg auf `new_level`; `skill_points` ist der Stand der offenen Punkte DANACH.
## Getrennt von `changed`, weil ein Aufstieg gefeiert werden will und eine Änderung nur
## angezeigt.
signal leveled_up(new_level: int, skill_points: int)

## Gesamt-Erfahrung des Profils. Die einzige gespeicherte Zahl (siehe oben).
var total_xp: int = 0
## Aktuelles Level — abgeleitet aus `total_xp` und nur deshalb ein Feld, weil der
## Aufstieg sonst nicht zu erkennen wäre (Vergleich vor/nach dem Zuwachs).
var level: int = 1
var player_id: String = "default"


func _ready() -> void:
	player_id = UserSettings.active_profile()
	load_level()
	SaveCoordinator.register(self)
	# Profilwechsel mitschalten, damit Erfahrung nicht im falschen Profil landet —
	# dasselbe Muster wie in Wallet und SessionLog. Gesichert hat der SaveCoordinator
	# den alten Stand vorher.
	UserSettings.active_profile_changed.connect(switch_to)


## Verbucht verdiente Erfahrung. Nicht-positive Beträge sind kein Fehler, sondern nichts
## zu tun — ein `changed` dafür würde Anzeigen grundlos neu bauen.
func gain(amount: int) -> void:
	if amount <= 0:
		return
	total_xp += amount
	var new_level := Experience.level_for(total_xp)
	var levels_gained := new_level - level
	level = new_level
	_save()
	changed.emit(total_xp, level)
	# Erst der neue Stand, dann die Feier: wer auf `leveled_up` hört, soll den Balken
	# schon gefüllt sehen.
	if levels_gained > 0:
		leveled_up.emit(level, skill_points())


## Die insgesamt VERDIENTEN Skillpunkte — nicht die offenen (siehe Kopf; die rechnet
## SkillBook.available aus). Eine Funktion und kein Feld, damit nichts von der Erfahrung
## abweichen kann.
func skill_points() -> int:
	return Experience.skill_points_for(level)


## Stand im aktuellen Level für Balken und Zeilen:
## { "level", "xp_in_level", "xp_for_level_up" } (siehe Experience.progress_in_level).
func progress() -> Dictionary:
	return Experience.progress_in_level(total_xp)


## Erfahrung als Text: „340 XP". Steht hier und nicht in jedem Screen, damit die
## Erfahrung überall gleich heißt (wie Wallet.label für das Gold).
func label(amount := -1) -> String:
	return "%d XP" % (amount if amount >= 0 else total_xp)


## Wechselt zum Profil `id` (lädt dessen Erfahrung). Gespeichert ist der alte Stand schon
## (SaveCoordinator); eine Instanz ohne ihn schreibt bei jeder Änderung sofort.
func switch_to(id: String) -> void:
	player_id = id
	reload()


## Lädt den Stand des Profils neu und meldet ihn (Profilwechsel, verworfene Welle).
func reload() -> void:
	total_xp = 0
	level = 1
	load_level()
	changed.emit(total_xp, level)


# --- Persistenz ---------------------------------------------------------------

func _save_path() -> String:
	return "%s/%s_level.json" % [SAVE_DIR, player_id]


func save_path() -> String:
	return _save_path()


func save_suffix() -> String:
	return "_level"


func save_payload() -> Dictionary:
	# `level` und `skill_points` stehen zum Mitlesen in der Datei (Debugging, Support),
	# gelesen wird beim Laden aber NUR total_xp — sonst gäbe es zwei Wahrheiten.
	return {
		"player_id": player_id,
		"total_xp": total_xp,
		"level": level,
		"skill_points": skill_points(),
	}


func _save() -> void:
	SaveCoordinator.mark_dirty(self)


## Lädt den Stand des aktuellen Profils. Keine Datei heißt „neues Profil": Level 1 ohne
## Erfahrung, kein Fehler.
func load_level() -> void:
	total_xp = _read_total_xp(_save_path())
	level = Experience.level_for(total_xp)


## Level eines Profils, ohne dorthin umzuschalten — „Wer spielt?" zeigt es auf jeder
## Kachel. Gerechnet wie beim Laden: aus der Erfahrung, nicht aus der Datei.
func level_of(id: String) -> int:
	if id == player_id:
		return level
	return Experience.level_for(_read_total_xp("%s/%s_level.json" % [SAVE_DIR, id]))


## Keine Datei heißt „neues Profil": keine Erfahrung, kein Fehler. Eine unlesbare Datei
## gibt hier auch 0 — überschrieben wird sie trotzdem nie (SaveGuard), und beim Öffnen des
## Profils hat der SaveCoordinator sie schon aus der Sicherung ersetzt.
func _read_total_xp(path: String) -> int:
	var read := SaveStore.read(path)
	if int(read["status"]) != SaveStore.Status.OK:
		if int(read["status"]) != SaveStore.Status.MISSING:
			push_warning("PlayerLevel: ungültige Datei '%s'" % path)
		return 0
	var payload: Dictionary = read["data"]
	# maxi(0, …): eine handgeschriebene negative Zahl wäre eine Schuld, die das Spiel
	# nicht kennt. Das Level kommt aus der Erfahrung und nicht aus der Datei — ein von
	# Hand hochgesetztes Level wäre sonst ein Level ohne Erfahrung dahinter.
	return maxi(0, int(payload.get("total_xp", 0)))
