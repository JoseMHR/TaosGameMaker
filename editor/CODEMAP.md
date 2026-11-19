# CODEMAP del EDITOR — Mapa de código (autogenerado)

> ⚙️ **Fichero AUTOGENERADO por `tools/gen_editor_codemap.py`. NO editar a mano.**
> Regénералo tras cambios estructurales:  `python tools/gen_editor_codemap.py`
>
> Índice de ALTA SEÑAL para tocar el editor (`editor/`) sin abrir ficheros enteros.
> Verifica tus cambios con:  `node tools/check_editor.mjs`

**Totales:** 92 ficheros `.js` · 25268 líneas.

Leyenda: `nombre Lnn` = símbolo/función en la línea *nn*. `template: Lnn` = inicio plantilla inline.

## ¿Qué abro para editar…? (espejo de `docs/INDEX.md`)

| Pestaña (activeTab) | Etiqueta | Grupo | Componente |
|---------------------|----------|-------|------------|
| `map` | 🗺️ Mapa | world | `MapEditor` |
| `cityWorkspace` | 🏙️ Ciudades | world | `CityWorkspace` |
| `ids` | 📦 Entidades | world | `IdsManager` |
| `dungeons` | 🏰 Mazmorras | world | `DungeonEditor` |
| `ambience` | 🌦️ Ambiente | world | `AmbienceManager` |
| `worldTransforms` | 🌍 Transformaciones | world | `WorldTransformsManager` |
| `worldBuildings` | 🏗️ Edificios (assets) | world | `WorldBuildingsManager` |
| `worldTerrains` | 🗺️ Terrenos | world | `WorldTerrainsManager` |
| `worldResources` | 🌲 Recursos (mapa) | world | `WorldResourcesManager` |
| `dungeonPieces` | 🧩 Piezas de mazmorra | world | `DungeonPiecesManager` |
| `dungeonTiles` | 🧱 Tipos de casilla | world | `DungeonPiecesManager` |
| `dungeonKits` | 🧩 Kits (Obj. Inteligente) | world | `DungeonPiecesManager` |
| `npcs` | 💬 NPCs | people | `NpcEditor` |
| `enemies` | 👾 Enemigos | people | `EnemiesManager` |
| `enemySkills` | ☄️ Skills de enemigo | people | `EnemySkillsManager` |
| `items` | 🎒 Objetos | systems | `ItemsManager` |
| `professions` | 📜 Profesiones | systems | `ProfessionsManager` |
| `skills` | ✨ Habilidades | systems | `SkillsManager` |
| `synergies` | 🔗 Sinergias | systems | `SynergiesManager` |
| `shops` | 🛒 Tiendas | systems | `ShopsManager` |
| `events` | ⭐ Misiones/Eventos | story | `EventsManager` |
| `quests` | 📈 Estados/Quests | story | `QuestsManager` |
| `scenes` | 🎭 Escenas | story | `ScenesManager` |
| `cinematics` | 🎬 Cinemáticas | story | `CinematicsManager` |
| `achievements` | 🏆 Logros | meta | `AchievementsManager` |
| `config` | ⚙️ Config | balance | `ConfigManager` |
| `mediaLibrary` | 📁 Biblioteca de Medios | systems | `MediaLibrary` |

## Raíz / shell

### `app`
`editor/js/app.js` · 300 líneas · template: L201

Raíz de la SPA. Monta la topbar (proyecto, búsqueda global, guardar), la barra

- **secciones:** `─` L2, `─` L6
- **funcs:** `setup` L80, `pick` L91, `doSave` L92, `doReload` L93, `onSidebarAction` L98, `runGodot` L103, `handleDropFiles` L120, `setLang` L165

### `fs`
`editor/js/fs.js` · 250 líneas

Capa de acceso a datos vía el API HTTP del servidor de desarrollo (serve.py).

- **secciones:** `─` L2, `─` L8

- **exports:** `isSupported` L11, `hasProject` L26, `projectName` L31, `hasAssets` L36, `openProject` L44, `readJson` L66, `writeJson` L83, `listCollection` L109, `readCollectionItem` L120, `writeCollectionItem` L132, `deleteCollectionItem` L147, `listAssets` L158, `assetUrl` L177, `findAssetUrl` L186, `uploadAsset` L205, `processImage` L225, `deleteAsset` L241

### `nav`
`editor/js/nav.js` · 222 líneas

NAVEGACIÓN. Fuente ÚNICA de la metainformación de navegación:

- **secciones:** `─` L2, `─` L13, `4 MODOS PRINCIPALES DE JUEGO + SISTEMAS GLOBALES` L43, `Modo Datos: agrupado por los 4 Modos de Juego + Sistemas Globales` L109, `Modo Diseñador: áreas de trabajo correspondientes a los 4 Modos` L118, `Comandos rápidos de la Paleta (Task 5, modo `>`)` L170

- **exports:** `TAB_META` L21, `getTabLabel` L36, `ALL_TABS` L41, `GAME_MODES` L46, `DATA_GROUPS` L110, `DESIGNER_AREAS` L119, `pickName` L128, `entityName` L137, `goTo` L150, `requestNewEntity` L165, `COMMANDS` L174, `searchCommands` L192, `globalSearch` L203

### `store`
`editor/js/store.js` · 594 líneas

Estado reactivo central del editor (Vue 3 reactive). Contiene los tres

- **secciones:** `─` L2, `─` L7, `CONSTANTES DE DOMINIO (alineadas con el motor Godot)` L13, `ESTADO REACTIVO` L154, `UTILIDADES I18N GLOBALES (JERARQUÍA: en -> es -> any -> "")` L291, `ACCIONES` L345, `Documentos (un JSON único): [file, obj, dirtyKey]` L500, `Colecciones "un fichero por id": qué ids escribir` L507, `NAVEGACIÓN` L541

- **exports:** `terrainsList` L23, `terrainMap` L26, `resourcesList` L29, `ID_TYPES` L37, `WORLD_VISUALS` L42, `visualOptions` L59, `POI_KINDS` L62, `REWARD_TOKENS` L70, `FACETS` L91, `ELEMENTS` L100, `ENEMY_AI` L101, `ITEM_CATEGORIES` L102, `EQUIP_SLOTS` L103, `STAT_KEYS` L104, `COMBAT_KEYS` L105, `LOOT_KINDS` L106, `CONDITION_SNIPPETS` L109, `CONDITION_TOKENS` L132, `store` L155, `t` L287, `getI18nFallback` L300, `getI18n` L315, `getI18nDisplay` L324, `setI18n` L336, `markDirty` L347, `markDungeonDirty` L360, `ensureDungeonLoaded` L369, `markWorldDirty` L378, `syncActiveMap` L383, `switchMap` L389, `anyDirty` L408, `flash` L417, `openProject` L422, `reloadAll` L481, `save` L496, `nav` L549, `setNavMode` L562, `toggleSidebar` L563, `setExpandedArea` L564, `toggleExpertMode` L567, `applyCompact` L569, `pushRecent` L574, `isFavorite` L581, `toggleFavorite` L586
- **funcs:** `_defaultWorld` L398, `loadAll` L439, `_lsGet` L546, `_lsSet` L547

### `validator`
`editor/js/validator.js` · 1101 líneas

Validador de integridad (QA). Ejecuta comprobaciones en caliente sobre los

- **secciones:** `─` L2, `─` L8, `─` L59

- **exports:** `runValidation` L22, `itemRefsInNode` L1061, `bgCandidates` L1089
- **funcs:** `isGenericObject` L12, `hasItem` L169, `checkLootEntries` L173, `enemyExists` L211, `isBlocked` L401, `hasSkill` L508, `collectLoot` L622, `dfsEvents` L900
  `codeTokensInMiniLang` L941, `addUse` L957, `anyAssetMatch` L1098

## Componentes (editores por sistema)

### `AchievementsManager`
`editor/js/components/AchievementsManager.js` · 123 líneas · template: L72

Gestor de achievements.json (Fase G): logros por CONDICIÓN. Cada entrada es

- **secciones:** `─` L2, `─` L8

- **exports:** `default`(def) L28
- **funcs:** `setup` L31, `setField` L56

### `AmbienceManager`
`editor/js/components/AmbienceManager.js` · 230 líneas · template: L150

Gestor de ambience.json (Fase D): música y clima data-driven. NO es una

- **secciones:** `─` L2, `─` L9, `Música` L50, `Terreno → clima` L72, `Clima (partículas)` L87

- **exports:** `default`(def) L28
- **funcs:** `toMusicFile` L22, `toMusicRes` L23, `setup` L31, `touch` L37, `doSave` L38, `edit` L48, `musicOptionsFor` L56, `setMusic` L63
  `setMusicFile` L64, `renameMusic` L65, `addMusic` L69, `removeMusic` L70, `addTerrain` L75, `setTerrainWeather` L82, `setTerrainMusic` L83, `setTerrainMusicFile` L84
  `removeTerrain` L85, `addWeather` L89, `renameWeather` L90, `setWeatherField` L94, `removeWeather` L95, `setWeatherCanvas` L102, `ensureParticles` L103, `tickWeatherPreviews` L114

