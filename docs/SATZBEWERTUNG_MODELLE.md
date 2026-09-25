# Modelle für die Satzbewertung — Recherchestand

Stand: 2026-09-24 · Gehört zu: [`adr/0004-satzbewertung-ohne-modell.md`](adr/0004-satzbewertung-ohne-modell.md)

Diese Notiz hält fest, **was es an kleinen Modellen für Englisch↔Deutsch gibt** und warum
die Entscheidung trotzdem gegen ein ausgeliefertes Modell fiel. Sie ist Material für das
ADR, keine Entscheidung — und sie ist ein Stand, kein Dauerzustand: die Zahlen zu den
Modellen stammen aus Modellkarten, Papers und einem Hersteller-Blog, **nicht aus eigenen
Messungen auf der Zielhardware**. Eigene Zahlen gibt es nur zur Bewertung selbst, gegen
einen festen Antwortbogen — sie stehen am Ende, zusammen mit dem, was noch offen ist.

Die Zielhardware ist der Familien- oder Schullaptop: keine zugesicherte GPU, 8 GB RAM oder
weniger, Windows, eine self-contained EXE (ADR 0001).

> **Das Wichtigste zuerst, Stand 2026-09-17:** Die Empfehlung aus den Modellkarten
> (EuroLLM-1.7B) ist an eigenen Zahlen gescheitert, **Qwen3-4B-Instruct-2507** trifft 90–92 %
> des Antwortbogens. Beides steht unter „Zweite Messung". Die Abschnitte davor sind der
> Rechercheteil und bleiben als das stehen, was sie waren: Herstellerangaben.

## Die Leitfrage ist nicht „welches Modell", sondern „welche Aufgabe"

Die Vision sagt „ein LLM kann alternative Formulierungen akzeptieren und semantisch
bewerten". Das klingt nach *einer* Aufgabe, sind aber drei, und sie haben verschiedene
spezialisierte Familien:

| Teilaufgabe | Passende Modellfamilie | Ergebnis |
|---|---|---|
| Satz erzeugen | großes LLM | Text — **braucht keine Laufzeit**, das ist Inhalt (ADR 0004, Entscheidung 1) |
| „Ist das inhaltlich dieselbe Aussage?" | Qualitätsschätzung (COMET-Familie) | eine **Zahl** |
| „Was war daran falsch?" | Grammatikkorrektur (GEC) | **Bearbeitungen** am Satz |
| „Übersetze das" | NMT (Opus-MT, NLLB, …) | eine Übersetzung — die wir **gar nicht brauchen** |

Der häufigste Denkfehler liegt in der letzten Zeile: Übersetzungsmodelle sind die
bekannteste und am besten spezialisierte Familie für en↔de, und sie beantworten die Frage
nicht, die im Bosskampf gestellt wird. Der Spieler übersetzt; das Spiel muss **bewerten
und erklären**.

## Übersetzung (NMT)

| Modell | Parameter | Größe | Lizenz | Anmerkung |
|---|---|---|---|---|
| Opus-MT `de-en` / `en-de` (Marian) | ~75 M | ~300 MB fp32; int8 ≈ ¼ davon | CC-BY 4.0 | ein Modell **je Richtung**; 1500+ Richtungen verfügbar |
| T5-small | 60 M | ~240 MB | Apache 2.0 | generisch, auf dem Paar schwächer als Opus-MT |
| T5-base | 220 M | ~900 MB | Apache 2.0 | |
| NLLB-200-distilled-600M | 600 M | ~2,5 GB | **CC-BY-NC 4.0** | nichtkommerziell — für ein verteiltes Spiel heikel |
| madlad400-3b-mt | 3 B | 12 GB (aggressiv quantisiert <1 GB) | Apache 2.0 | 400+ Sprachen; für ein Paar Verschwendung |
| EuroLLM-1.7B-Instruct | 1,7 B | GGUF Q4 ≈ 1,1 GB | Apache 2.0 | LLM, auf europäischen Parallelkorpora trainiert; laut Modellkarte deutlich besser als Gemma-2B in MT und konkurrenzfähig mit Gemma-7B |

**Spezialisierung schlägt Größe — das bestätigt sich.** Opus-MT wiegt ein Achtel von
NLLB-distilled und übersetzt sein Paar besser. Int8-Quantisierung (CTranslate2) drückt es
auf rund 75 MB bei 2–8× schnellerer Inferenz; das ist die Größenordnung, in der ein Modell
in einer EXE überhaupt diskutabel wäre.

