extends Control
## Werkbank für die Satzbewertung (scenes/dev/boss_lab.tscn) — eine eigenständige Szene,
## um Sätze und ihren Lösungsschlüssel ohne Spiel auszuprobieren
## (docs/adr/0004-satzbewertung-ohne-modell.md).
##
## Wozu: um eine Bewertungsregel zu beurteilen, will man zwanzig Antworten durchprobieren
## und nicht zwanzig Wellen spielen. Hier steht links die Auswahl (welcher Satz käme
## dran?), in der Mitte der Satz mit seinem Schlüssel und der getippten Antwort, rechts
## das Urteil BEIDER Stufen nebeneinander: die Prüfkarte, die immer antwortet, und das
## Modell, das nur antwortet, wenn auf diesem Rechner eines läuft.
##
## **Stufe 1 startet die Werkbank selbst** (`LocalModelServer`, Knopf „Dienst starten"):
## `llama-server.exe` aus `user://model/`, geholt über den Knopf im Inhalte-Screen. Vorher
## musste man den Dienst von Hand starten und dabei wissen, dass das URL-Feld auf Ollamas
## Port zeigte und nicht auf unseren — zwei Stolperstellen vor der ersten Antwort.
##
## **Die Zeitlimits sind hier andere als im Kampf** (`LAB_HTTP_TIMEOUT`). Der Boss holt vier
## Sekunden aus, ein 1,7-B-Modell auf der CPU ist danach nicht fertig; mit den
## Kampf-Vorgaben meldete die Werkbank „kein Dienst erreichbar", während der Dienst
## einwandfrei rechnete. Beurteilt wird hier, ob ein Modell die Aufgabe KANN — ob es das
## rechtzeitig tut, ist eine andere Frage und gehört in den Kampf.
##
## Der Schlüssel ist hier **veränderbar**. Eine Stolperstelle beurteilt man, indem man sie
## formuliert und sofort dagegen tippt; der Umweg über eine Datei im Submodule und einen
## Neustart wäre genau die Reibung, die dazu führt, dass es niemand tut. Geschrieben wird
## nichts — was hier steht, gilt für diesen Klick.
##
## Starten: im Editor mit F6 auf dieser Szene, oder
## `tools/godot.sh res://scenes/dev/boss_lab.tscn` (headless zeichnet nichts).
## Die Szene liegt unter scenes/dev/ und ist im Export ausgeschlossen (`exclude_filter`).
## Sie ist **nicht** in den Spielfluss eingehängt: es gibt keinen Boss-Kampf, sie verbucht
## nichts und sie meldet nichts an PlayerProgress.

const MENU_SCENE := "res://scenes/ui/profile_menu.tscn"

## So viele Sätze stehen höchstens zur Wahl. Der Bestand hat über tausend; eine
## Auswahlliste mit tausend Einträgen ist keine Auswahl mehr.
const MAX_CHOICES := 60

## Wie lange die Werkbank auf eine Antwort wartet. Großzügig, und mit Absicht nicht die
## Vorgabe aus dem Kampf: siehe oben. Der Richter wartet etwas LÄNGER als das Backend —
## gäbe er früher auf, stünde die Anfrage noch und jede weitere fiele in die Sperre.
const LAB_HTTP_TIMEOUT := 60.0
const LAB_JUDGE_TIMEOUT := LAB_HTTP_TIMEOUT + 2.0

## Die Felder, die den Lösungsschlüssel ausmachen — und damit das, was in der Werkbank
## veränderbar ist.
const KEY_FIELDS := ["accepted", "must_contain", "pitfalls"]

@onready var _boss_select: OptionButton = %BossSelect
@onready var _sentence_select: OptionButton = %SentenceSelect
@onready var _only_keyed: CheckButton = %OnlyKeyed
@onready var _use_profile: CheckButton = %UseProfile
@onready var _pool_info: Label = %PoolInfo
@onready var _source_text: Label = %SourceText
@onready var _sentence_info: Label = %SentenceInfo
@onready var _key_edit: TextEdit = %KeyEdit
@onready var _key_status: Label = %KeyStatus
@onready var _answer_edit: LineEdit = %AnswerEdit
@onready var _card_result: Label = %CardResult
@onready var _model_result: Label = %ModelResult
@onready var _model_toggle: CheckButton = %ModelToggle
@onready var _model_url: LineEdit = %ModelUrl
@onready var _serve_button: Button = %ServeButton
@onready var _serve_status: Label = %ServeStatus

