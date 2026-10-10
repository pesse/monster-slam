# sound-eval – Soundeffekte lokal bewerten

Bewertet, wie gut Soundeffekte zu einem Setting-Profil passen: semantisch mit
[LAION-CLAP](https://github.com/LAION-AI/CLAP) (Gewichte `laion/larger_clap_general`, geladen
über `transformers`), technisch per Signalanalyse, stilistisch gegen bereits akzeptierte Töne.
Läuft vollständig lokal; nur der erste Start lädt das Modell (~800 MB) von Hugging Face.
ElevenLabs ist optional und kostet nur nach ausdrücklicher Bestätigung.

> **Was die Zahlen sind:** CLAP-Werte sind Kosinus-Ähnlichkeiten im Modellraum – „liegt nah an
> dieser Beschreibung / an diesen Referenzen", keine Qualitätswahrscheinlichkeit und kein
> Ersatz fürs Hören. Technische Werte (Pegel, Clipping, Dauer, Stille) sind gemessen.

## Einrichten

```bash
tools/sound_eval/setup.sh          # WSL/Linux: uv, Python 3.12, PyTorch cu128 bzw. CPU, Modell, Selbsttest
tools/sound_eval/setup.sh --cpu    # ohne GPU
```

Windows nativ (PowerShell): `powershell -ExecutionPolicy Bypass -File tools\sound_eval\setup.ps1`
(`-Cpu`, `-CheckOnly`), danach `tools\sound_eval\sound-eval.cmd …`.

- `uv` landet user-lokal in `~/.local/bin`, nichts systemweit.
- WSL: die venv liegt unter `~/.cache/sound-eval/venv` (Linux-Dateisystem, schneller als
  `/mnt/c`, kollidiert nicht mit einer Windows-`.venv`). Windows: `tools/sound_eval/.venv`.
- PyTorch `cu128`, weil RTX-50xx (sm_120) erst ab CUDA 12.8 läuft; ältere Karten ab Turing
  gehen damit auch. Ohne GPU nimmt das Setup die CPU-Variante – langsamer, gleiche Ergebnisse.
- `sound-eval doctor [--smoke]` prüft Python, Torch, CUDA-Architektur, MP3-Support, Modell-Cache.

## Benutzen

```bash
E=tools/sound_eval/sound-eval
$E effects                                         # Effekte des Profils
$E evaluate neu/frost_v1.wav --effect spell_freeze # einzelne Dateien
$E batch assets/audio/sfx                          # ganzes Verzeichnis (rekursiv); Effekt per Dateimuster
$E rank kandidaten/ --effect spell_freeze --top 2  # Varianten vergleichen, die besten empfehlen
$E generate --effect spell_freeze --variants 3 --dry-run   # ElevenLabs: nur Kosten schätzen
$E budget                                          # verbrauchte Credits laut Ledger
```

Optionen: `--profile FILE` (oder `SOUND_EVAL_PROFILE`), `--device cpu|cuda`, `--json` (voller
Report auf stdout), `--no-write`, `--no-references`, `--out DIR`. Reports landen als `.md` +
`.json` in `tools/sound_eval/reports/` (gitignored).

## Bewertung

| Teil | Woher | 0–100 bedeutet |
| ---- | ----- | -------------- |
| `semantic` | CLAP: Ton vs. Prompts des Ziel-Effekts, im Vergleich zu allen anderen Effekten des Profils (Abstand zum Mittel, zum besten anderen, Rang) | Wie eindeutig der Ton im Modell nach *diesem* Effekt klingt |
| `style` | CLAP: Stil-Prompts minus nächster `avoid`-Prompt, relativ zum Referenzbestand | Durchschnittlich typischer Bestandston ≈ 69, eine Std. darunter ≈ 31 |
| `reference` | CLAP Audio–Audio: Top-3-Nähe zum Bestand; gibt es akzeptierte Töne desselben Effekts, zählen sie zur Hälfte | Wie oben, relativ zum Bestand |
| `technical` | gemessen: True Peak, Clipping, LUFS, Dauer gegen Effekt-Vorgabe, Stille vorn/hinten, Abtastrate, DC, Phase | 100 minus Abzüge (Fehler 30, Warnung 10) |

`total` ist das gewichtete Mittel (Gewichte im Profil). Urteil: ≥ 70 „passt gut", ≥ 50
„prüfen", darunter „passt eher nicht"; Clipping oder Stille → „technisch nachbessern", solche
Varianten stehen im Ranking hinten und werden nie empfohlen. Unter 3 Punkten Abstand markiert
das Ranking ein Patt (≈) – dann entscheidet das Gehör.

Vor der Einbettung wird jeder Ton auf Peak normalisiert und an den Rändern von Stille befreit:
Pegel und Stille bewertet die Technik, CLAP soll nur den Inhalt sehen. Audio-Einbettungen werden
je Dateihash in `~/.cache/sound-eval/embeddings` gecacht.

## Profil

YAML, Beispiel und Vorlage: `profiles/monster_slam.yaml`. Prompts auf **Englisch** (darauf ist
CLAP trainiert), Beschreibungen frei. Pfade relativ zur Profildatei.

```yaml
name: Mein Spiel
game: …             # Spiel, für Menschen und Claude
atmosphere: …
style: {description: …, prompts: [magical fantasy game sound], avoid: [8-bit chiptune]}
references: [../assets/sfx]          # akzeptierte Töne
weights: {semantic: 0.4, style: 0.2, reference: 0.25, technical: 0.15}
technical: {loudness_lufs: [-26, -10], max_true_peak_dbfs: -0.5, max_leading_silence_ms: 30}
effects:
  spell_freeze:
    description: Eis, das schlagartig zufriert …
    prompts: [ice freezing suddenly, crackling ending in a bright crystal clink]
    avoid: [glass bottle breaking]   # optional
    duration: [0.6, 1.0]
    files: [spell_freeze*]           # automatische Zuordnung in batch
    references: [../assets/sfx/spell_freeze.wav]  # optional; Bestandsdateien mit passendem Muster zählen ohnehin
    generation_prompt: …             # optional, für ElevenLabs
elevenlabs: {credits_per_second: 20, max_credits_per_run: 300, max_credits_total: 3000}
```

Wenn ein Ton nach Gehör passt, CLAP ihn aber einem anderen Effekt zuordnet, ist oft der Prompt
zu unscharf: Prompts beschreiben, was man hört („crackling ice, bright clink"), nicht was es
bedeutet („freeze spell").

## ElevenLabs

`generate` schätzt die Kosten, prüft Limits pro Lauf und gesamt (Ledger
`~/.cache/sound-eval/elevenlabs-ledger.jsonl`) und sendet **nur** mit `--yes` oder nach
Ja an der Konsole; ohne Terminal endet es mit Exit 3. Erzeugte MP3s landen in
`tools/sound_eval/generated/` (gitignored) und werden sofort bewertet und gerankt. API-Key in
`ELEVENLABS_API_KEY`. Die Credit-Sätze sind Schätzungen (die ElevenLabs-Doku nennt 11–20
Credits/s bei fester Dauer, 100 bei automatischer) – im Profil anpassen; der Ledger zählt die
Schätzung, nicht die echte Abrechnung.

## Tests

```bash
cd tools/sound_eval && UV_PROJECT_ENVIRONMENT=~/.cache/sound-eval/venv uv run --no-sync pytest -q
```

Die Unit-Tests laufen ohne Modell (Fake-Embedder); `tests/test_clap_integration.py` nimmt das
echte Modell gegen `assets/audio/sfx` und wird übersprungen, wenn es nicht im Cache liegt.
