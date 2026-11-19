// ui/DsBadge.js
// ─────────────────────────────────────────────────────────────────────────────
// DESIGN SYSTEM · Insignia (Fase 1). Contador o indicador de estado compacto,
// pensado para acompañar títulos de secciones/pestañas ("NPCs 128") o marcar
// estados ("●"). Distinto de DsTag: la badge es numérica/puntual, no clasifica.
//
// Props: value (número o texto), tone ('' | 'accent' | 'ok' | 'warn' | 'err'),
//        dot (solo punto sin texto).
// ─────────────────────────────────────────────────────────────────────────────
export default {
	name: 'DsBadge',
	props: {
		value: { type: [String, Number], default: '' },
		tone: { type: String, default: '' },
		dot: { type: Boolean, default: false },
	},
	template: `
	<span class="ds-badge" :class="[tone ? 'ds-badge--'+tone : '', { 'ds-badge--dot': dot }]">
		<template v-if="!dot"><slot>{{ value }}</slot></template>
	</span>
	`,
};