var _judge: SentenceJudge
var _backend: LocalModelBackend
var _server: LocalModelServer
## Die Sätze der aktuellen Auswahl, in der Reihenfolge der Liste.
var _choices: Array = []
## Das Fenster, dessen Größe die Werkbank geliehen hat.
var _room: Window


func _ready() -> void:
	# Eine Werkbank bekommt mehr Platz als das Spiel — drei Spalten nebeneinander passen
	# nicht in 1152×648, und am Fensterrand zu ziehen hilft dagegen nicht (LabRoom).
	_room = get_window()
	LabRoom.enlarge(_room)
	_judge = SentenceJudge.new()
	_judge.timeout = LAB_JUDGE_TIMEOUT
	add_child(_judge)
	_judge.refined.connect(_on_refined)
	_judge.gave_up.connect(_on_gave_up)
	_backend = LocalModelBackend.new()
	# VOR dem Einhängen: LocalModelBackend liest den Wert in seinem _ready().
	_backend.http_timeout = LAB_HTTP_TIMEOUT
	add_child(_backend)
	# Angelegt, nicht gestartet. Der Knoten kostet nichts, und mit ihm steht die Adresse
	# fest, die der Knopf gleich bedient — das URL-Feld muss niemand von Hand richten.
	_server = LocalModelServer.new()
	# In der Werkbank will man llama-servers EIGENES Log sehen — warum er die Gewichte
	# ablehnt, steht dort und sonst nirgends. Im Spiel wäre dieses Fenster ein zweites,
	# das niemand bestellt hat.
	_server.show_console = true
	add_child(_server)

	_boss_select.add_item("— alle Sätze —", 0)
	for boss in ContentRegistry.bosses.values():
		_boss_select.add_item(str((boss as Dictionary).get("name", boss.get("id", "?"))))
	_model_url.text = _server.url()

	_boss_select.item_selected.connect(func(_i: int): _refill())
	_only_keyed.toggled.connect(func(_on: bool): _refill())
	_use_profile.toggled.connect(func(_on: bool): _refill())
	_sentence_select.item_selected.connect(func(_i: int): _show_sentence())
	(%RollButton as Button).pressed.connect(_roll)
	(%JudgeButton as Button).pressed.connect(_judge_now)
	_answer_edit.text_submitted.connect(func(_t: String): _judge_now())
	_model_toggle.toggled.connect(_on_model_toggled)
	_serve_button.pressed.connect(_on_serve_pressed)
	(%BackButton as Button).pressed.connect(func(): get_tree().change_scene_to_file(MENU_SCENE))

	_render_serve()
	_refill()


## Das Fenster gehört dem Spiel; die Werkbank gibt es zurück. Hier und nicht an den beiden
## Ausgängen: es gibt Knopf, Escape und das Beenden, und drei Stellen wären zwei zu viel.
func _exit_tree() -> void:
	LabRoom.restore(_room)


func _input(event: InputEvent) -> void:
	# Escape führt zurück ins Menü — dieselbe Geste wie im Kampf.
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		get_tree().change_scene_to_file(MENU_SCENE)


## Der Pool, nach dem ausgewählt wird: die Regel des gewählten Bosses, wahlweise über der
## Auswahl des aktiven Profils. Ohne Profil-Häkchen bleiben Scope und Themen leer — und
## leer heißt im Wave-Pool wie hier „keine Einschränkung".
func pool() -> Dictionary:
	var out := {"scope": [], "tags": [], "grammar_tags": [], "difficulty_max": 0}
	if _use_profile.button_pressed:
		out = SentenceSelector.pool_from_settings()
	var index := _boss_select.selected
	if index > 0:
		var bosses: Array = ContentRegistry.bosses.values()
		if index - 1 < bosses.size():
			var boss: Dictionary = bosses[index - 1]
			var rule: Dictionary = boss.get("sentence_rule", {})
			out["grammar_tags"] = Array(rule.get("grammar_tags", []))
			if int(rule.get("difficulty_max", 0)) > 0:
				out["difficulty_max"] = int(rule["difficulty_max"])
	return out


