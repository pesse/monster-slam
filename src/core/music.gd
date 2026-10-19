extends Node
## Hintergrundmusik (Autoload `Music`, ADR 0033). Der Bereich folgt der laufenden Szene,
## das Stück dem Musik-Set des Profils. Zwei Player überblenden; Pause und Zeitlupe
## dämpfen nur, das Stück läuft weiter. Die Lautstärke des Busses setzt `Sfx`.

const MUSIC_DIR := "res://assets/audio/music/"
const SET_FILE := "set.tres"
const BATTLE_SCENE := "res://scenes/battle/battle.tscn"
## Bosskampf-Szenen; ihr Stück kommt erst mit `EventBus.boss_started`, das die Boss-Id trägt.
const BOSS_SCENES := ["res://scenes/battle/boss_fight.tscn", "res://scenes/battle/writing_boss.tscn"]
## Werkbänke bleiben still.
const DEV_DIR := "res://scenes/dev/"

## Überblenden in dB je Echtzeit-Sekunde.
const FADE_DB_PER_SEC := 40.0
const SILENT_DB := -60.0
## Dämpfung in dB, solange der Baum pausiert (Pause, Feier, Wellenende).
const PAUSE_DUCK_DB := -8.0
## Dämpfung in dB bei voller Zeitlupe, zusätzlich zum Tiefpass.
const SLOW_DUCK_DB := -5.0
## Grenzfrequenz des Tiefpasses auf dem Music-Bus in Hz: offen und bei voller Zeitlupe.
const OPEN_CUTOFF_HZ := 20000.0
const SLOW_CUTOFF_HZ := 700.0
## Änderung der Zeitlupen-Dämpfung je Echtzeit-Sekunde (Anteil); `SlowMotion.stop` springt.
const SLOW_RAMP_PER_SEC := 4.0

## Aus unter gdUnit4: kein Test spielt Musik.
var enabled := true

var _players: Array[AudioStreamPlayer] = []
var _gain_db: Array[float] = [SILENT_DB, SILENT_DB]
## Index des Players, der spielt oder einblendet; der andere blendet aus.
var _current := 0
var _area := MusicSet.Area.NONE
var _boss_id := ""
var _scene_id := 0
var _slow := 0.0
var _slow_target := 0.0
var _last_tick_ms := 0
## Id → MusicSet, beim ersten Zugriff geladen.
var _sets: Dictionary = {}


func _ready() -> void:
	# Läuft durch die Baum-Pause, nur gedämpft.
	process_mode = Node.PROCESS_MODE_ALWAYS
	enabled = not _under_test()
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.bus = Sfx.BUS_MUSIC
		player.volume_db = SILENT_DB
		player.finished.connect(_on_finished.bind(i))
		add_child(player)
		_players.append(player)
	EventBus.boss_started.connect(_on_boss_started)
	# Die Sieges-Fanfare steht allein.
	EventBus.boss_ended.connect(func(_id: String, _won: bool) -> void: _play(null))
	EventBus.slow_motion_changed.connect(func(intensity: float) -> void: _slow_target = intensity)
	UserSettings.active_profile_changed.connect(func(_id: String) -> void: refresh())
	_last_tick_ms = Time.get_ticks_msec()


## Echtzeit statt `delta`: die Zeitlupe senkt Engine.time_scale bis auf 0.
func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	var real_delta := float(now - _last_tick_ms) / 1000.0
	_last_tick_ms = now
	_follow_scene()
	_slow = move_toward(_slow, _slow_target, SLOW_RAMP_PER_SEC * real_delta)
	_apply_filter()
	var duck := SLOW_DUCK_DB * _slow + (PAUSE_DUCK_DB if get_tree().paused else 0.0)
	for i in _players.size():
		var player := _players[i]
		var target := 0.0 if i == _current and player.playing else SILENT_DB
		_gain_db[i] = move_toward(_gain_db[i], target, FADE_DB_PER_SEC * real_delta)
		player.volume_db = _gain_db[i] + duck
		if i != _current and player.playing and _gain_db[i] <= SILENT_DB:
			player.stop()


## Bereich einer Szene; unbekannte Szenen gehören zur Lobby.
static func area_for_scene(path: String) -> MusicSet.Area:
	if path.is_empty() or path.begins_with(DEV_DIR):
		return MusicSet.Area.NONE
	if path == BATTLE_SCENE:
		return MusicSet.Area.BATTLE
	if path in BOSS_SCENES:
		return MusicSet.Area.BOSS
	return MusicSet.Area.LOBBY


## Ein Stück aus `pool`, möglichst nicht `last`; null bei leerem Pool.
static func pick(pool: Array[AudioStream], last: AudioStream) -> AudioStream:
	if pool.is_empty():
		return null
	var others := pool.filter(func(stream: AudioStream) -> bool: return stream != last)
	if others.is_empty():
		return pool[0]
	return others.pick_random()


