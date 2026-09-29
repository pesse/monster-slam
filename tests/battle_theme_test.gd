extends GdUnitTestSuite
## Das Schlachtfeld steht in der Landschaft seiner Gebietskarte (BattleTheme).
##
## Geprüft werden die Zuordnung in map.json, die Farben des Bodens und dass das Thema die
## geteilten Ressourcen der Kampfszene nicht anfasst. Die Kampfszene selbst wird nicht
## gestartet — dafür braucht es Autoloads, Inhalte und den Fortschritt des Spielers.

const WaveRunnerScript := preload("res://src/battle/wave_runner.gd")
const BATTLE_SCENE := "res://scenes/battle/battle.tscn"
const EIGHT_BIT := 1.0 / 255.0


## Die Units, für die es ein Gebietsbild gibt, je Buch — aus den Bildern selbst gelesen,
## nicht aus den Inhalten: die Sprachdaten liegen im Submodule und fehlen in der CI.
func _units_with_image() -> Dictionary:
	var out := {}
	for book in DirAccess.get_directories_at(MapLayout.ROOT):
		# Nur Buchordner — daneben liegen die Werkzeuge (und ihr __pycache__).
		if not FileAccess.file_exists(MapLayout.json_path(book)):
			continue
		var units := {}
		for file in DirAccess.get_files_at(MapLayout.dir_of(book)):
			var base := file.get_basename()
			if base.begins_with("unit") and base.trim_prefix("unit").is_valid_int() \
					and not file.ends_with(".import") and not base.ends_with("-route"):
				units[int(base.trim_prefix("unit"))] = true
		out[book] = units.keys()
	return out


## Jede Unit mit Gebietskarte hat ein Thema, und es gibt die Datei dazu — auch jeder Stop
## mit eigenem Eintrag und jedes Thema, dessen Licht eines übernimmt. Ohne Eintrag stünde
## der Kampf still in der Vorgabe-Wiese — das fiele erst im Spiel auf.
func test_every_mapped_unit_names_an_existing_theme() -> void:
	var books := _units_with_image()
	assert_int(books.size()).is_greater(0)
	for book: String in books:
		var themes: Dictionary = MapLayout.data(book).get("themes", {})
		for unit: int in books[book]:
			var entry: Variant = themes.get(str(unit), "")
			var names: Array = (entry as Dictionary).values() if entry is Dictionary else [entry]
			assert_str(BattleTheme.name_for(book, unit)).override_failure_message(
				"%s/unit%d hat kein Thema in map.json" % [book, unit]).is_not_empty()
			for theme_name: String in names:
				_assert_theme_exists(theme_name, "%s/unit%d" % [book, unit])
				var light := (load("%s/%s.tres" % [BattleTheme.DIR, theme_name]) as BattleTheme).light_from
				if not light.is_empty():
					_assert_theme_exists(light, "%s/unit%d, Licht von %s" % [book, unit, theme_name])


func _assert_theme_exists(theme_name: String, where: String) -> void:
	assert_bool(ResourceLoader.exists("%s/%s.tres" % [BattleTheme.DIR, theme_name])) \
		.override_failure_message("%s: Thema '%s' fehlt" % [where, theme_name]).is_true()


## Jede Datei unter assets/battle_themes lädt als BattleTheme.
func test_every_theme_file_loads() -> void:
	var files := Array(DirAccess.get_files_at(BattleTheme.DIR)).filter(
			func(f: String) -> bool: return f.ends_with(".tres"))
	assert_int(files.size()).is_greater(0)
	for file: String in files:
		assert_object(load("%s/%s" % [BattleTheme.DIR, file]) as BattleTheme) \
			.override_failure_message("%s ist kein BattleTheme" % file).is_not_null()


## Ohne Level (Expertenmodus) und für eine Unit ohne Eintrag gilt die Vorgabe.
func test_without_a_level_the_default_applies() -> void:
	var fallback := BattleTheme.new()
	assert_that(BattleTheme.for_level({}).ground_low).is_equal(fallback.ground_low)
	assert_that(BattleTheme.for_unit("zz-kein-buch", 1).ground_low).is_equal(fallback.ground_low)


