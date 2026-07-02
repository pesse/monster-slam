# Content erweitern

Für den KI-Agenten und Content-Autoren. Grundregel: **eine JSON-Datei ablegen,
fertig.** Die `ContentRegistry` lädt sie beim nächsten Start (oder `reload()`)
automatisch. Jedes Objekt braucht eine eindeutige `id`.

## Sprachdaten & Aufgaben (ERM)

Sprachdaten, Aufgaben und Darstellung sind getrennt (siehe `docs/ARCHITECTURE.md`).
Ein neues Wort abzufragen heißt: **Lexem anlegen → Aufgabe (task_template) anlegen**.
Formen und Relationen sind optional und nur für bestimmte Aufgabentypen nötig.

### 1. Lexem → `data/lexemes/…json`
Das Wort selbst (Was?).
```json
{ "id": "lex.en.cat", "type": "noun", "lemma_de": "die Katze", "lemma_en": "cat", "difficulty": 1, "tags": ["noun", "basics", "animals"] }
```
`type`: `noun` | `verb` | `adjective` | `phrase`. `tags` steuern, welche Lexeme eine Welle zieht.

**Mehrfachübersetzungen** über optionale Arrays `lemma_en_alt` / `lemma_de_alt` — alle
gelten bei `translate` als richtig (Prompt zeigt weiter das primäre Lemma):
```json
{ "id": "lex.en.go", "type": "verb", "lemma_de": "gehen", "lemma_en": "go", "lemma_en_alt": ["walk"], "lemma_de_alt": ["laufen"], "difficulty": 1, "tags": ["verb", "basics"] }
```
So akzeptiert „gehen" → `go`/`walk` und „go" → `gehen`/`laufen`. Für reine Varianten
(z. B. `quick`/`fast`, `colour`/`color`) sind die Alt-Listen gedacht. Ist die Alternative
selbst ein eigenes Lernwort mit eigenen Aufgaben, lege besser ein zweites Lexem an.

### 2. Form (nur für Konjugation/Zeitformen) → `data/lexeme_forms/…json`
```json
{ "id": "form.eat.past", "lexeme_id": "lex.en.eat", "language": "en", "form_type": "past_simple", "value": "ate" }
```
`form_type`: `base` | `3sg_present` | `past_simple` | `past_participle` | `present_participle` | …

### 3. Relation (nur für opposite/synonym) → `data/lexeme_relations/…json`
```json
{ "id": "rel.big.small", "from_lexeme_id": "lex.en.big", "to_lexeme_id": "lex.en.small", "relation_type": "opposite", "confidence": 1.0, "review_status": "approved" }
```
`relation_type`: `opposite` | `synonym` | `confused_with` | `related`.

### 4. Aufgabe → `data/task_templates/…json`
Beschreibt, **was** abgefragt wird (noch kein Monster).
```json
{ "id": "task.translate.cat.de_en", "task_type": "translate", "direction": "de_to_en", "source_lexeme_id": "lex.en.cat", "difficulty": 1, "review_status": "approved" }
```
`task_type`: `translate` | `opposite` | `synonym` | `conjugation` | `tense` | `fill_gap`* | `sentence`*.
`direction`: `de_to_en` | `en_to_de` | `en_to_en` | `en` (Konjugation). Für `opposite`/`synonym`
zusätzlich `target_lexeme_id`, für `conjugation`/`tense` zusätzlich `form_type`.
Nur `review_status: "approved"` wird im Spiel verwendet. (\*`fill_gap`/`sentence` sind vorerst zurückgestellt.)

## Monster hinzufügen → `data/monsters/…json`
Monster sind **reine Darstellung**. Welcher Aufgabentyp welches Monster spawnt, legt eine
`monster_task_rule` fest.
```json
{ "id": "monster.wraith", "name": "Schemen", "speed": 95.0, "hp": 1, "difficulty": 3, "model": "res://assets/models/monsters/Wraith.glb", "model_scale": 2.4, "model_yaw": 0.0 }
```

## Aufgabe↔Monster verknüpfen → `data/monster_task_rules/…json`
```json
{ "id": "mrule.opposite.en_en", "task_type": "opposite", "direction": "en_to_en", "monster_type": "monster.skeleton_warrior", "base_speed": 100.0, "base_damage": 12, "base_reward": 20, "weight": 1.0 }
```
`base_speed` ist das Grundtempo; zur Laufzeit skaliert es zusätzlich mit der
`PlayerProgress.confidence` der konkreten Aufgabe (gut gekonnt → schneller).

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

## Checkliste
- [ ] Eindeutige `id` im Schema `kategorie.name`.
- [ ] Referenzierte IDs existieren (Welle → Monster/Boss; Boss/Monster → Sprite-Pfad).
- [ ] Gültiges JSON (die Registry loggt Fehler in die Godot-Konsole).
- [ ] Spielstart zeigt die neuen Zahlen in der Content-Übersicht.
