extends GdUnitTestSuite
## Musik-Regie (Autoload `Music`, ADR 0033). Geprüft wird die Auswahl, nicht der Ton:
## unter gdUnit4 spielt das Autoload nichts, und `assets/audio/music/` trägt nicht
## zwingend Stücke.

const BATTLE := MusicSet.Area.BATTLE
const BOSS := MusicSet.Area.BOSS


func _stream() -> AudioStream:
	return AudioStreamGenerator.new()


func test_the_scene_decides_the_area() -> void:
	assert_int(Music.area_for_scene("res://scenes/ui/profile_menu.tscn")).is_equal(MusicSet.Area.LOBBY)
	assert_int(Music.area_for_scene("res://scenes/ui/area_map.tscn")).is_equal(MusicSet.Area.LOBBY)
	assert_int(Music.area_for_scene(Music.BATTLE_SCENE)).is_equal(BATTLE)
	for path: String in Music.BOSS_SCENES:
		assert_int(Music.area_for_scene(path)).is_equal(BOSS)
	assert_int(Music.area_for_scene("res://scenes/dev/battle_theme_lab.tscn")).is_equal(MusicSet.Area.NONE)


func test_the_boss_scenes_exist() -> void:
	assert_bool(ResourceLoader.exists(Music.BATTLE_SCENE)).is_true()
	for path: String in Music.BOSS_SCENES:
		assert_bool(ResourceLoader.exists(path)).is_true()


func test_pick_avoids_the_last_track() -> void:
	var a := _stream()
	var b := _stream()
	var pool: Array[AudioStream] = [a, b]
	for i in 20:
		assert_object(Music.pick(pool, a)).is_same(b)
	var single: Array[AudioStream] = [a]
	assert_object(Music.pick(single, a)).is_same(a)
	assert_object(Music.pick([] as Array[AudioStream], a)).is_null()


func test_a_boss_with_its_own_tracks_gets_them() -> void:
	var music_set := MusicSet.new()
	var general := _stream()
	var own_a := _stream()
	var own_b := _stream()
	music_set.boss = [general]
	music_set.boss_tracks = {"boss.rambler": [own_a, own_b], "boss.empty": []}
	assert_array(music_set.tracks(BOSS, "boss.rambler")).contains_exactly([own_a, own_b])
	assert_array(music_set.tracks(BOSS, "boss.grammar_golem")).contains_exactly([general])
	assert_array(music_set.tracks(BOSS, "boss.empty")).contains_exactly([general])
	assert_array(music_set.tracks(BATTLE)).is_empty()


## Die Schlüssel in `boss_tracks` sind echte Boss-Ids; ein Tippfehler bliebe sonst still.
func test_boss_tracks_name_existing_bosses() -> void:
	for music_set in Music.sets():
		for boss_id: String in music_set.boss_tracks:
			assert_dict(ContentRegistry.get_entry("bosses", boss_id)) \
					.override_failure_message("Set '%s' nennt unbekannten Boss '%s'" % [music_set.id, boss_id]) \
					.is_not_empty()


func test_the_standard_set_exists_and_comes_first() -> void:
	var sets := Music.sets()
	assert_array(sets).is_not_empty()
	assert_str(String(sets[0].id)).is_equal(String(MusicSet.DEFAULT_ID))


func test_an_unknown_set_falls_back_to_the_standard() -> void:
	assert_str(String(Music.music_set(&"zz-gibt-es-nicht").id)).is_equal(String(MusicSet.DEFAULT_ID))
	assert_array(Music.tracks_for(BATTLE, "", &"zz-gibt-es-nicht")) \
			.is_equal(Music.tracks_for(BATTLE, "", MusicSet.DEFAULT_ID))


## Jedes Set liegt in einem Ordner, der wie seine Id heißt — so findet es das Profil.
func test_every_set_lives_in_its_own_folder() -> void:
	for music_set in Music.sets():
		assert_bool(ResourceLoader.exists(Music.MUSIC_DIR + String(music_set.id) + "/" + Music.SET_FILE)) \
				.override_failure_message("Set '%s' liegt nicht in seinem Ordner" % music_set.id).is_true()
		assert_str(music_set.title).is_not_empty()


func test_music_stays_silent_under_test() -> void:
	assert_bool(Music.enabled).is_false()
	assert_object(Music.current_stream()).is_null()


func test_the_music_bus_has_the_slow_motion_filter() -> void:
	var bus := AudioServer.get_bus_index(Sfx.BUS_MUSIC)
	assert_object(AudioServer.get_bus_effect(bus, 0)).is_instanceof(AudioEffectLowPassFilter)
