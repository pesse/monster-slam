extends GdUnitTestSuite
## Meldungen ("dieses Wort ist falsch") liegen in `user://`, nicht im Content.
##
## Der Test fasst den echten ContentRegistry-Autoload an und sichert/restauriert die
## Meldungsdatei, damit die Meldungen des Entwicklers nicht verloren gehen.

var _backup: String = ""
var _had_backup: bool = false
var _lexeme_id: String = ""


func before_test() -> void:
	_had_backup = FileAccess.file_exists(LexemeFlags.PATH)
	_backup = FileAccess.get_file_as_string(LexemeFlags.PATH) if _had_backup else ""
	DirAccess.remove_absolute(LexemeFlags.PATH)
	var ids := ContentRegistry.lexemes.keys()
	_lexeme_id = String(ids[0]) if not ids.is_empty() else ""


func after_test() -> void:
	if _had_backup:
		var file := FileAccess.open(LexemeFlags.PATH, FileAccess.WRITE)
		file.store_string(_backup)
		file.close()
	else:
		DirAccess.remove_absolute(LexemeFlags.PATH)
	ContentRegistry.reload()


func test_load_all_ohne_datei_ist_leer() -> void:
	assert_dict(LexemeFlags.load_all()).is_empty()


func test_load_all_ignoriert_kaputte_datei() -> void:
	var file := FileAccess.open(LexemeFlags.PATH, FileAccess.WRITE)
	file.store_string("[1, 2, 3]")  # Array statt Objekt
	file.close()
	assert_dict(LexemeFlags.load_all()).is_empty()


func test_save_und_load_round_trip() -> void:
	assert_bool(LexemeFlags.save_all({"lex.x": LexemeFlags.entry("falsch", "learn.x")})).is_true()
	var loaded := LexemeFlags.load_all()
	assert_dict(loaded).contains_keys(["lex.x"])
	assert_str(String(loaded["lex.x"]["comment"])).is_equal("falsch")
	assert_str(String(loaded["lex.x"]["learnable_id"])).is_equal("learn.x")
	assert_str(String(loaded["lex.x"]["at"])).is_not_empty()


func test_flag_lexeme_schreibt_nicht_in_die_quelldatei() -> void:
	if _lexeme_id.is_empty():
		return  # ohne Sprachdaten (EXE-Build, Submodule fehlt) nicht prüfbar
	var source := ContentRegistry.source_file("lexemes", _lexeme_id)
	var before := FileAccess.get_file_as_string(source)
	assert_bool(ContentRegistry.flag_lexeme(_lexeme_id, "Tippfehler", "learn.y")).is_true()
	assert_str(FileAccess.get_file_as_string(source)).is_equal(before)
	assert_dict(LexemeFlags.load_all()).contains_keys([_lexeme_id])


func test_flag_lexeme_wirkt_sofort_in_flagged_lexemes() -> void:
	if _lexeme_id.is_empty():
		return
	ContentRegistry.flag_lexeme(_lexeme_id, "Tippfehler", "learn.y")
	var ids: Array = []
	for entry in ContentRegistry.flagged_lexemes():
		ids.append(String(entry["id"]))
	assert_array(ids).contains([_lexeme_id])


func test_meldung_uebersteht_reload() -> void:
	if _lexeme_id.is_empty():
		return
	ContentRegistry.flag_lexeme(_lexeme_id, "Tippfehler", "learn.y")
	ContentRegistry.reload()
	var flag: Dictionary = ContentRegistry.lexemes[_lexeme_id].get("flag", {})
	assert_str(String(flag.get("comment", ""))).is_equal("Tippfehler")


func test_flag_lexeme_lehnt_unbekanntes_lexem_ab() -> void:
	assert_bool(ContentRegistry.flag_lexeme("lex.gibt.es.nicht", "x", "y")).is_false()
	assert_dict(LexemeFlags.load_all()).is_empty()


func test_unflag_lexeme_nimmt_zurueck() -> void:
	if _lexeme_id.is_empty():
		return
	ContentRegistry.flag_lexeme(_lexeme_id, "Tippfehler", "learn.y")
	assert_bool(ContentRegistry.unflag_lexeme(_lexeme_id)).is_true()
	assert_dict(LexemeFlags.load_all()).is_empty()
	assert_bool(ContentRegistry.lexemes[_lexeme_id].has("flag")).is_false()
	assert_bool(ContentRegistry.unflag_lexeme(_lexeme_id)).is_false()
