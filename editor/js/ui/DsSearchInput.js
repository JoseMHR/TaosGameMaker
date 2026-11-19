// ui/DsSearchInput.js
// ─────────────────────────────────────────────────────────────────────────────
// DESIGN SYSTEM · Campo de búsqueda (Fase 1). Input con icono de lupa y botón de
// limpiar. Usa v-model estándar (modelValue / update:modelValue).
//
// Props: modelValue, placeholder, autofocus.
// Emite: update:modelValue, 'enter'.
// ─────────────────────────────────────────────────────────────────────────────
import { ref, onMounted } from 'https://unpkg.com/vue@3/dist/vue.esm-browser.prod.js';

export default {
	name: 'DsSearchInput',
	props: {
		modelValue: { type: String, default: '' },
		placeholder: { type: String, default: 'Buscar…' },
		autofocus: { type: Boolean, default: false },
	},
	emits: ['update:modelValue', 'enter'],
	setup(props) {
		const el = ref(null);
		onMounted(() => { if (props.autofocus && el.value) el.value.focus(); });
		return { el };
	},
	template: `
	<div class="ds-search">
		<span class="ds-search__icon">🔍</span>
		<input ref="el" class="ds-search__input" type="search" :value="modelValue"
			:placeholder="placeholder"
			@input="$emit('update:modelValue', $event.target.value)"
			@keydown.enter="$emit('enter', modelValue)" />
		<button v-if="modelValue" class="ds-search__clear" @click="$emit('update:modelValue','')" title="Limpiar">✕</button>
	</div>
	`,
};
