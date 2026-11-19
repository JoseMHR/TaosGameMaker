// components/IdsManager.js
// ─────────────────────────────────────────────────────────────────────────────
// Gestor de ids.json: lista con buscador y filtro por tipo, formulario de
// edición (id, tipo, nombre/desc bilingües, icono, npc/kind/stock, bg) y un
// constructor visual del `content` (POIs) para ciudades/aldeas con añadir,
// eliminar y reordenar. Vista previa del fondo si existe en assets.
// ─────────────────────────────────────────────────────────────────────────────
import { computed, ref, watch } from 'https://unpkg.com/vue@3/dist/vue.esm-browser.prod.js';
import { store, markDirty, ID_TYPES, POI_KINDS, visualOptions, getI18n, getI18nFallback, getI18nDisplay, setI18n } from '../store.js';
import { bgCandidates } from '../validator.js';
import * as FS from '../fs.js';
import { useCollection } from '../lib/useCollection.js';
import EntityListPanel from './EntityListPanel.js';
import EditorToolbar from './EditorToolbar.js';
import VnSimulatorModal from './VnSimulatorModal.js';
import VnAssetPicker from './VnAssetPicker.js';
import ConditionEditor from './ConditionEditor.js';
import NpcPoiWizardModal from './NpcPoiWizardModal.js';

