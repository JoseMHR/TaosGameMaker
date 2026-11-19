// lib/useAutosave.js
// ─────────────────────────────────────────────────────────────────────────────
// Composable REUTILIZABLE de autoguardado periódico. Cada `intervalMs` comprueba
// si hay cambios (`isDirty()`); si los hay, invoca `onSave()` y registra el
// momento. Expone un texto legible ("💾 guardado hace Xs") que se refresca solo.
// Pensado para que todos los editores del backoffice compartan la misma lógica
// de autoguardado (base de la Tarea 4).
//
// El componente controla el ciclo de vida:
//   const auto = useAutosave({ intervalMs: 8000, isDirty: () => store.dirty.npcs, onSave: () => save(false) });
//   onMounted(auto.start); onUnmounted(auto.stop);
//   // en el template: {{ auto.savedAgoText.value }}
// ─────────────────────────────────────────────────────────────────────────────
import { ref, computed } from 'https://unpkg.com/vue@3/dist/vue.esm-browser.prod.js';

/**
 * @param {{ intervalMs?: number, isDirty: () => boolean, onSave: () => (void|Promise<void>) }} opts
 */
export function useAutosave(opts) {
	const intervalMs = opts.intervalMs || 8000;
	const isDirty = opts.isDirty;
	const onSave = opts.onSave;

	const lastSavedAt = ref(0);   // timestamp (ms) del último guardado efectivo
	const now = ref(Date.now());  // reloj para refrescar el texto "hace Xs"
	// Task 7, ítem 5.5: antes un fallo en onSave() quedaba en silencio (solo
	// seguía mostrando "cambios sin guardar", indistinguible de "aún no ha
	// tocado autoguardar"). Ahora se distingue explícitamente el estado de error.
	const saveFailed = ref(false);
	const lastError = ref(null);
	let saveTimer = null;
	let tickTimer = null;
	let saving = false;

	/** Texto legible del estado de autoguardado, reactivo al paso del tiempo. */
	const savedAgoText = computed(() => {
		if (saveFailed.value) return '⚠️ error al guardar (reintentando…)';
		if (!lastSavedAt.value) return isDirty() ? '● cambios sin guardar' : 'sin cambios';
		const secs = Math.max(0, Math.round((now.value - lastSavedAt.value) / 1000));
		if (isDirty()) return '● cambios sin guardar';
		if (secs < 2) return '💾 guardado';
		if (secs < 60) return `💾 guardado hace ${secs}s`;
		return `💾 guardado hace ${Math.round(secs / 60)}min`;
	});

	async function flush() {
		if (saving || !isDirty()) return;
		saving = true;
		try {
			await onSave();
			lastSavedAt.value = Date.now();
			saveFailed.value = false;
			lastError.value = null;
		} catch (err) {
			saveFailed.value = true;
			lastError.value = err;
			console.error('[useAutosave] Fallo al guardar:', err);
		} finally {
			saving = false;
		}
	}

	function start() {
		if (saveTimer) return;
		saveTimer = setInterval(flush, intervalMs);
		tickTimer = setInterval(() => { now.value = Date.now(); }, 1000);
	}

	function stop() {
		if (saveTimer) { clearInterval(saveTimer); saveTimer = null; }
		if (tickTimer) { clearInterval(tickTimer); tickTimer = null; }
	}

	return { start, stop, flush, lastSavedAt, savedAgoText, saveFailed, lastError };
}
