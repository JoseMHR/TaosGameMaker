// store.js
// ─────────────────────────────────────────────────────────────────────────────
// Estado reactivo central del editor (Vue 3 reactive). Contiene los tres
// documentos de diseño en memoria, metadatos de UI y utilidades compartidas
// (constantes de terreno/tipo, gramática de recompensas). Coordina carga,
// guardado y marcado de cambios sin guardar.
// ─────────────────────────────────────────────────────────────────────────────
import { reactive } from 'https://unpkg.com/vue@3/dist/vue.esm-browser.prod.js';
import * as FS from './fs.js';
import { TABS, DOC_COLLECTIONS, PERID_COLLECTIONS } from './collections.js';
import { t as i18nT, UI_TRANSLATIONS } from './i18n.js';

// ─── CONSTANTES DE DOMINIO (alineadas con el motor Godot) ────────────────────

// Terrenos y recursos del mapamundi: YA NO son constantes hardcodeadas. Cada
// código vive en su propio fichero `data/world_terrains/<code>.json` /
// `data/world_resources/<code>.json` (colecciones "un fichero por id", como
// `dungeon_tiles`), cargado por `loadAll()` en `store.worldTerrains` /
// `store.worldResources`. Estos helpers derivan la MISMA forma que antes
// (array ordenado / mapa por código) para no tocar los componentes que los
// consumen; llámalos siempre DENTRO de un `computed()` (o al vuelo tras
// cargar el proyecto), nunca los cachees en una constante de módulo.
export function terrainsList() {
	return Object.values(store.worldTerrains || {}).sort((a, b) => (a.order ?? 0) - (b.order ?? 0));
}
export function terrainMap() {
	return Object.fromEntries(terrainsList().map(t => [t.code, t]));
}
export function resourcesList() {
	return Object.values(store.worldResources || {}).sort((a, b) => (a.order ?? 0) - (b.order ?? 0));
}

// Tipos de entidad de ids.json.
// Se unificaron `village`→`city` y `house`→`poi`; el aspecto visual concreto
// (maqueta lowpoly) se elige por separado con el campo `visual` (ver WORLD_VISUALS),
// para no perder la variedad visual en el mundo.
export const ID_TYPES = ['city', 'dungeon', 'poi', 'forest', 'rock', 'cattle', 'fish'];

// Aspecto visual en el mundo por tipo lógico. El `value` es la clave de maqueta
// que consume el motor (CellResource.item → malla en TabWorld3D). Extensible: para
// añadir una maqueta nueva basta con sumar una opción aquí (y su rama en el motor).
export const WORLD_VISUALS = {
	city: [
		{ value: 'ciudad', label: 'Ciudad (lowpoly)' },
		{ value: 'aldea', label: 'Aldea (lowpoly)' },
	],
	poi: [
		{ value: 'place', label: 'Lugar (genérico)' },
		{ value: 'casita', label: 'Casita (lowpoly)' },
		{ value: 'templo', label: 'Templo (lowpoly)' },
	],
	dungeon: [
		{ value: 'cueva', label: 'Cueva (lowpoly)' },
		{ value: 'ruinas', label: 'Ruinas (lowpoly)' },
	],
};

/** Opciones de visual disponibles para un tipo (o [] si el tipo no las usa). */
export function visualOptions(type) { return WORLD_VISUALS[type] || []; }

// `kind` para POIs hijos de ciudad/aldea.
export const POI_KINDS = ['tavern', 'church', 'shop', 'npc', ''];

