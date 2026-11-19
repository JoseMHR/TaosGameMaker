// components/ItemWizardModal.js
// ─────────────────────────────────────────────────────────────────────────────
// ASISTENTE DE CREACIÓN DE OBJETOS (Task 5, 2.1). Modal guiado de 4 pasos que
// genera una entrada completa y coherente en `data/items/<id>.json` sin tocar
// JSON a mano: 1) nombre bilingüe + tipo, 2) icono, 3) estadísticas (según
// tipo) con precio sugerido por curva de tier/nivel, 4) vista previa de la
// tarjeta final. Se abre desde ItemsManager.js (botón "🧙 Asistente").
//
// El esquema real de items.json (ver ItemsManager.js) usa `category`
// (consumable/equipment/important/other) + `slot` para equipamiento, NO los
// tipos ilustrativos del documento de la tarea (weapon/armor/usable/material/
// key_item): este wizard se ajusta al modelo de datos REAL del motor.
// ─────────────────────────────────────────────────────────────────────────────
import { ref, computed, watch } from 'https://unpkg.com/vue@3/dist/vue.esm-browser.prod.js';
import { store, markDirty, flash, ITEM_CATEGORIES, EQUIP_SLOTS, STAT_KEYS, COMBAT_KEYS } from '../store.js';
import { goTo } from '../nav.js';

const CATEGORY_LABELS = { consumable: 'Consumible', equipment: 'Equipamiento', important: 'Objeto importante (clave)', other: 'Otro' };
const SLOT_ICONS = { weapon: '🗡️', shield: '🛡️', armor: '👕', helmet: '🪖', shoes: '🥾', accessory: '💍' };
// Selector visual de icono (los objetos de este motor usan un emoji como
// icono, no un sprite en disco; ver ItemsManager.js `icon`). Agrupado por tipo
// de objeto para que sea rápido encontrar uno adecuado.
const ICON_GROUPS = [
	{ label: 'Armas', icons: ['🗡️', '⚔️', '🏹', '🔫', '🪓', '🔨', '🗿'] },
	{ label: 'Armadura', icons: ['🛡️', '👕', '🪖', '🥾', '💍', '🧤', '👑'] },
	{ label: 'Consumibles', icons: ['🧪', '🍎', '🍖', '🍞', '🍯', '💊', '🍄'] },
	{ label: 'Materiales', icons: ['🟫', '🪨', '🪵', '🧵', '🦴', '🪶', '🥚'] },
	{ label: 'Objetos clave', icons: ['🔑', '🗝️', '📜', '🗺️', '💎', '⚱️', '🏆'] },
];

function uniqueItemId(base) {
	let id = base, n = 1;
	while (store.items && store.items[id]) id = base + '_' + (++n);
	return id;
}
function slugify(s) {
	return (s || '').toLowerCase().trim()
		.normalize('NFD').replace(/[\u0300-\u036f]/g, '')
		.replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '') || 'item_nuevo';
}
/** Precio sugerido (solo informativo: items.json no guarda precio, se fija por tienda). */
function suggestedPrice(category, tier) {
	if (category === 'equipment') { const buy = 80 + (tier - 1) * 120; return { buy, sell: Math.round(buy / 3) }; }
	if (category === 'consumable') return { buy: 25, sell: 8 };
	return { buy: 0, sell: 0 };
}

