# 01 — Visión General y Arquitectura

## 1. Qué es exactamente este template

Es un **RPG completo y jugable** ("Taos Game Maker", nombre interno en `project.godot`) más
un **editor de contenido a medida**. No es un motor genérico: es un juego ya construido
con todos sus sistemas funcionando, pensado para que reutilices el **80-90% del motor**
(combate, exploración, diálogos, guardado, progresión...) y sustituyas el **contenido**
(historia, enemigos, mapa, arte) por el tuyo.

Tiene 4 pilares jugables autónomos + 1 bloque de sistemas comunes:

| Pilar | De qué va | Vista principal |
|---|---|---|
| 🗺️ **Mundo** | Mapamundi 3D top-down, recolección de recursos, campamento, viaje | `scenes/tabs/tab_world_3d/TabWorld3D.gd` |
| 🏰 **Mazmorras** | Exploración en 1ª persona por rejilla, puzles con 6 habilidades | `scenes/views/view_dungeon/ViewDungeon.gd` |
| ⚔️ **Combate** | JRPG por turnos (ATB + cola de Puntos de Acción + sinergias) | `scenes/views/view_combat/ViewCombat.gd` |
| 📖 **Narrativa** | Novela visual: diálogos ramificados, NPCs, ciudades, misiones | `scenes/views/view_place/ViewPlace.gd` |
| ⚙️ **Sistemas globales** | Objetos, tiendas, logros, tutoriales, configuración de balance | Autoloads (ver más abajo) |

Esta misma agrupación en 4+1 es la que verás reflejada en la barra lateral del editor
web (`editor/js/nav.js` → `GAME_MODES`) y en el Hub de inicio del propio juego.

## 2. Stack tecnológico

| Capa | Tecnología | Dónde vive |
|---|---|---|
| Motor del juego | **Godot 4.x** (probado en 4.7+, etiqueta interna `"4.7"` en `project.godot`), GDScript, renderer `mobile`, físicas 3D nativas | raíz del repo, `project.godot` |
| Plataformas objetivo | Móvil (feature `Mobile` activada) + escritorio | `project.godot` → `config/features` |
| Editor de contenido | **Vue 3** (via CDN `unpkg.com/vue@3`, **sin build step**, sin npm/webpack) | `editor/js/` |
| Servidor del editor | **Python 3** puro (`http.server`), sin dependencias externas | `editor/serve.py` |
| Persistencia de contenido | **JSON plano** en disco, leído por Godot y por el editor | `data/` |
| Validación de datos | Script Python de integridad referencial | `tools/validate_data.py` |
| Documentación autogenerada | Scripts Python que escanean el código y regeneran `.md`/`.tsv` | `tools/gen_codemap.py`, `tools/gen_editor_codemap.py` |

**Por qué esta arquitectura:** el editor NO necesita Node/npm/build para funcionar (es
HTML+JS+CSS servido tal cual), y el servidor Python NO necesita librerías de terceros.
Esto significa que cualquiera con Python instalado puede editar el contenido del juego
sin instalar un stack de frontend completo.

## 3. Cómo se relacionan Godot, el editor web y los JSON

```
┌─────────────────────┐        lee/escribe JSON        ┌──────────────────────────┐
│   Editor Web (Vue)   │ ───────────────────────────▶  │   data/*.json y          │
│  editor/js/*.js      │  ◀───────────────────────────  │   data/<coleccion>/*.json│
│  (localhost:8000)    │        vía HTTP (serve.py)     └──────────────────────────┘
└─────────────────────┘                                            ▲
                                                                    │ carga en memoria
                                                                    │ al arrancar
                                                          ┌──────────────────────┐
                                                          │  Godot (el juego)    │
                                                          │  Design.gd (autoload)│
                                                          └──────────────────────┘
```

- El **editor web** (`editor/serve.py` + `editor/js/`) es una SPA que llama a una API
  HTTP local (`/api/data/<archivo>`, `/api/collection/<nombre>[/<id>]`, `/api/assets/...`)
  que lee y escribe directamente los ficheros de `data/` y `assets/` en disco.
- **Godot** nunca habla con el editor. Al arrancar el juego, el autoload `Design.gd`
  (`scripts/autoload/Design.gd`) carga TODOS los JSON de `data/` a memoria (algunos de
  forma perezosa) y expone getters (`Design.get_enemy(id)`, `Design.get_item(id)`,
  `Design.get_npc(id)`, etc.) que consume el resto del juego.
- **No hay paso de "build" ni "exportar contenido"**: guardas en el editor → el JSON en
  disco cambia → la próxima vez que Godot arranque (o recargue datos) lee la versión
  nueva. Esto hace el ciclo de iteración de contenido casi instantáneo.

## 4. Los "Autoloads" (singletons globales de Godot)

Declarados en `project.godot` → `[autoload]`. Son el corazón del motor: cualquier vista
puede llamarlos desde cualquier sitio sin pasarlos como referencia.

