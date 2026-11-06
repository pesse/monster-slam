extends GdUnitTestSuite
## Das Lesen von `.tar.gz` (src/content/tar_gz.gd), über das llama.cpp unter Linux kommt.

const DIR := "user://zz-tar-test"


func before_test() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)


func after_test() -> void:
	var folder := DirAccess.open(DIR)
	if folder != null:
		for file in folder.get_files():
			folder.remove(file)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR))


func test_files_come_back_under_their_path_in_the_archive() -> void:
	var files := TarGz.parse(TarBuilder.tar([
		TarBuilder.entry("a/eins.txt", "EINS"),
		TarBuilder.entry("a/leer.txt", ""),
	]))
	assert_array(files.keys()).contains_exactly_in_any_order(["a/eins.txt", "a/leer.txt"])
	assert_str((files["a/eins.txt"] as PackedByteArray).get_string_from_utf8()).is_equal("EINS")
	assert_int((files["a/leer.txt"] as PackedByteArray).size()).is_equal(0)


## Die Datei hinter einem Eintrag wird auf 512 Bytes aufgefüllt; wer das Auffüllen falsch
## rechnet, liest den nächsten Kopf als Inhalt.
func test_a_body_of_exactly_one_block_does_not_swallow_the_next_entry() -> void:
	var files := TarGz.parse(TarBuilder.tar([
		TarBuilder.entry("voll", "x".repeat(512)),
		TarBuilder.entry("danach", "DA"),
	]))
	assert_int((files["voll"] as PackedByteArray).size()).is_equal(512)
	assert_str((files["danach"] as PackedByteArray).get_string_from_utf8()).is_equal("DA")


func test_a_chain_of_links_ends_at_the_file() -> void:
	var files := TarGz.parse(TarBuilder.tar([
		TarBuilder.link("d/lib.so", "lib.so.0"),
		TarBuilder.link("d/lib.so.0", "lib.so.0.4.1"),
		TarBuilder.entry("d/lib.so.0.4.1", "ELF"),
	]))
	assert_str((files["d/lib.so"] as PackedByteArray).get_string_from_utf8()).is_equal("ELF")
	assert_str((files["d/lib.so.0"] as PackedByteArray).get_string_from_utf8()).is_equal("ELF")


## Ein Link ins Leere oder im Kreis wird nicht zu einer Datei.
func test_dangling_and_circular_links_are_dropped() -> void:
	var files := TarGz.parse(TarBuilder.tar([
		TarBuilder.link("d/weg", "gibt-es-nicht"),
		TarBuilder.link("d/hin", "her"),
		TarBuilder.link("d/her", "hin"),
	]))
	assert_dict(files).is_empty()


func test_a_long_gnu_name_is_used_for_the_next_entry() -> void:
	var name := "ordner/" + "n".repeat(140)
	var files := TarGz.parse(TarBuilder.tar([TarBuilder.long_entry(name, "LANG")]))
	assert_array(files.keys()).contains_exactly([name])


func test_a_truncated_archive_gives_nothing() -> void:
	var tar := TarBuilder.tar([TarBuilder.entry("a", "x".repeat(2000))])
	assert_dict(TarGz.parse(tar.slice(0, 1024))).is_empty()


func test_gzip_is_recognised_and_read() -> void:
	var path := "%s/archiv.tar.gz" % DIR
	var tar := TarBuilder.tar([TarBuilder.entry("a", "INHALT")])
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(tar.compress(FileAccess.COMPRESSION_GZIP))
	file.close()
	assert_bool(TarGz.is_gzip(path)).is_true()
	var files := TarGz.read_files(path)
	assert_str((files["a"] as PackedByteArray).get_string_from_utf8()).is_equal("INHALT")


func test_a_zip_is_not_gzip() -> void:
	var path := "%s/archiv.zip" % DIR
	var packer := ZIPPacker.new()
	packer.open(path)
	packer.start_file("a")
	packer.write_file("x".to_utf8_buffer())
	packer.close_file()
	packer.close()
	assert_bool(TarGz.is_gzip(path)).is_false()
	assert_dict(TarGz.read_files(path)).is_empty()
