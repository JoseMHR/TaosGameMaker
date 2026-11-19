# ⚔️ JRPG Complete Template & Engine — Guida per l'Utente

> **Benvenuto nel modello e motore JRPG professionale per Godot 4.**  
> Questo progetto combina un gioco completo (mappa del mondo 3D dall'alto, dungeon crawler in prima persona, combattimento a turni e narrativa in stile visual novel) con un **Editor Web Visuale dedicato** che ti consente di creare, modificare e bilanciare il tuo intero gioco senza toccare una sola riga di codice.

---

## ⚡ Avvio Rapido (In meno di 3 minuti)

Nessuna configurazione di database o compilazione complessa richiesta:

### 1. Prerequisiti
- **Godot Engine 4.3+** (Standard o .NET).
- **Python 3.8+** (Preinstallato su macOS/Linux; disponibile su [python.org](https://www.python.org/) per Windows).

### 2. Aprire ed Eseguire in Godot
1. Apri **Godot Engine** e clicca su **Importa**.
2. Seleziona il file `project.godot` in questa cartella.
3. Clicca su **Esegui progetto** (o premi `F5`). Sei nel menu principale!
   - Per testare tutti i contenuti all'istante, seleziona **Modalità Debug / Stanza di Test** nel menu.

### 3. Avviare l'Editor Web dei Contenuti
L'editor è un'applicazione web locale che non richiede `npm` né passaggi di build:
1. Apri un terminale nella cartella principale del progetto.
2. Esegui:
   ```bash
   python editor/serve.py
   ```
3. Apri il browser all'indirizzo:
   👉 **[http://localhost:8000](http://localhost:8000)**

Ogni modifica salvata nell'editor web (nemici, mappe, dialoghi) **si riflette immediatamente in Godot senza riavviare il motore**.

---

## 🎮 Cosa include questo template?

### 🗺️ 4 Pilastri di Gioco Completamente Integrati
1. **Mappa del Mondo 3D Top-Down**: Sistema a griglia, nebbia di guerra, biomi, pericoli climatici, trasformazioni persistenti del mondo (alberi da tagliare, rocce da spaccare, accampamenti costruibili) e nave navigabile.
2. **Dungeon Crawler in Prima Persona**: Dungeon 3D passo-passo con minimappa dinamica, porte con chiave, trappole, forzieri e battaglie contro i boss.
3. **Combattimento Tattico a Turni**: Sistema JRPG a turni con calcolo elementale, stati alterati, barra ATB, code di Punti Azione (PA), sinergie di classe e regia dinamica della telecamera.
4. **Narrativa e Visual Novel**: Dialoghi a bivi con alberi decisionali, ritratti espressivi, musica d'ambiente reattiva, missioni e flag globali persistenti.

### 🛠️ Editor Web Visuale "No-Code"
Una suite completa di game design nel browser:
- **Editor Mappa 3D**: Dipingi terreni, posiziona città, dungeon, risorse e forzieri con un clic.
- **Level Designer per Dungeon**: Progetta livelli su griglia 3D con anteprima delle texture e simulazione del percorso (*DungeonWalkthroughModal*).
- **Creatore di Nemici e Abilità**: Regola statistiche, IA, bottini e collauda ogni battaglia in tempo reale nel **Combat Sandbox** integrato.
- **Editor di Dialoghi e Missioni**: Crea grafi di conversazione visivi (*NpcGraphEditor*) e testali con il simulatore di Visual Novel (*VnSimulator*).
- **Alberi dei Talenti, Classi e Sinergie**: Bilancia la progressione dei personaggi.
- **Assistenti Rapidi (Wizards)**: Genera scheletri completi di dungeon, quest, oggetti e POI in un solo clic.
- **Supporto Multilingue Nativo (7 lingue)**: Italiano, inglese, spagnolo, francese, tedesco, cinese e giapponese integrati di fabbrica.

### 🧪 Stanza di Test & Debug
- Include `data/world_test.json`, un mondo modulare diviso in 8 padiglioni tematici che espone il **100% di POI (162), città (4), dungeon (13) e nemici (41)**.

---

## 📚 Indice della Guida

| Capitolo | Titolo | Descrizione |
|---|---|---|
| **01** | [**Panoramica e Architettura**](01-PANORAMICA-E-ARCHITETTURA.md) | Architettura di sistema, stack tecnico e filosofia data-driven. |
| **02** | [**Primi Passi**](02-PRIMI-PASSI.md) | Configurazione iniziale, server locale e flusso di lavoro quotidiano. |
| **03** | [**Editor Web: Guida Completa**](03-EDITOR-WEB-GUIDA-COMPLETA.md) | Manuale completo di tutte le schede, finestre e assistenti. |
| **04** | [**Struttura dei Dati (JSON)**](04-STRUTTURA-DEI-DATI.md) | Dizionario dei dati, sintassi delle condizioni e mini-linguaggio delle ricompense. |
| **05** | [**Meccaniche di Gioco**](05-MECCANICHE-DI-GIOCO.md) | Funzionamento dettagliato dei 4 pilastri di gameplay. |
| **06** | [**Arte, Audio e Asset**](06-ARTE-AUDIO-E-ASSET.md) | Risoluzioni standard, pipeline 3D, scontorno sprite e stili UI. |
| **07** | [**Personalizzare il Progetto**](07-PERSONALIZZARE-IL-PROGETTO.md) | **Tabella di marcia** per creare il tuo gioco commerciale o vendere questo template. |
| **08** | [**Strumenti CLI e Validazione**](08-STRUMENTI-CLI-E-VALIDAZIONE.md) | Script automatici in `tools/` per verificare l'integrità dei dati. |
| **09** | [**FAQ e Risoluzione Problemi**](09-FAQ-RISOLUZIONE-PROBLEMI.md) | Risposte dirette alle domande più frequenti. |