Zweckentfremden ließe es sich für die Bewertung auf zwei Weisen: die Schülerantwort
**zurückübersetzen** und gegen `source_text` vergleichen, oder die Wahrscheinlichkeit der
Antwort unter forciertem Decoding lesen. Beides ergibt eine Zahl ohne Begründung — und
eine, die bei freien, aber richtigen Formulierungen unzuverlässig wird.

## Qualitätsschätzung (die eigentlich passende Familie)

| Modell | Parameter | Art | Anmerkung |
|---|---|---|---|
| **xCOMET-lite** | 278 M | referenzbasiert | destilliert aus xCOMET-XXL: behält **92,1 %** von dessen Qualität bei 2,6 % der Parameter; schlägt COMET-22 und BLEURT-20 auf WMT22 um **6,4 %** bei halber Parameterzahl; 15,2× schneller, 12,5× weniger Spitzenspeicher. Quantisierung nochmal bis 3× kleiner **ohne** Qualitätsverlust |
| COMETKiwi (`wmt22-cometkiwi-da`) | 580 M | **referenzfrei** | XLM-R-basiert, bewertet Quelle↔Hypothese ohne Musterlösung; 2026 weiter aktiv benutzt (IWSLT-Metrik-Track) |

xCOMET-lite quantisiert liegt bei grob 100 MB und ist damit **der stärkste Kandidat, falls
später doch ein Modell mitgeliefert werden soll**. Referenzfreiheit brauchen wir nicht —
eine Musterlösung steht in jedem Satz —, also ist die kleinere, referenzbasierte Variante
die richtige.

Was auch sie nicht liefert: eine Begründung. Eine Zahl sagt dem Kind nicht, dass nach
*yesterday* das Simple Past steht.

## Grammatikkorrektur (GEC)

- **GECToR**-artige Modelle sind encoder-only und nicht-autoregressiv: sie sagen
  *Bearbeitungs-Tags* voraus statt einen Satz zu generieren. Deshalb sind sie billig und
  gelten als die für Produkte attraktive Bauart.
- **(m)T5-basierte Seq2Seq-GEC** (z. B. auf cLang-8 trainiert) ist qualitativ vorn, aber
  autoregressiv und damit teurer.
- Dass das auf Endgeräten geht, ist belegt: Grammarly hat GEC-Modelle per
  Graph-Optimierung (in der Art von TensorRT/ONNX Runtime) um **über 50 %** in Speicher
  und Latenz gedrückt und aufs Gerät gebracht.

GEC ist die Familie, die dem *Lernen* am nächsten steht — sie zeigt die Bearbeitung. Sie
ist aber auf Fehler im Englischen trainiert, nicht auf „passt diese Übersetzung zu diesem
deutschen Satz": ein grammatisch tadelloser Satz mit falschem Inhalt kommt dort sauber
durch.

## Semantische Ähnlichkeit (Embeddings)

Ein mehrsprachiges Satz-Embedding (MiniLM-Klasse, int8, rund 150 MB, wenige Dutzend
Millisekunden) vergleicht die Antwort mit der Menge der akzeptierten Lösungen und verträgt
Umformulierungen, die dort nicht stehen. Billigster Weg zu echter Paraphrasen-Toleranz —
liefert aber wieder nur eine Zahl und verlangt eine native Erweiterung je Plattform.

## Godot-Seite: es scheitert nicht an der Engine

- **NobodyWho** — GDExtension auf llama.cpp, GGUF, Streaming-Chat, strukturierte Ausgabe,
  Tool-Calling, Embeddings, RAG, GPU-Beschleunigung, offline, ohne Server oder Schlüssel.
- **godot-local-llm** — llama.cpp in Godot 4.3+, vollständig offline.
- **godot-llm** — GDExtension für Godot 4.2+, auf NPC-Dialoge gemünzt.

Ein Modell einzubetten wäre also technisch ein gelöstes Problem. Der Verzicht in ADR 0004
ist eine Entscheidung, kein Hindernis.

## Warum daraus trotzdem kein ausgeliefertes Modell wird

1. **Ein kleines LLM als Prüfer lehnt richtige Antworten ab.** Für ein Lernspiel für
   Kinder ist das der teuerste Fehler überhaupt — teurer als eine durchgewinkte falsche
   Antwort. Brauchbar zu urteilen beginnen Allzweck-LLMs etwa ab 3 B, also ~2,5 GB.
