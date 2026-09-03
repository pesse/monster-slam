extends GdUnitTestSuite
## Wächter für die Theme-Disziplin: Abstände, Schriftgrößen und Textfarben stehen im
## Theme (scenes/ui/ui_theme.tres), nicht als `theme_override_…` in den Szenen und nicht
## als `add_theme_*_override` im Code.
##
## Der Grund für den Test: eine Konvention, die nur in der Dokumentation steht, hält
## nicht. Genau diese Overrides hatten sich einmal auf 14 Schriftgrößen und 12
## Abstandswerte summiert, und der Statistik-Screen sah entsprechend aus. Was das Theme
## kann, gehört ins Theme — für Rollen gibt es Type-Variations (`Title`, `SectionTitle`,
## `Hint`, `Caption`, `Accent`, `ScreenMargin`, `ScreenStack`, `SectionStack`, `Tight`).
##
## Was der Test NICHT prüft: `size_flags_*`, `custom_minimum_size` und Anchors sind
## Knoten-Eigenschaften und im Theme gar nicht abbildbar — die bleiben in der Szene.

const THEME_PATH := "res://scenes/ui/ui_theme.tres"

## Overrides, die eine Theme-Entsprechung haben und deshalb nicht in die Szene gehören.
const SCENE_FORBIDDEN := [
	"theme_override_font_sizes/",
	"theme_override_colors/font_color",
	"theme_override_constants/separation",
	"theme_override_constants/h_separation",
	"theme_override_constants/v_separation",
	"theme_override_constants/margin_",
]

const CODE_FORBIDDEN := [
	"add_theme_font_size_override",
	"add_theme_constant_override",
]

## Erlaubte Stufen der Abstands-Skala. Ein Abstand, der hier nicht steht, ist keine
## Entscheidung, sondern ein Zufall.
const SPACING_STEPS := [0, 4, 8, 16, 24]

## Ausnahmen mit Begründung. Die Kampf- und Effekt-Oberflächen haben eine eigene,
## bewusst lautere Typografie (Combo-Zahlen, Reveal-Karte, Monster-Beschriftung); sie
## sind noch nicht auf Variations umgestellt. Wer eine Zeile hier hinzufügt, schreibt
## den Grund dazu — sonst ist die Liste in einem Jahr die Regel.
const ALLOWED := {
	"res://scenes/battle/battle.tscn": "Kampf-HUD, eigene Effekt-Typografie",
	"res://scenes/ui/hud.tscn": "Kampf-HUD, eigene Abstände und HP-Balken-Style",
	"res://scenes/ui/leak_reveal.tscn": "Effekt-Overlay",
	"res://scenes/ui/legend_entry.tscn": "Effekt-Overlay, Textkontur",
	"res://scenes/ui/reveal_card.tscn": "Effekt-Overlay, Wortart-Farben",
	"res://scenes/ui/wave_stats.tscn": "Effekt-Overlay",
	"res://scenes/ui/word_type_legend.tscn": "Effekt-Overlay",
	"res://src/battle/wave_runner.gd": "Combo-Zahlen, zur Laufzeit skaliert",
	"res://src/ui/reveal_card.gd": "Wortart-Farbe kommt aus WordTypePalette, nicht aus dem Theme",
	"res://src/ui/wave_stats.gd": "Sieg/Niederlage-Farbe zur Laufzeit",
	"res://src/ui/settings_menu.gd": "separation 0 klebt Meldungs-Kopf und -Kommentar zusammen",
}


static func _collect(root: String, suffix: String, out: Array) -> void:
	var dir := DirAccess.open(root)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var path := root.path_join(entry)
		if dir.current_is_dir():
			_collect(path, suffix, out)
		elif entry.ends_with(suffix):
			out.append(path)
		entry = dir.get_next()
	dir.list_dir_end()
	out.sort()


