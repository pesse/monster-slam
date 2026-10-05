# ADR 0014 — Zauber sind Verbrauchsgegenstände, gekauft mit Gold

Status: **angenommen** · Datum: 2026-10-02 · ändert ADR 0003 (Bedeutung von `spells`)

## Kontext

ADR 0003 hat den Namen `spells` den „aktiven Fähigkeiten mit Abklingzeit" gegeben. Gebaut
wurden sie nie: `data/spells/basic_spells.json` hat fünf Einträge mit `cooldown` und
`cost: 0`, `ContentRegistry.spells` wird nur in `main.gd` gezählt, `spell_activated` und
`spell_ready` haben keinen Sender, `GameState.active_spells` hat keinen Leser.

Gold hat dagegen nur einen Abfluss: Verlernen und Zurücksetzen im Fähigkeitsbaum. Eine Kiste
je Welle bringt ungefähr ein Zehntel der Punkte (`ChestReward.GOLD_PER_SCORE`), also
etwa 10 Gold.

Gewünscht sind Zauber, die man mit Gold kauft und die sich beim Einsatz verbrauchen: eine
Hilfe für den Moment, in dem eine Welle zu kippen droht. Ein Abo auf Hilfe soll das nicht
werden. Deshalb gibt kein Zauber etwas, das beim Lernen zählt.

## Entscheidung

1. **`spells` bleibt die Kategorie, ihr Inhalt wird ein Verbrauchsgegenstand.** Ein Zauber
   hat `id`, `name`, `description`, `icon`, `effect`, `params` und `price` (Gold). Eine
   Abklingzeit hat er nicht: wie oft er wirkt, hängt allein am Vorrat. Die Kategorie wird
   nicht umbenannt, damit sie nicht an vier Stellen geändert werden muss (ADR 0003). Die
   alten fünf Einträge entfallen. `spell_ready` entfällt ebenfalls, `spell_activated`
   bekommt seinen ersten Sender.

2. **Der Vorrat gehört zum Profil, nicht zum Lauf** (`Inventory`, Autoload, Ablage
   `user://progress/<profil>_inventory.json`, gesichert bei jeder Änderung wie `Wallet`).
   Gespeichert werden nur die Plätze in ihrer Reihenfolge, je Platz `{id, count}` oder
   leer. Gleiche Zauber stapeln sich ohne Obergrenze; ein neuer Zauber braucht einen freien
   Platz. Wie viele Plätze es gibt, wird gerechnet: `Inventory.BASE_SLOTS` (4) plus
   `SkillBook.bonuses().item_slots`. Die Zahl wird nicht gespeichert. Ein leerer Platz
   rückt nicht nach, damit die Taste eines Zaubers gleich bleibt. Eine gefallene Festung
   oder ein Abbruch kostet nur, was eingesetzt wurde.

3. **Gekauft wird im Laden**, einem Fenster wie den Fähigkeiten
   (`scenes/ui/spell_shop.tscn`). Er öffnet über den Knopf im Hauptmenü und über die
   Knopfreihe der kompakten Plakette, also überall außer im Kampf. Im Debug-Build kostet
   ein Kauf nichts (`Wallet.unlimited_gold`).

4. **Eingesetzt wird im Wellenkampf mit den Ziffertasten 1 bis n**, aber nur, solange das
   Antwortfeld leer ist. Sonst ist die Ziffer ein getipptes Zeichen. Das geht, weil keine
   Antwort mit einer Ziffer beginnt, und `tools/packs/build_packs.py` bricht ab, sobald
   doch eine das tut. Im Bosskampf gibt es vorerst keine Zauber, denn dort enthalten
   Lösungen Jahreszahlen. Die Plätze stehen als Raster unten links im Kampf-HUD, zwei
   Reihen hoch (2×2, mit mehr Plätzen 3×2, 4×2), mit Symbol, Anzahl und Taste. Hinweise
   gibt es dort keine (CLAUDE.md), die Erklärung steht im Laden.

5. **Ein Zauber, der nichts bewirken würde, wird nicht verbraucht.** Beispiele: die
   Festung ist schon heil, es gibt keine Rüstung oder sie ist voll, kein Monster ist auf
   dem Feld. Die Taste tut dann nichts, das Feld zittert kurz.

6. **Die Wirkungen.** „Auf dem Feld" heißt `WaveRunner._active`, nicht „im Blickfeld":

   | `effect` | Wirkung | `params` |
   |---|---|---|
   | `reveal_alts` | Das Schild am Monster zeigt zusätzlich die Alternativen der Aufgabe (`prompt_alt`). | `scope`: `field` oder `wave` |
   | `slow` | Die Monster laufen langsamer, über einen Faktor am Monster, nicht über `Engine.time_scale` (das gehört `SlowMotion` und bremste auch das Tippen). | `scope`, `factor` |
   | `freeze` | Die Monster auf dem Feld bleiben stehen. | `duration` (s) |
   | `strike` | Ein Blitz nimmt alle Monster vom Feld. | — |
   | `heal` | Die Festung bekommt Leben zurück, höchstens bis `fortress_max_health`. | `amount` |
   | `armor` | Die Rüstung füllt sich auf, höchstens bis `fortress_armor_max`. | `amount` |

   `scope: wave` gilt auch für Monster dieser Welle, die erst noch erscheinen, und endet
   mit der Welle. Zwei Verlangsamungen multiplizieren sich nicht, es gilt der kleinere
   Faktor.

7. **Ein Zauber verändert nicht, wie gelernt wird.**
   - Wer mit sichtbaren Alternativen richtig antwortet, hat richtig geantwortet, ohne
     Abzug.
   - Einfrieren und Verlangsamen verschieben `spawned_at_ms` nicht.
   - Ein Blitz behandelt Monster wie das Wachkatapult: erledigt für den Wellenbalken,
     sonst nichts. Kein Lernstand, keine Erfahrung, keine Punkte, kein Gold, kein Eintrag
     in der Auflösung. Dafür gibt es ein eigenes Signal `monster_struck`, damit die Spur
     den Blitz nicht als Katapult führt. Katapult und Blitz nehmen das Monster gleich vom
     Feld (aus `_active`, angehalten); beim Blitz verschwindet nur das Bild später, wenn
     sein Strahl einschlägt.

   Die Schwierigkeit bleibt bei ihrem einen Maß (`t - c`): kein Zauber geht in die Planung
   einer Welle ein.

## Folgen

- **`min_app_version` des `game`-Packs steigt** auf die App-Fassung, die diese Zauber
  mitbringt. Eine ältere App liest `spells` zwar, wertet die Kategorie aber nirgends aus.
  Die Regel gilt trotzdem: Ein Pack mit Feldern, die ein Client nicht kennt, hebt seine
  Schranke.
- Die Preise stehen in den Daten und sind vorläufig. Gemessen an etwa 10 Gold je Welle ist
  ein Blitz mehrere Wellen Arbeit, und so ist es gewollt.
- Neue Effekte (Blitz, Eis) gehören in `FxWarmup`, sonst ruckelt der erste Einsatz.
- Ein Skill kann später Plätze freischalten (`item_slots`). ADR 0003 sah vor, dass ein
  Skill einen Zauber freischaltet. Das bleibt möglich, ist aber nicht Teil dieses ADR.
- ADR 0003 bleibt stehen wie geschrieben. Dass `spells` dort noch Abklingzeiten haben, ist
  Chronologie.
