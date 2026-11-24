# ADR 0032 — Endungen als Lerneinheit: Deklination und Konjugation im Lateinischen

Status: **Angenommen** · Datum: 2026-11-17 · ergänzt ADR 0007, 0009, 0011, 0012

## Kontext

Latein kennt bisher nur die Stammformen (`la_genitive`, `la_gender`, `la_present_1sg`,
`la_perfect`, `la_ppp`). Tabellen über die Stammformen hinaus stehen in ADR 0007 unter
„Nicht gebaut“. In der Schule werden sie aber geübt und abgefragt: die fünf Fälle in
Singular und Plural, dazu Präsens, Imperfekt, Perfekt und Imperativ.

Als Form am Wort, wie die Konjugation im Französischen (ADR 0008), wären das bei 58 Nomen
eines Abschnitts 580 Aufgaben, nur für die Deklination. Sie verdrängten die Vokabeln, wie
die *-ed*-Formen in Access 4 (ADR 0009, Nachtrag 6), nur zehnmal stärker. Dabei übte das
Kind 58-mal dieselbe Regel. Gelernt wird nicht *amīcōrum*, sondern „o-Deklination,
Genitiv Plural“, und das Wort trägt die Endung nur.

Die Daten tragen schon, was jede regelmäßige Form bestimmt: Lemma, Genitiv und Genus beim
Nomen, Infinitiv, 1. Person und Perfekt beim Verb.

## Entscheidung

1. **Eine Endung ist eine eigene Lerneinheit**, ohne Lexem: eine Zelle einer Tabelle,
   z. B. `la.decl.3.gen_pl` oder `la.pres.a.3pl`. Sie hat einen Lernstand wie jede andere
   Aufgabe, mit eigener `learnable_id` (`ending:la:<zelle>`), und eine `task_definition`
   (`task_type: "ending"`), deren `difficulty` in `t - c` eingeht.
2. **Umfang.** Tabelle mal Zelle; eine Endung, die zwei Klassen gleich bilden, ist eine
   Einheit (`LatinMorphology.SHARES_WITH`: die gemischte Konjugation geht in i- bzw.
   konsonantisch auf, das o-Neutrum in o, die Varianten der 3. in die 3.):
   - Deklination: a, o (m/n), 3. (konsonantisch, i-Stamm, Neutrum), u, e, je zehn Zellen
     (Nominativ, Genitiv, Dativ, Akkusativ, Ablativ, je Singular und Plural).
   - Präsens und Imperfekt: je fünf Klassen (a, e, i, konsonantisch, gemischt) × sechs
     Personen.
   - Imperativ: fünf Klassen × Singular/Plural.
   - Perfekt: sechs Personen, für alle Klassen gleich (Stamm aus `la_perfect`).

   Zusammen gut 130 Einheiten.
3. **Die Formen werden gerechnet, nicht gespeichert.** `LatinMorphology` (`src/learning/`)
   bildet sie aus den vorhandenen Daten:
   - Nomen: Nominativ Singular aus dem Lemma, der Stamm aus `la_genitive`, die Deklination
     aus der Genitivendung, das Neutrum aus `la_gender`. Das Genus bestimmt die
     Deklination nicht (*māter, mātris* f gehört zur 3.).
   - Verb: die Klasse aus Infinitiv und `la_present_1sg` (*-āre*, *-ēre*, *-īre*, *-ere*
     mit *-ō* oder *-iō*). *-ēre* und *-ere* trennt nur das Makron; die Daten tragen es.
   - i-Stämme der 3. Deklination werden aus dem Lemma abgeleitet, nicht als Feld gespeichert:
     gleichsilbig auf *-is*/*-ēs*, auf *-s*/*-x* mit zwei Konsonanten vor der
     Genitivendung, Neutra auf *-e*/*-al*/*-ar*. „Nur Plural“ erkennt der Genitiv auf
     *-um*/*-ōrum*/*-ārum*. Die e-Deklination braucht ein Lemma auf *-ēs* (*deus, deī* ist o).
   - Nicht gefragt wird, was die Aufgabe zeigt oder was das Wort ohnehin lehrt: Nominativ
     Singular, ein gezeigter Genitiv, 1. Person Präsens und Perfekt.