## Alles, was zum Pool passt — und zwar dieselbe Menge, aus der auch „Satz ziehen"
## zieht. Zwei Mengen hießen: die Liste zeigt nur Sätze mit Schlüssel, der Knopf legt
## einen ohne daneben.
func _pool_sentences() -> Array:
	var found := SentenceSelector.new().candidates(pool())
	if _only_keyed.button_pressed:
		found = found.filter(func(s): return has_key(s))
	return found


## Füllt die Auswahlliste neu: was zum Pool passt, das Schwerste zuerst (Netto-Maß).
func _refill() -> void:
	var all := SentenceSelector.new().candidates(pool())
	var found := _pool_sentences()
	found.sort_custom(func(a, b):
		return SentenceSelector.net_difficulty(a) > SentenceSelector.net_difficulty(b))
	_pool_info.text = "%d Sätze im Pool, davon %d mit Schlüssel — höchstens %d zur Wahl." % [
		all.size(), all.filter(func(s): return has_key(s)).size(), MAX_CHOICES]
	if found.is_empty():
		_pool_info.text += "\n" + empty_note(all)
	show_sentences(found.slice(0, MAX_CHOICES))


## Warum nichts zur Wahl steht. Der häufigste Grund ist kein leerer Bestand, sondern ein
## liegengebliebener Pack: er gewinnt bei gleicher Id gegen das Submodule, und ein Pack von
## vor den Schlüsselfeldern macht aus tausend Sätzen tausend OHNE Schlüssel. Ohne diesen
## Satz tut „Satz ziehen wie im Spiel" dann schlicht nichts — es gibt nichts zu ziehen, und
## warum, steht nirgends: die Herkunft steht sonst AM Satz, und einen Satz gibt es ja nicht.
static func empty_note(pool_sentences: Array) -> String:
	if pool_sentences.is_empty():
		return "Nichts zur Wahl: kein Satz passt zu dieser Auswahlregel."
	var packs := {}
	for sentence in pool_sentences:
		var pack := ContentRegistry.pack_of(
				"sentences", str((sentence as Dictionary).get("id", "")))
		if not pack.is_empty():
			packs[pack] = true
	if packs.is_empty():
		return "Nichts zur Wahl: kein Satz im Pool trägt einen Schlüssel."
	return ("Nichts zur Wahl: kein Satz im Pool trägt einen Schlüssel — sie kommen aus "
			+ "Pack „%s“, und ein Pack verdeckt das Submodule. " % ", ".join(
					PackedStringArray(packs.keys().map(str)))
			+ "Aufräumen unter user://content.")


## Stellt eine Liste von Sätzen zur Wahl und zeigt den ersten. Die Naht, an der die Tests
## hängen: sie sollen eine Bewertungsregel an einem erfundenen Satz prüfen können und
## nicht an dem, was auf diesem Rechner gerade installiert ist.
func show_sentences(list: Array) -> void:
	_choices = list
	_sentence_select.clear()
	for sentence in _choices:
		_sentence_select.add_item(str((sentence as Dictionary).get("source_text", "?")))
	if not _choices.is_empty():
		_sentence_select.select(0)
	_show_sentence()


## Trägt der Satz einen Lösungsschlüssel, oder nur seine eine Musterlösung?
static func has_key(sentence: Dictionary) -> bool:
	for field in KEY_FIELDS:
		if not Array(sentence.get(field, [])).is_empty():
			return true
	return false


