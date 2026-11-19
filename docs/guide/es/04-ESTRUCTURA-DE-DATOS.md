# 04 — Estructura de Datos (`data/`)

Todo el contenido del juego vive en `data/` como JSON plano. Hay dos patrones de
persistencia (ver también `editor/js/collections.js`):

- **`kind: 'doc'`** — un único fichero JSON con un diccionario/objeto dentro
  (`data/professions.json`, `data/config.json`, `data/quests.json`...).
- **`kind: 'perId'`** — una carpeta con **un fichero por elemento**
  (`data/enemies/<id>.json`, `data/npcs/<id>.json`, `data/dungeons/<id>.json`...). Se
  usa para catálogos que crecen mucho y conviene tener localizables/versionables por
  separado en git.

## 1. Mapa completo de `data/`

| Fichero/carpeta | Tipo | Qué contiene |
|---|---|---|
| `world.json` / `world_test.json` | doc | Mapamundi real y de pruebas (rejilla de baldosas) |
| `world_transforms.json` | doc | Reglas de transformación dinámica del mapa por flags de historia |
| `world_buildings_classic.json` | doc (extra, sin pestaña) | Overrides visuales de las maquetas procedurales clásicas |
| `world_terrains/` | perId | Un fichero por código de terreno (`grs.json`, `ice.json`...) |
| `world_resources/` | perId | Un fichero por nodo recolectable (`forest.json`, `rock.json`, `fish.json`...) |
| `world_buildings/` | perId | Un fichero por maqueta de edificio colocable |
| `ids/` | perId | Ciudades, POIs, entradas de mazmorra, cofres de mapa... (todo lo "colocable" genérico) |
| `dungeons/` | perId | Una mazmorra completa por fichero (plantas + rejillas + eventos) |
| `dungeon_tiles/` | perId | Tipos de casilla de mazmorra (fijos + cosméticos) — ver `dungeon_kits.json` |
| `dungeon_kits.json` | doc | Kits/piezas de "Objeto Inteligente" data-driven para mazmorras |
| `npcs/` | perId | Un grafo de diálogo por NPC/POI |
| `enemies/` | perId | Un fichero por enemigo (stats, botín, IA, habilidades) |
| `enemy_skills.json` | doc | Habilidades exclusivas de enemigos |
| `items/` | perId | Un fichero por ítem (consumible/equipo/material) |
| `professions.json` | doc **(requerido)** | Clases jugables y sus habilidades por nivel |
| `skills.json` | doc **(requerido)** | Catálogo de habilidades de combate del jugador |
| `synergies.json` | doc | Combos de habilidades |
| `shops.json` | doc | Catálogos de stock de tienda |
| `events.json` | doc | Disparadores `condition` + `actions` (el "pegamento" de la historia) |
| `quests.json` | doc | Orden de estados de la questline principal + victorias de combate que avanzan la historia |
| `quests_secondary/` | perId (vacío por defecto) | Misiones secundarias independientes de la principal |
| `dialogues.json` | doc | Diálogos legados sueltos (avisos/toasts) |
| `scenes/` | perId | Grafos del Sistema Narrativo unificado (conversaciones, cinemáticas y reemplazo progresivo de diálogos) |
| `achievements.json` | doc | Logros (condición + recompensa) |
| `tutorials.json` | doc | Mensajes de ayuda contextual |
| `ambience.json` | doc | Música/clima por terreno |
| `config.json` | doc | **Todo el balance numérico del juego** |
| `codex.json` | doc | Códice de curiosidades/lore descubrible |
| `orb_barks.json` | doc | Frases contextuales del compañero "Orbe" |
| `templates/` | — | Plantillas usadas por asistentes del editor |

## 2. Convenciones de `id`

- Minúsculas, `snake_case`, sin espacios ni tildes (`orco_berserker`, `dun_yelmo`,
  `city_sylphrena`). El `id` es el nombre de fichero (colecciones `perId`) o la clave
  del diccionario (colecciones `doc`).
- Prefijos habituales por convención (no obligatorios, pero ayudan a leer el proyecto):
  `dun_` para mazmorras, `city_` para ciudades, `poi_` para puntos de interés.
