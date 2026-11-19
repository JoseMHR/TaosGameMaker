// ui/DsPalette.js
// ─────────────────────────────────────────────────────────────────────────────
// DESIGN SYSTEM · Paleta seleccionable (Fase 1). Lista vertical de opciones con
// swatch de color e/o icono, etiqueta y subtítulo. Selección simple o múltiple.
// La usan el editor de mapa (terrenos/recursos) y la mazmorra (tipos de celda).
//
// Props:
//   items {Array<{ value, label, color?, icon?, sub?, disabled? }>}
//   modelValue {String|Array}  valor(es) seleccionado(s) (v-model).
//   multiple {Boolean}         permite selección múltiple (modelValue = Array).
//   columns {Number}           nº de columnas (0 = lista vertical).
//   searchable {Boolean}       muestra un buscador que filtra por label/sub.
//   searchPlaceholder {String} placeholder del buscador.
// Emite: update:modelValue, 'select' (value).
// ─────────────────────────────────────────────────────────────────────────────
import { ref, computed } from 'https://unpkg.com/vue@3/dist/vue.esm-browser.prod.js';
import DsSearchInput from './DsSearchInput.js';

export default {
	name: 'DsPalette',
	components: { DsSearchInput },
	props: {
		items: { type: Array, default: () => [] },
		modelValue: { type: [String, Number, Array], default: '' },
		multiple: { type: Boolean, default: false },
		columns: { type: Number, default: 0 },
		searchable: { type: Boolean, default: false },
		searchPlaceholder: { type: String, default: 'Buscar…' },
	},
	emits: ['update:modelValue', 'select'],
	setup(props) {
		const q = ref('');
		const filtered = computed(() => {
			const s = q.value.trim().toLowerCase();
			if (!s) return props.items;
			return props.items.filter(it => (String(it.label || '') + ' ' + String(it.sub || '')).toLowerCase().includes(s));
		});
		const gridStyle = computed(() => props.columns > 0 ? { display: 'grid', gridTemplateColumns: 'repeat(' + props.columns + ', 1fr)' } : {});
		return { q, filtered, gridStyle };
	},
	methods: {
		isActive(v) { return this.multiple ? (Array.isArray(this.modelValue) && this.modelValue.includes(v)) : this.modelValue === v; },
		pick(it) {
			if (it.disabled) return;
			if (this.multiple) {
				const cur = Array.isArray(this.modelValue) ? this.modelValue.slice() : [];
				const i = cur.indexOf(it.value);
				if (i >= 0) cur.splice(i, 1); else cur.push(it.value);
				this.$emit('update:modelValue', cur);
			} else {
				this.$emit('update:modelValue', it.value);
			}
			this.$emit('select', it.value);
		},
	},
	template: `
	<div class="ds-palette-wrap">
		<ds-search-input v-if="searchable" v-model="q" :placeholder="searchPlaceholder" style="margin-bottom:8px"></ds-search-input>
		<div class="ds-palette" :style="gridStyle">
			<button v-for="it in filtered" :key="it.value" type="button"
				class="ds-palette__item" :class="{ active: isActive(it.value), 'is-disabled': it.disabled }"
				:disabled="it.disabled" :title="it.sub || it.label" @click="pick(it)">
				<span v-if="it.img" class="ds-palette__img-wrap">
					<img :src="it.img" class="ds-palette__img" alt=""
						@error="e => { e.target.style.display='none'; if (e.target.nextElementSibling) e.target.nextElementSibling.style.display='inline-block'; }" />
					<span class="ds-palette__icon" style="display:none">{{ it.icon || '❓' }}</span>
				</span>
				<span v-else-if="it.color" class="ds-palette__swatch" :style="{ background: it.color }"></span>
				<span v-else-if="it.icon" class="ds-palette__icon">{{ it.icon }}</span>
				<div class="ds-palette__text">
					<span class="ds-palette__label">{{ it.label }}</span>
					<div v-if="it.sub || (it.badges && it.badges.length)" class="ds-palette__sub-row">
						<span v-if="it.sub" class="ds-palette__sub">{{ it.sub }}</span>
						<span v-for="(b,bi) in (it.badges || [])" :key="bi" class="ds-palette__badge" :style="{ color: b.color || 'inherit' }">{{ b.text }}</span>
					</div>
				</div>
			</button>
			<div v-if="searchable && !filtered.length" class="ds-empty" style="padding:12px"><p class="muted" style="font-size:12px">Sin resultados para "{{ q }}".</p></div>
		</div>
	</div>
	`,
};