## Zieht einen Satz so, wie das Spiel ihn ziehen würde — gewichtet nach dem Netto-Maß.
func _roll() -> void:
	var picked := SentenceSelector.pick_from(_pool_sentences())
	if picked.is_empty():
		return
	for i in _choices.size():
		if str((_choices[i] as Dictionary).get("id", "")) == str(picked.get("id", "")):
			_sentence_select.select(i)
			_show_sentence()
			return
	# Gezogen wird aus dem ganzen Pool, die Liste zeigt nur den Anfang davon — der
	# gezogene Satz stellt sich dann vorn dazu.
	show_sentences(([picked] + _choices).slice(0, MAX_CHOICES))


func _show_sentence() -> void:
	var sentence := selected()
	_source_text.text = str(sentence.get("source_text", "—"))
	if sentence.is_empty():
		_sentence_info.text = "Kein Satz im Pool."
		_key_edit.text = ""
	else:
		var lexemes := SentenceSelector.lexeme_ids(str(sentence.get("id", "")))
		_sentence_info.text = "%s · Schwierigkeit %d · %s · Lernstand %.2f · netto %+.2f" % [
			sentence.get("id", "?"), int(sentence.get("difficulty", 1)),
			", ".join(PackedStringArray(Array(sentence.get("grammar_tags", [])).map(str))),
			SentenceSelector.confidence(str(sentence.get("id", ""))),
			SentenceSelector.net_difficulty(sentence),
		]
		if lexemes.is_empty():
			_sentence_info.text += " · ohne Lexeme"
		_sentence_info.text += " · %s" % origin_label(str(sentence.get("id", "")))
		_key_edit.text = JSON.stringify(key_of(sentence), "  ")
	_key_status.text = ""
	_card_result.text = "—"
	_model_result.text = _model_idle_text()


## Woher der Satz kommt. Steht dabei, weil ein installierter Pack bei gleicher Id gegen
## das Submodule GEWINNT (ContentRegistry liest user:// zuletzt): ein Satz ohne Schlüssel,
## der im Submodule längst einen hat, ist sonst ein Rätsel. Aufräumen heißt dann: den Pack
## unter `user://content` entfernen oder neu bauen.
static func origin_label(sentence_id: String) -> String:
	var pack := ContentRegistry.pack_of("sentences", sentence_id)
	return "aus Pack „%s“" % pack if not pack.is_empty() else "aus dem Submodule"


## Der Lösungsschlüssel eines Satzes als eigenes Dictionary — das, was in der Werkbank
## veränderbar ist.
static func key_of(sentence: Dictionary) -> Dictionary:
	var out := {}
	for field in KEY_FIELDS:
		out[field] = sentence.get(field, [])
	return out


## Der gewählte Satz aus dem Bestand (ohne die Änderungen im Schlüssel-Feld).
func selected() -> Dictionary:
	var index := _sentence_select.selected
	if index < 0 or index >= _choices.size():
		return {}
	return _choices[index]


## Der gewählte Satz MIT dem Schlüssel, wie er gerade im Feld steht. Steht dort Unsinn,
## gilt der Schlüssel aus den Daten — eine halb getippte Klammer soll die Bewertung nicht
## anhalten, sie soll es nur sagen.
func sentence_under_test() -> Dictionary:
	var sentence := selected().duplicate(true)
	if sentence.is_empty():
		return sentence
	var raw := _key_edit.text.strip_edges()
	if raw.is_empty():
		return sentence
	# JSON.new().parse() statt JSON.parse_string(): das halb Getippte ist hier der
	# Normalfall und kein Fehler, den jemand in der Konsole lesen müsste.
	var json := JSON.new()
	if json.parse(raw) != OK or not (json.data is Dictionary):
		_key_status.text = "Schlüssel ist kein gültiges JSON — es gilt der aus den Daten."
		return sentence
	for field in KEY_FIELDS:
		sentence[field] = Array((json.data as Dictionary).get(field, []))
	_key_status.text = "Schlüssel aus dem Feld (nicht gespeichert)."
	return sentence


func _judge_now() -> void:
	var sentence := sentence_under_test()
	if sentence.is_empty():
		return
	var card := _judge.judge(sentence, _answer_edit.text)
	_card_result.text = describe(card)
	if not _model_toggle.button_pressed:
		_model_result.text = _model_idle_text()
	elif _judge.pending():
		_model_result.text = "Fragt %s …" % _model_url.text
	else:
		_model_result.text = "Nicht gefragt — die Prüfkarte ist sich sicher."


