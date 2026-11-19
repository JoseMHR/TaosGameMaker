# 01 — Übersicht und Architektur

## 1. Was diese Vorlage genau ist

Es ist ein **vollwertiges, spielbares JRPG** ("Taos Game Maker" in `project.godot`), ergänzt durch einen **visuellen Inhalts-Editor**. Sie können **80–90 % des Motors wiederverwenden** (Kampfsystem, Dungeons, Dialogsystem, Inventar, Speichersystem) und den **kreativen Inhalt** (Story, Gegner, Karte, Artworks und Musik) durch Ihre eigenen Werke ersetzen.

Die 4 Gameplay-Säulen:
- 🗺️ **Welt**: 3D-Oberwelt, Ressourcensammeln, Zelten, Seefahrt (`TabWorld3D.gd`).
- 🏰 **Dungeons**: Ego-Perspektive auf Gitterbasis, 6 Erkundungsfähigkeiten (`ViewDungeon.gd`).
- ⚔️ **Kampf**: Rundenbasiertes ATB-System mit Aktionspunkt-Warteschlange (`ViewCombat.gd`).
- 📖 **Erzählung**: Visual Novel, verzweigte Dialoge, Städte und Quests (`ViewPlace.gd`).

---

## 2. Tech-Stack

- **Spiel-Engine**: Godot 4.3+, GDScript, Rendering-Methode `mobile`, native 3D-Physik.
- **Zielplattformen**: Desktop (Windows, macOS, Linux) und Mobilgeräte (Android, iOS).
- **Web-Editor**: Vue 3 (via CDN, kein npm-Build erforderlich).
- **Lokaler Server**: Standard-Python 3 (`editor/serve.py`).
- **Speicherung**: Reine JSON-Dateien im Verzeichnis `data/`.

---

## 3. Godot-Autoloads (Globale Singletons)

- `Locale` (`scripts/autoload/Locale.gd`): 7 Sprachen (DE, EN, ES, FR, IT, ZH, JA), Barrierefreiheit und Farbfilter.
- `Design` (`scripts/autoload/Design.gd`): Laden, Zwischenspeichern und Abfragen aller JSON-Dateien.
- `ExplorationSkills` (`scripts/autoload/ExplorationSkills.gd`): Logik der 6 Dungeon-Werkzeuge.
- `GlobalState` (`scripts/autoload/GlobalState.gd`): Spielerwerte, Gold, Inventar und Flags.
- `SaveManager` (`scripts/autoload/SaveManager.gd`): Speichern und Laden von Spielständen.
- `QuestManager` (`scripts/autoload/QuestManager.gd`): Storyfortschritt und Zwischensequenzen.