// Gramática del mini-lenguaje de recompensas (ver Design.gd _apply_token).
//   value: 'none'  -> token sin valor (heal, dam)
//   value: 'int'   -> gold:±N, xp:N, relation:±N
//   value: 'facet' -> faceta:KEY=±N
//   value: 'item'  -> item:ID=N  /  -item:ID=N
//   value: 'str'   -> flag:x, questf:x, quests:x, prof:x, qaction:x
export const REWARD_TOKENS = [
	{ key: 'gold',     value: 'int',   hint: 'Oro (+/-)' },
	{ key: 'xp',       value: 'int',   hint: 'Experiencia' },
	{ key: 'heal',     value: 'none',  hint: 'Curación total' },
	{ key: 'faceta',   value: 'facet', hint: 'Faceta de personalidad ±N' },
	{ key: 'item',     value: 'item',  hint: 'Dar objeto' },
	{ key: '-item',    value: 'item',  hint: 'Quitar objeto' },
	{ key: 'flag',     value: 'str',   hint: 'Marcar flag del NPC' },
	{ key: 'relation', value: 'int',   hint: 'Afinidad con el NPC (+/-)' },
	{ key: 'questf',   value: 'str',   hint: 'Avanzar misión (forward)' },
	{ key: 'quests',   value: 'str',   hint: 'Fijar estado de misión' },
	{ key: 'prof',     value: 'str',   hint: 'Desbloquear/fijar profesión' },
	{ key: 'dam',      value: 'none',  hint: 'Abrir la presa' },
	{ key: 'qaction',  value: 'str',   hint: 'Acción de misión' },
	{ key: 'gflag',    value: 'str',   hint: 'Flag global de historia (=0 desactiva)' },
	{ key: 'worldt',   value: 'str',   hint: 'Transformar mundo (dam_opened/cave_cleared/monkey_cleared)' },
	{ key: 'combat',   value: 'str',   hint: 'Combate: id[:lvl[:boss]]' },
	{ key: 'event',    value: 'str',   hint: 'Ejecutar otro evento' },
	{ key: 'dialogue', value: 'str',   hint: 'Mostrar un diálogo con guion' },
	{ key: 'cine',     value: 'str',   hint: 'Reproducir una cinemática' },
];
export const FACETS = ['valor', 'bondad', 'aspecto', 'inteligencia', 'cordura'];

// Elementos de combate (enemigos: `element`, `weak_to`, `resist`; también skills).
// UNIÓN de todos los valores que aparecen en data/ (enemies/*.json y
// enemy_skills.json): `element` usa physical/fire/ice/lightning/poison/none +
// earth (golem) + wind (hada); `weak_to`/`resist` añaden water y holy. Antes la
// lista omitía wind/earth/water/holy, así que el desplegable de elemento no podía
// representar a golem/hada y los toggles de débil/resiste no ofrecían water/holy.
// Si el motor añade un elemento nuevo, súmalo aquí.
export const ELEMENTS = ['physical', 'fire', 'water', 'ice', 'lightning', 'wind', 'earth', 'poison', 'holy', 'none'];
export const ENEMY_AI = ['aggressive', 'defensive', 'caster'];
export const ITEM_CATEGORIES = ['consumable', 'equipment', 'important', 'other'];
export const EQUIP_SLOTS = ['weapon', 'shield', 'armor', 'helmet', 'shoes', 'accessory'];
export const STAT_KEYS = ['str', 'agi', 'vit', 'int', 'dex', 'luk'];
export const COMBAT_KEYS = ['phys_damage', 'mag_damage', 'range_damage', 'phys_defense', 'mag_defense'];
export const LOOT_KINDS = ['gold', 'resource', 'consumable', 'equipment', 'item'];

// Fragmentos habituales para el asistente de condiciones (Godot Expression).
export const CONDITION_SNIPPETS = [
	'has_flag("FLAG")',
	'no_flag("FLAG")',
	'visits >= N',
	'relation >= N',
	'valor >= N',
	'bondad >= N',
	'aspecto >= N',
	'inteligencia >= N',
	'cordura >= N',
	'quest("001") == N',
	'has_item("ID")',
];

