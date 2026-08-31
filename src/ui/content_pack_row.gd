extends PanelContainer
## Eine Zeile in der Inhalte-Verwaltung. Vorlage für den Content-Manager, der sie je Pack
## instanziiert (siehe content_manager.gd).

signal selection_changed
signal redeem_requested(code: String)
signal forget_requested

const INSTALL_LABEL := {
	PackStatus.Install.INSTALLED: "Installiert",
	PackStatus.Install.UPDATE: "Update verfügbar",
	PackStatus.Install.AVAILABLE: "Nicht installiert",
}

## Ein Sperrgrund verdrängt in der Anzeige den Installationsstand.
const BLOCK_LABEL := {
	PackStatus.Block.LOCKED: "Zugangscode erforderlich",
	PackStatus.Block.STALE_CODE: "Zugangscode veraltet",
	PackStatus.Block.APP_OUTDATED: "Programm-Update erforderlich",
}

var pack_id := ""

@onready var _select: CheckBox = %Select
@onready var _code_input: LineEdit = %CodeInput


func _ready() -> void:
	_select.toggled.connect(func(_on): selection_changed.emit())
	(%RedeemButton as Button).pressed.connect(_on_redeem)
	_code_input.text_submitted.connect(func(_t): _on_redeem())
	(%ForgetButton as Button).pressed.connect(func(): forget_requested.emit())


func setup(pack: PackStatus, preselected: bool) -> void:
	pack_id = pack.id
	(%Name as Label).text = pack.name
	(%State as Label).text = _state_label(pack)

	var parts := PackedStringArray()
	if not pack.description.is_empty():
		parts.append(pack.description)
	if pack.file_count > 0:
		parts.append("%d Datei(en)" % pack.file_count)
	if pack.size > 0:
		parts.append("%d KiB" % maxi(1, roundi(pack.size / 1024.0)))
	if pack.block == PackStatus.Block.APP_OUTDATED:
		parts.append("verlangt Version %s" % pack.min_version)
	(%Info as Label).text = " · ".join(parts)

	var needs_code := pack.block in [PackStatus.Block.LOCKED, PackStatus.Block.STALE_CODE]
	(%CodeRow as HBoxContainer).visible = needs_code or (pack.protected and pack.block == PackStatus.Block.NONE)
	(%RedeemButton as Button).visible = needs_code
	_code_input.visible = needs_code
	(%ForgetButton as Button).visible = pack.protected and not needs_code \
		and pack.block != PackStatus.Block.APP_OUTDATED

	_select.disabled = not pack.installable()
	_select.button_pressed = preselected and pack.installable()


func selected() -> bool:
	return _select.button_pressed and not _select.disabled


func set_selected(on: bool) -> void:
	if not _select.disabled:
		_select.button_pressed = on


func _state_label(pack: PackStatus) -> String:
	if pack.block != PackStatus.Block.NONE:
		return str(BLOCK_LABEL[pack.block])
	if pack.content_outdated:
		return "Inhalt veraltet"
	return str(INSTALL_LABEL[pack.install])


func _on_redeem() -> void:
	var code := _code_input.text.strip_edges()
	if code.is_empty():
		return
	_code_input.clear()
	redeem_requested.emit(code)
