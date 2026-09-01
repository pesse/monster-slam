extends Node
## Zentrale Soundausgabe für kurze Effekte (Autoload `Sfx`).
##
## Namenskonvention: eine Id entspricht genau einer Datei `res://assets/audio/<id>.wav`
## — gleiche Schreibweise, snake_case, Endung .wav. WAV, weil kurze One-Shots damit ohne
## Dekodierschritt starten und die CC0-Quellen ohnehin WAV liefern; Musik kommt später als
## .ogg dazu, dort lohnt die Kompression. Neue Sounds brauchen einen Eintrag in
## [constant PATHS], sonst sind sie über [method play] nicht erreichbar.
##
## Nicht-positional (`AudioStreamPlayer`, kein …3D): die Kamera steht fest isometrisch,
## alles Hörbare ist im Bild — Panning nach Weltposition wäre Aufwand ohne Gewinn.
##
## Ohne Audiodateien läuft alles weiter: fehlende Streams werden EINMAL beim Start
## gemeldet, [method play] verwirft sie danach still. Frische Checkouts und Tests
## (headless = Dummy-Treiber) sollen nicht daran scheitern.

const AUDIO_DIR := "res://assets/audio/"

## Id -> Datei. Absichtlich explizit statt Verzeichnis-Scan: ein Tippfehler im Aufruf soll
## als Warnung auffallen, nicht als stiller Nicht-Ton.
const PATHS := {
	&"slow_mo_in": AUDIO_DIR + "slow_mo_in.wav",
	&"slow_mo_out": AUDIO_DIR + "slow_mo_out.wav",
	&"monster_kill": AUDIO_DIR + "monster_kill.wav",
}

const BUS_SFX := &"SFX"
const BUS_MUSIC := &"Music"

const POOL_SIZE := 8
## Mindestabstand zweier Ausgaben DERSELBEN Id. Zwei fast gleichzeitige Monster-Kills
## klingen sonst nicht doppelt, sondern nach Kammfilter (Phasing).
const COOLDOWN_MS := 40
## Streuung der Tonhöhe je Ausgabe — ohne sie klingt der zehnte Kill mechanisch.
const PITCH_SPREAD := 0.1

## Test-Seam: zuletzt ANGENOMMENE Id (unbekannte und per Cooldown verworfene Aufrufe
## ändern sie nicht). Erlaubt Tests ohne Audiodateien und ohne hörbare Ausgabe.
var last_played: StringName = &""

var _players: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _next_allowed_ms: Dictionary = {}


func _ready() -> void:
	for id: StringName in PATHS:
		var path: String = PATHS[id]
		# Einmalig laden: `play()` läuft im Kampf mehrmals pro Sekunde, ein Ladeversuch je
		# Aufruf wäre bei fehlender Datei zudem eine Warnung je Aufruf.
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


## Spielt den Sound zur Id, sofern Datei, Cooldown und ein freier Player es zulassen.
## Jeder dieser Fälle ist ein stilles Verwerfen — ein Effektsound ist nie so wichtig,
## dass er warten oder gar den Aufrufer aufhalten dürfte.
func play(id: StringName) -> void:
	if not PATHS.has(id):
		push_warning("Sfx: unbekannte Id '%s'" % id)
		return
	# Echtzeit, NICHT delta: Engine.time_scale sinkt beim Tippen auf 0.15 (siehe SlowMotion),
	# der Cooldown würde sich sonst auf über eine Viertelsekunde strecken.
	var now := Time.get_ticks_msec()
	if now < int(_next_allowed_ms.get(id, 0)):
		return
	_next_allowed_ms[id] = now + COOLDOWN_MS
	last_played = id
	var stream: AudioStream = _streams.get(id)
	if stream == null:
		return
	var player := _free_player()
	if player == null:
		return
	player.stream = stream
	player.pitch_scale = randf_range(1.0 - PITCH_SPREAD, 1.0 + PITCH_SPREAD)
	player.play()


## Überträgt die Lautstärken aus UserSettings auf die Busse. Öffentlich, damit ein späterer
## Regler das Ergebnis sofort hörbar machen kann, ohne den Autoload neu zu laden.
func apply_volumes() -> void:
	_apply_bus_volume(BUS_SFX, UserSettings.sfx_volume())
	_apply_bus_volume(BUS_MUSIC, UserSettings.music_volume())


func _apply_bus_volume(bus_name: StringName, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		push_warning("Sfx: Bus '%s' fehlt im Bus-Layout" % bus_name)
		return
	# linear_to_db(0.0) ist -inf und pflanzt sich als Inf durch jede weitere Rechnung fort;
	# bei 0 deshalb stummschalten und den dB-Wert unangetastet lassen.
	var silent := is_zero_approx(linear)
	AudioServer.set_bus_mute(idx, silent)
	if not silent:
		AudioServer.set_bus_volume_db(idx, linear_to_db(linear))


func _free_player() -> AudioStreamPlayer:
	for player in _players:
		if not player.playing:
			return player
	return null
