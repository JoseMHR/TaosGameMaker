# 06 — Grafik, Audio und Assets

## 1. Asset-Ordnerstruktur (`assets/`)

| Ordner | Inhalt |
|---|---|
| `assets/combat/` | Klassensprites (`character/`), Monster (`enemies/`), Kampfarenen (`bg/`), Skill-Icons (`skills/`), VFX |
| `assets/common/` | Cinzel-Schriftarten (`fonts/`), Item-Icons (`items/`), 3D-Modelle (`models/`), BGM & SFX |
| `assets/dungeon/` | Texturen für Dungeonwände und Böden (`textures/`) |
| `assets/vn/` | 16:9 Hintergründe (`bg/`) und PNG-Charakterporträts (`npcs/`) |
| `assets/world/` | Oberwelt-Terrain-Texturen (`map/`) |

---

## 2. Standard-Auflösungen

| Typ | Format | Zielauflösung |
|---|---|---|
| **Szenen-Hintergründe / POIs** | PNG / JPG | **1024×576** (16:9) |
| **Kampfarenen** | PNG / JPG | **1024×576** (16:9) |
| **Sprites (NPC / Gegner / Held)** | PNG 32-Bit RGBA | **512×512** (Transparenter Alpha-Kanal) |
| **Icons (Items / Skills)** | PNG 32-Bit RGBA | **128×128** oder **256×256** |
| **3D-Modelle** | `.glb` oder `.obj` | Skalierung 1.0 = 1 Godot-Einheit |
| **Musikspuren (BGM)** | `.ogg`, `.mp3`, `.wav` | Stereo im Loop |

---

## 3. Hintergrundentfernung für Sprites (`tools/process_image.py`)

Konvertiert KI-generierte Bilder mit einfarbigem Hintergrund in transparente PNGs:

```bash
pip install Pillow
python tools/process_image.py input.jpg output.png --type sprite
```
Auch direkt über die Schaltfläche „Bild verarbeiten“ in der Medienbibliothek des Web-Editors verfügbar.
