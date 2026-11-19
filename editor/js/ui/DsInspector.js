// ui/DsInspector.js
// ─────────────────────────────────────────────────────────────────────────────
// DESIGN SYSTEM · Inspector contextual (Fase 1). Panel (normalmente a la derecha)
// que muestra las propiedades del elemento seleccionado. Cabecera con título +
// acciones y estado vacío integrado cuando no hay selección.
//
// Props: title, icon, empty (Boolean: no hay selección), emptyText.
// Slots: default (propiedades), #actions (cabecera), #empty (estado vacío custom).
// ─────────────────────────────────────────────────────────────────────────────
export default {
	name: 'DsInspector',
	props: {
		title: { type: String, default: 'Inspector' },
		icon: { type: String, default: '🔎' },
		empty: { type: Boolean, default: false },
		emptyText: { type: String, default: 'Selecciona un elemento para inspeccionarlo.' },
	},
	template: `
	<aside class="ds-inspector">
		<header class="ds-inspector__head">
			<span class="ds-inspector__title"><span class="ds-inspector__icon">{{ icon }}</span>{{ title }}</span>
			<div class="ds-inspector__actions"><slot name="actions"></slot></div>
		</header>
		<div class="ds-inspector__body">
			<template v-if="empty">
				<slot name="empty"><div class="ds-empty"><div class="ds-empty__icon">👀</div><p>{{ emptyText }}</p></div></slot>
			</template>
			<slot v-else></slot>
		</div>
	</aside>
	`,
};
