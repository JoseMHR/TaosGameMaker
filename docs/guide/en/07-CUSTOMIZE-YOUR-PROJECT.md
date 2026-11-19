# 07 — Customize Your Project (Step-by-Step Roadmap)

This practical guide takes you through transforming the sample RPG into **your own game or commercial template product**. Follow the sequential phases: each builds on the previous one.

> 💡 Rule of thumb: **Commit with git before each phase**. The web editor writes directly to disk; version control is your primary safety net.

---

## Phase 0 — Commercial Model & Scope

Define how you will package and sell this project:

### Distribution Models
- **As a Premium Template / RPG Engine for Other Creators (itch.io, Gumroad, Asset Stores)**:
  Distribute the complete repository containing Godot 4 + the `editor/` suite. Buyers receive a turn-key JRPG engine and visual No-Code editor to make their own games without programming. This documentation suite in `docs/guide/` (available in 7 languages) serves as the official user manual for your customers.
- **As a Standalone Commercial Video Game (Steam, Nintendo Switch, Google Play, iOS, itch.io)**:
  Replace the sample story in `data/` and art in `assets/` with your own intellectual property. When exporting your final build (`export_presets.cfg`), development tools (`editor/`, `tools/`, `docs/`) are **automatically excluded**, producing a clean, optimized executable for your target storefront.

### Gameplay Scope
- **Retain all 4 pillars** (Overworld + Dungeons + Combat + Narrative) and only replace content → Follow all phases below.
- **Prune to 1 or 2 pillars** (e.g. only Combat + Narrative) → Remove unwanted buttons from the Main Menu (`scenes/ui/main_menu/`) and `editor/js/nav.js` (`GAME_MODES`). Do not remove shared singletons (`GlobalState`, `Design`, `QuestManager`).

---

## Phase 1 — Basic Rebranding

1. **Project Title**: In `project.godot`, set `[application] config/name="YourGameName"`.
2. **Game Icon**: Replace `icon.png` in the project root.
3. **Splash Screen**: Replace `assets/common/boot_splash.png` or update `boot_splash/image` in `project.godot`.
4. **Credits**: Update `Credits.txt` with your team and any third-party asset licenses you retain.
5. **Localization Configuration**: The project supports 7 native languages (`en`, `es`, `fr`, `it`, `de`, `zh`, `ja`). If your game only targets a single language, change the default locale in `scripts/autoload/Locale.gd` (`var current_locale = "en"`) and populate only that language key in `data/`.
6. **Export Presets**: Review `export_presets.cfg` (Android preset included) to adjust package names, version codes, and bundle identifiers.

---

## Phase 2 — Narrative Worldbuilding

1. Define your Acts, Zones, and Biomes (no engine limits: you can build 3 zones or 20).
2. Update `data/quests.json` → `order` with your main story milestones, and `descriptions` with titles and hints.
3. Configure `data/scenes/` for cinematic cutscenes and key narrative beats.

---

## Phase 3 — Classes, Combat & Bestiary

1. **Professions** (Web Editor: *Professions* tab, `data/professions.json`): Define your playable classes, stat affinities, and skill unlock levels.
2. **Skills** (*Skills* tab, `data/skills.json`): Create combat abilities (AP costs, damage types, cooldowns).
3. **Synergies** (*Synergies* tab, `data/synergies.json`): Configure combo skill fusions.
4. **Bestiary** (*Enemies* tab, `data/enemies/`): Create monsters, elemental weaknesses, AI archetypes, and loot tables. Use the **Combat Sandbox** in the browser to balance stats.
5. **Combat Tuning** (*Config* tab, `data/config.json`): Adjust ATB speeds, critical hit formulas, and elemental multipliers.

---

## Phase 4 — Economy & Inventory

1. **Items** (*Items* tab, `data/items/`): Add weapons, armor, consumables, and crafting reagents.
2. **Shops** (*Shops* tab, `data/shops.json`): Build merchant catalogs and link them to NPC dialogue options.
3. **Economy Rules** (`data/config.json`): Adjust upgrade costs and gold sinks.

---

## Phase 5 — Overworld Map & Cities

1. **Terrains** (*Terrains* tab, `data/world_terrains/`): Create custom biome tiles.
2. **Gathering Nodes** (*Resources* tab, `data/world_resources/`): Configure harvestable nodes and required tools.
3. **Paint the Map** (*Map* tab, `data/world.json`): Place tiles, cities, dungeons, and chests.
4. **City Setup** (*City Workspace*): Configure each settlement, taverns, shops, and citizens.
5. **Dynamic Transforms** (*World Transforms* tab): Set up environmental changes triggered by quest progress.

---

## Phase 6 — Dungeons & Puzzles

1. Inspect **Dungeon Pieces** in the editor to select appropriate Smart Objects for puzzle mechanics.
2. Build dungeon layouts using the **Dungeon Editor** (`data/dungeons/<id>.json`).
3. Validate floor traversal with the **Walkthrough Modal**.

---

## Phase 7 — NPCs & Quests

1. **NPC Dialogues** (*NPCs* tab, `data/npcs/`): Build dialogue graphs and test with the Visual Novel Simulator.
2. **Events** (*Events* tab, `data/events.json`): Wire world triggers using the tokenized action mini-language.
3. **Achievements & Tutorials** (*Achievements* / *Tutorials* tabs): Add progression milestones.

---

## Phase 8 — Art & Audio Polish

1. Replace player and monster sprites in `assets/combat/`.
2. Add location backgrounds to `assets/vn/bg/`.
3. Register music tracks in `data/ambience.json`.

---

## Phase 9 — Pre-Release Checklist

- [ ] `python tools/validate_data.py` passes with zero integrity errors.
- [ ] Automated documentation maps updated (`python tools/gen_codemap.py`, `python tools/gen_editor_codemap.py`).
- [ ] `Credits.txt` audited.
- [ ] Export presets verified with dev directories excluded (`editor/*, docs/*, tools/*`).
- [ ] Full playthrough completed inside Godot.
