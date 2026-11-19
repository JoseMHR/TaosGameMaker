# 07 — Personnaliser Votre Projet (Feuille de Route)

## Phase 0 — Modèle Commercial et Portée

### Modèles de Distribution
- **En tant que Modèle Premium / Moteur JRPG pour d'autres créateurs (itch.io, Gumroad, Asset Store)** :
  Distribuez l'intégralité du projet comprenant Godot 4 et le dossier `editor/`. L'acheteur bénéficie d'une solution clé en main prête à l'emploi et de ce guide complet disponible en 7 langues.
- **En tant que Jeu Commercial Indépendant (Steam, Nintendo Switch, Google Play, iOS)** :
  Remplacez le contenu de `data/` et les ressources de `assets/` par vos propres créations. Lors de l'exportation depuis Godot (`export_presets.cfg`), les outils de développement (`editor/`, `tools/`, `docs/`) sont **automatiquement exclus**.

---

## Phase 1 — Rebranding

1. **Nom du projet** : Dans `project.godot`, modifiez `[application] config/name="VotreJeu"`.
2. **Icône** : Remplacez `icon.png` à la racine.
3. **Écran de démarrage** : Remplacez `assets/common/boot_splash.png`.
4. **Crédits** : Mettez à jour `Credits.txt` avec votre équipe et les licences tierces conservées.
5. **Langues** : Modifiez la langue par défaut dans `scripts/autoload/Locale.gd` (`var current_locale = "fr"`).

---

## Phases 2 à 8 — Création de Contenu

1. **Histoire** : Définissez les états de la trame principale dans `data/quests.json`.
2. **Classes et Compétences** : Créez vos classes dans l'onglet *Métiers* et vos compétences dans l'onglet *Compétences*.
3. **Bestiaire** : Concevez vos ennemis dans l'onglet *Ennemis* et équilibrez-les avec le **Combat Sandbox**.
4. **Monde** : Peignez votre carte du monde avec l'onglet *Carte* et configurez vos villes.
5. **Donjons** : Dessinez vos donjons et testez-les avec le modal de simulation *Walkthrough*.
6. **PNJs et Dialogues** : Créez les conversations et testez-les avec le simulateur Visual Novel.

---

## Phase 9 — Liste de Contrôle Finale

- [ ] `python tools/validate_data.py` exécuté sans aucune erreur d'intégrité.
- [ ] Cartes de code mises à jour (`python tools/gen_codemap.py`, `python tools/gen_editor_codemap.py`).
- [ ] Test complet de la partie de bout en bout dans Godot.
