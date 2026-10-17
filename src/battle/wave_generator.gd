class_name WaveGenerator
extends RefCounted
## Wählt für einen Spawn eine Aufgabe und ihr Monster (ADR 0018). Tempo, Punkte und
## Erfahrung kommen aus `t - c` (docs/ARCHITECTURE.md, „Tempo = Schwierigkeit“).
## pick(pool) -> {task, monster_def, speed, gap, damage, reward, xp} oder {}, wenn nichts
## Spielbares da ist.

var _resolver := TaskResolver.new()

## Tempo bei `t - c` = 0; ändern verschiebt die Schwierigkeit aller Aufgaben.
const REFERENCE_SPEED := 35.0
## Wie stark `t - c` das Tempo auslenkt.
const SPEED_SENSITIVITY := 0.3
## Obergrenze der difficulty-Skala für die Normalisierung auf 0..1.
const DIFFICULTY_MAX := 5

## Punkte bei `t - c` = 0.
const REFERENCE_REWARD := 12
## Wie stark `t - c` die Punkte auslenkt.
const REWARD_SENSITIVITY := 0.6
## Anteil der Punkte für ein Monster mit gemeisterter Aufgabe, wie Experience.MASTERED_XP.
const MASTERED_REWARD_FACTOR := 0.1

## Schadensfaktor der Wellen 1 und 2; ab Welle 3 gilt `base_damage` und wächst je Welle um
## DAMAGE_GROWTH_PER_WAVE, ohne Deckel.
const EARLY_WAVE_DAMAGE: Array[float] = [0.6, 0.8]
const DAMAGE_GROWTH_PER_WAVE := 0.15

## Die Gruppen der Auswahl, so auch in der Spur; gewählt wird nach Gewicht.
const GROUP_DUE := "due"
const GROUP_NEW := "new"
const GROUP_REST := "rest"

## Gewicht eines neuen Worts. Ein unsicheres, fälliges Wort (c 0.5) liegt bei 0.5–1, ein
## gemeistertes bei 0.05–0.3 (selection_weight()).
const NEW_WEIGHT := 1.0
## Mindestanteil der neuen Wörter am Gesamtgewicht, solange es welche gibt.
const NEW_SHARE := 0.3
## Untergrenze des Bedarfs (1 − c): Gemeistertes kommt selten, aber nicht nie.
const NEED_FLOOR := 0.05
## Obergrenze der Dringlichkeit (verstrichener Anteil des Intervalls).
const URGENCY_CAP := 2.0
## Mindestanteil nicht gemeisterter Monster einer Welle, laufend gezählt (open_due()), damit
## das Wachkatapult nicht die ganze Welle abräumt.
const OPEN_SHARE := 0.5

## Neue Aufgaben (ADR 0027): so viele Einführungen je Welle, solange es in der Welle noch
## nicht gezeigte bekannte Aufgaben gibt; danach kommen erst die.
const INTRODUCTIONS_PER_WAVE := 5
## So viele Spawns nach dem Abtippen kommt die Aufgabe ohne Lösung wieder.
const RETEST_AFTER := 2

## Tippzeit (ADR 0026): Eine Antwort über LONG_ANSWER_CHARS Zeichen bremst ihr Monster im
## Verhältnis der Länge, höchstens bis MIN_TYPING_PACE, und hält den nächsten Spawn zurück,
## bis es weg ist, höchstens so lange, wie das Tippen bei TYPING_CHARS_PER_SECOND dauert.
## Kein Maß der Schwierigkeit:
## Punkte und Erfahrung bleiben bei `t - c`.
const LONG_ANSWER_CHARS := 30
const MIN_TYPING_PACE := 0.25
## Zeichen je Sekunde samt Lesen und Nachdenken.
const TYPING_CHARS_PER_SECOND := 2.0

## Wellenfaktor auf Tempo und Punkte, nicht auf Erfahrung (1.0 = neutral, >1 schwerer).
var speed_scale: float = 1.0
## Schadens-Multiplikator der Welle (wave_damage_scale()); trifft nur den Schaden.
var damage_scale: float = 1.0


## Schadensfaktor einer Welle: 0,6 · 0,8 · 1,0 · 1,15 · 1,3 · … Welle ≤ 0 zählt als Welle 1.
static func wave_damage_scale(wave_number: int) -> float:
	var n := maxi(1, wave_number)
	if n <= EARLY_WAVE_DAMAGE.size():
		return EARLY_WAVE_DAMAGE[n - 1]
	return 1.0 + DAMAGE_GROWTH_PER_WAVE * (n - EARLY_WAVE_DAMAGE.size() - 1)

