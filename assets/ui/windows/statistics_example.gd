extends Control
## Standalone UI example. Screenshot values are fixtures, never player data.

const BASE := "res://assets/ui/windows/"
const GOLD := Color("f4cd73")
const TEXT := Color("e6eaf3")
const MUTED := Color("aeb9ce")
var body: VBoxContainer
var metrics: GridContainer
var title: Label
var scroll: ScrollContainer
var active_tab := "Überblick"
var tabs: Array[Button] = []
var debug_values: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var ui_theme := Theme.new()
	ui_theme.default_font_size = 18
	ui_theme.set_color("font_color", "Label", TEXT)
	ui_theme.set_color("font_color", "Button", TEXT)
	ui_theme.set_color("font_hover_color", "Button", GOLD)
	ui_theme.set_color("font_pressed_color", "Button", GOLD)
	ui_theme.set_stylebox("normal", "Button", load(BASE + "styles/tab_normal.tres"))
	ui_theme.set_stylebox("hover", "Button", load(BASE + "styles/tab_highlighted.tres"))
	ui_theme.set_stylebox("pressed", "Button", load(BASE + "styles/tab_highlighted.tres"))
	var focus: StyleBoxTexture = load(BASE + "styles/tab_highlighted.tres").duplicate()
	focus.draw_center = false
	ui_theme.set_stylebox("focus", "Button", focus)
	var track := StyleBoxFlat.new()
	track.bg_color = Color("121924")
	track.content_margin_left = 6
	track.content_margin_right = 6
	var thumb := StyleBoxFlat.new()
	thumb.bg_color = Color("788ba9")
	thumb.corner_radius_top_left = 3
	thumb.corner_radius_top_right = 3
	thumb.corner_radius_bottom_left = 3
	thumb.corner_radius_bottom_right = 3
	ui_theme.set_stylebox("scroll", "VScrollBar", track)
	ui_theme.set_stylebox("grabber", "VScrollBar", thumb)
	ui_theme.set_stylebox("grabber_highlight", "VScrollBar", thumb)
	ui_theme.set_stylebox("grabber_pressed", "VScrollBar", thumb)
	theme = ui_theme
	var background := ColorRect.new()
	background.color = Color("111821")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)
	var shell: PanelContainer = preload("res://assets/ui/windows/window_shell.tscn").instantiate()
	margin.add_child(shell)
	var stack: VBoxContainer = shell.get_node("Content")
	var header := HBoxContainer.new()
	stack.add_child(header)
	var back := Button.new()
	back.text = "‹ Zurück"
	back.custom_minimum_size = Vector2(140, 56)
	back.pressed.connect(func(): get_tree().quit())
	header.add_child(back)
	title = label("STATISTIK", 30, GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(title)
	var tab_row := HFlowContainer.new()
	tab_row.add_theme_constant_override("h_separation", 8)
	stack.add_child(tab_row)
	var group := ButtonGroup.new()
	for caption in ["Überblick", "Fortschritt", "Aufgaben"]:
		var tab := Button.new()
		tab.text = caption
		tab.custom_minimum_size = Vector2(152, 56)
		tab.toggle_mode = true
		tab.button_group = group
		tab.button_pressed = caption == active_tab
		tab.pressed.connect(show_tab.bind(caption))
		tabs.append(tab)
		tab_row.add_child(tab)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stack.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 20)
	scroll.add_child(body)
	var footer := HBoxContainer.new()
	stack.add_child(footer)
	var hint := label("Sam  ·  Level 4", 14, MUTED)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(hint)
	footer.add_child(label("LAYOUT-VORSCHAU", 12, MUTED))
	resized.connect(adapt)
	show_tab("Überblick")
	adapt()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			capture(arg.trim_prefix("--capture="))

func label(value: String, font_size: int = 18, color: Color = TEXT) -> Label:
	var result := Label.new()
	result.text = value
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	return result

func paragraph(value: String, color: Color = MUTED) -> Label:
	var result := label(value, 17, color)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return result

func separator() -> void:
	var line := HSeparator.new()
	var style := StyleBoxLine.new()
	style.color = Color("48566f")
	style.thickness = 1
	line.add_theme_stylebox_override("separator", style)
	body.add_child(line)

