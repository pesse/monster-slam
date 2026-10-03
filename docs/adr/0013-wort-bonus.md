# ADR 0013 — Wort-Bonus: zusätzliche Vokabeln zu einer Unit

Status: **angenommen** · Datum: 2026-10-03 · ergänzt ADR 0012

## Kontext

Neben dem Buch kommen Vokabeln aus anderen Quellen dazu, etwa eine Seite aus einem
anderen Band, die die Lehrkraft zu einem Dossier mitgibt. Sie gehören inhaltlich zu einer
Unit, sind aber nicht ihr Stoff: Würden sie als Wörter der Unit zählen, sänke die
Festungsstufe, und die Teile der Unit wüchsen um Wörter, die im Buch dort nicht stehen.
ADR 0012 kennt Boni nur für Formen.

## Entscheidung

1. **Ein Lexem mit dem Feld `bonus` (ein Thema, etwa `"unite3"`) steht in einem Wort-Bonus**
   seiner Unit (`book`/`unit` wie jedes Lexem). Je Unit und Thema ein Bonus, ohne Teil:
   Scope-Schlüssel `bonus:<book>/<unit>/0/<thema>`, Kartenpunkt `bonus/0/<thema>`.
2. **Dubletten werden nicht doppelt angelegt.** Steht ein Wort der Seite schon im Buch
   (auch in einer anderen Unit), nennt das vorhandene Lexem den Bonus unter
   `also_bonus: [{ "unit": 1, "bonus": "unite3" }]`. Es bleibt ein Wort seiner Unit, mit
   seinem Lernstand, und spielt zusätzlich im Bonus mit.
3. **Ein Wort aus einem Wort-Bonus ist kein Wort seiner Unit:** kein Teil, nicht in der
   Festung, nicht in der Wortzählung der Unit, nicht in den Sätzen des Bosses. Die eine
   Stelle dafür ist `ContentRegistry._scope_keys` (das Wort steht nur unter seinem
   Bonus-Schlüssel) und `FortressTier.unit_key`.
4. **Im Bonus und in „Gesamt" kommen die Wörter mit allen Aufgaben**, nicht nur mit
   Formen wie bei ADR 0012. Ein Teil-Lauf bringt sie nicht mit (wie ADR 0012 Punkt 4).
5. **Gezählt wird wie bei jedem Bonus in Aufgaben** (`BonusLevel.counts`): je Wort die
   beiden Übersetzungsrichtungen, bei einem unregelmäßigen Verb dazu seine Formaufgaben
   — dieselbe Regel, nach der ein Wort gemeistert ist. Die Festung im Bonus-Lauf ist die
   seiner Unit, auch wenn Wörter aus `also_bonus` aus anderen Units stammen.

## Folgen

- Ein neuer Wort-Bonus ist eine Datei `fr_<buch>_unit<n>_bonus.json` mit dem Feld
  `bonus` an jedem Lexem und ein Punkt mit `title` in `map.json`, den
  `tests/map_screens_test.gd` einfordert.
- Eine ältere App kennt `bonus` nicht und zählte die Wörter zur Unit. Der Pack, der einen
  Wort-Bonus ausliefert, hebt sein `min_app_version`.
