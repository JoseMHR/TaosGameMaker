// lib/useDocumentHistory.js
// ─────────────────────────────────────────────────────────────────────────────
// Deshacer/rehacer (Task 5, 1.3) para editores de UN SOLO DOCUMENTO (no una
// colección {id->entidad}): ambience.json, config.json, quests.json (hooks),
// synergies.json… Complementa a useCollection.js (que ya cubre las colecciones)
// reutilizando el mismo useHistory.js y el mismo patrón de coalescing por
// ráfagas, para que "Ctrl+Z/Ctrl+Y en todos los gestores" sea de verdad TODOS.
// ─────────────────────────────────────────────────────────────────────────────
import { onMounted, onUnmounted } from 'https://unpkg.com/vue@3/dist/vue.esm-browser.prod.js';
import { store } from '../store.js';
import { useHistory, deepClone } from './useHistory.js';

const COALESCE_MS = 450;

/**
 * @param {{
 *   tabId: string,               // store.activeTab en el que este editor está activo
 *   getDoc: () => Object,        // getter del documento a fotografiar
 *   setDoc: (v:Object) => void,  // aplica un estado restaurado (reemplaza el documento)
 *   limit?: number,
 * }} cfg
 */
export function useDocumentHistory(cfg) {
	const history = useHistory({ limit: cfg.limit || 50 });
	let lastPush = 0;

	/** Fotografía el documento ANTES de mutar (llamar manualmente si no se usa `edit`). */
	function snapshot() { history.push(deepClone(cfg.getDoc())); lastPush = Date.now(); }
	/** Ejecuta una mutación con historial COALESCED (ráfagas de tecleo = 1 paso). */
	function edit(fn) {
		if (Date.now() - lastPush > COALESCE_MS) snapshot();
		else lastPush = Date.now();
		fn();
	}
	function undo() { const p = history.undo(deepClone(cfg.getDoc())); if (p) cfg.setDoc(p); }
	function redo() { const n = history.redo(deepClone(cfg.getDoc())); if (n) cfg.setDoc(n); }

	function onKey(e) {
		if (store.activeTab !== cfg.tabId) return;
		const k = e.key.toLowerCase();
		if ((e.ctrlKey || e.metaKey) && k === 'z' && !e.shiftKey) { e.preventDefault(); undo(); }
		else if ((e.ctrlKey || e.metaKey) && (k === 'y' || (e.shiftKey && k === 'z'))) { e.preventDefault(); redo(); }
	}
	onMounted(() => window.addEventListener('keydown', onKey));
	onUnmounted(() => window.removeEventListener('keydown', onKey));

	return { snapshot, edit, undo, redo, clear: history.clear, canUndo: history.canUndo, canRedo: history.canRedo };
}
