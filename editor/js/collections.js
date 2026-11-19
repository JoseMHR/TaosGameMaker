// collections.js
// ─────────────────────────────────────────────────────────────────────────────
// FUENTE ÚNICA de las pestañas y colecciones editables del editor.
// Antes esta información estaba REPARTIDA y DUPLICADA entre store.js (loadAll,
// save, markDirty, anyDirty, selección inicial), nav.js (TAB_META) y app.js
// (imports + switch de render). Añadir/editar una colección obligaba a tocar ~8
// sitios coordinados ("escopeta quirúrgica"). Ahora TODO se DERIVA de esta tabla:
//
//   · nav.js       → TAB_META (label/icon/group/sel/coll/workspace)
//   · store.js     → loadAll / save / markDirty / anyDirty / selección inicial
//   · app.js       → registro y render dinámico del editor activo
//
// Módulo PURO: no importa store/nav/app (para no crear ciclos). Guarda el nombre
// del componente como STRING; app.js lo mapea a su módulo importado.
//
// Cómo AÑADIR un editor nuevo:
//   1) crea el componente en js/components/<Nombre>.js
//   2) impórtalo en app.js y añádelo a `components: { ... }`
//   3) añade UNA fila a TABS aquí (con su kind/storeKey/file|endpoint/dirty)
//   4) si es colección "un fichero por id", regístrala en serve.py
//      (ALLOWED_COLLECTIONS) y añade su mapa `dirtyX` y prop `selectedX`/`storeKey`
//      al `store` reactivo de store.js.
//   5) `node tools/check_editor.mjs` y `python tools/gen_editor_codemap.py`.
//
// Campos de cada entrada:
//   key        — id de pestaña (store.activeTab) y clave de TAB_META.
//   label,icon,group — metadatos de navegación.
//   component  — NOMBRE del componente Vue (registrado en app.js).
//   workspace? — true para vistas-workspace (cityWorkspace).
//   kind       — 'doc' (un JSON único) | 'perId' (carpeta un-fichero-por-id) |
//                undefined (pestaña sin persistencia propia: map/cityWorkspace).
//   storeKey   — propiedad del `store` reactivo donde vive el dato.
//   file       — (kind 'doc') nombre del JSON en data/.
//   endpoint   — (kind 'perId') nombre de la colección en serve.py.
//   dirtyKey   — (kind 'doc') clave booleana en store.dirty.
//   dirtyMap   — (kind 'perId') nombre del mapa { id: true } en store.
//   sel        — (editores de diccionario) prop de selección en store.
//   collPath   — (editores de diccionario) ruta punteada desde store al dict
//                (por defecto = storeKey; dungeonKits usa 'dungeonKits.pieces').
//   default    — valor por defecto si el fichero no existe.
//   required   — (kind 'doc') si true, su carga NO se captura (falla dura).
//   lazy       — (kind 'perId') el listado inicial es un RESUMEN; el contenido
//                completo se pide bajo demanda (mazmorras).
// ─────────────────────────────────────────────────────────────────────────────

