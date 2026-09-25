extends Control
## Der Bosskampf (scenes/battle/boss_fight.tscn) — docs/adr/0005-bosskampf-mit-erklaerung.md.
##
## Der Satzmeister stellt fünf Sätze aus seiner `sentence_rule` über der Auswahl des
## Profils. Jeder Treffer kostet ihn 1 HP; ist er bei 0, ist er besiegt, sind die Sätze
## vorher aus, zieht er ab. Kein Zeitdruck und keine Strafe — und vorerst auch kein Gold,
## keine Erfahrung und kein Lernstand (ADR 0005, Entscheidung 6).
##
## Bewertet wird über SentenceJudge, also in Stufen:
##
##     Prüfkarte sicher      ─► Ergebnis sofort
##     Prüfkarte unsicher    ─► Modell urteilt (3–7 s auf der CPU), Ergebnis sofort danach
##                              └─ „falsch" ─► die Erklärung kommt nach, „Weiter" ist schon frei;
##                                 Rückmeldung und Musterlösung erst mit ihr
##     kein Modell / Zeitlimit ─► kein Treffer, Musterlösung
##
## **Die Musterlösung steht nach jedem Urteil da**, auch nach einem Treffer — nur nicht
## VOR der Erklärung: rechnet die noch, kommt sie mit ihr. Ein leerer Versuch zeigt sie nie,
## sonst holte man sie sich mit Enter.
##
## **Der Dienst startet beim Betreten und endet beim Verlassen** (LocalModelServer hängt
## als Kind an dieser Szene und beendet ihn in seinem _exit_tree). Solange er lädt, ist
## „Angreifen" gesperrt und beschriftet; der erste Satz steht schon da.
##
## **Die Szene ändert ihre Größe nicht, solange sie sichtbar ist**: jedes Feld ist immer da,
## es wird gesperrt und umbeschriftet statt ein- und ausgeblendet, und das Ergebnis steht in
## einem Rollbereich fester Höhe.
##
## **Zu sehen ist ein Kampf, keine Werkbank** (für die ist scenes/dev/boss_lab.tscn da): der
## Spieler steht im Gewölbe und schaut das Skelett an (BossStage). Was der Boss sagt, steht
## in seinen Sprechblasen — oben der Satz, rechts die Erklärung —, was der Spieler tippt, in
## seiner eigenen unten. Treffer und Fehlschläge spielt die Bühne vor; dazu ein Ausruf in
## der Bildmitte. Aufploppen und Ausblenden gehen über `scale` und `modulate`, nie über die
## Größe: das Layout steht still, auch wenn die Blasen es nicht tun.

const MENU_SCENE := "res://scenes/ui/profile_menu.tscn"
const SELF_SCENE := "res://scenes/battle/boss_fight.tscn"
const BOSS_ID := "boss.grammar_golem"

## Ab welcher Güte eine Antwort den Satzmeister trifft. Ein Volltreffer (1,0) und ein Treffer mit
## weggelassener Kleinigkeit (0,7) treffen, eine Stolperstelle (0,35) nicht.
const HIT_QUALITY := 0.6
## Wie viele Sätze, wenn der Boss es nicht selbst sagt.
const DEFAULT_COUNT := 5
## Wie viel HP, wenn der Boss es nicht selbst sagt.
const DEFAULT_HP := 3

