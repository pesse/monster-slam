extends GdUnitTestSuite
## Wie ein Buch seine Ebenen nennt (BookNaming, ADR 0008): Access zählt Units und Teile,
## À plus! Dossiers und Parties mit Buchstaben, Latein Abschnitte und durchgezählte Lektionen.

const APLUS := {"title": "À plus!", "unit": "Dossier", "part": "Partie", "part_glyph": "letter"}
const LATIN := {"unit": "Abschnitt", "part": "Lektion", "parts_per_unit": 6}


func test_without_naming_it_is_unit_and_part() -> void:
	assert_str(BookNaming.unit_label_in({}, 2)).is_equal("Unit 2")
	assert_str(BookNaming.part_label_in({}, 2, 1)).is_equal("Teil 1")
	assert_str(BookNaming.parts_label_in({}, 2, [2, 3])).is_equal("Teil 2 + 3")


func test_a_plus_counts_parts_with_letters() -> void:
	assert_str(BookNaming.unit_label_in(APLUS, 2)).is_equal("Dossier 2")
	assert_str(BookNaming.part_label_in(APLUS, 2, 3)).is_equal("Partie C")
	assert_str(BookNaming.parts_label_in(APLUS, 2, [1, 2])).is_equal("Partie A + B")


## Die Lektionen zählen über das ganze Buch: Abschnitt 2, Teil 4 ist Lektion 10.
func test_latin_counts_lessons_through_the_book() -> void:
	assert_str(BookNaming.unit_label_in(LATIN, 2)).is_equal("Abschnitt 2")
	assert_str(BookNaming.part_label_in(LATIN, 1, 1)).is_equal("Lektion 1")
	assert_str(BookNaming.part_label_in(LATIN, 2, 4)).is_equal("Lektion 10")
	assert_str(BookNaming.part_glyph_in(LATIN, 2, 4)).is_equal("10")


## Die Bücher im Repo tragen ihre Namen in der Karte.
func test_the_books_name_themselves() -> void:
	assert_str(BookNaming.unit_label("latein", 2)).is_equal("Abschnitt 2")
	assert_str(BookNaming.part_label("latein", 2, 4)).is_equal("Lektion 10")
	assert_str(BookNaming.unit_label("access4", 1)).is_equal("Unit 1")
	assert_str(BookNaming.part_label("aplusx", 2, 1)).is_equal("Partie A")
	assert_str(ContentRegistry.book_label("aplusx")).is_equal("À plus!")
	assert_str(ContentRegistry.book_label("access4")).is_equal("Access 4")
	assert_str(MapLevel.levels_for("aplusx", 2, 3)[2]["label"]).is_equal("Partie C")