export const TABS = [
	// ── Mundo ────────────────────────────────────────────────────────────────
	{ key: 'map', label: 'Mapa', icon: '🗺️', group: 'world', component: 'MapEditor' },
	{ key: 'cityWorkspace', label: 'Ciudades', icon: '🏙️', group: 'world', workspace: true, component: 'CityWorkspace' },
	{ key: 'ids', label: 'Entidades', icon: '📦', group: 'world', component: 'IdsManager', kind: 'perId', endpoint: 'ids', storeKey: 'ids', dirtyMap: 'dirtyIds', sel: 'selectedId', default: {} },
	{ key: 'dungeons', label: 'Mazmorras', icon: '🏰', group: 'world', component: 'DungeonEditor', kind: 'perId', endpoint: 'dungeons', storeKey: 'dungeons', dirtyMap: 'dirtyDungeons', sel: 'selectedDungeon', default: {}, lazy: true },
	{ key: 'ambience', label: 'Ambiente', icon: '🌦️', group: 'world', component: 'AmbienceManager', kind: 'doc', file: 'ambience.json', storeKey: 'ambience', dirtyKey: 'ambience', default: {} },
	{ key: 'worldTransforms', label: 'Transformaciones', icon: '🌍', group: 'world', component: 'WorldTransformsManager', kind: 'doc', file: 'world_transforms.json', storeKey: 'worldTransforms', dirtyKey: 'worldTransforms', sel: 'selectedWorldTransform', default: {} },
	{ key: 'worldBuildings', label: 'Edificios (assets)', icon: '🏗️', group: 'world', component: 'WorldBuildingsManager', kind: 'perId', endpoint: 'world_buildings', storeKey: 'worldBuildings', dirtyMap: 'dirtyWorldBuildings', sel: 'selectedWorldBuilding', default: {} },
	{ key: 'worldTerrains', label: 'Terrenos', icon: '🗺️', group: 'world', component: 'WorldTerrainsManager', kind: 'perId', endpoint: 'world_terrains', storeKey: 'worldTerrains', dirtyMap: 'dirtyWorldTerrains', sel: 'selectedWorldTerrain', default: {} },
	{ key: 'worldResources', label: 'Recursos (mapa)', icon: '🌲', group: 'world', component: 'WorldResourcesManager', kind: 'perId', endpoint: 'world_resources', storeKey: 'worldResources', dirtyMap: 'dirtyWorldResources', sel: 'selectedWorldResource', default: {} },
	// `dungeonPieces` es la pantalla FUSIONADA (Task: "Kits/Tipos de casilla
	// confusos") que lista TODO lo colocable en una mazmorra: casillas de
	// comportamiento fijo (dungeonTiles), cosméticas (dungeonTiles con render
	// genérico) y piezas de Objeto Inteligente (dungeonKits.pieces), con la
	// categoría de cada una a la vista. No tiene persistencia propia (no
	// `kind`, como `map`/`cityWorkspace`): sigue leyendo/escribiendo de las
	// DOS colecciones reales de abajo, que se mantienen registradas (con
	// `component` apuntando aquí también) para que la carga/guardado de
	// `data/dungeon_tiles/*.json` y `dungeon_kits.json` no se toque, y para
	// que enlaces antiguos (búsqueda global, recientes, favoritos) sigan
	// aterrizando en la pantalla correcta en vez de en las dos pantallas
	// viejas ya retiradas de la navegación.
	{ key: 'dungeonPieces', label: 'Piezas de mazmorra', icon: '🧩', group: 'world', component: 'DungeonPiecesManager' },
	{ key: 'dungeonTiles', label: 'Tipos de casilla', icon: '🧱', group: 'world', component: 'DungeonPiecesManager', kind: 'perId', endpoint: 'dungeon_tiles', storeKey: 'dungeonTiles', dirtyMap: 'dirtyDungeonTiles', sel: 'selectedDungeonTile', default: {} },
	{ key: 'dungeonKits', label: 'Kits (Obj. Inteligente)', icon: '🧩', group: 'world', component: 'DungeonPiecesManager', kind: 'doc', file: 'dungeon_kits.json', storeKey: 'dungeonKits', dirtyKey: 'dungeonKits', sel: 'selectedKitPiece', collPath: 'dungeonKits.pieces', default: {} },
	// ── Personajes ─────────────────────────────────────────────────────────────
	{ key: 'npcs', label: 'NPCs', icon: '💬', group: 'people', component: 'NpcEditor', kind: 'perId', endpoint: 'npcs', storeKey: 'npcs', dirtyMap: 'dirtyNpcs', sel: 'selectedNpc', default: {} },
	{ key: 'enemies', label: 'Enemigos', icon: '👾', group: 'people', component: 'EnemiesManager', kind: 'perId', endpoint: 'enemies', storeKey: 'enemies', dirtyMap: 'dirtyEnemies', sel: 'selectedEnemy', default: {} },
	{ key: 'enemySkills', label: 'Skills de enemigo', icon: '☄️', group: 'people', component: 'EnemySkillsManager', kind: 'doc', file: 'enemy_skills.json', storeKey: 'enemySkills', dirtyKey: 'enemySkills', sel: 'selectedEnemySkill', default: {} },
	// ── Objetos y sistemas ──────────────────────────────────────────────────────
	{ key: 'items', label: 'Objetos', icon: '🎒', group: 'systems', component: 'ItemsManager', kind: 'perId', endpoint: 'items', storeKey: 'items', dirtyMap: 'dirtyItems', sel: 'selectedItem', default: {} },
	{ key: 'professions', label: 'Profesiones', icon: '📜', group: 'systems', component: 'ProfessionsManager', kind: 'doc', file: 'professions.json', storeKey: 'professions', dirtyKey: 'professions', sel: 'selectedProfession', required: true },
	{ key: 'skills', label: 'Habilidades', icon: '✨', group: 'systems', component: 'SkillsManager', kind: 'doc', file: 'skills.json', storeKey: 'skills', dirtyKey: 'skills', sel: 'selectedSkill', required: true },
	{ key: 'synergies', label: 'Sinergias', icon: '🔗', group: 'systems', component: 'SynergiesManager', kind: 'doc', file: 'synergies.json', storeKey: 'synergies', dirtyKey: 'synergies', default: { synergies: [] } },
	{ key: 'shops', label: 'Tiendas', icon: '🛒', group: 'systems', component: 'ShopsManager', kind: 'doc', file: 'shops.json', storeKey: 'shops', dirtyKey: 'shops', sel: 'selectedShop', default: {} },
	// ── Historia ─────────────────────────────────────────────────────────────────
	{ key: 'events', label: 'Misiones/Eventos', icon: '⭐', group: 'story', component: 'EventsManager', kind: 'doc', file: 'events.json', storeKey: 'events', dirtyKey: 'events', sel: 'selectedEvent', default: {} },
	{ key: 'quests', label: 'Estados/Quests', icon: '📈', group: 'story', component: 'QuestsManager', kind: 'doc', file: 'quests.json', storeKey: 'quests', dirtyKey: 'quests', default: { order: [], combat_victory: {} } },
	{ key: 'scenes', label: 'Escenas', icon: '🎭', group: 'story', component: 'ScenesManager', kind: 'perId', endpoint: 'scenes', storeKey: 'scenes', dirtyMap: 'dirtyScenes', sel: 'selectedScene', default: {} },
	{ key: 'cinematics', label: 'Cinemáticas', icon: '🎬', group: 'story', component: 'CinematicsManager', kind: 'perId', endpoint: 'cinematics', storeKey: 'cinematics', dirtyMap: 'dirtyCinematics', sel: 'selectedCinematic', default: {} },
	// ── Progresión ─────────────────────────────────────────────────────────────
	{ key: 'achievements', label: 'Logros', icon: '🏆', group: 'meta', component: 'AchievementsManager', kind: 'doc', file: 'achievements.json', storeKey: 'achievements', dirtyKey: 'achievements', sel: 'selectedAchievement', default: {} },
	// ── Balance ─────────────────────────────────────────────────────────────────
	{ key: 'config', label: 'Config', icon: '⚙️', group: 'balance', component: 'ConfigManager', kind: 'doc', file: 'config.json', storeKey: 'config', dirtyKey: 'config', default: {} },
	// ── Medios (Task 5, Fase 3) ──────────────────────────────────────────────────
	// Sin persistencia propia (no es un documento ni una colección): navega
	// directamente los ficheros de assets/ vía fs.js (listAssets/uploadAsset/...).
	{ key: 'mediaLibrary', label: 'Biblioteca de Medios', icon: '📁', group: 'systems', component: 'MediaLibrary' },
];

