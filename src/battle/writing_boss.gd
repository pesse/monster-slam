class_name WritingBoss
extends Control
## Der Schreib-Boss „The Rambler“ (scenes/battle/writing_boss.tscn) —
## docs/adr/0023-schreib-boss.md.
##
## The Rambler erzählt eine Geschichte endlos und abschweifend; das Kind schreibt eine
## Summary dazu. An ihm hängen fünf Papierstapel, je Kriterium einer (WritingJudge.CRITERIA).
## Ein erfülltes Kriterium wirft seinen Stapel ab; fällt der letzte, ist er besiegt.
##
## **Ablauf in Phasen** (ADR 0023, Abschnitt 4). Die Bühne (RamblerStage, Ich-Sicht) steht
## immer dahinter, jede Phase hat ihr eigenes Overlay (scenes/battle/writing/*.tscn):
##
##     Begegnung ─► Lesen ─► Schreiben ─► Angriff ─► Überarbeiten ─► Angriff ─► … ─► Sieg
##                    ▲         │  ▲          │
##                    └─────────┘  └──────────┘ Dienstfehler: zurück, die Abgabe zählt nicht
##
## - **Begegnung:** der Boss vorn, er stellt die Aufgabe.
## - **Lesen:** die Vorlage groß und scrollbar, der Boss tritt zurück.
## - **Schreiben:** die Vorlage schmal links, das Schreibfeld breit, rechts die Randleiste
##   mit Wortzahl und Länge (SummaryCard.check) — entprellt, damit nicht jeder Tastendruck
##   den ganzen Text zerlegt. Alles Inhaltliche urteilt erst das Modell beim Angriff.
## - **Angriff:** das Warten auf das Modell ist das Aufladen; danach Kriterium für
##   Kriterium: Stapel fällt (`drop_stack`) oder hält (`hold_stack`).
## - **Überarbeiten:** der eigene Text mit den markierten Stellen und ihren Hinweisen;
##   erneut abgeben ist der nächste Angriff. **Die Zahl der Abgaben ist nicht begrenzt**
##   (ADR 0023, Abschnitt 6).
##
## **Ein gefallener Stapel kehrt nicht zurück.** Jede Abgabe wird ganz neu bewertet; was
## schon einmal erfüllt war, bleibt gefallen, auch wenn das Modell es diesmal anders sieht —
## gewertet wird in Stufen, und ein Kind soll für eine Überarbeitung nicht bestraft werden.
##
## **Der Text geht nie verloren.** Er lebt in `text`, nicht im Schreibfeld; beide Felder
## (Schreiben, Überarbeiten) spiegeln ihn. Scheitert der Dienst (kein Netz, Zeitlimit,
## unlesbare Antwort), bleibt er stehen, der Grund aus `reply.note` steht da, und die Abgabe
## zählt nicht. Verlassen mit Text fragt nach (ConfirmDialog).
##
## **Im Hintergrund brabbelt er.** Solange ein Overlay vorn liegt, wandert The Rambler
## hinten (RamblerStage) und tritt ab und zu am Bildrand auf; dort murmelt er einen
## Satzfetzen (MUMBLES) in einer schmalen Blase über dem Maul, nah am Rand.
##
## **Kein Zeitdruck**, wie beim Satzmeister. Kein Gold, keine Erfahrung, kein Lernstand.
##
## Je gewertete Abgabe ein Eintrag in WritingLog und `EventBus.writing_submitted` — die
## Kosten (ADR 0023, Abschnitt 7); ein Sieg über einen Boss von der Karte zählt in
## BossRecord wie beim Satzmeister (ADR 0006).
##
## **Die Szene ändert ihre Größe nicht**: jede Phase füllt dieselbe Fläche unter der
## Kopfleiste, umgeschaltet wird über Sichtbarkeit ganzer Overlays, nicht einzelner Felder.

const SELF_SCENE := "res://scenes/battle/writing_boss.tscn"
const STAGE_SCENE := "res://scenes/battle/rambler_stage.tscn"
const CRITERION_ROW := preload("res://scenes/battle/writing/criterion_row.tscn")
const MARK_ROW := preload("res://scenes/battle/writing/mark_row.tscn")
const BOSS_ID := "boss.rambler"
const DEFAULT_KIND := "summary"

enum Phase { ENCOUNTER, READING, WRITING, ATTACK, REVISION, VICTORY, EMPTY }

## So lange steht jedes Kriterium beim Angriff allein, bevor das nächste kommt.
const REVEAL_STEP := 0.8

## Die Kriterien, wie das Kind sie liest. Reihenfolge und Ids aus WritingJudge.CRITERIA.
const CRITERION_NAMES := {
	"intro": "Einleitung",
	"content": "Inhalt",
	"genre": "Textsorte",
	"language": "Sprache",
	"length": "Länge",
}
## Was ein haltender Stapel ohne markierte Stelle sagt — die Regel, nie die Lösung.
const CRITERION_RULES := {
	"intro": "Nenne im ersten Satz Titel und Autor der Geschichte.",
	"content": "Ein wichtiger Punkt der Geschichte fehlt noch. Lies sie noch einmal.",
	"genre": "Present Tense, keine direkte Rede, keine eigene Meinung.",
	"language": "Es stecken noch schwere Fehler im Text.",
	"length": "Ziel: %d–%d Wörter, du hast %d.",
}

