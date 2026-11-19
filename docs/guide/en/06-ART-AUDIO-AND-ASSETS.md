# 06 — Art, Audio, and Assets

## 1. Asset Directory Organization

| Directory | Contents |
|---|---|
| `assets/combat/` | Combat visuals: `character/` (player class sprites), `enemies/` (monster sprites), `bg/` (battle arenas), `platform/`, `skills/` (skill icons), `effects/` (VFX animations) |
| `assets/common/` | Shared global assets: `fonts/` (Cinzel typeface), `items/` (item icons), `models/` (all 3D models: `buildings/`, `characters/`, `decorations/`, `interactive/`), `music/`, `sfx/`, `shaders/`, `ui/`, `boot_splash.png` |
| `assets/dungeon/` | Dungeon wall, floor, and ceiling textures (`textures/`) |
| `assets/vn/` | Visual novel assets: `bg/` (scene backgrounds), `npcs/` (character portraits) |
| `assets/world/` | Overworld assets: `map/` (terrain textures) |

This structure matches `ASSET_DIRS` in `editor/serve.py`, ensuring seamless file management through the in-browser Media Library.

---

## 2. Standard Resolutions & Formats

| Asset Type | Format | Target Resolution | Notes |
|---|---|---|---|
| **Visual Novel / POI Backgrounds** | PNG / JPG | **1024×576** (16:9) | Fullscreen scenery in `assets/vn/bg/`. Character and setting can be integrated into the illustration directly. |
| **Combat Backgrounds** | PNG / JPG | **1024×576** (16:9) | Located in `assets/combat/bg/`. |
| **NPC Portraits** | PNG 32-bit RGBA | **512×512** | Transparent background in `assets/vn/npcs/`. If omitted, the engine shows the 16:9 scene cleanly without forcing placeholder sprites. |
| **Enemy Sprites** | PNG 32-bit RGBA | **512×512** | Transparent background in `assets/combat/enemies/`. |
| **Player Class Sprites** | PNG 32-bit RGBA | **512×512** | Transparent background in `assets/combat/character/`. |
| **Icons (Items / Skills)** | PNG 32-bit RGBA | **128×128** or **256×256** | `assets/common/items/` and `assets/combat/skills/`. |
| **3D Models** | `.glb` (preferred) or `.obj` | Scale 1.0 = 1 Godot Unit | Placed in `assets/common/models/`. Loaded dynamically via `ModelLoader.gd`. |
| **Music (BGM)** | `.ogg` / `.mp3` / `.wav` | Stereo, loopable | Managed by `AudioManager.gd`. Assigned in `data/ambience.json`. |
| **Sound Effects (SFX)** | `.ogg` / `.mp3` / `.wav` | Mono / Stereo | UI clicks, hit impacts, spells, footstep audio. |

---

## 3. Image Processing Utility (`tools/process_image.py`)

If you generate sprites using AI tools that export with solid backgrounds:

```bash
pip install Pillow
python tools/process_image.py input.jpg output.png --type sprite
python tools/process_image.py input.png output.png --resize 512x512
```

This utility performs color flood-fill background removal and edge de-haloing to produce clean 32-bit RGBA PNGs. Also accessible directly within the Web Editor via the **Process Image** button in the Media Library.

---

## 4. UI Theming & Global Styling (`UiKit.gd`)

All game UI colors, corner radii, borders, font sizes, and button styles are centralized in `scripts/config/UiKit.gd` (documented in `docs/design/UI_KIT.md`).

To give the entire game a completely new visual theme:
- Edit the color tokens and palette in `UiKit.gd`.
- All buttons, health bars, inventory slots, dialogue boxes, and menus adapt immediately and consistently across the entire game.
