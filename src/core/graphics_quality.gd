class_name GraphicsQuality
extends RefCounted
## Wie aufwendig das Spiel zeichnet: „Schön" (Vorgabe), „Mittel" oder „Schnell" für schwache
## Rechner.
##
## Stufen statt einzelner Schalter — wer ein Problem hat, dem hilft das Teure, und das decken
## die Stufen ab. Was sie weglassen, ist gemessen (`battle_theme_lab -- --fps`): MSAA kostet
## 11–29 % der Bildzeit, Glow 11–15 %, Schatten 7–15 %, Weg und Bodenflecken um 14 %, Wolken,
## Teilchen, Wind und die Farbkorrektur je 0–8 %.
## - „Mittel" nimmt Glow weg und halbiert MSAA und die Büschel des Bewuchses (GroundCover).
## - „Schnell" nimmt dazu MSAA, Wolkenschatten, Teilchen, Bodenflecken, Büschel und die
##   Farbkorrektur (Kontrast, Sättigung) weg. Das Tonemapping bleibt, es kostet nichts.
## Schatten, Wind und der Weg zum Tor bleiben in jeder Stufe: Schatten geben dem Bild die
## Tiefe, Wind kostet fast nichts, und der Weg gehört zum Bildaufbau (BattlePath).
##
## Die Stufe gehört dem Rechner, nicht dem Profil (UserSettings.graphics_quality). Hier
## stehen nur die Folgen; wer zeichnet, fragt hier und nicht in UserSettings.

enum Level { FAST, MEDIUM, FINE }


static func level() -> Level:
	return UserSettings.graphics_quality()


static func msaa(at := level()) -> Viewport.MSAA:
	match at:
		Level.FINE:
			return Viewport.MSAA_4X
		Level.MEDIUM:
			return Viewport.MSAA_2X
	return Viewport.MSAA_DISABLED


static func glow(at := level()) -> bool:
	return at == Level.FINE


static func clouds(at := level()) -> bool:
	return at != Level.FAST


static func particles(at := level()) -> bool:
	return at != Level.FAST


## Flecken im dritten Bodenton (BattleTheme.ground_patch).
static func patches(at := level()) -> bool:
	return at != Level.FAST


## Dichte des Bewuchses (GroundCover), als Anteil der Büschel: „Mittel" die Hälfte,
## „Schnell" keine. Die Sträucher bleiben.
static func cover(at := level()) -> float:
	match at:
		Level.FINE:
			return 1.0
		Level.MEDIUM:
			return 0.5
	return 0.0


## Wie viele Feuer der Deko (Fire) ein Licht bekommen. Jedes Punktlicht zeichnet im
## Compatibility-Renderer alles noch einmal, was es trifft; die Flammen brennen in jeder
## Stufe, ohne Licht leuchten sie nur.
static func fire_lights(at := level()) -> int:
	match at:
		Level.FINE:
			return 6
		Level.MEDIUM:
			return 3
	return 0


## Kontrast und Sättigung des Environments (adjustment_*).
static func grading(at := level()) -> bool:
	return at != Level.FAST


## Kantenglättung des Fensters. Beim Start (UserSettings) und nach jedem Umschalten.
static func apply_window(root: Viewport, at := level()) -> void:
	root.msaa_3d = msaa(at)


## Glow und Farbkorrektur einer Szene abschalten, wenn die Stufe es will — auf einer KOPIE
## des Environments: das der Szene ist geladen und damit geteilt.
static func apply_environment(world: WorldEnvironment, at := level()) -> void:
	if world == null or world.environment == null or (glow(at) and grading(at)):
		return
	var env := world.environment.duplicate() as Environment
	env.glow_enabled = env.glow_enabled and glow(at)
	env.adjustment_enabled = env.adjustment_enabled and grading(at)
	world.environment = env