## Was der Boss sagt — in seiner Blase, also in der Ich-Form.
const WAKING_TEXT := "Wer stört meinen Schlaf …? Warte, gleich bin ich wach."
const IDLE_TEXT := "Übersetze das, wenn du kannst!"
const THINKING_TEXT := "Hmm … lass mich sehen …"
const EXPLAINING_TEXT := "Moment, ich schreibe dir auf, was nicht stimmt …"
const HIT_LINES := ["Autsch! Das saß.", "Uff! Meine Knochen klappern!", "Nein! Das war richtig!"]
const MISS_LINES := ["Ha! Daneben!", "Knapp vorbei, hehe!", "Das bringt mich nicht zu Fall!"]
const NO_VERDICT_TEXT := "Das kann ich nicht beurteilen — das zählt nicht als Treffer."
const WON_TEXT := "Neiiin … ich zerfalle zu Staub! Du hast gewonnen!"
const LOST_TEXT := "Meine Sätze sind aus. Beim nächsten Mal kriege ich dich!"
## Die große Zeile in der Blase, wenn der Kampf vorbei ist.
const WON_FAREWELL := "🏆 Du hast den Satzmeister besiegt!"
const LOST_FAREWELL := "💨 Er ist fort — für diesmal."
## Der Ausruf in der Bildmitte.
const HIT_SHOUT := "TREFFER!"
const MISS_SHOUT := "DANEBEN!"
const WON_SHOUT := "SIEG!"
const HIT_SHOUT_TINT := Color(1.0, 0.86, 0.3)
const MISS_SHOUT_TINT := Color(0.65, 0.85, 1.0)
const EMPTY_POOL_TEXT := "Für den Satzmeister passt kein Satz zu deiner Auswahl. Wähle unter „▶ Spielen“ mehr Units aus."
const NO_MODEL_NOTE := "Ohne Sprachmodell zählt nur, was als Lösung hinterlegt ist. Das Modell gibt es unter „📚 Inhalte“."
const MODEL_NOTE := "Das Sprachmodell läuft auf diesem Rechner; nichts verlässt ihn."
const FAILED_MODEL_NOTE := "Das Sprachmodell ließ sich nicht starten — es zählt nur, was als Lösung hinterlegt ist."

## Ob beim Betreten der lokale Dienst gestartet wird. Aus für Tests: kein Test startet
## llama-server. Vor dem Einhängen setzen.
var start_service := true
## Für Tests: ein erfundenes Stufe-1-Backend statt LocalModelBackend. Vor dem Einhängen setzen.
var fake_backend: Callable = Callable()
var fake_explainer: Callable = Callable()

var boss: Dictionary = {}
var sentences: Array = []
var hp := 0
var max_hp := 0
var index := 0
var hits := 0

@onready var _stage: BossStage = %Stage
@onready var _boss_bubble: SpeechBubble = %BossBubble
@onready var _result_bubble: SpeechBubble = %ResultBubble
@onready var _player_bubble: SpeechBubble = %PlayerBubble
@onready var _hp_bar: ProgressBar = %HpBar
@onready var _flash: ColorRect = %Flash
@onready var _shout: Label = %Shout
@onready var _back_button: Button = %BackButton
@onready var _boss_name: Label = %BossName
@onready var _hp_label: Label = %HpLabel
@onready var _golem_line: Label = %GolemLine
@onready var _round_label: Label = %RoundLabel
@onready var _source_text: Label = %SourceText
@onready var _answer_edit: LineEdit = %AnswerEdit
@onready var _submit_button: Button = %SubmitButton
@onready var _verdict_label: Label = %VerdictLabel
@onready var _explanation_label: Label = %ExplanationLabel
@onready var _reference_label: Label = %ReferenceLabel
@onready var _model_note: Label = %ModelNote
@onready var _next_button: Button = %NextButton

var _judge: SentenceJudge
var _backend: LocalModelBackend
var _server: LocalModelServer
## Der Dienst lädt noch — solange nimmt der Satzmeister keine Antwort an.
var _waking := false
## Diese Runde ist entschieden; „Weiter" führt zum nächsten Satz.
var _decided := false
var _over := false
var _answer := ""
var _hp_tween: Tween
var _shout_tween: Tween
var _result_shown := false


func _ready() -> void:
	_judge = SentenceJudge.new()
	add_child(_judge)
	_judge.refined.connect(_on_refined)
	_judge.denied.connect(_on_denied)
	_judge.explained.connect(_on_explained)
	_judge.gave_up.connect(_on_gave_up)

	_back_button.pressed.connect(_leave)
	_submit_button.pressed.connect(_submit)
	_answer_edit.text_submitted.connect(func(_t: String): _submit())
	_next_button.pressed.connect(_next)

	var chosen := ContentRegistry.get_entry("bosses", BOSS_ID)
	begin(chosen, pick_sentences(chosen))
	_attach_stage_one()


## Die Spitzen der Boss-Blasen folgen seinem Kopf.
func _process(_delta: float) -> void:
	var mouth := _stage.mouth_on_screen()
	if mouth != Vector2.INF:
		_boss_bubble.point_at(mouth)
		_result_bubble.point_at(mouth)


