# 03 — Editor Web : Guida Completa

La configurazione di tutte le schede è definita in `editor/js/collections.js`.

---

## 🗺️ Schede Mondo

- **Mappa (`map` → `MapEditor.js`)**: Editor per la mappa 3D del mondo (`data/world.json`). Disegna terreni, posiziona insediamenti, dungeon e forzieri.
- **Area Città (`cityWorkspace` → `CityWorkspace.js`)**: Ambiente dedicato per gestire città, edifici, negozi e PNG collegati in una sola vista.
- **Entità (`ids` → `IdsManager.js`)**: Punti di interesse (POI) e dungeon con testi multilingue in 7 lingue (*POI Wizard* incluso).
- **Dungeon (`dungeons` → `DungeonEditor.js`)**: Progettazione di dungeon multi-livello su griglia 3D con simulatore di percorso (*DungeonWalkthroughModal*) e assistente di generazione (*DungeonWizardModal*).
- **Pezzi di Dungeon (`dungeonPieces` → `DungeonPiecesManager.js`)**: Gestione di tessere fisse 🔒, cosmetiche 🎨 e Oggetti Intelligenti 🧩 (*Smart Objects*).

---

## 💬 Personaggi & Nemici

- **PNG (`npcs` → `NpcEditor.js`)**: Grafi di dialogo in `data/npcs/<id>.json`. Include editor visuale a nodi (`NpcGraphEditor.js`), simulatore di Visual Novel (`VnSimulatorModal.js`) e supporto per avatar emoji.
- **Nemici (`enemies` → `EnemiesManager.js`)**: Statistiche di base, intelligenza artificiale, debolezze elementali e tabelle di bottino.
  > ⚔️ **Combat Sandbox**: Simula battaglie in tempo reale all'interno del browser (`CombatSandboxModal.js`) per collaudare statistiche e abilità senza avviare Godot.

---

## 🎒 Oggetti, Classi & Bilanciamento

- **Oggetti (`items` → `ItemsManager.js`)**: Armi, armature e consumabili con l'assistente rapido *Item Wizard*.
- **Classi (`professions` → `ProfessionsManager.js`)**: Gestione delle professioni giocabili e sblocco abilità per livello.
- **Abilità (`skills` → `SkillsManager.js`)**: Catalogo degli incantesimi e attacchi dei personaggi.
- **Configurazione (`config` → `ConfigManager.js`)**: **Pannello di bilanciamento completo** (curve di esperienza, formule di danno, velocità turni ATB, economia).