export default {
	name: 'ItemWizardModal',
	props: { open: { type: Boolean, default: false } },
	emits: ['close', 'created'],
	setup(props, { emit }) {
		const step = ref(1);
		const TOTAL_STEPS = 4;

		const nameText = ref('');
		const category = ref('equipment');
		const slot = ref('weapon');
		const icon = ref('🗡️');
		const tier = ref(1);
		const bonuses = ref({});
		const combat = ref({});
		const healPct = ref(0);
		const manaPct = ref(0);

		function reset() {
			step.value = 1; nameText.value = ''; category.value = 'equipment'; slot.value = 'weapon';
			icon.value = '🗡️'; tier.value = 1; bonuses.value = {}; combat.value = {}; healPct.value = 0; manaPct.value = 0;
		}
		watch(() => props.open, (o) => { if (o) reset(); });

		const suggestedId = computed(() => slugify(nameText.value || 'item_nuevo'));
		const price = computed(() => suggestedPrice(category.value, tier.value));

		const canNext = computed(() => {
			if (step.value === 1) return !!nameText.value.trim();
			return true;
		});

		function setBonus(k, v) { bonuses.value[k] = Number(v) || 0; }
		function setCombat(k, v) { combat.value[k] = Number(v) || 0; }

		function next() { if (canNext.value && step.value < TOTAL_STEPS) step.value++; }
		function back() { if (step.value > 1) step.value--; }

		function finish() {
			const id = uniqueItemId(suggestedId.value);
			const lang = store.currentLang || 'es';
			const item = {
				name: { [lang]: nameText.value.trim(), es: nameText.value.trim(), en: nameText.value.trim() },
				desc: { es: '', en: '' },
				icon: icon.value || '❓',
				category: category.value,
				usable: category.value === 'consumable',
			};
			if (category.value === 'equipment') {
				item.slot = slot.value;
				item.tier = tier.value;
				const b = {}; for (const k of STAT_KEYS) if (bonuses.value[k]) b[k] = bonuses.value[k];
				const c = {}; for (const k of COMBAT_KEYS) if (combat.value[k]) c[k] = combat.value[k];
				item.bonuses = b; item.combat = c;
			} else if (category.value === 'consumable') {
				item.effects = {};
				if (healPct.value) item.effects.heal_pct = healPct.value / 100;
				if (manaPct.value) item.effects.mana_pct = manaPct.value / 100;
			}
			if (!store.items) store.items = {};
			store.items[id] = item;
			markDirty('items', id);
			flash('🧙 Objeto creado: ' + id);
			goTo('items', id);
			emit('created', id);
			emit('close');
		}

		return {
			store, step, TOTAL_STEPS, nameText, category, slot, icon, tier,
			bonuses, combat, healPct, manaPct,
			ITEM_CATEGORIES, CATEGORY_LABELS, EQUIP_SLOTS, SLOT_ICONS, ICON_GROUPS,
			STAT_KEYS, COMBAT_KEYS, suggestedId, price,
			canNext, next, back, finish, setBonus, setCombat,
		};
	},
	template: `
	<ds-modal :open="open" size="lg" title="🧙 Asistente de creación de objeto" @close="$emit('close')">
		<div class="wizard">
			<div class="wizard__steps">
				<div class="wizard__step" v-for="n in TOTAL_STEPS" :key="n" :class="{ active: step===n, done: step>n }">{{ n }}</div>
			</div>

			<template v-if="step===1">
				<h3 class="sec">1. Nombre y tipo</h3>
				<div class="form-grid">
					<label>Nombre [{{ store.currentLang.toUpperCase() }}] <input class="input" type="text" v-model="nameText" :placeholder="store.currentLang === 'es' ? 'Espada de hierro' : 'Iron Sword'" /></label>
					<label class="full">Tipo
						<select class="input" v-model="category">
							<option v-for="c in ITEM_CATEGORIES" :key="c" :value="c">{{ CATEGORY_LABELS[c] }}</option>
						</select>
					</label>
					<label v-if="category==='equipment'">Slot de equipamiento
						<select class="input" v-model="slot">
							<option v-for="s in EQUIP_SLOTS" :key="s" :value="s">{{ SLOT_ICONS[s] }} {{ s }}</option>
						</select>
					</label>
				</div>
				<p class="muted">ID generado: <span class="mono">{{ suggestedId }}</span></p>
			</template>

			<template v-if="step===2">
				<h3 class="sec">2. Icono</h3>
				<div v-for="g in ICON_GROUPS" :key="g.label" style="margin-bottom:10px">
					<div class="muted" style="font-size:11px; margin-bottom:4px">{{ g.label }}</div>
					<div class="wizard__icon-grid">
						<button v-for="ic in g.icons" :key="ic" class="wizard__icon-btn" :class="{ active: icon===ic }" @click="icon=ic" type="button">{{ ic }}</button>
					</div>
				</div>
				<label>Icono personalizado (emoji u otro texto corto) <input class="input f-xs" type="text" v-model="icon" /></label>
			</template>

			<template v-if="step===3">
				<h3 class="sec">3. Estadísticas</h3>
				<template v-if="category==='equipment'">
					<div class="form-grid">
						<label>Tier (1-5)
							<select class="input" v-model.number="tier">
								<option v-for="t in [1,2,3,4,5]" :key="t" :value="t">Tier {{ t }}</option>
							</select>
						</label>
					</div>
					<div class="sub">Bonos de atributo</div>
					<div class="mini-grid">
						<label v-for="k in STAT_KEYS" :key="k">{{ k.toUpperCase() }}
							<input class="input num" type="number" :value="bonuses[k]||0" @input="setBonus(k,$event.target.value)" />
						</label>
					</div>
					<div class="sub">Bonos de combate</div>
					<div class="mini-grid">
						<label v-for="k in COMBAT_KEYS" :key="k">{{ k }}
							<input class="input num" type="number" :value="combat[k]||0" @input="setCombat(k,$event.target.value)" />
						</label>
					</div>
					<p class="muted" style="margin-top:10px">💰 Precio sugerido por curva de tier (informativo; se fija por tienda en ShopsManager): compra ≈ <b>{{ price.buy }}</b> oro · venta ≈ <b>{{ price.sell }}</b> oro.</p>
				</template>
				<template v-else-if="category==='consumable'">
					<div class="form-grid">
						<label>Curar HP (% del máx.) <input class="input num" type="number" min="0" max="100" v-model.number="healPct" /></label>
						<label>Restaurar MP (% del máx.) <input class="input num" type="number" min="0" max="100" v-model.number="manaPct" /></label>
					</div>
					<p class="muted" style="margin-top:10px">💰 Precio sugerido: compra ≈ <b>{{ price.buy }}</b> oro · venta ≈ <b>{{ price.sell }}</b> oro.</p>
				</template>
				<template v-else>
					<p class="muted">Este tipo de objeto no lleva estadísticas de combate.</p>
				</template>
			</template>

			<template v-if="step===4">
				<h3 class="sec">4. Vista previa</h3>
				<div class="wizard__card">
					<div class="wizard__card-icon">{{ icon }}</div>
					<div class="wizard__card-body">
						<b>{{ nameEs || nameEn }}</b>
						<span class="muted">{{ CATEGORY_LABELS[category] }}<template v-if="category==='equipment'"> · {{ slot }} · Tier {{ tier }}</template></span>
						<div class="wizard__card-stats" v-if="category==='equipment'">
							<span v-for="(v,k) in bonuses" :key="'b'+k" class="mono">+{{ v }} {{ k.toUpperCase() }}</span>
							<span v-for="(v,k) in combat" :key="'c'+k" class="mono">+{{ v }} {{ k }}</span>
						</div>
						<div class="wizard__card-stats" v-else-if="category==='consumable'">
							<span v-if="healPct" class="mono">+{{ healPct }}% HP</span>
							<span v-if="manaPct" class="mono">+{{ manaPct }}% MP</span>
						</div>
					</div>
				</div>
				<p class="muted" style="margin-top:10px">Se creará <span class="mono">data/items/{{ suggestedId }}.json</span>.</p>
			</template>
		</div>
		<template #footer>
			<button class="btn ghost sm" :disabled="step===1" @click="back">◀ Atrás</button>
			<span class="spacer"></span>
			<button v-if="step<TOTAL_STEPS" class="btn primary sm" :disabled="!canNext" @click="next">Siguiente ▶</button>
			<button v-else class="btn primary sm" @click="finish">✅ Crear objeto</button>
		</template>
	</ds-modal>
	`,
};
