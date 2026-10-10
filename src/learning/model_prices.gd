class_name ModelPrices
extends RefCounted
## Preistabelle der Cloud-Modelle — die EINE Stelle, an der aus Token Geld wird
## (docs/adr/0023-schreib-boss.md, §7).
##
## Gespeichert wird je Abgabe nur der Verbrauch (`WritingLog`: Modell, Token, Zeitpunkt),
## nie ein Betrag. Gerechnet wird hier, und jede Zeile trägt ein Gültig-ab-Datum: ändert
## Anthropic die Preise, kommt eine neue Zeile mit neuem `from` dazu, die alte bleibt —
## so stimmen alte Abgaben weiter.
##
## Quelle: https://platform.claude.com/docs/en/about-claude/pricing („Model pricing"),
## abgerufen am 2026-10-09. US-Dollar je Million Token. `cache_write` ist der Preis für
## 5-Minuten-Cache-Schreiben (das Backend setzt keine 1-Stunden-Breakpoints).
##
## Neben dem Modell des Backends stehen die Ziele, auf die eine serverseitige
## Ersatzanfrage (`fallbacks`) ausweichen kann; deren Antwort trägt das Modell, das
## tatsächlich geantwortet hat.

const MTOK := 1000000.0

## Modell-Id -> Zeilen, nach `from` aufsteigend. `from` ist das Datum, ab dem die Zeile
## gilt; für die erste Zeile eines Modells ist es das Datum, an dem der Preis hier geprüft
## wurde — ältere Abgaben mit diesem Modell gibt es nicht, und wer doch eine hat, bekommt
## die erste Zeile.
const TABLE := {
	"claude-opus-5-5": [
		{"from": "2026-10-09", "in": 4.0, "out": 20.0, "cache_read": 0.20, "cache_write": 5.0},
	],
	"claude-opus-5": [
		{"from": "2026-10-09", "in": 5.0, "out": 25.0, "cache_read": 0.50, "cache_write": 6.25},
	],
	"claude-opus-4-8": [
		{"from": "2026-10-09", "in": 5.0, "out": 25.0, "cache_read": 0.50, "cache_write": 6.25},
	],
	"claude-sonnet-5-5": [
		{"from": "2026-10-09", "in": 2.0, "out": 10.0, "cache_read": 0.10, "cache_write": 2.50},
	],
}


## Kennt die Tabelle das Modell? Ein unbekanntes kostet 0 — die Anzeige ist dann zu
## niedrig, und `known()` sagt, warum.
static func known(model: String) -> bool:
	return TABLE.has(model)


## Die Zeile, die zum Zeitpunkt `unix` galt, oder {} für ein unbekanntes Modell.
static func row(model: String, unix: int) -> Dictionary:
	if not TABLE.has(model):
		return {}
	var rows: Array = TABLE[model]
	var out: Dictionary = rows[0]
	for r in rows:
		if _from_unix(str(r["from"])) <= unix:
			out = r
	return out


## Was eine Abgabe gekostet hat, in US-Dollar. `entry` in der Form von `WritingLog`:
## { at, model, in, out, cr, cw }.
static func cost_usd(entry: Dictionary) -> float:
	var r := row(str(entry.get("model", "")), int(entry.get("at", 0)))
	if r.is_empty():
		return 0.0
	return (float(entry.get("in", 0)) * float(r["in"])
			+ float(entry.get("out", 0)) * float(r["out"])
			+ float(entry.get("cr", 0)) * float(r["cache_read"])
			+ float(entry.get("cw", 0)) * float(r["cache_write"])) / MTOK


static func _from_unix(date: String) -> int:
	return Time.get_unix_time_from_datetime_string(date + "T00:00:00")
