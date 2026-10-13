class_name SpacedRepetition
extends RefCounted
## Wiederholung mit Abstand (ADR 0018): wie viel ein Treffer zählt und wann eine Aufgabe
## wieder dran ist, beides aus Confidence und letzter Antwort, ohne eigenen Zustand.
## Zeitbasis sind Unix-Sekunden; nach einer richtigen Antwort wird zu Beginn des lokalen
## Tages fällig (`utc_offset`).

## Sekunden je Tag.
const DAY := 86400
## Abstand nach einer falschen Antwort (s), zugleich der kleinste, der zählt.
const RELEARN_SECONDS := 600

## Anteil der Lücke zu 1, den ein Treffer schließt: GAIN_MIN direkt nach der letzten
## Antwort, GAIN_MAX nach einem vollen Abstand (spacing_gain).
const GAIN_MIN := 0.10
const GAIN_MAX := 0.40

## Intervall nach einer richtigen Antwort, je Confidence: [ab Confidence, Tage]. Darunter
## ein Tag.
const INTERVALS := [[0.985, 45], [0.975, 30], [0.95, 14], [0.9, 7], [0.8, 3]]


## Wie viel ein Treffer zählt, nach dem Abstand zur letzten Antwort auf dieselbe Aufgabe.
##
## Logarithmisch zwischen RELEARN_SECONDS (GAIN_MIN) und dem vollen Abstand (GAIN_MAX);
## der volle Abstand ist ein Tag oder das längere geplante Intervall. `elapsed` < 0 heißt
## erste Antwort und zählt voll.
static func spacing_gain(elapsed: int, interval: int) -> float:
	if elapsed < 0:
		return GAIN_MAX
	var full := float(maxi(DAY, interval))
	var s := log(maxf(float(elapsed), RELEARN_SECONDS) / RELEARN_SECONDS) / log(full / RELEARN_SECONDS)
	return lerpf(GAIN_MIN, GAIN_MAX, clampf(s, 0.0, 1.0))


## Tage bis zur nächsten Wiederholung nach einer richtigen Antwort mit dieser Confidence.
static func interval_days(confidence: float) -> int:
	for step in INTERVALS:
		if confidence >= float(step[0]):
			return int(step[1])
	return 1


## Fälligkeit (unix) aus dem Lernstand einer Aufgabe; 0, wenn sie nie beantwortet wurde.
static func due_at(confidence: float, last_correct: bool, last_seen: int, utc_offset: int) -> int:
	if last_seen <= 0:
		return 0
	if not last_correct:
		return last_seen + RELEARN_SECONDS
	return day_start(last_seen, utc_offset) + interval_days(confidence) * DAY


## Beginn des lokalen Tages, in den `now` fällt (unix).
static func day_start(now: int, utc_offset: int) -> int:
	return int(floor(float(now + utc_offset) / DAY)) * DAY - utc_offset