## Was The Rambler sagt.
const ENCOUNTER_TEXT := "Ah, ein Zuhörer! Ich erzähle dir eine Geschichte – eine wunderbare, lange, sehr lange Geschichte … Und du? Du willst sie in ein paar Sätzen sagen? Haha! Versuch's doch!"
const TASK_TEXT := "Schreibe eine Summary auf Englisch: %s, im Present Tense, mit Titel und Autor im ersten Satz, ohne direkte Rede und ohne deine Meinung."
const TASK_NOTE := "Kein Zeitdruck. Zum Bewerten geht dein Text mit deinem eigenen Schlüssel an Anthropic – dein Name nicht."
const CHARGE_TEXT := "Er blättert und murmelt … dein Angriff lädt auf."
const HIT_TEXT := "Autsch! Meine schönen Blätter!"
const HOLD_TEXT := "Ha! Kein einziges Blatt verloren!"
const NO_VERDICT_TEXT := "Er hat nicht zugehört."
const FAILED_NOTE := "%s Dein Text ist gespeichert – diese Abgabe zählt nicht."
const FAILED_DEFAULT := "Die Bewertung kam nicht an."
const WON_TEXT := "Neiiin … meine ganze Geschichte – in so wenigen Worten?! Mir fehlen die Worte!"
const WON_TITLE := "🏆 Du hast The Rambler besiegt!"
const EMPTY_TEXT := "Für The Rambler gibt es in deiner Auswahl keine Schreibaufgabe. Wähle eine Unit mit Schreibaufgaben."
const EMPTY_TEXT_NOTE := "Zum Schreiben hast du nichts getippt."
const LEAVE_TITLE := "Kampf verlassen?"
const LEAVE_BODY := "Dein Text geht dabei verloren."
## Der Ausruf in der Bildmitte.
const HIT_SHOUT := "TREFFER!"
const HOLD_SHOUT := "HÄLT!"
const WON_SHOUT := "SIEG!"
const HIT_SHOUT_TINT := Color(1.0, 0.86, 0.3)
const HOLD_SHOUT_TINT := Color(0.65, 0.85, 1.0)

## Was er im Hintergrund vor sich hin murmelt.
const MUMBLES := [
	"Blabla … blabla …",
	"… und dann, ach ja, meine Tante …",
	"Wo war ich stehen geblieben?",
	"… Kapitel siebenundvierzig …",
	"… und so weiter und so fort …",
	"Das erinnert mich an eine andere Geschichte …",
	"… once upon a time … and then … and then …",
	"Hmm-hmm … ganz kurz nur …",
	"Die Fußnoten! Ich hab die Fußnoten vergessen!",
	"Kurzfassung? Pah!",
	"… Absatz, Absatz, Absatz …",
	"… wobei, eigentlich fing alles viel früher an …",
]
## Pause zwischen zwei Fetzen während eines Auftritts (s, von–bis), Verzögerung nach dem
## Ankommen (s) und wie lange ein Fetzen stehen bleibt (s).
const MUMBLE_PAUSE := Vector2(4.0, 7.0)
const MUMBLE_DELAY := 0.8
const MUMBLE_TIME := 3.0
## In diesen Phasen steht er hinten und murmelt.
const MUMBLE_PHASES := [Phase.READING, Phase.WRITING, Phase.REVISION]

## Wortschatz-Bonus (ADR 0023, Nachtrag 2026-10-15): so viele verschiedene Wörter der Unit
## (UnitWords) muss eine Abgabe enthalten. Er zählt erst, wenn der Stapel „Inhalt“ gefallen
## ist, bleibt danach erreicht und ist für den Sieg nicht nötig.
const UNIT_WORD_GOAL := 5
const BONUS_NAME := "Wortschatz-Bonus"
const BONUS_SHOUT := "BONUS!"
const BONUS_SHOUT_TINT := Color(0.75, 1.0, 0.55)

## Vor dem Einhängen setzen: ein erfundenes Backend statt CloudModelBackend, Zuschnitt wie
## `CloudModelBackend.judge_summary(task, text, on_done)`. Kein Test spricht mit dem Dienst.
var fake_backend: Callable = Callable()
## Vor dem Einhängen setzen: eine eigene Bühne (Tests: ein Stub). Sonst RamblerStage.
var stage: Node = null
## Ob Siege (BossRecord) und Abgaben (WritingLog) gebucht werden. Aus für die Werkbank.
var record := true
## Ob der Kampf seine EventBus-Signale sendet (und damit in der Spur steht). Aus für die
## Werkbank — sie spielt mit erfundenen Urteilen.
var emit_events := true
## Profil für WritingLog; leer = das aktive. Tests nehmen ein `zz-`-Profil.
var log_profile := ""
## Werkbank: statt des Szenenwechsels beim Verlassen.
var on_leave: Callable = Callable()
## Wie lange jedes Kriterium beim Angriff allein steht; 0 = alle sofort (Tests).
var reveal_step := REVEAL_STEP

var boss: Dictionary = {}
var task: Dictionary = {}
var phase: Phase = Phase.ENCOUNTER
## Der Text des Kindes — die eine Stelle, an der er lebt.
var text := ""
## Gewertete Abgaben bisher. Eine Abgabe ohne Urteil zählt nicht.
var rounds := 0
## Kriterien-Id -> true, sobald ihr Stapel gefallen ist.
var fallen: Dictionary = {}
## Ist der Wortschatz-Bonus erreicht? Bleibt danach erreicht, wie ein gefallener Stapel.
var bonus := false
## Die Wörter der Unit im Text, wie er gerade steht (UnitWords.found).
var unit_words: Array = []
## Das Urteil der letzten gewerteten Abgabe (WritingJudge.criteria).
var last_criteria: Array = []
## Der Grund, wenn die letzte Abgabe kein Urteil bekam, sonst leer.
var last_note := ""

@onready var _scene_zoom: SceneZoom = $SceneZoom
@onready var _flash: ColorRect = %Flash
@onready var _mumble: SpeechBubble = %Mumble
@onready var _mumble_line: Label = %MumbleLine
@onready var _shout: Label = %Shout
@onready var _back_button: Button = %BackButton
@onready var _boss_name: Label = %BossName
@onready var _stack_label: Label = %StackLabel
@onready var _stack_bar: ProgressBar = %StackBar
@onready var _round_label: Label = %RoundLabel
@onready var _check_timer: Timer = %CheckTimer
@onready var _confirm: ConfirmDialog = %ConfirmDialog
@onready var _encounter: Control = %Encounter
@onready var _reading: Control = %Reading
@onready var _writing: Control = %Writing
@onready var _attack: Control = %Attack
@onready var _revision: Control = %Revision

