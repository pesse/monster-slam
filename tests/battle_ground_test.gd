extends GdUnitTestSuite
## Der Boden füllt das Bild — gerechnet, nicht angeschaut.
##
## Das Spielfeld sah aus, als schwebte es: der Boden war ein festes Rechteck von 22×45
## Einheiten, der Ausschnitt der Orthogonal-Kamera ist größer, und daneben stand die
## Hintergrundfarbe der Umgebung. Jetzt rechnet `WaveRunner.visible_ground_area()` den
## Boden aus der KAMERA, und diese Suite hält, dass er wirklich reicht.
##
## Geprüft wird an einer eigenen Kamera, die `WaveRunner.setup_view()` einrichtet — also
## an derselben Kamera wie im Kampf, aber ohne die Kampfszene: eine Welle zu fahren, um
## den Boden zu messen, hieße Autoloads, Inhalte und den Fortschritt des Spielers
## anzufassen.

const WaveRunnerScript := preload("res://src/battle/wave_runner.gd")

## Seitenverhältnisse, unter denen das Bild stehen kann: das Vollbild auf 16:9 ist der
## SCHMALSTE Fall (siehe CLAUDE.md), ein maximiertes Fenster ist breiter, und bis
## `VIEW_MAX_ASPECT` soll der Boden reichen.
const ASPECTS := [16.0 / 9.0, 1196.0 / 648.0, 2.0, WaveRunnerScript.VIEW_MAX_ASPECT]

var _camera: Camera3D


func before_test() -> void:
	var pivot := Node3D.new()
	_camera = Camera3D.new()
	var sun := DirectionalLight3D.new()
	pivot.add_child(_camera)
	add_child(auto_free(pivot))
	add_child(auto_free(sun))
	WaveRunnerScript.setup_view(pivot, _camera, sun)


## Alle Kachel-Ecken des gebauten Meshes, als x/z-Schlüssel auf dem Kachelraster.
func _tiles(mesh: ArrayMesh) -> Dictionary:
	var out := {}
	var step: float = WaveRunnerScript.TERRAIN_STEP
	for v: Vector3 in mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		out[Vector2i(int(floor(v.x / step)), int(floor(v.z / step)))] = true
	return out


## Welt-Punkt auf der Ebene y=0, den das Bild an der Stelle (u,v) zeigt.
func _ground_at(u: float, v: float) -> Vector3:
	var basis := _camera.global_transform.basis
	var p: Vector3 = _camera.global_position + basis.x * u + basis.y * v
	return p + (-basis.z) * (p.y / basis.z.y)


## Für JEDEN Punkt des Bildes liegt Boden unter dem Strahl. Geprüft wird über die Ebene
## y=0: trifft der Strahl sie innerhalb einer gebauten Kachel, dann trifft er unterwegs
## auch das Gelände — die Fläche ist zusammenhängend und steigt nirgends unter null.
func test_the_ground_covers_the_whole_view() -> void:
	var noise: FastNoiseLite = WaveRunnerScript.terrain_noise(4711)
	var mesh: ArrayMesh = WaveRunnerScript.build_terrain(_camera, noise)
	var tiles := _tiles(mesh)
	var step: float = WaveRunnerScript.TERRAIN_STEP
	var half_h: float = _camera.size * 0.5
	for aspect: float in ASPECTS:
		var half_w := half_h * aspect
		for iu in 41:
			for iv in 25:
				var u := lerpf(-half_w, half_w, iu / 40.0)
				var v := lerpf(-half_h, half_h, iv / 24.0)
				var hit := _ground_at(u, v)
				var key := Vector2i(int(floor(hit.x / step)), int(floor(hit.z / step)))
				assert_bool(tiles.has(key)).override_failure_message(
					"Kein Boden bei Bildpunkt (%.1f, %.1f) auf %.2f:1 — Welt (%.1f, %.1f)"
					% [u, v, aspect, hit.x, hit.z]).is_true()


## Das Innenfeld bleibt flach: die Monster laufen auf y=0, und ein Hügel unter der Bahn
## würde sie in den Boden oder darüber setzen. Das ist die Grenze der Erweiterung —
## gewachsen ist die Kulisse, nicht das Spielfeld.
func test_the_playfield_stays_flat() -> void:
	var noise: FastNoiseLite = WaveRunnerScript.terrain_noise(4711)
	var lane: float = WaveRunnerScript.LANE_HALF_WIDTH
	for i in 60:
		var x := lerpf(-lane, lane, i / 59.0)
		for j in 60:
			var z := lerpf(WaveRunnerScript.SPAWN_Z, WaveRunnerScript.GOAL_Z, j / 59.0)
			assert_float(WaveRunnerScript.terrain_height(x, z, noise)).is_equal(0.0)


## Der Boden ist Kulisse und kein zweites Spielfeld: er darf reichen, so weit er muss,
## aber das Mesh soll nicht unbemerkt ins Unbezahlbare wachsen. Das Sichtfeld ist eine
## Raute im x/z-Raster (45° Gierwinkel), ein gutes Drittel des umschließenden Rechtecks
## wird also aussortiert (gemessen: 1138 von 1980 Kacheln gebaut).
func test_the_ground_only_builds_what_can_be_seen() -> void:
	var noise: FastNoiseLite = WaveRunnerScript.terrain_noise(4711)
	var mesh: ArrayMesh = WaveRunnerScript.build_terrain(_camera, noise)
	var area: Rect2 = WaveRunnerScript.visible_ground_area(_camera)
	var step: float = WaveRunnerScript.TERRAIN_STEP
	var possible := int(area.size.x / step) * int(area.size.y / step)
	assert_int(_tiles(mesh).size()).is_less(possible * 2 / 3)


## Der Boden hängt an der KAMERA und nicht an Konstanten daneben: wer den Zoom ändert,
## soll nicht auch noch eine Terrain-Grenze nachziehen müssen — genau das Nachziehen
## war vergessen worden, und das Spielfeld schwebte.
func test_the_ground_follows_the_camera() -> void:
	var before: Rect2 = WaveRunnerScript.visible_ground_area(_camera)
	_camera.size *= 2.0
	var after: Rect2 = WaveRunnerScript.visible_ground_area(_camera)
	assert_float(after.size.x).is_greater(before.size.x)
	assert_float(after.size.y).is_greater(before.size.y)
