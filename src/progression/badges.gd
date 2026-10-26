class_name Badges
extends RefCounted
## Plaketten im Wellenkampf (Issue #63): kleine Erfolge des Tages und der Welle, unabhängig
## von der Meisterung; was für immer gilt, sind Erfolge (Achievements, Issue #74). Die Arten
## stehen im Handbuch „Kampf“. Treffer werden nicht mitgezählt, sondern aus SessionLog
## abgelesen. Gespeichert wird je Tag, was verdient wurde (außer den Treffern), und welche
## Aufgaben heute „behalten“ waren.

const SAVE_DIR := "user://progress"

const HIT_STEPS := [10, 25, 50, 100]
const KEPT_STEPS := [1, 5, 10, 25]
## Confidence vor dem Treffer, unter der es eine Aufholjagd ist. Neue Aufgaben starten bei
## PlayerProgress.DEFAULT_CONFIDENCE, darunter kommt man nur über Fehler.
const CATCH_UP_BELOW := 0.10
## Rote Zone des Lebensbalkens (Anteil), dieselbe wie im HUD.
const COMEBACK_RATIO := preload("res://src/ui/hud.gd").HP_WARN
## Höchstens so viel Spielzeit (s) hätte das letzte Monster der Welle noch bis zur Festung
## gebraucht, als es getroffen wurde (Monster.seconds_left).
const LAST_SECOND := 1.0

const TIER_NAMES := ["Bronze", "Silber", "Gold", "Diamant"]
const TIER_PALETTES := [&"bronze", &"silver", &"gold", &"diamond"]
## Stufen, deren Plaketten den gemeinsamen Ton haben (sound_of).
const COMMON_PALETTES := [&"bronze", &"silver"]

## Plaketten, die es je Tag einmal gibt (Stufen zählen als eigene).
const DAILY := ["comeback", "better", "last_second"]
## Plaketten, die es je Welle einmal gibt.
const PER_WAVE := ["revenge", "catch_up"]
## Plaketten eines Tages in der Reihenfolge der Statistik. Die Treffer rechnet `day_summary`
## aus den richtigen Antworten des Tages, alle übrigen stehen in der Datei.
const DAY_ORDER := ["hits", "kept", "comeback", "better", "last_second", "revenge", "catch_up"]

var player_id: String
var _day := -1
var _kept: Array = []
## Lokaler Tagesindex (als String, JSON) -> verdiente Plaketten [[id, tier], …].
var _days: Dictionary = {}
var _this_wave: Array = []
## Treffer der laufenden Welle, die eine Revanche waren, auch ohne neue Plakette.
var revenges_this_wave := 0


func _init(id: String = PlayerProgress.player_id) -> void:
	player_id = id
	_load()


# --- Regeln -------------------------------------------------------------------

## Stufe 1..4, wenn `count` genau eine der Schwellen ist, sonst 0.
static func step_tier(steps: Array, count: int) -> int:
	return steps.find(count) + 1


## Was ein Treffer mit dem Stand `before` (PlayerProgress-Record vor der Antwort) außerdem
## bedeutet: "catch_up", "revenge", "kept" oder "". `last_day`/`today` sind lokale
## Tagesindizes (SessionLog.local_day).
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


## Der Ton einer Plakette: Bronze und Silber teilen sich `badge_earned`, die übrigen heißen
## `badge_<palette>`.
static func sound_of(palette: StringName) -> StringName:
	return &"badge_earned" if palette in COMMON_PALETTES else StringName("badge_" + palette)


## Besser als sonst: beide Werte gelten (sonst -1) und die Sitzung liegt darüber.
static func is_better(trend: Dictionary) -> bool:
	var accuracy := float(trend.get("accuracy", -1.0))
	var baseline := float(trend.get("baseline", -1.0))
	return accuracy >= 0.0 and baseline >= 0.0 and accuracy > baseline


## Eine Plakette zum Zeigen: id, tier (0 ohne Stufe), title, detail, mark (Zahl auf der
## Plakette oder leer für ihr Zeichen), palette (BadgePlate) und sound (Sfx-Id).
static func make(id: String, tier: int, detail_args: Dictionary = {}) -> Dictionary:
	var palette: StringName = TIER_PALETTES[tier - 1] if tier > 0 else StringName(id)
	var badge := {"id": id, "tier": tier, "title": "", "detail": "", "mark": "",
			"palette": palette, "sound": sound_of(palette)}
	match id:
		"hits":
			badge["mark"] = str(HIT_STEPS[tier - 1])
			badge["title"] = "%d Treffer heute!" % HIT_STEPS[tier - 1]
			badge["detail"] = "%s-Plakette" % TIER_NAMES[tier - 1]
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
		"last_second":
			badge["title"] = "In letzter Sekunde!"
			badge["detail"] = "Das letzte Monster stand schon vor der Mauer."
		"better":
			badge["title"] = "Besser als sonst!"
			badge["detail"] = "Heute %d %% richtig, sonst %d %%" % [
					roundi(100.0 * float(detail_args.get("accuracy", 0.0))),
					roundi(100.0 * float(detail_args.get("baseline", 0.0)))]
	return badge


