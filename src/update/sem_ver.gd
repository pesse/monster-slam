class_name SemVer
extends RefCounted
## Versionsvergleich für App und Content-Packs über das Zahlentripel; Suffixe (`-rc1`,
## `+build`) fallen weg. Leer heißt „keine Angabe“: keine Schranke, kein Update. Unlesbar
## heißt: die Schranke greift.


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


## True, wenn `current` die verlangte Mindestversion erreicht; Unlesbares gilt als nicht
## erfüllt.
static func satisfies_min(current: String, minimum: String) -> bool:
	var tc := triple(current)
	var tm := triple(minimum)
	if tc.is_empty() or tm.is_empty():
		return false
	for i in 3:
		if tc[i] != tm[i]:
			return tc[i] > tm[i]
	return true


## True, wenn `current` die verlangte Mindestversion nicht erreicht. Dient für „App zu alt
## für den Pack“ und „installierter Pack zu alt für die App“. Fehlt eine Angabe, gilt keine
## Schranke.
static func too_old_for(current: String, minimum: String) -> bool:
	if current.is_empty() or minimum.is_empty():
		return false
	return not satisfies_min(current, minimum)


## True, wenn `candidate` echt neuer ist als `current`; nie ein Downgrade.
static func is_newer(candidate: String, current: String) -> bool:
	if candidate.is_empty() or current.is_empty():
		return false
	return compare(candidate, current) > 0


## Die laufende Programmfassung aus `config/version` in project.godot.
static func app_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", ""))
