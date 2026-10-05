class_name TestPlaylist
extends RefCounted
## Der Beutel einer Testliste: jedes Wort einmal, dann erst wieder — wie eine Zufalls-Playlist.
##
## Eine **Runde** ist ein Durchgang durch die ganze Liste, über beliebig viele Wellen und
## Sitzungen; die Welle ist nur die Einheit, in der gespawnt wird. Gespielt ist ein Wort in
## der Runde, wenn seine jüngste Antwort (über alle seine Aufgaben) seit Rundenbeginn richtig
## war — ein Fehler legt es damit von selbst zurück in den Beutel. Gespeichert wird nur der
## Rundenbeginn (TestLists, `round_started_at`), der Rest kommt aus dem Lernstand.
##
## Zu Beginn jeder Welle wird der noch nicht gespielte Teil neu gemischt; die Wörter der
## vorigen Welle stehen dabei hinten, damit an der Wellengrenze keins direkt wiederkommt.
## Reicht der Beutel nicht für die Welle, füllen die schon gespielten Wörter auf, ebenso
## gemischt. Ist er zu Wellenbeginn leer, beginnt eine neue Runde.
##
## Die Aufgabe eines Wortes wählt weiter WaveGenerator.ordered (fällig → neu → Rest); die
## Playlist bestimmt nur, WELCHES Wort dran ist. Reine Rechnung (tests/test_playlist_test.gd).


## Die Wörter, die in der Runde noch dran sind. `words`: Grundwort-Id -> learnable_ids.
## `last_seen`/`last_correct`: learnable_id -> unix bzw. bool (PlayerProgress).
static func unplayed(words: Dictionary, last_seen: Callable, last_correct: Callable,
		round_start: int) -> Array:
	var out: Array = []
	for source in words:
		var latest := 0
		var correct := false
		for id in words[source]:
			var at := int(last_seen.call(id))
			if at > latest:
				latest = at
				correct = bool(last_correct.call(id))
		if latest < round_start or not correct:
			out.append(source)
	return out


## Die Reihenfolge einer Welle: der gemischte Beutel, dahinter die gespielten Wörter; in
## beiden Teilen die Wörter der vorigen Welle (`previous`, Id -> beliebig) zuletzt.
static func wave_order(unplayed_words: Array, all_words: Array, previous: Dictionary) -> Array:
	var open := {}
	for word in unplayed_words:
		open[word] = true
	var order := _mixed(unplayed_words, previous)
	order.append_array(_mixed(all_words.filter(func(w): return not open.has(w)), previous))
	return order


static func _mixed(words: Array, previous: Dictionary) -> Array:
	var fresh: Array = []
	var recent: Array = []
	for word in words:
		(recent if previous.has(word) else fresh).append(word)
	fresh.shuffle()
	recent.shuffle()
	return fresh + recent


## Ordnet eine WaveGenerator.listing Wort für Wort nach `order`. Innerhalb eines Wortes
## bleibt die Reihenfolge der listing (welche Aufgabe), Wörter, die in dieser Welle schon
## dran waren (`repeat`), kommen erst danach, Wörter ohne Platz in `order` ganz zuletzt.
static func arrange(listing: Array, order: Array) -> Array:
	var rank := {}
	for i in order.size():
		rank[order[i]] = i
	var groups := {}
	var sources: Array = []
	for c in listing:
		var source := str(c["source"].get("id", ""))
		if not groups.has(source):
			groups[source] = []
			sources.append(source)
		groups[source].append(c)
	var tail := order.size()
	var key := func(source: String) -> int:
		var again := 1 if bool(groups[source][0].get("repeat", false)) else 0
		return again * (tail + 1) + int(rank.get(source, tail))
	sources.sort_custom(func(a, b): return int(key.call(a)) < int(key.call(b)))
	var out: Array = []
	for source in sources:
		out.append_array(groups[source])
	return out
