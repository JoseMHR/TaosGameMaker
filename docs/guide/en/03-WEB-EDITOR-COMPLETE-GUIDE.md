# 03 — Web Editor Complete Guide

The single source of truth for all editor tabs is `editor/js/collections.js` (`TABS` constant). Each entry defines: tab ID, icon, navigation group, Vue component (`editor/js/components/<Component>.js`), and persistence model (`kind: 'doc'` for single JSON files, `kind: 'perId'` for folders with one JSON per item).

---

## 🗺️ World Group

### Map (`map` → `MapEditor.js`)
The 3D top-down overworld editor (`data/world.json` and `data/world_test.json`). Paint terrain tiles, place towns, POIs, dungeon entrances, resource nodes, and direct map chests (`gold` + item array) on the grid. Features tile cut/paste tools, live icon/NPC/background previews for POIs, layer toggles, and a detailed inspector for the selected tile. Over 2,000 lines of code.

### Cities Workspace (`cityWorkspace` → `CityWorkspace.js`)
**Task-Oriented Workspace**: Consolidates everything related to a specific town into one screen — metadata, overworld map location (with one-click jump to the Map Editor), and its sub-POIs (taverns, stores, residential buildings) as cards, with direct creation and editing of linked NPCs and shop catalogs. Edits `data/ids/<city>.json`.

### Entities (`ids` → `IdsManager.js`)
Generic collection `data/ids/*.json`: houses **towns, POIs, dungeon entrances, overworld chests, and placeable interactive entities**. Each entity defines `type` (`city`, `poi`), multi-language name/description (7 languages), map icon, linked `npc`, scene background (`bg`), and `content` (sub-POI list for towns). Includes the **POI Wizard** (`NpcPoiWizardModal.js`) to generate a POI and linked NPC dialogue in one click.

### Dungeons (`dungeons` → `DungeonEditor.js`)
The largest editor component (~2,400 lines). Each dungeon is saved as `data/dungeons/<id>.json` containing one or more floors, each with a 2D cell grid. Paint tile types, position enemies/bosses, chests, teleporters, switches with `targets`, and preview layouts using the step-by-step **Dungeon Walkthrough Simulator** (`DungeonWalkthroughModal.js`). Includes the **Dungeon Wizard** (`DungeonWizardModal.js`) to auto-generate dungeon skeletons.

### Ambience (`ambience` → `AmbienceManager.js`)
`data/ambience.json`: BGM music tracks and weather settings mapped by terrain/region.

### World Transforms (`worldTransforms` → `WorldTransformsManager.js`)
`data/world_transforms.json`: Dynamic world evolution rules triggered by story flags — e.g. when a quest flag activates, a rectangular area of dried earth transforms into a navigable river.

### Buildings / 3D Assets (`worldBuildings` → `WorldBuildingsManager.js`)
`data/world_buildings/*.json`: Catalog of placeable 3D models for the overworld, linking Godot scenes, visual scale, and vertical offsets.

### Terrains (`worldTerrains` → `WorldTerrainsManager.js`)
`data/world_terrains/*.json`: Defines every **terrain code** (`grs`, `sand`, `ice`, `lav`...) with icon, map palette color, passability, visual sub-biome variations, and hazard damage/speed rules.

### Resources (`worldResources` → `WorldResourcesManager.js`)
`data/world_resources/*.json`: Gathering nodes on the overworld (trees, stone quarries, fishing spots) with required tool, harvested item, and replenishment rate.

### 🧩 Dungeon Pieces (`dungeonPieces` → `DungeonPiecesManager.js`)
A unified screen that brings together everything placeable in a dungeon into a categorized list:
- **🔒 Fixed Behavior**: Tiles with logic in `GridDungeonStage.gd` (doors, chests, levers). Only appearance and 3D models are edited here; renaming prompts a confirmation dialog to protect engine stability.
- **🎨 Cosmetic (No Code)**: Purely visual architectural tiles rendered generically. 100% safe to add, rename, or delete.
- **🧩 Smart Objects**: 100% data-driven interactive pieces from `data/dungeon_kits.json` (archetype + shape + reaction). Use these to create breakable walls, pressure plates, and moving platforms without touching GDScript.

---

## 💬 Characters Group

### NPCs (`npcs` → `NpcEditor.js`)
Each NPC is saved in `data/npcs/<id>.json` as a node graph (`_meta` with avatar/background, `message`/`option` nodes with 7-language text, `next`, `reward`, and `condition`). Features a visual node graph editor (`NpcGraphEditor.js`), a live Visual Novel emulator (`VnSimulatorModal.js`), and portrait selection supporting both transparent PNG sprites and **emoji avatars**.

### Enemies (`enemies` → `EnemiesManager.js`)
`data/enemies/<id>.json`: Base stats, scaling rates, elemental affinities/weaknesses, AI archetype (`aggressive`/`defensive`/`caster`), level-unlocked skills, boss flags, and inline loot tables.
> ⚔️ **Combat Sandbox**: Launch the live combat simulator modal (`CombatSandboxModal.js`) straight from any enemy entry to fight in-browser battles, testing player builds and AI behaviors without launching Godot.

