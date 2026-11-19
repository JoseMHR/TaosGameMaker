// lib/qaIndex.js
// ─────────────────────────────────────────────────────────────────────────────
// Índice de integridad en CACHÉ para los badges rojos "⚠️ Error" de
// EntityListPanel.js (Task 5, 1.2). Ejecuta el validador completo (sin tocar
// disco — `checkAssets:false`, para que sea barato) y agrupa los hallazgos por
// (tab, id de entidad). Se refresca en segundo plano con un temporizador y
// tras cada guardado; NUNCA en cada tecla (ver app.js).
// ─────────────────────────────────────────────────────────────────────────────
import { store } from '../store.js';
import { runValidation } from '../validator.js';

let refreshing = false;

/** Reejecuta el validador y reconstruye `store.qaIndex`. Idempotente/best-effort. */
export async function refreshQaIndex() {
	if (!store.loaded || refreshing) return;
	refreshing = true;
	try {
		const findings = await runValidation(store, { checkAssets: false });
		const idx = {};
		for (const f of findings) {
			const tab = f.ref && f.ref.tab;
			let target = f.ref && f.ref.target;
			// Algunos hallazgos (p. ej. diálogos de NPC) apuntan a { npc, node }
			// en vez de al id de la entidad directamente: se resuelve aquí al id
			// real de fila. Los que apuntan a coordenadas del mapa ({x,y}) no
			// tienen fila en ninguna EntityListPanel y se omiten (quedan en QaPanel).
			if (target && typeof target === 'object') target = target.npc || null;
			if (!tab || typeof target !== 'string') continue;
			idx[tab] = idx[tab] || {};
			const cur = idx[tab][target] || { level: 'warning', messages: [] };
			if (f.level === 'error') cur.level = 'error';
			cur.messages.push(f.message);
			idx[tab][target] = cur;
		}
		store.qaIndex = idx;
	} catch (e) {
		// El índice de badges es un extra informativo: nunca debe romper el editor.
	} finally {
		refreshing = false;
	}
}

let timer = null;
/** Arranca el refresco periódico en segundo plano (una vez cargado el proyecto). */
export function startQaIndexAutoRefresh(intervalMs = 15000) {
	stopQaIndexAutoRefresh();
	refreshQaIndex();
	timer = setInterval(refreshQaIndex, intervalMs);
}
export function stopQaIndexAutoRefresh() {
	if (timer) clearInterval(timer);
	timer = null;
}
