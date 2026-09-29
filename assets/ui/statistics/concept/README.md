# Statistik – überarbeitetes Konzept

Entwurf vom 29.09.2026: `statistics-v3.webp`. Noch nicht als vom Nutzer freigegeben markieren.

Übernimmt vom Skill-Tree den fast bildschirmfüllenden Metallrahmen mit schmalem Außenrand, Titelzeile, Schließen-X, plastische Medaillons, goldenen Hover-Ring und dunkelblauen Tooltip mit Goldkante. Öffnet modal, kein seitliches Schieben. Keine Seitenleiste. Kein Profil-Badge in der Statistik.

Tabs: Überblick, Fortschritt, Aufgaben. Der Entwurf zeigt Überblick: Übungsserie und letzte Sitzung oben, Aktivität als Münzenreihe, Fortschritt und Rekorde darunter. Weitere Inhalte können im inneren Bereich scrollen; Kopf und Tabs bleiben stehen. Bei wenig Breite Abschnitte untereinander und Monatsanzeige als Raster.

Tages-Hover und Tastaturfokus zeigen Datum und Übungsstatus. Zahlen und Inhalte bleiben dynamisch. Beispiel: vier aktive Tage 23, 24, 28, 29; heute 29. September. Keine Kauf-/Reset-Aktion für Statistik-Medaillons und kein Zoom.

Wiederverwendung: `ui/skill_tree/medallions/available.webp`, `focus_ring.webp`, `icons/skill_point.webp`, Tooltip-Shell sowie vorhandene Fenster-/Tab- und Hauptmenü-Assets. Flamme und sonstige Statistik-Illustrationen im Konzept sind noch keine separat exportierten Assets.

Bekannte reine Raster-Mockup-Abweichung: Die generierten Tagesbeschriftungen lassen 12 aus und wiederholen 16. Bei Umsetzung Tage 1–30 aus Datum erzeugen; Bild nicht als fertige Oberfläche einbauen. XP-Füllstand exakt 166/400 = 41,5 % statt der ungefähren Bilddarstellung.

Erstellt mit eingebautem `image_gen.imagegen`. Ausgangsprompt: `prompt-v2.txt`. Anschließender Korrekturauftrag: ausschließlich Kalenderreihe auf 30 fortlaufende Tage, aktive Münzen 23/24/28/29 und Tooltip bei 29 korrigieren; übrigen Entwurf bewahren. Referenzen: Skill-Tree v3 und vorherige Statistik-Vorschau. Ältere Konzepte bleiben erhalten.

