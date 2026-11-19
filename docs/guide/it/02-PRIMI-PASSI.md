# 02 — Primi Passi

## 1. Requisiti

- **Godot Engine 4.3+**
- **Python 3.8+**
- Browser moderno (Chrome, Edge, Firefox)

---

## 2. Aprire il Progetto in Godot

1. Apri Godot, clicca su **Importa** e seleziona la cartella del progetto (`project.godot`).
2. Al primo avvio, Godot importerà texture e modelli 3D.
3. Premi ▶️ (**Esegui** o `F5`) per entrare nel menu principale.

---

## 3. Avviare l'Editor Web dei Contenuti

Dalla cartella principale del progetto nel terminale:

```bash
python editor/serve.py
```

Si aprirà automaticamente il browser su `http://localhost:8000/`.

---

## 4. Flusso di Lavoro Quotidiano

1. Mantieni attivo il server `python editor/serve.py` in background.
2. Modifica i dati nell'editor (nemici, mappe, dialoghi) e clicca su **Salva**.
3. Torna su Godot e premi ▶️ per testare immediatamente in-game.
4. Prima di confermare le modifiche, esegui il validatore di integrità:
   ```bash
   python tools/validate_data.py
   ```
