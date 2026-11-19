// components/EventsManager.js
// ─────────────────────────────────────────────────────────────────────────────
// Pestaña ⭐ MISIONES / EVENTOS (Tarea 5). Edita dos ficheros data-driven:
//
//   · events.json  → colección { event_id: { desc?, condition?, actions:[token] } }
//     Se gestiona con `useCollection` (CRUD, undo/redo, copiar/pegar, autosave,
//     búsqueda) igual que el resto de editores. Las acciones reutilizan
//     `RewardEditor` (mini-lenguaje de Design.gd) puenteando array ↔ string ";".
//
//   · quests.json  → documento único { order:[estado], combat_victory:{enemy:{event}} }
//     Panel dedicado: orden monotónico de la questline (añadir/quitar/reordenar) y
//     hooks de victoria en combate (enemigo → evento).
// ─────────────────────────────────────────────────────────────────────────────
import { ref, computed } from 'https://unpkg.com/vue@3/dist/vue.esm-browser.prod.js';
import { store, markDirty, save, CONDITION_SNIPPETS } from '../store.js';
import { useCollection } from '../lib/useCollection.js';
import { useDocumentHistory } from '../lib/useDocumentHistory.js';
import EntityListPanel from './EntityListPanel.js';
import EditorToolbar from './EditorToolbar.js';
import RewardEditor from './RewardEditor.js';

