// ui/DsContextMenu.js
// ─────────────────────────────────────────────────────────────────────────────
// DESIGN SYSTEM · Menú contextual (Fase 1). Menú flotante posicionado en (x,y),
// data-driven a partir de una lista de items. Se teletransporta a <body> y se
// cierra al hacer clic fuera o pulsar ESC. Ajusta su posición para no salirse
// de la pantalla.
//
// Props:
//   open {Boolean}, x {Number}, y {Number}
//   items {Array<{ label, icon?, action?, danger?, divider?, disabled? }>}
// Emite: 'select' (item), 'close'.
//
// Uso típico: @contextmenu.prevent="openMenu($event)" que guarda x/y y open=true.
// ─────────────────────────────────────────────────────────────────────────────
import { ref, watch, nextTick, onMounted, onUnmounted } from 'https://unpkg.com/vue@3/dist/vue.esm-browser.prod.js';

export default {
	name: 'DsContextMenu',
	props: {
		open: { type: Boolean, default: false },
		x: { type: Number, default: 0 },
		y: { type: Number, default: 0 },
		items: { type: Array, default: () => [] },
	},
	emits: ['select', 'close'],
	setup(props, { emit }) {
		const menu = ref(null);
		const pos = ref({ left: props.x + 'px', top: props.y + 'px' });

		function reposition() {
			nextTick(() => {
				const el = menu.value;
				if (!el) return;
				const r = el.getBoundingClientRect();
				let left = props.x, top = props.y;
				if (left + r.width > window.innerWidth) left = Math.max(4, window.innerWidth - r.width - 4);
				if (top + r.height > window.innerHeight) top = Math.max(4, window.innerHeight - r.height - 4);
				pos.value = { left: left + 'px', top: top + 'px' };
			});
		}
		watch(() => props.open, (o) => { if (o) reposition(); });

		function onDocClick() { if (props.open) emit('close'); }
		function onKey(e) { if (e.key === 'Escape' && props.open) emit('close'); }
		onMounted(() => { window.addEventListener('click', onDocClick); window.addEventListener('keydown', onKey); });
		onUnmounted(() => { window.removeEventListener('click', onDocClick); window.removeEventListener('keydown', onKey); });

		function choose(it) {
			if (it.divider || it.disabled) return;
			emit('select', it);
			if (typeof it.action === 'function') it.action();
			emit('close');
		}
		return { menu, pos, choose };
	},
	template: `
	<teleport to="body">
		<div v-if="open" ref="menu" class="ds-ctxmenu" :style="pos" @click.stop @contextmenu.prevent>
			<template v-for="(it,i) in items" :key="i">
				<div v-if="it.divider" class="ds-ctxmenu__divider"></div>
				<button v-else type="button" class="ds-ctxmenu__item" :class="{ 'is-danger': it.danger, 'is-disabled': it.disabled }"
					:disabled="it.disabled" @click="choose(it)">
					<span class="ds-ctxmenu__icon">{{ it.icon || '' }}</span>
					<span class="ds-ctxmenu__label">{{ it.label }}</span>
					<span v-if="it.shortcut" class="ds-ctxmenu__kbd">{{ it.shortcut }}</span>
				</button>
			</template>
		</div>
	</teleport>
	`,
};
