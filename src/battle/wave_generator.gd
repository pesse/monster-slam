class_name WaveGenerator
extends RefCounted
## Wählt für einen Spawn eine konkrete Aufgabe und deren Darstellung.
##
## Ablauf (siehe docs/ARCHITECTURE.md, "Nutzung im Spiel"):
##   1. Kandidaten aus dem Wave-Pool erzeugen: task_definitions × passende Lexeme
##      (allowed_types / requires_relation / requires_form), gefiltert nach
##      task_types/direction und den Lexem-tags.
##   2. Gewichtet ziehen: Fälliges, Unsicheres und Neues oft, Gemeistertes selten (ordered()).
##   3. Aufgabe über TaskResolver auflösen (prompt + accepted_answers).
##   4. monster_task_rules mappt (task_type, direction) -> monster_type + Basiswerte.
##   5. Tempo, Punkte und Erfahrung = Schwierigkeit: aus Aufgaben-Grundschwierigkeit +
##      Confidence (+ Wellenfaktor, der die Erfahrung bewusst NICHT anhebt).
##   6. Schaden = base_damage der Regel × Wellennummer-Faktor (wave_damage_scale).
##
## pick(pool) -> {
##   "task": Dictionary,          # aufgelöste Laufzeit-Aufgabe
##   "monster_def": Dictionary,   # reine Darstellung (monsters-Eintrag)
##   "speed": float, "damage": int, "reward": int, "xp": int,
## }  oder {} wenn nichts Spielbares gefunden wurde.

var _resolver := TaskResolver.new()

## Referenztempo = Nullpunkt der Schwierigkeitsskala (Netto-Können e = 0): die Confidence
## deckt die Grundschwierigkeit der Aufgabe genau. KEIN kosmetisches Attribut — Geschwindigkeit
## IST Schwierigkeit und entsteht ausschließlich hieraus. REFERENCE_SPEED zu ändern verschiebt
## die gesamte Skala für alle Aufgaben gleichzeitig; mit Vorsicht behandeln.
const REFERENCE_SPEED := 35.0
## Empfindlichkeit: wie stark das Netto-Können (c - t) das Tempo auslenkt. Klein halten,
## da jede Tempo-Änderung eine Schwierigkeits-Änderung ist.
const SPEED_SENSITIVITY := 0.3
## Obergrenze der difficulty-Skala für die Normalisierung auf 0..1.
const DIFFICULTY_MAX := 5

## Referenz-Punktzahl bei neutraler Schwierigkeit (Netto-Können e = 0). Wie beim Tempo
## ist die Schwierigkeit die einzige Quelle — es gibt keine per-Regel-Punkte mehr.
const REFERENCE_REWARD := 12
## Empfindlichkeit: wie stark die Schwierigkeit (t - c) die Punkte auslenkt.
const REWARD_SENSITIVITY := 0.6
## Anteil der Punkte, den ein Monster mit schon gemeisterter Aufgabe bringt — und damit
## auch des Golds, das aus den Punkten kommt (ChestReward). Dieselbe Absicht wie
## Experience.MASTERED_XP: Beute kommt aus dem Lernen, nicht aus dem Wiederholen. Nicht 0,
## denn die Wiederholungen wählt der Scheduler, nicht der Spieler.
const MASTERED_REWARD_FACTOR := 0.1

## Schadensfaktor der ersten Wellen (Welle 1, 2): zum Hineinfinden weniger als
## `base_damage`, das genau in Welle 3 gilt. Danach wächst er je Welle um
## DAMAGE_GROWTH_PER_WAVE, ohne Deckel (Issue #51).
const EARLY_WAVE_DAMAGE: Array[float] = [0.6, 0.8]
const DAMAGE_GROWTH_PER_WAVE := 0.15

## Die Gruppen der Auswahl (siehe ordered()), so auch in der Spur. Sie benennen nur, woher
## ein Kandidat kommt; gewählt wird nach seinem Gewicht (selection_weight()).
const GROUP_DUE := "due"
const GROUP_NEW := "new"
const GROUP_REST := "rest"