# Begegnung (auch Sieg und „keine Aufgabe“)
@onready var _boss_bubble: SpeechBubble = _encounter.get_node("%BossBubble")
@onready var _boss_line: Label = _encounter.get_node("%BossLine")
@onready var _task_title: Label = _encounter.get_node("%TaskTitle")
@onready var _task_text: Label = _encounter.get_node("%TaskText")
@onready var _task_note: Label = _encounter.get_node("%TaskNote")
@onready var _encounter_button: Button = _encounter.get_node("%ActionButton")
# Lesen
@onready var _read_title: Label = _reading.get_node("%Title")
@onready var _read_author: Label = _reading.get_node("%Author")
@onready var _read_text: Label = _reading.get_node("%SourceText")
@onready var _read_scroll: ScrollContainer = _reading.get_node("%Scroll")
@onready var _write_button: Button = _reading.get_node("%WriteButton")
# Schreiben
@onready var _source_title: Label = _writing.get_node("%SourceTitle")
@onready var _source_text: Label = _writing.get_node("%SourceText")
@onready var _editor: TextEdit = _writing.get_node("%TextEdit")
@onready var _words: Label = _writing.get_node("%Words")
@onready var _target: Label = _writing.get_node("%Target")
@onready var _checks: VBoxContainer = _writing.get_node("%Checks")
@onready var _submit_button: Button = _writing.get_node("%SubmitButton")
@onready var _submit_note: Label = _writing.get_node("%SubmitNote")
@onready var _reread_button: Button = _writing.get_node("%ReadButton")
# Angriff
@onready var _attack_line: Label = _attack.get_node("%BossLine")
@onready var _charge: ProgressBar = _attack.get_node("%Charge")
@onready var _attack_rows: VBoxContainer = _attack.get_node("%Criteria")
@onready var _attack_note: Label = _attack.get_node("%Note")
@onready var _continue_button: Button = _attack.get_node("%ContinueButton")
# Überarbeiten
@onready var _hints_tab: Button = _revision.get_node("%HintsTab")
@onready var _source_tab: Button = _revision.get_node("%SourceTab")
@onready var _hints_scroll: ScrollContainer = _revision.get_node("%HintsScroll")
@onready var _source_scroll: ScrollContainer = _revision.get_node("%SourceScroll")
@onready var _revision_source: Label = _revision.get_node("%SourceText")
@onready var _revision_rows: VBoxContainer = _revision.get_node("%Criteria")
@onready var _marks_title: Label = _revision.get_node("%MarksTitle")
@onready var _marks: VBoxContainer = _revision.get_node("%Marks")
@onready var _no_marks: Label = _revision.get_node("%NoMarks")
@onready var _revision_editor: TextEdit = _revision.get_node("%TextEdit")
@onready var _revision_words: Label = _revision.get_node("%Words")
@onready var _resubmit_button: Button = _revision.get_node("%SubmitButton")

var _cloud: Node
var _highlighter := WritingMarkHighlighter.new()
## Wartet auf das Modell — solange gibt es keine zweite Abgabe.
var _pending := false
## Spielt gerade die Einblendung der Kriterien.
var _revealing := false
## Was zuletzt abgegeben wurde; das Urteil gehört zu diesem Text, nicht zum aktuellen.
var _submitted := ""
var _asked_at := 0
## Je Abgabe eine Nummer — eine verspätete Antwort auf eine verlassene Abgabe fällt weg.
var _ticket := 0
var _card: Dictionary = {}
var _warming := false
var _shout_tween: Tween
var _bar_tween: Tween
var _check_rows: Dictionary = {}
## Die Lexeme der Unit der Aufgabe und ihre Formen; leer = kein Bonus.
var _unit_lexemes: Array = []
var _unit_forms: Dictionary = {}
## Die Wörter der Unit in der abgegebenen Fassung.
var _submitted_words: Array = []
## Bis zum nächsten Fetzen (s); der zuletzt gemurmelte, damit keiner zweimal hintereinander kommt.
var _mumble_wait := MUMBLE_DELAY
var _mumble_last := -1
var _mumble_tween: Tween


func _ready() -> void:
	_mount_stage()
	_build_check_rows()
	_editor.syntax_highlighter = null
	_revision_editor.syntax_highlighter = _highlighter

	_back_button.pressed.connect(_ask_leave)
	_encounter_button.pressed.connect(_on_encounter_action)
	_write_button.pressed.connect(func() -> void: goto(Phase.WRITING))
	_reread_button.pressed.connect(func() -> void: goto(Phase.READING))
	_submit_button.pressed.connect(submit)
	_resubmit_button.pressed.connect(submit)
	_continue_button.pressed.connect(_on_continue)
	_editor.text_changed.connect(func() -> void: _on_text_edited(_editor))
	_revision_editor.text_changed.connect(func() -> void: _on_text_edited(_revision_editor))
	_check_timer.timeout.connect(_refresh_checks)
	_hints_tab.pressed.connect(func() -> void: _show_side(true))
	_source_tab.pressed.connect(func() -> void: _show_side(false))
	_confirm.confirmed.connect(_leave_now)

	if not fake_backend.is_valid():
		_cloud = CloudModelBackend.new()
		add_child(_cloud)

	var chosen := ContentRegistry.get_entry("bosses", BOSS_ID)
	begin(chosen, pick_task(chosen))
	# Erst im Dunkeln vorwärmen (FxWarmup-Prinzip), dann aus dem Dunkel heran (SceneZoom).
	_scene_zoom.hold()
	await _warm_up()
	if not is_inside_tree():
		return
	_scene_zoom.reveal(func(k: float) -> void: _scale_to(lerpf(SceneZoom.FROM, 1.0, k)))


