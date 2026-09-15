extends Node
## Die gelernten Skills des Profils (Autoload `SkillBook`).
##
## Gekauft werden sie mit Skillpunkten, die aus Levelups kommen (PlayerLevel), umgelernt
## wird gegen Gold (Wallet). Wie Gold und Erfahrung gehört das Gelernte zum PROFIL und
## nicht zum Lauf: eine gefallene Festung kostet den Lauf, nicht das Gelernte.
##
## Die Ebenen daneben: PlayerProgress hält den Lernstand pro Aufgabe, SessionLog den
## Verlauf je Lauf, GameState den Zustand des laufenden Laufs, Wallet das Gold,
## PlayerLevel die Erfahrung. Dieses Autoload ist die sechste und hält genau eine Liste.
##
## GENAU EINE Liste, und alles andere ist daraus gerechnet (SkillTree): ausgegebene
## Punkte, offene Punkte und die Boni des Laufs. Das ist dieselbe Regel, nach der
## PlayerLevel nur die Gesamt-Erfahrung sichert — ein zweiter gespeicherter Zähler könnte
## abweichen, und dann wäre nicht mehr zu sagen, welcher stimmt.
##
## Persistenz: JSON unter user://progress/<player_id>_skills.json — dieselbe Ablage wie
## Fortschritt, Sitzungen, Geldbörse und Erfahrung. Gesichert wird SOFORT bei jeder
## Änderung: der Kauf ist eine Entscheidung des Spielers, und die darf ein Absturz nicht
## zurücknehmen.

const SAVE_DIR := "user://progress"

## Die gelernten Skills haben sich geändert (Kauf, Umlernen, Profilwechsel). Die Anzeigen
## hängen daran, statt nachzufragen.
signal changed()

## Ids der gelernten Knoten. Die einzige gespeicherte Größe (siehe Kopf).
var unlocked: PackedStringArray = PackedStringArray()
var player_id: String = "default"


func _ready() -> void:
	player_id = UserSettings.active_profile()
	load_skills()
	# Profilwechsel mitschalten, damit Gelerntes nicht im falschen Profil landet —
	# dasselbe Muster wie in Wallet, PlayerLevel und SessionLog.
	UserSettings.active_profile_changed.connect(switch_to)


## Die Knoten, aus denen gerechnet wird. Eine Funktion und kein Feld: die Registry lädt
## nach jeder Pack-Installation neu (ContentService), und ein gemerkter Schnappschuss
## wäre danach veraltet.
func entries() -> Array:
	return ContentRegistry.skills.values()


## Verdiente minus ausgegebene Punkte. `PlayerLevel.skill_points()` ist der VERDIENTE
## Stand — der Abzug gehört hierher, weil hier steht, wofür sie ausgegeben wurden.
func available() -> int:
	return PlayerLevel.skill_points() - SkillTree.spent(entries(), unlocked)


func is_unlocked(id: String) -> bool:
	return id in unlocked


## Lernt einen Skill, wenn Vorstufen und Punkte reichen; sonst bleibt alles unberührt und
## es kommt `false` zurück. Der Aufrufer entscheidet, was er dem Spieler dazu sagt — hier
## wird nur gerechnet (dasselbe Muster wie Wallet.spend).
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


## Gibt alle Punkte zurück und kostet dafür Gold. Alles oder nichts: ein Umlernen
## einzelner Knoten müsste entscheiden, was mit den Ästen darüber geschieht — und die
## Antwort darauf wäre in jedem Fall eine Überraschung.
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


## Was das Umlernen gerade kostet (für Beschriftung und Sperre des Knopfes).
func respec_cost() -> int:
	return SkillTree.respec_cost(SkillTree.spent(entries(), unlocked))


## Die Boni des Laufs: Effekt-Schlüssel -> Betrag, additiv auf die Grundwerte. Wird beim
## Laufbeginn EINMAL gelesen (WaveRunner) und an GameState und SlowMotion gegeben.
func bonuses() -> Dictionary:
	return SkillTree.bonuses(entries(), unlocked)


## Speichert den Stand und wechselt zum Profil `id` (lädt dessen gelernte Skills).
func switch_to(id: String) -> void:
	_save()
	player_id = id
	unlocked = PackedStringArray()
	load_skills()
	changed.emit()


# --- Persistenz ---------------------------------------------------------------

func _save_path() -> String:
	return "%s/%s_skills.json" % [SAVE_DIR, player_id]


func _save() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	# `spent_points` steht zum Mitlesen in der Datei (Debugging, Support), gelesen wird
	# beim Laden aber NUR `unlocked` — sonst gäbe es zwei Wahrheiten.
	var payload := {
		"player_id": player_id,
		"unlocked": Array(unlocked),
		"spent_points": SkillTree.spent(entries(), unlocked),
	}
	var file := FileAccess.open(_save_path(), FileAccess.WRITE)
	if file == null:
		push_warning("SkillBook: konnte '%s' nicht schreiben" % _save_path())
		return
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()


## Lädt den Stand des aktuellen Profils. Keine Datei heißt „neues Profil": nichts gelernt,
## kein Fehler.
func load_skills() -> void:
	if not FileAccess.file_exists(_save_path()):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_save_path()))
	if not (parsed is Dictionary):
		push_warning("SkillBook: ungültige Datei '%s'" % _save_path())
		return
	var payload: Dictionary = parsed
	var list := PackedStringArray()
	for id in payload.get("unlocked", []):
		# Doppelte Einträge würden doppelt abgerechnet — eine von Hand verdoppelte Zeile
		# soll keine Punkte kosten, die es nicht gibt.
		if str(id) not in list:
			list.append(str(id))
	unlocked = list
