class_name UiScale
extends RefCounted
## Wie groß die Oberfläche auf dem Bildschirm steht: „Klein", „Mittel" (Vorgabe) oder
## „Groß" (Issue #38, ADR 0017).
##
## Die Skalierung bleibt `canvas_items`/`expand`, aber die Bezugsgröße
## (`Window.content_scale_size`) ist nicht mehr fest 1152×648, sondern wird aus dem Fenster
## gerechnet: Fenster ÷ gewünschte Skala. Ein großes Fenster gibt damit mehr Platz statt
## größerer Menüs; die 3D-Welt rendert ohnehin in Fensterauflösung und ist nicht betroffen.
##
## Die gewünschte Skala ist die Skalierung des Betriebssystems mal die Stufe — „Mittel"
## heißt: so groß, wie der Rechner seine eigenen Fenster zeichnet. Dadurch wirken die
## Menüs auf jedem Bildschirm etwa gleich groß, ohne dass eine Vorgabe gespeichert wird.
##
## 1152×648 bleibt die kleinste Bezugsgröße (`game_size()`): wird das Fenster dafür zu
## klein, sinkt die Skala, wie bisher. Mehr Platz gibt es nur nach oben; das Vollbild auf
## 16:9 bei kleiner Skala ist weiterhin der schmalste Fall, den die Layout-Tests prüfen.
##
## Die Bezugsgröße setzt nur `apply()` — beim Start und nach jeder Größenänderung
## (UserSettings). Eine Werkbank, die mehr Platz braucht, hebt die Untergrenze (`floor_size`,
## LabRoom), statt die Bezugsgröße selbst zu schreiben.

enum Size { SMALL, MEDIUM, LARGE }

## Faktor je Stufe auf die Skalierung des Betriebssystems.
const FACTORS := {
	Size.SMALL: 0.85,
	Size.MEDIUM: 1.0,
	Size.LARGE: 1.2,
}
## Was der DisplayServer als Systemskalierung meldet, wird hierauf begrenzt — unter Linux
## ist `screen_get_dpi` die physische Dichte und kann daneben liegen.
const OS_SCALE_MIN := 1.0
const OS_SCALE_MAX := 4.0

## Untergrenze der Bezugsgröße über der des Spiels (Werkbänke). Null heißt: `game_size()`.
static var floor_size := Vector2i.ZERO


static func level() -> Size:
	return UserSettings.ui_size()


## Die Grundauflösung des Spiels — aus den Projekteinstellungen gelesen und nicht als
## zweite Konstante daneben gelegt.
static func game_size() -> Vector2i:
	return Vector2i(
			int(ProjectSettings.get_setting("display/window/size/viewport_width", 1152)),
			int(ProjectSettings.get_setting("display/window/size/viewport_height", 648)))


## Die Bezugsgröße zu einem Fenster: Fenster ÷ Skala, aber je Achse nie unter `least`.
## Reicht das Fenster für `factor` nicht, gilt die größte Skala, bei der `least` noch
## hineinpasst — die übrige Achse wächst wie bei `expand`.
static func base_size(window_size: Vector2i, factor: float, least := game_size()) -> Vector2i:
	if window_size.x <= 0 or window_size.y <= 0 or factor <= 0.0:
		return least
	var fit := minf(float(window_size.x) / least.x, float(window_size.y) / least.y)
	var s := minf(factor, fit)
	var base := (Vector2(window_size) / s).round()
	return Vector2i(base).max(least)


## Skalierung des Betriebssystems für den Bildschirm des Fensters. Unter Windows meldet
## `screen_get_dpi` die wirksame DPI (150 % → 144), unter macOS `screen_get_scale` den
## Retina-Faktor; kopflos ist beides 1.
static func os_scale(window: Window) -> float:
	var screen := window.current_screen if window != null else DisplayServer.SCREEN_OF_MAIN_WINDOW
	var os := DisplayServer.screen_get_scale(screen)
	if OS.get_name() != "macOS":
		os = DisplayServer.screen_get_dpi(screen) / 96.0
	return clampf(os, OS_SCALE_MIN, OS_SCALE_MAX)


## Die gewünschte Skala: System mal Stufe.
static func desired_scale(window: Window, at := level()) -> float:
	return os_scale(window) * float(FACTORS[at])


## Setzt die Bezugsgröße des Fensters. Beim Start (UserSettings), nach jeder Änderung der
## Fenstergröße und nach dem Umschalten der Stufe.
static func apply(window: Window, at := level()) -> void:
	if window == null or not is_instance_valid(window):
		return
	var least := game_size().max(floor_size)
	var base := least
	# Kopflos ist das Fenster 100×100 und gibt kein Maß — Tests und CI rechnen weiter mit
	# der Untergrenze, wie vor der Menügröße.
	if DisplayServer.get_name() != "headless":
		base = base_size(window.size, desired_scale(window, at), least)
	# Unverändert nicht neu setzen: das Setzen löst selbst eine Größenänderung aus.
	if window.content_scale_size != base:
		window.content_scale_size = base