2. **Die spezialisierten Kleinen liefern Zahlen, keine Rückmeldung.** Die Rückmeldung ist
   aber der Teil, der das Lernen trägt.
3. **Der Lösungsschlüssel in den Daten weiß mehr als jedes dieser Modelle**, weil er weiß,
   *worum es in der Aufgabe ging* — welches Lexem geprüft wird und welche Zeitform. Kein
   Bewertungsmodell kennt die Unit.
4. **Jeder Spieler bezahlt das Modell**, auch der, dessen Antwort der Schlüssel längst
   erkannt hat.

Daraus die Stufen in ADR 0004: Prüfkarte als Pflicht, ein lokal **vorgefundener** Dienst
als Kür.

## Empfehlungen, falls die Entscheidung später aufgemacht wird

- ~~**Stufe 1 über einen lokalen Dienst:** EuroLLM-1.7B-Instruct statt eines generischen
  Modells gleicher Größe — gebaut für genau diese Sprachrichtung, Apache 2.0.~~
  **Gemessen widerlegt** (2026-09-17, siehe unten): EuroLLM-1.7B bleibt auf der
  Basislinie „sagt zu allem ja". Es gilt jetzt **Qwen3-4B-Instruct-2507 Q4_K_M**
  (Apache-2.0, 2,5 GB) — ein generisches Modell der doppelten Größe, das die Aufgabe kann.
  Das ist der Fall, für den dieser Abschnitt geschrieben war: eine Empfehlung aus
  Modellkarten hält, bis jemand misst.
- **Europäische Alternative: Ministral-3-3B-Instruct-2512** (Mistral, Apache-2.0, Q4_K_M
  rund 2 GB, offizielle GGUF von Mistral). Ungemessen, siehe „Alternative: Ministral 3"
  unten.
- **Stufe 1b in der EXE, falls je gewünscht:** xCOMET-lite quantisiert (~100 MB).
  **Nicht** ein Übersetzungsmodell und **nicht** ein kleines Allzweck-LLM.
- **Finger weg von CC-BY-NC** (NLLB), solange das Spiel öffentlich verteilt wird.

## Alternative: Ministral 3 (Recherche 2026-09-24, ungemessen)

Qwen3-4B ist gemessen und gilt. Soll Stufe 1 ein **europäisches** Modell tragen, ist
**Ministral-3-3B-Instruct-2512** der naheliegende Gegenkandidat — und zwar der einzige, der
in derselben Gewichtsklasse liegt:

| | Ministral-3-3B-Instruct-2512 | Ministral-3-8B-Instruct-2512 |
|---|---|---|
| Hersteller | Mistral AI (FR) | Mistral AI (FR) |
| Lizenz | Apache-2.0 | Apache-2.0 |
| GGUF | offiziell von Mistral, dazu Unsloth | offiziell von Mistral, dazu Unsloth |
| Größe Q4_K_M (geschätzt) | ~2 GB | ~5 GB |
| Deutsch | laut Modellkarte ausdrücklich | laut Modellkarte ausdrücklich |
| Rolle | **Tauschkandidat** für Qwen3-4B | Obergrenze: was ein Europäer kann, wenn die Größe egal ist |

Dafür spricht: Es läuft auf dem offiziellen llama.cpp, also ohne eigenen Build neben
`b11002`. Mistral liefert die GGUF selbst, `model.json` würde damit auf eine
Herstellerdatei festgenagelt statt auf eine Community-Quantisierung. Und die Lizenz ist
dieselbe wie bisher.

Offen ist alles, was zählt. Die Familie kann Bilder verstehen; ob der Text-Teil allein als
GGUF sauber lädt und wie viel RAM er dann braucht, ist ungeprüft. Vor allem ist ungeprüft,
ob es die Falsch-Positiven des ausgelieferten Prompts (`judge-keyed`, 0 von 32) hält.
**EuroLLM-1.7B ist die Warnung**: dessen Empfehlung stand genauso auf Modellkarten und fiel
bei der ersten Messung durch. Gemessen wird wie bei Qwen, in der Werkstatt gegen
`tests/stage1.yaml`, Dauer auf der CPU. Hält das 8B-Modell die Falsch-Positiven nicht,
braucht man das 3B gar nicht erst anzusehen.

