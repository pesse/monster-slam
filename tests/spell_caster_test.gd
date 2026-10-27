extends GdUnitTestSuite
## Was Zauber im Wellenkampf tun (SpellCaster, Monster; ADR 0014) — ohne Welle: Monster
## stehen einzeln im Baum, GameState ist geteilter Zustand -> vorher und nachher reset().

const MONSTER_SCENE := preload("res://scenes/entities/monster.tscn")

var _caster: SpellCaster


func before_test() -> void:
	GameState.reset()
	_caster = SpellCaster.new()


func after_test() -> void:
	GameState.reset()


func _monster(alts: Array = [], task := {}) -> Monster:
	var monster := MONSTER_SCENE.instantiate() as Monster
	var data := {"prompt": "gehen", "prompt_alt": alts, "learnable_id": "zz.task"}
	data.merge(task, true)
	monster.setup({}, data, 1000.0, 20.0)
	add_child(monster)
	auto_free(monster)
	return monster


func _spell(effect: String, params := {}) -> Dictionary:
	return {"id": "zz.spell." + effect, "effect": effect, "params": params}


func _field(monsters: Array) -> Array[Monster]:
	var out: Array[Monster] = []
	out.assign(monsters)
	return out


## Jeder Zauber in den Daten hat, was Laden und Kampf brauchen, und eine bekannte Wirkung.
func test_every_spell_in_the_data_is_complete() -> void:
	var spells := ContentRegistry.all("spells")
	assert_array(spells).is_not_empty()
	for spell: Dictionary in spells:
		var id := str(spell.get("id", ""))
		assert_str(id).starts_with("spell.")
		for field in ["name", "icon", "description"]:
			assert_str(str(spell.get(field, ""))).append_failure_message(id + " " + field) \
					.is_not_empty()
		assert_array(SpellCaster.EFFECTS).append_failure_message(id) \
				.contains([str(spell.get("effect", ""))])
		assert_int(int(spell.get("price", 0))).append_failure_message(id).is_greater(0)
		assert_bool(spell.has("cooldown")).append_failure_message(id).is_false()


## Auf leerem Feld wirkt kein Feld-Zauber — und wird deshalb nicht verbraucht.
func test_field_spells_need_monsters() -> void:
	for effect in ["freeze", "strike", "slow", "reveal_alts", "reveal_initial", "recall", "block"]:
		assert_bool(_caster.can_cast(_spell(effect), _field([]), 0)) \
				.append_failure_message(effect).is_false()


func test_freezing_stops_a_monster_for_a_while() -> void:
	var monster := _monster()
	var start := monster.position.z
	_caster.cast(_spell("freeze", {"duration": 1.0}), _field([monster]), 0)
	assert_bool(monster.is_frozen()).is_true()
	assert_vector(monster.velocity()).is_equal(Vector3.ZERO)
	monster._physics_process(0.6)
	assert_float(monster.position.z).is_equal(start)
	monster._physics_process(0.6)
	assert_bool(monster.is_frozen()).is_false()
	monster._physics_process(1.0)
	assert_float(monster.position.z).is_greater(start)


## Zwei Bremsen multiplizieren sich nicht: es gilt die stärkere.
func test_slowing_takes_the_stronger_brake() -> void:
	var monster := _monster()
	var full := monster.velocity().z
	_caster.cast(_spell("slow", {"factor": 0.5}), _field([monster]), 0)
	assert_float(monster.velocity().z).is_equal_approx(full * 0.5, 0.0001)
	assert_bool(_caster.can_cast(_spell("slow", {"factor": 0.5}), _field([monster]), 0)).is_false()
	assert_bool(_caster.can_cast(_spell("slow", {"factor": 0.7}), _field([monster]), 0)).is_false()
	_caster.cast(_spell("slow", {"factor": 0.3}), _field([monster]), 0)
	assert_float(monster.velocity().z).is_equal_approx(full * 0.3, 0.0001)


## Für die ganze Welle heißt: auch was noch kommt — bis die Welle vorbei ist.
func test_a_wave_spell_reaches_later_monsters() -> void:
	var slow := _spell("slow", {"scope": "wave", "factor": 0.5})
	assert_bool(_caster.can_cast(slow, _field([]), 3)).is_true()
	_caster.cast(slow, _field([]), 3)
	var later := _monster(["walk"])
	# Was es bekommen hat, meldet on_spawn zurück — dafür spritzt und klingt es (SpellFx).
	assert_array(Array(_caster.on_spawn(later))).contains_exactly(["slow"])
	assert_float(later.pace).is_equal(0.5)
	_caster.reset_wave()
	var next_wave := _monster()
	assert_array(Array(_caster.on_spawn(next_wave))).is_empty()
	assert_float(next_wave.pace).is_equal(1.0)


## Ohne noch kommende Monster ist ein Wellen-Zauber ein Feld-Zauber.
func test_a_wave_spell_at_the_end_only_counts_the_field() -> void:
	assert_bool(_caster.can_cast(_spell("slow", {"scope": "wave"}), _field([]), 0)).is_false()