## Gewicht eines neuen Worts. Ein unsicheres, fälliges Wort (c 0.5) liegt bei 0.5–1, ein
## gemeistertes bei 0.05–0.3 (selection_weight()).
const NEW_WEIGHT := 1.0
## So viel des Gesamtgewichts haben die neuen Wörter mindestens, solange es welche gibt —
## sonst verdrängen viele fällige Wiederholungen eine frische Lektion (Issue #18).
const NEW_SHARE := 0.3
## Bedarf (1 − c) einer gemeisterten Aufgabe sinkt nicht unter diesen Wert: sie kommt
## seltener, aber nicht nie.
const NEED_FLOOR := 0.05
## Dringlichkeit ist der Anteil des Intervalls, der verstrichen ist — gedeckelt, damit ein
## lange liegengebliebenes Wort nicht alles andere verdrängt.
const URGENCY_CAP := 2.0

## Globaler Tempo-Multiplikator, vom WaveRunner aus der gewählten Wellen-Schwierigkeit gesetzt
## (1.0 = neutral, >1 schneller/schwerer, <1 langsamer/leichter). Ist selbst eine
## Schwierigkeits-Quelle und wirkt daher multiplikativ auf das Referenztempo.
var speed_scale: float = 1.0
## Schadens-Multiplikator, vom WaveRunner je Welle aus wave_damage_scale() gesetzt. Trifft
## nur den Schaden — Tempo, Punkte und Erfahrung bleiben bei `t - c`.
var damage_scale: float = 1.0


## Schadensfaktor einer Welle: 0,6 · 0,8 · 1,0 · 1,15 · 1,3 · … Welle ≤ 0 zählt als Welle 1.
static func wave_damage_scale(wave_number: int) -> float:
	var n := maxi(1, wave_number)
	if n <= EARLY_WAVE_DAMAGE.size():
		return EARLY_WAVE_DAMAGE[n - 1]
	return 1.0 + DAMAGE_GROWTH_PER_WAVE * (n - EARLY_WAVE_DAMAGE.size() - 1)

## Start-Confidence (Prior) für eine noch ungesehene Aufgabe, abgeleitet aus den
## deskriptiven Lexem-Metadaten `cefr` / `frequency_band`. Das bricht NICHT das Prinzip
## „Schwierigkeit = Projektion der Confidence": difficulty bleibt an der task_definition,
## der Prior ist nur eine bessere Anfangsschätzung des Lernstands als der Pauschal-Default.
## Schwerere/seltenere Wörter starten unsicherer -> langsameres Monster, mehr Punkte.
## Fehlen beide Felder, bleibt es beim neutralen PlayerProgress.DEFAULT_CONFIDENCE.
const CEFR_PRIOR := {
	"A1": 0.50, "A2": 0.40, "B1": 0.30, "B2": 0.20, "C1": 0.12, "C2": 0.08,
}
const FREQUENCY_PRIOR := {
	"core": 0.45, "high": 0.42, "common": 0.35, "mid": 0.30, "low": 0.20, "rare": 0.12,
}


## Mittelt die vorhandenen Prior-Signale (CEFR, Frequenzband) eines Lexems; ohne
## Signal -> neutraler Default. Ergebnis in 0..1.
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


## Start-Confidence einer Formaufgabe, deren Form aus der Regel folgt — ein Verb ohne
## `irregular`, dessen Vergangenheit auf *-ed* gebildet ist (ADR 0009, Nachtrag). Wer die
## Regel kann, kann jedes solche Verb; die Aufgabe soll ein-, zweimal kommen und dann als
## gemeistert hinten stehen, statt die unregelmäßigen zu verdrängen. Gemessen an der
## Fortschreibung in PlayerProgress.record (10–40 % des Abstands zu 1 je Treffer, nach
## Abstand; Meisterung ab 0.8): 0.65 ist nach zwei Treffern gemeistert, 0.6 nach drei in
## einer Sitzung oder zwei an zwei Tagen. Ein Fehler halbiert die Confidence wie bei jeder
## Aufgabe.
const RULE_FORM_PRIOR := 0.65
## Regel mit Schreibfalle: verdoppelter Konsonant (preferred, snorkelled) oder y → ied
## (bullied). Regelmäßig, aber nicht geschenkt.
const SPELLING_FORM_PRIOR := 0.6
## Formen, bei denen eine Sprache „regelmäßig" kennt (ADR 0009, Punkt 2). Latein und
## Französisch fehlen: dort gibt es die Formaufgaben nur bei unregelmäßigen Verben, oder
## die Regel hängt an der Konjugation, die das Lexem nicht trägt.
const RULE_FORMS := {"en": ["past_simple", "past_participle"]}


