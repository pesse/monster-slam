extends GdUnitTestSuite
## Die Bilder der Zauber: jeder ausgelieferte Zauber hat eins, und jedes lädt. Gelesen wird
## aus `data/spells/`, nicht aus der Registry (siehe skill_icons_test.gd).

const SPELLS_DIR := "res://data/spells/"


func _shipped_spell_ids() -> Array[String]:
	var out: Array[String] = []
	for file in DirAccess.get_files_at(SPELLS_DIR):
		if not file.ends_with(".json"):
			continue
		var parsed: Variant = JSON.parse_string(
				FileAccess.get_file_as_string(SPELLS_DIR + file))
		var entries: Array = parsed if parsed is Array else [parsed]
		for entry: Variant in entries:
			if entry is Dictionary:
				out.append(str(entry.get("id", "")))
	return out


func test_every_shipped_spell_has_a_picture() -> void:
	var ids := _shipped_spell_ids()
	assert_array(ids).is_not_empty()
	for id in ids:
		assert_bool(SpellIcons.has(id)).override_failure_message(
				"kein Eintrag in spell_icons.json: " + id).is_true()
		assert_object(SpellIcons.of(id)).override_failure_message(
				"Bild lädt nicht: " + id).is_not_null()


func test_an_unknown_spell_has_none() -> void:
	assert_object(SpellIcons.of("spell.zz.unknown")).is_null()


func test_without_a_picture_the_glyph_shows() -> void:
	var picture := auto_free(TextureRect.new()) as TextureRect
	var glyph := auto_free(Label.new()) as Label
	SpellIcons.show({"id": "spell.zz.unknown", "icon": "★"}, picture, glyph)
	assert_bool(picture.visible).is_false()
	assert_str(glyph.text).is_equal("★")
	SpellIcons.show({"id": "spell.frost", "icon": "❄"}, picture, glyph)
	assert_bool(picture.visible).is_true()
	assert_bool(glyph.visible).is_false()
