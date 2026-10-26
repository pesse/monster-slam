class_name AchievementRow
extends PanelContainer
## Eine Karte im Reiter „Erfolge“ der Statistik, wie bei Steam: Bild, Name, Beschreibung,
## rechts der Zeitpunkt der Freischaltung; noch offen grau, mit Stand und Balken.

## Deckkraft der Schrift eines noch offenen Erfolgs.
const LOCKED_ALPHA := 0.6

@export var locked_material: Material


## `entry` wie Achievements.catalog (oder nur title/body/icon). `unlocked_at` (unix) steht
## rechts, 0 für noch offen. `progress` ist [erreicht, nötig]; der Balken kommt ab nötig 2.
func setup(entry: Dictionary, unlocked_at: int, progress: Array = [0, 0]) -> void:
	var unlocked := unlocked_at > 0
	var icon := %Icon as TextureRect
	icon.texture = Achievements.icon(entry)
	icon.material = null if unlocked else locked_material
	(%Name as Label).text = str(entry["title"])
	(%Detail as Label).text = str(entry["body"])
	(%State as Label).text = stamp(unlocked_at) if unlocked else ""
	var need := int(progress[1])
	(%Progress as Control).visible = not unlocked and need > 1
	(%Bar as ProgressBar).value = float(progress[0]) / float(maxi(1, need))
	(%Count as Label).text = "%d / %d" % [int(progress[0]), need]
	(%Text as Control).modulate.a = 1.0 if unlocked else LOCKED_ALPHA


## „Freigeschaltet“ mit Datum und Uhrzeit in Ortszeit.
static func stamp(unix: int) -> String:
	var bias := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var d := Time.get_datetime_dict_from_unix_time(unix + bias)
	return "Freigeschaltet\n%d.%d.%d, %02d:%02d" % [int(d["day"]), int(d["month"]), int(d["year"]),
			int(d["hour"]), int(d["minute"])]
