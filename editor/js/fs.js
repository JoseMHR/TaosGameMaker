// fs.js
// ─────────────────────────────────────────────────────────────────────────────
// Capa de acceso a datos vía el API HTTP del servidor de desarrollo (serve.py).
// Sustituye a la File System Access API del navegador (que suele estar bloqueada
// por política corporativa): NO hay selector de carpeta; el servidor ya conoce la
// raíz del proyecto (autodetectada) y expone /api para leer/escribir los JSON y
// servir los assets. Se conservan las firmas usadas por el resto de la app.
// ─────────────────────────────────────────────────────────────────────────────

// El servidor siempre está "soportado" (solo requiere fetch, universal).
export const isSupported = true;

const API = '/api';

// Estado de conexión con el servidor.
const state = {
	connected: false,
	name: '',
	hasAssets: false,
};

// Índices de nombres de assets por carpeta ('bg'|'npc'|'enemy'|'item'|…), cacheados.
const assetIndex = { bg: null, npc: null, enemy: null, item: null, terrain: null, world_model: null, dungeon_model: null, combat_model: null, common_model: null, model: null };

/** ¿Se ha establecido conexión con el servidor y hay datos? */
export function hasProject() {
	return state.connected;
}

/** Nombre de la carpeta raíz del proyecto (según el servidor). */
export function projectName() {
	return state.name;
}

/** ¿Hay carpetas de assets disponibles para previsualizar? */
export function hasAssets() {
	return state.hasAssets;
}

/**
 * "Abre" el proyecto: consulta /api/info. No pide carpeta (el servidor ya sabe
 * la ruta). Lanza un Error legible si el servidor no responde o falta data.
 */
export async function openProject() {
	let info;
	try {
		const res = await fetch(`${API}/info`, { cache: 'no-store' });
		if (!res.ok) throw new Error('HTTP ' + res.status);
		info = await res.json();
	} catch (e) {
		throw new Error('No se pudo contactar con el servidor del editor. Arráncalo con `python serve.py` en editor y recarga la página.');
	}
	if (!info.hasData) {
		throw new Error('El servidor no encuentra la carpeta `data` en ' + (info.root || 'la raíz') + '. ¿Está serve.py dentro de editor?');
	}
	state.connected = true;
	state.name = info.name || 'proyecto';
	state.hasAssets = !!info.hasAssets;
	// Reset de cachés de assets.
	assetIndex.bg = null;
	assetIndex.npc = null;
	return { name: state.name, hasAssets: state.hasAssets };
}

/** Lee y parsea un JSON de la carpeta `data`. Devuelve null si no existe. */
export async function readJson(name) {
	const res = await fetch(`${API}/data/${name}`, { cache: 'no-store' });
	if (res.status === 404) return null;
	if (!res.ok) {
		let msg = 'HTTP ' + res.status;
		try { msg = (await res.json()).error || msg; } catch (_) {}
		throw new Error(`Error leyendo ${name}: ${msg}`);
	}
	const text = await res.text();
	if (text.trim() === '') return null;
	return JSON.parse(text);
}

/**
 * Escribe un objeto como JSON. El servidor lo guarda con indentación de 4
 * espacios y UTF-8 (mismo formato que build_design.py / que Godot carga bien).
 */
export async function writeJson(name, obj) {
	const res = await fetch(`${API}/data/${name}`, {
		method: 'PUT',
		headers: { 'Content-Type': 'application/json' },
		body: JSON.stringify(obj),
	});
	if (!res.ok) {
		let msg = 'HTTP ' + res.status;
		try { msg = (await res.json()).error || msg; } catch (_) {}
		throw new Error(`Error guardando ${name}: ${msg}`);
	}
	return res.json();
}

/**
 * COLECCIONES "un fichero por id" (data/<name>/<id>.json), p. ej. `dungeons`.
 * Alternativa a readJson/writeJson para catálogos que crecerían sin límite en
 * un solo JSON: cada elemento vive en su propio fichero y se lee/escribe por
 * separado, así que editar UNO no exige transferir la colección entera.
 */

/**
 * Listado LIGERO de una colección: { id: {name?, boss?, floors?, ...} }. Cada
 * entrada es solo un resumen (lo que el servidor extrae sin mandar el
 * contenido completo) — suficiente para poblar un desplegable/lista.
 */
export async function listCollection(name) {
	const res = await fetch(`${API}/collection/${name}`, { cache: 'no-store' });
	if (!res.ok) {
		let msg = 'HTTP ' + res.status;
		try { msg = (await res.json()).error || msg; } catch (_) {}
		throw new Error(`Error listando colección ${name}: ${msg}`);
	}
	return res.json();
}

/** Lee el contenido COMPLETO de un elemento de la colección (o null si no existe). */
export async function readCollectionItem(name, id) {
	const res = await fetch(`${API}/collection/${name}/${encodeURIComponent(id)}`, { cache: 'no-store' });
	if (res.status === 404) return null;
	if (!res.ok) {
		let msg = 'HTTP ' + res.status;
		try { msg = (await res.json()).error || msg; } catch (_) {}
		throw new Error(`Error leyendo ${name}/${id}: ${msg}`);
	}
	return res.json();
}

