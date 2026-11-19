// components/QuestsManager.js
// ─────────────────────────────────────────────────────────────────────────────
// Gestor de quests.json: NO es una colección `{id->entidad}`, sino un documento
// con dos secciones:
//   · order          : [estado] — orden canónico de estados de la questline
//                       principal (GlobalState.quest_state avanza por este orden).
//   · combat_victory : { enemy_id -> { event } } — al vencer a ese enemigo se
//                       dispara el evento indicado (gancho "boss → quest/evento").
// Se edita en su propio panel y marca cambios con markDirty('quests').
// ─────────────────────────────────────────────────────────────────────────────
import { computed, ref } from 'https://unpkg.com/vue@3/dist/vue.esm-browser.prod.js';
import { store, markDirty, save } from '../store.js';
import { useDocumentHistory } from '../lib/useDocumentHistory.js';
import EditorToolbar from './EditorToolbar.js';
import QuestWizardModal from './QuestWizardModal.js';

export default {
	name: 'QuestsManager',
	components: { EditorToolbar, QuestWizardModal },
	setup() {
		const wizardOpen = ref(false);
		const q = computed(() => {
			if (!store.quests) store.quests = { order: [], combat_victory: {} };
			if (!Array.isArray(store.quests.order)) store.quests.order = [];
			if (!store.quests.combat_victory) store.quests.combat_victory = {};
			return store.quests;
		});
		const dirty = computed(() => !!store.dirty.quests);
		function touch() { markDirty('quests'); }
		function doSave() { save(false); }

		// Task 5 (1.3): historial de deshacer/rehacer (documento único, no colección).
		const hist = useDocumentHistory({ tabId: 'quests', getDoc: () => q.value, setDoc: (v) => { store.quests = v; touch(); } });
		function edit(fn) { hist.edit(fn); touch(); }

		// Listas auxiliares para desplegables.
		const enemyIds = computed(() => Object.keys(store.enemies || {}).sort());
		const eventIds = computed(() => Object.keys(store.events || {}).sort());

		// ── order ───────────────────────────────────────────────────────────
		function setOrder(idx, v) { edit(() => { q.value.order[idx] = v; }); }
		function addOrder() { edit(() => { q.value.order.push('nuevo_estado'); }); }
		function removeOrder(idx) { edit(() => { q.value.order.splice(idx, 1); }); }
		function moveOrder(idx, dir) { const t = idx + dir; if (t < 0 || t >= q.value.order.length) return; edit(() => { const a = q.value.order; const tmp = a[idx]; a[idx] = a[t]; a[t] = tmp; }); }

		// ── combat_victory ──────────────────────────────────────────────────
		const hookKeys = computed(() => Object.keys(q.value.combat_victory));
		function addHook() {
			edit(() => {
				const cv = q.value.combat_victory;
				const first = enemyIds.value.find(e => !cv[e]) || 'nuevo_enemigo';
				cv[first] = { event: eventIds.value[0] || '' };
			});
		}
		function renameHook(oldK, newK) { if (!newK || newK === oldK || q.value.combat_victory[newK]) return; edit(() => { const cv = q.value.combat_victory; cv[newK] = cv[oldK]; delete cv[oldK]; }); }
		function setHookEvent(key, v) { edit(() => { q.value.combat_victory[key].event = v; }); }
		function removeHook(key) { edit(() => { delete q.value.combat_victory[key]; }); }

		return {
			store, q, dirty, doSave, enemyIds, eventIds, hookKeys, setOrder, addOrder, removeOrder, moveOrder, addHook, renameHook, setHookEvent, removeHook,
			canUndo: hist.canUndo, canRedo: hist.canRedo, undo: hist.undo, redo: hist.redo, wizardOpen,
		};
	},
	template: `
	<div class="manager" style="display:block; overflow:auto">
		<section class="editor-pane">
			<editor-toolbar :dirty="dirty" :has-current="true" :can-undo="canUndo" :can-redo="canRedo"
				:show="{ undo:true, copy:false, paste:false, duplicate:false, remove:false, save:true }"
				@undo="undo()" @redo="redo()" @save="doSave()"></editor-toolbar>
			<button class="btn secondary sm" style="margin-bottom:12px" @click="wizardOpen=true">🧙 Asistente de misión</button>
			<quest-wizard-modal :open="wizardOpen" @close="wizardOpen=false" @created="wizardOpen=false"></quest-wizard-modal>

			<h3 class="sec">📈 Orden de estados (questline principal)</h3>
			<p class="muted" style="margin:0 0 8px">El estado de misión avanza por este orden. El primero suele ser <span class="mono">not_started</span>.</p>
			<div class="skills-list">
				<div class="card panel" style="margin-bottom:6px; padding:8px" v-for="(st, idx) in q.order" :key="idx">
					<div class="flex" style="gap:6px; align-items:center">
						<b class="mono" style="min-width:24px">{{ idx }}</b>
						<input class="input mono" type="text" :value="st" @input="setOrder(idx, $event.target.value)" />
						<button class="btn sm ghost" :disabled="idx === 0" @click="moveOrder(idx, -1)">▲</button>
						<button class="btn sm ghost" :disabled="idx === q.order.length - 1" @click="moveOrder(idx, 1)">▼</button>
						<button class="btn sm err" @click="removeOrder(idx)">🗑️</button>
					</div>
				</div>
			</div>
			<button class="btn secondary sm" @click="addOrder">➕ Añadir estado</button>

			<h3 class="sec" style="margin-top:18px">⚔️ Ganchos de victoria (boss → evento)</h3>
			<p class="muted" style="margin:0 0 8px">Al vencer al enemigo, se dispara el evento (concede ítems, transforma el mundo, muestra diálogo…).</p>
			<div class="skills-list">
				<div class="card panel" style="margin-bottom:8px; padding:10px" v-for="k in hookKeys" :key="k">
					<div class="form-grid" style="align-items:end">
						<label>Enemigo
							<input class="input mono" type="text" :value="k" @change="renameHook(k, $event.target.value)" list="qm-enemies" />
						</label>
						<label>Evento
							<select class="input" :value="q.combat_victory[k].event" @change="setHookEvent(k, $event.target.value)">
								<option v-for="e in eventIds" :key="e" :value="e">{{ e }}</option>
							</select>
						</label>
						<button class="btn sm err" @click="removeHook(k)">🗑️</button>
					</div>
				</div>
			</div>
			<datalist id="qm-enemies"><option v-for="e in enemyIds" :key="e" :value="e"></option></datalist>
			<button class="btn secondary sm" @click="addHook">➕ Añadir gancho</button>
		</section>
	</div>
	`,
};
