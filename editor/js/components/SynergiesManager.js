// components/SynergiesManager.js
// ─────────────────────────────────────────────────────────────────────────────
// Gestor de synergies.json: combos de habilidades. El documento es
//   { synergies: [ { profession, required_ids:[id,id], result_id } ] }
//   · Al tener equipadas/aprendidas las `required_ids`, se desbloquea `result_id`.
// Es una LISTA (no un `{id->entidad}`), así que se edita en su propio panel.
// Los ids de skill se autocompletan desde skills.json.
// ─────────────────────────────────────────────────────────────────────────────
import { computed } from 'https://unpkg.com/vue@3/dist/vue.esm-browser.prod.js';
import { store, markDirty, save, getI18nDisplay } from '../store.js';
import { useDocumentHistory } from '../lib/useDocumentHistory.js';
import EditorToolbar from './EditorToolbar.js';

export default {
	name: 'SynergiesManager',
	components: { EditorToolbar },
	setup() {
		const doc = computed(() => {
			if (!store.synergies) store.synergies = { synergies: [] };
			if (!Array.isArray(store.synergies.synergies)) store.synergies.synergies = [];
			return store.synergies;
		});
		const rows = computed(() => doc.value.synergies);
		const dirty = computed(() => !!store.dirty.synergies);
		function touch() { markDirty('synergies'); }
		function doSave() { save(false); }

		// Task 5 (1.3): historial de deshacer/rehacer (documento único, no colección).
		const hist = useDocumentHistory({ tabId: 'synergies', getDoc: () => doc.value, setDoc: (v) => { store.synergies = v; touch(); } });
		function edit(fn) { hist.edit(fn); touch(); }

		const skillIds = computed(() => Object.keys(store.skills || {}).sort());
		const professions = computed(() => {
			const set = new Set(rows.value.map(r => r.profession).filter(Boolean));
			Object.values(store.professions || {}).forEach(p => { const n = (p && getI18nDisplay(p.name)) || null; if (n) set.add(n); });
			return [...set].sort();
		});
		function skillName(id) {
			const s = store.skills?.[id];
			if (!s) return id;
			return getI18nDisplay(s.name) || id;
		}
		// Referencia rota: hay un id escrito pero no existe en skills.json (typo o skill
		// borrada). Se marca en la UI para no dejar sinergias que nunca se desbloquean.
		function skillMissing(id) { return !!id && !store.skills?.[id]; }

		function add() { edit(() => { rows.value.push({ profession: professions.value[0] || 'Guerrero', required_ids: ['', ''], result_id: '' }); }); }
		function remove(idx) { edit(() => { rows.value.splice(idx, 1); }); }
		function setProfession(idx, v) { edit(() => { rows.value[idx].profession = v; }); }
		function setResult(idx, v) { edit(() => { rows.value[idx].result_id = v; }); }
		function setReq(idx, ri, v) { edit(() => { rows.value[idx].required_ids[ri] = v; }); }
		function addReq(idx) { edit(() => { rows.value[idx].required_ids = rows.value[idx].required_ids || []; rows.value[idx].required_ids.push(''); }); }
		function removeReq(idx, ri) { edit(() => { rows.value[idx].required_ids.splice(ri, 1); }); }

		return {
			store, rows, dirty, doSave, skillIds, professions, skillName, skillMissing, add, remove, setProfession, setResult, setReq, addReq, removeReq,
			canUndo: hist.canUndo, canRedo: hist.canRedo, undo: hist.undo, redo: hist.redo,
		};
	},
	template: `
	<div class="manager" style="display:block; overflow:auto">
		<section class="editor-pane">
			<editor-toolbar :dirty="dirty" :has-current="true" :can-undo="canUndo" :can-redo="canRedo"
				:show="{ undo:true, copy:false, paste:false, duplicate:false, remove:false, save:true }"
				@undo="undo()" @redo="redo()" @save="doSave()"></editor-toolbar>

			<div class="pane-header">
				<h3 class="sec">✨ Sinergias de habilidades ({{ rows.length }})</h3>
				<button class="btn secondary sm" @click="add">➕ Añadir sinergia</button>
			</div>
			<p class="muted" style="margin:4px 0 12px">Combinar las habilidades <span class="mono">required_ids</span> desbloquea <span class="mono">result_id</span>. Los ids se resuelven contra <span class="mono">skills.json</span>.</p>

			<div class="skills-list">
				<div class="card panel" style="margin-bottom:10px; padding:12px; border:1px solid rgba(255,255,255,0.1)"
					v-for="(r, idx) in rows" :key="idx">
					<div class="flex" style="justify-content:space-between; margin-bottom:8px">
						<b class="mono">#{{ idx + 1 }}</b>
						<button class="btn sm err" @click="remove(idx)">🗑️</button>
					</div>
					<div class="form-grid">
						<label>Profesión
							<input class="input" type="text" :value="r.profession" @input="setProfession(idx, $event.target.value)" list="syn-profs" />
						</label>
						<label>Resultado (result_id)
							<input class="input mono" :class="{ 'input--bad': skillMissing(r.result_id) }" type="text" :value="r.result_id" @input="setResult(idx, $event.target.value)" list="syn-skills" />
							<span v-if="skillMissing(r.result_id)" class="ref-bad">⚠️ no existe en skills.json</span>
							<span v-else class="muted" style="font-size:11px">{{ skillName(r.result_id) }}</span>
						</label>
					</div>
					<h4 class="sec" style="margin:10px 0 6px">Requiere ({{ (r.required_ids && r.required_ids.length) || 0 }})</h4>
					<div class="skills-list">
						<div class="flex" style="gap:6px; align-items:center; margin-bottom:6px" v-for="(rid, ri) in r.required_ids" :key="ri">
							<input class="input mono" :class="{ 'input--bad': skillMissing(rid) }" type="text" :value="rid" @input="setReq(idx, ri, $event.target.value)" list="syn-skills" />
							<span class="muted" style="font-size:11px; min-width:120px" :class="{ 'ref-bad': skillMissing(rid) }">{{ skillMissing(rid) ? '⚠️ no existe' : skillName(rid) }}</span>
							<button class="btn sm err" @click="removeReq(idx, ri)">✕</button>
						</div>
					</div>
					<button class="btn sm ghost" @click="addReq(idx)">➕ Añadir requisito</button>
				</div>
				<p v-if="!rows.length" class="muted">Sin sinergias. Pulsa “Añadir sinergia”.</p>
			</div>

			<datalist id="syn-profs"><option v-for="p in professions" :key="p" :value="p"></option></datalist>
			<datalist id="syn-skills"><option v-for="s in skillIds" :key="s" :value="s"></option></datalist>
		</section>
	</div>
	`,
};
