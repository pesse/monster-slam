class_name SecretVault
extends RefCounted
## Legt ein Geheimnis in den Schlüsselspeicher des Betriebssystems, statt es im Klartext
## nach `user://` zu schreiben (docs/adr/0023-schreib-boss.md, §1).
##
## - **Windows: DPAPI** (`ProtectedData`, Bereich CurrentUser) über die mitgelieferte
##   Windows PowerShell. Heraus kommt ein Base64-Block, den der Aufrufer selbst ablegt;
##   entschlüsseln kann ihn nur dasselbe Windows-Konto auf demselben Rechner. Eine kopierte
##   Datei oder eine Sicherung nützt also niemandem.
## - **macOS: Schlüsselbund** über `/usr/bin/security`. Der Eintrag liegt im Schlüsselbund
##   des Anmeldekontos; zurückgegeben wird nur eine Marke, kein Geheimnis.
## - **Linux: Secret Service** (GNOME-Schlüsselbund, KWallet) über `secret-tool` aus
##   libsecret. Fehlt das Programm, gilt Linux als nicht unterstützt. Auch hier bleibt nur
##   eine Marke beim Aufrufer.
## - Sonst: nicht unterstützt — dann wird nichts gespeichert. Einen Klartext-Notbehelf gibt
##   es mit Absicht nicht.
##
## Das Geheimnis reist **nie in der Kommandozeile** (die sieht jeder in der Prozessliste):
## unter Windows über eine Umgebungsvariable nur für diesen einen Aufruf, unter macOS und
## Linux über die Standardeingabe.
##
## Grenze: Ein Programm, das unter demselben Konto läuft, kommt trotzdem heran — das Spiel
## muss den Schlüssel ja selbst benutzen können. Geschützt ist die Datei, nicht das Konto.
##
## Jeder Aufruf startet einen Prozess (PowerShell braucht dafür eine halbe Sekunde) und
## blockiert. `ApiKeys` merkt sich das Entschlüsselte deshalb für die Laufzeit des Spiels.
##
## Tests ersetzen die Instanz in `ApiKeys.vault` durch eine Unterklasse ohne Prozesse.

## Unter diesem Namen steht das Geheimnis im Schlüsselbund (macOS, Linux).
const SERVICE := "Monster Slam"
## Zusätzliche Entropie für DPAPI: ein Block aus einem anderen Programm desselben Kontos
## lässt sich damit nicht einfach hier hineinkopieren.
const ENTROPY := "monster-slam"
## Die Umgebungsvariable, über die das Geheimnis zu PowerShell reist.
const ENV := "MONSTER_SLAM_VAULT_IN"
## Die Marke, die unter macOS und Linux statt eines Blocks abgelegt wird.
const KEYCHAIN_MARK := "keychain"


## Gibt es auf diesem System einen Schlüsselspeicher?
func supported() -> bool:
	match OS.get_name():
		"Windows", "macOS":
			return true
		"Linux":
			return not _secret_tool().is_empty()
	return false


## Legt `secret` unter `name` ab. Zurück kommt, was der Aufrufer speichern soll (Block oder
## Marke), "" bei einem Fehler.
func protect(name: String, secret: String) -> String:
	match OS.get_name():
		"Windows":
			return _powershell(_PROTECT, secret)
		"macOS":
			var command := "add-generic-password -U -a \"%s\" -s \"%s\" -w \"%s\"\n" \
					% [name, SERVICE, secret]
			return KEYCHAIN_MARK if _stdin("/usr/bin/security", ["-i"], command + "quit\n") \
					else ""
		"Linux":
			var args := ["store", "--label=%s" % SERVICE] + _attributes(name)
			return KEYCHAIN_MARK if _stdin(_secret_tool(), args, secret) else ""
	return ""


