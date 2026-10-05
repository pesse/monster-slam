class_name SpellSlot
extends PanelContainer
## Ein Platz im Zaubervorrat (scenes/ui/spell_slot.tscn): Zeichen des Zaubers, Anzahl und
## die Taste, die ihn im Kampf auslöst. Kampf-HUD (SpellSlots) und Laden nutzen dieselbe
## Vorlage, damit ein Platz überall gleich aussieht. Hinweise hängt hier niemand an —
## im Kampf gibt es keine (CLAUDE.md), der Laden erklärt am Angebot.

## So schwach steht ein leerer Platz.
const EMPTY_ALPHA := 0.45
## So weit und so lange zittert ein Platz, dessen Zauber nichts bewirkt hätte.
const REFUSE_SHIFT := 6.0
const REFUSE_TIME := 0.3

@onready var _icon: Label = %Icon
@onready var _key: Label = %Key
@onready var _count: Label = %Count

var _tween: Tween


## Zeigt `entry` ({id, count} oder {}) auf der Taste `key` (0: keine Taste zeigen).
func show_entry(entry: Dictionary, key: int) -> void:
	var spell := ContentRegistry.get_entry("spells", str(entry.get("id", "")))
	var empty := entry.is_empty() or spell.is_empty()
	_icon.text = "" if empty else str(spell.get("icon", "?"))
	_count.text = "" if empty else "×%d" % int(entry.get("count", 0))
	_key.text = str(key) if key > 0 else ""
	self_modulate.a = EMPTY_ALPHA if empty else 1.0


## Der Zauber hätte nichts bewirkt: kurz seitwärts zittern.
func refuse() -> void:
	_restart()
	var rest := position
	for i in 4:
		_tween.tween_property(self, "position:x",
				rest.x + (REFUSE_SHIFT if i % 2 == 0 else -REFUSE_SHIFT), REFUSE_TIME / 5.0)
	_tween.tween_property(self, "position:x", rest.x, REFUSE_TIME / 5.0)


## Der Zauber hat gewirkt: kurz aufleuchten.
func pulse() -> void:
	_restart()
	modulate = Color(1.6, 1.5, 1.0)
	_tween.tween_property(self, "modulate", Color.WHITE, 0.35)


func _restart() -> void:
	if _tween != null and _tween.is_valid():
		_tween.custom_step(1000.0)
		_tween.kill()
	# Echte Zeit: in der Zeitlupe soll der Platz nicht mitschleichen.
	_tween = create_tween().set_ignore_time_scale(true)
