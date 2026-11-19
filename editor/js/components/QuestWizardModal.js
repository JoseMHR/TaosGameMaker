// components/QuestWizardModal.js
// ─────────────────────────────────────────────────────────────────────────────
// ASISTENTE DE CREACIÓN DE MISIONES (Task 5, 2.3). Genera paso a paso una
// questline principal completa usando la gramática REAL del motor (ver
// EventsManager.js / QuestsManager.js / store.js CONDITION_TOKENS/REWARD_TOKENS):
//   · Cada ETAPA añade un estado a `quests.json.order` (avance monótono).
//   · Cada etapa genera un EVENTO en `events.json` con:
//       - condition: `quest == "<estado_anterior>"` (gating por questline)
//       - actions:   `questf:<estado_nuevo>` (avanza la misión) + recompensas
//   · Si el objetivo es "derrotar enemigo", en vez de condición se registra un
//     hook `quests.json.combat_victory[enemy_id] = { event }` (igual que
//     QuestsManager.js/EventsManager.js) para que se dispare al vencerlo.
//   · Si el objetivo es "hablar con PNJ", se avisa de que hay que añadir
//     `event:<event_id>` como recompensa del nodo de diálogo correspondiente
//     (no hay forma genérica de elegir "el" nodo correcto automáticamente).
// ─────────────────────────────────────────────────────────────────────────────
import { ref, computed, watch } from 'https://unpkg.com/vue@3/dist/vue.esm-browser.prod.js';
import { store, markDirty, flash, CONDITION_SNIPPETS } from '../store.js';
import { goTo } from '../nav.js';
import RewardEditor from './RewardEditor.js';

const OBJECTIVE_TYPES = [
	{ key: 'defeat_enemy', label: '⚔️ Derrotar enemigo' },
	{ key: 'collect_item', label: '📦 Recolectar objeto' },
	{ key: 'talk_npc', label: '💬 Hablar con PNJ' },
	{ key: 'custom', label: '🧩 Personalizado (condición libre)' },
];

function slugify(s) {
	return (s || '').toLowerCase().trim()
		.normalize('NFD').replace(/[\u0300-\u036f]/g, '')
		.replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '');
}
let stageSeq = 0;
function newStage() {
	stageSeq++;
	return { key: 'stage_' + stageSeq, name: '', objectiveType: 'custom', target: '', extraCondition: '', rewardStr: '' };
}

