extends Node
## Zentrale Soundausgabe für kurze Effekte (Autoload `Sfx`), nicht positional.
## Eine Id heißt wie ihre Datei unter `res://assets/audio/sfx/` (snake_case) und braucht
## einen Eintrag in [constant SOUNDS]. Fehlende Dateien werden einmal beim Start gemeldet
## und danach still verworfen.

const AUDIO_DIR := "res://assets/audio/sfx/"

## Id -> Datei und Pegel. `db` ist die Mischung in dB (0.0 = Datei unverändert), am
## gemessenen Pegel ausgerichtet (Zielband um -20 dBFS RMS), Häufiges leiser. `pitch`
## verschiebt die Tonhöhe, `spread` überschreibt [constant PITCH_SPREAD].
const SOUNDS := {
	# Dauerläufer: bei jedem Tippen bzw. jedem erledigten Monster.
	&"slow_mo_in": {"file": "slow_mo_in.wav", "db": -2.0},
	&"slow_mo_out": {"file": "slow_mo_out.wav", "db": -2.0},
	&"monster_kill": {"file": "monster_kill.wav", "db": -8.0},
	&"wrong_answer": {"file": "wrong_answer.wav", "db": -3.5},
	# Einmalige Ereignisse, dürfen tragen.
	&"fortress_hit": {"file": "fortress_hit.mp3", "db": 2.5},
	&"wave_cleared": {"file": "wave_cleared.wav", "db": 3.5},
	&"fortress_destroyed": {"file": "fortress_destroyed.wav", "db": 4.5},
	# Meister-Feier: Aufgabe knapp unter der Wellen-Fanfare (-15…-17 dBFS im lautesten
	# 300-ms-Fenster), das Wort darüber. `word_mastered`-Quelle: -12 dBFS RMS.
	&"task_mastered": {"file": "task_mastered.wav", "db": 3.0},
	&"word_mastered": {"file": "word_mastered.wav", "db": -6.5},
	# Plaketten: Dateien auf -16 dBFS im lautesten 300-ms-Fenster. Bronze und Silber nach
	# Abzug um -18,5 dBFS, die besonderen um -17 dBFS, unter der Aufgaben-Feier.
	&"badge_earned": {"file": "badge_earned.wav", "db": -0.8},
	&"badge_gold": {"file": "badge_gold.wav", "db": -1.2},
	&"badge_diamond": {"file": "badge_diamond.wav", "db": -0.4},
	&"badge_revenge": {"file": "badge_revenge.wav", "db": -0.9},
	&"badge_catch_up": {"file": "badge_catch_up.wav", "db": -1.0},
	&"badge_comeback": {"file": "badge_comeback.wav", "db": -0.6},
	&"badge_better": {"file": "badge_better.wav", "db": -0.7},
	# Zauber: um die Wellen-Fanfare.
	&"spell_reveal": {"file": "spell_reveal.wav", "db": -2.1},
	&"spell_slow": {"file": "spell_slow.wav", "db": -2.5},
	# Dieselbe Datei je neu erscheinendem Monster, daher deutlich leiser.
	&"spell_slow_spawn": {"file": "spell_slow.wav", "db": -9.0},
	&"spell_freeze": {"file": "spell_freeze.wav", "db": -1.8},
	&"spell_shatter": {"file": "spell_shatter.wav", "db": 1.0},
	&"spell_armor": {"file": "spell_armor.wav", "db": -1.0},
	# Quelle leise: -27 dBFS RMS.
	&"spell_haze": {"file": "spell_haze.wav", "db": 3.0},
	# So lang wie SpellFx.STRIKE_WINDUP; ohne Streuung, sonst verschiebt sich das Ende.
	&"spell_thunder_windup": {"file": "spell_thunder_windup.wav", "db": 2.0, "spread": 0.0},
	# Quelle an der Grenze: -15 dBFS RMS.
	&"spell_thunder": {"file": "spell_thunder.wav", "db": -1.5},
	&"spell_heal": {"file": "spell_heal.wav", "db": 0.0},
}

const BUS_SFX := &"SFX"
const BUS_MUSIC := &"Music"

const POOL_SIZE := 8
## Mindestabstand zweier Ausgaben derselben Id in ms; verhindert Kammfilter-Phasing.
const COOLDOWN_MS := 40
## Streuung der Tonhöhe je Ausgabe (Anteil); streckt auch die Länge.
const PITCH_SPREAD := 0.1

## Test-Seam: zuletzt angenommene Id und ihr Pegel, auch ohne Audiodateien gesetzt.
var last_played: StringName = &""
var last_volume_db: float = 0.0

var _players: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _next_allowed_ms: Dictionary = {}


func _ready() -> void:
	# Auch in der Baum-Pause weiterspielen.
	process_mode = Node.PROCESS_MODE_ALWAYS
	for id: StringName in SOUNDS:
		var path := _path_of(id)
		if ResourceLoader.exists(path):
			_streams[id] = load(path)
		else:
			push_warning("Sfx: Datei fehlt, '%s' bleibt stumm (%s)" % [id, path])
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = BUS_SFX
		add_child(player)
		_players.append(player)
	apply_volumes()


## Spielt den Sound zur Id, wenn Datei, Cooldown und ein freier Player es zulassen.
func play(id: StringName) -> void:
	if not SOUNDS.has(id):
		push_warning("Sfx: unbekannte Id '%s'" % id)
		return
	# Echtzeit, nicht delta: die Zeitlupe senkt Engine.time_scale.
	var now := Time.get_ticks_msec()
	if now < int(_next_allowed_ms.get(id, 0)):
		return
	_next_allowed_ms[id] = now + COOLDOWN_MS
	last_played = id
	last_volume_db = gain_db(id)
	var stream: AudioStream = _streams.get(id)
	if stream == null:
		return
	var player := _free_player()
	if player == null:
		return
	player.stream = stream
	player.volume_db = last_volume_db
	var spread := float((SOUNDS[id] as Dictionary).get("spread", PITCH_SPREAD))
	var pitch := float((SOUNDS[id] as Dictionary).get("pitch", 1.0))
	player.pitch_scale = pitch * randf_range(1.0 - spread, 1.0 + spread)
	player.play()


## Mischpegel einer Id in dB; unbekannte Id -> 0.0.
func gain_db(id: StringName) -> float:
	var entry: Dictionary = SOUNDS.get(id, {})
	return float(entry.get("db", 0.0))


func _path_of(id: StringName) -> String:
	return AUDIO_DIR + str((SOUNDS[id] as Dictionary)["file"])


## Überträgt die Lautstärken aus UserSettings auf die Busse.
func apply_volumes() -> void:
	_apply_bus_volume(BUS_SFX, UserSettings.sfx_volume())
	_apply_bus_volume(BUS_MUSIC, UserSettings.music_volume())


func _apply_bus_volume(bus_name: StringName, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		push_warning("Sfx: Bus '%s' fehlt im Bus-Layout" % bus_name)
		return
	# linear_to_db(0.0) ist -inf; bei 0 stummschalten statt den dB-Wert zu setzen.
	var silent := is_zero_approx(linear)
	AudioServer.set_bus_mute(idx, silent)
	if not silent:
		AudioServer.set_bus_volume_db(idx, linear_to_db(linear))


func _free_player() -> AudioStreamPlayer:
	for player in _players:
		if not player.playing:
			return player
	return null
