// components/ShopsManager.js
// ─────────────────────────────────────────────────────────────────────────────
// Gestor de shops.json: catálogos de tienda data-driven (Tarea 5, Fase C).
// Cada entrada es `stock_id -> [ { id, price } ]`. La barra lateral lista los
// stocks; el panel edita las líneas (objeto + precio) con desplegable de ítems
// resueltos desde items.json. Reutiliza el CRUD/atajos comunes de useCollection.
// ─────────────────────────────────────────────────────────────────────────────
import { computed } from 'https://unpkg.com/vue@3/dist/vue.esm-browser.prod.js';
import { store, getI18nDisplay } from '../store.js';
import { useCollection } from '../lib/useCollection.js';
import EntityListPanel from './EntityListPanel.js';
import EditorToolbar from './EditorToolbar.js';

export default {
	name: 'ShopsManager',
	components: { EntityListPanel, EditorToolbar },
	setup() {
		const col = useCollection({
			tabId: 'shops',
			dirtyKey: 'shops',
			collection: () => store.shops,
			setCollection: (v) => { store.shops = v; },
			selectedKey: 'selectedShop',
			clipboardKind: 'shop',
			entityLabel: 'tienda',
			newIdBase: 'tienda_nueva',
			makeNew: () => ([]),
			searchText: (id, arr) => id + ' ' + (Array.isArray(arr) ? arr.map(l => l.id).join(' ') : ''),
			sorts: [
				{ key: 'id', label: 'ID', get: (id) => id },
				{ key: 'count', label: 'Nº objetos', get: (id, arr) => (Array.isArray(arr) ? arr.length : 0) },
			],
		});
		const current = col.current;

		// Lista de ids de objeto disponibles (para el desplegable). Ordenada.
		const itemIds = computed(() => Object.keys(store.items || {}).sort());

		function itemName(id) {
			const it = store.items?.[id];
			if (!it) return id;
			return getI18nDisplay(it.name) || id;
		}
		function itemIcon(id) { return store.items?.[id]?.icon || '❓'; }

		function addLine() {
			if (!Array.isArray(current.value)) return;
			col.edit(() => {
				const first = itemIds.value[0] || '';
				current.value.push({ id: first, price: 0 });
			});
		}
		function removeLine(idx) {
			if (!Array.isArray(current.value)) return;
			col.edit(() => { current.value.splice(idx, 1); });
		}
		function moveLine(idx, dir) {
			if (!Array.isArray(current.value)) return;
			const t = idx + dir;
			if (t < 0 || t >= current.value.length) return;
			col.edit(() => {
				const tmp = current.value[idx];
				current.value[idx] = current.value[t];
				current.value[t] = tmp;
			});
		}
		function setLineId(idx, v) { col.edit(() => { current.value[idx].id = v; }); }
		function setLinePrice(idx, v) { col.edit(() => { current.value[idx].price = Math.max(0, Number(v) || 0); }); }

		return {
			store, col, current, itemIds, itemName, itemIcon,
			addLine, removeLine, moveLine, setLineId, setLinePrice,
		};
	},
	template: `
	<div class="manager">
		<entity-list-panel :c="col" search-placeholder="Buscar tienda…" new-label="➕ Nueva tienda">
			<template #row="{ id, o }">
				<span class="ent-icon">🛒</span>
				<span class="ent-name">{{ id }}</span>
				<span class="ent-id mono">{{ (o && o.length) || 0 }} art.</span>
			</template>
		</entity-list-panel>

		<section class="editor-pane" v-if="current">
			<editor-toolbar :can-undo="col.canUndo.value" :can-redo="col.canRedo.value"
				:can-paste="col.canPaste.value" :has-current="!!current" :dirty="col.dirty.value"
				:saved-text="col.savedText.value"
				@undo="col.undo()" @redo="col.redo()" @copy="col.copy()" @paste="col.paste()"
				@duplicate="col.duplicate()" @remove="col.remove()" @save="col.doSave()"></editor-toolbar>

			<h3 class="sec">🛒 Catálogo de tienda</h3>
			<div class="form-grid">
				<label>ID
					<input class="input mono" type="text" :value="col.selectedId.value" @change="col.rename($event.target.value)" />
				</label>
			</div>
			<p class="muted" style="margin:4px 0 12px">
				El <span class="mono">stock_id</span> se referencia desde el POI de tienda en el mundo. El nombre, icono y
				categoría del objeto se resuelven en vivo desde <span class="mono">items.json</span>; aquí solo defines
				<b>qué</b> objetos se venden y a <b>qué precio</b>.
			</p>

			<div class="pane-header" style="margin-top:10px">
				<h3 class="sec">📦 Artículos ({{ current.length }})</h3>
				<button class="btn secondary sm" @click="addLine" :disabled="!itemIds.length">➕ Añadir artículo</button>
			</div>

			<div class="skills-list" style="margin-top:12px">
				<div class="card panel" style="margin-bottom:10px; padding:12px; border:1px solid rgba(255,255,255,0.1)"
					v-for="(line, idx) in current" :key="idx">
					<div class="form-grid" style="align-items:end">
						<label>Objeto
							<select class="input" :value="line.id" @change="setLineId(idx, $event.target.value)">
								<option v-for="iid in itemIds" :key="iid" :value="iid">{{ itemIcon(iid) }} {{ itemName(iid) }} ({{ iid }})</option>
							</select>
						</label>
						<label>Precio (oro)
							<input class="input num" type="number" min="0" :value="line.price" @input="setLinePrice(idx, $event.target.value)" />
						</label>
						<div style="display:flex; gap:6px">
							<button class="btn sm ghost" :disabled="idx === 0" @click="moveLine(idx, -1)">▲</button>
							<button class="btn sm ghost" :disabled="idx === current.length - 1" @click="moveLine(idx, 1)">▼</button>
							<button class="btn sm err" @click="removeLine(idx)">🗑️</button>
						</div>
					</div>
				</div>
				<p v-if="!current.length" class="muted">Sin artículos. Pulsa “Añadir artículo”.</p>
			</div>
		</section>

		<section class="editor-pane empty" v-else>
			<p class="muted">Selecciona o crea una tienda.</p>
		</section>
	</div>
	`,
};
