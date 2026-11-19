// ui/DsEmpty.js
// ─────────────────────────────────────────────────────────────────────────────
// DESIGN SYSTEM · Estado vacío (Fase 1). Placeholder consistente para "no hay
// nada seleccionado / sin resultados / lista vacía", con icono, título, texto de
// ayuda y una acción opcional (slot).
//
// Props: icon, title, hint.
// Slots: #action (botón de acción sugerida).
// ─────────────────────────────────────────────────────────────────────────────
export default {
	name: 'DsEmpty',
	props: {
		icon: { type: String, default: '📭' },
		title: { type: String, default: 'Nada por aquí' },
		hint: { type: String, default: '' },
	},
	template: `
	<div class="ds-empty">
		<div class="ds-empty__icon">{{ icon }}</div>
		<div class="ds-empty__title">{{ title }}</div>
		<p v-if="hint" class="ds-empty__hint">{{ hint }}</p>
		<div v-if="$slots.action" class="ds-empty__action"><slot name="action"></slot></div>
	</div>
	`,
};