## Die Bühne: was vor dem Einhängen gesetzt wurde, sonst RamblerStage. Sie liegt ganz
## hinten, alle Overlays darüber.
func _mount_stage() -> void:
	if stage == null and ResourceLoader.exists(STAGE_SCENE):
		stage = (load(STAGE_SCENE) as PackedScene).instantiate()
	if stage == null:
		stage = Node3D.new()
	if "stack_count" in stage:
		stage.set("stack_count", WritingJudge.CRITERIA.size())
	add_child(stage)
	move_child(stage, 0)


## Ein Auftrag an die Bühne. Was sie nicht kann, lässt sie aus — so läuft der Kampf auch
## mit einer Stub-Bühne im Test.
func _act(method: StringName, args: Array = []) -> void:
	if stage != null and stage.has_method(method):
		stage.callv(method, args)


func _warm_up() -> void:
	_warming = true
	var shout_size := _shout.size
	_shout.text = HIT_SHOUT + HOLD_SHOUT + WON_SHOUT
	_shout.modulate.a = 1.0
	if stage != null and stage.has_method(&"warm_up"):
		await stage.warm_up()
	_shout.modulate.a = 0.0
	_shout.text = ""
	_shout.size = shout_size
	_warming = false


func _scale_to(factor: float) -> void:
	pivot_offset = size * 0.5
	scale = Vector2(factor, factor)


## Die Spitze der Sprechblase folgt dem Mund von The Rambler, das Gemurmel steht darüber.
func _process(delta: float) -> void:
	if stage == null or not stage.has_method(&"mouth_on_screen"):
		return
	var mouth: Vector2 = stage.mouth_on_screen()
	if _encounter.visible and mouth != Vector2.INF:
		_boss_bubble.point_at(mouth)
	_tick_mumble(delta, mouth)


func _tick_mumble(delta: float, mouth: Vector2) -> void:
	if not phase in MUMBLE_PHASES:
		if _mumble.visible:
			_hush()
		return
	var seen := mouth != Vector2.INF and get_viewport_rect().has_point(mouth)
	if _mumble.visible and seen:
		_place_mumble(mouth)
	if not (seen and stage.has_method(&"is_peeking") and stage.is_peeking()):
		_mumble_wait = MUMBLE_DELAY
		return
	_mumble_wait -= delta
	if _mumble_wait <= 0.0:
		_mumble_wait = randf_range(MUMBLE_PAUSE.x, MUMBLE_PAUSE.y)
		_mutter(mouth)


## Ein Fetzen: kurz einblenden, stehen lassen, ausblenden.
func _mutter(mouth: Vector2) -> void:
	var pick := randi() % MUMBLES.size()
	if pick == _mumble_last:
		pick = (pick + 1) % MUMBLES.size()
	_mumble_last = pick
	_mumble_line.text = MUMBLES[pick]
	_mumble.reset_size()
	_mumble.visible = true
	_place_mumble(mouth)
	_mumble.pop()
	_act(&"mutter", [MUMBLE_TIME])
	if _mumble_tween != null:
		_mumble_tween.kill()
	_mumble_tween = create_tween()
	_mumble_tween.tween_property(_mumble, "modulate:a", 0.9, 0.3)
	_mumble_tween.tween_interval(MUMBLE_TIME)
	_mumble_tween.tween_property(_mumble, "modulate:a", 0.0, 0.6)
	_mumble_tween.tween_callback(func() -> void: _mumble.visible = false)


func _hush() -> void:
	if _mumble_tween != null:
		_mumble_tween.kill()
	_mumble.modulate.a = 0.0
	_mumble.visible = false


## Über das Maul, im Bild und unter der Kopfleiste; die Spitze zeigt hin.
func _place_mumble(mouth: Vector2) -> void:
	var view := get_viewport_rect().size
	var gap := _mumble.tail_length + 8.0  # Maul bis Blasenunterkante (px)
	var at := mouth - Vector2(_mumble.size.x * 0.5, _mumble.size.y + gap)
	at.x = clampf(at.x, 8.0, maxf(8.0, view.x - _mumble.size.x - 8.0))
	at.y = maxf(at.y, _back_button.get_global_rect().end.y + 8.0)
	_mumble.global_position = at
	_mumble.point_at(mouth)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_ask_leave()
		return
	# Strg+Enter gibt ab — das Schreibfeld braucht Enter für Absätze.
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.ctrl_pressed \
			and (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER) \
			and (phase == Phase.WRITING or phase == Phase.REVISION):
		get_viewport().set_input_as_handled()
		submit()


# --- Auswahl ----------------------------------------------------------------------------

## Eine Schreibaufgabe aus der Regel des Bosses über dem Bereich des Laufs (RunRequest).
static func pick_task(the_boss: Dictionary) -> Dictionary:
	var tasks := tasks_in_scope(the_boss, RunRequest.scope())
	if tasks.is_empty():
		return {}
	return tasks[randi() % tasks.size()]


