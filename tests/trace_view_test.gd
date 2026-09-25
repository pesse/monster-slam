extends GdUnitTestSuite
## Die Protokoll-Ansicht (TraceView): Reihenfolge, Tageszeilen, Zeitzone, und dass eine
## Antwort das Wort nennt, zu dem sie gehört.
##
## Reine Regeln ohne Datei und ohne Autoload — die Zeilen sind erfunden, im Format, das
## TraceLog schreibt (tests/trace_log_test.gd hält das Format selbst).

## 2026-09-23 12:00:00 UTC
const NOON := 1790164800

const SPAWN := {
	"at": NOON, "e": "spawn", "id": "translate:de_to_en:zz.lex.coral", "lex": "zz.lex.coral",
	"type": "translate", "dir": "de_to_en", "prompt": "Koralle", "answers": ["coral"],
	"conf": 0.3, "diff": 2,
}


func _answer(text: String, hit: bool, id := "", field := []) -> Dictionary:
	return {"at": NOON + 5, "e": "answer", "text": text, "hit": hit, "full": hit, "id": id,
			"rt": 2400, "field": field}


func _events(rows: Array) -> Array:
	return rows.filter(func(r): return r["kind"] == "event")


func test_the_newest_entry_comes_first_under_its_day() -> void:
	var rows := TraceView.rows([
		{"at": NOON, "e": "run_start"},
		{"at": NOON + 60, "e": "wave_start", "wave": "procedural_1", "hp": 100, "armor": 0},
	])
	assert_str(rows[0]["kind"]).is_equal("day")
	assert_str(rows[0]["text"]).is_equal("23.09.2026")
	assert_str(rows[1]["text"]).is_equal("⚑ Welle 1 beginnt · ❤ 100")
	assert_str(rows[1]["time"]).is_equal("12:01:00")
	assert_str(rows[2]["text"]).is_equal("▶ Lauf beginnt")


## Eine neue Tageszeile nur, wo der Tag wechselt — nicht vor jedem Eintrag.
func test_a_day_line_stands_before_each_day() -> void:
	var rows := TraceView.rows([
		{"at": NOON - 86400, "e": "run_start"},
		{"at": NOON, "e": "run_start"},
		{"at": NOON + 1, "e": "run_start"},
	])
	var kinds: Array = rows.map(func(r): return r["kind"])
	assert_array(kinds).is_equal(["day", "event", "event", "day", "event"])
	assert_str(rows[3]["text"]).is_equal("22.09.2026")


## Die Uhrzeit ist Ortszeit: 23:30 UTC ist in UTC+2 schon der nächste Tag.
func test_the_time_is_local() -> void:
	var rows := TraceView.rows([{"at": NOON + 11 * 3600 + 1800, "e": "run_start"}], 120)
	assert_str(rows[0]["text"]).is_equal("24.09.2026")
	assert_str(rows[1]["time"]).is_equal("01:30:00")


## Die answer-Zeile kennt nur die Id; das Wort kommt aus der spawn-Zeile davor.
func test_a_hit_names_the_word_it_belongs_to() -> void:
	var rows := _events(TraceView.rows([SPAWN, _answer("coral", true, SPAWN["id"])]))
	assert_str(rows[0]["text"]).is_equal("✔ „coral“ — Koralle")
	assert_str(rows[0]["hint"]["note"]).contains("2.4 s")
	assert_str(rows[1]["text"]).is_equal("Aufgabe: Koralle")
	assert_str(rows[1]["hint"]["body"]).is_equal("Lösung: coral")


## Die Falscheingabe zeigt in ihrer Karte, was auf dem Feld stand — dafür gibt es sie.
func test_a_miss_lists_the_field() -> void:
	var rows := _events(TraceView.rows([
		SPAWN, _answer("corall", false, "", [SPAWN["id"], "translate:en_to_de:zz.gone"]),
	]))
	var miss: Dictionary = rows[0]
	assert_str(miss["text"]).is_equal("✘ „corall“ passte auf keine Aufgabe")
	assert_str(miss["style"]).is_equal("Accent")
	assert_array(miss["hint"]["list"]).is_equal([
		["", "Koralle", "coral"],
		["", "translate:en_to_de:zz.gone", ""],
	])


func test_a_leak_stands_out() -> void:
	var rows := _events(TraceView.rows([{"at": NOON, "e": "leak", "id": SPAWN["id"],
			"prompt": "Koralle", "answers": ["coral"], "dmg": 10}]))
	assert_str(rows[0]["text"]).is_equal("💥 durchgelassen: Koralle → coral · −10 ❤")
	assert_str(rows[0]["style"]).is_equal("Accent")


func test_a_fast_resolve_says_how_much_was_skipped() -> void:
	var rows := _events(TraceView.rows([{"at": NOON, "e": "fast_resolve",
			"wave": "procedural_3", "unspawned": 4, "on_field": 2}]))
	assert_str(rows[0]["text"]).is_equal(
			"⏩ schnell aufgelöst · 2 unterwegs, 4 noch nicht erschienen")


## Meisterungen (Issue #23) nennen das Wort aus der spawn-Zeile, nicht nur die Id.
func test_a_mastery_names_its_word() -> void:
	var rows := _events(TraceView.rows([SPAWN,
			{"at": NOON + 6, "e": "mastered", "id": SPAWN["id"]},
			{"at": NOON + 6, "e": "word_mastered", "lex": SPAWN["lex"]}]))
	assert_str(rows[0]["text"]).is_equal("🏆 Wort gemeistert: Koralle")
	assert_str(rows[1]["text"]).is_equal("🏅 gemeistert: Koralle")


## Neue Ereignisarten kommen im Protokoll dazu; die Ansicht zeigt sie mit Namen, statt sie
## zu verschlucken.
func test_an_unknown_event_is_shown_by_its_name() -> void:
	var rows := _events(TraceView.rows([{"at": NOON, "e": "boss_roar"}]))
	assert_str(rows[0]["text"]).is_equal("· boss_roar")


## Die Stil-Namen sind Type-Variations im Theme. Ein Tippfehler dort wird von Godot still
## verschluckt — die Zeile sähe dann aus wie jede andere.
func test_the_styles_exist_in_the_theme() -> void:
	var theme: Theme = load("res://scenes/ui/ui_theme.tres")
	var rows := TraceView.rows([SPAWN, _answer("x", false),
			{"at": NOON, "e": "leak", "prompt": "", "answers": [], "dmg": 1},
			{"at": NOON, "e": "word_mastered", "lex": "zz.lex.x"}])
	for row in rows:
		var style := str(row["style"])
		if not style.is_empty():
			assert_bool(theme.get_type_variation_list(&"Label").has(StringName(style))) \
					.append_failure_message(style).is_true()