## Holt das Geheimnis zurück; "" wenn es nicht (mehr) zu lesen ist.
func reveal(name: String, stored: String) -> String:
	if stored.is_empty():
		return ""
	match OS.get_name():
		"Windows":
			return _powershell(_REVEAL, stored)
		"macOS":
			var output: Array = []
			var code := OS.execute("/usr/bin/security",
					["find-generic-password", "-a", name, "-s", SERVICE, "-w"], output)
			return str(output[0]).strip_edges() if code == 0 and not output.is_empty() else ""
		"Linux":
			var output: Array = []
			var code := OS.execute(_secret_tool(),
					PackedStringArray(["lookup"] + _attributes(name)), output)
			return str(output[0]).strip_edges() if code == 0 and not output.is_empty() else ""
	return ""


## Entfernt das Geheimnis aus dem Speicher (unter Windows gibt es nichts zu tun: der Block
## liegt beim Aufrufer).
func forget(name: String, stored: String) -> void:
	if stored != KEYCHAIN_MARK:
		return
	match OS.get_name():
		"macOS":
			OS.execute("/usr/bin/security", ["delete-generic-password", "-a", name, "-s", SERVICE])
		"Linux":
			OS.execute(_secret_tool(), PackedStringArray(["clear"] + _attributes(name)))


# --- Windows ------------------------------------------------------------------

const _PREAMBLE := "$ErrorActionPreference='Stop';Add-Type -AssemblyName System.Security;" \
		+ "$e=[Text.Encoding]::UTF8.GetBytes('" + ENTROPY + "');$i=$env:" + ENV + ";"
const _PROTECT := _PREAMBLE + "[Console]::Out.Write([Convert]::ToBase64String(" \
		+ "[Security.Cryptography.ProtectedData]::Protect([Text.Encoding]::UTF8.GetBytes($i)," \
		+ "$e,'CurrentUser')))"
const _REVEAL := _PREAMBLE + "[Console]::Out.Write([Text.Encoding]::UTF8.GetString(" \
		+ "[Security.Cryptography.ProtectedData]::Unprotect([Convert]::FromBase64String($i)," \
		+ "$e,'CurrentUser')))"


## Führt `script` mit `input` in der Umgebungsvariablen aus; die Variable wird danach sofort
## wieder entfernt. Die Windows PowerShell 5.1 liegt auf jedem Windows — `pwsh` nicht.
func _powershell(script: String, input: String) -> String:
	var exe := OS.get_environment("SystemRoot").path_join(
			"System32/WindowsPowerShell/v1.0/powershell.exe")
	var output: Array = []
	OS.set_environment(ENV, input)
	var code := OS.execute(exe, ["-NoProfile", "-NonInteractive", "-Command", script], output)
	OS.unset_environment(ENV)
	if code != 0 or output.is_empty():
		return ""
	return str(output[0]).strip_edges()


# --- macOS und Linux ----------------------------------------------------------

## Wartezeit auf das Ende eines Schlüsselbund-Aufrufs (ms).
const STDIN_TIMEOUT_MS := 5000


## Startet `exe` mit `args`, schreibt `input` in die Standardeingabe und wartet auf das Ende.
func _stdin(exe: String, args: Array, input: String) -> bool:
	if exe.is_empty():
		return false
	var pipe := OS.execute_with_pipe(exe, PackedStringArray(args))
	if pipe.is_empty():
		return false
	var stdio: FileAccess = pipe["stdio"]
	stdio.store_string(input)
	stdio.close()
	var pid := int(pipe["pid"])
	var waited := 0
	while OS.is_process_running(pid) and waited < STDIN_TIMEOUT_MS:
		OS.delay_msec(20)
		waited += 20
	return OS.get_process_exit_code(pid) == 0


## Die Attribute, unter denen `secret-tool` den Eintrag findet.
func _attributes(name: String) -> Array:
	return ["service", SERVICE, "account", name]


## Der Pfad zu `secret-tool` aus dem PATH, "" wenn es fehlt.
func _secret_tool() -> String:
	for folder in OS.get_environment("PATH").split(":", false):
		var candidate := folder.path_join("secret-tool")
		if FileAccess.file_exists(candidate):
			return candidate
	return ""
