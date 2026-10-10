extends GdUnitTestSuite
## Der eigene API-Schlüssel (ADR 0023, §1): ohne Bestätigung wird nichts gespeichert, und
## ein Schlüssel ohne Bestätigung gilt als nicht da.
##
## Und: der Schlüssel steht nie im Klartext in der Datei.
##
## Auf einer eigenen Datei — `user://api_keys.cfg` gehört dem, der spielt — und mit einem
## erfundenen Speicher ohne Prozesse (den echten prüft tests/secret_vault_test.gd).

const TEST_PATH := "user://zz-api-keys-test.cfg"
const KEY := "sk-ant-zz-test-0000000000000000abcd"


## Ein Speicher, der „verschlüsselt“, indem er umdreht — so sieht man, dass die Datei den
## Schlüssel nicht im Klartext hat.
class FakeVault extends SecretVault:
	var works := true
	var reveals := 0

	func supported() -> bool:
		return works

	func protect(_name: String, secret: String) -> String:
		return "zz:" + secret.reverse() if works else ""

	func reveal(_name: String, stored: String) -> String:
		reveals += 1
		return stored.substr(3).reverse() if stored.begins_with("zz:") else ""

	func forget(_name: String, _stored: String) -> void:
		pass


var _vault: FakeVault


func before_test() -> void:
	ApiKeys.path = TEST_PATH
	_vault = FakeVault.new()
	ApiKeys.vault = _vault
	_remove()


func after_test() -> void:
	_remove()
	ApiKeys.path = ApiKeys.DEFAULT_PATH
	ApiKeys.vault = SecretVault.new()


func _remove() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(TEST_PATH)


func test_nothing_without_a_key() -> void:
	assert_str(ApiKeys.anthropic()).is_empty()
	assert_bool(ApiKeys.available()).is_false()
	assert_int(ApiKeys.confirmed_at()).is_equal(0)


func test_without_confirmation_nothing_is_stored() -> void:
	assert_bool(ApiKeys.store_anthropic(KEY, false)).is_false()
	assert_bool(FileAccess.file_exists(TEST_PATH)).is_false()
	assert_bool(ApiKeys.available()).is_false()


func test_confirmed_key_is_stored_with_its_time() -> void:
	var before := int(Time.get_unix_time_from_system())
	assert_bool(ApiKeys.store_anthropic("  %s \n" % KEY, true)).is_true()
	assert_str(ApiKeys.anthropic()).is_equal(KEY)
	assert_bool(ApiKeys.available()).is_true()
	assert_int(ApiKeys.confirmed_at()).is_greater_equal(before)


func test_a_rejected_attempt_keeps_the_old_key() -> void:
	ApiKeys.store_anthropic(KEY, true)
	assert_bool(ApiKeys.store_anthropic("sk-ant-other", false)).is_false()
	assert_bool(ApiKeys.store_anthropic("", true)).is_false()
	assert_bool(ApiKeys.store_anthropic("sk-ant with space", true)).is_false()
	assert_str(ApiKeys.anthropic()).is_equal(KEY)


func test_the_file_never_holds_the_key() -> void:
	ApiKeys.store_anthropic(KEY, true)
	assert_bool(FileAccess.get_file_as_string(TEST_PATH).contains(KEY)).is_false()
	assert_str(ApiKeys.shown()).is_equal(ApiKeys.masked(KEY))


func test_nothing_is_stored_without_a_vault() -> void:
	_vault.works = false
	assert_bool(ApiKeys.store_anthropic(KEY, true)).is_false()
	assert_bool(ApiKeys.available()).is_false()


func test_available_does_not_decrypt_and_the_key_is_decrypted_once() -> void:
	ApiKeys.store_anthropic(KEY, true)
	_vault.reveals = 0
	assert_bool(ApiKeys.available()).is_true()
	assert_int(_vault.reveals).is_equal(0)
	ApiKeys.anthropic()
	ApiKeys.anthropic()
	assert_int(_vault.reveals).is_equal(0)  # das Speichern hat ihn schon gemerkt


func test_a_plain_key_from_an_older_version_moves_into_the_vault() -> void:
	var config := ConfigFile.new()
	config.set_value(ApiKeys.SECTION, "key", KEY)
	config.set_value(ApiKeys.SECTION, "confirmed_at", 1791526650)
	config.save(TEST_PATH)
	assert_str(ApiKeys.anthropic()).is_equal(KEY)
	assert_int(ApiKeys.confirmed_at()).is_equal(1791526650)
	assert_bool(FileAccess.get_file_as_string(TEST_PATH).contains(KEY)).is_false()


func test_a_key_without_confirmation_in_the_file_does_not_count() -> void:
	var config := ConfigFile.new()
	config.set_value(ApiKeys.SECTION, "key", KEY)
	config.save(TEST_PATH)
	assert_str(ApiKeys.anthropic()).is_empty()
	assert_bool(ApiKeys.available()).is_false()
	assert_bool(FileAccess.get_file_as_string(TEST_PATH).contains(KEY)).is_false()


func test_clear_removes_key_and_confirmation() -> void:
	ApiKeys.store_anthropic(KEY, true)
	ApiKeys.clear()
	assert_bool(ApiKeys.available()).is_false()
	assert_int(ApiKeys.confirmed_at()).is_equal(0)
	assert_bool(FileAccess.file_exists(TEST_PATH)).is_false()


func test_masked_never_shows_the_middle() -> void:
	var shown := ApiKeys.masked(KEY)
	assert_str(shown).starts_with("sk-ant-")
	assert_str(shown).ends_with("abcd")
	assert_bool(shown.contains("0000")).is_false()
	assert_str(ApiKeys.masked("short")).is_equal("…")
	assert_str(ApiKeys.masked("")).is_empty()
