
# INDEX.md - ROUTING TABLE & DIRECTRICES DEL PROYECTO

## ⚠️ PROTOCOLO DE AHORRO DE TOKENS (PARA AGENTES IA)

1. **Punto de Entrada Unificado**: Consulta esta tabla antes de buscar archivos. Es la única fuente de verdad sobre dónde vive cada subsistema.
2. **Ubicación de Función y Línea**: Consulta `CODEMAP.md` o `SYMBOLS.tsv` para obtener el archivo y número de línea exacto (`nombre_funcion Lxx`).
3. **Lectura por Rangos Estricta**: **PROHIBIDO** leer archivos completos de más de 300 líneas (ej. `TabWorld3D.gd`, `ViewCombat.gd`, `GlobalState.gd`, `app.js`). Lee **ÚNICAMENTE** el rango de líneas o la `#region` objetivo.
4. **Mantenimiento Obligatorio de Mapas y Assets**:
   * **Si modificas el JUEGO (Godot - `scripts/`, `scenes/`, `resources/`)**:
     Tras cualquier cambio estructural (funciones, señales, regiones), **EJECUTA**:
     `python tools/gen_codemap.py`
   * **Si modificas el EDITOR (Web - `editor/`)**:
     Tras cualquier cambio en la herramienta web, **EJECUTA OBLIGATORIAMENTE**:
     `python tools/gen_editor_codemap.py`
     Y verifica que no haya errores de sintaxis/imports con:
     `node tools/check_editor.mjs`
   * **Si generas o importas IMÁGENES / SPRITES (JPEG/PNG)**:
     Ejecuta siempre el procesador para asegurar conversión a PNG real de 32 bits, eliminación de fondo y formato correcto para Godot:
     `python tools/process_image.py <origen> <destino> [--type sprite|background] [--resize WxH]`
5. **Especificaciones de Mecánicas (`docs/design/`)**: **NO las leas** salvo que la tarea consista explícitamente en diseñar, modificar o consultar reglas de juego.

---

## 🗺️ TABLA MAESTRA DE ACTOS Y ZONAS DEL MUNDO (CANON DEL PROYECTO)

*Esta tabla es la fuente de verdad absoluta para cualquier referencia a zonas, actos, niveles, ciudades y mazmorras en todo el proyecto:*

| Acto | Zona | Nombre de Zona | Bioma | Nivel Enemigos | Ciudad Principal | Mazmorras Clave | Boss / Hito Principal |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Prólogo** | **Zona 1** | **Yelmo** | `bad` (Yelmo/Páramo) | **1 – 5** | — (Campamento/Presa) | `dun_inicial`, `dun_yelmo` | **Orco Berserker** (id `orco_berserker`, Lv 99) · Despertar, Presa del Agua |
| **Acto 1** | **Zona 2** | **Hielo** | `ice` / `icy` (Nieve/Hielo) | **5 – 8** | — (Refugio de Nieve) | `dun_nieves` | **Eco Fragmentado** (id `eco_fragmentado`, Lv 7) · Laberinto de Hielo resbaladizo |
| **Acto 1** | **Zona 3** | **Pradera** | `grs` / `gnd` (Pradera/Agua) | **8 – 14** | **Sylphrena** (`city_sylphrena`, ex `city_001`) | `dun_bandidos` (ex `dun_002`), 3 Senderos Iniciales | **Jefe Bandido** (Lv 15) · 3 Profesiones iniciales, Puente del Mono |
| **Acto 2** | **Zona 4** | **Celestia** | `grs` / Templos | **15 – 25** | **Celestia** (`city_celestia`, ex `city_002`) | 3 Senderos Avanzados, Mazmorras de Templo | **Obtención del Barco** · Las 6 profesiones dominadas |
| **Acto 3** | **Zona 5** | **Gloriam** | `sand` / `des` (Desierto) | **25 – 35** | **Gloriam** (`city_gloriam`) | `dun_desierto` (Mazmorra del Desierto) | **Navegación Marina** · Tormentas de arena y ruinas |
| **Acto 4** | **Zona 6** | **Arcanum** | `bad` (Páramo Arcano) | **35 – 45** | **Arcanum** (`city_arcanum`) | `dun_laboratorio` (Laboratorio de Arcanum) | **Tecnología Arcana** · Autómatas y experimentos |
| **Acto 5** | **Zona 7** | **Final** | `bad` / Ruinas Sagradas | **45 – 50** | — (Templo Primordial) | `dun_final` (Templo del Origen / Tribunal) | **Guardián Supremo** (Lv 50) · Juicio final y desenlace |
| **Opcional** | **Zona Extra** | **Zona Extra** | `grs` / `sand` / Isla | **50** | — (Área de Leveo) | — (Cofres con recompensas futuras) | **Área de Farmeo** · Enemigos de alto nivel para levear |

