class_name MusicSet
extends Resource
## Ein wählbares Musik-Set (ADR 0033): Stücke je Bereich, abgelegt als
## `assets/audio/music/<id>/set.tres`. Ein leerer Bereich nimmt die Stücke des
## Standard-Sets. Mehrere Stücke je Bereich wechseln sich ab; ein Stück mit Loop-Flag
## läuft, bis der Bereich wechselt.

## Wo gerade gespielt wird; NONE ist still (Werkbänke, Szenenwechsel in den Bosskampf).
enum Area { NONE, LOBBY, BATTLE, BOSS }

## Das Set, auf das jedes andere zurückfällt; ohne Stücke bleibt es still.
const DEFAULT_ID := &"standard"

## Gleich dem Ordnernamen; so steht das Set im Profil (`UserSettings.music_set`).
@export var id: StringName = &""
## Name in der Set-Auswahl der Einstellungen.
@export var title: String = ""
## Startmenü, Karte und alle anderen Menüs.
@export var lobby: Array[AudioStream] = []
@export var battle: Array[AudioStream] = []
## Bosskampf ohne eigenes Stück in [member boss_tracks].
@export var boss: Array[AudioStream] = []
## Boss-Id (das `id` in `data/bosses/*.json`, z. B. „boss.rambler“) → eigene Stücke, die
## sich abwechseln.
@export var boss_tracks: Dictionary[String, Array] = {}


## Die Stücke eines Bereichs; leer, wenn das Set dort nichts trägt.
func tracks(area: Area, boss_id := "") -> Array[AudioStream]:
	match area:
		Area.LOBBY:
			return lobby
		Area.BATTLE:
			return battle
		Area.BOSS:
			var own: Array[AudioStream] = []
			own.assign(boss_tracks.get(boss_id, []))
			return boss if own.is_empty() else own
	return []
