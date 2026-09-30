extends GdUnitTestSuite
## Welche Release-Notes der Update-Dialog zeigt, wenn mehrere Releases übersprungen wurden.


func _manifest() -> Dictionary:
	return {
		"version": "0.18.0",
		"notes": "N18",
		"history": [
			{ "version": "0.18.0", "notes": "N18" },
			{ "version": "0.16.1", "notes": "N161" },
			{ "version": "0.17.0", "notes": "N17" },
		],
	}


func test_alle_uebersprungenen_neuester_zuerst() -> void:
	var text := ReleaseNotes.compose(_manifest(), "0.16.1")
	assert_str(text).is_equal("## Version 0.18.0\n\nN18\n\n## Version 0.17.0\n\nN17")


func test_ein_release_ohne_ueberschrift() -> void:
	assert_str(ReleaseNotes.compose(_manifest(), "0.17.0")).is_equal("N18")


func test_luecke_vor_der_historie_verweist_auf_die_release_seite() -> void:
	var text := ReleaseNotes.compose(_manifest(), "0.10.0")
	assert_str(text).contains("## Version 0.16.1")
	assert_str(text).ends_with("[Release-Seite](%s)." % ReleaseNotes.RELEASES_URL)


func test_altes_manifest_ohne_historie() -> void:
	assert_str(ReleaseNotes.compose({ "notes": "nur das" }, "0.1.0")).is_equal("nur das")


func test_unbekannte_installierte_fassung_zeigt_nur_notes() -> void:
	assert_str(ReleaseNotes.compose(_manifest(), "")).is_equal("N18")
