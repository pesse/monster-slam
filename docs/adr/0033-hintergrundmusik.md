# ADR 0033 — Hintergrundmusik: Bereiche, Musik-Sets, Lautstärke je Profil

Status: **angenommen** · Datum: 2026-10-19

## Kontext

Das Spiel hatte nur Effekte. Musik soll im Menü, im Kampf und im Bosskampf laufen, aus
wählbaren Sets, die sich später als Belohnung freischalten lassen. Geschwister am selben
Rechner wollen verschieden laut spielen; ADR 0028 hatte die Lautstärken noch geräteweit
gelassen, weil es keine Bedienung gab.

## Entscheidung

1. **Ein Autoload `Music`** spielt; keine Szene ruft einen Player. Der Bereich folgt der
   laufenden Szene (`Music.area_for_scene`): Kampf, Bosskampf, Werkbänke (still), alles
   andere ist Lobby. Menü → Buchwahl → Karte wechselt das Stück nicht.
2. **Bosskampf**: das Stück kommt mit `EventBus.boss_started` und der Boss-Id; ein Set kann
   je Boss ein eigenes tragen (`MusicSet.boss_tracks`), sonst gilt sein allgemeines.
   `boss_ended` blendet aus, damit die Sieges-Fanfare allein steht. Kein Feld an
   `data/bosses/*.json`, damit kein Pack sein `min_app_version` heben muss.
3. **Musik-Set als Resource** `assets/audio/music/<id>/set.tres` (`MusicSet`), in der EXE,
   nicht im Pack. Ein Bereich ohne Stücke fällt auf das Set `standard` zurück, ein
   unbekanntes Set ist das Standard-Set. Mehrere Stücke je Bereich wechseln sich ab, ein
   Stück mit Loop-Flag läuft bis zum Bereichswechsel.
4. **Pause und Zeitlupe dämpfen nur**: das Stück läuft weiter, leiser; in der Zeitlupe und
   im Stillstand schließt dazu ein Tiefpass auf dem Bus `Music`. Das Tempo bleibt, ein
   `AudioStreamPlayer` folgt `Engine.time_scale` nicht.
5. **Lautstärken und Set gelten je Profil** (ersetzt ADR 0028 Punkt 5 für die
   Lautstärken). Ohne eigenen Wert gilt der alte geräteweite aus `[general]`.
6. **Unter gdUnit4 spielt `Music` nichts.**

## Folgen

- Ein neues Set ist ein Ordner mit `set.tres` und seinen Stücken; jede Datei braucht ihren
  Eintrag in `assets/audio/CREDITS.md`. Stücke als OGG Vorbis mit Loop-Flag im Import,
  in einheitlicher Lautheit; jedes Stück vergrößert die EXE.
- Freischalten ist noch nicht gebaut. Es bekommt eine eigene Profildatei über
  `SaveStore` (ADR 0024); die Set-Auswahl zeigt bis dahin alle Sets.
