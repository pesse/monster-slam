class_name AnswerEvaluator
extends RefCounted
## Wertet Vokabel-Antworten aus: toleranter Abgleich gegen die hinterlegten Lösungen,
## offline und deterministisch.
##
## GANZE SÄTZE bewertet diese Klasse nicht mehr. Das war einmal eine Token-Überschneidung
## (`evaluate_sentence`), deren Ergebnis niemand sehen sollte; seit
## docs/adr/0004-satzbewertung-ohne-modell.md liegt die Satzbewertung in SentenceCard
## (Stufe 0, Lösungsschlüssel aus den Daten) und SentenceJudge (Vertrag und optionale
## Stufe 1). Die Normalisierung teilen sich beide — sie ist hier zu Hause und steht
## dafür über `tokens()` offen.

## Wegkürzbare Anlaute: der deutsche Artikel (Ziel ist Englisch lernen, nicht Deutsch),
## das englische "the" und das englische "to" vor dem Infinitiv. Das Lehrbuch schreibt
## beide mal mit und mal ohne — "the underground" neben "underground", "to brainstorm"
## neben "brainstorm" —, und abgefragt wird die Vokabel und nicht die Notation des
## Eintrags. Wird auf Eingabe UND hinterlegte Antwort angewendet, sodass "das Haus"/
## "Haus", "the underground"/"underground" und "to brainstorm"/"brainstorm" gleichwertig
## sind (symmetrisch, also ohne Datenmigration).
##
## Der englische UNBESTIMMTE Artikel steht bewusst NICHT hier: "a few" ist nicht "few"
## und "a little" nicht "little" — das ist der Unterschied, den das Buch lehrt, und beide
## Paare stehen als eigene Vokabeln im Bestand.
##
## Nur mit folgendem Leerzeichen, damit die Vokabeln "to" und "the" selbst nicht
## verschwinden.
const _OPTIONAL_PREFIXES := ["der ", "die ", "das ", "eine ", "ein ", "the ", "to "]

## Grammatik-Platzhalter aus dem Lehrbuch ("criticize sb. (for)"). Sie werden auf EIN
## Wildcard-Token abgebildet, sodass Schreibweise und Sprache der Notation gleichgültig
## sind: "sb." = "sb" = "somebody" = "jn." = "jmd." = "jemanden". Zusätzlich darf jeder
## Platzhalter ganz entfallen. Längere Alternativen zuerst, damit die Alternation nicht
## kürzer greift. "jmd."/"jmdn."/"jmdm." stehen nicht im Buch, aber so kürzen Kinder ab.
## Französisch: "qn" = "quelqu'un", "qc"/"qch" = "quelque chose" (ADR 0008).
##
## Mit Schrägstrich verbundene Platzhalter ("wait for sb./sth.", "jn./etwas") sind EINE
## Stelle mit zwei Lesarten, nicht zwei Stellen: "wait for sb", "wait for sth" und
## "wait for sb / sth" sind alle vollständig.
##
## Auslassungspunkte sind KEIN Platzhalter: weggelassen wären sie sonst „unvollständig".
## Sie fallen schon in `_normalize` weg (ELLIPSIS_PATTERN).
const WILDCARD := "•"
const _PLACEHOLDER_ATOM := \
	"(?:quelque chose|quelqu'un|qch\\.?|qn\\.?|qc\\.?|somebody|someone|something|jemandem|jemanden|jemand|etwas|etw\\.?" \
	+ "|sth\\.?|sb\\.?|jdm\\.?|jds\\.?|jmdn\\.?|jmdm\\.?|jmd\\.?|jdn\\.?|jm\\.?|jn\\.?|jd\\.?)(?!\\p{L})"
const PLACEHOLDER_PATTERN := \
	"(?<!\\p{L})" + _PLACEHOLDER_ATOM + "(?:\\s*/\\s*" + _PLACEHOLDER_ATOM + ")*"

## Klammergruppen sind optional: "(for)", "(wegen)", aber auch Glossen wie "(Kleidung)"
## oder "(Pl.)". Für die Auswertung ist beides dasselbe — was in Klammern steht, darf
## getippt werden, mit oder ohne Klammern, oder eben nicht.
const GROUP_PATTERN := "\\(([^)]*)\\)"

## Deckel gegen Kombinatorik. Im Bestand liegt das Maximum bei einer Klammergruppe und
## zwei Platzhaltern (10 Varianten); was darüber liegt, wird nur noch "behalten".
const MAX_GROUPS := 3
const MAX_PLACEHOLDERS := 4

