// components/MapEditor.js
// ─────────────────────────────────────────────────────────────────────────────
// Editor visual del mapamundi: rejilla width×height, paleta de terrenos, modo
// pincel (clic + arrastre) y un inspector lateral por celda. Trabaja siempre
// sobre store.world.tiles (mutación reactiva) y marca `world` como sucio.
//
// TAREA 2 — Herramienta profesional: redimensionar el mundo desde cualquier
// borde (con previsualización), historial deshacer/rehacer, autoguardado,
// duplicar entidades (ids.json + sus NPCs/hijos) y snapshots (puntos de
// restauración exportables/importables). NO cambia el formato de datos ni el
// runtime: sigue produciendo `{ width, height, tiles }` idéntico.
// ─────────────────────────────────────────────────────────────────────────────
import { computed, ref, reactive, watch, onMounted, onUnmounted, onActivated, nextTick } from 'https://unpkg.com/vue@3/dist/vue.esm-browser.prod.js';
import { store, markDirty, markWorldDirty, markDungeonDirty, switchMap, save, flash, terrainsList, terrainMap, resourcesList, getI18n, getI18nFallback, getI18nDisplay, setI18n } from '../store.js';
import { useHistory, deepClone } from '../lib/useHistory.js';
import { useAutosave } from '../lib/useAutosave.js';
import { useSnapshots } from '../lib/snapshots.js';
import { listAssets } from '../fs.js';
import TEMPLATE from './templates/MapEditorTemplate.js';

