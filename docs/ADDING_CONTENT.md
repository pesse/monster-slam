# Content erweitern

Für den KI-Agenten und Content-Autoren. Grundregel: **eine JSON-Datei ablegen,
fertig.** Die `ContentRegistry` lädt sie beim nächsten Start (oder `reload()`)
automatisch. Jedes Objekt braucht eine eindeutige `id`.

> **Wo liegt was?** Sprachdaten (`lexemes`, `lexeme_forms`, `lexeme_relations`,
> `sentences`, `sentence_lexemes`) liegen unter `data/language/` — ein separates
> **privates** Submodule, weil sie aus urheberrechtlich geschütztem
> Lehrbuchmaterial abgeleitet sind. Spielkonfiguration (Monster, Bosse, Wellen,
> Skills, Aufgaben-Regeln) liegt direkt unter `data/` im öffentlichen Repo.
> Änderungen an Sprachdaten werden im Submodule committet und gepusht.
>
> **Achtung:** eine Datei im Repo ist noch nicht beim Spieler — die verteilte EXE
> enthält keine Sprachdaten. Siehe „Wie kommt neuer Stoff zum Spieler?" unten.

## Sprachdaten & Aufgaben (ERM)

Sprachdaten, Aufgaben-Regeln und Darstellung sind getrennt (siehe `docs/ARCHITECTURE.md`).
Aufgaben werden **nicht mehr pro Wort** angelegt: Es gibt wenige statische
**task_definitions** (Regeln), und der `WaveGenerator` kombiniert sie zur Laufzeit mit
passenden Lexemen. Ein neues Wort abzufragen heißt daher meist nur: **Lexem anlegen** —
für bestehende Aufgabentypen (translate/…) entstehen die Aufgaben automatisch.
Formen und Relationen sind optional und nur für bestimmte Aufgabentypen nötig.

### 1. Lexem → `data/language/lexemes/…json`
Das Wort selbst (Was?).
```json
{ "id": "lex.en.cat", "type": "noun", "lemma_de": "die Katze", "lemma_en": "cat", "tags": ["animals"] }
```
`type`: `noun` | `verb` | `adjective` | `phrase` | `conjunction` | `preposition` | … — die
Wortart. Steuert `allowed_types` der Aufgaben; **nicht** in die `tags` duplizieren.

**Zwei getrennte Auswahl-Achsen** (fürs Session-Setup, siehe `docs/ARCHITECTURE.md`):
- *Themen* über `tags` (z.B. `animals`, `body`, `nature`; Attribute wie `plural`,
  `irregular`, `context`). Leere/keine Tags = keine Themen-Einschränkung.
- *Curriculum* über die optionalen Felder `book` (z.B. `"access2"`) + `unit` (int). Damit
  lässt sich „genau diese Unit" üben (Filter schneidet Curriculum UND Themen). Ohne die
  Felder zählt das Wort zum ungebundenen Grundwortschatz und erscheint nur ohne Scope.
```json
{ "id": "lex.en.a2.throat", "type": "noun", "book": "access2", "unit": 6, "lemma_de": "der Hals", "lemma_de_alt": ["die Kehle"], "lemma_en": "throat", "tags": ["body"] }
```
Am Lexem gibt es **keine** `difficulty` — wie schwer ein Wort ist, ergibt sich aus dem
Lernstand (`PlayerProgress.confidence`); Aufgaben-Schwierigkeit steht auf der `task_definition`.

**Optionale Felder** am Lexem:
- `cefr` (`A1`…`C2`) und `frequency_band` (`core`/`high`/`common`/`mid`/`low`/`rare`) sind
  deskriptive Metadaten. Sie setzen **keine** `difficulty`, liefern aber einen *Prior* für die
  Start-`confidence` einer noch ungesehenen Aufgabe (`WaveGenerator._confidence_prior`):
  schwerere/seltenere Wörter starten unsicherer → langsameres Monster + mehr Punkte. Fehlen die
  Felder, gilt `PlayerProgress.DEFAULT_CONFIDENCE`.
