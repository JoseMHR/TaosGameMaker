// components/NpcPoiWizardModal.js
// ─────────────────────────────────────────────────────────────────────────────
// ASISTENTE ATÓMICO DE PNJ Y POI (Task 5, 2.2). En un solo flujo guiado:
//   1) Registra el POI en `data/ids/<poi_id>.json` (y opcionalmente su posición
//      en `world.json`, campo `object` de la casilla — ver MapEditor.js).
//   2) Crea la ficha del PNJ en `data/npcs/<npc_id>.json` con su retrato (o sin
//      él, para un "lugar simple": ver el hallazgo de IdsManager.js sobre NPCs
//      sin avatar).
//   3) Genera el nodo raíz de bienvenida (`_meta` + `<npc_id>_1`).
//
// NOTA de fidelidad al motor: el documento de la tarea menciona generar el
// nodo de bienvenida en `data/dialogues.json`, pero ese fichero es un sistema
// DISTINTO (popups guionizados de una sola pantalla, ver DialoguesManager.js).
// El texto que el jugador ve al visitar un POI sale de `npcs.json` (ver
// ViewPlace.gd / NpcEditor.js), así que el "nodo de bienvenida" se genera ahí,
// que es el lugar real que consume el motor.
// ─────────────────────────────────────────────────────────────────────────────
import { ref, computed, watch } from 'https://unpkg.com/vue@3/dist/vue.esm-browser.prod.js';
import { store, markDirty, markWorldDirty, flash, POI_KINDS } from '../store.js';
import { goTo } from '../nav.js';

function slugify(s) {
	return (s || '').toLowerCase().trim()
		.normalize('NFD').replace(/[\u0300-\u036f]/g, '')
		.replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '') || 'poi_nuevo';
}
function uniqueId(dict, base) {
	let id = base, n = 1;
	while (dict && dict[id]) id = base + '_' + (++n);
	return id;
}

