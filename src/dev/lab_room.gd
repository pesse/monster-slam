class_name LabRoom
extends RefCounted
## Wie viel Platz eine Werkbank bekommt (scenes/dev/*).
##
## Das Spiel ist auf 1152×648 gebaut, und `canvas_items`/`expand` hält es dabei: ein
## größeres Fenster gibt NICHT mehr Platz, es macht das Bild größer. Wer eine überlaufende
## Werkbank durch Ziehen am Fensterrand retten will, zieht deshalb ins Leere.
##
## Für eine Werkbank ist diese Regel falsch herum. Sie hat kein Randlayout zu beweisen
## (dafür ist 1152 da, siehe CLAUDE.md „Das Vollbild ist der SCHMALSTE Fall"), sie stellt
## drei Spalten nebeneinander, und ihre Texte sind so lang, wie ein Modell sie macht.
##
## Gehoben wird deshalb ZWEIERLEI: das Fenster UND die Bezugsgröße der Skalierung
## (`Window.content_scale_size`). Nur das Fenster zu vergrößern hilft nicht — das Bild
## wüchse mit. Nur die Bezugsgröße zu heben auch nicht — dann würde alles kleiner. Erst
## beide zusammen geben mehr Raum bei gleicher Schriftgröße.
##
## Zurückgestellt wird beim Verlassen, und zwar in `_exit_tree()` der Werkbank: sie ist ein
## Gast im Fenster des Spiels. Es gibt in jeder Werkbank zwei Wege hinaus (Knopf und
## Escape) und dazu das Beenden — an einer Stelle zurückstellen ist eine, an dreien wäre es
## eine Frage der Zeit, bis einer vergessen wird.
##
## Liegt unter `src/dev/` und damit im `exclude_filter`: das ausgelieferte Spiel kennt
## diese Klasse nicht, und es soll sie auch nicht kennen.

## Der Platz einer Werkbank. 16:9 wie das Spiel — nicht weil `expand` das bräuchte, sondern
## damit ein Blick in die Werkbank nicht auch noch die Form des Fensters ändert.
const SIZE := Vector2i(1600, 900)


## Die Grundauflösung des Spiels — aus den Projekteinstellungen gelesen und nicht als
## zweite Konstante daneben gelegt.
static func game_size() -> Vector2i:
	return Vector2i(
			int(ProjectSettings.get_setting("display/window/size/viewport_width", 1152)),
			int(ProjectSettings.get_setting("display/window/size/viewport_height", 648)))


## Macht Platz.
static func enlarge(window: Window) -> void:
	_apply(window, fitting(window))


## Stellt das Fenster des Spiels wieder her.
static func restore(window: Window) -> void:
	_apply(window, game_size())


## Was von SIZE auf diesen Bildschirm passt — und nie weniger als das Spiel selbst. Ein
## Fenster, dessen untere Hälfte hinter der Taskleiste liegt, ist kein größeres Fenster;
## auf einem 1366×768-Laptop ist die Werkbank eben nur so groß, wie dort Platz ist.
static func fitting(window: Window) -> Vector2i:
	var usable := Vector2i.ZERO
	if window != null and is_instance_valid(window):
		usable = DisplayServer.screen_get_usable_rect(window.current_screen).size
	if usable.x <= 0 or usable.y <= 0:
		# Kopflos (und auf einem Bildschirm, den der DisplayServer nicht kennt) gibt es
		# nichts zu begrenzen. Der Wunsch gilt dann unverändert — sonst hinge die Größe der
		# Werkbank davon ab, ob gerade jemand zusieht.
		return SIZE
	var base := game_size()
	return Vector2i(
			clampi(SIZE.x, base.x, maxi(base.x, usable.x)),
			clampi(SIZE.y, base.y, maxi(base.y, usable.y)))


static func _apply(window: Window, size: Vector2i) -> void:
	if window == null or not is_instance_valid(window):
		return
	window.content_scale_size = size
	# Nur ein freies Fenster wird mitgezogen. Im Vollbild und im maximierten Fenster gibt es
	# nichts zu vergrößern — dort tut die Bezugsgröße allein schon, was sie soll.
	if window.mode != Window.MODE_WINDOWED:
		return
	window.size = size
	window.move_to_center()
