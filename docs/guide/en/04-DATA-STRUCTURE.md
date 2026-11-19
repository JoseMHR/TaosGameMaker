# 04 — Data Structure (`data/`)

All game content resides in `data/` as plain JSON files. There are two persistence patterns (defined in `editor/js/collections.js`):

- **`kind: 'doc'`** — A single JSON file containing a dictionary object (`data/professions.json`, `data/config.json`, `data/quests.json`...).
- **`kind: 'perId'`** — A folder containing **one JSON file per item** (`data/enemies/<id>.json`, `data/npcs/<id>.json`, `data/dungeons/<id>.json`...). Used for large catalogs to keep version control clean and modular.

---

## 1. Complete `data/` Directory Map

| Path | Type | Description |
|---|---|---|
| `world.json` / `world_test.json` | doc | Production and debug overworld tile grids |
| `world_transforms.json` | doc | Dynamic map tile replacement rules triggered by story flags |
| `world_buildings_classic.json` | doc | Procedural mesh overrides for classic buildings |
| `world_terrains/` | perId | Individual terrain files (`grs.json`, `ice.json`...) |
| `world_resources/` | perId | Gathering node configurations (`forest.json`, `rock.json`...) |
| `world_buildings/` | perId | Placeable 3D building instances |
| `ids/` | perId | Towns, POIs, dungeon portals, map chests (all generic placeable entities) |
| `dungeons/` | perId | Complete dungeon layouts (floors, grids, cell entities) |
| `dungeon_tiles/` | perId | Dungeon tile definitions (fixed logic + cosmetic) |
| `dungeon_kits.json` | doc | Data-driven Smart Object kits for puzzle elements |
| `npcs/` | perId | NPC dialogue graphs and decision trees |
| `enemies/` | perId | Enemy stat sheets, AI archetypes, skills, and loot |
| `enemy_skills.json` | doc | Monster-exclusive combat skills |
| `items/` | perId | Consumables, equipment, materials, and quest items |
| `professions.json` | doc **(Required)** | Playable class definitions and level progression trees |
| `skills.json` | doc **(Required)** | Player combat skill catalog |
| `synergies.json` | doc | Multi-skill combination attacks |
| `shops.json` | doc | Reusable merchant inventories and price lists |
| `events.json` | doc | Narrative event triggers (`condition` + `actions`) |
| `quests.json` | doc | Main storyline timeline order and boss victory hooks |
| `quests_secondary/` | perId | Modular side quests (Multi-Quest System) |
| `dialogues.json` | doc | Standalone notification alerts and legacy toasts |
| `scenes/` | perId | Unified Narrative System graphs (conversations and cutscenes) |
| `achievements.json` | doc | Achievement conditions and unlock rewards |
| `tutorials.json` | doc | Contextual tutorial prompts |
| `ambience.json` | doc | BGM audio loops and weather chances by terrain |
| `config.json` | doc | **Global numerical game balance constants** |
| `codex.json` | doc | Lore codex entries unlocked via exploration |
| `orb_barks.json` | doc | Companion Orb dialogue snippets |
| `templates/` | — | Internal blueprints used by editor creation wizards |

---

## 2. ID Conventions

- Lowercase `snake_case`, letters, numbers, and underscores only (`orc_berserker`, `dun_helmo`, `city_sylphrena`).
- Standard prefixes by convention: `dun_` for dungeons, `city_` for towns, `poi_` for points of interest.
- IDs are cross-referenced by string across multiple files. The validation script (`python tools/validate_data.py` or the QA Panel) ensures all cross-references remain intact.

---

## 3. Multi-Language Fields (7 Native Languages)

All player-facing text is stored as a multi-language dictionary supporting the 7 official game locales:
- `es` (Spanish)
- `en` (English)
- `fr` (French)
- `it` (Italian)
- `de` (German)
- `zh` (Simplified Chinese)
- `ja` (Japanese)

Example in an NPC node, item description, or quest title:
```json
"text": {
    "en": "Welcome to the tavern!",
    "es": "¡Bienvenido a la taberna!",
    "fr": "Bienvenue à la taverne !",
    "it": "Benvenuto alla taverna!",
    "de": "Willkommen in der Taverne!",
    "zh": "欢迎来到酒馆！",
    "ja": "酒場へようこそ！"
}
```

The `Locale.gd` engine singleton resolves the active language in real time without reloading scenes. If a translation key is missing, the engine falls back gracefully to `en` or the first available language without crashing.

---

## 4. The Tokenized REWARD Mini-Language (`reward`)

Used in `npcs/*.json` (dialogue nodes), `events.json` (`actions`), `achievements.json`, and `data/scenes/*` (`state` nodes). It consists of a semicolon-separated string of `key:value` tokens evaluated sequentially by `Design.apply_reward()` in Godot.

Examples:
```
"gold:-50;faceta:amabilidad=+1;flag:donated_orphans"
"item:diary=1;questf:item_found;dialogue:diary_found"
```

Supported Tokens:

