class_name AnswerEvaluator
extends RefCounted
## Wertet Vokabel-Antworten aus: toleranter Abgleich gegen die hinterlegten Lösungen,
## offline und deterministisch. `tokens()` ist die eine Normalisierung, die auch die
## Satzbewertung (SentenceCard) nutzt.

## Wegkürzbare Anlaute auf Eingabe und hinterlegter Antwort. Der englische unbestimmte
## Artikel fehlt mit Absicht: "a few" ist nicht "few".
const _OPTIONAL_PREFIXES := ["der ", "die ", "das ", "eine ", "ein ", "the ", "to "]

## Grammatik-Platzhalter ("criticize sb. (for)") werden auf ein Wildcard-Token abgebildet,
## gleich in welcher Schreibweise oder Sprache ("sb." = "somebody" = "jn."); jeder darf auch
## ganz entfallen. Längere Alternativen zuerst, damit die Alternation nicht kürzer greift.
## Mit Schrägstrich verbundene Platzhalter ("sb./sth.") sind eine Stelle mit zwei Lesarten.
## Wort-Alternativen mit Schrägstrich ("left/right") sind eine Wahl: jede Alternative allein
## ist vollständig, in jeder Breite bis MAX_SLASH_WIDTH (`_slash_alternatives`).
const WILDCARD := "•"
const _PLACEHOLDER_ATOM := \
	"(?:quelque chose|quelqu'un|qch\\.?|qn\\.?|qc\\.?|somebody|someone|something|jemandem|jemanden|jemand|etwas|etw\\.?" \
	+ "|sth\\.?|sb\\.?|jdm\\.?|jds\\.?|jmdn\\.?|jmdm\\.?|jmd\\.?|jdn\\.?|jm\\.?|jn\\.?|jd\\.?)(?!\\p{L})"
const PLACEHOLDER_PATTERN := \
	"(?<!\\p{L})" + _PLACEHOLDER_ATOM + "(?:\\s*/\\s*" + _PLACEHOLDER_ATOM + ")*"

## Klammergruppen ("(for)", "(Pl.)") sind optional: mit oder ohne Klammern tippen oder weglassen.
const GROUP_PATTERN := "\\(([^)]*)\\)"

## Deckel gegen Kombinatorik; weitere Gruppen und Platzhalter bleiben wörtlich.
const MAX_GROUPS := 3
const MAX_PLACEHOLDERS := 4
## Wörter je Seite einer Schrägstrich-Alternative, höchstens ("seit 10 Uhr/letzter Woche").
const MAX_SLASH_WIDTH := 3
## Schrägstrich-Stellen je Eintrag, höchstens; weitere bleiben wörtlich.
const MAX_SLASHES := 2

## Längenzeichen des Lateinischen, auf Eingabe und hinterlegter Antwort auf den
## Grundbuchstaben gefaltet. Umlaute bleiben.
const _MACRONS := {"ā": "a", "ē": "e", "ī": "i", "ō": "o", "ū": "u", "ȳ": "y",
		"ă": "a", "ĕ": "e", "ĭ": "i", "ŏ": "o", "ŭ": "u"}

## Diakritika, die nur der nachsichtige Vergleich faltet (ADR 0008); ein so getroffenes Wort
## wird mit richtiger Schreibweise eingeblendet. Umlaute und ß fehlen mit Absicht.
const _DIACRITICS := {"à": "a", "â": "a", "á": "a", "é": "e", "è": "e", "ê": "e", "ë": "e",
		"î": "i", "ï": "i", "í": "i", "ô": "o", "ó": "o", "û": "u", "ù": "u", "ú": "u",
		"ÿ": "y", "ç": "c", "œ": "oe", "æ": "ae"}
## Zeichen, die nachsichtig als Leerzeichen getippt werden oder fehlen dürfen.
const _JOINERS := ["'", "-", ","]

## Auslassungspunkte („either … or“): kein Platzhalter, sondern in `_normalize` ganz
## entfernt; weglassen ist also vollständig.
const ELLIPSIS_PATTERN := "…|\\.{2,}"

