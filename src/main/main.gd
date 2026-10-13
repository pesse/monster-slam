extends Node2D
## Script of scenes/main/main.tscn; prints what content was discovered. Not the main
## scene (that is profile_menu.tscn).


func _ready() -> void:
	print("=== Monster Slam ===")
	print("Content geladen:")
	print("  Vokabeln:    %d" % ContentRegistry.vocabulary.size())
	print("  Monster:     %d" % ContentRegistry.monsters.size())
	print("  Bosse:       %d" % ContentRegistry.bosses.size())
	print("  Zauber:      %d" % ContentRegistry.spells.size())
	print("  Skills:      %d" % ContentRegistry.skills.size())
	print("  Wellen:      %d" % ContentRegistry.waves.size())