## Wie eine englische Vergangenheitsform zu ihrer Grundform steht: "plain" (settled,
## discussed), "spelling" (preferred, bullied) oder "" (nicht nach der Regel — took, oder
## Daten, die nicht passen). Bei mehreren Wörtern („bump into") zählt das erste, der Rest
## muss gleich bleiben.
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


## Prior einer Formaufgabe nach der Regel (siehe RULE_FORM_PRIOR), oder -1, wenn die
## Aufgabe keine solche ist — dann gilt der Prior des Lexems.
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


## Aufgaben-Pool aus der Auswahl des aktiven Profils (Session-Setup). EINE Quelle für
## beide Fragen: welche Aufgaben der Kampf spawnt (WaveRunner._generate_wave) und ob
## überhaupt etwas spielbar ist (has_playable, Menü-Knöpfe). Getrennte Pools hier hießen:
## der Knopf gibt frei, wo die Welle nichts findet — oder umgekehrt.
## Semantik der LEEREN Auswahl: keine Einschränkung (siehe _candidates()).
static func pool_from_settings() -> Dictionary:
	return {
		"task_types": Array(UserSettings.selected_task_types()),
		"lexeme_types": Array(UserSettings.selected_lexeme_types()),
		"scope": Array(UserSettings.selected_scope()),
		"tags": Array(UserSettings.selected_tags()),
	}


## Wie viele Kandidaten die Stichprobe in has_playable() höchstens erzeugt, bevor sie
## den ganzen Pool durchsieht. Der volle Kandidatensatz kostet bei ~2000 Lexemen rund
## 300 ms — zu viel für einen Screen, der nach jeder Filteränderung neu fragt.
const PROBE_CANDIDATES := 64


## Gibt der Pool überhaupt eine auflösbare Aufgabe her? Hält beim ersten Treffer an.
##
## Ohne das hängt der Kampf: ein Spawn ohne Plan zählt nicht mit (_spawned), das
## Wellenende tritt nie ein und aus dem leeren Schlachtfeld führt kein Weg zurück.
## Deshalb fragen die Menüs VOR dem Kampf und der WaveRunner vor dem Wellenstart.
##
## Zwei Durchläufe: eine Stichprobe genügt praktisch immer und ist in Millisekunden
## fertig; erst wenn davon KEIN Kandidat auflösbar ist, wird der ganze Pool durchgesehen.
## Ein „nein" bleibt damit ein belastbares „nichts Spielbares", kein Stichprobenglück.
func has_playable(pool: Dictionary) -> bool:
	for limit in [PROBE_CANDIDATES, 0]:
		for candidate in _candidates(pool, limit):
			if not _build_plan(candidate).is_empty():
				return true
	return false


## `exclude_sources` (als Set: Lexem-id -> true) verhindert, dass ein Grundwort
## gewählt wird, das bereits als Monster auf dem Feld steht (Aufrufer: WaveRunner).
## `shown_sources` (Lexem-id -> laufende Spawn-Nummer der letzten Zeigung) sind die in
## dieser Welle schon gezeigten Grundwörter; sie kommen erst dran, wenn der Rest des
## Pools erschöpft ist (siehe ordered()).
##
## Der Plan trägt in `task["pick"]` den Grund der Wahl (siehe pick_reason()); die Spur
## schreibt ihn in jede spawn-Zeile.
##
## `order` (Grundwort-Ids) ist die Playlist einer Testliste (TestPlaylist.wave_order): dann
## kommt das Wort nach seinem Platz darin, nicht nach Fälligkeit.
func pick(pool: Dictionary, exclude_sources: Dictionary = {}, shown_sources: Dictionary = {},
		order: Array = []) -> Dictionary:
	var candidates := listing(pool, shown_sources)
	if not order.is_empty():
		candidates = TestPlaylist.arrange(candidates, order)
	var plan := pick_with(candidates, exclude_sources)
	if not order.is_empty() and not plan.is_empty():
		plan["task"]["pick"]["playlist"] = true
	return plan


