extends CanvasLayer
## Die Auskunft am Zeiger — eine Karte für das ganze Spiel.
##
## Godot bringt das schon mit, nur schlecht: sein Tooltip erscheint nach einer halben
## Sekunde, bleibt dann stehen, wo er aufgegangen ist, und bringt die Typografie der Engine
## statt die des Spiels mit. Über einem Netz heißt das eine halbe Sekunde je Knoten —
## deshalb hatte der Fähigkeiten-Screen längst eine eigene Karte, und deshalb gibt es sie
## jetzt für alle.
##
## Hier steht der Träger: eine eigene Zeichenschicht über allem (`LAYER`), in der genau
## EINE `HintCard` hängt. Wer etwas zu sagen hat, meldet es an seinem Control an
## (`attach`); gefragt wird nicht das Control, sondern der Zeiger — jeden Frame steht in
## `Viewport.gui_get_hovered_control()`, was gerade unter ihm liegt.
##
## Warum eine eigene Schicht: ein `ScrollContainer` beschneidet seine Kinder
## (`clip_contents`), eine Karte über einer Statistikzeile wäre am Rand halb weg —
## dasselbe Argument, aus dem die Karte im Fähigkeiten-Screen schon nie am `SkillGraph`
## hing. Ein `CanvasLayer` ist kein `CanvasItem`; seine Kinder hängen an einem eigenen
## Canvas, und damit endet jede Beschneidung an seiner Grenze.
##
## Warum gefragt und nicht gemeldet (kein `mouse_entered`/`mouse_exited`): jedes Signal
## bräuchte sein Gegenstück zum Abmelden, und jedes deckte nur EINEN Weg ab, auf dem eine
## Auskunft ungültig wird. Die Frage deckt alle auf einmal ab — weggescrollt, zugeklappt,
## freigegeben, Szene gewechselt, Dialog davor. Und sie geht von dem Control unter dem
## Zeiger nach OBEN weiter, während Godots eigene Suche am ersten `MOUSE_FILTER_STOP`-Kind
## abbricht: genau deshalb musste die Fortschrittszeile ihren Text zweimal setzen, einmal
## für sich und einmal für ihren Knopf.

## Der Schlüssel, unter dem die Auskunft am Control hängt. Metadaten statt einer Liste hier:
## eine Liste könnte ihre Knoten überleben, ein Meta stirbt mit seinem Knoten. Deshalb gibt
## es auch kein Abmelden — ein leerer Hinweis IST das Abmelden.
const META := &"hint"

## Über allem, was die Szenen selbst mitbringen: `battle.tscn` legt sein UI auf 1, und der
## Wellenabschluss samt Schatzkiste hängt darin.
const LAYER := 128

## Abstand der Karte zum Mauszeiger. Weit genug, dass der Zeiger nicht auf dem Text steht,
## nah genug, dass beides ein Blick ist.
const GAP := Vector2(18, 18)

@onready var _card: HintCard = %Card

## Was beim letzten Blick unter dem Zeiger lag. Der Vergleich spart das Neubauen der Karte
## in jedem Frame, in dem sich nichts bewegt hat — und bei einer Fläche, die ihre Auskunft
## selbst sucht (`attach_live`), spart er den Aufruf gleich mit.
var _last_id: int = 0
var _last_at := Vector2.INF


func _ready() -> void:
	layer = LAYER
	_card.hide()


func _process(_delta: float) -> void:
	_look(false)


## Fragt sofort nach, was unter dem Zeiger liegt. Öffentlich, weil sich der INHALT ändern
## kann, ohne dass sich der Zeiger bewegt: nach einem gelernten Knoten steht in der Karte
## ein Stand, den es nicht mehr gibt.
func refresh() -> void:
	_look(true)


## Hängt einem Control seine Auskunft an. Ein durchweg leerer Hinweis nimmt sie wieder ab —
## „keine Auskunft" und „leere Auskunft" sind dasselbe, und die Aufrufstellen bleiben
## einzeilig (Dutzende Statistikzeilen bekommen gar keine, die fliegenden Münzen der
## Schatzkiste auch nicht).
##
## Angehängt wird an das KLEINSTE, was der Text meint. Die Suche geht von dort nach oben,
## eine Auskunft an einer Zeile gilt also auch für deren Knöpfe und Balken — eine an einer
## Screen-Wurzel dagegen für das ganze Bild, und das will niemand.
func attach(target: Control, title: String, body := "", note := "") -> void:
	if title.is_empty() and body.is_empty() and note.is_empty():
		if target.has_meta(META):
			target.remove_meta(META)
		return
	target.set_meta(META, {"title": title, "body": body, "note": note})


