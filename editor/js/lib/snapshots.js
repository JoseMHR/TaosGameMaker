// lib/snapshots.js
// ─────────────────────────────────────────────────────────────────────────────
// Composable REUTILIZABLE de "snapshots" (puntos de restauración) de un estado
// serializable. Persiste en localStorage del navegador y permite exportar/
// importar cada snapshot como fichero .json. Es agnóstico al dominio: el
// llamante indica cómo leer/escribir el estado. Reutilizable por cualquier
// editor del backoffice (mundo, mazmorras, etc.) — base de las Tareas 4 y 5.
//
//   const snaps = useSnapshots({
//     storageKey: 'mw_snap_world', label: 'Mundo',
//     getState: () => store.world,
//     setState: (data) => applyWorld(data),
//   });
// ─────────────────────────────────────────────────────────────────────────────
import { ref } from 'https://unpkg.com/vue@3/dist/vue.esm-browser.prod.js';
import { deepClone } from './useHistory.js';

const MAGIC = 'magicworld.snapshot';

export function useSnapshots(opts) {
	const storageKey = opts.storageKey;
	const label = opts.label || 'Estado';
	const getState = opts.getState;
	const setState = opts.setState;

	const snapshots = ref(loadList());

	function loadList() {
		try { return JSON.parse(localStorage.getItem(storageKey) || '[]'); }
		catch (_) { return []; }
	}
	function persist() {
		try { localStorage.setItem(storageKey, JSON.stringify(snapshots.value)); }
		catch (e) { console.warn('No se pudo persistir snapshots:', e); }
	}

	/** Crea un snapshot del estado actual y lo guarda al principio de la lista. */
	function create(name) {
		const snap = {
			id: 'snap_' + Date.now().toString(36),
			name: (name || '').trim() || (label + ' ' + new Date().toLocaleString()),
			ts: Date.now(),
			data: deepClone(getState()),
		};
		snapshots.value.unshift(snap);
		persist();
		return snap;
	}

	/** Restaura un snapshot por id (aplica una copia profunda al estado). */
	function restore(id) {
		const s = snapshots.value.find(x => x.id === id);
		if (!s) return false;
		setState(deepClone(s.data));
		return true;
	}

	function remove(id) { snapshots.value = snapshots.value.filter(x => x.id !== id); persist(); }
	function rename(id, name) { const s = snapshots.value.find(x => x.id === id); if (s) { s.name = name; persist(); } }

	/** Descarga un snapshot como fichero .json (portátil entre máquinas). */
	function exportSnapshot(id) {
		const s = snapshots.value.find(x => x.id === id);
		if (!s) return;
		const payload = { _format: MAGIC, label, name: s.name, ts: s.ts, data: s.data };
		const blob = new Blob([JSON.stringify(payload, null, 2)], { type: 'application/json' });
		const url = URL.createObjectURL(blob);
		const a = document.createElement('a');
		a.href = url;
		a.download = (s.name.replace(/[^\w\-]+/g, '_') || 'snapshot') + '.json';
		document.body.appendChild(a); a.click(); a.remove();
		setTimeout(() => URL.revokeObjectURL(url), 1000);
	}

	/** Importa un snapshot desde un fichero (File). Devuelve una promesa. */
	function importFromFile(file) {
		return new Promise((resolve, reject) => {
			const reader = new FileReader();
			reader.onload = () => {
				try {
					const obj = JSON.parse(reader.result);
					const data = obj && obj._format === MAGIC ? obj.data : obj;
					if (data == null) throw new Error('Fichero de snapshot vacío o inválido.');
					const snap = {
						id: 'snap_' + Date.now().toString(36),
						name: (obj && obj.name) || (file.name.replace(/\.json$/i, '')) || 'Importado',
						ts: Date.now(),
						data,
					};
					snapshots.value.unshift(snap);
					persist();
					resolve(snap);
				} catch (e) { reject(e); }
			};
			reader.onerror = () => reject(reader.error);
			reader.readAsText(file);
		});
	}

	return { snapshots, create, restore, remove, rename, exportSnapshot, importFromFile };
}
