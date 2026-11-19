# 05 — Mécaniques de Jeu (Les 4 Piliers)

Consultez les spécifications détaillées dans `docs/design/` pour approfondir chaque mode.

---

## 1. 🗺️ Carte du Monde 3D Top-Down
- Mouvement par cases sur grille avec brouillard de guerre.
- **Récolte d'outils** : Hache pour le bois, pioche pour la pierre/minerai, canne à pêche, pelle pour les trésors.
- **Campement** : Tente pour soigner et avancer l'horloge ; feu de camp pour cuisiner des recettes conférant des bonus.
- **Transformations de terrain** : Modification dynamique de cases selon les flags de quête (`world_transforms.json`).

---

## 2. 🏰 Donjons à la 1ère Personne
- Mouvement pas à pas en 3D avec mini-carte dynamique et ennemis en sprites 2D.
- **6 Compétences d'exploration** : Onde cinétique (interrupteurs), Grappin psychique (anneaux), Vue du chasseur (murs secrets), Affinité élémentaire (torches/glace), Purification (gaz toxique), Chrono (plates-formes mobiles).

---

## 3. ⚔️ Combat Tactique au Tour par Tour
- Disposition classique : équipe à gauche, ennemis à droite.
- **Jauge ATB + Points d'Action (PA)** : Enchaînez plusieurs sorts ou attaques lors du même tour.
- **Synergies** : Associez certaines compétences consécutives pour déclencher des fusions élémentaires dévastatrices.
- **Garde Réactive en QTE** : Anneau temporel pour réduire les dégâts ou exécuter une Garde Parfaite.

---

## 4. 📖 Narration & Visual Novel
- Décors panoramiques 16:9 (`assets/vn/bg/`) et portraits centrés.
- **5 Facettes de personnalité** (`courage`, `bonté`, `charisme`, `intelligence`, `sang-froid`) débloquant des lignes de dialogue exclusives.
- Arbres de choix multilingues (7 langues) gérés par `data/npcs/<id>.json`.