static var _group_re: RegEx = RegEx.create_from_string(GROUP_PATTERN)
static var _placeholder_re: RegEx = RegEx.create_from_string(PLACEHOLDER_PATTERN)
static var _ellipsis_re: RegEx = RegEx.create_from_string(ELLIPSIS_PATTERN)


## Wertet `answer` gegen alle hinterlegten Antworten aus.
##
## Rückgabe:
##   "matched":   passt die Antwort?
##   "complete":  passt sie, ohne dass Optionales weggelassen wurde? Notation darf
##                abweichen, ein fehlender Bestandteil nicht.
##   "canonical": die getroffene hinterlegte Antwort in Originalschreibweise
##   "exact":     traf sie ohne Nachsicht bei der Schreibweise? Nur bei `lenient` false.
##
## `lenient` erlaubt fehlende Akzente, Bindestriche und Apostrophe (ADR 0008), aber erst,
## wenn der exakte Vergleich nichts Vollständiges fand.
func evaluate(accepted: Array, answer: String, lenient := false) -> Dictionary:
	var result := _best_match(accepted, answer, false)
	if not lenient or bool(result["complete"]):
		return result
	var loose := _best_match(accepted, answer, true)
	if bool(loose["complete"]) or (bool(loose["matched"]) and not bool(result["matched"])):
		return loose
	return result


func _best_match(accepted: Array, answer: String, loose: bool) -> Dictionary:
	var result := {"matched": false, "complete": false, "exact": false, "canonical": ""}
	var input := variants(answer, loose)
	if input.is_empty():
		return result
	for a in accepted:
		var candidate := str(a)
		var forms := variants(candidate, loose)
		var hit := false
		var complete := false
		for key in forms:
			if input.has(key):
				hit = true
				complete = complete or bool(forms[key])
		if not hit:
			continue
		if not bool(result["matched"]):
			result["matched"] = true
			result["exact"] = not loose
			result["canonical"] = candidate
		if complete:
			result["complete"] = true
			result["canonical"] = candidate
			return result
	return result


## Richtet `typed` Zeichen für Zeichen an `canonical` aus (kleinste Kosten, wie eine
## Editierdistanz). Rückgabe: `marked` (Indizes in `canonical`, deren Schreibweise
## nachgesehen wurde) und `typed_against` (je Zeichen, ob ihm Getipptes gegenübersteht).
static func _align(canonical: String, typed: String) -> Dictionary:
	var a := _spelling_chars(canonical)
	var b := _spelling_chars(typed.strip_edges())
	var m := a.size()
	var n := b.size()
	const INF := 1 << 20
	# cost[i][j]: günstigste Ausrichtung von a[i..] gegen b[j..]; step[i][j] der Schritt dazu.
	var cost: Array = []
	var step: Array = []
	for i in m + 1:
		var cost_row: Array = []
		cost_row.resize(n + 1)
		cost.append(cost_row)
		var step_row: Array = []
		step_row.resize(n + 1)
		step.append(step_row)
	for i in range(m, -1, -1):
		for j in range(n, -1, -1):
			if i == m and j == n:
				cost[i][j] = 0
				continue
			var best := INF
			var best_step: Array = []
			for option in _spelling_steps(a, b, i, j):
				var total: int = int(option[2]) + int(cost[int(option[0])][int(option[1])])
				if total < best:
					best = total
					best_step = option
			cost[i][j] = best
			step[i][j] = best_step
	var marked: Array[int] = []
	var typed_against: Array[bool] = []   # a[i] steht einem getippten Zeichen gegenüber
	typed_against.resize(m)
	var i := 0
	var j := 0
	while i < m or j < n:
		var s: Array = step[i][j]
		if i < m and int(s[0]) == i + 1:
			typed_against[i] = int(s[1]) > j
			if bool(s[3]):
				marked.append(i)
		i = int(s[0])
		j = int(s[1])
	return {"marked": marked, "typed_against": typed_against}


