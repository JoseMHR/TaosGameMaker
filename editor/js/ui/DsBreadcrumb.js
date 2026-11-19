// ui/DsBreadcrumb.js
// ─────────────────────────────────────────────────────────────────────────────
// DESIGN SYSTEM · Migas de pan (Fase 1). Ruta de navegación jerárquica, pensada
// para los Workspaces (p. ej. Mundo › Ciudad Imperial › Taberna). El último
// elemento es el actual (no cliqueable).
//
// Props: items {Array<{ label, icon?, id? }>}.
// Emite: 'navigate' (item, index).
// ─────────────────────────────────────────────────────────────────────────────
export default {
	name: 'DsBreadcrumb',
	props: {
		items: { type: Array, default: () => [] },
	},
	emits: ['navigate'],
	template: `
	<nav class="ds-breadcrumb">
		<template v-for="(it,i) in items" :key="i">
			<button v-if="i < items.length - 1" type="button" class="ds-breadcrumb__item" @click="$emit('navigate', it, i)">
				<span v-if="it.icon" class="ds-breadcrumb__icon">{{ it.icon }}</span>{{ it.label }}
			</button>
			<span v-else class="ds-breadcrumb__item is-current">
				<span v-if="it.icon" class="ds-breadcrumb__icon">{{ it.icon }}</span>{{ it.label }}
			</span>
			<span v-if="i < items.length - 1" class="ds-breadcrumb__sep">›</span>
		</template>
	</nav>
	`,
};
