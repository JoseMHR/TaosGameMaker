# 08 — Strumenti CLI e Validazione (`tools/`)

---

## `validate_data.py` — Validatore di Integrità dei Dati

```bash
python tools/validate_data.py
```

Analizza tutti i file JSON in `data/` per individuare riferimenti interrotti prima del rilascio:
- Verifica che gli oggetti citati nei forzieri o nei dialoghi esistano in `data/items/`.
- Controlla la validità di classi, abilità ed eventi.
- Verifica i bersagli dei pulsanti dei dungeon (`targets[].eid`).
- Controlla i collegamenti `next` nei nodi dei PNG.

---

## `gen_codemap.py` e `gen_editor_codemap.py`

```bash
python tools/gen_codemap.py          # Aggiorna docs/CODEMAP.md e docs/SYMBOLS.tsv
python tools/gen_editor_codemap.py   # Aggiorna editor/CODEMAP.md
```

Da eseguire ogni volta che si aggiungono o modificano funzioni in GDScript o nell'editor.

---

## `check_editor.mjs` — Analizzatore Sintattico dell'Editor

```bash
node tools/check_editor.mjs
```

Esegue controlli di sintassi su tutti i file JavaScript dell'editor e convalida gli import relativi dei moduli.