## Der erste Buchstabe, den man von `answer` tippen muss, in der Schreibweise der Lösung:
## vor ihm stehen höchstens Klammergruppen und wegkürzbare Anlaute ("(to) go" -> "g",
## "der Hund" -> "H"). Leer für eine leere Lösung.
static func initial(answer: String) -> String:
	var rest := answer.strip_edges()
	var stripped := true
	while stripped:
		stripped = false
		if rest.begins_with("(") and rest.find(")") > 0:
			rest = rest.substr(rest.find(")") + 1).strip_edges()
			stripped = true
		for prefix: String in _OPTIONAL_PREFIXES:
			if rest.to_lower().begins_with(prefix):
				rest = rest.substr(prefix.length()).strip_edges()
				stripped = true
	if rest.is_empty():
		rest = answer.strip_edges()
	return rest.left(1)


## Die Indizes in `canonical`, an denen `typed` von der Schreibweise abwich: Diakritika und
## Ligaturen, die ohne getippt wurden, und Verbinder, die fehlten oder als Leerzeichen kamen
## (ADR 0008). Was weggelassen werden durfte, bleibt unmarkiert.
static func spelling_marks(canonical: String, typed: String) -> PackedInt32Array:
	var aligned := _align(canonical, typed)
	var marked: Array[int] = aligned["marked"]
	var typed_against: Array[bool] = aligned["typed_against"]
	var m := typed_against.size()
	# Ein ausgelassener Verbinder ist nur mitten im Getippten ein Fehler, nicht am Rand
	# eines weggelassenen Teils („école“ für „l'école“).
	var marks := PackedInt32Array()
	for k in marked:
		var dropped := not typed_against[k]
		if dropped and not (k > 0 and typed_against[k - 1] and k + 1 < m and typed_against[k + 1]):
			continue
		marks.append(k)
	return marks


## Die Indizes in `canonical`, die bei einem unvollständigen Treffer fehlten (ADR 0010):
## Klammergruppen und Platzhalter, deren Zeichen nichts Getipptes gegenübersteht.
## Leerzeichen bleiben unmarkiert, eine weggelassene Klammergruppe samt Klammern markiert.
static func missing_marks(canonical: String, typed: String) -> PackedInt32Array:
	var typed_against: Array[bool] = _align(canonical, typed)["typed_against"]
	var lower := "".join(_spelling_chars(canonical))
	var regions: Array = []
	for g in _group_re.search_all(lower):
		regions.append([g.get_start(0), g.get_end(0)])
	for p in _placeholder_re.search_all(lower):
		regions.append([p.get_start(0), p.get_end(0)])
	var marked := {}
	for region in regions:
		var omitted := true
		for k in range(int(region[0]), int(region[1])):
			if typed_against[k] and lower[k] != " ":
				omitted = false
				break
		if not omitted:
			continue
		for k in range(int(region[0]), int(region[1])):
			if lower[k] != " ":
				marked[k] = true
	var keys := marked.keys()
	keys.sort()
	return PackedInt32Array(keys)


## Die möglichen Schritte von (i, j): [neues i, neues j, Kosten, markiert a[i]?].
## Kosten: 0 gleich, 1 nachgesehene Schreibweise, 2 Auslassung, 3 Ersetzung.
static func _spelling_steps(a: PackedStringArray, b: PackedStringArray, i: int, j: int) -> Array:
	var out: Array = []
	if i < a.size():
		var c := a[i]
		var joiner := c in _JOINERS
		if j < b.size():
			var t := b[j]
			if c == t:
				out.append([i + 1, j + 1, 0, false])
			else:
				var folded := str(_DIACRITICS.get(c, ""))
				if folded.length() == 1 and folded == t:
					out.append([i + 1, j + 1, 1, true])
				elif joiner and t == " ":
					out.append([i + 1, j + 1, 1, true])
				else:
					out.append([i + 1, j + 1, 3, false])
				if folded.length() == 2 and j + 1 < b.size() and folded == t + b[j + 1]:
					out.append([i + 1, j + 2, 1, true])
		# Fehlender Verbinder: Schreibfehler; fehlender Buchstabe: weggelassener Bestandteil.
		out.append([i + 1, j, 1 if joiner else 2, joiner])
	if j < b.size():
		out.append([i, j + 1, 2, false])
	return out


static func _spelling_chars(s: String) -> PackedStringArray:
	var chars := PackedStringArray()
	for c in s.to_lower().replace("’", "'").replace("‘", "'").replace("–", "-"):
		chars.append(c)
	return chars