- Los `id` son referenciados por STRING desde muchos otros ficheros (un evento referencia
  un `item_id`, una mazmorra referencia un `enemy_id`...). **No hay claves foráneas
  reales**: si renombras un id, el validador (`tools/validate_data.py` / panel QA del
  editor) es quien detecta las referencias que quedaron rotas.

## 3. Campos multilingües (Soporte Nativo para 7 Idiomas)

Todo texto visible al jugador se almacena como un diccionario multilingüe con las 7 claves oficiales del proyecto:
- `es` (Español)
- `en` (Inglés)
- `fr` (Francés)
- `it` (Italiano)
- `de` (Alemán)
- `zh` (Chino Simplificado)
- `ja` (Japonés)

Ejemplo en un nodo de NPC, ítem o entidad:
```json
"text": {
    "es": "¡Bienvenido a la taberna!",
    "en": "Welcome to the tavern!",
    "fr": "Bienvenue à la taverne !",
    "it": "Benvenuto alla taverna!",
    "de": "Willkommen in der Taverne!",
    "zh": "欢迎来到酒馆！",
    "ja": "酒場へようこそ！"
}
```

El motor (`Locale.gd`) resuelve el idioma activo en runtime al instante y de forma reactiva (cambiar el idioma en el menú de opciones actualiza los textos inmediatamente sin reiniciar la escena).

**Estrategia de adaptación para tu propio juego:**
- **Si vas a publicar a nivel internacional**: Mantén las 7 claves o las que decidas traducir para tu lanzamiento comercial.
- **Si tu juego solo tendrá un idioma (p. ej. solo español o solo inglés)**: Puedes rellenar únicamente tu idioma clave o duplicar el texto; el motor aplica un fallback seguro: si falta una clave, toma `es` o el primer valor disponible en el objeto, sin provocar errores en runtime.

## 4. El mini-lenguaje de RECOMPENSAS (`reward`)

Usado en `npcs/*.json` (nodos de diálogo), `events.json` (`actions`), `achievements.json`
y `data/scenes/*` (nodos `state`). Es una cadena de **tokens separados por `;`**, cada
uno `clave:valor` (o `clave=valor`), evaluados en orden estricto por
`Design.apply_reward()` / `Design._apply_token()` en Godot. Ejemplo real:

```
"gold:-50;faceta:amabilidad=+1;flag:donated_orphans"
"item:diario=1;questf:item_found;dialogue:diary_found"
```

Catálogo completo de tokens soportados (fuente: `Design.gd` → `_apply_token`,
sincronizado con `editor/js/store.js` → `REWARD_TOKENS`):