// Catálogo del CONSTRUCTOR VISUAL de condiciones (ConditionEditor.js), reflejo
// EXACTO de la gramática que evalúa Design.eval_condition() (Godot Expression):
// variables sueltas (_COND_VARS) y funciones invocables (has_flag/no_flag/...).
// `kind` decide cómo se pinta/parsea/serializa cada átomo (ver ConditionEditor.js):
//   - 'fnStr'    : función(string) -> bool                      → has_flag("X")
//   - 'fnCmpNum' : función(string) OP número                    → quest_stage("X") >= N
//   - 'varCmpNum': variable OP número                           → cordura >= N
//   - 'varCmpStr': variable OP "texto"                          → quest == "estado"
const OPS_NUM = ['>=', '<=', '==', '!=', '>', '<'];
export const CONDITION_TOKENS = [
	{ key: 'has_flag', label: 'Tiene flag de NPC', kind: 'fnStr', argHint: 'nombre_flag' },
	{ key: 'no_flag', label: 'NO tiene flag de NPC', kind: 'fnStr', argHint: 'nombre_flag' },
	{ key: 'gflag', label: 'Flag global de historia activo', kind: 'fnStr', argHint: 'nombre_flag' },
	{ key: 'no_gflag', label: 'Flag global de historia NO activo', kind: 'fnStr', argHint: 'nombre_flag' },
	{ key: 'has_item', label: 'Tiene objeto en el inventario', kind: 'fnStr', argHint: 'item_id' },
	{ key: 'no_item', label: 'NO tiene objeto en el inventario', kind: 'fnStr', argHint: 'item_id' },
	{ key: 'has_quest', label: 'Misión secundaria iniciada', kind: 'fnStr', argHint: 'quest_id' },
	{ key: 'quest_done', label: 'Misión secundaria completada', kind: 'fnStr', argHint: 'quest_id' },
	{ key: 'quest_stage', label: 'Fase de misión secundaria', kind: 'fnCmpNum', argHint: 'quest_id', ops: OPS_NUM },
	{ key: 'stat', label: 'Estadística del jugador (kills/level/xp/gold/job_level)', kind: 'fnCmpNum', argHint: 'kills', ops: OPS_NUM },
	{ key: 'quest', label: 'Estado de la misión PRINCIPAL', kind: 'varCmpStr', ops: ['==', '!='] },
	{ key: 'relation', label: 'Relación con el NPC', kind: 'varCmpNum', ops: OPS_NUM },
	{ key: 'visits', label: 'Nº de visitas al NPC', kind: 'varCmpNum', ops: OPS_NUM },
	{ key: 'gold', label: 'Oro del jugador', kind: 'varCmpNum', ops: OPS_NUM },
	{ key: 'valor', label: 'Faceta: Valor', kind: 'varCmpNum', ops: OPS_NUM },
	{ key: 'bondad', label: 'Faceta: Bondad', kind: 'varCmpNum', ops: OPS_NUM },
	{ key: 'aspecto', label: 'Faceta: Aspecto', kind: 'varCmpNum', ops: OPS_NUM },
	{ key: 'inteligencia', label: 'Faceta: Inteligencia', kind: 'varCmpNum', ops: OPS_NUM },
	{ key: 'cordura', label: 'Faceta: Cordura', kind: 'varCmpNum', ops: OPS_NUM },
];

