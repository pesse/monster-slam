class_name SpellCaster
extends RefCounted
## Was ein Zauber im Wellenkampf tut, ohne Bild (ADR 0014). `can_cast` fragt, ob er jetzt
## etwas bewirken würde, erst dann wird er verbraucht und `cast` gerufen. „Auf dem Feld“ ist
## die hereingegebene Liste, nicht das Blickfeld. Was für die ganze Welle gilt
## (`scope: wave`), bekommt jedes neue Monster über `on_spawn` bis `reset_wave`.

## Die Wirkungen, die es gibt — was in `effect` eines Zaubers stehen darf.
const EFFECTS := ["reveal_alts", "reveal_initial", "recall", "weaken", "block", "slow", "freeze", "strike", "heal", "armor"]

## Nimmt ein Monster per Blitz vom Feld (WaveRunner).
var strike: Callable
## Wann die Welle des Zaubers ein Monster erreicht (s): das Schild geht auf (Alternativen,
## erster Buchstabe), der Bumerang trägt es zurück. Ohne: sofort.
var reveal_delay := func(_monster: Monster) -> float: return 0.0
## Bumerang: wohin die Monster zurückfliegen (z der Startlinie) und wie schnell (m/s).
var start_z := -24.0
var back_speed := 40.0
## Tempo-Anteil für den Rest der Welle (1 = ungebremst).
var wave_pace := 1.0
## Zeigen alle Monster dieser Welle ihre Alternativen?
var wave_alts := false
## Anteil des Schadens für den Rest der Welle (Schrumpfpilz, 1 = voll).
var wave_damage := 1.0
## Knochenhaufen: so viele besiegte Monster hinterlassen noch einen, und so lange (s) hält
## er jedes, das hineinläuft.
var bones_left := 0
var bones_hold := 5.0
## Die liegenden Haufen: `at` (Position) und `held` (Instanz-Ids der schon aufgehaltenen).
var piles: Array[Dictionary] = []

## Ein Haufen hält ein Monster, das seitlich höchstens so weit (m) daneben läuft, so weit
## (m) vor seiner Mitte an: halbe Breite (BonePile, 1.6 m × SIZE) plus halbes Monster.
const PILE_REACH := 2.4
const PILE_STOP := 1.9


## Die Welle ist vorbei oder beginnt neu: was für sie galt, gilt nicht mehr.
func reset_wave() -> void:
	wave_pace = 1.0
	wave_alts = false
	wave_damage = 1.0
	bones_left = 0
	piles.clear()


## Ein Monster erscheint: es bekommt, was für die ganze Welle gewirkt wurde. Zurück kommen
## die Wirkungen, die es bekommen hat — für Bild und Ton (SpellFx.on_spawn).
func on_spawn(monster: Monster) -> PackedStringArray:
	var got := PackedStringArray()
	if wave_pace < 1.0 and monster.slow_to(wave_pace):
		got.append("slow")
	if wave_alts:
		monster.show_alts()
		got.append("reveal_alts")
	if wave_damage < 1.0 and monster.weaken(wave_damage):
		got.append("weaken")
	return got


## Würde `spell` jetzt etwas bewirken? `field` sind die Monster auf dem Feld, `to_come`
## die, die in dieser Welle noch erscheinen.
func can_cast(spell: Dictionary, field: Array[Monster], to_come: int) -> bool:
	var params: Dictionary = spell.get("params", {})
	var whole_wave := str(params.get("scope", "field")) == "wave" and to_come > 0
	match str(spell.get("effect", "")):
		"reveal_alts":
			if whole_wave and not wave_alts:
				return true
			for monster in field:
				if not monster.alts_shown and not monster.alts().is_empty():
					return true
			return false
		"reveal_initial":
			return field.any(func(monster: Monster) -> bool: return monster.can_show_initial())
		"recall":
			return field.any(func(monster: Monster) -> bool: return monster.can_send_back(start_z))
		"weaken":
			return float(params.get("share", 0.5)) < wave_damage \
					and (not field.is_empty() or to_come > 0)
		"block":
			return bones_left < int(params.get("count", 3)) and (not field.is_empty() or to_come > 0)
		"slow":
			var factor := float(params.get("factor", 0.5))
			if whole_wave and factor < wave_pace:
				return true
			for monster in field:
				if factor < monster.pace:
					return true
			return false
		"freeze", "strike":
			return not field.is_empty()
		"heal":
			return GameState.fortress_health > 0 \
					and GameState.fortress_health < GameState.fortress_max_health
		"armor":
			return GameState.fortress_health > 0 \
					and GameState.fortress_armor < GameState.fortress_armor_max
	return false


## Wirkt `spell` auf `field` (Aufrufer hat `can_cast` gefragt).
func cast(spell: Dictionary, field: Array[Monster], to_come: int) -> void:
	var params: Dictionary = spell.get("params", {})
	var whole_wave := str(params.get("scope", "field")) == "wave" and to_come > 0
	match str(spell.get("effect", "")):
		"reveal_alts":
			if whole_wave:
				wave_alts = true
			for monster in field:
				monster.show_alts(reveal_delay.call(monster))
		"reveal_initial":
			for monster in field:
				monster.show_initial(reveal_delay.call(monster))
		"recall":
			for monster in field:
				monster.send_back(start_z, reveal_delay.call(monster), back_speed)
		"weaken":
			wave_damage = float(params.get("share", 0.5))
			for monster in field:
				monster.weaken(wave_damage)
		"block":
			bones_left = int(params.get("count", 3))
			bones_hold = float(params.get("duration", 5.0))
		"slow":
			var factor := float(params.get("factor", 0.5))
			if whole_wave:
				wave_pace = minf(wave_pace, factor)
			for monster in field:
				monster.slow_to(factor)
		"freeze":
			for monster in field:
				monster.freeze(float(params.get("duration", 10.0)))
		"strike":
			# Eine Kopie: `strike` nimmt das Monster aus der Liste, über die hier läuft.
			for monster in field.duplicate():
				strike.call(monster)
		"heal":
			GameState.heal(int(params.get("amount", 25)))
		"armor":
			GameState.restore_armor(int(params.get("amount", 25)))


## Ein Monster ist bei `at` besiegt: hinterlässt es einen Knochenhaufen? Dann liegt er.
func leave_pile(at: Vector3) -> bool:
	if bones_left <= 0:
		return false
	bones_left -= 1
	piles.append({"at": Vector3(at.x, 0.0, at.z), "held": []})
	return true


## Hält jedes Monster aus `field` an, das gerade in einen Haufen läuft, einmal je Haufen.
## Zurück: je angehaltenem Monster `[monster, Index des Haufens]`, für Bild und Ton.
func block(field: Array[Monster]) -> Array:
	var stopped := []
	for i in piles.size():
		var pile := piles[i]
		var at: Vector3 = pile["at"]
		var held: Array = pile["held"]
		for monster in field:
			var dz := at.z - monster.position.z
			if dz <= 0.0 or dz > PILE_STOP or absf(monster.position.x - at.x) > PILE_REACH:
				continue
			if held.has(monster.get_instance_id()) or not monster.hold(bones_hold):
				continue
			held.append(monster.get_instance_id())
			stopped.append([monster, i])
	return stopped
