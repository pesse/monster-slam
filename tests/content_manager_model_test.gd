extends GdUnitTestSuite
## Der Zusatz-Abschnitt der Inhalte-Verwaltung (scenes/ui/content_manager.tscn) darf nicht
## aufblitzen, bevor feststeht, ob es überhaupt etwas zu holen gibt.
##
## Ob ein Zusatz angeboten wird, weiß das Spiel erst nach einer HTTP-Antwort. Bis dahin
## steht in der Szene, was der Editor zeigt — und das war ein fertiger „Herunterladen"-Knopf,
## der beim Öffnen des Screens sofort wieder verschwand. Ein Knopf, der erscheint und geht,
## ist schlimmer als keiner: er sieht aus wie ein Fehler und lädt zum Hinterherklicken ein.
##
## Geprüft wird an der uneingehängten Instanz: ohne add_child läuft kein _ready(), es steht
## also genau das da, was in der .tscn steht.

const SCREEN := preload("res://scenes/ui/content_manager.tscn")


func test_the_model_section_starts_hidden() -> void:
	var screen: Control = auto_free(SCREEN.instantiate())
	var panel := screen.get_node("%Model") as PanelContainer
	assert_object(panel).is_not_null()
	assert_bool(panel.visible).override_failure_message(
			"Der Zusatz-Abschnitt ist in der Szene sichtbar und blitzt damit auf, "
			+ "bevor ModelService geantwortet hat.").is_false()