## Alle Schreibaufgaben der Textart des Bosses im Scope. Leerer Scope heißt wie überall:
## keine Einschränkung. Ein Buch-Schlüssel nimmt alle Units des Buchs, ein Teil-Schlüssel
## („<book>/<unit>/<teil>“) die ganze Unit — eine Vorlage gehört zu einer Unit, nicht zu
## ihren Seiten.
static func tasks_in_scope(the_boss: Dictionary, scope: Array) -> Array:
	if the_boss.is_empty():
		return []
	var rule: Dictionary = the_boss.get("writing_rule", {})
	var kind := str(rule.get("kind", DEFAULT_KIND))
	var out: Array = []
	var seen := {}
	var candidates: Array = []
	if scope.is_empty():
		candidates = ContentRegistry.writing.values()
	else:
		for key in scope:
			var parts := str(key).split("/")
			if parts.size() == 1:
				for entry in ContentRegistry.writing.values():
					if str(entry.get("book", "")) == parts[0]:
						candidates.append(entry)
			else:
				candidates.append_array(ContentRegistry.writing_tasks(parts[0], int(parts[1]), kind))
	for entry in candidates:
		var id := str(entry.get("id", ""))
		if str(entry.get("kind", "")) != kind or seen.has(id):
			continue
		seen[id] = true
		out.append(entry)
	out.sort_custom(func(a, b): return str(a.get("id", "")) < str(b.get("id", "")))
	return out


## Gibt es The Rambler gerade? Nur mit eigenem Schlüssel (ADR 0023, Abschnitt 1) und
## einer Schreibaufgabe im Bereich des Laufs — sonst ist sein Knopf unsichtbar.
static func can_start() -> bool:
	return can_start_with(ApiKeys.available(), RunRequest.scope())


static func can_start_with(has_key: bool, scope: Array) -> bool:
	if not has_key:
		return false
	return not tasks_in_scope(ContentRegistry.get_entry("bosses", BOSS_ID), scope).is_empty()


# --- Ablauf -----------------------------------------------------------------------------

## Stellt den Kampf auf. Die Naht für Tests und Werkbank: ein erfundener Boss mit einer
## erfundenen Aufgabe, statt dem, was auf diesem Rechner installiert ist.
func begin(the_boss: Dictionary, the_task: Dictionary) -> void:
	_ticket += 1
	boss = the_boss
	task = the_task
	text = ""
	rounds = 0
	fallen = {}
	bonus = false
	unit_words = []
	_submitted_words = []
	_unit_lexemes = UnitWords.lexemes_for(task) if not task.is_empty() else []
	_unit_forms = UnitWords.forms_for(_unit_lexemes)
	last_criteria = []
	last_note = ""
	_pending = false
	_revealing = false
	_card = {}
	_boss_name.text = str(boss.get("name", "The Rambler"))
	_set_text_silently(_editor, "")
	_set_text_silently(_revision_editor, "")
	_act(&"restore_all")
	_render_stacks()
	_fill_task()
	_refresh_checks()
	if task.is_empty():
		goto(Phase.EMPTY)
		return
	if emit_events:
		EventBus.boss_started.emit(str(boss.get("id", BOSS_ID)))
	goto(Phase.ENCOUNTER)


func _fill_task() -> void:
	var title := str(task.get("title", "—"))
	var author := str(task.get("author", ""))
	var source := str(task.get("text", ""))
	_task_title.text = "„%s“%s" % [title, "" if author.is_empty() else " von " + author]
	_task_text.text = TASK_TEXT % _target_text()
	_task_note.text = TASK_NOTE
	_read_title.text = title
	_read_author.text = "%s · %s" % [author, str(task.get("genre", ""))] if not author.is_empty() else ""
	_read_text.text = source
	_source_title.text = "„%s“ – %s" % [title, author] if not author.is_empty() else title
	_source_text.text = source
	_revision_source.text = source
	_target.text = "Ziel: " + _target_text()


func _target_text() -> String:
	var target: Array = Array(task.get("target_words", []))
	if target.size() != 2:
		return "beliebig viele Wörter"
	return "%d–%d Wörter" % [int(target[0]), int(target[1])]


## Wechselt das Overlay. Die Bühne bleibt, nur The Rambler tritt vor oder zurück.
func goto(next: Phase) -> void:
	phase = next
	_encounter.visible = next in [Phase.ENCOUNTER, Phase.VICTORY, Phase.EMPTY]
	_reading.visible = next == Phase.READING
	_writing.visible = next == Phase.WRITING
	_attack.visible = next == Phase.ATTACK
	_revision.visible = next == Phase.REVISION
	match next:
		Phase.ENCOUNTER:
			_round_label.text = "Begegnung"
			_boss_line.text = ENCOUNTER_TEXT
			_encounter_button.text = "📖 Geschichte lesen"
			_encounter_button.disabled = false
			_task_note.visible = true
			_act(&"set_focus", [true])
			_act(&"speak")
			_boss_bubble.pop()
			_focus(_encounter_button)
		Phase.EMPTY:
			_round_label.text = "—"
			_boss_line.text = EMPTY_TEXT
			_task_title.text = "—"
			_task_text.text = ""
			_task_note.visible = false
			_encounter_button.text = "← Zurück"
			_encounter_button.disabled = false
			_act(&"set_focus", [true])
		Phase.READING:
			_round_label.text = "Lesen"
			_read_scroll.scroll_vertical = 0
			_act(&"set_focus", [false])
			_focus(_write_button)
		Phase.WRITING:
			_round_label.text = "Schreiben"
			_set_text_silently(_editor, text)
			_refresh_checks()
			_act(&"set_focus", [false])
			_focus(_editor)
		Phase.ATTACK:
			_round_label.text = "Angriff %d" % (rounds + 1)
			_act(&"set_focus", [true])
		Phase.REVISION:
			_round_label.text = "Überarbeiten"
			_set_text_silently(_revision_editor, text)
			_show_side(true)
			_render_revision()
			_refresh_checks()
			_act(&"set_focus", [false])
			_focus(_revision_editor)
		Phase.VICTORY:
			_round_label.text = "Besiegt"
			_boss_line.text = WON_TEXT
			_task_title.text = WON_TITLE
			_task_text.text = "Abgaben: %d" % rounds
			if bonus:
				_task_text.text += " · ✨ %s: %d Wörter aus der Unit" \
						% [BONUS_NAME, _submitted_words.size()]
			_task_note.visible = false
			_encounter_button.text = "← Zurück"
			_encounter_button.disabled = false
			_boss_bubble.pop()
			_focus(_encounter_button)