### `CinematicsManager`
`editor/js/components/CinematicsManager.js` · 504 líneas · template: L247

GESTOR DE CINEMÁTICAS — Carrusel de imágenes con textos multi-idioma.

- **secciones:** `─` L2, `─` L16

- **exports:** `default`(def) L36
- **funcs:** `setup` L39, `resolveBgUrl` L83, `selectSlide` L90, `addSlide` L96, `duplicateSlide` L113, `removeSlide` L123, `moveSlide` L136, `setSlideField` L146
  `setSlideSpeaker` L154, `setSlideText` L162, `setSlideFx` L170, `setTitle` L185, `setField` L191, `hasTextInLang` L197, `getSlideTextPreview` L203, `getSlideSpeakerPreview` L208
  `openSimulator` L214, `nextSimSlide` L220, `prevSimSlide` L229

### `CityWorkspace`
`editor/js/components/CityWorkspace.js` · 264 líneas · template: L144

WORKSPACE DE CIUDAD. Primer "Workspace vertical": una vista

- **secciones:** `─` L2, `─` L14, `Ciudades/aldeas` L28, `Edición de campos` L49, `Ubicación en el mapa` L57, `Edificios / POIs` L78, `Menú contextual de un edificio` L115

- **exports:** `default`(def) L19
- **funcs:** `setup` L21, `pickInitial` L39, `selectCity` L46, `touch` L47, `ensureBilingual` L50, `setName` L51, `setDesc` L52, `setIcon` L53
  `setVisual` L54, `findOnMap` L59, `gotoMap` L72, `ensureContent` L83, `addExisting` L84, `createAndAdd` L90, `removeBuilding` L99, `moveBuilding` L100
  `kindOf` L105, `toneFor` L106, `editPoi` L108, `editNpc` L109, `editShop` L110, `openCtx` L116

### `CombatSandboxModal`
`editor/js/components/CombatSandboxModal.js` · 542 líneas · template: L423

SANDBOX / SIMULADOR DE COMBATE TÁCTICO RPG (FASE 2)

- **secciones:** `─` L2, `─` L28, `Profesión y 4 huecos de habilidad equipada del héroe único` L68, `Estados alterados (subconjunto de GameConfig.STATUS_EFFECTS)` L172, `IA del héroe: elige qué de sus 4 habilidades equipadas usar` L209

- **exports:** `default`(def) L52
- **funcs:** `setup` L60, `skillDef` L73, `skillName` L74, `slotOptions` L87, `autoEquipDefaults` L94, `setEquipped` L104, `setProfession` L110, `getEnemyStats` L126
  `clamp` L141, `getHeroStats` L145, `elementalMult` L166, `statusDot` L173, `statusMult` L183, `statusSum` L188, `decrementStatuses` L193, `applyStatus` L196
  `tryApplySkillStatus` L201, `chooseHeroSkill` L210, `statForType` L223, `doHeroAction` L229, `doEnemyAction` L265, `runSimulation` L282, `onKey` L396

### `ConditionEditor`
`editor/js/components/ConditionEditor.js` · 187 líneas · template: L135

