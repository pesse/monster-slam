extends GdUnitTestSuite
## Monster machen mit der Wellenzahl mehr Schaden (Issue #51): die ersten zwei Wellen
## weniger als `base_damage`, Welle 3 genau `base_damage`, danach +15 % je Welle.
##
## Geprüft an der reinen Funktion WaveGenerator.wave_damage_scale() — keine Welle, kein
## Lernstand, keine Sprachdaten.

const GENERATOR := preload("res://src/battle/wave_generator.gd")


func test_curve_follows_the_agreed_factors() -> void:
	var expected := {1: 0.6, 2: 0.8, 3: 1.0, 4: 1.15, 5: 1.3, 6: 1.45, 10: 2.05}
	for wave in expected:
		assert_float(GENERATOR.wave_damage_scale(wave)) \
			.override_failure_message("Welle %d" % wave) \
			.is_equal_approx(expected[wave], 0.0001)


func test_wave_zero_or_below_counts_as_wave_one() -> void:
	assert_float(GENERATOR.wave_damage_scale(0)).is_equal_approx(0.6, 0.0001)
	assert_float(GENERATOR.wave_damage_scale(-3)).is_equal_approx(0.6, 0.0001)


func test_factor_grows_with_every_wave() -> void:
	for wave in range(1, 20):
		assert_float(GENERATOR.wave_damage_scale(wave + 1)) \
			.override_failure_message("Welle %d → %d" % [wave, wave + 1]) \
			.is_greater(GENERATOR.wave_damage_scale(wave))
