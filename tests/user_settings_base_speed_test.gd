extends GdUnitTestSuite
## Tests für die Grund-Geschwindigkeit (base_speed) in UserSettings. Nutzt ein Wegwerf-Profil,
## damit weder das aktive Profil noch dessen Einstellungen berührt werden (Getter/Setter
## akzeptieren einen expliziten Profil-Parameter).

const PROFILE := "__test_base_speed__"


## UserSettings persistiert in user://settings.cfg -> vor jedem Test auf Default zurücksetzen.
func before_test() -> void:
	UserSettings.set_base_speed(UserSettings.DEFAULT_BASE_SPEED, PROFILE)


func test_base_speed_default() -> void:
	# Frisches Profil (nie gesetzt) fällt auf den Default 1.0 zurück.
	assert_float(UserSettings.base_speed("__unset_profile__")).is_equal(UserSettings.DEFAULT_BASE_SPEED)


func test_base_speed_roundtrip() -> void:
	UserSettings.set_base_speed(1.25, PROFILE)
	assert_float(UserSettings.base_speed(PROFILE)).is_equal(1.25)


func test_base_speed_clamped_low() -> void:
	UserSettings.set_base_speed(0.1, PROFILE)
	assert_float(UserSettings.base_speed(PROFILE)).is_equal(UserSettings.MIN_BASE_SPEED)


func test_base_speed_clamped_high() -> void:
	UserSettings.set_base_speed(9.0, PROFILE)
	assert_float(UserSettings.base_speed(PROFILE)).is_equal(UserSettings.MAX_BASE_SPEED)


func test_base_speed_is_per_profile() -> void:
	UserSettings.set_base_speed(1.4, PROFILE)
	# Ein anderes Profil bleibt unberührt (Default 1.0).
	assert_float(UserSettings.base_speed("__other_profile__")).is_equal(UserSettings.DEFAULT_BASE_SPEED)
