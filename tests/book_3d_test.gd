extends GdUnitTestSuite
## Ein Buch der Bibliothek (Book3D) schlägt nach dem Rückweg aus der Buchkarte erst zu, bevor
## es zurück aufs Pult geht — die Bibliothek wartet darauf (`is_closed`), sonst stünden zwei
## Bücher vorn.

const BOOK_SCENE := preload("res://scenes/ui/book_3d.tscn")


func test_a_book_back_from_its_map_closes_before_it_counts_as_closed() -> void:
	var book: Book3D = auto_free(BOOK_SCENE.instantiate())
	add_child(book)
	book.show_open()
	book.hold_forward(false)
	assert_bool(book.is_closed()).is_false()
	# Ein Bild nach dem Loslassen ist der Deckel noch offen, das Buch steht noch vorn.
	book._process(MapCanvas.MAX_ZOOM_STEP)
	assert_bool(book.is_closed()).is_false()
	assert_float(book.lift).is_equal(1.0)
	for i in ceili(Book3D.OPEN_TIME / MapCanvas.MAX_ZOOM_STEP):
		book._process(MapCanvas.MAX_ZOOM_STEP)
	assert_bool(book.is_closed()).is_true()