| Token | Formato | Efecto |
|---|---|---|
| `gold` | `gold:±N` | Suma/resta oro |
| `xp` | `xp:N` | Da experiencia de personaje |
| `heal` | `heal` (sin valor) | Cura HP/MP al máximo |
| `damage` | `damage:N` o `damage:N%` | Inflige daño fuera de combate (plano o % del HP máx; nunca mata, mínimo deja en 1 HP) |
| `faceta` | `faceta:CLAVE=±N` | Modifica una faceta de personalidad (`valor/bondad/aspecto/inteligencia/cordura`, con alias legados `valentia/amabilidad/encanto/astucia`) |
| `item` | `item:ID=N` | Da N unidades de un ítem |
| `-item` | `-item:ID=N` | Quita N unidades de un ítem |
| `flag` | `flag:NOMBRE` | Marca un flag **local al NPC** |
| `relation` | `relation:±N` o `relation:NPC_ID=±N` | Modifica la afinidad con el NPC actual o uno concreto |
| `questf` | `questf:ESTADO` | Avanza la questline principal HACIA ADELANTE hasta ese estado (según `quests.json` → `order`) |
| `quests` | `quests:ESTADO` | Fija el estado de la questline directamente (sin comprobar orden) |
| `quest_start` | `quest_start:ID[:STAGE]` | Inicia una misión secundaria del Sistema Multi-Quest en la fase indicada |
| `quest_stage` | `quest_stage:ID=STAGE` | Actualiza la fase de una misión secundaria |
| `quest_complete` | `quest_complete:ID` | Marca como completada una misión secundaria |
| `quest_fail` | `quest_fail:ID` | Marca como fallida una misión secundaria |
| `prof` | `prof:ID` | Desbloquea y equipa una profesión |
| `dam` | `dam` (sin valor) | Abre la presa (evento especial del prólogo) |
| `boat_spawn` | `boat_spawn` o `spawn_boat` | Hace aparecer el barco en el puerto de Celestia |
| `boat_pos` | `boat_pos:X,Y` | Coloca y desbloquea el barco en una coordenada del mapamundi |
| `discover` | `discover:CODEX_ID` | Desbloquea una entrada de lore en el Códice de Curiosidades |
| `bark` | `bark:BARK_ID` | Fuerza una frase contextual inmediata del compañero Orbe |
| `music` | `music:TRACK_ID` | Cambia la música de fondo ambiental al vuelo desde un diálogo |
| `qaction` | `qaction:ACCION` | Dispara una acción de misión secundaria |
| `gflag` | `gflag:NOMBRE` (o `gflag:NOMBRE=0` para desactivar) | Flag **global** de historia (persiste entre NPCs/escenas) |
| `worldt` | `worldt:ID` | Dispara una transformación de `world_transforms.json` |
| `combat` | `combat:enemy_id[:nivel[:boss]]` | Lanza un combate |
| `event` | `event:ID` | Ejecuta otro evento de `events.json` |
| `emit` | `emit:EVENT_NAME[=k=v,k2=v2]` | Emite un evento arbitrario al bus global `GlobalEvents` con payload |
| `dialogue` | `dialogue:ID` | Muestra un diálogo (o la escena del Sistema Narrativo con el mismo id, si existe) |
| `cine` | `cine:ID` | Reproduce la escena (`data/scenes/<ID>.json`) con ese id como cinemática |

> El botín (`loot`) de enemigos/cofres **NO** usa este mini-lenguaje: es una lista
> estructurada de entradas `{ kind, id?, chance?, min?, max?, qty?, level? }` con
> `kind` ∈ `gold`/`item`/`consumable`/`resource`/`equipment`. Cada entrada tira su
> `chance` de forma **independiente** (no es un pool acumulado). Se define inline en
> cada `enemies/<id>.json` (campo `loot`) o en los `items` de un cofre en una mazmorra.

## 5. El mini-lenguaje de CONDICIONES (`condition`)

Usado en nodos `option` de NPCs, en `events.json` y en logros. Es una **expresión Godot
`Expression`** evaluada en runtime por `Design.eval_condition()`. El editor ofrece un
constructor visual (`ConditionEditor.js`) con este catálogo (`CONDITION_TOKENS` en
`store.js` y funciones de `Design.gd`):

| Función/variable | Uso |
|---|---|
| `has_flag("X")` / `no_flag("X")` | Flag local del NPC actual |
| `gflag("X")` / `has_gflag("X")` / `no_gflag("X")` | Flag global de historia |
| `has_item("id"[, qty])` / `no_item("id"[, qty])` | Comprueba posesión de un ítem (con cantidad opcional) |
| `has_quest("id")` / `quest_done("id")` | Misión secundaria iniciada y activa / completada |
| `quest_stage("id") == N` | Fase numérica de una misión secundaria (-999 si no iniciada) |
| `has_prof("prof_id")` / `no_prof("prof_id")` | Comprueba si el jugador tiene una profesión desbloqueada |
| `has_all_professions()` | Verdadero si ha desbloqueado las 6 profesiones de maestría |
| `defeated("dun:boss")` | Comprueba si un jefe de mazmorra ha sido derrotado |
| `discovered("codex_id")` / `not_discovered("codex_id")` | Si una entrada de lore del códice fue descubierta |
| `gate_flag("key")` | Comprueba banderas de paso/gating en el mapamundi |
| `hunt_count("quest_id") >= N` | Progreso numérico de monstruos eliminados en misiones de caza |
| `stat("kills"/"level"/"xp"/"gold"/"job_level") >= N` | Estadística agregada del jugador |
| `quest == "estado"` | Estado actual de la questline PRINCIPAL (string) |
| `rel("npc_id") >= N` | Afinidad con un NPC específico por id |
| `relation >= N` | Afinidad con el NPC actual (variable de contexto) |
| `visits_of("npc_id") >= N` | Visitas a un NPC específico por id |
| `visits >= N` | Nº de veces que se ha hablado con el NPC actual (variable de contexto) |
| `gold >= N` | Oro actual del jugador (variable de contexto) |
| `valor/bondad/aspecto/inteligencia/cordura >= N` | Facetas de personalidad (variables directas) |