// ── Documentos persistidos SIN pestaña propia (se cargan/guardan pero no tienen
//    editor dedicado en la barra). Se tratan como 'doc' en store.js. ──────────
//    Nota: `world`/`world_test` NO están aquí: tienen manejo ESPECIAL en store.js
//    (dos holders worldReal/worldDebug y un puntero `store.world`).
export const EXTRA_DOCS = [
	{ file: 'world_buildings_classic.json', storeKey: 'worldBuildingsClassic', dirtyKey: 'worldBuildingsClassic', default: {} },
	{ file: 'dialogues.json', storeKey: 'dialogues', dirtyKey: 'dialogues', default: {} },
	{ file: 'tutorials.json', storeKey: 'tutorials', dirtyKey: 'tutorials', default: {} },
];

// ── Derivados de conveniencia ────────────────────────────────────────────────
/** Todas las entradas que persisten como 'doc' (con o sin pestaña). */
export const DOC_COLLECTIONS = TABS.filter(t => t.kind === 'doc').concat(EXTRA_DOCS);
/** Todas las colecciones "un fichero por id". */
export const PERID_COLLECTIONS = TABS.filter(t => t.kind === 'perId');
/** Mapa key→componente (nombre) para el render dinámico. */
export const TAB_COMPONENT = Object.fromEntries(TABS.map(t => [t.key, t.component]));

/** Resuelve una ruta punteada ('a.b.c') sobre un objeto (para collPath). */
export function resolvePath(obj, path) {
	return path.split('.').reduce((o, k) => (o == null ? o : o[k]), obj);
}
