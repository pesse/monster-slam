class_name WaveGenerator
extends RefCounted
## Wählt für einen Spawn eine konkrete Aufgabe und deren Darstellung.
##
## Ablauf (siehe docs/ARCHITECTURE.md, "Nutzung im Spiel"):
##   1. Kandidaten aus dem Wave-Pool erzeugen: task_definitions × passende Lexeme
##      (allowed_types / requires_relation / requires_form), gefiltert nach
##      task_types/direction/difficulty_max und den Lexem-tags.
##   2. Fällige (SpacedRepetition) bevorzugen, dann neue, dann beliebige.
##   3. Aufgabe über TaskResolver auflösen (prompt + accepted_answers).
##   4. monster_task_rules mappt (task_type, direction) -> monster_type + Basiswerte.
##   5. Tempo, Punkte und Erfahrung = Schwierigkeit: aus Aufgaben-Grundschwierigkeit +
##      Confidence (+ Wellenfaktor, der die Erfahrung bewusst NICHT anhebt).
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

## Aufgabenarten, die der Schwierigkeitsriegel (`difficulty_max`) NIE aus dem Pool nimmt.
## Die Übersetzung ist das Fundament des Lernstands — ein WORT gilt erst als gemeistert,
## wenn beide Richtungen sitzen (PlayerProgress.LEXEME_MASTERY_DIRECTIONS). Auf Stufe 1
## fiel `def.translate.en_de` (difficulty 2) heraus; damit war kein Wort je zu meistern,
## jeder Fortschrittsbalken stand dauerhaft auf „0 von N" und jedes Wort auf „0 %",
## während „Gemeisterte Aufgaben" im Überblick weiterstieg — ein Widerspruch, der wie ein
## Rechenfehler der Statistik aussieht und keiner war. Der Riegel staffelt die
## ZUSATZaufgaben (Formen, Relationen), nicht die Lernrichtung.
const CORE_TASK_TYPES := ["translate"]

## Referenz-Punktzahl bei neutraler Schwierigkeit (Netto-Können e = 0). Wie beim Tempo
## ist die Schwierigkeit die einzige Quelle — es gibt keine per-Regel-Punkte mehr.
const REFERENCE_REWARD := 12
## Empfindlichkeit: wie stark die Schwierigkeit (t - c) die Punkte auslenkt.
const REWARD_SENSITIVITY := 0.6

## Globaler Tempo-Multiplikator, vom WaveRunner aus der gewählten Wellen-Schwierigkeit gesetzt
## (1.0 = neutral, >1 schneller/schwerer, <1 langsamer/leichter). Ist selbst eine
## Schwierigkeits-Quelle und wirkt daher multiplikativ auf das Referenztempo.
var speed_scale: float = 1.0

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


