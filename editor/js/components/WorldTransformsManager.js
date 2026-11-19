// components/WorldTransformsManager.js
// ─────────────────────────────────────────────────────────────────────────────
// Gestor de world_transforms.json (Fase B): transformaciones del MUNDO. Cada
// entrada es `transform_id -> { desc?, rules:[ { match, set } ] }` o bien
// `{ desc?, builtin: "id" }` para delegar en una rutina cableada (p. ej. la presa).
//   · match : { event_id | terrain | ... } — casillas a las que aplica.
//   · set   : campos de casilla a sobreescribir (name, icon, terrain, item…).
// El motor (WorldMapBuilder.apply_transform) aplica estas reglas al world.json.
// ─────────────────────────────────────────────────────────────────────────────
import { computed } from 'https://unpkg.com/vue@3/dist/vue.esm-browser.prod.js';
import { store, terrainsList } from '../store.js';
import { useCollection } from '../lib/useCollection.js';
import EntityListPanel from './EntityListPanel.js';
import EditorToolbar from './EditorToolbar.js';

// Campos de casilla más habituales a sobreescribir en `set` (todos los que
// WorldMapBuilder._apply_set() reconoce como String simple; ver ese fichero
// para el resto: obstacle/interactive/enemy/crop, que son Dictionary y se
// editan en JSON crudo más abajo).
const SET_FIELDS = ['name', 'icon', 'terrain', 'item', 'resource', 'description', 'biome_color', 'required_quest_state', 'event_id', 'path'];
// Campos por los que se puede filtrar en `match` (WorldMapBuilder._cell_matches).
const MATCH_FIELDS = ['event_id', 'terrain', 'item', 'resource'];

// Rutinas `builtin` que REALMENTE existen y hacen algo, cableadas en
// `QuestManager.run_world_transform` / `WorldMapBuilder._run_builtin`. Si `current.value.builtin` no está en esta lista, el aviso avisa de
// que el nombre no coincide con ninguna rutina conocida (probable typo, o el
// editor quedó desactualizado tras añadir una rutina nueva en GDScript sin
// añadirla aquí). Mantener sincronizado a mano con esos dos ficheros.
const KNOWN_BUILTINS = {
	dam_opened: 'QuestManager.open_dam() + WorldMapBuilder.apply_dam_opened() — PROCEDURAL de verdad (río/proximidad/bosques calculados en relativo a la presa): no expresable como rules[] simples, se queda en builtin a propósito.',
	cave_cleared: 'WorldMapBuilder.apply_cave_cleared() — solo como fallback: la transformación real en data/world_transforms.json YA usa rules[], esta rutina cableada no se ejecuta mientras existan.',
	monkey_cleared: 'QuestManager._unlock_monkey_bridge() + WorldMapBuilder.apply_monkey_cleared() — solo como fallback: la transformación real en data/world_transforms.json YA usa rules[], esta rutina cableada no se ejecuta mientras existan.',
};

