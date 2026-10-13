class_name AccessCodes
extends RefCounted
## Hinterlegte Zugangscodes für geschützte Content-Packs, mit der `keyVersion`, unter der sie
## gespeichert wurden. Bewusst keine Geheimnis-Ablage (ADR 0001).

const PATH := "user://codes.cfg"
const SECTION := "codes"


## {"code": String, "key_version": int} oder {} wenn keiner hinterlegt ist.
static func get_code(pack_id: String) -> Dictionary:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return {}
	var stored := str(config.get_value(SECTION, pack_id, ""))
	if stored.is_empty():
		return {}
	# Format ist "<keyVersion>:<code>"; ein Eintrag ohne Präfix gilt als Version 1.
	var split := stored.split(":", true, 1)
	if split.size() == 2 and split[0].is_valid_int():
		return {"code": split[1], "key_version": int(split[0])}
	return {"code": stored, "key_version": 1}


static func store(pack_id: String, code: String, key_version: int) -> void:
	var config := ConfigFile.new()
	config.load(PATH)
	config.set_value(SECTION, pack_id, "%d:%s" % [key_version, code])
	if config.save(PATH) != OK:
		push_warning("AccessCodes: '%s' nicht schreibbar." % PATH)


static func forget(pack_id: String) -> void:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return
	config.erase_section_key(SECTION, pack_id)
	config.save(PATH)
