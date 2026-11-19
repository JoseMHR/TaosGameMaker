// components/NpcGraphEditor.js
// ─────────────────────────────────────────────────────────────────────────────
// Modo GRAFO del editor de NPCs (Tarea 1). Canvas 2D nativo (sin librerías):
// cada nodo del diálogo es una tarjeta arrastrable; las conexiones `next` son
// curvas Bezier coloreadas por tipo de enlace. Incluye pan/zoom, selección
// múltiple (rubber band), copiar/pegar/duplicar/eliminar, deshacer/rehacer,
// búsqueda con resaltado, minimapa y autoguardado. Un drawer lateral edita el
// nodo completo (texto/condición/reward/next) reutilizando RewardEditor.
//
// El formato de npcs.json NO cambia: las posiciones son EFÍMERAS (en memoria).
// ─────────────────────────────────────────────────────────────────────────────
import { ref, computed, onMounted, onUnmounted, watch, nextTick } from 'https://unpkg.com/vue@3/dist/vue.esm-browser.prod.js';
import { store, markDirty, save, getI18n, getI18nFallback, getI18nDisplay, setI18n } from '../store.js';
import RewardEditor from './RewardEditor.js';
import ConditionEditor from './ConditionEditor.js';
import { useHistory, deepClone } from '../lib/useHistory.js';
import { useAutosave } from '../lib/useAutosave.js';
import * as Ann from '../lib/useNpcAnnotations.js';
import TEMPLATE from './templates/NpcGraphEditorTemplate.js';

// ── Constantes de layout / estilo ────────────────────────────────────────────
const NODE_W = 220;
const NODE_MIN_H = 80;
const NODE_MAX_H = 150;
const LAYER_DX = 300;   // separación horizontal entre capas
const LAYER_DY = 180;   // separación vertical entre nodos de una capa
const ORIGIN_X = 100;
const ORIGIN_Y = 80;
const MIN_SCALE = 0.3;
const MAX_SCALE = 2.0;

// Colores de cabecera por tipo de nodo.
const HEAD_MESSAGE = '#1e3a5f';
const HEAD_OPTION = '#5c3a00';
// Colores de aristas (según tipo de enlace).
const EDGE_NORMAL = '#4ade80';  // message → message sin condición
const EDGE_OPTION = '#60a5fa';  // message → option
const EDGE_COND = '#f87171';    // el origen tiene condición
const EDGE_BACK = '#facc15';    // salto atrás / ciclo
const EDGE_HOVER = '#ffffff';

// Posiciones por NPC: Map<npcId, Map<nodeId, {x,y}>>. A nivel de módulo para que
// sobrevivan al alternar entre modos (árbol/lista/grafo) durante la sesión.
const graphPositions = new Map();

