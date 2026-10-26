# ADR 0029 — Erfolge neben den Plaketten

Status: **angenommen** · Datum: 2026-10-25

## Kontext

Die Plaketten (Issue #63) feiern kleine Erfolge mitten im Kampf: groß in der Bildmitte, das
Spiel steht gut zwei Sekunden. Für Tagesziele passt das. Die Wort-Meilensteine (50 bis 1000
Wörter einer Sprache) gab es aber nur einmal, und es fehlte ein Ort für weitere einmalige
Ziele (Boss, Serie, Festung), eine Vorschau auf das, was noch kommt, und Überraschungen
(Issue #74, angelehnt an Steam-Achievements).

## Entscheidung

1. **Zwei Systeme.** Plaketten (`Badges`) gibt es nur noch je Tag und Welle. Was einmal für
   immer erreicht wird, ist ein **Erfolg** (`Achievements`, `AchievementBook`). Die
   Wort-Meilensteine wandern zu den Erfolgen.
2. **Abgeleitet, wo es geht.** Ein Erfolg nennt einen Fakt und eine Zahl; die Fakten
   rechnen sich aus dem vorhandenen Stand (`PlayerProgress`, `PlayerLevel`, `Wallet`,
   `BossRecord`, `FortressTier`, `SessionLog`, `SkillBook`, `Badges`). Gespeichert wird nur
   `id → Zeitpunkt` in `<profil>_achievements.json`; die Datei wächst nur
   (`SaveGuard.MONOTONIC`). Ein freigeschalteter Erfolg bleibt, auch wenn der Fakt wieder
   sinkt (Fähigkeit verlernt).
3. **Moment-Erfolge** lassen sich nicht nachrechnen und kommen aus dem Kampf: über
   EventBus-Signale in `AchievementBook`, die Revanchen einer Welle über `Badges`. Sie sind
   versteckt.
4. **Nachtragen.** Was beim ersten Prüfen schon erfüllt ist, wird einzeln freigeschaltet
   und eingeblendet, mit dem Zeitpunkt dieses Prüfens. Eine unlesbare Datei schaltet nichts
   frei, sonst käme alles noch einmal.
5. **Prüfen am Frame-Ende, nur was ein Signal betrifft**, und jeder Fakt erst, wenn ein noch
   offener Erfolg ihn braucht (`Achievements.fact`). Eine Antwort im Kampf rechnet so nur
   die Wortzahl, nicht die Festungsstufen.
6. **Einblendung unten rechts** wie bei Steam (`AchievementToast`, eigene CanvasLayer):
   Bild, „Erfolg freigeschaltet“, Name und Satz, von unten hereingleitend, überall im Spiel,
   ohne Pause und ohne Taste; mehrere stellen sich an, eine lange Schlange läuft schneller.
   Sie steht in `word_plate_keep_clear` und wird in Kampf und Boss vorgewärmt.
7. **Ansicht im Reiter „Erfolge“ der Statistik**, eine Karte je Erfolg wie bei Steam:
   freigeschaltete mit Zeitpunkt, offene mit grauem Bild (`locked.gdshader`), Stand und
   Balken, versteckte als eine Karte mit ihrer Zahl.
8. **Ein Bild je Erfolg** unter `assets/ui/achievements/icons/` (quadratisch, mit eigenem
   Grund und Rahmen), benannt nach der Id; die Wort-Erfolge teilen sich je Stufe ein Bild
   über alle Sprachen. Ein neuer Erfolg braucht ein Bild (`achievements_test`).

## Folgen

- Ein neuer Erfolg ist ein Eintrag in `Achievements.FIXED`, bei einem neuen Fakt dazu ein
  Eintrag in `live_facts` und ein Auslöser in `AchievementBook._connect_triggers`. Bestehende
  Profile bekommen ihn beim nächsten Start nachgereicht.
- Werkbänke unter `scenes/dev/` schalten nichts frei; sie zeigen den echten Stand.
- Ids werden nicht umbenannt: sie stehen in den Profilen und in der Spur.
- Die Spur bekommt das Ereignis `achievement` mit der Id; `TraceSanitizer` lässt nur sie
  durch. Der Statistik-Kanal sendet die Datei nicht.
