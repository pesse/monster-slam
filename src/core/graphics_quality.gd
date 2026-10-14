class_name GraphicsQuality
extends RefCounted
## Grafikstufe „Schön“ (Vorgabe), „Mittel“ oder „Schnell“; was sie weglassen, steht in
## docs/ARCHITECTURE.md („Grafikstufen“), gemessen mit `battle_theme_lab -- --fps`.
## Die Stufe gilt je Rechner; wer zeichnet, fragt hier und nicht in UserSettings.

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


## Dichte des Bewuchses (GroundCover) als Anteil der Büschel; Sträucher bleiben.
static func cover(at := level()) -> float:
	match at:
		Level.FINE:
			return 1.0
		Level.MEDIUM:
			return 0.5
	return 0.0


## Wie viele Feuer der Deko (Fire) ein Licht bekommen. Jedes Punktlicht zeichnet im
## Compatibility-Renderer alles, was es trifft, noch einmal.
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


## Kantenglättung des Fensters.
static func apply_window(root: Viewport, at := level()) -> void:
	root.msaa_3d = msaa(at)


## Schaltet Glow und Farbkorrektur nach Stufe ab, auf einer Kopie des (geteilten)
## Environments.
static func apply_environment(world: WorldEnvironment, at := level()) -> void:
	if world == null or world.environment == null or (glow(at) and grading(at)):
		return
	var env := world.environment.duplicate() as Environment
	env.glow_enabled = env.glow_enabled and glow(at)
	env.adjustment_enabled = env.adjustment_enabled and grading(at)
	world.environment = env
