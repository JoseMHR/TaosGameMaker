# 01 — Panoramica e Architettura

## 1. Cos'è esattamente questo template

È un **JRPG completo e giocabile** ("Taos Game Maker" in `project.godot`) corredato da un **editor visuale di contenuti su misura**. Non è una scatola vuota: è un gioco interamente funzionante strutturato per permetterti di riutilizzare l'**80-90% del motore** (combattimento, dungeon, dialoghi, salvataggio, inventario) sostituendo il **contenuto creativo** (trama, nemici, mappa, grafica e audio) con il tuo.

I 4 pilastri di gameplay autonomi + 1 base di sistemi globali:
- 🗺️ **Mondo**: Mappa 3D dall'alto, raccolta risorse, campeggio, navigazione navale (`TabWorld3D.gd`).
- 🏰 **Dungeon**: Esplorazione a griglia in prima persona, enigmi con 6 abilità (`ViewDungeon.gd`).
- ⚔️ **Combattimento**: JRPG a turni ATB con coda di Punti Azione e sinergie (`ViewCombat.gd`).
- 📖 **Narrativa**: Visual novel, grafi di dialogo, città, PNG e missioni (`ViewPlace.gd`).
- ⚙️ **Sistemi globali**: Economia, botteghe, trofei, bilanciamento (Autoloads).

---

## 2. Stack Tecnologico

- **Motore di Gioco**: Godot 4.3+, GDScript, rendering mobile, fisica 3D nativa.
- **Piattaforme Cibo**: Desktop (Windows, macOS, Linux) e Mobile (Android, iOS).
- **Editor Web**: Vue 3 (via CDN, senza passaggi di build npm).
- **Server Locale**: Python 3 standard (`editor/serve.py`).
- **Persistenza**: File JSON semplici in `data/`.

---

## 3. Autoload di Godot (Singletons Globali)

- `Locale` (`scripts/autoload/Locale.gd`): Supporto per 7 lingue (IT, EN, ES, FR, DE, ZH, JA), accessibilità e daltonismo.
- `Design` (`scripts/autoload/Design.gd`): Caricamento, caching e consultazione di tutti i file JSON in `data/`.
- `ExplorationSkills` (`scripts/autoload/ExplorationSkills.gd`): Logica delle 6 abilità di dungeon.
- `GlobalState` (`scripts/autoload/GlobalState.gd`): Statistiche del giocatore, oro, inventario, equipaggiamento e flag.
- `GlobalEvents` (`scripts/autoload/GlobalEvents.gd`): Bus di eventi disaccoppiato.
- `SaveManager` (`scripts/autoload/SaveManager.gd`): Serializzazione dei salvataggi su disco.
- `QuestManager` (`scripts/autoload/QuestManager.gd`): Avanzamento della trama e trigger cinematici.
