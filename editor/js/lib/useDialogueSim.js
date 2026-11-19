// lib/useDialogueSim.js
// ─────────────────────────────────────────────────────────────────────────────
// SIMULACIÓN DE DIÁLOGO. Reproduce en el editor —lo más fielmente
// posible— la EVALUACIÓN DE CONDICIONES y la APLICACIÓN DE RECOMPENSAS que hace
// el motor (`Design.gd`: eval_condition + _apply_token), sobre un ESTADO SIMULADO
// editable (oro, facetas, relación, visitas, flags, inventario, quest_state).
//
// No toca datos del juego: opera sobre un objeto de estado en memoria propiedad
// del componente. Es un "gemelo" del runtime para que el diseñador pruebe ramas.
//
// Limitaciones honestas: las condiciones son `Expression` de Godot; aquí se
// traducen los operadores (and/or/not) a JS y se evalúan en un sandbox. Si una
// condición usa algo no soportado, se marca como 'unknown' (no se adivina).
// ─────────────────────────────────────────────────────────────────────────────

/** Estado simulado por defecto (equivalente a un jugador recién llegado). */
export function defaultSimState() {
	return {
		quest: '',
		gold: 100,
		xp: 0,
		visits: 1,
		relation: 0,
		facetas: { valor: 0, bondad: 0, aspecto: 0, inteligencia: 0, cordura: 0 },
		flags: {},        // flags del NPC actual:  { nombre: true }
		worldFlags: {},   // flags globales de historia
		items: {},        // inventario: { id: cantidad }
	};
}

// ── Evaluación de condiciones ────────────────────────────────────────────────
// Traduce operadores GDScript a JS. Best-effort; el resto es JS válido.
function toJsExpr(cond) {
	return String(cond)
		.replace(/\band\b/g, '&&')
		.replace(/\bor\b/g, '||')
		.replace(/\bnot\b/g, '!');
}

/**
 * Evalúa una condición contra el estado simulado.
 * @returns {'pass'|'fail'|'unknown'}
 */
export function evalCondition(cond, st) {
	const c = (cond || '').trim();
	if (!c) return 'pass';
	try {
		const facets = st.facetas || {};
		// Variables expuestas (mismas que _COND_VARS del motor + facetas por nombre).
		const vars = {
			quest: st.quest || '',
			gold: st.gold | 0,
			relation: st.relation | 0,
			visits: st.visits | 0,
			valor: (facets.valor !== undefined ? facets.valor : facets.valentia) | 0,
			bondad: (facets.bondad !== undefined ? facets.bondad : facets.amabilidad) | 0,
			aspecto: (facets.aspecto !== undefined ? facets.aspecto : facets.encanto) | 0,
			inteligencia: (facets.inteligencia !== undefined ? facets.inteligencia : facets.astucia) | 0,
			cordura: facets.cordura | 0,
			valentia: (facets.valor !== undefined ? facets.valor : facets.valentia) | 0,
			amabilidad: (facets.bondad !== undefined ? facets.bondad : facets.amabilidad) | 0,
			encanto: (facets.aspecto !== undefined ? facets.aspecto : facets.encanto) | 0,
			astucia: (facets.inteligencia !== undefined ? facets.inteligencia : facets.astucia) | 0,
		};
		// Funciones invocables (equivalentes a Design.gd).
		const fns = {
			has_item: (id, n = 1) => (st.items[id] || 0) >= n,
			no_item: (id, n = 1) => (st.items[id] || 0) < n,
			has_flag: (f) => !!st.flags[f],
			no_flag: (f) => !st.flags[f],
			gflag: (f) => !!st.worldFlags[f],
			gate_flag: (f) => !!st.worldFlags[f],
			stat: (k) => (k === 'gold' ? (st.gold | 0) : (k === 'xp' ? (st.xp | 0) : 0)),
		};
		const argNames = [...Object.keys(vars), ...Object.keys(fns)];
		const argVals = [...Object.values(vars), ...Object.values(fns)];
		// eslint-disable-next-line no-new-func
		const fn = new Function(...argNames, 'return (' + toJsExpr(c) + ');');
		return fn(...argVals) ? 'pass' : 'fail';
	} catch (e) {
		return 'unknown';
	}
}

// ── Aplicación de recompensas ────────────────────────────────────────────────
function pint(v) { const n = parseInt(String(v).replace('+', ''), 10); return isNaN(n) ? 0 : n; }
function clampi(v, lo, hi) { return Math.max(lo, Math.min(hi, v)); }

