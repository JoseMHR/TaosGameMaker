// components/SkillsManager.js
// ─────────────────────────────────────────────────────────────────────────────
// Gestor de skills.json: habilidades de combate. Cada entrada es
//   `skill_id -> { id, name{es,en}, desc{es,en}, icon, type, element, power,
//                  cost, pa_cost, tag, resonance_gain, status?{type,turns,target} }`.
//   · Las profesiones referencian estos ids en su lista `skills[]`.
//   · Las sinergias combinan ids para producir un `result_id`.
// Reutiliza el CRUD/atajos comunes de useCollection y el panel de lista común.
// ─────────────────────────────────────────────────────────────────────────────
import { computed } from 'https://unpkg.com/vue@3/dist/vue.esm-browser.prod.js';
import { store, ELEMENTS, getI18n, getI18nFallback, getI18nDisplay, setI18n } from '../store.js';
import { useCollection } from '../lib/useCollection.js';
import EntityListPanel from './EntityListPanel.js';
import EditorToolbar from './EditorToolbar.js';

const SKILL_TYPES = ['physical', 'magic', 'ranged', 'buff', 'debuff', 'heal', 'support'];
const STATUS_TARGETS = ['self', 'enemy', 'ally', 'all_enemies', 'all_allies'];
const NUM_FIELDS = [
	{ k: 'power', label: 'Poder' },
	{ k: 'cost', label: 'Coste MP' },
	{ k: 'pa_cost', label: 'Coste PA' },
	{ k: 'resonance_gain', label: 'Resonancia' },
];

