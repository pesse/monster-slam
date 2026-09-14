# Content-Generierung — Lauf-Protokoll

Log über Ansätze zur Generierung des Vokabel-Contents, um **Qualität vs. Kosten**
verschiedener Wege vergleichbar zu machen. Pro Lauf ein Eintrag; Vergleichstabelle unten.

## Vergleichstabelle

| Lauf | Datum | Ansatz | Modell | Agenten | ~Agent-Tokens | ~Kosten | Output-Objekte | Validierung |
|---|---|---|---|---|---|---|---|---|
| #1 | 2026-07-03 | Parallel-Fan-out + Merge/Validate-Skript | Sonnet (Agenten), Opus (Orchestrierung) | 40 | ~2,0 Mio. | **~40 $** | 7.377 | 0 Fehler / 0 Dubletten |
| #2 | 2026-09-03 | Ein-Kontext-Lauf aus Buchfotos (Vision) + Merge/Validate-Skript | Opus | 0 | ~2 Mio. (geschätzt) | ~30 $ (geschätzt) | 1.166 | 0 Fehler / 0 Dubletten |
| #3 | 2026-09-14 | Ein-Kontext-Lauf aus Buchfotos, ohne Beispielsätze | Opus | 0 | ~0,2 Mio. | ~3 $ | 279 | 0 Fehler / 0 Dubletten |

---

## Lauf #1 — Klasse-9-Basisvokabular (Phase 1 + 2)

**Datum:** 2026-07-03
**Ziel:** Grundvokabular A2+/B1 (Gymnasium Kl. 9) im ERM-Datenmodell
(lexemes / forms / relations / sentences / sentence_lexemes).

### Ansatz
- **Orchestrierung (Opus):** Datenmodell aus `docs/` gelesen, Themen/Slices geplant,
  Agenten gestartet, Ergebnisse per **Python-Merge-Skript** dedupliziert und alle
  Querverweise validiert. Godot-Headless-Ladeprüfung als End-to-End-Check.
- **Generierung (40× Sonnet, parallel im Hintergrund):** je Agent ein Thema/Batch,
  Schreiben in ein Staging-Verzeichnis außerhalb `data/` (kein Registry-Pickup),
  finale Antwort nur „WROTE n …" → Orchestrierungs-Kontext bleibt klein.
- **Determinismus/Integrität im Skript, nicht im LLM:** Slug-/ID-Vergabe, Dedup
  (keep-first), Ausschluss vorhandener Basiswörter, Referenzprüfung, Adjektiv-Regel
  für opposite/synonym, Auto-Ergänzung fehlender Gegenrichtung.

### Aufwand
| | Phase 1 (Lexeme) | Phase 2 (Formen/Rel./Sätze) | Summe |
|---|---|---|---|
| Agenten (Sonnet) | 16 | 24 | 40 |
| ~Agent-Tokens | ~0,92 Mio. | ~1,10 Mio. | ~2,0 Mio. |
| Wall-clock (längster Agent) | ~8,7 min | ~9,8 min | 2 Wellen |

**Gesamtkosten: ~40 $** (Agenten Sonnet + Orchestrierung Opus).
Grobe Richtwerte: ~0,02 $/Agent-Objekt bzw. ~1 $ je 185 Output-Objekte.

### Output (7.377 Objekte)
| Kategorie | Objekte | Kernzahlen |
|---|---|---|
| lexemes | 2.007 | 1.222 core / 785 receptive; 199 Dubletten verworfen |
| lexeme_forms | 1.770 | 354 Verben × 5 Formen |
| lexeme_relations | 262 | opposite 132 / synonym 54 / confused_with 76 |
| sentences | 1.522 | 1.222 einfach + 300 anspruchsvoll |
| sentence_lexemes | 1.816 | 1.521/1.522 Sätze verlinkt |

### Qualität
- **Automatisch:** 0 JSON-Fehler, 0 Duplikat-IDs, 0 ungültige Referenzen, Godot lädt
  fehlerfrei. Alle produktiven Verben mit 5 Formen; opposite/synonym nur Adjektiv↔Adjektiv.
- **Stichprobe:** Irregulars korrekt (bought/thought, woke up/woken up), BE-Schreibung
  konsistent (travelled/travelling), Phrasal Verbs richtig gebeugt, Sätze natürlich.
- **Review offen:** 16 Draft-Relationspaare (Nuance in `lemma_de`), alle Sätze `draft`
  (nicht redaktionell gegengelesen). Details: `import_report.md`.

### Stärken / Schwächen dieses Ansatzes
- **+** Hoher Durchsatz durch Parallelität; kleiner Orchestrierungs-Kontext (Agenten
  schreiben Dateien, geben nur Kurzmeldung zurück).
