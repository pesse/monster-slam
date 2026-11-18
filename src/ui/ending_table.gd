class_name EndingTable
extends VBoxContainer
## Die lateinischen Endungen als Tabelle (ADR 0032): Zeilen sind Zellen, Spalten Klassen, in
## jedem Feld die Endung, gefärbt nach ihrem Stand. Eine Endung, die mehrere Klassen gleich
## bilden, ist eine Lerneinheit und steht mit demselben Stand in jeder ihrer Spalten.

const CELL_SCENE := preload("res://scenes/ui/ending_cell.tscn")
const PROGRESS := preload("res://src/learning/player_progress.gd")

## Breite der Zeilenbeschriftung (px), damit Deklination und Konjugation fluchten.
const ROW_LABEL_WIDTH := 132

## Spaltenköpfe: Klasse -> kurz. Die Hinweiskarte nennt den vollen Namen.
const DECL_COLUMNS := {"a": "a", "o": "o", "o_n": "o, n.", "3": "3.", "3_n": "3., n.",
		"3_i": "3., i", "3_in": "3., i, n.", "u": "u", "e": "e"}
const CONJ_COLUMNS := {"a": "a", "e": "e", "i": "i", "cons": "kons.", "mixed": "gem."}

## Feldfarben (self_modulate auf weißem Grund): ohne Träger, ungeübt, Stand 0 % und knapp unter
## der Meisterung, gemeistert.
const COLOR_ABSENT := Color(1, 1, 1, 0.04)
const COLOR_NEW := Color(0.42, 0.48, 0.6, 0.35)
const COLOR_LOW := Color(0.66, 0.26, 0.22, 0.65)
const COLOR_HIGH := Color(0.62, 0.56, 0.2, 0.65)
const COLOR_MASTERED := Color(0.22, 0.6, 0.32, 0.85)
const COLOR_HEAD := Color(1, 1, 1, 0)


## Die Tabelle einer Art ("decl" oder "conj"): { title, columns: [{text, hint}], rows: [{label,
## cells: [{text, unit, state, confidence}]}] }. `present`: Endings.present_units;
## `conf`: Confidence einer learnable_id, -1 ohne Record.
static func sheet(kind: String, present: Dictionary, conf: Callable, is_mastered: Callable) -> Dictionary:
	var columns: Dictionary = DECL_COLUMNS if kind == "decl" else CONJ_COLUMNS
	var heads: Array = []
	for cls in columns:
		var full: String = LatinMorphology.CLASS_LABELS[cls] if kind == "decl" \
				else LatinMorphology.CONJ_LABELS[cls]
		heads.append({"text": columns[cls], "hint": full})
	var rows: Array = []
	for table in (["decl"] if kind == "decl" else ["pres", "impf", "imp", "perf"]):
		var cells: Array = LatinMorphology.CELLS[table]
		for i in cells.size():
			var row := {"label": LatinMorphology.cell_label("%s.%s" % [table, cells[i]]), "cells": []}
			for cls in columns:
				var unit := LatinMorphology.unit_at(table, cls, i)
				var id := Endings.learnable_id("la", unit)
				var confidence := float(conf.call(id))
				var state := "absent"
				if present.has(unit):
					state = "mastered" if is_mastered.call(id) else ("new" if confidence < 0.0 else "learning")
				row["cells"].append({"text": LatinMorphology.ending_text(table, cls, i), "unit": unit,
						"state": state, "confidence": confidence})
			rows.append(row)
	return {"title": LatinMorphology.TABLE_LABELS["decl"] if kind == "decl" else "Konjugation",
			"columns": heads, "rows": rows}


## Gemeistert und gesamt über die Endungen in `present`, je Lerneinheit einmal.
static func summary(present: Dictionary, is_mastered: Callable) -> Dictionary:
	var done := 0
	for unit in present:
		if is_mastered.call(Endings.learnable_id("la", unit)):
			done += 1
	return {"done": done, "total": present.size()}


## Hat die Tabelle mindestens eine Endung mit Träger?
static func has_present(table_sheet: Dictionary) -> bool:
	for row in table_sheet["rows"]:
		for cell in row["cells"]:
			if cell["state"] != "absent":
				return true
	return false


static func cell_color(cell: Dictionary) -> Color:
	match str(cell["state"]):
		"absent":
			return COLOR_ABSENT
		"new":
			return COLOR_NEW
		"mastered":
			return COLOR_MASTERED
	var share := clampf(float(cell["confidence"]) / PROGRESS.MASTERY_CONFIDENCE, 0.0, 1.0)
	return COLOR_LOW.lerp(COLOR_HIGH, share)


static func cell_note(cell: Dictionary) -> String:
	match str(cell["state"]):
		"absent":
			return "Wird hier nicht abgefragt: kein Wort trägt sie, oder sie steht schon in der Aufgabe (Genitiv)."
		"new":
			return "Noch nicht geübt."
		"mastered":
			return "✓ gemeistert · %d %%" % roundi(float(cell["confidence"]) * 100.0)
	return "%d %%" % roundi(float(cell["confidence"]) * 100.0)


func show_sheet(table_sheet: Dictionary) -> void:
	($Title as Label).text = str(table_sheet["title"])
	var grid := $Grid as GridContainer
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	var heads: Array = table_sheet["columns"]
	grid.columns = heads.size() + 1
	_add(grid, "", COLOR_HEAD, "Caption").custom_minimum_size.x = ROW_LABEL_WIDTH
	for head in heads:
		Hints.attach(_add(grid, str(head["text"]), COLOR_HEAD, "Caption"), str(head["hint"]), "")
	for row in table_sheet["rows"]:
		var label := _add(grid, str(row["label"]), COLOR_HEAD, "Caption")
		label.custom_minimum_size.x = ROW_LABEL_WIDTH
		(label.get_node("Text") as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		for cell in row["cells"]:
			var box := _add(grid, str(cell["text"]), cell_color(cell),
					"Hint" if cell["state"] == "absent" else "")
			Hints.attach(box, LatinMorphology.unit_label(str(cell["unit"])), cell_note(cell))


func _add(grid: GridContainer, text: String, color: Color, variation: String) -> PanelContainer:
	var box := CELL_SCENE.instantiate() as PanelContainer
	box.self_modulate = color
	var label := box.get_node("Text") as Label
	label.text = text
	label.theme_type_variation = StringName(variation)
	grid.add_child(box)
	return box