## Zeichenzahl der kürzesten Eingabe, die eine Aufgabe annimmt: ohne optionalen Artikel,
## ohne weglassbare Klammergruppe (`AnswerEvaluator.variants`).
static func answer_chars(answers: Array) -> int:
	var evaluator := AnswerEvaluator.new()
	var shortest := -1
	for answer in answers:
		for key in evaluator.variants(str(answer)):
			var n := str(key).length()
			if n > 0 and (shortest < 0 or n < shortest):
				shortest = n
	return maxi(shortest, 0)


## Tempofaktor für eine Antwort mit `chars` Zeichen, 1 bei kurzen.
static func typing_pace(chars: int) -> float:
	if chars <= LONG_ANSWER_CHARS:
		return 1.0
	return maxf(MIN_TYPING_PACE, float(LONG_ANSWER_CHARS) / chars)


## Sekunden, die der nächste Spawn mindestens wartet, 0 bei kurzen Antworten.
static func typing_gap(chars: int) -> float:
	if chars <= LONG_ANSWER_CHARS:
		return 0.0
	return chars / TYPING_CHARS_PER_SECOND


## Start-Confidence (Prior) einer ungesehenen Aufgabe aus `cefr` / `frequency_band` des
## Lexems; ohne beide gilt PlayerProgress.DEFAULT_CONFIDENCE.
const CEFR_PRIOR := {
	"A1": 0.50, "A2": 0.40, "B1": 0.30, "B2": 0.20, "C1": 0.12, "C2": 0.08,
}
const FREQUENCY_PRIOR := {
	"core": 0.45, "high": 0.42, "common": 0.35, "mid": 0.30, "low": 0.20, "rare": 0.12,
}


## Mittelt die Prior-Signale eines Lexems, 0..1.
func _confidence_prior(source: Dictionary) -> float:
	var priors: Array = []
	var cefr := str(source.get("cefr", "")).to_upper()
	if CEFR_PRIOR.has(cefr):
		priors.append(float(CEFR_PRIOR[cefr]))
	var band := str(source.get("frequency_band", "")).to_lower()
	if FREQUENCY_PRIOR.has(band):
		priors.append(float(FREQUENCY_PRIOR[band]))
	if priors.is_empty():
		return PlayerProgress.DEFAULT_CONFIDENCE
	var sum := 0.0
	for p in priors:
		sum += p
	return sum / float(priors.size())


## Start-Confidence einer Formaufgabe, deren Form aus der Regel folgt (Verb ohne
## `irregular`, Vergangenheit auf -ed; ADR 0009): gemeistert nach zwei Treffern.
const RULE_FORM_PRIOR := 0.65
## Regel mit Schreibfalle: verdoppelter Konsonant oder y → ied.
const SPELLING_FORM_PRIOR := 0.6
## Formen, bei denen eine Sprache „regelmäßig“ kennt (ADR 0009, Punkt 2).
const RULE_FORMS := {"en": ["past_simple", "past_participle"]}


## Wie eine englische Vergangenheitsform zu ihrer Grundform steht: "plain", "spelling"
## (Schreibfalle) oder "" (nicht nach der Regel). Bei mehreren Wörtern zählt das erste.
static func rule_form_kind(base: String, value: String) -> String:
	var parts := base.split(" ", false, 1)
	if parts.is_empty():
		return ""
	var head := parts[0]
	var tail := (" " + parts[1]) if parts.size() > 1 else ""
	if not value.ends_with(tail):
		return ""
	var form := value.substr(0, value.length() - tail.length())
	if form == head + "ed" or (head.ends_with("e") and form == head + "d"):
		return "plain"
	if head.length() > 1 and form == head + head.right(1) + "ed":
		return "spelling"
	if head.ends_with("y") and form == head.substr(0, head.length() - 1) + "ied":
		return "spelling"
	return ""


## Prior einer Formaufgabe nach der Regel (RULE_FORM_PRIOR), sonst -1.
func _rule_form_prior(definition: Dictionary, source: Dictionary) -> float:
	var form_type := str(definition.get("requires_form", ""))
	if not form_type in RULE_FORMS.get(Lexeme.language(source), []):
		return -1.0
	if bool(source.get("irregular", false)):
		return -1.0
	var id := str(source.get("id", ""))
	var bases := ContentRegistry.forms_for(id, "base")
	var base := str(bases[0].get("value", "")) if not bases.is_empty() else Lexeme.foreign(source)
	var forms := ContentRegistry.forms_for(id, form_type, _resolver.scope)
	if forms.is_empty():
		return -1.0
	var spelling := false
	for form in forms:
		match rule_form_kind(base, str(form.get("value", ""))):
			"plain":
				pass
			"spelling":
				spelling = true
			_:
				return -1.0
	return SPELLING_FORM_PRIOR if spelling else RULE_FORM_PRIOR


