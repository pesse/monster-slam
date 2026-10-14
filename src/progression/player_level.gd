extends Node
## Erfahrung und Level des Profils (Autoload `PlayerLevel`).
## Hält genau eine Zahl, die Gesamt-Erfahrung; Level und Skillpunkte rechnet Experience
## daraus. Sie gehört zum Profil, nicht zum Lauf. Die ausgegebenen Punkte stehen in
## SkillBook. Datei: user://progress/<player_id>_level.json, gespeichert über den
## SaveCoordinator (ADR 0024).

const SAVE_DIR := "user://progress"

## Erfahrung hat sich geändert (neuer Gesamtstand, neues Level).
signal changed(total_xp: int, level: int)

## Aufstieg auf `new_level`; `skill_points` ist der Stand der verdienten Punkte danach.
signal leveled_up(new_level: int, skill_points: int)

## Gesamt-Erfahrung des Profils, die einzige gespeicherte Zahl.
var total_xp: int = 0
## Aktuelles Level, abgeleitet aus `total_xp`; als Feld nur, um den Aufstieg zu erkennen.
var level: int = 1
var player_id: String = "default"


func _ready() -> void:
	player_id = UserSettings.active_profile()
	load_level()
	SaveCoordinator.register(self)
	UserSettings.active_profile_changed.connect(switch_to)


## Verbucht verdiente Erfahrung. Nicht-positive Beträge werden ignoriert.
func gain(amount: int) -> void:
	if amount <= 0:
		return
	total_xp += amount
	var new_level := Experience.level_for(total_xp)
	var levels_gained := new_level - level
	level = new_level
	_save()
	changed.emit(total_xp, level)
	# Erst der neue Stand, dann die Feier.
	if levels_gained > 0:
		leveled_up.emit(level, skill_points())


## Die insgesamt verdienten Skillpunkte, nicht die offenen (SkillBook.available).
func skill_points() -> int:
	return Experience.skill_points_for(level)


## Stand im aktuellen Level (siehe Experience.progress_in_level).
func progress() -> Dictionary:
	return Experience.progress_in_level(total_xp)


func label(amount := -1) -> String:
	return "%d XP" % (amount if amount >= 0 else total_xp)


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
	# `level` und `skill_points` nur zum Mitlesen; geladen wird nur total_xp.
	return {
		"player_id": player_id,
		"total_xp": total_xp,
		"level": level,
		"skill_points": skill_points(),
	}


func _save() -> void:
	SaveCoordinator.mark_dirty(self)


## Lädt den Stand des aktuellen Profils. Ohne Datei: Level 1 ohne Erfahrung.
func load_level() -> void:
	total_xp = _read_total_xp(_save_path())
	level = Experience.level_for(total_xp)


## Level eines Profils, ohne dorthin umzuschalten.
func level_of(id: String) -> int:
	if id == player_id:
		return level
	return Experience.level_for(_read_total_xp("%s/%s_level.json" % [SAVE_DIR, id]))


## Gesamt-Erfahrung aus einer Profildatei; fehlend oder unlesbar gibt 0. Überschrieben wird
## eine unlesbare Datei trotzdem nie (SaveGuard).
func _read_total_xp(path: String) -> int:
	var read := SaveStore.read(path)
	if int(read["status"]) != SaveStore.Status.OK:
		if int(read["status"]) != SaveStore.Status.MISSING:
			push_warning("PlayerLevel: ungültige Datei '%s'" % path)
		return 0
	var payload: Dictionary = read["data"]
	# Negative Werte aus einer von Hand bearbeiteten Datei gelten als 0.
	return maxi(0, int(payload.get("total_xp", 0)))