static func samples() -> Array:
	return [make("hits", 1), make("hits", 2), make("hits", 3), make("hits", 4),
			make("kept", 1, {"word": "house → Haus"}), make("kept", 2),
			make("revenge", 0, {"word": "receive → erhalten"}),
			make("catch_up", 0, {"word": "Haus → house"}),
			make("comeback", 0), make("last_second", 0),
			make("better", 0, {"accuracy": 0.92, "baseline": 0.81})]



static func catalog() -> Array:
	var all := []
	for tier in range(1, 5):
		all.append(make("hits", tier))
	for tier in range(1, 5):
		all.append(make("kept", tier, {"word": "house → Haus"}))
	all.append_array([make("revenge", 0, {"word": "receive → erhalten"}),
			make("catch_up", 0, {"word": "Haus → house"}), make("comeback", 0),
			make("last_second", 0), make("better", 0, {"accuracy": 0.92, "baseline": 0.81})])
	return all


# --- Statistik ----------------------------------------------------------------

## Höchste erreichte Stufe (0..4) bei `count`, für Treffer und Behaltenes.
static func reached_tier(steps: Array, count: int) -> int:
	var tier := 0
	for step: int in steps:
		if count >= step:
			tier += 1
	return tier


## Die Plaketten eines Tages, je Art eine: {id, tier, count}. `stored` wie in der Datei,
## `correct` die richtigen Antworten des Tages. Gestufte Arten zeigen ihre höchste Stufe,
## Wellen-Plaketten zählen mit.
static func day_summary(stored: Array, correct: int) -> Array:
	var tiers := {}
	var counts := {}
	var hit_tier := reached_tier(HIT_STEPS, correct)
	if hit_tier > 0:
		tiers["hits"] = hit_tier
		counts["hits"] = 1
	for entry in stored:
		var id := str((entry as Array)[0])
		tiers[id] = maxi(int(tiers.get(id, 0)), int((entry as Array)[1]))
		counts[id] = int(counts.get(id, 0)) + 1
	var out: Array = []
	for id: String in DAY_ORDER:
		if counts.has(id):
			var count := int(counts[id]) if id in PER_WAVE else 1
			out.append({"id": id, "tier": int(tiers[id]), "count": count})
	return out


## Wie oft es jede Art von `DAY_ORDER` gab, über alle Tage: id -> {tiers (Tage je Stufe 1..4,
## eine höhere Stufe zählt die niedrigeren mit), count (Plaketten), days, last (Tagesindex, -1
## für nie)}. `days` wie `all_days`, `correct_by_day` wie SessionLog.correct_by_day.
static func tally(days: Dictionary, correct_by_day: Dictionary) -> Dictionary:
	var out := {}
	for id: String in DAY_ORDER:
		out[id] = {"tiers": [0, 0, 0, 0], "count": 0, "days": 0, "last": -1}
	var all := {}
	for day: int in days:
		all[day] = true
	for day: int in correct_by_day:
		all[day] = true
	for day: int in all:
		for entry: Dictionary in day_summary(days.get(day, []), int(correct_by_day.get(day, 0))):
			var t: Dictionary = out[entry["id"]]
			t["count"] = int(t["count"]) + int(entry["count"])
			t["days"] = int(t["days"]) + 1
			t["last"] = maxi(int(t["last"]), day)
			for i in int(entry["tier"]):
				t["tiers"][i] = int(t["tiers"][i]) + 1
	return out


## Überschrift und Erklärung einer Plakette in der Statistik, ohne Bezug auf „heute“ und
## ohne das Wort, an dem sie hing.
static func describe(id: String, tier: int) -> Dictionary:
	var tier_name: String = TIER_NAMES[tier - 1] if tier > 0 else ""
	match id:
		"hits":
			return {"title": "%d Treffer an einem Tag" % HIT_STEPS[tier - 1],
					"body": "%s-Plakette" % tier_name}
		"kept":
			return {"title": "Von gestern behalten",
					"body": ("Ein Wort getroffen, das du an einem früheren Tag zuletzt richtig hattest"
					if tier == 1 else "%d solche Wörter an einem Tag" % KEPT_STEPS[tier - 1])
					+ " (%s-Plakette)" % tier_name}
		"revenge":
			return {"title": "Revanche!", "body": "Ein Wort getroffen, das dir zuletzt entwischt ist."}
		"catch_up":
			return {"title": "Aufholjagd!", "body": "Ein Wort gewusst, das fast schon vergessen war."}
		"comeback":
			return {"title": "Comeback des Tages!",
					"body": "Die Festung stand im roten Bereich, und die Welle war trotzdem gewonnen."}
		"last_second":
			return {"title": "In letzter Sekunde!",
					"body": "Das letzte Monster stand schon vor der Mauer."}
		"better":
			return {"title": "Besser als sonst!",
					"body": "Mehr Antworten richtig als in den Tagen davor."}
	return {"title": id, "body": ""}


