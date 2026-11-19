// components/DungeonWizardModal.js
// ─────────────────────────────────────────────────────────────────────────────
// ASISTENTE DE CREACIÓN DE MAZMORRAS (Task 5, 2.4). Genera el layout inicial
// en `data/dungeons/<id>.json`: sala rectangular W×H con textura de suelo/pared
// elegida, tema ambiental (ver ENV_THEME_OPTIONS en DungeonEditor.js), y una
// sala de spawn con entrada (teleport) y antorchas flanqueando la puerta.
// Complementa a los presets fijos ya existentes (DungeonEditor.js
// `createDungeonWithTemplate`); aquí el diseñador elige tema/dimensiones/
// texturas en vez de una plantilla cerrada.
// ─────────────────────────────────────────────────────────────────────────────
import { ref, computed, watch } from 'https://unpkg.com/vue@3/dist/vue.esm-browser.prod.js';
import { store, markDirty, markDungeonDirty, flash } from '../store.js';
import { goTo } from '../nav.js';
import { ENV_THEME_OPTIONS, WALL_TYPES, FLOOR_TEX } from '../lib/dungeonConstants.js';

function slugify(s) {
	return String(s || '').toLowerCase().trim()
		.normalize('NFD').replace(/[\u0300-\u036f]/g, '')
		.replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '') || 'dun';
}
function uniqueId(dict, base) {
	let id = base, n = 2;
	while (dict && dict[id]) id = base + '_' + (n++);
	return id;
}

/** Genera una sala rectangular W×H con muro perimetral, spawn y antorchas. */
function buildLayout(w, h, wallTex, floorTex) {
	const cells = [];
	for (let y = 0; y < h; y++) {
		const row = [];
		for (let x = 0; x < w; x++) {
			const border = x === 0 || x === w - 1 || y === 0 || y === h - 1;
			const cell = { t: border ? 'wall' : 'floor' };
			if (border && wallTex) cell.wall = wallTex;
			if (!border && floorTex) cell.tex = floorTex;
			row.push(cell);
		}
		cells.push(row);
	}
	const spawnX = Math.floor(w / 2);
	const spawnY = h - 2;
	cells[spawnY][spawnX] = { t: 'teleport' };
	if (floorTex) cells[spawnY][spawnX].tex = floorTex;
	if (spawnX - 1 > 0) cells[spawnY - 1][spawnX - 1] = { t: 'torch', torch_face: 'sur' };
	if (spawnX + 1 < w - 1) cells[spawnY - 1][spawnX + 1] = { t: 'torch', torch_face: 'sur' };
	return { cells, spawnX, spawnY };
}

