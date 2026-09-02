class_name ReportToken
extends RefCounted
## Hinterlegtes Melde-Token — wer es hat, hat einen Rückkanal (siehe
## docs/adr/0002-melde-rueckkanal.md).
##
## Ablage ist `user://codes.cfg`, Sektion `report` — dieselbe Datei wie die
## Pack-Zugangscodes (`AccessCodes`), weil es für den Spieler dasselbe ist: „was ich hier
## eingetragen habe". Eigene Sektion, weil `codes` nach `pack_id` geschlüsselt ist und ein
## Melde-Token kein Pack ist.
##
## **Das ist keine Geheimnis-Ablage**, genauso wie bei `AccessCodes`: Godot hat keinen
## Zugriff auf einen Schlüsselbund des Betriebssystems, und wer die Datei lesen kann, liest
## auch die entpackten Vokabeln daneben. Das Token schützt den öffentlichen Endpunkt, nicht
## den lokalen Rechner.
##
## Mitgeführt wird die `keyVersion`, unter der es gespeichert wurde: daran erkennt der
## Endpunkt eine Rotation des Geheimnisses und kann sie benennen (`stale_key`), statt das
## Token nur „ungültig" zu nennen.

const PATH := "user://codes.cfg"
const SECTION := "report"
const KEY := "token"

## Crockford-Base32 ohne I, L, O, U. Format: tools/report/mint_token.py, server/melden/token.php.
const ALPHABET := "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
const MAC_CHARS := 16

static var _label_re: RegEx = null


## {"token": String, "key_version": int} oder {} wenn keines hinterlegt ist.
static func get_stored() -> Dictionary:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return {}
	var stored := str(config.get_value(SECTION, KEY, ""))
	if stored.is_empty():
		return {}
	# Format ist "<keyVersion>:<token>"; ein Eintrag ohne Präfix gilt als Version 1.
	var split := stored.split(":", true, 1)
	if split.size() == 2 and split[0].is_valid_int():
		return {"token": split[1], "key_version": int(split[0])}
	return {"token": stored, "key_version": 1}


static func has_token() -> bool:
	return not get_stored().is_empty()


static func store(token: String, key_version: int) -> void:
	var config := ConfigFile.new()
	config.load(PATH)
	config.set_value(SECTION, KEY, "%d:%s" % [key_version, token])
	if config.save(PATH) != OK:
		push_warning("ReportToken: '%s' nicht schreibbar." % PATH)


static func forget() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return
	config.erase_section_key(SECTION, KEY)
	config.save(PATH)


## Bringt ein abgetipptes Token auf die kanonische Form `label.MAC16`, oder "" wenn schon
## die Gestalt nicht passt. Prüft NICHT die Signatur — das kann nur der Endpunkt, das
## Geheimnis liegt dort. Der Zweck ist, einen Tippfehler ohne Netzrunde zu erkennen.
##
## Toleriert, was beim Abtippen passiert: Leerzeichen, Bindestriche, Kleinschreibung und
## die Crockford-Verwechslungen O->0, I/L->1.
static func normalize(raw: String) -> String:
	var text := raw.strip_edges()
	var dot := text.find(".")
	if dot <= 0:
		return ""
	var label := text.substr(0, dot).to_lower()
	var mac := text.substr(dot + 1).to_upper()
	mac = mac.replace("-", "").replace(" ", "").replace("\t", "")
	mac = mac.replace("O", "0").replace("I", "1").replace("L", "1")
	if not label_ok(label):
		return ""
	if mac.length() != MAC_CHARS:
		return ""
	for i in mac.length():
		if not ALPHABET.contains(mac[i]):
			return ""
	return "%s.%s" % [label, mac]


static func label_ok(label: String) -> bool:
	if _label_re == null:
		_label_re = RegEx.new()
		_label_re.compile("^[a-z0-9][a-z0-9-]{0,23}$")
	return _label_re.search(label) != null


## Der Melder-Name aus einem kanonischen Token ("" wenn keiner drinsteht).
static func label_of(token: String) -> String:
	var dot := token.find(".")
	return token.substr(0, dot) if dot > 0 else ""
