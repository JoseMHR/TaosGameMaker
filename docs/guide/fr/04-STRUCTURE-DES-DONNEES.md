# 04 — Structure des Données (`data/`)

Tout le contenu du jeu réside dans `data/` au format JSON brut :

- **`kind: 'doc'`** : Un fichier JSON unique contenant un dictionnaire (`professions.json`, `config.json`, `quests.json`).
- **`kind: 'perId'`** : Un dossier contenant **un fichier JSON par élément** (`enemies/<id>.json`, `npcs/<id>.json`, `dungeons/<id>.json`).

---

## 1. Support Multilingue Natif (7 Langues)

Tous les textes affichés au joueur sont stockés dans un dictionnaire contenant les 7 langues officielles :
- `fr` (Français)
- `en` (Anglais)
- `es` (Espagnol)
- `it` (Italien)
- `de` (Allemand)
- `zh` (Chinois Simplifié)
- `ja` (Japonais)

Exemple :
```json
"text": {
    "fr": "Bienvenue à la taverne !",
    "en": "Welcome to the tavern!",
    "es": "¡Bienvenido a la taberna!",
    "it": "Benvenuto alla taverna!",
    "de": "Willkommen in der Taverne!",
    "zh": "欢迎来到酒馆！",
    "ja": "酒場へようこそ！"
}
```

---

## 2. Le Mini-Langage des RÉCOMPENSES (`reward`)

Utilisé dans les dialogues, événements et succès. Chaîne de jetons séparés par des points-virgules `;` :

| Jeton | Syntaxe | Effet |
|---|---|---|
| `gold` | `gold:±N` | Ajoute ou retire de l'or |
| `xp` | `xp:N` | Attribue de l'expérience au personnage |
| `heal` | `heal` | Restaure tous les PV et PM de l'équipe |
| `damage` | `damage:N` / `damage:N%` | Inflige des dégâts hors combat (laisse à 1 PV min.) |
| `item` | `item:ID=N` | Donne N exemplaires d'un objet |
| `-item` | `-item:ID=N` | Retire N exemplaires d'un objet |
| `flag` | `flag:NOM` | Définit un flag local au PNJ actuel |
| `gflag` | `gflag:NOM` | Définit un flag d'histoire global et persistant |
| `questf` | `questf:ETAT` | Fait avancer la quête principale vers cet état |
| `prof` | `prof:ID` | Débloque et équipe une classe |
| `combat` | `combat:enemy_id[:niveau]` | Déclenche un combat |
| `cine` | `cine:ID` | Joue la scène comme cinématique |

---

## 3. Syntaxe des CONDITIONS (`condition`)

Expressions booléennes évaluées dynamiquement :
- `has_flag("X")` / `no_flag("X")` : Flag local au PNJ.
- `gflag("X")` / `has_gflag("X")` : Flag global de progression.
- `has_item("id"[, qte])` : Possession d'un objet dans l'inventaire.
- `gold >= 100` : Vérification du montant d'or.
- `has_prof("guerrier")` : Vérifie si une classe est débloquée.
- `quest == "dam_opened"` : État de la quête principale.