// ─── ESTADO REACTIVO ─────────────────────────────────────────────────────────
export const store = reactive({
	supported: FS.isSupported,
	projectName: '',
	hasAssets: false,
	loaded: false,
	loading: false,
	dirty: { world: false, worldTest: false, professions: false, skills: false, enemySkills: false, synergies: false, events: false, quests: false, shops: false, ambience: false, dialogues: false, achievements: false, tutorials: false, worldTransforms: false, config: false, dungeonKits: false },
	// Mazmorras / entidades del mapamundi / NPCs / enemigos: COLECCIONES "un
	// fichero por id" (data/dungeons/<id>.json, data/ids/<id>.json,
	// data/npcs/<id>.json, data/enemies/<id>.json), no un documento único, así
	// que su "sucio" se rastrea por id, no con un booleano global. Ver
	// markDirty(which, id?) / markDungeonDirty(id) / ensureDungeonLoaded(id) / save().
	dirtyDungeons: {},   // { event_id: true }
	dirtyIds: {},         // { entity_id: true }
	dirtyWorldBuildings: {}, // { code: true }
	dirtyNpcs: {},        // { npc_id: true }
	dirtyEnemies: {},     // { enemy_id: true }
	dirtyItems: {},       // { item_id: true } (data/items/<id>.json)
	dirtyScenes: {},      // { scene_id: true } (data/scenes/<id>.json)
	dirtyCinematics: {},  // { cinematic_id: true } (data/cinematics/<id>.json)
	dirtyDungeonTiles: {},   // { t: true }
	dirtyWorldTerrains: {},  // { code: true }
	dirtyWorldResources: {}, // { code: true }
	error: '',
	toast: '',
	// Índice de integridad en caché para los badges de EntityListPanel.js
	// (Task 5, 1.2): { [tab]: { [id]: { level:'error'|'warning', messages:[] } } }.
	// Se recalcula en segundo plano; ver lib/qaIndex.js.
	qaIndex: {},

	// Documentos en memoria.
	world: null,   // MAPA ACTIVO en edición (referencia a worldReal o worldDebug).
	// Los dos mapamundis editables. `world` apunta SIEMPRE a uno de estos:
	//   worldReal  ↔ world.json      (mapa real; inicio normal del protagonista)
	//   worldDebug ↔ world_test.json (mapa debug/Sala de Tests; inicio en modo debug)
	worldReal: null,
	worldDebug: null,
	activeMap: 'real',   // 'real' | 'debug' — cuál se está editando ahora.
	ids: null,     // { id: {...} } — colección "un fichero por id" (data/ids/<id>.json), cargada COMPLETA
	npcs: null,    // { npc: { node: {...} } } — colección "un fichero por id" (data/npcs/<npc_id>.json), cargada COMPLETA
	enemies: null, // { id: { base_*, *_scale, skills[], loot[] } } — colección "un fichero por id" (data/enemies/<id>.json), cargada COMPLETA
	items: null,   // { id: { name, desc, icon, category, usable, ... } }
	professions: null, // { id: { name, icon, color, skills[] } }
	skills: null,  // { id: { id, name, desc, icon, type, ... } }
	enemySkills: null, // { id: { name, role, power_mult, type, element, status?, self_status? } } — habilidades de enemigo (enemy_skills.json), referenciadas por skill_id en enemies/*.json
	// { event_id: preview|full }. Al cargar el proyecto solo se trae un RESUMEN
	// por id ({name?, boss?, floors:N}); el contenido completo (floors[] real)
	// se trae perezosamente con ensureDungeonLoaded(id) al seleccionar una mazmorra.
	dungeons: null,
	dungeonKits: null, // { kits:{...}, pieces:{...} } — catálogo de piezas de Objeto Inteligente. CRUD completo.
	dungeonTiles: null, // { t: { label, icon, color, group, order, solid?, entity?, ..., render? } } — colección "un fichero por id" (data/dungeon_tiles/<t>.json). CRUD completo.
	worldTerrains: null, // { code: { label, color, icon, biome_color, order, description?, walkable?, ..., variants? } } — colección "un fichero por id" (data/world_terrains/<code>.json). CRUD completo.
	worldResources: null, // { code: { label, icon, biome_color, order, description?, placeable?, skill?, item?, capacity? } } — colección "un fichero por id" (data/world_resources/<code>.json). CRUD completo.
	events: null,  // { event_id: { desc?, condition?, actions:[token] } }
	quests: null,  // { order:[estado], combat_victory:{ enemy_id:{ event } } }
	shops: null,   // { stock_id: [ { id, price } ] } — catálogos de tienda data-driven
	ambience: null,   // { music, terrain, weather } — música/clima data-driven (Fase D)
	dialogues: null,  // { dialogue_id: { npc_name, npc_avatar, text, choices[] } } (Fase F)
	scenes: null,     // { scene_id: { meta?, entry, nodes:{ id:{kind,...} } } } — Sistema Narrativo
	cinematics: null, // { cinematic_id: { id, title, music, slides: [...] } } — Cinemáticas (carrusel de imágenes con texto)
	achievements: null, // { ach_id: { name, desc, icon, condition, reward } } (Fase G)
	tutorials: null,  // { tut_id: { name, steps[] } } — tutoriales por condición (Fase G)
	synergies: null,  // { synergies: [ { profession, required_ids[], result_id } ] } — combos de skills
	worldTransforms: null, // { transform_id: { desc, rules[] | builtin } } — transformaciones de mundo (Fase B)
	worldBuildings: null, // { code: { label, icon, scene, scale?, y_offset?, description? } } — colección "un fichero por id" (data/world_buildings/<code>.json), CRUD completo desde el editor (a diferencia de worldTerrains/worldResources, que son solo lectura): permite añadir un edificio nuevo sin GDScript
	config: null,     // { CLAVE: valor } — parámetros de balance (GameConfig.gd los lee con fallback)
	worldBuildingsClassic: null, // { code: { wall_color?, roof_color?, scale? } } — override visual OPCIONAL de las 8 maquetas cableadas (ciudad/aldea/casita/templo/cueva/ruinas/presa)

	// Selección/UI compartida entre pestañas. Arranca en el panel de INICIO
	// (onboarding B5, WelcomePanel): "¿qué quieres editar?" en vez de caer directo
	// en el mapa. 'home' es un caso especial resuelto en app.js (no es colección).
	activeTab: 'home',
	// Pincel del mapa: herramientas de responsabilidad única.
	//   tool: 'terrain' | 'resource' | 'entity' | 'erase' | 'spawn'
	//   cada herramienta tiene su PROPIA selección para no mezclar estados:
	//   terrain (código de terreno), resource (recurso genérico), entity (id de ids.json).
	// : arranca en 'select' (solo inspecciona, nunca pinta) para que
	// nadie modifique el mapa sin querer por olvidarse de cambiar de herramienta.
	brush: { tool: 'select', terrain: 'grs', resource: 'forest', entity: '', entityCat: 'all', enemy: 'slime_01', size: 1, smooth: false },
	// Capa visual del Mapamundi Studio: 'biome' (color de terreno, por defecto),
	// 'physics' (overlay de transitabilidad: caminable/agua/bloqueado/resbaladizo)
	// o 'weather' (overlay de clima/ambiente asignado por terreno en ambience.json).
	mapLayer: 'biome',
	selectedCell: null,   // {x,y}
	selectedId: null,     // clave de ids.json
	selectedNpc: null,    // clave de npcs.json
	selectedEnemy: null,  // clave de enemies.json
	selectedItem: null,   // clave de items.json
	selectedProfession: null, // clave de professions.json
	selectedDungeon: null, // clave (event_id) de data/dungeons/<id>.json
	selectedEvent: null,   // clave (event_id) de events.json
	selectedShop: null,    // clave (stock_id) de shops.json
	selectedAchievement: null, // clave (ach_id) de achievements.json
	selectedTutorial: null,    // clave (tut_id) de tutorials.json
	selectedDialogue: null,    // clave (dialogue_id) de dialogues.json
	selectedScene: null,       // clave (scene_id) de scenes.json (Sistema Narrativo)
	selectedSceneNode: null,   // id de nodo dentro de la escena seleccionada
	selectedCinematic: null,   // clave de cinematics (data/cinematics/<id>.json)
	selectedWorldTransform: null, // clave (transform_id) de world_transforms.json
	selectedWorldBuilding: null, // clave (code) de data/world_buildings/<code>.json
	selectedSkill: null,       // clave (skill_id) de skills.json
	selectedEnemySkill: null,  // clave (skill_id) de enemy_skills.json
	selectedDungeonTile: null,    // clave (t) de data/dungeon_tiles/<t>.json
	selectedWorldTerrain: null,   // clave (code) de data/world_terrains/<code>.json
	selectedWorldResource: null,  // clave (code) de data/world_resources/<code>.json
	selectedKit: null,            // clave (kit_id) de dungeon_kits.json (kits)
	selectedKitPiece: null,       // clave (piece_id) de dungeon_kits.json (pieces)

	// 🎛️ MODO EXPERTO: muestra campos avanzados/opcionales que un usuario normal
	// no tocaría (render 3D, variantes, textos de locale, ids técnicos...). Se
	// oculta por defecto para que las pestañas se vean limpias; los apartados
	// que lo respetan usan `v-if="store.expertMode"`. Persistente.
	expertMode: (() => { try { return JSON.parse(localStorage.getItem('mw-expert-mode') || 'false'); } catch (e) { return false; } })(),

	// 🌐 INTERNACIONALIZACIÓN (i18n) GLOBAL DEL EDITOR
	currentLang: 'es',
	supportedLanguages: [
		{ code: 'es', label: 'Español' },
		{ code: 'en', label: 'English' },
		{ code: 'fr', label: 'Français' },
		{ code: 'it', label: 'Italiano' },
		{ code: 'de', label: 'Deutsch' },
		{ code: 'zh', label: '中文' },
		{ code: 'ja', label: '日本語' },
	],
});

