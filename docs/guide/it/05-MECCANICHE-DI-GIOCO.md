# 05 — Meccaniche di Gioco (I 4 Pilastri)

---

## 1. 🗺️ Mappa del Mondo 3D Top-Down
- Movimento su griglia con nebbia di guerra ed effetti meteo dinamici.
- **Raccolta Risorse**: Attrezzi specifici per tipo di nodo (Ascia per il legname, Piccone per minerali e pietre, Canna da pesca, Vanga per tesori sepolti).
- **Accampamento**: Tenda per riposare e far avanzare il tempo; falò per cucinare cibi con potenziamenti temporanei.
- **Trasformazioni Dinamiche**: Cambiamenti di terreno in tempo reale collegati all'avanzamento della trama (`world_transforms.json`).

---

## 2. 🏰 Dungeon in Prima Persona
- Esplorazione a caselle 3D con minimappa in tempo reale e nemici con sprite 2D billboarded.
- **6 Abilità di Esplorazione**: Onda Cinetica (interruttori e barriere), Presa Psichica (anelli e pilastri), Vista del Cacciatore (passaggi segreti), Affinità Elementale (torce e ghiaccio), Purificazione (miasma velenoso), Alterazione Temporale (piattaforme mobili).

---

## 3. ⚔️ Combattimento Tattico a Turni
- Layout JRPG laterale classico: gruppo a sinistra, mostri a destra.
- **Barra ATB e Punti Azione (PA)**: Accoda più attacchi o incantesimi nello stesso turno.
- **Sinergie**: Abilità consecutive nella coda possono fondersi in attacchi combinati devastanti.
- **Difesa Attiva QTE**: Cerchio temporale per ridurre i danni subiti o eseguire una Parata Perfetta.

---

## 4. 📖 Narrativa & Visual Novel
- Sfondi panoramici in 16:9 (`assets/vn/bg/`) con ritratti dei personaggi.
- **5 Sfaccettature del Protagonista** (`coraggio`, `bontà`, `fascino`, `intelletto`, `lucidità`) per sbloccare scelte di dialogo esclusive.
- Grafo di scelte multilingue (7 lingue) memorizzato in `data/npcs/<id>.json`.
