class_name Badges
extends RefCounted
## Plaketten im Wellenkampf (Issue #63): kleine Erfolge, die nicht an der Meisterung hängen.
## Eine Aufgabe sitzt frühestens nach drei Tagen (ADR 0018) — bis dahin gibt es sonst nichts
## zu feiern. Gefeiert werden Spielen und Erinnern:
##
## - `hits`      Treffer heute: 10 / 25 / 50 / 100 (Bronze, Silber, Gold, Diamant)
## - `words`     Wörter einer Sprache schon einmal richtig: 20 / 50 / 100 / 250, dauerhaft
## - `kept`      Von gestern behalten: die letzte Antwort war richtig und lag vor heute;
##               Plakette beim 1., 5., 10. und 25. Wort des Tages
## - `revenge`   Revanche: die letzte Antwort war ein durchgelassenes Monster
## - `catch_up`  Aufholjagd: die Confidence lag vor dem Treffer unter CATCH_UP_BELOW
## - `comeback`  Comeback des Tages: Welle gewonnen, obwohl die Festung im Roten stand
## - `better`    Besser als sonst: Genauigkeit der Sitzung über dem Vergleichswert
##
## Nichts wird nebenher gezählt. Treffer und Wörter kommen aus SessionLog und PlayerProgress
## und lösen beim Überschreiten einer Schwelle aus (die Zahl steigt je Antwort um höchstens
## eins). Gespeichert wird nur, was sich danach nicht mehr ablesen lässt: welche Tages-
## Plaketten heute schon kamen und welche Aufgaben heute „behalten" waren — record()
## überschreibt den Stand davor. Datei: user://progress/<player_id>_badges.json, nur der
## laufende Tag.
##
## Revanche und Aufholjagd kommen je Welle höchstens einmal: wer viele wacklige Wörter hat,
## soll nicht nach jedem Treffer angehalten werden.
##
## Die Regeln sind statisch und ohne Autoload prüfbar (tests/badges_test.gd); die Instanz
## liest den Stand und schreibt den Tag. Gezeigt werden die Plaketten von MasteryCelebration.

const SAVE_DIR := "user://progress"

const HIT_STEPS := [10, 25, 50, 100]
const WORD_STEPS := [20, 50, 100, 250]
const KEPT_STEPS := [1, 5, 10, 25]
## Unter dieser Confidence vor dem Treffer ist es eine Aufholjagd. Eine neue Aufgabe startet
## bei 0,3 (PlayerProgress.DEFAULT_CONFIDENCE); darunter kommt man nur über Fehler.
const CATCH_UP_BELOW := 0.10
## Rote Zone des Lebensbalkens — dieselbe Schwelle wie im HUD.
const COMEBACK_RATIO := preload("res://src/ui/hud.gd").HP_WARN

const TIER_NAMES := ["Bronze", "Silber", "Gold", "Diamant"]
const TIER_PALETTES := [&"bronze", &"silver", &"gold", &"diamond"]
const WORD_TITLES := ["Wortschnüffler", "Vokabeljäger", "Wörterdrache", "Sprachmonster"]
## Stufen, deren Plaketten den gemeinsamen Ton haben (sound_of).
const COMMON_PALETTES := [&"bronze", &"silver"]

## Plaketten, die es je Tag einmal gibt (Stufen zählen als eigene).
const DAILY := ["comeback", "better"]
## Plaketten, die es je Welle einmal gibt.
const PER_WAVE := ["revenge", "catch_up"]

var player_id: String
var _day := -1
var _earned: Array = []
var _kept: Array = []
var _this_wave: Array = []


func _init(id: String = PlayerProgress.player_id) -> void:
	player_id = id
	_load()


# --- Regeln -------------------------------------------------------------------

## Stufe 1..4, wenn `count` genau eine der Schwellen ist, sonst 0.
static func step_tier(steps: Array, count: int) -> int:
	return steps.find(count) + 1


## Was ein Treffer auf eine Aufgabe mit dem Stand `before` (ein PlayerProgress-Record VOR
## der Antwort) außer dem Treffer bedeutet: "catch_up", "revenge", "kept" oder "".
## `last_day`/`today` sind lokale Tagesindizes (SessionLog.local_day).
static func answer_kind(before: Dictionary, last_day: int, today: int) -> String:
	if int(before.get("attempts", 0)) <= 0:
		return ""
	if float(before.get("confidence", 1.0)) < CATCH_UP_BELOW:
		return "catch_up"
	if not bool(before.get("last_correct", false)):
		return "revenge"
	if last_day < today:
		return "kept"
	return ""


