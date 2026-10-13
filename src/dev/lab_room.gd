class_name LabRoom
extends RefCounted
## Wie viel Platz eine Werkbank bekommt (docs/ARCHITECTURE.md „Werkbänke haben mehr Platz“).
## Gehoben werden Fenster und `UiScale.floor_size`; die Bezugsgröße selbst setzt nur
## `UiScale.apply`. Die Werkbank stellt in `_exit_tree()` zurück, das deckt jeden Ausgang ab.

## Der Platz einer Werkbank in px, 16:9 wie das Spiel.
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


## Was von SIZE in den nutzbaren Bereich des Bildschirms passt, nie weniger als das Spiel.
static func fitting(window: Window) -> Vector2i:
	var usable := Vector2i.ZERO
	if window != null and is_instance_valid(window):
		usable = DisplayServer.screen_get_usable_rect(window.current_screen).size
	if usable.x <= 0 or usable.y <= 0:
		# Kopflos oder unbekannter Bildschirm: SIZE unverändert, damit Tests nicht schwanken.
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
	# Nur ein freies Fenster wird mitgezogen; sonst wirkt die Untergrenze allein.
	if window.mode == Window.MODE_WINDOWED:
		window.size = size if size != Vector2i.ZERO else game_size()
		window.move_to_center()
	UiScale.apply(window)
