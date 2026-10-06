# ADR 0019 — Das Handbuch im Spiel

Status: **angenommen** · Datum: 2026-10-06

## Kontext

Das Handbuch (`docs/handbuch/`, je Kapitel eine Datei) erklärt, was im Spiel passiert und
warum, am ausführlichsten, wann ein Wort gemeistert ist und wann es wiederkommt
(Kapitel 18). Gelesen wurde es nur auf GitHub. Wer im Spiel über „Heute fällig: 0“
stolpert, sucht die Erklärung dort nicht. Die Hinweise am Zeiger (`Hints`) tragen einen
Satz, keine Tabelle mit Beispielen.

## Entscheidung

1. **Dieselben Dateien, keine zweite Fassung.** Die Markdown-Kapitel kommen über den
   `include_filter` der Export-Presets (`docs/handbuch/*.md`) in die EXE. `docs/` steht
   dafür nicht mehr im `exclude_filter`. Der Ordner enthält nur Markdown, und das ist keine
   Ressource: Godot exportiert es nur, was der Include-Filter nennt. Die übrigen Docs
   bleiben draußen. Gelesen wird zur Laufzeit (`Handbook.read`), das Inhaltsverzeichnis ist
   die Liste unter „## Inhalt“ in `README.md`.

2. **Gegliedert in Blöcke, nicht als ein BBCode-Text** (`Handbook.blocks`). Überschriften
   sind Labels mit eigener Variation (`HandbookTitle`/`HandbookHeading`/
   `HandbookSubheading`). Ein Listenpunkt ist eine Zeile aus Marker und Text mit hängendem
   Einzug. BBCode-`[ol]` kann keinen Folgeabsatz im selben Punkt und keine Startnummer.
   Tabellen und Zeichen (fett, kursiv, Code, Links) macht das RichTextLabel,
   `MarkdownToBbcode.inline`. Unterstützt ist, was das Handbuch benutzt. Ab der ersten
   Linie (`---`) ist Schluss, denn darunter steht die Blätterzeile für GitHub.

3. **Ein Fenster über allem** (`Handbook.open(datei, abschnitt)`): eine eigene
   `CanvasLayer` (110, unter `Hints` 128) direkt unter der Wurzel. So öffnet es aus dem
   Menü, aus einem anderen Fenster und von einer Karte, ohne dass der Screen darunter
   etwas davon weiß. Ist es offen, blättert ein zweiter Aufruf darin. Links stehen die
   Kapitel, rechts die Seite. ↑/↓ wechselt das Kapitel, Bild↑/↓ blättert, Esc oder F1
   schließt. Links zwischen Kapiteln (auch mit `#anker`) bleiben im Fenster, Webseiten
   öffnet der Browser.

4. **Absprünge sind wichtiger als der Einstieg.** Der Einstieg im Startmenü ist ein Symbol
   links neben „Eigene Runde – Expertenmodus“, kein voller Knopf. Wo etwas erklärt werden
   will, steht ein „?“ (`HandbookLink`, `scenes/ui/handbook_link.tscn`) mit Kapitel und
   Überschrift, und zwar:
   - im Titelband der Fenster (Statistik und Einstellungen je nach offenem Reiter);
   - auf Buch- und Gebietskarte;
   - in „Runde vorbereiten“;
   - in der Statistik klein neben „Heute fällig“, „Gemeisterte Aufgaben“, „Nach Unit“ und
     dem Aufgaben-Reiter, die direkt in Kapitel 18 springen.

   F1 öffnet den obersten sichtbaren Absprung. Die kleinen im Inhalt hören nicht darauf
   (`answers_f1 = false`), sonst gewönnen sie gegen den des Fensters.

5. **Der Abschnitt ist die Überschrift, wie sie im Kapitel steht**, und wird wie auf GitHub
   zum Anker (`Handbook.anchor`). `tests/handbook_test.gd` prüft jedes Ziel in jeder
   Szene, die Reiter-Abschnitte im Code und jeden Link im Handbuch. Wer eine Überschrift
   umbenennt, erfährt dort, welches „?“ daran hängt.

## Folgen

- Das Handbuch ist ein Teil der Oberfläche. Ein Kapitel, das etwas Falsches sagt, sagt es
  jetzt auch im Spiel. Ein neues Kapitel kommt in die Liste unter „## Inhalt“, sonst ist
  es im Spiel nicht erreichbar (der Test meldet es).
- Markdown, das der Parser nicht kennt (Bilder, Zitate, Code-Blöcke), bliebe als Zeichen
  stehen. Der Test fängt die häufigsten Reste ab. Wer so etwas ins Handbuch schreibt,
  erweitert zuerst `Handbook.blocks`.
- Im Kampf gibt es keinen Absprung: im HUD stehen keine Hinweise, und die Pause hat noch
  keinen Platz dafür. F1 tut dort nichts.