## Der Ton einer Plakette: Bronze und Silber kommen oft und teilen sich `badge_earned`;
## die besonderen (Gold, Diamant und die ohne Stufe) heißen wie ihre Palette, `badge_<palette>`.
static func sound_of(palette: StringName) -> StringName:
	return &"badge_earned" if palette in COMMON_PALETTES else StringName("badge_" + palette)


## Besser als sonst: beide Werte gelten (SessionLog.accuracy_trend gibt sonst -1) und die
## Sitzung liegt darüber.
static func is_better(trend: Dictionary) -> bool:
	var accuracy := float(trend.get("accuracy", -1.0))
	var baseline := float(trend.get("baseline", -1.0))
	return accuracy >= 0.0 and baseline >= 0.0 and accuracy > baseline


## Eine Plakette zum Zeigen: id, tier (0 ohne Stufe), title, detail, mark (Zahl auf der
## Plakette, sonst leer: dann zeichnet sie ihr Zeichen), palette (BadgePlate) und sound
## (Sfx-Id, sound_of).
static func make(id: String, tier: int, detail_args: Dictionary = {}) -> Dictionary:
	var palette: StringName = TIER_PALETTES[tier - 1] if tier > 0 else StringName(id)
	var badge := {"id": id, "tier": tier, "title": "", "detail": "", "mark": "",
			"palette": palette, "sound": sound_of(palette)}
	match id:
		"hits":
			badge["mark"] = str(HIT_STEPS[tier - 1])
			badge["title"] = "%d Treffer heute!" % HIT_STEPS[tier - 1]
			badge["detail"] = "%s-Plakette" % TIER_NAMES[tier - 1]
		"words":
			var language := Lexeme.language_name(str(detail_args.get("lang", "")))
			badge["mark"] = str(WORD_STEPS[tier - 1])
			badge["title"] = "%s-%s" % [language, WORD_TITLES[tier - 1]]
			badge["detail"] = "%d %s-Vokabeln schon richtig gehabt" % [WORD_STEPS[tier - 1], language]
		"kept":
			badge["mark"] = str(KEPT_STEPS[tier - 1])
			badge["title"] = "Von gestern behalten!"
			badge["detail"] = str(detail_args.get("word", "")) if tier == 1 \
					else "Schon %d Wörter heute" % KEPT_STEPS[tier - 1]
		"revenge":
			badge["title"] = "Revanche!"
			badge["detail"] = "%s – diesmal nicht!" % str(detail_args.get("word", ""))
		"catch_up":
			badge["title"] = "Aufholjagd!"
			badge["detail"] = "%s – fast vergessen und doch gewusst" % str(detail_args.get("word", ""))
		"comeback":
			badge["title"] = "Comeback des Tages!"
			badge["detail"] = "Die Festung wackelte – und hält."
		"better":
			badge["title"] = "Besser als sonst!"
			badge["detail"] = "Heute %d %% richtig, sonst %d %%" % [
					roundi(100.0 * float(detail_args.get("accuracy", 0.0))),
					roundi(100.0 * float(detail_args.get("baseline", 0.0)))]
	return badge


## Je eine Plakette jeder Art, für das Debug-Panel.
static func samples() -> Array:
	return [make("hits", 1), make("hits", 2), make("hits", 3), make("hits", 4),
			make("words", 1, {"lang": "fr"}), make("words", 4, {"lang": "en"}),
			make("kept", 1, {"word": "house → Haus"}), make("kept", 2),
			make("revenge", 0, {"word": "receive → erhalten"}),
			make("catch_up", 0, {"word": "Haus → house"}),
			make("comeback", 0), make("better", 0, {"accuracy": 0.92, "baseline": 0.81})]



## Jede Plakette in jeder Stufe mit Beispieltexten, für die Werkbank (battle_theme_lab).
static func catalog() -> Array:
	var all := []
	for tier in range(1, 5):
		all.append(make("hits", tier))
	for tier in range(1, 5):
		all.append(make("words", tier, {"lang": "en"}))
	for tier in range(1, 5):
		all.append(make("kept", tier, {"word": "house → Haus"}))
	all.append_array([make("revenge", 0, {"word": "receive → erhalten"}),
			make("catch_up", 0, {"word": "Haus → house"}), make("comeback", 0),
			make("better", 0, {"accuracy": 0.92, "baseline": 0.81})])
	return all

