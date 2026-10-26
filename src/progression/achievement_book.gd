extends Node
## Die freigeschalteten Erfolge des Profils (Autoload `AchievementBook`, ADR 0029); die
## Regeln stehen in `Achievements`. Gespeichert wird je Erfolg nur der Zeitpunkt der
## Freischaltung, über den SaveCoordinator. Was schon erfüllt ist, als die Datei noch fehlte,
## wird beim ersten Prüfen nachgetragen und ebenso gemeldet.

const SAVE_DIR := "user://progress"

## Fakten, die sich bei einem Signal ändern können (siehe `_connect_triggers`). `ALL` prüft
## jeden abgeleiteten Erfolg.
const ALL := "*"

var player_id: String = "default"

## Erfolgs-Id -> Zeitpunkt der Freischaltung (unix).
var _unlocked: Dictionary = {}
## Unlesbare Datei: dann wird nichts freigeschaltet, sonst käme alles noch einmal.
var _readable := true
## Fakten, die am Frame-Ende geprüft werden (Schlüssel wie in Achievements.FIXED).
var _pending: Dictionary = {}
var _flush_queued := false
## Moment-Erfolge: gewonnene Wellen des Laufs ohne Schaden (-1 nach dem ersten Schaden),
## bewertete und verfehlte Antworten des laufenden Bosskampfs.
var _untouched_waves := 0
var _boss_judged := 0
var _boss_missed := false


func _ready() -> void:
	player_id = UserSettings.active_profile()
	_load()
	SaveCoordinator.register(self)
	UserSettings.active_profile_changed.connect(switch_to)
	# Unter gdUnit4 prüfen nur eigene Instanzen; das Autoload hielte sonst das
	# Entwicklungsprofil fest.
	if _under_test():
		return
	_connect_triggers()
	request(ALL)


func _connect_triggers() -> void:
	EventBus.item_reviewed.connect(func(_id, _correct, _ms) -> void: request("words"))
	EventBus.lexeme_mastered.connect(func(_id) -> void:
		request("mastered")
		request("best_unit_tier")
		request("best_book_tier"))
	EventBus.boss_won.connect(func(_boss, _unit) -> void:
		request("boss_wins")
		request("best_medal"))
	EventBus.run_started.connect(func() -> void: request("best_streak"))
	EventBus.badge_earned.connect(func(_id, _tier) -> void: request("badge_kinds"))
	PlayerLevel.changed.connect(func(_xp, _level) -> void: request("level"))
	Wallet.changed.connect(func(_gold) -> void: request("chests"))
	SkillBook.changed.connect(func() -> void:
		request("skills")
		request("branches"))
	EventBus.run_started.connect(on_run_started)
	EventBus.fortress_damaged.connect(on_fortress_damaged)
	EventBus.wave_cleared.connect(on_wave_cleared)
	EventBus.boss_started.connect(on_boss_started)
	EventBus.boss_answer_judged.connect(on_boss_answer)
	EventBus.boss_won.connect(on_boss_won)


## Prüft am Frame-Ende die Erfolge des Fakts `key` („words“ steht für alle Sprachen).
func request(key: String) -> void:
	_pending[key] = true
	if not _flush_queued:
		_flush_queued = true
		_flush.call_deferred()


func _flush() -> void:
	_flush_queued = false
	var keys := _pending.keys()
	_pending.clear()
	if _in_workbench():
		return
	var languages := Achievements.languages()
	check(Achievements.live_facts(languages), languages, [] if ALL in keys else keys)


## Schaltet frei, was die Fakten erfüllen, und gibt die neuen Ids zurück. `only` beschränkt
## auf diese Fakt-Schlüssel, „words“ auf alle Wort-Erfolge; leer heißt alle.
func check(facts: Dictionary, languages: Array, only: Array = []) -> Array:
	var out: Array = []
	if not _readable:
		return out
	for entry: Dictionary in Achievements.catalog(languages):
		var id := str(entry["id"])
		if _unlocked.has(id) or bool(entry.get("moment", false)):
			continue
		var key := str(entry["fact"])
		if not only.is_empty() and not key in only \
				and not ("words" in only and key.begins_with("words_")):
			continue
		if Achievements.reached(entry, facts):
			_stamp(id)
			out.append(id)
	return out