func test_alternatives_show_only_where_there_are_some() -> void:
	var plain := _monster()
	var rich := _monster(["walk", "run"])
	var reveal := _spell("reveal_alts")
	assert_bool(_caster.can_cast(reveal, _field([plain]), 0)).is_false()
	assert_bool(_caster.can_cast(reveal, _field([plain, rich]), 0)).is_true()
	_caster.cast(reveal, _field([plain, rich]), 0)
	assert_bool(rich.alts_shown).is_true()
	assert_bool(plain.alts_shown).is_false()
	assert_bool(_caster.can_cast(reveal, _field([plain, rich]), 0)).is_false()
	assert_str(WordPlate.alt_line(rich.alts())).is_equal("auch: walk, run")


## Die Flüstermuschel deckt nur auf, wo eine Lösung fehlt: nicht ohne Lösung, nicht neben der
## ganzen Lösung einer neuen Aufgabe (ADR 0027), nicht zweimal.
func test_the_first_letter_shows_where_the_answer_is_hidden() -> void:
	var plain := _monster([], {"accepted_answers": ["(to) go", "walk"]})
	var copied := _monster([], {"accepted_answers": ["go"], "help": true})
	var blank := _monster()
	var whisper := _spell("reveal_initial")
	assert_bool(_caster.can_cast(whisper, _field([copied, blank]), 0)).is_false()
	assert_bool(_caster.can_cast(whisper, _field([plain, copied, blank]), 0)).is_true()
	_caster.cast(whisper, _field([plain, copied, blank]), 0)
	assert_bool(plain.initial_shown).is_true()
	assert_bool(copied.initial_shown).is_false()
	assert_bool(blank.initial_shown).is_false()
	assert_str(WordPlate.initial_line(plain.initial())).is_equal("g…")
	assert_bool(_caster.can_cast(whisper, _field([plain, copied, blank]), 0)).is_false()


## Der Bumerang trägt ein Monster zurück an die Startlinie, wenn der Wind es erreicht; eins,
## das schon dort steht, bleibt, wo es ist.
func test_the_boomerang_carries_monsters_back_to_the_start() -> void:
	var near := _monster()
	near.position.z = 10.0
	var home := _monster()
	home.position.z = -23.0
	_caster.start_z = -24.0
	_caster.back_speed = 20.0
	_caster.reveal_delay = func(monster: Monster) -> float:
		return 0.5 if monster == near else 0.0
	var recall := _spell("recall")
	assert_bool(_caster.can_cast(recall, _field([home]), 0)).is_false()
	assert_bool(_caster.can_cast(recall, _field([home, near]), 0)).is_true()
	_caster.cast(recall, _field([home, near]), 0)
	assert_bool(home.is_flying_back()).is_false()
	# Bis der Wind es erreicht, läuft es weiter auf die Festung zu.
	near._physics_process(0.4)
	assert_float(near.position.z).is_greater(10.0)
	assert_bool(_caster.can_cast(recall, _field([home, near]), 0)).is_false()
	near._physics_process(0.2)
	assert_bool(near.is_flying_back()).is_true()
	assert_float(near.velocity().z).is_less(0.0)
	for i in 30:
		if near.is_flying_back():
			near._physics_process(0.1)
	assert_bool(near.is_flying_back()).is_false()
	assert_float(near.position.z).is_equal_approx(-24.0, 0.001)


## Der Schrumpfpilz halbiert den Schaden für das Feld und jedes neue Monster der Welle.
func test_the_mushroom_halves_damage_for_the_wave() -> void:
	var share := 0.5
	var shrink := _spell("weaken", {"share": share})
	var monster := _monster()
	monster.damage = 20
	assert_bool(_caster.can_cast(shrink, _field([]), 0)).is_false()
	assert_bool(_caster.can_cast(shrink, _field([]), 5)).is_true()
	_caster.cast(shrink, _field([monster]), 5)
	assert_int(monster.damage).is_equal(roundi(20 * share))
	assert_bool(_caster.can_cast(shrink, _field([monster]), 5)).is_false()
	var later := _monster()
	later.damage = 20
	assert_array(Array(_caster.on_spawn(later))).contains(["weaken"])
	assert_int(later.damage).is_equal(roundi(20 * share))
	# Ein zweites Mal rechnet vom vollen Schaden, nicht vom schon verringerten.
	assert_bool(monster.weaken(share)).is_false()
	assert_int(monster.damage).is_equal(roundi(20 * share))
	_caster.reset_wave()
	assert_array(Array(_caster.on_spawn(_monster()))).not_contains(["weaken"])


## Der Donnerschlag gibt jedes Monster auf dem Feld an den WaveRunner (`strike`).
func test_the_strike_hands_over_every_monster() -> void:
	var struck: Array = []
	var field := _field([_monster(), _monster()])
	_caster.strike = func(monster: Monster) -> void:
		struck.append(monster)
		field.erase(monster)
	_caster.cast(_spell("strike"), field, 0)
	assert_int(struck.size()).is_equal(2)