## Alle Sets unter MUSIC_DIR, das Standard-Set zuerst, sonst nach Titel.
func sets() -> Array[MusicSet]:
	if _sets.is_empty():
		for entry in ResourceLoader.list_directory(MUSIC_DIR):
			var path := MUSIC_DIR + entry + SET_FILE
			if entry.ends_with("/") and ResourceLoader.exists(path):
				var loaded := load(path) as MusicSet
				if loaded != null:
					_sets[loaded.id] = loaded
	var out: Array[MusicSet] = []
	out.assign(_sets.values())
	out.sort_custom(func(a: MusicSet, b: MusicSet) -> bool:
		if (a.id == MusicSet.DEFAULT_ID) != (b.id == MusicSet.DEFAULT_ID):
			return a.id == MusicSet.DEFAULT_ID
		return a.title.naturalnocasecmp_to(b.title) < 0)
	return out


## Das Set zur Id; ein unbekanntes (gelöscht, umbenannt) ist das Standard-Set.
func music_set(id: StringName) -> MusicSet:
	sets()
	return _sets.get(id, _sets.get(MusicSet.DEFAULT_ID))


## Stücke eines Bereichs aus dem Set `set_id`, wo es nichts trägt, aus dem Standard-Set.
func tracks_for(area: MusicSet.Area, boss_id: String, set_id: StringName) -> Array[AudioStream]:
	var chosen := music_set(set_id)
	if chosen != null and not chosen.tracks(area, boss_id).is_empty():
		return chosen.tracks(area, boss_id)
	var fallback := music_set(MusicSet.DEFAULT_ID)
	if fallback == null:
		return []
	return fallback.tracks(area, boss_id)


## Das Stück, das gerade spielt oder einblendet; null bei Stille.
func current_stream() -> AudioStream:
	var player := _players[_current]
	return player.stream if player.playing else null


## Nach einem Wechsel von Set oder Profil: bleibt beim Stück, wenn es im neuen Pool liegt.
func refresh() -> void:
	if _area == MusicSet.Area.NONE or (_area == MusicSet.Area.BOSS and _boss_id.is_empty()):
		return
	if _players[_current].stream in _pool():
		return
	_play(pick(_pool(), null))


func _pool() -> Array[AudioStream]:
	return tracks_for(_area, _boss_id, UserSettings.music_set())


## Ein Szenenwechsel ist erst fertig, wenn die neue Szene steht; ein Neuladen derselben
## Szene (Bosskampf „Noch einmal“) zählt als Wechsel.
func _follow_scene() -> void:
	var scene := get_tree().current_scene
	if scene == null or scene.get_instance_id() == _scene_id:
		return
	_scene_id = scene.get_instance_id()
	var area := area_for_scene(scene.scene_file_path)
	# Menü → Buchwahl → Karte: dasselbe Stück läuft weiter.
	if area == _area and area != MusicSet.Area.BOSS:
		return
	_area = area
	_boss_id = ""
	if area == MusicSet.Area.NONE or area == MusicSet.Area.BOSS:
		_play(null)
	else:
		_play(pick(_pool(), null))


func _on_boss_started(boss_id: String) -> void:
	if _area != MusicSet.Area.BOSS:
		return
	_boss_id = boss_id
	_play(pick(_pool(), null))


## Ein Stück ohne Loop ist zu Ende: das nächste aus demselben Pool.
func _on_finished(index: int) -> void:
	if index == _current:
		_play(pick(_pool(), _players[index].stream))


## Blendet auf `stream` über; null blendet aus. Läuft es schon, bleibt es.
func _play(stream: AudioStream) -> void:
	if not enabled:
		return
	var playing := _players[_current]
	if stream == playing.stream and (playing.playing or stream == null):
		return
	_current = 1 - _current
	var next := _players[_current]
	next.stop()
	next.stream = stream
	_gain_db[_current] = SILENT_DB
	next.volume_db = SILENT_DB
	if stream != null:
		next.play()


func _apply_filter() -> void:
	var bus := AudioServer.get_bus_index(Sfx.BUS_MUSIC)
	if bus < 0 or AudioServer.get_bus_effect_count(bus) == 0:
		return
	var filter := AudioServer.get_bus_effect(bus, 0) as AudioEffectLowPassFilter
	if filter == null:
		return
	var open := is_zero_approx(_slow)
	AudioServer.set_bus_effect_enabled(bus, 0, not open)
	if not open:
		# Geometrisch, damit die Höhen gleichmäßig verschwinden.
		filter.cutoff_hz = OPEN_CUTOFF_HZ * pow(SLOW_CUTOFF_HZ / OPEN_CUTOFF_HZ, _slow)


func _under_test() -> bool:
	for arg in OS.get_cmdline_args():
		if str(arg).contains("GdUnitCmdTool"):
			return true
	return false
