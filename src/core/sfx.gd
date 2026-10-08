extends Node
## Zentrale Soundausgabe für kurze Effekte (Autoload `Sfx`).
##
## Namenskonvention: eine Id heißt wie ihre Datei unter `res://assets/audio/sfx/`, snake_case.
## (Musik bekommt einen eigenen Ordner daneben.)
## Der Dateiname steht trotzdem ausgeschrieben in [constant SOUNDS] — so kann eine einzelne
## Quelle auch mal ein anderes Format mitbringen, ohne dass Code sich ändert. Standard ist
## .wav: kurze One-Shots starten damit ohne Dekodierschritt, und die CC0-Quellen liefern
## ohnehin WAV. Musik kommt später als .ogg dazu, dort lohnt die Kompression.
##
## Neue Sounds brauchen einen Eintrag in [constant SOUNDS], sonst sind sie über
## [method play] nicht erreichbar.
##
## Nicht-positional (`AudioStreamPlayer`, kein …3D): die Kamera steht fest isometrisch,
## alles Hörbare ist im Bild — Panning nach Weltposition wäre Aufwand ohne Gewinn.
##
## Ohne Audiodateien läuft alles weiter: fehlende Streams werden EINMAL beim Start
## gemeldet, [method play] verwirft sie danach still. Frische Checkouts und Tests
## (headless = Dummy-Treiber) sollen nicht daran scheitern.

const AUDIO_DIR := "res://assets/audio/sfx/"

## Id -> Datei und Pegel. Absichtlich explizit statt Verzeichnis-Scan: ein Tippfehler im
## Aufruf soll als Warnung auffallen, nicht als stiller Nicht-Ton.
##
## `db` ist die MISCHUNG, nicht die Lautstärke des Spielers. Zwei Gründe, warum sie pro
## Sound stehen muss: Quelldateien sind unterschiedlich ausgesteuert (eine Blechfanfare
## kommt lauter aus dem Netz als ein gehauchtes „nein"), und ein Sound, den man bei jeder
## Falscheingabe hört, darf nicht so laut sein wie einer, der einmal pro Welle kommt.
## 0.0 = Datei unverändert, negative Werte leiser. `pitch` (Standard 1.0) verschiebt die
## Tonhöhe, damit eine Datei für einen verwandten Anlass ein zweites Mal dienen kann. Der Regler des Spielers sitzt DARÜBER
## auf dem Bus (siehe [method apply_volumes]) und verschiebt alles gemeinsam.
## Die dB-Werte sind an den gemessenen RMS-Pegeln der Dateien ausgerichtet (Zielband um
## -20 dBFS), danach nach Rolle verschoben: was oft kommt, liegt darunter, was einmal pro
## Welle kommt, darüber. `monster_kill` kam mit -11.7 dBFS RMS und fast an der
## Aussteuerungsgrenze aus der Quelle — ohne die -8 hier wäre alles andere nur noch Beiwerk.
const SOUNDS := {
	# Dauerläufer: bei jedem Tippen bzw. jedem erledigten Monster.
	&"slow_mo_in": {"file": "slow_mo_in.wav", "db": -2.0},
	&"slow_mo_out": {"file": "slow_mo_out.wav", "db": -2.0},
	&"monster_kill": {"file": "monster_kill.wav", "db": -8.0},
	# Bewusst der leiseste im Spiel: er trifft niemanden, der gerade gut spielt.
	&"wrong_answer": {"file": "wrong_answer.wav", "db": -3.5},
	# Einmalige Ereignisse, dürfen tragen.
	&"fortress_hit": {"file": "fortress_hit.mp3", "db": 2.5},
	&"wave_cleared": {"file": "wave_cleared.wav", "db": 3.5},
	&"fortress_destroyed": {"file": "fortress_destroyed.wav", "db": 4.5},
	# Meister-Feier (Issue #23). Die Aufgabe liegt knapp unter der Wellen-Fanfare, weil sie
	# öfter kommt; das Wort darüber, es ist der größte gute Moment im Kampf. Die Quelle von
	# `word_mastered` steht an der Aussteuerungsgrenze (-12 dBFS RMS, Spitzen bei 0) — daher
	# der kräftige Abzug.
	&"task_mastered": {"file": "task_mastered.wav", "db": -2.0},
	&"word_mastered": {"file": "word_mastered.wav", "db": -6.5},
	# Plaketten (Issue #63, Badges.sound_of). Bronze und Silber kommen oft und klingen wie
	# Eisenhaut, etwas leiser als der Zauber. Die besonderen haben eigene Töne und liegen
	# knapp über Bronze/Silber, unter der Aufgaben-Feier (gemessen am lautesten 300-ms-Fenster,
	# Ziel um -17 dBFS nach Abzug). Gold und Diamant kamen sehr leise aus der Quelle (-27
	# bzw. -39 dBFS) und sind in der Datei angehoben (CREDITS.md); `badge_catch_up` ist ein
	# Rechteck-Chiptune an der Grenze (-3).
	&"badge_earned": {"file": "spell_armor.wav", "db": -4.0},
	&"badge_gold": {"file": "badge_gold.wav", "db": 2.0},
	&"badge_diamond": {"file": "badge_diamond.wav", "db": 3.0},
	&"badge_revenge": {"file": "badge_revenge.wav", "db": 4.0},
	&"badge_catch_up": {"file": "badge_catch_up.wav", "db": -14.0},
	&"badge_comeback": {"file": "badge_comeback.wav", "db": 3.5},
	&"badge_better": {"file": "badge_better.wav", "db": 5.5},
	# Zauber (ADR 0014, SpellFx): selten und vom Spieler gewollt, also um die Wellen-Fanfare.
	# `spell_reveal` kommt sehr leise aus der Quelle (-30 dBFS RMS, Spitzen bei -12),
	# `spell_slow` und `spell_armor` laut und an der Grenze.
	&"spell_reveal": {"file": "spell_reveal.wav", "db": 6.0},
	&"spell_slow": {"file": "spell_slow.wav", "db": -2.5},
	# Dieselbe Datei, wenn unter Schwere Luft ein neues Monster erscheint: kommt je Monster,
	# also deutlich unter dem Zauber selbst.
	&"spell_slow_spawn": {"file": "spell_slow.wav", "db": -9.0},
	&"spell_freeze": {"file": "spell_freeze.wav", "db": 2.5},
	# Taut das ganze Feld auf einmal auf, spielt der Cooldown ihn nur einmal.
	&"spell_shatter": {"file": "spell_shatter.wav", "db": 1.0},
	&"spell_armor": {"file": "spell_armor.wav", "db": -1.0},
	# Schwere Luft kommt leise und lückig aus der Quelle (-27 dBFS RMS, Spitzen bei -3).
	&"spell_haze": {"file": "spell_haze.wav", "db": 3.0},
	# Das Aufladen ist so lang wie das Verdunkeln (SpellFx.STRIKE_WINDUP) — ohne Streuung,
	# sonst endet es bis zu einer Zehntelsekunde neben dem ersten Blitz.
	&"spell_thunder_windup": {"file": "spell_thunder_windup.wav", "db": 2.0, "spread": 0.0},
	# Der Donner trägt alle Blitze; die Quelle steht an der Grenze (-15 dBFS RMS).
	&"spell_thunder": {"file": "spell_thunder.wav", "db": -1.5},
	&"spell_heal": {"file": "spell_heal.wav", "db": 0.0},
}

