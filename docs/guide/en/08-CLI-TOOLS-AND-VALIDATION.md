# 08 — CLI Tools and Validation (`tools/`)

All scripts in `tools/` are permanent maintenance utilities designed to run from the project root directory.

---

## `validate_data.py` — Referential Integrity Auditor

```bash
python tools/validate_data.py
```

Scans all files in `data/` and verifies cross-references that would otherwise fail silently during gameplay:
1. `item:` tokens and drop tables point to existing files in `data/items/`.
2. `prof:` tokens point to valid classes in `professions.json`.
3. Skill IDs in `professions.json` exist in `skills.json`.
4. Dialogue graph `next` targets exist in the same NPC file (or resolve to `"close"`).
5. Cinematic (`cine:`) and dialogue (`dialogue:`) triggers resolve to valid entries.
6. Dungeon switch targets (`targets[].eid`) exist on the same floor.
7. Overworld map terrain codes exist in `data/world_terrains/`.
8. City `content` arrays point to valid entity files in `data/ids/`.

Returns exit code `0` on success, `1` if broken references are detected. The same engine is integrated into the web editor via the **QA Panel**.

---

## `gen_codemap.py` — Engine Code Map (Godot / GDScript)

```bash
python tools/gen_codemap.py
```

Scans `scripts/`, `scenes/`, and `resources/` to regenerate:
- `docs/CODEMAP.md` — Hierarchical map of all functions, signals, `@export` variables, and regions.
- `docs/SYMBOLS.tsv` — Tab-separated index for rapid symbol grepping (`symbol \t type \t file \t line`).

Run this whenever you add, rename, or move functions in GDScript.

---

## `gen_editor_codemap.py` — Editor Code Map (Vue 3 / JS)

```bash
python tools/gen_editor_codemap.py
```

Scans `editor/js/` and regenerates `editor/CODEMAP.md`. Run this after making structural modifications to the Web Editor.

---

## `check_editor.mjs` — Static Syntax Checker

```bash
node tools/check_editor.mjs
```

Performs three automated checks:
1. **Syntax**: `node --check` across all `editor/**/*.js` files.
2. **Imports**: Verifies all relative module imports resolve to existing files.
3. **Tab Coverage**: Ensures all tabs declared in `nav.js` are properly mounted in `app.js`.

---

## `process_image.py` — Sprite Background Remover

```bash
pip install Pillow
python tools/process_image.py input.jpg output.png --type sprite
python tools/process_image.py input.png output.png --resize 512x512
```

Converts images to 32-bit RGBA PNG, removes solid backgrounds via flood-fill, and softens edges to prevent white halo artifacts in Godot.

---

## Quick Reference Summary

| Task | Command |
|---|---|
| Edited game content in `data/` | `python tools/validate_data.py` |
| Modified engine GDScript code | `python tools/gen_codemap.py` |
| Modified Web Editor JavaScript | `python tools/gen_editor_codemap.py` && `node tools/check_editor.mjs` |
| Added new character or monster sprites | `python tools/process_image.py ... --type sprite` |
