// components/DungeonPiecesManager.js
// ─────────────────────────────────────────────────────────────────────────────
// GESTOR UNIFICADO de todo lo COLOCABLE en el editor de mazmorras. Fusiona lo
// que antes eran DOS pantallas separadas y confusas:
//   · "Tipos de casilla"  (data/dungeon_tiles/<t>.json)
//   · "Kits (Obj. Inteligente)" (dungeon_kits.json → pieces)
// en una sola lista con TRES categorías claramente etiquetadas:
//   🔒 Comportamiento FIJO   — el "t" tiene su propio `match t:` en
//                              GridDungeonStage.gd. Aquí solo editas su
//                              aspecto de paleta (icono/color/grupo); el
//                              comportamiento vive en GDScript y NO cambia
//                              aunque toques estos campos.
//   🎨 Cosmético (sin código) — el "t" NO tiene código dedicado: su geometría
//                              la decide 100% el `render` de aquí (shape:
//                              floor/wall/liquid/model/light…). Sin lógica de
//                              juego, solo decoración.
//   🧩 Objeto Inteligente     — pieza de `dungeon_kits.json`: archetype+shape+
//                              reaction definen TANTO el aspecto COMO el
//                              comportamiento sin tocar GDScript. Es el único
//                              camino 100% data-driven de los tres.
//
// Por qué la fusión: antes parecían dos catálogos redundantes ("¿cuál uso?").
// En realidad gestionan sistemas distintos, pero la separación ocultaba que
// la mayoría de "Tipos de casilla" son solo metadatos de un comportamiento ya
// fijo en código (editable pero no "programable" desde aquí), mientras que
// "Kits" sí es plenamente programable. Verlos juntos, con la categoría a la
// vista, hace evidente cuál es cuál sin tener que leer GDScript.
//
// Protección añadida: renombrar el `t` de una casilla 🔒 (torch, door,
// chest…) la desconecta de su `match t:` para las casillas NUEVAS que se
// coloquen con ese id (las ya existentes en mazmorras no se tocan, siguen
// funcionando). Antes esto se podía hacer sin ningún aviso; ahora se bloquea.
// ─────────────────────────────────────────────────────────────────────────────
import { ref, reactive, computed, watch, onMounted, onUnmounted } from 'https://unpkg.com/vue@3/dist/vue.esm-browser.prod.js';
import { store, markDirty, getI18n, getI18nFallback, setI18n } from '../store.js';
import * as FS from '../fs.js';
import { useCollection } from '../lib/useCollection.js';
import EntityListPanel from './EntityListPanel.js';
import EditorToolbar from './EditorToolbar.js';

// ─── CASILLAS (antes DungeonTilesManager) ────────────────────────────────────
const TILE_GROUPS = ['Onda Cinética', 'Agarre Psíquico', 'Tiempo', 'Instinto Cazador', 'Afinidad Elemental', 'Purificar', 'Estructura', 'Sistema', 'Peligros', 'Decoración', 'Acceso', 'Interactivos', 'Suelo'];
const RENDER_SHAPES = ['', 'none', 'floor', 'wall', 'model', 'liquid', 'cone', 'light'];

// `t` con su propio caso en el `match t:` de GridDungeonStage.gd._build_cell
// (líneas ~1166-1420). Renombrar/borrar cualquiera de estos dejaría a las
// casillas NUEVAS de ese id sin su comportamiento (caen al render genérico o
// a una simple losa); las ya colocadas en mazmorras existentes no se ven
// afectadas (el motor no relee este catálogo para ellas en cada partida).
const HARDCODED_TILE_TYPES = new Set([
	'wall', 'climb_wall', 'floor', 'bridge', 'stairs', 'ramp',
	'escalera_con_muros', 'hojas_pared', 'door', 'water', 'ice_floor', 'ice_block', 'moving_platform', 'elevator',
	'lava', 'spikes', 'monster', 'chest', 'gate', 'switch', 'lever', 'weight_plate', 'torch',
	'crystal', 'column', 'barrel', 'crate', 'caja_pesada',
	'armario_libreria', 'barril_manzanas', 'cama',
	'bomba', 'rune', 'campfire', 'smart', 'sign', 'teleport', 'event', 'npc',
	'item', 'decor', 'light',
]);

function rgbArrToHex(arr) {
	if (!Array.isArray(arr) || arr.length < 3) return '#ffffff';
	const c = (v) => Math.max(0, Math.min(255, Math.round((Number(v) || 0) * 255))).toString(16).padStart(2, '0');
	return '#' + c(arr[0]) + c(arr[1]) + c(arr[2]);
}
function hexToRgbArr(hex) {
	const m = /^#?([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})$/i.exec(String(hex || '').trim());
	if (!m) return [1, 1, 1];
	return [parseInt(m[1], 16) / 255, parseInt(m[2], 16) / 255, parseInt(m[3], 16) / 255];
}

// ─── PIEZAS DE KIT (antes DungeonKitsManager) ───────────────────────────────
const KIT_SHAPES = ['box', 'wall', 'arch', 'barrier', 'rock', 'crate', 'ice', 'platform', 'bridge',
	'water', 'fog', 'button', 'button_high', 'column', 'pillar', 'ring', 'key', 'chest', 'statue',
	'spikes', 'blade', 'mill', 'gate', 'torch', 'brazier', 'roots', 'crystal', 'gear'];
const ELEMENTS = ['fuego', 'hielo', 'rayo', 'agua', 'viento', 'tierra'];
const VERBS = ['impact', 'grab', 'timeshift', 'reveal', 'element', 'restore'];

