# 01 — Vue d'Ensemble et Architecture

## 1. Ce qu'est exactement ce modèle

Il s'agit d'un **RPG complet et jouable** ("Taos Game Maker" dans `project.godot`) accompagné d'un **éditeur de contenu visuel sur mesure**. Ce n'est pas un moteur vide : c'est un jeu déjà fonctionnel, conçu pour que vous réutilisiez **80 à 90 % du moteur** (combat, exploration, donjons, dialogues, sauvegarde, progression) tout en remplaçant le **contenu** (histoire, ennemis, carte, graphismes et audio) par le vôtre.

Il comprend 4 piliers de gameplay autonomes + 1 socle de systèmes globaux :

| Pilier | Contenu | Contrôleur Principal |
|---|---|---|
| 🗺️ **Monde** | Carte 3D vue de dessus, récolte, campement, voyage maritime | `scenes/tabs/tab_world_3d/TabWorld3D.gd` |
| 🏰 **Donjons** | Exploration 1ère personne sur grille, énigmes, 6 compétences | `scenes/views/view_dungeon/ViewDungeon.gd` |
| ⚔️ **Combat** | JRPG au tour par tour (ATB + file de Points d'Action + synergies) | `scenes/views/view_combat/ViewCombat.gd` |
| 📖 **Narration** | Visual novel : graphes de dialogues ramifiés, PNJs, villes, quêtes | `scenes/views/view_place/ViewPlace.gd` |
| ⚙️ **Systèmes globaux** | Objets, boutiques, succès, tutoriels, équilibrage | Autoloads (voir ci-dessous) |

---

## 2. Stack Technologique

| Couche | Technologie | Emplacement |
|---|---|---|
| Moteur de jeu | **Godot 4.x** (testé sur 4.3+), GDScript, rendu `mobile`, physique 3D native | Racine, `project.godot` |
| Plateformes cibles | Mobile (Android/iOS) + Ordinateur (Windows, macOS, Linux) | `project.godot` → `config/features` |
| Éditeur de contenu | **Vue 3** (via CDN `unpkg.com/vue@3`, **aucun build step**, sans npm) | `editor/js/` |
| Serveur local éditeur | **Python 3** pur (`http.server`), aucune bibliothèque tierce | `editor/serve.py` |
| Persistance | **JSON brut** sur disque, lu par Godot et par l'éditeur | `data/` |
| Validation | Script d'intégrité référentielle en Python | `tools/validate_data.py` |

---

## 3. Interaction Godot, Éditeur Web et JSON

```
┌─────────────────────┐       Lecture / Écriture       ┌──────────────────────────┐
│   Éditeur Web (Vue) │ ───────────────────────────▶   │   data/*.json et         │
│  editor/js/*.js     │  ◀───────────────────────────  │   data/<dossier>/*.json  │
│  (localhost:8000)   │        via HTTP (serve.py)     └──────────────────────────┘
└─────────────────────┘                                             ▲
                                                                    │ Chargement mémoire
                                                                    │ au lancement
                                                           ┌──────────────────────┐
                                                           │    Godot (Le Jeu)    │
                                                           │   Design.gd (autoload│
                                                           └──────────────────────┘
```

- L'éditeur web modifie les fichiers JSON directement sur votre disque local via l'API de `serve.py`.
- Au démarrage, l'autoload `Design.gd` charge tous les fichiers JSON en mémoire et offre des méthodes d'accès rapides pour l'ensemble du moteur (`Design.get_enemy(id)`, `Design.get_item(id)`).
- **Aucune étape de compilation** : sauvegardez dans l'éditeur, relancez le jeu dans Godot, les changements sont immédiatement actifs.

---

## 4. Les Autoloads (Singletons Globaux de Godot)

Déclarés dans `project.godot` sous `[autoload]` :

| Autoload | Fichier | Rôle Principal |
|---|---|---|
| `Locale` | `scripts/autoload/Locale.gd` | Gestion multilingue (7 langues : FR, EN, ES, IT, DE, ZH, JA), mise à l'échelle des polices, filtres daltonisme |
| `Design` | `scripts/autoload/Design.gd` | Chargement et cache de tous les JSON de `data/` |
| `ExplorationSkills` | `scripts/autoload/ExplorationSkills.gd` | Logique des 6 compétences d'exploration de donjon |
| `GlobalState` | `scripts/autoload/GlobalState.gd` | Statistiques du joueur, or, inventaire, équipement, flags |
| `GlobalEvents` | `scripts/autoload/GlobalEvents.gd` | Bus d'événements globaux découplé |
| `SaveManager` | `scripts/autoload/SaveManager.gd` | Sauvegarde et chargement de parties |
| `TimeManager` | `scripts/autoload/TimeManager.gd` | Cycle jour/nuit et calendrier |
| `QuestManager` | `scripts/autoload/QuestManager.gd` | Suivi des quêtes et déclenchement de cinématiques |
| `SceneRunner` | `scripts/autoload/SceneRunner.gd` | Moteur d'exécution des scènes narratives |
| `NarrativeOverlay` | `scenes/components/narrative/NarrativeOverlay.gd` | Interface d'affichage des dialogues visual novel |
| `SceneManager` | `scripts/autoload/SceneManager.gd` | Transitions et changements de scènes |
| `AudioManager` | `scripts/autoload/AudioManager.gd` | Musiques d'ambiance et bruitages |

---

## 5. Philosophie « Data-Driven » : Code vs Contenu

- **Code (GDScript — à ne pas toucher pour un nouveau jeu)** : Calcul des dégâts, moteur de collision, rendu des donjons, boucles de combat.
- **Contenu (JSON — modifiable à 100 % via l'éditeur)** : Statistiques des monstres, butins, choix de dialogue, agencement des cartes et formules d'équilibrage (`data/config.json`).
