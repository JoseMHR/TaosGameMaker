# ⚔️ JRPG Complete Template & Engine — Guide de l'utilisateur

> **Bienvenue dans le modèle et moteur JRPG professionnel pour Godot 4.**  
> Ce projet associe un jeu complet (carte du monde 3D en vue de dessus, exploration de donjons à la première personne, combat au tour par tour et narration style visual novel) à un **Éditeur Web Visuel dédié** qui vous permet de créer, modifier et équilibrer l'ensemble de votre jeu sans écrire une seule ligne de code.

---

## ⚡ Démarrage Rapide (En moins de 3 minutes)

Aucune configuration de base de données ni étape de compilation complexe requise :

### 1. Prérequis
- **Godot Engine 4.3+** (Standard ou .NET).
- **Python 3.8+** (Préinstallé sur macOS/Linux ; téléchargeable sur [python.org](https://www.python.org/) pour Windows).

### 2. Ouvrir et Jouer dans Godot
1. Ouvrez **Godot Engine** et cliquez sur **Importer**.
2. Sélectionnez le fichier `project.godot` de ce répertoire.
3. Cliquez sur **Lancer le projet** (ou appuyez sur `F5`). Vous êtes sur le menu principal !
   - Pour tester l'intégralité du contenu, sélectionnez **Mode Debug / Salle de Tests** dans le menu.

### 3. Lancer l'Éditeur Web de Contenu
L'éditeur est une application web locale ne nécessitant ni `npm` ni compilation :
1. Ouvrez un terminal dans le dossier racine du projet.
2. Exécutez :
   ```bash
   python editor/serve.py
   ```
3. Ouvrez votre navigateur sur :
   👉 **[http://localhost:8000](http://localhost:8000)**

Toute modification enregistrée dans l'éditeur web (ennemis, cartes, dialogues, etc.) **se reflète immédiatement dans Godot sans redémarrer le moteur**.

---

## 🎮 Que contient ce modèle ?

### 🗺️ 4 Piliers de Jeu Entièrement Intégrés
1. **Monde 3D Top-Down** : Système de cases hexagonales/carrées, brouillard de guerre, biomes, aléas climatiques, transformations persistantes du monde (arbres coupables, rochers destructibles, campements constructibles) et navire navigable.
2. **Donjons à la 1ère Personne (3D Dungeon Crawler)** : Donjons case par case avec mini-carte dynamique, portes verrouillées, pièges à énigmes, coffres et combats de boss.
3. **Combat Tactique au Tour par Tour** : Système JRPG avec calculs élémentaires, altérations d'état, file de points d'action (PA), synergies de compétences et caméra dynamique.
4. **Narration & Visual Novel** : Arbres de dialogues à choix multiples, portraits expressifs, musique d'ambiance réactive, quêtes et flags globaux persistants.

### 🛠️ Éditeur Web Visuel "No-Code"
Une suite complète de conception de jeux directement dans votre navigateur :
- **Éditeur de Monde 3D** : Peignez les terrains, placez villes, donjons, ressources et coffres en un clic.
- **Concepteur de Donjons** : Créez des niveaux sur grille 3D avec prévisualisation des textures et simulation de parcours pas à pas (*DungeonWalkthroughModal*).
- **Créateur d'Ennemis et Compétences** : Réglez statistiques, IA, drops et testez n'importe quel combat en direct grâce au **Combat Sandbox** intégré.
- **Éditeur de Dialogues et Quêtes** : Créez des arbres de conversation avec l'éditeur visuel de graphes (*NpcGraphEditor*) et émulateur de Visual Novel (*VnSimulator*).
- **Arbres de Talents, Métiers et Synergies** : Équilibrez l'évolution des classes.
- **Assistants Rapides (Wizards)** : Générez des donjons complets, quêtes, objets et POIs en un clic.
- **Support Multilingue Natif (7 langues)** : Français, anglais, espagnol, italien, allemand, chinois et japonais avec changement instantané en jeu.

### 🧪 Salle de Tests & Debug
- Comprend `data/world_test.json`, un monde de test modulaire organisé en 8 pavillons exposant **100 % des POIs (162), villes (4), donjons (13) et ennemis (41)**.

---

## 📚 Sommaire du Guide

| Chapitre | Titre | Description |
|---|---|---|
| **01** | [**Vue d'Ensemble et Architecture**](01-VUE-D-ENSEMBLE-ET-ARCHITECTURE.md) | Comprendre l'architecture, le stack technique et la philosophie data-driven. |
| **02** | [**Premiers Pas**](02-PREMIERS-PAS.md) | Configuration initiale, serveur local et flux de travail quotidien. |
| **03** | [**Éditeur Web : Guide Complet**](03-EDITEUR-WEB-GUIDE-COMPLET.md) | Manuel exhaustif de tous les onglets, fenêtres et assistants. |
| **04** | [**Structure des Données (JSON)**](04-STRUCTURE-DES-DONNEES.md) | Dictionnaire des données, syntaxe des conditions et mini-langage de récompenses. |
| **05** | [**Mécaniques de Jeu**](05-MECANIQUES-DE-JEU.md) | Fonctionnement détaillé des 4 modes de jeu. |
| **06** | [**Art, Audio et Assets**](06-ART-AUDIO-ET-ASSETS.md) | Résolutions standard, pipeline 3D, détourage de sprites et thèmes d'interface. |
| **07** | [**Personnaliser Votre Projet**](07-PERSONNALISER-VOTRE-PROJET.md) | **Feuille de route** pour créer votre jeu commercial ou distribuer ce template. |
| **08** | [**Outils CLI et Validation**](08-OUTILS-CLI-ET-VALIDATION.md) | Scripts automatisés en `tools/` pour auditer l'intégrité des données. |
| **09** | [**FAQ et Dépannage**](09-FAQ-DEPANNAGE.md) | Réponses directes aux questions courantes. |

---

## 💡 Principe Fondateur

> **« Si cela peut être défini dans un JSON, ne le mettez pas dans le code. »**

Créer votre jeu avec ce modèle consiste simplement à **éditer ou remplacer les fichiers JSON dans `data/` via l'éditeur web**, tout en préservant le moteur GDScript stable.