| Token | Syntax | Effect |
|---|---|---|
| `gold` | `gold:±N` | Adds or subtracts player gold |
| `xp` | `xp:N` | Awards character experience points |
| `heal` | `heal` | Fully restores party HP and MP |
| `damage` | `damage:N` or `damage:N%` | Out-of-combat damage (flat or percentage; cannot kill, leaves at 1 HP minimum) |
| `faceta` | `faceta:KEY=±N` | Modifies a personality facet (`valor/bondad/aspecto/inteligencia/cordura`) |
| `item` | `item:ID=N` | Adds N units of an item to inventory |
| `-item` | `-item:ID=N` | Removes N units of an item from inventory |
| `flag` | `flag:NAME` | Sets a **local flag** scoped to the current NPC |
| `relation` | `relation:±N` | Modifies relationship affinity with the NPC |
| `questf` | `questf:STATE` | Advances the main questline **forward** to that state in `quests.json` order |
| `quests` | `quests:STATE` | Forcefully sets the main questline state regardless of order |
| `quest_start` | `quest_start:ID[:STAGE]` | Starts a modular side quest at the specified stage |
| `quest_stage` | `quest_stage:ID=STAGE` | Updates side quest stage |
| `quest_complete` | `quest_complete:ID` | Marks a side quest as completed |
| `quest_fail` | `quest_fail:ID` | Marks a side quest as failed |
| `prof` | `prof:ID` | Unlocks and equips a character class |
| `dam` | `dam` | Opens the river dam (prologue world transform) |
| `boat_spawn` | `boat_spawn` | Spawns the navigable ship at Celestia Harbor |
| `boat_pos` | `boat_pos:X,Y` | Relocates the ship to specific overworld coordinates |
| `discover` | `discover:CODEX_ID` | Unlocks an entry in the Exploration Lore Codex |
| `bark` | `bark:BARK_ID` | Triggers an immediate contextual quote from the Orb companion |
| `music` | `music:TRACK_ID` | Switches background music dynamically from dialogue |
| `gflag` | `gflag:NAME` (or `gflag:NAME=0`) | Sets a **global persistent story flag** |
| `worldt` | `worldt:ID` | Triggers a tile transformation from `world_transforms.json` |
| `combat` | `combat:enemy_id[:level[:boss]]` | Initiates a turn-based combat encounter |
| `event` | `event:ID` | Invokes another event sequence from `events.json` |
| `emit` | `emit:EVENT[=k=v,k2=v2]` | Emits a custom signal to the `GlobalEvents` bus with payload |
| `dialogue` | `dialogue:ID` | Displays a dialogue alert (or narrative scene with matching ID) |
| `cine` | `cine:ID` | Plays the narrative scene (`data/scenes/<ID>.json`) as a cinematic |

> Enemy/chest loot does **not** use this token string. It uses a structured array of `{ kind, id, chance, min, max, qty }` entries where each item rolls its drop rate independently.

---

## 5. The Boolean CONDITION Syntax (`condition`)

Used in NPC option nodes, `events.json`, and achievements. Evaluated dynamically by `Design.eval_condition()`:

| Function / Variable | Description |
|---|---|
| `has_flag("X")` / `no_flag("X")` | Local NPC flag check |
| `gflag("X")` / `has_gflag("X")` / `no_gflag("X")` | Global persistent story flag check |
| `has_item("id"[, qty])` / `no_item("id"[, qty])` | Item possession in inventory (with optional quantity) |
| `has_quest("id")` / `quest_done("id")` | Side quest active / completed |
| `quest_stage("id") == N` | Current numeric stage of a side quest |
| `has_prof("id")` / `no_prof("id")` | Class unlock status |
| `has_all_professions()` | True if all 6 mastery classes are unlocked |
| `defeated("dun:boss")` | Checks if a specific dungeon boss was defeated |
| `discovered("codex_id")` | True if a lore entry was found |
| `stat("kills"/"level"/"gold") >= N` | Aggregated player statistics |
| `quest == "state"` | Current main storyline state string |
| `rel("npc_id") >= N` | Relationship affinity with a specific NPC |
| `relation >= N` | Affinity with the active NPC |
| `visits >= N` | Number of conversations held with the active NPC |
| `gold >= N` | Current player gold balance |
| `valor/bondad/aspecto/inteligencia/cordura >= N` | Personality facet thresholds |

Can be combined with standard boolean operators:
```gdscript
(has_flag("boss_cleared") or has_gflag("harbor_open")) and gold >= 100
```

---

## 6. `data/config.json` — Global Game Balance

Contains all numerical balancing knobs:
- Character XP curves (`XP_CHAR_BASE`, `XP_CHAR_EXPONENT`)
- Job XP formulas (`MAX_JOB_LEVEL`, `XP_JOB_BASE`)
- Health and mana scaling per stat point (`HP_PER_VIT`, `MP_PER_INT`)
- ATB turn pacing and AP limits (`COMBAT_TURN_INTERVAL`, `PA_LIMIT_NORMAL`)
- Dungeon tick rates and random ambush probabilities
- Economy prices (reforge costs, building upgrade curves)
- Accessibility limits (minimum/maximum font scaling)

All keys have safe defaults in `GameConfig.gd`, so deleting or tweaking individual keys is safe.
