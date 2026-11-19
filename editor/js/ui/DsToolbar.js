// ui/DsToolbar.js
// ─────────────────────────────────────────────────────────────────────────────
// DESIGN SYSTEM · Toolbar genérica (Fase 1). Barra horizontal reutilizable con
// tres zonas por slots: #start (izquierda), default (centro) y #end (derecha),
// más un título opcional. NO impone acciones concretas (a diferencia del
// EditorToolbar de colección, que es específico del CRUD): sirve para cualquier
// cabecera de herramienta.
//
// Props: title, icon, dense (menos alto).
// ─────────────────────────────────────────────────────────────────────────────
export default {
	name: 'DsToolbar',
	props: {
		title: { type: String, default: '' },
		icon: { type: String, default: '' },
		dense: { type: Boolean, default: false },
	},
	template: `
	<div class="ds-toolbar" :class="{ 'ds-toolbar--dense': dense }">
		<span v-if="icon || title" class="ds-toolbar__title">
			<span v-if="icon" class="ds-toolbar__icon">{{ icon }}</span>{{ title }}
		</span>
		<slot name="start"></slot>
		<div class="ds-toolbar__mid"><slot></slot></div>
		<span class="ds-toolbar__spacer"></span>
		<slot name="end"></slot>
	</div>
	`,
};
