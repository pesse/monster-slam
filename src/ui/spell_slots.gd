class_name SpellSlots
extends GridContainer
## Der Zaubervorrat im Kampf-HUD, unten links (scenes/ui/spell_slots.tscn, ADR 0014): je
## Platz ein SpellSlot mit der Taste davor, zwei Spalten breit und nach oben wachsend —
## mit mehr Plätzen aus dem Fähigkeitsbaum werden es 2×3, 2×4.
##
## Liest nur `Inventory` und zeigt an; was eine Taste auslöst, entscheidet der WaveRunner.

const SLOT_SCENE := preload("res://scenes/ui/spell_slot.tscn")


func _ready() -> void:
	Inventory.changed.connect(refresh)
	refresh()


## Baut die Plätze nach dem Vorrat neu. Ihre Zahl ändert sich nur zwischen zwei Kämpfen
## (Fähigkeitsbaum); hier entsteht nur, was fehlt.
func refresh() -> void:
	var count := Inventory.slot_count()
	while get_child_count() > count:
		var last := get_child(get_child_count() - 1)
		remove_child(last)
		last.queue_free()
	while get_child_count() < count:
		add_child(SLOT_SCENE.instantiate())
	for i in count:
		(get_child(i) as SpellSlot).show_entry(Inventory.slot(i), i + 1)


func refuse(index: int) -> void:
	if index >= 0 and index < get_child_count():
		(get_child(index) as SpellSlot).refuse()


func pulse(index: int) -> void:
	if index >= 0 and index < get_child_count():
		(get_child(index) as SpellSlot).pulse()