## Längenzeichen des Lateinischen. Kein Kind tippt „ā", und das Buch fragt die Vokabel ab,
## nicht die Quantität: auf Eingabe UND hinterlegter Antwort auf den Grundbuchstaben
## gefaltet. Umlaute sind keine Längenzeichen und bleiben.
const _MACRONS := {"ā": "a", "ē": "e", "ī": "i", "ō": "o", "ū": "u", "ȳ": "y",
		"ă": "a", "ĕ": "e", "ĭ": "i", "ŏ": "o", "ŭ": "u"}

## Diakritika, die der NACHSICHTIGE Vergleich faltet (ADR 0008): Französisch lässt sich
## auf der deutschen Tastatur kaum tippen (ç, œ gar nicht), die Schreibweise ist aber
## Lernstoff. Anders als die Makrons nicht in `_normalize` — ein so getroffenes Wort wird
## mit richtiger Schreibweise eingeblendet. Umlaute und ß fehlen mit Absicht: sie sind die
## deutsche Seite.
const _DIACRITICS := {"à": "a", "â": "a", "á": "a", "é": "e", "è": "e", "ê": "e", "ë": "e",
		"î": "i", "ï": "i", "í": "i", "ô": "o", "ó": "o", "û": "u", "ù": "u", "ú": "u",
		"ÿ": "y", "ç": "c", "œ": "oe", "æ": "ae"}
## Zeichen, die nachsichtig als Leerzeichen getippt werden oder fehlen dürfen: die
## Wortverbinder („est ce que", „aujourdhui") und das Komma („yes please"). Ein Komma
## ist Schreibweise wie ein Bindestrich — wer es weglässt, kennt das Wort trotzdem.
const _JOINERS := ["'", "-", ","]

## Auslassungspunkte („not only … but also", „either ... or"): eine Lücke im Eintrag,
## kein Bestandteil. Wie ein Satzpunkt ganz wegnormalisiert, ob als „…", „..." oder
## „..", getippt oder nicht — weglassen ist also vollständig.
const ELLIPSIS_PATTERN := "…|\\.{2,}"

static var _group_re: RegEx = RegEx.create_from_string(GROUP_PATTERN)
static var _placeholder_re: RegEx = RegEx.create_from_string(PLACEHOLDER_PATTERN)
static var _ellipsis_re: RegEx = RegEx.create_from_string(ELLIPSIS_PATTERN)


## Wertet `answer` gegen alle hinterlegten Antworten aus.
##
## Rückgabe:
##   "matched":   passt die Antwort?
##   "complete":  passt sie OHNE dass etwas Optionales weggelassen wurde? Notation darf
##                abweichen ("criticize sb for" ist vollständig), ein fehlender Bestandteil
##                nicht ("criticize" ist richtig, aber unvollständig).
##   "canonical": die getroffene hinterlegte Antwort in Originalschreibweise — bei
##                unvollständigem Treffer die Form, die der Spieler noch sehen soll.
##   "exact":     traf sie ohne Nachsicht bei der Schreibweise? Nur bei `lenient` kann
##                das false sein; `canonical` ist dann die richtige Schreibweise.
##
## `lenient` erlaubt fehlende Akzente, Bindestriche und Apostrophe (ADR 0008) — aber erst,
## wenn der exakte Vergleich nichts Vollständiges fand. Der Wellenkampf fragt so, die
## Satzbewertung nicht.
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
			# Bester Fall — die Suche kann hier aufhören.
			result["complete"] = true
			result["canonical"] = candidate
			return result
	return result


## Die Stellen in `canonical`, an denen `typed` von der Schreibweise abwich: Indizes der
## Zeichen mit Akzent, Cédille oder Ligatur, die ohne getippt wurden, und der Bindestriche
## und Apostrophe, die fehlten oder als Leerzeichen kamen. Für die Einblendung nach einem
## nachsichtigen Treffer (ADR 0008, `exact` false): das Kind sieht die richtige Form mit
## markierten Fehlern, nicht seine eigene.
##
## Ausgerichtet wird Zeichen für Zeichen (kleinste Kosten, wie eine Editierdistanz). Was
## weggelassen werden durfte (Artikel, Klammerteile, Platzhalter), ist kein Schreibfehler
## und bleibt unmarkiert — markiert wird nur, was `_loosen` nachsieht.
static func spelling_marks(canonical: String, typed: String) -> PackedInt32Array:
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
	# Ein ausgelassener Verbinder ist nur ein Fehler MITTEN im Getippten („lecole"), nicht
	# am Rand eines weggelassenen Teils („école" für „l'école": der Artikel durfte fehlen).
	var marks := PackedInt32Array()
	for k in marked:
		var dropped := not typed_against[k]
		if dropped and not (k > 0 and typed_against[k - 1] and k + 1 < m and typed_against[k + 1]):
			continue
		marks.append(k)
	return marks


