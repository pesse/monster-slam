extends GdUnitTestSuite
## Die Bezugsgröße der Oberfläche wird aus Fenster und Menügröße gerechnet (UiScale,
## Issue #38). Geprüft wird die reine Rechnung — je Achse, weil `assert_vector(...)`
## lexikografisch vergleicht.

const LEAST := Vector2i(1152, 648)


## Ein großes Fenster gibt Platz statt größerer Menüs: 1920×1080 bei 125 % ist eine
## Bezugsgröße von 1536×864.
func test_a_large_window_gives_room_at_the_wanted_scale() -> void:
	var base := UiScale.base_size(Vector2i(1920, 1080), 1.25, LEAST)
	assert_int(base.x).is_equal(1536)
	assert_int(base.y).is_equal(864)


## Reicht das Fenster für die Skala nicht, bleibt 1152×648 — die Menüs werden kleiner,
## wie bisher, aber nie bekommt das Spiel weniger Platz.
func test_a_small_window_keeps_the_least_size() -> void:
	for window: Vector2i in [Vector2i(1152, 648), Vector2i(1280, 720), Vector2i(800, 450)]:
		var base := UiScale.base_size(window, 2.0, LEAST)
		assert_int(base.x).is_equal(1152)
		assert_int(base.y).is_equal(648)


## Ein anderes Seitenverhältnis: eine Achse liegt auf der Untergrenze, die andere wächst
## wie bei `expand`.
func test_the_other_axis_grows_like_expand() -> void:
	var tall := UiScale.base_size(Vector2i(1280, 800), 1.5, LEAST)
	assert_int(tall.x).is_equal(1152)
	assert_int(tall.y).is_equal(720)
	var wide := UiScale.base_size(Vector2i(2560, 1080), 1.5, LEAST)
	assert_int(wide.y).is_equal(720)
	assert_int(wide.x).is_greater(1152)


## Auch eine Skala unter 1 („Klein" auf einem Bildschirm ohne Systemskalierung) hält
## das Seitenverhältnis des Fensters.
func test_a_small_scale_follows_the_window() -> void:
	var base := UiScale.base_size(Vector2i(1920, 1080), 0.85, LEAST)
	assert_int(base.x).is_equal(2259)
	assert_int(base.y).is_equal(1271)


## Die Untergrenze einer Werkbank zählt wie die des Spiels.
func test_a_raised_floor_holds() -> void:
	var base := UiScale.base_size(Vector2i(1920, 1080), 1.5, Vector2i(1600, 900))
	assert_int(base.x).is_equal(1600)
	assert_int(base.y).is_equal(900)


## Ohne Fenster (kopflos, minimiert) gilt die Untergrenze.
func test_no_window_means_the_least_size() -> void:
	assert_int(UiScale.base_size(Vector2i.ZERO, 1.0, LEAST).x).is_equal(1152)
	assert_int(UiScale.base_size(Vector2i(1920, 1080), 0.0, LEAST).y).is_equal(648)


## Groß ist größer als Mittel ist größer als Klein — sonst stünden die Knöpfe verkehrt.
func test_the_sizes_are_ordered() -> void:
	assert_float(UiScale.FACTORS[UiScale.Size.SMALL]).is_less(UiScale.FACTORS[UiScale.Size.MEDIUM])
	assert_float(UiScale.FACTORS[UiScale.Size.MEDIUM]).is_less(UiScale.FACTORS[UiScale.Size.LARGE])