4. **Ausnahmen gehören zum Wort, wie bei den unregelmäßigen Verben (ADR 0009).** Was nicht
   aus Lemma, Genitiv und Genus bzw. Infinitiv, 1. Person und Perfekt nach der Regel seiner
   Klasse folgt, steht ausgeschrieben in `lexeme_forms` (neue Formtypen je Zelle, z. B.
   `la_abl_pl`, `la_pres_2sg`, `la_imp_sg`). Das Lexem trägt `irregular: true`, die Formen
   zählen zur Meisterung des Wortes und laufen im normalen Kontingent. Beispiele: *vīs*,
   *domus*, *deus*, *locus*; *esse*, *posse*, *īre*, *velle*, *nōlle*, *ferre* und ihre
   Komposita; *dīc!*, *dūc!*, *fac!*, *fer!*. Ausgeschrieben werden nur Zellen, die es gibt
   (*vīs* hat keinen Genitiv und Dativ Singular).

   **Hat ein Lexem eine Zelle als Form, trägt es diese Endung nicht.** *esse* ist für keine
   Präsensendung ein Träger, *dīcere* nur für den Imperativ Singular nicht. Eine Zelle hat
   damit genau eine Wahrheit: die ausgeschriebene Form oder die Rechnung.

   ADR 0009 Punkt 2 bekommt einen Absatz für Nomen; der Test, nach dem jedes Lexem mit
   `irregular` ein Verb ist, wird darauf erweitert.
5. **Die Aufgabe:** ein Trägerwort mit Lexikonform und die Zelle, also „rēx, rēgis m →
   Akk. Pl.“ oder „mittere, mittō → 3. Pl. Imperfekt“. Getippt wird nur die Form, ohne
   Pronomen; Makrons werden wie immer gefaltet. Den Genitiv zu zeigen ist Absicht: Er ist
   eine eigene Aufgabe am Wort, und ein falscher Stamm soll nicht die Endung belasten.
   Lernstand bekommt nur die Endung, nicht das Trägerwort.
6. **Trägerwort:** eines aus der laufenden Lektion bzw. dem Scope, dessen Klasse passt und
   das die Zelle nicht ausgeschrieben hat; sonst ein Wort derselben Klasse aus einer
   früheren Lektion des Buchs. Bei Perfektendungen muss das Perfekt des Wortes eingeführt
   sein (ADR 0011 Punkt 2). Gibt es keins, kommt die Endung nicht in den Pool.
7. **Gespielt wird in den normalen Runden**, eingestreut zwischen die Übersetzungen, nicht
   in einem Bonus. Weil die Endung an keinem Wort hängt, muss die Lektion, die sie
   einführt, keine alten Wörter nachholen (anders als ADR 0012). Ab ihrer Lektion steht
   sie in jedem Lauf dieser und jeder späteren Lektion im Pool.
8. **Obergrenze je Welle:** höchstens `ENDING_SHARE` der Monster einer Welle tragen eine
   Endung (Start: ein Viertel). Nomen- und Verbendungen teilen sich das Kontingent.
   Innerhalb davon wählt die übliche Reihenfolge nach Fälligkeit und Confidence.
9. **Einführung:** Fälle, Präsens, Imperfekt und Imperativ gelten ab Lektion 1, die
   Perfektendungen ab dem eingeführten Perfekt des Trägerworts (`ContentRegistry.form_in_scope`,
   ADR 0011). Futur gibt es nicht. Eine Zeitleiste je Buch kann später nachschärfen, ohne
   Lernstand zu verlieren: Er hängt an der Endung, nicht an der Lektion.
