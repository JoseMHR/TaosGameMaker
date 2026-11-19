// lib/useHistory.js
// ─────────────────────────────────────────────────────────────────────────────
// Composable REUTILIZABLE de deshacer/rehacer por instantáneas (snapshots JSON).
// Es agnóstico al dominio: el llamante decide QUÉ estado fotografiar (un objeto
// serializable) y cómo aplicarlo al restaurar. Pensado para que TODOS los
// editores del backoffice compartan el mismo historial (base de la Tarea 4).
//
// Uso típico:
//   const hist = useHistory({ limit: 50 });
//   // antes de mutar:            hist.push(getState());
//   // deshacer:                  const prev = hist.undo(getState()); if (prev) applyState(prev);
//   // rehacer:                   const next = hist.redo(getState()); if (next) applyState(next);
//   // al cambiar de contexto:    hist.clear();
// ─────────────────────────────────────────────────────────────────────────────
import { ref, computed } from 'https://unpkg.com/vue@3/dist/vue.esm-browser.prod.js';

/** Clona en profundidad un valor serializable (estado del editor). */
export function deepClone(obj) {
	return obj == null ? obj : JSON.parse(JSON.stringify(obj));
}

/**
 * Crea un historial de instantáneas con límite configurable.
 * @param {{ limit?: number }} opts
 */
export function useHistory(opts = {}) {
	const limit = opts.limit || 50;
	const undoStack = ref([]);
	const redoStack = ref([]);

	const canUndo = computed(() => undoStack.value.length > 0);
	const canRedo = computed(() => redoStack.value.length > 0);

	/** Fotografía el estado ANTES de una mutación. Invalida la pila de rehacer. */
	function push(state) {
		undoStack.value.push(deepClone(state));
		if (undoStack.value.length > limit) undoStack.value.shift();
		redoStack.value = [];
	}

	/**
	 * Deshace: guarda `current` en la pila de rehacer y devuelve el estado
	 * anterior (o null si no hay nada que deshacer).
	 */
	function undo(current) {
		if (!undoStack.value.length) return null;
		redoStack.value.push(deepClone(current));
		return undoStack.value.pop();
	}

	/**
	 * Rehace: guarda `current` en la pila de deshacer y devuelve el estado
	 * siguiente (o null si no hay nada que rehacer).
	 */
	function redo(current) {
		if (!redoStack.value.length) return null;
		undoStack.value.push(deepClone(current));
		return redoStack.value.pop();
	}

	/** Limpia ambas pilas (p. ej. al cambiar de entidad/NPC seleccionado). */
	function clear() {
		undoStack.value = [];
		redoStack.value = [];
	}

	return { push, undo, redo, clear, canUndo, canRedo, undoStack, redoStack };
}
