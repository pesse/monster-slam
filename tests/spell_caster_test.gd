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


func _monster(alts: Array = []) -> Monster:
	var monster := MONSTER_SCENE.instantiate() as Monster
	monster.setup({}, {"prompt": "gehen", "prompt_alt": alts, "learnable_id": "zz.task"},
			1000.0, 20.0)
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
	for effect in ["freeze", "strike", "slow", "reveal_alts"]:
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
	_caster.on_spawn(later)
	assert_float(later.pace).is_equal(0.5)
	_caster.reset_wave()
	var next_wave := _monster()
	_caster.on_spawn(next_wave)
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