10. **Nicht zur Festung.** Die Festungsstufe misst weiter die Wörter (Issue #21), und
    Endungen bewegen den Ring der Karte nicht. Ihr Stand wird aus `PlayerProgress`
    gerechnet, ohne eigenen Speicher. Die Statistik (Reiter „Fortschritt“) und die Buchkarte
    (Knopf „Endungen“, Overlay `EndingSheet`) zeigen ihn als Tabelle (`EndingTable`):
    Zeilen sind Zellen, Spalten Klassen, das Feld trägt die Endung und die Farbe des Stands.
    Eine geteilte Endung steht in jeder ihrer Spalten. Die Karte zählt das ganze Buch.
    Auf der Gebietskarte wählt „Alles ▾“ (`RunRequest.want_content`), was ein Level
    abfragt: Grundformen, Deklinationen, Konjugationen. Ohne Grundformen bleiben nur
    Endungen, die Obergrenze aus Punkt 8 greift dann nicht, weil sonst nichts da ist. Die
    Wahl gehört wie der Satz-Schalter (ADR 0026) dem Lauf, nicht dem Profil, und steht nicht
    in `RunSave`.
11. **„Für eine Arbeit üben“** (`TestLists`, `TestPlaylist`):
    - Neben Wörtern und Form-Boni hat das Buch Zeilen für Endungsgruppen, z. B.
      „3. Deklination“ oder „Imperfekt, a-Konjugation“, gefiltert nach der Zeitleiste. Sie
      stehen vor der ersten Unit und haben die Wortart „Endungen“. Eine
      markierte Gruppe steht in der Liste unter dem neuen Feld `ending_groups`; ältere
      Listen ohne Feld haben keine.
    - Im Beutel der Runde ist jede Zelle einer markierten Gruppe ein Eintrag wie ein
      Wort: Jede kommt einmal dran, bevor eine wiederkommt.
    - Die Obergrenze aus Punkt 8 gilt dort nicht; den Anteil bestimmt die Auswahl. Eine
      Liste nur mit „Präsens, a-Konjugation“ spielt nur Endungen.
    - Trägerwörter kommen zuerst aus den Wörtern der Liste, sonst nach Punkt 6.
    - Der Richtungsfilter zählt Endungen zu „Deutsch gefragt“ (`from_de`), wie die
      Formen: gefragt ist die lateinische Form.
    - Ausgeschriebene Formen unregelmäßiger Wörter (*esse* → *este*) kommen mit ihrem Wort,
      aber nur, wenn die Liste eine Endungsgruppe derselben Tabelle markiert hat; ohne
      Endungen fragt sie nur Übersetzungen und Grundformen. Ebenso zählt die Abfragewahl
      der Karte sie zu Deklination bzw. Konjugation, nicht zu den Grundformen.

## Folgen

- Keine neue Pack-Kategorie. Neu sind der `task_type` `ending` mit dem Feld `ending_table`
  (`game`-Pack) und die Formtypen je Zelle (Latein-Pack); beide heben `min_app_version`.
- Die Ausnahmen der vorhandenen Latein-Lexeme sind von Hand ausgeschrieben. Ein Test prüft,
  dass jedes regelmäßige Nomen und Verb des Katalogs eine Klasse findet. *dare* und seine
  Komposita sind a-Konjugation mit kurzem *a* (*damus*, *dabam*), lang nur in *dās* und *dā*.
- Ein Nomen, das jetzt `irregular` bekommt, verliert seine Meisterung, bis seine Formen
  sitzen. Bei *domus* oder *vīs* kann eine Festungsstufe sinken (wie in ADR 0009).
- Die Spur bleibt, wie sie ist: `lex` ist die Endungs-Id (`ending:la:<zelle>`), kein
  Lehrbuchinhalt. Das Trägerwort steht nicht in der Spur; „Melden“ meldet es.
- `Lexeme.language_of_learnable` kennt die neue Id ohne Lexem.
- Handbuch: Endungen in der Statistik und auf der Karte (Kapitel 12), die Abfragewahl und
  „Für eine Arbeit üben“ in Kapitel 10.

## Offen

- Ob eine Endung beim ersten Auftritt die Lösung zeigt (ADR 0027 Punkt 1). Vorerst nein;
  wenn, dann nicht innerhalb von `INTRODUCTIONS_PER_WAVE`, sonst verdrängen am Anfang
  rund 100 neue Endungen jede neue Vokabel.
- Wert von `ENDING_SHARE` nach den ersten Spuren.

## Nicht gebaut

- Formen erkennen (*amīcīs* → „Dat./Abl. Pl.“): als zweite Aufgabe auf derselben Einheit
  möglich, später.
- Ein Tabellen-Boss für Latein, der eine ganze Tabelle am Stück verlangt.
- Futur, Plusquamperfekt, Futur II, Passiv, Adjektive und Pronomen, Wortgruppen
  (*cum amīcō*, Übereinstimmung von Adjektiv und Nomen).
- Endungen für Englisch und Französisch.
