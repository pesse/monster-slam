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


func test_flag_lexeme_schreibt_nicht_in_die_quelldatei(do_skip := LanguageData.missing(), skip_reason := LanguageData.REASON) -> void:
	var source := ContentRegistry.source_file("lexemes", _lexeme_id)
	var before := FileAccess.get_file_as_string(source)
	assert_bool(ContentRegistry.flag_lexeme(_lexeme_id, "Tippfehler", "learn.y")).is_true()
	assert_str(FileAccess.get_file_as_string(source)).is_equal(before)
	assert_dict(LexemeFlags.load_all()).contains_keys([_lexeme_id])


func test_flag_lexeme_wirkt_sofort_in_flagged_lexemes(do_skip := LanguageData.missing(), skip_reason := LanguageData.REASON) -> void:
	ContentRegistry.flag_lexeme(_lexeme_id, "Tippfehler", "learn.y")
	var ids: Array = []
	for entry in ContentRegistry.flagged_lexemes():
		ids.append(String(entry["id"]))
	assert_array(ids).contains([_lexeme_id])


func test_meldung_uebersteht_reload(do_skip := LanguageData.missing(), skip_reason := LanguageData.REASON) -> void:
	ContentRegistry.flag_lexeme(_lexeme_id, "Tippfehler", "learn.y")
	ContentRegistry.reload()
	var flag: Dictionary = ContentRegistry.lexemes[_lexeme_id].get("flag", {})
	assert_str(String(flag.get("comment", ""))).is_equal("Tippfehler")


func test_flag_lexeme_lehnt_unbekanntes_lexem_ab() -> void:
	assert_bool(ContentRegistry.flag_lexeme("lex.gibt.es.nicht", "x", "y")).is_false()
	assert_dict(LexemeFlags.load_all()).is_empty()


func test_unflag_lexeme_nimmt_zurueck(do_skip := LanguageData.missing(), skip_reason := LanguageData.REASON) -> void:
	ContentRegistry.flag_lexeme(_lexeme_id, "Tippfehler", "learn.y")
	assert_bool(ContentRegistry.unflag_lexeme(_lexeme_id)).is_true()
	assert_dict(LexemeFlags.load_all()).is_empty()
	assert_bool(ContentRegistry.lexemes[_lexeme_id].has("flag")).is_false()
	assert_bool(ContentRegistry.unflag_lexeme(_lexeme_id)).is_false()


## --- Warteschlange des Rückkanals (siehe docs/adr/0002-melde-rueckkanal.md) ---

func test_neue_meldung_ist_offen() -> void:
	LexemeFlags.save_all({"lex.x": LexemeFlags.entry("falsch", "learn.x")})
	var open := LexemeFlags.pending()
	assert_int(open.size()).is_equal(1)
	assert_str(String(open[0]["lexeme_id"])).is_equal("lex.x")
	assert_str(String(open[0]["comment"])).is_equal("falsch")


## Meldungen aus einer Fassung vor dem Rückkanal haben kein Feld `sent` — sie sollen
## mitgehen, nicht stillschweigend verfallen.
func test_meldung_ohne_sent_feld_gilt_als_offen() -> void:
	LexemeFlags.save_all({"lex.alt": {"comment": "falsch", "learnable_id": "learn.x", "at": "2026-01-01T00:00:00"}})
	assert_int(LexemeFlags.pending().size()).is_equal(1)


func test_mark_sent_nimmt_aus_der_warteschlange() -> void:
	LexemeFlags.save_all({"lex.x": LexemeFlags.entry("falsch", "learn.x")})
	assert_bool(LexemeFlags.mark_sent("lex.x")).is_true()
	assert_array(LexemeFlags.pending()).is_empty()
	assert_bool(bool(LexemeFlags.load_all()["lex.x"]["sent"])).is_true()


func test_mark_sent_fuer_unbekannte_meldung_ist_false() -> void:
	assert_bool(LexemeFlags.mark_sent("lex.gibt.es.nicht")).is_false()


func test_mark_flag_sent_wirkt_sofort_in_der_anzeige(do_skip := LanguageData.missing(), skip_reason := LanguageData.REASON) -> void:
	ContentRegistry.flag_lexeme(_lexeme_id, "Tippfehler", "learn.y")
	assert_bool(ContentRegistry.mark_flag_sent(_lexeme_id)).is_true()
	assert_bool(bool(ContentRegistry.lexemes[_lexeme_id]["flag"]["sent"])).is_true()
	assert_array(LexemeFlags.pending()).is_empty()
