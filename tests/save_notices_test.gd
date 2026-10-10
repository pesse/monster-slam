extends GdUnitTestSuite
## SaveNotices (ADR 0024): jeder Hinweis des SaveCoordinator hat einen Text; nur ein
## gesperrtes Profil fragt.

const KINDS := ["restored", "blocked", "refused", "implausible", "settings_restored", "settings_rebuilt"]


func test_every_kind_has_a_text() -> void:
	for kind: String in KINDS:
		var text := SaveNotices.text({"kind": kind, "files": ["_level"], "backup_at": 1_760_100_000}, "Anna")
		assert_str(str(text.get("title", ""))).override_failure_message(kind).is_not_empty()
		assert_str(str(text.get("body", ""))).override_failure_message(kind).is_not_empty()
		assert_bool(str(text["keep"]).is_empty()).override_failure_message(kind).is_equal(kind != "blocked")


func test_restored_names_the_parts_and_the_profile() -> void:
	var body := str(SaveNotices.text({"kind": "restored", "files": ["_level", "_wallet", ""],
			"backup_at": 1_760_100_000}, "Anna")["body"])
	assert_str(body).contains("Anna").contains("Erfahrung, Gold und Lernstand")


func test_unknown_kind_is_empty() -> void:
	assert_dict(SaveNotices.text({"kind": "irgendwas"}, "Anna")).is_empty()