## Trifft `answer` eine der Antworten in `accepted`?
func evaluate_answers(accepted: Array, answer: String) -> bool:
	return bool(evaluate(accepted, answer)["matched"])


## Kompatibilitäts-Helfer: prüft gegen entry["answers"].
func evaluate_vocab(entry: Dictionary, answer: String) -> bool:
	return evaluate_answers(entry.get("answers", []), answer)


## Die Vergleichs-Token eines Strings: normalisiert, ohne Satzzeichen, ohne Leerstellen.
func tokens(s: String) -> PackedStringArray:
	return _tokens(s)


## Alle Schreibweisen, unter denen ein String akzeptiert wird: Variante -> vollständig
## (nichts weggelassen). Ein Vergleich zweier Strings ist der Schnitt ihrer Variantenmengen,
## also symmetrisch. `loose` faltet zusätzlich nachsichtig (`_loosen`, ADR 0008).
func variants(s: String, loose := false) -> Dictionary:
	var base := _normalize(s)
	if base.is_empty():
		return {}
	var result := {}
	# Erst Klammern, dann Platzhalter: ein Platzhalter kann in einer Klammergruppe stehen.
	for group_form in _expand(base, _group_slots(base)):
		for form in _expand(str(group_form[0]), _placeholder_slots(str(group_form[0]))):
			var complete: bool = bool(group_form[1]) and bool(form[1])
			# Nach den Platzhaltern: "sb./sth." ist dann schon ein Wildcard.
			for alternative in _slash_alternatives(str(form[0])):
				var key := _strip_optional_prefix(str(alternative))
				if key.is_empty():
					continue
				result[key] = bool(result.get(key, false)) or complete
	if result.is_empty():
		result[base] = true
	if not loose:
		return result
	var folded := {}
	for key in result:
		for form in _loosen(str(key)):
			folded[form] = bool(folded.get(form, false)) or bool(result[key])
	return folded


## Die nachsichtigen Formen einer Variante: ohne Diakritika, jeder Wortverbinder einmal als
## Leerzeichen und einmal weggelassen („l'école" -> „l ecole", „lecole").
func _loosen(key: String) -> Array:
	var folded := key
	for mark in _DIACRITICS:
		folded = folded.replace(mark, _DIACRITICS[mark])
	var forms: Array = [folded]
	for joiner in _JOINERS:
		if not folded.contains(joiner):
			continue
		var next: Array = []
		for f in forms:
			next.append(_collapse(str(f).replace(joiner, " ")))
			next.append(_collapse(str(f).replace(joiner, "")))
		forms = next
	return forms


## Die Lesarten eines Strings mit Wort-Alternativen: er selbst und je Schrägstrich-Wort jede
## Alternative in jeder Breite bis MAX_SLASH_WIDTH. Mehr als zwei Teile wechseln nur
## Einzelwörter; ein leerer Teil ist keine Alternative.
func _slash_alternatives(s: String) -> Array:
	var words := s.split(" ", false)
	# Ein Schrägstrich vor einer weggekürzten Auslassung („woche/…") hängt allein.
	for k in words.size():
		if words[k].length() > 1:
			words[k] = words[k].trim_suffix("/").trim_prefix("/")
	var forms: Array = [" ".join(words)]
	var seen := 0
	# Von rechts nach links, damit die Wörter links einer Alternative an ihrer Stelle bleiben.
	for k in range(words.size() - 1, -1, -1):
		if not _is_slash_word(words[k]):
			continue
		seen += 1
		if seen > MAX_SLASHES:
			break
		var head := words.slice(0, k + 1)
		var next: Array = []
		for f in forms:
			next.append(f)
			var fw := str(f).split(" ", false)
			if fw.size() <= k or fw.slice(0, k + 1) != head:
				continue
			next.append_array(_alternatives_at(fw, k))
		forms = next
	return forms


func _is_slash_word(word: String) -> bool:
	var parts := word.split("/")
	return parts.size() > 1 and parts[0] != "" and parts[1] != "" and not word.begins_with("http")


