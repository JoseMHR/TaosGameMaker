// validator.js
// ─────────────────────────────────────────────────────────────────────────────
// Validador de integridad (QA). Ejecuta comprobaciones en caliente sobre los
// tres documentos en memoria y devuelve una lista de hallazgos con severidad:
//   'error'   -> rompe el juego (referencia inexistente, diálogo sin salida...)
//   'warning' -> conviene revisar (asset faltante...)
// Cada hallazgo: { level, code, message, ref? {tab, target} } para poder saltar.
// ─────────────────────────────────────────────────────────────────────────────
import { ensureDungeonLoaded, resourcesList } from './store.js';
import * as FS from './fs.js';

function isGenericObject(objId) {
	// Prefijos de recurso genérico placeable (data/world_resources/<code>.json)
	// admitidos como `object` del mapa sin estar en data/ids/.
	return resourcesList().some(r => r.placeable !== false && objId.startsWith(r.code));
}

/**
 * Ejecuta todas las comprobaciones. Las de assets son asíncronas (miran disco);
 * si `checkAssets` es false se omiten (p. ej. si no hay carpeta de assets).
 */
export async function runValidation(store, { checkAssets = true } = {}) {
	const out = [];
	const ids = store.ids || {};
	const npcs = store.npcs || {};
	const world = store.world;

	// Mazmorras: colección "un fichero por id" — `store.dungeons` solo trae el
	// RESUMEN ligero al abrir el proyecto (name/boss/floors:N, sin floors[] real).
	// Las comprobaciones de más abajo (boss, cofres, eids, actuadores...) SÍ
	// necesitan el contenido completo, así que se hidratan aquí todas de golpe
	// antes de validar (esta es la única pasada que necesita TODAS a la vez).
	await Promise.all(Object.keys(store.dungeons || {}).map(id => ensureDungeonLoaded(id)));

	// ── ÍNDICE DE COMPROBACIONES (para navegar estas ~900 líneas sin leerlas
	//    enteras; busca el marcador "// N." de la familia que te interese) ──────
	//   1.       Mapa: object→data/ids/ y terrain→data/world_terrains/
	//   2.       Ciudades: content→POI en data/ids/
	//   2b.      Gating: puertas/muros con dir válida y open_when presente
	//   3a.      NPC faltante: ids.npc→npcs.json
	//   3b + 4.  Diálogos: `next`→nodo inexistente y nodos sin salida
	//   6.       Ítems: helpers checkLootEntries / integridad de items.json
	//   6a.      Loot de enemigos (tabla o lista en línea)
	//   6a-bis.  Tablas de botín compartidas (loot.json)
	//   6b.      Ítems referenciados en condition/reward de diálogos
	//   7.       Eventos y quests (mini-lenguaje de acciones/condiciones)
	//   8.       Tiendas (shops.json)→items.json
	//   9.       Mazmorras: boss, cofres (items/loot) y layout
	//   9b.      Kits de Objeto Inteligente (dungeon_kits.json)
	//   10.      Logros (achievements.json): reward válido
	//   12.      Ambiente (ambience.json): music/weather definidos
	//   13.      Sinergias (synergies.json): required_ids/result_id→skills
	//   14.      Transformaciones de mundo (world_transforms.json)
	//   5.       Assets faltantes (async; se ejecuta AL FINAL, requiere disco)
	//   Helpers al final del fichero: itemRefsInNode, bgCandidates, codeTokensInMiniLang.
	//   NOTA (A7): partir esto en módulos por familia queda como mejora opcional;
	//   hoy comparten mucho contexto (ids/npcs/world/items/enemies/loot/…), así que
	//   este índice cubre la navegabilidad sin el riesgo de un refactor grande.
	// ────────────────────────────────────────────────────────────────────────────

	// 1. Referencias del mapa rotas: object que no existe en ids ni es genérico,
	// y terrain que no existe en data/world_terrains/ (colección data-driven).
	const worldTerrainsQa = store.worldTerrains || {};
	if (world && Array.isArray(world.tiles)) {
		for (let y = 0; y < world.tiles.length; y++) {
			const row = world.tiles[y] || [];
			for (let x = 0; x < row.length; x++) {
				const tile = row[x];
				if (!tile) continue;
				if (tile.object && !ids[tile.object] && !isGenericObject(tile.object)) {
					out.push({
						level: 'error', code: 'map-ref',
						message: `Casilla (${x},${y}) apunta a object "${tile.object}" que no existe en data/ids/.`,
						ref: { tab: 'map', target: { x, y } },
					});
				}
				if (tile.terrain && !worldTerrainsQa[tile.terrain]) {
					out.push({
						level: 'error', code: 'map-terrain',
						message: `Casilla (${x},${y}) usa terrain "${tile.terrain}" que no existe en data/world_terrains/.`,
						ref: { tab: 'map', target: { x, y } },
					});
				}
			}
		}
	}

	// 2. Estructura de ciudades rota: content -> POI inexistente en ids.
	for (const [id, obj] of Object.entries(ids)) {
		if (!Array.isArray(obj.content)) continue;
		for (const child of obj.content) {
			if (!ids[child]) {
				out.push({
					level: 'error', code: 'city-content',
					message: `"${id}" incluye en content el POI "${child}" que no existe en data/ids/.`,
					ref: { tab: 'ids', target: id },
				});
			}
		}
	}

	// 2b. PUERTAS/MUROS CONDICIONADOS (gating): dir válido y open_when presente.
	// Detecta el error de datos más común del gating: dirección mal escrita (el muro
	// no bloquearía nada) o falta de condición (el muro quedaría siempre abierto).
	const GATE_DIRS = ['north', 'south', 'east', 'west'];
	for (const [id, obj] of Object.entries(ids)) {
		if (!obj.gate || typeof obj.gate !== 'object') continue;
		const g = obj.gate;
		if (!GATE_DIRS.includes(g.dir)) {
			out.push({
				level: 'error', code: 'gate-dir',
				message: `"${id}" define gate.dir "${g.dir}" inválido (usa: ${GATE_DIRS.join('/')}).`,
				ref: { tab: 'ids', target: id },
			});
		}
		if (!g.open_when || !String(g.open_when).trim()) {
			out.push({
				level: 'warning', code: 'gate-open',
				message: `"${id}" tiene gate sin "open_when": el muro quedaría SIEMPRE abierto (¿falta la condición?).`,
				ref: { tab: 'ids', target: id },
			});
		}
	}

	// 3a. NPC faltante: entidad con `npc` que no existe en npcs.json.
	for (const [id, obj] of Object.entries(ids)) {
		if (obj.npc && !npcs[obj.npc]) {
			out.push({
				level: 'error', code: 'npc-missing',
				message: `"${id}" referencia el NPC "${obj.npc}" que no existe en npcs.json.`,
				ref: { tab: 'ids', target: id },
			});
		}
	}

	// 3b + 4. Dentro de cada NPC: next a nodos inexistentes y diálogos sin salida.
	for (const [npcId, nodes] of Object.entries(npcs)) {
		const nodeIds = new Set(Object.keys(nodes));
		for (const [nodeId, node] of Object.entries(nodes)) {
			if (nodeId === '_meta') continue; // el nodo meta no es navegable
			const next = Array.isArray(node.next) ? node.next : [];
			// next roto
			for (const target of next) {
				if (target === 'close') continue;
				if (!nodeIds.has(target)) {
					out.push({
						level: 'error', code: 'next-broken',
						message: `NPC "${npcId}", nodo "${nodeId}" enlaza a "${target}" que no existe.`,
						ref: { tab: 'npcs', target: { npc: npcId, node: nodeId } },
					});
				}
			}
			// diálogo muerto: sin next y sin "close"
			if (next.length === 0) {
				out.push({
					level: 'error', code: 'dead-end',
					message: `NPC "${npcId}", nodo "${nodeId}" no tiene next ni "close": congelaría el diálogo.`,
					ref: { tab: 'npcs', target: { npc: npcId, node: nodeId } },
				});
			}
		}
	}

	// 6. Integridad referencial de ÍTEMS (items.json).
	const items = store.items || {};
	const enemies = store.enemies || {};
	const dialogues = store.dialogues || {};
	const scenesForCine = store.scenes || {};
	const hasItem = (id) => !!items[id];

	// Valida una LISTA de entradas de botín en línea: cada resource/consumable/
	// item debe existir en items.json.
	const checkLootEntries = (entries, report) => {
		if (!Array.isArray(entries)) return;
		for (const entry of entries) {
			if (!entry || typeof entry !== 'object') continue;
			const kind = entry.kind;
			if ((kind === 'resource' || kind === 'consumable' || kind === 'item') && entry.id && !hasItem(entry.id)) {
				report(`el ítem "${entry.id}" que no existe en items.json`);
			}
		}
	};

	// 6a. Loot de enemigos: lista en línea (cada resource/consumable/item → items.json).
	for (const [enemyId, e] of Object.entries(enemies)) {
		checkLootEntries(e.loot, (what) => out.push({
			level: 'error', code: 'loot-item',
			message: `Enemigo "${enemyId}" suelta ${what}.`,
			ref: { tab: 'enemies', target: enemyId },
		}));
	}

	// 6b. Diálogos de NPCs: ítems referenciados en condition y reward deben existir.
	for (const [npcId, nodes] of Object.entries(npcs)) {
		for (const [nodeId, node] of Object.entries(nodes)) {
			for (const itemId of itemRefsInNode(node)) {
				if (!hasItem(itemId)) {
					out.push({
						level: 'error', code: 'dialogue-item',
						message: `NPC "${npcId}", nodo "${nodeId}" referencia el ítem "${itemId}" que no existe en items.json.`,
						ref: { tab: 'npcs', target: { npc: npcId, node: nodeId } },
					});
				}
			}
		}
	}

	// 7. Integridad de EVENTOS y QUESTS (Tarea 5, data-driven).
	const events = store.events || {};
	const quests = store.quests || {};
	const enemyExists = (id) => !!enemies[id];

	for (const [evId, ev] of Object.entries(events)) {
		const actions = Array.isArray(ev.actions) ? ev.actions : [];
		for (const tok of actions) {
			// event:x → el evento referenciado debe existir.
			if (tok.startsWith('event:')) {
				const ref = tok.slice(6).trim();
				if (ref && !events[ref]) {
					out.push({
						level: 'error', code: 'event-ref',
						message: `Evento "${evId}" invoca event:"${ref}" que no existe en events.json.`,
						ref: { tab: 'events', target: evId },
					});
				}
			}
			// combat:id[:lvl[:boss]] → el enemigo debe existir en enemies.json.
			else if (tok.startsWith('combat:')) {
				const enemyId = tok.slice(7).split(':')[0].trim();
				if (enemyId && !enemyExists(enemyId)) {
					out.push({
						level: 'error', code: 'event-combat',
						message: `Evento "${evId}" lanza combat:"${enemyId}" que no existe en enemies.json.`,
						ref: { tab: 'events', target: evId },
					});
				}
			}
			// worldt:x → transformación conocida por el motor.
			else if (tok.startsWith('worldt:')) {
				const t = tok.slice(7).trim();
				if (!['dam_opened', 'cave_cleared', 'monkey_cleared'].includes(t)) {
					out.push({
						level: 'warning', code: 'event-worldt',
						message: `Evento "${evId}" usa worldt:"${t}" no reconocido por el motor (dam_opened/cave_cleared/monkey_cleared).`,
						ref: { tab: 'events', target: evId },
					});
				}
			}
			// dialogue:id → el diálogo debe existir como escena en scenes/ o en dialogues.json.
			else if (tok.startsWith('dialogue:')) {
				const t = tok.slice(9).trim();
				if (t && !dialogues[t] && !scenesForCine[t]) {
					out.push({
						level: 'error', code: 'event-dialogue',
						message: `Evento "${evId}" muestra dialogue:"${t}" que no existe como escena ni en diálogos.`,
						ref: { tab: 'events', target: evId },
					});
				}
			}
			// cine:id → debe existir una escena con ese id en scenes.json.
			else if (tok.startsWith('cine:')) {
				const t = tok.slice(5).trim();
				if (t && !scenesForCine[t]) {
					out.push({
						level: 'error', code: 'event-cine',
						message: `Evento "${evId}" lanza cine:"${t}" que no existe como escena en scenes.json.`,
						ref: { tab: 'events', target: evId },
					});
				}
			}
		}
		// Ítems referenciados por las acciones del evento (item:/-item:) deben existir.
		for (const itemId of itemRefsInNode({ reward: actions.join(';') })) {
			if (!hasItem(itemId)) {
				out.push({
					level: 'error', code: 'event-item',
					message: `Evento "${evId}" referencia el ítem "${itemId}" que no existe en items.json.`,
					ref: { tab: 'events', target: evId },
				});
			}
		}
	}

	// quests.combat_victory: enemigo debe existir y su evento debe estar definido.
	const cv = (quests && quests.combat_victory) || {};
	for (const [enemyId, entry] of Object.entries(cv)) {
		if (!enemyExists(enemyId)) {
			out.push({
				level: 'warning', code: 'quest-hook-enemy',
				message: `quests.json: hook de victoria para "${enemyId}" que no existe en enemies.json.`,
				ref: { tab: 'events', target: enemyId },
			});
		}
		const evId = entry && entry.event;
		if (evId && !events[evId]) {
			out.push({
				level: 'error', code: 'quest-hook-event',
				message: `quests.json: el hook de "${enemyId}" apunta al evento "${evId}" que no existe en events.json.`,
				ref: { tab: 'events', target: enemyId },
			});
		}
	}

	// 8. TIENDAS (shops.json): cada artículo debe existir en items.json.
	const shops = store.shops || {};
	for (const [stockId, list] of Object.entries(shops)) {
		if (!Array.isArray(list)) continue;
		for (const line of list) {
			if (line && line.id && !hasItem(line.id)) {
				out.push({
					level: 'error', code: 'shop-item',
					message: `Tienda "${stockId}" vende el ítem "${line.id}" que no existe en items.json.`,
					ref: { tab: 'shops', target: stockId },
				});
			}
		}
	}

	// 9. MAZMORRAS (data/dungeons/<id>.json): boss, cofres (items/loot) y layout coherentes.
	const dungeons = store.dungeons || {};
	const dungeonTilesQa = store.dungeonTiles || {};
	const dungeonKitPiecesQa = (store.dungeonKits && store.dungeonKits.pieces) || {};
	for (const [dunId, d] of Object.entries(dungeons)) {
		if (d && d.boss && !enemyExists(d.boss)) {
			out.push({
				level: 'error', code: 'dungeon-boss',
				message: `Mazmorra "${dunId}" tiene boss "${d.boss}" que no existe en enemies.json.`,
				ref: { tab: 'dungeons', target: dunId },
			});
		}
		for (const enemyId of (Array.isArray(d && d.random_pool) ? d.random_pool : [])) {
			if (!enemyExists(enemyId)) {
				out.push({
					level: 'warning', code: 'dungeon-pool',
					message: `Mazmorra "${dunId}" tiene en random_pool "${enemyId}" que no existe en enemies.json.`,
					ref: { tab: 'dungeons', target: dunId },
				});
			}
		}
		for (const floor of (Array.isArray(d && d.floors) ? d.floors : [])) {
			for (const row of (Array.isArray(floor.cells) ? floor.cells : [])) {
				for (const cell of (Array.isArray(row) ? row : [])) {
					if (!cell) continue;
					// Celdas de MONSTRUO/JEFE: su `ref` (o el boss de la mazmorra) debe existir.
					if (cell.t === 'monster') {
						const eid = cell.ref || (cell.boss ? d.boss : '');
						if (eid && !enemyExists(eid)) {
							out.push({
								level: 'error', code: 'dungeon-monster',
								message: `Mazmorra "${dunId}": una casilla de monstruo usa "${eid}" que no existe en enemies.json.`,
								ref: { tab: 'dungeons', target: dunId },
							});
						}
					}
					// Tipo de casilla no catalogado en data/dungeon_tiles/ (aviso: cae al
					// render genérico o a una losa de suelo, pero probablemente es un typo).
					if (cell.t && !dungeonTilesQa[cell.t]) {
						out.push({
							level: 'warning', code: 'dungeon-tile-unknown',
							message: `Mazmorra "${dunId}": una casilla usa el tipo "${cell.t}" que no existe en data/dungeon_tiles/.`,
							ref: { tab: 'dungeons', target: dunId },
						});
					}
					// Casillas de OBJETO INTELIGENTE ("smart"): su `ref` (pieza del kit)
					// debe existir en dungeon_kits.json (pieces).
					if (cell.t === 'smart' && cell.ref && !dungeonKitPiecesQa[cell.ref]) {
						out.push({
							level: 'error', code: 'dungeon-smart-piece',
							message: `Mazmorra "${dunId}": un Objeto Inteligente usa la pieza "${cell.ref}" que no existe en dungeon_kits.json.`,
							ref: { tab: 'dungeons', target: dunId },
						});
					}
					if (cell.t !== 'chest') continue;
					for (const it of (Array.isArray(cell.items) ? cell.items : [])) {
						if (it && it.id && !hasItem(it.id)) {
							out.push({
								level: 'error', code: 'dungeon-chest-item',
								message: `Mazmorra "${dunId}": un cofre contiene el ítem "${it.id}" que no existe en items.json.`,
								ref: { tab: 'dungeons', target: dunId },
							});
						}
					}
				}
			}
		}

		// 9a2. VALIDADOR DE SOLUBILIDAD ESTRUCTURAL (Pilar 4.2): BFS desde el punto
		// de inicio siguiendo casillas no sólidas y escaleras/teletransportes con
		// destino. Las puertas/compuertas/luces (CONTROLLABLE_TYPES) se consideran
		// SIEMPRE abribles (no se simula el estado de los interruptores): esto NO
		// resuelve el puzle completo, solo descarta bloqueos reales de muros/vacío
		// — el caso más frecuente y grave (contenido encerrado por accidente).
		{
			const CONTROLLABLE_TYPES_QA = new Set(['door', 'gate', 'light']);
			const fl = Array.isArray(d && d.floors) ? d.floors : [];
			const sp = (d && d.spawn) || {};
			const sf = Number(sp.f) || 0, sx = Number(sp.x) || 0, sy = Number(sp.y) || 0;
			const startFloor = fl[sf];
			const startCell = startFloor && Array.isArray(startFloor.cells) ? (startFloor.cells[sy] || [])[sx] : null;
			if (startFloor && startCell) {
				const isBlocked = (cell) => {
					if (!cell || cell.t === 'void') return true;
					if (cell.col === false) return false;
					if (cell.col === true) return true;
					if (CONTROLLABLE_TYPES_QA.has(cell.t)) return false;
					const def = dungeonTilesQa[cell.t];
					return !!(def && def.solid);
				};
				const visited = new Set([`${sf},${sx},${sy}`]);
				const queue = [[sf, sx, sy]];
				while (queue.length) {
					const [cf, cx, cy] = queue.shift();
					const floor = fl[cf];
					const cells = floor && Array.isArray(floor.cells) ? floor.cells : null;
					if (!cells) continue;
					const cell = (cells[cy] || [])[cx];
					if (!cell) continue;
					if ((cell.t === 'teleport' || cell.t === 'stairs') && cell.to && typeof cell.to === 'object') {
						const tf = Number(cell.to.f) || 0, tx = Number(cell.to.x), ty = Number(cell.to.y);
						const key = `${tf},${tx},${ty}`;
						if (!visited.has(key) && fl[tf]) { visited.add(key); queue.push([tf, tx, ty]); }
					}
					const w = floor.w || (cells[0] || []).length, h = floor.h || cells.length;
					for (const [nx, ny] of [[cx + 1, cy], [cx - 1, cy], [cx, cy + 1], [cx, cy - 1]]) {
						if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
						if (isBlocked((cells[ny] || [])[nx])) continue;
						const key = `${cf},${nx},${ny}`;
						if (!visited.has(key)) { visited.add(key); queue.push([cf, nx, ny]); }
					}
				}
				let bossUnreachable = false;
				let contentUnreachableCount = 0;
				fl.forEach((floor, fi) => {
					(Array.isArray(floor.cells) ? floor.cells : []).forEach((row, y) => {
						(Array.isArray(row) ? row : []).forEach((cell, x) => {
							if (!cell || visited.has(`${fi},${x},${y}`)) return;
							if (cell.t === 'monster' && cell.boss) bossUnreachable = true;
							else if (cell.t === 'chest' || cell.t === 'monster') contentUnreachableCount++;
						});
					});
				});
				if (bossUnreachable) {
					out.push({
						level: 'error', code: 'dungeon-boss-unreachable',
						message: `Mazmorra "${dunId}": el boss no tiene camino físico desde el punto de inicio (revisa muros/vacío; puertas/compuertas se asumen abribles).`,
						ref: { tab: 'dungeons', target: dunId },
					});
				}
				if (contentUnreachableCount > 0) {
					out.push({
						level: 'warning', code: 'dungeon-content-unreachable',
						message: `Mazmorra "${dunId}": ${contentUnreachableCount} cofre(s)/monstruo(s) sin camino físico desde el punto de inicio.`,
						ref: { tab: 'dungeons', target: dunId },
					});
				}
			}
		}
	}

	// 9b. KITS DE OBJETO INTELIGENTE (dungeon_kits.json): cada pieza debe apuntar
	// a un kit existente.
	const dungeonKitsQa = (store.dungeonKits && store.dungeonKits.kits) || {};
	for (const [pieceId, piece] of Object.entries(dungeonKitPiecesQa)) {
		if (piece && piece.kit && !dungeonKitsQa[piece.kit]) {
			out.push({
				level: 'error', code: 'kit-piece-kit',
				message: `Pieza "${pieceId}" pertenece al kit "${piece.kit}" que no existe en dungeon_kits.json.`,
				ref: { tab: 'dungeonKits', target: pieceId },
			});
		}
	}

	// 10. LOGROS (achievements.json): el reward no debe referenciar ítems/tablas rotos.
	const achievements = store.achievements || {};
	for (const [achId, a] of Object.entries(achievements)) {
		const reward = String((a && a.reward) || '');
		for (const itemId of itemRefsInNode({ reward })) {
			if (!hasItem(itemId)) {
				out.push({
					level: 'error', code: 'ach-item',
					message: `Logro "${achId}" da el ítem "${itemId}" que no existe en items.json.`,
					ref: { tab: 'events', target: achId },
				});
			}
		}
	}

	// 12. AMBIENTE (ambience.json): music/weather referenciados deben estar definidos.
	const ambience = store.ambience || {};
	const ambMusic = (ambience && ambience.music) || {};
	const ambWeather = (ambience && ambience.weather) || {};
	const ambTerrain = (ambience && ambience.terrain) || {};
	for (const [code, def] of Object.entries(ambTerrain)) {
		if (def && def.music && !ambMusic[def.music]) {
			out.push({ level: 'warning', code: 'ambience-music',
				message: `ambience.json: terreno "${code}" usa music:"${def.music}" no definido en ambience.music.`,
				ref: { tab: 'map', target: null } });
		}
		if (def && def.weather && def.weather !== 'none' && !ambWeather[def.weather]) {
			out.push({ level: 'warning', code: 'ambience-weather',
				message: `ambience.json: terreno "${code}" usa weather:"${def.weather}" no definido en ambience.weather.`,
				ref: { tab: 'map', target: null } });
		}
	}

	// 13. SINERGIAS (synergies.json): required_ids y result_id deben existir en skills.
	const skills = store.skills || {};
	const hasSkill = (id) => !!skills[id];
	const synergyList = Array.isArray(store.synergies && store.synergies.synergies) ? store.synergies.synergies : [];
	synergyList.forEach((s, i) => {
		if (!s || typeof s !== 'object') return;
		for (const rid of (Array.isArray(s.required_ids) ? s.required_ids : [])) {
			if (rid && !hasSkill(rid)) {
				out.push({ level: 'error', code: 'synergy-req',
					message: `Sinergia #${i + 1} (${s.profession || '?'}) requiere la habilidad "${rid}" que no existe en skills.json.`,
					ref: { tab: 'synergies', target: null } });
			}
		}
		if (s.result_id && !hasSkill(s.result_id)) {
			out.push({ level: 'error', code: 'synergy-result',
				message: `Sinergia #${i + 1} produce "${s.result_id}" que no existe en skills.json.`,
				ref: { tab: 'synergies', target: null } });
		}
	});

	// 14. TRANSFORMACIONES DE MUNDO (world_transforms.json): match.event_id debe existir
	// en data/ids/ (o ser una casilla del mapa) y terrain de `set` debe ser válido.
	const worldTransforms = store.worldTransforms || {};
	// Códigos válidos de terreno: data-driven (data/world_terrains/<code>.json), no
	// una lista cableada — así un terreno nuevo creado en el editor se valida solo.
	const TERRAIN_CODES = Object.keys(store.worldTerrains || {});
	for (const [wtId, wt] of Object.entries(worldTransforms)) {
		if (!wt || typeof wt !== 'object') continue;
		if (typeof wt.builtin === 'string') continue; // rutina cableada: no se valida aquí
		for (const rule of (Array.isArray(wt.rules) ? wt.rules : [])) {
			const evId = rule && rule.match && rule.match.event_id;
			if (evId && !ids[evId]) {
				out.push({ level: 'warning', code: 'worldt-match',
					message: `Transformación "${wtId}" apunta a event_id "${evId}" que no existe en data/ids/.`,
					ref: { tab: 'worldTransforms', target: wtId } });
			}
			const terr = rule && rule.set && rule.set.terrain;
			if (terr && !TERRAIN_CODES.includes(terr)) {
				out.push({ level: 'error', code: 'worldt-terrain',
					message: `Transformación "${wtId}" fija terrain "${terr}" no válido (${TERRAIN_CODES.join('/')}).`,
					ref: { tab: 'worldTransforms', target: wtId } });
			}
		}
	}

	// ══════════════════════════════════════════════════════════════════════
	// QA INTELIGENTE. Va más allá de la integridad referencial: detecta
	// contenido "sin sentido de juego" (inalcanzable, inobtenible, sin uso…).
	// Casi todo es WARNING; solo los enlaces claramente rotos o ciclos son ERROR.
	// ══════════════════════════════════════════════════════════════════════
	const professions = store.professions || {};
	const achievements2 = store.achievements || {};

	// A. NPCs: nodos de diálogo INACCESIBLES desde la entrada.
	for (const [npcId, nodes] of Object.entries(npcs)) {
		const keys = Object.keys(nodes).filter(k => k !== '_meta');
		if (!keys.length) continue;
		const targeted = new Set();
		for (const [k, n] of Object.entries(nodes)) {
			if (k === '_meta') continue;
			for (const nx of (n.next || [])) if (nx !== 'close') targeted.add(nx);
		}
		let entry = null, fallback = null;
		for (const k of keys) {
			if ((nodes[k].type || 'message') !== 'message') continue;
			if (!targeted.has(k)) { entry = k; break; }
			if (!fallback) fallback = k;
		}
		if (!entry) entry = nodes[npcId + '_1'] ? npcId + '_1' : (fallback || keys[0]);
		const reachable = new Set();
		const stack = [entry];
		while (stack.length) {
			const id = stack.pop();
			if (id === 'close' || reachable.has(id) || !nodes[id]) continue;
			reachable.add(id);
			for (const nx of (nodes[id].next || [])) stack.push(nx);
		}
		for (const k of keys) {
			if (!reachable.has(k)) {
				out.push({
					level: 'warning', code: 'npc-unreachable',
					message: `NPC "${npcId}": el nodo "${k}" no es alcanzable desde la entrada ("${entry}").`,
					ref: { tab: 'npcs', target: { npc: npcId, node: k } },
				});
			}
		}

		// A2. Nodos atrapados en un CICLO SIN SALIDA: SÍ tienen next y SÍ son
		// alcanzables, pero ninguna de sus ramas llega jamás a "close" — el
		// jugador quedaría congelado dando vueltas en el diálogo para siempre.
		// Distinto de "dead-end" (nodo sin next) y de "unreachable" (nadie lo enlaza).
		const canReachClose = new Set();
		let growing = true;
		while (growing) {
			growing = false;
			for (const k of keys) {
				if (canReachClose.has(k)) continue;
				const nx = Array.isArray(nodes[k].next) ? nodes[k].next : [];
				if (nx.some(t => t === 'close' || canReachClose.has(t))) { canReachClose.add(k); growing = true; }
			}
		}
		for (const k of keys) {
			const nx = Array.isArray(nodes[k].next) ? nodes[k].next : [];
			if (reachable.has(k) && nx.length > 0 && !canReachClose.has(k)) {
				out.push({
					level: 'error', code: 'npc-infinite-loop',
					message: `NPC "${npcId}", nodo "${k}" queda atrapado en un ciclo sin salida: ninguna de sus ramas llega nunca a "close".`,
					ref: { tab: 'npcs', target: { npc: npcId, node: k } },
				});
			}
		}
	}

	// B. ÍTEMS inobtenibles: definidos en items.json pero nunca concedidos por
	// ningún medio (tienda, botín, cofre, casilla de objeto o recompensa).
	const obtainable = new Set();
	const collectLoot = (entries) => {
		if (!Array.isArray(entries)) return;
		for (const e of entries) if (e && (e.kind === 'resource' || e.kind === 'consumable' || e.kind === 'item') && e.id) obtainable.add(e.id);
	};
	for (const list of Object.values(shops)) if (Array.isArray(list)) for (const line of list) if (line && line.id) obtainable.add(line.id);
	for (const entries of Object.values(loot)) collectLoot(entries);
	for (const e of Object.values(enemies)) if (Array.isArray(e.loot)) collectLoot(e.loot);
	for (const nodes of Object.values(npcs)) for (const node of Object.values(nodes)) for (const id of itemRefsInNode(node)) obtainable.add(id);
	for (const ev of Object.values(events)) { const acts = Array.isArray(ev.actions) ? ev.actions : []; for (const id of itemRefsInNode({ reward: acts.join(';') })) obtainable.add(id); }
	for (const a of Object.values(achievements2)) for (const id of itemRefsInNode({ reward: String((a && a.reward) || '') })) obtainable.add(id);
	for (const d of Object.values(dungeons)) {
		for (const floor of (Array.isArray(d && d.floors) ? d.floors : [])) {
			for (const row of (Array.isArray(floor.cells) ? floor.cells : [])) {
				for (const cell of (Array.isArray(row) ? row : [])) {
					if (!cell) continue;
					if (cell.t === 'item' && cell.ref) obtainable.add(cell.ref);
					if (cell.t === 'chest') for (const it of (Array.isArray(cell.items) ? cell.items : [])) if (it && it.id) obtainable.add(it.id);
				}
			}
		}
	}
	for (const itemId of Object.keys(items)) {
		if (!obtainable.has(itemId)) {
			out.push({
				level: 'warning', code: 'item-unobtainable',
				message: `El ítem "${itemId}" no se obtiene por ningún medio (tienda, botín, cofre, casilla u recompensa). ¿Falta colocarlo?`,
				ref: { tab: 'items', target: itemId },
			});
		}
	}

	// C. SKILLS sin uso: no referenciadas por ninguna profesión ni sinergia.
	const usedSkills = new Set();
	for (const prof of Object.values(professions)) {
		for (const s of (Array.isArray(prof && prof.skills) ? prof.skills : [])) {
			const sid = typeof s === 'string' ? s : (s && s.id);
			if (sid) usedSkills.add(sid);
		}
	}
	for (const s of synergyList) {
		for (const rid of (Array.isArray(s && s.required_ids) ? s.required_ids : [])) if (rid) usedSkills.add(rid);
		if (s && s.result_id) usedSkills.add(s.result_id);
	}
	for (const skillId of Object.keys(skills)) {
		if (!usedSkills.has(skillId)) {
			out.push({
				level: 'warning', code: 'skill-unused',
				message: `La habilidad "${skillId}" no la usa ninguna profesión ni sinergia.`,
				ref: { tab: 'skills', target: skillId },
			});
		}
	}

	// D. MAZMORRAS: accionadores sin destino, destinos rotos, compuertas sin
	// controlador, eids duplicados y mazmorras incompletas.
	const ACTUATORS = new Set(['switch', 'button', 'lever', 'pressure']);
	const CONTROLLABLE = new Set(['gate', 'door', 'light']);
	for (const [id, obj] of Object.entries(ids)) {
		if (obj.type === 'dungeon' && !dungeons[id]) {
			out.push({
				level: 'warning', code: 'dungeon-undefined',
				message: `"${id}" es de tipo dungeon pero no tiene fichero data/dungeons/${id}.json (mazmorra vacía).`,
				ref: { tab: 'ids', target: id },
			});
		}
	}
	for (const [dunId, d] of Object.entries(dungeons)) {
		const fl = Array.isArray(d && d.floors) ? d.floors : [];
		if (!fl.length) {
			out.push({
				level: 'warning', code: 'dungeon-empty',
				message: `Mazmorra "${dunId}" no tiene plantas (floors): está incompleta.`,
				ref: { tab: 'dungeons', target: dunId },
			});
			continue;
		}
		// SPAWN del jugador: debe caer en una casilla existente, no vacía y no
		// sólida (si no, el jugador aparecería dentro de un muro o cayendo al vacío).
		const sp = d.spawn || {};
		const spFloor = fl[Number(sp.f) || 0];
		if (!spFloor) {
			out.push({
				level: 'error', code: 'dungeon-spawn-floor',
				message: `Mazmorra "${dunId}": el inicio del jugador apunta a la planta ${Number(sp.f) || 0}, que no existe.`,
				ref: { tab: 'dungeons', target: dunId },
			});
		} else {
			const spRow = Array.isArray(spFloor.cells) ? spFloor.cells[Number(sp.y) || 0] : null;
			const spCell = spRow ? spRow[Number(sp.x) || 0] : null;
			if (!spCell || spCell.t === 'void') {
				out.push({
					level: 'warning', code: 'dungeon-spawn-empty',
					message: `Mazmorra "${dunId}": el inicio del jugador (${Number(sp.x) || 0},${Number(sp.y) || 0}) cae en una casilla vacía; podría caer al vacío al empezar.`,
					ref: { tab: 'dungeons', target: dunId },
				});
			} else if (dungeonTilesQa[spCell.t] && dungeonTilesQa[spCell.t].solid && spCell.col !== false) {
				out.push({
					level: 'warning', code: 'dungeon-spawn-solid',
					message: `Mazmorra "${dunId}": el inicio del jugador (${Number(sp.x) || 0},${Number(sp.y) || 0}) cae dentro de un "${spCell.t}" sólido; podría quedar atascado.`,
					ref: { tab: 'dungeons', target: dunId },
				});
			}
		}
		// Entradas/salidas NOMBRADAS: cada `portals.<nombre>` debe
		// tener al menos una celda de teletransporte de SALIDA (`t:'teleport'`, sin
		// `to`) marcada con ese mismo nombre — si no, esa puerta es inalcanzable
		// desde dentro (el jugador nunca podría volver a salir por ahí). Y al revés:
		// una celda con `portal:"<nombre>"` debe existir en `portals`, o el nombre
		// no está declarado y ViewDungeon no sabría a qué casilla del mundo volver.
		const declaredPortals = (d.portals && typeof d.portals === 'object') ? d.portals : {};
		const usedPortalNames = new Set();
		const eidCount = {};
		const eidSet = new Set();
		const targetedEids = new Set();
		const actuatorCells = [];
		const controllableCells = [];
		fl.forEach((floor, fi) => {
			(Array.isArray(floor.cells) ? floor.cells : []).forEach((row, y) => {
				(Array.isArray(row) ? row : []).forEach((cell, x) => {
					if (!cell) return;
					if (cell.eid) { eidCount[cell.eid] = (eidCount[cell.eid] || 0) + 1; eidSet.add(cell.eid); }
					if (ACTUATORS.has(cell.t)) {
						actuatorCells.push({ cell, fi, x, y });
						for (const tg of (Array.isArray(cell.targets) ? cell.targets : [])) if (tg && tg.eid) targetedEids.add(tg.eid);
					}
					if (CONTROLLABLE.has(cell.t) && cell.eid) controllableCells.push({ cell, fi, x, y });
					// TELETRANSPORTE con destino INTERNO (`to`): debe apuntar dentro
					// de límites. Sin `to` es un teleport de SALIDA (válido), no se valida.
					// Las ESCALERAS reutilizan el mismo campo `to` para
					// conectar plantas: sin destino son solo decorativas (aviso).
					if ((cell.t === 'teleport' || cell.t === 'stairs') && cell.to && typeof cell.to === 'object') {
						const label = cell.t === 'stairs' ? 'una escalera' : 'un teletransporte';
						const to = cell.to;
						const tf = fl[Number(to.f) || 0];
						const tx = Number(to.x), ty = Number(to.y);
						const okBounds = tf && tx >= 0 && ty >= 0 && tx < tf.w && ty < tf.h;
						if (!okBounds) {
							out.push({
								level: 'error', code: 'dungeon-teleport-oob',
								message: `Mazmorra "${dunId}": ${label} en planta ${fi + 1} (${x},${y}) apunta al destino (f${Number(to.f) || 0}, ${tx}, ${ty}) fuera de límites.`,
								ref: { tab: 'dungeons', target: dunId },
							});
						} else {
							const destCell = tf.cells[ty] && tf.cells[ty][tx];
							if (!destCell || destCell.t === 'void') {
								out.push({
									level: 'warning', code: 'dungeon-teleport-empty',
									message: `Mazmorra "${dunId}": ${label} en planta ${fi + 1} (${x},${y}) lleva a una casilla vacía; el jugador caería al vacío.`,
									ref: { tab: 'dungeons', target: dunId },
								});
							}
						}
					} else if (cell.t === 'stairs' && !cell.to) {
						out.push({
							level: 'warning', code: 'dungeon-stairs-no-target',
							message: `Mazmorra "${dunId}": la escalera en planta ${fi + 1} (${x},${y}) no tiene destino; es solo decorativa y no sube de planta.`,
							ref: { tab: 'dungeons', target: dunId },
						});
					}
					// Salida NOMBRADA (`portal:"<nombre>"`, solo tiene sentido en un
					// teleport de SALIDA, sin `to`): el nombre debe estar declarado en
					// `portals`, o ViewDungeon no encontrará a qué casilla del mundo volver.
					if (cell.t === 'teleport' && !cell.to && cell.portal) {
						usedPortalNames.add(cell.portal);
						if (!declaredPortals[cell.portal]) {
							out.push({
								level: 'error', code: 'dungeon-portal-undeclared',
								message: `Mazmorra "${dunId}": el teletransporte en planta ${fi + 1} (${x},${y}) sale por la entrada "${cell.portal}", que no está declarada en "Entradas nombradas".`,
								ref: { tab: 'dungeons', target: dunId },
							});
						}
					}
				});
			});
		});
		for (const [name, p] of Object.entries(declaredPortals)) {
			if (!usedPortalNames.has(name)) {
				out.push({
					level: 'warning', code: 'dungeon-portal-unused',
					message: `Mazmorra "${dunId}": la entrada nombrada "${name}" no tiene ninguna celda de teletransporte que salga por ella; nunca podrás volver a salir por esa puerta.`,
					ref: { tab: 'dungeons', target: dunId },
				});
			}
			const sp = (p && p.spawn) || {};
			const spFl = fl[Number(sp.f) || 0];
			const spRow2 = spFl && Array.isArray(spFl.cells) ? spFl.cells[Number(sp.y) || 0] : null;
			const spCell2 = spRow2 ? spRow2[Number(sp.x) || 0] : null;
			if (!spFl || !spCell2 || spCell2.t === 'void') {
				out.push({
					level: 'warning', code: 'dungeon-portal-spawn-empty',
					message: `Mazmorra "${dunId}": el punto de aparición de la entrada "${name}" (${Number(sp.x) || 0},${Number(sp.y) || 0}) cae fuera del mapa o en una casilla vacía.`,
					ref: { tab: 'dungeons', target: dunId },
				});
			}
		}
		for (const [eid, n] of Object.entries(eidCount)) {
			if (n > 1) {
				out.push({
					level: 'error', code: 'dungeon-eid-dup',
					message: `Mazmorra "${dunId}": el eid "${eid}" está definido ${n} veces (deben ser únicos).`,
					ref: { tab: 'dungeons', target: dunId },
				});
			}
		}
		for (const { cell, fi, x, y } of actuatorCells) {
			const targets = Array.isArray(cell.targets) ? cell.targets.filter(t => t && t.eid) : [];
			if (!targets.length) {
				out.push({
					level: 'warning', code: 'actuator-no-target',
					message: `Mazmorra "${dunId}": el ${cell.t} en planta ${fi + 1} (${x},${y}) no acciona ningún objetivo (sin targets).`,
					ref: { tab: 'dungeons', target: dunId },
				});
			}
			for (const tg of targets) {
				if (!eidSet.has(tg.eid)) {
					out.push({
						level: 'error', code: 'actuator-broken-target',
						message: `Mazmorra "${dunId}": un ${cell.t} en planta ${fi + 1} (${x},${y}) acciona el eid "${tg.eid}" que no existe.`,
						ref: { tab: 'dungeons', target: dunId },
					});
				}
			}
		}
		for (const { cell, fi } of controllableCells) {
			if (!targetedEids.has(cell.eid)) {
				const label = cell.t === 'gate' ? 'la compuerta' : (cell.t === 'light' ? 'la luz' : 'la puerta');
				out.push({
					level: 'warning', code: 'gate-no-controller',
					message: `Mazmorra "${dunId}": ${label} "${cell.eid}" (planta ${fi + 1}) no la acciona ningún interruptor/palanca/placa.`,
					ref: { tab: 'dungeons', target: dunId },
				});
			}
		}
	}

	// E. ENTIDADES inaccesibles: ciudades/mazmorras no colocadas en ningún mapa,
	// y POIs que no están en el content de ninguna ciudad ni en el mapa.
	const placed = new Set();
	for (const w of [store.worldReal, store.worldDebug, world]) {
		if (!w || !Array.isArray(w.tiles)) continue;
		for (const row of w.tiles) for (const t of (row || [])) if (t && t.object) placed.add(t.object);
	}
	const inCityContent = new Set();
	for (const obj of Object.values(ids)) if (Array.isArray(obj.content)) for (const c of obj.content) inCityContent.add(c);
	for (const [id, obj] of Object.entries(ids)) {
		if (obj.type === 'city' || obj.type === 'dungeon') {
			if (!placed.has(id)) {
				out.push({
					level: 'warning', code: 'entity-unplaced',
					message: `${obj.type === 'city' ? 'La ciudad' : 'La mazmorra'} "${id}" no está colocada en ningún mapa: es inaccesible.`,
					ref: { tab: 'ids', target: id },
				});
			}
		} else if (obj.type === 'poi') {
			if (!placed.has(id) && !inCityContent.has(id)) {
				out.push({
					level: 'warning', code: 'poi-orphan',
					message: `El POI "${id}" no está en el mapa ni dentro del content de ninguna ciudad: es inaccesible.`,
					ref: { tab: 'ids', target: id },
				});
			}
		}
	}

	// F. REFERENCIAS CIRCULARES entre eventos (event:x que se invocan en ciclo).
	const eventGraph = {};
	for (const [evId, ev] of Object.entries(events)) {
		const deps = [];
		for (const tok of (Array.isArray(ev.actions) ? ev.actions : [])) {
			if (typeof tok === 'string' && tok.startsWith('event:')) {
				const r = tok.slice(6).trim();
				if (r && events[r]) deps.push(r);
			}
		}
		eventGraph[evId] = deps;
	}
	const cyclesReported = new Set();
	const colorMap = {};   // 0=blanco, 1=gris (en pila), 2=negro (cerrado)
	const dfsEvents = (node, path) => {
		colorMap[node] = 1;
		path.push(node);
		for (const dep of (eventGraph[node] || [])) {
			if (colorMap[dep] === 1) {
				const idx = path.indexOf(dep);
				const cycle = path.slice(idx).concat(dep);
				const key = [...new Set(cycle)].sort().join('|');
				if (!cyclesReported.has(key)) {
					cyclesReported.add(key);
					out.push({
						level: 'error', code: 'event-cycle',
						message: `Referencia circular entre eventos: ${cycle.join(' → ')}.`,
						ref: { tab: 'events', target: cycle[0] },
					});
				}
			} else if (colorMap[dep] !== 2) {
				dfsEvents(dep, path);
			}
		}
		path.pop();
		colorMap[node] = 2;
	};
	for (const evId of Object.keys(eventGraph)) if (colorMap[evId] !== 2) dfsEvents(evId, []);

	// G. ACCIONES "SOLO-CÓDIGO". El mini-lenguaje de `reward`/`ops`
	// es DATA-FIRST: un token `qaction:x` primero busca `events.json[x]` y solo si
	// no existe cae a QuestManager.handle_choice (match cableado); `worldt:x` cae
	// igual a WorldMapBuilder._run_builtin; un enemigo sin hook en
	// quests.combat_victory cae a QuestManager.on_combat_victory (match cableado).
	// Esto es VÁLIDO por diseño (no es un error), pero el editor no puede tocar esa
	// lógica: se informa para que el diseñador sepa qué necesita ayuda de
	// desarrollo. Mantener sincronizado a mano con esos `match` de GDScript.
	const KNOWN_QACTIONS = { accept_quest: 'QuestManager.handle_choice', start_cave_combat: 'QuestManager.handle_choice', receive_banana: 'QuestManager.handle_choice', give_banana: 'QuestManager.handle_choice' };
	const KNOWN_CODE_TRANSFORMS = { dam_opened: 'WorldMapBuilder._run_builtin', cave_cleared: 'WorldMapBuilder._run_builtin', monkey_cleared: 'WorldMapBuilder._run_builtin' };
	const KNOWN_COMBAT_HOOKS = { sombra_oscura: 'QuestManager.on_combat_victory', cave_boss: 'QuestManager.on_combat_victory', dungeon_boss: 'QuestManager.on_combat_victory' };

	// Extrae los tokens qaction:/worldt:/dam del mini-lenguaje `reward`/`ops`
	// ("gold:10;qaction:give_banana;worldt:dam_opened;dam"). `action` es el
	// campo suelto de dialogues.json (sin ';', se traduce a qaction: si no es
	// "" ni "dismiss" — ver SceneAdapters.dialogue_to_scene).
	function codeTokensInMiniLang(str) {
		const found = [];
		for (const raw of String(str || '').split(';')) {
			const tok = raw.trim();
			if (!tok) continue;
			if (tok.startsWith('qaction:')) found.push({ kind: 'qaction', id: tok.slice(8).trim() });
			else if (tok.startsWith('worldt:')) found.push({ kind: 'worldt', id: tok.slice(7).trim() });
			else if (tok === 'dam') found.push({ kind: 'worldt', id: 'dam_opened' });
		}
		return found;
	}

	// Recopila { qaction: Map<id, count>, worldt: Map<id, count> } de todas las
	// fuentes narrativas: npcs.json (reward), dialogues.json (action) y
	// scenes.json (nodos "state" → ops).
	const codeTokenUses = { qaction: new Map(), worldt: new Map() };
	const addUse = (kind, id) => codeTokenUses[kind].set(id, (codeTokenUses[kind].get(id) || 0) + 1);
	for (const nodes of Object.values(npcs)) {
		for (const node of Object.values(nodes)) {
			for (const t of codeTokensInMiniLang(node && node.reward)) addUse(t.kind, t.id);
		}
	}
	for (const d of Object.values(dialogues)) {
		for (const choice of (Array.isArray(d && d.choices) ? d.choices : [])) {
			const action = String((choice && choice.action) || '').trim();
			if (action && action !== 'dismiss') addUse('qaction', action);
		}
	}
	const scenesQa = store.scenes || {};
	for (const sc of Object.values(scenesQa)) {
		for (const node of Object.values((sc && sc.nodes) || {})) {
			if (node && node.kind === 'state') {
				for (const t of codeTokensInMiniLang(node.ops)) addUse(t.kind, t.id);
			}
		}
	}
	for (const [action, n] of codeTokenUses.qaction) {
		if (events[action]) continue; // data-first: resuelve en events.json, no depende de código
		if (KNOWN_QACTIONS[action]) {
			out.push({
				level: 'info', code: 'code-only-qaction',
				message: `La acción "${action}" (usada ${n}×) depende del código cableado en ${KNOWN_QACTIONS[action]} — no existe events.json["${action}"].`,
				ref: { tab: 'events', target: action },
			});
		} else {
			out.push({
				level: 'warning', code: 'code-unknown-qaction',
				message: `La acción "${action}" (usada ${n}×) no existe en events.json NI es una acción cableada reconocida: probablemente no hace nada.`,
				ref: { tab: 'events', target: action },
			});
		}
	}
	for (const [wt, n] of codeTokenUses.worldt) {
		const def = worldTransforms[wt];
		if (def && Array.isArray(def.rules)) continue; // data-driven completo
		if (KNOWN_CODE_TRANSFORMS[wt]) {
			out.push({
				level: 'info', code: 'code-only-worldt',
				message: `La transformación "${wt}" (usada ${n}×) depende de la rutina cableada ${KNOWN_CODE_TRANSFORMS[wt]}${def && def.builtin ? '' : ' (sin ficha en world_transforms.json)'}.`,
				ref: { tab: 'worldTransforms', target: wt },
			});
		} else {
			out.push({
				level: 'warning', code: 'code-unknown-worldt',
				message: `La transformación "${wt}" (usada ${n}×) no tiene reglas en world_transforms.json NI es una rutina builtin reconocida: probablemente no hace nada.`,
				ref: { tab: 'worldTransforms', target: wt },
			});
		}
	}
	// Enemigos con posible hook de combate cableado (QuestManager.on_combat_victory)
	// que NO tienen ficha en quests.combat_victory.
	for (const enemyId of Object.keys(KNOWN_COMBAT_HOOKS)) {
		if (!enemyExists(enemyId) || cv[enemyId]) continue;
		out.push({
			level: 'info', code: 'code-only-combat',
			message: `El enemigo "${enemyId}" tiene un hook de victoria cableado en ${KNOWN_COMBAT_HOOKS[enemyId]} — no hay ficha en quests.json.combat_victory.`,
			ref: { tab: 'enemies', target: enemyId },
		});
	}

	// 5. Assets faltantes (advertencia). Fondos e imágenes de NPC.
	if (checkAssets) {
		const bgNames = await FS.listAssets('bg');
		const npcNames = await FS.listAssets('npc');
		if (bgNames.length || npcNames.length) {
			// Fondos: POIs/ciudades con bg o npc suelen tener fondo asociado.
			for (const [id, obj] of Object.entries(ids)) {
				const wantsBg = obj.type === 'city' || obj.type === 'poi';
				if (!wantsBg) continue;
				const cands = bgCandidates(id, obj);
				if (!anyAssetMatch(bgNames, cands)) {
					out.push({
						level: 'warning', code: 'asset-bg',
						message: `"${id}" no tiene fondo en assets/bg_images (probado: ${cands.join(', ')}).`,
						ref: { tab: 'ids', target: id },
					});
				}
			}
			// Sprites de NPC.
			for (const npcId of Object.keys(npcs)) {
				const cands = [`npc_${npcId}`];
				if (!anyAssetMatch(npcNames, cands)) {
					out.push({
						level: 'warning', code: 'asset-npc',
						message: `NPC "${npcId}" no tiene sprite en assets/img_npcs (probado: npc_${npcId}.png).`,
						ref: { tab: 'npcs', target: { npc: npcId } },
					});
				}
			}
		}
	}

	return out;
}