- `notes`: Freitext für Review/Zweifelsfälle (BE/AE-Hinweis, „warum draft"). Wird vom Spiel
  nicht gelesen, hilft aber bei generierten Sets.
- Unregelmäßige Verben mit dem Tag `"irregular"` markieren (kein eigenes Feld) — so lässt sich
  später eine „unregelmäßige Verben"-Welle über den Tag-Filter ziehen.

**Mehrfachübersetzungen** über optionale Arrays `lemma_en_alt` / `lemma_de_alt` — alle
gelten bei `translate` als richtig (Prompt zeigt weiter das primäre Lemma):
```json
{ "id": "lex.en.go", "type": "verb", "lemma_de": "gehen", "lemma_en": "go", "lemma_en_alt": ["walk"], "lemma_de_alt": ["laufen"], "tags": ["basics"] }
```
So akzeptiert „gehen" → `go`/`walk` und „go" → `gehen`/`laufen`. Für reine Varianten
(z. B. `quick`/`fast`, `colour`/`color`) sind die Alt-Listen gedacht. Ist die Alternative
selbst ein eigenes Lernwort mit eigenen Aufgaben, lege besser ein zweites Lexem an.

### 2. Form (nur für Konjugation/Zeitformen) → `data/language/lexeme_forms/…json`
```json
{ "id": "form.eat.past", "lexeme_id": "lex.en.eat", "language": "en", "form_type": "past_simple", "value": "ate" }
```
`form_type`: `base` | `3sg_present` | `past_simple` | `past_participle` | `present_participle` | …

### 3. Relation (nur für opposite/synonym) → `data/language/lexeme_relations/…json`
```json
{ "id": "rel.big.small", "from_lexeme_id": "lex.en.big", "to_lexeme_id": "lex.en.small", "relation_type": "opposite", "confidence": 1.0, "review_status": "approved" }
```
`relation_type`: `opposite` | `synonym` | `confused_with` | `related`.
`opposite`/`synonym` erzeugen Aufgaben nur für Adjektive; `confused_with` erzeugt
`confusables`-Aufgaben (Verwechslungspaare, alle Wortarten, siehe unten) und sollte in
**beiden** Richtungen angelegt werden (`relations_of` schaut nur auf `from_lexeme_id`).
`related` ist Datenbestand ohne Aufgabe.

### 4. Aufgaben-*Regel* → `data/task_definitions/…json`
Beschreibt eine **Regel**, was abgefragt wird — **nicht** pro Wort, sondern einmal pro
Aufgabentyp/Richtung. Der `WaveGenerator` kombiniert sie zur Laufzeit mit allen passenden
Lexemen. Für die vorhandenen Typen (translate/opposite/synonym/conjugation) existieren die
Definitions bereits; ein neues Wort braucht hier **keine** neue Zeile.
```json
{ "id": "def.translate.de_en", "task_type": "translate", "direction": "de_to_en", "allowed_types": ["*"], "difficulty": 1 }
{ "id": "def.opposite", "task_type": "opposite", "direction": "en_to_en", "requires_relation": "opposite", "allowed_types": ["adjective"], "difficulty": 3 }
{ "id": "def.conj.past_simple", "task_type": "conjugation", "direction": "en", "requires_form": "past_simple", "allowed_types": ["verb"], "difficulty": 2 }
```
```json
{ "id": "def.confusables", "task_type": "confusables", "direction": "de_to_en", "requires_relation": "confused_with", "allowed_types": ["*"], "difficulty": 3 }
```
`task_type`: `translate` | `opposite` | `synonym` | `confusables` | `conjugation` | `tense` | `fill_gap`* | `sentence`*.
`confusables` zeigt die deutsche Bedeutung + beide englischen Kandidaten des Verwechslungspaars
(z. B. „sich leihen — borrow oder lend?") und akzeptiert das passende Lemma.
`direction`: `de_to_en` | `en_to_de` | `en_to_en` | `en` (Konjugation).
`allowed_types`: welche Lexem-`type`s die Definition annimmt (`["*"]` = alle) — verhindert
unmögliche Kombinationen (z. B. Adjektiv konjugieren).
`requires_relation` (opposite/synonym) bzw. `requires_form` (conjugation/tense): nur Lexeme,
die die Relation/Form besitzen, werden zu Kandidaten; die Enumeration expandiert über die
tatsächlich vorhandenen Relationen/Formen.
`difficulty`: Basis-Schwierigkeit der Aufgaben-*Art*; der Wave-`difficulty_max` schaltet damit
Aufgabentypen frei/aus. (\*`fill_gap`/`sentence` sind vorerst zurückgestellt.)

Der Fortschritt wird pro **`learnable_id`** geführt (Task-Typ + Richtung + Lexeme/Form/Relation,
z. B. `translate:de_to_en:lex.en.cat`, `opposite:lex.en.big:lex.en.small`,
`confusables:lex.en.borrow:lex.en.lend`, `conjugation:lex.en.go:past_simple`) —
Schema in `TaskResolver.learnable_id()`.

## Monster hinzufügen → `data/monsters/…json`
Monster sind **reine Darstellung** — kein `speed`, keine `difficulty` (Geschwindigkeit ist
Schwierigkeit, siehe unten). Welcher Aufgabentyp welches Monster spawnt, legt eine
`monster_task_rule` fest.
```json
{ "id": "monster.wraith", "name": "Schemen", "hp": 1, "model": "res://assets/models/monsters/Wraith.glb", "model_scale": 2.4, "model_yaw": 0.0 }
```

## Aufgabe↔Monster verknüpfen → `data/monster_task_rules/…json`
```json
{ "id": "mrule.opposite.en_en", "task_type": "opposite", "direction": "en_to_en", "monster_type": "monster.skeleton_warrior", "base_damage": 12, "weight": 1.0 }
```
Die Regel trägt **weder Tempo noch Punkte**. Beide sind Projektionen der Schwierigkeit und
entstehen ausschließlich aus `task_definition.difficulty` + der `PlayerProgress.confidence`
der konkreten Aufgabe + der Wellen-Schwierigkeit (siehe `docs/ARCHITECTURE.md`,
„Tempo = Schwierigkeit"):
- Ein schwererer Aufgabentyp macht das Monster **langsamer** (mehr Zeit zum Abrufen), nicht schneller.
- Und er gibt **mehr Punkte** — je schwerer (auch: je unsicherer der Spieler), desto höher der Reward.

## Boss hinzufügen → `data/bosses/…json`
```json
{
  "id": "boss.syntax_serpent",
  "name": "Syntax-Schlange",
  "hp": 5,
  "sentences": [
	{
	  "prompt": "Sie liest jeden Abend ein Buch.",
	  "reference": "She reads a book every evening.",
	  "hints": { "tense": "Präsens" }
	}
  ]
}
```
Bosse verwenden ganze Sätze; die Bewertung erfolgt semantisch (siehe
`src/learning/answer_evaluator.gd`).

## Welle hinzufügen → `data/waves/…json`
```json
{
  "id": "wave.forest_2",
  "name": "Tiefer Wald",
  "time_pressure": "medium",
  "spawns": [
	{ "count": 8, "interval": 2.0, "task_pool": { "task_types": ["translate"], "tags": ["animals"], "difficulty_max": 2 } }
  ]
}
```
`time_pressure`: `none` | `low` | `medium` | `high`. Ein Spawn nennt **kein** Monster mehr —
der `WaveGenerator` wählt aus dem `task_pool` eine (bevorzugt fällige/neue) Aufgabe und leitet
das Monster über die `monster_task_rules` ab. `task_pool`-Felder (alle optional):
`task_types` (Liste), `direction`, `tags` (Lexem-Tags), `difficulty_max` (0 = kein Limit).
Eine Boss-Welle nutzt statt `spawns` das Feld `"boss": "<boss-id>"`.

## Fähigkeit hinzufügen → `data/skills/…json`
```json
{
  "id": "skill.highlight_word",
  "name": "Wort hervorheben",
  "description": "Hebt ein schwieriges Wort hervor.",
  "effect": "highlight_word",
  "cooldown": 18.0,
  "cost": 0
}
```
Nutzt eine Fähigkeit einen **neuen** `effect`, muss zusätzlich ein Effekt-Handler
für diesen Schlüssel ergänzt werden (rein additiv, bestehende Handler bleiben
unberührt). Verwendet sie einen vorhandenen Effekt, genügt die JSON-Datei.

## Neue Mechanik hinzufügen
Neues System als eigenes Script/Szene anlegen, das relevante `EventBus`-Signale
abonniert (z. B. `monster_defeated`, `answer_submitted`). Kein bestehendes System
muss das neue kennen. Braucht die Mechanik neue Ereignisse, ein Signal im
`EventBus` ergänzen (additiv).

## Wie kommt neuer Stoff zum Spieler?

Eine JSON-Datei im Repo ist im *Entwicklungs*-Spiel sofort da — beim Spieler nicht. Die
verteilte EXE enthält **keine** Sprachdaten (`data/language/*` ist aus dem Export
ausgeschlossen); sie holt Inhalte als **Content-Packs** nach `user://content/<pack-id>/`.
Hintergrund: `docs/ARCHITECTURE.md` („Ausliefern: zwei getrennte Update-Kanäle").

Der Weg einer neuen Datei:

1. **Ablegen und committen** — Sprachdaten im privaten Submodule `data/language/`,
   Spielkonfiguration im Hauptrepo unter `data/`.
2. **Zuordnen.** Jede Datei muss von genau einem Pack in `packs.yaml` (im Content-Repo)
   beansprucht werden. Passt kein Muster oder passen zwei, **bricht der Build ab** —
   Absicht: eine unklare Datei darf nicht versehentlich im offen verteilten Pack landen.
   Neues Buch = neuer Pack-Eintrag (`protected: true`, `password_env`, `key_version`) und
   das Buch-Kürzel zusätzlich in `protected_books`.
3. **Bauen** — der Workflow im Content-Repo baut die Packs und hängt sie an das Release
   mit dem festen Tag `packs` im Transport-Repo. Eine Änderung unter `data/` im Hauptrepo
   stößt denselben Workflow per `repository_dispatch` an; lokal prüfen:
   `python3 tools/packs/build_packs.py --config data/language/packs.yaml --dry-run`.
4. **Holen** — der Spieler sieht den Pack unter „📚 Inhalte" mit Version und Größe,
   geschützte Packs erst nach Eingabe des Zugangscodes.

Was das für Autoren heißt:

- **Nur die `id` zählt.** Dateinamen dürfen sich ändern, IDs nicht: der Installer erkennt
  eine zurückgezogene Datei am Namen und entfernt sie, eine geänderte `id` ist dagegen ein
  neuer Eintrag und der alte bleibt beim Spieler liegen, bis seine Datei verschwindet.
- **Ein Pack überschreibt Eingebautes** bei gleicher `id` — so lassen sich Werte
  korrigieren, ohne eine neue EXE zu verteilen.
- **Ein neues Feld, das Code braucht, braucht `min_app_version`.** Sonst bekommt ein
  Spieler mit alter EXE Daten, die sie nicht versteht. Die Nummer in `packs.yaml` hochziehen;
  ältere Apps blockieren den Pack dann sichtbar statt still falsch zu spielen.
- **Nutzer-Meldungen (⚑) landen nicht im Content**, sondern in
  `user://lexeme_flags.json`. Eine gemeldete Datei wird also weiter aktualisiert; die
  Meldung selbst ist im Repo nicht zu sehen — sie muss aus dem Spiel abgeschrieben werden.

## Checkliste
- [ ] Eindeutige `id` im Schema `kategorie.name`.
- [ ] Referenzierte IDs existieren (Welle → Monster/Boss; Boss/Monster → Sprite-Pfad).
- [ ] Gültiges JSON (die Registry loggt Fehler in die Godot-Konsole).
- [ ] Spielstart zeigt die neuen Zahlen in der Content-Übersicht.
- [ ] Von genau einem Pack in `packs.yaml` beansprucht (`build_packs.py --dry-run` läuft
      grün) — sonst kommt die Datei beim Spieler nie an.
- [ ] Braucht die Datei neuen Code? Dann `min_app_version` in `packs.yaml` hochziehen.
