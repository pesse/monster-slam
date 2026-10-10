class_name SaveGuard
extends RefCounted
## Die Plausibilitätssperre des Spielstands (docs/adr/0024-spielstand-sicher-speichern.md).
##
## Manche Werte eines Profils wachsen nur: die Gesamt-Erfahrung, das insgesamt verdiente
## Gold, die geöffneten Kisten, die Zahl der Lernstände, Sitzungen und Boss-Siege. Ein
## Speichern, das einen davon SENKEN würde, ist ein Fehler — genau so ging ein Spielstand
## verloren: eine unlesbare Datei wurde als „0 XP" geladen und beim nächsten Kill
## gespeichert. Ein solches Schreiben wird verweigert, gemeldet und die Datei bleibt, wie
## sie ist.
##
## Verglichen wird mit der Datei auf der Platte, nicht mit einem Zähler daneben — es gibt
## keinen zweiten gespeicherten Wert. Sinken darf ein Wert nur über eine ausdrückliche
## Ausnahme (`allow_drop`): „Fortschritt zurücksetzen", Import, „leer weiterspielen".

## Monotone Werte je Datei-Endung. `#feld` zählt die Einträge einer Liste oder eines
## Dictionaries.
const MONOTONIC := {
	"": ["#records"],
	"_level": ["total_xp"],
	"_wallet": ["total_earned", "chests_opened"],
	"_sessions": ["#sessions"],
	"_bosses": ["#wins"],
}


## Die monotonen Werte von `data` für die Datei mit Endung `suffix`.
static func metrics(suffix: String, data: Dictionary) -> Dictionary:
	var out := {}
	for field: String in MONOTONIC.get(suffix, []):
		if field.begins_with("#"):
			var value: Variant = data.get(field.substr(1))
			out[field] = (value as Array).size() if value is Array \
					else ((value as Dictionary).size() if value is Dictionary else 0)
		else:
			out[field] = int(data.get(field, 0))
	return out


## Was beim Schritt von `before` nach `after` sinken würde: [{field, old, new}].
static func drops(suffix: String, before: Dictionary, after: Dictionary) -> Array:
	var was := metrics(suffix, before)
	var will := metrics(suffix, after)
	var out: Array = []
	for field in was:
		if int(will.get(field, 0)) < int(was[field]):
			out.append({"field": field, "old": int(was[field]), "new": int(will.get(field, 0))})
	return out


## Darf `data` nach `path` (Endung `suffix`)? "" heißt ja; sonst der Grund. Eine Datei, die
## nicht lesbar ist oder aus einer neueren Fassung stammt, wird nie überschrieben.
static func check(path: String, suffix: String, data: Dictionary, allow_drop := false) -> String:
	var watched := MONOTONIC.has(suffix) and not allow_drop
	var current := SaveStore.read(path, watched)
	match int(current["status"]):
		SaveStore.Status.CORRUPT:
			return "beschädigt (%s)" % current["error"]
		SaveStore.Status.NEWER:
			return "aus einer neueren Fassung"
		SaveStore.Status.MISSING:
			return ""
	if not watched:
		return ""
	var lost := drops(suffix, current["data"], data)
	if lost.is_empty():
		return ""
	var first: Dictionary = lost[0]
	return "%s würde von %d auf %d sinken" % [first["field"], first["old"], first["new"]]


## Schreibt `data` sicher nach `path`, wenn `check` es erlaubt; sonst bleibt die Datei und
## es kommt ERR_UNAUTHORIZED zurück (und eine Meldung über den EventBus).
static func write(path: String, suffix: String, data: Dictionary, allow_drop := false) -> Error:
	var reason := check(path, suffix, data, allow_drop)
	if not reason.is_empty():
		refuse(path, reason)
		return ERR_UNAUTHORIZED
	return SaveStore.write(path, data)


## Meldet ein verweigertes Speichern. Eine Warnung und kein Fehler: der Spielstand ist
## sicher, nur der neue Stand kam nicht an.
static func refuse(path: String, reason: String) -> void:
	push_warning("Speichern verweigert: %s — %s" % [path, reason])
	EventBus.save_refused.emit(path.get_file(), reason)