## Aufgaben-Pool aus der Auswahl des Profils (Expertenmodus); leer schränkt nicht ein. Der
## Kampf liest seinen Pool über RunRequest.task_pool().
static func pool_from_settings() -> Dictionary:
	return {
		"task_types": Array(UserSettings.selected_task_types()),
		"lexeme_types": Array(UserSettings.selected_lexeme_types()),
		"scope": Array(UserSettings.selected_scope()),
		"tags": Array(UserSettings.selected_tags()),
	}


## Stichprobe in has_playable() vor dem ganzen Pool (~300 ms bei ~2000 Lexemen).
const PROBE_CANDIDATES := 64


## Gibt der Pool eine auflösbare Aufgabe her? Ein „nein“ prüft den ganzen Pool.
func has_playable(pool: Dictionary) -> bool:
	for limit in [PROBE_CANDIDATES, 0]:
		for candidate in _candidates(pool, limit):
			if not _build_plan(candidate).is_empty():
				return true
	return false


## `exclude_sources` (Lexem-id -> true): Grundwörter auf dem Feld. `shown_sources` (Lexem-id
## -> Spawn-Nummer): in dieser Welle gezeigte, sie kommen nach dem Rest. `order`: Playlist
## einer Testliste (TestPlaylist.wave_order). `open_first`: eine nicht gemeisterte Aufgabe
## vorziehen, wenn es eine gibt (open_due()). `intro`: die Einführungen des Laufs (ADR 0027),
## eine fällige Wiederholung geht allem vor. Der Grund der Wahl steht in `task["pick"]`.
func pick(pool: Dictionary, exclude_sources: Dictionary = {}, shown_sources: Dictionary = {},
		order: Array = [], open_first := false, intro: Introductions = null) -> Dictionary:
	var candidates := listing(pool, shown_sources, -1, intro)
	if not order.is_empty():
		candidates = TestPlaylist.arrange(candidates, order)
	if intro != null:
		candidates = retests_first(candidates, intro.due())
	var plan := pick_with(candidates, exclude_sources, open_first)
	if not order.is_empty() and not plan.is_empty():
		plan["task"]["pick"]["playlist"] = true
	return plan


## Alle Kandidaten des Pools, ungeordnet, für die Playlist einer Testliste.
func candidates(pool: Dictionary) -> Array:
	return _candidates(pool)


## Die Kandidaten des Pools in der Reihenfolge, in der pick() sie probiert, jeder mit
## `group`, `repeat` und `weight` (siehe ordered()). `now`: Bezugszeit (unix, -1 = jetzt).
func listing(pool: Dictionary, shown_sources: Dictionary, now := -1,
		intro: Introductions = null) -> Array:
	if now < 0:
		now = int(Time.get_unix_time_from_system())
	return ordered(_candidates(pool), PlayerProgress.state_of, shown_sources, now, intro)


## Stellt die Kandidaten mit fälliger Wiederholung (`due`: learnable_ids) nach vorn und
## markiert sie mit `retest`; die übrige Reihenfolge bleibt.
static func retests_first(candidates: Array, due: Array) -> Array:
	if due.is_empty():
		return candidates
	var front: Array = []
	var rest: Array = []
	for c in candidates:
		if c["learnable_id"] in due:
			c["retest"] = true
			front.append(c)
		else:
			rest.append(c)
	return front + rest


## Woran „schon eingeführt" hängt: eine Übersetzung am Wort, denn wer eine Richtung
## abgetippt hat, kennt beide Seiten; jede andere Aufgabe an sich selbst.
static func help_key(candidate: Dictionary) -> String:
	if str(candidate["definition"].get("task_type", "")) == "translate":
		return "translate:" + str(candidate["source"].get("id", ""))
	return str(candidate["learnable_id"])


## Steht die Lösung auf dem Schild? Ja für eine nie beantwortete Aufgabe, die im Lauf noch
## nicht eingeführt war; eine Übersetzung nur, wenn auch die Gegenrichtung nie dran war.
## Eine Form nie: sie folgt meist aus dem Wort. Abtippen verbucht nichts, die Wiederholung
## (RETEST_AFTER) ist die erste Antwort.
static func needs_help(candidate: Dictionary, state: Callable, intro: Introductions) -> bool:
	if intro == null or intro.keys.has(help_key(candidate)):
		return false
	if not str(candidate["definition"].get("requires_form", "")).is_empty():
		return false
	if not (state.call(candidate["learnable_id"]) as Dictionary).is_empty():
		return false
	var reverse := reverse_translation(candidate)
	return reverse.is_empty() or (state.call(reverse) as Dictionary).is_empty()


