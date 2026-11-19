// lib/useClipboard.js
// ─────────────────────────────────────────────────────────────────────────────
// PORTAPAPELES INTERNO COMPARTIDO entre todos los editores del backoffice
// (Tarea 4). Es un único búfer a nivel de módulo (persistido en localStorage)
// para poder COPIAR una entidad en un editor y PEGARLA en otro del mismo "kind"
// (p. ej. copiar un enemigo y pegarlo como nuevo enemigo).
//
// Cada elemento copiado guarda su `kind` (enemy/item/ids/profession/npc/dungeon/
// dun_cell/…) para que un editor solo pueda pegar lo que le corresponde.
//
//   const clip = useClipboard();
//   clip.copy('enemy', enemyObj);
//   if (clip.canPaste('enemy')) { const data = clip.read('enemy'); ... }
// ─────────────────────────────────────────────────────────────────────────────
import { ref, computed } from 'https://unpkg.com/vue@3/dist/vue.esm-browser.prod.js';

const STORAGE_KEY = 'mw_editor_clipboard_v1';

function _load() {
	try { return JSON.parse(localStorage.getItem(STORAGE_KEY)) || null; }
	catch (_) { return null; }
}

// Estado ÚNICO a nivel de módulo (compartido por todas las instancias).
const _clip = ref(_load());

function _clone(obj) { return obj == null ? obj : JSON.parse(JSON.stringify(obj)); }

export function useClipboard() {
	/** Copia `data` etiquetado con `kind`. Persiste en localStorage. */
	function copy(kind, data) {
		_clip.value = { kind, data: _clone(data), ts: Date.now() };
		try { localStorage.setItem(STORAGE_KEY, JSON.stringify(_clip.value)); } catch (_) {}
	}

	/** ¿Hay algo copiado de este `kind` listo para pegar? */
	function canPaste(kind) {
		return !!_clip.value && _clip.value.kind === kind;
	}

	/** Devuelve una COPIA de lo almacenado para `kind` (o null). */
	function read(kind) {
		return canPaste(kind) ? _clone(_clip.value.data) : null;
	}

	/** Kind actualmente en el portapapeles ("" si está vacío). */
	const kind = computed(() => _clip.value ? _clip.value.kind : '');

	return { clip: _clip, kind, copy, canPaste, read };
}
