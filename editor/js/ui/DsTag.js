// ui/DsTag.js
// ─────────────────────────────────────────────────────────────────────────────
// DESIGN SYSTEM · Etiqueta (Fase 1). Pastilla pequeña para clasificar (tipo,
// elemento, categoría…). Admite color arbitrario o un tono semántico, icono y
// un modo "removable" con botón ✕.
//
// Props: label, icon, color (CSS válido), tone ('' | 'accent' | 'ok' | 'warn' | 'err'),
//        removable, size ('sm' | 'md').
// Emite: 'remove'.
// ─────────────────────────────────────────────────────────────────────────────
export default {
	name: 'DsTag',
	props: {
		label: { type: [String, Number], default: '' },
		icon: { type: String, default: '' },
		color: { type: String, default: '' },
		tone: { type: String, default: '' },
		removable: { type: Boolean, default: false },
		size: { type: String, default: 'md' },
	},
	emits: ['remove'],
	computed: {
		style() {
			if (!this.color) return {};
			return { '--ds-tag-color': this.color, borderColor: this.color, color: this.color };
		},
	},
	template: `
	<span class="ds-tag" :class="['ds-tag--'+size, tone ? 'ds-tag--'+tone : '']" :style="style">
		<span v-if="icon" class="ds-tag__icon">{{ icon }}</span>
		<span class="ds-tag__label"><slot>{{ label }}</slot></span>
		<button v-if="removable" class="ds-tag__x" @click.stop="$emit('remove')" title="Quitar">✕</button>
	</span>
	`,
};