/**
 * Aplica un `reward` (mini-lenguaje) al estado simulado y devuelve un registro
 * legible de cada efecto. Los tokens con efectos externos (combate, evento,
 * cinemática…) se registran como "acción" sin simular su interior.
 * @returns {Array<{ icon, text }>}
 */
export function applyReward(reward, st) {
	const log = [];
	const r = (reward || '').trim();
	if (!r) return log;
	for (const raw of r.split(';')) {
		const tok = raw.trim();
		if (!tok) continue;
		// Ignora metadatos del nodo _meta (avatar/bg) que no son efectos de juego.
		if (tok.startsWith('avatar=') || tok.startsWith('bg=')) continue;

		if (tok.startsWith('-item:')) {
			const [id, n] = tok.substr(6).split('=');
			const q = n ? pint(n) : 1;
			st.items[id] = Math.max(0, (st.items[id] || 0) - q);
			if (!st.items[id]) delete st.items[id];
			log.push({ icon: '📤', text: `Quita objeto ${id} ×${q}` });
			continue;
		}
		const colon = tok.indexOf(':');
		const key = colon === -1 ? tok : tok.substr(0, colon);
		const val = colon === -1 ? '' : tok.substr(colon + 1);
		switch (key) {
			case 'gold': { const d = pint(val); st.gold = Math.max(0, st.gold + d); log.push({ icon: '🪙', text: `Oro ${d >= 0 ? '+' : ''}${d} → ${st.gold}` }); break; }
			case 'xp': { const d = pint(val); st.xp += d; log.push({ icon: '⭐', text: `XP +${d} → ${st.xp}` }); break; }
			case 'heal': log.push({ icon: '❤️', text: 'Curación total (HP/MP al máximo)' }); break;
			case 'faceta': {
				const [fk, fv] = val.split('=');
				if (fk && fv !== undefined) {
					st.facetas[fk] = clampi((st.facetas[fk] | 0) + pint(fv), -10, 10);
					log.push({ icon: '🎭', text: `Faceta ${fk} ${pint(fv) >= 0 ? '+' : ''}${pint(fv)} → ${st.facetas[fk]}` });
				}
				break;
			}
			case 'item': { const [id, n] = val.split('='); const q = n ? pint(n) : 1; st.items[id] = (st.items[id] || 0) + q; log.push({ icon: '📥', text: `Da objeto ${id} ×${q} → ${st.items[id]}` }); break; }
			case 'flag': st.flags[val] = true; log.push({ icon: '🚩', text: `Marca flag NPC "${val}"` }); break;
			case 'relation': { const d = pint(val); st.relation += d; log.push({ icon: '💗', text: `Relación ${d >= 0 ? '+' : ''}${d} → ${st.relation}` }); break; }
			case 'quests': st.quest = val; log.push({ icon: '📜', text: `Estado de misión = "${val}"` }); break;
			case 'questf': log.push({ icon: '📜', text: `Avanza misión (questf:${val})` }); break;
			case 'prof': log.push({ icon: '🎓', text: `Profesión → ${val}` }); break;
			case 'gflag': {
				const [gk, gv] = val.split('=');
				const on = gv === undefined ? true : pint(gv) !== 0;
				st.worldFlags[gk] = on;
				log.push({ icon: '🌐', text: `Flag global "${gk}" ${on ? 'ON' : 'OFF'}` });
				break;
			}
			case 'dam': st.worldFlags['dam_opened'] = true; log.push({ icon: '🌊', text: 'Abre la presa (dam)' }); break;
			case 'worldt': log.push({ icon: '🌍', text: `Transformación de mundo: ${val}` }); break;
			case 'qaction': log.push({ icon: '🧩', text: `Acción de misión: ${val}` }); break;
			case 'loot': log.push({ icon: '🎁', text: `Concede tabla de botín: ${val}` }); break;
			case 'combat': log.push({ icon: '⚔️', text: `Combate: ${val}` }); break;
			case 'event': log.push({ icon: '🔗', text: `Ejecuta evento: ${val}` }); break;
			case 'dialogue': log.push({ icon: '🗨️', text: `Muestra diálogo: ${val}` }); break;
			case 'cine': log.push({ icon: '🎬', text: `Lanza cinemática: ${val}` }); break;
			default: log.push({ icon: '❔', text: `Token desconocido: ${tok}` });
		}
	}
	return log;
}

/** Resumen corto de un reward para mostrar como etiqueta (sin aplicar nada). */
export function summarizeReward(reward) {
	const r = (reward || '').trim();
	if (!r) return '';
	return r.split(';').map(s => s.trim()).filter(s => s && !s.startsWith('avatar=') && !s.startsWith('bg=')).join(' · ');
}
