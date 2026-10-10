class_name SaveNotices
extends RefCounted
## Was der Spieler über seinen Spielstand erfährt (ADR 0024): die Texte zu den Hinweisen des
## SaveCoordinator (`take_notices`). Das Startmenü zeigt sie nacheinander im ConfirmDialog.
##
## Ein Spielstand geht nie still verloren — auch nicht still repariert: wer aus einer
## Sicherung zurückgeholt wurde, soll wissen, dass die Zeit danach fehlt.

const HANDBOOK := "Mehr im Handbuch unter „Spielstand und Sicherungen“."

## Wie die Teile eines Spielstands für den Spieler heißen (Endung der Datei → Name).
const PARTS := {
	"": "Lernstand",
	"_sessions": "Lernzeiten",
	"_wallet": "Gold",
	"_level": "Erfahrung",
	"_skills": "Fähigkeiten",
	"_inventory": "Zauber",
	"_bosses": "Bosse",
	"_badges": "Abzeichen",
	"_test_lists": "Testlisten",
}


## Titel, Text und Knöpfe eines Hinweises: {title, body, action, keep}. `keep` ist leer,
## wenn der Hinweis nur informiert; sonst fragt er, und `action` ist die Tat.
## `name` ist der Anzeigename des Profils.
static func text(notice: Dictionary, name: String) -> Dictionary:
	var parts := part_names(notice.get("files", []))
	match str(notice.get("kind", "")):
		"restored":
			return _inform("Spielstand wiederhergestellt",
					"Der Spielstand von %s war beschädigt (%s). Er wurde aus der Sicherung vom %s "
					% [name, parts, date(int(notice.get("backup_at", 0)))]
					+ "zurückgeholt – was danach gespielt wurde, fehlt. Die beschädigten Dateien "
					+ "sind aufgehoben.\n\n" + HANDBOOK)
		"blocked":
			return {
				"title": "Spielstand beschädigt",
				"body": "Der Spielstand von %s ist beschädigt (%s), und es gibt keine Sicherung. " % [name, parts]
						+ "Damit nichts überschrieben wird, speichert das Spiel für dieses Profil "
						+ "gerade nicht.\n\nWer eine gesicherte Datei hat, lädt sie unter Einstellungen → "
						+ "Profil → „Laden…“. Sonst geht es für diese Teile mit leerem Stand weiter; "
						+ "die beschädigten Dateien bleiben aufgehoben.\n\n" + HANDBOOK,
				"action": "Leer weiterspielen",
				"keep": "Noch nicht",
			}
		"refused":
			return _inform("Nicht gespeichert",
					"Beim Speichern von %s wäre ein Wert gesunken, der nur wachsen kann. " % name
					+ "Das Spiel hat deshalb nicht gespeichert und den letzten guten Stand behalten. "
					+ "Bitte sag den Entwicklern Bescheid.\n\n" + HANDBOOK)
		"implausible":
			return _inform("Erfahrung fehlt",
					"%s hat mehr Skillpunkte ausgegeben als verdient – da ist Erfahrung verloren " % name
					+ "gegangen. Eine gesicherte Datei lässt sich unter Einstellungen → Profil → "
					+ "„Laden…“ einspielen.\n\n" + HANDBOOK)
		"settings_restored":
			return _inform("Einstellungen wiederhergestellt",
					"Die Einstellungen waren beschädigt und wurden aus der letzten Sicherung "
					+ "zurückgeholt. Die Spielstände sind nicht betroffen.")
		"settings_rebuilt":
			return _inform("Einstellungen neu angelegt",
					"Die Einstellungen waren beschädigt oder fehlten. Die Profile wurden in den "
					+ "Spielständen wiedergefunden; Namen und Einstellungen stehen auf Anfang.")
	return {}


## „Erfahrung und Gold" aus den Endungen.
static func part_names(files: Array) -> String:
	var names: Array = []
	for suffix: String in files:
		names.append(PARTS.get(suffix, suffix.trim_prefix("_")))
	if names.size() <= 1:
		return "".join(names)
	return ", ".join(names.slice(0, -1)) + " und " + str(names.back())


## „3.10.2026 um 18:42" in Ortszeit.
static func date(unix: int) -> String:
	var bias := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var at := Time.get_datetime_dict_from_unix_time(unix + bias)
	return "%d.%d.%d um %02d:%02d" % [at["day"], at["month"], at["year"], at["hour"], at["minute"]]


static func _inform(title: String, body: String) -> Dictionary:
	return {"title": title, "body": body, "action": "Verstanden", "keep": ""}