Die anderen europäischen Familien (EuroLLM-9B, Apertus-8B, Salamandra, Teuken, Pharia)
sind entweder zu groß für die Zielklasse, zu klein zum Urteilen oder lizenzrechtlich
heikel. Keine davon ist ein Tauschkandidat für das 4B-Modell.

## Gemessen wird gegen einen Antwortbogen

Seit 2026-09-16 gibt es dafür ein Werkzeug statt einer Absichtserklärung:

```bash
tools/godot.sh res://scenes/dev/measure_sentences.tscn            # nur Stufe 0
tools/godot.sh res://scenes/dev/measure_sentences.tscn -- --model # mit Stufe 1
```

Der Antwortbogen (`src/dev/answer_sheet.json`) ist eine feste Liste getippter Antworten
mit dem Urteil, das eine Lehrkraft fällen würde — 10 Sätze, 63 Antworten, sortiert nach
Art: Musterlösung, hinterlegte Variante, **frei** (richtig, aber nicht im Schlüssel),
Falle, Fehler, leer. Das Skript (`src/dev/measure_sentences.gd`) rechnet daraus eine
Vierfeldertafel.

Warum ein Bogen und nicht die Werkbank: `scenes/dev/boss_lab.tscn` beurteilt EINE Antwort
und liefert einen Eindruck. Die Entscheidung über eine zweite Stufe hängt an einer Zahl,
und zwar an der teuersten — wie viele RICHTIGE Antworten abgewiesen werden. Die bekommt
man nur aus einem Maßstab, der sich nicht mit der Laune des Tippenden ändert und der nach
einem Modellwechsel dieselbe Messung wiederholt.

Die Sätze im Bogen sind **erfunden** und nennen ihre `must_contain`-Formen selbst: die
Messung läuft ohne das private Submodule und misst die Regel, nicht den Bestand. Dass der
Bogen in sich stimmt (keine Stolperstelle auf einer richtigen Lösung, kein `variante`, das
nicht im Schlüssel steht), hält `tests/answer_sheet_test.gd` — ein schiefer Maßstab
erzeugte Falsch-Negative, die im Bogen stehen und nicht im Code.

### Was die erste Messung ergab — und was daraus folgte

Die erste Fassung der Prüfkarte gab dort, wo sie nichts im Schlüssel fand, eine geschätzte
Güte aus (die Wort-Überschneidung). Gemessen: 2 Falsch-Negative, **4 Falsch-Positive**, und
**alle sechs Fehlurteile stammten aus genau diesem Zweig** — die 38 Antworten mit einem
echten Befund waren ausnahmslos richtig eingeordnet.

Der Befund war nicht justierbar: „Always she walks to school." enthält dieselben Wörter wie
die Musterlösung und bekam **1,00**. Eine Überschneidung von Wortmengen sieht weder
Reihenfolge noch Beugung — also genau das nicht, was ein Bosskampf übt. Über alle Schwellen
von 0,40 bis 0,80 blieb es dabei.

Daraus wurde die Änderung, die im Nachtrag zu ADR 0004 steht: **ohne Schlüsseltreffer kein
Urteil.** Die Nähe bleibt als `overlap` erhalten und wählt nur noch die Rückmeldung.

### Stand (Stufe 0 allein, Schwelle 0,60)

| | angenommen | abgelehnt |
|---|---|---|
| erwartet richtig | 25 | **12** |
| erwartet falsch | 0 | 26 |

- **Falsch-Positive 0** — und zwar bei jeder Schwelle von 0,40 bis 0,80. Eine falsche
  Antwort kann jetzt nur noch über den Schlüssel durchkommen, also über eine falsche
  Lösung in `accepted`; dagegen steht `tests/sentence_data_test.gd`.
