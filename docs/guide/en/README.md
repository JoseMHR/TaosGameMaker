# ⚔️ JRPG Complete Template & Engine — User Guide

> **Welcome to the professional JRPG template and engine for Godot 4.**  
> This project combines a complete game (3D top-down overworld, first-person dungeon crawler, turn-based combat, and visual novel narrative) with a dedicated **Visual Web Editor** that allows you to create, modify, and balance your entire game without touching a single line of code.

---

## ⚡ Quick Start (Under 3 Minutes)

No database configuration or complex build steps required. The project works out of the box:

### 1. Requirements
- **Godot Engine 4.3+** (Standard or .NET).
- **Python 3.8+** (Pre-installed on macOS/Linux; available at [python.org](https://www.python.org/) for Windows).

### 2. Open and Play in Godot
1. Open **Godot Engine** and click **Import**.
2. Select the `project.godot` file in this directory.
3. Click **Run Project** (or press `F5`). You are now in the main menu!
   - To test all content at once, select **Debug Mode / Test Room** in the menu.

### 3. Launch the Web Content Editor
The content editor is a local web application requiring neither `npm` nor compilation:
1. Open a terminal in the project root directory.
2. Run:
   ```bash
   python editor/serve.py
   ```
3. Open your browser at:
   👉 **[http://localhost:8000](http://localhost:8000)**

Any change saved in the web editor (new enemies, maps, dialogues, etc.) **reflects immediately in Godot without restarting the engine**.

---

## 🎮 What is Included in this Template?

### 🗺️ 4 Fully Integrated Game Pillars
1. **3D Top-Down Overworld**: Grid-based tile system, fog of war, biomes, weather hazards, persistent world transformations (choppable trees, breakable rocks, buildable camps), and navigable sea vessel.
2. **First-Person Dungeon Crawler**: Classic step-by-step 3D dungeons with dynamic minimap, fog of war, locked doors, puzzle traps, loot chests, and boss encounters.
3. **Turn-Based Tactical Combat**: JRPG combat system with elemental damage calculations, status ailments, turn queue bar, class skill trees, party synergies, and dynamic camera choreography.
4. **Narrative & Visual Novel**: Branching dialogue trees with decision options, expressive character portraits, reactive ambient music, main and side quests, and persistent global flags.

### 🛠️ "No-Code" Visual Web Editor
A complete game design suite running locally in your browser:
- **3D World Map Editor**: Paint terrains, place towns, dungeons, gathering nodes, enemies, and chests with a single click.
- **Dungeon Level Designer**: Design multi-floor 3D grid levels with texture preview, doors, interactive puzzle switches, and step-by-step walkthrough simulation (*DungeonWalkthroughModal*).
- **Enemy & Skill Designer**: Tweak base stats, AI archetypes, sprites, loot tables, and test any battle in real time with the browser-based **Combat Sandbox**.
- **Dialogue & Quest Tree Editor**: Create conversation trees using visual node graphs (*NpcGraphEditor*), branching conditions, and preview with the integrated Visual Novel Simulator (*VnSimulator*).
- **Talents, Professions & Synergies**: Balance progression curves, job unlock trees, and combo synergies.
- **One-Click Creation Wizards**: Instantly generate complete dungeon skeletons, quests, items, and Points of Interest (POIs) with linked NPCs.
- **Native Multi-Language Support (7 Languages)**: English, Spanish, French, Italian, German, Simplified Chinese, and Japanese with instant runtime language switching.

### 🧪 Test Chamber & Debug Hub
- Includes `data/world_test.json`, a modular test world organized into 8 thematic pavilions showcasing **100% of all POIs (162), cities (4), dungeons (13), and enemies (41)** for instant verification.

---

## 📚 Step-by-Step Guide Index

This guide suite contains comprehensive manuals for adapting and transforming this template into your own commercial release:

| Chapter | Title | Summary |
|---|---|---|
| **01** | [**Overview & Architecture**](01-OVERVIEW-AND-ARCHITECTURE.md) | Understand project architecture, technical stack, autoloads, and the data-driven philosophy. |
| **02** | [**Getting Started**](02-GETTING-STARTED.md) | Initial setup guide, local editor execution, and recommended daily workflow. |
| **03** | [**Web Editor Complete Guide**](03-WEB-EDITOR-COMPLETE-GUIDE.md) | Exhaustive tab-by-tab breakdown of all editor features, modals, and creation wizards. |
| **04** | [**Data Structure (JSON)**](04-DATA-STRUCTURE.md) | Data dictionary: fields, condition syntax, and the tokenized reward mini-language. |
| **05** | [**Game Mechanics**](05-GAME-MECHANICS.md) | Deep dive into the 4 gameplay modes: overworld, dungeon crawler, combat, and narrative. |
| **06** | [**Art, Audio & Assets**](06-ART-AUDIO-AND-ASSETS.md) | Asset specifications, resolutions, 3D model pipelines, sprite background remover, and UI theming. |
| **07** | [**Customize Your Project**](07-CUSTOMIZE-YOUR-PROJECT.md) | **Key Roadmap**: Step-by-step phases to rebrand and publish your own game or commercial template. |
| **08** | [**CLI Tools & Validation**](08-CLI-TOOLS-AND-VALIDATION.md) | Automated Python/Node scripts in `tools/` to audit referential integrity in seconds. |
| **09** | [**FAQ & Troubleshooting**](09-FAQ-TROUBLESHOOTING.md) | Direct solutions to common configuration, data, and asset questions. |

---

## 🧭 Folder Structure Map

```text
📁 ods-proy-godot/
├── 📄 project.godot          # Primary Godot 4 configuration file
├── 📁 data/                  # THE HEART OF THE GAME: all content in JSON
│   ├── world.json            # Official campaign overworld map
│   ├── world_test.json       # Debug test overworld with all assets exposed
│   ├── enemies/              # Enemy stat sheets, AI, and loot tables
│   ├── dungeons/             # Multi-floor layouts and interactive triggers
│   ├── ids/                  # Cities, POIs, dungeons entries, and map chests
│   ├── quests.json           # Main questline progression order
│   └── dialogues.json        # Narrative notifications and dialogue nodes
├── 📁 editor/                # Local web editor SPA (Vue 3 + serve.py)
├── 📁 scenes/                # Godot scenes (.tscn): views, UI, and components
├── 📁 scripts/               # Engine logic (.gd): autoloads and specialist systems
├── 📁 assets/                # 2D graphics, low-poly 3D models, music, and SFX
├── 📁 tools/                 # CLI validation and asset processing utilities
└── 📁 docs/                  # Technical documentation and guides
    └── 📁 guide/             # Multilingual user guides (en, es, fr, it, de, zh, ja)
```

---

## 💡 Guiding Principle

> **"If it can be defined in a JSON, do not put it in code."**

The architecture completely decouples the **engine code** (which is tested, optimized, and stable) from the **creative content** (story, enemies, maps, and art). 

Creating your own game with this template consists of **editing or replacing JSON data in `data/` using the web editor**, while keeping the robust GDScript engine intact.

---

## 🛠️ Quick Health Check

Before exporting or publishing your project, verify that all references and data links are consistent:

```bash
python tools/validate_data.py
```

When all links are valid, it reports: `✅ Sin errores de integridad cruzada.` (Zero referential integrity errors).
