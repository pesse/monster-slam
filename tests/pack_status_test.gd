extends GdUnitTestSuite
## Die Zustandsmatrix eines Packs. Hier entscheidet sich, was angeboten wird — und die
## Fälle, die selten auftreten (App zu alt, Inhalt zu alt, rotierter Code), sind genau die,
## die im Betrieb niemand von Hand nachstellt.

const OPEN := {
	"id": "language-basic",
	"name": "Grundwortschatz",
	"protected": false,
	"version": "abc123",
	"minVersion": "0.2.0",
	"file": "language-basic.zip",
}

const PROTECTED := {
	"id": "language-access2",
	"name": "Access 2",
	"protected": true,
	"version": "def456",
	"minVersion": "0.2.0",
	"keyVersion": 2,
	"file": "language-access2.enc",
}


func _installed(version: String, min_version := "0.2.0") -> Dictionary:
	return {"version": version, "minVersion": min_version}


# --- Installationsstand -----------------------------------------------------------------

func test_nicht_installiert() -> void:
	var status := PackStatus.evaluate(OPEN, {}, "0.2.0", {})
	assert_int(status.install).is_equal(PackStatus.Install.AVAILABLE)
	assert_int(status.block).is_equal(PackStatus.Block.NONE)
	assert_bool(status.installable()).is_true()


func test_installiert_und_aktuell() -> void:
	var status := PackStatus.evaluate(OPEN, _installed("abc123"), "0.2.0", {})
	assert_int(status.install).is_equal(PackStatus.Install.INSTALLED)
	assert_bool(status.installable()).is_false()
	assert_bool(status.wants_attention()).is_false()


func test_andere_version_ist_ein_update() -> void:
	var status := PackStatus.evaluate(OPEN, _installed("alt999"), "0.2.0", {})
	assert_int(status.install).is_equal(PackStatus.Install.UPDATE)
	assert_bool(status.installable()).is_true()
	assert_bool(status.wants_attention()).is_true()


# --- Versionsschranke, beide Richtungen -------------------------------------------------

func test_app_zu_alt_sperrt() -> void:
	var status := PackStatus.evaluate(OPEN, {}, "0.1.0", {})
	assert_int(status.block).is_equal(PackStatus.Block.APP_OUTDATED)
	assert_bool(status.installable()).is_false()
	# Sichtbar, aber unangeboten — und kein Abzeichen, denn der Nutzer kann hier nichts tun,
	# bis das Programm-Update durch ist.
	assert_bool(status.wants_attention()).is_false()


func test_inhalt_zu_alt_ist_kein_sperrgrund() -> void:
	# Installiert wurde unter minVersion 0.2.0, der Index verlangt inzwischen 0.3.0: die
	# Inhalte liegen eine Generation zurück, Mechanik fehlt still. Aktualisieren ist der Fix.
	var entry := OPEN.duplicate()
	entry["minVersion"] = "0.3.0"
	var status := PackStatus.evaluate(entry, _installed("abc123", "0.2.0"), "0.3.0", {})
	assert_int(status.install).is_equal(PackStatus.Install.INSTALLED)
	assert_bool(status.content_outdated).is_true()
	assert_int(status.block).is_equal(PackStatus.Block.NONE)
	assert_bool(status.installable()).is_true()
	assert_bool(status.wants_attention()).is_true()


func test_bestandsinstallation_ohne_minversion_erzeugt_keine_schranke() -> void:
	var status := PackStatus.evaluate(OPEN, {"version": "abc123"}, "0.2.0", {})
	assert_bool(status.content_outdated).is_false()


func test_ohne_app_version_gilt_keine_schranke() -> void:
	# Der Debug-Build meldet "" — sonst sperrte die committete Version die Entwicklung an
	# den eigenen Inhalten aus.
	var status := PackStatus.evaluate(OPEN, {}, "", {})
	assert_int(status.block).is_equal(PackStatus.Block.NONE)


# --- Zugangscodes -----------------------------------------------------------------------

func test_geschuetzt_ohne_code_ist_gesperrt() -> void:
	var status := PackStatus.evaluate(PROTECTED, {}, "0.2.0", {})
	assert_int(status.block).is_equal(PackStatus.Block.LOCKED)
	assert_bool(status.installable()).is_false()


func test_geschuetzt_mit_passendem_code_ist_frei() -> void:
	var status := PackStatus.evaluate(PROTECTED, {}, "0.2.0", {"code": "x", "key_version": 2})
	assert_int(status.block).is_equal(PackStatus.Block.NONE)
	assert_bool(status.installable()).is_true()


func test_veralteter_code_wird_benannt() -> void:
	# Code wurde rotiert (keyVersion 2 im Index, 1 hinterlegt): benennbar statt still
	# scheiternd.
	var status := PackStatus.evaluate(PROTECTED, {}, "0.2.0", {"code": "x", "key_version": 1})
	assert_int(status.block).is_equal(PackStatus.Block.STALE_CODE)
	assert_bool(status.installable()).is_false()


func test_versionsschranke_verdraengt_den_code() -> void:
	# Auch mit gültigem Code bleibt es bei "App zu alt" — das Schloss darf nicht
	# "entsperrt" behaupten, wenn ohnehin nichts installiert werden kann.
	var status := PackStatus.evaluate(PROTECTED, {}, "0.1.0", {"code": "x", "key_version": 2})
	assert_int(status.block).is_equal(PackStatus.Block.APP_OUTDATED)


# --- Felder aus dem Index ---------------------------------------------------------------

func test_felder_werden_uebernommen() -> void:
	var status := PackStatus.evaluate(PROTECTED, _installed("alt"), "0.2.0", {})
	assert_str(status.name).is_equal("Access 2")
	assert_str(status.file).is_equal("language-access2.enc")
	assert_int(status.key_version).is_equal(2)
	assert_str(status.installed_version).is_equal("alt")
