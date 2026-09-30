extends PanelContainer
## Wortart-Legende unter dem Antwortfeld, im Legendenstreifen. Das statische Layout liegt in
## word_type_legend.tscn (Rahmen, Ausrichtung, Abstand) und der Eintrags-Vorlage legend_entry.tscn.
## Hier wird nur der datengetriebene Teil erledigt: je Wortart einen Eintrag instanziieren
## und aus WordTypePalette befüllen (einzige Quelle für Farben & Namen), damit Legende und
## Monster-Outline immer denselben Farbcode zeigen.

const ENTRY_SCENE := preload("res://scenes/ui/legend_entry.tscn")


func _ready() -> void:
	for type in WordTypePalette.LABELS:
		var entry := ENTRY_SCENE.instantiate() as LegendEntry
		%Entries.add_child(entry)
		entry.setup(WordTypePalette.color_for(type), str(WordTypePalette.LABELS[type]))
