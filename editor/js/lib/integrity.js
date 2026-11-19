// lib/integrity.js
// ─────────────────────────────────────────────────────────────────────────────
// Heurística GENÉRICA y barata para el badge amarillo "⚡ Incompleto" en
// EntityListPanel.js (Task 5, 1.2). No conoce el esquema de cada colección:
// solo mira nombres de campo habituales y avisa si EXISTEN pero están vacíos o
// a cero. Se ejecuta de forma síncrona por fila (sin tocar disco), a diferencia
// del badge rojo "⚠️ Error" que sí requiere el validador completo (ver
// lib/qaIndex.js) porque cruza referencias entre colecciones.
// ─────────────────────────────────────────────────────────────────────────────
const IMAGE_FIELDS = ['sprite', 'avatar', 'icon', 'image', 'img', 'portrait', 'bg', 'background', 'model'];
const DESC_FIELDS = ['desc', 'description'];
const ZERO_RISK_FIELDS = ['atk', 'def', 'hp', 'mp', 'price', 'sell_price', 'buy_price', 'value', 'damage', 'power'];

function isEmptyText(v) {
	if (v == null) return true;
	if (typeof v === 'string') return v.trim() === '';
	if (typeof v === 'object') return !v.es && !v.en; // texto bilingüe { es, en }
	return false;
}

/**
 * Devuelve un mensaje de aviso si la entidad parece incompleta, o null si no
 * hay nada reseñable. Solo avisa de un campo si EXISTE como clave en el objeto
 * (para no marcar como incompletas entidades cuyo esquema no usa ese campo).
 */
export function assessIncomplete(o) {
	if (!o || typeof o !== 'object') return null;
	for (const f of IMAGE_FIELDS) {
		if (f in o && isEmptyText(o[f])) return 'Sin imagen asignada (campo "' + f + '")';
	}
	for (const f of DESC_FIELDS) {
		if (f in o && isEmptyText(o[f])) return 'Sin descripción localizada (campo "' + f + '")';
	}
	for (const f of ZERO_RISK_FIELDS) {
		if (f in o && o[f] === 0) return 'Valor "' + f + '" en cero';
	}
	return null;
}