## Das Level aus der Karte wählt das Thema seiner Unit.
func test_a_level_picks_the_theme_of_its_unit() -> void:
	var books := _units_with_image()
	var book: String = books.keys()[0]
	var unit: int = books[book][0]
	var expected := BattleTheme.named(BattleTheme.name_for(book, unit))
	var picked := BattleTheme.for_level({"book": book, "unit": unit})
	assert_that(picked.ground_high).is_equal(expected.ground_high)


## Ein Stop mit eigenem Eintrag bekommt sein Thema, jeder andere das der Unit — ein Name
## statt eines Wörterbuchs gilt für alle Stops.
func test_a_stop_can_name_its_own_theme() -> void:
	var themes := {"1": {"default": "forest", "t2": "desert"}, "2": "canyon"}
	assert_str(BattleTheme.name_in(themes, 1, "t2")).is_equal("desert")
	assert_str(BattleTheme.name_in(themes, 1, "t1")).is_equal("forest")
	assert_str(BattleTheme.name_in(themes, 1)).is_equal("forest")
	assert_str(BattleTheme.name_in(themes, 2, "t2")).is_equal("canyon")
	assert_str(BattleTheme.name_in(themes, 3, "t2")).is_empty()


## Auf einer echten Karte wählt der Stop-Schlüssel des Levels das Thema seines Stops.
func test_a_level_on_a_stop_with_its_own_theme_picks_it() -> void:
	var found := false
	for book: String in _units_with_image():
		var themes: Dictionary = MapLayout.data(book).get("themes", {})
		for unit_key: String in themes:
			if not themes[unit_key] is Dictionary:
				continue
			for key: String in themes[unit_key]:
				if key == "default":
					continue
				found = true
				var level := {"book": book, "unit": int(unit_key), "key": key}
				assert_that(BattleTheme.for_level(level).ground_high) \
					.is_equal(BattleTheme.named(str(themes[unit_key][key])).ground_high)
	assert_bool(found).is_true()


## `light_from` nimmt Hintergrund, Umgebungslicht und Sonne vom anderen Thema, Boden und
## Deko bleiben die eigenen — und das geladene Thema im Cache bleibt, wie es war.
func test_light_from_takes_the_light_of_another_theme() -> void:
	var variant := _theme_files().filter(func(t: BattleTheme) -> bool: return not t.light_from.is_empty())
	assert_int(variant.size()).is_greater(0)
	var raw: BattleTheme = variant[0]
	var theme_name := raw.resource_path.get_file().get_basename()
	var raw_sun := raw.sun_color
	var light := BattleTheme.named(raw.light_from)
	var picked := BattleTheme.named(theme_name)
	assert_that(picked.sun_color).is_equal(light.sun_color)
	assert_that(picked.ambient).is_equal(light.ambient)
	assert_that(picked.background).is_equal(light.background)
	assert_that(picked.ground_low).is_equal(raw.ground_low)
	assert_array(picked.trees).is_equal(raw.trees)
	assert_that(raw.sun_color).is_equal(raw_sun)


## Das flache Innenfeld trägt nur Töne zwischen den beiden Bodenfarben des Themas —
## der Boden kommt wirklich aus dem Thema und nicht aus einer Konstante daneben.
func test_the_flat_field_uses_the_theme_ground_colors() -> void:
	var pivot := Node3D.new()
	var camera := Camera3D.new()
	var sun := DirectionalLight3D.new()
	pivot.add_child(camera)
	add_child(auto_free(pivot))
	add_child(auto_free(sun))
	WaveRunnerScript.setup_view(pivot, camera, sun)
	var theme := BattleTheme.new()
	theme.ground_low = Color(0.9, 0.1, 0.1)
	theme.ground_high = Color(0.9, 0.3, 0.1)
	var mesh: ArrayMesh = WaveRunnerScript.build_terrain(camera, WaveRunnerScript.terrain_noise(4711), theme)
	var arrays := mesh.surface_get_arrays(0)
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var flat := 0
	# Je drei Ecken ein Dreieck mit EINER Farbe; nur ganz flache Dreiecke zählen, ein
	# Dreieck am Hügelfuß kippt schon zur Hügelfarbe.
	for i in range(0, vertices.size(), 3):
		if vertices[i].y != 0.0 or vertices[i + 1].y != 0.0 or vertices[i + 2].y != 0.0:
			continue
		flat += 1
		# Vertexfarben liegen in 8 Bit vor: 0.9 kommt als 229/255 zurück.
		assert_float(colors[i].r).is_equal_approx(0.9, EIGHT_BIT)
		assert_float(colors[i].g).is_between(0.1 - EIGHT_BIT, 0.3 + EIGHT_BIT)
	assert_int(flat).is_greater(0)


