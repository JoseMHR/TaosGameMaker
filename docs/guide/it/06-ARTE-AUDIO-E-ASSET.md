# 06 — Arte, Audio e Asset

## 1. Struttura delle Cartelle (`assets/`)

| Cartella | Contenuto |
|---|---|
| `assets/combat/` | Sprite di classi (`character/`), mostri (`enemies/`), arene (`bg/`), icone (`skills/`), effetti speciali |
| `assets/common/` | Caratteri Cinzel (`fonts/`), icone oggetti (`items/`), modelli 3D (`models/`), musiche e SFX |
| `assets/dungeon/` | Texture per pavimenti e pareti dei dungeon (`textures/`) |
| `assets/vn/` | Sfondi scenici 16:9 (`bg/`) e ritratti PNG dei PNG (`npcs/`) |
| `assets/world/` | Texture dei terreni della mappa del mondo (`map/`) |

---

## 2. Risoluzioni Standard

| Tipo di Asset | Formato | Risoluzione Standard |
|---|---|---|
| **Sfondi Scenici / POI** | PNG / JPG | **1024×576** (16:9 panoramico) |
| **Arene di Battaglia** | PNG / JPG | **1024×576** (16:9) |
| **Sprite PNG / Nemici / Eroi** | PNG 32-bit RGBA | **512×512** (Trasparenza alpha) |
| **Icone Oggetti / Abilità** | PNG 32-bit RGBA | **128×128** o **256×256** |
| **Modelli 3D** | `.glb` o `.obj` | Scala 1.0 = 1 unità Godot |
| **Tracce Audio (BGM)** | `.ogg`, `.mp3`, `.wav` | Stereo in loop |

---

## 3. Rimozione Automatica Sfondi Sprite (`tools/process_image.py`)

Per convertire immagini con sfondo opaco generate da IA in sprite trasparenti:

```bash
pip install Pillow
python tools/process_image.py input.jpg output.png --type sprite
```
Disponibile anche dal pulsante «Elabora immagine» nella Libreria Multimediale dell'Editor Web.
