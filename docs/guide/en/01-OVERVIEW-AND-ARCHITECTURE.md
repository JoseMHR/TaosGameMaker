# 01 — Overview and Architecture

## 1. What This Template Is

This project is a **complete, playable JRPG** ("Taos Game Maker" internal name in `project.godot`) combined with a **tailor-made visual content editor**. It is not an abstract, empty framework: it is an already functional game, architected so that you can reuse **80-90% of the core engine** (combat, exploration, dungeon crawling, visual novel dialogues, save system, inventory, talent progression) while substituting the **content** (story, enemies, overworld map, art, and music) with your own.

It contains 4 autonomous gameplay pillars + 1 global systems foundation:

| Pillar | Gameplay Focus | Primary Scene / Controller |
|---|---|---|
| 🗺️ **World** | 3D top-down overworld, resource gathering, camping, travel | `scenes/tabs/tab_world_3d/TabWorld3D.gd` |
| 🏰 **Dungeons** | 1st-person grid crawler, spatial puzzles, 6 exploration skills | `scenes/views/view_dungeon/ViewDungeon.gd` |
| ⚔️ **Combat** | Turn-based JRPG (ATB + Action Point queuing + synergies) | `scenes/views/view_combat/ViewCombat.gd` |
| 📖 **Narrative** | Visual novel: branching dialogue graphs, NPCs, towns, quests | `scenes/views/view_place/ViewPlace.gd` |
| ⚙️ **Global Systems** | Items, shops, achievements, tutorials, balance parameters | Autoloads (see below) |

This 4+1 structure is mirrored directly in the web editor's sidebar navigation (`editor/js/nav.js` → `GAME_MODES`) and in the in-game Debug Hub.

---

## 2. Technology Stack

| Layer | Technology | Location |
|---|---|---|
| Game Engine | **Godot 4.x** (tested on 4.3+), GDScript, `mobile` rendering method, native 3D physics | Project root, `project.godot` |
| Target Platforms | Mobile (Android/iOS) + Desktop (Windows, macOS, Linux) | `project.godot` → `config/features` |
| Content Editor | **Vue 3** (via CDN `unpkg.com/vue@3`, **zero build step**, no npm/webpack) | `editor/js/` |
| Editor Local Server | Pure **Python 3** (`http.server`), standard library only | `editor/serve.py` |
| Data Persistence | **Plain JSON** on disk, read by both Godot and the editor | `data/` |
| Data Validation | Referential integrity script in Python | `tools/validate_data.py` |
| Generated Docs | Python scripts scanning code and generating markdown maps | `tools/gen_codemap.py`, `tools/gen_editor_codemap.py` |

**Why this architecture:** The visual editor requires NO Node.js, npm, or frontend build tool to run (it is pure HTML+JS+CSS served directly), and the local Python server uses only the Python standard library. Anyone with Python installed can edit game content immediately.

---

## 3. How Godot, the Web Editor, and JSON Interact

```
┌─────────────────────┐        read/write JSON         ┌──────────────────────────┐
│   Web Editor (Vue)  │ ───────────────────────────▶   │   data/*.json and        │
│  editor/js/*.js     │  ◀───────────────────────────  │   data/<collection>/*.json│
│  (localhost:8000)   │        via HTTP (serve.py)     └──────────────────────────┘
└─────────────────────┘                                             ▲
                                                                    │ loads into memory
                                                                    │ on startup
                                                           ┌──────────────────────┐
                                                           │   Godot (The Game)   │
                                                           │   Design.gd (autoload)│
                                                           └──────────────────────┘
```

- The **Web Editor** (`editor/serve.py` + `editor/js/`) is a Single Page Application communicating with a local HTTP API (`/api/data/<file>`, `/api/collection/<name>[/<id>]`, `/api/assets/...`) that reads and writes JSON files in `data/` and asset directories in `assets/`.
- **Godot** never connects directly to the editor web server. When the game launches, the `Design.gd` singleton (`scripts/autoload/Design.gd`) parses all JSON files from `data/` into memory and exposes clean accessors (`Design.get_enemy(id)`, `Design.get_item(id)`, `Design.get_npc(id)`, etc.) consumed across the entire engine.
- **No compilation or export step for content**: Save in the editor → the JSON file updates on disk → Godot reads the updated file on next launch (or upon calling `Design.reload()`).

---

## 4. Engine Autoloads (Godot Global Singletons)