export default {
	name: 'DungeonWizardModal',
	props: { open: { type: Boolean, default: false } },
	emits: ['close', 'created'],
	setup(props, { emit }) {
		const step = ref(1);
		const TOTAL_STEPS = 3;

		const nameText = ref('');
		const dunId = ref('');
		const dunIdTouched = ref(false);
		const theme = ref('cave');
		const width = ref(15);
		const height = ref(15);
		const wallTex = ref('cave');
		const floorTex = ref('stone');

		function reset() {
			step.value = 1; nameText.value = ''; dunId.value = ''; dunIdTouched.value = false;
			theme.value = 'cave'; width.value = 15; height.value = 15; wallTex.value = 'cave'; floorTex.value = 'stone';
		}
		watch(() => props.open, (o) => { if (o) reset(); });

		const suggestedId = computed(() => 'dun_' + (slugify(nameText.value) || 'nueva'));
		watch(nameText, () => { if (!dunIdTouched.value) dunId.value = suggestedId.value; });

		const canNext = computed(() => {
			if (step.value === 1) return !!nameText.value.trim();
			if (step.value === 2) return width.value >= 7 && height.value >= 7;
			return true;
		});
		function next() { if (canNext.value && step.value < TOTAL_STEPS) step.value++; }
		function back() { if (step.value > 1) step.value--; }

		function finish() {
			const id = uniqueId(store.dungeons, slugify(dunId.value || suggestedId.value));
			const w = Math.max(7, Math.min(60, Math.round(width.value)));
			const h = Math.max(7, Math.min(60, Math.round(height.value)));
			const { cells, spawnX, spawnY } = buildLayout(w, h, wallTex.value, floorTex.value);
			const lang = store.currentLang || 'es';
			const dunData = {
				id,
				name: { [lang]: nameText.value.trim(), es: nameText.value.trim(), en: nameText.value.trim() },
				theme: theme.value,
				music: 'dungeon',
				cell_size: 4,
				wall_height: 4,
				ceiling: true,
				fog: true,
				spawn: { f: 0, x: spawnX, y: spawnY },
				floors: [{ name: 'Planta Principal', w, h, cells }],
			};
			if (!store.dungeons) store.dungeons = {};
			store.dungeons[id] = dunData;
			markDungeonDirty(id);

			// Entrada en ids.json (type dungeon) para poder colocarla en el mapamundi.
			if (!store.ids) store.ids = {};
			if (!store.ids[id]) {
				store.ids[id] = { id, type: 'dungeon', name: { ...dunData.name }, icon: '🕳️', desc: {} };
				markDirty('ids', id);
			}

			flash('🧙 Mazmorra creada: ' + id);
			goTo('dungeons', id);
			emit('created', id);
			emit('close');
		}

		return {
			store, step, TOTAL_STEPS, nameText, dunId, dunIdTouched, suggestedId,
			theme, width, height, wallTex, floorTex, ENV_THEME_OPTIONS, WALL_TYPES, FLOOR_TEX,
			canNext, next, back, finish,
		};
	},
	template: `
	<ds-modal :open="open" size="lg" title="🧙 Asistente de creación de mazmorra" @close="$emit('close')">
		<div class="wizard">
			<div class="wizard__steps">
				<div class="wizard__step" v-for="n in TOTAL_STEPS" :key="n" :class="{ active: step===n, done: step>n }">{{ n }}</div>
			</div>

			<template v-if="step===1">
				<h3 class="sec">1. Nombre y tema</h3>
				<div class="form-grid">
					<label>Nombre [{{ store.currentLang.toUpperCase() }}] <input class="input" type="text" v-model="nameText" :placeholder="store.currentLang === 'es' ? 'Catacumbas Olvidadas' : 'Forgotten Catacombs'" /></label>
					<label>ID <input class="input mono" type="text" v-model="dunId" @input="dunIdTouched=true" :placeholder="suggestedId" /></label>
					<label>Tema ambiental
						<select class="input" v-model="theme">
							<option v-for="t in ENV_THEME_OPTIONS" :key="t.value" :value="t.value">{{ t.label }}</option>
						</select>
					</label>
				</div>
			</template>

			<template v-if="step===2">
				<h3 class="sec">2. Dimensiones y texturas</h3>
				<div class="form-grid">
					<label>Ancho (W) <input class="input num" type="number" min="7" max="60" v-model.number="width" /></label>
					<label>Alto (H) <input class="input num" type="number" min="7" max="60" v-model.number="height" /></label>
					<label>Textura de pared
						<select class="input" v-model="wallTex">
							<option v-for="w in WALL_TYPES" :key="w" :value="w">{{ w || '(por defecto)' }}</option>
						</select>
					</label>
					<label>Textura de suelo
						<select class="input" v-model="floorTex">
							<option v-for="f in FLOOR_TEX" :key="f" :value="f">{{ f || '(por defecto)' }}</option>
						</select>
					</label>
				</div>
				<p class="muted">Se generará una sala rectangular con muro perimetral, sala de spawn con antorchas y punto de entrada.</p>
			</template>

			<template v-if="step===3">
				<h3 class="sec">3. Vista previa</h3>
				<div class="wizard__card">
					<div class="wizard__card-icon">🕳️</div>
					<div class="wizard__card-body">
						<b>{{ nameEs || nameEn }}</b>
						<span class="muted">Tema: {{ theme }} · {{ width }}×{{ height }} · pared: {{ wallTex || 'por defecto' }} · suelo: {{ floorTex || 'por defecto' }}</span>
					</div>
				</div>
				<p class="muted" style="margin-top:10px">Se creará <span class="mono">data/dungeons/{{ dunId || suggestedId }}.json</span> y su entrada en <span class="mono">data/ids/</span> (type dungeon).</p>
			</template>
		</div>
		<template #footer>
			<button class="btn ghost sm" :disabled="step===1" @click="back">◀ Atrás</button>
			<span class="spacer"></span>
			<button v-if="step<TOTAL_STEPS" class="btn primary sm" :disabled="!canNext" @click="next">Siguiente ▶</button>
			<button v-else class="btn primary sm" @click="finish">✅ Crear mazmorra</button>
		</template>
	</ds-modal>
	`,
};
