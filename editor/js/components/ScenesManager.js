// components/ScenesManager.js
// ─────────────────────────────────────────────────────────────────────────────
// EDITOR UNIFICADO DE ESCENAS — Sistema Narrativo.
//
// Edita scenes.json: cada entrada es una ESCENA (grafo de nodos) capaz de
// representar cualquier situación narrativa (conversación, cartel, tutorial,
// cinemática...). El escritor piensa solo en la historia: elige el tipo de cada
// nodo y encadena. Toda la complejidad la resuelve el motor (SceneRunner).
//
// Formato: scene_id -> { meta:{title{es,en},desc}, entry, nodes:{ id:{kind,...} } }.
// Tipos de nodo (una responsabilidad cada uno):
//   · say    → texto/narración: speaker, portrait, text{es,en}, fx, style, auto, next
//   · choice → opciones: prompt{es,en}, options:[{text{es,en}, condition, to}]
//   · state  → modifica el Estado Global: ops (mini-lenguaje), next
//   · event  → emite un evento global: emit, next
//   · flow   → control: op (goto|call|branch|wait|end), to/scene/branches/else/dur/next
//
// La lógica (condiciones, ops, eventos) se muestra SEPARADA de la narrativa para
// que la escena se lea como un guion.
// ─────────────────────────────────────────────────────────────────────────────
import { computed, ref } from 'https://unpkg.com/vue@3/dist/vue.esm-browser.prod.js';
import { store, getI18n, getI18nFallback, getI18nDisplay, setI18n } from '../store.js';
import * as FS from '../fs.js';
import { useCollection } from '../lib/useCollection.js';
import EntityListPanel from './EntityListPanel.js';
import EditorToolbar from './EditorToolbar.js';
import VnSimulatorModal from './VnSimulatorModal.js';
import VnAssetPicker from './VnAssetPicker.js';
import DsAudioBtn from '../ui/DsAudioBtn.js';
import TEMPLATE from './templates/ScenesManagerTemplate.js';

// Metadatos visuales de cada tipo de nodo (icono + etiqueta).
const NODE_KINDS = [
	{ kind: 'say', icon: '💬', label: 'Narrativa (say)' },
	{ kind: 'choice', icon: '🔀', label: 'Decisión (choice)' },
	{ kind: 'state', icon: '📊', label: 'Estado (state)' },
	{ kind: 'event', icon: '📡', label: 'Evento (event)' },
	{ kind: 'flow', icon: '🔁', label: 'Flujo (flow)' },
];
const FLOW_OPS = ['goto', 'call', 'branch', 'wait', 'end'];