## Aufgaben-Pool aus der Auswahl des aktiven Profils (Session-Setup). EINE Quelle für
## beide Fragen: welche Aufgaben der Kampf spawnt (WaveRunner._generate_wave) und ob
## überhaupt etwas spielbar ist (has_playable, Menü-Knöpfe). Getrennte Pools hier hießen:
## der Knopf gibt frei, wo die Welle nichts findet — oder umgekehrt.
## Semantik der LEEREN Auswahl: keine Einschränkung (siehe _candidates()).
static func pool_from_settings(difficulty: int) -> Dictionary:
	return {
		"task_types": Array(UserSettings.selected_task_types()),
		"lexeme_types": Array(UserSettings.selected_lexeme_types()),
		"scope": Array(UserSettings.selected_scope()),
		"tags": Array(UserSettings.selected_tags()),
		"difficulty_max": clampi(difficulty, 1, 5),
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
func pick(pool: Dictionary, exclude_sources: Dictionary = {}) -> Dictionary:
	var candidates := _candidates(pool)
	if candidates.is_empty():
		return {}
	# Reihenfolge: fällige zuerst, dann neue, dann der Rest — innerhalb gemischt.
	var due := PlayerProgress.due_task_ids()
	var buckets := {"due": [], "new": [], "rest": []}
	for c in candidates:
		var id: String = c["learnable_id"]
		if id in due:
			buckets["due"].append(c)
		elif not PlayerProgress.has_seen(id):
			buckets["new"].append(c)
		else:
			buckets["rest"].append(c)

	# Erste nicht-leere Priorität durchprobieren, bis eine Aufgabe auflösbar ist.
	# Erster Durchlauf meidet bereits sichtbare Grundwörter; findet sich damit nichts
	# Spielbares, lässt der zweite Durchlauf die Sperre fallen (lieber ein Duplikat
	# als eine hängende Welle).
	for respect_exclude in [true, false]:
		for key in ["due", "new", "rest"]:
			var pool_list: Array = buckets[key]
			pool_list.shuffle()
			for candidate in pool_list:
				if respect_exclude and exclude_sources.has(str(candidate["source"].get("id", ""))):
					continue
				var plan := _build_plan(candidate)
				if not plan.is_empty():
					return plan
	return {}


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
	var difficulty_max: int = int(pool.get("difficulty_max", 0)) # 0 = kein Limit
	var lexemes := ContentRegistry.lexemes_scoped(scope, tags) # leerer scope/tags -> alle Lexeme
	if not lexeme_types.is_empty():
		lexemes = lexemes.filter(func(lx): return str(lx.get("type", "")) in lexeme_types)
	var result: Array = []
	for definition in ContentRegistry.task_definitions.values():
		if not definition_allowed(definition, task_types, direction, difficulty_max):
			continue
		_expand(definition, lexemes, result, limit)
		if limit > 0 and result.size() >= limit:
			break
	return result


## Passt eine task_definition zu den Filtern des Pools? Statisch und ohne Autoload, damit
## die Regel für sich prüfbar bleibt — dieselbe Begründung wie bei
## PlayerProgress.mastered_lexemes_in und StatsScreen.unit_rows.
##
## Leere `task_types` und leere `direction` heißen „keine Einschränkung", `difficulty_max`
## 0 heißt „kein Limit". Der Schwierigkeitsriegel lässt CORE_TASK_TYPES unberührt.
static func definition_allowed(definition: Dictionary, task_types: Array,
		direction: String, difficulty_max: int) -> bool:
	var task_type := str(definition.get("task_type", ""))
	if not task_types.is_empty() and not (task_type in task_types):
		return false
	if direction != "" and str(definition.get("direction", "")) != direction:
		return false
	if task_type in CORE_TASK_TYPES:
		return true
	return difficulty_max <= 0 or int(definition.get("difficulty", 1)) <= difficulty_max


## Verbindet eine Definition mit allen kompatiblen Lexemen und hängt die Kandidaten an.
## Relations-/Formaufgaben expandieren über die tatsächlich vorhandenen Relationen/Formen,
## sodass nie eine unauflösbare Instanz entsteht.
func _expand(definition: Dictionary, lexemes: Array, result: Array, limit: int = 0) -> void:
	for source in lexemes:
		if limit > 0 and result.size() >= limit:
			return
		for extra in _instances(definition, source):
			result.append(_candidate(definition, source, extra))


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
func _instances(definition: Dictionary, source: Dictionary) -> Array:
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
		return [{"form_type": form_req}] if not ContentRegistry.forms_for(source_id, form_req).is_empty() else []
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
	var prior := _confidence_prior(candidate["source"])
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
	var reward := int(round(REFERENCE_REWARD * clampf(1.0 + REWARD_SENSITIVITY * net, 0.4, 1.6) * speed_scale))

	# Erfahrung aus derselben Schwierigkeit, aber OHNE `speed_scale`: XP ist
	# Lernfortschritt und keine Beute — eine härtere Welle macht das einzelne Wort nicht
	# schwerer, sie bringt nur mehr Monster und mehr Punkte. Eine schon gemeisterte
	# Aufgabe bringt fast nichts (siehe Experience.MASTERED_XP); geprüft wird das HIER,
	# beim Spawn, denn nach dem Treffer hat PlayerProgress die Confidence bereits
	# angehoben — das Monster, das die Meisterung bringt, zählt noch voll.
	var xp := Experience.for_monster(0.5 + 0.5 * net, c >= PlayerProgress.MASTERY_CONFIDENCE)
	return {
		"task": task,
		"monster_def": monster_def,
		"speed": speed,
		"damage": int(rule.get("base_damage", 10)),
		"reward": reward,
		"xp": xp,
	}
