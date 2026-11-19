// ui/DsSplitPanel.js
// ─────────────────────────────────────────────────────────────────────────────
// DESIGN SYSTEM · Panel dividido redimensionable (Fase 1). Dos zonas (slots
// #start y #end) separadas por un divisor arrastrable. Horizontal o vertical.
// El tamaño se PERSISTE en localStorage si se pasa `persistKey`, cumpliendo el
// requisito de "persistencia del layout" y "paneles redimensionables".
//
// Props:
//   direction {String}  'horizontal' (columnas) | 'vertical' (filas).
//   initial {Number}    tamaño inicial del panel #start en px.
//   min {Number}, minEnd {Number}  tamaños mínimos en px.
//   persistKey {String} clave de localStorage para recordar el tamaño.
// ─────────────────────────────────────────────────────────────────────────────
import { ref, computed, onMounted, onUnmounted } from 'https://unpkg.com/vue@3/dist/vue.esm-browser.prod.js';

export default {
	name: 'DsSplitPanel',
	props: {
		direction: { type: String, default: 'horizontal' },
		initial: { type: Number, default: 280 },
		min: { type: Number, default: 160 },
		minEnd: { type: Number, default: 160 },
		persistKey: { type: String, default: '' },
	},
	setup(props) {
		const root = ref(null);
		const stored = props.persistKey ? Number(localStorage.getItem('ds-split:' + props.persistKey)) : NaN;
		const size = ref(Number.isFinite(stored) && stored > 0 ? stored : props.initial);
		const dragging = ref(false);
		const isH = computed(() => props.direction !== 'vertical');

		const startStyle = computed(() => isH.value ? { width: size.value + 'px' } : { height: size.value + 'px' });

		function onDown(e) {
			dragging.value = true;
			e.preventDefault();
			window.addEventListener('mousemove', onMove);
			window.addEventListener('mouseup', onUp);
		}
		function onMove(e) {
			if (!dragging.value || !root.value) return;
			const r = root.value.getBoundingClientRect();
			let s = isH.value ? (e.clientX - r.left) : (e.clientY - r.top);
			const total = isH.value ? r.width : r.height;
			s = Math.max(props.min, Math.min(s, total - props.minEnd));
			size.value = Math.round(s);
		}
		function onUp() {
			dragging.value = false;
			window.removeEventListener('mousemove', onMove);
			window.removeEventListener('mouseup', onUp);
			if (props.persistKey) localStorage.setItem('ds-split:' + props.persistKey, String(size.value));
		}
		onUnmounted(() => { window.removeEventListener('mousemove', onMove); window.removeEventListener('mouseup', onUp); });

		return { root, size, dragging, isH, startStyle, onDown };
	},
	template: `
	<div ref="root" class="ds-split" :class="[isH ? 'ds-split--h' : 'ds-split--v', { 'is-dragging': dragging }]">
		<div class="ds-split__start" :style="startStyle"><slot name="start"></slot></div>
		<div class="ds-split__divider" @mousedown="onDown"><span class="ds-split__grip"></span></div>
		<div class="ds-split__end"><slot name="end"></slot></div>
	</div>
	`,
};
