# 03 — Guía Completa del Editor Web

Fuente única de la lista de pestañas: `editor/js/collections.js` (constante `TABS`).
Cada fila de ahí define: pestaña, icono, grupo de navegación, componente Vue que la
renderiza (`editor/js/components/<Componente>.js`) y cómo persiste (`kind: 'doc'` = un
único JSON en `data/`, `kind: 'perId'` = una carpeta con un fichero por elemento en
`data/<coleccion>/`, sin `kind` = pantalla sin persistencia propia que solo lee otras
colecciones).

> Si añades una pestaña nueva para tu propio contenido, **todo se declara en un único
> sitio** (`collections.js`); no repartas la lógica de navegación a mano. El propio
> fichero documenta el procedimiento paso a paso en su cabecera.

## Grupo 🗺️ Mundo

### Mapa (`map` → `MapEditor.js`)
El editor del mapamundi 3D top-down (`data/world.json`, y `data/world_test.json` como
mapa de pruebas alternativo). Pinta terrenos por baldosa, coloca ciudades/POIs/mazmorras/
recursos recolectables y cofres de botín directo (`gold` + lista de ítems con cantidad)
sobre el grid. Incluye herramientas de mover elementos (cortar/pegar casilla), previsualización
de qué icono, NPC o fondo cargará cada punto de interés, capas visuales y un inspector
exhaustivo de la casilla seleccionada. Es el componente más grande del editor (más de
2000 líneas).

### Ciudades (`cityWorkspace` → `CityWorkspace.js`)
**Workspace por tarea**: reúne en una sola pantalla todo lo relacionado con una
ciudad/aldea concreta — sus datos (nombre, icono, descripción), su ubicación en el mapa
(con salto directo al Mapa) y sus edificios/POIs (taberna, tienda, casas...) como
tarjetas, con acceso directo a editar/crear/reordenar el NPC y la tienda vinculados a
cada uno. Edita `data/ids/<ciudad>.json` (mismo formato que "Entidades"), pensado para
no tener que saltar entre pestañas sueltas al construir una ciudad completa.

### Entidades (`ids` → `IdsManager.js`)
Colección genérica `data/ids/*.json`: aquí viven **ciudades, POIs, mazmorras-entrada,
cofres de mapa y cualquier "cosa" colocable sobre el mapamundi** que no encaja en una
colección más específica. Cada entidad tiene `type` (`city`, `poi`, ...), nombre/desc
multilingüe (7 idiomas), icono, y para POIs con NPC: el `npc` vinculado, fondo de escena (`bg`) y
`content` (lista de sub-POIs si es una ciudad). Incluye un asistente ("Wizard") para
crear de un tirón un POI + su NPC (`NpcPoiWizardModal.js`).

### Mazmorras (`dungeons` → `DungeonEditor.js`)
El editor más grande del proyecto (~2400 líneas). Cada mazmorra es un fichero en
`data/dungeons/<id>.json` con una o más plantas, cada una una rejilla de celdas. Permite
pintar tipos de casilla, colocar enemigos/jefes/cofres, portales/teletransportes,
interruptores con `targets`, y previsualizar el resultado con un modal de recorrido
(`DungeonWalkthroughModal.js`). Un asistente (`DungeonWizardModal.js`) genera el
esqueleto de una mazmorra nueva. Ver también "Piezas de mazmorra" más abajo, que es
donde se definen los TIPOS de casilla que aquí se pintan.

### Ambiente (`ambience` → `AmbienceManager.js`)
`data/ambience.json`: música y clima por terreno/región del mapamundi (qué pista suena
en cada bioma, qué climas son posibles y su probabilidad).

### Transformaciones (`worldTransforms` → `WorldTransformsManager.js`)
`data/world_transforms.json`: reglas de "el mundo cambia según la historia" — p. ej. al
activarse un flag global, un rango de baldosas de un terreno se sustituye por otro (la
presa que se abre y convierte tierra seca en río). Ver `docs/design/WORLD_MAP.md` §4.

### Edificios / assets (`worldBuildings` → `WorldBuildingsManager.js`)
`data/world_buildings/*.json`: catálogo de maquetas 3D colocables en el mapamundi
(edificios clásicos de ciudad/aldea, casitas, templos...), con su escena Godot asociada,
escala y offset vertical.

