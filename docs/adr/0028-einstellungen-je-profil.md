# ADR 0028 — Einstellungen je Profil, Stillstand beim Tippen

Status: **angenommen** · Datum: 2026-10-19

## Kontext

Ein Kind mit gebrochenem Arm tippt mit einer Hand. Selbst die tiefste Zeitlupe
(`SkillTree.MIN_SLOW_FACTOR`) lässt die Monster weiterlaufen, während es die Buchstaben
sucht. Gleichzeitig spielen Geschwister am selben Rechner: Grafik, Menügröße, Vollbild und
das Protokoll standen geräteweit in `[general]`, eine Umstellung für das eine Kind traf
auch das andere.

## Entscheidung

1. **Stillstand beim Tippen als Einstellung des Profils** (`UserSettings.typing_standstill`,
   Vorgabe aus). Der Kampf setzt dann den Faktor der Zeitlupe auf 0
   (`SlowMotion.stand_still`): zwischen Enter und Abschicken oder Esc steht die Zeit. Die
   Untergrenze des Zeitwandler-Baums bleibt; ein Baum soll nie bis zum Stillstand führen,
   die Einstellung ist eine Hilfe, kein Spielvorteil, und gibt keinen Ausgleich.
2. **Alles im Einstellungs-Fenster gilt je Profil**: Schwierigkeit und Tempo wie bisher,
   dazu Stillstand, Grafikstufe, Menügröße, Vollbild und Protokoll. Abgelegt wie die
   übrigen Profilwerte als `[<einstellung>] <player_id>=…`.
3. **Ohne eigenen Wert gilt der alte geräteweite** aus `[general]` (`_profile_value`). So
   startet jedes Profil mit dem bisherigen Stand; `[general]` wird nicht mehr geschrieben.
4. **Ein Profilwechsel stellt das Fenster um** (Grafik, Menügröße, Vollbild nur in der EXE
   wie ADR 0017) und schaltet das Protokoll nach dem Wert des neuen Profils.
5. **Geräteweit bleiben** die Lautstärken (ohne Bedienung), der Satzmeister in der Cloud
   (hängt am Schlüssel des Rechners, ADR 0025) und der Statistik-Hinweis (ADR 0021).

## Folgen

- Mit Stillstand dauert eine Welle so lange, wie das Kind tippt. Gerechnet wird sonst
  nichts anders; die Schwierigkeit bleibt `t − c`.
- Ein neues Profil erbt die alten Gerätewerte, nicht die des zuletzt aktiven Profils.