## Eine Fläche, die ihre Treffer selbst sucht (`SkillGraph`): statt fester Zeilen hängt hier
## eine Funktion, die für einen Punkt IN der Fläche die Karte liefert — oder ein leeres
## Dictionary für „hier ist nichts". Leer heißt wirklich nichts: gefragt wird dann nicht
## beim Elternknoten weiter, denn die Fläche hat schon geantwortet.
func attach_live(target: Control, provider: Callable) -> void:
	target.set_meta(META, provider)


## Was an einem Control hängt — leer, wenn nichts hängt. Für Tests und für Stellen, die
## ihren eigenen Hinweis nachlesen wollen.
func hint_of(target: Control) -> Dictionary:
	if not target.has_meta(META):
		return {}
	var value: Variant = target.get_meta(META)
	return value if value is Dictionary else {}


## Die Karte selbst. Für Tests — im Spiel fasst sie niemand an.
func card() -> HintCard:
	return _card


## Tut so, als läge der Zeiger bei `at` über `control`, und stellt die Karte entsprechend.
##
## Das ist die Naht für Tests, und sie hat einen handfesten Grund: Godot befördert in der
## kopflosen Betriebsart keine Mausereignisse, `gui_get_hovered_control()` ist dort also
## immer leer. Geprüft wird damit alles außer der Trefferprüfung der Engine selbst — die
## Suche nach oben, die Breitenregel, das Umklappen am Rand, das Abmelden.
##
## Gezeigt wird nur bis zum nächsten Frame: `_process` fragt dann wieder den echten Zeiger.
## Tests dazu kommen deshalb ohne `await` aus — was ohnehin die Zusage ist.
func probe(control: Control, at := Vector2.INF) -> void:
	var point := at if at.is_finite() else control.get_global_rect().get_center()
	_show(_hint_under(control, point), point)


func _look(forced: bool) -> void:
	var view := get_viewport()
	if view == null:
		return
	var over := view.gui_get_hovered_control()
	var at := view.get_mouse_position()
	var id := over.get_instance_id() if over != null else 0
	if not forced and id == _last_id and at == _last_at:
		return
	_last_id = id
	_last_at = at
	_show(_hint_under(over, at), at)


func _show(found: Dictionary, at: Vector2) -> void:
	if found.is_empty():
		_card.hide()
		return
	_card.fill(str(found.get("title", "")), str(found.get("body", "")),
			str(found.get("note", "")))
	_place(at)
	_card.show()


## Godots eigene Suche, nur ohne ihren Abbruch: von dem Control unter dem Zeiger nach oben,
## bis eines eine Auskunft trägt.
func _hint_under(node: Node, at: Vector2) -> Dictionary:
	var walk := node
	while walk != null:
		var control := walk as Control
		if control != null and control.has_meta(META):
			var value: Variant = control.get_meta(META)
			if value is Callable:
				# Der Punkt IN der Fläche, aus `at` gerechnet statt über
				# `get_local_mouse_position()`: derselbe Wert, aber auch dann richtig, wenn
				# der Zeiger gar nicht wirklich dort steht (siehe `probe`).
				var local: Vector2 = control.get_global_transform().affine_inverse() * at
				var answer: Variant = (value as Callable).call(local)
				return answer if answer is Dictionary else {}
			return value if value is Dictionary else {}
		walk = walk.get_parent()
	return {}


## Neben den Zeiger, aber nie über den Bildrand hinaus: am rechten oder unteren Rand klappt
## die Karte auf die andere Seite des Zeigers. Eine halb abgeschnittene Auskunft ist keine.
##
## Gemessen wird gegen das BILD und nicht gegen einen Screen: die Karte hängt in einer
## eigenen Schicht und kennt keinen. Das ist zugleich der Fall, der im maximierten Fenster
## stimmt, wo das Spiel breiter ist als die Grundauflösung (CLAUDE.md).
func _place(at: Vector2) -> void:
	var room := get_viewport().get_visible_rect().size
	var size := _card.size
	var to := at + GAP
	if to.x + size.x > room.x:
		to.x = at.x - GAP.x - size.x
	if to.y + size.y > room.y:
		to.y = at.y - GAP.y - size.y
	_card.position = to.clamp(Vector2.ZERO, (room - size).max(Vector2.ZERO))
