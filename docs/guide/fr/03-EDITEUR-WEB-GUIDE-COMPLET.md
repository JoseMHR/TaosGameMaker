# 03 — Éditeur Web : Guide Complet

La liste de tous les onglets est centralisée dans `editor/js/collections.js` (`TABS`).

---

## 🗺️ Groupe Monde

- **Carte (`map` → `MapEditor.js`)** : Éditeur de carte du monde 3D top-down (`data/world.json`). Peignez les terrains, placez villes, donjons, coffres et ressources.
- **Espace Villes (`cityWorkspace` → `CityWorkspace.js`)** : Panneau tout-en-un pour configurer une cité, ses points d'intérêt (tavernes, commerces) et ses PNJs associés.
- **Entités (`ids` → `IdsManager.js`)** : Gestion des POIs, donjons et coffres sur la carte avec support multilingue (7 langues). Comprend l'assistant **POI Wizard**.
- **Donjons (`dungeons` → `DungeonEditor.js`)** : Conception de donjons multi-étages sur grille 3D avec modal de parcours pas à pas (*DungeonWalkthroughModal*) et assistant (*DungeonWizardModal*).
- **Pièces de donjon (`dungeonPieces` → `DungeonPiecesManager.js`)** : Gestion unifiée des tuiles fixes 🔒, cosmétiques 🎨 et Objets Intelligents 🧩 (*Smart Objects* de `data/dungeon_kits.json`).

---

## 💬 Groupe Personnages

- **PNJs (`npcs` → `NpcEditor.js`)** : Arbres de dialogues sauvegardés dans `data/npcs/<id>.json`. Comprend un éditeur visuel de graphe (`NpcGraphEditor.js`), un simulateur de Visual Novel (`VnSimulatorModal.js`) et la prise en charge d'avatars emoji.
- **Ennemis (`enemies` → `EnemiesManager.js`)** : Fiches statistiques, IA, affinités élémentaires et butins.
  > ⚔️ **Combat Sandbox** : Ouvrez le simulateur de combat (`CombatSandboxModal.js`) pour tester et équilibrer vos monstres directement dans le navigateur sans lancer Godot.

---

## 🎒 Objets & Systèmes

- **Objets (`items` → `ItemsManager.js`)** : Consommables, armes, armures et objets de quête avec l'assistant *Item Wizard*.
- **Métiers / Classes (`professions` → `ProfessionsManager.js`)** : Définition des classes jouables et compétences débloquées par niveau.
- **Compétences (`skills` → `SkillsManager.js`)** : Catalogue des sorts et attaques de combat du joueur.
- **Synergies (`synergies` → `SynergiesManager.js`)** : Combos de compétences déclenchés lors du même tour.
- **Boutiques (`shops` → `ShopsManager.js`)** : Inventaires de marchands réutilisables.

---

## ⭐ Histoire, Progression & Équilibrage

- **Événements (`events` → `EventsManager.js`)** : Déclencheurs narratifs liant conditions et actions.
- **Quêtes (`quests` → `QuestsManager.js`)** : Chronologie de la trame principale et récompenses de victoire de boss (*QuestWizardModal*).
- **Configuration (`config` → `ConfigManager.js`)** : **Panneau complet d'équilibrage du jeu** (courbes d'XP, formules de dégâts, cadence des tours ATB, économie).
