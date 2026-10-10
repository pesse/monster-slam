extends Node
## Die gelernten Skills des Profils (Autoload `SkillBook`).
##
## Gekauft werden sie mit Skillpunkten, die aus Levelups kommen (PlayerLevel), zurück-
## genommen — alles oder ein einzelner Knoten — gegen Gold (Wallet). Wie Gold und Erfahrung
## gehört das Gelernte zum PROFIL und nicht zum Lauf: eine gefallene Festung kostet den
## Lauf, nicht das Gelernte.
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
## Fortschritt, Sitzungen, Geldbörse und Erfahrung. Gespeichert wird über den
## SaveCoordinator am Ende des Frames (ADR 0024) — zusammen mit dem Gold, das ein Verlernen
## kostet, in einem Commit.

const SAVE_DIR := "user://progress"

## Die gelernten Skills haben sich geändert (Kauf, Verlernen, Umlernen, Profilwechsel). Die Anzeigen
## hängen daran, statt nachzufragen.
signal changed()

## Ids der gelernten Knoten. Die einzige gespeicherte Größe (siehe Kopf).
var unlocked: PackedStringArray = PackedStringArray()
var player_id: String = "default"

## Debug-Build: so viele Punkte, wie man ausgeben möchte — zum Ausprobieren der Bäume, ohne
## erst Level zu sammeln. Nur das Autoload setzt das (in `_ready`); eine Instanz im Test
## rechnet mit den echten Punkten. Gespeichert wird weiter nur die Liste der Knoten.
var unlimited_points := false
const UNLIMITED_POINTS := 999


func _ready() -> void:
	unlimited_points = OS.is_debug_build()
	player_id = UserSettings.active_profile()
	load_skills()
	SaveCoordinator.register(self)
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
	if unlimited_points:
		return UNLIMITED_POINTS
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


## Verlernt EINEN Knoten gegen Gold, und mit ihm jeden gelernten Knoten, der über ihn
## hängt (`SkillTree.forget_set`) — eine Vorstufe ohne ihren Ast darüber gibt es nicht.
## Reicht das Gold nicht oder ist der Knoten nicht gelernt, bleibt alles unberührt.
func forget(id: String) -> bool:
	var list := entries()
	var gone := SkillTree.forget_set(list, id, unlocked)
	if gone.is_empty():
		return false
	var price := SkillTree.forget_cost(list, id, unlocked)
	# Ein Knoten für 0 Punkte kostet auch 0 Gold — `Wallet.spend(0)` lehnt ab, also nur
	# zahlen, wenn es etwas zu zahlen gibt.
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


## Was das Verlernen von `id` gerade kostet (für Karte und Rückfrage).
func forget_cost(id: String) -> int:
	return SkillTree.forget_cost(entries(), id, unlocked)


## Gibt alle Punkte zurück und kostet dafür Gold, je Punkt (`RESPEC_GOLD_PER_POINT`). Im
## Ergebnis dasselbe wie `forget` an jeder Wurzel, aber teurer: wer alles umwirft, zahlt
## für jeden ausgegebenen Punkt, wer einzeln verlernt, nur je Knoten.
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


## Wechselt zum Profil `id` (lädt dessen gelernte Skills). Gespeichert ist der alte Stand
## schon (SaveCoordinator); eine Instanz ohne ihn schreibt bei jeder Änderung sofort.
func switch_to(id: String) -> void:
	player_id = id
	reload()


## Lädt den Stand des Profils neu und meldet ihn (Profilwechsel, Import).
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
	# `spent_points` steht zum Mitlesen in der Datei (Debugging, Support), gelesen wird
	# beim Laden aber NUR `unlocked` — sonst gäbe es zwei Wahrheiten.
	return {
		"player_id": player_id,
		"unlocked": Array(unlocked),
		"spent_points": SkillTree.spent(entries(), unlocked),
	}


func _save() -> void:
	SaveCoordinator.mark_dirty(self)


## Lädt den Stand des aktuellen Profils. Keine Datei heißt „neues Profil": nichts gelernt,
## kein Fehler.
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
		# Doppelte Einträge würden doppelt abgerechnet — eine von Hand verdoppelte Zeile
		# soll keine Punkte kosten, die es nicht gibt.
		if str(id) not in list:
			list.append(str(id))
	unlocked = list
