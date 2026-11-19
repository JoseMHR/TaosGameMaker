# ⚔️ JRPG Complete Template & Engine — Benutzerhandbuch

> **Willkommen bei der professionellen JRPG-Vorlage und Engine für Godot 4.**  
> Dieses Projekt kombiniert ein vollständiges Spiel (3D-Oberwelt aus der Vogelperspektive, Ego-Dungeon-Crawler, rundenbasierter Kampf und Visual-Novel-Erzählung) mit einem **maßgeschneiderten visuellen Web-Editor**, mit dem Sie Ihr gesamtes Spiel erstellen, anpassen und ausbalancieren können, ohne eine einzige Zeile Code schreiben zu müssen.

---

## ⚡ Schnellstart (In unter 3 Minuten)

Keine Datenbankeinrichtung oder komplizierte Build-Schritte erforderlich:

### 1. Voraussetzungen
- **Godot Engine 4.3+** (Standard oder .NET).
- **Python 3.8+** (Auf macOS/Linux vorinstalliert; für Windows auf [python.org](https://www.python.org/) verfügbar).

### 2. In Godot öffnen und spielen
1. Öffnen Sie die **Godot Engine** und klicken Sie auf **Importieren**.
2. Wählen Sie die Datei `project.godot` in diesem Verzeichnis aus.
3. Klicken Sie auf **Projekt ausführen** (oder drücken Sie `F5`). Sie befinden sich im Hauptmenü!
   - Um alle Inhalte direkt auszuprobieren, wählen Sie im Menü **Debug-Modus / Testraum**.

### 3. Den Web-Inhalt-Editor starten
Der Editor ist eine lokale Web-Anwendung, die weder `npm` noch Kompilierung erfordert:
1. Öffnen Sie ein Terminal im Hauptverzeichnis des Projekts.
2. Führen Sie aus:
   ```bash
   python editor/serve.py
   ```
3. Öffnen Sie Ihren Browser unter:
   👉 **[http://localhost:8000](http://localhost:8000)**

Jede im Web-Editor gespeicherte Änderung (Gegner, Karten, Dialoge) **wird sofort in Godot übernommen, ohne dass die Engine neu gestartet werden muss**.

---

## 🎮 Was beinhaltet diese Vorlage?

### 🗺️ 4 Vollständig Integrierte Spielpfeiler
1. **3D-Top-Down-Oberwelt**: Kachel-Gitter-System, Kriegsnebel, Biome, Umweltgefahren, dauerhafte Weltveränderungen (fällbare Bäume, zerstörbare Felsen, baubare Lager) und navigierbares Schiff.
2. **Ego-Dungeon-Crawler (3D Grid)**: Schrittweise Dungeons mit dynamischer Minikarte, Schlüsseltüren, Rätselfallen, Schatztruhen und Bosskämpfen.
3. **Taktischer Rundenkampf**: JRPG-Kampfsystem mit Elementarschaden, Statusveränderungen, ATB-Leiste, Aktionspunkt-Warteschlangen (AP), Klassensynergien und dynamischen Kamerabewegungen.
4. **Narrativ & Visual Novel**: Verzweigte Dialogbäume mit Entscheidungsoptionen, ausdrucksstarke Porträts, reaktive Musik, Quests und persistente globale Flags.

### 🛠️ Visueller "No-Code" Web-Editor
Eine vollständige Suite für Game-Design im Browser:
- **3D-Weltkarten-Editor**: Zeichnen Sie Terrains, platzieren Sie Städte, Dungeons, Ressourcen und Schatztruhen per Mausklick.
- **Dungeon-Leveldesigner**: Entwerfen Sie mehrstöckige 3D-Gitter-Level mit Texturvorschau und Schritt-für-Schritt-Rundgang (*DungeonWalkthroughModal*).
- **Gegner- & Fähigkeiten-Designer**: Passen Sie Werte, KI, Drops an und testen Sie jeden Kampf live in der integrierten **Combat Sandbox**.
- **Dialog- & Questbaum-Editor**: Erstellen Sie visuelle Dialoggraphen (*NpcGraphEditor*) und testen Sie diese mit dem Visual-Novel-Simulator (*VnSimulator*).
- **Talentbäume, Berufe & Synergien**: Balancieren Sie den Klassenfortschritt.
- **Schnell-Assistenten (Wizards)**: Generieren Sie Dungeons, Quests, Items und POIs mit einem Klick.
- **Nativer 7-Sprachen-Support**: Deutsch, Englisch, Spanisch, Französisch, Italienisch, Chinesisch und Japanisch ab Werk integriert.

### 🧪 Testkammer & Debug-Hub
- Beinhaltet `data/world_test.json`, eine modulare Testwelt in 8 Pavillons, die **100 % aller POIs (162), Städte (4), Dungeons (13) und Gegner (41)** ausstellt.

---

## 📚 Inhaltsverzeichnis des Handbuchs

| Kapitel | Titel | Beschreibung |
|---|---|---|
| **01** | [**Übersicht und Architektur**](01-UEBERSICHT-UND-ARCHITEKTUR.md) | Systemarchitektur, Tech-Stack und datengesteuerte Philosophie. |
| **02** | [**Erste Schritte**](02-ERSTE-SCHRITTE.md) | Ersteinrichtung, lokaler Server und empfohlener Arbeitsablauf. |
| **03** | [**Web-Editor: Vollständiger Leitfaden**](03-WEB-EDITOR-VOLLSTAENDIGER-LEITFADEN.md) | Umfassendes Handbuch aller Tabs, Werkzeuge und Assistenten. |
| **04** | [**Datenstruktur (JSON)**](04-DATENSTRUKTUR.md) | Datenlexikon, Bedingungssyntax und Belohnungssprache. |
| **05** | [**Spielmechaniken**](05-SPIELMECHANIKEN.md) | Detaillierte Funktionsweise der 4 Spielpfeiler. |
| **06** | [**Grafik, Audio und Assets**](06-GRAFIK-AUDIO-UND-ASSETS.md) | Auflösungen, 3D-Pipeline, Sprite-Hintergrundentfernung und UI-Themes. |
| **07** | [**Projekt Anpassen**](07-PROJEKT-ANPASSEN.md) | **Fahrplan** zur Erstellung Ihres eigenen Spiels oder Templates. |
| **08** | [**CLI-Tools und Validierung**](08-CLI-TOOLS-UND-VALIDIERUNG.md) | Automatisierte Prüfskripte in `tools/` zur Datenintegrität. |
| **09** | [**FAQ und Fehlerbehebung**](09-FAQ-FEHLERBEHEBUNG.md) | Direkte Antworten auf häufige Fragen. |