export default {
	name: 'EventsManager',
	components: { EntityListPanel, EditorToolbar, RewardEditor },
	setup() {
		const view = ref('events'); // 'events' | 'quest'

		// ── EVENTOS (colección) ───────────────────────────────────────────────
		const col = useCollection({
			tabId: 'events',
			dirtyKey: 'events',
			collection: () => store.events,
			setCollection: (v) => { store.events = v; },
			selectedKey: 'selectedEvent',
			clipboardKind: 'event',
			entityLabel: 'evento',
			newIdBase: 'event_new',
			makeNew: () => ({ desc: '', condition: '', actions: [] }),
			searchText: (id, o) => id + ' ' + (o.desc || ''),
			sorts: [{ key: 'id', label: 'ID', get: (id) => id }],
		});
		const current = col.current;

		function setField(k, v) {
			col.edit(() => { if (v === '' || v == null) delete current.value[k]; else current.value[k] = v; });
		}

		// Puente array ↔ string ";" para reutilizar RewardEditor sin duplicar UI.
		const actionsStr = computed({
			get: () => Array.isArray(current.value?.actions) ? current.value.actions.join(';') : '',
			set: (s) => col.edit(() => {
				current.value.actions = String(s || '').split(';').map(t => t.trim()).filter(Boolean);
			}),
		});

		function addSnippet(sn) {
			const prev = current.value.condition || '';
			setField('condition', prev ? prev + ' and ' + sn : sn);
		}

		// ── MISIÓN (quests.json, documento único) ─────────────────────────────
		const newState = ref('');
		const order = computed(() => (store.quests?.order) || []);
		const combatVictory = computed(() => (store.quests?.combat_victory) || {});

		function qtouch() { markDirty('quests'); }
		function ensureQuests() {
			if (!store.quests) store.quests = { order: [], combat_victory: {} };
			if (!Array.isArray(store.quests.order)) store.quests.order = [];
			if (!store.quests.combat_victory || typeof store.quests.combat_victory !== 'object') store.quests.combat_victory = {};
		}
		ensureQuests();
		// Task 5 (1.3): historial de deshacer/rehacer. Este subpanel edita el MISMO
		// documento (store.quests) que QuestsManager.js (tabId "quests"); aquí se
		// escucha con tabId "events" porque es la pestaña activa cuando se usa desde
		// este subview "⭐ Misión".
		const qhist = useDocumentHistory({ tabId: 'events', getDoc: () => store.quests, setDoc: (v) => { store.quests = v; qtouch(); } });
		function qedit(fn) { qhist.edit(fn); qtouch(); }
		function addState() {
			const s = newState.value.trim();
			if (!s) return;
			ensureQuests();
			if (store.quests.order.includes(s)) { store.error = 'El estado "' + s + '" ya está en el orden.'; return; }
			qedit(() => { store.quests.order.push(s); });
			newState.value = '';
		}
		function removeState(i) { ensureQuests(); qedit(() => { store.quests.order.splice(i, 1); }); }
		function moveState(i, d) {
			ensureQuests();
			const j = i + d;
			if (j < 0 || j >= store.quests.order.length) return;
			qedit(() => { const o = store.quests.order; [o[i], o[j]] = [o[j], o[i]]; });
		}

		const newHookEnemy = ref('');
		function addHook() {
			const e = newHookEnemy.value.trim();
			if (!e) return;
			ensureQuests();
			if (store.quests.combat_victory[e]) { store.error = 'Ya hay un hook para "' + e + '".'; return; }
			qedit(() => { store.quests.combat_victory[e] = { event: '' }; });
			newHookEnemy.value = '';
		}
		function setHookEvent(enemy, ev) { ensureQuests(); qedit(() => { store.quests.combat_victory[enemy] = { event: ev }; }); }
		function removeHook(enemy) { ensureQuests(); qedit(() => { delete store.quests.combat_victory[enemy]; }); }
		function saveQuests() { save(false); }

		const eventIds = computed(() => Object.keys(store.events || {}));
		const enemyIds = computed(() => Object.keys(store.enemies || {}));
		const questsDirty = computed(() => !!store.dirty.quests);

		return {
			store, view, col, current, setField, actionsStr, addSnippet, CONDITION_SNIPPETS,
			newState, order, combatVictory, addState, removeState, moveState,
			newHookEnemy, addHook, setHookEvent, removeHook, saveQuests,
			eventIds, enemyIds, questsDirty,
			canUndoQuest: qhist.canUndo, canRedoQuest: qhist.canRedo, undoQuest: qhist.undo, redoQuest: qhist.redo,
		};
	},
	template: `
	<div>
		<div class="subtabs">
			<button :class="{ active: view==='events' }" @click="view='events'">⚙️ Eventos ({{ eventIds.length }})</button>
			<button :class="{ active: view==='quest' }" @click="view='quest'">⭐ Misión (orden + combate)</button>
		</div>

		<!-- ══ EVENTOS ══ -->
		<div v-show="view==='events'" class="manager">
			<entity-list-panel :c="col" search-placeholder="Buscar evento…" new-label="＋ Nuevo evento">
				<template #row="{ id, o }">
					<span class="ent-name">{{ id }}</span>
					<span class="ent-id mono">{{ (o.actions||[]).length }} acc.</span>
				</template>
			</entity-list-panel>

			<section class="editor-pane" v-if="current">
				<editor-toolbar :can-undo="col.canUndo.value" :can-redo="col.canRedo.value"
					:can-paste="col.canPaste.value" :has-current="!!current" :dirty="col.dirty.value"
					:saved-text="col.savedText.value"
					@undo="col.undo()" @redo="col.redo()" @copy="col.copy()" @paste="col.paste()"
					@duplicate="col.duplicate()" @remove="col.remove()" @save="col.doSave()"></editor-toolbar>

				<div class="form-grid">
					<label>ID <input class="input mono" :value="col.selectedId.value" @change="col.rename($event.target.value)" /></label>
					<label>Descripción <input class="input" :value="current.desc" @input="setField('desc',$event.target.value)" placeholder="Para qué sirve este evento" /></label>
				</div>

				<template v-if="store.expertMode">
				<h3 class="sec">🧪 Condición <span class="muted" style="font-weight:400">(experto)</span></h3>
				<label class="full">
					<input class="input mono" :value="current.condition" @input="setField('condition',$event.target.value)"
						placeholder='p. ej. gflag("dam_opened") and no_item("banana")' />
				</label>
				<div class="flex" style="flex-wrap:wrap; gap:5px; margin-top:6px">
					<button v-for="sn in CONDITION_SNIPPETS" :key="sn" class="btn sm ghost mono" @click="addSnippet(sn)">+ {{ sn }}</button>
				</div>
				</template>

				<h3 class="sec">🎬 Acciones (en orden)</h3>
				<reward-editor v-model="actionsStr"></reward-editor>
			</section>

			<section class="editor-pane empty" v-else>
				<p class="muted">Selecciona o crea un evento.</p>
			</section>
		</div>

		<!-- ══ MISIÓN (quests.json) ══ -->
		<div v-show="view==='quest'" class="quest-doc">
			<div class="editor-toolbar">
				<span class="et-title">⭐ Questline principal (quests.json)</span>
				<div class="seg">
					<button class="btn sm ghost" :disabled="!canUndoQuest" @click="undoQuest()" title="Deshacer (Ctrl+Z)">↶</button>
					<button class="btn sm ghost" :disabled="!canRedoQuest" @click="redoQuest()" title="Rehacer (Ctrl+Y)">↷</button>
				</div>
				<span class="spacer"></span>
				<span v-if="questsDirty" class="et-dirty" title="Cambios sin guardar">●</span>
				<button class="btn sm primary" :disabled="!questsDirty" @click="saveQuests">💾 Guardar</button>
			</div>

			<h3 class="sec">📶 Orden monotónico de estados</h3>
			<p class="muted">El avance de misión nunca retrocede: <span class="mono">set_quest_forward</span> respeta este orden.</p>
			<ol class="order-list">
				<li v-for="(s,i) in order" :key="s" class="order-row">
					<span class="mono">{{ s }}</span>
					<span class="spacer"></span>
					<button class="btn sm ghost" :disabled="i===0" @click="moveState(i,-1)" title="Subir">▲</button>
					<button class="btn sm ghost" :disabled="i===order.length-1" @click="moveState(i,1)" title="Bajar">▼</button>
					<button class="btn sm danger" @click="removeState(i)" title="Quitar">✕</button>
				</li>
				<li v-if="!order.length" class="empty-row">Sin estados. Añade el primero (p. ej. <span class="mono">not_started</span>).</li>
			</ol>
			<div class="flex" style="gap:6px; margin-top:6px">
				<input class="input mono" v-model="newState" placeholder="nuevo_estado" @keyup.enter="addState" />
				<button class="btn primary sm" @click="addState">＋ Añadir estado</button>
			</div>

			<h3 class="sec">⚔️ Hooks de victoria en combate</h3>
			<p class="muted">Al vencer a un enemigo se ejecuta el evento asociado (si no hay hook, usa el flujo cableado).</p>
			<div class="hook-list">
				<div v-for="(v,enemy) in combatVictory" :key="enemy" class="hook-row">
					<span class="chip mono">{{ enemy }}</span>
					<span>→</span>
					<select class="input" :value="v.event" @change="setHookEvent(enemy,$event.target.value)">
						<option value="">(elige evento)</option>
						<option v-for="e in eventIds" :key="e" :value="e">{{ e }}</option>
					</select>
					<button class="btn sm danger" @click="removeHook(enemy)">✕</button>
				</div>
				<div v-if="!Object.keys(combatVictory).length" class="empty-row">Sin hooks de combate.</div>
			</div>
			<div class="flex" style="gap:6px; margin-top:6px">
				<input class="input mono" v-model="newHookEnemy" list="enemy-ids" placeholder="enemy_id" @keyup.enter="addHook" />
				<datalist id="enemy-ids"><option v-for="e in enemyIds" :key="e" :value="e"></option></datalist>
				<button class="btn primary sm" @click="addHook">＋ Añadir hook</button>
			</div>
		</div>
	</div>
	`,
};