## Alle Kandidaten des Pools, ungeordnet — für die Playlist einer Testliste, die daraus
## die Grundwörter und ihre Aufgaben nimmt.
func candidates(pool: Dictionary) -> Array:
	return _candidates(pool)


## Die Kandidaten des Pools in der Reihenfolge, in der pick() sie probiert, jeder mit
## `group`, `repeat` und `weight` (siehe ordered()). `now`: Bezugszeit (unix, -1 = jetzt) —
## die Werkbank fragt mit verstellter Uhr.
func listing(pool: Dictionary, shown_sources: Dictionary, now := -1) -> Array:
	if now < 0:
		now = int(Time.get_unix_time_from_system())
	return ordered(_candidates(pool), PlayerProgress.state_of, shown_sources, now)


## Wählt aus einer listing() den ersten spielbaren Kandidaten.
##
## Der Reihe nach durchprobieren, bis eine Aufgabe auflösbar ist. Erster Durchlauf meidet
## bereits sichtbare Grundwörter; findet sich damit nichts Spielbares, lässt der zweite
## Durchlauf die Sperre fallen (lieber ein Duplikat als eine hängende Welle).
func pick_with(ordered_candidates: Array, exclude_sources: Dictionary = {}) -> Dictionary:
	for respect_exclude in [true, false]:
		for i in ordered_candidates.size():
			var candidate: Dictionary = ordered_candidates[i]
			if respect_exclude and exclude_sources.has(str(candidate["source"].get("id", ""))):
				continue
			var plan := _build_plan(candidate)
			if not plan.is_empty():
				plan["task"]["pick"] = pick_reason(ordered_candidates, i, not respect_exclude,
						float(plan["net"]), int(candidate.get("due_at", 0)))
				return plan
	return {}


## Warum der Kandidat an Stelle `index` gewählt wurde — für die Spur, das Debug-Panel und
## die Werkbank. Nur Ids und Zahlen, keine Wörter: die stehen schon in der spawn-Zeile.
##   group:    "due" | "new" | "rest" (siehe ordered())
##   repeat:   das Wort war in dieser Welle schon dran (alle anderen sind verbraucht)
##   pos:      Stelle in der Reihenfolge (0 = vorn); davor lagen Wörter auf dem Feld
##             oder Unauflösbares
##   pool:     Zahl der Kandidaten
##   counts:   je Gruppe, wie viele noch nicht gezeigte es gab, dazu `repeat`
##   fallback: die Sperre gegen Wörter auf dem Feld musste fallen
##   net:      t - c des Monsters
##   due_at:   Fälligkeit (unix), 0 = nie beantwortet
##   last_seen: zuletzt beantwortet, über alle Aufgaben des Grundworts (unix), 0 = nie
##   weight:   Gewicht in der Auswahl (selection_weight())
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
	}


const GROUP_LABELS := {"due": "fällig", "new": "neu", "rest": "Rest"}


## Der Grund als eine Zeile, z. B. „fällig (seit 2 T) · Platz 1 von 34 · fällig 3 / neu 12
## / Rest 19 / gezeigt 0 · t−c +0.25". `now`: Bezugszeit für die Fälligkeit (unix).
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