export default {
	name: 'WorldTransformsManager',
	components: { EntityListPanel, EditorToolbar },
	setup() {
		// Catálogo de terrenos, derivado de la colección data-driven `store.worldTerrains`
		// (data/world_terrains/<code>.json). Ver terrainsList() en store.js.
		const TERRAINS = computed(() => terrainsList());
		const col = useCollection({
			tabId: 'worldTransforms',
			dirtyKey: 'worldTransforms',
			collection: () => store.worldTransforms,
			setCollection: (v) => { store.worldTransforms = v; },
			selectedKey: 'selectedWorldTransform',
			clipboardKind: 'worldTransform',
			entityLabel: 'transformación',
			newIdBase: 'nueva_transformacion',
			makeNew: () => ({ desc: '', rules: [{ match: { event_id: '' }, set: { terrain: 'grs' } }] }),
			searchText: (id, o) => id + ' ' + (o?.desc || ''),
			sorts: [{ key: 'id', label: 'ID', get: (id) => id }],
		});
		const current = col.current;

		const isBuiltin = (o) => o && typeof o.builtin === 'string';

		function setDesc(v) { col.edit(() => { current.value.desc = v; }); }
		function toggleBuiltin(on) {
			col.edit(() => {
				const o = current.value;
				if (on) { o.builtin = o.builtin || col.selectedId.value; delete o.rules; }
				else { delete o.builtin; o.rules = o.rules || []; }
			});
		}
		function setBuiltin(v) { col.edit(() => { current.value.builtin = v; }); }

		function addRule() { col.edit(() => { current.value.rules = current.value.rules || []; current.value.rules.push({ match: { event_id: '' }, set: {} }); }); }
		function removeRule(idx) { col.edit(() => { current.value.rules.splice(idx, 1); }); }
		// `match` admite varios criterios simultáneos (TODOS deben cumplirse,
		// ver WorldMapBuilder._cell_matches): event_id/terrain/item/resource
		// (igualdad de texto) + coord ([x,y] exacto), no solo event_id.
		function setMatchField(idx, field, v) {
			col.edit(() => {
				const m = current.value.rules[idx].match = current.value.rules[idx].match || {};
				if (v === '') delete m[field]; else m[field] = v;
			});
		}
		function hasMatchCoord(idx) {
			const m = current.value.rules[idx] && current.value.rules[idx].match;
			return !!(m && Array.isArray(m.coord));
		}
		function toggleMatchCoord(idx, on) {
			col.edit(() => {
				const m = current.value.rules[idx].match = current.value.rules[idx].match || {};
				if (on) m.coord = [0, 0]; else delete m.coord;
			});
		}
		function setMatchCoord(idx, axis, v) {
			col.edit(() => {
				const m = current.value.rules[idx].match;
				if (!m || !Array.isArray(m.coord)) return;
				m.coord[axis] = parseInt(v, 10) || 0;
			});
		}
		function setSet(idx, field, v) {
			col.edit(() => {
				const set = current.value.rules[idx].set = current.value.rules[idx].set || {};
				if (v === '' ) delete set[field]; else set[field] = v;
			});
		}
		// Task 5 (4.2, `set_collision_mask`): tri-estado sobre `set.walkable`
		// (bool) — más legible que escribir a mano el Dictionary `obstacle` en
		// "Opciones avanzadas". Ver WorldMapBuilder.gd::_apply_set caso "walkable".
		function walkableValue(idx) {
			const w = current.value.rules[idx].set && current.value.rules[idx].set.walkable;
			return w === true ? 'true' : (w === false ? 'false' : '');
		}
		function setWalkable(idx, v) {
			col.edit(() => {
				const set = current.value.rules[idx].set = current.value.rules[idx].set || {};
				if (v === '') delete set.walkable; else set.walkable = (v === 'true');
			});
		}
		// Task 5 (4.2): plantillas rápidas para spawn_poi/remove_poi, expresables
		// con la gramática YA existente (coord+event_id) sin ampliar el motor.
		function addSpawnPoiRule() {
			col.edit(() => {
				current.value.rules = current.value.rules || [];
				current.value.rules.push({ match: { coord: [0, 0] }, set: { event_id: 'poi_nuevo' } });
			});
		}
		function addRemovePoiRule() {
			col.edit(() => {
				current.value.rules = current.value.rules || [];
				current.value.rules.push({ match: { event_id: 'poi_a_quitar' }, set: { event_id: '' } });
			});
		}
		// Task 5 (4.2, `trigger_cinematic`): campo a nivel de TRANSFORMACIÓN (no
		// de regla — no pertenece a una celda concreta), que lanza una ESCENA
		// (scenes.json) tras aplicar las reglas. Ver QuestManager.gd
		// run_world_transform() rama genérica / play_cinematic().
		const cinematicIds = computed(() => Object.keys(store.scenes || {}));
		function setCinematic(v) { col.edit(() => { if (v === '') delete current.value.cinematic; else current.value.cinematic = v; }); }
		// Campos avanzados de `set` que son Dictionary en runtime (obstacle/
		// interactive/enemy/crop): se editan como JSON crudo para no tener que
		// modelar cada esquema en un formulario dedicado.
		const ADVANCED_SET_FIELDS = ['obstacle', 'interactive', 'enemy', 'crop'];
		function advancedSetText(idx, field) {
			const v = current.value.rules[idx].set && current.value.rules[idx].set[field];
			return v ? JSON.stringify(v) : '';
		}
		function setAdvancedSet(idx, field, text) {
			col.edit(() => {
				const set = current.value.rules[idx].set = current.value.rules[idx].set || {};
				const trimmed = (text || '').trim();
				if (!trimmed) { delete set[field]; return; }
				try { set[field] = JSON.parse(trimmed); } catch (e) { alert('JSON inválido para "' + field + '": ' + e.message); }
			});
		}

		return {
			store, col, current, isBuiltin, setDesc, toggleBuiltin, setBuiltin, addRule, removeRule,
			setMatchField, hasMatchCoord, toggleMatchCoord, setMatchCoord, setSet,
			walkableValue, setWalkable, addSpawnPoiRule, addRemovePoiRule, cinematicIds, setCinematic,
			ADVANCED_SET_FIELDS, advancedSetText, setAdvancedSet,
			SET_FIELDS, MATCH_FIELDS, TERRAINS, KNOWN_BUILTINS,
		};
	},
	template: `
	<div style="display:flex; flex-direction:column; height:100%; min-height:0; overflow:hidden">
		<!-- Banner informativo superior -->
		<div class="row gap" style="align-items:center; justify-content:space-between; padding:10px 16px; background:rgba(18,21,31,0.6); border-bottom:1px solid var(--line); flex-shrink:0">
			<div class="flex" style="align-items:center; gap:8px">
				<span style="font-size:18px">🌍</span>
				<div>
					<b style="font-size:13px">Transformaciones del Mundo</b>
					<div class="muted" style="font-size:11px">Cambios físicos permanentes en el Mapamundi al avanzar en la historia (abrir presas, desbloquear puentes, despejar cuevas…)</div>
				</div>
			</div>
			<div class="muted mono" style="font-size:11px; background:rgba(255,255,255,0.04); padding:4px 8px; border-radius:4px; max-width:340px; text-align:right">
				Disparador: reward "worldt:id_transformacion" en diálogos/misiones.<br>Excepción: la 🌊 Presa usa el reward especial "dam" (ver "dam_opened" ⚙️ abajo).
			</div>
		</div>

		<!-- Contenedor principal de dos columnas -->
		<div class="manager" style="flex:1; min-height:0; overflow:hidden">
			<entity-list-panel :c="col" search-placeholder="Buscar transformación…" new-label="➕ Nueva transformación">
				<template #row="{ id, o }">
					<span class="ent-icon">{{ o && o.builtin ? '⚙️' : '🌍' }}</span>
					<span class="ent-name" :title="o && o.desc || ''">{{ id }}</span>
					<span class="ent-id mono">{{ o && o.builtin ? 'procedural' : ((o && o.rules && o.rules.length) || 0) + ' reglas' }}</span>
				</template>
			</entity-list-panel>

			<section class="editor-pane scroll" v-if="current" style="overflow-y:auto; height:100%; padding:14px">
				<editor-toolbar :can-undo="col.canUndo.value" :can-redo="col.canRedo.value"
					:can-paste="col.canPaste.value" :has-current="!!current" :dirty="col.dirty.value"
					:saved-text="col.savedText.value"
					@undo="col.undo()" @redo="col.redo()" @copy="col.copy()" @paste="col.paste()"
					@duplicate="col.duplicate()" @remove="col.remove()" @save="col.doSave()"></editor-toolbar>

				<div class="panel" style="margin-bottom:12px; padding:12px; background:rgba(255,255,255,0.02)">
					<div class="form-grid">
						<label>ID
							<input class="input mono" type="text" :value="col.selectedId.value" @change="col.rename($event.target.value)" />
						</label>
						<label class="full">¿Cuándo ocurre? / Descripción narrativa
							<input class="input" type="text" :value="current.desc" @input="setDesc($event.target.value)" placeholder="Al derrotar al jefe de la cueva, o al completar la misión..." />
						</label>
						<label class="full">🎭 Escena al aplicar (opcional — <span class="mono">trigger_cinematic</span>)
							<select class="input" :value="current.cinematic || ''" @change="setCinematic($event.target.value)">
								<option value="">(ninguna)</option>
								<option v-for="c in cinematicIds" :key="c" :value="c">{{ c }}</option>
							</select>
						</label>
					</div>
				</div>

				<label class="flex" style="gap:8px; align-items:center; margin-bottom:12px">
					<input type="checkbox" :checked="isBuiltin(current)" @change="toggleBuiltin($event.target.checked)" />
					<span style="font-size:12px"><b>Transformación Procedural Avanzada (código GDScript)</b> — <i>Reservado SOLO para animaciones cinemáticas de motor irreducibles a reglas declarativas (p. ej. la Presa: geometría calculada en relativo). Para todo lo demás (aparecer/quitar POIs, bloquear/abrir pasos, cambiar terreno o disparar una cinemática) usa las reglas de abajo.</i></span>
				</label>

				<div v-if="isBuiltin(current)" class="panel" style="margin-bottom:12px; padding:12px">
					<label class="full">Nombre de la rutina en el motor:
						<input class="input mono" type="text" :value="current.builtin" @input="setBuiltin($event.target.value)" placeholder="dam_opened" />
					</label>
					<div class="warnbox full" style="margin-top:8px" v-if="KNOWN_BUILTINS[current.builtin]">
						⚙️ Delegada en código: <span class="mono">{{ KNOWN_BUILTINS[current.builtin] }}</span>
					</div>
					<div class="warnbox full" style="margin-top:8px; background:rgba(240,101,95,.1); border-color:rgba(240,101,95,.35); color:var(--err)" v-else>
						⚠️ "{{ current.builtin || '(vacío)' }}" no coincide con ninguna rutina procedural conocida ({{ Object.keys(KNOWN_BUILTINS).join(', ') }}).
					</div>
				</div>

				<template v-else>
					<div class="pane-header" style="margin-bottom:10px">
						<h3 class="sec" style="margin:0">📐 Reglas de Reemplazo en el Mapa ({{ (current.rules && current.rules.length) || 0 }})</h3>
						<div class="row gap">
							<button class="btn primary sm" @click="addRule">➕ Añadir regla de cambio</button>
							<button class="btn secondary sm" @click="addSpawnPoiRule" title="Plantilla: hacer aparecer un POI en una coordenada">🧩 Aparecer POI</button>
							<button class="btn secondary sm" @click="addRemovePoiRule" title="Plantilla: quitar el POI de la casilla que lo tenga">🧩 Quitar POI</button>
						</div>
					</div>

					<div class="skills-list">
						<div class="card panel" style="margin-bottom:12px; padding:14px; border:1px solid rgba(255,255,255,0.12)"
							v-for="(r, idx) in current.rules" :key="idx">
							<div class="flex" style="justify-content:space-between; align-items:center; margin-bottom:10px; border-bottom:1px solid var(--line); padding-bottom:6px">
								<b style="font-size:13px">Regla #{{ idx + 1 }}</b>
								<button class="btn sm ghost err" @click="removeRule(idx)" title="Eliminar regla">🗑️ Eliminar regla</button>
							</div>

							<!-- 1. CASILLAS DIANA -->
							<div style="background:rgba(15,23,42,0.6); padding:10px; border-radius:6px; margin-bottom:12px; border-left:3px solid var(--acc)">
								<div style="font-weight:700; font-size:12px; margin-bottom:8px; color:var(--txt-0)">
									🎯 1. ¿A qué casillas del mapa afecta? (Filtro)
								</div>
								<div class="form-grid">
									<label>Por ID de Evento / POI
										<input class="input mono" type="text" :value="(r.match && r.match.event_id) || ''"
											@input="setMatchField(idx, 'event_id', $event.target.value)" placeholder="ej: poi_monkey_001 o dun_001" />
									</label>
									<label>Por Terreno actual
										<select class="input" :value="(r.match && r.match.terrain) || ''" @change="setMatchField(idx, 'terrain', $event.target.value)">
											<option value="">(cualquiera)</option>
											<option v-for="t in TERRAINS" :key="t.code" :value="t.code">{{ t.label }} ({{ t.code }})</option>
										</select>
									</label>
									<label>Por Objeto / Item actual
										<input class="input mono" type="text" :value="(r.match && r.match.item) || ''"
											@input="setMatchField(idx, 'item', $event.target.value)" placeholder="ej: rock o cueva" />
									</label>
									<label>Por Recurso actual
										<input class="input mono" type="text" :value="(r.match && r.match.resource) || ''"
											@input="setMatchField(idx, 'resource', $event.target.value)" placeholder="ej: forest" />
									</label>
									<div class="full" style="margin-top:6px">
										<label class="check" style="font-size:12px">
											<input type="checkbox" :checked="hasMatchCoord(idx)" @change="toggleMatchCoord(idx, $event.target.checked)" />
											Filtrar por coordenada exacta [X, Y]
										</label>
									</div>
									<template v-if="hasMatchCoord(idx)">
										<label>Coordenada X
											<input class="input num" type="number" step="1" :value="r.match.coord[0]" @input="setMatchCoord(idx, 0, $event.target.value)" />
										</label>
										<label>Coordenada Y
											<input class="input num" type="number" step="1" :value="r.match.coord[1]" @input="setMatchCoord(idx, 1, $event.target.value)" />
										</label>
									</template>
								</div>
							</div>

							<!-- 2. CAMBIOS APLICADOS -->
							<div style="background:rgba(15,23,42,0.6); padding:10px; border-radius:6px; border-left:3px solid #10b981">
								<div style="font-weight:700; font-size:12px; margin-bottom:8px; color:var(--txt-0)">
									✨ 2. ¿Qué cambios se aplican sobre esas casillas? (Nuevos valores)
								</div>
								<div class="form-grid">
									<label>Nuevo Nombre
										<input class="input" type="text" :value="(r.set && r.set.name) || ''"
											@input="setSet(idx, 'name', $event.target.value)" placeholder="(sin cambio)" />
									</label>
									<label>Nuevo icono
										<input class="input f-xs" type="text" :value="(r.set && r.set.icon) || ''"
											@input="setSet(idx, 'icon', $event.target.value)" placeholder="ej: 🌉" />
									</label>
									<label>Nuevo Terreno
										<select class="input" :value="(r.set && r.set.terrain) || ''" @change="setSet(idx, 'terrain', $event.target.value)">
											<option value="">(sin cambio)</option>
											<option v-for="t in TERRAINS" :key="t.code" :value="t.code">{{ t.label }} ({{ t.code }})</option>
										</select>
									</label>
									<label>Nuevo Objeto / Edificio (item)
										<input class="input mono" type="text" :value="(r.set && r.set.item) || ''"
											@input="setSet(idx, 'item', $event.target.value)" placeholder="(dejar vacío para borrar objeto)" />
									</label>
									<label class="full">Nueva Descripción en el mapa
										<input class="input" type="text" :value="(r.set && r.set.description) || ''"
											@input="setSet(idx, 'description', $event.target.value)" placeholder="El monstruo ha caído y el paso está libre..." />
									</label>
									<label>Estado de Misión requerido (required_quest_state)
										<input class="input mono" type="text" :value="(r.set && r.set.required_quest_state) || ''"
											@input="setSet(idx, 'required_quest_state', $event.target.value)" placeholder="(dejar vacío para desbloquear)" />
									</label>
									<label>Color de Bioma
										<input class="input mono" type="text" :value="(r.set && r.set.biome_color) || ''"
											@input="setSet(idx, 'biome_color', $event.target.value)" placeholder="ej: 4a3728" />
									</label>
									<label>ID de POI (event_id) — <span class="mono">spawn_poi</span>/<span class="mono">remove_poi</span>
										<input class="input mono" type="text" :value="(r.set && r.set.event_id) || ''"
											@input="setSet(idx, 'event_id', $event.target.value)" placeholder="poi_nuevo (vacío = quitar POI)" />
									</label>
									<label>Transitable (set_collision_mask)
										<select class="input" :value="walkableValue(idx)" @change="setWalkable(idx, $event.target.value)">
											<option value="">(sin cambio)</option>
											<option value="true">✅ Transitable</option>
											<option value="false">🚫 Bloqueado</option>
										</select>
									</label>
								</div>

								<details style="margin-top:10px">
									<summary class="muted" style="cursor:pointer; font-size:11px">⚙️ Opciones avanzadas (Obstáculo / Objeto interactivo / Enemigos)</summary>
									<div class="form-grid" style="margin-top:6px">
										<label class="full" v-for="f in ADVANCED_SET_FIELDS" :key="f">{{ f }} (JSON, o vacío = sin cambio)
											<input class="input mono" type="text" :value="advancedSetText(idx, f)" @change="setAdvancedSet(idx, f, $event.target.value)" placeholder='{"solid": true}' />
										</label>
									</div>
								</details>
							</div>
						</div>
						<p v-if="!current.rules || !current.rules.length" class="muted">No hay reglas en esta transformación. Pulsa “➕ Añadir regla de cambio”.</p>
					</div>
				</template>
			</section>

			<section class="editor-pane empty" v-else>
				<p class="muted">Selecciona o crea una transformación de mundo.</p>
			</section>
		</div>
	</div>
	`,
};