window.__EDITOR_STORE__ = store;

/**
 * Traduce una clave de interfaz (UI) según store.currentLang.
 */
export function t(key, subs = {}) {
	return i18nT(key, subs, store.currentLang);
}

// ─── UTILIDADES I18N GLOBALES (JERARQUÍA: en -> es -> any -> "") ─────────────

/**
 * Devuelve el valor con fallback según la jerarquía:
 * 1. Idioma inglés ("en") si existe y no está vacío.
 * 2. Idioma español ("es") si existe y no está vacío.
 * 3. Primer idioma que tenga contenido.
 * 4. Cadena vacía si todo está vacío.
 */
export function getI18nFallback(obj) {
	if (!obj) return '';
	if (typeof obj === 'string') return obj;
	if (typeof obj !== 'object') return String(obj);
	if (obj.en && String(obj.en).trim() !== '') return String(obj.en);
	if (obj.es && String(obj.es).trim() !== '') return String(obj.es);
	for (const k of Object.keys(obj)) {
		if (obj[k] && String(obj[k]).trim() !== '') return String(obj[k]);
	}
	return '';
}

/**
 * Devuelve el valor exacto para el idioma indicado (o el activo en store).
 */
export function getI18n(obj, lang = store.currentLang) {
	if (!obj) return '';
	if (typeof obj === 'string') return obj;
	return (obj && typeof obj === 'object' && obj[lang] != null) ? String(obj[lang]) : '';
}