## Die Auswahlreihenfolge von pick(), statisch und ohne Autoload prüfbar (ADR 0018).
##
## Oberste Stufe ist „in dieser Welle schon gezeigt" (Issue #24): erst alle Kandidaten,
## deren Grundwort noch nicht dran war, danach die Wiederholungen, geordnet nach Grundwort —
## das am längsten nicht gezeigte (kleinste Nummer in `shown`) zuerst. Die Sperre greift am
## Grundwort, nicht am learnable_id — sonst käme dasselbe Wort über eine andere Richtung
## oder Aufgabenart sofort wieder.
##
## Innerhalb einer Stufe wird gewichtet gezogen, ohne Zurücklegen (selection_weight()): ein
## Kandidat mit doppeltem Gewicht steht doppelt so oft vor dem anderen. Bis 0.26 galt hart
## fällig → neu → Rest; damit stand ein frisch gemeistertes, morgen fälliges Wort vor jedem
## neuen, und ein gemeistertes, nicht fälliges kam praktisch nie (Issue #18).
##
## `state`: learnable_id -> {} (nie beantwortet) oder { confidence, last_seen, due_at }
## (PlayerProgress.state_of). `now`: Bezugszeit (unix).
##
## Jeder Kandidat bekommt dabei `group` ("due" | "new" | "rest"), `repeat` (Wort in dieser
## Welle schon gezeigt), `last_seen` (Grundwort zuletzt beantwortet), `due_at` und `weight` —
## der Grund der Wahl kommt so aus derselben Rechnung und nicht aus einer zweiten Regel
## daneben.
static func ordered(candidates: Array, state: Callable, shown: Dictionary, now: int) -> Array:
	# Am Grundwort, wie die Sperre: „convict" kam eben in der einen Richtung, also auch
	# in der anderen nicht gleich wieder.
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
		c["repeat"] = shown.has(source_id)
		if shown.has(source_id):
			var key := int(shown[source_id])
			if not repeats.has(key):
				repeats[key] = []
			repeats[key].append(c)
		else:
			fresh.append(c)
	var out := weighted_order(_with_new_share(fresh))
	var keys := repeats.keys()
	keys.sort()
	for key in keys:
		out.append_array(weighted_order(repeats[key]))
	return out


## Gewicht eines Kandidaten: Bedarf × Dringlichkeit, ein neues Wort NEW_WEIGHT.
##
##   Bedarf        1 − c, mindestens NEED_FLOOR — gemeistert heißt selten, nicht nie.
##   Dringlichkeit verstrichener Anteil des Intervalls (1 = gerade fällig), bis URGENCY_CAP.
##                 Gemessen ab der letzten Antwort auf das GRUNDWORT (`word_seen`): die andere
##                 Richtung eines eben gezeigten Worts wartet, auch wenn sie fällig ist.
##
## Ein Fehler hebt beides: die Confidence halbiert sich, und die Aufgabe ist nach zehn Minuten
## wieder fällig (SpacedRepetition.RELEARN_SECONDS) — zwanzig Minuten später wiegt sie mehr
## als ein neues Wort.
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
## ln(u) / w, der größte zuerst. Ein Gewicht 0 steht hinten, fällt aber nicht weg — die
## Rückfallebene in pick() braucht jeden Kandidaten.
static func weighted_order(candidates: Array) -> Array:
	var keyed: Array = []
	for c in candidates:
		var w := maxf(float(c.get("weight", 0.0)), 1e-9)
		keyed.append([log(maxf(randf(), 1e-12)) / w, c])
	keyed.sort_custom(func(a, b): return float(a[0]) > float(b[0]))
	return keyed.map(func(k): return k[1])


## Erzeugt alle spielbaren Kandidaten (Definition × Lexeme [× Form/Relation]) für den
## Wave-Pool. Jeder Kandidat kennt bereits seinen learnable_id für die Bucket-Zuordnung.
##
## `limit` > 0 bricht ab, sobald so viele Kandidaten zusammen sind — nur für die
## Stichprobe in has_playable(). pick() braucht ALLE: die Auswahl fällt über die
## Fälligkeits-Buckets, und eine abgeschnittene Menge verzerrte sie.
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
	# Ein Wort, das nur über einen Bonus dabei ist, bringt nur seine Bonus-Formen mit — keine
	# Übersetzung, keine andere Form (ADR 0012): der Bonus übt das Perfekt, nicht Lektion 1.
	# Ein Wort aus einem Wort-Bonus (ADR 0013) ist dagegen selbst der Stoff des Bonus.
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