export default {
	name: 'ScenesManager',
	components: { EntityListPanel, EditorToolbar, VnSimulatorModal, VnAssetPicker, DsAudioBtn },
	setup() {
		const simOpen = ref(false);
		const col = useCollection({
			tabId: 'scenes',
			dirtyKey: 'scenes',
			dirtyMap: () => store.dirtyScenes,
			collection: () => store.scenes,
			setCollection: (v) => { store.scenes = v; },
			selectedKey: 'selectedScene',
			clipboardKind: 'scene',
			entityLabel: 'escena',
			newIdBase: 'nueva_escena',
			// scenes es colección "un fichero por id": al borrar/
			// renombrar hay que borrar también el fichero en disco del id saliente.
			onRemove: (id) => FS.deleteCollectionItem('scenes', id),
			makeNew: () => ({
				meta: { title: { es: '', en: '' }, desc: '' },
				entry: 'n1',
				nodes: { n1: { kind: 'say', speaker: { es: '', en: '' }, text: { es: '', en: '' }, next: 'end' }, end: { kind: 'flow', op: 'end' } },
			}),
			searchText: (id, o) => id + ' ' + (o?.meta?.title?.es || '') + ' ' + (o?.meta?.desc || ''),
			sorts: [
				{ key: 'id', label: 'ID', get: (id) => id },
				{ key: 'nodes', label: 'Nº nodos', get: (id, o) => Object.keys(o?.nodes || {}).length },
			],
		});
		const current = col.current;

		// ── Lista de nodos de la escena actual (ordenada, entry primero) ──
		const nodeIds = computed(() => {
			const nodes = current.value?.nodes || {};
			const entry = current.value?.entry;
			const ids = Object.keys(nodes);
			ids.sort((a, b) => (a === entry ? -1 : b === entry ? 1 : a.localeCompare(b)));
			return ids;
		});
		const selNode = computed(() => {
			const nid = store.selectedSceneNode;
			return (current.value?.nodes && nid) ? current.value.nodes[nid] : null;
		});
		// Todos los ids de nodo (para los desplegables de destino) + palabras clave.
		const targetOptions = computed(() => ['end', ...Object.keys(current.value?.nodes || {})]);
		const sceneIds = computed(() => Object.keys(store.scenes || {}));

		function selectNode(id) { store.selectedSceneNode = id; }

		function setMeta(path, v) {
			col.edit(() => {
				const o = current.value;
				if (!o.meta) o.meta = { title: { es: '', en: '' }, desc: '' };
				if (path === 'title.es') { o.meta.title = o.meta.title || {}; o.meta.title.es = v; }
				else if (path === 'title.en') { o.meta.title = o.meta.title || {}; o.meta.title.en = v; }
				else if (path === 'desc') o.meta.desc = v;
			});
		}
		function setEntry(v) { col.edit(() => { current.value.entry = v; }); }

		// ── CRUD de nodos ──
		function uniqueNodeId() {
			const nodes = current.value.nodes || {};
			let i = 1; let id = 'n' + i;
			while (nodes[id]) { i++; id = 'n' + i; }
			return id;
		}
		function addNode() {
			col.edit(() => {
				current.value.nodes = current.value.nodes || {};
				const id = uniqueNodeId();
				current.value.nodes[id] = { kind: 'say', speaker: { es: '', en: '' }, text: { es: '', en: '' }, next: 'end' };
				store.selectedSceneNode = id;
			});
		}
		function removeNode(id) {
			col.edit(() => { delete current.value.nodes[id]; if (store.selectedSceneNode === id) store.selectedSceneNode = null; });
		}
		function renameNode(oldId, newId) {
			newId = (newId || '').trim();
			if (!newId || newId === oldId || current.value.nodes[newId]) return;
			col.edit(() => {
				const nodes = current.value.nodes;
				nodes[newId] = nodes[oldId];
				delete nodes[oldId];
				if (current.value.entry === oldId) current.value.entry = newId;
				store.selectedSceneNode = newId;
			});
		}
		// Cambia el TIPO del nodo, reconstruyendo campos por defecto de ese tipo.
		function setKind(id, kind) {
			col.edit(() => {
				const nodes = current.value.nodes;
				let n;
				if (kind === 'say') n = { kind, speaker: { es: '', en: '' }, text: { es: '', en: '' }, next: 'end' };
				else if (kind === 'choice') n = { kind, prompt: { es: '', en: '' }, options: [] };
				else if (kind === 'state') n = { kind, ops: '', next: 'end' };
				else if (kind === 'event') n = { kind, emit: '', next: 'end' };
				else n = { kind: 'flow', op: 'end' };
				nodes[id] = n;
			});
		}
		// Escribe un campo (con ruta 'a.b') del nodo seleccionado.
		function setNodeField(path, v) {
			col.edit(() => {
				const n = selNode.value; if (!n) return;
				const parts = path.split('.');
				let obj = n;
				for (let i = 0; i < parts.length - 1; i++) {
					if (typeof obj[parts[i]] !== 'object' || obj[parts[i]] == null) obj[parts[i]] = {};
					obj = obj[parts[i]];
				}
				obj[parts[parts.length - 1]] = v;
			});
		}
		function setFx(key, v) {
			col.edit(() => {
				const n = selNode.value; if (!n) return;
				if (!n.fx || typeof n.fx !== 'object') n.fx = {};
				if (v === '' || v == null) delete n.fx[key];
				else n.fx[key] = Number(v);
				if (Object.keys(n.fx).length === 0) delete n.fx;
			});
		}

		// ── Opciones de un nodo choice ──
		function addOption() {
			col.edit(() => {
				const n = selNode.value; if (!n) return;
				n.options = n.options || [];
				n.options.push({ text: { es: '', en: '' }, condition: '', to: 'end' });
			});
		}
		function removeOption(idx) { col.edit(() => { selNode.value.options.splice(idx, 1); }); }
		function setOption(idx, path, v) {
			col.edit(() => {
				const o = selNode.value.options[idx];
				if (path === 'text.es') { o.text = o.text || {}; o.text.es = v; }
				else if (path === 'text.en') { o.text = o.text || {}; o.text.en = v; }
				else if (path === 'condition') { if (v) o.condition = v; else delete o.condition; }
				else if (path === 'to') o.to = v;
			});
		}

		// ── Ramas de un flow branch ──
		function addBranch() {
			col.edit(() => {
				const n = selNode.value; if (!n) return;
				n.branches = n.branches || [];
				n.branches.push({ condition: '', to: 'end' });
			});
		}
		function removeBranch(idx) { col.edit(() => { selNode.value.branches.splice(idx, 1); }); }
		function setBranch(idx, path, v) {
			col.edit(() => {
				const b = selNode.value.branches[idx];
				if (path === 'condition') b.condition = v;
				else if (path === 'to') b.to = v;
			});
		}

		function nodeKindMeta(kind) { return NODE_KINDS.find(k => k.kind === kind) || NODE_KINDS[0]; }
		function nodeSummary(n) {
			if (!n) return '';
			if (n.kind === 'say') return (n.text?.es || '(sin texto)').slice(0, 42);
			if (n.kind === 'choice') return (n.options?.length || 0) + ' opciones';
			if (n.kind === 'state') return n.ops || '(sin ops)';
			if (n.kind === 'event') return '📡 ' + (n.emit || '');
			if (n.kind === 'flow') return '🔁 ' + (n.op || 'goto') + (n.to ? ' → ' + n.to : '') + (n.scene ? ' ⟶ ' + n.scene : '');
			return '';
		}

		return {
			store, col, current, NODE_KINDS, FLOW_OPS,
			nodeIds, selNode, targetOptions, sceneIds,
			selectNode, setMeta, setEntry,
			addNode, removeNode, renameNode, setKind, setNodeField, setFx,
			addOption, removeOption, setOption,
			addBranch, removeBranch, setBranch,
			nodeKindMeta, nodeSummary,
			simOpen,
			getI18n, getI18nFallback, getI18nDisplay, setI18n,
		};
	},
	template: TEMPLATE,
};
