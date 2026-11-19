// components/NpcEditor.js
// ─────────────────────────────────────────────────────────────────────────────
// Editor de npcs.json. Lista lateral de NPCs y, para el seleccionado, un flujo
// visual por bloques (un bloque por nodo). Cada nodo edita tipo, condición
// (asistida), texto bilingüe, recompensa (RewardEditor) y enlaces `next` con
// dropdowns dinámicos y botón "ir al nodo". Vista previa del sprite del NPC.
// ─────────────────────────────────────────────────────────────────────────────
import { computed, ref, reactive, watch, nextTick, onMounted, onUnmounted } from 'https://unpkg.com/vue@3/dist/vue.esm-browser.prod.js';
import { store, markDirty, flash, save, CONDITION_SNIPPETS, FACETS, getI18n, getI18nFallback, getI18nDisplay, setI18n } from '../store.js';
import RewardEditor from './RewardEditor.js';
import ConditionEditor from './ConditionEditor.js';
import NpcGraphEditor from './NpcGraphEditor.js';
import EditorToolbar from './EditorToolbar.js';
import VnSimulatorModal from './VnSimulatorModal.js';
import VnAssetPicker from './VnAssetPicker.js';
import DsAudioBtn from '../ui/DsAudioBtn.js';
import { useClipboard } from '../lib/useClipboard.js';
import { useAutosave } from '../lib/useAutosave.js';
import { useDocumentHistory } from '../lib/useDocumentHistory.js';
import { deepClone } from '../lib/useHistory.js';
import { defaultSimState, evalCondition, applyReward, summarizeReward } from '../lib/useDialogueSim.js';
import * as FS from '../fs.js';
import TEMPLATE from './templates/NpcEditorTemplate.js';

