# 02 — Premiers Pas

## 1. Prérequis

- **Godot Engine 4.3+**
- **Python 3.8+** (utilisé pour héberger l'éditeur local avec `editor/serve.py`)
- Un navigateur web récent (Chrome, Firefox, Edge)

---

## 2. Ouvrir le jeu dans Godot

1. Lancez Godot 4, cliquez sur **Importer**, et sélectionnez le dossier racine du projet (`project.godot`).
2. Lors de la première ouverture, Godot réimporte les ressources 3D et textures.
3. Appuyez sur ▶️ (**Lancer le projet** ou `F5`). La scène principale se lance (`MainMenu.tscn`).

---

## 3. Lancer l'Éditeur Web

Dans votre terminal à la racine du projet :

```bash
python editor/serve.py
```

Cela démarre le serveur local sur `http://localhost:8000/` et ouvre automatiquement votre navigateur par défaut.

Drapeaux de commande utiles :
```bash
python editor/serve.py --port 8123      # Port alternatif
python editor/serve.py --no-open        # Ne pas ouvrir le navigateur automatiquement
```

---

## 4. Flux de Travail Quotidien Recommandé

1. Laissez `python editor/serve.py` tourner dans un terminal en tâche de fond.
2. Modifiez le contenu dans votre navigateur (monstres, donjons, dialogues) et cliquez sur **Sauvegarder**.
3. Basculez sur Godot et appuyez sur ▶️ pour tester immédiatement en jeu.
4. Avant de valider vos modifications, lancez le vérificateur d'intégrité :
   ```bash
   python tools/validate_data.py
   ```
