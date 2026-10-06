class_name LabRoom
extends RefCounted
## Wie viel Platz eine Werkbank bekommt (scenes/dev/*).
##
## Das Spiel rechnet seine Bezugsgröße aus dem Fenster und der Menügröße (UiScale): ein
## kleines Fenster gibt 1152×648, ein großes mehr — aber nur so viel, wie die Menügröße
## zulässt. Wer eine überlaufende Werkbank durch Ziehen am Fensterrand retten will, bekommt
## deshalb erst dann Platz, wenn das Fenster größer ist als Bezugsgröße mal Skala.
##
## Für eine Werkbank reicht das nicht. Sie hat kein Randlayout zu beweisen (dafür ist 1152
## da, siehe docs/CONVENTIONS.md „Das Vollbild ist der SCHMALSTE Fall"), sie stellt drei Spalten
## nebeneinander, und ihre Texte sind so lang, wie ein Modell sie macht.
##
## Gehoben wird deshalb ZWEIERLEI: das Fenster UND die Untergrenze der Bezugsgröße
## (`UiScale.floor_size`). Die Bezugsgröße selbst setzt nur `UiScale.apply` — schriebe die
## Werkbank sie direkt, nähme die nächste Größenänderung sie wieder weg.
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


## Die Grundauflösung des Spiels (UiScale).
static func game_size() -> Vector2i:
	return UiScale.game_size()


## Macht Platz.
static func enlarge(window: Window) -> void:
	_apply(window, fitting(window))


## Stellt das Fenster des Spiels wieder her.
static func restore(window: Window) -> void:
	_apply(window, Vector2i.ZERO)


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


## `size` ist die Untergrenze der Bezugsgröße; null gibt sie dem Spiel zurück.
static func _apply(window: Window, size: Vector2i) -> void:
	if window == null or not is_instance_valid(window):
		return
	UiScale.floor_size = size
	# Nur ein freies Fenster wird mitgezogen. Im Vollbild und im maximierten Fenster gibt es
	# nichts zu vergrößern — dort tut die Untergrenze allein schon, was sie soll.
	if window.mode == Window.MODE_WINDOWED:
		window.size = size if size != Vector2i.ZERO else game_size()
		window.move_to_center()
	UiScale.apply(window)
