// nav.js
// ─────────────────────────────────────────────────────────────────────────────
// NAVEGACIÓN. Fuente ÚNICA de la metainformación de navegación:
//   · TAB_META      — metadatos de cada pestaña (etiqueta, icono, grupo, y si es
//                     un editor de colección: su clave de selección y su getter).
//   · DATA_GROUPS   — agrupación de pestañas para el "Modo Datos" (por tipo).
//   · DESIGNER_AREAS— grandes áreas de trabajo para el "Modo Diseñador" (por tarea).
//   · goTo/globalSearch/entityName — helpers de navegación y búsqueda global.
//
// Mantener aquí (y NO repartido) evita que cada componente reinvente el mapeo
// pestaña→selección y permite que la búsqueda global recorra todas las colecciones
// de forma genérica y escalable.
// ─────────────────────────────────────────────────────────────────────────────
import { store, nav, pushRecent, save, reloadAll, anyDirty, t } from './store.js';
import { TABS, resolvePath } from './collections.js';

// Metadatos por pestaña. Se DERIVAN del descriptor único `collections.js` (TABS),
// no se duplican aquí. `sel` y `coll` solo para editores de colección (diccionario
// id→entidad); las pestañas sin selección puntual los omiten. `coll` usa `collPath`
// si se da (p. ej. dungeonKits → `dungeonKits.pieces`), o el propio `storeKey`.
export const TAB_META = Object.fromEntries(TABS.map((tabDef) => {
	const meta = {
		get label() { return t('tab.' + tabDef.key) || tabDef.label; },
		icon: tabDef.icon,
		group: tabDef.group,
	};
	if (tabDef.workspace) meta.workspace = true;
	if (tabDef.sel) {
		meta.sel = tabDef.sel;
		const path = tabDef.collPath || tabDef.storeKey;
		meta.coll = () => resolvePath(store, path);
	}
	return [tabDef.key, meta];
}));

export function getTabLabel(tabKey) {
	return t('tab.' + tabKey) || TAB_META[tabKey]?.label || tabKey;
}

// Orden canónico de pestañas (para "todas" y para el buscador global).
export const ALL_TABS = Object.keys(TAB_META);

// ─── 4 MODOS PRINCIPALES DE JUEGO + SISTEMAS GLOBALES ──────────────────────────
// El juego se estructura en 4 pilares autónomos + 1 conjunto de sistemas comunes.
// Esta es la fuente canónica para el Hub de Inicio (WelcomePanel) y la navegación IDE.
export const GAME_MODES = [
	{
		id: 'world',
		get label() { return t('mode.world.label'); },
		get shortLabel() { return t('mode.world.short'); },
		icon: '🗺️',
		get tagline() { return t('mode.world.tagline'); },
		get desc() { return t('mode.world.desc'); },
		color: 'var(--accent, #3b82f6)',
		get badge() { return t('mode.world.badge'); },
		primaryTab: 'map',
		tabs: ['map', 'cityWorkspace', 'worldTerrains', 'worldResources', 'ids', 'worldBuildings', 'ambience', 'worldTransforms'],
	},
	{
		id: 'dungeon',
		get label() { return t('mode.dungeon.label'); },
		get shortLabel() { return t('mode.dungeon.short'); },
		icon: '🏰',
		get tagline() { return t('mode.dungeon.tagline'); },
		get desc() { return t('mode.dungeon.desc'); },
		color: '#8b5cf6',
		get badge() { return t('mode.dungeon.badge'); },
		primaryTab: 'dungeons',
		tabs: ['dungeons', 'dungeonPieces'],
	},
	{
		id: 'combat',
		get label() { return t('mode.combat.label'); },
		get shortLabel() { return t('mode.combat.short'); },
		icon: '⚔️',
		get tagline() { return t('mode.combat.tagline'); },
		get desc() { return t('mode.combat.desc'); },
		color: '#ef4444',
		get badge() { return t('mode.combat.badge'); },
		primaryTab: 'enemies',
		tabs: ['enemies', 'enemySkills', 'professions', 'skills', 'synergies'],
	},
	{
		id: 'story',
		get label() { return t('mode.story.label'); },
		get shortLabel() { return t('mode.story.short'); },
		icon: '📖',
		get tagline() { return t('mode.story.tagline'); },
		get desc() { return t('mode.story.desc'); },
		color: '#ec4899',
		get badge() { return t('mode.story.badge'); },
		primaryTab: 'scenes',
		tabs: ['scenes', 'cinematics', 'npcs', 'events', 'quests'],
	},
	{
		id: 'common',
		get label() { return t('mode.common.label'); },
		get shortLabel() { return t('mode.common.short'); },
		icon: '⚙️',
		get tagline() { return t('mode.common.tagline'); },
		get desc() { return t('mode.common.desc'); },
		color: '#10b981',
		get badge() { return t('mode.common.badge'); },
		primaryTab: 'items',
		tabs: ['items', 'shops', 'achievements', 'config', 'mediaLibrary'],
	},
];

// ── Modo Datos: agrupado por los 4 Modos de Juego + Sistemas Globales ─────────
export const DATA_GROUPS = GAME_MODES.map(m => ({
	id: m.id,
	get label() { return m.label; },
	get shortLabel() { return m.shortLabel; },
	icon: m.icon,
	tabs: m.tabs,
}));

