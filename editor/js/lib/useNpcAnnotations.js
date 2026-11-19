// lib/useNpcAnnotations.js
// ─────────────────────────────────────────────────────────────────────────────
// ANOTACIONES DE DIÁLOGO. Metadatos de AUTORÍA para el grafo de
// un NPC: colores personalizados por nodo, comentarios, marcadores (bookmarks) y
// grupos con nombre/color. Se guardan dentro del propio NPC en `_meta.editor`, un
// bloque que el motor IGNORA con seguridad (Design.gd solo lee `_meta.text` y
// `_meta.reward`), por lo que es 100% retrocompatible con npcs.json.
//
// Estructura:
//   _meta.editor = {
//     colors:   { [nodeId]: '#hex' },
//     comments: { [nodeId]: 'texto' },
//     bookmarks:[ nodeId, … ],
//     groups:   [ { id, name, color } ],
//     groupOf:  { [nodeId]: groupId },
//   }
// ─────────────────────────────────────────────────────────────────────────────

/** Devuelve (creando si hace falta) el bloque `_meta.editor` de un NPC. */
export function ensureEditor(npcData) {
	if (!npcData) return null;
	if (!npcData._meta) npcData._meta = { type: 'meta', text: { es: '', en: '' }, next: [], reward: '' };
	const m = npcData._meta;
	if (!m.editor) m.editor = {};
	const e = m.editor;
	if (!e.colors) e.colors = {};
	if (!e.comments) e.comments = {};
	if (!Array.isArray(e.bookmarks)) e.bookmarks = [];
	if (!Array.isArray(e.groups)) e.groups = [];
	if (!e.groupOf) e.groupOf = {};
	return e;
}

/** Lectura tolerante (sin crear estructura) del bloque editor. */
function readEditor(npcData) {
	return (npcData && npcData._meta && npcData._meta.editor) ? npcData._meta.editor : null;
}

// ── Colores ──────────────────────────────────────────────────────────────────
export function getColor(npcData, id) { const e = readEditor(npcData); return (e && e.colors[id]) || ''; }
export function setColor(npcData, id, hex) {
	const e = ensureEditor(npcData);
	if (hex) e.colors[id] = hex; else delete e.colors[id];
}

// ── Comentarios ──────────────────────────────────────────────────────────────
export function getComment(npcData, id) { const e = readEditor(npcData); return (e && e.comments[id]) || ''; }
export function setComment(npcData, id, text) {
	const e = ensureEditor(npcData);
	if (text && text.trim()) e.comments[id] = text; else delete e.comments[id];
}

// ── Marcadores (bookmarks) ───────────────────────────────────────────────────
export function isBookmarked(npcData, id) { const e = readEditor(npcData); return !!(e && e.bookmarks.includes(id)); }
export function toggleBookmark(npcData, id) {
	const e = ensureEditor(npcData);
	const i = e.bookmarks.indexOf(id);
	if (i >= 0) e.bookmarks.splice(i, 1); else e.bookmarks.push(id);
}
export function bookmarks(npcData) { const e = readEditor(npcData); return e ? e.bookmarks.slice() : []; }

// ── Grupos ───────────────────────────────────────────────────────────────────
export function groups(npcData) { const e = readEditor(npcData); return e ? e.groups.slice() : []; }
export function groupOf(npcData, id) {
	const e = readEditor(npcData);
	if (!e) return null;
	const gid = e.groupOf[id];
	return gid ? (e.groups.find(g => g.id === gid) || null) : null;
}
export function createGroup(npcData, name, color) {
	const e = ensureEditor(npcData);
	const id = 'g_' + Date.now().toString(36);
	const g = { id, name: name || 'Grupo', color: color || '#6c8cff' };
	e.groups.push(g);
	return g;
}
export function setNodeGroup(npcData, id, groupId) {
	const e = ensureEditor(npcData);
	if (groupId) e.groupOf[id] = groupId; else delete e.groupOf[id];
}
export function renameGroup(npcData, groupId, name) {
	const e = ensureEditor(npcData);
	const g = e.groups.find(x => x.id === groupId); if (g) g.name = name;
}
export function setGroupColor(npcData, groupId, color) {
	const e = ensureEditor(npcData);
	const g = e.groups.find(x => x.id === groupId); if (g) g.color = color;
}
export function removeGroup(npcData, groupId) {
	const e = ensureEditor(npcData);
	e.groups = e.groups.filter(g => g.id !== groupId);
	for (const nid of Object.keys(e.groupOf)) if (e.groupOf[nid] === groupId) delete e.groupOf[nid];
}