const ARCHETYPES = {
	breakable: { label: 'Rompible (impacto)', reactionType: 'breakable', fields: ['min_strength', 'break_event'] },
	movable: { label: 'Movible (empuje/arrastre)', reactionType: 'movable', fields: ['impact_force', 'pull_force'], mass: true },
	pullable: { label: 'Atraíble (agarre a distancia)', reactionType: 'pullable', fields: ['pull_force'], mass: true },
	anchor: { label: 'Anclaje (agarre, punto fijo)', reactionType: 'anchor', fields: ['anchor_offset_y'] },
	switch: { label: 'Interruptor (on/off)', reactionType: 'switch', fields: ['verbs', 'one_way', 'switch_event'] },
	time: { label: 'Afectado por el tiempo (móvil)', reactionType: 'time', fields: ['slow_factor'], motion: true },
	element_receiver: { label: 'Receptor elemental', reactionType: 'element', fields: ['accepted_element', 'activate_event'] },
	element_source: { label: 'Fuente elemental', reactionType: 'element_source', fields: ['source_element', 'one_shot', 'proximity'] },
	restore: { label: 'Restaurable (roto/reparado)', reactionType: 'restore', fields: ['restore_event', 'proximity'] },
	reveal: { label: 'Revelable (secreto)', reactionType: 'reveal', fields: ['reveal_seconds'] },
	false_solid: { label: 'Sólido falso (atravesable)', reactionType: 'false_wall', fields: ['reveal_seconds'] },
	purify: { label: 'Purificable (contaminado/limpio)', reactionType: 'purify', fields: ['clean', 'purify_event', 'proximity'] },
	campfire: { label: 'Hoguera (encendida/apagada)', reactionType: 'campfire', fields: ['element', 'lit', 'proximity'] },
	emit_event: { label: 'Emisor de evento (genérico)', reactionType: 'emit_event', fields: ['verbs', 'event_name'] },
	auto_platform: { label: 'Plataforma automática (siempre en marcha, sin habilidad)', reactionType: null, fields: [], motion: true },
};
const ARCHETYPE_KEYS = Object.keys(ARCHETYPES);

function defaultReaction(archetype) {
	const a = ARCHETYPES[archetype];
	const t = a ? a.reactionType : archetype;
	const base = { type: t };
	switch (archetype) {
		case 'breakable': return { ...base, min_strength: 0.0, break_event: '' };
		case 'movable': return { ...base, impact_force: 14.0, pull_force: 12.0 };
		case 'pullable': return { ...base, pull_force: 12.0 };
		case 'anchor': return { ...base, anchor_offset_y: 0.0 };
		case 'switch': return { ...base, verbs: ['impact'], one_way: false, switch_event: '' };
		case 'time': return { ...base, slow_factor: 0.15 };
		case 'element_receiver': return { ...base, accepted_element: 'fuego', activate_event: '' };
		case 'element_source': return { ...base, source_element: 'fuego', one_shot: false, proximity: false };
		case 'restore': return { ...base, restore_event: '', proximity: true };
		case 'reveal': return { ...base, reveal_seconds: 0.0 };
		case 'false_solid': return { ...base, reveal_seconds: 0.0 };
		case 'purify': return { ...base, clean: 'none', purify_event: '', proximity: true };
		case 'campfire': return { ...base, element: 'fuego', lit: true, proximity: true };
		case 'emit_event': return { ...base, verbs: ['impact'], event_name: '' };
	}
	return base;
}

const CATEGORY_META = {
	fixed: { icon: '🔒', label: 'Comportamiento fijo (código)' },
	cosmetic: { icon: '🎨', label: 'Cosmético (sin código)' },
	smart: { icon: '🧩', label: 'Objeto Inteligente (data-driven)' },
};