export default {
	name: 'QuestWizardModal',
	components: { RewardEditor },
	props: { open: { type: Boolean, default: false } },
	emits: ['close', 'created'],
	setup(props, { emit }) {
		const step = ref(1);
		const TOTAL_STEPS = 3;

		const questName = ref('');
		const questId = ref('');
		const questIdTouched = ref(false);
		const stages = ref([newStage()]);

		function reset() {
			step.value = 1; questName.value = ''; questId.value = ''; questIdTouched.value = false; stages.value = [newStage()];
		}
		watch(() => props.open, (o) => { if (o) reset(); });

		const suggestedQuestId = computed(() => slugify(questName.value) || 'mision_nueva');
		watch(questName, () => { if (!questIdTouched.value) questId.value = suggestedQuestId.value; });

		const enemyIds = computed(() => Object.keys(store.enemies || {}).sort());
		const itemIds = computed(() => Object.keys(store.items || {}).sort());
		const npcIds = computed(() => Object.keys(store.npcs || {}).sort());

		function addStage() { stages.value.push(newStage()); }
		function removeStage(idx) { if (stages.value.length > 1) stages.value.splice(idx, 1); }
		function setRewardStr(idx, v) { stages.value[idx].rewardStr = v; }

		const canNext = computed(() => {
			if (step.value === 1) return !!questName.value.trim();
			if (step.value === 2) return stages.value.every(s => s.name.trim());
			return true;
		});
		function next() { if (canNext.value && step.value < TOTAL_STEPS) step.value++; }
		function back() { if (step.value > 1) step.value--; }

		// Estados y eventos que se generarán (para la vista previa y la creación).
		const plan = computed(() => {
			const qid = questId.value || suggestedQuestId.value;
			let prevState = store.quests?.order?.length ? store.quests.order[store.quests.order.length - 1] : 'not_started';
			const rows = [];
			for (const s of stages.value) {
				const state = qid + '_' + (slugify(s.name) || 'etapa');
				const eventId = 'event_' + state;
				let condition = '';
				let combatHook = null;
				let note = '';
				if (s.objectiveType === 'defeat_enemy') {
					combatHook = s.target || null;
					note = s.target ? '' : 'Falta elegir el enemigo.';
				} else if (s.objectiveType === 'collect_item') {
					condition = 'quest == "' + prevState + '"' + (s.target ? ' and has_item("' + s.target + '")' : '');
				} else if (s.objectiveType === 'talk_npc') {
					condition = 'quest == "' + prevState + '"';
					note = 'Añade "event:' + eventId + '" como recompensa del nodo de diálogo de "' + (s.target || 'NPC') + '".';
				} else {
					condition = 'quest == "' + prevState + '"' + (s.extraCondition ? ' and ' + s.extraCondition : '');
				}
				const actions = ['questf:' + state];
				if (s.rewardStr) actions.push(...s.rewardStr.split(';').map(t => t.trim()).filter(Boolean));
				rows.push({ state, eventId, condition, combatHook, actions, note, stageName: s.name });
				prevState = state;
			}
			return rows;
		});

		function finish() {
			if (!store.quests) store.quests = { order: [], combat_victory: {} };
			if (!Array.isArray(store.quests.order)) store.quests.order = [];
			if (!store.quests.combat_victory) store.quests.combat_victory = {};
			if (!store.events) store.events = {};

			for (const row of plan.value) {
				if (!store.quests.order.includes(row.state)) store.quests.order.push(row.state);
				const ev = { desc: questName.value + ' — ' + row.stageName, actions: row.actions };
				if (row.condition) ev.condition = row.condition;
				store.events[row.eventId] = ev;
				markDirty('events', row.eventId);
				if (row.combatHook) store.quests.combat_victory[row.combatHook] = { event: row.eventId };
			}
			markDirty('quests');
			flash('🧙 Misión creada: ' + (questId.value || suggestedQuestId.value) + ' (' + plan.value.length + ' etapas)');
			goTo('events');
			emit('created', questId.value || suggestedQuestId.value);
			emit('close');
		}

		return {
			step, TOTAL_STEPS, questName, questId, questIdTouched, suggestedQuestId, stages,
			OBJECTIVE_TYPES, enemyIds, itemIds, npcIds, addStage, removeStage, setRewardStr,
			canNext, next, back, plan, finish, CONDITION_SNIPPETS,
		};
	},
	template: `
	<ds-modal :open="open" size="xl" title="🧙 Asistente de creación de misión" @close="$emit('close')">
		<div class="wizard">
			<div class="wizard__steps">
				<div class="wizard__step" v-for="n in TOTAL_STEPS" :key="n" :class="{ active: step===n, done: step>n }">{{ n }}</div>
			</div>

			<template v-if="step===1">
				<h3 class="sec">1. Nombre de la misión</h3>
				<div class="form-grid">
					<label class="full">Nombre <input class="input" type="text" v-model="questName" placeholder="El secreto de la presa" /></label>
					<label>ID base <input class="input mono" type="text" v-model="questId" @input="questIdTouched=true" :placeholder="suggestedQuestId" /></label>
				</div>
				<p class="muted">Cada etapa añadirá un estado <span class="mono">{{ questId || suggestedQuestId }}_&lt;etapa&gt;</span> a la questline principal.</p>
			</template>

			<template v-if="step===2">
				<h3 class="sec">2. Etapas y objetivos ({{ stages.length }})</h3>
				<div class="skills-list">
					<div class="card panel" style="margin-bottom:10px; padding:12px" v-for="(s, idx) in stages" :key="s.key">
						<div class="flex" style="justify-content:space-between; margin-bottom:8px">
							<b class="mono">Etapa #{{ idx + 1 }}</b>
							<button class="btn sm err" :disabled="stages.length===1" @click="removeStage(idx)">🗑️</button>
						</div>
						<div class="form-grid">
							<label>Nombre de la etapa <input class="input" type="text" v-model="s.name" placeholder="encontrar_pista" /></label>
							<label>Objetivo
								<select class="input" v-model="s.objectiveType">
									<option v-for="o in OBJECTIVE_TYPES" :key="o.key" :value="o.key">{{ o.label }}</option>
								</select>
							</label>
							<label v-if="s.objectiveType==='defeat_enemy'">Enemigo
								<input class="input mono" type="text" v-model="s.target" list="qw-enemies" placeholder="enemy_id" />
							</label>
							<label v-else-if="s.objectiveType==='collect_item'">Objeto
								<input class="input mono" type="text" v-model="s.target" list="qw-items" placeholder="item_id" />
							</label>
							<label v-else-if="s.objectiveType==='talk_npc'">PNJ
								<input class="input mono" type="text" v-model="s.target" list="qw-npcs" placeholder="npc_id" />
							</label>
							<label v-else class="full">Condición extra (gflag, opcional)
								<input class="input mono" type="text" v-model="s.extraCondition" placeholder='gflag("dam_opened")' />
							</label>
						</div>
						<div class="sub">Recompensas al completar</div>
						<reward-editor :model-value="s.rewardStr" @update:model-value="v => setRewardStr(idx, v)"></reward-editor>
					</div>
				</div>
				<button class="btn secondary sm" @click="addStage">➕ Añadir etapa</button>
				<datalist id="qw-enemies"><option v-for="e in enemyIds" :key="e" :value="e"></option></datalist>
				<datalist id="qw-items"><option v-for="i in itemIds" :key="i" :value="i"></option></datalist>
				<datalist id="qw-npcs"><option v-for="n in npcIds" :key="n" :value="n"></option></datalist>
			</template>

			<template v-if="step===3">
				<h3 class="sec">3. Vista previa</h3>
				<div class="skills-list">
					<div class="card panel" style="margin-bottom:8px; padding:10px" v-for="row in plan" :key="row.state">
						<b class="mono">{{ row.state }}</b>
						<p class="muted" style="margin:4px 0">Evento <span class="mono">{{ row.eventId }}</span>
							<template v-if="row.condition"> · condición: <span class="mono">{{ row.condition }}</span></template>
							<template v-if="row.combatHook"> · hook de combate: <span class="mono">{{ row.combatHook }}</span></template>
						</p>
						<p class="muted" style="margin:4px 0">Acciones: <span class="mono">{{ row.actions.join('; ') }}</span></p>
						<p v-if="row.note" class="muted" style="color:var(--warn)">⚠️ {{ row.note }}</p>
					</div>
				</div>
			</template>
		</div>
		<template #footer>
			<button class="btn ghost sm" :disabled="step===1" @click="back">◀ Atrás</button>
			<span class="spacer"></span>
			<button v-if="step<TOTAL_STEPS" class="btn primary sm" :disabled="!canNext" @click="next">Siguiente ▶</button>
			<button v-else class="btn primary sm" @click="finish">✅ Crear misión</button>
		</template>
	</ds-modal>
	`,
};
