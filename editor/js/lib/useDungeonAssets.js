// lib/useDungeonAssets.js
// ─────────────────────────────────────────────────────────────────────────────
// BIBLIOTECA DE ASSETS DE MAZMORRA. Un "asset" es una casilla
// ya CONFIGURADA (tipo + propiedades: textura, altura, color, referencias…) que
// se guarda con un nombre para REUTILIZARLA como sello del pincel. Evita tener
// que reconfigurar a mano cada antorcha, cofre, pared alta, puerta cerrada, etc.
//
// Hay dos orígenes:
//   · BUILTIN — presets de fábrica (constantes aquí).
//   · USER    — presets creados por el diseñador, persistidos en localStorage.
//
// Cada asset: { id, name, icon, builtin?, cell }  (cell = objeto de casilla).
// ─────────────────────────────────────────────────────────────────────────────
import { ref } from 'https://unpkg.com/vue@3/dist/vue.esm-browser.prod.js';

const LS_KEY = 'mw_dun_assets';

// Presets de fábrica CURADOS. `cell` es exactamente lo que se estampa en la
// rejilla. Se eligen para que TODOS se vean bien en el motor sin depender de
// texturas aún no implementadas: varían tipo + tinte de color + luz + altura,
// que GridDungeonStage.gd ya renderiza con calidad. Objetivo:
// "kit de arranque" mínimo y bonito para montar una mazmorra decente sin nada más.
export const BUILTIN_ASSETS = [
	// ── Estructura ──
	{ id: 'wall_stone_high', name: 'Muro de piedra (alto)', icon: '🧱', cell: { t: 'wall', wall: 'stone', h: 4 } },
	{ id: 'wall_cave', name: 'Muro de cueva', icon: '🪨', cell: { t: 'wall', wall: 'cave', color: '#5a4636' } },
	{ id: 'wall_low', name: 'Murete (medio)', icon: '🧱', cell: { t: 'wall', h: 1.4, color: '#6b5040' } },
	{ id: 'floor_stone', name: 'Suelo de piedra', icon: '⬛', cell: { t: 'floor', tex: 'stone' } },
	// ── Luz y ambiente ──
	{ id: 'torch_wall', name: 'Antorcha de pared', icon: '🔦', cell: { t: 'torch', color: '#e6a23a' } },
	{ id: 'crystal_blue', name: 'Cristal mágico (azul)', icon: '💎', cell: { t: 'crystal', color: '#4aa3ff', light: 2 } },
	// ── Decoración activa ──
	{ id: 'armario_libreria', name: 'Armario alto (librería)', icon: '📚', cell: { t: 'armario_libreria', wall_snap: true } },
	{ id: 'barril_manzanas', name: 'Barril de manzanas', icon: '🍎', cell: { t: 'barril_manzanas' } },
	{ id: 'cama', name: 'Cama', icon: '🛏️', cell: { t: 'cama', wall_snap: true } },
	{ id: 'hojas_pared', name: 'Hojas / Enredadera de pared', icon: '🌿', cell: { t: 'hojas_pared', wall_snap: true } },
	// ── Peligros ──
	{ id: 'lava_deep', name: 'Lava profunda', icon: '🌋', cell: { t: 'lava', light: 1.5, color: '#e0521a' } },
	{ id: 'spikes_trap', name: 'Trampa de pinchos', icon: '🔺', cell: { t: 'spikes' } },
	// ── Tesoro y accesos ──
	{ id: 'chest_gold', name: 'Cofre con oro', icon: '🧰', cell: { t: 'chest', gold: 100 } },
	{ id: 'door_closed', name: 'Puerta cerrada', icon: '🚪', cell: { t: 'door', state: 'closed' } },
];

function readUser() {
	try { const v = JSON.parse(localStorage.getItem(LS_KEY)); return Array.isArray(v) ? v : []; }
	catch (e) { return []; }
}
function writeUser(list) {
	try { localStorage.setItem(LS_KEY, JSON.stringify(list)); } catch (e) { /* almacenamiento no disponible */ }
}

/**
 * Composable de la biblioteca de assets. Expone la lista reactiva y las acciones
 * de crear/borrar/renombrar presets de usuario.
 */
export function useDungeonAssets() {
	const user = ref(readUser());

	function _persist() { writeUser(user.value); }

	/** Crea un asset de usuario a partir de una casilla (se clona, sin datos vacíos). */
	function saveFromCell(name, cell, icon) {
		const clean = {};
		for (const k in cell) {
			const v = cell[k];
			if (v === '' || v == null || v === false) continue;
			clean[k] = (typeof v === 'object') ? JSON.parse(JSON.stringify(v)) : v;
		}
		const id = 'u_' + Date.now().toString(36);
		const asset = { id, name: name || 'Asset', icon: icon || '⭐', cell: clean };
		user.value = [asset, ...user.value];
		_persist();
		return asset;
	}
	function remove(id) { user.value = user.value.filter(a => a.id !== id); _persist(); }
	function rename(id, name) {
		user.value = user.value.map(a => a.id === id ? { ...a, name } : a);
		_persist();
	}

	return { builtin: BUILTIN_ASSETS, user, saveFromCell, remove, rename };
}
