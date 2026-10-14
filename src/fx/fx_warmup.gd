class_name FxWarmup
extends RefCounted
## Zeigt beim Kampfstart hinter dem Schleier einmal alles, was sonst mitten im Kampf zum
## ersten Mal Shader übersetzen oder Zeichen rastern würde (CONVENTIONS „Fallen“). Ein
## Punktlicht zwingt auch Boden, Burg und Monster in eine zweite Variante. Übersetzt wird nur,
## was im Bild steht, deshalb liegt alles vor der Kamera.

## So viele Bilder bleibt alles stehen: eins für Shader und Schrift, eins für die ersten
## Partikel (sie erscheinen erst im Bild nach dem Ausstoß), der Rest ist Reserve.
const FRAMES := 4

const MONSTER_SCENE := preload("res://scenes/entities/monster.tscn")

## Die Zeichen, die ein Schild oder aufsteigender Text zeigen kann.
const GLYPHS := "ABCDEFGHIJKLMNOPQRSTUVWXYZÄÖÜ abcdefghijklmnopqrstuvwxyzäöüß 0123456789 +-.,:;!?'’…()/✓"

## Größe der Explosion: die größte im Kampf, damit ihr Licht jedes Material im Feld trifft.
const EXPLOSION_SCALE := 3.0


## Stellt `extras` und die Effekte bei `at` unter `parent` auf, wartet FRAMES Bilder und
## räumt wieder ab. `monster_defs`: die Monster-Definitionen, deren Modelle vorkommen können;
## `screen_sized`: ihre Schilder in fester Bildgröße wie in der Ich-Sicht.
static func run(parent: Node3D, at: Vector3, monster_defs: Array, extras: Array[Node3D] = [],
		screen_sized := false) -> void:
	var shown: Array[Node3D] = []
	var fx := Explosion.new()
	fx.setup(Color.WHITE, EXPLOSION_SCALE)
	fx.position = at
	parent.add_child(fx)
	for def in monster_defs:
		shown.append(_monster(parent, def, at, screen_sized, false))
		# Gemeistert: durchsichtige Materialien, eigene Shader-Variante.
		shown.append(_monster(parent, def, at, screen_sized, true))
	for node in extras:
		node.position = at
		parent.add_child(node)
		shown.append(node)
	await frames()
	# Die Explosion gibt sich selbst frei (sie wartet auf ihren Timer); nur ausblenden.
	if is_instance_valid(fx):
		fx.visible = false
	for node in shown:
		if is_instance_valid(node):
			node.queue_free()


## FRAMES Bilder abwarten (process_frame und nicht frame_post_draw: das kommt kopflos nicht
## verlässlich, und gezeichnet wird ohnehin am Ende jedes Bilds).
static func frames() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	for i in FRAMES:
		await tree.process_frame


## Die Monster-Definitionen mit Modell — jede Art, die ein Kampf zeigen kann.
static func monster_defs() -> Array:
	return ContentRegistry.all("monsters").filter(
			func(def: Dictionary) -> bool: return not str(def.get("model", "")).is_empty())


## Ein stehendes Monster aus derselben Szene wie im Kampf, ohne Tempo. Das Schild zeigt auch
## die Zeile der Alternativen (eigene Schriftgröße).
static func _monster(parent: Node3D, def: Dictionary, at: Vector3, screen_sized: bool,
		mastered: bool) -> Node3D:
	var monster := MONSTER_SCENE.instantiate() as Monster
	# Ziel weit hinter dem Monster, Tempo 0: es steht.
	monster.setup(def, {"prompt": GLYPHS, "prompt_alt": [GLYPHS]}, at.z + 1000.0, 0.0)
	monster.mastered = mastered
	monster.screen_sized_label = screen_sized
	monster.position = at
	parent.add_child(monster)
	monster.show_alts()
	return monster


## Ein Punkt im Bild der Kamera: `preferred`, wenn die Kamera ihn sieht, sonst 8 m vor ihr
## (Ich-Sicht).
static func point_in_view(camera: Camera3D, preferred: Vector3) -> Vector3:
	if camera == null or camera.is_position_in_frustum(preferred):
		return preferred
	return camera.global_position - camera.global_basis.z * 8.0