/**
 * Devuelve el valor del idioma activo si existe, o el fallback (en -> es -> any) para render/display.
 */
export function getI18nDisplay(obj, lang = store.currentLang) {
	if (!obj) return '';
	if (typeof obj === 'string') return obj;
	const exact = getI18n(obj, lang);
	if (exact && exact.trim() !== '') return exact;
	return getI18nFallback(obj);
}

/**
 * Asigna de forma segura el valor en el idioma activo (`lang`) dentro del objeto contenedor.
 * Si el campo no existe o es una cadena simple, lo inicializa como diccionario multi-idioma.
 */
export function setI18n(parentObj, field, value, lang = store.currentLang) {
	if (!parentObj) return;
	if (!parentObj[field] || typeof parentObj[field] !== 'object') {
		const oldVal = typeof parentObj[field] === 'string' ? parentObj[field] : '';
		parentObj[field] = { es: oldVal, en: '', fr: '', it: '', de: '', zh: '', ja: '' };
	}
	parentObj[field][lang] = value;
}

// ─── ACCIONES ────────────────────────────────────────────────────────────────

export function markDirty(which, id = null) {
	// Si se da un id, marca sólo ese id en la colección "un fichero por id".
	// Si no, marca todos los ids cargados (útil para undo/redo o migraciones).
	const perId = PERID_COLLECTIONS.find(c => c.key === which);
	if (perId) {
		if (id) store[perId.dirtyMap][id] = true;
		else for (const _id of Object.keys(store[perId.storeKey] || {})) store[perId.dirtyMap][_id] = true;
		return;
	}
	store.dirty[which] = true;
}

/** Marca UNA mazmorra (por id) como sucia, para que save() la escriba. */
export function markDungeonDirty(id) {
	if (id) store.dirtyDungeons[id] = true;
}

/**
 * Asegura que `store.dungeons[id]` tenga el contenido COMPLETO (con floors[]
 * real), no solo el resumen del listado inicial. Perezoso: si ya está completo
 * no vuelve a pedirlo. Lo llama el editor de mazmorras al cambiar de selección.
 */
export async function ensureDungeonLoaded(id) {
	if (!id || !store.dungeons) return;
	const cur = store.dungeons[id];
	if (cur && Array.isArray(cur.floors)) return;   // ya completo
	const full = await FS.readCollectionItem('dungeons', id);
	if (full) store.dungeons[id] = full;
}

/** Marca como sucio el MAPA ACTIVO (world.json o world_test.json según activeMap). */
export function markWorldDirty() {
	store.dirty[store.activeMap === 'debug' ? 'worldTest' : 'world'] = true;
}

/** Vuelca `store.world` (mapa activo) en su holder (worldReal/worldDebug). */
export function syncActiveMap() {
	if (store.activeMap === 'debug') store.worldDebug = store.world;
	else store.worldReal = store.world;
}

/** Cambia el mapa en edición ('real' ↔ 'debug') conservando los cambios de ambos. */
export function switchMap(which) {
	if ((which !== 'real' && which !== 'debug') || which === store.activeMap) return;
	syncActiveMap();
	store.activeMap = which;
	store.world = (which === 'debug') ? store.worldDebug : store.worldReal;
	store.selectedCell = null;
}

/** Mapamundi mínimo por defecto (9×9 de mar) usado si falta world_test.json. */
function _defaultWorld() {
	const tiles = [];
	for (let y = 0; y < 9; y++) {
		const row = [];
		for (let x = 0; x < 9; x++) row.push({ terrain: 'sea' });
		tiles.push(row);
	}
	return { width: 9, height: 9, spawn: { x: 4, y: 4 }, tiles };
}

export function anyDirty() {
	// Mapas especiales (world/world_test) + documentos (booleano store.dirty[key])
	// + colecciones "un fichero por id" (tamaño de su mapa dirty). Deriva del descriptor.
	if (store.dirty.world || store.dirty.worldTest) return true;
	for (const c of DOC_COLLECTIONS) if (store.dirty[c.dirtyKey]) return true;
	for (const c of PERID_COLLECTIONS) if (Object.keys(store[c.dirtyMap] || {}).length > 0) return true;
	return false;
}

export function flash(msg) {
	store.toast = msg;
	setTimeout(() => { if (store.toast === msg) store.toast = ''; }, 2600);
}

