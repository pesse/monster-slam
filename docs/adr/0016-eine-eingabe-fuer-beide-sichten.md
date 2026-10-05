# ADR 0016 — Eine Eingabe für beide Sichten

Status: **angenommen** · Datum: 2026-10-05 · ändert ADR 0014 (Einsatz der Zauber)

## Kontext

Die Iso-Sicht und die Ich-Sicht hatten zwei Eingaben. Von oben war das Antwortfeld immer
offen, die Zeitlupe hielt nach jedem Zeichen eine Sekunde nach (`SlowMotion.hold_ms`), und
eine Ziffer setzte einen Zauber nur ein, solange das Feld leer war. Damit das ging, prüfte
`build_packs.py`, dass keine Antwort mit einer Ziffer beginnt. Das nackte P war von oben
ein Buchstabe, gepaust wurde nur mit Strg+P.

Die Ich-Sicht brauchte die Buchstaben zum Laufen und bekam deshalb eine Eingabe mit zwei
Zuständen: Enter öffnet, Enter schickt ab und schließt, Escape schließt. Solange sie offen
ist, hält die Zeitlupe, ohne Haltedauer. Der Zeitwandler-Ast „Nachwirkung“
(`slow_hold_ms`: Atempause, Langer Atem, Stillstand) wirkte dort nicht.

Zwei Regelwerke für dieselben Tasten waren schwer zu erklären, und jede neue Taste im
Kampf hätte für beide Sichten eine eigene Antwort gebraucht.

## Entscheidung

1. **Beide Sichten haben die Eingabe der Ich-Sicht.** `AnswerInput` ist immer zu, bis
   Enter sie öffnet; `gated` entfällt. `AnswerInput.first_person` beschriftet nur noch die
   geschlossene Eingabe mit Laufen und Maus.
2. **Offen gehört jede Taste dem Wort, zu sind Ziffern Zauber und P die Pause.**
   `WaveRunner` fragt dafür `AnswerInput.is_typing()`, nicht den Inhalt des Feldes und
   nicht die Sicht. Die Prüfung `check_no_digit_answers` in `build_packs.py` entfällt:
   eine Antwort darf mit einer Ziffer beginnen.
3. **Die Zeitlupe hält, solange die Eingabe offen ist.** Die Haltedauer je Zeichen und der
   Effekt `slow_hold_ms` entfallen. `typing_activity` bleibt als Signal, es spannt den
   Bogen der Ich-Sicht.
4. **Der Ast „Nachwirkung“ fällt aus dem Zeitwandler.** **Zähe Zeit** wird die Wurzel,
   Zeitriss und Schwere Schritte hängen daran, Zäher Boden und Späte Horde hinter
   Schweren Schritten.

## Folgen

- Von oben braucht jede Antwort ein Enter mehr, dafür beginnt die Zeitlupe schon beim
  Öffnen statt beim ersten Buchstaben.
- Escape im offenen Feld schließt nur das Feld, erst das zweite bricht den Kampf ab.
- Gelernte Knoten, die es nicht mehr gibt, zählen nicht mehr: `SkillTree.spent` überspringt
  unbekannte Ids, die Punkte sind ohne Migration wieder frei. Wer Schwere Schritte ohne die
  frühere Wurzel gelernt hat, behält den Knoten, auch ohne Zähe Zeit. Das ist ein
  Zustand, den das Lernen sonst nicht herstellt; geprüft wird die Vorstufe nur beim Lernen.
