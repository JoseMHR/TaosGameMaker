# 09 — FAQ e Risoluzione Problemi

## Generale & Editor

**È necessario conoscere GDScript per usare questo template?**  
No. Oltre il 90% della creazione di contenuti (storia, mappe, dungeon, nemici, oggetti) viene gestito nell'Editor Web. GDScript è richiesto solo se desideri aggiungere meccaniche inedite.

**L'editor richiede Node.js o npm?**  
No. L'editor è ospitato direttamente da Python (`serve.py`) e carica Vue 3 via CDN.

**Ho salvato una modifica nell'editor ma non compare nel gioco.**  
Godot carica i dati JSON all'avvio. Riavvia la sessione di gioco (▶️) o richiama `Design.reload()`.

**Perché alcuni POI non mostrano uno sprite di personaggio al centro dello schermo?**  
In questo template, molte illustrazioni 16:9 (`assets/vn/bg/`) integrano già il personaggio nell'ambientazione. Se non è associato alcuno sprite `npc_<id>.png` ritagliato, il motore (`ViewPlace.gd`) mostra lo sfondo panoramico pulito insieme all'avatar emoji, senza sovrapporre sprite ridondanti.

---

## Dati & Multilingue

**Come funziona il sistema multilingue?**  
I testi contengono le 7 chiavi di lingua (`it`, `en`, `es`, `fr`, `de`, `zh`, `ja`). Se pubblichi il gioco solo in italiano, puoi compilare unicamente quella chiave; il motore applica automaticamente un fallback sicuro.

**Dove vengono salvate le partite del giocatore?**  
Nella cartella utente (`user://save_slot_*.json`), gestita da `SaveManager.gd`, completamente separata dai file di progetto in `data/`.
