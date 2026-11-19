// ui/DsVirtualList.js
// ─────────────────────────────────────────────────────────────────────────────
// DESIGN SYSTEM · Lista virtualizada.
// Renderiza SOLO las filas visibles (ventana + overscan) de una lista enorme,
// manteniendo la barra de desplazamiento con espaciadores. Pensada para catálogos
// de miles de registros (5000 NPCs, 10000 diálogos…) sin degradar la UI.
//
// Props:
//   items {Array}          colección completa a mostrar.
//   itemHeight {Number}    alto FIJO de cada fila en px (por defecto 34).
//   overscan {Number}      filas extra arriba/abajo para un scroll suave.
//   keyField {String}      campo del item usado como :key (si no, se usa el índice).
// Slot (scoped): { item, index } por cada fila visible.
//
// Uso:
//   <ds-virtual-list :items="rows" :item-height="36" style="height:420px">
//     <template #default="{ item }"> … </template>
//   </ds-virtual-list>
// ─────────────────────────────────────────────────────────────────────────────
import { ref, computed, onMounted, onUnmounted } from 'https://unpkg.com/vue@3/dist/vue.esm-browser.prod.js';

export default {
	name: 'DsVirtualList',
	props: {
		items: { type: Array, default: () => [] },
		itemHeight: { type: Number, default: 34 },
		overscan: { type: Number, default: 6 },
		keyField: { type: String, default: '' },
	},
	setup(props) {
		const viewport = ref(null);
		const scrollTop = ref(0);
		const viewportH = ref(400);
		let ro = null;

		function onScroll(e) { scrollTop.value = e.target.scrollTop; }
		function measure() { if (viewport.value) viewportH.value = viewport.value.clientHeight || 400; }

		onMounted(() => {
			measure();
			if (typeof ResizeObserver !== 'undefined' && viewport.value) {
				ro = new ResizeObserver(measure);
				ro.observe(viewport.value);
			}
		});
		onUnmounted(() => { if (ro) { ro.disconnect(); ro = null; } });

		const total = computed(() => props.items.length);
		const startIndex = computed(() =>
			Math.max(0, Math.floor(scrollTop.value / props.itemHeight) - props.overscan));
		const visibleCount = computed(() =>
			Math.ceil(viewportH.value / props.itemHeight) + props.overscan * 2);
		const endIndex = computed(() =>
			Math.min(total.value, startIndex.value + visibleCount.value));
		const padTop = computed(() => startIndex.value * props.itemHeight);
		const padBottom = computed(() => Math.max(0, (total.value - endIndex.value) * props.itemHeight));

		// Filas visibles con su índice absoluto (para el :key y el slot).
		const slice = computed(() => {
			const out = [];
			for (let i = startIndex.value; i < endIndex.value; i++) {
				const item = props.items[i];
				const key = props.keyField && item && typeof item === 'object' ? item[props.keyField] : i;
				out.push({ item, index: i, key });
			}
			return out;
		});

		return { viewport, onScroll, padTop, padBottom, slice, total };
	},
	template: `
	<div ref="viewport" class="ds-vlist" @scroll="onScroll">
		<div class="ds-vlist__pad" :style="{ height: padTop + 'px' }"></div>
		<div v-for="row in slice" :key="row.key" class="ds-vlist__row">
			<slot :item="row.item" :index="row.index"></slot>
		</div>
		<div class="ds-vlist__pad" :style="{ height: padBottom + 'px' }"></div>
	</div>
	`,
};
