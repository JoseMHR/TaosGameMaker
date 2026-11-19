// components/GlobalSearch.js
// ─────────────────────────────────────────────────────────────────────────────
// BÚSQUEDA GLOBAL. Paleta de comandos/búsqueda que recorre TODAS
// las colecciones (entidades, NPCs, enemigos, objetos, skills, eventos…) y permite
// saltar a cualquiera con teclado. Se abre con Ctrl/Cmd+K o desde la topbar.
//
// Reutiliza el Design System: DsModal + DsSearchInput. La lógica de búsqueda vive
// en nav.js (`globalSearch`), genérica y acotada por rendimiento.
//
// Task 5 (1.1): además de buscar entidades, admite un "Modo Comando": si el
// texto empieza por `>` se listan acciones rápidas (`COMMANDS`/`searchCommands`
// en nav.js) en vez de resultados de entidad — p. ej. `> Nuevo Objeto`,
// `> Validar Datos`, `> Exportar Todo`, `> Limpiar Caché`.
// ─────────────────────────────────────────────────────────────────────────────
import { ref, computed, watch } from 'https://unpkg.com/vue@3/dist/vue.esm-browser.prod.js';
import { globalSearch, goTo, TAB_META, searchCommands } from '../nav.js';

export default {
	name: 'GlobalSearch',
	props: { open: { type: Boolean, default: false } },
	emits: ['close'],
	setup(props, { emit }) {
		const query = ref('');
		const commandMode = computed(() => query.value.trimStart().startsWith('>'));
		const commands = computed(() => commandMode.value ? searchCommands(query.value.trimStart().slice(1)) : []);
		const groups = computed(() => commandMode.value ? [] : globalSearch(query.value));
		// Lista plana para navegación con teclado (entidades o comandos, según el modo).
		const flat = computed(() => {
			if (commandMode.value) return commands.value.map(c => ({ command: c }));
			const out = [];
			for (const g of groups.value) for (const it of g.items) out.push({ tab: g.tab, id: it.id, name: it.name });
			return out;
		});
		const active = ref(0);
		watch(query, () => { active.value = 0; });
		watch(() => props.open, (o) => { if (o) { query.value = ''; active.value = 0; } });

		function choose(entry) {
			if (!entry) return;
			if (entry.command) { entry.command.run(); emit('close'); return; }
			goTo(entry.tab, entry.id);
			emit('close');
		}
		function onKeydown(e) {
			if (e.key === 'ArrowDown') { e.preventDefault(); active.value = Math.min(active.value + 1, flat.value.length - 1); }
			else if (e.key === 'ArrowUp') { e.preventDefault(); active.value = Math.max(active.value - 1, 0); }
			else if (e.key === 'Enter') { e.preventDefault(); choose(flat.value[active.value]); }
		}
		function flatIndex(tab, id) { return flat.value.findIndex(f => f.tab === tab && f.id === id); }
		function commandIndex(id) { return flat.value.findIndex(f => f.command && f.command.id === id); }

		return { query, groups, commandMode, commands, flat, active, choose, onKeydown, flatIndex, commandIndex, TAB_META };
	},
	template: `
	<ds-modal :open="open" size="md" @close="$emit('close')">
		<template #header>
			<div class="gsearch__head" @keydown="onKeydown">
				<ds-search-input v-model="query" :autofocus="true" placeholder="Buscar en todo el proyecto… o escribe &gt; para comandos (↑↓ y Enter)"></ds-search-input>
			</div>
		</template>
		<div class="gsearch" @keydown="onKeydown">
			<template v-if="commandMode">
				<div v-if="!commands.length" class="ds-empty"><div class="ds-empty__icon">🫥</div><p>Sin comandos para "{{ query }}".</p></div>
				<div v-else class="gsearch__group">
					<div class="gsearch__grouphead"><span>⚡</span>Comandos</div>
					<button v-for="c in commands" :key="c.id" class="gsearch__item"
						:class="{ active: commandIndex(c.id) === active }"
						@click="choose({ command: c })" @mouseenter="active = commandIndex(c.id)">
						<span class="gsearch__name">{{ c.icon }} {{ c.label }}</span>
						<span class="gsearch__id">{{ c.hint }}</span>
					</button>
				</div>
			</template>
			<template v-else>
				<div v-if="!query" class="ds-empty"><div class="ds-empty__icon">🔍</div><p>Escribe para buscar entidades, NPCs, enemigos, objetos, eventos… (o <span class="mono">&gt;</span> para comandos)</p></div>
				<div v-else-if="!flat.length" class="ds-empty"><div class="ds-empty__icon">🫥</div><p>Sin resultados para "{{ query }}".</p></div>
				<template v-else>
					<div v-for="g in groups" :key="g.tab" class="gsearch__group">
						<div class="gsearch__grouphead"><span>{{ g.icon }}</span>{{ g.label }}</div>
						<button v-for="it in g.items" :key="g.tab+it.id" class="gsearch__item"
							:class="{ active: flatIndex(g.tab, it.id) === active }"
							@click="choose({ tab: g.tab, id: it.id })" @mouseenter="active = flatIndex(g.tab, it.id)">
							<span class="gsearch__name">{{ it.name || it.id }}</span>
							<span class="gsearch__id">{{ it.id }}</span>
						</button>
					</div>
				</template>
			</template>
		</div>
	</ds-modal>
	`,
};
