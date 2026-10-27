class_name SpellCaster
extends RefCounted
## Was ein Zauber im Wellenkampf tut, ohne Bild (ADR 0014). `can_cast` fragt, ob er jetzt
## etwas bewirken würde, erst dann wird er verbraucht und `cast` gerufen. „Auf dem Feld“ ist
## die hereingegebene Liste, nicht das Blickfeld. Was für die ganze Welle gilt
## (`scope: wave`), bekommt jedes neue Monster über `on_spawn` bis `reset_wave`.

## Die Wirkungen, die es gibt — was in `effect` eines Zaubers stehen darf.
const EFFECTS := ["reveal_alts", "reveal_initial", "slow", "freeze", "strike", "heal", "armor"]

## Nimmt ein Monster per Blitz vom Feld (WaveRunner).
var strike: Callable
## Nach wie vielen Sekunden das Schild eines Monsters aufgeht (Alternativen, erster
## Buchstabe). Ohne: sofort.
var reveal_delay := func(_monster: Monster) -> float: return 0.0
## Tempo-Anteil für den Rest der Welle (1 = ungebremst).
var wave_pace := 1.0
## Zeigen alle Monster dieser Welle ihre Alternativen?
var wave_alts := false


## Die Welle ist vorbei oder beginnt neu: was für sie galt, gilt nicht mehr.
func reset_wave() -> void:
	wave_pace = 1.0
	wave_alts = false


## Ein Monster erscheint: es bekommt, was für die ganze Welle gewirkt wurde. Zurück kommen
## die Wirkungen, die es bekommen hat — für Bild und Ton (SpellFx.on_spawn).
func on_spawn(monster: Monster) -> PackedStringArray:
	var got := PackedStringArray()
	if wave_pace < 1.0 and monster.slow_to(wave_pace):
		got.append("slow")
	if wave_alts:
		monster.show_alts()
		got.append("reveal_alts")
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