export default {
	name: 'DungeonPiecesManager',
	components: { EntityListPanel, EditorToolbar },
	setup() {
		// ── Colección real de CASILLAS (data/dungeon_tiles/<t>.json) ──────────
		const tilesCol = useCollection({
			tabId: '__dpm_tiles_inactive__', // desactiva su atajo de teclado propio; ver onKey unificado más abajo
			dirtyKey: 'dungeonTiles',
			dirtyMap: () => store.dirtyDungeonTiles,
			collection: () => store.dungeonTiles,
			setCollection: (v) => { store.dungeonTiles = v; },
			selectedKey: 'selectedDungeonTile',
			clipboardKind: 'dungeonTile',
			entityLabel: 'tipo de casilla',
			newIdBase: 'tile_nuevo',
			codeField: 't',
			onRemove: (t) => FS.deleteCollectionItem('dungeon_tiles', t),
			makeNew: (t) => ({ t, order: 99, label: 'Nueva casilla', icon: '⬜', color: '#888888', group: 'Decoración', entity: true }),
			searchText: (id, o) => id + ' ' + (o?.label || '') + ' ' + (o?.group || ''),
			sorts: [{ key: 'code', label: 'Código', get: (id) => id }],
		});

		// ── Colección real de PIEZAS de kit (dungeon_kits.json → pieces) ──────
		const kits = computed(() => store.dungeonKits.kits || (store.dungeonKits.kits = {}));
		const piecesCol = useCollection({
			tabId: '__dpm_pieces_inactive__',
			dirtyKey: 'dungeonKits',
			collection: () => store.dungeonKits.pieces,
			setCollection: (v) => { store.dungeonKits.pieces = v; },
			selectedKey: 'selectedKitPiece',
			clipboardKind: 'dungeonKitPiece',
			entityLabel: 'pieza',
			newIdBase: 'pieza_nueva',
			makeNew: () => ({
				kit: Object.keys(kits.value)[0] || '',
				name: { es: 'Nueva pieza', en: 'New piece' }, icon: '🧩',
				archetype: 'breakable', shape: 'box', color: '#8a8a8a',
				reaction: defaultReaction('breakable'),
			}),
			searchText: (id, o) => id + ' ' + (o?.kit || '') + ' ' + (o?.archetype || '') + ' ' + (o?.name?.es || ''),
			sorts: [{ key: 'code', label: 'Código', get: (id) => id }],
		});

		// ── Kind activo (qué colección manda ahora mismo) ──────────────────────
		// Reactivo a navegación EXTERNA (búsqueda global / recientes / favoritos,
		// que escriben directamente store.selectedDungeonTile o
		// store.selectedKitPiece vía goTo() en nav.js) además de a select() local.
		const activeKind = ref(store.selectedKitPiece && !store.selectedDungeonTile ? 'piece' : 'tile');
		watch(() => store.selectedDungeonTile, (v) => { if (v) activeKind.value = 'tile'; });
		watch(() => store.selectedKitPiece, (v) => { if (v) activeKind.value = 'piece'; });
		function kindOf(id) {
			if (store.dungeonTiles && Object.prototype.hasOwnProperty.call(store.dungeonTiles, id)) return 'tile';
			if (store.dungeonKits && store.dungeonKits.pieces && Object.prototype.hasOwnProperty.call(store.dungeonKits.pieces, id)) return 'piece';
			return null;
		}
		function categoryOf(row) {
			if (row.kind === 'piece') return 'smart';
			return HARDCODED_TILE_TYPES.has(row.id) ? 'fixed' : 'cosmetic';
		}

		// ── Lista fusionada + filtro/orden propios (no reutiliza list de useCollection: mezcla 2 colecciones) ──
		const search = ref('');
		const filterState = reactive({ category: '' });
		const sortKey = ref('category');
		const sortDir = ref('asc');
		const mergedRows = computed(() => {
			const tiles = Object.entries(store.dungeonTiles || {}).map(([id, o]) => ({ id, o, kind: 'tile' }));
			const pieces = Object.entries((store.dungeonKits && store.dungeonKits.pieces) || {}).map(([id, o]) => ({ id, o, kind: 'piece' }));
			return [...tiles, ...pieces];
		});
		const list = computed(() => {
			let rows = mergedRows.value;
			if (filterState.category) rows = rows.filter((r) => categoryOf(r) === filterState.category);
			const q = search.value.trim().toLowerCase();
			if (q) {
				rows = rows.filter((r) => (r.id + ' ' + (r.o?.label || '') + ' ' + (r.o?.group || '') + ' ' + (r.o?.kit || '') + ' ' + (r.o?.name?.es || '')).toLowerCase().includes(q));
			}
			const dir = sortDir.value === 'desc' ? -1 : 1;
			const keyOf = (r) => {
				if (sortKey.value === 'category') return CATEGORY_META[categoryOf(r)].label;
				if (sortKey.value === 'label') return r.o?.label || r.o?.name?.es || r.id;
				return r.id;
			};
			return [...rows].sort((a, b) => {
				const va = keyOf(a), vb = keyOf(b);
				if (va < vb) return -1 * dir;
				if (va > vb) return 1 * dir;
				return 0;
			});
		});

		const selectedId = computed(() => (activeKind.value === 'tile' ? tilesCol.selectedId.value : piecesCol.selectedId.value));
		function select(id) {
			const k = kindOf(id);
			if (!k) return;
			activeKind.value = k;
			(k === 'tile' ? tilesCol : piecesCol).select(id);
		}
		function addTile() { activeKind.value = 'tile'; tilesCol.add(); }
		function addPiece() { activeKind.value = 'piece'; piecesCol.add(); }

		// "col" sintético SOLO para alimentar a EntityListPanel (lista+búsqueda+
		// filtro+orden); el CRUD real (undo/copy/paste/save…) sigue viviendo en
		// tilesCol/piecesCol y se selecciona según cuál esté activo (ver debajo).
		const fakeCol = {
			tabId: 'dungeonPieces',
			list, search,
			filters: [{ key: 'category', label: 'Categoría', options: [
				{ value: 'fixed', label: '🔒 Comportamiento fijo' },
				{ value: 'cosmetic', label: '🎨 Cosmético' },
				{ value: 'smart', label: '🧩 Objeto Inteligente' },
			] }],
			filterState,
			sorts: [{ key: 'category', label: 'Categoría' }, { key: 'label', label: 'Etiqueta' }, { key: 'code', label: 'Código' }],
			sortKey, sortDir, toggleSortDir: () => { sortDir.value = sortDir.value === 'asc' ? 'desc' : 'asc'; },
			selectedId, select, add: addTile,
		};

		// ── Datos de la casilla/pieza activa ────────────────────────────────────
		const current = computed(() => (activeKind.value === 'tile' ? tilesCol.current.value : piecesCol.current.value));
		const activeCol = computed(() => (activeKind.value === 'tile' ? tilesCol : piecesCol));
		const isHardcodedTile = computed(() => activeKind.value === 'tile' && HARDCODED_TILE_TYPES.has(selectedId.value));

		// ── Atajos de teclado UNIFICADOS (Ctrl+Z/Y/D/C/V, Delete) — reemplazan
		// los de tilesCol/piecesCol (desactivados arriba con tabId ficticio) para
		// que actúen SOLO sobre la colección realmente activa. ──────────────────
		function _typingTarget(e) {
			const tag = (e.target && e.target.tagName) || '';
			return tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT' || (e.target && e.target.isContentEditable);
		}
		function onKey(e) {
			if (store.activeTab !== 'dungeonPieces') return;
			const c = activeCol.value;
			const k = e.key.toLowerCase();
			if ((e.ctrlKey || e.metaKey) && k === 'z' && !e.shiftKey) { e.preventDefault(); c.undo(); }
			else if ((e.ctrlKey || e.metaKey) && (k === 'y' || (e.shiftKey && k === 'z'))) { e.preventDefault(); c.redo(); }
			else if ((e.ctrlKey || e.metaKey) && k === 'd') { e.preventDefault(); c.duplicate(); }
			else if ((e.ctrlKey || e.metaKey) && k === 'c' && !_typingTarget(e)) { e.preventDefault(); c.copy(); }
			else if ((e.ctrlKey || e.metaKey) && k === 'v' && !_typingTarget(e)) { e.preventDefault(); c.paste(); }
			else if (e.key === 'Delete' && !_typingTarget(e)) { e.preventDefault(); c.remove(); }
		}
		onMounted(() => window.addEventListener('keydown', onKey));
		onUnmounted(() => window.removeEventListener('keydown', onKey));

		// ── Renombrado con guardia para tipos de comportamiento FIJO ───────────
		function renameCurrent(newId) {
			if (activeKind.value === 'tile' && isHardcodedTile.value) {
				const ok = confirm(
					'"' + selectedId.value + '" tiene comportamiento FIJO en el código (GridDungeonStage.gd).\n\n' +
					'Renombrarlo NO rompe las mazmorras ya guardadas (siguen usando el id viejo), pero cualquier ' +
					'casilla NUEVA que coloques con el nuevo id perderá su comportamiento especial (caerá a suelo ' +
					'genérico). ¿Renombrar de todos modos?'
				);
				if (!ok) return;
			}
			activeCol.value.rename(newId);
		}
		function removeCurrent() {
			if (activeKind.value === 'tile' && isHardcodedTile.value) {
				const ok = confirm(
					'"' + selectedId.value + '" tiene comportamiento FIJO en el código. Borrar esta entrada solo la ' +
					'quita de la PALETA del editor (las casillas ya colocadas seguirán renderizándose igual, hay una ' +
					'red de seguridad en GridDungeonStage.gd). ¿Borrar de todos modos?'
				);
				if (!ok) return;
			}
			activeCol.value.remove();
		}

		// ── Campos de CASILLA (idéntico a DungeonTilesManager) ──────────────────
		function setTileField(field, v) { tilesCol.edit(() => { tilesCol.current.value[field] = v; }); }
		function setTileNumberField(field, v) { tilesCol.edit(() => { tilesCol.current.value[field] = parseFloat(v) || 0; }); }
		function setTileBoolField(field, v) { tilesCol.edit(() => { tilesCol.current.value[field] = !!v; }); }
		function setShape(shape) {
			tilesCol.edit(() => {
				const c = tilesCol.current.value;
				if (!shape) { delete c.render; return; }
				if (!c.render || typeof c.render !== 'object') c.render = {};
				c.render.shape = shape;
			});
		}
		function setRenderField(field, v) { tilesCol.edit(() => { const c = tilesCol.current.value; if (!c.render) c.render = {}; c.render[field] = v; }); }
		function toggleLight(on) {
			tilesCol.edit(() => {
				const c = tilesCol.current.value;
				if (!c.render) c.render = {};
				if (on) c.render.light = { color: [1.0, 0.85, 0.6], energy: 2.4, range_mult: 3.0, height_mult: 0.6 };
				else delete c.render.light;
			});
		}
		function setLightColor(hex) { tilesCol.edit(() => { tilesCol.current.value.render.light.color = hexToRgbArr(hex); }); }
		function setLightField(field, v) { tilesCol.edit(() => { tilesCol.current.value.render.light[field] = parseFloat(v) || 0; }); }

		const modelFiles = ref([]);
		const modelPickerOpen = ref(false);
		async function refreshModelFiles() { modelFiles.value = await FS.listAssets('dungeon_model'); }
		function openModelPicker() { modelPickerOpen.value = true; refreshModelFiles(); }
		function closeModelPicker() { modelPickerOpen.value = false; }
		function selectModelFile(file) { setRenderField('model', file); modelPickerOpen.value = false; }
		function onUploadModel(ev) {
			const file = ev.target.files && ev.target.files[0];
			ev.target.value = '';
			if (!file) return;
			if (!/\.(glb|obj)$/i.test(file.name)) { alert('Solo se admiten modelos .glb o .obj.'); return; }
			let id = (window.prompt('Id/Nombre del modelo (sin extensión):', tilesCol.current.value?.t || file.name.replace(/\.(glb|obj)$/i, '')) || '').trim();
			if (!id) return;
			if (!/^[A-Za-z0-9_-]+$/.test(id)) { alert('Id no válido: solo letras, números, "_" y "-".'); return; }
			const ext = file.name.slice(file.name.lastIndexOf('.')).toLowerCase();
			const filename = id + ext;
			const reader = new FileReader();
			reader.onload = async () => {
				try {
					await FS.uploadAsset('dungeon_model', filename, reader.result, 'application/octet-stream');
					setRenderField('model', filename);
					await refreshModelFiles();
					alert(`Modelo 3D "${filename}" subido y asignado.`);
				} catch (e) { alert(e.message || String(e)); }
			};
			reader.readAsArrayBuffer(file);
		}

		// ── Campos de PIEZA de kit (idéntico a DungeonKitsManager) ──────────────
		const archetypeDef = computed(() => ARCHETYPES[piecesCol.current.value?.archetype] || null);
		function setPieceField(field, v) { piecesCol.edit(() => { piecesCol.current.value[field] = v; }); }
		function setPieceNameField(lang, v) { piecesCol.edit(() => { setI18n(piecesCol.current.value, 'name', v, lang); }); }
		function setArchetype(a) {
			piecesCol.edit(() => {
				const c = piecesCol.current.value;
				c.archetype = a;
				c.reaction = defaultReaction(a);
				if (!ARCHETYPES[a]?.mass) delete c.mass; else c.mass = c.mass ?? 1.0;
				if (!ARCHETYPES[a]?.motion) delete c.motion; else c.motion = c.motion || { kind: 'spin', axis: 'y', amplitude: 2.0, speed: 2.0 };
			});
		}
		function setMass(v) { piecesCol.edit(() => { piecesCol.current.value.mass = parseFloat(v) || 0; }); }
		function setMotionField(field, v) {
			piecesCol.edit(() => {
				const c = piecesCol.current.value;
				c.motion = c.motion || {};
				c.motion[field] = (field === 'kind' || field === 'axis' || field === 'direction') ? v : (parseFloat(v) || 0);
			});
		}
		function setReactionField(field, v) { piecesCol.edit(() => { piecesCol.current.value.reaction[field] = v; }); }
		function setReactionNumberField(field, v) { piecesCol.edit(() => { piecesCol.current.value.reaction[field] = parseFloat(v) || 0; }); }
		function setReactionBoolField(field, v) { piecesCol.edit(() => { piecesCol.current.value.reaction[field] = !!v; }); }
		function setReactionVerbs(csv) { piecesCol.edit(() => { piecesCol.current.value.reaction.verbs = csv.split(',').map((s) => s.trim()).filter(Boolean); }); }

		// ── Sub-editor de KITS (habilidades: kinetic_wave/psychic_grab/…) ───────
		const kitsSubTab = ref(false); // false = piezas normales; true = editando habilidades
		const selectedKit = computed({ get: () => store.selectedKit, set: (v) => { store.selectedKit = v; } });
		const currentKit = computed(() => (selectedKit.value ? kits.value[selectedKit.value] : null));
		function touchKits() { markDirty('dungeonKits'); }
		function addKit() {
			let code = 'kit_nuevo', n = 1;
			while (kits.value[code]) code = 'kit_nuevo_' + (++n);
			kits.value[code] = { label: { es: 'Nuevo kit', en: 'New kit' }, verb: 'impact', icon: '✨', color: '#8888ff' };
			touchKits();
			selectedKit.value = code;
		}
		function removeKit(code) {
			const pieceCount = Object.values(store.dungeonKits.pieces || {}).filter((p) => p.kit === code).length;
			if (!confirm('¿Eliminar kit "' + code + '"? Tiene ' + pieceCount + ' pieza(s) asociada(s) que quedarán sin kit válido.')) return;
			delete kits.value[code];
			touchKits();
			selectedKit.value = Object.keys(kits.value)[0] || null;
		}
		function renameKit(newCode) {
			newCode = (newCode || '').trim();
			const oldCode = selectedKit.value;
			if (!newCode || newCode === oldCode) return;
			if (kits.value[newCode]) { store.error = 'Ya existe un kit "' + newCode + '".'; return; }
			kits.value[newCode] = kits.value[oldCode];
			delete kits.value[oldCode];
			for (const p of Object.values(store.dungeonKits.pieces || {})) { if (p.kit === oldCode) p.kit = newCode; }
			selectedKit.value = newCode;
			touchKits();
		}
		function setKitField(field, v) { currentKit.value[field] = v; touchKits(); }
		function setKitLabel(lang, v) { setI18n(currentKit.value, 'label', v, lang); touchKits(); }

		return {
			store, CATEGORY_META,
			TILE_GROUPS, RENDER_SHAPES, KIT_SHAPES, ELEMENTS, VERBS, ARCHETYPE_KEYS, ARCHETYPES,
			fakeCol, current, activeKind, activeCol, isHardcodedTile, selectedId,
			renameCurrent, removeCurrent,
			// casilla
			tilesCol, setTileField, setTileNumberField, setTileBoolField,
			setShape, setRenderField, toggleLight, setLightColor, setLightField, rgbArrToHex,
			modelFiles, modelPickerOpen, openModelPicker, closeModelPicker, selectModelFile, onUploadModel,
			// pieza
			piecesCol, archetypeDef, setPieceField, setPieceNameField, setArchetype, setMass, setMotionField,
			setReactionField, setReactionNumberField, setReactionBoolField, setReactionVerbs, addPiece,
			// kits (habilidades)
			kitsSubTab, kits, selectedKit, currentKit, addKit, removeKit, renameKit, setKitField, setKitLabel,
			getI18n, getI18nFallback,
		};
	},
	template: `
	<div class="manager">
		<template v-if="!kitsSubTab">
			<entity-list-panel :c="fakeCol" search-placeholder="Buscar casilla o pieza…" new-label="＋ Nueva casilla">
				<template #row="{ id, o }">
					<span class="ent-icon">{{ (o && (o.icon || (o.name && '🧩'))) || '⬜' }}</span>
					<span class="ent-name">{{ (o && (o.label || (o.name && (o.name.es || o.name.en)))) || id }}</span>
					<span class="ent-id mono">{{ id }}</span>
				</template>
				<template #extra-actions>
					<button class="btn ghost sm" @click="addPiece">➕ Nueva pieza (Obj. Inteligente)</button>
					<button class="btn ghost sm" @click="kitsSubTab = true">⚙️ Gestionar kits (habilidades)</button>
				</template>
			</entity-list-panel>

			<section class="editor-pane" v-if="current">
				<editor-toolbar :can-undo="activeCol.canUndo.value" :can-redo="activeCol.canRedo.value"
					:can-paste="activeCol.canPaste.value" :has-current="!!current" :dirty="activeCol.dirty.value"
					:saved-text="activeCol.savedText.value"
					@undo="activeCol.undo()" @redo="activeCol.redo()" @copy="activeCol.copy()" @paste="activeCol.paste()"
					@duplicate="activeCol.duplicate()" @remove="removeCurrent()" @save="activeCol.doSave()"></editor-toolbar>

				<p class="muted sm" :class="'category-hint category-hint--' + (activeKind==='piece' ? 'smart' : (isHardcodedTile ? 'fixed' : 'cosmetic'))">
					<template v-if="activeKind === 'piece'">🧩 <b>Objeto Inteligente</b> — archetype + shape + reaction definen aspecto Y comportamiento aquí mismo, sin tocar código.</template>
					<template v-else-if="isHardcodedTile">🔒 <b>Comportamiento fijo</b> — este tipo tiene su propia lógica en <span class="mono">GridDungeonStage.gd</span>. Aquí solo editas su etiqueta/icono/color/grupo de paleta; el comportamiento en juego NO depende de estos campos.</template>
					<template v-else>🎨 <b>Cosmético (sin código)</b> — sin lógica dedicada. Su geometría la decide por completo el bloque "Render genérico" de abajo.</template>
				</p>

				<!-- ══════════ PANEL DE CASILLA ══════════ -->
				<template v-if="activeKind === 'tile'">
					<h3 class="sec">🧱 Casilla</h3>
					<div class="form-grid">
						<label>ID
							<input class="input mono" type="text" :value="selectedId" @change="renameCurrent($event.target.value)" />
						</label>
						<label>Icono
							<input class="input f-xs" type="text" :value="current.icon" @input="setTileField('icon', $event.target.value)" placeholder="⬜" />
						</label>
						<label class="full">Etiqueta
							<input class="input" type="text" :value="current.label" @input="setTileField('label', $event.target.value)" />
						</label>
						<label>Color pincel
							<input class="input" type="color" :value="current.color || '#888888'" @input="setTileField('color', $event.target.value)" />
						</label>
						<label>Grupo (paleta)
							<input class="input" type="text" list="dt-groups" :value="current.group || ''" @input="setTileField('group', $event.target.value)" />
							<datalist id="dt-groups"><option v-for="g in TILE_GROUPS" :key="g" :value="g"></option></datalist>
						</label>
						<label>Orden en el grupo
							<input class="input" type="number" step="1" :value="current.order ?? 0" @input="setTileNumberField('order', $event.target.value)" />
						</label>
					</div>

					<template v-if="isHardcodedTile">
						<h3 class="sec">⚙️ Flags de comportamiento <span class="muted" style="font-weight:400">(reflejan lo que ya hace el código)</span></h3>
						<div class="form-grid">
							<label class="check"><input type="checkbox" :checked="!!current.solid" @change="setTileBoolField('solid', $event.target.checked)" /> Sólido (bloquea paso)</label>
							<label class="check"><input type="checkbox" :checked="!!current.entity" @change="setTileBoolField('entity', $event.target.checked)" /> Entidad (usa marcador/nodo propio)</label>
							<label class="check"><input type="checkbox" :checked="!!current.actuator" @change="setTileBoolField('actuator', $event.target.checked)" /> Actuador (switch/button/lever/pressure)</label>
							<label class="check"><input type="checkbox" :checked="!!current.stateful" @change="setTileBoolField('stateful', $event.target.checked)" /> Con estado (on/off persistente)</label>
							<label class="check"><input type="checkbox" :checked="!!current.orient" @change="setTileBoolField('orient', $event.target.checked)" /> Orientable (decoración con rotación)</label>
							<label class="check"><input type="checkbox" :checked="!!current.smart" @change="setTileBoolField('smart', $event.target.checked)" /> Objeto Inteligente (usa kit de piezas)</label>
						</div>

						<h3 class="sec">🖼️ Modelo 3D personalizado</h3>
						<p class="muted">Sustituye solo el ASPECTO por el modelo que subas; si lo dejas vacío se usa el aspecto por defecto. El comportamiento (arriba) no cambia.</p>
						<div class="form-grid">
							<label class="full">Modelo 3D (.glb / .obj / .tscn en assets/common/models/)
								<div class="row gap">
									<input class="input mono" type="text" :value="(current.render && current.render.model) || ''" @input="setRenderField('model', $event.target.value)" placeholder="interactive/torch.glb" />
									<button class="btn xs secondary" @click="openModelPicker" type="button">📂 Elegir existente</button>
									<label class="btn xs ghost" style="cursor:pointer; margin:0">⭱ Subir modelo
										<input type="file" accept=".glb,.obj,.gltf,.tscn" style="display:none" @change="onUploadModel" />
									</label>
								</div>
							</label>
							<div class="tex-modal" v-if="modelPickerOpen">
								<div class="tex-modal__backdrop" @click="closeModelPicker"></div>
								<div class="tex-modal__box">
									<div class="tex-modal__head"><b>Elegir modelo 3D (assets/common/models/)</b><button class="btn xs ghost" @click="closeModelPicker">✕</button></div>
									<ul class="entity-list" style="max-height:320px">
										<li v-for="f in modelFiles" :key="f" @click="selectModelFile(f)"><span class="ent-icon">📦</span><span class="ent-name mono">{{ f }}</span></li>
										<li v-if="!modelFiles.length" class="empty-row">No hay modelos en assets/common/models/.</li>
									</ul>
								</div>
							</div>
						</div>
					</template>

					<template v-else>
						<h3 class="sec">✨ Render genérico <span class="muted" style="font-weight:400">(esto es lo que de verdad dibuja esta casilla)</span></h3>
						<div class="form-grid">
							<label>Forma (shape)
								<select class="input" :value="(current.render && current.render.shape) || ''" @change="setShape($event.target.value)">
									<option v-for="s in RENDER_SHAPES" :key="s" :value="s">{{ s || '(sin render → losa de suelo)' }}</option>
								</select>
							</label>
							<template v-if="current.render && current.render.shape === 'model'">
								<label class="full">Modelo 3D
									<div class="row gap">
										<input class="input mono" type="text" :value="(current.render && current.render.model) || ''" @input="setRenderField('model', $event.target.value)" placeholder="interactive/mi_modelo.glb" />
										<button class="btn xs secondary" @click="openModelPicker" type="button">📂 Elegir existente</button>
										<label class="btn xs ghost" style="cursor:pointer; margin:0">⭱ Subir modelo<input type="file" accept=".glb,.obj,.gltf,.tscn" style="display:none" @change="onUploadModel" /></label>
									</div>
								</label>
								<div class="tex-modal" v-if="modelPickerOpen">
									<div class="tex-modal__backdrop" @click="closeModelPicker"></div>
									<div class="tex-modal__box">
										<div class="tex-modal__head"><b>Elegir modelo 3D</b><button class="btn xs ghost" @click="closeModelPicker">✕</button></div>
										<ul class="entity-list" style="max-height:320px">
											<li v-for="f in modelFiles" :key="f" @click="selectModelFile(f)"><span class="ent-icon">📦</span><span class="ent-name mono">{{ f }}</span></li>
											<li v-if="!modelFiles.length" class="empty-row">No hay modelos en assets/common/models/.</li>
										</ul>
									</div>
								</div>
							</template>
							<template v-if="current.render && current.render.shape === 'liquid'">
								<label>Material
									<select class="input" :value="current.render.material || 'water'" @change="setRenderField('material', $event.target.value)">
										<option value="water">water</option><option value="lava">lava</option>
									</select>
								</label>
								<label>Peligro (hazard)
									<select class="input" :value="current.render.hazard || ''" @change="setRenderField('hazard', $event.target.value)">
										<option value="">(ninguno)</option><option value="water">water</option><option value="lava">lava</option><option value="spikes">spikes</option>
									</select>
								</label>
							</template>
							<template v-if="current.render && current.render.shape === 'cone'">
								<label>Peligro (hazard)
									<input class="input" type="text" :value="current.render.hazard || 'spikes'" @input="setRenderField('hazard', $event.target.value)" />
								</label>
							</template>
						</div>
						<template v-if="current.render && (current.render.shape === 'light' || current.render.shape === 'liquid')">
							<label class="check">
								<input type="checkbox" :checked="!!current.render.light" @change="toggleLight($event.target.checked)" />
								{{ current.render.shape === 'light' ? 'Configurar luz' : 'Incluir luz adicional' }}
							</label>
							<div class="form-grid" v-if="current.render.light">
								<label>Color<input class="input" type="color" :value="rgbArrToHex(current.render.light.color)" @input="setLightColor($event.target.value)" /></label>
								<label>Energía<input class="input" type="number" step="0.1" min="0" :value="current.render.light.energy ?? 1.5" @input="setLightField('energy', $event.target.value)" /></label>
								<label>Multiplicador de alcance<input class="input" type="number" step="0.1" min="0" :value="current.render.light.range_mult ?? 2.0" @input="setLightField('range_mult', $event.target.value)" /></label>
								<label>Multiplicador de altura<input class="input" type="number" step="0.05" min="0" :value="current.render.light.height_mult ?? 0.5" @input="setLightField('height_mult', $event.target.value)" /></label>
							</div>
						</template>
					</template>
				</template>

				<!-- ══════════ PANEL DE PIEZA DE KIT ══════════ -->
				<template v-else>
					<h3 class="sec">🧩 Pieza</h3>
					<div class="form-grid">
						<label>ID
							<input class="input mono" type="text" :value="selectedId" @change="renameCurrent($event.target.value)" />
						</label>
						<label>Icono
							<input class="input f-xs" type="text" :value="current.icon" @input="setPieceField('icon', $event.target.value)" placeholder="🧩" />
						</label>
						<label>Kit (habilidad)
							<select class="input" :value="current.kit" @change="setPieceField('kit', $event.target.value)">
								<option v-for="(k, code) in kits" :key="code" :value="code">{{ (k.label && k.label.es) || code }} ({{ code }})</option>
							</select>
						</label>
						<label>Nombre [{{ store.currentLang.toUpperCase() }}]
							<input class="input" type="text" :value="getI18n(current.name)" :placeholder="getI18nFallback(current.name) || 'Nombre de la pieza...'" @input="setPieceNameField(store.currentLang, $event.target.value)" />
						</label>
						<label>Color
							<input class="input" type="color" :value="current.color || '#8a8a8a'" @input="setPieceField('color', $event.target.value)" />
						</label>
						<label>Forma (shape)
							<select class="input" :value="current.shape || 'box'" @change="setPieceField('shape', $event.target.value)">
								<option v-for="s in KIT_SHAPES" :key="s" :value="s">{{ s }}</option>
							</select>
						</label>
						<label>Arquetipo (cuerpo + reacción)
							<select class="input" :value="current.archetype" @change="setArchetype($event.target.value)">
								<option v-for="a in ARCHETYPE_KEYS" :key="a" :value="a">{{ ARCHETYPES[a].label }}</option>
							</select>
						</label>
					</div>

					<template v-if="store.expertMode && archetypeDef && archetypeDef.mass">
						<h3 class="sec">⚖️ Masa <span class="muted" style="font-weight:400">(experto)</span></h3>
						<div class="form-grid">
							<label>Masa (kg aprox.)<input class="input" type="number" step="0.1" min="0.1" :value="current.mass ?? 1.0" @input="setMass($event.target.value)" /></label>
						</div>
					</template>

					<template v-if="store.expertMode && archetypeDef && archetypeDef.motion">
						<h3 class="sec">🌀 Movimiento <span class="muted" style="font-weight:400">(experto)</span></h3>
						<template v-if="current.archetype === 'auto_platform'">
							<p class="muted sm">Este arquetipo siempre está en marcha (modo "shuttle": va y vuelve desde el origen), sin depender de ninguna habilidad. Dirección/Distancia de aquí son solo el valor por defecto: cada casilla donde se coloque puede indicar su propia Dirección/Distancia desde el editor de mazmorras.</p>
							<div class="form-grid">
								<label>Dirección por defecto
									<select class="input" :value="current.motion.direction || 'horizontal'" @change="setMotionField('direction', $event.target.value)">
										<option value="horizontal">Horizontal (→ derecha)</option>
										<option value="vertical">Vertical (↑ arriba)</option>
									</select>
								</label>
								<label>Distancia por defecto (casillas)<input class="input" type="number" min="1" step="1" :value="current.motion.distance ?? 3" @input="setMotionField('distance', $event.target.value)" /></label>
								<label>Velocidad<input class="input" type="number" step="0.1" min="0" :value="current.motion.speed ?? 1.0" @input="setMotionField('speed', $event.target.value)" /></label>
							</div>
						</template>
						<div class="form-grid" v-else-if="current.motion">
							<label>Tipo
								<select class="input" :value="current.motion.kind" @change="setMotionField('kind', $event.target.value)">
									<option value="slide">slide (desliza)</option><option value="bob">bob (sube/baja)</option>
									<option value="spin">spin (gira)</option><option value="gate">gate (compuerta)</option>
								</select>
							</label>
							<label>Eje
								<select class="input" :value="current.motion.axis" @change="setMotionField('axis', $event.target.value)">
									<option value="x">x</option><option value="y">y</option><option value="z">z</option>
								</select>
							</label>
							<label>Amplitud<input class="input" type="number" step="0.1" min="0" :value="current.motion.amplitude ?? 2.0" @input="setMotionField('amplitude', $event.target.value)" /></label>
							<label>Velocidad<input class="input" type="number" step="0.1" min="0" :value="current.motion.speed ?? 2.0" @input="setMotionField('speed', $event.target.value)" /></label>
						</div>
					</template>

					<h3 class="sec">⚡ Reacción ({{ archetypeDef ? (archetypeDef.reactionType || 'ninguna') : '' }})</h3>
					<div class="form-grid" v-if="current.reaction">
						<template v-for="f in (archetypeDef ? archetypeDef.fields : [])" :key="f">
							<label v-if="f === 'verbs'">Verbos que activan (coma)<input class="input mono" type="text" :value="(current.reaction.verbs || []).join(', ')" @change="setReactionVerbs($event.target.value)" :list="'dk-verbs'" /></label>
							<label v-else-if="f === 'accepted_element' || f === 'source_element' || f === 'element'">{{ f }}
								<select class="input" :value="current.reaction[f]" @change="setReactionField(f, $event.target.value)">
									<option v-for="e in ELEMENTS" :key="e" :value="e">{{ e }}</option>
								</select>
							</label>
							<label v-else-if="f === 'clean'">Estado limpio
								<select class="input" :value="current.reaction.clean || 'none'" @change="setReactionField('clean', $event.target.value)">
									<option value="none">none (suelo desnudo)</option><option value="water">water (lámina de agua)</option>
								</select>
							</label>
							<label v-else-if="f === 'one_way' || f === 'one_shot' || f === 'proximity' || f === 'lit'" class="check">
								<input type="checkbox" :checked="!!current.reaction[f]" @change="setReactionBoolField(f, $event.target.checked)" /> {{ f }}
							</label>
							<label v-else-if="f === 'min_strength' || f === 'impact_force' || f === 'pull_force' || f === 'anchor_offset_y' || f === 'slow_factor' || f === 'reveal_seconds'">{{ f }}
								<input class="input" type="number" step="0.1" min="0" :value="current.reaction[f] ?? 0" @input="setReactionNumberField(f, $event.target.value)" />
							</label>
							<label v-else class="mono">{{ f }} (evento global)<input class="input mono" type="text" :value="current.reaction[f] || ''" @input="setReactionField(f, $event.target.value)" placeholder="EVENT_ALGO" /></label>
						</template>
						<p v-if="!(archetypeDef && archetypeDef.fields.length)" class="muted sm">Este arquetipo no necesita ninguna habilidad para activarse — siempre está en marcha.</p>
					</div>
					<datalist id="dk-verbs"><option v-for="v in VERBS" :key="v" :value="v"></option></datalist>

					<p class="muted" style="margin-top:10px">
						Para usarlo: colócala como <span class="mono">kit</span> de una casilla tipo <span class="mono">smart</span> en el editor de mazmorras (aparece sola en el grupo de su habilidad).
					</p>
				</template>
			</section>

			<section class="editor-pane empty" v-else>
				<p class="muted">Selecciona o crea una casilla/pieza.</p>
			</section>
		</template>

		<!-- ══════════ SUB-PANTALLA: KITS (habilidades) ══════════ -->
		<template v-else>
			<aside class="side">
				<div class="side-tools">
					<button class="btn ghost sm" @click="kitsSubTab = false">⬅️ Volver a casillas/piezas</button>
					<button class="btn primary sm" @click="addKit">➕ Nuevo kit</button>
				</div>
				<ul class="entity-list">
					<li v-for="(k, code) in kits" :key="code" :class="{ active: selectedKit === code }" @click="selectedKit = code">
						<span class="ent-icon">{{ k.icon || '✨' }}</span>
						<span class="ent-name">{{ (k.label && k.label.es) || code }}</span>
						<span class="ent-id mono">{{ code }}</span>
					</li>
					<li v-if="!Object.keys(kits).length" class="empty-row">Sin kits.</li>
				</ul>
			</aside>

			<section class="editor-pane" v-if="currentKit">
				<div class="pane-header">
					<h3 class="sec">✨ Kit (habilidad)</h3>
					<button class="btn sm err" @click="removeKit(selectedKit)">🗑️ Eliminar</button>
				</div>
				<div class="form-grid">
					<label>ID<input class="input mono" type="text" :value="selectedKit" @change="renameKit($event.target.value)" /></label>
					<label>Icono<input class="input f-xs" type="text" :value="currentKit.icon" @input="setKitField('icon', $event.target.value)" placeholder="✨" /></label>
					<label>Verbo (habilidad que lo activa)
						<select class="input" :value="currentKit.verb" @change="setKitField('verb', $event.target.value)">
							<option v-for="v in VERBS" :key="v" :value="v">{{ v }}</option>
						</select>
					</label>
					<label>Color<input class="input" type="color" :value="currentKit.color || '#8888ff'" @input="setKitField('color', $event.target.value)" /></label>
					<label>Etiqueta [{{ store.currentLang.toUpperCase() }}]
						<input class="input" type="text" :value="getI18n(currentKit.label)" :placeholder="getI18nFallback(currentKit.label) || 'Etiqueta del kit...'" @input="setKitLabel(store.currentLang, $event.target.value)" />
					</label>
				</div>
				<p class="muted" style="margin-top:10px">Cambiar el código de un kit reasigna automáticamente las piezas que lo usaban.</p>
			</section>
			<section class="editor-pane empty" v-else>
				<p class="muted">Selecciona o crea un kit.</p>
			</section>
		</template>
	</div>
	`,
};