const BUS_SFX := &"SFX"
const BUS_MUSIC := &"Music"

const POOL_SIZE := 8
## Mindestabstand zweier Ausgaben DERSELBEN Id. Zwei fast gleichzeitige Monster-Kills
## klingen sonst nicht doppelt, sondern nach Kammfilter (Phasing).
const COOLDOWN_MS := 40
## Streuung der Tonhöhe je Ausgabe — ohne sie klingt der zehnte Kill mechanisch. Sie
## streckt auch die Länge; ein Ton, der auf ein Bild getimt ist, setzt `"spread": 0.0`.
const PITCH_SPREAD := 0.1

## Test-Seam: zuletzt ANGENOMMENE Id und der Pegel, mit dem sie ausgegeben wird
## (unbekannte und per Cooldown verworfene Aufrufe ändern beides nicht). Beides wird
## gesetzt, bevor Stream und freier Player geprüft werden — so ist die Auswahl auch ohne
## Audiodateien und ohne hörbare Ausgabe prüfbar.
var last_played: StringName = &""
var last_volume_db: float = 0.0

var _players: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _next_allowed_ms: Dictionary = {}


func _ready() -> void:
	# Auch in der Baum-Pause (Meister-Feier): ein Effektsound, der mitten im Klang anhält
	# und zwei Sekunden später weiterspielt, klingt kaputt.
	process_mode = Node.PROCESS_MODE_ALWAYS
	for id: StringName in SOUNDS:
		var path := _path_of(id)
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
	if not SOUNDS.has(id):
		push_warning("Sfx: unbekannte Id '%s'" % id)
		return
	# Echtzeit, NICHT delta: Engine.time_scale sinkt beim Tippen auf 0.15 (siehe SlowMotion),
	# der Cooldown würde sich sonst auf über eine Viertelsekunde strecken.
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
	# Jedes Mal setzen: ein Player kommt aus dem Pool mit dem Pegel seines Vorgängers.
	player.volume_db = last_volume_db
	var spread := float((SOUNDS[id] as Dictionary).get("spread", PITCH_SPREAD))
	var pitch := float((SOUNDS[id] as Dictionary).get("pitch", 1.0))
	player.pitch_scale = pitch * randf_range(1.0 - spread, 1.0 + spread)
	player.play()


## Mischpegel einer Id in dB (0.0 = Datei unverändert). Unbekannte Id -> 0.0, damit ein
## Tippfehler nicht zusätzlich zur Warnung auch noch den Pegel verbiegt.
func gain_db(id: StringName) -> float:
	var entry: Dictionary = SOUNDS.get(id, {})
	return float(entry.get("db", 0.0))


func _path_of(id: StringName) -> String:
	return AUDIO_DIR + str((SOUNDS[id] as Dictionary)["file"])


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