func _focus(control: Control) -> void:
	if is_visible_in_tree():
		control.grab_focus.call_deferred()


func _on_encounter_action() -> void:
	match phase:
		Phase.ENCOUNTER:
			goto(Phase.READING)
		_:
			_leave_now()


# --- Schreiben --------------------------------------------------------------------------

func _set_text_silently(edit: TextEdit, value: String) -> void:
	if edit.text != value:
		edit.text = value


func _on_text_edited(edit: TextEdit) -> void:
	text = edit.text
	_check_timer.start()


## Die Zeilen der Randleiste — einmal aus der Vorlage, danach nur noch beschriftet.
func _build_check_rows() -> void:
	for id in ["length", "unit_words"]:
		var row: WritingCriterionRow = CRITERION_ROW.instantiate()
		_checks.add_child(row)
		_check_rows[id] = row


## Wortzahl und Länge, wie sie gerade stehen. Läuft entprellt nach dem Tippen.
func _refresh_checks() -> void:
	if task.is_empty():
		return
	_card = SummaryCard.check(task, text)
	var words := int(_card.get("words", 0))
	var length_ok := bool(_card.get("length_ok", false))
	_words.text = "%d Wörter" % words
	_revision_words.text = "%d Wörter · Ziel: %s" % [words, _target_text()]
	var target: Array = Array(task.get("target_words", []))
	var length_detail := ""
	if not length_ok and target.size() == 2:
		length_detail = "Noch zu kurz." if words < int(target[0]) else "Zu lang – fasse knapper zusammen."
	_row(_check_rows["length"], length_ok, "Länge", length_detail)
	unit_words = UnitWords.found(text, _unit_lexemes, _unit_forms)
	var words_row: WritingCriterionRow = _check_rows["unit_words"]
	words_row.visible = has_bonus()
	if has_bonus():
		_row(words_row, bonus or unit_words.size() >= UNIT_WORD_GOAL, "Wörter der Unit",
				_bonus_detail(unit_words.size()))


## Die Naht für Tests und Werkbank: erfundene Lexeme der Unit statt der installierten.
func use_unit_lexemes(lexemes: Array, forms: Dictionary = {}) -> void:
	_unit_lexemes = lexemes
	_unit_forms = forms
	_refresh_checks()


## Gibt es zu dieser Aufgabe einen Wortschatz-Bonus? Nur mit Lexemen der Unit.
func has_bonus() -> bool:
	return not _unit_lexemes.is_empty()


## Was die Zeile zum Bonus sagt, bei `count` Wörtern der Unit.
func _bonus_detail(count: int) -> String:
	if bonus:
		return "Bonus erreicht (%d Wörter)." % count
	if count < UNIT_WORD_GOAL:
		return "%d von %d – benutze Wörter aus der Unit." % [count, UNIT_WORD_GOAL]
	if not fallen.has("content"):
		return "%d – der Bonus zählt, sobald der Inhalt stimmt." % count
	return "%d – gib ab, dann zählt der Bonus." % count


## Eine Prüfzeile: erfüllt ✔, offen ○.
func _row(row: WritingCriterionRow, ok: bool, title: String, detail: String) -> void:
	row.show_row("✔" if ok else "○", title, detail)


# --- Angriff ----------------------------------------------------------------------------

## Gibt den Text ab. Leer gibt es nichts zu bewerten; während The Rambler noch urteilt,
## gibt es keine zweite Abgabe.
func submit() -> void:
	if _pending or _revealing or task.is_empty():
		return
	if not (phase == Phase.WRITING or phase == Phase.REVISION):
		return
	if text.strip_edges().is_empty():
		_submit_note.text = EMPTY_TEXT_NOTE
		return
	_submit_note.text = "Strg+Enter gibt ab."
	_submitted = text
	_card = SummaryCard.check(task, _submitted)
	_submitted_words = UnitWords.found(_submitted, _unit_lexemes, _unit_forms)
	_pending = true
	_ticket += 1
	var ticket := _ticket
	_asked_at = Time.get_ticks_msec()
	goto(Phase.ATTACK)
	_attack_line.text = CHARGE_TEXT
	_attack_note.text = ""
	_charge.indeterminate = true
	_continue_button.disabled = true
	_continue_button.text = "⚡ Lädt auf …"
	_fill_attack_rows()
	_act(&"speak")
	var done := func(reply: Dictionary) -> void: _on_reply(ticket, reply)
	if fake_backend.is_valid():
		fake_backend.call(task, _submitted, done)
	else:
		_cloud.judge_summary(task, _submitted, done)


## Wartet The Rambler noch auf das Modell?
func pending() -> bool:
	return _pending


func _on_reply(ticket: int, reply: Dictionary) -> void:
	if ticket != _ticket or not is_inside_tree():
		return
	_pending = false
	_charge.indeterminate = false
	var result: Dictionary = reply.get("result", {})
	if result.is_empty():
		# Auch ein unbrauchbares Urteil kann Token gekostet haben (ADR 0023, Abschnitt 7).
		if _billed(reply):
			_log(reply, true)
		_fail(str(reply.get("note", "")))
		return
	last_note = ""
	rounds += 1
	last_criteria = WritingJudge.criteria(task, _submitted, _card, result)
	_log(reply)
	_reveal(last_criteria)


## Kein Urteil: der Dienst antwortete nicht oder nicht brauchbar. Der Text bleibt, die
## Abgabe zählt nicht.
func _fail(note: String) -> void:
	last_note = note if not note.is_empty() else FAILED_DEFAULT
	_attack_line.text = NO_VERDICT_TEXT
	_attack_note.text = FAILED_NOTE % last_note
	_charge.value = 0.0
	_fill_attack_rows()
	_continue_button.disabled = false
	_continue_button.text = "✍ Zurück zum Text"
	_act(&"gloat")
	_focus(_continue_button)