### Enemy Skills (`enemySkills` → `EnemySkillsManager.js`)
`data/enemy_skills.json`: Combat skills exclusively used by enemy monsters.

---

## 🎒 Items & Systems Group

### Items (`items` → `ItemsManager.js`)
`data/items/<id>.json`: Full item catalog (consumables, weapons, armor, materials, key quest items), rarity badges, stat bonuses, and equip requirements. Includes the **Item Wizard** (`ItemWizardModal.js`).

### Professions (`professions` → `ProfessionsManager.js`)
`data/professions.json`: Playable character classes (7 default: Nobody, Warrior, Archer, Elementalist, Priest, Psychic, Timekeeper), color palettes, and skill unlocks up to level 30 (`MAX_JOB_LEVEL`).

### Skills (`skills` → `SkillsManager.js`)
`data/skills.json`: Player combat skill definitions (AP cost, elemental damage, cooldowns, buffs/debuffs).

### Synergies (`synergies` → `SynergiesManager.js`)
`data/synergies.json`: Skill combos — pairs or triplets of skills queued in the same turn that fuse into empowered attacks.

### Shops (`shops` → `ShopsManager.js`)
`data/shops.json`: Reusable store inventories assigned to NPCs or cities by `stock_id`.

---

## ⭐ Story Group

### Events / Triggers (`events` → `EventsManager.js`)
`data/events.json`: Data-driven triggers combining a `condition` (Godot expression) and an `actions` string (reward tokens). The glue connecting gameplay events to story reactions.

### Quests / Timeline (`quests` → `QuestsManager.js`)
`data/quests.json`: Main story timeline (`order` array of sequential state IDs), 7-language titles and hints, and `combat_victory` triggers that advance quests upon defeating specific bosses. Includes the **Quest Wizard** (`QuestWizardModal.js`).

### Scenes (`scenes` → `ScenesManager.js`)
`data/scenes/<id>.json`: Unified Narrative System graphs (`say`, `choice`, `state`, `event`, `flow`) for complex cinematic cutscenes and multi-party conversations.

---

## 🏆 Progression & ⚙️ Balance

### Achievements (`achievements` → `AchievementsManager.js`)
`data/achievements.json`: Unlock conditions and token rewards for in-game achievements.

### Tutorials (`tutorials` → `TutorialsManager.js`)
`data/tutorials.json`: Context-sensitive popups triggered when the player encounters a mechanic for the first time.

### Config (`config` → `ConfigManager.js`)
`data/config.json`: **Complete game balance control center** — XP curves, stat ratios, ATB turn intervals, AP limits, dodge/crit formulas, day/night speeds, economy multipliers, and accessibility defaults.

### Media Library (`mediaLibrary` → `MediaLibrary.js`)
Visual browser for all files in `assets/` with preview, batch upload, and image processing tools.

---

## Transversal Components & Modals

| Component | Usage |
|---|---|
| `EntityListPanel.js` | Sidebar list with search, category filtering, and item selection |
| `EditorToolbar.js` | Universal toolbar for undo, redo, copy, paste, duplicate, delete, and save |
| `ConditionEditor.js` | Visual builder for boolean `condition` expressions |
| `RewardEditor.js` | Helper modal for composing semicolon-separated `reward` token strings |
| `VnAssetPicker.js` | Asset picker for backgrounds, portraits, and audio (supports emoji avatars) |
| `VnSimulatorModal.js` | In-browser Visual Novel emulator for testing dialogue branches |
| `CombatSandboxModal.js` | Interactive combat simulator to test and balance battle stats in the browser |
| `DungeonWalkthroughModal.js` | Step-by-step layout validator for testing dungeon navigability |
| `GlobalSearch.js` | Instant cross-collection search modal (`Ctrl+K`) |
| `QaPanel.js` | Live referential integrity auditor matching `tools/validate_data.py` |
| `HelpDrawer.js` | Slide-out drawer with contextual help for the active tab |
| `FirstStepsPanel.js` | Interactive onboarding panel guiding new creators through common tasks |
| `NpcPoiWizardModal.js` | 1-click wizard to generate a map POI, entity record, and NPC dialogue tree |
| `ItemWizardModal.js` | Rapid item creation wizard with rarity, stats, and icon presets |
| `QuestWizardModal.js` | Step-by-step wizard to register story quest states and hints |
| `DungeonWizardModal.js` | Automated wizard to generate a full dungeon layout (rooms, halls, boss chamber) |

---

## Adding Custom Content Tabs

To add a completely new data collection (e.g. "Crafting Recipes", "Collectibles"):
1. Create your Vue component in `editor/js/components/<Name>.js`.
2. Register it in `editor/js/app.js` (`components: { ... }`).
3. Add ONE entry to `TABS` in `editor/js/collections.js`.
4. If it uses separate files per ID, add the folder name to `ALLOWED_COLLECTIONS` in `editor/serve.py` and state properties in `editor/js/store.js`.
5. Run `node tools/check_editor.mjs` and `python tools/gen_editor_codemap.py`.
