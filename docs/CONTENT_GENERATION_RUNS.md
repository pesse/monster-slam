# Content-Generierung — Lauf-Protokoll

Log über Ansätze zur Generierung des Vokabel-Contents, um **Qualität vs. Kosten**
verschiedener Wege vergleichbar zu machen. Pro Lauf ein Eintrag; Vergleichstabelle unten.

## Vergleichstabelle

| Lauf | Datum | Ansatz | Modell | Agenten | ~Agent-Tokens | ~Kosten | Output-Objekte | Validierung |
|---|---|---|---|---|---|---|---|---|
| #1 | 2026-07-03 | Parallel-Fan-out + Merge/Validate-Skript | Sonnet (Agenten), Opus (Orchestrierung) | 40 | ~2,0 Mio. | **~40 $** | 7.377 | 0 Fehler / 0 Dubletten |

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