Constructor VISUAL de condiciones (Godot Expression que evalúa

- **secciones:** `─` L2, `─` L16

- **exports:** `default`(def) L77
- **funcs:** `atomRegexes` L25, `parseAtom` L38, `parseAll` L53, `serializeAtom` L67, `setup` L81, `serialize` L95, `commit` L99, `addAtom` L101
  `removeAtom` L112, `onAddSelect` L113, `toggleRawMode` L117, `onRawInput` L127

### `ConfigManager`
`editor/js/components/ConfigManager.js` · 333 líneas · plantilla → `templates/ConfigManagerTemplate.js`

Gestor de config.json: PARÁMETROS DE BALANCE del juego (los lee GameConfig.gd

- **secciones:** `─` L2, `─` L9, `BALANCE AVANZADO` L16

- **exports:** `default`(def) L243
- **funcs:** `setup` L246, `touch` L249, `doSave` L250, `edit` L254, `val` L257, `setField` L259, `dictVal` L267, `setDict` L272
  `overrideOf` L286, `fieldVal` L290, `isOverridden` L294, `setOverrideField` L297, `resetOverrideField` L310, `statusModFields` L320

### `DialoguesManager`
`editor/js/components/DialoguesManager.js` · 132 líneas · template: L73

Gestor de dialogues.json (Fase F): diálogos GUIONIZADOS (no ramificados como

- **secciones:** `─` L2, `─` L8

- **exports:** `default`(def) L14
- **funcs:** `setup` L17, `setField` L38, `setChoice` L46, `addChoice` L53, `removeChoice` L54, `getDialogueAvatar` L56

### `TexSwatchPicker`
`editor/js/components/DungeonEditor.js` · 2792 líneas · template: L122

EDITOR VISUAL DE MAZMORRAS (Tarea 3) — data-driven sobre `data/dungeons/<id>.json`

- **secciones:** `─` L2, `─` L20, `CATÁLOGO DE TIPOS DE CASILLA` L33, `CACHÉ de imágenes de TEXTURA REAL para las previsualizaciones` L69, `PALETA UNIFICADA POR TEMA (Fase 1/2, Task 5)` L402, `TASK 3 — ATMÓSFERA Y TEMÁTICA 3D` L419, `Estado de UI` L468, `Copiar/pegar regiones` L490, `Biblioteca de assets (Fase 6)` L566, `KITS DE OBJETOS INTELIGENTES` L574, `PALETA UNIFICADA POR TEMA (Fase 1/2, Task 5)` L614, `PREFABS DE SALAS COMPLETAS` L668, `Selectores de dominio` L739, `Constructores` L779, `TEXTURAS DE MAZMORRA (assets/dungeon/textures)` L790, `Historial (fotografía la mazmorra activa completa)` L948, `Gestión de mazmorras` L968, `Metadatos de la mazmorra` L1184, `TASK 3 — Atmósfera y Temática 3D` L1205, `Gestión de plantas` L1217, `Secciones colapsables del panel lateral izquierdo` L1246, `Redimensionado de mazmorra desde cualquier borde (con preview)` L1276, `PRESETS DE SALA (plantillas rápidas sobre la planta activa)` L1416, `Pintar / seleccionar casillas` L1502, `Mover casilla / enemigo seleccionada` L1602, `Copiar/pegar regiones` L1625, `Pincel: tipo suelto vs asset` L1850, `PROPS PERSONALIZADOS (import de modelos .glb)` L1909, `Cofre data-driven: oro + lista de objetos { id, qty }` L2009, `Salida al mundo (portal de salida data-driven)` L2043, `Entradas/salidas NOMBRADAS` L2069, `ELEMENTOS INTERACTIVOS con ESTADOS e IDs (Fase 6)` L2115, `PROBLEMAS DE ESTA MAZMORRA, EN VIVO` L2182, `Zoom y encuadre de la rejilla` L2297, `Estilos de la rejilla superior` L2326, `Preview 3D isométrica (canvas)` L2368, `PREVISUALIZACIÓN DE ITEM (una sola casilla, isométrica)` L2597, `Autoguardado + atajos` L2686

- **exports:** `default`(def) L440
- **funcs:** `loadTexImage` L76, `setup` L108, `swatchStyle` L109, `pick` L114, `onFile` L115, `tileCaps` L151, `set` L193, `onUpload` L199
  `askConfirm` L451, `onConfirmDialogConfirm` L457, `onConfirmDialogCancel` L463, `isInRect` L499, `rectInBounds` L509, `isInPastePreview` L516, `isLightEmitterCell` L527, `lightRadiusCellCount` L528
  `inLightRadius` L532, `rotatePendingOrientation` L543, `norm` L544, `selectKitPiece` L598, `pieceUsesElement` L607, `dismissPaletteNewBadge` L628, `isSectionOpen` L646, `_escapeHtml` L654
  `highlightMatch` L657, `toggleSection` L665, `collapseAllSections` L666, `expandAllSections` L667, `stampPrefab` L720, `enemySpriteUrl` L773, `blankFloor` L780, `loadDungeonTextures` L795
  `importDungeonTexture` L810, `templateRoomsDungeon` L827, `templateChasmDungeon` L866, `templateStandardDungeon` L905, `blankDungeon` L944, `snapshot` L949, `applyDun` L953, `doUndo` L961
  `doRedo` L962, `clampFloor` L964, `slugify` L969, `uniqueId` L973, `openCreateModal` L979, `onNewDunNameInput` L987, `templateBlankDungeon` L994, `submitCreateDungeon` L1029
  `createDungeon` L1063, `createDungeonWithTemplate` L1067, `duplicateDungeon` L1085, `deleteDungeon` L1102, `maybeSyncIds` L1124, `syncToIds` L1138, `goToMap` L1169, `setMeta` L1185
  `setName` L1191, `setPool` L1198, `toggleAtmo` L1207, `musicPreviewUrl` L1211, `setFogEnabled` L1215, `addFloor` L1218, `removeFloor` L1228, `renameFloor` L1239
  `selectFloor` L1244, `toggleDunSec` L1257, `collapseAllDunSections` L1260, `expandAllDunSections` L1263, `onSelectTemplate` L1267, `bump` L1289, `resetResize` L1290, `keptBounds` L1292
  `applyResize` L1331, `resizeFloor` L1394, `applyRoomPreset` L1427, `border` L1463, `beginStroke` L1503, `overCell` L1569, `endStroke` L1584, `moveSelectedCell` L1603
  `copyRegion` L1626, `rotateClipboardCW` L1647, `mirrorClipboardH` L1659, `clearRegionSel` L1664, `pasteAt` L1671, `applyDungeonFloodFill` L1701, `applyDungeonRectangle` L1759, `fillEntireFloor` L1798
  `paintCell` L1825, `selectCell` L1848, `brushConfigClean` L1852, `newBrushCell` L1862, `setBrushConfig` L1864, `selectTile` L1870, `pickCell` L1880, `selectAsset` L1897
  `clearAsset` L1898, `saveCurrentAsAsset` L1899, `uniqueTileId` L1922, `onPropFile` L1928, `importProp` L1937, `deleteProp` L1974, `setCellProp` L1992, `setTeleportTarget` L2001
  `setChestGold` L2010, `addChestItem` L2019, `removeChestItem` L2027, `setChestItem` L2035, `toggleExitTo` L2044, `setExitTo` L2051, `markSpawnHere` L2058, `isSpawn` L2066
  `addPortal` L2079, `removePortal` L2090, `setPortalSpawn` L2096, `setPortalHere` L2106, `isActuator` L2119, `isStateful` L2120, `stateOptionsFor` L2121, `setEid` L2148
  `setState` L2155, `addTarget` L2156, `removeTarget` L2163, `setTarget` L2170, `jumpToIssue` L2291, `clampZoom` L2302, `zoomBy` L2303, `fitToView` L2307
  `onWheelZoom` L2320, `cellStyle` L2334, `cellIcon` L2350, `cellTitle` L2360, `schedulePreview` L2370, `renderPreview` L2376, `proj` L2396, `cubeHeight` L2424
  `shade` L2435, `onTextureReady` L2450, `resolveSurfaceFill` L2462, `drawCube` L2484, `face` L2501, `poly` L2551, `previewCellData` L2603, `renderItemPreview` L2609
  `_drawStairsPreview` L2638, `scheduleItemPreview` L2650, `onKey` L2692

### `DungeonPiecesManager`
`editor/js/components/DungeonPiecesManager.js` · 724 líneas · template: L423

GESTOR UNIFICADO de todo lo COLOCABLE en el editor de mazmorras. Fusiona lo

- **secciones:** `─` L2, `─` L33, `CASILLAS (antes DungeonTilesManager)` L41, `PIEZAS DE KIT (antes DungeonKitsManager)` L71, `Colección real de CASILLAS (data/dungeon_tiles/<t>.json)` L130, `Colección real de PIEZAS de kit (dungeon_kits.json → pieces)` L148, `Kind activo (qué colección manda ahora mismo)` L169, `Lista fusionada + filtro/orden propios (no reutiliza list de useCollection: mezcla 2 colecciones)` L186, `Datos de la casilla/pieza activa` L244, `Renombrado con guardia para tipos de comportamiento FIJO` L270, `Campos de CASILLA (idéntico a DungeonTilesManager)` L295, `Campos de PIEZA de kit (idéntico a DungeonKitsManager)` L347, `Sub-editor de KITS (habilidades: kinetic_wave/psychic_grab/…)` L373

- **exports:** `default`(def) L126
- **funcs:** `rgbArrToHex` L60, `c` L62, `hexToRgbArr` L65, `defaultReaction` L97, `setup` L129, `kindOf` L176, `categoryOf` L181, `keyOf` L204
  `select` L218, `addTile` L224, `addPiece` L225, `_typingTarget` L252, `onKey` L256, `renameCurrent` L271, `removeCurrent` L283, `setTileField` L296
  `setTileNumberField` L297, `setTileBoolField` L298, `setShape` L299, `setRenderField` L307, `toggleLight` L308, `setLightColor` L316, `setLightField` L317, `refreshModelFiles` L321
  `openModelPicker` L322, `closeModelPicker` L323, `selectModelFile` L324, `onUploadModel` L325, `setPieceField` L349, `setPieceNameField` L350, `setArchetype` L351, `setMass` L360
  `setMotionField` L361, `setReactionField` L368, `setReactionNumberField` L369, `setReactionBoolField` L370, `setReactionVerbs` L371, `touchKits` L377, `addKit` L378, `removeKit` L385
  `renameKit` L392, `setKitField` L403, `setKitLabel` L404

### `DungeonWalkthroughModal`
`editor/js/components/DungeonWalkthroughModal.js` · 337 líneas · template: L308

MODO PASEO 3D EN PRIMERA PERSONA (Walkthrough Mode — FASE 3)

- **secciones:** `─` L2, `─` L8, `Audio` L88, `Bucle de Renderizado 3D (Raycasting en tiempo real)` L115

- **exports:** `default`(def) L34
- **funcs:** `resolveMusicUrl` L25, `setup` L43, `getCell` L69, `isSolid` L83, `startBgm` L89, `stopBgm` L101, `toggleMute` L109, `renderFrame` L116
  `onKeyDown` L249, `onKeyUp` L256

### `DungeonWizardModal`
`editor/js/components/DungeonWizardModal.js` · 184 líneas · template: L125

ASISTENTE DE CREACIÓN DE MAZMORRAS (Task 5, 2.4). Genera el layout inicial

- **secciones:** `─` L2, `─` L10

- **exports:** `default`(def) L50
- **funcs:** `slugify` L16, `uniqueId` L21, `buildLayout` L28, `setup` L54, `reset` L67, `next` L81, `back` L82, `finish` L84

### `EditorSidebar`
`editor/js/components/EditorSidebar.js` · 120 líneas · template: L52

SHELL DE NAVEGACIÓN. Barra lateral VERTICAL que sustituye a

- **secciones:** `─` L2, `─` L12

- **exports:** `default`(def) L17
- **funcs:** `setup` L20, `navTab` L24, `openArea` L25, `labelFor` L30, `iconFor` L31, `tabLabel` L32, `isActiveTab` L33, `goEntry` L34
  `isActiveEntry` L37

### `EditorToolbar`
`editor/js/components/EditorToolbar.js` · 47 líneas · template: L28

BARRA DE ACCIONES COMÚN a todos los editores (Tarea 4). Presenta de forma

- **secciones:** `─` L2, `─` L10

- **exports:** `default`(def) L11

### `EnemiesManager`
`editor/js/components/EnemiesManager.js` · 432 líneas · template: L251

Gestor de enemies.json: lista con buscador + filtro por elemento, formulario

- **secciones:** `─` L2, `─` L8, `Elementos débiles/resistentes (toggles)` L148, `Habilidades` L158, `Loot` L167, `Cálculo de escalado por nivel (para el slider)` L182

- **exports:** `GAME_ZONES` L43, `default`(def) L83
- **funcs:** `hpBase` L32, `atkBase` L33, `defBase` L34, `isBoss` L63, `getEnemyZone` L74, `zoneShortName` L78, `setup` L86, `setName` L144
  `setField` L145, `setNum` L146, `toggleTag` L149, `addSkill` L159, `removeSkill` L165, `addLoot` L168, `removeLoot` L174, `setLoot` L175
  `touch` L180, `proceduralStat` L184, `scaled` L194, `proceduralBarPct` L202, `skillUnlocked` L205, `enemySkillLabel` L217, `getEnemyRowSprite` L222

### `EnemySkillsManager`
`editor/js/components/EnemySkillsManager.js` · 257 líneas · template: L146

Gestor de enemy_skills.json (catálogo de habilidades de ENEMIGO). Cada entrada:

- **secciones:** `─` L2, `─` L13

- **exports:** `default`(def) L29
- **funcs:** `setup` L32, `setName` L65, `setField` L66, `setNum` L67, `setRole` L69, `toggleStatus` L85, `setStatus` L91, `setSelfStatus` L97

### `EntityListPanel`
`editor/js/components/EntityListPanel.js` · 99 líneas · template: L59

PANEL LATERAL COMÚN de lista de entidades (Tarea 4). Unifica en un solo

- **secciones:** `─` L2, `─` L21

- **exports:** `default`(def) L26
- **funcs:** `setup` L33, `rowIssue` L41

### `EventsManager`
`editor/js/components/EventsManager.js` · 220 líneas · template: L120

Pestaña ⭐ MISIONES / EVENTOS (Tarea 5). Edita dos ficheros data-driven:

- **secciones:** `─` L2, `─` L13, `EVENTOS (colección)` L28, `MISIÓN (quests.json, documento único)` L61

- **exports:** `default`(def) L22
- **funcs:** `setup` L25, `setField` L44, `addSnippet` L56, `qtouch` L66, `ensureQuests` L67, `qedit` L78, `addState` L79, `removeState` L87
  `moveState` L88, `addHook` L96, `setHookEvent` L104, `removeHook` L105, `saveQuests` L106

### `FirstStepsPanel`
`editor/js/components/FirstStepsPanel.js` · 89 líneas · template: L54

GUÍA DE PRIMEROS PASOS (Task 1 Fase 7). Cajón lateral con una checklist fija

- **secciones:** `─` L2, `─` L10

- **exports:** `default`(def) L31
- **funcs:** `loadDone` L15, `saveDone` L18, `setup` L35, `toggle` L37, `resetAll` L41, `go` L48

### `GlobalSearch`
`editor/js/components/GlobalSearch.js` · 92 líneas · template: L54

BÚSQUEDA GLOBAL. Paleta de comandos/búsqueda que recorre TODAS

- **secciones:** `─` L2, `─` L14

- **exports:** `default`(def) L18
- **funcs:** `setup` L22, `choose` L38, `onKeydown` L44, `flatIndex` L49, `commandIndex` L50

### `HelpDrawer`
`editor/js/components/HelpDrawer.js` · 85 líneas · template: L22

AYUDA CONTEXTUAL. Cajón lateral que muestra la ayuda de la

- **secciones:** `─` L2, `─` L6

- **exports:** `default`(def) L12
- **funcs:** `setup` L16

### `IdsManager`
`editor/js/components/IdsManager.js` · 726 líneas · template: L433

Gestor de ids.json: lista con buscador y filtro por tipo, formulario de

- **secciones:** `─` L2, `─` L7, `Campos con creación perezosa de subobjetos` L67, `Content builder` L199

- **exports:** `default`(def) L20
- **funcs:** `setup` L23, `ensureBilingual` L60, `touch` L65, `setName` L68, `setDesc` L69, `setField` L74, `setPortalField` L82, `setGateField` L102
  `toggleGate` L116, `setCinematic` L128, `setCinematicId` L150, `setCinematicLabel` L159, `setType` L167, `setVisual` L176, `setBg` L185, `toggleBg` L192
  `moveChild` L200, `removeChild` L207, `ensureContent` L208, `addExistingChild` L209, `createAndAddChild` L218, `childDef` L231, `linkOrCreateNpc` L249, `createTownTemplate` L266
  `addPresence` L328, `removePresence` L339, `updatePresence` L347, `getIdRowThumb` L401

### `ItemWizardModal`
`editor/js/components/ItemWizardModal.js` · 224 líneas · template: L124

ASISTENTE DE CREACIÓN DE OBJETOS (Task 5, 2.1). Modal guiado de 4 pasos que

- **secciones:** `─` L2, `─` L13

- **exports:** `default`(def) L48
- **funcs:** `uniqueItemId` L31, `slugify` L36, `suggestedPrice` L42, `setup` L52, `reset` L66, `setBonus` L80, `setCombat` L81, `next` L83
  `back` L84, `finish` L86

### `ItemsManager`
`editor/js/components/ItemsManager.js` · 239 líneas · template: L134

Gestor de items.json: lista con buscador + filtro por categoría, formulario

- **secciones:** `─` L2, `─` L8, `Preview de equipo: qué slot ocupa la pieza actual` L109

- **exports:** `default`(def) L21
- **funcs:** `setup` L24, `setName` L54, `setDesc` L55, `setField` L56, `setCategory` L58, `toggleUsable` L80, `setEffect` L87, `setBonus` L94
  `setCombat` L101, `getItemThumb` L115

### `MapEditor`
`editor/js/components/MapEditor.js` · 2123 líneas · plantilla → `templates/MapEditorTemplate.js`

Editor visual del mapamundi: rejilla width×height, paleta de terrenos, modo

- **secciones:** `─` L2, `─` L12, `Task 5 (5.1): herramienta MEDIR (regla Manhattan/Euclidiana)` L44, `Panel de paleta (segundo menú) redimensionable a mano, con memoria` L144, `Herramienta MOVER OBJETO` L501, `PINCEL DE TERRENO: tamaño (1x1/3x3/5x5) y suavizado de bordes` L841, `CAPAS VISUALES: Físicas/Transitabilidad y Clima/Ambiente (Pilar 1.2)` L912, `INICIO DEL PROTAGONISTA (data-driven `spawn` del mapa activo)` L947, `VIRTUALIZACIÓN de la rejilla (rendimiento en mundos grandes)` L979, `MINIMAPA interactivo (Pilar 1.1)` L1025, `ZOOM con la rueda del ratón usando Ctrl/Cmd. Sin Ctrl/Cmd permite scroll natural.` L1256, `PANEO con el botón central, derecho, herramienta mover mapa o Espacio` L1265, `Previews visuales para el Inspector de casilla` L1528, `Historial deshacer/rehacer (reutiliza el composable común)` L1846, `Autoguardado periódico` L1859, `Redimensionado del mundo desde cualquier borde (con preview)` L1862, `Duplicar entidad (ids.json) + sus NPCs e hijos de content` L1935, `Snapshots (puntos de restauración del mundo)` L1972, `Paneles / UI` L1989, `Atajos de teclado (solo con la pestaña Mapa activa)` L1999

- **exports:** `default`(def) L21
- **funcs:** `setup` L23, `isInRect` L35, `measureDown` L48, `measureMove` L49, `measureUp` L50, `regionNormalize` L64, `clearRegion` L67, `regionDown` L72
  `regionMove` L77, `regionUp` L78, `isInRegionSel` L79, `copyRegion` L84, `requestPasteRegion` L96, `pasteRegionAt` L101, `getEnemySpriteUrl` L119, `getTileEnemy` L129
  `onPaletteResizeDown` L152, `onPaletteResizeMove` L158, `onPaletteResizeUp` L164, `toggleInspector` L172, `goToTerrainEditor` L181, `goToNewTerrain` L187, `goToDungeon` L195, `slugifyDunId` L212
  `quickCreateDungeon` L216, `positionTooltip` L253, `getPoiNpcSprite` L278, `isPoiWithNpc` L332, `getPoiNpcSpriteUrl` L346, `getTilePoiNpc` L352, `tileAt` L405, `cellStyle` L409
  `cellGridStyle` L416, `objIcon` L436, `isGenericObject` L456, `removeObjectElsewhere` L462, `assignObject` L473, `setTool` L495, `isMoveSrc` L506, `handleMove` L507
  `terrainTextureUrl` L564, `applyBrush` L618, `applyMapFloodFill` L693, `applyRectangle` L778, `fillEntireMapTerrain` L821, `setBrushSize` L847, `toggleBrushSmooth` L848, `terrainBrushCells` L849
  `applyTerrainBrushArea` L864, `useEyedropper` L884, `setMapLayer` L922, `physicsOverlayColor` L923, `weatherOverlayColor` L935, `layerOverlayColor` L940, `isSpawn` L954, `setSpawn` L958
  `gotoSpawn` L966, `onScroll` L994, `syncViewport` L1000, `toggleMinimap` L1036, `scheduleMinimapDraw` L1041, `drawMinimap` L1045, `minimapGoTo` L1077, `onMinimapDown` L1093
  `onMinimapMove` L1099, `onMinimapUp` L1100, `centerMap` L1106, `centerViewOnSpawn` L1119, `zoomIn` L1123, `zoomOut` L1124, `resetZoom` L1125, `scrollMap` L1127
  `onCellDown` L1133, `onCellDblClick` L1170, `exportMapRender` L1188, `onCellEnter` L1218, `onCellMove` L1234, `onCellLeave` L1244, `stopPaint` L1245, `onWheel` L1257
  `onWrapDown` L1266, `onWrapMove` L1274, `onWrapUp` L1280, `hoverInfo` L1283, `setSelTerrain` L1382, `setSelObject` L1383, `clearCurrentTileItem` L1597, `startMoveCurrentItem` L1610
  `quickAddCity` L1629, `quickAddPoi` L1641, `quickAddDungeon` L1653, `quickAddResource` L1665, `quickCreateCity` L1677, `quickCreatePoi` L1692, `setInline` L1734, `addEnemy` L1746
  `addInteractive` L1764, `addObstacle` L1770, `addBlockedPath` L1782, `addChest` L1794, `setChestGold` L1801, `addChestItem` L1807, `removeChestItem` L1814, `setChestItem` L1820
  `removeInline` L1828, `setObstacleReward` L1832, `worldState` L1848, `applyWorld` L1849, `pushHistory` L1850, `ensureStrokeSnapshot` L1851, `clampSelection` L1852, `doUndo` L1856
  `doRedo` L1857, `bump` L1869, `resetResize` L1870, `keptBounds` L1873, `applyResize` L1906, `idExists` L1936, `npcExists` L1937, `uniqueKey` L1938
  `cloneNpc` L1944, `duplicateEntity` L1951, `restoreState` L1976, `createSnapshot` L1981, `importSnapshot` L1982, `snapDate` L1987, `selectMap` L1994, `onKey` L2000
  `onKeyUp` L2017

### `MediaLibrary`
`editor/js/components/MediaLibrary.js` · 238 líneas · template: L178

BIBLIOTECA GLOBAL DE MEDIOS / ASSET EXPLORER (Task 5, Fase 3). Explorador

- **secciones:** `─` L2, `─` L16, `Drag & Drop / subida` L82, `Procesado server-side (tools/process_image.py)` L110, `Espectro de audio en vivo (Web Audio API)` L136

- **exports:** `default`(def) L53
- **funcs:** `extOf` L51, `setup` L55, `reload` L64, `select` L80, `uploadFiles` L85, `onDrop` L104, `onFilePick` L108, `processSelected` L112
  `removeSelected` L125, `ensureAudioGraph` L140, `drawSpectrum` L151, `onAudioPlay` L167

### `NpcEditor`
`editor/js/components/NpcEditor.js` · 668 líneas · plantilla → `templates/NpcEditorTemplate.js`

Editor de npcs.json. Lista lateral de NPCs y, para el seleccionado, un flujo

- **secciones:** `─` L2, `─` L7, `Árbol de flujo: recorre desde la entrada; marca ciclos (retornos).` L128, `Estilo de la tarjeta de personaje según bg=r,g,b del _meta.reward` L167, `Edición de nodo` L198, `Helpers de creación fluida (1-clic) para el Modo Guión` L236, `Alta / baja de nodos y NPCs` L350, `NPC-level: duplicar / copiar / pegar (portapapeles común)` L396, `Eventos emitidos por el modo Grafo (NpcGraphEditor)` L429, `Autosave + guardado manual (Tarea 4, vía común)` L561, `Atajos de teclado comunes a nivel NPC` L569

- **exports:** `default`(def) L25
- **funcs:** `setup` L28, `isEmojiAvatarValue` L39, `getNpcPortrait` L45, `metaText` L74, `nodeCount` L75, `ensureMeta` L99, `walk` L134, `toggleCollapse` L153
  `rowHidden` L155, `touch` L183, `edit` L193, `selectNpc` L196, `setType` L199, `setText` L200, `setCondition` L206, `appendSnippet` L209
  `setReward` L212, `ensureNext` L215, `setNext` L216, `addNext` L217, `removeNext` L218, `gotoNode` L220, `isDeadEnd` L229, `nextBroken` L232
  `generateNodeId` L237, `appendNextMessage` L244, `appendChoices` L261, `addOptionToChoice` L302, `setSemanticDest` L324, `isForkNode` L338, `getChildOptions` L343, `addNode` L354
  `deleteNode` L363, `addNpc` L371, `deleteNpc` L384, `uniqueNpcId` L397, `duplicateNpc` L402, `copyNpc` L410, `pasteNpc` L416, `addMeta` L424
  `onGraphNodeUpdated` L434, `onGraphNodeAdded` L435, `onGraphNodeDeleted` L439, `setNpcAvatar` L464, `resetSimState` L490, `startSim` L492, `stopSim` L499, `restartSim` L500
  `condStatus` L505, `condLabel` L506, `applyNodeReward` L527, `simChoose` L534, `simText` L540, `simReward` L544, `simAddItem` L548, `simRemoveItem` L552
  `simAddFlag` L555, `simToggleFlag` L559, `saveNow` L567, `onKeydown` L570

### `NpcGraphEditor`
`editor/js/components/NpcGraphEditor.js` · 797 líneas · plantilla → `templates/NpcGraphEditorTemplate.js`

Modo GRAFO del editor de NPCs (Tarea 1). Canvas 2D nativo (sin librerías):

- **secciones:** `─` L2, `─` L11, `Constantes de layout / estilo` L21, `Utilidades de datos` L91, `Posiciones` L99, `Transformaciones mundo⇄pantalla` L160, `Búsqueda` L183, `Bucle de dibujo (RAF con bandera dirty)` L196, `Selección` L470, `Historial / mutaciones` L476, `Copiar / pegar / duplicar / eliminar` L505, `Zoom / encuadre` L546, `Detección de arista bajo el cursor (hover)` L577, `Ratón` L607, `Minimapa (clic/arrastre reposiciona el viewport)` L662, `Drawer de edición` L673, `Anotaciones del nodo (color/comentario/marcador/grupo) — Fase 7` L704, `Marcadores: menú desplegable para saltar a un nodo marcado` L724, `Teclado` L729, `Ciclo de vida` L749

- **exports:** `default`(def) L46
- **funcs:** `setup` L57, `nodeIds` L92, `getNode` L96, `getState` L97, `posMap` L100, `nodePos` L105, `computeLayout` L108, `ensurePositions` L134
  `computeLayers` L144, `toScreen` L161, `toWorld` L162, `nodeHeight` L164, `nodeRect` L171, `nodeAt` L173, `requestRedraw` L198, `fitCanvas` L205
  `draw` L214, `drawGrid` L242, `drawGroups` L254, `edgeColor` L280, `edgeEndpoints` L291, `drawEdge` L300, `drawArrowHead` L322, `clip` L330
  `drawNode` L335, `roundRect` L410, `roundRectTop` L416, `drawMinimap` L423, `canvasXY` L465, `selectOnly` L473, `toggleSel` L474, `mutate` L477
  `commitEdit` L484, `applyState` L490, `doUndo` L502, `doRedo` L503, `uniqueId` L506, `doCopy` L512, `doPaste` L513, `doDuplicate` L533
  `doDeleteSelected` L534, `zoomAt` L547, `onWheel` L553, `zoomButton` L554, `fitView` L555, `centerNode` L566, `onSearchEnter` L572, `bezierPt` L578
  `distToSeg` L582, `updateEdgeHover` L587, `onMouseDown` L608, `onMouseMove` L632, `onMouseUp` L654, `onDblClick` L659, `onContextMenu` L660, `onMinimapDown` L663
  `minimapPan` L664, `openDrawer` L675, `closeDrawer` L676, `dSetType` L677, `dSetText` L678, `dSetCondition` L679, `dAppendSnippet` L680, `dSetReward` L681
  `dEnsureNext` L682, `dSetNext` L683, `dAddNext` L684, `dRemoveNext` L685, `nextBroken` L686, `terminalBadge` L694, `annCommit` L707, `dSetColor` L713
  `dSetComment` L714, `dToggleBookmark` L715, `dSetGroup` L716, `dCreateGroup` L717, `jumpBookmark` L727, `isTyping` L730, `onKey` L734, `onKeyUp` L747

### `NpcPoiWizardModal`
`editor/js/components/NpcPoiWizardModal.js` · 210 líneas · template: L137

ASISTENTE ATÓMICO DE PNJ Y POI (Task 5, 2.2). En un solo flujo guiado:

- **secciones:** `─` L2, `─` L17

- **exports:** `default`(def) L33
- **funcs:** `slugify` L22, `uniqueId` L27, `setup` L37, `reset` L56, `next` L79, `back` L80, `finish` L82

### `ProfessionsManager`
`editor/js/components/ProfessionsManager.js` · 407 líneas · template: L215

Gestor de professions.json: lista de profesiones en barra lateral, formulario

- **secciones:** `─` L2, `─` L6, `Habilidades` L71, `Visualizador de curva de stats` L192

- **exports:** `default`(def) L14
- **funcs:** `setup` L17, `toggleCompact` L22, `touch` L45, `setName` L47, `setField` L48, `addSkill` L72, `removeSkill` L99, `moveSkill` L121
  `updateSkillField` L132, `toggleSkillStatus` L167, `updateSkillStatusField` L181

### `QaPanel`
`editor/js/components/QaPanel.js` · 182 líneas · template: L137

ASISTENTE DE QA. Cajón lateral con el diagnóstico de

- **secciones:** `─` L2, `─` L8

- **exports:** `default`(def) L59
- **funcs:** `fixHint` L54, `sectionOf` L55, `sectionLabel` L56, `sectionIcon` L57, `setup` L63, `run` L102, `jump` L117

### `QuestWizardModal`
`editor/js/components/QuestWizardModal.js` · 212 líneas · template: L135

ASISTENTE DE CREACIÓN DE MISIONES (Task 5, 2.3). Genera paso a paso una

- **secciones:** `─` L2, `─` L16

- **exports:** `default`(def) L40
- **funcs:** `slugify` L29, `newStage` L35, `setup` L45, `reset` L54, `addStage` L66, `removeStage` L67, `setRewardStr` L68, `next` L75
  `back` L76, `finish` L108

### `QuestsManager`
`editor/js/components/QuestsManager.js` · 110 líneas · template: L64

Gestor de quests.json: NO es una colección `{id->entidad}`, sino un documento

- **secciones:** `─` L2, `─` L10, `order` L40, `combat_victory` L46

- **exports:** `default`(def) L17
- **funcs:** `setup` L20, `touch` L29, `doSave` L30, `edit` L34, `setOrder` L41, `addOrder` L42, `removeOrder` L43, `moveOrder` L44
  `addHook` L48, `renameHook` L55, `setHookEvent` L56, `removeHook` L57

### `RewardEditor`
`editor/js/components/RewardEditor.js` · 114 líneas · template: L79

Editor asistido del mini-lenguaje de recompensas (";"-separado). Parsea el

- **secciones:** `─` L2, `─` L6

- **exports:** `default`(def) L48
- **funcs:** `parse` L13, `serializeTok` L41, `setup` L52, `serialize` L60, `commit` L61, `addTok` L63, `removeTok` L70, `onAddSelect` L72

### `ScenesManager`
`editor/js/components/ScenesManager.js` · 227 líneas · plantilla → `templates/ScenesManagerTemplate.js`

EDITOR UNIFICADO DE ESCENAS — Sistema Narrativo.

- **secciones:** `─` L2, `─` L20, `Lista de nodos de la escena actual (ordenada, entry primero)` L73, `CRUD de nodos` L102, `Opciones de un nodo choice` L167, `Ramas de un flow branch` L186

- **exports:** `default`(def) L42
- **funcs:** `setup` L45, `selectNode` L89, `setMeta` L91, `setEntry` L100, `uniqueNodeId` L103, `addNode` L109, `removeNode` L117, `renameNode` L120
  `setKind` L132, `setNodeField` L145, `setFx` L157, `addOption` L168, `removeOption` L175, `setOption` L176, `addBranch` L187, `removeBranch` L194
  `setBranch` L195, `nodeKindMeta` L203, `nodeSummary` L204

### `ShopsManager`
`editor/js/components/ShopsManager.js` · 137 líneas · template: L75

Gestor de shops.json: catálogos de tienda data-driven (Tarea 5, Fase C).

- **secciones:** `─` L2, `─` L7

- **exports:** `default`(def) L14
- **funcs:** `setup` L17, `itemName` L39, `itemIcon` L44, `addLine` L46, `removeLine` L53, `moveLine` L57, `setLineId` L67, `setLinePrice` L68

### `SkillsManager`
`editor/js/components/SkillsManager.js` · 219 líneas · template: L120

Gestor de skills.json: habilidades de combate. Cada entrada es

- **secciones:** `─` L2, `─` L9

- **exports:** `default`(def) L25
- **funcs:** `setup` L28, `setField` L54, `setNum` L65, `toggleStatus` L71, `setStatus` L77

### `SynergiesManager`
`editor/js/components/SynergiesManager.js` · 108 líneas · template: L60

Gestor de synergies.json: combos de habilidades. El documento es

- **secciones:** `─` L2, `─` L8

- **exports:** `default`(def) L14
- **funcs:** `setup` L17, `touch` L25, `doSave` L26, `edit` L30, `skillName` L38, `skillMissing` L45, `add` L47, `remove` L48
  `setProfession` L49, `setResult` L50, `setReq` L51, `addReq` L52, `removeReq` L53

### `VnAssetPicker`
`editor/js/components/VnAssetPicker.js` · 347 líneas · template: L278

Selector visual de assets para Novela Visual & Narrativa:

- **secciones:** `─` L2, `─` L7

- **exports:** `default`(def) L188
- **funcs:** `setup` L198, `resolvePreviewUrl` L230, `selectAsset` L251, `applyCustom` L257, `openModal` L263

### `VnSimulatorModal`
`editor/js/components/VnSimulatorModal.js` · 411 líneas · template: L311

EMULADOR INTERACTIVO DE NOVELA VISUAL & NARRATIVA (WYSIWYG en Vivo).

- **secciones:** `─` L2, `─` L12, `Control de Audio` L91, `Avance del Typewriter` L127, `Ejecución de Operaciones de Estado (ops)` L160, `Carga y Proceso de Nodo` L185

- **exports:** `default`(def) L17
- **funcs:** `setup` L27, `playSfx` L92, `startBgm` L101, `stopBgm` L113, `toggleMute` L121, `startTypewriter` L128, `completeTypewriter` L149, `applyOps` L161
  `loadNode` L186, `onAdvance` L221, `chooseOption` L237, `checkAutoAdvance` L247, `toggleAuto` L255, `restart` L260, `closeModal` L267, `onKey` L274

### `WelcomePanel`
`editor/js/components/WelcomePanel.js` · 123 líneas · template: L54

Panel de INICIO / IDE Hub.

- **secciones:** `─` L2, `─` L6

- **exports:** `default`(def) L11
- **funcs:** `setup` L13, `getModeStat` L29

### `WorldBuildingsManager`
`editor/js/components/WorldBuildingsManager.js` · 381 líneas · template: L209

Gestor de EDIFICIOS-ASSET del mapamundi (data/world_buildings/<code>.json),

- **secciones:** `─` L2, `─` L16, `PICKER DE ESCENA` L29, `MAQUETAS CLÁSICAS` L34, `Picker de escena y modelo 3D (.tscn / .glb / .obj)` L112

- **exports:** `default`(def) L53
- **funcs:** `setup` L56, `touchClassic` L63, `classicStyle` L64, `classicField` L65, `setClassicField` L69, `setClassicScale` L74, `resetClassic` L75, `isClassicOverridden` L80
  `setField` L107, `setNumberField` L108, `isReserved` L110, `refreshSceneFiles` L117, `refreshModelFiles` L118, `openScenePicker` L119, `closeScenePicker` L120, `openModelPicker` L121
  `closeModelPicker` L122, `selectSceneFile` L123, `selectModelFile` L127, `onUploadModel` L131, `autoImportAssets` L170

### `WorldResourcesManager`
`editor/js/components/WorldResourcesManager.js` · 262 líneas · template: L142

Gestor de RECURSOS FARMEABLES del mapamundi (data/world_resources/<code>.json),

- **secciones:** `─` L2, `─` L15, `Picker y subida de modelos 3D (.glb / .obj)` L100

- **exports:** `default`(def) L53
- **funcs:** `setup` L56, `setField` L84, `setNumberField` L85, `setBoolField` L86, `itemMissing` L87, `refreshModelFiles` L103, `openModelPicker` L104, `closeModelPicker` L105
  `selectModelFile` L106, `onUploadModel` L110

### `WorldTerrainsManager`
`editor/js/components/WorldTerrainsManager.js` · 358 líneas · template: L186

Gestor de TERRENOS del mapamundi (data/world_terrains/<code>.json), colección

- **secciones:** `─` L2, `─` L13, `Variantes (sub-biomas aleatorios con peso)` L76, `Textura del terreno: preview + subir nueva (PNG) + elegir existente` L97

- **exports:** `default`(def) L41
- **funcs:** `setup` L44, `setField` L72, `setNumberField` L73, `setBoolField` L74, `addVariant` L77, `removeVariant` L83, `setVariantField` L84, `setUvScroll` L89
  `textureFileFor` L102, `refreshTextureFiles` L111, `openTexturePicker` L112, `closeTexturePicker` L113, `selectTexture` L114, `terrainUsing` L119, `deleteTexture` L125, `onUploadTexture` L140
  `getTerrainThumb` L169

### `WorldTransformsManager`
`editor/js/components/WorldTransformsManager.js` · 357 líneas · template: L161

Gestor de world_transforms.json (Fase B): transformaciones del MUNDO. Cada

- **secciones:** `─` L2, `─` L9

- **exports:** `default`(def) L35
- **funcs:** `setup` L38, `isBuiltin` L57, `setDesc` L59, `toggleBuiltin` L60, `setBuiltin` L67, `addRule` L69, `removeRule` L70, `setMatchField` L74
  `hasMatchCoord` L80, `toggleMatchCoord` L84, `setMatchCoord` L90, `setSet` L97, `walkableValue` L106, `setWalkable` L110, `addSpawnPoiRule` L118, `addRemovePoiRule` L124
  `setCinematic` L135, `advancedSetText` L140, `setAdvancedSet` L144

## Plantillas Markup (js/components/templates)

### `ConfigManagerTemplate`
`editor/js/components/templates/ConfigManagerTemplate.js` · 124 líneas

Plantilla (markup Vue) extraída de ConfigManager.js.

- **exports:** `default`(def) L5

### `DungeonEditorTemplate`
`editor/js/components/templates/DungeonEditorTemplate.js` · 868 líneas

Plantilla (markup Vue) extraída de DungeonEditor.js.

- **exports:** `default`(def) L5

### `MapEditorTemplate`
`editor/js/components/templates/MapEditorTemplate.js` · 670 líneas

Plantilla (markup Vue) extraída de MapEditor.js.

- **exports:** `default`(def) L5

### `NpcEditorTemplate`
`editor/js/components/templates/NpcEditorTemplate.js` · 451 líneas

Plantilla (markup Vue) extraída de NpcEditor.js.

- **exports:** `default`(def) L5

### `NpcGraphEditorTemplate`
`editor/js/components/templates/NpcGraphEditorTemplate.js` · 100 líneas

Plantilla (markup Vue) extraída de NpcGraphEditor.js.

- **exports:** `default`(def) L5

### `ScenesManagerTemplate`
`editor/js/components/templates/ScenesManagerTemplate.js` · 244 líneas

Plantilla (markup Vue) extraída de ScenesManager.js.

- **exports:** `default`(def) L5

## Composables / lógica común (js/lib)

### `dungeonConstants`
`editor/js/lib/dungeonConstants.js` · 46 líneas

Constantes de mazmorra compartidas entre DungeonEditor.js y

- **secciones:** `─` L2, `─` L6

- **exports:** `WALL_TYPES` L10, `FLOOR_TEX` L11, `ENV_THEME_OPTIONS` L17, `ENV_SKY_OPTIONS` L33, `ENV_VOID_OPTIONS` L41

### `helpContent`
`editor/js/lib/helpContent.js` · 167 líneas

AYUDA CONTEXTUAL. Registro de textos de ayuda por pestaña.

- **secciones:** `─` L2, `─` L8

- **exports:** `GLOBAL_SHORTCUTS` L11, `HELP` L18, `helpFor` L165

### `integrity`
`editor/js/lib/integrity.js` · 38 líneas

Heurística GENÉRICA y barata para el badge amarillo "⚡ Incompleto" en

- **secciones:** `─` L2, `─` L9

- **exports:** `assessIncomplete` L26
- **funcs:** `isEmptyText` L14

### `qaIndex`
`editor/js/lib/qaIndex.js` · 54 líneas

Índice de integridad en CACHÉ para los badges rojos "⚠️ Error" de

- **secciones:** `─` L2, `─` L8

- **exports:** `refreshQaIndex` L15, `startQaIndexAutoRefresh` L46, `stopQaIndexAutoRefresh` L51

### `snapshots`
`editor/js/lib/snapshots.js` · 101 líneas

Composable REUTILIZABLE de "snapshots" (puntos de restauración) de un estado

- **secciones:** `─` L2, `─` L14

- **exports:** `useSnapshots` L20
- **funcs:** `loadList` L28, `persist` L32, `create` L38, `restore` L51, `remove` L58, `rename` L59, `exportSnapshot` L62, `importFromFile` L76

### `useAutosave`
`editor/js/lib/useAutosave.js` · 75 líneas

Composable REUTILIZABLE de autoguardado periódico. Cada `intervalMs` comprueba

- **secciones:** `─` L2, `─` L13

- **exports:** `useAutosave` L19
- **funcs:** `flush` L46, `start` L63, `stop` L69

### `useClipboard`
`editor/js/lib/useClipboard.js` · 50 líneas

PORTAPAPELES INTERNO COMPARTIDO entre todos los editores del backoffice

- **secciones:** `─` L2, `─` L14

- **exports:** `useClipboard` L29
- **funcs:** `_load` L19, `_clone` L27, `copy` L31, `canPaste` L37, `read` L42

### `useCollection`
`editor/js/lib/useCollection.js` · 263 líneas

COMPOSABLE MAESTRO de los editores de COLECCIÓN (Tarea 4). Unifica en un solo

- **secciones:** `─` L2, `─` L19, `Estado de búsqueda / filtro / orden` L54, `Acceso a la colección y a la selección` L62, `Lista filtrada + ordenada: [{ id, o }]` L70, `Historial` L96, `Ids únicos` L127, `CRUD (todas fotografían antes de mutar)` L134, `Copiar / Pegar (portapapeles compartido)` L194, `Autoguardado + indicador` L216, `Atajos de teclado (solo cuando esta pestaña está activa)` L228

- **exports:** `useCollection` L49
- **funcs:** `toggleSortDir` L93, `select` L94, `snapshot` L97, `_restore` L98, `undo` L114, `redo` L115, `edit` L118, `touch` L125
  `uniqueId` L128, `add` L135, `duplicate` L145, `remove` L159, `rename` L174, `copy` L195, `paste` L201, `_isDirtyNow` L219
  `doSave` L226, `_typingTarget` L229, `onKey` L233

### `useDialogueSim`
`editor/js/lib/useDialogueSim.js` · 160 líneas

SIMULACIÓN DE DIÁLOGO. Reproduce en el editor —lo más fielmente

- **secciones:** `─` L2, `─` L14, `Evaluación de condiciones` L31, `Aplicación de recompensas` L85

- **exports:** `defaultSimState` L17, `evalCondition` L44, `applyReward` L95, `summarizeReward` L156
- **funcs:** `toJsExpr` L33, `pint` L86, `clampi` L87

### `useDocumentHistory`
`editor/js/lib/useDocumentHistory.js` · 48 líneas

Deshacer/rehacer (Task 5, 1.3) para editores de UN SOLO DOCUMENTO (no una

- **secciones:** `─` L2, `─` L8

- **exports:** `useDocumentHistory` L23
- **funcs:** `snapshot` L28, `edit` L30, `undo` L35, `redo` L36, `onKey` L38

### `useDungeonAssets`
`editor/js/lib/useDungeonAssets.js` · 83 líneas

BIBLIOTECA DE ASSETS DE MAZMORRA. Un "asset" es una casilla

- **secciones:** `─` L2, `─` L13, `Estructura` L24, `Luz y ambiente` L29, `Decoración activa` L32, `Peligros` L37, `Tesoro y accesos` L40

- **exports:** `BUILTIN_ASSETS` L23, `useDungeonAssets` L57
- **funcs:** `readUser` L45, `writeUser` L49, `_persist` L60, `saveFromCell` L63, `remove` L76, `rename` L77

### `useHistory`
`editor/js/lib/useHistory.js` · 68 líneas

Composable REUTILIZABLE de deshacer/rehacer por instantáneas (snapshots JSON).

- **secciones:** `─` L2, `─` L14

- **exports:** `deepClone` L18, `useHistory` L26
- **funcs:** `push` L35, `undo` L45, `redo` L55, `clear` L62

### `useNpcAnnotations`
`editor/js/lib/useNpcAnnotations.js` · 93 líneas

ANOTACIONES DE DIÁLOGO. Metadatos de AUTORÍA para el grafo de

- **secciones:** `─` L2, `─` L17, `Colores` L39, `Comentarios` L46, `Marcadores (bookmarks)` L53, `Grupos` L62

- **exports:** `ensureEditor` L20, `getColor` L40, `setColor` L41, `getComment` L47, `setComment` L48, `isBookmarked` L54, `toggleBookmark` L55, `bookmarks` L60, `groups` L63, `groupOf` L64, `createGroup` L70, `setNodeGroup` L77, `renameGroup` L81, `setGroupColor` L85, `removeGroup` L89
- **funcs:** `readEditor` L35

## Design System (js/ui)

### `DsAudioBtn`
`editor/js/ui/DsAudioBtn.js` · 127 líneas · template: L120

Botón interactivo para reproducir/escuchar cualquier pista de audio

- **secciones:** `─` L2, `─` L5

- **exports:** `stopAllGlobalAudio` L11, `default`(def) L23
- **funcs:** `setup` L30, `resolveUrl` L35, `togglePlay` L51, `stop` L96

### `DsBadge`
`editor/js/ui/DsBadge.js` · 22 líneas · template: L17

DESIGN SYSTEM · Insignia (Fase 1). Contador o indicador de estado compacto,

- **secciones:** `─` L2, `─` L9

- **exports:** `default`(def) L10

### `DsBreadcrumb`
`editor/js/ui/DsBreadcrumb.js` · 29 líneas · template: L16

DESIGN SYSTEM · Migas de pan (Fase 1). Ruta de navegación jerárquica, pensada

- **secciones:** `─` L2, `─` L9

- **exports:** `default`(def) L10

### `DsCard`
`editor/js/ui/DsCard.js` · 38 líneas · template: L22

DESIGN SYSTEM · Tarjeta (Fase 1). Contenedor con cabecera opcional (título,

- **secciones:** `─` L2, `─` L10

- **exports:** `default`(def) L11

### `DsConfirmDialog`
`editor/js/ui/DsConfirmDialog.js` · 32 líneas · template: L23

DESIGN SYSTEM · Diálogo de confirmación (Fase 1). Sustituye a los window.confirm

- **secciones:** `─` L2, `─` L8

- **exports:** `default`(def) L11

### `DsContextMenu`
`editor/js/ui/DsContextMenu.js` · 71 líneas · template: L56

DESIGN SYSTEM · Menú contextual (Fase 1). Menú flotante posicionado en (x,y),

- **secciones:** `─` L2, `─` L14

- **exports:** `default`(def) L17
- **funcs:** `setup` L26, `reposition` L30, `onDocClick` L43, `onKey` L44, `choose` L48

### `DsEmpty`
`editor/js/ui/DsEmpty.js` · 25 líneas · template: L17

DESIGN SYSTEM · Estado vacío (Fase 1). Placeholder consistente para "no hay

- **secciones:** `─` L2, `─` L9

- **exports:** `default`(def) L10

### `DsField`
`editor/js/ui/DsField.js` · 29 líneas · template: L19

DESIGN SYSTEM · Campo de formulario (Fase 1). Envoltorio consistente para un

- **secciones:** `─` L2, `─` L9

- **exports:** `default`(def) L10

### `DsFilterPanel`
`editor/js/ui/DsFilterPanel.js` · 43 líneas · template: L32

DESIGN SYSTEM · Panel de filtros (Fase 1). Renderiza un conjunto de selectores

- **secciones:** `─` L2, `─` L11

- **exports:** `default`(def) L12
- **funcs:** `anyActive` L20, `optValue` L23, `optLabel` L24, `set` L25, `clear` L26

### `DsGallery`
`editor/js/ui/DsGallery.js` · 156 líneas · template: L62

DESIGN SYSTEM · Galería / documentación viva (Fase 1). Muestra cada componente

- **secciones:** `─` L2, `─` L8

- **exports:** `default`(def) L11
- **funcs:** `setup` L15, `openCtx` L57

### `DsHelpDialog`
`editor/js/ui/DsHelpDialog.js` · 62 líneas · template: L27

DESIGN SYSTEM · Ayuda contextual (Fase 1). Ventana integrada (no documento

- **secciones:** `─` L2, `─` L16

- **exports:** `default`(def) L19

### `DsInspector`
`editor/js/ui/DsInspector.js` · 32 líneas · template: L18

DESIGN SYSTEM · Inspector contextual (Fase 1). Panel (normalmente a la derecha)

- **secciones:** `─` L2, `─` L9

- **exports:** `default`(def) L10

### `DsModal`
`editor/js/ui/DsModal.js` · 56 líneas · template: L40

DESIGN SYSTEM · Modal base (Fase 1). Overlay reutilizable que sirve de cimiento

- **secciones:** `─` L2, `─` L15

- **exports:** `default`(def) L18
- **funcs:** `setup` L28, `onKey` L29, `onBackdrop` L32

### `DsPalette`
`editor/js/ui/DsPalette.js` · 82 líneas · template: L56

DESIGN SYSTEM · Paleta seleccionable (Fase 1). Lista vertical de opciones con

- **secciones:** `─` L2, `─` L15

- **exports:** `default`(def) L19
- **funcs:** `setup` L31, `isActive` L42, `pick` L43

### `DsSearchInput`
`editor/js/ui/DsSearchInput.js` · 34 líneas · template: L24

DESIGN SYSTEM · Campo de búsqueda (Fase 1). Input con icono de lupa y botón de

- **secciones:** `─` L2, `─` L8

- **exports:** `default`(def) L11
- **funcs:** `setup` L19

### `DsSplitPanel`
`editor/js/ui/DsSplitPanel.js` · 65 líneas · template: L58

DESIGN SYSTEM · Panel dividido redimensionable (Fase 1). Dos zonas (slots

- **secciones:** `─` L2, `─` L13

- **exports:** `default`(def) L16
- **funcs:** `setup` L25, `onDown` L34, `onMove` L40, `onUp` L48

### `DsTag`
`editor/js/ui/DsTag.js` · 35 líneas · template: L28

DESIGN SYSTEM · Etiqueta (Fase 1). Pastilla pequeña para clasificar (tipo,

- **secciones:** `─` L2, `─` L10

- **exports:** `default`(def) L11
- **funcs:** `style` L23

### `DsToolbar`
`editor/js/ui/DsToolbar.js` · 29 líneas · template: L18

DESIGN SYSTEM · Toolbar genérica (Fase 1). Barra horizontal reutilizable con

- **secciones:** `─` L2, `─` L10

- **exports:** `default`(def) L11

### `DsTreeNode`
`editor/js/ui/DsTree.js` · 74 líneas · template: L32

DESIGN SYSTEM · Árbol (Fase 1). Vista de árbol genérica y recursiva a partir de

- **secciones:** `─` L2, `─` L13

- **exports:** `default`(def) L54
- **funcs:** `setup` L25, `hasChildren` L30, `onSelect` L64

### `DsVirtualList`
`editor/js/ui/DsVirtualList.js` · 80 líneas · template: L71

DESIGN SYSTEM · Lista virtualizada.

- **secciones:** `─` L2, `─` L19

- **exports:** `default`(def) L22
- **funcs:** `setup` L30, `onScroll` L36, `measure` L37

### `index`
`editor/js/ui/index.js` · 58 líneas

DESIGN SYSTEM · Registro central (Fase 1). Punto único que agrupa TODOS los

- **secciones:** `─` L2, `─` L10

- **exports:** `DESIGN_SYSTEM` L33, `registerDesignSystem` L45

## Otros

### `collections`
`editor/js/collections.js` · 118 líneas

FUENTE ÚNICA de las pestañas y colecciones editables del editor.

- **secciones:** `─` L2, `─` L44, `Mundo` L47, `Personajes` L72, `Objetos y sistemas` L76, `Historia` L82, `Progresión` L87, `Balance` L89, `Medios (Task 5, Fase 3)` L91, `Derivados de conveniencia` L107

- **exports:** `TABS` L46, `EXTRA_DOCS` L101, `DOC_COLLECTIONS` L109, `PERID_COLLECTIONS` L111, `TAB_COMPONENT` L113, `resolvePath` L116

### `i18n`
`editor/js/i18n.js` · 828 líneas

INTERNACIONALIZACIÓN DE LA INTERFAZ DEL EDITOR (UI i18n).

- **secciones:** `─` L2, `─` L7

- **exports:** `UI_TRANSLATIONS` L9, `t` L819

## Secciones de `styles.css`

`editor/styles.css` · 2817 líneas. Secciones:

- **Botones** · L118
- **Topbar** · L145
- **Selector de Idioma HUD** · L174
- **Layout general** · L264
- **Pantalla de bienvenida** · L270
- **MAPA** · L285
- **Listas / tablas genéricas** · L375
- **NPC / diálogo por bloques** · L452
- **QA panel** · L485
- **Toast / error** · L505
- **Modal** · L509
- **TEMA "CYBERPUNK RPG" — acentos neón, glassmorphism y micro-animaciones** · L525
- **Layout genérico de gestores (Enemigos / Objetos)** · L549
- **Selector de textura (WorldTerrainsManager): preview + subir/elegir** · L592
- **MapEditor: zoom, paneo y tooltip** · L677
- **MapEditor: capa visual (overlay sobre cada celda virtualizada)** · L714
- **MapEditor: contenedor viewport y minimapa HUD** · L717
- **MapEditor: selector de tamaño de pincel y capas (paleta)** · L752
- **Inicio del protagonista (spawn) + selector de mapa (real/debug)** · L770
- **Lista virtualizada (DsVirtualList)** · L775
- **Tabla compacta de habilidades (Profesiones · )** · L781
- **T3 — Pincel único, cabecera de NPC, simulador y árbol de flujo** · L797
- **T1 — Modo GRAFO del editor de NPCs (canvas interactivo)** · L862
- **T2 — Editor de mundo profesional (barra, redimensionar, snapshots)** · L883
- **T3 — Editor visual de MAZMORRAS (rejilla cenital + preview 3D)** · L919
- **T4 — Librería común: barra de acciones + panel de lista uniformes** · L1085
- **Pestaña Misiones/Eventos (Tarea 5)** · L1238
- **DESIGN SYSTEM — biblioteca de componentes reutilizables.** · L1253
- **Modal base** · L1267
- **Help dialog** · L1294
- **Card** · L1306
- **Tag** · L1325
- **Badge** · L1335
- **Toolbar genérica** · L1343
- **Inspector** · L1351
- **Search input** · L1358
- **Filter panel** · L1365
- **Field** · L1370
- **Empty state** · L1380
- **Palette** · L1387
- **Context menu** · L1398
- **Split panel** · L1409
- **Breadcrumb** · L1424
- **Tree** · L1432
- **Gallery (documentación viva del Design System)** · L1444
- **SHELL DE NAVEGACIÓN — barra lateral vertical + búsqueda** · L1451
- **WORKSPACE DE CIUDAD — vista orientada a la tarea.** · L1523
- **Ayuda contextual + asistente de QA + modo compacto (Fase 8)** · L1548
- **Guía de primeros pasos (FirstStepsPanel.js, Fase 7)** · L1555
- **Editor de NPCs · anotaciones del grafo (Fase 7)** · L1603
- **Editor de mazmorras · biblioteca de assets (Fase 6)** · L1615
- **Editor de mapa · herramientas de responsabilidad única (Fase 4)** · L1624
- **Indicador de referencia rota (id que no existe en su catálogo)** · L1644
- **Panel de INICIO / IDE Hub (4 Modos de Juego + Sistemas Globales)** · L1648
- **DsPalette: Miniaturas de Texturas y Badges de Terreno** · L1709
- **MapEditor: Previsualizador de Casilla e Inspector de Cualidades** · L1717
- **MapEditor: Tarjeta de Item/Contenido en Casilla** · L1739
- **MapEditor Inspector: previsualización de sprites / fondos** · L1760
- **MapEditor: Accesos Rápidos de Casilla Vacía** · L1809
- **ESTUDIO DE NOVELA VISUAL & SIMULADOR EN VIVO (FASE 1)** · L1823
- **VnAssetPicker: Selectores Visuales** · L2142
- **DsAudioBtn: Botón de Audio en Vivo** · L2324
- **FASE 2: COMBAT SANDBOX & BALANCE SIMULATOR** · L2346
- **FASE 3: MODO PASEO 3D EN MAZMORRAS** · L2480
- **FASE 5: BOTÓN GODOT & DROPZONE UNIVERSAL** · L2542
- **CINEMÁTICAS & CARRUSEL DE FINALES** · L2585

