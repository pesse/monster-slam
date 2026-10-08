extends PanelContainer
## Löst nach dem Wellenende die gespielten Vokabeln auf: zeigt sie als Karten-
## Karussell (immer EINE Karte sichtbar) mit "Wort -> korrekte Übersetzung", inkl.
## aller alternativen Antworten. Beim ersten Durchlauf läuft eine automatische
## Animation über die DURCHGELASSENEN (falschen) Vokabeln (Karte einwischen ->
## Lösung aufdecken -> 3 s halten -> zur nächsten wischen); danach kann der Spieler
## mit Pfeilen frei blättern, per "Alle anzeigen" auch die richtig beantworteten
## dazunehmen (schon während des Durchlaufs: sie werden dann hinten angehängt, der
## Durchlauf selbst bleibt bei den durchgelassenen und lässt sich nicht abbrechen), einzelne Vokabeln per "⚑ Melden" mit Kommentar flaggen und mit
## "Weiter" zum Statistik-Screen gehen.
##
## **Enter drückt "Weiter"**, sobald der Knopf frei ist, ←/→ blättern — gespielt wird mit der Tastatur.
## Erst nach `enter_grace_ms`: bei perfekter Welle steht der Screen sofort da, und das
## Enter der letzten Antwort soll nicht durch ihn hindurchklicken. Im Kommentarfeld
## gehört Enter dem Absenden.
##
## "⚑ Melden" erscheint nur, wenn diese Fassung einen Rückkanal hat (Endpunkt und
## App-Schlüssel, siehe ReportService und docs/adr/0022-melden-ohne-token.md). Ohne ihn wäre
## die Meldung ohne Folge — und ein Knopf ohne Folge ist ärgerlicher als keiner.
##
## Bei perfekter Welle (0 durchgelassen) erscheint der Screen ohne Animation und
## geht direkt in den freien Blätter-Modus über alle gespielten Vokabeln.
##
## **Zurück aus dem Ergebnis** (Issue #52, „◂ Zurück" im WaveStats): die Antworten sind
## das, woran gelernt wird, und nach einem Blick auf die Zahlen will man sie noch einmal
## sehen. `play(played, true)` zeigt sie ohne Durchlauf — die durchgelassenen schon
## aufgedeckt, frei zu blättern, „Weiter" sofort frei. Der Durchlauf ist die erste
## Begegnung mit der Lösung; beim zweiten Mal wäre er nur Warten.
##
## Die statische Hülle (Titel, Bühne, Fortschritt, Nav-/Aktions-Buttons) liegt in
## leak_reveal.tscn; hier bleibt nur das dynamische Karten-Karussell. Die Nav-/
## Aktions-Controls haben focus_mode=FOCUS_NONE (in der Szene gesetzt); das
## Kommentarfeld darf fokussiert werden (die Kampf-Antwort-LineEdit ist während des
## Reveals unsichtbar und stiehlt den Fokus dann nicht, siehe answer_input.gd).

const CARD_SCENE := preload("res://scenes/ui/reveal_card.tscn")
const HOLD_TIME := 3.0                          # Standzeit pro Karte im Auto-Durchlauf
const READ_QUESTION_TIME := 0.5                 # kurze Pause auf der Frage vor dem Aufdecken
const SWIPE_TIME := 0.35
const REVEAL_TIME := 0.3
## So lange nach dem Freigeben von "Weiter" zählt Enter noch nicht (siehe Kopf). Eine
## Variable, damit Tests ohne Warten auskommen.
var enter_grace_ms := 400

var _items: Array = []          # aktuell durchblätterbare Menge (erst nur falsche, dann ggf. alle)
var _leaked: Array = []         # durchgelassene (falsche) Vokabeln — Reihenfolge fürs Autoplay
var _all_ordered: Array = []    # alle: falsche zuerst, dann richtige
var _showing_all: bool = false
var _autoplaying: bool = false  # läuft der Auto-Durchlauf über die durchgelassenen?
var _index: int = 0
var _continue_since_ms: int = 0

@onready var _stage: Control = %Stage
@onready var _progress: Label = %Progress
@onready var _prev_btn: Button = %PrevBtn
@onready var _next_btn: Button = %NextBtn
@onready var _show_all_btn: Button = %ShowAllBtn
@onready var _flag_btn: Button = %FlagBtn
@onready var _flag_input: HBoxContainer = %FlagInput
@onready var _flag_comment: LineEdit = %FlagComment
@onready var _flag_submit: Button = %FlagSubmit
@onready var _flag_status: Label = %FlagStatus
@onready var _continue_btn: Button = %ContinueBtn
var _current_card: Control = null


