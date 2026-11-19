// components/EditorSidebar.js
// ─────────────────────────────────────────────────────────────────────────────
// SHELL DE NAVEGACIÓN. Barra lateral VERTICAL que sustituye a
// la tira horizontal de pestañas (elimina el scroll horizontal). Ofrece DOS modos
// que editan exactamente la misma información:
//   · Modo Diseñador — organizado por grandes ÁREAS DE TRABAJO (por tarea).
//   · Modo Datos     — organizado por TIPOS DE DATO (las pestañas de siempre).
// Incluime además Favoritos y Recientes (persistentes) y colapsado de la barra.
//
// No conoce ningún editor concreto: navega vía `goTo(tab)` y delega QA/acciones
// especiales al padre mediante el evento 'action'.
// ─────────────────────────────────────────────────────────────────────────────
import { computed } from 'https://unpkg.com/vue@3/dist/vue.esm-browser.prod.js';
import { store, nav, setNavMode, toggleSidebar, setExpandedArea, toggleFavorite, isFavorite, t } from '../store.js';
import { TAB_META, DATA_GROUPS, DESIGNER_AREAS, entityName, goTo, getTabLabel } from '../nav.js';

export default {
	name: 'EditorSidebar',
	emits: ['action'],
	setup(props, { emit }) {
		const mode = computed(() => nav.mode);
		const collapsed = computed(() => nav.collapsed);

		function navTab(tab) { goTo(tab); }
		function openArea(area) {
			setExpandedArea(area.id);
			if (area.action) { emit('action', area.action); return; }
			if (area.tabs && area.tabs.length) goTo(area.tabs[0]);
		}
		function labelFor(entry) { return entityName(entry.tab, entry.id); }
		function iconFor(tab) { return TAB_META[tab] ? TAB_META[tab].icon : '•'; }
		function tabLabel(tab) { return getTabLabel(tab); }
		function isActiveTab(tab) { return store.activeTab === tab; }
		function goEntry(entry) { goTo(entry.tab, entry.id); }

		// ¿Está esta entrada (tab,id) actualmente activa? (para resaltar favoritos)
		function isActiveEntry(entry) {
			if (store.activeTab !== entry.tab) return false;
			const meta = TAB_META[entry.tab];
			if (!entry.id || !meta || !meta.sel) return true;
			return store[meta.sel] === entry.id;
		}

		return {
			store, nav, mode, collapsed,
			DATA_GROUPS, DESIGNER_AREAS,
			setNavMode, toggleSidebar, toggleFavorite, isFavorite,
			navTab, openArea, labelFor, iconFor, tabLabel, isActiveTab, isActiveEntry, goEntry,
			t,
		};
	},
	template: `
	<aside class="nav-side" :class="{ 'is-collapsed': collapsed }">
		<div class="nav-side__top">
			<div v-if="!collapsed" class="nav-mode">
				<button :class="{ active: mode==='designer' }" @click="setNavMode('designer')" :title="t('sidebar.designer')">🎯 {{ t('sidebar.designer') }}</button>
				<button :class="{ active: mode==='data' }" @click="setNavMode('data')" :title="t('sidebar.data')">🗂️ {{ t('sidebar.data') }}</button>
			</div>
			<button class="nav-collapse" @click="toggleSidebar" :title="collapsed ? t('sidebar.expand') : t('sidebar.collapse')">{{ collapsed ? '»' : '«' }}</button>
		</div>

		<div class="nav-side__scroll">
			<!-- MODO DISEÑADOR -->
			<template v-if="mode==='designer'">
				<div v-for="area in DESIGNER_AREAS" :key="area.id" class="nav-area">
					<button class="nav-area__head" :class="{ open: nav.expandedArea===area.id }" @click="openArea(area)" :title="area.label">
						<span class="nav-ico">{{ area.icon }}</span>
						<span v-if="!collapsed" class="nav-area__label">{{ area.label }}</span>
						<span v-if="!collapsed && area.tabs && area.tabs.length>1" class="nav-area__chev">{{ nav.expandedArea===area.id ? '▾' : '▸' }}</span>
					</button>
					<div v-if="!collapsed && nav.expandedArea===area.id && area.tabs && area.tabs.length>1" class="nav-sub">
						<button v-for="t in area.tabs" :key="t" class="nav-sub__item" :class="{ active: isActiveTab(t) }" @click="navTab(t)">
							<span class="nav-ico">{{ iconFor(t) }}</span><span>{{ tabLabel(t) }}</span>
						</button>
					</div>
				</div>
			</template>

			<!-- MODO DATOS -->
			<template v-else>
				<div v-for="g in DATA_GROUPS" :key="g.id" class="nav-group">
					<div v-if="!collapsed" class="nav-group__label">{{ g.label }}</div>
					<button v-for="t in g.tabs" :key="t" class="nav-item" :class="{ active: isActiveTab(t) }" @click="navTab(t)" :title="tabLabel(t)">
						<span class="nav-ico">{{ iconFor(t) }}</span>
						<span v-if="!collapsed" class="nav-item__label">{{ tabLabel(t) }}</span>
					</button>
				</div>
			</template>

			<!-- FAVORITOS -->
			<div v-if="!collapsed && nav.favorites.length" class="nav-group nav-group--extra">
				<div class="nav-group__label">⭐ {{ t('sidebar.favorites') }}</div>
				<button v-for="(e,i) in nav.favorites" :key="'fav'+i" class="nav-item nav-item--entry"
					:class="{ active: isActiveEntry(e) }"
					@click="goEntry(e)" :title="labelFor(e)">
					<span class="nav-ico">{{ iconFor(e.tab) }}</span>
					<span class="nav-item__label">{{ labelFor(e) }}</span>
					<span class="nav-item__star" @click.stop="toggleFavorite(e)" title="Quitar de favoritos">✕</span>
				</button>
			</div>

			<!-- RECIENTES -->
			<div v-if="!collapsed && nav.recents.length" class="nav-group nav-group--extra">
				<div class="nav-group__label">🕘 {{ t('sidebar.recent') }}</div>
				<button v-for="(e,i) in nav.recents.slice(0,8)" :key="'rec'+i" class="nav-item nav-item--entry" @click="goEntry(e)" :title="labelFor(e)">
					<span class="nav-ico">{{ iconFor(e.tab) }}</span>
					<span class="nav-item__label">{{ labelFor(e) }}</span>
					<span class="nav-item__star" @click.stop="toggleFavorite(e)" :title="isFavorite(e.tab, e.id) ? 'Quitar de favoritos' : 'Añadir a favoritos'">{{ isFavorite(e.tab, e.id) ? '★' : '☆' }}</span>
				</button>
			</div>
		</div>

		<div class="nav-side__foot">
			<button class="nav-item" @click="$emit('action','qa')" title="Validación QA">
				<span class="nav-ico">🔎</span><span v-if="!collapsed" class="nav-item__label">Validar (QA)</span>
			</button>
		</div>
	</aside>
	`,
};
