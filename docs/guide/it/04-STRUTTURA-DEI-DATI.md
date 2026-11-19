# 04 — Struttura dei Dati (`data/`)

Tutti i dati risiedono nella cartella `data/` in formato JSON:

- **`kind: 'doc'`**: Un singolo file JSON contenente un dizionario (`professions.json`, `config.json`, `quests.json`).
- **`kind: 'perId'`**: Una cartella contenente **un file JSON per ogni elemento** (`enemies/<id>.json`, `npcs/<id>.json`, `dungeons/<id>.json`).

---

## 1. Campi Multilingue (Supporto Nativo per 7 Lingue)

Tutti i testi mostrati al giocatore sono memorizzati con le 7 chiavi di lingua ufficiali:
- `it` (Italiano)
- `en` (Inglese)
- `es` (Spagnolo)
- `fr` (Francese)
- `de` (Tedesco)
- `zh` (Cinese Semplificato)
- `ja` (Giapponese)

Esempio:
```json
"text": {
    "it": "Benvenuto alla taverna!",
    "en": "Welcome to the tavern!",
    "es": "¡Bienvenido a la taberna!",
    "fr": "Bienvenue à la taverne !",
    "de": "Willkommen in der Taverne!",
    "zh": "欢迎来到酒馆！",
    "ja": "酒場へようこそ！"
}
```

---

## 2. Il Mini-Linguaggio delle RICOMPENSE (`reward`)

Stringhe di token separati da punto e virgola `;` valutati in sequenza:

| Token | Sintassi | Effetto |
|---|---|---|
| `gold` | `gold:±N` | Aggiunge o sottrae oro |
| `xp` | `xp:N` | Assegna punti esperienza al personaggio |
| `heal` | `heal` | Ripristina interamente PV e PM del gruppo |
| `damage` | `damage:N` | Infligge danni fuori dal combattimento (lascia a 1 PV minimo) |
| `item` | `item:ID=N` | Aggiunge N copie di un oggetto all'inventario |
| `-item` | `-item:ID=N` | Rimuove N copie di un oggetto dall'inventario |
| `flag` | `flag:NOME` | Imposta un flag locale per il PNG corrente |
| `gflag` | `gflag:NOME` | Imposta un flag globale permanente di trama |
| `questf` | `questf:STATO` | Fa avanzare la missione principale a tale stato |
| `prof` | `prof:ID` | Sblocca ed equipaggia una classe |
| `combat` | `combat:enemy_id[:livello]` | Avvia un combattimento |
| `cine` | `cine:ID` | Esegue la scena indicata come filmato |

---

## 3. Sintassi delle CONDIZIONI (`condition`)

Espressioni logiche valutate a runtime:
- `has_flag("X")` / `no_flag("X")`: Controllo flag locale.
- `gflag("X")` / `has_gflag("X")`: Controllo flag globale.
- `has_item("id"[, qta])`: Presenza di un oggetto nell'inventario.
- `gold >= 100`: Verifica del denaro posseduto.
- `quest == "dam_opened"`: Stato della missione principale.