## Ein Ergebnis in Klartext. Dieselben Felder, die auch der Kampf bekäme.
static func describe(result: Dictionary) -> String:
	var lines := PackedStringArray([
		"Güte: %d %%" % roundi(float(result.get("quality", 0.0)) * 100.0),
		str(result.get("feedback", "")),
	])
	var matched := str(result.get("matched", ""))
	if not matched.is_empty():
		lines.append("Getroffen: %s" % matched)
	var missing: Array = result.get("missing", [])
	if not missing.is_empty():
		lines.append("Fehlt: %s" % ", ".join(PackedStringArray(missing.map(str))))
	if bool(result.get("sure", true)):
		lines.append("sicher")
	else:
		# Ohne Urteil ist die Güte 0 — was die Karte trotzdem weiß, ist die Nähe am
		# Wortlaut. Sie steht hier, damit in der Werkbank nicht bloß „0 %" dasteht, wo die
		# Karte in Wahrheit nichts sagt.
		lines.append("kein Urteil (Nähe %d %%) — Stufe 1 darf ran"
				% roundi(float(result.get("overlap", 0.0)) * 100.0))
	return "\n".join(lines)


## Startet den Dienst aus `user://model/` — oder beendet ihn wieder. Nach einem
## erfolgreichen Start ist Stufe 1 an: wer hier drückt, will sie benutzen, und ein zweiter
## Schalter dazwischen wäre nur eine Stelle, an der man hängenbleibt.
func _on_serve_pressed() -> void:
	if _server.running():
		_server.stop()
		_render_serve()
		return
	_serve_button.disabled = true
	_serve_status.text = "Startet … beim ersten Mal lädt ein Gigabyte von der Platte."
	var started := await _server.start()
	_serve_button.disabled = false
	if started:
		_model_url.text = _server.url()
		_model_toggle.button_pressed = true
		# Setzen löst `toggled` nur aus, wenn sich etwas ÄNDERT — war Stufe 1 schon an,
		# bekäme das Backend die Adresse sonst nicht.
		_on_model_toggled(true)
	_render_serve()


## Was der Knopf gerade anbietet und woran es sonst liegt. Der Pfad steht immer dabei:
## „Kein Modell" ist keine Auskunft, solange man nicht weiß, wo gesucht wurde.
func _render_serve() -> void:
	if _server.running():
		_serve_button.text = "Dienst beenden"
		_serve_status.text = "Läuft auf Port %d." % _server.port
		return
	_serve_button.text = "Dienst starten"
	var where := ProjectSettings.globalize_path(_server.dir)
	if not _server.last_note.is_empty():
		_serve_status.text = _server.last_note
	elif not _server.missing_files().is_empty():
		_serve_status.text = "Kein Modell in %s — es fehlt: %s. Zu holen im Inhalte-Screen." % [
				where, ", ".join(_server.missing_files())]
	else:
		_serve_status.text = "Bereit: %s" % where


func _on_model_toggled(on: bool) -> void:
	_backend.url = _model_url.text.strip_edges()
	_judge.model_backend = _backend.judge if on else Callable()
	_model_result.text = _model_idle_text()


func _on_refined(result: Dictionary) -> void:
	_model_result.text = describe(result)


func _on_gave_up() -> void:
	# Warum nichts kam, weiß das Backend — „kein Dienst" und „Modell hält sich nicht an
	# die Form" sehen sonst gleich aus, und man sucht am falschen Ende.
	var note := _backend.last_note
	if note.is_empty():
		note = "Zeitlimit überschritten — oder das Modell hatte nichts beizutragen."
	_model_result.text = "Keine Antwort — es bleibt bei der Prüfkarte.\n%s" % note


func _model_idle_text() -> String:
	if _model_toggle != null and _model_toggle.button_pressed:
		return "Bereit — fragt bei unsicherem Urteil."
	return "Aus. Stufe 1 ist nicht Teil der Auslieferung;\nsie braucht einen Dienst — siehe „Dienst starten“."
