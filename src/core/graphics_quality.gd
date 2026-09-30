class_name GraphicsQuality
extends RefCounted
## Wie aufwendig das Spiel zeichnet: „Schön" (Vorgabe) oder „Einfach" für schwache Rechner.
##
## Eine Stufe statt einzelner Schalter — wer ein Problem hat, dem hilft das Teure, und das
## deckt „Einfach" ab. Was sie weglässt, ist gemessen (`battle_theme_lab -- --fps`): Glow und
## MSAA kosten je 11–29 % der Bildzeit, Schatten 7–15 %, Wolken, Teilchen und Wind je 0–8 %.
## „Einfach" nimmt MSAA, Glow, Wolkenschatten und Teilchen weg; Schatten geben dem Bild die
## Tiefe und Wind kostet fast nichts — die bleiben.
##
## Die Stufe gehört dem Rechner, nicht dem Profil (UserSettings.graphics_simple). Hier
## stehen nur die Folgen; wer zeichnet, fragt hier und nicht in UserSettings.


static func simple() -> bool:
	return UserSettings.graphics_simple()


static func msaa(is_simple := simple()) -> Viewport.MSAA:
	return Viewport.MSAA_DISABLED if is_simple else Viewport.MSAA_4X


static func glow(is_simple := simple()) -> bool:
	return not is_simple


static func clouds(is_simple := simple()) -> bool:
	return not is_simple


static func particles(is_simple := simple()) -> bool:
	return not is_simple


## Kantenglättung des Fensters. Beim Start (UserSettings) und nach jedem Umschalten.
static func apply_window(root: Viewport, is_simple := simple()) -> void:
	root.msaa_3d = msaa(is_simple)


## Glow einer Szene abschalten, wenn die Stufe es will — auf einer KOPIE des Environments:
## das der Szene ist geladen und damit geteilt.
static func apply_environment(world: WorldEnvironment, is_simple := simple()) -> void:
	if world == null or world.environment == null or glow(is_simple):
		return
	var env := world.environment.duplicate() as Environment
	env.glow_enabled = false
	world.environment = env