### Terrenos (`worldTerrains` → `WorldTerrainsManager.js`)
`data/world_terrains/*.json`: define cada **código de terreno** (`grs`, `sand`, `ice`,
`lav`...) con su icono, color de paleta, si es transitable, si tiene variantes visuales
con peso (sub-biomas) y sus reglas de daño/velocidad/deslizamiento si aplica.

### Recursos, mapa (`worldResources` → `WorldResourcesManager.js`)
`data/world_resources/*.json`: nodos recolectables del mapamundi (árboles, rocas, agua
de pesca...) con su herramienta requerida, ítem obtenido y capacidad/regeneración. Ver
`docs/design/WORLD_MAP.md` §2 para la tabla herramienta→recurso completa.

### 🧩 Piezas de mazmorra (`dungeonPieces` → `DungeonPiecesManager.js`)
Pantalla **fusionada** (no tiene persistencia propia; sigue leyendo/escribiendo las dos
colecciones reales de abajo) que unifica TODO lo que se puede colocar en una mazmorra en
una sola lista categorizada:

- **🔒 Comportamiento fijo**: tipos de casilla con lógica hardcodeada en
  `GridDungeonStage.gd` (puertas, cofres, palancas...). Aquí solo se edita su paleta
  (icono/color/grupo) y modelo 3D; renombrarlas pide confirmación explícita porque
  rompería el comportamiento de celdas nuevas.
- **🎨 Cosmético (sin código)**: casillas cuyo aspecto lo decide 100% el bloque de
  "render genérico" — libres de crear/borrar/renombrar sin ningún riesgo.
- **🧩 Objeto Inteligente**: piezas 100% data-driven de `data/dungeon_kits.json`
  (archetype + shape + reacción definen su comportamiento sin tocar GDScript). Aquí es
  donde creas la mayoría de interactuables nuevos (barreras rompibles, interruptores,
  plataformas móviles...).

*(Las entradas técnicas "Tipos de casilla" / "Kits (Obj. Inteligente)" siguen existiendo
en `collections.js` solo para no romper la persistencia real de
`data/dungeon_tiles/*.json` / `data/dungeon_kits.json`; en la navegación solo aparece la
pantalla fusionada de arriba.)*

## Grupo 💬 Personajes

### NPCs (`npcs` → `NpcEditor.js`)
Cada NPC es `data/npcs/<id>.json`: un grafo plano de nodos (`_meta` con avatar/fondo,
nodos `message`/`option` con texto multilingüe en 7 idiomas, `next`, `reward` y `condition`). Incluye un
editor visual de grafo (`NpcGraphEditor.js`), un simulador en vivo de cómo se verá en
Novela Visual (`VnSimulatorModal.js`) y un selector de retrato que admite tanto sprites
reales (`assets/vn/npcs/`) como **emoji como avatar** (el motor los renderiza como texto,
ver `docs/design/NARRATIVE.md` y el propio `DialogueResource.gd`).

### Enemigos (`enemies` → `EnemiesManager.js`)
`data/enemies/<id>.json`: stats base y de escalado, elemento/debilidades/resistencias,
IA (`aggressive`/`defensive`/`caster`), habilidades desbloqueadas por nivel, botín
inline (lista de entradas `gold`/`item`/`resource`/`equipment`/`consumable`, cada una
con su `chance` independiente) y si es jefe. `scripts/systems/EnemyDatabase.gd` es quien
consume esto en runtime para generar la ficha final procedural por nivel.

> ⚔️ **Combat Sandbox Integrado**: Desde la propia ficha del enemigo puedes abrir el
> modal de simulación de combate (`CombatSandboxModal.js`) para librar batallas de prueba
> en tiempo real dentro del navegador web, ajustando nivel, profesión, equipo y atributos
> del jugador sin tener que arrancar Godot.

### Skills de enemigo (`enemySkills` → `EnemySkillsManager.js`)
`data/enemy_skills.json`: catálogo de habilidades usables solo por enemigos en combate
(separado del árbol de habilidades del jugador).

## Grupo 🎒 Objetos y sistemas