> 📌 **Topes de Nivel Globales**: Nivel máximo del Personaje = **50** (`MAX_CHAR_LEVEL`). Nivel máximo de Profesión = **30** (`MAX_JOB_LEVEL`).

---

## 🛠️ AUTOLOADS Y SISTEMAS CORE (JUEGO)

| Módulo / Sistema            | Archivo GDScript                          | Responsabilidad Principal                                 |
| :--------------------------- | :---------------------------------------- | :-------------------------------------------------------- |
| **Estado Jugador**     | `scripts/autoload/GlobalState.gd`       | Stats, oro, profesión, facetas. Inventario/equipo, flags, botín/forja y encargos delegados en especialistas (ver Sistemas Especialistas) |
| **Carga de Datos**     | `scripts/autoload/Design.gd`            | Carga y caché en memoria de todos los JSON de `data/`  |
| **Gestor de Escenas**  | `scripts/autoload/SceneManager.gd`      | Cambios de vista/escena y transiciones                    |
| **Misiones/Historia**  | `scripts/autoload/QuestManager.gd`      | Progreso de misiones, triggers de eventos y flags         |
| **Tiempo/Reloj**       | `scripts/autoload/TimeManager.gd`       | Ciclo día/noche, paso de horas y calendario              |
| **Habs. Exploración** | `scripts/autoload/ExplorationSkills.gd` | Lógica de las 6 habilidades de puzle en mazmorras        |
| **Audio/Música**      | `scripts/autoload/AudioManager.gd`      | Gestión de BGM y SFX                                     |

---

## 🧩 SISTEMAS ESPECIALISTAS (DESFRAGMENTACIÓN DE MONOLITOS)

Módulos extraídos de los antiguos ficheros gigantes (`GlobalState.gd`,
`ViewCombat.gd`, `TabWorld3D.gd`). Los ficheros origen conservan **fachadas** con
las mismas firmas públicas, así que el resto del código no cambia.

| ¿Qué abro para modificar X?      | Archivo GDScript                                                        | Extraído de        |
| :-------------------------------- | :---------------------------------------------------------------------- | :----------------- |
| **Gestión de Inventario/Equipo**  | `scripts/systems/ItemInventoryManager.gd`                               | `GlobalState.gd`   |
| **Banderas/Eventos Globales**     | `scripts/systems/GameFlagsManager.gd`                                   | `GlobalState.gd`   |
| **Botín/Rareza/Forja/Re-forja**   | `scripts/systems/LootManager.gd`                                        | `GlobalState.gd`   |
| **Encargos del Tablón**           | `scripts/systems/EncargosManager.gd`                                    | `GlobalState.gd`   |
| **Motor Turnos ATB Combate**      | `scenes/views/view_combat/components/CombatTurnEngine.gd`               | `ViewCombat.gd`    |
| **Cola y Sinergias de Combate**   | `scenes/views/view_combat/components/CombatQueueSystem.gd`              | `ViewCombat.gd`    |
| **Daño/Estados Alterados Combate**| `scenes/views/view_combat/components/CombatDamageResolver.gd`           | `ViewCombat.gd`    |
| **Panel Resultado/Barras/Cola UI**| `scenes/views/view_combat/components/CombatResultUI.gd`                 | `ViewCombat.gd`    |
| **Clima y Audio de Biomas 3D**    | `scenes/tabs/tab_world_3d/interactive/WorldEnvironmentController.gd`     | `TabWorld3D.gd`    |
| **Física de Terreno/Hielo**       | `scenes/tabs/tab_world_3d/interactive/OverworldPhysicsController.gd`     | `TabWorld3D.gd`    |
| **Joystick/Panel Inferior HUD**   | `scenes/tabs/tab_world_3d/interactive/WorldHudBuilder.gd`                | `TabWorld3D.gd`    |
| **Cámara de Cinemáticas/Presa**   | `scenes/tabs/tab_world_3d/interactive/WorldCinematicController.gd`      | `TabWorld3D.gd`    |

---

## 🎮 RUTA POR MODOS DE JUEGO

### 1. Modo Mapamundi (3D Top-Down & Farmeo)

* **Vista Principal**: `scenes/tabs/tab_world_3d/TabWorld3D.gd`
* **Generación Mapa**: `scripts/systems/WorldMapBuilder.gd`
* **Acampada / Hoguera**: `scenes/tabs/tab_world_3d/interactive/CampTentSystem.gd`
* **Herramientas / Farmeo**: `scenes/tabs/tab_world_3d/interactive/TravelSystem.gd`
* **Clima / Día-Noche / Audio Bioma**: `scenes/tabs/tab_world_3d/interactive/WorldEnvironmentController.gd`
* **Física de Terreno / Hielo**: `scenes/tabs/tab_world_3d/interactive/OverworldPhysicsController.gd`
* **Joystick / Panel Inferior / HUD**: `scenes/tabs/tab_world_3d/interactive/WorldHudBuilder.gd`
* **Cámara de Cinemáticas / Presa**: `scenes/tabs/tab_world_3d/interactive/WorldCinematicController.gd`
* **Datos JSON**: `data/world.json`, `data/world_terrains/`, `data/world_resources/`

