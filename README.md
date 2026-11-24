# ⚔️ Taos Game Maker — Complete RPG Engine & Studio Suite (Godot 4)

> **Taos Game Maker is a turnkey, hybrid 2D/3D RPG engine and studio suite for Godot 4, bundled with a standalone visual Web Editor and native 7-language support.**  
> Create, edit, and publish your own full-fledged role-playing game without writing engine code from scratch.

<div align="center">

![Engine](https://img.shields.io/badge/Engine-Godot_4.3%2B-478CBF?logo=godot-engine&logoColor=white)
![Studio](https://img.shields.io/badge/Web_Studio-45%2B_visual_tools-8A2BE2)
![Release](https://img.shields.io/github/v/release/JoseMHR/TaosGameMaker?color=2ea44f&label=Release)
![License](https://img.shields.io/badge/License-100%25_Free_%26_Open_Source-brightgreen)
![Royalties](https://img.shields.io/badge/Games_you_build-100%25_Royalty--Free-F9A825)
![Export](https://img.shields.io/badge/Export-Windows_%7C_macOS_%7C_Linux_%7C_Android-00A8E8)
[![Donate](https://img.shields.io/badge/Donate-PayPal-00457C?style=flat&logo=paypal&logoColor=white)](https://www.paypal.com/donate/?hosted_button_id=SAWNH6X9N38RY)

**[📖 Official Documentation & Showcase](https://josemhr.github.io/TaosGameMaker/) · [📦 Download v1.1 Packages](https://github.com/JoseMHR/TaosGameMaker/releases/latest) · [🎮 Play Free Demo](https://taosworld.itch.io/echoesoftruth) · [🎬 Engine Video Tour](https://youtu.be/9ugIta7vTkQ) · [🎬 Game Trailer (ES)](https://youtu.be/xNsCNHatSUI) · [🎬 Game Trailer (EN)](https://youtu.be/Omau2eJ1cR8) · [🌐 Literary Universe](https://sites.google.com/view/sagalazaro) · [💖 Donate](https://www.paypal.com/donate/?hosted_button_id=SAWNH6X9N38RY)**

</div>

---

## 🌐 Select Your Language / Elige tu Idioma / Choisissez votre Langue

The complete user guide, web editor manual, data schemas, and commercial customization steps are fully translated and documented in **7 native languages**:

| Language | Portal / Guide | Description |
| :--- | :--- | :--- |
| 🇪🇸 **Español** | [**docs/guide/es/**](docs/guide/es/README.md) | Guía de usuario completa, manual del editor web y personalización |
| 🇬🇧 **English** | [**docs/guide/en/**](docs/guide/en/README.md) | Complete user guide, web editor manual, and project customization |
| 🇫🇷 **Français** | [**docs/guide/fr/**](docs/guide/fr/README.md) | Guide complet de l'utilisateur, manuel de l'éditeur web et personnalisation |
| 🇮🇹 **Italiano** | [**docs/guide/it/**](docs/guide/it/README.md) | Guida utente completa, manuale dell'editor web e personalizzazione |
| 🇩🇪 **Deutsch** | [**docs/guide/de/**](docs/guide/de/README.md) | Vollständiges Benutzerhandbuch, Web-Editor-Handbuch und Anpassung |
| 🇨🇳 **简体中文** | [**docs/guide/zh/**](docs/guide/zh/README.md) | 完整用户指南、Web编辑器手册与游戏定制指南 |
| 🇯🇵 **日本語** | [**docs/guide/ja/**](docs/guide/ja/README.md) | 完全ユーザーガイド、Webエディタマニュアル、プロジェクトカスタマイズ |

👉 **Central Documentation Hub**: [**docs/guide/README.md**](docs/guide/README.md)

---

## 🚀 Quick Start in 3 Steps

### 1. Requirements
- **Godot Engine 4.3+** (Standard or .NET edition).
- Any modern web browser (Chrome, Firefox, Edge, Safari).
- Python 3.8+ (for serving the local web editor).

### 2. Play the Game in Godot
1. Open **Godot Engine** and import `project.godot`.
2. Press **Play (`F5`)**.
3. Explore the full campaign, or test mechanics, dungeons, world map, and battle systems.

### 3. Launch the Visual Content Web Editor (1-Click)
In the project root folder:
- **Windows**: Double-click `start_editor.bat`
- **macOS / Linux**: Double-click `start_editor.sh` (or run `./start_editor.sh` in terminal)
- *Alternative via terminal*:
  ```bash
  python editor/serve.py
  ```
The server will start and automatically open your default browser at:  
👉 **[http://localhost:8000](http://localhost:8000)**

From the web editor, you can visually create and modify Zones, POIs, Dialogues, Enemies, Skills, Items, and run real-time battle simulations in the **Combat Sandbox** with instant hot-reloading!

---

## 🌟 Key Features

- **Decoupled Architecture**: All game content lives in clean JSON files inside `data/`. Game logic and presentation live in `scenes/` and `scripts/`.
- **Integrated Web Editor (`editor/`)**: Visual, browser-based editor with real-time Combat Simulator, Dialogue Graph visualization, and quick export.
- **Hybrid Gameplay Modes**:
  - 🗺️ **3D World Map**: Top-down terrain exploration, camping, gathering, dynamic weather, and day/night cycles.
  - 🏰 **3D Grid Dungeons**: First-person dungeon crawling with puzzles and 6 exploration abilities.
  - ⚔️ **2D Turn-Based JRPG Combat**: ATB turn engine, Action Points, Elemental affinities, resonance synergies, and animated FX.
  - 📜 **Narrative Visual Novel**: Interactive POI dialogue trees, multi-choice branching, shopkeepers, and faction reputation.
- **Native 7-Language Localization**: Full translation system supporting English, Spanish, French, Italian, German, Simplified Chinese, and Japanese with automatic safe fallback.
- **Commercial Ready**: Modular design ready to be published as a standalone game (Steam, itch.io, consoles) or distributed as a customizable commercial RPG engine/template.

---

## 📜 License & Commercial Rights

This software is governed by the terms in [`LICENSE.txt`](LICENSE.txt):

1. **Games Created with Taos Game Maker (Commercial & Royalty-Free)**:
   - You own 100% of any commercial or non-commercial game you develop using this framework.
   - You may freely sell, monetize, and distribute your compiled games across any platform (Steam, itch.io, Epic Games Store, Nintendo Switch, PlayStation, Xbox, iOS, Android, Web) with **zero royalties or ongoing fees**.
   - **Attribution Requirement**: You must include credit in your game stating:  
     `"Created with Taos Game Maker"` or `"Powered by Taos Game Maker"`.

2. **Free & Open-Source Engine & Editor**:
   - Taos Game Maker and the included visual Web Editor suite (`editor/`) are 100% free and open-source software.
   - You are free to modify, extend, and adapt the framework for your own games.
   - You may not re-package or resell the unmodified raw framework template as a competing engine product in digital stores.

3. **Third-Party Assets**:
   - Included 3D models, sound effects, and music in the demonstration project are licensed under permissive open/CC0 terms as documented in [`Credits.txt`](Credits.txt).

---

## 🗂️ Project Structure

```text
├── data/              # All game content (JSON): zones, pois, enemies, items, dialogues...
├── editor/            # Standalone visual web content editor (HTML5/Vue/CSS)
├── docs/
│   ├── guide/         # Complete documentation in 7 languages (es, en, fr, it, de, zh, ja)
│   ├── design/        # Game design documents and mechanics specifications
│   ├── CODEMAP.md     # Auto-generated Godot architecture codemap
│   └── INDEX.md       # AI & Developer routing table
├── scenes/            # Godot UI, 3D world, dungeon, and combat scenes
├── scripts/           # GDScript managers, systems, and autoloads
├── assets/            # Audio, fonts, textures, 3D models, and UI themes
├── tools/             # CLI data validators and utility scripts
├── start_editor.bat   # 1-click editor launcher for Windows
├── start_editor.sh    # 1-click editor launcher for macOS / Linux
├── LICENSE.txt        # Commercial license and usage terms
└── project.godot      # Godot 4 main project configuration
```

---

## 📖 Complete Documentation Index

For in-depth guides, select your preferred language folder inside [`docs/guide/`](docs/guide/README.md):
- **Chapter 01**: Overview and Engine Architecture
- **Chapter 02**: Getting Started & First Steps
- **Chapter 03**: Web Editor Complete Guide & Combat Sandbox
- **Chapter 04**: Data Structure & JSON Schemas
- **Chapter 05**: Game Mechanics & Turn-Based Combat Formulas
- **Chapter 06**: Art, Audio, and Asset Requirements
- **Chapter 07**: Customizing Your Project (Rebranding, Genres & Commercialization)
- **Chapter 08**: CLI Tools and Automated Data Validation
- **Chapter 09**: FAQ & Troubleshooting

---

## 💖 Support & Donations

Taos Game Maker and the Web Studio Suite are **100% free, open-source, and royalty-free forever**.  
If this framework has been helpful for creating your games, saved you weeks of work, or if you wish to support its ongoing maintenance and new features, any donation is deeply appreciated.

<div align="center">

[![Donate with PayPal](https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif)](https://www.paypal.com/donate/?hosted_button_id=SAWNH6X9N38RY)

<br/>

<a href="https://www.paypal.com/donate/?hosted_button_id=SAWNH6X9N38RY" target="_blank" rel="noopener">
  <img src="docs/assets/paypal-qr.png" alt="Scan QR to donate via PayPal" width="160" style="border-radius: 12px; margin: 12px 0;" />
</a>

<br/>

*Scan the QR code with your mobile device or click the button to donate securely via PayPal.*

👉 **Direct link:** [https://www.paypal.com/donate/?hosted_button_id=SAWNH6X9N38RY](https://www.paypal.com/donate/?hosted_button_id=SAWNH6X9N38RY)

</div>

---

*Taos Game Maker — Built with Godot 4 and modern Web technologies.*