## Getroffen ist erledigt, sonst nichts: keine Punkte, keine Serie, kein Heilen.
func test_a_struck_monster_only_resolves() -> void:
	GameState.fortress_health = GameState.fortress_max_health - 5
	var health := GameState.fortress_health
	EventBus.monster_struck.emit({"learnable_id": "zz.task"})
	assert_int(GameState.wave_resolved).is_equal(1)
	assert_int(GameState.score).is_equal(0)
	assert_int(GameState.monsters_defeated).is_equal(0)
	assert_int(GameState.monsters_leaked).is_equal(0)
	assert_int(GameState.fortress_health).is_equal(health)


func test_healing_stops_at_the_maximum() -> void:
	var heal := _spell("heal", {"amount": 25})
	assert_bool(_caster.can_cast(heal, _field([]), 0)).is_false()
	GameState.fortress_health = GameState.fortress_max_health - 10
	assert_bool(_caster.can_cast(heal, _field([]), 0)).is_true()
	_caster.cast(heal, _field([]), 0)
	assert_int(GameState.fortress_health).is_equal(GameState.fortress_max_health)


func test_a_fallen_fortress_does_not_heal() -> void:
	GameState.fortress_health = 0
	assert_bool(_caster.can_cast(_spell("heal", {"amount": 25}), _field([]), 0)).is_false()
	assert_int(GameState.heal(25)).is_equal(0)


## Ohne Rüstung aus dem Bollwerk gibt es nichts zu schmieden.
func test_armor_needs_armor_to_restore() -> void:
	var armor := _spell("armor", {"amount": 25})
	assert_bool(_caster.can_cast(armor, _field([]), 0)).is_false()
	GameState.fortress_armor_max = 40
	GameState.fortress_armor = 30
	assert_bool(_caster.can_cast(armor, _field([]), 0)).is_true()
	_caster.cast(armor, _field([]), 0)
	assert_int(GameState.fortress_armor).is_equal(40)


func test_digits_pick_a_slot() -> void:
	var WaveRunner := load("res://src/battle/wave_runner.gd")
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_1
	assert_int(WaveRunner.spell_key(key)).is_equal(0)
	key.keycode = KEY_KP_4
	assert_int(WaveRunner.spell_key(key)).is_equal(3)
	key.keycode = KEY_A
	assert_int(WaveRunner.spell_key(key)).is_equal(-1)
	key.keycode = KEY_0
	assert_int(WaveRunner.spell_key(key)).is_equal(-1)
	key.keycode = KEY_2
	key.echo = true
	assert_int(WaveRunner.spell_key(key)).is_equal(-1)


## Der Knochenhaufen: die nächsten drei besiegten Monster hinterlassen einen Haufen; wer
## dahinter hineinläuft, steht fünf Sekunden und nur einmal je Haufen.
func test_bone_piles_hold_monsters_that_walk_into_them() -> void:
	var bones := _spell("block", {"count": 3, "duration": 5.0})
	assert_bool(_caster.can_cast(bones, _field([]), 0)).is_false()
	assert_bool(_caster.leave_pile(Vector3.ZERO)).is_false()
	assert_bool(_caster.can_cast(bones, _field([]), 4)).is_true()
	_caster.cast(bones, _field([]), 4)
	assert_bool(_caster.can_cast(bones, _field([]), 4)).is_false()
	for i in 3:
		assert_bool(_caster.leave_pile(Vector3(0.0, 0.0, 5.0 * i))).is_true()
	assert_bool(_caster.leave_pile(Vector3(0.0, 0.0, 20.0))).is_false()
	assert_int(_caster.piles.size()).is_equal(3)

	var walker := _monster()
	walker.position = Vector3(0.5, 0.0, -0.5)
	var aside := _monster()
	aside.position = Vector3(SpellCaster.PILE_REACH + 0.5, 0.0, -0.5)
	var past := _monster()
	past.position = Vector3(0.0, 0.0, 0.5)
	var hits := _caster.block(_field([walker, aside, past]))
	assert_int(hits.size()).is_equal(1)
	assert_object(hits[0][0]).is_same(walker)
	assert_int(hits[0][1]).is_equal(0)
	assert_bool(walker.is_held()).is_true()
	assert_bool(aside.is_held() or past.is_held()).is_false()
	assert_vector(walker.velocity()).is_equal(Vector3.ZERO)
	assert_float(walker.seconds_left()).is_greater(5.0)

	walker._physics_process(5.0)
	assert_bool(walker.is_held()).is_false()
	# Derselbe Haufen hält es kein zweites Mal.
	assert_array(_caster.block(_field([walker]))).is_empty()

	_caster.reset_wave()
	assert_array(_caster.piles).is_empty()
	assert_int(_caster.bones_left).is_equal(0)