func _ready() -> void:
	_prev_btn.pressed.connect(func(): _goto(_index - 1))
	_next_btn.pressed.connect(func(): _goto(_index + 1))
	_show_all_btn.pressed.connect(_on_show_all)
	_flag_btn.pressed.connect(_on_flag_toggle)
	_flag_submit.pressed.connect(_on_flag_submit)
	_flag_comment.text_submitted.connect(func(_t): _on_flag_submit())


## Awaitbar: zeigt das Karussell, spielt die falschen einmal automatisch durch und
## kehrt erst zurück, wenn der Spieler "Weiter" klickt. Erwartet je Eintrag:
## {"prompt", "answers", "lexeme_type", "source_id", "learnable_id", "leaked"}.
## `again`: der Rückweg aus dem Ergebnis — ohne Durchlauf (siehe Kopf).
func play(played: Array, again := false) -> void:
	if played.is_empty():
		return
	_leaked = played.filter(func(t): return bool(t.get("leaked", false)))
	var correct := played.filter(func(t): return not bool(t.get("leaked", false)))
	_all_ordered = _leaked + correct
	_showing_all = false
	_index = 0
	_reset_flag_ui()
	_apply_report_gate()
	visible = true
	# Während des Auto-Durchlaufs alle Interaktion sperren — bis auf „Alle anzeigen": das
	# hängt nur die richtigen hinten an und unterbricht den Durchlauf nicht.
	_prev_btn.disabled = true
	_next_btn.disabled = true
	_continue_btn.disabled = true
	_flag_btn.disabled = true
	_update_show_all()
	# Ein Frame, damit die Bühne ihre echte Größe hat (für die Wisch-Distanz).
	await get_tree().process_frame

	if _leaked.is_empty():
		# Perfekte Welle: keine Animation, direkt alle frei durchblättern.
		_showing_all = true
		_items = _all_ordered
		_index = 0
		_place_card(0, true, false)
	elif again:
		_items = _leaked
		_place_card(0, true, false)
	else:
		_items = _leaked
		_autoplaying = true
		await _autoplay()
		_autoplaying = false

	_continue_btn.disabled = false
	_continue_since_ms = Time.get_ticks_msec()
	_flag_btn.disabled = false
	_update_nav()
	_update_show_all()
	await _continue_btn.pressed
	hide_reveal()


## `_input` und nicht `_unhandled_input`: die Knöpfe haben keinen Fokus (siehe Kopf).
## ←/→ drücken die Pfeilknöpfe, solange die frei sind (nicht im Auto-Durchlauf);
## gehaltene Tasten blättern weiter.
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or _flag_comment.has_focus():
		return
	var key := event as InputEventKey
	if key == null or not key.pressed:
		return
	var arrow := {KEY_LEFT: _prev_btn, KEY_RIGHT: _next_btn}.get(key.keycode) as Button
	if arrow != null:
		if not arrow.disabled:
			accept_event()
			arrow.pressed.emit()
		return
	if key.echo or _continue_btn.disabled or not key.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		return
	if Time.get_ticks_msec() - _continue_since_ms < enter_grace_ms:
		return
	accept_event()
	_continue_btn.pressed.emit()


func hide_reveal() -> void:
	visible = false
	if is_instance_valid(_current_card):
		_current_card.queue_free()
		_current_card = null


## Spielt die durchgelassenen Karten einmal automatisch durch. Gezählt wird an `_leaked`
## und nicht an `_items`: „Alle anzeigen" kann die Menge währenddessen verlängern, und
## die angehängten richtigen gehören nicht in den Durchlauf.
func _autoplay() -> void:
	for i in _leaked.size():
		_index = i
		_update_progress()
		_place_card(i, false, true)         # Frage sichtbar, Lösung verdeckt, off-screen rechts
		await _swipe_in()
		await get_tree().create_timer(READ_QUESTION_TIME).timeout
		await _reveal_solution()
		await get_tree().create_timer(HOLD_TIME).timeout
		if i < _leaked.size() - 1:
			await _swipe_out()


## Baut die Karte für `index` und hängt sie in die Bühne. `offscreen` platziert sie
## rechts außerhalb (für den Einwisch), sonst zentriert bei x=0.
func _place_card(index: int, revealed: bool, offscreen: bool) -> void:
	if is_instance_valid(_current_card):
		_current_card.queue_free()
	var w := _stage.size.x
	var card := CARD_SCENE.instantiate() as RevealCard
	_stage.add_child(card)                 # zuerst in den Baum -> onready-Knoten stehen
	card.set_width(w)                      # vor setup(): die langen Zeilen brechen sofort um
	card.setup(_items[index], revealed)
	card.size = Vector2(w, _stage.size.y)
	card.position = Vector2(w if offscreen else 0.0, 0.0)
	_current_card = card