### 2. Modo Mazmorras (1ª Persona 3D & Puzles)

* **Vista Principal**: `scenes/views/view_dungeon/ViewDungeon.gd`
* **Escenario y Rejilla**: `scenes/views/view_dungeon/components/GridDungeonStage.gd`
* **Jugador / Enemigos**: `DungeonPlayer.gd`, `DungeonEnemy.gd`
* **HUD y Habilidades**: `ExplorationHud.gd`, `ExplorationSkillController.gd`
* **Datos JSON**: `data/dungeons/`, `data/dungeon_tiles/`

### 3. Modo Combate (Turnos 2D JRPG)

* **Vista Principal**: `scenes/views/view_combat/ViewCombat.gd`
* **UI Pestañas / Menús**: `scenes/views/view_combat/components/CombatTabsUI.gd`
* **Motor ATB (turnos)**: `scenes/views/view_combat/components/CombatTurnEngine.gd`
* **Cola y Sinergias**: `scenes/views/view_combat/components/CombatQueueSystem.gd`
* **Daño / Estados Alterados**: `scenes/views/view_combat/components/CombatDamageResolver.gd`
* **Panel Resultado / Barras / Cola UI**: `scenes/views/view_combat/components/CombatResultUI.gd`
* **FX y Sintonía**: `CombatFx.gd`, `ResonanceCircle.gd`
* **Base de Enemigos**: `scripts/systems/EnemyDatabase.gd`
* **Datos JSON**: `data/enemies/`, `data/skills.json`, `data/professions.json`

### 4. Modo Narrativo (Visual Novel & POIs)

* **Vista Principal**: `scenes/views/view_place/ViewPlace.gd`
* **Overlay Diálogos**: `scenes/components/narrative/NarrativeOverlay.gd`
* **Vista Ciudad/POIs**: `scenes/views/view_city/ViewCity.gd`
* **Datos JSON**: `data/dialogues.json`, `data/npcs/`, `data/ids/`

### 5. Editor de Juego (Herramienta Web Vue 3)

* **Punto de Entrada**: `editor/index.html` / `editor/js/app.js`
* **Mapa de Código Web**: `editor/CODEMAP.md`
* **Servidor Local**: `editor/serve.py`
* **Lógica / Componentes**: `editor/js/components/` y `editor/js/store.js`
* **Operación**: Modifica directamente los archivos `.json` de la carpeta `data/`

---

## 🗂️ MAPA DE DOCUMENTACIÓN (`docs/`)

* **`docs/INDEX.md`**: (Este archivo) Punto de entrada único del proyecto.
* **`docs/guide/README.md`**: 🌐 **Portal Central de Documentación y Manuales del Template / Motor** (Disponible en 7 idiomas: [Español](guide/es/README.md), [English](guide/en/README.md), [Français](guide/fr/README.md), [Italiano](guide/it/README.md), [Deutsch](guide/de/README.md), [简体中文](guide/zh/README.md), [日本語](guide/ja/README.md)).
* **`docs/CODEMAP.md`**: Mapa de código del juego autogenerado por `tools/gen_codemap.py`.
* **`docs/SYMBOLS.tsv`**: Tabla de símbolos GDScript autogenerada.
* **`editor/CODEMAP.md`**: Mapa de código del editor web autogenerado por `tools/gen_editor_codemap.py`.

### Especificaciones Técnicas y Reglas (`docs/design/`)

*Consultar EXCLUSIVAMENTE cuando se pida crear, modificar o balancear elementos de estos modos:*

* **`docs/design/STORY.md`**: Biblia narrativa, personajes reales (Aiden, Elara), giro de Arcanum, 5 Actos, 7 Zonas y finales múltiples.
* **`docs/design/PROGRESSION.md`**: Curva de niveles (1-50), habilidades de "Don Nadie" (1-30) y reparto de XP de profesión.
* **`docs/design/COMBAT.md`**: Mecánicas de turnos ATB, Puntos de Acción (PA), Sintonía/Resonancia, fórmulas de daño, elementos y sinergias.
* **`docs/design/DUNGEONS.md`**: Rejilla 3D, puzles, interactuables de celda y mecánicas de las 6 Habilidades de Exploración.
* **`docs/design/NARRATIVE.md`**: Vista de Novela Visual, árbol de diálogos, Facetas/Atributos y navegación por ciudades/POIs.
* **`docs/design/WORLD_MAP.md`**: Sistemas de acampada/hoguera, herramientas de farmeo y transformaciones dinámicas del terreno.
* **`docs/design/UI_KIT.md`**: Paleta de color, tipografía (Cinzel) y espaciados estándar extraídos de `UiKit.gd`/`Locale.gd` — consultar antes de añadir un color/estilo nuevo para no desviarse de la paleta existente.
