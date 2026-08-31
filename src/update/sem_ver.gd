class_name SemVer
extends RefCounted
## Versionsvergleich für die beiden Update-Kanäle (App und Content-Packs).
##
## Verglichen wird das Zahlentripel; ein Suffix (`-rc1`, `+build`, vierte Stelle) fällt
## weg, damit ein Release Candidate der verlangten Version die Schranke ERFÜLLT statt an
## ihr zu scheitern.
##
## Ein leerer String heißt „keine Angabe" und wird nirgends geraten: er ergibt keine
## Schranke (`too_old_for`) und kein Update (`is_newer`). Eine *unlesbare* Angabe ist der
## umgekehrte Fall — dort greift die Schranke, denn wer die Zahl nicht versteht, darf nicht
## annehmen, dass er sie erfüllt.


## Zahlentripel einer Version, oder [] wenn unlesbar.
static func triple(v: String) -> Array:
	var core := v.strip_edges().trim_prefix("v").split("-")[0].split("+")[0]
	var parts := core.split(".")
	if parts.size() < 3:
		return []
	var out: Array = []
	for i in 3:
		var part := parts[i].strip_edges()
		if not part.is_valid_int():
			return []
		out.append(int(part))
	return out


## -1 / 0 / 1 wie üblich; 0 auch, wenn eine Seite unlesbar ist (dann entscheidet der Aufrufer).
static func compare(a: String, b: String) -> int:
	var ta := triple(a)
	var tb := triple(b)
	if ta.is_empty() or tb.is_empty():
		return 0
	for i in 3:
		if ta[i] != tb[i]:
			return -1 if ta[i] < tb[i] else 1
	return 0


## True, wenn `current` die verlangte Mindestversion erreicht. Unlesbares gilt als NICHT
## erfüllt — geraten wird nicht.
static func satisfies_min(current: String, minimum: String) -> bool:
	var tc := triple(current)
	var tm := triple(minimum)
	if tc.is_empty() or tm.is_empty():
		return false
	for i in 3:
		if tc[i] != tm[i]:
			return tc[i] > tm[i]
	return true


## True, wenn `current` die verlangte Mindestversion nicht erreicht.
##
## Zwei Richtungen, eine Schranke: mit der App-Version gegen die `min_app_version` eines
## Packs heißt es „App zu alt für diesen Inhalt"; mit der `min_app_version` des INSTALLIERTEN
## Packs gegen die des Index heißt es „Inhalt zu alt für diese App" — der Fall, in dem
## Mechanik still fehlt.
##
## Beide Richtungen wirken nur nach vorn: fehlt eine der beiden Angaben, gilt keine Schranke.
static func too_old_for(current: String, minimum: String) -> bool:
	if current.is_empty() or minimum.is_empty():
		return false
	return not satisfies_min(current, minimum)


## True, wenn `candidate` echt neuer ist als `current`.
static func is_newer(candidate: String, current: String) -> bool:
	if candidate.is_empty() or current.is_empty():
		return false
	return compare(candidate, current) > 0


## Die laufende Programmfassung — einzige Quelle ist `config/version` in project.godot,
## das der Release-Workflow aus dem Tag speist.
static func app_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", ""))