/** Escribe (crea o sobrescribe) UN elemento de la colección. */
export async function writeCollectionItem(name, id, obj) {
	const res = await fetch(`${API}/collection/${name}/${encodeURIComponent(id)}`, {
		method: 'PUT',
		headers: { 'Content-Type': 'application/json' },
		body: JSON.stringify(obj),
	});
	if (!res.ok) {
		let msg = 'HTTP ' + res.status;
		try { msg = (await res.json()).error || msg; } catch (_) {}
		throw new Error(`Error guardando ${name}/${id}: ${msg}`);
	}
	return res.json();
}

/** Borra UN elemento de la colección. */
export async function deleteCollectionItem(name, id) {
	const res = await fetch(`${API}/collection/${name}/${encodeURIComponent(id)}`, { method: 'DELETE' });
	if (!res.ok) {
		let msg = 'HTTP ' + res.status;
		try { msg = (await res.json()).error || msg; } catch (_) {}
		throw new Error(`Error borrando ${name}/${id}: ${msg}`);
	}
	return res.json();
}

/** Lista de nombres de fichero disponibles en una carpeta de assets ('bg'|'npc'|'dungeon_tex'|'model'|…). */
export async function listAssets(kind) {
	// `== null` (no `=== null`) para cubrir kinds NO preinicializados en assetIndex
	// (p. ej. 'dungeon_tex', 'model'): la primera consulta era `undefined` y se
	// saltaba el fetch dejando la lista siempre vacía. Ahora se piden bien.
	if (assetIndex[kind] == null) {
		try {
			const res = await fetch(`${API}/assets/${kind}/list`, { cache: 'no-store' });
			assetIndex[kind] = res.ok ? await res.json() : [];
		} catch (_) {
			assetIndex[kind] = [];
		}
	}
	return assetIndex[kind] || [];
}

/**
 * URL servible de un asset concreto (por nombre exacto de fichero). El servidor
 * entrega la imagen directamente, así que basta con construir la ruta.
 */
export function assetUrl(kind, fileName) {
	return `${API}/assets/${kind}/${encodeURIComponent(fileName)}`;
}

/**
 * Busca el PRIMER asset cuyo nombre (con o sin extensión) coincida con alguno de
 * los candidatos. Devuelve {url, name} o null. Útil porque los fondos usan
 * nombres como `bg_building_<npc>.jpg`.
 */
export async function findAssetUrl(kind, candidates) {
	const names = await listAssets(kind);
	if (!names.length) return null;
	const lower = names.map(n => ({ raw: n, low: n.toLowerCase() }));
	for (const cand of candidates) {
		const c = cand.toLowerCase();
		const hit = lower.find(n =>
			n.low === c ||
			n.low.replace(/\.(png|jpg|jpeg|webp|gif)$/, '') === c);
		if (hit) return { url: assetUrl(kind, hit.raw), name: hit.raw };
	}
	return null;
}

/**
 * Sube un asset nuevo (p. ej. una textura de terreno PNG) a una carpeta de
 * assets. `data` es un ArrayBuffer/Blob con el contenido del fichero. Invalida
 * la caché de `listAssets(kind)` para que el siguiente listado lo incluya.
 */
export async function uploadAsset(kind, fileName, data, contentType = 'image/png') {
	const res = await fetch(`${API}/assets/${kind}/${encodeURIComponent(fileName)}`, {
		method: 'POST',
		headers: { 'Content-Type': contentType },
		body: data,
	});
	if (!res.ok) {
		let msg = 'HTTP ' + res.status;
		try { msg = (await res.json()).error || msg; } catch (_) {}
		throw new Error(`Error subiendo ${fileName}: ${msg}`);
	}
	assetIndex[kind] = null;
	return res.json();
}

/**
 * Procesa una imagen YA SUBIDA en el servidor (Task 5, Fase 3): ejecuta
 * `tools/process_image.py` IN-PLACE sobre `assets/<kind>/<fileName>` — convierte
 * a PNG de 32 bits y, si `type` es 'sprite', elimina el fondo. Ver MediaLibrary.js.
 */
export async function processImage(kind, fileName, type = 'auto') {
	const res = await fetch(`${API}/process_image`, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json' },
		body: JSON.stringify({ kind, file: fileName, type }),
	});
	if (!res.ok) {
		let msg = 'HTTP ' + res.status;
		try { msg = (await res.json()).error || msg; } catch (_) {}
		throw new Error(`Error procesando ${fileName}: ${msg}`);
	}
	assetIndex[kind] = null;
	return res.json();
}

/** Borra un asset de una carpeta de assets. Invalida la caché de `listAssets(kind)`. */
export async function deleteAsset(kind, fileName) {
	const res = await fetch(`${API}/assets/${kind}/${encodeURIComponent(fileName)}`, { method: 'DELETE' });
	if (!res.ok) {
		let msg = 'HTTP ' + res.status;
		try { msg = (await res.json()).error || msg; } catch (_) {}
		throw new Error(`Error borrando ${fileName}: ${msg}`);
	}
	assetIndex[kind] = null;
	return res.json();
}
