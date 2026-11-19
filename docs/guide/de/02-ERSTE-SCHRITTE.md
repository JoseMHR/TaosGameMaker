# 02 — Erste Schritte

## 1. Voraussetzungen

- **Godot Engine 4.3+**
- **Python 3.8+**
- Ein aktueller Webbrowser (Chrome, Firefox, Edge)

---

## 2. Projekt in Godot öffnen

1. Godot öffnen, auf **Importieren** klicken und den Projektordner auswählen (`project.godot`).
2. Beim ersten Start importiert Godot Texturen und 3D-Modelle.
3. Drücken Sie ▶️ (**Ausführen** oder `F5`), um ins Hauptmenü zu gelangen.

---

## 3. Den Web-Editor starten

Führen Sie im Projekt-Hauptverzeichnis folgenden Befehl aus:

```bash
python editor/serve.py
```

Der Browser öffnet sich automatisch unter `http://localhost:8000/`.

---

## 4. Empfohlener Arbeitsablauf

1. Lassen Sie `python editor/serve.py` im Hintergrund laufen.
2. Ändern Sie Daten im Browser (Gegner, Dungeons, Dialoge) und klicken Sie auf **Speichern**.
3. Wechseln Sie zu Godot und drücken Sie ▶️, um die Änderungen sofort im Spiel zu sehen.
4. Prüfen Sie vor jedem Git-Commit die Datenintegrität:
   ```bash
   python tools/validate_data.py
   ```