## Ein Moment-Erfolg aus dem Kampf. Nur beim ersten Mal true.
func unlock(id: String) -> bool:
	if not _readable or _unlocked.has(id) or _in_workbench():
		return false
	_stamp(id)
	return true


# --- Moment-Erfolge ------------------------------------------------------------

func on_run_started() -> void:
	_untouched_waves = 0


func on_fortress_damaged(amount: int) -> void:
	if amount > 0:
		_untouched_waves = -1


## Eine gewonnene Welle; `fortress_health` danach. Öffentlich für Tests.
func on_wave_cleared(_wave_id: Variant = null, fortress_health := -1) -> void:
	var hp := GameState.fortress_health if fortress_health < 0 else fortress_health
	if hp > 0 and hp <= Achievements.THREAD_HP:
		unlock("wave_last_hp")
	if _untouched_waves >= 0:
		_untouched_waves += 1
		if _untouched_waves >= Achievements.UNTOUCHED_WAVES:
			unlock("run_untouched")


func on_boss_started(_boss_id: String) -> void:
	_boss_judged = 0
	_boss_missed = false


func on_boss_answer(_sentence_id: String, _text: String, result: Dictionary) -> void:
	_boss_judged += 1
	if not bool(result.get("hit", false)):
		_boss_missed = true


## Ohne bewertete Antwort (Schreib-Boss) gibt es nichts.
func on_boss_won(_boss_id: String, _unit_key: String) -> void:
	if _boss_judged > 0 and not _boss_missed:
		unlock("boss_flawless")


func _stamp(id: String) -> void:
	_unlocked[id] = int(Time.get_unix_time_from_system())
	_save()
	EventBus.achievement_unlocked.emit(id)


func is_unlocked(id: String) -> bool:
	return _unlocked.has(id)


## Zeitpunkt der Freischaltung (unix), 0 für noch nicht.
func unlocked_at(id: String) -> int:
	return int(_unlocked.get(id, 0))


## Alle freigeschalteten: Id -> Zeitpunkt.
func unlocked() -> Dictionary:
	return _unlocked.duplicate()


func switch_to(id: String) -> void:
	player_id = id
	reload()


## Lädt den Stand des Profils neu (Profilwechsel, verworfene Welle) und prüft ihn.
func reload() -> void:
	_load()
	if not _under_test():
		request(ALL)


# --- Persistenz ---------------------------------------------------------------

func _save_path() -> String:
	return "%s/%s_achievements.json" % [SAVE_DIR, player_id]


func save_path() -> String:
	return _save_path()


func save_suffix() -> String:
	return "_achievements"


func save_payload() -> Dictionary:
	return {"player_id": player_id, "unlocked": _unlocked.duplicate()}


func _save() -> void:
	SaveCoordinator.mark_dirty(self)


func _load() -> void:
	_unlocked = {}
	_readable = true
	var read := SaveStore.read(_save_path())
	match int(read["status"]):
		SaveStore.Status.MISSING:
			return
		SaveStore.Status.OK:
			var stored: Variant = (read["data"] as Dictionary).get("unlocked", {})
			if stored is Dictionary:
				for id: String in stored:
					_unlocked[id] = int(stored[id])
		_:
			_readable = false
			push_warning("AchievementBook: ungültige Datei '%s'" % _save_path())


## Werkbänke (scenes/dev/) zeigen den echten Stand und schreiben nichts, auch keine Erfolge.
func _in_workbench() -> bool:
	var tree := get_tree()
	var scene := tree.current_scene if tree != null else null
	return scene != null and scene.scene_file_path.begins_with("res://scenes/dev/")


func _under_test() -> bool:
	for arg in OS.get_cmdline_args():
		if str(arg).contains("GdUnitCmdTool"):
			return true
	return false