## Kuppen über `peak_height` kippen in die Kuppenfarbe (Schnee), darunter nicht.
func test_peaks_turn_to_the_peak_color() -> void:
	var theme := BattleTheme.new()
	theme.peak = Color(1, 1, 1)
	theme.peak_height = 2.0
	assert_that(theme.ground_color(0.5, 2.0 + BattleTheme.PEAK_BLEND)).is_equal(Color(1, 1, 1))
	assert_float(theme.ground_color(0.5, 1.9).b).is_less(0.9)
	# Ohne Kuppenhöhe bleibt jede Höhe Boden- und Hügelfarbe.
	assert_float(BattleTheme.new().ground_color(0.5, 100.0).b).is_less(0.9)


## Flecken liegen auch in der Ebene, nur über der Schwelle, mit weichem Rand.
func test_patches_lie_only_above_their_threshold() -> void:
	var theme := BattleTheme.new()
	theme.peak = Color(1, 1, 1)
	theme.patches = 0.7
	var inside := 0.7 + BattleTheme.PATCH_BLEND
	var outside := 0.7 - BattleTheme.PATCH_BLEND
	assert_that(theme.ground_color(inside, 0.0)).is_equal(Color(1, 1, 1))
	assert_that(theme.ground_color(outside, 0.0)).is_equal(theme.ground_low.lerp(theme.ground_high, outside))
	# Dazwischen weich — kein Sprung, der als Kante im glatten Boden stünde.
	var mid := theme.ground_color(0.7, 0.0)
	assert_float(mid.b).is_between(theme.ground_color(outside, 0.0).b, 1.0)
	# Die Vorgabe hat keine: t reicht nur bis 1.
	assert_that(BattleTheme.new().ground_color(1.0, 0.0)).is_not_equal(BattleTheme.new().peak)


## Das Thema färbt eine KOPIE des Environments: das der Szene ist geteilt und käme sonst
## beim nächsten Kampf — auch im Expertenmodus — gefärbt wieder.
func test_applying_a_theme_leaves_the_scene_environment_alone() -> void:
	var scene := load(BATTLE_SCENE) as PackedScene
	var state := scene.get_state()
	var world := WorldEnvironment.new()
	var shared := _scene_environment(state)
	world.environment = shared
	var before := shared.background_color
	var sun := DirectionalLight3D.new()
	var theme := BattleTheme.new()
	theme.background = Color(1, 0, 1)
	theme.apply(world, sun)
	assert_that(world.environment.background_color).is_equal(Color(1, 0, 1))
	assert_that(shared.background_color).is_equal(before)
	world.free()
	sun.free()


func _scene_environment(state: SceneState) -> Environment:
	for i in state.get_node_count():
		if state.get_node_type(i) != &"WorldEnvironment":
			continue
		for p in state.get_node_property_count(i):
			if state.get_node_property_name(i, p) == &"environment":
				return state.get_node_property_value(i, p) as Environment
	return null


## Jedes Deko-Modell, das ein Thema nennt, gibt es. Ein Tippfehler fiele sonst nicht auf:
## der Kampf überspringt fehlende Modelle still, und das Feld stünde nur leerer da.
func test_every_decor_model_of_every_theme_exists() -> void:
	var themes: Array[BattleTheme] = [BattleTheme.new()]
	for file in DirAccess.get_files_at(BattleTheme.DIR):
		if file.ends_with(".tres"):
			themes.append(load("%s/%s" % [BattleTheme.DIR, file]) as BattleTheme)
	for theme in themes:
		assert_array(theme.trees).override_failure_message(
			"%s hat keine Bäume" % theme.resource_path).is_not_empty()
		for model in theme.decor_models():
			assert_bool(ResourceLoader.exists("%s/%s" % [BattleTheme.MODEL_DIR, model])) \
				.override_failure_message("%s: Modell '%s' fehlt" % [theme.resource_path, model]) \
				.is_true()