export default {
	name: 'MapEditor',
	setup() {
		const npcAssetFiles = ref([]);
		onMounted(async () => {
			try {
				npcAssetFiles.value = await listAssets('npc');
			} catch (_) {}
		});
		const painting = ref(false);
		const drawMode = ref('pencil'); // 'pencil' | 'rect' | 'fill'
		const rectStart = ref(null); // { x, y }
		const rectEnd = ref(null); // { x, y }

		function isInRect(x, y) {
			if (drawMode.value !== 'rect' || !rectStart.value || !rectEnd.value) return false;
			const x0 = Math.min(rectStart.value.x, rectEnd.value.x);
			const x1 = Math.max(rectStart.value.x, rectEnd.value.x);
			const y0 = Math.min(rectStart.value.y, rectEnd.value.y);
			const y1 = Math.max(rectStart.value.y, rectEnd.value.y);
			return x >= x0 && x <= x1 && y >= y0 && y <= y1;
		}

		// ── Task 5 (5.1): herramienta MEDIR (regla Manhattan/Euclidiana) ────────
		const measureStart = ref(null); // { x, y }
		const measureEnd = ref(null);   // { x, y }
		const measuring = ref(false);
		function measureDown(x, y) { measuring.value = true; measureStart.value = { x, y }; measureEnd.value = { x, y }; }
		function measureMove(x, y) { if (measuring.value) measureEnd.value = { x, y }; }
		function measureUp() { measuring.value = false; }
		const measureInfo = computed(() => {
			if (!measureStart.value || !measureEnd.value) return null;
			const dx = measureEnd.value.x - measureStart.value.x;
			const dy = measureEnd.value.y - measureStart.value.y;
			return { manhattan: Math.abs(dx) + Math.abs(dy), euclidean: Math.sqrt(dx * dx + dy * dy).toFixed(2), dx, dy };
		});

		// ── Task 5 (5.1): herramienta REGIÓN (seleccionar/copiar/pegar un área
		// rectangular de casillas, ej. clonar un lago o un bosque) ─────────────
		const regionSel = ref(null);      // { x0, y0, x1, y1 } (normalizado, x0<=x1, y0<=y1)
		const regionDragStart = ref(null); // { x, y } mientras se arrastra la selección
		const regionClipboard = ref(null); // { w, h, tiles: [[tile,...],...] }
		const regionPasteReady = ref(false); // true tras Ctrl+V: el próximo clic pega
		function regionNormalize(a, b) {
			return { x0: Math.min(a.x, b.x), y0: Math.min(a.y, b.y), x1: Math.max(a.x, b.x), y1: Math.max(a.y, b.y) };
		}
		function clearRegion() {
			regionSel.value = null;
			regionDragStart.value = null;
			regionPasteReady.value = false;
		}
		function regionDown(x, y) {
			if (regionPasteReady.value) { pasteRegionAt(x, y); return; }
			regionDragStart.value = { x, y };
			regionSel.value = regionNormalize({ x, y }, { x, y });
		}
		function regionMove(x, y) { if (regionDragStart.value) regionSel.value = regionNormalize(regionDragStart.value, { x, y }); }
		function regionUp() { regionDragStart.value = null; }
		function isInRegionSel(x, y) {
			if (store.brush.tool !== 'region' && !regionPasteReady.value) return false;
			const r = regionSel.value;
			return !!r && x >= r.x0 && x <= r.x1 && y >= r.y0 && y <= r.y1;
		}
		function copyRegion() {
			const r = regionSel.value;
			if (!r) { flash('Selecciona primero un área con la herramienta Región.'); return; }
			const tiles = [];
			for (let y = r.y0; y <= r.y1; y++) {
				const row = [];
				for (let x = r.x0; x <= r.x1; x++) row.push(deepClone(tileAt(x, y)) || { terrain: 'water' });
				tiles.push(row);
			}
			regionClipboard.value = { w: r.x1 - r.x0 + 1, h: r.y1 - r.y0 + 1, tiles };
			flash('📋 Región copiada: ' + regionClipboard.value.w + '×' + regionClipboard.value.h + ' casillas.');
		}
		function requestPasteRegion() {
			if (!regionClipboard.value) { flash('No hay ninguna región copiada.'); return; }
			regionPasteReady.value = true;
			flash('📥 Haz clic en el mapa para pegar la región (esquina superior-izquierda).');
		}
		function pasteRegionAt(x, y) {
			const clip = regionClipboard.value;
			regionPasteReady.value = false;
			if (!clip) return;
			pushHistory();
			for (let dy = 0; dy < clip.h; dy++) {
				for (let dx = 0; dx < clip.w; dx++) {
					const t = tileAt(x + dx, y + dy);
					if (!t) continue;
					Object.assign(t, deepClone(clip.tiles[dy][dx]));
				}
			}
			markWorldDirty();
			scheduleMinimapDraw();
			flash('✅ Región pegada en (' + x + ', ' + y + ').');
		}

		// Helper para resolver la miniatura real del sprite del enemigo
		function getEnemySpriteUrl(enemyId) {
			if (!enemyId) return null;
			const e = store.enemies?.[enemyId];
			const img = e?.image || e?.sprite || '';
			if (!img) return null;
			const file = img.split('/').pop();
			if (!file || file === '👾' || file === '❓') return null;
			return `/api/assets/enemy/${encodeURIComponent(file)}`;
		}

		function getTileEnemy(t) {
			if (!t || !t.enemy) return null;
			const id = t.enemy.enemy || t.enemy.enemy_id || (typeof t.enemy === 'string' ? t.enemy : '');
			const sprite = getEnemySpriteUrl(id);
			const e = store.enemies?.[id];
			const name = getI18nDisplay(e?.name) || id || 'Enemigo';
			return { id, sprite, name };
		}

		// Zoom (rueda) y paneo (arrastre con botón central/derecho).
		const zoom = ref(1);
		const panning = ref(false);
		const panStart = ref({ x: 0, y: 0, sl: 0, st: 0 });
		const wrapRef = ref(null);

		// ── Panel de paleta (segundo menú) redimensionable a mano, con memoria ──
		// El nombre de las entidades/recursos no cabía en el ancho fijo de 220px;
		// ahora el usuario puede arrastrar el borde y el tamaño se recuerda entre
		// sesiones (misma clave que DsSplitPanel, ver ui/DsSplitPanel.js).
		const PALETTE_MIN = 220, PALETTE_MAX = 560;
		const storedPaletteW = Number(localStorage.getItem('ds-split:map-palette'));
		const paletteWidth = ref(Number.isFinite(storedPaletteW) && storedPaletteW > 0 ? storedPaletteW : 280);
		const paletteResizing = ref(false);
		function onPaletteResizeDown(e) {
			paletteResizing.value = true;
			e.preventDefault();
			window.addEventListener('mousemove', onPaletteResizeMove);
			window.addEventListener('mouseup', onPaletteResizeUp);
		}
		function onPaletteResizeMove(e) {
			if (!paletteResizing.value) return;
			const layoutEl = document.querySelector('.map-layout');
			const left = layoutEl ? layoutEl.getBoundingClientRect().left : 0;
			paletteWidth.value = Math.max(PALETTE_MIN, Math.min(e.clientX - left, PALETTE_MAX));
		}
		function onPaletteResizeUp() {
			paletteResizing.value = false;
			window.removeEventListener('mousemove', onPaletteResizeMove);
			window.removeEventListener('mouseup', onPaletteResizeUp);
			localStorage.setItem('ds-split:map-palette', String(paletteWidth.value));
		}

		const showInspector = ref(false); // Comienza oculto por defecto
		function toggleInspector() { showInspector.value = !showInspector.value; }
		const mapLayoutStyle = computed(() => {
			const inspW = showInspector.value ? '320px' : '44px';
			return { gridTemplateColumns: paletteWidth.value + 'px 8px 1fr ' + inspW, '--map-insp-w': inspW };
		});

		// Acceso directo al gestor de terrenos (crear/editar código, textura, clima,
		// velocidad, daño…) sin salir del flujo de pintado: el pincel solo elige,
		// pero editar/crear terrenos vive en su propio CRUD (Terrenos).
		function goToTerrainEditor() {
			if (store.worldTerrains && store.worldTerrains[store.brush.terrain]) {
				store.selectedWorldTerrain = store.brush.terrain;
			}
			store.activeTab = 'worldTerrains';
		}
		function goToNewTerrain() {
			store.selectedWorldTerrain = null;
			store.activeTab = 'worldTerrains';
		}
		// Salto directo a la mazmorra de esta casilla: sin esto,
		// el único camino era ids.json → copiar el id a mano → pestaña Mazmorras →
		// buscarlo en el desplegable. Reutiliza el watcher de DungeonEditor sobre
		// `selectedDungeon` (carga perezosa + refresco de previsualización).
		function goToDungeon(id) {
			if (!id) return;
			const idDef = store.ids?.[id];
			const dunId = idDef?.portal?.event_id || idDef?.portal?.target || idDef?.dungeon_id || id;
			if (store.dungeons && dunId in store.dungeons) {
				store.selectedDungeon = dunId;
				store.activeTab = 'dungeons';
			} else if (store.dungeons && id in store.dungeons) {
				store.selectedDungeon = id;
				store.activeTab = 'dungeons';
			}
		}
		// Crear una mazmorra EN BLANCO sin salir del mapa: antes
		// había que ir a la pestaña Mazmorras a crearla (y de paso se sincroniza
		// sola con ids.json) para volver aquí a colocarla — 2 saltos de pestaña
		// solo para "quiero una mazmorra nueva en este sitio". Deja el pincel de
		// Entidades listo con la mazmorra recién creada para clicar y colocarla.
		function slugifyDunId(s) {
			return String(s || '').toLowerCase().trim()
				.replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '') || 'dun';
		}
		function quickCreateDungeon() {
			if (!store.dungeons || !store.ids) return;
			const raw = prompt('Nombre de la nueva mazmorra:', 'Nueva mazmorra');
			if (raw === null) return;
			const base = slugifyDunId(raw || 'dun_new');
			let id = base, n = 2;
			while (store.dungeons[id]) id = base + '_' + (n++);
			const name = { es: raw || 'Nueva mazmorra', en: raw || 'New dungeon' };
			const blankCells = Array.from({ length: 8 }, () => Array.from({ length: 8 }, () => ({ t: 'void' })));
			store.dungeons[id] = {
				id, name, music: 'dungeon', boss: 'dungeon_boss', random_pool: [],
				cell_size: 3, wall_height: 3, spawn: { f: 0, x: 0, y: 0 },
				floors: [{ name: 'Planta 0', w: 8, h: 8, cells: blankCells }],
			};
			markDungeonDirty(id);
			if (!store.ids[id]) {
				store.ids[id] = { id, type: 'dungeon', name: deepClone(name), icon: '🕳️', desc: { es: '', en: '' } };
				markDirty('ids', id);
			}
			store.brush.tool = 'entity';
			store.brush.entityCat = 'dungeon';
			store.brush.entity = id;
			flash('Mazmorra "' + id + '" creada — haz clic en el mapa para colocarla (edítala del todo en la pestaña 🏰 Mazmorras).');
		}

		// Tooltip flotante al pasar el cursor por una casilla.
		// PERF: `hover` guarda solo la CELDA (x,y) — cambia como mucho una vez por
		// casilla. La posición en PANTALLA (px,py) se escribe directamente sobre
		// el `<div>` del tooltip vía `tooltipRef` (fuera de la reactividad de
		// Vue) en cada `mousemove`. Antes `hover.px/py` eran reactivos y se
		// mutaban en CADA mousemove (decenas de eventos por segundo mientras el
		// ratón se movía sobre el mapamundi), lo que forzaba un re-render
		// completo de la plantilla —incluida toda la rejilla virtualizada de
		// celdas— en cada pixel de movimiento: esa era la causa real de la
		// lentitud reportada al mover el ratón sobre el mapa.
		const hover = ref(null); // { x, y }
		const tooltipRef = ref(null);
		function positionTooltip(ev) {
			const el = tooltipRef.value;
			if (!el) return;
			el.style.left = (ev.clientX + 14) + 'px';
			el.style.top = (ev.clientY + 14) + 'px';
		}

		const world = computed(() => store.world);
		const width = computed(() => world.value?.width || 0);
		const height = computed(() => world.value?.height || 0);

		// Catálogo de terrenos/recursos, derivado de las colecciones data-driven
		// `store.worldTerrains`/`store.worldResources` (data/world_terrains/<code>.json,
		// data/world_resources/<code>.json). Solo se ofrecen como PINCEL los recursos
		// marcados `placeable` (los derivados automáticos como forestBad/gold NO).
		const TERRAINS = computed(() => terrainsList());
		const TERRAIN_MAP = computed(() => terrainMap());
		const placeableResources = computed(() => resourcesList().filter(r => r.placeable !== false));

		// Helper: ¿Carga este POI/entidad un sprite de personaje (NPC visible)?
		// En el motor (ViewPlace.gd / ViewForge.gd / ViewShop.gd + Design.gd):
		// - "Con NPC": el lugar carga y muestra el sprite del personaje (ej. Don Velocidad, guardián, anciana, etc.).
		//   Se comprueba si tiene avatar en su diálogo (_meta.reward "avatar=..."), si es una vista con sprite o
		//   si existe el asset de sprite en assets/vn/npcs/.
		// - "Sin NPC": el lugar NO carga sprite de NPC (ej. altares, tablones, buzones, cofres, tumbas sin retrato, etc.).
		function getPoiNpcSprite(id, obj) {
			if (!id && !obj) return null;
			const o = obj || store.ids?.[id];
			if (!o) return null;
			const sid = String(id || o.id || '');
			if (o.type === 'city' || o.type === 'dungeon' || sid.startsWith('city_') || sid.startsWith('dun_') || sid.startsWith('sendero_')) return null;

			const assetList = npcAssetFiles.value || [];
			if (assetList.length === 0) return null;

			// 1. Si el objeto declara avatar explícito en ids.json y es fichero de imagen
			if (o.avatar && typeof o.avatar === 'string' && (o.avatar.endsWith('.png') || o.avatar.endsWith('.jpg') || o.avatar.endsWith('.webp'))) {
				const clean = o.avatar.replace(/^res:\/\/assets\/vn\/npcs\//, '').replace(/^assets\/vn\/npcs\//, '');
				if (assetList.includes(clean)) return clean;
			}

			// 2. Comprobar diálogo NPC asociado en store.npcs
			const npcId = o.npc || sid;
			const npc = store.npcs?.[npcId];
			if (npc && npc._meta) {
				const meta = npc._meta;
				if (meta.avatar && typeof meta.avatar === 'string' && (meta.avatar.endsWith('.png') || meta.avatar.endsWith('.jpg') || meta.avatar.endsWith('.webp'))) {
					const clean = meta.avatar.replace(/^res:\/\/assets\/vn\/npcs\//, '').replace(/^assets\/vn\/npcs\//, '');
					if (assetList.includes(clean)) return clean;
				}
				const rew = String(meta.reward || '');
				const m = rew.match(/avatar=([^;\s]+)/);
				if (m && m[1] && (m[1].endsWith('.png') || m[1].endsWith('.jpg') || m[1].endsWith('.webp'))) {
					const clean = m[1].replace(/^res:\/\/assets\/vn\/npcs\//, '').replace(/^assets\/vn\/npcs\//, '');
					if (assetList.includes(clean)) return clean;
				}
			}

			// 3. Vistas especiales del motor que siempre cargan sprite (ej. Herrería Borin en ViewForge)
			if (o.kind === 'forge' || sid === 'poi_sylphrena_herrero') {
				if (assetList.includes('npc_sylphrena_herrero.png')) return 'npc_sylphrena_herrero.png';
			}

			// 4. Comprobación contra assets de sprites reales (/api/assets/npc)
			const bg = String(o.bg || '');
			let candSprite = null;
			if (bg.startsWith('bg_')) {
				candSprite = 'npc_' + bg.substring(3);
			} else {
				candSprite = `npc_${npcId}.png`;
			}

			if (candSprite && assetList.includes(candSprite)) return candSprite;
			if (assetList.includes(`npc_${npcId}.png`)) return `npc_${npcId}.png`;
			if (assetList.includes(`npc_${sid}.png`)) return `npc_${sid}.png`;

			return null;
		}

		function isPoiWithNpc(id, obj) {
			const o = obj || store.ids?.[id];
			if (!o) return false;
			const sid = String(id || o.id || '');
			if (o.type === 'city' || o.type === 'dungeon' || sid.startsWith('city_') || sid.startsWith('dun_') || sid.startsWith('sendero_')) return false;
			if (o.npc) return true;
			const npcId = o.npc || sid;
			if (store.npcs?.[npcId]) return true;
			return getPoiNpcSprite(id, obj) !== null;
		}

		// URL real de la miniatura del NPC de un POI (mismo criterio que
		// getEnemySpriteUrl): null si no hay ficha con sprite real (p. ej.
		// avatar emoji), para poder caer al icono 👤 genérico.
		function getPoiNpcSpriteUrl(id, obj) {
			const file = getPoiNpcSprite(id, obj);
			if (!file) return null;
			return `/api/assets/npc/${encodeURIComponent(file)}`;
		}

		function getTilePoiNpc(t) {
			if (!t || !t.object) return null;
			const id = t.object;
			const known = store.ids?.[id];
			if (!known) return null;
			const sprite = getPoiNpcSpriteUrl(id, known);
			if (!sprite) return null;
			return { sprite, name: known.name?.es || id };
		}

		// Lista de objetos pintables: recursos genéricos + ids del mundo unificados
		const objectPalette = computed(() => {
			const generic = placeableResources.value.map(r => ({ id: r.code, label: r.label, icon: r.icon, sub: 'recurso', badge: 'Recurso' }));
			const fromIds = Object.values(store.ids || {})
				.filter(o => ['city', 'dungeon', 'poi', 'house', 'sendero', 'npc'].includes(o.type))
				.map(o => {
					let cat = o.type;
					let icon = o.icon || '📍';
					let badge = o.type;
					let img = null;
					if (o.type === 'city' || o.id.startsWith('city_')) {
						cat = 'city';
						icon = '🏰';
						badge = 'Ciudad';
					} else if (o.type === 'dungeon' || o.id.startsWith('dun_') || o.id.startsWith('sendero_')) {
						cat = 'dungeon';
						icon = '🕳️';
						badge = 'Mazmorra';
					} else {
						const withNpc = isPoiWithNpc(o.id, o);
						cat = withNpc ? 'poi_npc' : 'poi_lore';
						icon = o.icon || (withNpc ? '👤' : '📜');
						badge = withNpc ? 'Con NPC' : 'Sin NPC';
						if (withNpc) img = getPoiNpcSpriteUrl(o.id, o);
					}
					return { id: o.id, label: o.name?.es || o.id, icon, sub: cat, badge, img };
				});
			return [...generic, ...fromIds];
		});

		// Mapa de coords con referencia rota (para resaltar en rojo).
		const badRefs = computed(() => {
			const set = new Set();
			const ids = store.ids || {};
			const gp = placeableResources.value.map(r => r.code);
			const tiles = world.value?.tiles || [];
			tiles.forEach((row, y) => (row || []).forEach((t, x) => {
				if (t?.object && !ids[t.object] && !gp.some(p => t.object.startsWith(p)))
					set.add(x + ',' + y);
			}));
			return set;
		});

		function tileAt(x, y) {
			return world.value?.tiles?.[y]?.[x] || null;
		}

		function cellStyle(x, y) {
			const t = tileAt(x, y);
			const terr = t ? TERRAIN_MAP.value[t.terrain] : null;
			return { background: terr ? terr.color : '#000' };
		}
		// Estilo de una celda VIRTUALIZADA: además del color de fondo, fija su
		// posición explícita en la rejilla (grid-column/grid-row 1-indexados).
		function cellGridStyle(x, y) {
			const s = cellStyle(x, y);
			s.gridColumn = x + 1;
			s.gridRow = y + 1;
			const px = BASE_CELL_PX * zoom.value;
			s.width = px + 'px';
			s.height = px + 'px';
			s.fontSize = Math.max(6, 15 * zoom.value) + 'px';
			return s;
		}

		// Iconos canónicos unificados:
		// - Ciudades -> 🏰
		// - Mazmorras -> 🕳️
		// - POI con NPC -> 👤
		// - POI sin NPC -> 📜
		// - Enemigos -> 👾
		// - Obstáculos -> 🧱
		// - Interactivos / Carteles -> 🪧
		// - Recursos -> icono de recurso natural (🌲, 🪨, etc.)
		function objIcon(t) {
			if (!t) return '';
			if (t.enemy) return '👾';
			if (t.chest || t.object === 'chest') return '🧰';
			if (t.obstacle || t.object === 'bloqueo_piedra') return '🪨';
			if (t.interactive) {
				if (t.interactive.kind === 'cinematic') return '🎬';
				return (t.interactive.kind === 'sign' ? '🪧' : (t.interactive.icon || '🗿'));
			}
			if (!t.object) return '';
			const id = t.object;
			const known = store.ids?.[id];
			if (known) {
				if (known.type === 'city' || id.startsWith('city_')) return '🏰';
				if (known.type === 'dungeon' || id.startsWith('dun_')) return '🕳️';
				if (known.icon && known.icon !== '📍') return known.icon;
				return isPoiWithNpc(id, known) ? '👤' : '📜';
			}
			const found = placeableResources.value.find(r => id.startsWith(r.code));
			return found ? found.icon : '❓';
		}

		// ¿Es un recurso farmeable genérico (colocable infinitas veces)?
		function isGenericObject(val) {
			return placeableResources.value.some(r => r.code === val);
		}

		// Retira una entidad única de CUALQUIER otra casilla (salvo la indicada),
		// para garantizar una sola instancia en todo el mapa.
		function removeObjectElsewhere(val, keepX, keepY) {
			const tiles = world.value?.tiles || [];
			tiles.forEach((row, rowY) => (row || []).forEach((cell, cellX) => {
				if (cell && cell.object === val && (cellX !== keepX || rowY !== keepY)) {
					delete cell.object;
				}
			}));
		}

		// Asigna un objeto a una casilla aplicando la regla de instancia única
		// para entidades de ids.json (los recursos genéricos se repiten libremente).
		function assignObject(t, x, y, val) {
			if (t.object === val) return;
			if (!isGenericObject(val)) removeObjectElsewhere(val, x, y);
			t.object = val;
			markWorldDirty();
		}

		// Herramientas de responsabilidad única. Cada una hace UNA
		// cosa y tiene su propia selección; nada de un "modo objeto" que mezcla todo.
		const TOOLS = [
			{ id: 'select',   label: 'Selec.',    icon: '🖱️', help: 'Solo inspecciona la casilla. NUNCA modifica el mapa.' },
			{ id: 'pan',      label: 'Vista',     icon: '🖐️', help: 'Haz clic y arrastra con el ratón para moverte por el mapa (también con Espacio o botón central).' },
			{ id: 'move',     label: 'Mover',     icon: '📦', help: 'Recoge el objeto de una casilla y colócalo en otra (no toca el terreno).' },
			{ id: 'terrain',  label: 'Terreno',   icon: '🖌️', help: 'Pinta el tipo de terreno de las casillas.' },
			{ id: 'resource', label: 'Recursos',  icon: '🌲', help: 'Coloca recursos farmeables (se repiten libremente).' },
			{ id: 'entity',   label: 'Entidad',   icon: '🏰', help: 'Coloca entidades únicas de ids.json (una sola por mapa).' },
			{ id: 'enemy',    label: 'Enemigos',  icon: '👾', help: 'Coloca enemigos del mapamundi en las casillas.' },
			{ id: 'erase',    label: 'Borrar',    icon: '🧽', help: 'Elimina el objeto o enemigo de la casilla (no toca el terreno).' },
			{ id: 'spawn',    label: 'Inicio',    icon: '🚩', help: 'Marca la casilla de aparición del protagonista.' },
			{ id: 'measure',  label: 'Medir',     icon: '📏', help: 'Arrastra entre dos casillas para medir distancia Manhattan y Euclidiana.' },
			{ id: 'region',   label: 'Región',    icon: '⬚', help: 'Arrastra para seleccionar un área; Ctrl+C la copia, Ctrl+V la pega en otro sitio (ej. clonar un lago o bosque).' },
		];
		function setTool(id) {
			store.brush.tool = id;
			if (id !== 'move') moveSrc.value = null;
			if (id !== 'region') clearRegion();
		}

		// ── Herramienta MOVER OBJETO ────────────────────────────────
		// Reubica el objeto de una casilla a otra en dos clics: 1º recoge (origen),
		// 2º suelta (destino). No modifica el terreno. Respeta la instancia única
		// (assignObject retira la entidad de cualquier otra casilla).
		const moveSrc = ref(null);   // { x, y, object, enemy, interactive, obstacle, chest } | null
		function isMoveSrc(x, y) { const m = moveSrc.value; return !!m && m.x === x && m.y === y; }
		function handleMove(x, y) {
			const t = tileAt(x, y); if (!t) return;
			if (!moveSrc.value) {
				const hasItem = t.object || t.enemy || t.interactive || t.obstacle || t.chest;
				if (!hasItem) { flash('Esta casilla no tiene elemento para mover.'); return; }
				moveSrc.value = {
					x, y,
					object: t.object || null,
					enemy: t.enemy ? deepClone(t.enemy) : null,
					interactive: t.interactive ? deepClone(t.interactive) : null,
					obstacle: t.obstacle ? deepClone(t.obstacle) : null,
					chest: t.chest ? deepClone(t.chest) : null,
				};
				const itemName = t.object || (t.enemy ? 'Enemigo' : (t.interactive ? 'Interactivo' : (t.obstacle ? 'Obstáculo' : (t.chest ? 'Cofre' : 'Elemento'))));
				flash('📦 Elemento "' + itemName + '" recogido. Haz clic en la casilla destino (o Esc para cancelar).');
			} else {
				if (moveSrc.value.x === x && moveSrc.value.y === y) { moveSrc.value = null; flash('Movimiento cancelado.'); return; }
				pushHistory();
				const srcTile = tileAt(moveSrc.value.x, moveSrc.value.y);
				if (srcTile) {
					if (moveSrc.value.object && srcTile.object === moveSrc.value.object) delete srcTile.object;
					if (moveSrc.value.enemy) delete srcTile.enemy;
					if (moveSrc.value.interactive) delete srcTile.interactive;
					if (moveSrc.value.obstacle) delete srcTile.obstacle;
					if (moveSrc.value.chest) delete srcTile.chest;
				}
				if (moveSrc.value.object) {
					assignObject(t, x, y, moveSrc.value.object);
				}
				if (moveSrc.value.enemy) {
					t.enemy = deepClone(moveSrc.value.enemy);
				}
				if (moveSrc.value.interactive) {
					t.interactive = deepClone(moveSrc.value.interactive);
				}
				if (moveSrc.value.obstacle) {
					t.obstacle = deepClone(moveSrc.value.obstacle);
				}
				if (moveSrc.value.chest) {
					t.chest = deepClone(moveSrc.value.chest);
				}
				markWorldDirty();
				store.selectedCell = { x, y };
				flash('Elemento movido a (' + x + ', ' + y + ').');
				moveSrc.value = null;
			}
		}

		// Selector de CATEGORÍA para la herramienta Entidades.
		const ENTITY_CATS = [
			{ value: 'all',      label: 'Todas' },
			{ value: 'city',     label: '🏰 Ciudades' },
			{ value: 'dungeon',  label: '🕳️ Mazmorras' },
			{ value: 'poi_npc',  label: '👤 Con NPC' },
			{ value: 'poi_lore', label: '📜 Sin NPC' },
		];

		function terrainTextureUrl(code) {
			if (!code) return '/api/assets/terrain/tile_ground.png';
			const map = {
				are: '/api/assets/terrain/tile_beach.png',
				bad: '/api/assets/terrain/tile_yelmo.png',
				cst: '/api/assets/terrain/tile_sea.png',
				des: '/api/assets/terrain/tile_sand.png',
				gnd: '/api/assets/terrain/tile_ground.png',
				grs: '/api/assets/terrain/tile_pradera.png',
				ice: '/api/assets/terrain/tile_snow.png',
				icy: '/api/assets/terrain/tile_ice.png',
				lav: '/api/assets/terrain/tile_lava.png',
				mnt: '/api/assets/terrain/tile_mountain.png',
				pth: '/api/assets/terrain/tile_templo.png',
				sea: '/api/assets/terrain/tile_sea.png',
				void: '/api/assets/terrain/tile_grieta.png',
				pol: '/api/assets/terrain/tile_contaminacion.png',
			};
			return map[code] || '/api/assets/terrain/tile_ground.png';
		}

		// Ítems de cada paleta en el formato del Design System (DsPalette) con texturas reales y badges.
		const terrainItems = computed(() => TERRAINS.value.map(t => {
			const badges = [];
			if (t.hazard === 'heat' || t.code === 'des') badges.push({ text: '☀️ Calor', color: '#f59e0b' });
			if (t.hazard === 'cold' || t.code === 'ice' || t.code === 'icy') badges.push({ text: '❄️ Frío', color: '#06b6d4' });
			if (t.slippery || t.code === 'icy') badges.push({ text: '⛸️ Resbala', color: '#38bdf8' });
			if (t.damage || t.code === 'lav') badges.push({ text: '🌋 Lava', color: '#ef4444' });
			if (t.walkable === false) badges.push({ text: '🚫 Bloqueado', color: '#f87171' });
			if (t.code === 'sea' || t.code === 'cst') badges.push({ text: '⛵ Barco', color: '#60a5fa' });
			return {
				value: t.code,
				label: t.label,
				color: t.color,
				sub: t.code,
				img: terrainTextureUrl(t.code),
				badges,
			};
		}));
		const resourceItems = computed(() => objectPalette.value
			.filter(p => p.sub === 'recurso')
			.map(o => ({ value: o.id, label: o.label, icon: o.icon, sub: o.id })));
		const entityItems = computed(() => {
			const cat = store.brush.entityCat;
			return objectPalette.value
				.filter(p => p.sub !== 'recurso')
				.filter(p => {
					if (cat === 'all') return true;
					if (cat === 'poi') return p.sub === 'poi_npc' || p.sub === 'poi_lore';
					return p.sub === cat;
				})
				.map(o => ({ value: o.id, label: o.label, icon: o.icon, img: o.img, sub: o.badge || o.sub }));
		});

		function applyBrush(x, y) {
			const t = tileAt(x, y);
			if (!t) return;
			const tool = store.brush.tool;
			if (tool === 'terrain') {
				applyTerrainBrushArea(x, y);
			} else if (tool === 'erase') {
				var erased = false;
				if ('object' in t) { delete t.object; erased = true; }
				if ('enemy' in t) { delete t.enemy; erased = true; }
				if ('interactive' in t) { delete t.interactive; erased = true; }
				if ('obstacle' in t) { delete t.obstacle; erased = true; }
				if ('chest' in t) { delete t.chest; erased = true; }
				if (erased) { ensureStrokeSnapshot(); markWorldDirty(); }
			} else if (tool === 'enemy') {
				const enemyId = store.brush.enemy || (ENEMY_IDS.value[0] || 'slime_01');
				if (!t.enemy || t.enemy.enemy !== enemyId) {
					ensureStrokeSnapshot();
					t.enemy = {
						enemy: enemyId,
						enemy_id: enemyId,
						level: 1,
						color: '#ff4d4d',
						radius: 1,
						speed: 1.0,
						respawn: true,
						respawn_time: 120,
						aggressive: true,
						sprite: '👾',
						move_interval: 2.5
					};
					markWorldDirty();
				}
			} else if (tool === 'resource' || tool === 'entity') {
				const val = tool === 'resource' ? store.brush.resource : store.brush.entity;
				if (val === 'chest') {
					ensureStrokeSnapshot();
					t.object = 'chest';
					if (!t.chest) t.chest = { gold: 50, items: [] };
					delete t.obstacle;
					delete t.interactive;
					delete t.enemy;
					markWorldDirty();
				} else if (val === 'bloqueo_piedra') {
					ensureStrokeSnapshot();
					t.object = 'bloqueo_piedra';
					t.icon = '🪨';
					t.name = { es: 'Bloqueo de piedra', en: 'Rock blockage' };
					t.description = {
						es: 'Un desprendimiento bloquea el paso. Solo una explosión de bomba podría destruirlo.',
						en: 'A rockfall blocks the way. Only a bomb explosion could clear it.'
					};
					t.obstacle = {
						tool: '',
						bombable: true,
						reward: { item: 'stone', qty: 3 },
						after: { icon: '', name: { es: '', en: '' } },
						sfx: 'hit',
						orientation: 'horizontal'
					};
					delete t.chest;
					delete t.interactive;
					delete t.enemy;
					markWorldDirty();
				} else if (val && t.object !== val) {
					ensureStrokeSnapshot();
					assignObject(t, x, y, val);
					delete t.chest;
					delete t.obstacle;
				}
			} else if (tool === 'spawn') {
				setSpawn(x, y);
			}
		}

		function applyMapFloodFill(startX, startY) {
			const tiles = world.value?.tiles;
			if (!tiles) return;
			const h = tiles.length;
			const w = tiles[0]?.length || 0;
			if (startX < 0 || startX >= w || startY < 0 || startY >= h) return;

			const tool = store.brush.tool;
			const startTile = tiles[startY][startX];
			if (!startTile) return;

			let modified = false;
			const queue = [[startX, startY]];
			const visited = new Set();
			visited.add(`${startX},${startY}`);

			if (tool === 'terrain') {
				const startTerrain = startTile.terrain;
				const targetTerrain = store.brush.terrain;
				if (startTerrain === targetTerrain) return;
				pushHistory();

				while (queue.length > 0) {
					const [cx, cy] = queue.shift();
					const t = tiles[cy]?.[cx];
					if (t && t.terrain === startTerrain) {
						t.terrain = targetTerrain;
						modified = true;
						for (const [nx, ny] of [[cx+1, cy], [cx-1, cy], [cx, cy+1], [cx, cy-1]]) {
							if (nx >= 0 && nx < w && ny >= 0 && ny < h) {
								const key = `${nx},${ny}`;
								if (!visited.has(key)) { visited.add(key); queue.push([nx, ny]); }
							}
						}
					}
				}
			} else if (tool === 'erase') {
				const startObj = startTile.object;
				if (!startObj) return;
				pushHistory();

				while (queue.length > 0) {
					const [cx, cy] = queue.shift();
					const t = tiles[cy]?.[cx];
					if (t && t.object === startObj) {
						delete t.object;
						modified = true;
						for (const [nx, ny] of [[cx+1, cy], [cx-1, cy], [cx, cy+1], [cx, cy-1]]) {
							if (nx >= 0 && nx < w && ny >= 0 && ny < h) {
								const key = `${nx},${ny}`;
								if (!visited.has(key)) { visited.add(key); queue.push([nx, ny]); }
							}
						}
					}
				}
			} else if (tool === 'resource' || tool === 'entity') {
				const targetObj = tool === 'resource' ? store.brush.resource : store.brush.entity;
				if (!targetObj) return;
				const startObj = startTile.object || null;
				if (startObj === targetObj) return;
				pushHistory();

				while (queue.length > 0) {
					const [cx, cy] = queue.shift();
					const t = tiles[cy]?.[cx];
					const currentObj = (t && t.object) || null;
					if (t && currentObj === startObj) {
						assignObject(t, cx, cy, targetObj);
						modified = true;
						for (const [nx, ny] of [[cx+1, cy], [cx-1, cy], [cx, cy+1], [cx, cy-1]]) {
							if (nx >= 0 && nx < w && ny >= 0 && ny < h) {
								const key = `${nx},${ny}`;
								if (!visited.has(key)) { visited.add(key); queue.push([nx, ny]); }
							}
						}
					}
				}
			}

			if (modified) {
				markWorldDirty();
				scheduleMinimapDraw();
			}
		}

		function applyRectangle() {
			if (!rectStart.value || !rectEnd.value) return;
			const x0 = Math.min(rectStart.value.x, rectEnd.value.x);
			const x1 = Math.max(rectStart.value.x, rectEnd.value.x);
			const y0 = Math.min(rectStart.value.y, rectEnd.value.y);
			const y1 = Math.max(rectStart.value.y, rectEnd.value.y);

			let modified = false;
			pushHistory();

			for (let y = y0; y <= y1; y++) {
				for (let x = x0; x <= x1; x++) {
					const t = tileAt(x, y);
					if (!t) continue;
					const tool = store.brush.tool;
					if (tool === 'terrain') {
						if (t.terrain !== store.brush.terrain) {
							t.terrain = store.brush.terrain;
							modified = true;
						}
					} else if (tool === 'erase') {
						if ('object' in t) {
							delete t.object;
							modified = true;
						}
					} else if (tool === 'resource' || tool === 'entity') {
						const val = tool === 'resource' ? store.brush.resource : store.brush.entity;
						if (val && t.object !== val) {
							assignObject(t, x, y, val);
							modified = true;
						}
					} else if (tool === 'spawn') {
						setSpawn(x1, y1);
						modified = true;
					}
				}
			}
			if (modified) {
				markWorldDirty();
				scheduleMinimapDraw();
			}
		}

		function fillEntireMapTerrain() {
			const terrain = store.brush.terrain;
			if (!world.value?.tiles || !confirm('¿Estás seguro de que quieres cambiar TODO el terreno del mapa a "' + terrain + '"?')) return;
			pushHistory();
			let modified = false;
			world.value.tiles.forEach(row => {
				(row || []).forEach(t => {
					if (t && t.terrain !== terrain) {
						t.terrain = terrain;
						modified = true;
					}
				});
			});
			if (modified) {
				markWorldDirty();
				scheduleMinimapDraw();
				flash('Todo el mapa rellenado con "' + terrain + '".');
			}
		}

		// ── PINCEL DE TERRENO: tamaño (1x1/3x3/5x5) y suavizado de bordes ──────
		// Pincel 1x1 = una sola casilla (comportamiento previo, sin cambios). Con
		// tamaño 3/5 se pinta un área centrada en el clic; con "smooth" activado
		// la brocha es circular (bordes redondeados) en vez de cuadrada, evitando
		// "manchas" con esquinas duras al pintar biomas orgánicos (bosques, lagos…).
		const BRUSH_SIZES = [1, 3, 5];
		function setBrushSize(n) { store.brush.size = n; }
		function toggleBrushSmooth() { store.brush.smooth = !store.brush.smooth; }
		function terrainBrushCells(cx, cy) {
			const size = store.brush.size || 1;
			const r = (size - 1) / 2;
			const smooth = !!store.brush.smooth;
			const w = width.value, h = height.value;
			const out = [];
			for (let dy = -r; dy <= r; dy++) {
				for (let dx = -r; dx <= r; dx++) {
					if (smooth && Math.sqrt(dx * dx + dy * dy) > r + 0.5) continue;
					const nx = cx + dx, ny = cy + dy;
					if (nx >= 0 && nx < w && ny >= 0 && ny < h) out.push([nx, ny]);
				}
			}
			return out;
		}
		function applyTerrainBrushArea(cx, cy) {
			const tiles = world.value?.tiles;
			if (!tiles) return;
			let modified = false;
			for (const [nx, ny] of terrainBrushCells(cx, cy)) {
				const t = tiles[ny]?.[nx];
				if (t && t.terrain !== store.brush.terrain) {
					ensureStrokeSnapshot();
					t.terrain = store.brush.terrain;
					modified = true;
				}
			}
			if (modified) { markWorldDirty(); scheduleMinimapDraw(); }
		}

		// ── CUENTAGOTAS (Eyedropper): Alt + Click copia el terreno, recurso,
		// entidad o enemigo bajo el cursor a la selección actual del pincel, para
		// no tener que buscarlo a mano en la paleta. Funciona con cualquier
		// herramienta activa y cambia de herramienta automáticamente según lo que
		// haya bajo el cursor (terreno / recurso / entidad / enemigo).
		function useEyedropper(x, y) {
			const t = tileAt(x, y);
			if (!t) return;
			if (t.enemy) {
				store.brush.tool = 'enemy';
				store.brush.enemy = t.enemy.enemy || t.enemy.enemy_id || store.brush.enemy;
				flash('🎨 Cuentagotas: enemigo "' + store.brush.enemy + '" copiado al pincel.');
				return;
			}
			if (t.object) {
				if (isGenericObject(t.object)) {
					store.brush.tool = 'resource';
					store.brush.resource = t.object;
					flash('🎨 Cuentagotas: recurso "' + t.object + '" copiado al pincel.');
				} else {
					const known = store.ids?.[t.object];
					store.brush.tool = 'entity';
					store.brush.entityCat = known ? known.type : 'all';
					store.brush.entity = t.object;
					flash('🎨 Cuentagotas: entidad "' + t.object + '" copiada al pincel.');
				}
				return;
			}
			store.brush.tool = 'terrain';
			store.brush.terrain = t.terrain;
			flash('🎨 Cuentagotas: terreno "' + t.terrain + '" copiado al pincel.');
		}

		// ── CAPAS VISUALES: Físicas/Transitabilidad y Clima/Ambiente (Pilar 1.2) ──
		// Overlay semitransparente pintado SOBRE el color de bioma de cada celda
		// visible (nunca lo sustituye), para poder alternar de un vistazo entre
		// "cómo se ve" (bioma) y "cómo se juega" (transitabilidad) o "qué ambiente
		// suena" (clima), sin abrir el inspector casilla a casilla.
		const MAP_LAYERS = [
			{ id: 'biome', label: '🎨 Biomas', help: 'Vista normal: color y textura de cada terreno.' },
			{ id: 'physics', label: '🚧 Físicas', help: 'Overlay de transitabilidad: verde=caminable, azul=requiere barco, rojo=bloqueado, cian=resbaladizo, naranja=daño.' },
			{ id: 'weather', label: '🌦️ Clima', help: 'Overlay del clima/ambiente asignado a cada terreno (ambience.json).' },
		];
		function setMapLayer(id) { store.mapLayer = id; }
		function physicsOverlayColor(code) {
			const def = TERRAIN_MAP.value[code] || {};
			if (code === 'sea' || code === 'cst') return 'rgba(59,130,246,0.55)';
			if (def.walkable === false || code === 'mnt') return 'rgba(239,68,68,0.55)';
			if (def.slippery || code === 'icy') return 'rgba(56,189,248,0.55)';
			if (def.damage || code === 'lav') return 'rgba(249,115,22,0.55)';
			return 'rgba(16,185,129,0.35)';
		}
		const WEATHER_OVERLAY_COLORS = {
			sand: 'rgba(245,158,11,0.5)', snow: 'rgba(6,182,212,0.5)', ash: 'rgba(107,114,128,0.5)',
			rain: 'rgba(59,130,246,0.5)', clear: 'rgba(148,163,184,0.22)',
		};
		function weatherOverlayColor(code) {
			const w = store.ambience?.terrain?.[code]?.weather
				|| (code === 'des' ? 'sand' : (code === 'ice' || code === 'icy' ? 'snow' : (code === 'lav' ? 'ash' : 'clear')));
			return WEATHER_OVERLAY_COLORS[w] || WEATHER_OVERLAY_COLORS.clear;
		}
		function layerOverlayColor(x, y) {
			if (store.mapLayer === 'biome') return null;
			const t = tileAt(x, y);
			if (!t) return null;
			return store.mapLayer === 'physics' ? physicsOverlayColor(t.terrain) : weatherOverlayColor(t.terrain);
		}

		// ── INICIO DEL PROTAGONISTA (data-driven `spawn` del mapa activo) ─────
		// El mapa real (world.json) guarda el inicio de la partida normal; el mapa
		// debug (world_test.json) guarda el inicio de la Sala de Tests / modo debug.
		const spawnPos = computed(() => {
			const s = store.world?.spawn;
			return (s && Number.isInteger(s.x) && Number.isInteger(s.y)) ? s : null;
		});
		function isSpawn(x, y) {
			const s = spawnPos.value;
			return !!s && s.x === x && s.y === y;
		}
		function setSpawn(x, y) {
			if (!store.world) return;
			const s = store.world.spawn;
			if (s && s.x === x && s.y === y) return;
			pushHistory();
			store.world.spawn = { x, y };
			markWorldDirty();
		}
		function gotoSpawn() {
			const s = spawnPos.value;
			if (s) store.selectedCell = { x: s.x, y: s.y };
		}
		// Centrar la vista en el inicio del personaje: al entrar en
		// la pestaña Mapamundi, el foco arranca ahí en vez de en la esquina (0,0) —
		// antes había que localizar el inicio a ojo o con "Ir al inicio" + desplazar
		// a mano. Cada celda mide `BASE_CELL_PX * zoom` píxeles REALES (ver
		// `cellGridStyle`/plantilla: ya no se usa `transform: scale()` sobre
		// `.grid`), así que el centro de una celda en scrollLeft/Top es
		// directamente (x+0.5, y+0.5) * (BASE_CELL_PX * zoom).
		const BASE_CELL_PX = 30;

		// ── VIRTUALIZACIÓN de la rejilla (rendimiento en mundos grandes) ──────
		// Antes se montaba un <div> DOM por CADA casilla del mapa (281×178 =
		// 50.018 nodos reactivos vivos a la vez con el mundo actual — y crecerá
		// con la Task 2). Ahora solo se montan las casillas VISIBLES + un
		// colchón (`VIRTUAL_BUFFER`); cada una se coloca explícitamente en su
		// `grid-column`/`grid-row` (en vez de depender del orden de montaje), así
		// que `.grid` sigue teniendo el tamaño total real (todas las pistas de
		// `grid-template-columns`/`grid-auto-rows` existen aunque no todas tengan
		// una celda montada) y el scroll/zoom/`centerViewOnSpawn` no cambian.
		const CELL_GAP = 2;   // debe coincidir con `.grid { gap: 2px }` en styles.css
		const CELL_PITCH = BASE_CELL_PX + CELL_GAP;
		const VIRTUAL_BUFFER = 4;   // casillas extra fuera de la vista, para que el scroll no "parpadee"
		const viewport = reactive({ w: 0, h: 0 });
		const scrollPos = reactive({ left: 0, top: 0 });
		let resizeObserver = null;
		function onScroll() {
			const el = wrapRef.value;
			if (!el) return;
			scrollPos.left = el.scrollLeft;
			scrollPos.top = el.scrollTop;
		}
		function syncViewport() {
			const el = wrapRef.value;
			if (!el) return;
			viewport.w = el.clientWidth;
			viewport.h = el.clientHeight;
		}
		const visibleRange = computed(() => {
			const w = width.value, h = height.value;
			if (!w || !h) return { x0: 0, x1: -1, y0: 0, y1: -1 };
			const pitch = CELL_PITCH * zoom.value;
			const x0 = Math.max(0, Math.floor(scrollPos.left / pitch) - VIRTUAL_BUFFER);
			const y0 = Math.max(0, Math.floor(scrollPos.top / pitch) - VIRTUAL_BUFFER);
			const x1 = Math.min(w - 1, Math.ceil((scrollPos.left + viewport.w) / pitch) + VIRTUAL_BUFFER);
			const y1 = Math.min(h - 1, Math.ceil((scrollPos.top + viewport.h) / pitch) + VIRTUAL_BUFFER);
			return { x0, x1, y0, y1 };
		});
		const visibleCells = computed(() => {
			const { x0, x1, y0, y1 } = visibleRange.value;
			const out = [];
			for (let y = y0; y <= y1; y++) {
				for (let x = x0; x <= x1; x++) out.push({ x, y });
			}
			return out;
		});

		// ── MINIMAPA interactivo (Pilar 1.1) ──────────────────────────────────
		// Vista miniatura de TODO el mapa en un <canvas> aparte (NO virtualizado:
		// se redibuja una sola vez tras cada operación que cambia terreno, nunca
		// en cada frame de scroll/zoom). El rectángulo de viewport se superpone
		// como <div> posicionado con CSS (cálculo barato, sin redibujar canvas) y
		// permite teletransportarse por el mapa haciendo clic o arrastrando.
		const minimapRef = ref(null);
		const MINIMAP_W = 176, MINIMAP_H = 120;
		// Minimizable: el usuario puede plegarlo a una píldora pequeña y
		// volver a desplegarlo sin perder su posición fija en la esquina.
		const minimapCollapsed = ref(false);
		function toggleMinimap() {
			minimapCollapsed.value = !minimapCollapsed.value;
			if (!minimapCollapsed.value) nextTick(() => drawMinimap());
		}
		let minimapRaf = null;
		function scheduleMinimapDraw() {
			if (minimapRaf) return;
			minimapRaf = requestAnimationFrame(() => { minimapRaf = null; drawMinimap(); });
		}
		function drawMinimap() {
			const cv = minimapRef.value;
			const w = width.value, h = height.value;
			if (!cv || !w || !h) return;
			const scale = Math.min(MINIMAP_W / w, MINIMAP_H / h);
			cv.width = Math.max(1, Math.round(w * scale));
			cv.height = Math.max(1, Math.round(h * scale));
			const ctx = cv.getContext('2d');
			const tiles = world.value?.tiles || [];
			for (let y = 0; y < h; y++) {
				const row = tiles[y] || [];
				for (let x = 0; x < w; x++) {
					const t = row[x];
					const terr = t ? TERRAIN_MAP.value[t.terrain] : null;
					ctx.fillStyle = terr ? terr.color : '#0b1220';
					ctx.fillRect(Math.floor(x * scale), Math.floor(y * scale), Math.ceil(scale), Math.ceil(scale));
				}
			}
		}
		const minimapViewport = computed(() => {
			const cv = minimapRef.value;
			const w = width.value, h = height.value;
			if (!cv || !w || !h) return null;
			const scale = Math.min(MINIMAP_W / w, MINIMAP_H / h);
			const cell = BASE_CELL_PX * zoom.value;
			return {
				left: (scrollPos.left / cell) * scale,
				top: (scrollPos.top / cell) * scale,
				width: Math.min(cv.width, (viewport.w / cell) * scale),
				height: Math.min(cv.height, (viewport.h / cell) * scale),
			};
		});
		function minimapGoTo(ev) {
			const cv = minimapRef.value, el = wrapRef.value;
			const w = width.value, h = height.value;
			if (!cv || !el || !w || !h) return;
			const rect = cv.getBoundingClientRect();
			const scale = Math.min(MINIMAP_W / w, MINIMAP_H / h);
			const px = (ev.clientX - rect.left) / scale;
			const py = (ev.clientY - rect.top) / scale;
			const cell = BASE_CELL_PX * zoom.value;
			el.scrollLeft = Math.max(0, px * cell - el.clientWidth / 2);
			el.scrollTop = Math.max(0, py * cell - el.clientHeight / 2);
		}
		// Arrastre robusto con listeners en `window` (igual que el redimensionado
		// de la paleta): así el arrastre no se queda "pegado" si el botón se
		// suelta fuera del propio minimapa.
		const minimapDragging = ref(false);
		function onMinimapDown(ev) {
			minimapDragging.value = true;
			minimapGoTo(ev);
			window.addEventListener('mousemove', onMinimapMove);
			window.addEventListener('mouseup', onMinimapUp);
		}
		function onMinimapMove(ev) { if (minimapDragging.value) minimapGoTo(ev); }
		function onMinimapUp() {
			minimapDragging.value = false;
			window.removeEventListener('mousemove', onMinimapMove);
			window.removeEventListener('mouseup', onMinimapUp);
		}

		function centerMap() {
			const el = wrapRef.value;
			if (!el) return;
			const w = width.value || 50;
			const h = height.value || 50;
			const targetX = spawnPos.value ? spawnPos.value.x : Math.floor(w / 2);
			const targetY = spawnPos.value ? spawnPos.value.y : Math.floor(h / 2);
			const cell = BASE_CELL_PX * zoom.value;
			const cx = (targetX + 0.5) * cell;
			const cy = (targetY + 0.5) * cell;
			el.scrollLeft = Math.max(0, cx - el.clientWidth / 2);
			el.scrollTop = Math.max(0, cy - el.clientHeight / 2);
		}
		function centerViewOnSpawn() { centerMap(); }

		const spacePressed = ref(false);

		function zoomIn() { zoom.value = Math.min(3, +(zoom.value + 0.15).toFixed(2)); }
		function zoomOut() { zoom.value = Math.max(0.35, +(zoom.value - 0.15).toFixed(2)); }
		function resetZoom() { zoom.value = 1; }

		function scrollMap(dx, dy) {
			const el = wrapRef.value;
			if (!el) return;
			el.scrollBy({ left: dx, top: dy, behavior: 'smooth' });
		}

		function onCellDown(x, y, ev) {
			store.selectedCell = { x, y };
			if (ev && ev.altKey) { useEyedropper(x, y); return; }
			const tool = store.brush.tool;
			// Si la herramienta es 'pan' o se mantiene pulsado Espacio, o se clica con botón central/derecho
			if (tool === 'pan' || spacePressed.value || (ev && (ev.button === 1 || ev.button === 2))) {
				if (ev) {
					panning.value = true;
					const el = wrapRef.value;
					panStart.value = { x: ev.clientX, y: ev.clientY, sl: el.scrollLeft, st: el.scrollTop };
				}
				return;
			}
			// Seleccionar solo inspecciona: abre el inspector lateral de casilla.
			if (tool === 'select') {
				clearRegion();
				showInspector.value = true;
				return;
			}
			if (tool === 'move') { handleMove(x, y); return; }
			if (tool === 'measure') { measureDown(x, y); return; }
			if (tool === 'region') { regionDown(x, y); return; }

			painting.value = true;
			strokeSnapshotTaken = false;

			if (drawMode.value === 'rect') {
				rectStart.value = { x, y };
				rectEnd.value = { x, y };
			} else if (drawMode.value === 'fill') {
				applyMapFloodFill(x, y);
				painting.value = false;
			} else {
				applyBrush(x, y);
			}
		}

		function onCellDblClick(x, y) {
			const t = tileAt(x, y);
			if (t && t.object) {
				const known = store.ids?.[t.object];
				if (known) {
					if (known.type === 'city' || known.type === 'town') {
						store.selectedCity = t.object;
						store.activeTab = 'cities';
						return;
					} else if (known.type === 'dungeon') {
						store.selectedDungeon = t.object;
						store.activeTab = 'dungeon';
						return;
					}
				}
			}
		}

		function exportMapRender() {
			const w = width.value;
			const h = height.value;
			const tileSize = 48;
			const cv = document.createElement('canvas');
			cv.width = w * tileSize;
			cv.height = h * tileSize;
			const ctx = cv.getContext('2d');

			for (let y = 0; y < h; y++) {
				for (let x = 0; x < w; x++) {
					const t = tileAt(x, y);
					const terr = TERRAIN_MAP.value[t?.terrain || 'water'];
					ctx.fillStyle = terr?.color || '#1e3a8a';
					ctx.fillRect(x * tileSize, y * tileSize, tileSize, tileSize);
					if (t?.object) {
						ctx.fillStyle = '#ef4444';
						ctx.beginPath();
						ctx.arc(x * tileSize + tileSize / 2, y * tileSize + tileSize / 2, tileSize / 4, 0, Math.PI * 2);
						ctx.fill();
					}
				}
			}

			const a = document.createElement('a');
			a.download = `world_map_render_${w}x${h}.png`;
			a.href = cv.toDataURL('image/png');
			a.click();
			flash('Render de mapa descargado');
		}
		function onCellEnter(x, y, ev) {
			if (painting.value) {
				if (drawMode.value === 'rect') {
					rectEnd.value = { x, y };
				} else if (drawMode.value === 'pencil') {
					applyBrush(x, y);
				}
			}
			measureMove(x, y);
			regionMove(x, y);
			// Solo dispara re-render si la celda cambió de verdad (no en cada
			// pixel): sin esto, entrar/salir repetidamente de la misma celda por
			// jitter del ratón seguiría invalidando el hover innecesariamente.
			if (!hover.value || hover.value.x !== x || hover.value.y !== y) hover.value = { x, y };
			nextTick(() => positionTooltip(ev));
		}
		function onCellMove(ev) {
			if (panning.value) {
				const el = wrapRef.value;
				if (el) {
					el.scrollLeft = panStart.value.sl - (ev.clientX - panStart.value.x);
					el.scrollTop = panStart.value.st - (ev.clientY - panStart.value.y);
				}
			}
			if (hover.value) positionTooltip(ev);
		}
		function onCellLeave() { hover.value = null; }
		function stopPaint() {
			if (painting.value && drawMode.value === 'rect' && rectStart.value && rectEnd.value) {
				applyRectangle();
			}
			painting.value = false;
			rectStart.value = null;
			rectEnd.value = null;
			measureUp();
			regionUp();
		}

		// ── ZOOM con la rueda del ratón usando Ctrl/Cmd. Sin Ctrl/Cmd permite scroll natural. ──
		function onWheel(ev) {
			if (ev.ctrlKey || ev.metaKey) {
				ev.preventDefault();
				const dir = ev.deltaY < 0 ? 1 : -1;
				zoom.value = Math.min(3, Math.max(0.35, +(zoom.value + dir * 0.12).toFixed(2)));
			}
		}

		// ── PANEO con el botón central, derecho, herramienta mover mapa o Espacio ──
		function onWrapDown(ev) {
			if (ev.button === 1 || ev.button === 2 || store.brush.tool === 'pan' || spacePressed.value) {
				ev.preventDefault();
				panning.value = true;
				const el = wrapRef.value;
				panStart.value = { x: ev.clientX, y: ev.clientY, sl: el.scrollLeft, st: el.scrollTop };
			}
		}
		function onWrapMove(ev) {
			if (!panning.value) return;
			const el = wrapRef.value;
			el.scrollLeft = panStart.value.sl - (ev.clientX - panStart.value.x);
			el.scrollTop = panStart.value.st - (ev.clientY - panStart.value.y);
		}
		function onWrapUp() { panning.value = false; }

		// Info compacta de la casilla bajo el cursor (para el tooltip).
		function hoverInfo() {
			if (!hover.value) return null;
			const t = tileAt(hover.value.x, hover.value.y);
			if (!t) return null;
			const terr = TERRAIN_MAP.value[t.terrain];
			let objLabel = '';
			if (t.chest || t.object === 'chest') {
				const numItems = Array.isArray(t.chest?.items) ? t.chest.items.length : 0;
				objLabel = `Cofre con botín (${t.chest?.gold || 0} oro · ${numItems} ítems)`;
			} else if (t.obstacle || t.object === 'bloqueo_piedra') {
				objLabel = t.name?.es || 'Bloqueo de piedra (Bomba 💣)';
			} else if (t.object) {
				const known = store.ids?.[t.object];
				objLabel = known ? (known.name?.es || t.object) : t.object;
			} else if (t.interactive) {
				objLabel = t.interactive.title_es || t.interactive.title || t.interactive.kind || 'Objeto interactivo';
			} else if (t.enemy) {
				objLabel = t.enemy.enemy || t.enemy.enemy_id || 'Enemigo';
			}
			return {
				coord: `(${hover.value.x}, ${hover.value.y})`,
				terrain: terr ? `${terr.label} (${t.terrain})` : t.terrain,
				object: objLabel,
			};
		}

		// Inspector: celda seleccionada.
		const sel = computed(() => store.selectedCell);
		const selTile = computed(() => sel.value ? tileAt(sel.value.x, sel.value.y) : null);
		const selObjDef = computed(() => {
			const t = selTile.value;
			return t?.object ? (store.ids?.[t.object] || null) : null;
		});

		const selTileInfo = computed(() => {
			const t = selTile.value;
			if (!t) return null;
			const code = t.terrain || 'grs';
			const def = TERRAIN_MAP.value[code] || {};
			const ambienceData = store.ambience?.terrain?.[code] || {};

			// Transitabilidad
			let passability = { label: 'A pie (Accesible)', icon: '🚶', color: '#10b981', type: 'walkable' };
			if (code === 'sea' || code === 'cst') {
				passability = { label: 'Acuático (Requiere Barco)', icon: '⛵', color: '#3b82f6', type: 'boat' };
			} else if (def.walkable === false || code === 'mnt') {
				passability = { label: 'Infranqueable (Bloqueado)', icon: '🚫', color: '#ef4444', type: 'blocked' };
			}

			// Velocidad
			const speedMult = def.speed_mult !== undefined ? def.speed_mult : 1.0;
			let speedLabel = `${speedMult}x (Normal)`;
			if (speedMult < 0.8) speedLabel = `${speedMult}x (Lento)`;
			else if (speedMult > 1.1) speedLabel = `${speedMult}x (Rápido)`;

			// Peligros / Hazards
			const hazards = [];
			if (def.hazard === 'heat' || code === 'des') {
				hazards.push({ label: 'Insolación / Calor Extremo', icon: '☀️', color: '#f59e0b', desc: 'Provoca deshidratación e insolación.' });
			}
			if (def.hazard === 'cold' || code === 'ice' || code === 'icy') {
				hazards.push({ label: 'Frío / Congelación', icon: '❄️', color: '#06b6d4', desc: 'Reduce el vigor por frío extremo.' });
			}
			if (def.slippery || code === 'icy') {
				hazards.push({ label: 'Suelo Resbaladizo', icon: '⛸️', color: '#38bdf8', desc: 'Deslizamiento incontrolado hasta salir.' });
			}
			if (def.damage || code === 'lav') {
				const dmg = def.damage || 6;
				hazards.push({ label: `Quemadura por Lava (${dmg} DPS)`, icon: '🌋', color: '#ef4444', desc: `Quema al pisar (${dmg} daño).` });
			}
			if (code === 'void') {
				hazards.push({ label: 'Grieta Espaciotemporal', icon: '🌀', color: '#a855f7', desc: 'Distorsión del flujo temporal.' });
			}

			if (code === 'pol') {
				hazards.push({ label: 'Contaminación / Radiación (5 DPS + Veneno)', icon: '☣️', color: '#22c55e', desc: 'Envenena y drena vida al pisar y durante 5s tras salir.' });
			}

			// Clima
			let weather = ambienceData.weather || (code === 'des' ? 'sand' : (code === 'ice' || code === 'icy' ? 'snow' : (code === 'lav' ? 'ash' : 'Despejado')));

			return {
				code,
				label: def.label || code,
				desc: def.description || '',
				icon: def.icon || '🌍',
				color: def.color || '#333',
				textureImg: terrainTextureUrl(code),
				passability,
				speedMult,
				speedLabel,
				hazards,
				weather,
				objectIcon: objIcon(t),
				objectName: selObjDef.value ? (selObjDef.value.name?.es || t.object) : t.object,
				enemyName: t.enemy ? (t.enemy.enemy || t.enemy.enemy_id) : null,
			};
		});

		function setSelTerrain(code) { if (selTile.value && selTile.value.terrain !== code) { pushHistory(); selTile.value.terrain = code; markWorldDirty(); scheduleMinimapDraw(); } }
		function setSelObject(val) {
			const t = selTile.value; if (!t || !sel.value) return;
			if (!val) { if ('object' in t) { pushHistory(); delete t.object; markWorldDirty(); } }
			else if (t.object !== val) { pushHistory(); assignObject(t, sel.value.x, sel.value.y, val); }
		}

		// ══════════════════════════════════════════════════════════════════════
		// — INSPECTOR MODULAR: Elemento presente en la casilla & Accesos rápidos
		// ══════════════════════════════════════════════════════════════════════
		const selTileItem = computed(() => {
			const t = selTile.value;
			if (!t) return null;

			// 1. Cofre (prioritario para abrir panel de botín)
			if (t.chest || t.object === 'chest') {
				if (!t.chest) t.chest = { gold: 50, items: [] };
				const numItems = Array.isArray(t.chest.items) ? t.chest.items.length : 0;
				return {
					kind: 'chest',
					subType: 'chest',
					typeLabel: 'Cofre con Botín',
					typeBadgeClass: 'badge-chest',
					typeIcon: '🧰',
					id: 'chest',
					icon: '🧰',
					name: 'Cofre del Mapamundi',
					desc: `${t.chest.gold || 0} oro · ${numItems} ítem(s)`,
					def: t.chest,
				};
			}

			// 2. Obstáculo / Bloqueo de piedra
			if (t.obstacle || t.object === 'bloqueo_piedra') {
				if (!t.obstacle) {
					t.obstacle = { tool: '', bombable: true, reward: { item: 'stone', qty: 3 }, after: { icon: '', name: { es: '', en: '' } }, sfx: 'hit' };
				}
				const toolLabel = TOOL_IDS.find(tl => tl.value === (t.obstacle.tool || ''))?.label || 'Obstáculo';
				return {
					kind: 'obstacle',
					subType: 'obstacle',
					typeLabel: t.object === 'bloqueo_piedra' ? 'Bloqueo de Piedra' : 'Obstáculo Demolible',
					typeBadgeClass: 'badge-obstacle',
					typeIcon: '🪨',
					id: t.object || t.obstacle.tool || 'obstacle',
					icon: '🪨',
					name: t.object === 'bloqueo_piedra' ? 'Bloqueo de Piedra' : (t.obstacle.after?.name?.es || 'Obstáculo rompible'),
					desc: `Requiere ${toolLabel}${t.obstacle.bombable ? ' o Bomba 💣' : ''}`,
					def: t.obstacle,
				};
			}

			// 3. Objeto (Ciudad / POI / Mazmorra / Recurso)
			if (t.object) {
				const idDef = store.ids?.[t.object] || null;
				if (idDef) {
					const type = idDef.type || 'poi';
					let typeLabel = 'Lugar';
					let typeBadgeClass = 'badge-poi';
					let typeIcon = '📍';
					if (type === 'city') {
						typeLabel = 'Ciudad';
						typeBadgeClass = 'badge-city';
						typeIcon = '🏛️';
					} else if (type === 'poi') {
						typeLabel = 'Punto de Interés (POI)';
						typeBadgeClass = 'badge-poi';
						typeIcon = '📍';
					} else if (type === 'dungeon') {
						typeLabel = 'Mazmorra';
						typeBadgeClass = 'badge-dungeon';
						typeIcon = '🏰';
					}
					return {
						kind: 'entity',
						subType: type,
						typeLabel,
						typeBadgeClass,
						typeIcon,
						id: t.object,
						icon: idDef.icon || typeIcon,
						name: idDef.name?.es || t.object,
						desc: idDef.desc?.es || '',
						def: idDef,
					};
				}
				const rDef = store.worldResources?.[t.object] || null;
				return {
					kind: 'resource',
					subType: 'resource',
					typeLabel: 'Recurso de Farmeo',
					typeBadgeClass: 'badge-resource',
					typeIcon: '🌲',
					id: t.object,
					icon: rDef?.icon || '🌿',
					name: rDef?.label || t.object,
					desc: rDef?.description || 'Recurso recolectable del mapamundi.',
					def: rDef,
				};
			}

			// 4. Enemigo
			if (t.enemy) {
				const eId = t.enemy.enemy || t.enemy.enemy_id || 'Enemigo';
				const eDef = store.enemies?.[eId] || null;
				return {
					kind: 'enemy',
					subType: 'enemy',
					typeLabel: 'Enemigo del Mapamundi',
					typeBadgeClass: 'badge-enemy',
					typeIcon: '👾',
					id: eId,
					icon: '👾',
					name: eDef?.name?.es || eDef?.name || eId,
					desc: `Nivel ${t.enemy.level || 1} · Radio ${t.enemy.radius !== undefined ? t.enemy.radius : 1} · Vel ${t.enemy.speed !== undefined ? t.enemy.speed : 1.0}x`,
					def: t.enemy,
				};
			}

			// 5. Objeto Interactivo
			if (t.interactive) {
				const k = t.interactive.kind || 'sign';
				const kLabel = INTERACTIVE_KINDS.find(ik => ik.value === k)?.label || 'Interactivo';
				const isCine = k === 'cinematic';
				const cineTitle = isCine && t.interactive.cinematic_id ? (store.cinematics?.[t.interactive.cinematic_id]?.title?.[store.currentLang] || store.cinematics?.[t.interactive.cinematic_id]?.title?.es || t.interactive.cinematic_id) : null;
				return {
					kind: 'interactive',
					subType: 'interactive',
					typeLabel: isCine ? 'Trigger Cinemática' : 'Objeto Interactivo',
					typeBadgeClass: isCine ? 'badge-purple' : 'badge-interactive',
					typeIcon: isCine ? '🎬' : '🪧',
					id: k,
					icon: isCine ? '🎬' : (t.interactive.icon || '🪧'),
					name: cineTitle || t.interactive.title?.es || kLabel,
					desc: isCine ? `Reproduce "${t.interactive.cinematic_id || 'intro'}" (${t.interactive.trigger_on_step !== false ? 'al pisar' : 'al interactuar'}${t.interactive.once !== false ? ', una vez' : ''})` : (t.interactive.text?.es || '(Sin texto escrito)'),
					def: t.interactive,
				};
			}

			return null;
		});

		const activeQuickAdd = ref(null); // 'city' | 'poi' | 'dungeon' | 'resource' | null
		const citiesList = computed(() => Object.values(store.ids || {}).filter(o => o.type === 'city'));
		const poisList = computed(() => Object.values(store.ids || {}).filter(o => o.type === 'poi'));
		const dungeonsList = computed(() => Object.values(store.ids || {}).filter(o => o.type === 'dungeon'));
		const farmingList = computed(() => placeableResources.value);

		// ── Previews visuales para el Inspector de casilla ─────────────────────
		// Devuelve { npcSprite, bg, bossSprite } según el tipo de elemento
		// presente en la casilla seleccionada. Todo se resuelve de forma síncrona
		// a partir de los datos ya cargados en el store (sin fetch adicional).
		const selTileVisuals = computed(() => {
			const item = selTileItem.value;
			if (!item) return null;
			const result = {};

			// ENEMIGO → sprite del enemigo
			if (item.kind === 'enemy') {
				result.enemySprite = getEnemySpriteUrl(item.id);
				result.enemyName = item.name;
				return result;
			}

			// ENTIDAD → POI / Ciudad / Mazmorra
			if (item.kind === 'entity') {
				const idDef = store.ids?.[item.id];

				// POI o Ciudad: NPC portrait + background del lugar
				if (item.subType === 'poi' || item.subType === 'city') {
					// NPC portrait — los ficheros en assets/vn/npcs se nombran
					// a veces como "<npcId>.png" y a veces como "npc_<npcId>.png".
					// Generamos ambas variantes; el template usará @error para
					// intentar el segundo si el primero falla.
					const npcId = idDef?.npc;
					if (npcId) {
						const base = npcId.endsWith('.png') ? npcId.slice(0, -4) : npcId;
						// Variante principal: npc_<id>.png (la más habitual)
						const npcFilePrefixed = 'npc_' + base + '.png';
						const npcFileDirect  = base + '.png';
						// Si ya tiene el prefijo npc_, no lo duplicamos
						result.npcSprite = base.startsWith('npc_')
							? `/api/assets/npc/${encodeURIComponent(base + '.png')}`
							: `/api/assets/npc/${encodeURIComponent(npcFilePrefixed)}`;
						result.npcSpriteFallback = base.startsWith('npc_')
							? null
							: `/api/assets/npc/${encodeURIComponent(npcFileDirect)}`;
						result.npcId = npcId;
					}
					// BG del lugar
					const bgFile = idDef?.bg;
					if (bgFile) {
						result.bg = `/api/assets/bg/${encodeURIComponent(bgFile)}`;
						result.bgName = bgFile;
					}
					return result;
				}

				// Mazmorra: sprite del boss
				if (item.subType === 'dungeon') {
					const idDef = store.ids?.[item.id];
					const dunId = idDef?.portal?.event_id || idDef?.portal?.target || idDef?.dungeon_id || item.id;
					const dunDef = store.dungeons?.[dunId] || store.dungeons?.[item.id];
					const bossId = dunDef?.boss;
					if (bossId) {
						result.bossSprite = getEnemySpriteUrl(bossId);
						result.bossId = bossId;
						const bossDef = store.enemies?.[bossId];
						result.bossName = getI18nDisplay(bossDef?.name) || bossId;
					}
					return result;
				}
			}

			return null;
		});

		function clearCurrentTileItem() {
			const t = selTile.value;
			if (!t) return;
			pushHistory();
			delete t.object;
			delete t.enemy;
			delete t.interactive;
			delete t.obstacle;
			delete t.chest;
			markWorldDirty();
			flash('Elemento quitado de la casilla.');
		}

		function startMoveCurrentItem() {
			if (!sel.value) return;
			const t = selTile.value;
			if (!t) return;
			const hasItem = t.object || t.enemy || t.interactive || t.obstacle || t.chest;
			if (!hasItem) { flash('Esta casilla no tiene elemento para mover.'); return; }
			store.brush.tool = 'move';
			moveSrc.value = {
				x: sel.value.x, y: sel.value.y,
				object: t.object || null,
				enemy: t.enemy ? deepClone(t.enemy) : null,
				interactive: t.interactive ? deepClone(t.interactive) : null,
				obstacle: t.obstacle ? deepClone(t.obstacle) : null,
				chest: t.chest ? deepClone(t.chest) : null,
			};
			const itemName = selTileItem.value?.name || t.object || (t.chest ? 'Cofre' : 'Elemento');
			flash('📦 Elemento "' + itemName + '" recogido. Haz clic en otra casilla del mapa para moverlo.');
		}

		function quickAddCity(cityId) {
			if (!sel.value || !selTile.value) return;
			pushHistory();
			delete selTile.value.enemy;
			delete selTile.value.interactive;
			delete selTile.value.obstacle;
			delete selTile.value.chest;
			assignObject(selTile.value, sel.value.x, sel.value.y, cityId);
			activeQuickAdd.value = null;
			flash('Ciudad colocada en la casilla.');
		}

		function quickAddPoi(poiId) {
			if (!sel.value || !selTile.value) return;
			pushHistory();
			delete selTile.value.enemy;
			delete selTile.value.interactive;
			delete selTile.value.obstacle;
			delete selTile.value.chest;
			assignObject(selTile.value, sel.value.x, sel.value.y, poiId);
			activeQuickAdd.value = null;
			flash('POI colocado en la casilla.');
		}

		function quickAddDungeon(dunId) {
			if (!sel.value || !selTile.value) return;
			pushHistory();
			delete selTile.value.enemy;
			delete selTile.value.interactive;
			delete selTile.value.obstacle;
			delete selTile.value.chest;
			assignObject(selTile.value, sel.value.x, sel.value.y, dunId);
			activeQuickAdd.value = null;
			flash('Mazmorra colocada en la casilla.');
		}

		function quickAddResource(resId) {
			if (!sel.value || !selTile.value) return;
			pushHistory();
			delete selTile.value.enemy;
			delete selTile.value.interactive;
			delete selTile.value.obstacle;
			delete selTile.value.chest;
			assignObject(selTile.value, sel.value.x, sel.value.y, resId);
			activeQuickAdd.value = null;
			flash('Recurso de farmeo colocado en la casilla.');
		}

		function quickCreateCity() {
			const raw = prompt('Nombre de la nueva Ciudad:', 'Nueva Ciudad');
			if (!raw) return;
			const base = 'city_' + slugifyDunId(raw);
			let id = base, n = 2;
			while (store.ids && store.ids[id]) id = base + '_' + (n++);
			const name = { es: raw, en: raw };
			if (!store.ids) store.ids = {};
			store.ids[id] = { id, type: 'city', name, icon: '🏛️', desc: { es: '', en: '' }, content: [] };
			markDirty('ids', id);
			if (sel.value && selTile.value) {
				quickAddCity(id);
			}
		}

		function quickCreatePoi() {
			const raw = prompt('Nombre del nuevo Punto de Interés (POI):', 'Nuevo POI');
			if (!raw) return;
			const base = 'poi_' + slugifyDunId(raw);
			let id = base, n = 2;
			while (store.ids && store.ids[id]) id = base + '_' + (n++);
			const name = { es: raw, en: raw };
			if (!store.ids) store.ids = {};
			store.ids[id] = { id, type: 'poi', name, icon: '📍', desc: { es: '', en: '' } };
			markDirty('ids', id);
			if (sel.value && selTile.value) {
				quickAddPoi(id);
			}
		}

		// ══════════════════════════════════════════════════════════════════════
		// — Editores INLINE por casilla: enemigo, objeto interactivo y
		// obstáculo rompible/demolible. El runtime (WorldMapBuilder) lee estos
		// campos directamente del tile de world.json, así que basta con escribirlos.
		// ══════════════════════════════════════════════════════════════════════
		const ENEMY_IDS = computed(() => Object.keys(store.enemies || {}));
		const INTERACTIVE_KINDS = [
			{ value: 'sign', label: '🪧 Cartel' },
			{ value: 'cinematic', label: '🎬 Cinemática' },
			{ value: 'tombstone', label: '🪦 Lápida' },
			{ value: 'book', label: '📖 Libro' },
			{ value: 'monument', label: '🗿 Monumento' },
			{ value: 'statue', label: '🗽 Estatua' },
		];
		const TOOL_IDS = [
			{ value: '', label: '— (solo bomba) —' },
			{ value: 'hacha', label: '🪓 Hacha' },
			{ value: 'pico', label: '⛏️ Pico' },
			{ value: 'pala', label: '🥄 Pala' },
		];

		const cinematicOptions = computed(() => Object.keys(store.cinematics || {}));
		const inspEnemy = computed(() => selTile.value?.enemy || null);
		const inspInteractive = computed(() => selTile.value?.interactive || null);
		const inspObstacle = computed(() => selTile.value?.obstacle || null);
		const inspChest = computed(() => selTile.value?.chest || null);
		const allItemIds = computed(() => Object.keys(store.items || {}).sort());

		// Lee/escribe una propiedad (con ruta 'a.b') de un campo inline del tile.
		function setInline(key, path, value) {
			const t = selTile.value; if (!t || !t[key]) return;
			pushHistory();
			const parts = path.split('.');
			let obj = t[key];
			for (let i = 0; i < parts.length - 1; i++) {
				if (typeof obj[parts[i]] !== 'object' || obj[parts[i]] === null) obj[parts[i]] = {};
				obj = obj[parts[i]];
			}
			obj[parts[parts.length - 1]] = value;
			markWorldDirty();
		}
		function addEnemy() {
			const t = selTile.value; if (!t) return;
			pushHistory();
			t.enemy = {
				enemy: (ENEMY_IDS.value[0] || 'slime_01'),
				enemy_id: (ENEMY_IDS.value[0] || 'slime_01'),
				level: 1,
				color: '#ff4d4d',
				radius: 1,
				speed: 1.0,
				respawn: true,
				respawn_time: 60,
				aggressive: true,
				sprite: '👾',
				move_interval: 2.5
			};
			markWorldDirty();
		}
		function addInteractive() {
			const t = selTile.value; if (!t) return;
			pushHistory();
			t.interactive = { kind: 'sign', icon: '🪧', title: { es: 'Cartel', en: 'Sign' }, text: { es: '', en: '' } };
			markWorldDirty();
		}
		function addCinematic() {
			const t = selTile.value; if (!t) return;
			pushHistory();
			const defaultCine = cinematicOptions.value[0] || 'intro';
			t.interactive = {
				kind: 'cinematic',
				icon: '🎬',
				cinematic_id: defaultCine,
				trigger_on_step: true,
				once: true,
				title: { es: 'Cinemática', en: 'Cinematic' }
			};
			markWorldDirty();
			flash('Trigger de cinemática colocado en la casilla.');
		}
		function addObstacle() {
			const t = selTile.value; if (!t) return;
			pushHistory();
			t.obstacle = { tool: 'hacha', bombable: false, reward: { item: 'wood', qty: 3 }, after: { icon: '🌿', name: { es: 'Claro', en: 'Clearing' } }, sfx: 'hit', orientation: 'horizontal' };
			markWorldDirty();
		}
		// Categoría "Utilidades y decoración" (task2_mundo.md): placeables sin
		// función de recurso/POI, solo utilidad o ambientación. "Camino bloqueado
		// por piedra" es su primer ítem — un obstáculo SOLO demolible con bomba
		// (tool: '' → cell_has_actionable_obstacle en TerrainToolsSystem.gd exige
		// tool no vacío, así que nunca se rompe a mano) que bloquea el paso hasta
		// que una explosión lo hace desaparecer con su propio efecto visual.
		function addBlockedPath() {
			const t = selTile.value; if (!t) return;
			pushHistory();
			t.icon = '🪨';
			t.name = { es: 'Camino bloqueado por piedra', en: 'Rock-blocked path' };
			t.description = {
				es: 'Un desprendimiento bloquea el paso. Solo una explosión podría abrirlo.',
				en: 'A rockfall blocks the way. Only an explosion could clear it.'
			};
			t.obstacle = { tool: '', bombable: true, reward: {}, after: { icon: '', name: { es: '', en: '' } }, sfx: 'hit', orientation: 'horizontal' };
			markWorldDirty();
		}
		function addChest() {
			const t = selTile.value; if (!t) return;
			pushHistory();
			t.chest = { gold: 50, items: [] };
			markWorldDirty();
			flash('Cofre colocado en la casilla.');
		}
		function setChestGold(val) {
			const t = selTile.value; if (!t || !t.chest) return;
			pushHistory();
			t.chest.gold = Math.max(0, parseInt(val, 10) || 0);
			markWorldDirty();
		}
		function addChestItem() {
			const t = selTile.value; if (!t || !t.chest) return;
			pushHistory();
			if (!Array.isArray(t.chest.items)) t.chest.items = [];
			t.chest.items.push({ id: '', qty: 1 });
			markWorldDirty();
		}
		function removeChestItem(idx) {
			const t = selTile.value; if (!t || !t.chest || !Array.isArray(t.chest.items)) return;
			pushHistory();
			t.chest.items.splice(idx, 1);
			markWorldDirty();
		}
		function setChestItem(idx, key, val) {
			const t = selTile.value; if (!t || !t.chest || !Array.isArray(t.chest.items)) return;
			const item = t.chest.items[idx];
			if (!item) return;
			pushHistory();
			item[key] = key === 'qty' ? Math.max(1, parseInt(val, 10) || 1) : val;
			markWorldDirty();
		}
		function removeInline(key) {
			const t = selTile.value; if (!t || !(key in t)) return;
			pushHistory(); delete t[key]; markWorldDirty();
		}
		function setObstacleReward(prop, value) {
			const t = selTile.value; if (!t || !t.obstacle) return;
			pushHistory();
			if (!t.obstacle.reward || typeof t.obstacle.reward !== 'object') t.obstacle.reward = {};
			t.obstacle.reward[prop] = value;
			markWorldDirty();
		}

		// ══════════════════════════════════════════════════════════════════════
		// TAREA 2 — Historial, autoguardado, redimensionado, duplicar, snapshots
		// ══════════════════════════════════════════════════════════════════════
		const DEFAULT_TERRAIN = 'sea';   // relleno del "lienzo" (océano) al expandir
		let strokeSnapshotTaken = false; // evita múltiples snapshots por pincelada

		// ── Historial deshacer/rehacer (reutiliza el composable común) ───────
		const history = useHistory({ limit: 60 });
		function worldState() { return deepClone(store.world); }
		function applyWorld(w) { store.world = w; markWorldDirty(); clampSelection(); scheduleMinimapDraw(); }
		function pushHistory() { history.push(worldState()); }
		function ensureStrokeSnapshot() { if (!strokeSnapshotTaken) { pushHistory(); strokeSnapshotTaken = true; } }
		function clampSelection() {
			const s = store.selectedCell;
			if (s && (s.x < 0 || s.y < 0 || s.x >= width.value || s.y >= height.value)) store.selectedCell = null;
		}
		function doUndo() { const p = history.undo(worldState()); if (p) applyWorld(p); }
		function doRedo() { const n = history.redo(worldState()); if (n) applyWorld(n); }

		// ── Autoguardado periódico ────────────────────────────────────────────
		const autosave = useAutosave({ intervalMs: 8000, isDirty: () => !!store.dirty.world || !!store.dirty.worldTest, onSave: () => save(false) });

		// ── Redimensionado del mundo desde cualquier borde (con preview) ────
		const resize = reactive({ top: 0, right: 0, bottom: 0, left: 0 });
		const newW = computed(() => width.value + resize.left + resize.right);
		const newH = computed(() => height.value + resize.top + resize.bottom);
		const resizeValid = computed(() => newW.value >= 1 && newH.value >= 1);
		const resizeDirty = computed(() => resize.top || resize.right || resize.bottom || resize.left);
		const coordShift = computed(() => resize.top > 0 || resize.left > 0);
		function bump(side, d) { resize[side] += d; }
		function resetResize() { resize.top = resize.right = resize.bottom = resize.left = 0; }

		// Rango de casillas (coords antiguas) que se CONSERVA tras el resize.
		function keptBounds() {
			const w = width.value, h = height.value;
			return {
				x0: resize.left < 0 ? -resize.left : 0,
				x1: resize.right < 0 ? w - 1 + resize.right : w - 1,
				y0: resize.top < 0 ? -resize.top : 0,
				y1: resize.bottom < 0 ? h - 1 + resize.bottom : h - 1,
			};
		}
		const removedNonEmpty = computed(() => {
			if (!resizeDirty.value) return 0;
			const { x0, x1, y0, y1 } = keptBounds();
			const tiles = store.world?.tiles || []; let c = 0;
			for (let y = 0; y < height.value; y++) for (let x = 0; x < width.value; x++) {
				if (x < x0 || x > x1 || y < y0 || y > y1) {
					const t = tiles[y]?.[x];
					if (t && (t.object || (t.terrain && t.terrain !== DEFAULT_TERRAIN))) c++;
				}
			}
			return c;
		});
		// Previsualización esquemática (px): caja nueva + región conservada.
		const preview = computed(() => {
			const nw = newW.value, nh = newH.value;
			if (nw < 1 || nh < 1) return null;
			const MAX = 168, s = Math.max(2, Math.min(MAX / nw, MAX / nh, 9));
			const kb = keptBounds();
			return {
				s, boxW: nw * s, boxH: nh * s,
				retX: (kb.x0 + resize.left) * s, retY: (kb.y0 + resize.top) * s,
				retW: (kb.x1 - kb.x0 + 1) * s, retH: (kb.y1 - kb.y0 + 1) * s,
			};
		});
		function applyResize() {
			if (!resizeValid.value || !resizeDirty.value) return;
			if (removedNonEmpty.value > 0 &&
				!confirm('Se eliminarán ' + removedNonEmpty.value + ' casilla(s) con contenido (terreno no-mar u objeto). ¿Continuar?')) return;
			pushHistory();
			const w = width.value, h = height.value, nw = newW.value, nh = newH.value;
			const tiles = store.world.tiles, nt = [];
			for (let ny = 0; ny < nh; ny++) {
				const row = [], oy = ny - resize.top;
				for (let nx = 0; nx < nw; nx++) {
					const ox = nx - resize.left;
					row.push((oy >= 0 && oy < h && ox >= 0 && ox < w) ? tiles[oy][ox] : { terrain: DEFAULT_TERRAIN });
				}
				nt.push(row);
			}
			store.world.tiles = nt; store.world.width = nw; store.world.height = nh;
			// Desplaza el inicio del protagonista junto con las coordenadas y lo acota.
			if (store.world.spawn) {
				const sx = store.world.spawn.x + resize.left;
				const sy = store.world.spawn.y + resize.top;
				store.world.spawn = {
					x: Math.min(Math.max(sx, 0), nw - 1),
					y: Math.min(Math.max(sy, 0), nh - 1),
				};
			}
			markWorldDirty(); clampSelection(); resetResize(); scheduleMinimapDraw();
			flash('Mundo redimensionado a ' + nw + '×' + nh + '.');
		}

		// ── Duplicar entidad (ids.json) + sus NPCs e hijos de content ────────
		function idExists(id) { return !!(store.ids && store.ids[id]); }
		function npcExists(id) { return !!(store.npcs && store.npcs[id]); }
		function uniqueKey(base, exists) {
			if (!exists(base)) return base;
			let c = base + '_copy', n = 2;
			while (exists(c)) { c = base + '_copy' + n; n++; }
			return c;
		}
		function cloneNpc(npcId) {
			if (!npcExists(npcId)) return npcId;
			const nn = uniqueKey(npcId, npcExists);
			store.npcs[nn] = deepClone(store.npcs[npcId]);
			markDirty('npcs', nn);
			return nn;
		}
		function duplicateEntity(id) {
			const src = store.ids?.[id]; if (!src) return;
			const newId = uniqueKey(id, idExists);
			const copy = deepClone(src); copy.id = newId;
			if (copy.npc) copy.npc = cloneNpc(copy.npc);
			if (Array.isArray(copy.content)) {
				copy.content = copy.content.map(childId => {
					const child = store.ids?.[childId];
					if (!child) return childId;
					const nc = uniqueKey(childId, idExists);
					const cc = deepClone(child); cc.id = nc;
					if (cc.npc) cc.npc = cloneNpc(cc.npc);
					store.ids[nc] = cc;
					return nc;
				});
			}
			store.ids[newId] = copy; markDirty('ids', newId);
			store.brush.tool = 'entity'; store.brush.entity = newId; store.brush.entityCat = 'all';
			flash('Duplicada: ' + newId + ' — selecciona una casilla para colocarla.');
		}

		// ── Snapshots (puntos de restauración del mundo) ─────────────────────
		// Un juego de snapshots POR MAPA (real/debug), en claves de localStorage
		// distintas, para no restaurar por error un mapa sobre el otro. `snaps`
		// apunta siempre al conjunto del mapa activo.
		const restoreState = (data) => { pushHistory(); applyWorld(data); flash('Copia de seguridad restaurada.'); };
		const snapsReal = useSnapshots({ storageKey: 'mw_snap_world', label: 'Mapa Real', getState: () => store.world, setState: restoreState });
		const snapsDebug = useSnapshots({ storageKey: 'mw_snap_world_test', label: 'Mapa de Pruebas', getState: () => store.world, setState: restoreState });
		const snaps = computed(() => store.activeMap === 'debug' ? snapsDebug : snapsReal);
		const newSnapName = ref('');
		function createSnapshot() { const s = snaps.value.create(newSnapName.value); newSnapName.value = ''; flash('Copia de seguridad creada: ' + s.name); }
		function importSnapshot(ev) {
			const file = ev.target.files?.[0]; if (!file) return;
			snaps.value.importFromFile(file).then(s => flash('Copia de seguridad importada: ' + s.name)).catch(e => { store.error = 'Import inválido: ' + e.message; });
			ev.target.value = '';
		}
		function snapDate(ts) { return new Date(ts).toLocaleString(); }

		// ── Paneles / UI ──────────────────────────────────────────────────────
		const showResize = ref(false);
		const showSnaps = ref(false);
		const dirtyWorld = computed(() => !!store.dirty.world || !!store.dirty.worldTest);
		// Selector de mapa activo (real ↔ debug) y etiqueta descriptiva del inicio.
		function selectMap(which) { switchMap(which); }
		const spawnLabel = computed(() => store.activeMap === 'debug'
			? 'Inicio en el Mapa de Pruebas (para probar cosas sin afectar la partida real)'
			: 'Inicio del protagonista (partida normal)');

		// ── Atajos de teclado (solo con la pestaña Mapa activa) ─────────────
		function onKey(e) {
			if (store.activeTab !== 'map') return;
			const tag = (e.target.tagName || '').toLowerCase();
			if (tag === 'input' || tag === 'textarea' || tag === 'select' || e.target.isContentEditable) return;
			const ctrl = e.ctrlKey || e.metaKey, k = e.key.toLowerCase();
			if (e.code === 'Space' && !spacePressed.value) {
				spacePressed.value = true;
			}
			if (ctrl && k === 'z') { e.preventDefault(); e.shiftKey ? doRedo() : doUndo(); }
			else if (ctrl && k === 'y') { e.preventDefault(); doRedo(); }
			else if (ctrl && k === 'c' && store.brush.tool === 'region') { e.preventDefault(); copyRegion(); }
			else if (ctrl && k === 'v' && store.brush.tool === 'region') { e.preventDefault(); requestPasteRegion(); }
			else if (e.key === 'Escape') {
				if (moveSrc.value) { e.preventDefault(); moveSrc.value = null; flash('Movimiento cancelado.'); }
				if (regionSel.value || regionPasteReady.value) { e.preventDefault(); clearRegion(); flash('Región deseleccionada.'); }
			}
		}
		function onKeyUp(e) {
			if (e.code === 'Space') {
				spacePressed.value = false;
				panning.value = false;
			}
		}
		onMounted(() => {
			window.addEventListener('keydown', onKey);
			window.addEventListener('keyup', onKeyUp);
			autosave.start();
			nextTick(() => { syncViewport(); centerMap(); drawMinimap(); });
			setTimeout(centerMap, 60);
			setTimeout(centerMap, 200);
			if (wrapRef.value && window.ResizeObserver) {
				resizeObserver = new ResizeObserver(syncViewport);
				resizeObserver.observe(wrapRef.value);
			} else {
				window.addEventListener('resize', syncViewport);
			}
		});
		// `<keep-alive>` (app.js) no desmonta este editor al cambiar de pestaña: solo
		// onMounted correría UNA vez. onActivated se dispara cada vez que se vuelve a
		// esta pestaña, que es justo cuando "el foco se inicia" según lo pedido.
		onActivated(() => {
			nextTick(() => { syncViewport(); centerMap(); drawMinimap(); });
			setTimeout(centerMap, 60);
		});
		onUnmounted(() => {
			window.removeEventListener('keydown', onKey);
			window.removeEventListener('keyup', onKeyUp);
			autosave.stop();
			window.removeEventListener('mousemove', onPaletteResizeMove);
			window.removeEventListener('mouseup', onPaletteResizeUp);
			window.removeEventListener('mousemove', onMinimapMove);
			window.removeEventListener('mouseup', onMinimapUp);
			if (resizeObserver) resizeObserver.disconnect();
			else window.removeEventListener('resize', syncViewport);
		});

		// Al cambiar de mapa (real ↔ debug) se limpia el historial: las pilas de
		// deshacer/rehacer contienen instantáneas del mapa anterior y aplicarlas
		// sobre el otro corrompería sus datos.
		watch(() => store.activeMap, () => { history.clear(); scheduleMinimapDraw(); });

		const enemyItems = computed(() => {
			return ENEMY_IDS.value.map(id => {
				const e = store.enemies?.[id] || {};
				const sprite = getEnemySpriteUrl(id);
				const name = getI18nDisplay(e.name) || id;
				if (sprite) {
					return { value: id, label: name, img: sprite, sub: `NV ${e.level || 1}` };
				} else {
					return { value: id, label: name, icon: '❌', sub: `NV ${e.level || 1} · ⚠️ Sin sprite` };
				}
			});
		});

		return {
			store, TERRAINS, TERRAIN_MAP, width, height, world,
			objectPalette, badRefs, painting,
			drawMode, rectStart, rectEnd, isInRect, fillEntireMapTerrain,
			// Task 5 (5.1): herramientas Medir y Región
			measureInfo, isInRegionSel, regionSel, regionClipboard, regionPasteReady, copyRegion, requestPasteRegion, clearRegion,
			TOOLS, setTool, ENTITY_CATS, terrainItems, resourceItems, entityItems, enemyItems,
			moveSrc, isMoveSrc,
			tileAt, cellStyle, objIcon, getTileEnemy, getEnemySpriteUrl, getTilePoiNpc,
			onCellDown, onCellEnter, onCellMove, onCellLeave, stopPaint,
			sel: computed(() => store.selectedCell), selTile, selObjDef, selTileInfo, terrainTextureUrl, setSelTerrain, setSelObject,
			zoom, zoomIn, zoomOut, resetZoom, scrollMap, spacePressed, wrapRef, hover, panning,
			onWheel, onWrapDown, onWrapMove, onWrapUp, hoverInfo,
			onScroll, visibleCells, cellGridStyle,
			paletteWidth, paletteResizing, mapLayoutStyle, onPaletteResizeDown,
			showInspector, toggleInspector, centerMap,
			goToTerrainEditor, goToNewTerrain, goToDungeon, quickCreateDungeon,
			// TAREA 2
			canUndo: history.canUndo, canRedo: history.canRedo, doUndo, doRedo,
			savedText: autosave.savedAgoText, dirtyWorld, doSave: () => save(false),
			resize, newW, newH, resizeValid, resizeDirty, coordShift, removedNonEmpty, preview,
			bump, resetResize, applyResize,
			showResize, showSnaps,
			duplicateEntity,
			snapshots: computed(() => snaps.value.snapshots.value), createSnapshot, newSnapName, snapDate,
			restoreSnapshot: (id) => snaps.value.restore(id), removeSnapshot: (id) => snaps.value.remove(id),
			exportSnapshot: (id) => snaps.value.exportSnapshot(id), importSnapshot,
			// Inicio del protagonista + selector de mapa (real/debug)
			spawnPos, isSpawn, setSpawn, gotoSpawn, selectMap, spawnLabel,
			// — editores inline por casilla
			ENEMY_IDS, INTERACTIVE_KINDS, TOOL_IDS, cinematicOptions,
			inspEnemy, inspInteractive, inspObstacle, inspChest, allItemIds,
			setInline, addEnemy, addInteractive, addCinematic, addObstacle, addBlockedPath, addChest, setChestGold, addChestItem, removeChestItem, setChestItem, removeInline, setObstacleReward,
			// Inspector modular
			selTileItem, selTileVisuals, activeQuickAdd,
			citiesList, poisList, dungeonsList, farmingList,
			quickAddCity, quickAddPoi, quickAddDungeon, quickAddResource,
			quickCreateCity, quickCreatePoi,
			clearCurrentTileItem, startMoveCurrentItem,
			onCellDblClick, exportMapRender,
			// Pilar 1 (Task 1): pincel con tamaño/suavizado, cuentagotas, capas visuales y minimapa
			BRUSH_SIZES, setBrushSize, toggleBrushSmooth,
			MAP_LAYERS, setMapLayer, layerOverlayColor,
			minimapRef, MINIMAP_W, MINIMAP_H, minimapViewport, minimapCollapsed, toggleMinimap,
			onMinimapDown, onMinimapMove, onMinimapUp, tooltipRef,
			getI18n, getI18nFallback, getI18nDisplay, setI18n,
		};
	},
	template: TEMPLATE,
};
