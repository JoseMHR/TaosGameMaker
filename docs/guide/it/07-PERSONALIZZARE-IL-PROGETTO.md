# 07 — Personalizzare il Progetto (Tabella di Marcia)

## Fase 0 — Modello di Distribuzione e Ambito

### Modelli Commerciali
- **Come Template Premium / Motore JRPG per altri sviluppatori (Godot Asset Store, GitHub...)**:
  Distribuisci l'intero repository comprendente Godot 4 e la cartella `editor/`. Chi acquista riceve un motore JRPG testato e un editor No-Code per creare il proprio gioco. Questa guida (in 7 lingue) funge da manuale d'uso.
- **Come Videogioco Commerciale Indipendente (Steam, Nintendo Switch, Google Play, iOS)**:
  Sostituisci il contenuto di `data/` e gli asset grafici/audio di `assets/`. Esportando da Godot (`export_presets.cfg`), gli strumenti di sviluppo (`editor/`, `tools/`, `docs/`) vengono **automaticamente esclusi** dalla build finale.

---

## Fase 1 — Rebranding

1. **Nome del Gioco**: In `project.godot`, modifica `[application] config/name="TuoGioco"`.
2. **Icona**: Sostituisci `icon.png` nella cartella radice.
3. **Schermata d'Avvio**: Sostituisci `assets/common/boot_splash.png`.
4. **Crediti**: Aggiorna `Credits.txt` con il tuo team e le licenze di terze parti conservate.
5. **Lingue**: Imposta la lingua predefinita in `scripts/autoload/Locale.gd` (`var current_locale = "it"`).

---

## Fasi 2 - 8 — Creazione di Contenuti

1. **Trama**: Definisci gli stati della storia principale in `data/quests.json`.
2. **Classi e Abilità**: Crea le professioni nella scheda *Classi* e gli incantesimi nella scheda *Abilità*.
3. **Bestiario**: Crea i mostri nella scheda *Nemici* e testali nel **Combat Sandbox**.
4. **Mappa del Mondo**: Disegna il mondo nella scheda *Mappa* e imposta le città.
5. **Dungeon**: Costruisci i dungeon e verifica i percorsi con il modal *Walkthrough*.
6. **PNG e Dialoghi**: Scrivi i dialoghi e testali con il simulatore di Visual Novel.

---

## Fase 9 — Verifica Finale

- [ ] Esegui `python tools/validate_data.py` senza alcun errore.
- [ ] Rigenera le mappe del codice (`python tools/gen_codemap.py`, `python tools/gen_editor_codemap.py`).
- [ ] Collauda una partita completa dall'inizio alla fine in Godot.