## Passt eine task_definition zu den Filtern des Pools? Statisch und ohne Autoload, damit
## die Regel für sich prüfbar bleibt — dieselbe Begründung wie bei
## PlayerProgress.mastered_lexemes_in und StatsScreen.unit_rows.
##
## Leere `task_types` und leere `direction` heißen „keine Einschränkung".
##
## Die Wellen-Schwierigkeit filtert hier bewusst NICHT: ein Riegel über die `difficulty`
## der Definition nahm auf niedrigen Stufen ganze Aufgabenarten (Formen, Relationen) aus
## dem Pool, ohne dass der Spieler es sehen konnte. Die `difficulty` bleibt das `t` in
## `t - c` und wirkt nur über Tempo, Punkte und Erfahrung.
static func definition_allowed(definition: Dictionary, task_types: Array,
		direction: String) -> bool:
	var task_type := str(definition.get("task_type", ""))
	if not task_types.is_empty() and not (task_type in task_types):
		return false
	if direction != "" and str(definition.get("direction", "")) != direction:
		return false
	return true


## Verbindet eine Definition mit allen kompatiblen Lexemen und hängt die Kandidaten an.
## Relations-/Formaufgaben expandieren über die tatsächlich vorhandenen Relationen/Formen,
## sodass nie eine unauflösbare Instanz entsteht.
## `bonus_only` (Lexem-Id -> true) nennt die Wörter, die nur über einen Bonus dabei sind:
## von ihnen kommen nur die Formaufgaben, deren Form in einem Bonus steht.
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
## `scope` als Bonus mitspielt?
func _bonus_task(definition: Dictionary, source: Dictionary, scope: Array) -> bool:
	var form_type := str(definition.get("requires_form", ""))
	if form_type.is_empty():
		return false
	for form in ContentRegistry.forms_for(str(source.get("id", "")), form_type, scope):
		if not ContentRegistry.bonus_of_form(form).is_empty() \
				and ContentRegistry.form_task_in_scope(form, scope):
			return true
	return false


## Die `extra`-Bausteine, mit denen eine Definition auf EIN Lexem passt — eine leere
## Liste, wenn sie gar nicht passt. Relations-/Formaufgaben fächern über die tatsächlich
## vorhandenen Relationen/Formen auf, sodass nie eine unauflösbare Instanz entsteht.
##
## Die eine Stelle, die sagt, welche Aufgaben es zu einem Wort gibt: der Wave-Pool
## (_expand) und die Statistik (learnables_of) fragen dieselbe.
##
## `excluded_task_types` am Lexem nimmt einzelne Aufgabenarten heraus — für ein Wort, das
## im Buch keinen eigenen Eintrag hat und dessen deutschen Prompt sich ein Nachbar teilt,
## ohne dass das Buch eine Unterscheidung anbietet. Es bleibt im Bestand (en→de-Lesen,
## Relationen), stellt aber keine Ratefrage. Weil beide Seiten durch dieses Nadelöhr gehen,
## verschwindet es damit auch aus der Aufgabenzahl der Statistik — und
## `PlayerProgress.masterable()` nimmt es aus dem NENNER des Fortschrittsbalkens, sonst
## stünde die Unit dauerhaft bei „N-1 von N".
##
## Eine Definition gilt nur für Lexeme ihrer Sprache (`language`, ohne Feld englisch):
## sonst stellte die englische Übersetzung ein lateinisches Wort und umgekehrt.
##
## `scope` lässt nur Formen zu, die dort schon gelehrt sind und deren Bonus, wenn sie in
## einem stehen, dort mitspielt (ContentRegistry.form_task_in_scope); leer, wie für die
## Statistik, zählt jede Form.
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
	return [{}]


## Alle learnable_ids, die es zu einem Lexem überhaupt gibt — Definitionen × vorhandene
## Formen/Relationen, also das, was der Wave-Pool daraus auch spawnen würde.
##
## Für die Statistik: dort steht neben einem Wort, wie viele Aufgaben es dazu gibt und
## wie viele davon sitzen. Aus dem Katalog gerechnet und nicht aus dem Lernstand, sonst
## wäre eine noch nie gespawnte Aufgabe für die Anzeige nicht vorhanden.
func learnables_of(lexeme: Dictionary) -> Array:
	var ids: Array = []
	for definition in ContentRegistry.task_definitions.values():
		for extra in _instances(definition, lexeme):
			ids.append(_resolver.learnable_id(
					str(definition.get("task_type", "")),
					str(definition.get("direction", "")),
					str(lexeme.get("id", "")), extra))
	return ids