### Objetos (`items` → `ItemsManager.js`)
`data/items/<id>.json`: catálogo completo de ítems (consumibles, equipamiento,
materiales, importantes de misión), con categoría, si es usable, bonuses/stats de
combate si es equipable.

### Profesiones (`professions` → `ProfessionsManager.js`)
`data/professions.json` (documento único, `required: true` — el juego no arranca sin
él): las clases jugables (por defecto 7: Don Nadie, Guerrero, Arquero, Elementalista,
Sacerdote, Psíquico, Tiempo), su icono/color y qué habilidades desbloquea cada una a qué
nivel de profesión (máximo 30, `MAX_JOB_LEVEL` en `data/config.json`).

### Habilidades (`skills` → `SkillsManager.js`)
`data/skills.json` (también `required: true`): definición de cada habilidad de combate
(coste, efectos, tipo, requisitos). Se equipan desde `professions.json` o desde
sinergias.

### Sinergias (`synergies` → `SynergiesManager.js`)
`data/synergies.json`: combos — qué pares/tríos de habilidades encoladas en el mismo
turno de combate se fusionan en un efecto especial (con bonus si la Resonancia está al
100%, ver `docs/design/COMBAT.md` §3).

### Tiendas (`shops` → `ShopsManager.js`)
`data/shops.json`: catálogos de stock reutilizables (qué vende y a qué precio) que
luego se asignan a un NPC/ciudad concreta por `stock_id`.

## Grupo ⭐ Historia

### Misiones/Eventos (`events` → `EventsManager.js`)
`data/events.json`: disparadores data-driven — una `condition` (expresión Godot) y una
lista de `actions` (mini-lenguaje de tokens: `item:`, `gflag:`, `questf:`, `dialogue:`,
`cine:`, `combat:`, `worldt:`...). Es el pegamento entre "algo pasó en el juego" y "el
mundo/la historia reacciona". Ver `04-ESTRUCTURA-DE-DATOS.md` para el listado completo
de tokens soportados.

### Estados/Quests (`quests` → `QuestsManager.js`)
`data/quests.json`: la línea temporal de estados de la questline principal (`order`,
un array ordenado de ids de estado) más sus títulos/pistas multilingües (7 idiomas), y el mapeo
`combat_victory` (qué evento dispara automáticamente al vencer a cierto enemigo). El
progreso nunca retrocede: `questf:<estado>` avanza "hacia adelante" en este orden.

### Escenas (`scenes` → `ScenesManager.js`)
`data/scenes/<id>.json`: el **Sistema Narrativo unificado** (motor nuevo, `SceneRunner`).
Cada escena es un grafo de nodos con distintos "kind" (`say`, `choice`, `state`, `event`,
`flow`), y sirve tanto para conversaciones como para **cinemáticas**: un nodo `event`
que emite `EVENT_CINE_CAMERA` mueve la cámara del mundo, y uno o varios `say` con
`style: "banner"` narran la escena. El token `cine:<id>` (mini-lenguaje de
reward/condition) reproduce la escena con ese id (ver `QuestManager.play_cinematic`).
También reemplaza progresivamente `dialogues.json`: si existe una escena con el MISMO
id que un `dialogue:` invocado desde cualquier otro sitio, esa escena se reproduce en
su lugar automáticamente (ver `QuestManager.request_dialogue_id`).

## Grupo 🏆 Progresión

### Logros (`achievements` → `AchievementsManager.js`)
`data/achievements.json`: condición de desbloqueo + recompensa (mismo mini-lenguaje de
recompensas que NPCs/eventos).

### Tutoriales (`tutorials` → `TutorialsManager.js`)
`data/tutorials.json`: mensajes de ayuda contextual que se disparan por condición
(primera vez que el jugador hace X).

## Grupo ⚙️ Balance

### Config (`config` → `ConfigManager.js`)
`data/config.json`: **el panel de balance numérico completo del juego** — stats
iniciales, curvas de XP (personaje y profesión), fórmulas de daño/defensa/esquiva/crítico
a partir de atributos, energía, día/noche, parámetros de combate (PA, Resonancia,
intervalo de turno), mazmorras (tick de trampas, probabilidad de emboscada), economía
(coste de reforjado/reset de stats, escalado de mejora de edificios) y accesibilidad.
Es probablemente el fichero que más tocarás al ajustar la sensación/dificultad de tu
juego sin escribir una sola línea de GDScript. Ver el detalle campo por campo en
`04-ESTRUCTURA-DE-DATOS.md`.

