# 03 — Web-Editor : Vollständiger Leitfaden

Alle Reiter und Module sind in `editor/js/collections.js` definiert.

---

## 🗺️ Welt-Gruppe

- **Karte (`map` → `MapEditor.js`)**: Editor für die 3D-Oberwelt (`data/world.json`). Zeichnen Sie Kacheln, platzieren Sie Städte, Dungeons und Kisten.
- **Städte-Workspace (`cityWorkspace` → `CityWorkspace.js`)**: Zentrale Verwaltung von Siedlungen, Gebäuden, Läden und NPCs.
- **Entitäten (`ids` → `IdsManager.js`)**: Points of Interest (POIs) mit 7-Sprachen-Texten (*POI Wizard* integriert).
- **Dungeons (`dungeons` → `DungeonEditor.js`)**: 3D-Gitter-Dungeon-Design mit Rundgang-Simulator (*DungeonWalkthroughModal*) und Generator (*DungeonWizardModal*).
- **Dungeon-Bausteine (`dungeonPieces` → `DungeonPiecesManager.js`)**: Verwaltung fester Kacheln 🔒, kosmetischer Bausteine 🎨 und Smart Objects 🧩.

---

## 💬 Charaktere & Gegner

- **NPCs (`npcs` → `NpcEditor.js`)**: Dialogbäume in `data/npcs/<id>.json`. Mit visuellem Grapheditor (`NpcGraphEditor.js`), Visual-Novel-Simulator (`VnSimulatorModal.js`) und Emoji-Avatar-Support.
- **Gegner (`enemies` → `EnemiesManager.js`)**: Stat-Sheets, Verhaltens-KI, Resistenzen und Beutetabellen.
  > ⚔️ **Combat Sandbox**: Simulieren Sie Gefechte direkt im Browser (`CombatSandboxModal.js`), um Attribute und Fähigkeiten live auszubalancieren.

---

## 🎒 Gegenstände, Klassen & Balance

- **Items (`items` → `ItemsManager.js`)**: Waffen, Rüstungen und Tränke mit dem *Item Wizard*.
- **Berufe / Klassen (`professions` → `ProfessionsManager.js`)**: Spielbare Klassen und Fähigkeiten-Freischaltungen.
- **Fähigkeiten (`skills` → `SkillsManager.js`)**: Zauber- und Angriffs-Katalog.
- **Konfiguration (`config` → `ConfigManager.js`)**: **Globales Balance-Panel** (XP-Kurven, Schadensformeln, ATB-Rhythmus, Wirtschaft).
