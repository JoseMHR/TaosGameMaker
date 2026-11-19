// ui/DsCard.js
// ─────────────────────────────────────────────────────────────────────────────
// DESIGN SYSTEM · Tarjeta (Fase 1). Contenedor con cabecera opcional (título,
// subtítulo, acciones) y cuerpo. Base visual para rejillas de contenido
// (ciudades, enemigos, objetos…). Puede ser seleccionable/cliqueable.
//
// Props: title, subtitle, icon, selected, clickable, tone ('' | 'ok' | 'warn' | 'err').
// Slots: default (cuerpo), #actions (cabecera derecha), #media (imagen/preview), #footer.
// Emite: 'click'.
// ─────────────────────────────────────────────────────────────────────────────
export default {
	name: 'DsCard',
	props: {
		title: { type: String, default: '' },
		subtitle: { type: String, default: '' },
		icon: { type: String, default: '' },
		selected: { type: Boolean, default: false },
		clickable: { type: Boolean, default: false },
		tone: { type: String, default: '' },
	},
	emits: ['click'],
	template: `
	<div class="ds-card" :class="[{ 'is-selected': selected, 'is-clickable': clickable }, tone ? 'ds-card--'+tone : '']"
		@click="clickable && $emit('click', $event)">
		<div v-if="$slots.media" class="ds-card__media"><slot name="media"></slot></div>
		<header v-if="title || subtitle || icon || $slots.actions" class="ds-card__head">
			<span v-if="icon" class="ds-card__icon">{{ icon }}</span>
			<div class="ds-card__titles" v-if="title || subtitle">
				<div v-if="title" class="ds-card__title">{{ title }}</div>
				<div v-if="subtitle" class="ds-card__subtitle">{{ subtitle }}</div>
			</div>
			<div class="ds-card__actions" v-if="$slots.actions" @click.stop><slot name="actions"></slot></div>
		</header>
		<div v-if="$slots.default" class="ds-card__body"><slot></slot></div>
		<footer v-if="$slots.footer" class="ds-card__foot"><slot name="footer"></slot></footer>
	</div>
	`,
};