func _alternatives_at(words: PackedStringArray, k: int) -> Array:
	var out: Array = []
	var parts := words[k].split("/")
	var widths := MAX_SLASH_WIDTH if parts.size() == 2 else 1
	for w in range(1, widths + 1):
		var first := k - w + 1
		var last := k + w - 1
		if first < 0 or last >= words.size():
			break
		var before := " ".join(words.slice(0, first))
		var after := " ".join(words.slice(last + 1))
		for i in parts.size():
			if parts[i].is_empty():
				continue
			var middle: Array[String] = []
			if i == 0:
				middle.append_array(Array(words.slice(first, k)))
			middle.append(parts[i])
			if i == parts.size() - 1:
				middle.append_array(Array(words.slice(k + 1, last + 1)))
			out.append(_collapse("%s %s %s" % [before, " ".join(middle), after]))
	return out


## Klammergruppen dreifach auflösen: behalten, entklammert, weggelassen. Nur das
## Weglassen macht die Variante unvollständig — Klammern sind bloß Notation.
func _group_slots(s: String) -> Array:
	var slots: Array = []
	for g in _group_re.search_all(s):
		if slots.size() >= MAX_GROUPS:
			break
		slots.append({
			"start": g.get_start(0),
			"end": g.get_end(0),
			"options": [[g.get_string(0), true], [g.get_string(1).strip_edges(), true], ["", false]],
		})
	return slots


## Platzhalter je Vorkommen entweder auf das Wildcard-Token abbilden (Notation egal,
## Struktur erhalten -> vollständig) oder weglassen (-> unvollständig).
func _placeholder_slots(s: String) -> Array:
	var slots: Array = []
	for m in _placeholder_re.search_all(s):
		if slots.size() >= MAX_PLACEHOLDERS:
			break
		slots.append({
			"start": m.get_start(0),
			"end": m.get_end(0),
			"options": [[WILDCARD, true], ["", false]],
		})
	return slots


## Setzt den String aus seinen festen Teilen und allen Kombinationen der optionalen
## Bereiche neu zusammen, positionsbasiert: jedes Vorkommen entscheidet einzeln.
## Rückgabe: Array von [String, bool complete].
func _expand(s: String, slots: Array) -> Array:
	if slots.is_empty():
		return [[_collapse(s), true]]
	var forms: Array = [["", true]]
	var cursor := 0
	for slot in slots:
		var fixed := s.substr(cursor, int(slot["start"]) - cursor)
		var next: Array = []
		for f in forms:
			for option in slot["options"]:
				next.append([
					str(f[0]) + fixed + str(option[0]),
					bool(f[1]) and bool(option[1]),
				])
		forms = next
		cursor = int(slot["end"])
	var tail := s.substr(cursor)
	var out: Array = []
	for f in forms:
		out.append([_collapse(str(f[0]) + tail), bool(f[1])])
	return out


## Vereinheitlicht Schreibweise: Kleinschreibung, typografische Zeichen, Mehrfach-
## Leerzeichen, Auslassungspunkte, Satzendzeichen ("That's fine by me." == "that's fine by me").
func _normalize(s: String) -> String:
	var normalized := s.strip_edges().to_lower()
	normalized = normalized.replace("’", "'").replace("‘", "'")
	normalized = normalized.replace("“", '"').replace("”", '"')
	normalized = normalized.replace("–", "-").replace("—", "-")
	for mark in _MACRONS:
		normalized = normalized.replace(mark, _MACRONS[mark])
	normalized = _ellipsis_re.sub(normalized, " ", true).strip_edges()
	while normalized.ends_with(".") or normalized.ends_with("!") or normalized.ends_with("?"):
		normalized = normalized.substr(0, normalized.length() - 1).strip_edges()
	return _strip_optional_prefix(_collapse(normalized))


func _strip_optional_prefix(s: String) -> String:
	for prefix in _OPTIONAL_PREFIXES:
		if s.begins_with(prefix):
			return s.substr(prefix.length()).strip_edges()
	return s


## Zieht Mehrfach-Leerzeichen zusammen, auch innen an Klammern und vor dem Komma, damit
## "(to )" die getippte Form "(to)" trifft.
func _collapse(s: String) -> String:
	var out := " ".join(s.split(" ", false))
	return out.replace("( ", "(").replace(" )", ")").replace(" ,", ",")


func _tokens(s: String) -> PackedStringArray:
	return _normalize(s).replace(".", " ").replace(",", " ").split(" ", false)
