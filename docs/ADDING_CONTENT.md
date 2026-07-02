# Content erweitern

Für den KI-Agenten und Content-Autoren. Grundregel: **eine JSON-Datei ablegen,
fertig.** Die `ContentRegistry` lädt sie beim nächsten Start (oder `reload()`)
automatisch. Jedes Objekt braucht eine eindeutige `id`.

## Vokabel hinzufügen → `data/vocabulary/<lang>/…json`
```json
{
  "id": "vocab.en.cat",
  "source_lang": "de",
  "target_lang": "en",
  "prompt": "die Katze",
  "answers": ["cat"],
  "tags": ["noun", "basics", "animals"],
  "difficulty": 1
}
```
`answers` darf mehrere gültige Übersetzungen enthalten. `tags` steuern, welche
Vokabeln eine Welle zieht (`vocab_tags`).

## Monster hinzufügen → `data/monsters/…json`
```json
{
  "id": "monster.wraith",
  "name": "Schemen",
  "speed": 95.0,
  "hp": 1,
  "carries": "vocabulary",
  "difficulty": 3,
  "sprite": "res://assets/sprites/monsters/wraith.png"
}
```
`speed` steuert den Zeitdruck. Schnelle Monster nur für bereits bekannte Vokabeln.

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
    { "monster": "monster.goblin", "count": 8, "interval": 2.0, "vocab_tags": ["animals"] }
  ]
}
```
`time_pressure`: `none` | `low` | `medium` | `high`. Eine Boss-Welle nutzt
statt `spawns` das Feld `"boss": "<boss-id>"`.

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
