extends GdUnitTestSuite
## Die Bilder des Fähigkeitsbaums: jeder ausgelieferte Skill hat eins, und jedes lädt.
##
## Gelesen werden die Skills aus `data/skills/` und nicht aus der Registry: die trägt, was
## auf dem Rechner an Packs installiert ist. Fehlt einem neuen Skill das Bild, zeichnet
## der Graph zwar sein Zeichen — aber das soll eine Ausnahme für ältere Clients bleiben,
## kein Zustand der EXE.

const SKILLS_DIR := "res://data/skills/"


func _shipped_skill_ids() -> Array[String]:
	var out: Array[String] = []
	for file in DirAccess.get_files_at(SKILLS_DIR):
		if not file.ends_with(".json"):
			continue
		var parsed: Variant = JSON.parse_string(
				FileAccess.get_file_as_string(SKILLS_DIR + file))
		var entries: Array = parsed if parsed is Array else [parsed]
		for entry: Variant in entries:
			if entry is Dictionary and str(entry.get("kind", "")) == "skill":
				out.append(str(entry.get("id", "")))
	return out


func test_every_shipped_skill_has_a_picture() -> void:
	var ids := _shipped_skill_ids()
	assert_array(ids).is_not_empty()
	for id in ids:
		assert_bool(SkillIcons.has(id)).override_failure_message(
				"kein Eintrag in skill_icons.json: " + id).is_true()
		assert_object(SkillIcons.of(id)).override_failure_message(
				"Bild lädt nicht: " + id).is_not_null()


func test_an_unknown_skill_has_none() -> void:
	assert_object(SkillIcons.of("skill.zz.unknown")).is_null()


func test_the_frame_pictures_load() -> void:
	for texture: Texture2D in [SkillIcons.medallion(), SkillIcons.focus_ring(),
			SkillIcons.check(), SkillIcons.lock(), SkillIcons.skill_point()]:
		assert_object(texture).is_not_null()
