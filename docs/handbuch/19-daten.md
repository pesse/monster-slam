# 19. Wo die Daten liegen

Alles, was ein Profil sich erspielt (Lernstand, Gold, Erfahrung, Fähigkeiten, Boss-Siege,
Einstellungen, Meldungen und Protokoll), liegt im Benutzer-Datenordner des Spiels auf
diesem Rechner, nicht im Spielordner. Deshalb überlebt es auch ein Update. Unter Windows
ist das in der Regel `%APPDATA%\Godot\app_userdata\Monster Slam\`, auf dem Mac
`~/Library/Application Support/Godot/app_userdata/Monster Slam/`. Den genauen Pfad der
Protokolldatei zeigt der Reiter „Protokoll“ in den Einstellungen, und „Ordner öffnen“
führt direkt dorthin.

Im selben Ordner liegen die Sicherungen (`backups`, je Profil ein Ordner) und
beschädigte Dateien, die das Spiel beiseitegelegt hat (`quarantine`). Alte Sicherungen
räumt das Spiel selbst weg; beiseitegelegte Dateien bleiben liegen, damit nichts verloren
geht. Wie die Sicherungen funktionieren, steht in [Kapitel 23](23-spielstand-und-sicherungen.md).

Was davon für die Entwicklung an unseren Server geht, und was nie, steht in
[Kapitel 21: Spieldaten für die Entwicklung](21-spieldaten.md).

---

← [18. Wie das Spiel lernt](18-wie-das-spiel-lernt.md) · [Inhalt](README.md) · [20. Der Bosskampf](20-bosskampf.md) →