| Autoload | Archivo | Responsabilidad |
|---|---|---|
| `Locale` | `scripts/autoload/Locale.gd` | Idioma (7 idiomas: ES, EN, FR, IT, DE, ZH, JA), accesibilidad (escala de fuente, reducir movimiento, daltonismo) |
| `Design` | `scripts/autoload/Design.gd` | Carga y caché de TODOS los JSON de `data/`; única fuente de verdad de contenido |
| `ExplorationSkills` | `scripts/autoload/ExplorationSkills.gd` | Lógica de las 6 habilidades de puzle de mazmorras |
| `GlobalState` | `scripts/autoload/GlobalState.gd` | Stats del jugador, oro, inventario/equipo, flags, botín/forja (delega en `scripts/systems/`) |
| `GlobalEvents` | `scripts/autoload/GlobalEvents.gd` | Bus de eventos globales desacoplado (pub/sub) |
| `SaveManager` | `scripts/autoload/SaveManager.gd` | Guardado/carga de partida |
| `TimeManager` | `scripts/autoload/TimeManager.gd` | Ciclo día/noche y calendario |
| `QuestManager` | `scripts/autoload/QuestManager.gd` | Progreso de misiones, disparo de diálogos/cinemáticas/escenas |
| `SceneRunner` | `scripts/autoload/SceneRunner.gd` | Motor del "Sistema Narrativo" (grafos de escena nuevos) |
| `NarrativeOverlay` | `scenes/components/narrative/NarrativeOverlay.gd` | Overlay visual de novela visual (diálogos en pantalla) |
| `SceneManager` | `scripts/autoload/SceneManager.gd` | Cambios de vista/escena y transiciones |
| `AudioManager` | `scripts/autoload/AudioManager.gd` | Música y efectos de sonido |
| `MetaManager` | `scripts/autoload/MetaManager.gd` | Metadatos de progreso/meta-juego |
| `Juice` | `scripts/autoload/Juice.gd` | Micro-interacciones/feedback ("juice") de UI |
| `OrbBarksManager` | `scripts/systems/OrbBarksManager.gd` | Frases contextuales del compañero "Orbe" |
| `OrbCompanionOverlay` | `scenes/components/orb_companion/OrbCompanionOverlay.gd` | Overlay visual y animación flotante del compañero Orbe |

Ver la tabla ampliada de **sistemas especialistas** (módulos extraídos de los autoloads
gigantes para no tener ficheros de miles de líneas) en `docs/INDEX.md` sección
"SISTEMAS ESPECIALISTAS".

## 5. Estructura de carpetas de primer nivel

| Carpeta | Contenido |
|---|---|
| `scripts/` | GDScript: `autoload/` (singletons), `systems/` (lógica especialista), `config/` (constantes de balance como `GameConfig`/`UiKit`) |
| `scenes/` | Escenas de Godot (`.tscn`) y su lógica: `tabs/` (mapamundi), `views/` (mazmorras, combate, ciudad, tienda, forja...), `ui/` (menús, HUD, opciones), `components/` (piezas reutilizables), `game/` (raíz del juego) |
| `resources/` | Definiciones de `Resource` custom de Godot (`.gd extends Resource`), p. ej. `DialogueResource.gd`, `EquipmentResource.gd`, `CellResource.gd` |
| `data/` | **Todo el contenido del juego en JSON**: enemigos, objetos, profesiones, mazmorras, npcs, historia, economía, balance. Ver `04-ESTRUCTURA-DE-DATOS.md` |
| `assets/` | Arte, audio y modelos 3D, organizados por sistema (`combat/`, `common/`, `dungeon/`, `vn/`, `world/`). Ver `06-ARTE-AUDIO-Y-ASSETS.md` |
| `editor/` | El editor web de contenido completo (servidor Python + SPA Vue) |
| `tools/` | Scripts Python/Node de mantenimiento: validación de datos, generación de documentación, procesado de imágenes |
| `docs/` | Documentación: `INDEX.md`/`CODEMAP.md`/`SYMBOLS.tsv` (para IA/desarrollo), `design/` (especificaciones de mecánicas), `guide/` (esta guía completa en 7 idiomas) |

## 6. Filosofía "data-driven": qué es código y qué es contenido

Esta es la distinción más importante para adaptar el template con éxito:

- **Código (GDScript, no lo tocas para hacer un juego nuevo salvo que quieras mecánicas
  distintas)**: cómo se calcula el daño, cómo se mueve el jugador, cómo funciona un
  puzle de mazmorra, cómo se renderiza el mapa, el bucle de combate por turnos...
- **Contenido (JSON, editable 100% desde el editor web, es lo que cambias siempre)**:
  qué enemigos existen y sus stats, qué objetos hay, qué dice cada NPC, cómo se llama
  cada profesión y qué habilidades tiene, el mapa entero, las mazmorras, los diálogos,
  las misiones, los precios de las tiendas, los parámetros numéricos de balance
  (`data/config.json`)...

Hay una excepción importante y deliberada: unos pocos **"tipos de casilla de
comportamiento fijo"** en mazmorras (puertas, cofres, palancas...) tienen lógica
hardcodeada en `GridDungeonStage.gd` porque su comportamiento en el motor no es
puramente cosmético. El editor (`DungeonPiecesManager.js`) los marca visualmente como
🔒 "Comportamiento fijo" y avisa antes de renombrarlos para que no rompas el juego sin
darte cuenta. Todo lo demás (piezas cosméticas y "Objetos Inteligentes" data-driven) es
libre de crear/editar/borrar sin tocar código.

## 7. Próximo paso

Continúa con `02-PRIMEROS-PASOS.md` para dejar el proyecto funcionando en tu máquina.