func _input(event: InputEvent) -> void:
	# Escape führt zurück ins Menü — dieselbe Geste wie im Kampf.
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_leave()


## Die Sätze des Kampfes: aus der Regel des Bosses über der Auswahl des Profils, ohne
## Wiederholung, gewichtet nach dem Netto-Maß wie im Wave-Pool.
static func pick_sentences(the_boss: Dictionary) -> Array:
	var rule: Dictionary = the_boss.get("sentence_rule", {})
	var count := int(rule.get("count", DEFAULT_COUNT))
	var pool := SentenceSelector.pool_for_boss(the_boss)
	var selector := SentenceSelector.new()
	var used := {}
	var out: Array = []
	for i in count:
		var sentence := selector.pick(pool, used)
		if sentence.is_empty():
			break
		used[str(sentence.get("id", ""))] = true
		out.append(sentence)
	return out


## Stellt den Kampf auf. Die Naht für Tests: ein erfundener Boss mit erfundenen Sätzen,
## statt dem, was auf diesem Rechner installiert ist.
func begin(the_boss: Dictionary, the_sentences: Array) -> void:
	boss = the_boss
	sentences = the_sentences
	max_hp = maxi(1, int(boss.get("hp", DEFAULT_HP)))
	hp = max_hp
	index = 0
	hits = 0
	_over = false
	_boss_name.text = str(boss.get("name", "Boss"))
	_hp_bar.max_value = max_hp
	_render_hp()
	_stage.wake()
	_show_result(false)
	if sentences.is_empty():
		_over = true
		_golem_line.text = EMPTY_POOL_TEXT
		_round_label.text = ""
		_source_text.text = "—"
		_lock_answer("⚔ Angreifen")
		_next_button.disabled = true
		return
	EventBus.boss_started.emit(str(boss.get("id", "")))
	_present()


## Hängt Stufe 1 ein und startet — wenn installiert — den Dienst.
func _attach_stage_one() -> void:
	if fake_backend.is_valid():
		_judge.model_backend = fake_backend
		_judge.explainer = fake_explainer
		_model_note.text = MODEL_NOTE
		return
	_backend = LocalModelBackend.new()
	add_child(_backend)
	if not start_service or not ModelService.installed():
		_model_note.text = NO_MODEL_NOTE
		return
	_server = LocalModelServer.new()
	add_child(_server)
	_backend.url = _server.url()
	_waking = true
	_model_note.text = ""
	_render_answer_gate()
	var started := await _server.start()
	_waking = false
	if not is_inside_tree():
		return
	if started:
		_judge.model_backend = _backend.judge
		_judge.explainer = _backend.explain
		_model_note.text = MODEL_NOTE
	else:
		_model_note.text = FAILED_MODEL_NOTE
	_render_answer_gate()


## Zeigt den aktuellen Satz.
func _present() -> void:
	var sentence: Dictionary = sentences[index]
	_decided = false
	_answer = ""
	_round_label.text = "Satz %d von %d" % [index + 1, sentences.size()]
	_source_text.text = str(sentence.get("source_text", "—"))
	_verdict_label.text = ""
	_explanation_label.text = ""
	_reference_label.text = ""
	_answer_edit.text = ""
	_next_button.disabled = true
	_next_button.text = "Weiter"
	_render_answer_gate()
	_stage.resume()
	_boss_bubble.pop()
	_show_result(false)
	EventBus.boss_sentence_presented.emit(sentence)


## Sperrt oder öffnet die Eingabe je nach Zustand — und beschriftet den Knopf so, dass er
## sagt, worauf gewartet wird.
func _render_answer_gate() -> void:
	if _over or _decided:
		return
	if _waking:
		_golem_line.text = WAKING_TEXT
		_lock_answer("💤 Er erwacht …")
	elif _judge.pending():
		_golem_line.text = THINKING_TEXT
		_lock_answer("🤔 Er prüft …")
		_stage.listen()
		_boss_bubble.wobble(true)
	else:
		_golem_line.text = IDLE_TEXT
		_answer_edit.editable = true
		_submit_button.disabled = false
		_submit_button.text = "⚔ Angreifen"
		if is_visible_in_tree():
			_answer_edit.grab_focus()


