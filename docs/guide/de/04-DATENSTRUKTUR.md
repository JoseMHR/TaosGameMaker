# 04 — Datenstruktur (`data/`)

Alle Spieldaten liegen in `data/` als standardisiertes JSON vor:

- **`kind: 'doc'`**: Einzelne Datei mit einem Dictionary (`professions.json`, `config.json`, `quests.json`).
- **`kind: 'perId'`**: Ordner mit **einer JSON-Datei pro Eintrag** (`enemies/<id>.json`, `npcs/<id>.json`, `dungeons/<id>.json`).

---

## 1. Nativer 7-Sprachen-Support

Alle dem Spieler angezeigten Texte werden mit den 7 offiziellen Schlüsseln gespeichert:
- `de` (Deutsch)
- `en` (Englisch)
- `es` (Spanisch)
- `fr` (Französisch)
- `it` (Italienisch)
- `zh` (Vereinfachtes Chinesisch)
- `ja` (Japanisch)

Beispiel:
```json
"text": {
    "de": "Willkommen in der Taverne!",
    "en": "Welcome to the tavern!",
    "es": "¡Bienvenido a la taberna!",
    "fr": "Bienvenue à la taverne !",
    "it": "Benvenuto alla taverna!",
    "zh": "欢迎来到酒馆！",
    "ja": "酒場へようこそ！"
}
```

---

## 2. Die Token-Sprache für BELOHNUNGEN (`reward`)

Eine durch Semikolons `;` getrennte Kette von Anweisungen:

| Token | Syntax | Auswirkung |
|---|---|---|
| `gold` | `gold:±N` | Fügt Gold hinzu oder zieht es ab |
| `xp` | `xp:N` | Vergibt Charakter-Erfahrungspunkte |
| `heal` | `heal` | Heilt KP und MP der Gruppe vollständig |
| `damage` | `damage:N` | Fügt Schaden außerhalb des Kampfes zu (min. 1 KP) |
| `item` | `item:ID=N` | Fügt N Gegenstände dem Inventar hinzu |
| `-item` | `-item:ID=N` | Entfernt N Gegenstände aus dem Inventar |
| `flag` | `flag:NAME` | Setzt ein lokales NPC-Flag |
| `gflag` | `gflag:NAME` | Setzt ein dauerhaftes globales Story-Flag |
| `questf` | `questf:STATUS` | Setzt die Hauptquest vorwärts auf diesen Status |
| `prof` | `prof:ID` | Schaltet eine Klasse frei und rüstet sie aus |
| `combat` | `combat:enemy_id[:level]` | Startet einen Kampf |
| `cine` | `cine:ID` | Spielt die Szene als Zwischensequenz ab |

---

## 3. Syntax für BEDINGUNGEN (`condition`)

Dynamisch ausgewertete logische Ausdrücke:
- `has_flag("X")` / `no_flag("X")`: Lokales NPC-Flag.
- `gflag("X")` / `has_gflag("X")`: Globales Fortschritts-Flag.
- `has_item("id"[, menge])`: Gegenstand im Inventar vorhanden.
- `gold >= 100`: Goldstand prüfen.
- `quest == "dam_opened"`: Zustand der Hauptgeschichte.