func stat(parent: Node, value: String, caption: String, note: String) -> void:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 4)
	parent.add_child(column)
	column.add_child(label(caption.to_upper(), 14, MUTED))
	column.add_child(label(value, 42, GOLD))
	column.add_child(paragraph(note))

func progress_bar(value: float, maximum: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value = maximum
	bar.value = value
	bar.show_percentage = false
	bar.custom_minimum_size.y = 12
	var track := StyleBoxFlat.new()
	track.bg_color = Color("111722")
	var fill := StyleBoxFlat.new()
	fill.bg_color = GOLD
	bar.add_theme_stylebox_override("background", track)
	bar.add_theme_stylebox_override("fill", fill)
	return bar

func record_row(caption: String, value: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var key := paragraph(caption, TEXT)
	key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(key)
	row.add_child(label(value, 20, GOLD))
	body.add_child(row)

func show_tab(caption: String) -> void:
	active_tab = caption
	metrics = null
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	scroll.scroll_vertical = 0
	if caption == "Überblick":
		metrics = GridContainer.new()
		metrics.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		metrics.add_theme_constant_override("h_separation", 36)
		metrics.add_theme_constant_override("v_separation", 20)
		body.add_child(metrics)
		stat(metrics, "2 Tage", "Deine Übungsserie", "in Folge geübt · Heute ist dabei")
		stat(metrics, "89 %", "Letzte Sitzung", "+39 Prozentpunkte gegenüber den 7 Tagen davor (50 %)")
		separator()
		body.add_child(label("SEPTEMBER", 16, GOLD))
		body.add_child(paragraph("An 4 von 30 Tagen geübt"))
		var calendar := HFlowContainer.new()
		calendar.add_theme_constant_override("h_separation", 3)
		calendar.add_theme_constant_override("v_separation", 8)
		body.add_child(calendar)
		for day in range(1, 31):
			var column := VBoxContainer.new()
			column.custom_minimum_size.x = 30
			var practiced: bool = day in [23, 24, 28, 29]
			var marker := label("●" if practiced else "○", 24, GOLD if practiced else Color("728097"))
			marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			column.add_child(marker)
			var number := label(str(day), 12, GOLD if practiced else MUTED)
			number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			column.add_child(number)
			calendar.add_child(column)
		separator()
		body.add_child(label("LEVEL 4", 18, GOLD))
		body.add_child(progress_bar(166, 400))
		body.add_child(paragraph("166 / 400 XP  ·  Insgesamt 766 XP"))
		separator()
		body.add_child(label("REKORDE", 18, GOLD))
		record_row("Höchste geräumte Welle", "2")
		record_row("Längste Serie ohne Durchlass", "4 Monster")
		record_row("Geöffnete Schatzkisten", "18")
		record_row("Gemeisterte Aufgaben", "0")
		record_row("Heute fällig", "52")
		var debug_toggle := CheckButton.new()
		debug_toggle.text = "Debug-Werte anzeigen"
		body.add_child(debug_toggle)
		debug_values = paragraph("∞ Gold (Debug) · 999 Skillpunkte offen")
		debug_values.visible = false
		body.add_child(debug_values)
		debug_toggle.toggled.connect(func(on: bool): debug_values.visible = on)
	elif caption == "Fortschritt":
		body.add_child(label("LEVEL 4", 32, GOLD))
		body.add_child(progress_bar(166, 400))
		body.add_child(paragraph("166 / 400 XP · Noch 234 XP bis Level 5"))
		record_row("Insgesamt gesammelte XP", "766")
		body.add_child(paragraph("Beispieldaten aus dem bereitgestellten Statistik-Screen."))
	else:
		body.add_child(label("DEINE AUFGABEN", 24, GOLD))
		record_row("Heute fällig", "52")
		record_row("Gemeisterte Aufgaben", "0")
		body.add_child(paragraph("Beispieldaten aus dem bereitgestellten Statistik-Screen."))
	adapt()

func adapt() -> void:
	if is_instance_valid(metrics):
		metrics.columns = 2 if size.x >= 760 else 1
	if is_instance_valid(title):
		title.add_theme_font_size_override("font_size", 30 if size.x >= 600 else 22)

func capture(destination: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(destination)
	get_tree().quit()
