extends GdUnitTestSuite
## Der Weg, auf dem das Sprachmodell auf den Rechner kommt (src/content/model_service.gd).
##
## Kein Test lädt etwas herunter. Geprüft wird das, was über den Download entscheidet: was
## aus einem Archiv übernommen wird, was nicht, und dass ein Eintrag mit Pfad darin das
## Zielverzeichnis nicht verlassen kann.
##
## Geschrieben wird in ein `zz-`Verzeichnis und nicht nach `user://model` — dort liegt auf
## einem Entwicklungsrechner das echte Modell, und `user://` ist projektübergreifend
## dasselbe Verzeichnis (dieselbe Regel wie beim `zz-`Profil von Wallet und PlayerLevel).

const DIR := "user://zz-model-test"
const SCRIPT := "res://src/content/model_service.gd"

const MANIFEST := {
	"name": "Sprachmodell (Test)",
	"parts": [
		{"file": "llama-server.exe", "url": "https://example.invalid/bin.zip",
			"sha256": "aa", "bytes": 20 * 1024 * 1024, "unzip": true},
		{"file": "model.gguf", "url": "https://example.invalid/model.gguf",
			"sha256": "bb", "bytes": 1100 * 1024 * 1024},
	],
}

var _service: Node


func before_test() -> void:
	_service = auto_free(load(SCRIPT).new())
	add_child(_service)
	_service.dir = DIR
	_service.manifest = MANIFEST.duplicate(true)
	DirAccess.make_dir_recursive_absolute(DIR)


func after_test() -> void:
	_wipe(DIR)


## Vor dem Klick soll dastehen, was er kostet. „1,1 GB" ist die Angabe, die ein Elternteil
## braucht; „1181116006 Bytes" ist keine.
func test_the_size_is_readable_before_the_click() -> void:
	assert_str(_service.humanized(1181116006)).is_equal("1.1 GB")
	assert_str(_service.humanized(20 * 1024 * 1024)).is_equal("20 MB")
	assert_str(_service.humanized(512)).is_equal("512 Bytes")


func test_the_manifest_tells_name_and_total_size() -> void:
	assert_str(_service.display_name()).is_equal("Sprachmodell (Test)")
	assert_int(_service.total_bytes()).is_equal((20 + 1100) * 1024 * 1024)


## Aus einem llama.cpp-Archiv kommen das Programm UND seine DLLs — ohne die startet es
## nicht. Alles andere bleibt draußen: was nicht ausgepackt wird, kann nichts anrichten.
func test_only_the_program_and_its_libraries_are_unpacked() -> void:
	var zip := "%s/bin.zip" % DIR
	_zip(zip, {
		"llama-server.exe": "PROGRAMM",
		"ggml.dll": "BIBLIOTHEK",
		"README.md": "Anleitung",
		"include/llama.h": "Kopfdatei",
	})
	assert_str(_service._place(zip, "llama-server.exe", true)).is_empty()
	assert_bool(FileAccess.file_exists("%s/llama-server.exe" % DIR)).is_true()
	assert_bool(FileAccess.file_exists("%s/ggml.dll" % DIR)).is_true()
	assert_bool(FileAccess.file_exists("%s/README.md" % DIR)).is_false()
	assert_bool(FileAccess.file_exists("%s/llama.h" % DIR)).is_false()


## Übernommen wird nur der DATEINAME, nie der Pfad im Archiv. Ein Eintrag, der aus dem
## Zielverzeichnis hinausführen will, landet damit trotzdem darin — und nicht im Autostart.
func test_a_path_inside_the_archive_cannot_escape() -> void:
	var zip := "%s/böse.zip" % DIR
	_zip(zip, {"../../../autostart.exe": "BÖSE", "llama-server.exe": "PROGRAMM"})
	assert_str(_service._place(zip, "llama-server.exe", true)).is_empty()
	assert_bool(FileAccess.file_exists("%s/autostart.exe" % DIR)).is_true()
	assert_bool(FileAccess.file_exists("%s/../../../autostart.exe" % DIR)).is_false()


## Ein Archiv ohne Programm ist kein Zustand, in dem man weitermacht — sonst stünde
## hinterher ein halb eingerichtetes Verzeichnis da, das niemand erklären kann.
func test_an_archive_without_a_program_is_refused() -> void:
	var zip := "%s/leer.zip" % DIR
	_zip(zip, {"README.md": "nichts drin"})
	assert_str(_service._place(zip, "llama-server.exe", true)).is_not_empty()


## Die Gewichte sind kein Archiv: sie werden unter ihrem Namen abgelegt.
func test_plain_weights_are_just_moved_into_place() -> void:
	var raw := "%s/model.gguf.download" % DIR
	var file := FileAccess.open(raw, FileAccess.WRITE)
	file.store_string("GEWICHTE")
	file.close()
	assert_str(_service._place(raw, "model.gguf", false)).is_empty()
	assert_bool(FileAccess.file_exists("%s/model.gguf" % DIR)).is_true()


## „Installiert" heißt dasselbe wie für LocalModelServer — eine zweite Buchführung darüber
## liefe irgendwann auseinander, und dann zeigte der Knopf „einsatzbereit", während der
## Dienst nichts findet.
func test_installed_means_what_the_service_needs() -> void:
	assert_bool(_service.installed()).is_false()
	for name in [LocalModelServer.EXE_NAME, LocalModelServer.WEIGHTS_NAME]:
		var file := FileAccess.open(DIR.path_join(name), FileAccess.WRITE)
		file.store_string("x")
		file.close()
	assert_bool(_service.installed()).is_true()
	assert_array(LocalModelServer.missing_in(DIR)).is_empty()


## Ein Gigabyte muss man auch wieder loswerden können, sonst ist der Knopf eine
## Einbahnstraße.
func test_what_was_installed_can_be_removed_again() -> void:
	for name in [LocalModelServer.EXE_NAME, LocalModelServer.WEIGHTS_NAME]:
		var file := FileAccess.open(DIR.path_join(name), FileAccess.WRITE)
		file.store_string("x")
		file.close()
	_service.remove()
	assert_bool(_service.installed()).is_false()


## Kein Manifest heißt: dieser Kanal bietet gerade keinen Zusatz an. Das ist ein Zustand
## und kein Fehler — solange noch kein Modell veröffentlicht ist, antwortet der Kanal mit
## HTTP 404, und ein rotes „Server antwortet mit HTTP 404" an einem Zusatz, den niemand
## bestellt hat, ist eine Fehlermeldung für nichts. Der Grund geht ins Log.
func test_nothing_on_offer_is_a_state_and_not_an_error() -> void:
	_service._no_offer("Server antwortet mit HTTP 404.")
	assert_bool(_service.available()).is_false()
	assert_str(_service.error).is_empty()
	assert_int(_service.state).is_equal(_service.State.READY)


## Umgekehrt: wer selbst auf „Herunterladen" gedrückt hat, hat eine Antwort verdient.
func test_without_a_manifest_nothing_is_downloaded() -> void:
	_service.manifest = {}
	await _service.install()
	assert_int(_service.state).is_equal(_service.State.ERROR)
	assert_str(_service.error).is_not_empty()


func _zip(path: String, files: Dictionary) -> void:
	var packer := ZIPPacker.new()
	assert_int(packer.open(path)).is_equal(OK)
	for name in files:
		packer.start_file(str(name))
		packer.write_file(str(files[name]).to_utf8_buffer())
		packer.close_file()
	packer.close()


func _wipe(path: String) -> void:
	var folder := DirAccess.open(path)
	if folder == null:
		return
	for file in folder.get_files():
		folder.remove(file)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
