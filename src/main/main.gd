extends Node2D
## Entry point. Boots the game and reports what content was discovered.
## Replace the print block with the real game-loop / scene routing as systems land.


func _ready() -> void:
	print("=== Monster Slam ===")
	print("Content geladen:")
	print("  Vokabeln:    %d" % ContentRegistry.vocabulary.size())
	print("  Monster:     %d" % ContentRegistry.monsters.size())
	print("  Bosse:       %d" % ContentRegistry.bosses.size())
	print("  Zauber:      %d" % ContentRegistry.spells.size())
	print("  Skills:      %d" % ContentRegistry.skills.size())
	print("  Wellen:      %d" % ContentRegistry.waves.size())
