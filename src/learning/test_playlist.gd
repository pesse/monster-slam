class_name TestPlaylist
extends RefCounted
## Der Beutel einer Testliste: jedes Wort einmal, dann erst wieder. Eine Runde läuft über
## beliebig viele Wellen; ein Wort ist gespielt, wenn seine jüngste Antwort seit
## Rundenbeginn richtig war. Gespeichert wird nur der Rundenbeginn (TestLists,
## `round_started_at`). Welche Aufgabe eines Wortes drankommt, wählt WaveGenerator.ordered;
## die Playlist bestimmt nur das Wort.


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