## Je gewertete Abgabe ein Eintrag mit dem Verbrauch (ADR 0023, Abschnitt 7) — kein Text,
## kein Schlüssel.
func _log(reply: Dictionary, failed := false) -> void:
	var usage: Dictionary = reply.get("usage", {})
	var met: Array = []
	if not failed:
		for c in last_criteria:
			if bool(c.get("met", false)):
				met.append(str(c.get("id", "")))
	var seconds := float(usage.get("seconds", (Time.get_ticks_msec() - _asked_at) / 1000.0))
	var entry := {
		"at": int(Time.get_unix_time_from_system()),
		"boss": str(boss.get("id", BOSS_ID)),
		"task": str(task.get("id", "")),
		"round": rounds,
		"model": str(usage.get("model", "")),
		"in": int(usage.get("input_tokens", 0)),
		"out": int(usage.get("output_tokens", 0)),
		"cr": int(usage.get("cache_read_input_tokens", 0)),
		"cw": int(usage.get("cache_creation_input_tokens", 0)),
		"s": snappedf(seconds, 0.1),
		"met": met,
		"words": int(_card.get("words", 0)),
		"failed": failed,
		"kind": "summary",
		"unit_words": _submitted_words.size(),
	}
	if record:
		WritingLog.record(entry, _profile())
	if emit_events:
		EventBus.writing_submitted.emit(entry)


## Hat der Anbieter für diese Antwort etwas berechnet?
static func _billed(reply: Dictionary) -> bool:
	var usage: Dictionary = reply.get("usage", {})
	return int(usage.get("input_tokens", 0)) + int(usage.get("output_tokens", 0)) > 0


func _profile() -> String:
	return log_profile if not log_profile.is_empty() else UserSettings.active_profile()


## Die Kriterienzeilen beim Angriff; ohne Urteil mit „…“.
func _fill_attack_rows() -> void:
	for child in _attack_rows.get_children():
		_attack_rows.remove_child(child)
		child.queue_free()
	for id in WritingJudge.CRITERIA:
		var row: WritingCriterionRow = CRITERION_ROW.instantiate()
		_attack_rows.add_child(row)
		row.show_row("📄" if not fallen.has(id) else "✔", CRITERION_NAMES.get(id, id),
				"schon gefallen" if fallen.has(id) else "")
	if has_bonus():
		var bonus_row: WritingCriterionRow = CRITERION_ROW.instantiate()
		_attack_rows.add_child(bonus_row)
		bonus_row.show_row("✨" if bonus else "○", BONUS_NAME, "schon erreicht" if bonus else "")


## Kriterium für Kriterium: Stapel fällt oder hält. Mit `reveal_step` 0 alles auf einmal.
func _reveal(criteria: Array) -> void:
	_revealing = true
	_attack_line.text = "…"
	var dropped := 0
	var ticket := _ticket
	for i in criteria.size():
		if reveal_step > 0.0:
			await get_tree().create_timer(reveal_step).timeout
			if not is_inside_tree() or ticket != _ticket:
				return
		if _reveal_one(i, criteria[i]):
			dropped += 1
	if has_bonus():
		if reveal_step > 0.0:
			await get_tree().create_timer(reveal_step).timeout
			if not is_inside_tree() or ticket != _ticket:
				return
		_reveal_bonus()
	_revealing = false
	_attack_line.text = HIT_TEXT if dropped > 0 else HOLD_TEXT
	_continue_button.disabled = false
	_continue_button.text = "🏆 Weiter" if won() else "✍ Überarbeiten"
	_focus(_continue_button)


## Ein Kriterium. Gibt zurück, ob dabei ein Stapel fiel.
func _reveal_one(index: int, criterion: Dictionary) -> bool:
	var id := str(criterion.get("id", ""))
	var row := _attack_rows.get_child(index) as WritingCriterionRow
	var name := str(CRITERION_NAMES.get(id, id))
	if fallen.has(id):
		row.show_row("✔", name, "schon gefallen")
		return false
	if not bool(criterion.get("decided", true)):
		row.show_row("–", name, "kein Urteil")
		_act(&"hold_stack", [index])
		return false
	if bool(criterion.get("met", false)):
		fallen[id] = true
		row.show_row("✔", name, "Stapel fällt!")
		_act(&"drop_stack", [index])
		_render_stacks()
		_cheer(HIT_SHOUT, HIT_SHOUT_TINT)
		_flash.modulate.a = 1.0
		create_tween().tween_property(_flash, "modulate:a", 0.0, 0.4)
		Sfx.play(&"monster_kill")
		return true
	row.show_row("✖", name, "hält")
	_act(&"hold_stack", [index])
	_cheer(HOLD_SHOUT, HOLD_SHOUT_TINT)
	return false


## Der Wortschatz-Bonus nach den Kriterien: erreicht, sobald die Abgabe genug Wörter der
## Unit hat und der Inhalt stimmt.
func _reveal_bonus() -> void:
	var row := _attack_rows.get_child(_attack_rows.get_child_count() - 1) as WritingCriterionRow
	var count := _submitted_words.size()
	if bonus:
		row.show_row("✨", BONUS_NAME, "schon erreicht")
		return
	if count >= UNIT_WORD_GOAL and fallen.has("content"):
		bonus = true
		row.show_row("✨", BONUS_NAME, "%d Wörter aus der Unit!" % count)
		_cheer(BONUS_SHOUT, BONUS_SHOUT_TINT)
		Sfx.play(&"monster_kill")
		return
	row.show_row("○", BONUS_NAME, _bonus_detail(count))


func _on_continue() -> void:
	if _pending or _revealing:
		return
	if won():
		_win()
	elif rounds == 0:
		goto(Phase.WRITING)
	else:
		goto(Phase.REVISION)


# --- Überarbeiten -----------------------------------------------------------------------

