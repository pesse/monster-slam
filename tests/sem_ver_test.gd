extends GdUnitTestSuite
## Der Versionsvergleich trägt beide Update-Kanäle: er entscheidet, ob ein Update angeboten
## und ob ein Pack installiert wird. Beides sind Ja/Nein-Entscheidungen ohne Zwischenweg,
## deshalb hier auch die Randfälle.


func test_triple_liest_dreistellige_version() -> void:
	assert_array(SemVer.triple("1.2.3")).is_equal([1, 2, 3])


func test_triple_ignoriert_praefix_und_suffix() -> void:
	# Ein Release Candidate der verlangten Version soll die Schranke erfüllen.
	assert_array(SemVer.triple("v0.4.0-rc1")).is_equal([0, 4, 0])
	assert_array(SemVer.triple("0.4.0+build7")).is_equal([0, 4, 0])
	assert_array(SemVer.triple("0.4.0.2")).is_equal([0, 4, 0])


func test_triple_lehnt_unlesbares_ab() -> void:
	for bad in ["", "1.2", "1.2.x", "abc", "..", "1..3"]:
		assert_array(SemVer.triple(bad)).override_failure_message(
			"'%s' hätte nicht gelesen werden dürfen" % bad
		).is_empty()


func test_satisfies_min_vergleicht_stellenweise() -> void:
	assert_bool(SemVer.satisfies_min("0.2.0", "0.2.0")).is_true()
	assert_bool(SemVer.satisfies_min("0.10.0", "0.9.0")).is_true()
	assert_bool(SemVer.satisfies_min("1.0.0", "0.99.99")).is_true()
	assert_bool(SemVer.satisfies_min("0.2.0", "0.2.1")).is_false()
	assert_bool(SemVer.satisfies_min("0.9.0", "0.10.0")).is_false()


func test_satisfies_min_lehnt_unlesbares_ab() -> void:
	# Wer die Zahl nicht versteht, darf nicht annehmen, dass er sie erfüllt.
	assert_bool(SemVer.satisfies_min("keine Ahnung", "0.1.0")).is_false()
	assert_bool(SemVer.satisfies_min("9.9.9", "irgendwas")).is_false()


func test_too_old_for_ohne_angabe_keine_schranke() -> void:
	assert_bool(SemVer.too_old_for("", "0.5.0")).is_false()
	assert_bool(SemVer.too_old_for("0.1.0", "")).is_false()


func test_too_old_for_beide_richtungen() -> void:
	# App zu alt für den Inhalt.
	assert_bool(SemVer.too_old_for("0.2.0", "0.3.0")).is_true()
	# Inhalt zu alt für die App (installierte min_app_version gegen die des Index).
	assert_bool(SemVer.too_old_for("0.3.0", "0.2.0")).is_false()


func test_is_newer() -> void:
	assert_bool(SemVer.is_newer("0.3.0", "0.2.9")).is_true()
	assert_bool(SemVer.is_newer("0.2.9", "0.2.9")).is_false()
	assert_bool(SemVer.is_newer("0.2.8", "0.2.9")).is_false()
	# Ohne verlässliche Angabe wird kein Update angeboten.
	assert_bool(SemVer.is_newer("", "0.2.9")).is_false()
	assert_bool(SemVer.is_newer("neu", "0.2.9")).is_false()


func test_app_version_kommt_aus_den_projekteinstellungen() -> void:
	assert_array(SemVer.triple(SemVer.app_version())).override_failure_message(
		"config/version in project.godot ist keine dreistellige Version"
	).is_not_empty()