export async function openProject() {
	store.error = '';
	store.loading = true;
	try {
		const info = await FS.openProject();
		store.projectName = info.name;
		store.hasAssets = info.hasAssets;
		await loadAll();
		store.loaded = true;
		flash('Proyecto cargado: ' + info.name);
	} catch (e) {
		store.error = e.message || String(e);
	} finally {
		store.loading = false;
	}
}

async function loadAll() {
	// world.json es OBLIGATORIO (arranque); el resto se DERIVA del descriptor
	// (collections.js): docs → readJson(file); "un fichero por id" → listCollection.
	// Las colecciones perId se traen COMPLETAS al cargar salvo `lazy` (dungeons),
	// de las que solo se trae un RESUMEN y el contenido va bajo demanda
	// (ensureDungeonLoaded). Ver comentarios de cada entrada en collections.js.
	const [world, worldTest, docVals, perIdVals] = await Promise.all([
		FS.readJson('world.json'),
		FS.readJson('world_test.json').catch(() => null),
		Promise.all(DOC_COLLECTIONS.map(c =>
			c.required ? FS.readJson(c.file) : FS.readJson(c.file).catch(() => (c.default ?? {})))),
		Promise.all(PERID_COLLECTIONS.map(c => FS.listCollection(c.endpoint).catch(() => ({})))),
	]);
	if (!world) throw new Error('No se encontró world.json en la carpeta data.');
	// Dos mapas editables: real (world.json) y debug (world_test.json). `world`
	// arranca apuntando al real. Si no existe el de debug, se crea uno mínimo.
	store.worldReal = world;
	store.worldDebug = worldTest || _defaultWorld();
	store.activeMap = 'real';
	store.world = store.worldReal;

	// Asignación de cada colección a su `storeKey` (con su valor por defecto).
	DOC_COLLECTIONS.forEach((c, i) => { store[c.storeKey] = docVals[i] || (c.default ?? {}); });
	PERID_COLLECTIONS.forEach((c, i) => { store[c.storeKey] = perIdVals[i] || {}; });

	// Reset de "sucio": documentos (booleanos) + colecciones perId (mapas vacíos).
	const dirty = { world: false, worldTest: false };
	for (const c of DOC_COLLECTIONS) dirty[c.dirtyKey] = false;
	store.dirty = dirty;
	for (const c of PERID_COLLECTIONS) store[c.dirtyMap] = {};

	// Selección inicial sensata: primer id de cada colección con selección propia.
	// dungeonKits es especial (selección anidada kits/pieces) y se fija aparte.
	for (const t of TABS) {
		if (t.sel && t.key !== 'dungeonKits') store[t.sel] = Object.keys(store[t.storeKey] || {})[0] || null;
	}
	store.selectedKit = Object.keys(store.dungeonKits.kits || {})[0] || null;
	store.selectedKitPiece = Object.keys(store.dungeonKits.pieces || {})[0] || null;
	store.selectedSceneNode = null;
	store.selectedCell = null;
}

export async function reloadAll() {
	store.loading = true;
	try {
		await loadAll();
		flash('Recargado desde disco.');
	} catch (e) {
		store.error = e.message || String(e);
	} finally {
		store.loading = false;
	}
}

/** Guarda solo lo que tiene cambios (o todo si force=true). Todo se DERIVA del
 *  descriptor (collections.js): documentos (un JSON) y colecciones "un fichero por
 *  id". world/world_test tienen manejo especial (holders real/debug). */
export async function save(force = false) {
	try {
		// Vuelca el mapa activo en su holder antes de decidir qué escribir.
		syncActiveMap();
		// ── Documentos (un JSON único): [file, obj, dirtyKey] ──
		const jobs = [];
		if (force || store.dirty.world) jobs.push(['world.json', store.worldReal, 'world']);
		if (force || store.dirty.worldTest) jobs.push(['world_test.json', store.worldDebug, 'worldTest']);
		for (const c of DOC_COLLECTIONS) {
			if (force || store.dirty[c.dirtyKey]) jobs.push([c.file, store[c.storeKey], c.dirtyKey]);
		}
		// ── Colecciones "un fichero por id": qué ids escribir ──
		// force = todos los cargados (las `lazy`/mazmorras: solo los que tienen
		// floors[] completo, no los que siguen siendo un resumen); si no, los sucios.
		const perIdJobs = PERID_COLLECTIONS.map((c) => {
			const dict = store[c.storeKey] || {};
			let ids;
			if (force) {
				ids = c.lazy
					? Object.keys(dict).filter(id => Array.isArray(dict[id]?.floors))
					: Object.keys(dict);
			} else {
				ids = Object.keys(store[c.dirtyMap] || {});
			}
			return { c, ids };
		});
		const anyPerId = perIdJobs.some(j => j.ids.length > 0);
		if (!jobs.length && !anyPerId) { flash('No hay cambios que guardar.'); return; }
		// Escritura.
		for (const [name, obj] of jobs) await FS.writeJson(name, obj);
		for (const { c, ids } of perIdJobs) {
			for (const id of ids) await FS.writeCollectionItem(c.endpoint, id, store[c.storeKey][id]);
		}
		// Limpiar "sucio".
		for (const [, , key] of jobs) if (key) store.dirty[key] = false;
		for (const { c, ids } of perIdJobs) for (const id of ids) delete store[c.dirtyMap][id];
		// Toast con los ficheros escritos.
		const savedNames = jobs.map(j => j[0]);
		for (const { c, ids } of perIdJobs) savedNames.push(...ids.map(id => `${c.endpoint}/${id}.json`));
		flash('Guardado: ' + savedNames.join(', '));
	} catch (e) {
		store.error = 'Error al guardar: ' + (e.message || String(e));
	}
}

