# 06 — Art, Audio et Assets

## 1. Organisation des Ressources (`assets/`)

| Dossier | Contenu |
|---|---|
| `assets/combat/` | Sprites des classes (`character/`), monstres (`enemies/`), arènes (`bg/`), icônes (`skills/`), effets visuels |
| `assets/common/` | Police Cinzel (`fonts/`), icônes d'objets (`items/`), modèles 3D (`models/`), musiques, bruitages |
| `assets/dungeon/` | Textures murales et sols des donjons (`textures/`) |
| `assets/vn/` | Arrière-plans 16:9 (`bg/`) et portraits de personnages (`npcs/`) |
| `assets/world/` | Textures de terrain de la carte du monde (`map/`) |

---

## 2. Résolutions et Formats Standard

| Type | Format | Résolution Standard |
|---|---|---|
| **Fonds de Scène / POI** | PNG / JPG | **1024×576** (16:9) |
| **Arènes de Combat** | PNG / JPG | **1024×576** (16:9) |
| **Sprites PNJs / Ennemis / Joueur** | PNG 32 bits RGBA | **512×512** (Fond transparent) |
| **Icônes d'Objets et Sorts** | PNG 32 bits RGBA | **128×128** ou **256×256** |
| **Modèles 3D** | `.glb` ou `.obj` | Échelle 1.0 = 1 unité Godot |
| **Musiques et Effets** | `.ogg`, `.mp3`, `.wav` | Stéréo en boucle pour BGM, mono/stéréo court pour SFX |

---

## 3. Outil de Traitement des Sprites (`tools/process_image.py`)

Supprimez les fonds opaques des images générées par IA :

```bash
pip install Pillow
python tools/process_image.py entree.jpg sortie.png --type sprite
```
Également accessible via le bouton « Traiter l'image » de la Médiathèque dans l'Éditeur Web.
