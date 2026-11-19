// components/EntityListPanel.js
// ─────────────────────────────────────────────────────────────────────────────
// PANEL LATERAL COMÚN de lista de entidades (Tarea 4). Unifica en un solo
// componente la barra de herramientas de la lista de TODOS los editores de
// colección: buscador, filtros por campo, ordenación (campo + asc/desc) y botón
// "Nuevo", más la propia lista con selección.
//
// Se le pasa el objeto devuelto por `useCollection` como prop `c`; cada fila de
// la lista se dibuja mediante el slot con ámbito `#row="{ id, o, active }"`, de
// modo que cada editor conserva su aspecto de fila sin duplicar la lógica.
//
// Task 5 (Paleta de Comandos, `> Nuevo X`): como TODOS los editores de colección
// pasan por aquí para el botón "＋ Nuevo", este es el único punto donde hace
// falta escuchar `nav.pendingNew` (fijado por `requestNewEntity()` en nav.js)
// y disparar `c.add()` automáticamente, sin que cada manager repita lógica.
//
// Task 5 (1.2, Badges de integridad): por el mismo motivo, este es también el
// único punto donde hace falta pintar el badge ⚠️ Error (de `store.qaIndex`,
// ver lib/qaIndex.js) / ⚡ Incompleto (heurística síncrona `assessIncomplete`,
// lib/integrity.js) y el filtro [Todos][Válidos][Con Advertencias].
// ─────────────────────────────────────────────────────────────────────────────
import { computed, ref, watch } from 'https://unpkg.com/vue@3/dist/vue.esm-browser.prod.js';
import { store, nav } from '../store.js';
import { assessIncomplete } from '../lib/integrity.js';

export default {
	name: 'EntityListPanel',
	props: {
		c: { type: Object, required: true },        // instancia de useCollection
		searchPlaceholder: { type: String, default: 'Buscar…' },
		newLabel: { type: String, default: '＋ Nuevo' },
	},
	setup(props) {
		watch(() => nav.pendingNew, (t) => {
			if (!t || t !== props.c.tabId) return;
			nav.pendingNew = null;
			props.c.add();
		}, { immediate: true });

		const integrityFilter = ref('all'); // 'all' | 'valid' | 'warn'
		function rowIssue(id, o) {
			const qa = store.qaIndex && store.qaIndex[props.c.tabId] && store.qaIndex[props.c.tabId][id];
			if (qa) return { level: qa.level, title: qa.messages.join('\n') };
			const inc = assessIncomplete(o);
			if (inc) return { level: 'warning', title: inc };
			return null;
		}
		const filteredList = computed(() => {
			const rows = props.c.list.value;
			if (integrityFilter.value === 'all') return rows;
			return rows.filter((r) => {
				const issue = rowIssue(r.id, r.o);
				return integrityFilter.value === 'valid' ? !issue : !!issue;
			});
		});

		return { integrityFilter, rowIssue, filteredList };
	},
	template: `
	<aside class="side">
		<div class="side-tools">
			<input class="input" type="search" :value="c.search.value"
				@input="c.search.value = $event.target.value" :placeholder="searchPlaceholder" />
			<select v-for="f in c.filters" :key="f.key" class="input"
				:value="c.filterState[f.key]" @change="c.filterState[f.key] = $event.target.value">
				<option value="">{{ f.label }}: todos</option>
				<option v-for="opt in f.options" :key="typeof opt === 'object' ? opt.value : opt" :value="typeof opt === 'object' ? opt.value : opt">{{ typeof opt === 'object' ? opt.label : opt }}</option>
			</select>
			<div class="sort-row">
				<select class="input" :value="c.sortKey.value" @change="c.sortKey.value = $event.target.value" title="Ordenar por">
					<option v-for="s in c.sorts" :key="s.key" :value="s.key">↕ {{ s.label }}</option>
				</select>
				<button class="btn sm ghost" @click="c.toggleSortDir()" :title="c.sortDir.value === 'asc' ? 'Ascendente' : 'Descendente'">
					{{ c.sortDir.value === 'asc' ? '▲' : '▼' }}
				</button>
			</div>
			<div class="integrity-filter-row" role="group" aria-label="Filtro de integridad">
				<button class="btn sm" :class="integrityFilter==='all' ? 'primary' : 'ghost'" @click="integrityFilter='all'">Todos</button>
				<button class="btn sm" :class="integrityFilter==='valid' ? 'primary' : 'ghost'" @click="integrityFilter='valid'">✅ Válidos</button>
				<button class="btn sm" :class="integrityFilter==='warn' ? 'primary' : 'ghost'" @click="integrityFilter='warn'">⚠️ Con Advertencias</button>
			</div>
			<button class="btn primary sm" @click="c.add()">{{ newLabel }}</button>
			<slot name="extra-actions"></slot>
		</div>
		<ul class="entity-list">
			<li v-for="row in filteredList" :key="row.id"
				:class="{ active: c.selectedId.value === row.id }" @click="c.select(row.id)">
				<slot name="row" :id="row.id" :o="row.o" :active="c.selectedId.value === row.id">
					<span class="ent-name">{{ row.id }}</span>
				</slot>
				<span v-if="rowIssue(row.id, row.o)" class="ent-badge" :class="'ent-badge--' + rowIssue(row.id, row.o).level" :title="rowIssue(row.id, row.o).title">
					{{ rowIssue(row.id, row.o).level === 'error' ? '⚠️' : '⚡' }}
				</span>
			</li>
			<li v-if="!filteredList.length" class="empty-row">Sin resultados.</li>
		</ul>
	</aside>
	`,
};