// ─── NAVEGACIÓN ────────────────────────────────────────────
// Estado de la shell de navegación: modo (Diseñador/Datos), colapso de la barra
// lateral, favoritos y recientes. Se PERSISTE en localStorage para recordar el
// layout entre sesiones (requisito "persistencia del layout").
const RECENTS_MAX = 12;
const _lsGet = (k, def) => { try { const v = localStorage.getItem(k); return v == null ? def : JSON.parse(v); } catch (e) { return def; } };
const _lsSet = (k, v) => { try { localStorage.setItem(k, JSON.stringify(v)); } catch (e) { /* almacenamiento no disponible */ } };

export const nav = reactive({
	mode: _lsGet('mw-nav-mode', 'designer'),          // 'designer' | 'data'
	collapsed: _lsGet('mw-nav-collapsed', false),      // barra lateral colapsada
	expandedArea: _lsGet('mw-nav-area', 'world'),      // área abierta en Modo Diseñador
	favorites: _lsGet('mw-nav-favorites', []),         // [{ tab, id }]
	recents: _lsGet('mw-nav-recents', []),             // [{ tab, id }] (más reciente primero)
	searchOpen: false,                                 // búsqueda global visible
	helpOpen: false,                                   // panel de ayuda contextual visible (Fase 8)
	compact: true,                                      // modo compacto SIEMPRE activo (sin toggle; ver html.compact en CSS)
	qaOpen: false,                                     // panel de Validación QA visible (Task 5)
	pendingNew: null,                                  // tabId con una creación "Nuevo X" pendiente (Task 5, paleta de comandos)
});

export function setNavMode(mode) { nav.mode = mode; _lsSet('mw-nav-mode', mode); }
export function toggleSidebar() { nav.collapsed = !nav.collapsed; _lsSet('mw-nav-collapsed', nav.collapsed); }
export function setExpandedArea(id) { nav.expandedArea = id; _lsSet('mw-nav-area', id); }

/** Alterna el modo experto (muestra los apartados avanzados/opcionales). Persistente. */
export function toggleExpertMode() { store.expertMode = !store.expertMode; _lsSet('mw-expert-mode', store.expertMode); }
/** Aplica/quita la clase de densidad en el <html> para que el CSS reaccione. */
export function applyCompact() {
	if (typeof document !== 'undefined') document.documentElement.classList.toggle('compact', !!nav.compact);
}

/** Añade (o promueve) una entrada al historial de recientes. */
export function pushRecent(entry) {
	if (!entry || !entry.tab) return;
	const key = entry.tab + '::' + (entry.id || '');
	nav.recents = [entry, ...nav.recents.filter(e => (e.tab + '::' + (e.id || '')) !== key)].slice(0, RECENTS_MAX);
	_lsSet('mw-nav-recents', nav.recents);
}

export function isFavorite(tab, id) {
	return nav.favorites.some(e => e.tab === tab && (e.id || '') === (id || ''));
}

/** Alterna una entrada en favoritos. */
export function toggleFavorite(entry) {
	if (!entry || !entry.tab) return;
	if (isFavorite(entry.tab, entry.id)) {
		nav.favorites = nav.favorites.filter(e => !(e.tab === entry.tab && (e.id || '') === (entry.id || '')));
	} else {
		nav.favorites = [...nav.favorites, { tab: entry.tab, id: entry.id || null }];
	}
	_lsSet('mw-nav-favorites', nav.favorites);
}