- **Falsch-Negative 12 von 37 (32,4 %)** — das sind exakt die richtigen Antworten im Topf
  ohne Urteil. Sie sind kein Tadel: die Karte sagt „ich weiß es nicht", nicht „falsch".
  Wie ein Kampf das anzeigt, ist offen (ADR 0004, „Nicht entschieden").
- **Ohne Urteil 25 von 63 (39,7 %)**, davon 12 richtig und 13 falsch.

Die Schwellenreihe ist damit flach — die Schwelle ist nicht mehr der Hebel, und das ist der
Sinn der Änderung.

### Was das für eine zweite Stufe heißt

Stufe 1 ist jetzt **das Einzige, was aus einem Zweifel einen Treffer machen kann** — für
Bosskämpfe also keine Kür mehr. Zugleich trägt die Regel „nur heben, nie senken" erst
dadurch: die 13 falschen Antworten im Topf sind bereits abgewiesen, ein Modell kann sie gar
nicht durchwinken; anzuheben hat es nur die 12 richtigen.

Damit hat der Modellversuch ein Erfolgskriterium, das er vorher nicht hatte: **0
Falsch-Positive halten und die 12 Falsch-Negativen Richtung 2 drücken.**

### Und wer stellt den Dienst hin?

Die ursprüngliche Antwort — „wer will, installiert sich Ollama" — trägt nicht mehr,
sobald Stufe 1 für Bosskämpfe tragend ist: sie hieße, dass die halbe Aufgabenart nur auf
Rechnern richtig funktioniert, auf denen jemand einen Modell-Dienst betreibt. Der
Familien-Laptop ist das nicht.

Seit 2026-09-16 bringt das Spiel ihn deshalb selbst mit: `llama-server.exe` aus llama.cpp
(MIT, keine Abhängigkeiten, dieselbe OpenAI-Form) plus eine GGUF-Datei, gestartet von
`LocalModelServer` aus `user://model/`, später als optionaler Pack. Begründung, Abgrenzung
gegen die fertigen Anwendungen (Ollama, LM Studio, Jan, GPT4All, Foundry Local) und die
offenen Punkte stehen im Nachtrag „Stufe 1 auf eigenen Beinen" in
[ADR 0004](adr/0004-satzbewertung-ohne-modell.md).

Gemessen wird damit wie vorher, nur ohne Fremd-App:

```bash
tools/godot.sh res://scenes/dev/measure_sentences.tscn -- --serve --timeout=60
```

### Erste Messung MIT Modell (2026-09-17): der Kandidat trägt nichts bei

Gemessen wurde der Kandidat aus `tools/model/model.json` — `EuroLLM-1.7B-Instruct.Q4_K_M`
auf llama.cpp `b11002`, CPU, über `--serve`:

```
25 unsichere Antworten gefragt, 0 angehoben, 25 ohne Beitrag — 29,7 s (1,2 s je Frage)
```

Die Vierfeldertafel ist danach **Zeichen für Zeichen dieselbe** wie ohne Modell: 12
Falsch-Negative, 0 Falsch-Positive. Das Erfolgskriterium von oben — die 12 Richtung 2
drücken — ist um die volle Strecke verfehlt.

**Am Tempo liegt es nicht.** 1,2 s je Frage liegen deutlich unter den 3,5 s, die der Kampf
hergibt; kein einziger Abbruch. Es liegt daran, dass **keine einzige** der 25 Antworten in
der verabredeten Form kam. Zwei Muster, beide gut erkennbar:

```
"Antwort: She always goes on foot to school."      ← gibt die Schülerantwort zurück
"Antwort: 0.0 bis 1.0"                             ← schreibt den Schema-Text ab
```

Damit ist der Befund **noch kein Urteil über EuroLLM**, denn beide Muster zeigen auf den
Prompt (`LocalModelBackend.prompt_for`), und zwar auf zwei Stellen:

- Die Schülerantwort steht dort unter der Beschriftung `Antwort: …` — und die
  wahrscheinlichste Fortsetzung einer Zeile `Antwort: X` ist eine weitere Zeile
  `Antwort: …`. Ein kleines Modell setzt das Muster fort, statt die Frage zu beantworten.
- Die geforderte Form ist als `{"quality": 0.0 bis 1.0, "feedback": "…"}` angegeben. Das
  ist **kein JSON**, sondern eine Schema-Beschreibung in JSON-Klammern; „0.0 bis 1.0"
  wörtlich abgeschrieben zu bekommen ist die naheliegende Reaktion darauf.

Vor einem „das Modell kann es nicht" stehen deshalb zwei billigere Versuche: die
Beschriftung im Prompt entzerren, und die Form erzwingen statt sie zu erbitten —
llama-server kann `response_format`/GBNF und liefert dann nur noch gültiges JSON. Beides
ist ungeprüft. Erst danach ist die Frage „welches Modell" wieder eine Frage über Modelle.

Der Messlauf hat nebenbei die Ausgabe der beiden Klassen geschärft: `LocalModelBackend`
legt jetzt die VOLLE Antwort ins Log (auf dem Bildschirm steht weiter nur ein Auszug) —
ohne das wären die beiden Muster oben gar nicht zu sehen gewesen.

### Zweite Messung (2026-09-17): der Prompt war es — und das Modell auch

Die beiden billigeren Versuche von oben sind gemacht: **Beschriftung entzerrt** (ein
Prompt, der die Schülerantwort nicht als `Antwort: …` einführt und als Urteil `correct`
oder `incorrect` verlangt statt einer Zahl) und **Form erzwungen** (`response_format`
mit `json_schema`, von llama-server als GBNF umgesetzt). Gemessen wurde in einer eigenen
Werkstatt (`C:\dev\prompt-eval`, promptfoo + ChainForge) gegen **denselben Antwortbogen**,
alle 63 Antworten, zwei Promptvarianten mal zwei Ausgabeformen.

Die Bezugsgröße ist nicht 0, sondern **37 von 63 = 58,7 %** — so gut ist ein Modell, das
stur „correct" sagt. Alles darunter ist schlechter als Schweigen.

| Modell | blind | mit Schlüssel | Form kaputt | Ø Dauer |
|---|---|---|---|---|
| EuroLLM-1.7B-Instruct | auf Basislinie | auf Basislinie | ja, im freien Modus | 1–2 s |
| **Qwen3-4B-Instruct-2507** | **57/63 (90 %)** | **58/63 (92 %)** | **nein, 252/252 gültig** | ~6 s |

Damit ist der Befund von oben zu Ende geführt, und zwar in beide Richtungen:

- **Der Prompt war wirklich ein Teil des Problems.** Mit entzerrter Beschriftung und
  erzwungener Form kommt aus beiden Modellen gültiges JSON statt zurückgegebener
  Schülerantworten. Das war die richtige Reihenfolge.
- **Es war aber nicht nur der Prompt.** EuroLLM-1.7B bleibt auch mit dem besseren Prompt
  auf der Basislinie: es sagt zu fast allem „correct". Das ist jetzt ein Urteil über das
  Modell, kein Verdacht mehr.
- **Die erzwungene Form repariert die FORM, nicht das URTEIL.** Bei Qwen ändert sie an der
  Trefferquote nichts (57 gegen 57, 58 gegen 58) — es schreibt das verabredete JSON schon
  von sich aus. Wer die Struktur erzwingt, hat damit die Struktur und sonst nichts
  gewonnen; sie bleibt trotzdem drin, weil sie nichts kostet.

**Rund 6 Sekunden pro Urteil sind in Ordnung** und ausdrücklich entschieden. (Die Zahl ist
ein Mittel bei vier parallelen Anfragen; einzeln und warm lag ein Aufruf bei etwa 2 s.)
Die 3,5 s aus `LocalModelBackend.HTTP_TIMEOUT` sind damit für den Bosskampf zu knapp
bemessen und nachzuziehen — sie stammen aus einer Zeit, in der Stufe 1 Kür war.

**Was Qwen3-4B falsch beurteilt**, sind acht Antworten in drei Mustern — und die sind
lehrreicher als die Quote:

1. **Satzbau wird nicht geprüft** (Falsch-Positive): „She walks always to school.",
   „We will rent a boat tomorrow." für *Wir haben vor…*, „They built the museum in 1890."
   für *Das Museum wurde 1890 gebaut.* Das Modell liest auf Bedeutung und winkt durch, was
   sinngemäß stimmt — genau das, was ein Bosskampf prüfen soll.
2. **Der Schlüssel wird beantwortet statt der Satz** (nur mit Schlüssel): die **leere
   Antwort** wird zweimal als richtig durchgewinkt, mit der Begründung, sie benutze das
   Pflichtwort „reef". Da steht nichts. Eine leere Eingabe gehört deshalb gar nicht erst
   an ein Modell — das ist ein Zustand und kein Urteil, und `SentenceCard` weiß es schon.
3. **Blind zu streng bei freien Umformulierungen** (Falsch-Negative): Passiv-Umbau,
   `going to` statt Präsens, „grandma and grandpa" für Großeltern. Zwei der drei
   verschwinden, sobald der Schlüssel danebenliegt — dafür ist er da.

Der Lösungsschlüssel wirkt also in beide Richtungen: er drückt die Falsch-Negativen auf
**0** (das Erfolgskriterium von oben, übererfüllt) und hebt die Falsch-Positiven von 3 auf
5. Für Vokabeln ist das der richtige Tausch, für einen Bosskampf ist es einer, über den
man reden muss.

Aufbau, Zahlen im Einzelnen und die nächsten Schritte stehen in `STAND.md` der Werkstatt
`C:\dev\prompt-eval` — ein eigenes Verzeichnis, nicht Teil dieses Repos.

### Noch offen

- Spitzenspeicher und Latenz von xCOMET-lite int8 auf einem Rechner der Zielklasse.
- **Echte Schülerantworten.** Der Bogen ist von Hand geschrieben und damit ein Maßstab,
  kein Stichprobenbefund; er kennt die Fehler, die jemand erwartet hat.
- **Welches Modell: entschieden, aber noch nicht eingetragen.** Die Messung spricht für
  **Qwen3-4B-Instruct-2507 Q4_K_M** (Apache-2.0, 2,5 GB); EuroLLM-1.7B ist damit erledigt.
  `tools/model/model.json` nennt weiterhin EuroLLM, weil der Tausch nicht nur eine Zeile
  ist: das Manifest zeigt auf den **Windows**-Build von llama.cpp, geprüft ist bisher nur
  der Linux-Build in WSL. Dass `b11002` unter Windows dieselbe GGUF lädt, ist plausibel
  und ungeprüft. Die Werte liegen bereit in `C:\dev\prompt-eval\tools\models.json`.
- **Ob der Pack gebaut wird.** Aus 1,0 GB sind 2,5 GB geworden. Dafür trägt Stufe 1 jetzt
  wirklich etwas bei, und sie ist für Bosskämpfe ohnehin tragend („nur heben, nie senken"
  wirkt erst, seit die Prüfkarte ohne Schlüsseltreffer kein Urteil mehr gibt). Die
  Abwägung ist damit eine andere als bei „ein Gigabyte für zwei Antworten", aber nicht
  von selbst entschieden.
- **SmartScreen** auf einer heruntergeladenen, nicht von uns signierten `.exe`. Das
  größte offene Risiko der Pack-Route, und vor dem Pack zu klären.
- **Derselbe Bogen gegen die ausgelieferten Sätze.** Von 1522 Sätzen tragen 12 einen
  Schlüssel; die Quote „unsicher" dürfte dort deutlich höher liegen als die gemessenen
  39,7 %, weil ohne `accepted` jede Umformulierung unsicher ist.

## Quellen

- [picovoice — Popular Open-Source Translation Models for Mobile & Embedded (2026)](https://picovoice.ai/blog/open-source-translation/)
- [Helsinki-NLP/Opus-MT](https://github.com/Helsinki-NLP/Opus-MT) · [ct2fast-opus-mt-de-en (int8/CTranslate2)](https://huggingface.co/michaelfeil/ct2fast-opus-mt-de-en)
- [utter-project/EuroLLM-1.7B-Instruct](https://huggingface.co/utter-project/EuroLLM-1.7B-Instruct) · [GGUF-Quantisierungen](https://huggingface.co/QuantFactory/EuroLLM-1.7B-Instruct-GGUF) · [EuroLLM-Paper](https://arxiv.org/pdf/2409.16235)
- [xCOMET-lite (EMNLP 2024)](https://aclanthology.org/2024.emnlp-main.1223/) · [Code](https://github.com/NL2G/xCOMET-lite)
- [Unbabel/wmt22-cometkiwi-da](https://huggingface.co/Unbabel/wmt22-cometkiwi-da) · [IWSLT 2026 Metrics Track](https://aclanthology.org/2026.iwslt-1.36/)
- [Pillars of Grammatical Error Correction](https://arxiv.org/pdf/2404.14914) · [gec-t5](https://github.com/gotutiyan/gec-t5)
- [Grammarly — On-Device AI at Scale](https://www.grammarly.com/blog/engineering/on-device-models-scale/)
- [mistralai/Ministral-3-3B-Instruct-2512-GGUF](https://huggingface.co/mistralai/Ministral-3-3B-Instruct-2512-GGUF) · [Ministral-3-8B-Instruct-2512-GGUF](https://huggingface.co/mistralai/Ministral-3-8B-Instruct-2512-GGUF)
- [NobodyWho](https://github.com/nobodywho-ooo/nobodywho) · [godot-local-llm](https://github.com/MhrnMhrn/godot-local-llm) · [godot-llm](https://github.com/Adriankhl/godot-llm)
