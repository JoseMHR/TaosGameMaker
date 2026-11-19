// ui/DsModal.js
// ─────────────────────────────────────────────────────────────────────────────
// DESIGN SYSTEM · Modal base (Fase 1). Overlay reutilizable que sirve de cimiento
// a los diálogos (confirmación, ayuda, formularios flotantes…). Se teletransporta
// a <body> para no verse afectado por overflow/stacking de los editores.
//
// Props:
//   open        {Boolean}  visibilidad controlada por el padre.
//   title       {String}   título de la cabecera (opcional; también hay slot #header).
//   size        {String}   'sm' | 'md' | 'lg' | 'xl' | 'full' (ancho máx.).
//   closable    {Boolean}  muestra la X y permite cerrar con backdrop/ESC.
//   backdrop    {Boolean}  cerrar al hacer clic fuera (por defecto = closable).
// Slots: default (cuerpo), #header, #footer.
// Emite: 'close'.
// ─────────────────────────────────────────────────────────────────────────────
import { onMounted, onUnmounted } from 'https://unpkg.com/vue@3/dist/vue.esm-browser.prod.js';

export default {
	name: 'DsModal',
	props: {
		open: { type: Boolean, default: false },
		title: { type: String, default: '' },
		size: { type: String, default: 'md' },
		closable: { type: Boolean, default: true },
		backdrop: { type: Boolean, default: null },
	},
	emits: ['close'],
	setup(props, { emit }) {
		function onKey(e) {
			if (e.key === 'Escape' && props.open && props.closable) emit('close');
		}
		function onBackdrop() {
			const allow = props.backdrop === null ? props.closable : props.backdrop;
			if (allow) emit('close');
		}
		onMounted(() => window.addEventListener('keydown', onKey));
		onUnmounted(() => window.removeEventListener('keydown', onKey));
		return { onBackdrop };
	},
	template: `
	<teleport to="body">
		<transition name="ds-modal-fade">
			<div v-if="open" class="ds-modal-backdrop" @mousedown.self="onBackdrop">
				<div class="ds-modal" :class="'ds-modal--'+size" role="dialog" aria-modal="true">
					<header class="ds-modal__head">
						<slot name="header"><h3 class="ds-modal__title">{{ title }}</h3></slot>
						<button v-if="closable" class="ds-modal__x" @click="$emit('close')" title="Cerrar (Esc)">✕</button>
					</header>
					<div class="ds-modal__body"><slot></slot></div>
					<footer v-if="$slots.footer" class="ds-modal__foot"><slot name="footer"></slot></footer>
				</div>
			</div>
		</transition>
	</teleport>
	`,
};