## Normalisiert die Aufgaben-Grundschwierigkeit (task_definition.difficulty,
## 1..DIFFICULTY_MAX) auf 0..1 — damit sie mit der Confidence vergleichbar ist.
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

	# Schwierigkeit dieses konkreten Monsters, aus zwei Quellen (+ Wellenfaktor):
	#   t = Grundschwierigkeit der Aufgaben-Art (task_definition.difficulty, 0..1)
	#   c = Confidence des Spielers für diese konkrete Aufgabe (0..1)
	#   e = c - t   (Netto-Können; e<0 = für den Spieler schwer, e>0 = sicher beherrscht)
	var t := _difficulty_norm(int(task.get("difficulty", 1)))
	# Prior aus den Lexem-Metadaten: gilt als Confidence, solange die Aufgabe ungesehen ist,
	# und als Start-Confidence des Records beim ersten echten Kontakt (siehe WaveRunner).
	# Eine Form nach der Regel hat ihren eigenen, höheren Prior (siehe RULE_FORM_PRIOR).
	var prior := _rule_form_prior(candidate["definition"], candidate["source"])
	if prior < 0.0:
		prior = _confidence_prior(candidate["source"])
	task["initial_confidence"] = prior
	var c := PlayerProgress.confidence(task["learnable_id"], prior)

	# Netto-Schwierigkeit dieses Monsters: t - c, also -1 (sicher beherrscht) bis +1
	# (harte Aufgabe, unsicherer Spieler). Sie ist die EINE Größe, aus der Tempo, Punkte
	# und Erfahrung entstehen — jedes weitere Schwierigkeitsmaß daneben liefe auseinander,
	# sobald eines von beiden justiert wird.
	var net := t - c

	# Tempo = sichtbare Projektion der Schwierigkeit: schwer -> langsamer (Zeit zum
	# Abrufen), nur wenn die Confidence die Grundschwierigkeit übersteigt -> schneller.
	var speed := REFERENCE_SPEED * clampf(1.0 - SPEED_SENSITIVITY * net, 0.7, 1.3) * speed_scale

	# Punkte skalieren mit derselben Schwierigkeit, aber invers zum Tempo: je schwerer
	# das Monster (hohe Grundschwierigkeit, niedrige Confidence, härtere Welle), desto
	# mehr Punkte. So lohnt sich das Abrufen unsicherer/harter Aufgaben.
	# Eine schon gemeisterte Aufgabe bringt nur einen Bruchteil (MASTERED_REWARD_FACTOR),
	# geprüft beim Spawn wie die Erfahrung unten.
	var mastered := c >= PlayerProgress.MASTERY_CONFIDENCE
	var reward_scale := clampf(1.0 + REWARD_SENSITIVITY * net, 0.4, 1.6) * speed_scale
	if mastered:
		reward_scale *= MASTERED_REWARD_FACTOR
	var reward := maxi(1, int(round(REFERENCE_REWARD * reward_scale)))

	# Erfahrung aus derselben Schwierigkeit, aber OHNE `speed_scale`: XP ist
	# Lernfortschritt und keine Beute — eine härtere Welle macht das einzelne Wort nicht
	# schwerer, sie bringt nur mehr Monster und mehr Punkte. Eine schon gemeisterte
	# Aufgabe bringt fast nichts (siehe Experience.MASTERED_XP); geprüft wird das HIER,
	# beim Spawn, denn nach dem Treffer hat PlayerProgress die Confidence bereits
	# angehoben — das Monster, das die Meisterung bringt, zählt noch voll.
	var xp := Experience.for_monster(0.5 + 0.5 * net, mastered)
	return {
		"task": task,
		"monster_def": monster_def,
		"speed": speed,
		"damage": maxi(1, roundi(int(rule.get("base_damage", 10)) * damage_scale)),
		"reward": reward,
		"xp": xp,
		"net": net,
	}
