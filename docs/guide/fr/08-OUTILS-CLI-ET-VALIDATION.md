# 08 — Outils CLI et Validation (`tools/`)

Tous les scripts s'exécutent depuis la racine du projet :

---

## `validate_data.py` — Audit d'Intégrité Référentielle

```bash
python tools/validate_data.py
```

Scanne l'ensemble des fichiers de `data/` et vérifie qu'aucun lien n'est brisé :
- Existence des objets référencés dans les butins ou les dialogues.
- Validité des classes, compétences et récepteurs d'interrupteurs de donjons (`targets[].eid`).
- Correspondance des codes de terrain avec `data/world_terrains/`.
- Présence des nœuds de dialogue `next` dans les fichiers PNJ.

---

## `gen_codemap.py` et `gen_editor_codemap.py`

```bash
python tools/gen_codemap.py          # Met à jour docs/CODEMAP.md et docs/SYMBOLS.tsv
python tools/gen_editor_codemap.py   # Met à jour editor/CODEMAP.md
```

À exécuter dès que vous ajoutez, renommez ou déplacez des fonctions en GDScript ou dans l'éditeur.

---

## `check_editor.mjs` — Vérificateur Statique de l'Éditeur

```bash
node tools/check_editor.mjs
```

Contrôle la syntaxe JavaScript et valide que tous les imports relatifs de l'éditeur sont corrects.
