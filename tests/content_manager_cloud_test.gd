extends GdUnitTestSuite
## Der Abschnitt „Schreib-Boss (Cloud)" der Inhalte-Verwaltung (ADR 0023, §1).
##
## Geprüft an der uneingehängten Instanz wie in content_manager_model_test.gd: eingehängt
## fragte `_ready` das Pack-Verzeichnis beim Server an, und kein Test spricht mit einem
## Dienst.

const SCREEN := preload("res://scenes/ui/content_manager.tscn")


func test_the_key_is_masked_while_typing() -> void:
	var screen: Control = auto_free(SCREEN.instantiate())
	var input := screen.get_node("%KeyInput") as LineEdit
	assert_object(input).is_not_null()
	assert_bool(input.secret).is_true()


func test_storing_goes_through_a_confirmation() -> void:
	var screen: Control = auto_free(SCREEN.instantiate())
	assert_object(screen.get_node("%CloudConfirm") as ConfirmDialog).is_not_null()
	# Entfernen und Prüfen gibt es erst mit Schlüssel — in der Szene sind sie aus.
	assert_bool((screen.get_node("%CloudRemoveButton") as Control).visible).is_false()
	assert_bool((screen.get_node("%CloudCheckButton") as Control).visible).is_false()


func test_costs_read_as_dollars() -> void:
	var script: GDScript = load("res://src/ui/content_manager.gd")
	assert_str(script.call("_dollars", 0.0)).is_equal("0,00 $")
	assert_str(script.call("_dollars", 0.004)).is_equal("0,004 $")
	assert_str(script.call("_dollars", 1.236)).is_equal("1,24 $")
