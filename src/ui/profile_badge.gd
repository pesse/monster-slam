class_name ProfileBadge
extends Control
## Wer spielt, oben rechts in Hauptmenü und Bibliothek (scenes/ui/profile_badge.tscn): das
## Medaillon aus assets/ui/player_badge/ — Avatar im Ring, außen die Erfahrung im Level als
## blauer Bogen, unten die Levelplakette, links Name und Gold, ganz links „Profil wechseln".
## Eine Szene für beide Screens, damit die Plakette überall gleich aussieht. In Statistik
## und Fähigkeiten steht sie nicht (README des Pakets).
##
## Rahmen und Bogen zeichnet `_draw`, alles darüber (Avatar, Levelplakette, Beschriftung,
## Knopf) liegt als Knoten in der Szene — Kinder werden nach dem Elternknoten gezeichnet,
## so bleibt die Plakette über dem Bogen. Maße sind die des Pakets (`layout.json`, Leinwand
## 1536 × 1024) mal `SCALE`, verschoben um `ORIGIN`: das Control deckt nur die sichtbare
## Silhouette, nicht den durchsichtigen Rand der Leinwand.
##
## Die Bilder liegen vorab verkleinert unter `player_badge/menu/` (`src/dev/shrink_image.gd`,
## Faktor so, dass sie bei 1920 × 1080 Pixel für Pixel stehen): die Leinwand des Pakets auf
## ein Fünftel zu zeichnen, ließ an den feinen Kanten Fragmente stehen. Neu erzeugen, wenn
## sich das Paket oder `SCALE` ändert.
##
## Was „Profil wechseln" tut, entscheidet der Screen (`switch_pressed`).

signal switch_pressed

const FRAME := preload("res://assets/ui/player_badge/menu/frame.webp")
const CANVAS := Vector2(1536, 1024)
const SCALE := 0.2
## Linke obere Ecke der Silhouette auf der Leinwand (gemessen am Render des Pakets; die
## `visible_bounds` in layout.json schneiden die Levelplakette ab).
const ORIGIN := Vector2(50, 160)
const RING_CENTER := Vector2(1133, 480)
const RING_RADIUS := 278.0
const RING_WIDTH := 34.0
const RING_COLOR := Color("43bafa")

@onready var _name_label: Label = %ProfileLabel
@onready var _gold_label: Label = %GoldLabel
@onready var _level_label: Label = %LevelLabel

var _ratio := 0.0


func _ready() -> void:
	(%SwitchButton as BaseButton).pressed.connect(switch_pressed.emit)
	Hints.attach(%SwitchButton as Control, "Profil wechseln", "zurück zu „Wer spielt?“")
	PlayerLevel.changed.connect(func(_total_xp, _level): refresh())
	Wallet.changed.connect(func(_gold): refresh())
	refresh()


## Liest Name, Gold und Erfahrung des aktiven Profils neu — nach einem Profilwechsel.
func refresh() -> void:
	_name_label.text = UserSettings.display_name()
	_gold_label.text = Wallet.digits()
	var progress := PlayerLevel.progress()
	var in_level := int(progress["xp_in_level"])
	var for_up := int(progress["xp_for_level_up"])
	var level := int(progress["level"])
	_level_label.text = str(level)
	_ratio = clampf(float(in_level) / float(maxi(for_up, 1)), 0.0, 1.0)
	Hints.attach(%Medallion as Control, "Level %d" % level, "%d / %d XP bis Level %d" % [
			in_level, for_up, level + 1])
	Hints.attach(%Plates as Control, UserSettings.display_name(), "", Wallet.label())
	queue_redraw()


## Ein Punkt der Leinwand im Control.
static func at(canvas_point: Vector2) -> Vector2:
	return (canvas_point - ORIGIN) * SCALE


func _draw() -> void:
	draw_texture_rect(FRAME, Rect2(at(Vector2.ZERO), CANVAS * SCALE), false)
	if _ratio > 0.0:
		# Von oben gegen den Uhrzeigersinn, wie im Entwurf.
		draw_arc(at(RING_CENTER), RING_RADIUS * SCALE, -PI / 2.0 - TAU * _ratio, -PI / 2.0,
				96, RING_COLOR, RING_WIDTH * SCALE, true)