## Die Hinweise der letzten Abgabe: was noch hält (mit seiner Regel) und die markierten
## Stellen der Kriterien, die noch hängen.
func _render_revision() -> void:
	for child in _revision_rows.get_children() + _marks.get_children():
		child.get_parent().remove_child(child)
		child.queue_free()
	var quotes: Array = []
	for criterion in last_criteria:
		var id := str(criterion.get("id", ""))
		var row: WritingCriterionRow = CRITERION_ROW.instantiate()
		_revision_rows.add_child(row)
		var name := str(CRITERION_NAMES.get(id, id))
		if fallen.has(id):
			row.show_row("✔", name, "")
			continue
		if not bool(criterion.get("decided", true)):
			row.show_row("–", name, "Darüber hat er diesmal nicht geurteilt.")
			continue
		row.show_row("📄", name, _rule_for(id))
		for mark in criterion.get("marks", []):
			var quote := str(mark.get("quote", ""))
			if quote.is_empty():
				continue
			var mark_row: WritingMarkRow = MARK_ROW.instantiate()
			_marks.add_child(mark_row)
			mark_row.show_mark(quote, str(mark.get("hint", "")))
			mark_row.picked.connect(_select_quote)
			quotes.append(quote)
	if has_bonus():
		var bonus_row: WritingCriterionRow = CRITERION_ROW.instantiate()
		_revision_rows.add_child(bonus_row)
		bonus_row.show_row("✨" if bonus else "○", BONUS_NAME,
				_bonus_detail(_submitted_words.size()))
	_highlighter.set_quotes(quotes)
	_marks_title.visible = not quotes.is_empty()
	_no_marks.visible = quotes.is_empty()


func _rule_for(id: String) -> String:
	if id != "length":
		return str(CRITERION_RULES.get(id, ""))
	var target: Array = Array(task.get("target_words", []))
	if target.size() != 2:
		return ""
	return CRITERION_RULES["length"] % [int(target[0]), int(target[1]),
			SummaryCard.split_words(_submitted).size()]


## Wählt eine markierte Stelle im Schreibfeld aus — die erste, die dort noch steht.
func _select_quote(quote: String) -> void:
	var low := quote.to_lower()
	for line in _revision_editor.get_line_count():
		var at := _revision_editor.get_line(line).to_lower().find(low)
		if at != -1:
			_revision_editor.select(line, at, line, at + quote.length())
			_revision_editor.set_caret_line(line)
			_revision_editor.set_caret_column(at + quote.length())
			_revision_editor.grab_focus()
			return


## Links entweder die Hinweise oder die Geschichte; beide füllen denselben Platz.
func _show_side(hints: bool) -> void:
	_hints_scroll.visible = hints
	_source_scroll.visible = not hints
	_hints_tab.set_pressed_no_signal(hints)
	_source_tab.set_pressed_no_signal(not hints)


# --- Sieg und Ausgang -------------------------------------------------------------------

## Sind alle Stapel gefallen?
func won() -> bool:
	return fallen.size() >= WritingJudge.CRITERIA.size()


func _win() -> void:
	goto(Phase.VICTORY)
	_act(&"fall")
	_cheer(WON_SHOUT, HIT_SHOUT_TINT)
	Sfx.play(&"wave_cleared")
	if emit_events:
		EventBus.boss_ended.emit(str(boss.get("id", BOSS_ID)), true)
	_record_win()


## Ein Sieg am Ende einer Unit zählt auf der Karte (ADR 0006); einer aus dem Expertenmodus
## gehört zu keiner Unit.
func _record_win() -> void:
	var unit := RunRequest.unit_key()
	if unit.is_empty() or not record:
		return
	BossRecord.record_win(unit, UserSettings.active_profile())
	if emit_events:
		EventBus.boss_won.emit(str(boss.get("id", BOSS_ID)), unit)


## Verlassen mit Text fragt nach — der Text ginge verloren.
func _ask_leave() -> void:
	if _scene_zoom.is_running() or _warming or _confirm.visible:
		return
	if phase != Phase.VICTORY and not text.strip_edges().is_empty():
		_confirm.ask(LEAVE_TITLE, LEAVE_BODY, "Verlassen", "Weiterschreiben")
		return
	_leave_now()


func _leave_now() -> void:
	if _scene_zoom.is_running() or _warming:
		return
	_ticket += 1
	_pending = false
	if on_leave.is_valid():
		on_leave.call()
		return
	MapSelection.zoom_out = RunRequest.is_level()
	_scene_zoom.cover(func(k: float) -> void: _scale_to(lerpf(1.0, SceneZoom.FROM, k)))
	await _scene_zoom.finished
	get_tree().change_scene_to_file(RunRequest.return_scene())


# --- Anzeige ----------------------------------------------------------------------------

func _render_stacks() -> void:
	var total := WritingJudge.CRITERIA.size()
	var left := total - fallen.size()
	_stack_label.text = "📄 %d/%d" % [left, total]
	_stack_bar.max_value = total
	if _bar_tween != null:
		_bar_tween.kill()
	_bar_tween = create_tween()
	_bar_tween.tween_property(_stack_bar, "value", float(left), 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Der Ausruf in der Bildmitte: ploppt auf, steht kurz, verfliegt.
func _cheer(shout: String, tint: Color) -> void:
	if _shout_tween != null:
		_shout_tween.kill()
	_shout.text = shout
	_shout.pivot_offset = _shout.size / 2.0
	_shout.scale = Vector2.ONE * 0.4
	_shout.modulate = Color(tint.r, tint.g, tint.b, 1.0)
	_shout.rotation = randf_range(-0.12, 0.12)
	_shout_tween = create_tween()
	_shout_tween.tween_property(_shout, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_shout_tween.tween_interval(0.4)
	_shout_tween.tween_property(_shout, "modulate:a", 0.0, 0.3)