## Die learnable_id der Gegenrichtung einer Übersetzung, leer für jede andere Aufgabe.
static func reverse_translation(candidate: Dictionary) -> String:
	var definition: Dictionary = candidate["definition"]
	if str(definition.get("task_type", "")) != "translate":
		return ""
	var sides := str(definition.get("direction", "")).split("_to_")
	if sides.size() != 2:
		return ""
	return TaskResolver.learnable_id("translate", "%s_to_%s" % [sides[1], sides[0]],
			str(candidate["source"].get("id", "")))


## Muss der nächste Spawn offen sein? `open` von `spawned` bisherigen Monstern waren es.
## Bei 0,5: das erste, dann jedes zweite.
static func open_due(open: int, spawned: int) -> bool:
	return open < ceili(OPEN_SHARE * (spawned + 1))


## Wählt aus einer listing() den ersten spielbaren Kandidaten. Findet sich ohne die
## Grundwörter auf dem Feld nichts, fällt die Sperre. `open_first` probiert vor jeder Stufe
## erst die nicht gemeisterten Kandidaten (`mastered` aus ordered()), die in dieser Welle
## noch nicht dran waren — der Anteil wiederholt kein Wort.
func pick_with(ordered_candidates: Array, exclude_sources: Dictionary = {},
		open_first := false) -> Dictionary:
	var passes: Array = [true, false] if open_first else [false]
	for respect_exclude in [true, false]:
		for open_only in passes:
			var plan := _first_plan(ordered_candidates, exclude_sources, respect_exclude, open_only)
			if not plan.is_empty():
				return plan
	return {}


func _first_plan(ordered_candidates: Array, exclude_sources: Dictionary, respect_exclude: bool,
		open_only: bool) -> Dictionary:
	for i in ordered_candidates.size():
		var candidate: Dictionary = ordered_candidates[i]
		if open_only and (bool(candidate.get("mastered", false))
				or (bool(candidate.get("repeat", false)) and not bool(candidate.get("retest", false)))):
			continue
		if respect_exclude and exclude_sources.has(str(candidate["source"].get("id", ""))):
			continue
		var plan := _build_plan(candidate)
		if not plan.is_empty():
			plan["task"]["pick"] = pick_reason(ordered_candidates, i, not respect_exclude,
					float(plan["net"]), int(candidate.get("due_at", 0)))
			return plan
	return {}


## Warum der Kandidat an Stelle `index` gewählt wurde. Nur Ids und Zahlen, keine Wörter.
##   group:    "due" | "new" | "rest" (siehe ordered())
##   repeat:   das Wort war in dieser Welle schon dran (alle anderen sind verbraucht)
##   pos:      Stelle in der Reihenfolge (0 = vorn)
##   pool:     Zahl der Kandidaten
##   counts:   je Gruppe, wie viele noch nicht gezeigte es gab, dazu `repeat`
##   fallback: die Sperre gegen Wörter auf dem Feld musste fallen
##   net:      t - c des Monsters
##   due_at:   Fälligkeit (unix), 0 = nie beantwortet
##   last_seen: zuletzt beantwortet, über alle Aufgaben des Grundworts (unix), 0 = nie
##   weight:   Gewicht in der Auswahl (selection_weight())
##   retest:   Wiederholung ohne Lösung nach dem Abtippen (ADR 0027)
static func pick_reason(candidates: Array, index: int, fallback: bool, net: float,
		due_at: int) -> Dictionary:
	var counts := {GROUP_DUE: 0, GROUP_NEW: 0, GROUP_REST: 0, "repeat": 0}
	for c in candidates:
		if bool(c.get("repeat", false)):
			counts["repeat"] += 1
		else:
			counts[str(c["group"])] += 1
	var chosen: Dictionary = candidates[index]
	return {
		"group": str(chosen["group"]),
		"repeat": bool(chosen.get("repeat", false)),
		"pos": index,
		"pool": candidates.size(),
		"counts": counts,
		"fallback": fallback,
		"net": snappedf(net, 0.01),
		"due_at": due_at,
		"last_seen": int(chosen.get("last_seen", 0)),
		"weight": snappedf(float(chosen.get("weight", 0.0)), 0.01),
		"retest": bool(chosen.get("retest", false)),
	}