/**
 * Extrae los IDs de ítem referenciados en un nodo de diálogo, tanto en el
 * `reward` (tokens item:ID=n y -item:ID=n) como en el `condition`
 * (has_item("ID"), no_item("ID")). Devuelve un Set de ids únicos.
 */
export function itemRefsInNode(node) {
	const refs = new Set();
	if (!node) return refs;

	// reward: "item:banana=1;-item:diario=1;gold:10"
	const reward = String(node.reward || '');
	for (const raw of reward.split(';')) {
		const tok = raw.trim();
		let body = null;
		if (tok.startsWith('item:')) body = tok.slice(5);
		else if (tok.startsWith('-item:')) body = tok.slice(6);
		if (body !== null) {
			const id = body.split('=')[0].trim();
			if (id) refs.add(id);
		}
	}

	// condition: has_item("diario"[, n]) / no_item("banana")
	const cond = String(node.condition || '');
	const re = /(?:has_item|no_item)\(\s*["']([^"']+)["']/g;
	let m;
	while ((m = re.exec(cond)) !== null) {
		if (m[1]) refs.add(m[1]);
	}
	return refs;
}

/** Nombres base candidatos para el fondo de una entidad. */
export function bgCandidates(id, obj) {
	const c = [`bg_${id}`, `bg_place_${id}`];
	if (obj && obj.npc) {
		c.push(`bg_building_${obj.npc}`, `bg_${obj.npc}`);
	}
	if (obj && obj.kind) c.push(`bg_building_${obj.kind}`);
	return c;
}

function anyAssetMatch(names, candidates) {
	const bases = names.map(n => n.toLowerCase().replace(/\.(png|jpg|jpeg|webp)$/, ''));
	return candidates.some(c => bases.includes(c.toLowerCase()));
}