// ── Modo Diseñador: áreas de trabajo correspondientes a los 4 Modos ────────────
export const DESIGNER_AREAS = GAME_MODES.map(m => ({
	id: m.id,
	get label() { return m.label; },
	get shortLabel() { return m.shortLabel; },
	icon: m.icon,
	tabs: m.tabs,
}));

/** Extrae un nombre legible de una entidad heterogénea (bilingüe o string). */
export function pickName(o) {
	if (!o || typeof o !== 'object') return '';
	const n = o.name ?? o._meta?.name ?? o.title;
	if (n && typeof n === 'object') return n[store.currentLang] || n.en || n.es || '';
	if (typeof n === 'string') return n;
	return '';
}

/** Nombre mostrado para (tab,id): nombre de la entidad o el propio id. */
export function entityName(tab, id) {
	if (!id) return getTabLabel(tab);
	const meta = TAB_META[tab];
	const coll = meta && meta.coll ? (meta.coll() || {}) : null;
	const o = coll ? coll[id] : null;
	const nm = pickName(o);
	return nm ? (nm + ' · ' + id) : id;
}

/**
 * Navega a una pestaña y, si procede, selecciona una entidad. Registra la visita
 * en recientes. Es el ÚNICO punto por el que deben pasar todas las navegaciones.
 */
export function goTo(tab, id = null) {
	if (!TAB_META[tab]) return;
	store.activeTab = tab;
	const meta = TAB_META[tab];
	if (id && meta.sel) store[meta.sel] = id;
	pushRecent({ tab, id: id || null });
}

/**
 * Navega a la pestaña de una colección y solicita la creación inmediata de una
 * nueva entidad en ella (Task 5, Paleta de Comandos — `> Nuevo X`). El propio
 * `EntityListPanel.js` (usado por TODOS los editores de colección) observa
 * `nav.pendingNew` y ejecuta `c.add()` en cuanto coincide con su `tabId`, sin
 * que cada manager tenga que exponer nada nuevo.
 */
export function requestNewEntity(tab) {
	goTo(tab);
	nav.pendingNew = tab;
}

// ── Comandos rápidos de la Paleta (Task 5, modo `>`) ────────────────────────
// Cada comando es independiente de cualquier entidad concreta; se ejecuta con
// `run()` y cierra la paleta. `requiresConfirm` avisa antes de una acción que
// puede perder cambios sin guardar (recarga desde disco).
export const COMMANDS = [
	{ id: 'new_item', icon: '🧪', label: 'Nuevo Objeto', hint: 'items', run: () => requestNewEntity('items') },
	{ id: 'new_dungeon', icon: '🏰', label: 'Nueva Mazmorra', hint: 'dungeons', run: () => requestNewEntity('dungeons') },
	{ id: 'new_npc', icon: '🧑', label: 'Nuevo PNJ', hint: 'npcs', run: () => requestNewEntity('npcs') },
	{ id: 'new_quest', icon: '📜', label: 'Nueva Misión', hint: 'quests', run: () => requestNewEntity('quests') },
	{ id: 'new_enemy', icon: '👹', label: 'Nuevo Enemigo', hint: 'enemies', run: () => requestNewEntity('enemies') },
	{ id: 'new_cinematic', icon: '🎬', label: 'Nueva Cinemática', hint: 'cinematics', run: () => requestNewEntity('cinematics') },
	{ id: 'validate', icon: '🔎', label: 'Validar Datos', hint: 'QA', run: () => { nav.qaOpen = true; } },
	{ id: 'export_all', icon: '📤', label: 'Exportar Todo', hint: 'guarda todo a disco', run: () => save(true) },
	{
		id: 'clear_cache', icon: '🧹', label: 'Limpiar Caché', hint: 'recarga todo desde disco',
		run: () => {
			if (anyDirty() && !confirm('Hay cambios sin guardar. ¿Recargar desde disco y perderlos?')) return;
			reloadAll();
		},
	},
];

/** Filtra COMMANDS por texto libre (sin el prefijo `>`). */
export function searchCommands(query) {
	const q = (query || '').trim().toLowerCase();
	if (!q) return COMMANDS;
	return COMMANDS.filter(c => c.label.toLowerCase().includes(q) || c.id.includes(q));
}

/**
 * Búsqueda global sobre TODAS las colecciones. Devuelve resultados agrupados por
 * pestaña. Acotado por `perTab` para seguir siendo rápido con miles de registros.
 * @returns {Array<{ tab, label, icon, items: Array<{ id, name }> }>}
 */
export function globalSearch(query, perTab = 8) {
	const q = (query || '').trim().toLowerCase();
	if (!q) return [];
	const groups = [];
	for (const tab of ALL_TABS) {
		const meta = TAB_META[tab];
		if (!meta.coll) continue;
		const coll = meta.coll() || {};
		const items = [];
		for (const id in coll) {
			if (items.length >= perTab) break;
			const name = pickName(coll[id]);
			if (id.toLowerCase().includes(q) || (name && name.toLowerCase().includes(q))) {
				items.push({ id, name });
			}
		}
		if (items.length) groups.push({ tab, label: meta.label, icon: meta.icon, items });
	}
	return groups;
}