const GROUP_LABELS := {"due": "fällig", "new": "neu", "rest": "Rest"}


## Der Grund als eine Zeile. `now`: Bezugszeit für die Fälligkeit (unix).
static func describe_reason(why: Dictionary, now: int) -> String:
	if why.is_empty():
		return ""
	var group := str(GROUP_LABELS.get(str(why.get("group", "")), why.get("group", "")))
	var due_at := int(why.get("due_at", 0))
	if due_at > 0:
		group += " (%s)" % due_text(due_at, now)
	var last_seen := int(why.get("last_seen", 0))
	if last_seen > 0:
		group += ", zuletzt vor " + span_text(now - last_seen)
	if bool(why.get("repeat", false)):
		group = "Wiederholung, " + group
	if bool(why.get("retest", false)):
		group = "nach dem Abtippen, " + group
	var counts: Dictionary = why.get("counts", {})
	var parts: Array = [
		group,
		"Platz %d von %d" % [int(why.get("pos", 0)) + 1, int(why.get("pool", 0))],
		"fällig %d / neu %d / Rest %d / schon gezeigt %d" % [int(counts.get("due", 0)),
				int(counts.get("new", 0)), int(counts.get("rest", 0)), int(counts.get("repeat", 0))],
		"t−c %+.2f" % float(why.get("net", 0.0)),
	]
	if why.has("weight"):
		parts.append("Gewicht %.2f" % float(why["weight"]))
	if bool(why.get("fallback", false)):
		parts.append("trotz Wort auf dem Feld")
	return " · ".join(parts)


## „seit 2 T", „in 8 min" — die Fälligkeit relativ zu `now`.
static func due_text(due_at: int, now: int) -> String:
	var delta := due_at - now
	return ("in " if delta > 0 else "seit ") + span_text(delta)


## „8 min", „3 h", „2 T" für eine Spanne in Sekunden (Vorzeichen egal).
static func span_text(seconds: int) -> String:
	var span := absi(seconds)
	if span < 3600:
		return "%d min" % ceili(span / 60.0)
	if span < 86400:
		return "%d h" % roundi(span / 3600.0)
	return "%d T" % roundi(span / 86400.0)


## Die Auswahlreihenfolge von pick() (ADR 0018). `state`: learnable_id -> {} oder
## PlayerProgress.state_of. `now`: Bezugszeit (unix). Setzt an jedem Kandidaten `group`,
## `repeat`, `last_seen` (des Grundworts), `due_at`, `weight`, `mastered` (wie
## PlayerProgress.is_mastered) und `help` (needs_help()). Hat `intro` in dieser Welle schon
## INTRODUCTIONS_PER_WAVE eingeführt, stehen die ungezeigten ohne Lösung vor denen mit.
static func ordered(candidates: Array, state: Callable, shown: Dictionary, now: int,
		intro: Introductions = null) -> Array:
	# `last_seen` am Grundwort, über alle Richtungen und Aufgabenarten.
	var states := {}
	var word_seen := {}
	for c in candidates:
		var id: String = c["learnable_id"]
		states[id] = state.call(id)
		var source := str(c["source"].get("id", ""))
		word_seen[source] = maxi(int(word_seen.get(source, 0)),
				int(states[id].get("last_seen", 0)))
	var fresh: Array = []
	var repeats := {} # Spawn-Nummer -> Kandidaten
	for c in candidates:
		var st: Dictionary = states[c["learnable_id"]]
		var source_id := str(c["source"].get("id", ""))
		c["last_seen"] = int(word_seen.get(source_id, 0))
		c["due_at"] = int(st.get("due_at", 0))
		if st.is_empty():
			c["group"] = GROUP_NEW
		else:
			c["group"] = GROUP_DUE if now >= int(c["due_at"]) else GROUP_REST
		c["weight"] = selection_weight(st, int(c["last_seen"]), now)
		c["mastered"] = not st.is_empty() \
				and float(st.get("confidence", 0.0)) >= PlayerProgress.MASTERY_CONFIDENCE
		c["repeat"] = shown.has(source_id)
		c["help"] = needs_help(c, state, intro)
		if shown.has(source_id):
			var key := int(shown[source_id])
			if not repeats.has(key):
				repeats[key] = []
			repeats[key].append(c)
		else:
			fresh.append(c)
	var out: Array
	var known := fresh.filter(func(c): return not bool(c["help"]))
	if intro != null and intro.in_wave >= INTRODUCTIONS_PER_WAVE and not known.is_empty():
		out = weighted_order(_with_new_share(known))
		out.append_array(weighted_order(fresh.filter(func(c): return bool(c["help"]))))
	else:
		out = weighted_order(_with_new_share(fresh))
	var keys := repeats.keys()
	keys.sort()
	for key in keys:
		out.append_array(weighted_order(repeats[key]))
	return out