- **+** Integrität garantiert durch Skript, nicht durch LLM-Disziplin → 0 kaputte Refs.
- **+** Günstig: Sonnet für Masse, Opus nur für Planung/Merge.
- **−** Cross-Batch-Redundanz (199 Lexeme doppelt generiert → verworfen; „bezahlte" Tokens).
- **−** Keine redaktionelle Qualitätssicherung der Sätze/Nuancen (nur strukturell geprüft).
- **−** Agenten hinterließen vereinzelt Scratch-Dateien im Staging (mussten weggeräumt werden).

### Ideen für Vergleichsläufe (Qualität ↔ Kosten)
- **Opus-Agenten** statt Sonnet für Nuance/Übersetzungsqualität → Kosten/Qualität messen.
- **Adversariales Review** (2. Agent prüft/kürzt je Batch) → weniger Draft, höhere Kosten.
- **Weniger Redundanz** durch vorab verteilte Wortlisten statt themen-überlappender Batches.
- **Ein-Kontext-Lauf** (kein Fan-out) als Baseline für Konsistenz vs. Durchsatz.
- Einheitliche Metriken je Lauf: $ gesamt, $/Objekt, Draft-Quote, Dublettenquote,
  Referenzfehler, manuelle Korrekturzeit.

---

## Lauf #2 — Access 4, Units 1–4 (aus Buchfotos)

**Datum:** 2026-09-03
**Ziel:** Das Vokabelverzeichnis eines Lehrbuchs als eigenständiges Inhaltspaket
(`language-access4`), Units 1–4.

### Ansatz
- **Kein Fan-out** — der in Lauf #1 als Vergleich vorgemerkte *Ein-Kontext-Lauf*.
  Ein Kontext liest die Fotos, transkribiert Seite für Seite in ein Staging-JSON je
  Seite und führt am Ende zusammen. Keine Agenten, keine Cross-Batch-Redundanz.
- **Quelle sind Fotos, kein Wissen des Modells**: 29 abfotografierte Seiten unter
  `raw/` (gitignored). Vor dem Lesen ein Inventar per Bild-Montagen (Kopf-/Fußzeilen),
  weil die Fotos weder sortiert noch mit EXIF-Zeitstempeln versehen waren; zwei
  Doppelseiten mussten gedreht und geteilt, eine unscharfe Seite geschärft werden.
- **Determinismus/Integrität im Skript**: Slug-/Id-Vergabe aus dem englischen Lemma,
  Dedup keep-first, Kollisionsauflösung statt stillem Überschreiben, regelbasierte
  BE-Verbformen mit expliziten Ausnahmen, Abgeschlossenheitsprüfung.
- **Standalone-Regel**: Dedupliziert wird NUR innerhalb des Pakets. Überschneidung mit
  dem Grundwortschatz bleibt bewusst stehen (eigene Ids `lex.en.a4.*`), weil jedes
  Inhaltspaket allein spielbar sein muss.

### Aufwand
| | Lauf #2 |
|---|---|
| Agenten | 0 (ein Kontext) |
| Bild-Eingaben | 29 Seitenfotos + ~15 Montagen/Ausschnitte |
| ~Tokens | ~2 Mio. (geschätzt, nicht gemessen: wachsender Kontext × 29 Seiten) |
| Wall-clock | ~2 h über zwei Kontextfenster |

### Output (1.166 Objekte)
| Kategorie | Objekte | Kernzahlen |
|---|---|---|
| lexemes | 587 | Unit 1: 161 / 2: 119 / 3: 143 / 4: 164 |
| lexeme_forms | 565 | 113 Einträge × 5 Formen (84 regelbasiert, 29 explizit) |
| lexeme_relations | 14 | 7 Paare opposite/synonym, beidseitig |

### Qualität
- **Automatisch:** 0 JSON-Fehler, 0 doppelte Ids (auch keine gegen den Bestand),
  0 Referenzen aus dem Paket heraus, Godot lädt alle 587 Lexeme in den richtigen
  Unit-Scopes, Testsuite 241/241 grün.
- **Aufgelöst statt verworfen:** 5 Slug-Kollisionen (gleiches Stichwort in anderer
  Wortart oder anderer Bedeutung) bekamen eigene Ids; echte Dubletten gab es keine.
- **Bewusst verworfen:** 20 opposite/synonym-Angaben, deren Gegenwort nicht im Buch
  steht — sie würden die Abgeschlossenheit des Pakets brechen (Issue #15).
- **Lücke:** zwei Buchseiten (Unit 2) fehlen als Foto, ~40 Wörter. Nachzufotografieren.

### Stärken / Schwächen dieses Ansatzes
- **+** Keine Redundanz, keine Scratch-Dateien, durchgehend konsistente Tag-Vergabe
  (ein Kontext hält das Tag-Vokabular fest, statt es 40× neu zu erfinden).
- **+** Die Vorlage ist das Buch — Übersetzungen und Nuancen sind belegt, nicht erfunden.
- **−** Nicht parallelisierbar: Wall-clock ≈ Anzahl Seiten; der Kontext läuft voll und
  muss zusammengefasst werden.
- **−** Bildqualität ist die Untergrenze der Datenqualität (Bundsteg, Unschärfe,
  Seitenkrümmung). Vor dem nächsten Buch: gerade, vollständige Fotos einsammeln.

---

## Lauf #3 — Access 3, Unit 1 (aus Buchfotos, ohne Sätze)

**Datum:** 2026-09-14
**Ziel:** Das Vokabelverzeichnis von Unit 1 als neues Inhaltspaket (`language-access3`).

### Ansatz
Wie Lauf #2 (ein Kontext, Seite für Seite ins Staging, Merge/Validate im Skript), mit
zwei Abweichungen:

- **Beispielsätze bewusst weggelassen.** Gefordert waren nur die Vokabeln; damit fiel
  die rechte Spalte des Verzeichnisses weg — genau die Spalte, die auf zwei der sechs
  Fotos abgeschnitten ist. Die Lücke in den Fotos wurde so zur Nicht-Lücke im Ergebnis.
- **Kasten-Vokabeln mitgenommen.** Die Grammatik- und Bildkästen des Verzeichnisses
  (Himmelsrichtungen, Fahrtrichtungen, Gegensatzpaare, Verb-Kästen) führen Wörter, die
  nicht als eigene Zeile in der Liste stehen. Sie sind im `notes`-Feld als solche
  markiert, ebenso die wenigen deutschen Entsprechungen, die das Buch nicht glossiert
  und die nach dem Muster des Haupteintrags ergänzt wurden.

### Aufwand
| | Lauf #3 |
|---|---|
| Agenten | 0 (ein Kontext) |
| Bild-Eingaben | 6 Seitenfotos (2 gedreht) + 13 Ausschnitte/Kontrollmontagen |
| ~Tokens | ~0,2 Mio. |
| Wall-clock | ~25 min, ein Kontextfenster |

### Output (279 Objekte)
| Kategorie | Objekte | Kernzahlen |
|---|---|---|
| lexemes | 134 | 65 noun / 35 verb / 15 phrase / 12 adjective / 7 sonstige |
| lexeme_forms | 145 | 29 Verben × 5 Formen (24 regelbasiert, 5 explizit unregelmäßig) |
| lexeme_relations | 0 | keine beidseitig belegten Paare in dieser Unit |

### Qualität
- **Automatisch:** 0 JSON-Fehler, 0 doppelte Ids, 0 Formen ohne Lexem, Godot lädt alle
  134 Lexeme im Scope `access3/1`, Testsuite 378/378 grün, Pack-Zuordnung eindeutig.
- **Aufgelöst statt verworfen:** 1 Slug-Kollision (zwei Einträge mit demselben Stichwort
  in verschiedener Wortart) bekam eine eigene Id.
- **Ohne Formen:** 6 Einträge, die als Konstruktion mit *be* geführt werden — die Formen
  gehören dort zum Hilfsverb, nicht zum Eintrag.
- **Lücke:** auf zwei Fotos ist der Fuß der Seite angeschnitten (S. 174 und S. 177), je
  bis zu drei Einträge. Nachzufotografieren.

### Stärken / Schwächen dieses Ansatzes
- **+** Eine Größenordnung billiger als Lauf #2 je Seite: ohne die Satzspalte schrumpft
  sowohl das, was gelesen, als auch das, was geschrieben werden muss.
- **+** Fotomängel am rechten Rand sind folgenlos, solange nur die linken zwei Spalten
  gebraucht werden — die Anforderung an die Fotos sinkt mit dem Umfang des Ziels.
- **−** Ohne Sätze fehlt dem Paket der Kontext, aus dem später Boss-/Satzaufgaben kommen
  sollen; wer sie will, muss die Seiten erneut fotografieren und lesen.
- **−** Angeschnittene Seitenfüße fallen erst beim Zählen auf, weil die Liste nahtlos
  weiterläuft. Beim Fotografieren gehört die Fußzeile mit ins Bild — sie ist der Beleg,
  dass die Seite vollständig ist.