## Sistemas / Medios

### Biblioteca de Medios (`mediaLibrary` → `MediaLibrary.js`)
Sin persistencia propia (no es un JSON): navegador directo de los ficheros de `assets/`
(imágenes, audio) organizados por sistema, con previsualización y subida. Es el punto
central para gestionar el arte del juego sin usar el explorador de archivos del sistema
operativo. Ver `06-ARTE-AUDIO-Y-ASSETS.md`.

## Componentes transversales (no son pestañas, pero aparecen en varias)

| Componente | Uso |
|---|---|
| `EntityListPanel.js` | Lista lateral con buscador/filtro que reutilizan casi todas las colecciones tipo diccionario |
| `EditorToolbar.js` | Barra de undo/redo/copiar/pegar/duplicar/borrar/guardar común |
| `ConditionEditor.js` | Editor asistido de expresiones `condition` (autocompletado de snippets de `CONDITION_SNIPPETS`) |
| `RewardEditor.js` | Editor asistido del mini-lenguaje `reward` (autocompletado de `REWARD_TOKENS`) |
| `VnAssetPicker.js` | Selector visual de fondos/retratos/audio de Novela Visual (soporta emoji como retrato) |
| `VnSimulatorModal.js` | Emulador fiel de cómo se verá una escena/diálogo en el juego, sin tener que abrir Godot |
| `CombatSandboxModal.js` | Simulador interactivo de combates en el navegador para balancear estadísticas de enemigos e IA |
| `DungeonWalkthroughModal.js` | Modal de recorrido paso a paso para testear y validar mapas de mazmorras |
| `GlobalSearch.js` | Buscador universal que recorre TODAS las colecciones registradas en `collections.js` |
| `QaPanel.js` | Ejecuta la validación de integridad referencial (misma lógica que `tools/validate_data.py`) desde el navegador |
| `HelpDrawer.js` | Panel de ayuda contextual por pestaña (contenido en `editor/js/lib/helpContent.js`) |
| `FirstStepsPanel.js` | Panel interactivo de primeros pasos integrado en el editor para guiar a los nuevos creadores |
| `NpcPoiWizardModal.js` | Asistente para crear de un solo golpe un Punto de Interés (POI) en el mapa con su entidad y su árbol de diálogo de NPC |
| `ItemWizardModal.js` | Asistente para crear ítems rápidamente configurando categoría, rareza, icono y bonificaciones |
| `QuestWizardModal.js` | Asistente para estructurar estados de misión, títulos, pistas y recompensas |
| `DungeonWizardModal.js` | Asistente para generar el esqueleto completo de una mazmorra nueva (salas, pasillos, cofre y sala del jefe) |

## Cómo añadir tu propia pestaña de contenido

Si tu juego necesita un tipo de contenido nuevo que no encaja en las colecciones
existentes (p. ej. "Recetas de crafteo", "Cartas coleccionables"...), el propio
`collections.js` documenta el procedimiento en su cabecera:

1. Crea el componente Vue en `editor/js/components/<Nombre>.js`.
2. Impórtalo y regístralo en `editor/js/app.js` (`components: { ... }`).
3. Añade UNA fila a `TABS` en `collections.js` (con su `kind`/`storeKey`/`file` o
   `endpoint`/`dirty*`).
4. Si es colección "un fichero por id", regístrala también en `editor/serve.py`
   (`ALLOWED_COLLECTIONS`) y añade su mapa `dirtyX`/prop `selectedX`/`storeKey` al
   `store` reactivo de `editor/js/store.js`.
5. Corre `node tools/check_editor.mjs` y `python tools/gen_editor_codemap.py`.

Todo lo demás (aparecer en la navegación, en la búsqueda global, en el QA...) se deriva
automáticamente de esa única fila — es el mismo patrón que ya usan las ~30 pestañas
existentes.