export default {
	name: 'IdsManager',
	components: { EntityListPanel, EditorToolbar, VnSimulatorModal, VnAssetPicker, ConditionEditor, NpcPoiWizardModal },
	setup() {
		const npcPoiWizardOpen = ref(false);
		const showAddChild = ref(false);
		const childPick = ref('');
		const newChildId = ref('');
		const bgUrl = ref(null);
		const vnSimOpen = ref(false);

		const col = useCollection({
			tabId: 'ids',
			dirtyKey: 'ids',
			dirtyMap: () => store.dirtyIds,
			collection: () => store.ids,
			setCollection: (v) => { store.ids = v; },
			selectedKey: 'selectedId',
			clipboardKind: 'ids',
			entityLabel: 'entidad',
			// ids es una colección "un fichero por id" (data/ids/<id>.json): al
			// borrar o renombrar hay que borrar también el fichero en disco del id
			// saliente (si no, quedaría huérfano — nunca se reescribe solo).
			onRemove: (id) => FS.deleteCollectionItem('ids', id),
			newIdBase: 'poi_new',
			makeNew: (id) => ({ id, type: 'poi', name: { es: id, en: id } }),
			searchText: (id, o) => id + ' ' + (o.name?.es || '') + ' ' + (o.name?.en || ''),
			filters: [
				{ key: 'type', label: 'Tipo', options: ID_TYPES, get: (o) => o.type },
				{ key: 'poiScope', label: 'POI', options: ['mapamundi', 'interiores'], get: (o) => o.type === 'poi' ? (o.kind ? 'interiores' : 'mapamundi') : '' },
			],
			sorts: [
				{ key: 'name', label: 'Nombre', get: (id, o) => (o.name?.es || id).toLowerCase() },
				{ key: 'id', label: 'ID', get: (id) => id },
				{ key: 'type', label: 'Tipo', get: (id, o) => o.type || '' },
			],
		});
		const current = col.current;
		const isContainer = computed(() => current.value && current.value.type === 'city');

		function ensureBilingual(obj, field) {
			if (!obj[field]) obj[field] = { es: '', en: '' };
			return obj[field];
		}

		function touch() { markDirty('ids', store.selectedId); }

		// ── Campos con creación perezosa de subobjetos ──
		function setName(lang, v) { col.edit(() => { ensureBilingual(current.value, 'name')[lang] = v; }); }
		function setDesc(lang, v) {
			const o = current.value;
			if (!o.desc && !v) return;
			col.edit(() => { ensureBilingual(o, 'desc')[lang] = v; });
		}
		function setField(k, v) {
			col.edit(() => {
				const o = current.value;
				if (v === '' || v == null) delete o[k]; else o[k] = v;
			});
		}
		// Escribe una propiedad dentro de `spec.portal` (creándolo si hace falta). El
		// runtime lee de ahí, p. ej. la disponibilidad por fase del POI (open_phase).
		function setPortalField(k, v) {
			col.edit(() => {
				const o = current.value;
				if (v === '' || v == null || v === 'any') {
					if (o.portal && k in o.portal) {
						delete o.portal[k];
						if (Object.keys(o.portal).length === 0) delete o.portal;
					}
					return;
				}
				if (!o.portal || typeof o.portal !== 'object') o.portal = {};
				o.portal[k] = v;
			});
		}
		const portalOpenPhase = computed(() => current.value?.portal?.open_phase || 'any');
		// Escribe una propiedad dentro de `spec.gate` (creándolo si hace falta). El
		// runtime lo lee para levantar un muro de 3 casillas hacia `dir`: sin `open_when` es PERMANENTE (nunca se cruza caminando — p. ej. las
		// dos "puertas" de una mazmorra con entradas propias, que solo se cruzan
		// atravesándola). Con `open_when` (una condición, ver Design.eval_condition)
		// se abre cuando esa condición se cumple.
		function setGateField(k, v) {
			col.edit(() => {
				const o = current.value;
				if (v === '' || v == null) {
					if (o.gate && k in o.gate) {
						delete o.gate[k];
						if (Object.keys(o.gate).length === 0) delete o.gate;
					}
					return;
				}
				if (!o.gate || typeof o.gate !== 'object') o.gate = {};
				o.gate[k] = v;
			});
		}
		function toggleGate(on) {
			col.edit(() => {
				const o = current.value;
				if (on) { if (!o.gate) o.gate = { dir: 'east' }; }
				else { delete o.gate; }
			});
		}

		const isCinematic = computed(() => current.value?.portal?.view === 'cinematic' || current.value?.interactive?.kind === 'cinematic');
		const cinematicId = computed(() => current.value?.portal?.cinematic_id || current.value?.interactive?.cinematic_id || '');
		const cinematicOptions = computed(() => Object.keys(store.cinematics || {}));

		function setCinematic(active, cineId = '') {
			col.edit(() => {
				const o = current.value;
				if (!active) {
					if (o.portal && o.portal.view === 'cinematic') {
						delete o.portal.view;
						delete o.portal.cinematic_id;
						delete o.portal.label;
						if (Object.keys(o.portal).length === 0) delete o.portal;
					}
					if (o.interactive && o.interactive.kind === 'cinematic') {
						delete o.interactive;
					}
				} else {
					if (!o.portal || typeof o.portal !== 'object') o.portal = {};
					o.portal.view = 'cinematic';
					o.portal.cinematic_id = cineId || cinematicOptions.value[0] || '';
					if (!o.portal.label) o.portal.label = '🎬  Ver Cinemática';
				}
			});
		}

		function setCinematicId(cineId) {
			col.edit(() => {
				const o = current.value;
				if (!o.portal || typeof o.portal !== 'object') o.portal = {};
				o.portal.view = 'cinematic';
				o.portal.cinematic_id = cineId;
			});
		}

		function setCinematicLabel(label) {
			col.edit(() => {
				const o = current.value;
				if (!o.portal || typeof o.portal !== 'object') o.portal = {};
				o.portal.label = label;
			});
		}

		function setType(v) {
			col.edit(() => {
				current.value.type = v;
				// Si el visual actual ya no es válido para el nuevo tipo, se limpia
				// (el motor volverá al aspecto por defecto derivado del tipo).
				const opts = visualOptions(v).map(o => o.value);
				if (current.value.visual && !opts.includes(current.value.visual)) delete current.value.visual;
			});
		}
		function setVisual(v) {
			col.edit(() => {
				if (v) current.value.visual = v; else delete current.value.visual;
			});
		}
		const currentVisuals = computed(() => current.value ? visualOptions(current.value.type) : []);

		// bg como [r,g,b]
		const bgArr = computed(() => current.value?.bg || null);
		function setBg(i, v) {
			col.edit(() => {
				const o = current.value;
				if (!o.bg) o.bg = [0, 0, 0];
				o.bg[i] = parseFloat(v) || 0;
			});
		}
		function toggleBg() {
			col.edit(() => {
				const o = current.value;
				if (o.bg) delete o.bg; else o.bg = [0.06, 0.045, 0.1];
			});
		}

		// ── Content builder ──
		function moveChild(idx, dir) {
			const arr = current.value.content;
			const j = idx + dir;
			if (j < 0 || j >= arr.length) return;
			[arr[idx], arr[j]] = [arr[j], arr[idx]];
			touch();
		}
		function removeChild(idx) { col.edit(() => { current.value.content.splice(idx, 1); }); }
		function ensureContent() { if (!current.value.content) current.value.content = []; }
		function addExistingChild() {
			if (!childPick.value) return;
			col.edit(() => {
				ensureContent();
				if (!current.value.content.includes(childPick.value)) current.value.content.push(childPick.value);
			});
			childPick.value = '';
			showAddChild.value = false;
		}
		function createAndAddChild() {
			const id = newChildId.value.trim();
			if (!id) return;
			if (store.ids[id]) { store.error = 'Ya existe un id "' + id + '".'; return; }
			col.snapshot();
			store.ids[id] = { id, type: 'poi', name: { es: id, en: id }, kind: 'npc' };
			ensureContent();
			current.value.content.push(id);
			touch();
			newChildId.value = '';
			showAddChild.value = false;
			store.selectedId = id; // saltar al nuevo POI para completarlo
		}
		function childDef(id) { return store.ids?.[id] || null; }

		// Asistente "este POI tiene NPC": si el campo `npc` está vacío, lo rellena
		// con el propio id del POI (convención habitual en data/ids/*.json); si
		// ese NPC no existe todavía en npcs.json, lo crea con el mismo esqueleto
		// mínimo que "+ Nuevo NPC" en NpcEditor.js (_meta + un mensaje inicial),
		// y salta directamente a completarlo — cierra en un clic el hueco de
		// "elegir POI → ¿tiene NPC? → crear su diálogo" (Task 1 Fase 4).
		//
		// IMPORTANTE (aclara la confusión "¿cómo hago un POI de solo fondo +
		// texto?"): el campo "Descripción" de arriba NO se muestra nunca al
		// jugador — es solo para uso interno del editor. Lo que SÍ ve el
		// jugador es el texto del NPC vinculado aquí abajo. Un "lugar simple"
		// (fondo + texto, sin personaje) es sencillamente un NPC SIN avatar con
		// un único mensaje: así están hechos, p. ej., la Presa Abandonada
		// (poi_presa_001) o el Puente del Mono (poi_monkey_001). Por eso, si ya
		// escribiste una Descripción, este botón la reutiliza como primer
		// mensaje del NPC para no tener que escribirla dos veces.
		function linkOrCreateNpc() {
			const o = current.value;
			if (!o) return;
			const npcId = (o.npc || o.id || '').trim();
			if (!npcId) return;
			if (!o.npc) { col.edit(() => { o.npc = npcId; }); }
			if (!store.npcs[npcId]) {
				store.npcs[npcId] = {
					_meta: { type: 'meta', text: { es: o.name?.es || npcId, en: o.name?.en || npcId }, next: [], reward: '' },
					[npcId + '_1']: { type: 'message', text: { es: o.desc?.es || '', en: o.desc?.en || '' }, next: ['close'], reward: '' },
				};
				markDirty('npcs', npcId);
			}
			store.selectedNpc = npcId;
			store.activeTab = 'npcs';
		}

		function createTownTemplate() {
			let n = 1;
			while (store.ids && store.ids['city_' + String(n).padStart(3, '0')]) n++;
			const cityId = 'city_' + String(n).padStart(3, '0');
			const innId = 'poi_' + cityId + '_inn';
			const shopId = 'poi_' + cityId + '_shop';
			const boardId = 'poi_' + cityId + '_board';
			const tavernId = 'poi_' + cityId + '_tavern';

			col.snapshot();
			store.ids[cityId] = {
				id: cityId,
				type: 'city',
				name: { es: 'Nueva Ciudad ' + n, en: 'New City ' + n },
				icon: '🏛️',
				content: [innId, shopId, boardId, tavernId],
			};
			markDirty('ids', cityId);

			store.ids[innId] = {
				id: innId,
				type: 'poi',
				kind: 'house',
				name: { es: 'Posada del Descanso', en: 'Rest Inn' },
				icon: '🛏️',
				npc: innId,
			};
			markDirty('ids', innId);

			store.ids[shopId] = {
				id: shopId,
				type: 'poi',
				kind: 'shop',
				name: { es: 'Tienda de Suministros', en: 'General Store' },
				icon: '🏪',
				stock: 'default',
				npc: shopId,
			};
			markDirty('ids', shopId);

			store.ids[boardId] = {
				id: boardId,
				type: 'poi',
				kind: 'board',
				name: { es: 'Tablón de Encargos', en: 'Notice Board' },
				icon: '📜',
			};
			markDirty('ids', boardId);

			store.ids[tavernId] = {
				id: tavernId,
				type: 'poi',
				kind: 'tavern',
				name: { es: 'Taberna El Ancla', en: 'The Anchor Tavern' },
				icon: '🍺',
				npc: tavernId,
			};
			markDirty('ids', tavernId);

			store.selectedId = cityId;
		}

		function addPresence() {
			col.edit(() => {
				if (!current.value.presences) current.value.presences = [];
				current.value.presences.push({
					condition: 'default',
					actor: current.value.npc || col.selectedId.value,
					entry_node: '',
				});
			});
		}

		function removePresence(idx) {
			col.edit(() => {
				if (current.value.presences) {
					current.value.presences.splice(idx, 1);
				}
			});
		}

		function updatePresence(idx, key, val) {
			col.edit(() => {
				if (current.value.presences && current.value.presences[idx]) {
					current.value.presences[idx][key] = val;
				}
			});
		}

		const npcOptions = computed(() => {
			return Object.keys(store.npcs || {}).sort();
		});

		const poiSceneData = computed(() => {
			if (!current.value) return null;
			const o = current.value;
			const pres = (o.presences && o.presences[0]) || { actor: o.npc || col.selectedId.value };
			const actorId = pres.actor || o.npc || col.selectedId.value;
			const raw = store.npcs?.[actorId] || {};
			
			const sceneNodes = {};
			for (const [k, v] of Object.entries(raw)) {
				if (k === '_meta') continue;
				const nextList = v.next || [];
				if (nextList.length > 1) {
					sceneNodes[k] = {
						kind: 'choice',
						prompt: v.text,
						options: nextList.map(target => ({
							text: raw[target]?.text || { es: 'Opción: ' + target, en: 'Option: ' + target },
							to: target,
						})),
					};
				} else {
					sceneNodes[k] = {
						kind: 'say',
						speaker: { es: raw._meta?.text?.es || actorId, en: raw._meta?.text?.en || actorId },
						portrait: 'npc_' + actorId + '.png',
						text: v.text,
						next: nextList[0] || 'end',
					};
				}
			}

			return {
				meta: {
					title: { es: o.name?.es || col.selectedId.value, en: o.name?.en || col.selectedId.value },
					bg: o.bg || 'bg_building_house_001.jpg',
					music: o.music || 'bgm_wasteland_ambient.ogg',
				},
				entry: pres.entry_node || Object.keys(sceneNodes)[0] || 'n1',
				nodes: sceneNodes,
			};
		});

		function getIdRowThumb(id, o) {
			if (!o) return null;
			if (o.npc) {
				const base = o.npc.toLowerCase().replace(/\.png$/, '');
				const f = base.startsWith('npc_') ? base + '.png' : 'npc_' + base + '.png';
				return `/api/assets/npc/${encodeURIComponent(f)}`;
			}
			if (o.bg) {
				const f = Array.isArray(o.bg) ? o.bg[0] : o.bg;
				if (f) return `/api/assets/bg/${encodeURIComponent(f)}`;
			}
			if (o.type === 'dungeon' && store.dungeons?.[id]?.boss) {
				const boss = store.dungeons[id].boss;
				return `/api/assets/enemy/${encodeURIComponent(boss + '.png')}`;
			}
			return null;
		}

		return {
			store, ID_TYPES, POI_KINDS, col, npcPoiWizardOpen,
			current, isContainer,
			setName, setDesc, setField, setType, setVisual, currentVisuals,
			setPortalField, portalOpenPhase, setGateField, toggleGate,
			bgArr, setBg, toggleBg,
			moveChild, removeChild, childDef,
			showAddChild, childPick, newChildId, addExistingChild, createAndAddChild,
			bgUrl, linkOrCreateNpc, createTownTemplate, getIdRowThumb,
			vnSimOpen, addPresence, removePresence, updatePresence, npcOptions, poiSceneData,
			isCinematic, cinematicId, cinematicOptions, setCinematic, setCinematicId, setCinematicLabel,
			getI18n, getI18nFallback, getI18nDisplay, setI18n,
		};
	},
	template: `
	<div class="ids-layout">
		<!-- Lista común con miniaturas reales -->
		<entity-list-panel :c="col" search-placeholder="Buscar por id o nombre…">
			<template #row="{ id, o }">
				<img v-if="getIdRowThumb(id, o)" :src="getIdRowThumb(id, o)" class="ent-thumb" alt=""
					@error="e => { e.target.style.display='none'; if (e.target.nextElementSibling) e.target.nextElementSibling.style.display='inline-block'; }" />
				<span class="ent-icon" :style="{ display: getIdRowThumb(id, o) ? 'none' : 'inline-block' }">{{ o && o.icon || '📍' }}</span>
				<span class="ent-name">{{ (o && o.name && (o.name[store.currentLang] || o.name.es || o.name.en)) || id }}</span>
				<span class="ent-id mono">{{ id }}</span>
			</template>
			<template #extra-actions>
				<button class="btn secondary sm" @click="npcPoiWizardOpen=true">🧙 Asistente PNJ+POI</button>
			</template>
		</entity-list-panel>
		<npc-poi-wizard-modal :open="npcPoiWizardOpen" @close="npcPoiWizardOpen=false" @created="npcPoiWizardOpen=false"></npc-poi-wizard-modal>

		<!-- Editor -->
		<div class="col scroll" style="overflow-y:auto; height:100%; min-width:0">
			<div v-if="!current" class="panel empty" style="margin:0">Selecciona o crea una entidad.</div>
			<div v-else class="editor-scroll">
				<div class="row gap" style="align-items:center; justify-content:space-between; margin-bottom:8px">
					<editor-toolbar :can-undo="col.canUndo.value" :can-redo="col.canRedo.value"
						:can-paste="col.canPaste.value" :has-current="!!current" :dirty="col.dirty.value"
						:saved-text="col.savedText.value"
						@undo="col.undo()" @redo="col.redo()" @copy="col.copy()" @paste="col.paste()"
						@duplicate="col.duplicate()" @remove="col.remove()" @save="col.doSave()"></editor-toolbar>
					<button v-if="current.type==='poi'" class="btn primary sm" @click="vnSimOpen=true" style="font-weight:700" title="Probar el POI con su fondo y actor en el emulador de Novela Visual">🎬 Probar en Novela Visual</button>
				</div>
				<div class="section panel">
					<div class="sh"><span style="font-size:22px">{{ current.icon || '📍' }}</span>
						<input class="mono id-rename" :value="col.selectedId.value" @change="col.rename($event.target.value)" title="ID (clave)" />
						<span class="type-tag">{{ current.type }}</span>
						<span class="grow"></span>
					</div>
					<div class="form-grid">
						<div>
							<label>Tipo</label>
							<select :value="current.type" @change="setType($event.target.value)">
								<option v-for="t in ID_TYPES" :key="t" :value="t">{{ t }}</option>
							</select>
						</div>
						<div>
							<label>Icono</label>
							<input class="f-xs" :value="current.icon || ''" @input="setField('icon', $event.target.value)" placeholder="🏰" />
						</div>
						<div>
							<label>Nombre [{{ store.currentLang.toUpperCase() }}]</label>
							<input :value="getI18n(current.name)" :placeholder="getI18nFallback(current.name) || 'Nombre del lugar...'" @input="setName(store.currentLang, $event.target.value)" />
						</div>
						<div class="full">
							<label>Descripción [{{ store.currentLang.toUpperCase() }}]</label>
							<textarea :value="getI18n(current.desc)" :placeholder="getI18nFallback(current.desc) || 'Descripción del lugar...'" @input="setDesc(store.currentLang, $event.target.value)"></textarea>
						</div>
						<p v-if="current.type==='poi'" class="muted sm full" style="margin-top:-4px">
							ℹ️ Esta descripción es solo para uso INTERNO del editor (buscador, listados) — el jugador
							<u>nunca</u> la ve en el juego. Para que un texto aparezca en pantalla al visitar el POI,
							escríbelo en el <b>NPC / diálogo</b> de la sección "Vínculos" (más abajo).
						</p>
					</div>
				</div>

				<!-- 🎬 Escenografía y Novela Visual (Fondo + Música) -->
				<div v-if="current.type==='poi' || current.type==='city'" class="section panel">
					<div class="sh">🎬 Escenografía de Novela Visual (Fondo & Música)</div>
					<div class="form-grid" style="margin-top:10px">
						<label>Fondo de Escena (Background)
							<vn-asset-picker kind="bg" :model-value="current.bg" @update:model-value="setField('bg', $event)"></vn-asset-picker>
						</label>
						<label>Música Ambiental (BGM)
							<vn-asset-picker kind="audio" :model-value="current.music" @update:model-value="setField('music', $event)"></vn-asset-picker>
						</label>
					</div>
					<div v-if="current.bg && typeof current.bg === 'string'" style="margin-top:12px; position:relative; border-radius:10px; overflow:hidden; border:1px solid rgba(255,255,255,0.15); box-shadow:0 8px 24px rgba(0,0,0,0.5); max-height:220px; background:#000;">
						<img :src="'/assets/vn/bg/' + current.bg" style="width:100%; height:200px; object-fit:cover; display:block;" alt="Vista previa del fondo" />
						<div style="position:absolute; bottom:0; left:0; right:0; padding:8px 14px; background:linear-gradient(to top, rgba(0,0,0,0.85), transparent); display:flex; justify-content:space-between; align-items:center;">
							<span class="mono" style="font-size:12px; color:#fff; font-weight:600;">🖼️ {{ current.bg }}</span>
							<span class="badge" style="font-size:11px; background:rgba(255,255,255,0.15); color:#fff;">Vista previa de fondo (16:9)</span>
						</div>
					</div>
				</div>

				<!-- 👥 Presencias Condicionales de Personajes -->
				<div v-if="current.type==='poi'" class="section panel">
					<div class="sh">
						<span>👥 Presencias de Personajes y Reglas</span>
						<span class="grow"></span>
						<button class="btn sm secondary" @click="addPresence">➕ Añadir Regla</button>
					</div>
					<div class="muted" style="margin-bottom:8px; font-size:12px">
						Define qué personaje aparece en este lugar según las condiciones del juego (se evalúan en orden de arriba a abajo).
					</div>

					<div v-if="!(current.presences && current.presences.length)" class="empty" style="padding:10px">
						Sin reglas condicionales. El POI usará el NPC configurado por defecto.
					</div>

					<div v-for="(p, pidx) in (current.presences || [])" :key="pidx" class="card panel" style="padding:10px; margin-top:8px; border:1px solid rgba(255,255,255,0.1)">
						<div class="flex" style="justify-content:space-between; align-items:center">
							<b class="mono" style="font-size:12px">Regla #{{ pidx + 1 }}</b>
							<button class="btn xs danger" @click="removePresence(pidx)">🗑️</button>
						</div>
						<div class="form-grid" style="margin-top:6px">
							<div class="full">
								<label>Condición de activación</label>
								<condition-editor :model-value="p.condition || ''" @update:model-value="updatePresence(pidx, 'condition', $event)"></condition-editor>
							</div>
							<label>Actor / Personaje que aparece
								<select class="input" :value="p.actor" @change="updatePresence(pidx, 'actor', $event.target.value)">
									<option value="">(ninguno / lugar vacío)</option>
									<option v-for="npc in npcOptions" :key="npc" :value="npc">{{ npc }} — {{ store.npcs[npc]?._meta?.text?.es || npc }}</option>
								</select>
							</label>
							<label>Nodo de Entrada (opcional)
								<input class="input mono" :value="p.entry_node" @input="updatePresence(pidx, 'entry_node', $event.target.value)" placeholder="inicio_dialogo" />
							</label>
						</div>
					</div>
				</div>

				<!-- Aspecto visual en el mundo -->
				<div v-if="currentVisuals.length" class="section panel">
					<div class="sh">🎭 Aspecto en el mundo</div>
					<div class="muted" style="margin-bottom:8px">Elige con qué maqueta se dibuja esta entidad en el mapa 3D, independientemente de su tipo lógico.</div>
					<div class="form-grid">
						<div>
							<label>Visual (maqueta)</label>
							<select :value="current.visual || ''" @change="setVisual($event.target.value)">
								<option value="">Por defecto ({{ current.type }})</option>
								<option v-for="v in currentVisuals" :key="v.value" :value="v.value">{{ v.label }}</option>
							</select>
						</div>
					</div>
				</div>

				<!-- Entradas múltiples / muro permanente -->
				<div v-if="current.type==='dungeon' && store.expertMode" class="section panel">
					<div class="sh">🚪 Entrada de mazmorra y muro <span class="muted" style="font-weight:400">(experto)</span></div>
					<p class="muted sm">Para una mazmorra con 2+ "puertas" en el mapamundi (p. ej. un túnel con boca oeste y este que apuntan a la MISMA mazmorra): crea un id distinto por puerta (este es uno de ellos) y rellena aquí a qué mazmorra real abre y qué entrada usa dentro de ella (debe coincidir con una "Entrada nombrada" de esa mazmorra, pestaña 🏰 Mazmorras).</p>
					<div class="form-grid">
						<div>
							<label>Mazmorra real (event_id, si es distinto de este id)</label>
							<input :value="current.portal?.event_id || ''" @change="setPortalField('event_id', $event.target.value)" :placeholder="col.selectedId.value" />
						</div>
						<div>
							<label>Entrada (nombre del portal dentro de la mazmorra)</label>
							<input :value="current.portal?.entry || ''" @change="setPortalField('entry', $event.target.value)" placeholder="west" />
						</div>
					</div>
					<label class="chkline"><input type="checkbox" :checked="!!current.gate" @change="toggleGate($event.target.checked)"> Muro permanente hacia una dirección (no se puede cruzar caminando)</label>
					<div v-if="current.gate" class="form-grid">
						<div>
							<label>Dirección bloqueada</label>
							<select :value="current.gate.dir || 'east'" @change="setGateField('dir', $event.target.value)">
								<option value="east">Este →</option>
								<option value="west">← Oeste</option>
								<option value="north">↑ Norte</option>
								<option value="south">↓ Sur</option>
							</select>
						</div>
					</div>
					<p class="muted sm">Sin condición, el muro es PERMANENTE (nunca se cruza caminando en esa dirección). Coloca dos entidades-puerta contiguas con muros hacia direcciones opuestas para sellar el paso por ambos lados.</p>
				</div>

				<!-- Campos específicos -->
				<div class="section panel">
					<div class="sh">Vínculos</div>
					<p v-if="current.type==='poi'" class="muted sm" style="margin-top:-2px">
						Este es el texto que SÍ ve el jugador. ¿Solo quieres un lugar con fondo + un texto
						descriptivo, sin ningún personaje con retrato (p. ej. una vista panorámica o unas ruinas)?
						No hace falta un editor aparte: pulsa el botón, se crea un NPC "invisible" (sin retrato) con
						un único mensaje — reutiliza el texto de la Descripción de arriba si ya lo escribiste — y se
						abre listo para revisar en la pestaña 🕸️ NPCs. Así están hechos, por ejemplo, la Presa
						Abandonada o el Puente del Mono.
					</p>
					<div class="form-grid">
						<div>
							<label>NPC / diálogo por defecto</label>
							<div class="flex">
								<input :value="current.npc || ''" @input="setField('npc', $event.target.value)" placeholder="p.ej. house_001" />
								<button v-if="current.npc && store.npcs[current.npc]" class="btn sm ghost" @click="store.selectedNpc=current.npc; store.activeTab='npcs'" title="Ir al NPC">→</button>
								<button v-else class="btn sm secondary" @click="linkOrCreateNpc" title="Si el campo está vacío usa el id del POI; crea el NPC (sin retrato) usando la Descripción como texto, y abre su editor">
									{{ current.npc ? '✚ Crear diálogo' : '✚ Crear lugar simple (sin NPC visible)' }}
								</button>
							</div>
						</div>
						<div>
							<label>Kind (POI)</label>
							<select :value="current.kind || ''" @change="setField('kind', $event.target.value)">
								<option v-for="k in POI_KINDS" :key="k" :value="k">{{ k || '—' }}</option>
							</select>
						</div>
						<div>
							<label title="Cuándo está disponible este POI según el ciclo día/noche. Las tiendas suelen abrir solo de día.">🌗 Disponibilidad (día/noche)</label>
							<select :value="portalOpenPhase" @change="setPortalField('open_phase', $event.target.value)">
								<option value="any">Siempre (día y noche)</option>
								<option value="day">☀️ Solo de día</option>
								<option value="night">🌙 Solo de noche</option>
							</select>
						</div>
						<div>
							<label>Stock (tienda)</label>
							<input :value="current.stock || ''" @input="setField('stock', $event.target.value)" placeholder="imperial / desert…" />
						</div>

						<div class="full" style="margin-top:10px; padding:12px; background:var(--bg-2); border:1px solid var(--line); border-radius:8px">
							<div class="row gap" style="align-items:center; margin-bottom:8px">
								<span style="font-weight:700; font-size:12.5px">🎬 Cinemática al interactuar</span>
								<label class="chkline" style="margin-left:auto; margin-bottom:0">
									<input type="checkbox" :checked="isCinematic" @change="setCinematic($event.target.checked, cinematicId)"> Activar reproducción de cinemática
								</label>
							</div>
							<div v-if="isCinematic" class="form-grid" style="margin-top:8px">
								<div>
									<label>Cinemática a reproducir</label>
									<div class="flex" style="gap:6px">
										<select class="input" :value="cinematicId" @change="setCinematicId($event.target.value)">
											<option value="">— Seleccionar cinemática —</option>
											<option v-for="cid in cinematicOptions" :key="cid" :value="cid">
												🎬 {{ store.cinematics?.[cid]?.title?.[store.currentLang] || store.cinematics?.[cid]?.title?.es || cid }} ({{ cid }})
											</option>
										</select>
										<button v-if="cinematicId && store.cinematics?.[cinematicId]" class="btn sm ghost"
											@click="store.selectedCinematic=cinematicId; store.activeTab='cinematics'" title="Ir al editor de esta cinemática">→</button>
									</div>
								</div>
								<div>
									<label>Texto del botón en el Mapamundi</label>
									<input class="input" type="text" :value="current.portal?.label || ''" placeholder="🎬  Ver Cinemática"
										@input="setCinematicLabel($event.target.value)" />
								</div>
							</div>
							<p v-if="isCinematic" class="muted sm" style="margin-top:6px; margin-bottom:0">
								Al tocar este elemento en el mapamundi, se reproducirá el carrusel de diapositivas de la cinemática seleccionada y, al terminar, el jugador volverá exactamente al punto donde estaba.
							</p>
						</div>
					</div>
				</div>

				<!-- Content builder -->
				<div v-if="isContainer" class="section panel">
					<div class="sh">Edificios / POIs de la ciudad
						<span class="grow"></span>
						<button class="btn sm primary" @click="showAddChild=true">+ Añadir edificio</button></div>
					<div class="muted" style="margin-bottom:8px">Orden = orden de los botones en el menú del lugar.</div>
					<div v-if="!current.content || !current.content.length" class="empty">Sin edificios. Añade el primero.</div>
					<div v-for="(child, idx) in (current.content || [])" :key="idx" class="content-row">
						<span class="grip">⋮⋮</span>
						<span style="font-size:16px">{{ childDef(child)?.icon || (store.ids[child] ? '📍' : '⚠️') }}</span>
						<span class="cr-main">
							<div class="t">{{ childDef(child)?.name?.es || child }}</div>
							<div class="s mono">{{ child }} {{ !store.ids[child] ? '· NO EXISTE' : '' }}</div>
						</span>
						<button class="btn sm ghost" @click="store.selectedId=child" title="Editar">✎</button>
						<span class="arrows">
							<button class="btn sm ghost" @click="moveChild(idx,-1)" :disabled="idx===0">▲</button>
							<button class="btn sm ghost" @click="moveChild(idx,1)" :disabled="idx===current.content.length-1">▼</button>
						</span>
						<button class="btn sm danger" @click="removeChild(idx)">✕</button>
					</div>
				</div>
			</div>
		</div>

		<!-- Modal: añadir edificio -->
		<div v-if="showAddChild" class="modal-back" @click.self="showAddChild=false">
			<div class="modal">
				<h3>Añadir edificio / POI</h3>
				<label>Elegir uno existente</label>
				<select v-model="childPick">
					<option value="">— selecciona —</option>
					<option v-for="o in Object.values(store.ids).filter(o=>o.type==='poi')" :key="o.id" :value="o.id">
						{{ o.icon || '📍' }} {{ o.name?.es || o.id }} — {{ o.id }}
					</option>
				</select>
				<div class="row" style="justify-content:flex-start; margin-top:8px">
					<button class="btn sm primary" @click="addExistingChild" :disabled="!childPick">Añadir seleccionado</button>
				</div>
				<hr style="border-color:var(--line); margin:16px 0" />
				<label>…o crear uno nuevo</label>
				<input v-model="newChildId" placeholder="nuevo id de POI" @keyup.enter="createAndAddChild" />
				<div class="row">
					<button class="btn ghost" @click="showAddChild=false">Cancelar</button>
					<button class="btn primary" @click="createAndAddChild" :disabled="!newChildId.trim()">Crear y añadir</button>
				</div>
			</div>
		</div>

		<!-- SIMULADOR NOVELA VISUAL PARA POI -->
		<vn-simulator-modal v-if="current" :open="vnSimOpen" :scene="poiSceneData" :scene-id="col.selectedId.value"
			@close="vnSimOpen=false"></vn-simulator-modal>
	</div>
	`,
};
