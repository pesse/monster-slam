class_name BossChoice
extends Control
## Die Wahl am Boss-Ort (ADR 0023): eine Karte je Boss, ein Klick startet ihn. Ein Overlay
## wie ConfirmDialog, kein Godot-`Window`. Was danach geschieht, entscheidet der Aufrufer.

## Der Spieler hat einen Boss gewählt: `writing` = The Rambler, sonst der Satzmeister.
signal chosen(writing: bool)
signal cancelled()

@onready var _golem: Button = %GolemCard
@onready var _rambler: Button = %RamblerCard
@onready var _cancel: Button = %CancelButton


func _ready() -> void:
	hide()
	_golem.pressed.connect(func() -> void: _pick(false))
	_rambler.pressed.connect(func() -> void: _pick(true))
	Hints.attach(_rambler, "The Rambler", "Der Schreib-Boss: Fasse seine Geschichte in einer "
			+ "Summary zusammen.", "Dein Text geht zur Bewertung an Anthropic.")
	_cancel.pressed.connect(func() -> void:
			hide()
			cancelled.emit())


## Escape bricht ab, nur solange die Wahl offen ist.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		hide()
		cancelled.emit()
		accept_event()


## Öffnet die Wahl; der Fokus liegt auf dem Satzmeister.
func ask() -> void:
	show()
	_golem.grab_focus()


func _pick(writing: bool) -> void:
	hide()
	chosen.emit(writing)
