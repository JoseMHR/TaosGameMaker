# 09 — Frequently Asked Questions & Troubleshooting

## General

**Do I need to know GDScript to use this template?**  
No. Over 90% of game creation (story, maps, dungeons, balance, enemies, items) is handled through the visual Web Editor. GDScript is only required if you want to implement completely new custom mechanics (e.g. a card mini-game or rhythm combat).

**Does the web editor require Node.js or npm?**  
No. The web editor is a static Single Page Application served directly by Python (`serve.py`). Vue 3 loads via CDN. Node.js is only used for optional maintenance scripts (`tools/check_editor.mjs`).

**Where are player save files stored?**  
Save data is managed by `scripts/autoload/SaveManager.gd` inside the user data directory (`user://save_slot_*.json`). Player save files are strictly separate from the design data in `data/`.

---

## Web Editor

**The editor shows an error: "Data directory not found".**  
You are running `serve.py` from the wrong working directory. Run it from the project root (`python editor/serve.py`). Ensure `data/` and `editor/` are sibling directories.

**I saved changes in the editor, but they do not appear in the running game.**  
The editor writes directly to disk, but Godot loads `data/` on startup. Restart your playtest session in Godot (▶️) or call `Design.reload()`.

**Can I have the web editor and Godot open simultaneously?**  
Yes. They run as independent processes communicating only through the JSON files on disk.

**Why does the editor warn me before renaming or deleting certain dungeon tiles?**  
Tiles marked with 🔒 (*Fixed Behavior*) have logic hardcoded in `GridDungeonStage.gd` (doors, levers, chests). Renaming them breaks existing dungeon stages. Cosmetic tiles and Smart Objects are completely safe to edit or delete.

---

## Data & Mechanics

**How do multi-language fields work?**  
All player-facing text (names, descriptions, dialogue options) is stored as a dictionary supporting 7 languages (`en`, `es`, `fr`, `it`, `de`, `zh`, `ja`). If you are only creating a game in one language (e.g. English), you can fill only that key or duplicate the string; the engine applies safe fallback automatically.

**A monster does not drop the loot I configured.**  
Loot entries roll their chances **independently**. If an enemy has three drops with a 20% rate, it is mathematically possible for none to drop, or for all three to drop simultaneously.

**Why do some POIs not show a cropped character sprite in the center of the screen?**  
In this template, many POI illustrations (panoramic 16:9 images in `assets/vn/bg/`) already depict the merchant or character integrated directly into the setting. When no standalone `npc_<id>.png` sprite is assigned, `ViewPlace.gd` displays the clean 16:9 background along with the character's name and emoji avatar, preventing awkward visual overlap.

---

## Art & Assets

**My sprite has a solid background or white edges in-game.**  
Run the sprite through the background processor:
```bash
python tools/process_image.py input.png output.png --type sprite
```
This produces clean 32-bit RGBA transparency with anti-aliased edges.

**Where should I place custom 3D models?**  
Place them in `assets/common/models/` under the appropriate category (`buildings/`, `characters/`, `decorations/`, `interactive/`). Supported formats are `.glb` (preferred) and `.obj`.