export default {
	name: 'SkillsManager',
	components: { EntityListPanel, EditorToolbar },
	setup() {
		const col = useCollection({
			tabId: 'skills',
			dirtyKey: 'skills',
			collection: () => store.skills,
			setCollection: (v) => { store.skills = v; },
			selectedKey: 'selectedSkill',
			clipboardKind: 'skill',
			entityLabel: 'habilidad',
			newIdBase: 'nueva_skill',
			makeNew: (id) => ({ id, name: { es: 'Nueva habilidad', en: 'New skill' }, desc: { es: '', en: '' }, icon: '✨', type: 'physical', element: 'physical', power: 0, cost: 0, pa_cost: 1, tag: '', resonance_gain: 0 }),
			searchText: (id, o) => id + ' ' + (o?.name?.es || '') + ' ' + (o?.type || '') + ' ' + (o?.element || ''),
			filters: [
				{ key: 'type', label: 'Tipo', options: SKILL_TYPES, get: (o) => o?.type },
				{ key: 'element', label: 'Elemento', options: ELEMENTS, get: (o) => o?.element },
			],
			sorts: [
				{ key: 'id', label: 'ID', get: (id) => id },
				{ key: 'name', label: 'Nombre', get: (id, o) => (o?.name?.es || id).toLowerCase() },
				{ key: 'cost', label: 'Coste MP', get: (id, o) => Number(o?.cost) || 0 },
				{ key: 'power', label: 'Poder', get: (id, o) => Number(o?.power) || 0 },
			],
		});
		const current = col.current;
		const hasStatus = computed(() => current.value && current.value.status && typeof current.value.status === 'object');

		function setField(path, v) {
			col.edit(() => {
				const o = current.value;
				if (path === 'icon') o.icon = v;
				else if (path === 'type') o.type = v;
				else if (path === 'element') o.element = v;
				else if (path === 'tag') o.tag = v;
				else if (path.startsWith('name.')) setI18n(o, 'name', v, path.split('.')[1]);
				else if (path.startsWith('desc.')) setI18n(o, 'desc', v, path.split('.')[1]);
			});
		}
		function setNum(k, v) {
			col.edit(() => {
				const n = Number(v);
				current.value[k] = isNaN(n) ? 0 : n;
			});
		}
		function toggleStatus(on) {
			col.edit(() => {
				if (on) current.value.status = { type: 'burn', turns: 2, target: 'enemy' };
				else delete current.value.status;
			});
		}
		function setStatus(field, v) { col.edit(() => { current.value.status[field] = field === 'turns' ? (Number(v) || 0) : v; }); }

		const elementColors = {
			fire: '#ef4444',
			ice: '#38bdf8',
			lightning: '#eab308',
			thunder: '#eab308',
			wind: '#10b981',
			earth: '#d97706',
			dark: '#a855f7',
			holy: '#fef08a',
			physical: '#94a3b8',
		};

		const skillCardStyle = computed(() => {
			const el = current.value?.element || 'physical';
			const c = elementColors[el] || '#64748b';
			return {
				borderColor: c,
				boxShadow: `0 4px 20px ${c}25`,
			};
		});

		const naturalExplanation = computed(() => {
			if (!current.value) return '';
			const o = current.value;
			let text = `Habilidad de tipo ${o.type || 'física'} (${o.element || 'físico'}). `;
			if (o.power > 0) text += `Poder base de impacto: ${o.power}. `;
			text += `Coste: ${o.cost || 0} MP, ${o.pa_cost || 1} PA. `;
			if (o.resonance_gain > 0) text += `Otorga +${o.resonance_gain} de resonancia. `;
			if (o.status && o.status.type) {
				text += `Aplica estado [${o.status.type}] durante ${o.status.turns || 1} turnos a ${o.status.target || 'objetivo'}.`;
			}
			return text;
		});

		return {
			store, col, current, hasStatus, setField, setNum, toggleStatus, setStatus,
			SKILL_TYPES, STATUS_TARGETS, NUM_FIELDS, ELEMENTS,
			skillCardStyle, naturalExplanation,
			getI18n, getI18nFallback, getI18nDisplay, setI18n,
		};
	},
	template: `
	<div class="manager">
		<entity-list-panel :c="col" search-placeholder="Buscar habilidad…" new-label="➕ Nueva habilidad">
			<template #row="{ id, o }">
				<span class="ent-icon">{{ o && o.icon || '✨' }}</span>
				<span class="ent-name">{{ (o && o.name && (o.name[store.currentLang] || o.name.en || o.name.es)) || id }}</span>
				<span class="ent-id mono">{{ (o && o.type) || '' }}</span>
			</template>
		</entity-list-panel>

		<section class="editor-pane" v-if="current">
			<editor-toolbar :can-undo="col.canUndo.value" :can-redo="col.canRedo.value"
				:can-paste="col.canPaste.value" :has-current="!!current" :dirty="col.dirty.value"
				:saved-text="col.savedText.value"
				@undo="col.undo()" @redo="col.redo()" @copy="col.copy()" @paste="col.paste()"
				@duplicate="col.duplicate()" @remove="col.remove()" @save="col.doSave()"></editor-toolbar>

			<!-- 🎴 Tarjeta Visual WYSIWYG de Habilidad -->
			<div class="skill-card-preview card panel" :style="skillCardStyle" style="margin-bottom:14px; padding:14px; border:2px solid; border-radius:12px; background:linear-gradient(180deg, rgba(20,24,35,0.9), rgba(10,14,20,0.95))">
				<div class="flex" style="justify-content:space-between; align-items:center">
					<div class="flex" style="gap:10px; align-items:center">
						<span style="font-size:32px">{{ current.icon || '✨' }}</span>
						<div>
							<h3 style="margin:0; font-size:18px">{{ getI18nDisplay(current.name) || col.selectedId.value }}</h3>
							<div class="mono muted" style="font-size:12px">{{ col.selectedId.value }}</div>
						</div>
					</div>
					<div class="flex" style="gap:6px">
						<span class="type-tag" style="font-size:11px; text-transform:uppercase; font-weight:700">{{ current.element || 'físico' }}</span>
						<span class="type-tag" style="font-size:11px; text-transform:uppercase">{{ current.type }}</span>
					</div>
				</div>

				<p style="margin:8px 0; font-size:13px; color:var(--txt-1)">{{ getI18nDisplay(current.desc) || 'Sin descripción.' }}</p>

				<div class="flex" style="gap:12px; margin-top:10px; padding:8px; background:rgba(0,0,0,0.3); border-radius:8px; font-size:12px">
					<div><b>💥 Poder:</b> {{ current.power || 0 }}</div>
					<div><b>🧪 Coste MP:</b> {{ current.cost || 0 }}</div>
					<div><b>⚡ Coste PA:</b> {{ current.pa_cost || 1 }}</div>
					<div v-if="current.resonance_gain"><b>🎵 Resonancia:</b> +{{ current.resonance_gain }}</div>
				</div>

				<div style="margin-top:8px; font-size:12px; padding:6px 10px; background:rgba(59,130,246,0.1); border-left:3px solid #3b82f6; border-radius:4px">
					💡 <b>Lógica de combate:</b> {{ naturalExplanation }}
				</div>
			</div>

			<h3 class="sec">✨ Parámetros de Habilidad</h3>
			<div class="form-grid">
				<label>ID
					<input class="input mono" type="text" :value="col.selectedId.value" @change="col.rename($event.target.value)" />
				</label>
				<label>Icono
					<input class="input f-xs" type="text" :value="current.icon" @input="setField('icon', $event.target.value)" />
				</label>
				<label>Nombre [{{ store.currentLang.toUpperCase() }}] <input class="input" type="text" :value="getI18n(current.name)" :placeholder="getI18nFallback(current.name) || 'Nombre de la habilidad...'" @input="setField('name.' + store.currentLang, $event.target.value)" /></label>
				<label class="col-span-2">Descripción [{{ store.currentLang.toUpperCase() }}] <input class="input" type="text" :value="getI18n(current.desc)" :placeholder="getI18nFallback(current.desc) || 'Descripción de la habilidad...'" @input="setField('desc.' + store.currentLang, $event.target.value)" /></label>
			</div>

			<h3 class="sec" style="margin-top:14px">⚙️ Parámetros Numéricos</h3>
			<div class="form-grid">
				<label>Tipo
					<select class="input" :value="current.type" @change="setField('type', $event.target.value)">
						<option v-for="t in SKILL_TYPES" :key="t" :value="t">{{ t }}</option>
					</select>
				</label>
				<label>Elemento
					<select class="input" :value="current.element" @change="setField('element', $event.target.value)">
						<option v-for="e in ELEMENTS" :key="e" :value="e">{{ e }}</option>
					</select>
				</label>
				<label v-for="f in NUM_FIELDS" :key="f.k">{{ f.label }}
					<input class="input num" type="number" :value="current[f.k]" @input="setNum(f.k, $event.target.value)" />
				</label>
				<label v-if="store.expertMode">Tag <span class="muted">(lógica interna, experto)</span>
					<input class="input mono" type="text" :value="current.tag" @input="setField('tag', $event.target.value)" />
				</label>
			</div>

			<label class="flex" style="gap:8px; align-items:center; margin-top:12px">
				<input type="checkbox" :checked="hasStatus" @change="toggleStatus($event.target.checked)" />
				<span>Aplica un estado alterado (buff/debuff)</span>
			</label>
			<div v-if="hasStatus" class="form-grid" style="margin-top:8px">
				<label>Estado (type) <input class="input mono" type="text" :value="current.status.type" @input="setStatus('type', $event.target.value)" placeholder="barrera / veneno…" /></label>
				<label>Turnos <input class="input num" type="number" :value="current.status.turns" @input="setStatus('turns', $event.target.value)" /></label>
				<label>Objetivo
					<select class="input" :value="current.status.target" @change="setStatus('target', $event.target.value)">
						<option v-for="t in STATUS_TARGETS" :key="t" :value="t">{{ t }}</option>
					</select>
				</label>
			</div>
		</section>

		<section class="editor-pane empty" v-else>
			<p class="muted">Selecciona o crea una habilidad.</p>
		</section>
	</div>
	`,
};
