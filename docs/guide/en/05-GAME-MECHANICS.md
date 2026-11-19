# 05 — Game Mechanics (The 4 Pillars)

This chapter summarizes the internal mechanics of each gameplay mode. For full mathematical equations and technical signatures, consult the corresponding specification in `docs/design/`.

---

## 1. 🗺️ Overworld (3D Top-Down Exploration)

📄 Technical Spec: `docs/design/WORLD_MAP.md` · Controller: `TabWorld3D.gd`

- 3D top-down perspective with tile grid navigation (`data/world_terrains/`).
- **Resource Gathering**: Overworld nodes require a specific tool equipped (Axe → Wood, Pickaxe → Stone/Ores, Fishing Rod → Fish, Shovel → Buried Relics). Configured in `data/world_resources/`.
- **Wilderness Camping**: Deploy a tent (`tent`) to rest, heal, and advance the day/night clock. Deploy a campfire (`plano_hoguera`) to cook raw ingredients into buff consumables.
- **Dynamic Terrain Transformations**: `data/world_transforms.json` alters map tiles dynamically when story flags are set (dams breaking, dried rivers flooding, paths clearing).
- **Modular Systems**: Extracted from `TabWorld3D.gd` into standalone interactive scripts: weather and biome audio, ice and slope physics, touch joystick, and cinematic camera sweeps (`scenes/tabs/tab_world_3d/interactive/`).

---

## 2. 🏰 Dungeons (1st-Person Grid Crawler)

📄 Technical Spec: `docs/design/DUNGEONS.md` · Controller: `ViewDungeon.gd` · Grid: `GridDungeonStage.gd`

- Classic step-by-step 3D grid movement with dynamic minimap and fog of war. Monsters appear as billboarded 2D sprites.
- **6 Exploration Skills** (bottom HUD bar, managed by `ExplorationSkills.gd`):

| Skill | Solves Puzzles With |
|---|---|
| 💥 Kinetic Wave | Barriers, destructible crates, statues, remote levers |
| ⭕ Psychic Grapple | High grapple rings, distant ledges, floating pillars |
| 👁️ Hunter's Sight | Illusionary walls, invisible floors, hidden treasure marks |
| 🔥/💧 Elemental Affinity | Torches, roots, ice blocks, electrical conduits |
| ☁️ Purify | Poison gas vents, corrupted water pools |
| ⏳ Chrono Warp | Moving platforms, timed pressure plates, collapsing doors |

- **Smart Objects**: Levers and switches send signal events (`eid`) to trigger targets. Trap hazards (lava, spike grates, poison miasma) deal proximity or step damage.

---

## 3. ⚔️ Combat (Turn-Based Tactical JRPG)

📄 Technical Spec: `docs/design/COMBAT.md` · Controller: `ViewCombat.gd`

- Traditional 2D JRPG side-view layout: party on the left, enemies on the right, dynamic combat background (`assets/combat/bg/`).
- **7 Character Classes**: (Nobody, Warrior, Archer, Elementalist, Priest, Psychic, Timekeeper). Up to **4 active skills** equipped per class. Switching jobs during combat costs an action.
- **ATB Gauge + Action Point (AP) Queuing**: When the ATB gauge fills, queue multiple skills up to your AP limit (`PA_LIMIT_NORMAL`, or `PA_LIMIT_RESONANT` in Resonant Mode).
- **Skill Synergies**: Queuing specific skill pairs or triplets in the same turn fuses them into powerful combo synergy attacks.
- **Active QTE Defense**: Two-zone timed defense ring during enemy attacks. Hitting the outer ring reduces damage; hitting the inner ring executes a **Perfect Guard**, granting damage immunity and charging Resonance.
- **11 Elements**: `physical, fire, water, ice, lightning, wind, earth, poison, holy, mind, time` with damage multipliers configured in `config.json`.

---

## 4. 📖 Narrative (Visual Novel & Cities)

📄 Technical Spec: `docs/design/NARRATIVE.md` · Controller: `ViewPlace.gd` · Overlay: `NarrativeOverlay.gd`

- Visual novel stage: panoramic 16:9 backgrounds (`assets/vn/bg/`), centered character portraits (`assets/vn/npcs/` or text emoji avatars), and interactive dialogue choice boxes.
- **5 Personality Facets** (`valor`, `bondad`, `aspecto`, `inteligencia`, `cordura`): Unlocks unique dialogue branches when matching condition checks.
- **NPC Dialogue Graphs**: Stored in `data/npcs/<id>.json` with multi-language text (7 languages), rewards, and conditions.
- **City Hubs**: A city is a parent entity displaying an interactive grid of sub-POIs (inns, shops, blacksmiths, guild houses).
- **Unified Narrative Scenes**: Advanced graph engine (`SceneRunner.gd`) powering multi-character conversations and cutscenes with camera triggers (`EVENT_CINE_CAMERA`).

---

## 5. Progression & Difficulty

📄 Technical Spec: `docs/design/PROGRESSION.md`

- Enemy stats scale procedurally by level and archetype (`EnemyDatabase.gd`), eliminating the need to hand-craft monster statistics for every level.
- Character and job level caps are controlled via `data/config.json` (`MAX_CHAR_LEVEL`, `MAX_JOB_LEVEL`).
