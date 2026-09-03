extends GdUnitTestSuite
## Lernkurven-Control: Achsen-Maximum und Punktlage (Issue #7).
##
## Geprüft werden die statischen Rechnungen, nicht das Bild: was `_draw()` malt, lässt
## sich nicht sinnvoll behaupten, aber die Zahlen dahinter schon. Dazu einmal die Szene
## des Statistik-Screens, damit ein Tippfehler im Knotennamen der Kurve auffällt.

const CHART := preload("res://src/ui/stats_chart.gd")
const STATS_SCENE := preload("res://scenes/ui/stats_screen.tscn")

const PLOT := Rect2(Vector2(40.0, 10.0), Vector2(200.0, 100.0))


## Eine leere oder flache Reihe darf die Achse nicht auf 0 setzen — die Punktlage teilt
## durch das Maximum.
func test_axis_max_is_never_zero() -> void:
	assert_int(CHART.axis_max([])).is_equal(1)
	assert_int(CHART.axis_max([0, 0, 0])).is_equal(1)


## Kleine Zahlen bleiben genau, größere werden auf eine ablesbare Stufe aufgerundet.
func test_axis_max_rounds_up_to_a_readable_step() -> void:
	assert_int(CHART.axis_max([3, 1, 2])).is_equal(3)
	assert_int(CHART.axis_max([7])).is_equal(10)
	assert_int(CHART.axis_max([52])).is_equal(60)
	assert_int(CHART.axis_max([101])).is_equal(150)


func test_points_span_the_plot_from_left_to_right() -> void:
	var points := CHART.plot_points([0, 1, 2], PLOT, 2)
	assert_int(points.size()).is_equal(3)
	assert_float(points[0].x).is_equal_approx(PLOT.position.x, 0.01)
	assert_float(points[2].x).is_equal_approx(PLOT.end.x, 0.01)


## Y läuft nach unten: der Höchstwert sitzt oben, die Null auf der Grundlinie.
func test_the_highest_value_sits_at_the_top() -> void:
	var points := CHART.plot_points([0, 2], PLOT, 2)
	assert_float(points[0].y).is_equal_approx(PLOT.end.y, 0.01)
	assert_float(points[1].y).is_equal_approx(PLOT.position.y, 0.01)


## Eine flache Reihe liegt auf einer Höhe — und nicht auf der Grundlinie, wenn ihr Wert
## über null liegt. Genau das ist der Fall „alles vor dem Messbeginn gemeistert".
func test_a_flat_series_stays_on_one_level_above_the_baseline() -> void:
	var points := CHART.plot_points([4, 4, 4], PLOT, 4)
	assert_float(points[0].y).is_equal_approx(points[2].y, 0.01)
	assert_float(points[0].y).is_less(PLOT.end.y)


func test_a_single_value_and_an_empty_series_do_not_break() -> void:
	assert_int(CHART.plot_points([3], PLOT, 3).size()).is_equal(1)
	assert_int(CHART.plot_points([], PLOT, 3).size()).is_equal(0)


## Ein Control ohne Fläche (noch nicht ausgelegt) darf keine Punkte liefern.
func test_a_plot_without_area_yields_no_points() -> void:
	assert_int(CHART.plot_points([1, 2], Rect2(), 2).size()).is_equal(0)


func test_stats_scene_has_the_curve() -> void:
	var screen: Control = auto_free(STATS_SCENE.instantiate())
	add_child(screen)
	assert_object(screen.get_node("%Curve")).is_not_null()
	assert_object(screen.get_node("%CurveCaption")).is_not_null()
	# Die Bilanzzeile wird beim Betreten gefüllt und bleibt nicht leer.
	assert_str((screen.get_node("%CurveCaption") as Label).text).is_not_empty()
	remove_child(screen)