func _swipe_in() -> void:
	var tw := create_tween()
	tw.tween_property(_current_card, "position:x", 0.0, SWIPE_TIME) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished


func _swipe_out() -> void:
	var card := _current_card
	var tw := create_tween()
	tw.tween_property(card, "position:x", -_stage.size.x, SWIPE_TIME) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw.finished


func _reveal_solution() -> void:
	if not is_instance_valid(_current_card):
		return
	var sol := (_current_card as RevealCard).solution()
	sol.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(sol, "modulate:a", 1.0, REVEAL_TIME)
	await tw.finished


## Manuelle Navigation per Pfeil: springt zur Karte, vollständig aufgelöst.
func _goto(index: int) -> void:
	_index = clampi(index, 0, _items.size() - 1)
	_place_card(_index, true, false)
	_reset_flag_ui()
	_update_nav()


## "Alle anzeigen": erweitert die Blätter-Menge auf alle gespielten (falsche zuerst,
## dann richtige) und blendet sich danach aus. Während des Auto-Durchlaufs bleiben die
## Pfeile gesperrt — nur der Zähler zeigt schon die neue Gesamtzahl.
func _on_show_all() -> void:
	_showing_all = true
	_items = _all_ordered
	if _autoplaying:
		_update_progress()
	else:
		_reset_flag_ui()
		_update_nav()
	_update_show_all()


func _update_show_all() -> void:
	# Nur anbieten, wenn es zusätzliche (richtige) Vokabeln gibt und noch nicht alle
	# gezeigt werden.
	_show_all_btn.visible = _all_ordered.size() > _leaked.size() and not _showing_all
	# Nie gesperrt: früher sperrte play() ihn für den Durchlauf und gab ihn nicht wieder
	# frei — nach jeder Welle mit Durchgelassenen stand er grau da.
	_show_all_btn.disabled = false


func _update_nav() -> void:
	_prev_btn.disabled = _index <= 0
	_next_btn.disabled = _index >= _items.size() - 1
	# Flaggen nur möglich, wenn die Vokabel ein Quell-Lexem trägt.
	_flag_btn.disabled = _current_item_source_id().is_empty()
	_update_progress()


func _update_progress() -> void:
	_progress.text = "Karte %d / %d" % [_index + 1, _items.size()]


# --- Flaggen -----------------------------------------------------------------

## Ohne Rückkanal gibt es kein "Melden" — der Knopf erscheint nicht. Einmal je Reveal:
## der Rückkanal hängt an der Fassung und ändert sich während einer Welle nicht.
func _apply_report_gate() -> void:
	_flag_btn.visible = ReportService.can_report()


func _current_item_source_id() -> String:
	if _index < 0 or _index >= _items.size():
		return ""
	return String(_items[_index].get("source_id", ""))


func _reset_flag_ui() -> void:
	_flag_input.visible = false
	_flag_comment.text = ""
	_flag_status.text = ""


## "⚑ Melden": klappt das Kommentarfeld auf/zu.
func _on_flag_toggle() -> void:
	_flag_input.visible = not _flag_input.visible
	_flag_status.text = ""
	if _flag_input.visible:
		_flag_comment.grab_focus()


func _on_flag_submit() -> void:
	var comment := _flag_comment.text.strip_edges()
	if comment.is_empty():
		_flag_status.text = "Bitte einen Kommentar eingeben."
		return
	var item: Dictionary = _items[_index]
	var source_id := String(item.get("source_id", ""))
	if source_id.is_empty():
		_flag_status.text = "Kein Lexem zum Melden."
		return
	var ok := ContentRegistry.flag_lexeme(source_id, comment, String(item.get("learnable_id", "")))
	if not ok:
		_flag_status.text = "Melden fehlgeschlagen (siehe Log)."
		return
	_flag_input.visible = false
	_flag_comment.text = ""
	_flag_status.text = "✔ Gemeldet: %s" % String(item.get("prompt", ""))
	# Gemeldet ist die Vokabel schon — lokal. Der Versand ist der zweite Schritt; klappt
	# er nicht, bleibt die Meldung offen und geht beim nächsten Start mit.
	if not await ReportService.send_pending(true):
		_flag_status.text = "⚑ Gemerkt — Versand später (%s)" % ReportService.error