Registered in `project.godot` under `[autoload]`. Any script in the engine can invoke them globally:

| Autoload | File | Core Responsibility |
|---|---|---|
| `Locale` | `scripts/autoload/Locale.gd` | Multi-language management (7 languages: ES, EN, FR, IT, DE, ZH, JA), font scaling, colorblind filters |
| `Design` | `scripts/autoload/Design.gd` | Loads, parses, caches, and queries all JSON files in `data/` |
| `ExplorationSkills` | `scripts/autoload/ExplorationSkills.gd` | Logic and state for the 6 dungeon exploration tools |
| `GlobalState` | `scripts/autoload/GlobalState.gd` | Player stats, gold, inventory, equipment, flags, forge |
| `GlobalEvents` | `scripts/autoload/GlobalEvents.gd` | Decoupled global event bus (publish/subscribe pattern) |
| `SaveManager` | `scripts/autoload/SaveManager.gd` | Save game serialization, slots, and persistent player state |
| `TimeManager` | `scripts/autoload/TimeManager.gd` | In-game day/night cycle, calendar, and environmental lighting |
| `QuestManager` | `scripts/autoload/QuestManager.gd` | Questline progression tracking, cinematic triggers, dialogue requests |
| `SceneRunner` | `scripts/autoload/SceneRunner.gd` | Execution engine for Unified Narrative System scenes |
| `NarrativeOverlay` | `scenes/components/narrative/NarrativeOverlay.gd` | Visual Novel dialogue UI overlay and choice presentation |
| `SceneManager` | `scripts/autoload/SceneManager.gd` | High-level scene transitions and view switching |
| `AudioManager` | `scripts/autoload/AudioManager.gd` | Background music loops, SFX playback, and volume control |
| `MetaManager` | `scripts/autoload/MetaManager.gd` | Meta-progression and global game statistics |
| `Juice` | `scripts/autoload/Juice.gd` | Micro-interactions, haptics, UI animations, and screen shake |
| `OrbBarksManager` | `scripts/systems/OrbBarksManager.gd` | Contextual one-liners for the Orb companion |
| `OrbCompanionOverlay` | `scenes/components/orb_companion/OrbCompanionOverlay.gd` | Visual floating companion widget and emote display |

---

## 5. Root Folder Structure

| Directory | Contents |
|---|---|
| `scripts/` | GDScript logic: `autoload/` (singletons), `systems/` (specialized subsystems), `config/` (constants like `GameConfig.gd` / `UiKit.gd`) |
| `scenes/` | Godot scenes (`.tscn`): `tabs/` (overworld), `views/` (dungeons, combat, cities, shops, forge), `ui/` (menus, HUD), `components/` (reusable widgets) |
| `resources/` | Custom Godot `Resource` scripts (`.gd extends Resource`) |
| `data/` | **All game content in plain JSON**: enemies, items, classes, dungeons, NPCs, quests, economy, balance formulas |
| `assets/` | Art, audio, and 3D models organized by system (`combat/`, `common/`, `dungeon/`, `vn/`, `world/`) |
| `editor/` | Standalone browser-based visual content editor (Python server + Vue 3 SPA) |
| `tools/` | Maintenance scripts: data validation, code map generators, image processing |
| `docs/` | Documentation: `INDEX.md`, `CODEMAP.md`, `design/` (mechanic specs), and `guide/` (user manuals in 7 languages) |

---

## 6. The "Data-Driven" Philosophy: Code vs. Content

To build your own game efficiently, understand what belongs in code and what belongs in data:

- **Engine Code (GDScript — do not modify unless changing fundamental mechanics)**: How damage formulas execute, grid collision, dungeon rendering, turn resolution, save file encryption.
- **Content (JSON — 100% editable via the Web Editor)**: Enemy stats, loot drops, dialogue choices, town layouts, quest stages, dungeon piece placement, item pricing, and numeric difficulty multipliers (`data/config.json`).

There is a deliberate, guarded exception: a small set of **"Fixed-Behavior Dungeon Tiles"** (doors, chests, levers, switches) have core logic in `GridDungeonStage.gd`. The editor (`DungeonPiecesManager.js`) marks them with a 🔒 lock icon and prompts for confirmation before renaming them so you never break engine compatibility by accident. All other tiles (cosmetic pieces and data-driven "Smart Objects") can be freely created, edited, and removed without coding.

---

## 7. Next Step

Proceed to `02-GETTING-STARTED.md` to set up and run the template on your system.