# --- Im Kampf -----------------------------------------------------------------

## Eine neue Welle: Revanche und Aufholjagd gibt es wieder.
func new_wave() -> void:
	_this_wave.clear()


## Stand einer Aufgabe VOR ihrem Treffer — vor PlayerProgress.record() holen und nach dem
## Verbuchen an after_hit() geben.
func before_hit(task_id: String) -> Dictionary:
	var rec := PlayerProgress.record_of(task_id)
	var ctx := {"task": task_id, "rec": rec, "words": -1, "lang": ""}
	var parts := task_id.split(":")
	# Die Zahl der Wörter kann nur steigen, wenn diese Richtung noch nie richtig war.
	if parts.size() == 3 and parts[0] == "translate" and int(rec.get("correct_total", 0)) == 0:
		var lang := Lexeme.language_of_direction(parts[1])
		if not lang.is_empty():
			ctx["lang"] = lang
			ctx["words"] = PlayerProgress.lexemes_answered(lang)
	return ctx


## Die Plaketten eines eben verbuchten Treffers (record() und item_reviewed sind durch).
func after_hit(ctx: Dictionary) -> Array:
	_roll_day()
	var out: Array = []
	var tier := step_tier(HIT_STEPS, SessionLog.correct_today())
	if tier > 0:
		out.append(make("hits", tier))
	if int(ctx["words"]) >= 0:
		var lang := str(ctx["lang"])
		var now := PlayerProgress.lexemes_answered(lang)
		if now > int(ctx["words"]):
			tier = step_tier(WORD_STEPS, now)
			if tier > 0:
				out.append(make("words", tier, {"lang": lang}))
	var task_id := str(ctx["task"])
	var before: Dictionary = ctx["rec"]
	var kind := answer_kind(before, SessionLog.local_day(int(before.get("last_seen_at", 0))), _day)
	var word := TaskResolver.new().describe_learnable(task_id)
	match kind:
		"kept":
			if not task_id in _kept:
				_kept.append(task_id)
				_save()
				tier = step_tier(KEPT_STEPS, _kept.size())
				if tier > 0:
					out.append(make("kept", tier, {"word": word}))
		"revenge", "catch_up":
			if not kind in _this_wave:
				_this_wave.append(kind)
				out.append(make(kind, 0, {"word": word}))
	return out


## Die Plaketten einer gewonnenen Welle. `low_ratio`: tiefster HP-Stand der Welle als
## Anteil am Maximum.
func wave_won(low_ratio: float) -> Array:
	_roll_day()
	var out: Array = []
	if low_ratio <= COMEBACK_RATIO and _earn("comeback"):
		out.append(make("comeback", 0))
	var trend := SessionLog.session_accuracy()
	if is_better(trend) and _earn("better"):
		out.append(make("better", 0, trend))
	return out


## Heute schon verdient? Sonst jetzt verdienen (und speichern).
func _earn(id: String) -> bool:
	if id in _earned:
		return false
	_earned.append(id)
	_save()
	return true


# --- Tag und Datei ------------------------------------------------------------

## Ein neuer Tag beginnt (auch mitten im Lauf über Mitternacht): alles Tägliche von vorn.
func _roll_day() -> void:
	var today := SessionLog.local_day(int(Time.get_unix_time_from_system()))
	if today == _day:
		return
	_day = today
	_earned.clear()
	_kept.clear()


func _save_path() -> String:
	return "%s/%s_badges.json" % [SAVE_DIR, player_id]


func _save() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var file := FileAccess.open(_save_path(), FileAccess.WRITE)
	if file == null:
		push_warning("Badges: konnte '%s' nicht schreiben" % _save_path())
		return
	file.store_string(JSON.stringify({"day": _day, "earned": _earned, "kept": _kept}, "\t"))
	file.close()


func _load() -> void:
	_roll_day()
	if not FileAccess.file_exists(_save_path()):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_save_path()))
	if not (parsed is Dictionary) or int((parsed as Dictionary).get("day", -1)) != _day:
		return
	_earned = (parsed as Dictionary).get("earned", [])
	_kept = (parsed as Dictionary).get("kept", [])
