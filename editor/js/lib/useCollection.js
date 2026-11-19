// lib/useCollection.js
// ─────────────────────────────────────────────────────────────────────────────
// COMPOSABLE MAESTRO de los editores de COLECCIÓN (Tarea 4). Unifica en un solo
// lugar TODO el comportamiento que la tarea exige que compartan "absolutamente
// todos los editores" que gestionan un diccionario `{ id -> entidad }`:
//
//   · Buscar (texto libre)          · Filtrar (por campos)     · Ordenar (asc/desc)
//   · Ctrl+Z / Ctrl+Y (undo/redo)   · Duplicar                 · Copiar / Pegar
//   · Eliminar (con confirmación)   · Autoguardado             · Guardar manual
//   · Indicador de cambios pendientes
//
// Reutiliza las libs comunes: useHistory, useAutosave, useClipboard. Los
// editores solo aportan CONFIGURACIÓN declarativa (getters de dominio) y su
// panel de edición; no reimplementan el CRUD ni los atajos.
//
// El historial fotografía la COLECCIÓN completa (deep clone). Las ediciones de
// campos se agrupan por ráfagas (coalescing) para que escribir en un input sea
// un único paso de deshacer, no uno por tecla.
// ─────────────────────────────────────────────────────────────────────────────
import { ref, reactive, computed, onMounted, onUnmounted } from 'https://unpkg.com/vue@3/dist/vue.esm-browser.prod.js';
import { store, markDirty, flash, save } from '../store.js';
import { useHistory, deepClone } from './useHistory.js';
import { useAutosave } from './useAutosave.js';
import { useClipboard } from './useClipboard.js';

const COALESCE_MS = 450;   // ráfaga de edición de campos que cuenta como 1 paso

/**
 * @param {{
 *   tabId: string,               // store.activeTab en el que este editor está activo
 *   dirtyKey: string,            // clave de store.dirty / markDirty
 *   dirtyMap?: () => Object,     // colecciones "un fichero por id": getter del
 *                                // diccionario per-id sucio (p. ej. () => store.dirtyEnemies).
 *                                // Si se da, el indicador "sucio"/autoguardado mira
 *                                // Object.keys(dirtyMap()).length en vez de store.dirty[dirtyKey]
 *                                // (que para estas colecciones ya no es un booleano).
 *   collection: () => Object,    // getter del diccionario { id -> entidad }
 *   setCollection: (v:Object)=>void, // reemplaza el diccionario (para restaurar historial)
 *   selectedKey: string,         // nombre de la prop de selección en store (p. ej. 'selectedItem')
 *   clipboardKind: string,       // kind para el portapapeles compartido
 *   entityLabel: string,         // etiqueta legible singular ("objeto", "enemigo"…)
 *   newIdBase: string,           // base para ids nuevos ("item_new")
 *   makeNew: (id:string)=>Object,// fábrica de entidad nueva
 *   searchText: (id:string, o:Object)=>string, // texto para buscar
 *   filters?: Array<{ key, label, options:Array<string>, get:(o)=>any }>,
 *   sorts?: Array<{ key, label, get:(id,o)=>any }>,
 * }} cfg
 */