## Ohne Thema steht die Deko wie vor den Themen: Baum, Kiesel, Gras, Fass und Kisten.
func test_the_default_decor_is_the_old_look() -> void:
	var fallback := BattleTheme.new()
	assert_array(fallback.trees).contains_exactly(["props/tree.glb"])
	assert_array(fallback.rocks).contains_exactly(["props/rock.glb"])
	assert_array(fallback.grass).contains_exactly(["props/grass.glb"])
	assert_array(fallback.props).contains_exactly(["props/barrel_large.gltf", "props/crates_stacked.gltf"])
	assert_array(fallback.landmarks).is_empty()


## Die Themen aus assets/battle_themes, ohne die Vorgabe.
func _theme_files() -> Array[BattleTheme]:
	var out: Array[BattleTheme] = []
	for file in DirAccess.get_files_at(BattleTheme.DIR):
		if file.ends_with(".tres"):
			out.append(load("%s/%s" % [BattleTheme.DIR, file]) as BattleTheme)
	return out


## Jede Bodentextur, die ein Thema nennt, steht im Auftrag an den Bild-Agenten
## (assets/textures/ground/BRIEF.md) — sonst wartet das Thema auf eine Datei, die niemand
## malt, und ein Tippfehler fiele nie auf: ohne Datei bleibt der Boden still glatt.
func test_every_ground_texture_is_ordered_in_the_brief() -> void:
	var brief := FileAccess.get_file_as_string("%s/BRIEF.md" % BattleTheme.GROUND_TEXTURE_DIR)
	assert_str(brief).is_not_empty()
	for theme in _theme_files():
		if theme.ground_texture.is_empty():
			continue
		assert_bool(brief.contains("### `%s.png`" % theme.ground_texture)) \
			.override_failure_message("%s: Textur '%s' steht nicht im BRIEF.md" % [
				theme.resource_path, theme.ground_texture]).is_true()


## Ohne Textur (oder solange die Datei fehlt) bleibt der Boden glatt: derselbe Shader,
## aber ohne Detail.
func test_without_a_ground_texture_the_ground_stays_plain() -> void:
	var waiting := BattleTheme.new()
	waiting.ground_texture = "zz-gibt-es-nicht"
	for theme: BattleTheme in [BattleTheme.new(), waiting]:
		var mat := theme.ground_material() as ShaderMaterial
		assert_object(mat).is_not_null()
		assert_object(mat.get_shader_parameter("detail")).is_null()
		assert_float(mat.get_shader_parameter("strength")).is_equal(0.0)


## Der Shader beleuchtet den Boden mit dem Umgebungslicht des Themas — nicht mit einem
## eigenen, sonst stimmt die Farbe in der Sonne nicht mehr.
func test_the_ground_is_lit_with_the_theme_ambient() -> void:
	var theme := BattleTheme.new()
	theme.ambient = Color(0.4, 0.5, 0.6)
	theme.ambient_energy = 2.0
	var amb: Vector3 = (theme.ground_material() as ShaderMaterial).get_shader_parameter("ambient_light")
	var want := theme.ambient.srgb_to_linear() * 2.0
	assert_vector(amb).is_equal_approx(Vector3(want.r, want.g, want.b), Vector3.ONE * 0.001)


## Liegt die Textur da, trägt der Boden sie — mit Mipmaps, sonst flimmert er aus der Ferne.
func test_a_delivered_ground_texture_is_used_with_mipmaps() -> void:
	for theme in _theme_files():
		if theme.ground_texture.is_empty() or not ResourceLoader.exists(theme.ground_texture_path()):
			continue
		var mat := theme.ground_material() as ShaderMaterial
		assert_object(mat).override_failure_message(
			"%s: Textur liegt da, aber der Boden ist glatt" % theme.resource_path).is_not_null()
		var detail := mat.get_shader_parameter("detail") as Texture2D
		assert_bool(detail.get_image().has_mipmaps()).is_true()
