// ui/DsFilterPanel.js
// ─────────────────────────────────────────────────────────────────────────────
// DESIGN SYSTEM · Panel de filtros (Fase 1). Renderiza un conjunto de selectores
// declarativos y expone su estado como objeto v-model { key: valor }. Incluye
// botón "limpiar" cuando hay algún filtro activo.
//
// Props:
//   filters {Array<{ key, label, options:Array<String|{value,label}> }>}
//   modelValue {Object}  estado { key: valor } (v-model).
// Emite: update:modelValue.
// ─────────────────────────────────────────────────────────────────────────────
export default {
	name: 'DsFilterPanel',
	props: {
		filters: { type: Array, default: () => [] },
		modelValue: { type: Object, default: () => ({}) },
	},
	emits: ['update:modelValue'],
	computed: {
		anyActive() { return Object.values(this.modelValue || {}).some(v => v !== '' && v != null); },
	},
	methods: {
		optValue(o) { return (o && typeof o === 'object') ? o.value : o; },
		optLabel(o) { return (o && typeof o === 'object') ? (o.label ?? o.value) : o; },
		set(key, val) { this.$emit('update:modelValue', { ...this.modelValue, [key]: val }); },
		clear() {
			const next = { ...this.modelValue };
			for (const f of this.filters) next[f.key] = '';
			this.$emit('update:modelValue', next);
		},
	},
	template: `
	<div class="ds-filters">
		<label v-for="f in filters" :key="f.key" class="ds-filters__item">
			<select class="input" :value="modelValue[f.key] || ''" @change="set(f.key, $event.target.value)">
				<option value="">{{ f.label }}: todos</option>
				<option v-for="o in f.options" :key="optValue(o)" :value="optValue(o)">{{ optLabel(o) }}</option>
			</select>
		</label>
		<button v-if="anyActive" class="btn sm ghost" @click="clear" title="Limpiar filtros">✕ Limpiar</button>
	</div>
	`,
};