func _lock_answer(label: String) -> void:
	_answer_edit.editable = false
	_submit_button.disabled = true
	_submit_button.text = label


func _submit() -> void:
	if _over or _decided or _waking or _judge.pending():
		return
	var typed := _answer_edit.text.strip_edges()
	if typed.is_empty():
		# Nichts getippt ist kein Versuch: der Satz bleibt stehen.
		_verdict_label.text = SentenceCard.EMPTY_FEEDBACK
		_show_result(true)
		return
	_answer = typed
	var card := _judge.judge(sentences[index], typed)
	if bool(card.get("sure", true)):
		_decide(card)
	elif _judge.pending():
		_verdict_label.text = ""
		_render_answer_gate()
	else:
		# Kein Modell: die Karte hat kein Urteil, und ohne Urteil gibt es keinen Treffer.
		_decide(card, NO_VERDICT_TEXT)


## Die Runde ist entschieden. `headline` überschreibt die Zeile über dem Ergebnis.
##
## `explanation_coming`: das Urteil steht, die Erklärung rechnet noch. Dann bleiben
## Rückmeldung und Musterlösung leer, bis sie da ist (_on_explained) — die Rückmeldung der
## Karte („nah dran …") ist nicht das Urteil des Modells und stünde nur im Weg.
func _decide(result: Dictionary, headline := "", explanation_coming := false) -> void:
	_decided = true
	var hit := float(result.get("quality", 0.0)) >= HIT_QUALITY
	if hit:
		hits += 1
		hp = maxi(0, hp - 1)
		_render_hp()
	_golem_line.text = _line(HIT_LINES) if hit else (headline if not headline.is_empty() else _line(MISS_LINES))
	_verdict_label.text = "" if explanation_coming else str(result.get("feedback", ""))
	_reference_label.text = "" if explanation_coming else _reference_text()
	_lock_answer("⚔ Angreifen")
	_next_button.disabled = false
	_next_button.grab_focus.call_deferred()
	_react(hit, headline.is_empty())
	_show_result(true)
	var sentence: Dictionary = sentences[index]
	EventBus.boss_answer_evaluated.emit(float(result.get("quality", 0.0)), str(result.get("feedback", "")))
	EventBus.boss_answer_judged.emit(str(sentence.get("id", "")), _answer, {
		"quality": float(result.get("quality", 0.0)),
		"stage": str(result.get("stage", "")),
		"sure": bool(result.get("sure", false)),
		"hit": hit,
	})
	if hp == 0 or index + 1 >= sentences.size():
		_next_button.text = "Ergebnis"


func _on_refined(result: Dictionary) -> void:
	_decide(result)


## Das Modell sagt „falsch". Das steht sofort da; die Erklärung rechnet noch, und „Weiter"
## ist schon frei — wer nicht warten will, muss nicht.
func _on_denied(result: Dictionary) -> void:
	_decide(result, "", _judge.explaining())
	if _judge.explaining():
		_golem_line.text = EXPLAINING_TEXT
		_explanation_label.text = "…"
		_result_bubble.wobble(true)


func _on_explained(result: Dictionary) -> void:
	var text := str(result.get("explanation", ""))
	if _golem_line.text == EXPLAINING_TEXT:
		_golem_line.text = _line(MISS_LINES)
	_result_bubble.wobble(false)
	_explanation_label.text = text
	_reference_label.text = _reference_text()
	# Ohne gefundenen Fehler keine Rückmeldung, nur die Musterlösung (ADR 0005). Mit ihm
	# ersetzt die Erklärung die allgemeine Rückmeldung der Karte, sie steht nicht daneben.
	_verdict_label.text = "" if text.is_empty() else "Das stimmt noch nicht:"
	if not text.is_empty():
		var sentence: Dictionary = sentences[index]
		EventBus.boss_answer_explained.emit(str(sentence.get("id", "")), text)
	_result_bubble.pop()


