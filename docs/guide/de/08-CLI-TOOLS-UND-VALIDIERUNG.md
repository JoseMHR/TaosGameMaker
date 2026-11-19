# 08 — CLI-Tools und Validierung (`tools/`)

---

## `validate_data.py` — Datenintegritäts-Prüfer

```bash
python tools/validate_data.py
```

Überprüft alle JSON-Dateien in `data/` auf ungültige Querverweise vor dem Release:
- Existenz referenzierter Items in Beutetabellen oder Dialogen.
- Gültigkeit von Klassen, Fähigkeiten und Dungeon-Schalterzielen (`targets[].eid`).
- Übereinstimmung von Kachelcodes mit `data/world_terrains/`.
- Verknüpfungen von `next`-Knoten in NPC-Dialogen.

---

## `gen_codemap.py` und `gen_editor_codemap.py`

```bash
python tools/gen_codemap.py          # Aktualisiert docs/CODEMAP.md und docs/SYMBOLS.tsv
python tools/gen_editor_codemap.py   # Aktualisiert editor/CODEMAP.md
```

Immer ausführen, wenn Funktionen in GDScript oder im Editor hinzugefügt oder verschoben wurden.

---

## `check_editor.mjs` — Statischer Syntax-Checker

```bash
node tools/check_editor.mjs
```

Prüft die JavaScript-Syntax aller Editor-Dateien und validiert relative Modul-Importe.