export function useCollection(cfg) {
	const clipboard = useClipboard();
	const history = useHistory({ limit: 80 });
	let _lastPush = 0;

	// ── Estado de búsqueda / filtro / orden ─────────────────────────────────
	const search = ref('');
	const filterState = reactive({});
	for (const f of (cfg.filters || [])) filterState[f.key] = '';
	const sorts = cfg.sorts || [{ key: 'id', label: 'ID', get: (id) => id }];
	const sortKey = ref(sorts[0].key);
	const sortDir = ref('asc');

	// ── Acceso a la colección y a la selección ──────────────────────────────
	const all = computed(() => cfg.collection() || {});
	const selectedId = computed({
		get: () => store[cfg.selectedKey],
		set: (v) => { store[cfg.selectedKey] = v; },
	});
	const current = computed(() => selectedId.value ? all.value[selectedId.value] : null);

	// ── Lista filtrada + ordenada: [{ id, o }] ──────────────────────────────
	const list = computed(() => {
		const q = search.value.trim().toLowerCase();
		let rows = Object.entries(all.value).map(([id, o]) => ({ id, o }));
		// Filtros por campo.
		for (const f of (cfg.filters || [])) {
			const val = filterState[f.key];
			if (val) rows = rows.filter(({ id, o }) => String(f.get(o, id) ?? '') === val);
		}
		// Búsqueda de texto.
		if (q) rows = rows.filter(({ id, o }) => cfg.searchText(id, o).toLowerCase().includes(q));
		// Orden.
		const sorter = sorts.find(s => s.key === sortKey.value) || sorts[0];
		const dir = sortDir.value === 'desc' ? -1 : 1;
		rows.sort((a, b) => {
			const va = sorter.get(a.id, a.o), vb = sorter.get(b.id, b.o);
			if (va < vb) return -1 * dir;
			if (va > vb) return 1 * dir;
			return 0;
		});
		return rows;
	});

	function toggleSortDir() { sortDir.value = sortDir.value === 'asc' ? 'desc' : 'asc'; }
	function select(id) { selectedId.value = id; }

	// ── Historial ────────────────────────────────────────────────────────────
	function snapshot() { history.push(deepClone(all.value)); _lastPush = Date.now(); }
	function _restore(state) {
		if (!state) return;
		const before = cfg.collection() || {};
		cfg.setCollection(state);
		markDirty(cfg.dirtyKey);
		// Colecciones "un fichero por id" (cfg.onRemove): un id que existía ANTES
		// del undo/redo y ya no está en el estado restaurado quedaría huérfano en
		// disco (el bucle de arriba solo REESCRIBE los que quedan, nunca borra).
		// Se borra remotamente cada uno (best-effort).
		if (cfg.onRemove) {
			for (const id of Object.keys(before)) {
				if (!(id in state)) cfg.onRemove(id).catch(() => {});
			}
		}
		if (!all.value[selectedId.value]) selectedId.value = Object.keys(all.value)[0] || null;
	}
	function undo() { const p = history.undo(deepClone(all.value)); if (p) _restore(p); }
	function redo() { const n = history.redo(deepClone(all.value)); if (n) _restore(n); }

	/** Ejecuta una mutación de campo con historial COALESCED y marca cambios. */
	function edit(fn) {
		if (Date.now() - _lastPush > COALESCE_MS) snapshot();
		else _lastPush = Date.now();
		fn();
		markDirty(cfg.dirtyKey, selectedId.value);
	}
	/** Marca cambios sin snapshot adicional (para casos ya fotografiados). */
	function touch() { markDirty(cfg.dirtyKey, selectedId.value); }

	// ── Ids únicos ────────────────────────────────────────────────────────────
	function uniqueId(base) {
		let id = base, n = 1;
		while (all.value[id]) id = base + '_' + (++n);
		return id;
	}

	// ── CRUD (todas fotografían antes de mutar) ────────────────────────────────
	function add() {
		snapshot();
		const id = uniqueId(cfg.newIdBase);
		cfg.collection()[id] = cfg.makeNew(id);
		touch();
		select(id);
		flash('Nuevo ' + cfg.entityLabel + ': ' + id);
		return id;
	}

	function duplicate() {
		if (!current.value) return;
		snapshot();
		const id = uniqueId(selectedId.value + '_copy');
		const clone = deepClone(current.value);
		const kf = cfg.codeField || 'id';
		if (clone && typeof clone === 'object' && kf in clone) clone[kf] = id;
		cfg.collection()[id] = clone;
		touch();
		select(id);
		flash(cfg.entityLabel + ' duplicado: ' + id);
		return id;
	}

	async function remove() {
		if (!selectedId.value) return;
		if (!confirm('¿Eliminar ' + cfg.entityLabel + ' "' + selectedId.value + '"? Esta acción se puede deshacer con Ctrl+Z.')) return;
		snapshot();
		const removed = selectedId.value;
		delete cfg.collection()[removed];
		selectedId.value = Object.keys(all.value)[0] || null;
		touch();
		// Colecciones "un fichero por id": el borrado del FICHERO en disco es
		// INMEDIATO (no espera a "Guardar"), igual que con las mazmorras — Ctrl+Z
		// deshace la parte en memoria, pero el fichero ya se fue.
		if (cfg.onRemove) { try { await cfg.onRemove(removed); } catch (e) { store.error = 'Error al borrar: ' + (e.message || String(e)); } }
		flash(cfg.entityLabel + ' eliminado: ' + removed);
	}

	async function rename(newId) {
		newId = (newId || '').trim();
		const oldId = selectedId.value;
		if (!newId || newId === oldId) return;
		if (all.value[newId]) { store.error = 'Ya existe un id "' + newId + '".'; return; }
		snapshot();
		const col = cfg.collection();
		col[newId] = col[oldId];
		// Algunas colecciones embeben la clave dentro de la propia entidad con un
		// nombre distinto de "id" (p. ej. "code" en world_terrains/world_resources,
		// "t" en dungeon_tiles). `cfg.codeField` indica cuál sincronizar; si no se
		// da, se prueba "id" por compatibilidad con las colecciones más antiguas.
		const kf = cfg.codeField || 'id';
		if (col[newId] && typeof col[newId] === 'object' && kf in col[newId]) col[newId][kf] = newId;
		delete col[oldId];
		selectedId.value = newId;
		if (cfg.onRemove) { try { await cfg.onRemove(oldId); } catch (e) { store.error = 'Error al borrar: ' + (e.message || String(e)); } }
		touch();
	}

	// ── Copiar / Pegar (portapapeles compartido) ────────────────────────────
	function copy() {
		if (!current.value) return;
		clipboard.copy(cfg.clipboardKind, current.value);
		flash(cfg.entityLabel + ' copiado al portapapeles.');
	}
	const canPaste = computed(() => clipboard.canPaste(cfg.clipboardKind));
	function paste() {
		const data = clipboard.read(cfg.clipboardKind);
		if (!data) return;
		snapshot();
		const kf = cfg.codeField || 'id';
		const base = (data && data[kf]) ? String(data[kf]) + '_copy' : cfg.newIdBase;
		const id = uniqueId(base);
		if (data && typeof data === 'object' && kf in data) data[kf] = id;
		cfg.collection()[id] = data;
		touch();
		select(id);
		flash(cfg.entityLabel + ' pegado: ' + id);
		return id;
	}

	// ── Autoguardado + indicador ────────────────────────────────────────────
	// Colecciones "un fichero por id" (cfg.dirtyMap) rastrean su "sucio" por id
	// (p. ej. store.dirtyEnemies), no con un booleano de store.dirty.
	const _isDirtyNow = () => cfg.dirtyMap ? Object.keys(cfg.dirtyMap()).length > 0 : !!store.dirty[cfg.dirtyKey];
	const autosave = useAutosave({
		intervalMs: 9000,
		isDirty: _isDirtyNow,
		onSave: () => save(false),
	});
	const dirty = computed(_isDirtyNow);
	function doSave() { save(false); }

	// ── Atajos de teclado (solo cuando esta pestaña está activa) ─────────────
	function _typingTarget(e) {
		const tag = (e.target && e.target.tagName) || '';
		return tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT' || (e.target && e.target.isContentEditable);
	}
	function onKey(e) {
		if (store.activeTab !== cfg.tabId) return;
		const k = e.key.toLowerCase();
		if ((e.ctrlKey || e.metaKey) && k === 'z' && !e.shiftKey) { e.preventDefault(); undo(); }
		else if ((e.ctrlKey || e.metaKey) && (k === 'y' || (e.shiftKey && k === 'z'))) { e.preventDefault(); redo(); }
		else if ((e.ctrlKey || e.metaKey) && k === 'd') { e.preventDefault(); duplicate(); }
		else if ((e.ctrlKey || e.metaKey) && k === 'c' && !_typingTarget(e)) { e.preventDefault(); copy(); }
		else if ((e.ctrlKey || e.metaKey) && k === 'v' && !_typingTarget(e)) { e.preventDefault(); paste(); }
		else if ((e.key === 'Delete') && !_typingTarget(e)) { e.preventDefault(); remove(); }
	}

	onMounted(() => { window.addEventListener('keydown', onKey); autosave.start(); });
	onUnmounted(() => { window.removeEventListener('keydown', onKey); autosave.stop(); });

	return {
		// estado búsqueda/filtro/orden
		search, filterState, filters: cfg.filters || [], sorts, sortKey, sortDir, toggleSortDir,
		// datos
		all, list, current, selectedId, select,
		// edición
		edit, touch, snapshot,
		// crud
		add, duplicate, remove, rename, copy, paste, canPaste,
		// historial
		undo, redo, canUndo: history.canUndo, canRedo: history.canRedo,
		// guardado
		dirty, doSave, savedText: autosave.savedAgoText,
		// meta
		entityLabel: cfg.entityLabel, tabId: cfg.tabId,
	};
}