## Die möglichen Schritte von (i, j): [neues i, neues j, Kosten, markiert a[i]?].
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
		# Ein fehlender Verbinder ist ein Schreibfehler, ein fehlender Buchstabe ein
		# weggelassener Bestandteil (Artikel, Klammer, Platzhalter).
		out.append([i + 1, j, 1 if joiner else 2, joiner])
	if j < b.size():
		out.append([i, j + 1, 2, false])
	return out


static func _spelling_chars(s: String) -> PackedStringArray:
	var chars := PackedStringArray()
	for c in s.to_lower().replace("’", "'").replace("‘", "'").replace("–", "-"):
		chars.append(c)
	return chars


## Returns true if `answer` matches any accepted answer.
## Nimmt direkt die Liste gültiger Antworten (z. B. task.accepted_answers).
func evaluate_answers(accepted: Array, answer: String) -> bool:
	return bool(evaluate(accepted, answer)["matched"])


## Kompatibilitäts-Helfer: prüft gegen entry["answers"].
func evaluate_vocab(entry: Dictionary, answer: String) -> bool:
	return evaluate_answers(entry.get("answers", []), answer)


## Die Vergleichs-Token eines Strings: normalisiert, ohne Satzzeichen, ohne Leerstellen.
## Öffentlich, weil die Satzbewertung dieselbe Zerlegung braucht (SentenceCard) — zwei
## Normalisierungen nebeneinander liefen irgendwann auseinander.
func tokens(s: String) -> PackedStringArray:
	return _tokens(s)


## Alle Schreibweisen, unter denen ein String akzeptiert wird: Variante -> „vollständig".
## Vollständig heißt: bei der Erzeugung wurde nichts weggelassen. Ein Vergleich zweier
## Strings ist damit der Schnitt ihrer Variantenmengen — symmetrisch, sodass es keine
## Rolle spielt, ob Klammern und Platzhalter in den Daten oder in der Eingabe stehen.
##
## Öffentlich, weil die Datenvalidierung dieselbe Frage stellt wie die Auswertung: ob sich
## zwei Lemmata unterscheiden lassen, entscheidet der Schnitt ihrer VOLLSTÄNDIGEN Varianten
## (tests/lexeme_data_test.gd). Eine zweite Normalisierung daneben liefe davon weg.
##
## `loose` faltet jede Variante zusätzlich nachsichtig (`_loosen`, ADR 0008).
func variants(s: String, loose := false) -> Dictionary:
	var base := _normalize(s)
	if base.is_empty():
		return {}
	var result := {}
	# Erst die Klammern, dann die Platzhalter: ein Platzhalter kann INNERHALB einer
	# Klammergruppe stehen ("prefer sth. (to sth.)"), und auch der soll zum Wildcard
	# werden. Zwei Stufen, weil sich die Bereiche sonst überlappen würden.
	for group_form in _expand(base, _group_slots(base)):
		for form in _expand(str(group_form[0]), _placeholder_slots(str(group_form[0]))):
			var key := _strip_optional_prefix(str(form[0]))
			if key.is_empty():
				continue
			var complete: bool = bool(group_form[1]) and bool(form[1])
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
## Bereiche neu zusammen. Positionsbasiert und nicht über replace(), weil derselbe
## Platzhalter mehrfach vorkommen kann ("prefer sth. (to sth.)") und dann jedes
## Vorkommen einzeln entscheidbar sein muss.
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


## Mehrfach-Leerzeichen zusammenziehen — entsteht beim Weglassen von Bestandteilen.
## Auch direkt an den Klammern, sonst bliebe aus "(to sth.)" ohne Platzhalter ein
## "(to )" stehen, das die getippte Form "(to)" nicht mehr trifft. Ebenso vor dem Komma:
## aus "les uns…, les autres" wird ohne Lücke "les uns, les autres", nicht "les uns , …".
func _collapse(s: String) -> String:
	var out := " ".join(s.split(" ", false))
	return out.replace("( ", "(").replace(" )", ")").replace(" ,", ",")


func _tokens(s: String) -> PackedStringArray:
	return _normalize(s).replace(".", " ").replace(",", " ").split(" ", false)