Se pueden combinar con `and`/`or`/`not` como cualquier expresión booleana normal:
`(has_flag("boss_puerto_activo") or has_gflag("boss_puerto_activo")) and no_flag("boss_puerto_derrotado")`.

## 6. `data/quests.json` — la línea temporal principal

```jsonc
{
  "order": ["not_started", "knows_dam", "...", "game_completed"],
  "descriptions": {
    "not_started": { "title": {"es": "...", "en": "..."}, "hint": {"es": "...", "en": "..."} }
  },
  "combat_victory": {
    "jefe_puerto": { "event": "defeat_harbor_boss" }
  }
}
```

- `order` es la única fuente de verdad del **orden** de la historia principal. `questf:`
  nunca retrocede: si el jugador se salta pasos, el motor sincroniza automáticamente las
  transformaciones de mundo de los hitos intermedios saltados.
- `combat_victory` dispara un evento de `events.json` automáticamente al vencer a un
  enemigo concreto — así conectas "matar al jefe X" con "avanza la historia" sin tocar
  GDScript.

## 7. `data/config.json` — balance numérico completo

Organizado por bloques temáticos (ver también la pestaña **Config** del editor):

| Bloque | Ejemplos de claves |
|---|---|
| Progresión de personaje | `MAX_CHAR_LEVEL`, `XP_CHAR_BASE`, `XP_CHAR_EXPONENT`, `STAT_POINTS_PER_LEVEL` |
| Progresión de profesión | `MAX_JOB_LEVEL`, `XP_JOB_BASE`, `XP_JOB_EXPONENT` |
| Vida/maná | `HP_BASE`, `HP_PER_VIT`, `MP_BASE`, `MP_PER_INT` |
| Daño/defensa por atributo | `PHYS_DMG_FROM_STR`, `MAG_DMG_FROM_INT`, `PDEF_FROM_VIT`... |
| Esquiva/crítico/precisión | `DODGE_BASE`, `CRIT_MULTIPLIER`, `ACCURACY_MAX`... |
| Recolección/energía | `GATHER_XP_PER_TAP`, `GATHER_NODE_CAPACITY`, `MAX_ENERGY` |
| Día/noche | `DAY_DURATION_SEC`, `NIGHT_START_HOUR` |
| Combate (ATB/PA/Resonancia) | `COMBAT_TURN_INTERVAL`, `PA_LIMIT_NORMAL`, `RESONANCE_MAX` |
| Mazmorras | `DUNGEON_TICK_INTERVAL`, `DUNGEON_AMBUSH_CHANCE` |
| Elementos | `ELEMENT_WEAK_MULT`, `ELEMENT_RESIST_MULT` |
| Economía | `REFORGE_COST_GOLD`, `BUILDING_UPGRADE_GOLD_BASE` |
| Progreso offline | `OFFLINE_MAX_SECONDS`, `OFFLINE_GATHER_CAP_PER_RES` |
| Accesibilidad | `UI_FONT_SCALE_MIN/MAX/DEFAULT`, `COLORBLIND_DEFAULT` |

Todas estas constantes se leen con **fallback seguro**: si borras una clave, el juego no
se rompe, usa el valor cableado por defecto en `scripts/config/` (`GameConfig.gd`). Esto
te permite tocar solo lo que te interesa balancear.

## 8. Siguiente paso

Para entender CÓMO se usan estos datos dentro del motor (combate, mazmorras, mundo,
narrativa), continúa con `05-MECANICAS-DE-JUEGO.md`.
