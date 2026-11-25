# 07 — Projekt Anpassen (Fahrplan)

## Phase 0 — Vertriebsmodell und Umfang

### Geschäftsmodelle
- **Als Premium-Vorlage / JRPG-Engine für andere Entwickler (Godot Asset Store, GitHub...)**:
  Verteilen Sie das gesamte Repository inklusive Godot 4 und dem Ordner `editor/`. Käufer erhalten eine schlüsselfertige Engine und einen No-Code-Editor. Dieses Handbuch (in 7 Sprachen) dient als Benutzeranleitung.
- **Als Eigenständiges Kommerzielles Spiel (Steam, Nintendo Switch, Google Play, iOS)**:
  Ersetzen Sie den Beispielinhalt in `data/` und die Assets in `assets/`. Beim Export aus Godot (`export_presets.cfg`) werden Entwicklungswerkzeuge (`editor/`, `tools/`, `docs/`) **automatisch ausgeschlossen**.

---

## Phase 1 — Rebranding

1. **Spielname**: In `project.godot` unter `[application] config/name="IhrSpiel"`.
2. **Icon**: Ersetzen Sie `icon.png` im Hauptverzeichnis.
3. **Startbildschirm**: Ersetzen Sie `assets/common/boot_splash.png`.
4. **Credits**: Aktualisieren Sie `Credits.txt` mit Ihrem Team und beibehaltenen Drittanbieter-Lizenzen.
5. **Standardsprache**: Legen Sie die Startsprache in `scripts/autoload/Locale.gd` fest (`var current_locale = "de"`).

---

## Phasen 2 bis 8 — Inhaltserstellung

1. **Handlung**: Tragen Sie die Meilensteine in `data/quests.json` ein.
2. **Klassen & Skills**: Erstellen Sie Berufe im Reiter *Berufe* und Zauber im Reiter *Fähigkeiten*.
3. **Bestiarium**: Gestalten Sie Monster im Reiter *Gegner* und balancieren Sie diese in der **Combat Sandbox**.
4. **Weltkarte**: Zeichnen Sie die Welt im Reiter *Karte* und richten Sie Städte ein.
5. **Dungeons**: Bauen Sie Dungeons und prüfen Sie die Begehbarkeit mit dem *Walkthrough*-Simulator.
6. **NPCs & Dialoge**: Schreiben Sie Dialogbäume und testen Sie sie im Visual-Novel-Simulator.

---

## Phase 9 — Abschlussprüfung

- [ ] `python tools/validate_data.py` ohne Fehler ausgeführt.
- [ ] Code-Maps aktualisiert (`python tools/gen_codemap.py`, `python tools/gen_editor_codemap.py`).
- [ ] Vollständigen Spieldurchlauf in Godot erfolgreich absolviert.