## Die verdienten Plaketten eines Tages, wie gespeichert: [[id, tier], …].
func day_list(day: int) -> Array:
	return (_days.get(str(day), []) as Array).duplicate(true)


## Alle Tage mit gespeicherten Plaketten: Tagesindex -> [[id, tier], …].
func all_days() -> Dictionary:
	var out := {}
	for key: String in _days:
		out[int(key)] = (_days[key] as Array).duplicate(true)
	return out


# --- Im Kampf -----------------------------------------------------------------

## Eine neue Welle: Revanche und Aufholjagd gibt es wieder.
func new_wave() -> void:
	_this_wave.clear()
	revenges_this_wave = 0


## Stand einer Aufgabe vor ihrem Treffer: vor PlayerProgress.record() holen und nach dem
## Verbuchen an after_hit() geben.
func before_hit(task_id: String) -> Dictionary:
	return {"task": task_id, "rec": PlayerProgress.record_of(task_id)}


## Die Plaketten eines eben verbuchten Treffers (record() und item_reviewed sind durch).
func after_hit(ctx: Dictionary) -> Array:
	_roll_day()
	var out: Array = []
	var tier := step_tier(HIT_STEPS, SessionLog.correct_today())
	if tier > 0:
		out.append(make("hits", tier))
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
					_note("kept", tier)
					out.append(make("kept", tier, {"word": word}))
		"revenge", "catch_up":
			if kind == "revenge":
				revenges_this_wave += 1
			if not kind in _this_wave:
				_this_wave.append(kind)
				_note(kind, 0)
				out.append(make(kind, 0, {"word": word}))
	return out


## Die Plaketten einer gewonnenen Welle. `low_ratio`: tiefster HP-Stand der Welle als
## Anteil am Maximum. `last_left`: Monster.seconds_left des Treffers, der das Feld geleert
## hat, INF ohne einen solchen.
func wave_won(low_ratio: float, last_left := INF) -> Array:
	_roll_day()
	var out: Array = []
	if low_ratio <= COMEBACK_RATIO and _earn("comeback"):
		out.append(make("comeback", 0))
	if last_left <= LAST_SECOND and _earn("last_second"):
		out.append(make("last_second", 0))
	var trend := SessionLog.session_accuracy()
	if is_better(trend) and _earn("better"):
		out.append(make("better", 0, trend))
	return out


## Heute schon verdient? Sonst jetzt verdienen (und speichern).
func _earn(id: String) -> bool:
	for entry: Array in _days.get(str(_day), []):
		if str(entry[0]) == id:
			return false
	_note(id, 0)
	return true


## Trägt eine Plakette beim heutigen Tag ein und speichert.
func _note(id: String, tier: int) -> void:
	var key := str(_day)
	if not _days.has(key):
		_days[key] = []
	(_days[key] as Array).append([id, tier])
	_save()


# --- Tag und Datei ------------------------------------------------------------

## Ein neuer Tag beginnt (auch mitten im Lauf): alles Tägliche von vorn.
func _roll_day() -> void:
	var today := SessionLog.local_day(int(Time.get_unix_time_from_system()))
	if today == _day:
		return
	_day = today
	_kept.clear()


func _save_path() -> String:
	return "%s/%s_badges.json" % [SAVE_DIR, player_id]


func save_path() -> String:
	return _save_path()


func save_suffix() -> String:
	return "_badges"


func save_payload() -> Dictionary:
	return {"day": _day, "kept": _kept.duplicate(), "days": _days.duplicate(true)}


## Lädt den Tag neu (verworfene Welle): was in ihr verdient wurde, gibt es noch einmal.
func reload() -> void:
	_day = -1
	_kept = []
	_days = {}
	_load()


func _save() -> void:
	SaveCoordinator.mark_dirty(self)


func _load() -> void:
	_roll_day()
	var read := SaveStore.read(_save_path())
	if int(read["status"]) != SaveStore.Status.OK:
		return
	var parsed: Dictionary = read["data"]
	var days: Variant = parsed.get("days", {})
	if days is Dictionary:
		_days = days
	if int(parsed.get("day", -1)) != _day:
		return
	_kept = parsed.get("kept", [])
	# Dateien vor der Historie kennen nur die Tages-Plaketten von heute; gespeichert wird
	# erst mit der nächsten Plakette.
	var legacy: Array = parsed.get("earned", [])
	if not legacy.is_empty() and not _days.has(str(_day)):
		_days[str(_day)] = legacy.map(func(id): return [str(id), 0])