## Sammelt die Fundstellen als „pfad:zeile: text" — die Meldung soll direkt sagen, wo
## nachzuarbeiten ist, nicht nur dass etwas nicht stimmt.
static func _offences(root: String, suffix: String, needles: Array) -> Array:
	var files: Array = []
	_collect(root, suffix, files)
	var found: Array = []
	for path in files:
		if ALLOWED.has(path):
			continue
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for i in lines.size():
			var line := str(lines[i]).strip_edges()
			for needle in needles:
				if line.begins_with(needle) or line.contains("." + str(needle)):
					found.append("%s:%d: %s" % [path, i + 1, line])
					break
	return found


func test_scenes_carry_no_spacing_or_typography_overrides() -> void:
	var found := _offences("res://scenes", ".tscn", SCENE_FORBIDDEN)
	assert_array(found).override_failure_message(
			"Diese Szenen setzen Abstände/Schriftgrößen selbst, statt eine Theme-Variation "
			+ "zu benutzen:\n  " + "\n  ".join(found)).is_empty()


func test_code_sets_no_spacing_or_font_sizes() -> void:
	var found := _offences("res://src", ".gd", CODE_FORBIDDEN)
	assert_array(found).override_failure_message(
			"Diese Stellen überschreiben Theme-Werte zur Laufzeit:\n  "
			+ "\n  ".join(found)).is_empty()


## Die Skala ist selbst geprüft, nicht nur eingehalten: ein Abstand im Theme, der keine
## Stufe der Skala ist, fällt hier auf — sonst wandert die Streuung aus den Szenen ins
## Theme.
func test_theme_spacing_uses_the_scale() -> void:
	var theme: Theme = load(THEME_PATH)
	var off: Array = []
	for type_name in theme.get_constant_type_list():
		for item in theme.get_constant_list(type_name):
			if not ("separation" in item or "margin" in item):
				continue
			var value := theme.get_constant(item, type_name)
			if not SPACING_STEPS.has(value):
				off.append("%s/%s = %d" % [type_name, item, value])
	assert_array(off).override_failure_message(
			"Abstände außerhalb der Skala %s:\n  %s" % [SPACING_STEPS, "\n  ".join(off)]
			).is_empty()


## Die Rollen, auf die die Screens sich verlassen. Ein Tippfehler im
## `theme_type_variation` einer Szene fällt sonst nirgends auf: Godot meldet nichts und
## der Knoten sieht einfach aus wie der Standard.
func test_theme_declares_the_role_variations() -> void:
	var theme: Theme = load(THEME_PATH)
	for role in ["Display", "Title", "SectionTitle", "Hint", "Caption", "Accent",
			"SectionButton", "ScreenMargin", "ScrollGutter", "ScreenStack", "SectionStack", "Tight"]:
		assert_str(theme.get_type_variation_base(role)).override_failure_message(
				"Variation fehlt im Theme: " + role).is_not_empty()


## Jede in einer Szene benutzte Variation muss es im Theme geben — die Gegenrichtung zum
## Test oben.
func test_scenes_reference_only_declared_variations() -> void:
	var theme: Theme = load(THEME_PATH)
	var declared := theme.get_type_variation_list("Label")
	declared.append_array(theme.get_type_variation_list("Button"))
	declared.append_array(theme.get_type_variation_list("MarginContainer"))
	declared.append_array(theme.get_type_variation_list("BoxContainer"))
	var files: Array = []
	_collect("res://scenes", ".tscn", files)
	var unknown: Array = []
	for path in files:
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for i in lines.size():
			var line := str(lines[i]).strip_edges()
			if not line.begins_with("theme_type_variation"):
				continue
			var role := line.get_slice("&\"", 1).trim_suffix("\"")
			if not declared.has(role):
				unknown.append("%s:%d: %s" % [path, i + 1, role])
	assert_array(unknown).override_failure_message(
			"Unbekannte Variation in einer Szene:\n  " + "\n  ".join(unknown)).is_empty()
