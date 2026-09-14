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
## Ausgegebene Skillpunkte gibt es noch nicht: es gibt noch keine Fähigkeiten. Wenn sie
## kommen, bringen sie ihren eigenen Zähler mit (verdient minus ausgegeben) — bis dahin
## sind alle verdienten Punkte offen, und das ist keine Annahme, sondern der Zustand.
##
## Persistenz: JSON unter user://progress/<player_id>_level.json — dieselbe Ablage wie
## Fortschritt, Sitzungen und Geldbörse. Gesichert wird SOFORT bei jeder Änderung, also
## mitten in der Welle: ein Absturz darf gelernte Erfahrung nicht kosten. Die Datei ist
## ein paar Dutzend Bytes, das kostet nichts Messbares.

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
	# Profilwechsel mitschalten, damit Erfahrung nicht im falschen Profil landet —
	# dasselbe Muster wie in Wallet und SessionLog.
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


## Verdiente und noch offene Skillpunkte. Solange es keine Fähigkeiten gibt, ist das
## dasselbe (siehe Kopf). Eine Funktion und kein Feld, damit nichts von der Erfahrung
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


## Speichert den Stand und wechselt zum Profil `id` (lädt dessen Erfahrung).
func switch_to(id: String) -> void:
	_save()
	player_id = id
	total_xp = 0
	level = 1
	load_level()
	changed.emit(total_xp, level)


# --- Persistenz ---------------------------------------------------------------

func _save_path() -> String:
	return "%s/%s_level.json" % [SAVE_DIR, player_id]


func _save() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	# `level` und `skill_points` stehen zum Mitlesen in der Datei (Debugging, Support),
	# gelesen wird beim Laden aber NUR total_xp — sonst gäbe es zwei Wahrheiten.
	var payload := {
		"player_id": player_id,
		"total_xp": total_xp,
		"level": level,
		"skill_points": skill_points(),
	}
	var file := FileAccess.open(_save_path(), FileAccess.WRITE)
	if file == null:
		push_warning("PlayerLevel: konnte '%s' nicht schreiben" % _save_path())
		return
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()


## Lädt den Stand des aktuellen Profils. Keine Datei heißt „neues Profil": Level 1 ohne
## Erfahrung, kein Fehler.
func load_level() -> void:
	if not FileAccess.file_exists(_save_path()):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_save_path()))
	if not (parsed is Dictionary):
		push_warning("PlayerLevel: ungültige Datei '%s'" % _save_path())
		return
	var payload: Dictionary = parsed
	# maxi(0, …): eine handgeschriebene negative Zahl wäre eine Schuld, die das Spiel
	# nicht kennt. Das Level kommt aus der Erfahrung und nicht aus der Datei — ein von
	# Hand hochgesetztes Level wäre sonst ein Level ohne Erfahrung dahinter.
	total_xp = maxi(0, int(payload.get("total_xp", 0)))
	level = Experience.level_for(total_xp)