## Gewicht eines Kandidaten: Bedarf × Dringlichkeit, ein neues Wort NEW_WEIGHT.
##
##   Bedarf        1 − c, mindestens NEED_FLOOR — gemeistert heißt selten, nicht nie.
##   Dringlichkeit verstrichener Anteil des Intervalls (1 = gerade fällig), bis URGENCY_CAP,
##                 gemessen ab der letzten Antwort auf das Grundwort (`word_seen`).
static func selection_weight(state: Dictionary, word_seen: int, now: int) -> float:
	if state.is_empty():
		return NEW_WEIGHT
	var last := int(state.get("last_seen", 0))
	var interval := maxi(int(state.get("due_at", 0)) - last, 1)
	var since := maxi(now - maxi(word_seen, last), 0)
	var urgency := clampf(float(since) / interval, 0.0, URGENCY_CAP) if last > 0 else 1.0
	var need := maxf(1.0 - float(state.get("confidence", 0.0)), NEED_FLOOR)
	return need * urgency


## Hebt die neuen Kandidaten so weit an, dass sie zusammen mindestens NEW_SHARE des
## Gesamtgewichts tragen. Ändert die Kandidaten in place und gibt sie zurück.
static func _with_new_share(candidates: Array) -> Array:
	var new_sum := 0.0
	var other_sum := 0.0
	for c in candidates:
		if c["group"] == GROUP_NEW:
			new_sum += float(c["weight"])
		else:
			other_sum += float(c["weight"])
	if new_sum <= 0.0:
		return candidates
	var scale := NEW_SHARE * other_sum / ((1.0 - NEW_SHARE) * new_sum)
	if scale > 1.0:
		for c in candidates:
			if c["group"] == GROUP_NEW:
				c["weight"] = float(c["weight"]) * scale
	return candidates


## Gewichtete Zufallsreihenfolge ohne Zurücklegen (Efraimidis–Spirakis): Schlüssel
## ln(u) / w, der größte zuerst. Ein Gewicht 0 steht hinten, fällt aber nicht weg.
static func weighted_order(candidates: Array) -> Array:
	var keyed: Array = []
	for c in candidates:
		var w := maxf(float(c.get("weight", 0.0)), 1e-9)
		keyed.append([log(maxf(randf(), 1e-12)) / w, c])
	keyed.sort_custom(func(a, b): return float(a[0]) > float(b[0]))
	return keyed.map(func(k): return k[1])


## Alle spielbaren Kandidaten (Definition × Lexem [× Form/Relation]) mit learnable_id.
## `limit` > 0 schneidet ab, nur für die Stichprobe in has_playable().
func _candidates(pool: Dictionary, limit: int = 0) -> Array:
	var task_types: Array = pool.get("task_types", [])
	var tags: Array = pool.get("tags", [])
	var scope: Array = pool.get("scope", []) # leer -> alle Bücher/Units
	var lexeme_types: Array = pool.get("lexeme_types", []) # leer -> alle Wortarten
	var direction := str(pool.get("direction", "")) # "" = beliebige Richtung
	# leerer scope/tags -> alle Lexeme; dazu die der Boni, die der Scope mitspielt
	var lexemes := ContentRegistry.lexemes_for_run(scope, tags)
	_resolver.scope = scope
	if not lexeme_types.is_empty():
		lexemes = lexemes.filter(func(lx): return str(lx.get("type", "")) in lexeme_types)
	# Ein Wort, das nur über einen Form-Bonus dabei ist, bringt nur seine Bonus-Formen mit
	# (ADR 0012); eins aus einem Wort-Bonus (ADR 0013) alle Aufgaben.
	var bonus_only := {}
	if not scope.is_empty():
		var own := {}
		for entry in ContentRegistry.lexemes_scoped(scope, tags):
			own[str(entry.get("id", ""))] = true
		for entry in lexemes:
			if not own.has(str(entry.get("id", ""))) \
					and not ContentRegistry.in_word_bonus(entry, scope):
				bonus_only[str(entry.get("id", ""))] = true
	# Eine Testliste nennt ihre Wörter selbst; dazu kommen die Wörter ihrer Form-Boni.
	if pool.has("lexeme_ids"):
		var listed := {}
		for id in pool["lexeme_ids"]:
			listed[str(id)] = true
		lexemes = lexemes.filter(func(lx):
			var id := str(lx.get("id", ""))
			return listed.has(id) or bonus_only.has(id))
	var direction_mode := str(pool.get("direction_mode", ""))
	var result: Array = []
	for definition in ContentRegistry.task_definitions.values():
		if not definition_allowed(definition, task_types, direction):
			continue
		if not TestLists.direction_allows(direction_mode, str(definition.get("direction", ""))):
			continue
		_expand(definition, lexemes, result, limit, scope, bonus_only)
		if limit > 0 and result.size() >= limit:
			break
	return result