export default {
	name: 'NpcGraphEditor',
	components: { RewardEditor, ConditionEditor },
	props: {
		npcId: { type: String, default: null },
		npcData: { type: Object, default: null },
		entryNodeId: { type: String, default: null },
		nextOptions: { type: Array, default: () => [] },
		conditionSnippets: { type: Array, default: () => [] },
	},
	emits: ['node-updated', 'node-added', 'node-deleted'],
	setup(props, { emit }) {
		const canvasRef = ref(null);
		const minimapRef = ref(null);

		// Cámara (transformación mundo→pantalla en px CSS): screen = world*scale + cam.
		const camera = { x: 0, y: 0, scale: 1 };
		const zoomPct = ref(100);

		const searchQuery = ref('');
		const drawerNodeId = ref(null);
		const selectionCount = ref(0);
		const selection = new Set();     // ids seleccionados (lógica de canvas)
		let clipboard = [];              // [{id, node}] copiados

		const history = useHistory({ limit: 50 });
		const autosave = useAutosave({
			intervalMs: 8000,
			isDirty: () => Object.keys(store.dirtyNpcs).length > 0,
			onSave: () => save(false),
		});

		// Estado interno de interacción (no reactivo: se lee en el bucle de dibujo).
		let layerMap = {};               // {nodeId: capa} para colorear back-edges
		let mode = 'idle';               // idle|dragNodes|panCanvas|rubberBand|minimapDrag
		let dragStart = { x: 0, y: 0 };  // punto inicial (mundo) del arrastre de nodos
		let panStart = { x: 0, y: 0 };   // punto inicial (pantalla) del paneo
		let camStart = { x: 0, y: 0 };
		let rubber = null;               // {x0,y0,x1,y1} en mundo
		let dragMoved = false;
		let spaceDown = false;
		let hoveredEdge = null;          // {src, idx}
		let mm = null;                   // transform del minimapa para mapear clics
		let editBaseline = null;         // snapshot para agrupar ediciones del drawer

		// ── Utilidades de datos ─────────────────────────────────────────────
		function nodeIds() {
			if (!props.npcData) return [];
			return Object.keys(props.npcData).filter(k => k !== '_meta');
		}
		function getNode(id) { return props.npcData ? props.npcData[id] : null; }
		function getState() { return deepClone(props.npcData); }

		// ── Posiciones ───────────────────────────────────────────────────────
		function posMap() {
			if (!props.npcId) return new Map();
			if (!graphPositions.has(props.npcId)) graphPositions.set(props.npcId, new Map());
			return graphPositions.get(props.npcId);
		}
		function nodePos(id) { return posMap().get(id) || { x: ORIGIN_X, y: ORIGIN_Y }; }

		// Layout automático en capas (tipo "dagre" manual) desde el nodo entrada.
		function computeLayout() {
			const pm = posMap();
			pm.clear();
			computeLayers();
			const byLayer = {};
			for (const id of nodeIds()) {
				const l = layerMap[id] == null ? -1 : layerMap[id];
				(byLayer[l] = byLayer[l] || []).push(id);
			}
			const normalLayers = Object.keys(byLayer).map(Number).filter(l => l >= 0).sort((a, b) => a - b);
			let maxY = ORIGIN_Y;
			for (const l of normalLayers) {
				const ids = byLayer[l];
				const totalH = (ids.length - 1) * LAYER_DY;
				let y = ORIGIN_Y - totalH / 2;
				for (const id of ids) {
					pm.set(id, { x: ORIGIN_X + l * LAYER_DX, y });
					maxY = Math.max(maxY, y);
					y += LAYER_DY;
				}
			}
			const orphans = byLayer[-1] || [];
			let ox = ORIGIN_X;
			for (const id of orphans) { pm.set(id, { x: ox, y: maxY + 200 }); ox += LAYER_DX; }
		}

		function ensurePositions() {
			const pm = posMap();
			if (pm.size === 0 && nodeIds().length) { computeLayout(); return; }
			let extra = 0;
			for (const id of nodeIds()) {
				if (!pm.has(id)) { pm.set(id, { x: ORIGIN_X + (extra++ * 40), y: ORIGIN_Y - 160 }); }
			}
		}

		// Capas por BFS desde la entrada (para colorear saltos atrás/ciclos).
		function computeLayers() {
			layerMap = {};
			const entry = props.entryNodeId;
			if (!entry || !getNode(entry)) return;
			const queue = [[entry, 0]];
			while (queue.length) {
				const [id, d] = queue.shift();
				if (id === 'close' || !getNode(id)) continue;
				if (layerMap[id] != null) continue;
				layerMap[id] = d;
				for (const nx of (getNode(id).next || [])) {
					if (nx !== 'close' && getNode(nx) && layerMap[nx] == null) queue.push([nx, d + 1]);
				}
			}
		}

		// ── Transformaciones mundo⇄pantalla ─────────────────────────────────
		function toScreen(wx, wy) { return { x: wx * camera.scale + camera.x, y: wy * camera.scale + camera.y }; }
		function toWorld(sx, sy) { return { x: (sx - camera.x) / camera.scale, y: (sy - camera.y) / camera.scale }; }

		function nodeHeight(id) {
			const n = getNode(id); if (!n) return NODE_MIN_H;
			let h = 30 + 34 + 18;
			if (n.condition) h += 18;
			if (n.reward) h += 18;
			return Math.max(NODE_MIN_H, Math.min(NODE_MAX_H, h));
		}
		function nodeRect(id) { const p = nodePos(id); return { x: p.x, y: p.y, w: NODE_W, h: nodeHeight(id) }; }

		function nodeAt(sx, sy) {
			const ids = nodeIds();
			for (let i = ids.length - 1; i >= 0; i--) {
				const r = nodeRect(ids[i]);
				const tl = toScreen(r.x, r.y); const br = toScreen(r.x + r.w, r.y + r.h);
				if (sx >= tl.x && sx <= br.x && sy >= tl.y && sy <= br.y) return ids[i];
			}
			return null;
		}

		// ── Búsqueda ─────────────────────────────────────────────────────────
		const matchSet = computed(() => {
			const q = searchQuery.value.trim().toLowerCase();
			const s = new Set();
			if (!q) return s;
			for (const id of nodeIds()) {
				const n = getNode(id);
				const hay = [id, n.text?.es, n.text?.en, n.condition, n.reward].filter(Boolean).join(' ').toLowerCase();
				if (hay.includes(q)) s.add(id);
			}
			return s;
		});

		// ── Bucle de dibujo (RAF con bandera dirty) ──────────────────────────
		let rafPending = false;
		function requestRedraw() {
			if (rafPending) return;
			rafPending = true;
			requestAnimationFrame(() => { rafPending = false; draw(); drawMinimap(); });
		}
		watch(searchQuery, requestRedraw);

		function fitCanvas(canvas) {
			const dpr = window.devicePixelRatio || 1;
			const cw = canvas.clientWidth, ch = canvas.clientHeight;
			if (canvas.width !== Math.round(cw * dpr) || canvas.height !== Math.round(ch * dpr)) {
				canvas.width = Math.round(cw * dpr); canvas.height = Math.round(ch * dpr);
			}
			return { dpr, cw, ch };
		}

		function draw() {
			const canvas = canvasRef.value; if (!canvas) return;
			const { dpr, cw, ch } = fitCanvas(canvas);
			const ctx = canvas.getContext('2d');
			ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
			ctx.clearRect(0, 0, cw, ch);
			ctx.fillStyle = '#0a0c14'; ctx.fillRect(0, 0, cw, ch);
			drawGrid(ctx, cw, ch);
			drawGroups(ctx);

			const matches = matchSet.value;
			for (const srcId of nodeIds()) {
				const next = getNode(srcId).next || [];
				for (let idx = 0; idx < next.length; idx++) drawEdge(ctx, srcId, idx, next[idx], matches);
			}
			for (const id of nodeIds()) drawNode(ctx, id, matches);

			if (mode === 'rubberBand' && rubber) {
				const a = toScreen(rubber.x0, rubber.y0); const b = toScreen(rubber.x1, rubber.y1);
				ctx.save();
				ctx.strokeStyle = 'rgba(255,255,255,0.7)'; ctx.setLineDash([5, 4]); ctx.lineWidth = 1;
				ctx.fillStyle = 'rgba(120,150,255,0.08)';
				const rx = Math.min(a.x, b.x), ry = Math.min(a.y, b.y), rw = Math.abs(b.x - a.x), rh = Math.abs(b.y - a.y);
				ctx.fillRect(rx, ry, rw, rh); ctx.strokeRect(rx, ry, rw, rh);
				ctx.restore();
			}
		}

		function drawGrid(ctx, cw, ch) {
			const step = 40 * camera.scale;
			if (step < 12) return;
			ctx.save();
			ctx.strokeStyle = 'rgba(255,255,255,0.035)'; ctx.lineWidth = 1;
			const ox = camera.x % step, oy = camera.y % step;
			for (let x = ox; x < cw; x += step) { ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, ch); ctx.stroke(); }
			for (let y = oy; y < ch; y += step) { ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(cw, y); ctx.stroke(); }
			ctx.restore();
		}

		// Dibuja marcos translúcidos por grupo (Fase 7): bbox de los nodos miembros.
		function drawGroups(ctx) {
			const gs = Ann.groups(props.npcData);
			if (!gs.length) return;
			const editor = props.npcData._meta && props.npcData._meta.editor;
			if (!editor) return;
			for (const g of gs) {
				const members = nodeIds().filter(id => editor.groupOf[id] === g.id);
				if (!members.length) continue;
				let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
				for (const id of members) { const r = nodeRect(id); minX = Math.min(minX, r.x); minY = Math.min(minY, r.y); maxX = Math.max(maxX, r.x + r.w); maxY = Math.max(maxY, r.y + r.h); }
				const pad = 18;
				const tl = toScreen(minX - pad, minY - pad - 16);
				const w = (maxX - minX + pad * 2) * camera.scale;
				const h = (maxY - minY + pad * 2 + 16) * camera.scale;
				ctx.save();
				ctx.fillStyle = g.color + '18';        // relleno muy tenue (hex + alpha)
				ctx.strokeStyle = g.color; ctx.lineWidth = 1.5; ctx.setLineDash([8, 5]);
				roundRect(ctx, tl.x, tl.y, w, h, 10 * camera.scale); ctx.fill(); ctx.stroke();
				ctx.setLineDash([]);
				ctx.fillStyle = g.color; ctx.font = `600 ${Math.max(10, 12 * camera.scale)}px 'Inter', sans-serif`;
				ctx.textAlign = 'left'; ctx.textBaseline = 'bottom';
				ctx.fillText(g.name, tl.x + 8, tl.y + 16 * camera.scale);
				ctx.restore();
			}
		}

		function edgeColor(srcId, dstId) {
			const src = getNode(srcId);
			if (src.condition && String(src.condition).trim()) return EDGE_COND;
			if (dstId !== 'close' && getNode(dstId)) {
				const ls = layerMap[srcId], ld = layerMap[dstId];
				if (ls != null && ld != null && ld <= ls) return EDGE_BACK;
				if ((getNode(dstId).type || 'message') === 'option') return EDGE_OPTION;
			}
			return EDGE_NORMAL;
		}

		function edgeEndpoints(srcId, dstId) {
			const rs = nodeRect(srcId);
			const from = toScreen(rs.x + rs.w, rs.y + rs.h / 2);
			let to;
			if (dstId === 'close' || !getNode(dstId)) to = toScreen(rs.x + rs.w + 60, rs.y + rs.h / 2);
			else { const rd = nodeRect(dstId); to = toScreen(rd.x, rd.y + rd.h / 2); }
			return { from, to };
		}

		function drawEdge(ctx, srcId, idx, dstId, matches) {
			const { from, to } = edgeEndpoints(srcId, dstId);
			const hovered = hoveredEdge && hoveredEdge.src === srcId && hoveredEdge.idx === idx;
			const color = hovered ? EDGE_HOVER : edgeColor(srcId, dstId);
			const cp = 100 * camera.scale;
			ctx.save();
			if (matches.size && !matches.has(srcId)) ctx.globalAlpha = 0.15;
			ctx.strokeStyle = color; ctx.lineWidth = hovered ? 3 : 2;
			ctx.beginPath();
			ctx.moveTo(from.x, from.y);
			ctx.bezierCurveTo(from.x + cp, from.y, to.x - cp, to.y, to.x, to.y);
			ctx.stroke();
			if (dstId === 'close' || !getNode(dstId)) {
				ctx.fillStyle = '#555'; ctx.beginPath(); ctx.arc(to.x, to.y, 8, 0, Math.PI * 2); ctx.fill();
				ctx.fillStyle = '#fff'; ctx.font = '10px monospace'; ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
				ctx.fillText('✕', to.x, to.y + 0.5);
			} else {
				drawArrowHead(ctx, to.x, to.y, color);
			}
			ctx.restore();
		}

		function drawArrowHead(ctx, x, y, color) {
			const s = 7;
			ctx.fillStyle = color;
			ctx.beginPath();
			ctx.moveTo(x, y); ctx.lineTo(x - s, y - s * 0.6); ctx.lineTo(x - s, y + s * 0.6);
			ctx.closePath(); ctx.fill();
		}

		function clip(text, max) {
			text = String(text || '');
			return text.length > max ? text.slice(0, max - 1) + '…' : text;
		}

		function drawNode(ctx, id, matches) {
			const n = getNode(id); if (!n) return;
			const r = nodeRect(id);
			const tl = toScreen(r.x, r.y);
			const w = r.w * camera.scale, h = r.h * camera.scale;
			const headH = 30 * camera.scale;
			const dim = matches.size && !matches.has(id);
			ctx.save();
			ctx.globalAlpha = dim ? 0.15 : 1.0;

			ctx.fillStyle = '#0f1524';
			roundRect(ctx, tl.x, tl.y, w, h, 8 * camera.scale); ctx.fill();
			// Color de cabecera: personalizado (anotación) → por defecto según tipo.
			const annColor = Ann.getColor(props.npcData, id);
			ctx.fillStyle = annColor || ((n.type === 'option') ? HEAD_OPTION : HEAD_MESSAGE);
			roundRectTop(ctx, tl.x, tl.y, w, headH, 8 * camera.scale); ctx.fill();

			let border = '#2b3145', bw = 1;
			const orphan = layerMap[id] == null;
			if (id === drawerNodeId.value) { border = '#6c8cff'; bw = 2; }
			else if (selection.has(id)) { border = '#ffffff'; bw = 2; }
			else if (matches.has(id)) { border = EDGE_BACK; bw = 2; }
			ctx.lineWidth = bw; ctx.strokeStyle = border;
			if (orphan && id !== drawerNodeId.value && !selection.has(id)) { ctx.setLineDash([5, 3]); ctx.strokeStyle = '#f0655f'; }
			roundRect(ctx, tl.x, tl.y, w, h, 8 * camera.scale); ctx.stroke();
			ctx.setLineDash([]);

			const fs = Math.max(9, 12 * camera.scale);
			ctx.fillStyle = '#eef1f8'; ctx.font = `600 ${fs}px monospace`; ctx.textAlign = 'left'; ctx.textBaseline = 'middle';
			const star = (id === props.entryNodeId) ? '⭐ ' : '';
			ctx.fillText(clip(star + id, 24), tl.x + 8 * camera.scale, tl.y + headH / 2);

			// Indicadores de anotación (marcador / comentario) en la esquina de la cabecera.
			const marks = [];
			if (Ann.isBookmarked(props.npcData, id)) marks.push('🔖');
			if (Ann.getComment(props.npcData, id)) marks.push('💬');
			if (marks.length) {
				ctx.font = `${Math.max(9, 12 * camera.scale)}px sans-serif`;
				ctx.textAlign = 'right'; ctx.textBaseline = 'middle';
				ctx.fillText(marks.join(''), tl.x + w - 6 * camera.scale, tl.y + headH / 2);
				ctx.textAlign = 'left';
			}

			if (camera.scale >= 0.5) {
				let ty = tl.y + headH + 14 * camera.scale;
				const bx = tl.x + 8 * camera.scale;
				const bfs = Math.max(8, 11 * camera.scale);
				ctx.font = `${bfs}px 'Inter', sans-serif`;
				ctx.fillStyle = '#aab2c8';
				ctx.fillText(clip('“' + (n.text?.es || '') + '”', 34), bx, ty); ty += 16 * camera.scale;
				if (n.condition) { ctx.fillStyle = '#f0a5a2'; ctx.fillText(clip('⚡ ' + n.condition, 32), bx, ty); ty += 16 * camera.scale; }
				if (n.reward) { ctx.fillStyle = '#e8c98b'; ctx.fillText(clip('🎁 ' + n.reward, 32), bx, ty); ty += 16 * camera.scale; }
				ctx.fillStyle = '#6f7793'; ctx.fillText('🔗 Links: ' + (n.next || []).length, bx, ty);
			}

			// Task 5 (5.3): badge de fin de flujo (esquina inferior derecha).
			const badge = terminalBadge(id);
			if (badge && camera.scale >= 0.35) {
				const label = badge.icon + ' ' + badge.label;
				const bfs = Math.max(8, 10 * camera.scale);
				ctx.font = `600 ${bfs}px 'Inter', sans-serif`;
				const padX = 6 * camera.scale;
				const tw = ctx.measureText(label).width + padX * 2;
				const bh2 = Math.max(14, 18 * camera.scale);
				const bx2 = tl.x + w - tw - 4 * camera.scale;
				const by2 = tl.y + h - bh2 - 4 * camera.scale;
				ctx.fillStyle = badge.color + 'cc';
				roundRect(ctx, bx2, by2, tw, bh2, bh2 / 2); ctx.fill();
				ctx.fillStyle = '#fff'; ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
				ctx.fillText(label, bx2 + tw / 2, by2 + bh2 / 2 + 0.5);
				ctx.textAlign = 'left';
			}
			ctx.restore();
		}

		function roundRect(ctx, x, y, w, h, r) {
			r = Math.min(r, w / 2, h / 2);
			ctx.beginPath();
			ctx.moveTo(x + r, y); ctx.arcTo(x + w, y, x + w, y + h, r); ctx.arcTo(x + w, y + h, x, y + h, r);
			ctx.arcTo(x, y + h, x, y, r); ctx.arcTo(x, y, x + w, y, r); ctx.closePath();
		}
		function roundRectTop(ctx, x, y, w, h, r) {
			r = Math.min(r, w / 2, h);
			ctx.beginPath();
			ctx.moveTo(x, y + h); ctx.lineTo(x, y + r); ctx.arcTo(x, y, x + r, y, r);
			ctx.lineTo(x + w - r, y); ctx.arcTo(x + w, y, x + w, y + r, r); ctx.lineTo(x + w, y + h); ctx.closePath();
		}

		function drawMinimap() {
			const canvas = minimapRef.value; if (!canvas) return;
			const { dpr, cw, ch } = fitCanvas(canvas);
			const ctx = canvas.getContext('2d');
			ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
			ctx.clearRect(0, 0, cw, ch);
			ctx.fillStyle = 'rgba(10,10,20,0.8)'; ctx.fillRect(0, 0, cw, ch);
			const ids = nodeIds(); if (!ids.length) { mm = null; return; }
			let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
			for (const id of ids) { const r = nodeRect(id); minX = Math.min(minX, r.x); minY = Math.min(minY, r.y); maxX = Math.max(maxX, r.x + r.w); maxY = Math.max(maxY, r.y + r.h); }
			const pad = 8;
			const bw = maxX - minX || 1, bh = maxY - minY || 1;
			const s = Math.min((cw - pad * 2) / bw, (ch - pad * 2) / bh);
			const offX = pad - minX * s + (cw - pad * 2 - bw * s) / 2;
			const offY = pad - minY * s + (ch - pad * 2 - bh * s) / 2;
			mm = { s, offX, offY };
			ctx.lineWidth = 1;
			for (const srcId of ids) {
				const rs = nodeRect(srcId);
				for (const dst of (getNode(srcId).next || [])) {
					if (dst === 'close' || !getNode(dst)) continue;
					const rd = nodeRect(dst);
					ctx.strokeStyle = edgeColor(srcId, dst);
					ctx.beginPath();
					ctx.moveTo((rs.x + rs.w) * s + offX, (rs.y + rs.h / 2) * s + offY);
					ctx.lineTo(rd.x * s + offX, (rd.y + rd.h / 2) * s + offY);
					ctx.stroke();
				}
			}
			for (const id of ids) {
				const r = nodeRect(id);
				ctx.fillStyle = (getNode(id).type === 'option') ? HEAD_OPTION : HEAD_MESSAGE;
				ctx.fillRect(r.x * s + offX, r.y * s + offY, Math.max(2, r.w * s), Math.max(2, r.h * s));
			}
			const canvasEl = canvasRef.value;
			if (canvasEl) {
				const w0 = toWorld(0, 0); const w1 = toWorld(canvasEl.clientWidth, canvasEl.clientHeight);
				ctx.strokeStyle = 'rgba(255,255,255,0.4)'; ctx.lineWidth = 1;
				ctx.strokeRect(w0.x * s + offX, w0.y * s + offY, (w1.x - w0.x) * s, (w1.y - w0.y) * s);
			}
		}

		function canvasXY(e) {
			const rect = canvasRef.value.getBoundingClientRect();
			return { x: e.clientX - rect.left, y: e.clientY - rect.top };
		}

		// ── Selección ──────────────────────────────────────────────────────
		let dragOrigin = {};             // posiciones iniciales al arrastrar
		let rubberBase = new Set();      // selección previa al iniciar rubber band
		function selectOnly(id) { selection.clear(); if (id) selection.add(id); selectionCount.value = selection.size; }
		function toggleSel(id) { if (selection.has(id)) selection.delete(id); else selection.add(id); selectionCount.value = selection.size; }

		// ── Historial / mutaciones ──────────────────────────────────────────
		function mutate(fn) {
			history.push(getState());
			fn();
			computeLayers(); ensurePositions();
			emit('node-updated');
			requestRedraw();
		}
		function commitEdit() {
			if (editBaseline) { history.push(editBaseline); editBaseline = null; }
			computeLayers();
			emit('node-updated');
			requestRedraw();
		}
		function applyState(snap) {
			const d = props.npcData; if (!d) return;
			for (const k of Object.keys(d)) delete d[k];
			for (const k of Object.keys(snap)) d[k] = snap[k];
			const pm = posMap();
			for (const id of Array.from(pm.keys())) if (!d[id] && id !== '_meta') pm.delete(id);
			computeLayers(); ensurePositions();
			if (drawerNodeId.value && !d[drawerNodeId.value]) drawerNodeId.value = null;
			for (const id of Array.from(selection)) if (!d[id]) selection.delete(id);
			selectionCount.value = selection.size;
			emit('node-updated'); requestRedraw();
		}
		function doUndo() { const prev = history.undo(getState()); if (prev) applyState(prev); }
		function doRedo() { const nx = history.redo(getState()); if (nx) applyState(nx); }

		// ── Copiar / pegar / duplicar / eliminar ────────────────────────────
		function uniqueId(base) {
			if (!props.npcData[base]) return base;
			let cand = base + '_copy'; let n = 2;
			while (props.npcData[cand]) { cand = base + '_copy' + n; n++; }
			return cand;
		}
		function doCopy() { clipboard = Array.from(selection).map(id => ({ id, node: deepClone(getNode(id)) })).filter(c => c.node); }
		function doPaste() {
			if (!clipboard.length || !props.npcData) return;
			mutate(() => {
				const idMap = {};
				for (const c of clipboard) idMap[c.id] = uniqueId(c.id);
				selection.clear();
				const pm = posMap();
				for (const c of clipboard) {
					const nid = idMap[c.id];
					const node = deepClone(c.node);
					if (Array.isArray(node.next)) node.next = node.next.map(nx => idMap[nx] || nx);
					props.npcData[nid] = node;
					const op = pm.get(c.id) || { x: ORIGIN_X, y: ORIGIN_Y };
					pm.set(nid, { x: op.x + 40, y: op.y + 40 });
					selection.add(nid);
					emit('node-added', nid, node);
				}
				selectionCount.value = selection.size;
			});
		}
		function doDuplicate() { if (!selection.size) return; doCopy(); doPaste(); }
		function doDeleteSelected() {
			const ids = Array.from(selection).filter(id => id !== '_meta' && getNode(id));
			if (!ids.length) return;
			if (ids.length > 1 && !confirm('¿Eliminar ' + ids.length + ' nodos seleccionados?')) return;
			mutate(() => {
				const pm = posMap();
				for (const id of ids) { delete props.npcData[id]; pm.delete(id); selection.delete(id); emit('node-deleted', id); }
				selectionCount.value = selection.size;
				if (drawerNodeId.value && !getNode(drawerNodeId.value)) drawerNodeId.value = null;
			});
		}

		// ── Zoom / encuadre ──────────────────────────────────────────────────
		function zoomAt(sx, sy, factor) {
			const before = toWorld(sx, sy);
			camera.scale = Math.max(MIN_SCALE, Math.min(MAX_SCALE, camera.scale * factor));
			camera.x = sx - before.x * camera.scale; camera.y = sy - before.y * camera.scale;
			zoomPct.value = Math.round(camera.scale * 100); requestRedraw();
		}
		function onWheel(e) { const { x, y } = canvasXY(e); zoomAt(x, y, e.deltaY < 0 ? 1.1 : 1 / 1.1); }
		function zoomButton(dir) { const c = canvasRef.value; const sx = c ? c.clientWidth / 2 : 0, sy = c ? c.clientHeight / 2 : 0; zoomAt(sx, sy, dir > 0 ? 1.1 : 1 / 1.1); }
		function fitView() {
			const ids = nodeIds(); const c = canvasRef.value; if (!ids.length || !c) return;
			let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
			for (const id of ids) { const r = nodeRect(id); minX = Math.min(minX, r.x); minY = Math.min(minY, r.y); maxX = Math.max(maxX, r.x + r.w); maxY = Math.max(maxY, r.y + r.h); }
			const pad = 60; const bw = maxX - minX || 1, bh = maxY - minY || 1;
			const scale = Math.max(MIN_SCALE, Math.min(MAX_SCALE, Math.min((c.clientWidth - pad * 2) / bw, (c.clientHeight - pad * 2) / bh)));
			camera.scale = scale;
			camera.x = (c.clientWidth - bw * scale) / 2 - minX * scale;
			camera.y = (c.clientHeight - bh * scale) / 2 - minY * scale;
			zoomPct.value = Math.round(scale * 100); requestRedraw();
		}
		function centerNode(id) {
			const r = nodeRect(id); const c = canvasRef.value; if (!c) return;
			camera.x = c.clientWidth / 2 - (r.x + r.w / 2) * camera.scale;
			camera.y = c.clientHeight / 2 - (r.y + r.h / 2) * camera.scale;
			requestRedraw();
		}
		function onSearchEnter() {
			const m = matchSet.value; if (!m.size) return;
			const first = nodeIds().find(id => m.has(id)); if (first) centerNode(first);
		}

		// ── Detección de arista bajo el cursor (hover) ──────────────────────
		function bezierPt(p0, p1, p2, p3, t) {
			const u = 1 - t, a = u * u * u, b = 3 * u * u * t, c = 3 * u * t * t, d = t * t * t;
			return { x: a * p0.x + b * p1.x + c * p2.x + d * p3.x, y: a * p0.y + b * p1.y + c * p2.y + d * p3.y };
		}
		function distToSeg(px, py, x1, y1, x2, y2) {
			const dx = x2 - x1, dy = y2 - y1, l2 = dx * dx + dy * dy;
			let t = l2 ? ((px - x1) * dx + (py - y1) * dy) / l2 : 0; t = Math.max(0, Math.min(1, t));
			return Math.hypot(px - (x1 + t * dx), py - (y1 + t * dy));
		}
		function updateEdgeHover(sx, sy) {
			let found = null, best = 8;
			for (const srcId of nodeIds()) {
				const next = getNode(srcId).next || [];
				const cp = 100 * camera.scale;
				for (let idx = 0; idx < next.length; idx++) {
					const { from, to } = edgeEndpoints(srcId, next[idx]);
					const p1 = { x: from.x + cp, y: from.y }, p2 = { x: to.x - cp, y: to.y };
					let px = from.x, py = from.y;
					for (let t = 0.1; t <= 1.0001; t += 0.1) {
						const p = bezierPt(from, p1, p2, to, t);
						if (distToSeg(sx, sy, px, py, p.x, p.y) < best) { best = 0; found = { src: srcId, idx }; }
						px = p.x; py = p.y;
					}
				}
			}
			const changed = (found && (!hoveredEdge || found.src !== hoveredEdge.src || found.idx !== hoveredEdge.idx)) || (!found && hoveredEdge);
			if (changed) { hoveredEdge = found; requestRedraw(); }
		}

		// ── Ratón ─────────────────────────────────────────────────────────────
		function onMouseDown(e) {
			if (!canvasRef.value) return;
			const { x, y } = canvasXY(e);
			if (e.button === 1 || e.button === 2 || (e.button === 0 && spaceDown)) {
				e.preventDefault();
				mode = 'panCanvas'; panStart = { x, y }; camStart = { x: camera.x, y: camera.y };
				canvasRef.value.classList.add('panning'); return;
			}
			if (e.button !== 0) return;
			const id = nodeAt(x, y);
			if (id) {
				if (e.shiftKey) toggleSel(id);
				else if (!selection.has(id)) selectOnly(id);
				mode = 'dragNodes'; dragMoved = false; dragStart = toWorld(x, y);
				dragOrigin = {};
				for (const sid of selection) { const p = nodePos(sid); dragOrigin[sid] = { x: p.x, y: p.y }; }
				requestRedraw();
			} else {
				mode = 'rubberBand'; const w = toWorld(x, y); rubber = { x0: w.x, y0: w.y, x1: w.x, y1: w.y };
				if (!e.shiftKey) { selection.clear(); selectionCount.value = 0; }
				rubberBase = new Set(selection);
				requestRedraw();
			}
		}
		function onMouseMove(e) {
			if (!canvasRef.value) return;
			const { x, y } = canvasXY(e);
			if (mode === 'panCanvas') { camera.x = camStart.x + (x - panStart.x); camera.y = camStart.y + (y - panStart.y); requestRedraw(); return; }
			if (mode === 'dragNodes') {
				const w = toWorld(x, y); const dx = w.x - dragStart.x, dy = w.y - dragStart.y;
				if (Math.abs(dx) > 1 || Math.abs(dy) > 1) dragMoved = true;
				const pm = posMap();
				for (const sid of selection) { const o = dragOrigin[sid]; if (o) pm.set(sid, { x: o.x + dx, y: o.y + dy }); }
				requestRedraw(); return;
			}
			if (mode === 'rubberBand' && rubber) {
				const w = toWorld(x, y); rubber.x1 = w.x; rubber.y1 = w.y;
				const minX = Math.min(rubber.x0, rubber.x1), maxX = Math.max(rubber.x0, rubber.x1);
				const minY = Math.min(rubber.y0, rubber.y1), maxY = Math.max(rubber.y0, rubber.y1);
				selection.clear(); for (const s of rubberBase) selection.add(s);
				for (const id of nodeIds()) { const r = nodeRect(id); if (r.x + r.w >= minX && r.x <= maxX && r.y + r.h >= minY && r.y <= maxY) selection.add(id); }
				selectionCount.value = selection.size; requestRedraw(); return;
			}
			if (mode === 'minimapDrag') { minimapPan(e); return; }
			if (mode === 'idle') updateEdgeHover(x, y);
		}
		function onMouseUp() {
			if (mode === 'panCanvas' && canvasRef.value) canvasRef.value.classList.remove('panning');
			if (mode === 'rubberBand') rubber = null;
			mode = 'idle'; requestRedraw();
		}
		function onDblClick(e) { const { x, y } = canvasXY(e); const id = nodeAt(x, y); if (id) openDrawer(id); }
		function onContextMenu(e) { e.preventDefault(); }

		// ── Minimapa (clic/arrastre reposiciona el viewport) ────────────────
		function onMinimapDown(e) { mode = 'minimapDrag'; minimapPan(e); }
		function minimapPan(e) {
			if (!mm || !minimapRef.value || !canvasRef.value) return;
			const rect = minimapRef.value.getBoundingClientRect();
			const wx = (e.clientX - rect.left - mm.offX) / mm.s, wy = (e.clientY - rect.top - mm.offY) / mm.s;
			const c = canvasRef.value;
			camera.x = c.clientWidth / 2 - wx * camera.scale; camera.y = c.clientHeight / 2 - wy * camera.scale;
			requestRedraw();
		}

		// ── Drawer de edición ────────────────────────────────────────────────
		const dNode = computed(() => (drawerNodeId.value && props.npcData) ? props.npcData[drawerNodeId.value] : null);
		function openDrawer(id) { drawerNodeId.value = id; editBaseline = getState(); selectOnly(id); requestRedraw(); }
		function closeDrawer() { drawerNodeId.value = null; editBaseline = null; requestRedraw(); }
		function dSetType(v) { const n = dNode.value; if (!n) return; n.type = v; commitEdit(); }
		function dSetText(lang, v) { const n = dNode.value; if (!n) return; if (!n.text) n.text = { es: '', en: '' }; n.text[lang] = v; commitEdit(); }
		function dSetCondition(v) { const n = dNode.value; if (!n) return; if (v === '') delete n.condition; else n.condition = v; commitEdit(); }
		function dAppendSnippet(s) { const n = dNode.value; if (!n) return; n.condition = (n.condition ? n.condition + ' and ' : '') + s; commitEdit(); }
		function dSetReward(v) { const n = dNode.value; if (!n) return; n.reward = v; commitEdit(); }
		function dEnsureNext(n) { if (!Array.isArray(n.next)) n.next = []; }
		function dSetNext(i, v) { const n = dNode.value; if (!n) return; dEnsureNext(n); n.next[i] = v; commitEdit(); }
		function dAddNext() { const n = dNode.value; if (!n) return; dEnsureNext(n); n.next.push('close'); commitEdit(); }
		function dRemoveNext(i) { const n = dNode.value; if (!n) return; n.next.splice(i, 1); commitEdit(); }
		function nextBroken(id) { return id !== 'close' && !props.nextOptions.includes(id); }

		// ── Task 5 (5.3): Badges de FIN DE FLUJO en nodos terminales. Se derivan
		// de la gramática REAL del mini-lenguaje de recompensas (REWARD_TOKENS en
		// store.js — Design.gd::_apply_token) y de `next`, no de campos inventados.
		// "Abre Tienda" no existe como token de diálogo en este motor (las tiendas
		// se abren al visitar un POI kind=shop, no desde un reward de nodo), así
		// que no se fabrica esa insignia para no sugerir una capacidad falsa.
		function terminalBadge(id) {
			const n = getNode(id); if (!n) return null;
			const reward = String(n.reward || '');
			if (/(^|;)\s*combat:/.test(reward)) return { icon: '⚔️', label: 'Inicia Combate', color: '#ef4444' };
			if (/(^|;)\s*(questf|quests):/.test(reward)) return { icon: '📜', label: 'Entrega Misión', color: '#a78bfa' };
			const next = n.next || [];
			if (!next.length || next.every(nx => nx === 'close')) return { icon: '🔚', label: 'Cierra Diálogo', color: '#6b7280' };
			return null;
		}

		// ── Anotaciones del nodo (color/comentario/marcador/grupo) — Fase 7 ────────
		// Reactividad: `annTick` fuerza recomputar los getters de la plantilla tras mutar.
		const annTick = ref(0);
		function annCommit() { markDirty('npcs', props.npcId); annTick.value++; emit('node-updated'); requestRedraw(); }
		const dColor = computed(() => (annTick.value, drawerNodeId.value ? Ann.getColor(props.npcData, drawerNodeId.value) : ''));
		const dComment = computed(() => (annTick.value, drawerNodeId.value ? Ann.getComment(props.npcData, drawerNodeId.value) : ''));
		const dBookmarked = computed(() => (annTick.value, drawerNodeId.value ? Ann.isBookmarked(props.npcData, drawerNodeId.value) : false));
		const dGroupId = computed(() => { annTick.value; const g = drawerNodeId.value ? Ann.groupOf(props.npcData, drawerNodeId.value) : null; return g ? g.id : ''; });
		const groupList = computed(() => (annTick.value, Ann.groups(props.npcData)));
		function dSetColor(v) { if (drawerNodeId.value) { Ann.setColor(props.npcData, drawerNodeId.value, v); annCommit(); } }
		function dSetComment(v) { if (drawerNodeId.value) { Ann.setComment(props.npcData, drawerNodeId.value, v); annCommit(); } }
		function dToggleBookmark() { if (drawerNodeId.value) { Ann.toggleBookmark(props.npcData, drawerNodeId.value); annCommit(); } }
		function dSetGroup(gid) { if (drawerNodeId.value) { Ann.setNodeGroup(props.npcData, drawerNodeId.value, gid); annCommit(); } }
		function dCreateGroup() {
			const name = prompt('Nombre del grupo:'); if (!name) return;
			const g = Ann.createGroup(props.npcData, name.trim());
			if (drawerNodeId.value) Ann.setNodeGroup(props.npcData, drawerNodeId.value, g.id);
			annCommit();
		}

		// ── Marcadores: menú desplegable para saltar a un nodo marcado ────────────
		const showBookmarks = ref(false);
		const bookmarkList = computed(() => (annTick.value, Ann.bookmarks(props.npcData).filter(id => getNode(id))));
		function jumpBookmark(id) { showBookmarks.value = false; if (getNode(id)) { selectOnly(id); centerNode(id); requestRedraw(); } }

		// ── Teclado ────────────────────────────────────────────────────────
		function isTyping(e) {
			const tag = (e.target.tagName || '').toLowerCase();
			return tag === 'input' || tag === 'textarea' || tag === 'select' || e.target.isContentEditable;
		}
		function onKey(e) {
			const typing = isTyping(e);
			const ctrl = e.ctrlKey || e.metaKey;
			const k = e.key.toLowerCase();
			if (e.code === 'Space' && !typing) { spaceDown = true; e.preventDefault(); return; }
			if (ctrl && k === 'z') { if (typing) return; e.preventDefault(); e.stopPropagation(); e.shiftKey ? doRedo() : doUndo(); }
			else if (ctrl && k === 'y') { if (typing) return; e.preventDefault(); e.stopPropagation(); doRedo(); }
			else if (ctrl && k === 'c') { if (typing) return; doCopy(); }
			else if (ctrl && k === 'v') { if (typing) return; doPaste(); }
			else if (ctrl && k === 'd') { if (typing) return; e.preventDefault(); doDuplicate(); }
			else if (k === 'delete' || k === 'backspace') { if (typing || drawerNodeId.value) return; e.preventDefault(); doDeleteSelected(); }
			else if (k === 'escape') { if (drawerNodeId.value) closeDrawer(); }
		}
		function onKeyUp(e) { if (e.code === 'Space') spaceDown = false; }

		// ── Ciclo de vida ────────────────────────────────────────────────────
		let ro = null;
		onMounted(() => {
			window.addEventListener('mousemove', onMouseMove);
			window.addEventListener('mouseup', onMouseUp);
			window.addEventListener('keydown', onKey);
			window.addEventListener('keyup', onKeyUp);
			ro = new ResizeObserver(() => requestRedraw());
			if (canvasRef.value) ro.observe(canvasRef.value);
			autosave.start();
			nextTick(() => { ensurePositions(); computeLayers(); fitView(); });
		});
		onUnmounted(() => {
			window.removeEventListener('mousemove', onMouseMove);
			window.removeEventListener('mouseup', onMouseUp);
			window.removeEventListener('keydown', onKey);
			window.removeEventListener('keyup', onKeyUp);
			if (ro) ro.disconnect();
			autosave.stop();
		});
		watch(() => props.npcId, () => {
			history.clear(); selection.clear(); selectionCount.value = 0;
			drawerNodeId.value = null; editBaseline = null; hoveredEdge = null;
			nextTick(() => { ensurePositions(); computeLayers(); fitView(); });
		});

		return {
			// refs de plantilla
			canvasRef, minimapRef, searchQuery, zoomPct, selectionCount, drawerNodeId, dNode,
			snippets: computed(() => props.conditionSnippets),
			nextOpts: computed(() => props.nextOptions),
			entryId: computed(() => props.entryNodeId),
			canUndo: history.canUndo, canRedo: history.canRedo, savedText: autosave.savedAgoText,
			// interacción canvas
			onMouseDown, onWheel, onDblClick, onContextMenu, onMinimapDown,
			// barra de herramientas
			zoomButton, fitView, doUndo, doRedo, doCopy, doPaste, doDuplicate, doDeleteSelected, onSearchEnter,
			// drawer
			openDrawer, closeDrawer, dSetType, dSetText, dSetCondition, dAppendSnippet, dSetReward,
			dSetNext, dAddNext, dRemoveNext, nextBroken,
			// anotaciones (Fase 7)
			dColor, dComment, dBookmarked, dGroupId, groupList,
			dSetColor, dSetComment, dToggleBookmark, dSetGroup, dCreateGroup,
			showBookmarks, bookmarkList, jumpBookmark,
			store, getI18n, getI18nFallback, getI18nDisplay, setI18n,
		};
	},
	template: TEMPLATE,
};
