extends PanelContainer
## Wortart-Legende unter dem Antwortfeld: je Wortart ein Eintrag, Farben und Namen aus
## `WordTypePalette` wie die Monster-Outline.

const ENTRY_SCENE := preload("res://scenes/ui/legend_entry.tscn")


func _ready() -> void:
	for type in WordTypePalette.LABELS:
		var entry := ENTRY_SCENE.instantiate() as LegendEntry
		%Entries.add_child(entry)
		entry.setup(WordTypePalette.color_for(type), str(WordTypePalette.LABELS[type]))