export default {
	name: 'NpcPoiWizardModal',
	props: { open: { type: Boolean, default: false } },
	emits: ['close', 'created'],
	setup(props, { emit }) {
		const step = ref(1);
		const TOTAL_STEPS = 4;

		const poiId = ref('');
		const nameText = ref('');
		const icon = ref('📍');
		const kind = ref('');
		const placeOnMap = ref(false);
		const posX = ref(0);
		const posY = ref(0);

		const npcId = ref('');
		const npcIdTouched = ref(false);
		const hasAvatar = ref(false);
		const avatar = ref('');

		const welcomeText = ref('');

		function reset() {
			step.value = 1; poiId.value = ''; nameText.value = ''; icon.value = '📍'; kind.value = '';
			placeOnMap.value = false; posX.value = 0; posY.value = 0;
			npcId.value = ''; npcIdTouched.value = false; hasAvatar.value = false; avatar.value = '';
			welcomeText.value = '';
		}
		watch(() => props.open, (o) => { if (o) reset(); });

		const suggestedPoiId = computed(() => 'poi_' + slugify(nameText.value || 'nuevo'));
		watch(nameText, () => { if (!poiId.value) poiId.value = suggestedPoiId.value; if (!npcIdTouched.value) npcId.value = poiId.value || suggestedPoiId.value; });
		watch(poiId, (v) => { if (!npcIdTouched.value) npcId.value = v; });

		const mapBounds = computed(() => {
			const w = store.world;
			return w && Array.isArray(w.tiles) ? { w: w.tiles[0]?.length || 0, h: w.tiles.length } : { w: 0, h: 0 };
		});

		const canNext = computed(() => {
			if (step.value === 1) return !!nameText.value.trim();
			if (step.value === 2) return !!(npcId.value || '').trim();
			return true;
		});

		function next() { if (canNext.value && step.value < TOTAL_STEPS) step.value++; }
		function back() { if (step.value > 1) step.value--; }

		function finish() {
			const pid = uniqueId(store.ids, slugify(poiId.value || suggestedPoiId.value));
			const nid = uniqueId(store.npcs, slugify(npcId.value || pid));
			const lang = store.currentLang || 'es';

			// 1) POI en data/ids/
			if (!store.ids) store.ids = {};
			const poi = {
				id: pid, type: 'poi',
				name: { [lang]: nameText.value.trim(), es: nameText.value.trim(), en: nameText.value.trim() },
				icon: icon.value || '📍',
				npc: nid,
			};
			if (kind.value) poi.kind = kind.value;
			store.ids[pid] = poi;
			markDirty('ids', pid);

			// 1b) Posición opcional en el mapamundi (world.json activo).
			if (placeOnMap.value && store.world && Array.isArray(store.world.tiles)) {
				const row = store.world.tiles[posY.value];
				if (row && row[posX.value]) { row[posX.value].object = pid; markWorldDirty(); }
			}

			// 2) NPC en data/npcs/ + 3) nodo de bienvenida.
			if (!store.npcs) store.npcs = {};
			const npc = {
				_meta: {
					type: 'meta',
					text: { [lang]: nameText.value.trim(), es: nameText.value.trim(), en: nameText.value.trim() },
					next: [], reward: '',
				},
				[nid + '_1']: {
					type: 'message',
					text: { [lang]: welcomeText.value, es: welcomeText.value, en: welcomeText.value },
					next: ['close'],
					reward: '',
				},
			};
			if (hasAvatar.value && avatar.value.trim()) npc._meta.avatar = avatar.value.trim();
			store.npcs[nid] = npc;
			markDirty('npcs', nid);

			flash('🧙 POI + PNJ creados: ' + pid + ' / ' + nid);
			goTo('ids', pid);
			emit('created', { poiId: pid, npcId: nid });
			emit('close');
		}

		return {
			store, step, TOTAL_STEPS, poiId, nameText, icon, kind, POI_KINDS,
			placeOnMap, posX, posY, mapBounds,
			npcId, npcIdTouched, hasAvatar, avatar, welcomeText,
			suggestedPoiId, canNext, next, back, finish,
		};
	},
	template: `
	<ds-modal :open="open" size="lg" title="🧙 Asistente de PNJ + POI" @close="$emit('close')">
		<div class="wizard">
			<div class="wizard__steps">
				<div class="wizard__step" v-for="n in TOTAL_STEPS" :key="n" :class="{ active: step===n, done: step>n }">{{ n }}</div>
			</div>

			<template v-if="step===1">
				<h3 class="sec">1. Lugar (POI)</h3>
				<div class="form-grid">
					<label>Nombre [{{ store.currentLang.toUpperCase() }}] <input class="input" type="text" v-model="nameText" :placeholder="store.currentLang === 'es' ? 'Ruinas del Bosque' : 'Forest Ruins'" /></label>
					<label>ID del POI <input class="input mono" type="text" v-model="poiId" :placeholder="suggestedPoiId" /></label>
					<label>Icono <input class="input f-xs" type="text" v-model="icon" /></label>
					<label>Tipo (kind, opcional — solo si es hijo de una ciudad)
						<select class="input" v-model="kind">
							<option value="">(ninguno — POI independiente del mapamundi)</option>
							<option v-for="k in POI_KINDS.filter(k=>k)" :key="k" :value="k">{{ k }}</option>
						</select>
					</label>
				</div>
				<label class="check" style="margin-top:8px">
					<input type="checkbox" v-model="placeOnMap" /> Colocar en el mapamundi activo ({{ mapBounds.w }}×{{ mapBounds.h }})
				</label>
				<div class="form-grid" v-if="placeOnMap">
					<label>X <input class="input num" type="number" min="0" :max="mapBounds.w-1" v-model.number="posX" /></label>
					<label>Y <input class="input num" type="number" min="0" :max="mapBounds.h-1" v-model.number="posY" /></label>
				</div>
			</template>

			<template v-if="step===2">
				<h3 class="sec">2. Personaje (PNJ)</h3>
				<div class="form-grid">
					<label class="full">ID del PNJ <input class="input mono" type="text" v-model="npcId" @input="npcIdTouched=true" /></label>
				</div>
				<label class="check" style="margin-top:8px">
					<input type="checkbox" v-model="hasAvatar" /> Tiene retrato (personaje visible)
				</label>
				<p v-if="!hasAvatar" class="muted" style="margin-top:6px">Sin retrato se crea un "lugar simple" (solo fondo + texto), como <span class="mono">poi_presa_001</span> o <span class="mono">poi_monkey_001</span>.</p>
				<div class="form-grid" v-if="hasAvatar">
					<label class="full">Sprite (nombre de fichero en assets/npcs/) <input class="input mono" type="text" v-model="avatar" :placeholder="'npc_' + npcId + '.png'" /></label>
				</div>
			</template>

			<template v-if="step===3">
				<h3 class="sec">3. Mensaje de bienvenida</h3>
				<p class="muted">Primer texto que verá el jugador al visitar el lugar (nodo <span class="mono">{{ npcId }}_1</span>).</p>
				<div>
					<label>Texto [{{ store.currentLang.toUpperCase() }}] <textarea class="input" v-model="welcomeText" :placeholder="store.currentLang === 'es' ? 'Bienvenido a este lugar...' : 'Welcome to this place...'"></textarea></label>
				</div>
			</template>

			<template v-if="step===4">
				<h3 class="sec">4. Vista previa</h3>
				<div class="wizard__card">
					<div class="wizard__card-icon">{{ icon }}</div>
					<div class="wizard__card-body">
						<b>{{ nameEs || nameEn }}</b>
						<span class="muted">POI <span class="mono">{{ poiId || suggestedPoiId }}</span> → PNJ <span class="mono">{{ npcId }}</span>{{ hasAvatar ? ' (con retrato)' : ' (lugar simple)' }}</span>
						<span class="muted" v-if="placeOnMap">📍 Mapa: ({{ posX }}, {{ posY }})</span>
						<span class="muted">"{{ welcomeEs || welcomeEn || '(sin texto)' }}"</span>
					</div>
				</div>
				<p class="muted" style="margin-top:10px">Se crearán <span class="mono">data/ids/{{ poiId || suggestedPoiId }}.json</span> y <span class="mono">data/npcs/{{ npcId }}.json</span>.</p>
			</template>
		</div>
		<template #footer>
			<button class="btn ghost sm" :disabled="step===1" @click="back">◀ Atrás</button>
			<span class="spacer"></span>
			<button v-if="step<TOTAL_STEPS" class="btn primary sm" :disabled="!canNext" @click="next">Siguiente ▶</button>
			<button v-else class="btn primary sm" @click="finish">✅ Crear POI + PNJ</button>
		</template>
	</ds-modal>
	`,
};
