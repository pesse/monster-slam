extends PanelContainer
## Einklappbares Debug-Panel (nur im Debug-Build sichtbar). Das Layout liegt in
## debug_panel.tscn; hier nur der Debug-Check und die Signal-Verdrahtung. Weitere
## Debug-Funktionen: in der Szene ergänzen und hier verbinden.

## Der Nutzer hat eine Festungsstufe (0..4) gewählt.
signal fortress_tier_selected(tier: int)
## Die Meister-Feier testweise zeigen (`word` = Wort-Feier statt Aufgaben-Feier).
signal celebration_requested(word: bool)
## Reihum eine Beispiel-Plakette zeigen (Badges.samples), ohne sie zu verdienen.
signal badge_requested()
## Das Aufleuchten des Level-Badges testweise zeigen, ohne Erfahrung zu verbuchen.
signal level_up_requested()

## So viele Spawns stehen im Protokoll, der neueste oben.
const PICK_LINES := 4

var _picks: Array[String] = []


func _ready() -> void:
	# Im veröffentlichten Build gibt es kein Debug-Panel.
	if not OS.is_debug_build():
		queue_free()
		return
	var body: VBoxContainer = $Root/Body
	($Root/Toggle as Button).toggled.connect(func(on: bool) -> void: body.visible = on)
	# Jeder Festung-Stufen-Button (0..4) setzt direkt seine Ausbaustufe.
	var row := $Root/Body/TierRow
	for tier in row.get_child_count():
		(row.get_child(tier) as Button).pressed.connect(_on_tier_pressed.bind(tier))
	($Root/Body/CelebrateRow/Task as Button).pressed.connect(celebration_requested.emit.bind(false))
	($Root/Body/CelebrateRow/Word as Button).pressed.connect(celebration_requested.emit.bind(true))
	($Root/Body/CelebrateRow/Level as Button).pressed.connect(level_up_requested.emit)
	($Root/Body/CelebrateRow/Badge as Button).pressed.connect(badge_requested.emit)
	EventBus.monster_spawned.connect(func(_monster, task): note_pick(task))


## Warum dieses Wort: eine Zeile je Spawn hier und in der Konsole. Die Spur schreibt den
## Grund ohnehin mit (TraceLog, Feld `why`), auch ohne Debug-Build.
func note_pick(task: Dictionary) -> void:
	var why := WaveGenerator.describe_reason(task.get("pick", {}),
			int(Time.get_unix_time_from_system()))
	if why.is_empty():
		return
	var line := "%s — %s" % [str(task.get("prompt", "")), why]
	print("Spawn: ", line, " [", str(task.get("learnable_id", "")), "]")
	_picks.push_front(line)
	_picks.resize(mini(_picks.size(), PICK_LINES))
	(%Picks as Label).text = "\n".join(_picks)


func _on_tier_pressed(tier: int) -> void:
	fortress_tier_selected.emit(tier)