export default {
	name: 'NpcEditor',
	components: { RewardEditor, ConditionEditor, NpcGraphEditor, EditorToolbar, VnSimulatorModal, VnAssetPicker, DsAudioBtn },
	setup() {
		const vnSimOpen = ref(false);
		const search = ref('');
		const sortKey = ref('id');   // id | name | nodes
		const flashNode = ref('');
		const clipboard = useClipboard();

		const npcs = computed(() => store.npcs || {});

		// Un avatar "emoji" (p. ej. "🍸") NO es un fichero: es texto que el motor
		// (DialogueResource.npc_avatar) renderiza tal cual. Mismo criterio que
		function isEmojiAvatarValue(av) {
			if (!av || typeof av !== 'string') return false;
			if (av.includes('.') || av.includes('/')) return false;
			return !/^[a-zA-Z0-9_-]+$/.test(av);
		}

		function getNpcPortrait(id) {
			if (!id) return { url: null, emoji: '' };
			const n = npcs.value[id];
			const av = n?._meta?.avatar || (n?._meta?.reward && n._meta.reward.match(/avatar=([^;\s]+)/)?.[1]);
			if (av && isEmojiAvatarValue(av)) return { url: null, emoji: av };
			if (av) {
				const base = av.split('/').pop().replace(/\.png$/, '');
				const f = base.startsWith('npc_') ? base + '.png' : 'npc_' + base + '.png';
				return { url: `/api/assets/npc/${encodeURIComponent(f)}`, emoji: '' };
			}
			const base = id.toLowerCase().replace(/\.png$/, '');
			const f = base.startsWith('npc_') ? base + '.png' : 'npc_' + base + '.png';
			return { url: `/api/assets/npc/${encodeURIComponent(f)}`, emoji: '' };
		}

		const npcList = computed(() => {
			const q = search.value.trim().toLowerCase();
			const rows = Object.keys(npcs.value)
				.filter(id => !q || id.toLowerCase().includes(q) || metaText(id).toLowerCase().includes(q))
				.map(id => { const av = getNpcPortrait(id); return { id, meta: metaText(id), count: nodeCount(id), portrait: av.url, emoji: av.emoji }; });
			const k = sortKey.value;
			rows.sort((a, b) => {
				if (k === 'name') return (a.meta || a.id).localeCompare(b.meta || b.id);
				if (k === 'nodes') return b.count - a.count;
				return a.id.localeCompare(b.id);
			});
			return rows;
		});

		function metaText(id) { return npcs.value[id]?._meta?.text?.es || ''; }
		function nodeCount(id) { return Object.keys(npcs.value[id] || {}).filter(k => k !== '_meta').length; }

		const current = computed(() => store.selectedNpc ? npcs.value[store.selectedNpc] : null);

		// Modo de vista del flujo: 'script' (guión/chat visual) | 'tree' (árbol jerárquico) | 'list' | 'graph'.
		const flowMode = ref('script');
		// Nodos colapsados (por id) en la vista de árbol.
		const collapsed = ref({});

		// Nodos conversacionales (excluye _meta), ordenados por clave.
		const nodeEntries = computed(() => {
			if (!current.value) return [];
			return Object.keys(current.value)
				.filter(k => k !== '_meta')
				.sort((a, b) => a.localeCompare(b))
				.map(k => ({ id: k, node: current.value[k] }));
		});
		// Opciones de `next` para dropdowns: todos los nodos navegables + close.
		const nextOptions = computed(() => {
			if (!current.value) return [];
			return Object.keys(current.value).filter(k => k !== '_meta');
		});

		// Garantiza que el _meta exista (para la cabecera premium).
		function ensureMeta() {
			if (current.value && !current.value._meta) {
				current.value._meta = { type: 'meta', text: { es: '', en: '' }, next: [], reward: '' };
			}
			if (current.value && !current.value._meta.text) current.value._meta.text = { es: '', en: '' };
		}
		watch(current, () => { if (current.value) ensureMeta(); }, { immediate: true });

		// ── Nodo de entrada del diálogo: el primer "message" no referenciado por
		//    ningún next (misma lógica que Design.entry_node), con fallback a *_1.
		const entryNodeId = computed(() => {
			if (!current.value) return null;
			const nodes = current.value;
			const targeted = new Set();
			for (const [k, n] of Object.entries(nodes)) {
				if (k === '_meta') continue;
				for (const nx of (n.next || [])) if (nx !== 'close') targeted.add(nx);
			}
			let fallback = null;
			for (const [k, n] of Object.entries(nodes)) {
				if (k === '_meta' || (n.type || 'message') !== 'message') continue;
				if (!targeted.has(k)) return k;
				if (!fallback) fallback = k;
			}
			// Si todo está referenciado, usa *_1 o el primer nodo.
			return (store.selectedNpc && nodes[store.selectedNpc + '_1']) ? store.selectedNpc + '_1'
				: (fallback || Object.keys(nodes).find(k => k !== '_meta') || null);
		});

		// ── Árbol de flujo: recorre desde la entrada; marca ciclos (retornos). ──
		const flowTree = computed(() => {
			if (!current.value) return [];
			const nodes = current.value;
			const rows = [];
			const seen = new Set();
			function walk(id, depth, ancestors) {
				if (id === 'close' || !nodes[id]) return;
				if (ancestors.has(id)) { rows.push({ id, depth, loop: true }); return; }
				const alreadySeen = seen.has(id);
				rows.push({ id, depth, loop: false, dup: alreadySeen });
				if (alreadySeen) return; // no re-expandir nodos ya mostrados
				seen.add(id);
				const nextAnc = new Set(ancestors); nextAnc.add(id);
				for (const nx of (nodes[id].next || [])) walk(nx, depth + 1, nextAnc);
			}
			if (entryNodeId.value) walk(entryNodeId.value, 0, new Set());
			// Añade nodos huérfanos (no alcanzables) al final, a nivel 0.
			for (const k of Object.keys(nodes)) {
				if (k === '_meta') continue;
				if (!seen.has(k) && !rows.some(r => r.id === k)) rows.push({ id: k, depth: 0, loop: false, orphan: true });
			}
			return rows;
		});

		function toggleCollapse(id) { collapsed.value[id] = !collapsed.value[id]; }
		// ¿La fila está oculta porque un ancestro en el árbol está colapsado?
		function rowHidden(rows, i) {
			const d = rows[i].depth;
			for (let j = i - 1; j >= 0; j--) {
				if (rows[j].depth < d) {
					if (collapsed.value[rows[j].id]) return true;
					if (rows[j].depth === 0) break;
					// seguir subiendo por la cadena de ancestros
				}
			}
			return false;
		}

		// ── Estilo de la tarjeta de personaje según bg=r,g,b del _meta.reward ──
		const metaCardStyle = computed(() => {
			const reward = current.value?._meta?.reward || '';
			const match = reward.match(/bg=([0-9.,]+)/);
			if (match) {
				const rgb = match[1].split(',');
				if (rgb.length === 3) {
					const r = Math.round(parseFloat(rgb[0]) * 255);
					const g = Math.round(parseFloat(rgb[1]) * 255);
					const b = Math.round(parseFloat(rgb[2]) * 255);
					return { background: `linear-gradient(135deg, rgba(${r},${g},${b},0.85), rgba(${r},${g},${b},0.4))` };
				}
			}
			return {};
		});

		function touch() { markDirty('npcs', store.selectedNpc); }

		// Task 5 (1.3): historial de deshacer/rehacer, con ámbito el NPC seleccionado
		// (fotografía/restaura solo su árbol de nodos, no todo npcs.json). Se limpia
		// al cambiar de NPC para no mezclar pasos de diálogos distintos.
		const hist = useDocumentHistory({
			tabId: 'npcs',
			getDoc: () => current.value,
			setDoc: (v) => { if (store.selectedNpc) store.npcs[store.selectedNpc] = v; touch(); },
		});
		function edit(fn) { hist.edit(fn); touch(); }
		watch(() => store.selectedNpc, () => hist.clear());

		function selectNpc(id) { store.selectedNpc = id; }

		// ── Edición de nodo ──
		function setType(node, v) { edit(() => { node.type = v; }); }
		function setText(node, lang, v) {
			edit(() => {
				if (!node.text) node.text = { es: '', en: '' };
				node.text[lang] = v;
			});
		}
		function setCondition(node, v) {
			edit(() => { if (v === '') delete node.condition; else node.condition = v; });
		}
		function appendSnippet(node, snip) {
			edit(() => { node.condition = (node.condition ? node.condition + ' and ' : '') + snip; });
		}
		function setReward(node, v) { edit(() => { node.reward = v; }); }

		// next
		function ensureNext(node) { if (!Array.isArray(node.next)) node.next = []; }
		function setNext(node, idx, v) { edit(() => { ensureNext(node); node.next[idx] = v; }); }
		function addNext(node, v) { edit(() => { ensureNext(node); node.next.push(v || 'close'); }); }
		function removeNext(node, idx) { edit(() => { node.next.splice(idx, 1); }); }

		async function gotoNode(id) {
			if (id === 'close') return;
			flashNode.value = id;
			await nextTick();
			const el = document.getElementById('node-' + id);
			if (el) el.scrollIntoView({ behavior: 'smooth', block: 'start' });
			setTimeout(() => { if (flashNode.value === id) flashNode.value = ''; }, 1200);
		}

		function isDeadEnd(node) {
			return !Array.isArray(node.next) || node.next.length === 0;
		}
		function nextBroken(id) {
			return id !== 'close' && !nextOptions.value.includes(id);
		}

		// ── Helpers de creación fluida (1-clic) para el Modo Guión ──
		function generateNodeId(prefix = 'm') {
			const base = (store.selectedNpc || 'npc') + '_' + prefix;
			let n = 1;
			while (current.value && current.value[base + '_' + n]) n++;
			return base + '_' + n;
		}

		function appendNextMessage(fromNodeId) {
			if (!current.value) return;
			const newId = generateNodeId('m');
			edit(() => {
				current.value[newId] = {
					type: 'message',
					text: { es: '', en: '' },
					next: ['close'],
					reward: '',
				};
				if (fromNodeId && current.value[fromNodeId]) {
					current.value[fromNodeId].next = [newId];
				}
			});
			gotoNode(newId);
		}

		function appendChoices(fromNodeId) {
			if (!current.value) return;
			const opt1Id = generateNodeId('opt');
			const resp1Id = generateNodeId('m');
			const opt2Id = generateNodeId('opt');
			const resp2Id = generateNodeId('m');

			edit(() => {
				current.value[resp1Id] = {
					type: 'message',
					text: { es: '', en: '' },
					next: ['close'],
					reward: '',
				};
				current.value[opt1Id] = {
					type: 'option',
					text: { es: 'Opción A', en: 'Option A' },
					next: [resp1Id],
					reward: '',
				};

				current.value[resp2Id] = {
					type: 'message',
					text: { es: '', en: '' },
					next: ['close'],
					reward: '',
				};
				current.value[opt2Id] = {
					type: 'option',
					text: { es: 'Opción B', en: 'Option B' },
					next: [resp2Id],
					reward: '',
				};

				if (fromNodeId && current.value[fromNodeId]) {
					current.value[fromNodeId].next = [opt1Id, opt2Id];
				}
			});
			gotoNode(opt1Id);
		}

		function addOptionToChoice(fromMessageId) {
			if (!current.value || !current.value[fromMessageId]) return;
			const optId = generateNodeId('opt');
			const respId = generateNodeId('m');
			edit(() => {
				current.value[respId] = {
					type: 'message',
					text: { es: '', en: '' },
					next: ['close'],
					reward: '',
				};
				current.value[optId] = {
					type: 'option',
					text: { es: 'Nueva opción', en: 'New option' },
					next: [respId],
					reward: '',
				};
				ensureNext(current.value[fromMessageId]);
				current.value[fromMessageId].next.push(optId);
			});
		}

		function setSemanticDest(node, destType, targetId = '') {
			if (!node) return;
			edit(() => {
				ensureNext(node);
				if (destType === 'close') {
					node.next = ['close'];
				} else if (destType === 'menu') {
					node.next = [entryNodeId.value || 'close'];
				} else if (destType === 'target') {
					node.next = [targetId];
				}
			});
		}

		function isForkNode(node) {
			if (!node || !Array.isArray(node.next)) return false;
			return node.next.some(nx => current.value?.[nx]?.type === 'option');
		}

		function getChildOptions(node) {
			if (!node || !Array.isArray(node.next)) return [];
			return node.next
				.filter(nx => current.value?.[nx]?.type === 'option')
				.map(id => ({ id, node: current.value[id] }));
		}

		// ── Alta / baja de nodos y NPCs ──
		const showAddNode = ref(false);
		const newNodeId = ref('');
		const newNodeType = ref('message');
		function addNode() {
			const id = newNodeId.value.trim();
			if (!id || !current.value) return;
			if (current.value[id]) { store.error = 'Ya existe el nodo "' + id + '".'; return; }
			edit(() => { current.value[id] = { type: newNodeType.value, text: { es: '', en: '' }, next: ['close'], reward: '' }; });
			newNodeId.value = '';
			showAddNode.value = false;
			gotoNode(id);
		}
		function deleteNode(id) {
			if (id === '_meta') { if (!confirm('¿Eliminar el nodo _meta del NPC?')) return; }
			else if (!confirm('¿Eliminar el nodo "' + id + '"?')) return;
			edit(() => { delete current.value[id]; });
		}

		const showAddNpc = ref(false);
		const newNpcId = ref('');
		function addNpc() {
			const id = newNpcId.value.trim();
			if (!id) return;
			if (store.npcs[id]) { store.error = 'Ya existe el NPC "' + id + '".'; return; }
			store.npcs[id] = {
				_meta: { type: 'meta', text: { es: id, en: id }, next: [], reward: '' },
				[id + '_1']: { type: 'message', text: { es: '', en: '' }, next: ['close'], reward: '' },
			};
			newNpcId.value = '';
			showAddNpc.value = false;
			store.selectedNpc = id;
			touch();
		}
		function deleteNpc() {
			const id = store.selectedNpc;
			if (!id || !confirm('¿Eliminar el NPC "' + id + '" completo? Se puede recuperar recargando si no guardas.')) return;
			delete store.npcs[id];
			store.selectedNpc = Object.keys(store.npcs)[0] || null;
			touch();
			// npcs es colección "un fichero por id" (data/npcs/<id>.json): el borrado
			// del FICHERO en disco es INMEDIATO (no espera a "Guardar"), igual que
			// ids/dungeons/world_buildings.
			FS.deleteCollectionItem('npcs', id).catch(() => {});
		}

		// ── NPC-level: duplicar / copiar / pegar (portapapeles común) ──────────
		function uniqueNpcId(base) {
			let id = base, n = 1;
			while (store.npcs[id]) id = base + '_' + (++n);
			return id;
		}
		function duplicateNpc() {
			const id = store.selectedNpc;
			if (!id || !store.npcs[id]) return;
			const nid = uniqueNpcId(id + '_copy');
			store.npcs[nid] = deepClone(store.npcs[id]);
			store.selectedNpc = nid; touch();
			flash('NPC duplicado: ' + nid);
		}
		function copyNpc() {
			if (!current.value) return;
			clipboard.copy('npc', current.value);
			flash('NPC copiado al portapapeles.');
		}
		const canPasteNpc = computed(() => clipboard.canPaste('npc'));
		function pasteNpc() {
			const data = clipboard.read('npc');
			if (!data) return;
			const nid = uniqueNpcId((store.selectedNpc || 'npc') + '_copy');
			store.npcs[nid] = data;
			store.selectedNpc = nid; touch();
			flash('NPC pegado: ' + nid);
		}
		function addMeta() {
			if (!current.value || current.value._meta) return;
			edit(() => { current.value._meta = { type: 'meta', text: { es: '', en: '' }, next: [], reward: '' }; });
		}

		// ── Eventos emitidos por el modo Grafo (NpcGraphEditor) ──────────────
		// El grafo NO muta store.npcs directamente para nodos nuevos/borrados:
		// emite y aquí centralizamos la mutación + markDirty (misma vía que el
		// resto del editor). Las ediciones de campos existentes sí son directas
		// (objetos reactivos compartidos), pero también pasan por touch().
		function onGraphNodeUpdated() { edit(() => {}); }
		function onGraphNodeAdded(nodeId, nodeData) {
			if (!current.value || !nodeId) return;
			edit(() => { current.value[nodeId] = nodeData; });
		}
		function onGraphNodeDeleted(nodeId) {
			if (!current.value || !nodeId || nodeId === '_meta') return;
			edit(() => { delete current.value[nodeId]; });
		}

		// Vista previa y selección del avatar/sprite del NPC.
		const currentAvatarName = computed(() => {
			if (!current.value) return '';
			if (current.value._meta?.avatar) return current.value._meta.avatar;
			const rew = current.value._meta?.reward || '';
			const m = rew.match(/avatar=([^;\s]+)/);
			if (m && m[1]) return m[1];
			return 'npc_' + store.selectedNpc + '.png';
		});

		const isEmojiAvatar = computed(() => isEmojiAvatarValue(currentAvatarName.value));

		const spriteUrl = computed(() => {
			const av = currentAvatarName.value;
			if (!av || isEmojiAvatar.value) return null;
			if (av.startsWith('http://') || av.startsWith('https://') || av.startsWith('/')) return av;
			if (av.endsWith('.png') || av.endsWith('.jpg') || av.endsWith('.webp')) return '/assets/vn/npcs/' + av;
			return '/assets/vn/npcs/' + (av.startsWith('npc_') ? av : 'npc_' + av) + '.png';
		});

		function setNpcAvatar(val) {
			if (!current.value) return;
			if (!current.value._meta) current.value._meta = { type: 'meta', text: { es: '', en: '' } };
			current.value._meta.avatar = val;
			let rew = current.value._meta.reward || '';
			if (rew.includes('avatar=')) {
				current.value._meta.reward = rew.replace(/avatar=[^;\s]+/, 'avatar=' + val);
			} else if (rew) {
				current.value._meta.reward = rew + '; avatar=' + val;
			}
			touch();
		}

		// ══════════════════════════════════════════════════════════════════════
		// SIMULADOR DE DIÁLOGO (Play Mode) — con simulación de CONDICIONES y
		// RECOMPENSAS sobre un ESTADO SIMULADO editable. Usa la librería
		// `useDialogueSim`, gemelo del runtime (Design.gd).
		// ══════════════════════════════════════════════════════════════════════
		const simOpen = ref(false);
		const simNodeId = ref(null);
		const simLang = ref('es');
		const simState = reactive(defaultSimState());   // estado del "jugador" simulado
		const simLog = ref([]);                          // registro de efectos aplicados
		const simShowState = ref(true);                  // panel de estado desplegado
		const SIM_FACETS = ['valor', 'bondad', 'aspecto', 'inteligencia', 'cordura'];

		function resetSimState() { Object.assign(simState, defaultSimState()); }

		function startSim() {
			simOpen.value = true;
			simLang.value = 'es';
			simLog.value = [];
			simNodeId.value = entryNodeId.value;
			if (simNodeId.value) { gotoNode(simNodeId.value); applyNodeReward(simNodeId.value, true); }
		}
		function stopSim() { simOpen.value = false; }
		function restartSim() { resetSimState(); startSim(); }

		const simNode = computed(() => (simNodeId.value && current.value) ? current.value[simNodeId.value] : null);

		// Estado de una condición evaluada contra el estado simulado.
		function condStatus(cond) { return evalCondition(cond, simState); }
		function condLabel(s) { return s === 'pass' ? '✓ se cumple' : (s === 'fail' ? '✗ no se cumple' : '? no evaluable'); }

		// Opciones (nodos "option") accesibles, con su estado de condición.
		const simOptions = computed(() => {
			if (!simNode.value || !current.value) return [];
			return (simNode.value.next || [])
				.filter(nx => nx !== 'close' && current.value[nx] && (current.value[nx].type === 'option'))
				.map(nx => { const node = current.value[nx]; return { id: nx, node, cond: node.condition || '', status: condStatus(node.condition) }; });
		});
		// Continuación directa (primer next que no es opción) para nodos-mensaje.
		const simContinue = computed(() => {
			if (!simNode.value || !current.value) return null;
			for (const nx of (simNode.value.next || [])) {
				if (nx === 'close') return 'close';
				const child = current.value[nx];
				if (child && child.type !== 'option') return nx;
			}
			return simOptions.value.length ? null : 'close';
		});

		// Aplica el reward del nodo destino al estado simulado y registra los efectos.
		function applyNodeReward(nodeId, isEntry = false) {
			const node = current.value?.[nodeId];
			if (!node || !node.reward) return;
			const effects = applyReward(node.reward, simState);
			if (effects.length) simLog.value = [...simLog.value, { node: nodeId, entry: isEntry, effects }];
		}

		function simChoose(nodeId) {
			if (nodeId === 'close' || !nodeId) { stopSim(); return; }
			simNodeId.value = nodeId;
			gotoNode(nodeId);
			applyNodeReward(nodeId);
		}
		function simText(node) {
			if (!node) return '';
			return (node.text && node.text[simLang.value]) || node.text?.es || '';
		}
		function simReward(node) { return node ? summarizeReward(node.reward) : ''; }

		// Inventario simulado como lista para la plantilla.
		const simItems = computed(() => Object.entries(simState.items).map(([id, n]) => ({ id, n })));
		function simAddItem() {
			const id = prompt('ID del objeto a añadir al inventario simulado:');
			if (id && id.trim()) { simState.items[id.trim()] = (simState.items[id.trim()] || 0) + 1; }
		}
		function simRemoveItem(id) { delete simState.items[id]; }
		// Flags simulados como lista.
		const simFlags = computed(() => Object.keys(simState.flags));
		function simAddFlag() {
			const f = prompt('Nombre del flag del NPC a activar:');
			if (f && f.trim()) simState.flags[f.trim()] = true;
		}
		function simToggleFlag(f) { if (simState.flags[f]) delete simState.flags[f]; else simState.flags[f] = true; }

		// ── Autosave + guardado manual (Tarea 4, vía común) ────────────────────
		const autosave = useAutosave({
			isDirty: () => Object.keys(store.dirtyNpcs).length > 0,
			onSave: () => save(false),
			intervalMs: 30000,
		});
		function saveNow() { save(false); }

		// ── Atajos de teclado comunes a nivel NPC ─────────────────────────────
		function onKeydown(e) {
			// No interceptar mientras se escribe en un campo de texto.
			const tag = (e.target && e.target.tagName || '').toLowerCase();
			if (tag === 'input' || tag === 'textarea' || e.target?.isContentEditable) return;
			const ctrl = e.ctrlKey || e.metaKey;
			if (ctrl && e.key.toLowerCase() === 's') { e.preventDefault(); saveNow(); }
			else if (ctrl && e.key.toLowerCase() === 'd') { e.preventDefault(); duplicateNpc(); }
			else if (ctrl && e.key.toLowerCase() === 'c') { copyNpc(); }
			else if (ctrl && e.key.toLowerCase() === 'v') { if (canPasteNpc.value) pasteNpc(); }
			else if (e.key === 'Delete' && store.selectedNpc) { deleteNpc(); }
		}
		onMounted(() => { window.addEventListener('keydown', onKeydown); autosave.start(); });
		onUnmounted(() => { window.removeEventListener('keydown', onKeydown); autosave.stop(); });

		// Conversión dinámica del NPC al formato escena para el simulador VN completo
		const npcSceneData = computed(() => {
			if (!current.value) return null;
			const raw = current.value;
			const sceneNodes = {};
			for (const [k, v] of Object.entries(raw)) {
				if (k === '_meta') continue;
				const nextList = v.next || [];
				const isChoice = nextList.length > 1;
				if (isChoice) {
					sceneNodes[k] = {
						kind: 'choice',
						prompt: v.text,
						options: nextList.map(target => ({
							text: raw[target]?.text || { es: 'Opción: ' + target, en: 'Option: ' + target },
							to: target,
						})),
					};
				} else {
					sceneNodes[k] = {
						kind: 'say',
						speaker: { es: raw._meta?.text?.es || store.selectedNpc, en: raw._meta?.text?.en || store.selectedNpc },
						portrait: currentAvatarName.value || ('npc_' + store.selectedNpc + '.png'),
						text: v.text,
						next: nextList[0] || 'end',
					};
				}
			}
			return {
				meta: { title: { es: 'Conversación con ' + (raw._meta?.text?.es || store.selectedNpc), en: store.selectedNpc } },
				entry: entryNodeId.value || Object.keys(sceneNodes)[0] || 'n1',
				nodes: sceneNodes,
			};
		});

		const appearingLocations = computed(() => {
			if (!store.selectedNpc || !store.ids) return [];
			const id = store.selectedNpc;
			const locs = [];
			for (const [poiId, poi] of Object.entries(store.ids)) {
				if (poi.type !== 'poi' && poi.type !== 'city') continue;
				let matches = poi.npc === id;
				if (!matches && poi.presences) {
					matches = poi.presences.some(p => p.actor === id);
				}
				if (matches) {
					locs.push({
						id: poiId,
						name: poi.name?.es || poiId,
						icon: poi.icon || '📍',
					});
				}
			}
			return locs;
		});

		return {
			store, CONDITION_SNIPPETS,
			search, sortKey, npcList, current, nodeEntries, nextOptions, spriteUrl, currentAvatarName, isEmojiAvatar, setNpcAvatar, flashNode,
			appearingLocations,
			selectNpc, metaText, nodeCount, touch,
			canUndo: hist.canUndo, canRedo: hist.canRedo, undo: hist.undo, redo: hist.redo,
			setType, setText, setCondition, appendSnippet, setReward,
			setNext, addNext, removeNext, gotoNode, isDeadEnd, nextBroken,
			showAddNode, newNodeId, newNodeType, addNode, deleteNode, addMeta,
			showAddNpc, newNpcId, addNpc, deleteNpc,
			// Tarea 4: portapapeles/duplicado + autosave/guardado a nivel NPC
			duplicateNpc, copyNpc, pasteNpc, canPasteNpc, saveNow, autosave,
			// Modo Grafo (Tarea 1)
			onGraphNodeUpdated, onGraphNodeAdded, onGraphNodeDeleted,
			// T3: cabecera meta, árbol de flujo y simulador
			flowMode, collapsed, flowTree, toggleCollapse, rowHidden, entryNodeId, metaCardStyle,
			simOpen, simNodeId, simLang, startSim, stopSim, restartSim, simNode, simOptions, simContinue, simChoose, simText,
			// Simulación de condiciones/recompensas + estado simulado
			simState, simLog, simShowState, SIM_FACETS, condLabel, simReward,
			simItems, simAddItem, simRemoveItem, simFlags, simAddFlag, simToggleFlag,
			vnSimOpen, npcSceneData,
			// Script flow 1-click helpers
			appendNextMessage, appendChoices, addOptionToChoice, setSemanticDest, isForkNode, getChildOptions, generateNodeId,
			getI18n, getI18nFallback, getI18nDisplay, setI18n,
			currentLangBadge: computed(() => store.supportedLanguages.find(l => l.code === store.currentLang)?.label || store.currentLang.toUpperCase()),
		};
	},
	template: TEMPLATE,
};