## Aus dem Satz selbst, nicht aus dem Ergebnis: so ist sie da, egal welche Stufe geurteilt
## hat — auch nach einem Treffer, dessen Ergebnis keine Musterlösung mitbringt.
func _reference_text() -> String:
	return "Musterlösung: %s" % str(sentences[index].get("reference_translation", ""))


func _on_gave_up() -> void:
	if _decided:
		return
	_decide(SentenceCard.evaluate(sentences[index], _answer), NO_VERDICT_TEXT)


func _next() -> void:
	if _over:
		get_tree().change_scene_to_file(SELF_SCENE)
		return
	if not _decided:
		return
	_judge.cancel()
	if hp == 0 or index + 1 >= sentences.size():
		_finish()
		return
	index += 1
	_present()


func _finish() -> void:
	_over = true
	var won := hp == 0
	_golem_line.text = WON_TEXT if won else LOST_TEXT
	_round_label.text = "%d von %d Sätzen getroffen" % [hits, index + 1]
	_source_text.text = WON_FAREWELL if won else LOST_FAREWELL
	_verdict_label.text = ""
	_explanation_label.text = ""
	_reference_label.text = ""
	_lock_answer("⚔ Angreifen")
	_next_button.disabled = false
	_next_button.text = "Noch einmal"
	_next_button.grab_focus.call_deferred()
	_show_result(false)
	_boss_bubble.pop()
	if won:
		_stage.fall()
		_cheer(WON_SHOUT, HIT_SHOUT_TINT)
		Sfx.play(&"wave_cleared")
	else:
		_stage.leave()
	EventBus.boss_ended.emit(str(boss.get("id", "")), won)


func _render_hp() -> void:
	_hp_label.text = "❤ %d/%d" % [hp, max_hp]
	if _hp_tween != null:
		_hp_tween.kill()
	_hp_tween = create_tween()
	_hp_tween.tween_property(_hp_bar, "value", float(hp), 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Die Bühne spielt das Urteil vor. Ohne Urteil (`judged` = false) gibt es nichts zu feiern
## und nichts zu verspotten — der Boss geht einfach weiter.
func _react(hit: bool, judged: bool) -> void:
	_boss_bubble.wobble(false)
	_boss_bubble.pop()
	if hit:
		_stage.hurt(hp == 0)
		_cheer(HIT_SHOUT, HIT_SHOUT_TINT)
		_flash.modulate.a = 1.0
		create_tween().tween_property(_flash, "modulate:a", 0.0, 0.4)
		Sfx.play(&"monster_kill")
	elif judged:
		_stage.gloat()
		_cheer(MISS_SHOUT, MISS_SHOUT_TINT)
		Sfx.play(&"wrong_answer")
	else:
		_stage.resume()


## Der Ausruf in der Bildmitte: ploppt auf, steht kurz, verfliegt nach oben.
func _cheer(text: String, tint: Color) -> void:
	if _shout_tween != null:
		_shout_tween.kill()
	_shout.text = text
	_shout.pivot_offset = _shout.size / 2.0
	_shout.scale = Vector2.ONE * 0.4
	_shout.modulate = Color(tint.r, tint.g, tint.b, 1.0)
	_shout.rotation = randf_range(-0.12, 0.12)
	_shout_tween = create_tween()
	_shout_tween.tween_property(_shout, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_shout_tween.tween_interval(0.5)
	_shout_tween.tween_property(_shout, "modulate:a", 0.0, 0.4)


## Die Blase mit Rückmeldung und Erklärung. Leer ist sie nur durchsichtig, nicht weg: das
## Layout rechnet mit ihr.
func _show_result(on: bool) -> void:
	if not on:
		_result_bubble.wobble(false)
	if on == _result_shown:
		return
	_result_shown = on
	create_tween().tween_property(_result_bubble, "modulate:a", 1.0 if on else 0.0, 0.2)
	if on:
		_result_bubble.pop()


func _line(lines: Array) -> String:
	return str(lines[randi() % lines.size()])


func _leave() -> void:
	_judge.cancel()
	get_tree().change_scene_to_file(MENU_SCENE)


## Ist der Kampf vorbei? Für Tests und für die Anzeige.
func over() -> bool:
	return _over


## Hat der Spieler gewonnen? Nur sinnvoll, wenn `over()`.
func won() -> bool:
	return _over and hp == 0