## Passt eine task_definition zu den Filtern des Pools? Leere `task_types` und leere
## `direction` heißen „keine Einschränkung“. Nach `difficulty` wird nicht gefiltert
## (docs/ARCHITECTURE.md, „Ein Filter nach Schwierigkeit“).
static func definition_allowed(definition: Dictionary, task_types: Array,
		direction: String) -> bool:
	var task_type := str(definition.get("task_type", ""))
	if not task_types.is_empty() and not (task_type in task_types):
		return false
	if direction != "" and str(definition.get("direction", "")) != direction:
		return false
	return true


## Hängt die Kandidaten einer Definition an. Von Wörtern in `bonus_only` (Lexem-Id -> true)
## kommen nur ihre Bonus-Formaufgaben.
func _expand(definition: Dictionary, lexemes: Array, result: Array, limit: int = 0,
		scope: Array = [], bonus_only: Dictionary = {}) -> void:
	for source in lexemes:
		if limit > 0 and result.size() >= limit:
			return
		if bonus_only.has(str(source.get("id", ""))) and not _bonus_task(definition, source, scope):
			continue
		for extra in _instances(definition, source, scope):
			result.append(_candidate(definition, source, extra))


## Ist die Definition für dieses Wort eine Bonus-Aufgabe — eine Formaufgabe, deren Form in
## `scope` als Bonus mitspielt, oder ein Buchsatz, dessen Bonus gewählt ist?
func _bonus_task(definition: Dictionary, source: Dictionary, scope: Array) -> bool:
	if bool(definition.get("requires_example", false)):
		return ContentRegistry.examples_in_scope(source, scope)
	var form_type := str(definition.get("requires_form", ""))
	if form_type.is_empty():
		return false
	for form in ContentRegistry.forms_for(str(source.get("id", "")), form_type, scope):
		if not ContentRegistry.bonus_of_form(form).is_empty() \
				and ContentRegistry.form_task_in_scope(form, scope):
			return true
	return false


## Die `extra`-Bausteine, mit denen eine Definition auf ein Lexem passt, leer, wenn nicht.
## Die eine Stelle, die sagt, welche Aufgaben es zu einem Wort gibt; beachtet
## `excluded_task_types` (docs/ADDING_CONTENT.md) und die Sprache (ohne Feld englisch).
## `scope` filtert Formen über ContentRegistry.form_task_in_scope, leer zählt jede.
func _instances(definition: Dictionary, source: Dictionary, scope: Array = []) -> Array:
	if Lexeme.language(definition) != Lexeme.language(source):
		return []
	if str(definition.get("task_type", "")) in source.get("excluded_task_types", []):
		return []
	if not _type_allowed(source, definition.get("allowed_types", ["*"])):
		return []
	var source_id := str(source.get("id", ""))
	var relation_req := str(definition.get("requires_relation", ""))
	if relation_req != "":
		var out: Array = []
		for rel in ContentRegistry.relations_of(source_id, relation_req):
			var target_id := str(rel.get("to_lexeme_id", ""))
			if target_id != "":
				out.append({"target_lexeme_id": target_id})
		return out
	var form_req := str(definition.get("requires_form", ""))
	if form_req != "":
		var forms := ContentRegistry.forms_for(source_id, form_req, scope)
		return [{"form_type": form_req}] if forms.any(func(f):
				return ContentRegistry.form_task_in_scope(f, scope)) else []
	# Buchsätze nur im gewählten Bonus (ADR 0026), nie im leeren Scope.
	if bool(definition.get("requires_example", false)):
		if not ContentRegistry.examples_in_scope(source, scope):
			return []
		return Lexeme.examples(source).map(func(e): return {"example_key": str(e["key"])})
	return [{}]


## Alle learnable_ids eines Lexems, aus dem Katalog gerechnet.
func learnables_of(lexeme: Dictionary) -> Array:
	var ids: Array = []
	for definition in ContentRegistry.task_definitions.values():
		for extra in _instances(definition, lexeme):
			ids.append(_resolver.learnable_id(
					str(definition.get("task_type", "")),
					str(definition.get("direction", "")),
					str(lexeme.get("id", "")), extra))
	return ids


