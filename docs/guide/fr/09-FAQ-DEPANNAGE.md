# 09 — FAQ et Dépannage

## Général & Éditeur

**Dois-je maîtriser GDScript pour utiliser ce modèle ?**  
Non. Plus de 90 % de la création de jeu s'effectue via l'Éditeur Web Visuel. GDScript n'est requis que si vous concevez une mécanique inédite (mini-jeu de rythme, système de cartes).

**L'éditeur web nécessite-t-il Node.js ou npm ?**  
Non. L'éditeur est servi nativement par Python (`serve.py`) et charge Vue 3 via CDN.

**J'ai enregistré mes modifications dans l'éditeur, mais rien ne change en jeu.**  
Godot charge les fichiers JSON au démarrage de la partie. Relancez simplement le projet (▶️) ou appelez `Design.reload()`.

**Pourquoi certains POIs n'affichent-ils pas de sprite de personnage au centre de l'écran ?**  
Dans ce modèle, beaucoup d'illustrations 16:9 (`assets/vn/bg/`) intègrent déjà le marchand ou l'habitant dans le décor. Lorsque aucun sprite détouré `npc_<id>.png` n'est configuré, le moteur (`ViewPlace.gd`) affiche l'arrière-plan complet sans superposition redondante.

---

## Données & Multilingue

**Comment fonctionne le support multilingue ?**  
Les champs de texte contiennent les 7 clés de langue (`fr`, `en`, `es`, `it`, `de`, `zh`, `ja`). Si vous ne développez votre jeu qu'en français, vous pouvez ne renseigner que cette clé ; le moteur applique un mécanisme de repli automatique sécurisé.

**Où sont enregistrées les sauvegardes des joueurs ?**  
Dans le répertoire utilisateur (`user://save_slot_*.json`), gérées par `SaveManager.gd`, distinctes des fichiers de conception de `data/`.
