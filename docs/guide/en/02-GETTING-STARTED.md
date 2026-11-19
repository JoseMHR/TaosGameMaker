# 02 — Getting Started

## 1. Prerequisites

| Tool | Recommended Version | Purpose |
|---|---|---|
| **Godot Engine** | **4.x** (recommended **4.3 or higher**) | Run, test, and export the game |
| **Python** | 3.8+ | Host the local web editor server (`editor/serve.py`) and run `tools/` |
| **Node.js** | Any recent LTS | Optional: only for `tools/check_editor.mjs` (syntax checker) |
| Modern Web Browser | Chrome / Edge / Firefox | Use the Visual Content Editor |

No `npm install`, `webpack`, or external Python dependencies are needed: **the editor and engine run entirely with standard libraries**.

---

## 2. Opening the Project in Godot

1. Open Godot Engine (4.3+), click **Import**, and select the project root folder (where `project.godot` is located).
2. On first import, Godot will process all 3D models and textures (this may take 1-2 minutes depending on your hardware).
3. Press ▶️ (**Play Project** or `F5`). The boot scene is `scenes/ui/main_menu/MainMenu.tscn`.
4. The renderer is preconfigured to `mobile` (`project.godot` → `[rendering]`) for optimal cross-platform compatibility across PC, Android, and iOS.

---

## 3. Starting the Visual Content Editor

From your terminal in the **project root directory**:

```bash
python editor/serve.py
```

Or from inside the `editor/` directory:

```bash
python serve.py
```

This command will:
1. Start a local HTTP server at `http://localhost:8000/`.
2. Automatically launch your default browser to that URL (use `--no-open` to disable auto-launch).
3. Serve the Vue 3 Single Page Application and expose endpoints that directly read and write files in `data/` and `assets/`.

CLI Flags:
```bash
python editor/serve.py --port 8123      # Use a custom port
python editor/serve.py --host 0.0.0.0   # Allow access from other devices on your LAN
python editor/serve.py --no-open        # Do not automatically open the browser
```

> ⚠️ The editor writes directly to your local project files on disk. Save operations immediately modify `data/*.json`. Keep your project under git version control and make commits regularly as you build.

---

## 4. Editor Interface Overview

When opening `http://localhost:8000/`, you will see the **Welcome Panel / Hub** (`editor/js/components/WelcomePanel.js`) with large cards representing the 4 gameplay pillars and global systems.

You can switch navigation perspectives in the top bar:
- **Data Mode**: Groups tabs logically by data type (World, Characters, Items, Narrative, Balance).
- **Designer Mode**: Groups tabs by workflow tasks (Overworld, Level Design, Bestiary, Quests).

Both modes read from the single configuration source (`editor/js/nav.js` → `GAME_MODES`).

Universal tools accessible from any tab:
- **🔍 Global Search** (`Ctrl+K` / `GlobalSearch.js`): Search for any ID, name, or text across all collections simultaneously.
- **✅ QA Panel** (`QaPanel.js`): Run referential integrity audits directly in the browser.
- **↩️ Undo / Redo**: Multi-level history per open tab with unsaved change badges.
- **❓ Contextual Help** (`HelpDrawer.js`): Explains the purpose and fields of the active tab.

---

## 5. Recommended Daily Workflow

1. Start `python editor/serve.py` in a background terminal.
2. Edit content in the browser (enemies, dungeon layouts, dialogues, loot tables) and click **Save**.
3. Switch to Godot and press ▶️ to test immediately (no need to restart the web server; Godot reloads the JSON upon launching a scene).
4. Run the data validation tool before committing:
   ```bash
   python tools/validate_data.py
   ```
   This catches broken references (e.g. an enemy dropping a non-existent item ID) before runtime.
5. If you modified engine GDScript or editor JS files, update the automated code maps:
   ```bash
   python tools/gen_codemap.py          # if you changed scripts/ or scenes/
   python tools/gen_editor_codemap.py   # if you changed editor/js/
   node tools/check_editor.mjs          # static syntax check for the editor
   ```

---

## 6. Next Step

Continue to `03-WEB-EDITOR-COMPLETE-GUIDE.md` for a comprehensive breakdown of every editor panel and creation wizard.