## task_definition.difficulty (1..DIFFICULTY_MAX) auf 0..1, wie die Confidence.
func _difficulty_norm(difficulty: int) -> float:
	return clampf(float(difficulty - 1) / float(DIFFICULTY_MAX - 1), 0.0, 1.0)


## True, wenn der Lexem-Typ zur Definition passt (["*"] oder leer = alle Typen).
func _type_allowed(source: Dictionary, allowed: Array) -> bool:
	if allowed.is_empty() or "*" in allowed:
		return true
	return str(source.get("type", "")) in allowed


func _candidate(definition: Dictionary, source: Dictionary, extra: Dictionary) -> Dictionary:
	var lid := _resolver.learnable_id(
		str(definition.get("task_type", "")),
		str(definition.get("direction", "")),
		str(source.get("id", "")),
		extra)
	return {"definition": definition, "source": source, "extra": extra, "learnable_id": lid}


func _build_plan(candidate: Dictionary) -> Dictionary:
	var task := _resolver.resolve(candidate["definition"], candidate["source"], candidate["extra"])
	if task.is_empty():
		return {}
	var rule := ContentRegistry.monster_rule_for(task["task_type"], task["direction"])
	if rule.is_empty():
		push_warning("WaveGenerator: keine monster_task_rule für (%s, %s)" % [task["task_type"], task["direction"]])
		return {}
	var monster_def := ContentRegistry.get_entry("monsters", str(rule.get("monster_type", "")))
	if monster_def.is_empty():
		push_warning("WaveGenerator: unbekannter monster_type '%s'" % rule.get("monster_type", ""))
		return {}

	# t = Grundschwierigkeit der Aufgaben-Art (0..1), c = Confidence für diese Aufgabe (0..1).
	var t := _difficulty_norm(int(task.get("difficulty", 1)))
	# Ungesehen gilt der Prior.
	var prior := _rule_form_prior(candidate["definition"], candidate["source"])
	if prior < 0.0:
		prior = _confidence_prior(candidate["source"])
	task["initial_confidence"] = prior
	var c := PlayerProgress.confidence(task["learnable_id"], prior)

	# Netto-Schwierigkeit, -1 (sicher beherrscht) bis +1 (hart und unsicher): das einzige Maß
	# für Tempo, Punkte und Erfahrung.
	var net := t - c

	# Schwer heißt langsamer (Zeit zum Abrufen), Tempo höchstens ±30 %; lange Antworten
	# zusätzlich nach ihrer Tippzeit.
	var chars := answer_chars(task.get("accepted_answers", []))
	var speed := REFERENCE_SPEED * clampf(1.0 - SPEED_SENSITIVITY * net, 0.7, 1.3) * speed_scale \
			* typing_pace(chars)

	# Punkte invers zum Tempo: schwer heißt mehr Punkte (0,4- bis 1,6-fach).
	var mastered := c >= PlayerProgress.MASTERY_CONFIDENCE
	var reward_scale := clampf(1.0 + REWARD_SENSITIVITY * net, 0.4, 1.6) * speed_scale
	if mastered:
		reward_scale *= MASTERED_REWARD_FACTOR

	# Mit der Lösung auf dem Schild (ADR 0027) ist Abtippen kein Abruf: Punkte und Erfahrung
	# wie gemeistert, das Tempo bleibt das einer neuen Aufgabe, zum Lesen.
	var help := bool(candidate.get("help", false))
	task["help_key"] = help_key(candidate)
	if help:
		task["help"] = true
		reward_scale *= MASTERED_REWARD_FACTOR
	var reward := maxi(1, int(round(REFERENCE_REWARD * reward_scale)))

	# Erfahrung ohne `speed_scale`; `net` auf 0..1 abgebildet. Gemeistert beim Spawn geprüft,
	# damit das Monster, das die Meisterung bringt, noch voll zählt.
	var xp := Experience.for_monster(0.5 + 0.5 * net, mastered or help)
	return {
		"task": task,
		"monster_def": monster_def,
		"speed": speed,
		"gap": typing_gap(chars),
		"damage": maxi(1, roundi(int(rule.get("base_damage", 10)) * damage_scale)),
		"reward": reward,
		"xp": xp,
		"net": net,
		# Dasselbe Urteil wie bei Punkten und Erfahrung (Monster.mastered).
		"mastered": mastered,
	}
