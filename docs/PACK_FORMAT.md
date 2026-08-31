# Pack-Container-Format v1

Vertrag zwischen drei Implementierungen:

| Rolle | Ort |
|---|---|
| Erzeuger | `tools/packs/build_packs.py` (Python) |
| Prüfer / Referenz | `tools/packs/verify_pack.py` (Python) |
| Verbraucher | `src/content/pack_crypto.gd` (GDScript) |

Eine Änderung hier ist eine Änderung an **allen drei** Stellen und braucht eine neue
Formatversion. Warum es die Packs überhaupt gibt: `docs/adr/0001-app-und-content-update.md`.

## Offene Packs

Ein gewöhnliches ZIP mit content-relativen Pfaden (`lexemes/en_basics.json`). Keine Hülle,
keine Kopfdaten. Der erste Pfadabschnitt muss eine Content-Kategorie sein — geprüft beim
Bauen (`check_paths`) und noch einmal beim Auspacken
(`PackInstaller.is_allowed_entry`).

Das ZIP ist deterministisch: sortierte Namen, fester Zeitstempel. Damit hängt die
Pack-Version allein am Inhalt und nicht an der Uhrzeit des Builds.

## Geschützte Packs (`.enc`)

Ein ZIP gleichen Aufbaus, verschlüsselt mit AES-256-CBC und mit HMAC-SHA256 gesichert.

```
Offset  Größe  Feld
     0      6  Magic "MSPACK"
     6      1  Formatversion (= 1)
     7      1  KDF-Kennung (= 1 für PBKDF2-HMAC-SHA256)
     8      4  Iterationen (uint32, big endian)
    12     16  Salt
    28     32  Verifier
    60     16  IV
    76     32  HMAC-SHA256 über Bytes 0…76 ‖ Ciphertext
   108    ...  Ciphertext (PKCS#7-gefüllt)
```

### Schlüsselableitung

```
master   = PBKDF2-HMAC-SHA256(code, salt, iterationen, dklen = 32)
enc_key  = HMAC-SHA256(master, "monster-slam:enc")
mac_key  = HMAC-SHA256(master, "monster-slam:mac")
verifier = HMAC-SHA256(master, "monster-slam:verify")
```

Drei abgeleitete Werte mit drei Aufgaben:

- **`verifier`** steht im Kopf. Er erlaubt die Prüfung eines eingegebenen Zugangscodes über
  einen Range-Request auf die ersten 108 Bytes — ohne den ganzen Pack zu laden. Das verrät
  einem Angreifer nichts Zusätzliches: wer die Datei hat, könnte einen Rateangriff ebenso
  gegen den MAC fahren. Die Kosten pro Versuch bestimmt allein die Ableitung.
- **`mac_key`** sichert Kopf *und* Ciphertext (Encrypt-then-MAC). Ein veränderter Kopf —
  etwa ein herabgesetzter Iterationswert — lässt die Prüfung scheitern, statt still einen
  schwächeren Schlüssel zu erzwingen. **Der MAC wird vor dem Entschlüsseln geprüft.**
- **`enc_key`** entschlüsselt.

### Reihenfolge der Prüfungen

`verifier` zuerst, dann MAC, dann entschlüsseln. Die Reihenfolge ist eine Entscheidung über
Fehlermeldungen, nicht über Sicherheit: ein falscher Zugangscode lässt beide Prüfungen
scheitern, und „Falscher Zugangscode" ist die Meldung, die er braucht. Als Preis meldet ein
manipulierter Kopf ebenfalls „Falscher Zugangscode" statt „verändert" — die Datei wird in
beiden Fällen abgewiesen (`tests/pack_crypto_test.gd`).

### Parameter

`iterationen = 600000` — die OWASP-Empfehlung für PBKDF2-HMAC-SHA256. In GDScript
**gemessen 938 ms** (Godot 4.7, `Crypto.hmac_digest` in einer Schleife); das ist die
Obergrenze dessen, was beim Entsperren zumutbar ist. Der Wert steht im Kopf und ist damit
später erhöhbar, ohne alte Packs unlesbar zu machen.

`PackCrypto.MAX_ITERATIONS` begrenzt ihn nach oben: der Kopf ist zum Zeitpunkt der
Ableitung noch nicht verifiziert, eine manipulierte Datei könnte die App sonst beliebig
lange rechnen lassen.

## Abweichungen vom Vorbild (dnd-planner)

Beide erzwungen davon, was Godot ohne GDExtension anbietet — mit ihren Folgen:

| dnd-planner | hier | Folge |
|---|---|---|
| AES-256-GCM | AES-256-CBC + HMAC (Encrypt-then-MAC) | Gleiche Zusicherung, ein Feld mehr im Kopf. `AESContext` kennt kein GCM. |
| scrypt | PBKDF2-HMAC-SHA256 | Keine Speicher-Härte. Akzeptiert, weil das Ziel „Lehrbuchmaterial liegt nicht als offener Download herum" ist, nicht Widerstand gegen einen finanzierten Angreifer. |

## Gegenproben

```bash
# Inhalt eines Packs zeigen (offen oder geschützt)
python3 tools/packs/verify_pack.py dist/language-access2.enc --code GEHEIM

# Fixtures für die GDScript-Tests neu bauen
python3 tests/fixtures/packs/make_fixtures.py
```

`tests/pack_crypto_test.gd` prüft die GDScript-Seite gegen eine mit `build_packs.py`
erzeugte Fixture **und** die Ableitung gegen die Referenzwerte von Pythons
`hashlib.pbkdf2_hmac`. Ein Missverständnis zwischen den drei Implementierungen fällt damit
im Testlauf auf und nicht beim Ausrollen.
