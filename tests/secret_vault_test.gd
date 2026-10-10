extends GdUnitTestSuite
## Der echte Schlüsselspeicher (SecretVault), nur unter Windows: DPAPI braucht keinen
## Dienst und hinterlässt nichts — der Block bleibt in diesem Test. Den macOS-Schlüsselbund
## fasst kein Test an, er gehört dem Konto.

const SECRET := "sk-ant-zz-vault-test-0123456789"


func test_dpapi_round_trip_without_plain_text() -> void:
	if OS.get_name() != "Windows":
		return
	var vault := SecretVault.new()
	var stored := vault.protect("zz-test", SECRET)
	assert_str(stored).is_not_empty()
	assert_bool(stored.contains(SECRET)).is_false()
	assert_str(vault.reveal("zz-test", stored)).is_equal(SECRET)
	assert_str(OS.get_environment(SecretVault.ENV)).is_empty()


func test_a_foreign_block_reveals_nothing() -> void:
	if OS.get_name() != "Windows":
		return
	assert_str(SecretVault.new().reveal("zz-test", Marshalls.utf8_to_base64("kein Block"))).is_empty()
