// components/ItemsManager.js
// ─────────────────────────────────────────────────────────────────────────────
// Gestor de items.json: lista con buscador + filtro por categoría, formulario
// bilingüe (nombre/desc), icono, interruptor "usable" con efectos, y (para
// equipamiento) slot + bonuses de atributo + bonuses de combate.
// Incluye una PREVISUALIZACIÓN DE EQUIPO: un avatar con slots que resalta dónde
// encaja la pieza seleccionada y qué stats aporta.
// ─────────────────────────────────────────────────────────────────────────────
import { computed, ref } from 'https://unpkg.com/vue@3/dist/vue.esm-browser.prod.js';
import { store, ITEM_CATEGORIES, EQUIP_SLOTS, STAT_KEYS, COMBAT_KEYS, getI18n, getI18nFallback, getI18nDisplay, setI18n } from '../store.js';
import * as FS from '../fs.js';
import { useCollection } from '../lib/useCollection.js';
import EntityListPanel from './EntityListPanel.js';
import EditorToolbar from './EditorToolbar.js';
import ItemWizardModal from './ItemWizardModal.js';

const SLOT_ICONS = {
	weapon: '🗡️', shield: '🛡️', armor: '👕', helmet: '🪖', shoes: '🥾', accessory: '💍',
};

export default {
	name: 'ItemsManager',
	components: { EntityListPanel, EditorToolbar, ItemWizardModal },
	setup() {
		const wizardOpen = ref(false);
		const col = useCollection({
			tabId: 'items',
			dirtyKey: 'items',
			dirtyMap: () => store.dirtyItems,
			collection: () => store.items,
			setCollection: (v) => { store.items = v; },
			selectedKey: 'selectedItem',
			clipboardKind: 'item',
			entityLabel: 'objeto',
			newIdBase: 'item_new',
			// items es colección "un fichero por id": al borrar/
			// renombrar hay que borrar también el fichero en disco del id saliente.
			onRemove: (id) => FS.deleteCollectionItem('items', id),
			makeNew: () => ({
				name: { es: 'Nuevo objeto', en: 'New item' }, desc: { es: '', en: '' },
				icon: '❓', category: 'other', usable: false,
			}),
			searchText: (id, it) => id + ' ' + (it.name?.es || '') + ' ' + (it.name?.en || ''),
			filters: [{ key: 'category', label: 'Categoría', options: ITEM_CATEGORIES, get: (it) => it.category }],
			sorts: [
				{ key: 'name', label: 'Nombre', get: (id, it) => (it.name?.es || id).toLowerCase() },
				{ key: 'id', label: 'ID', get: (id) => id },
				{ key: 'category', label: 'Categoría', get: (id, it) => it.category || '' },
			],
		});
		const current = col.current;
		const isEquip = computed(() => current.value?.category === 'equipment');

		function setName(l, v) { col.edit(() => { setI18n(current.value, 'name', v, l); }); }
		function setDesc(l, v) { col.edit(() => { setI18n(current.value, 'desc', v, l); }); }
		function setField(k, v) { col.edit(() => { if (v === '' || v == null) delete current.value[k]; else current.value[k] = v; }); }

		function setCategory(v) {
			col.edit(() => {
				const it = current.value; it.category = v;
				// Ajustar campos por categoría.
				if (v === 'equipment') {
					if (!it.slot) it.slot = 'weapon';
					if (!it.tier) it.tier = 1;
					if (!it.bonuses) it.bonuses = {};
					if (!it.combat) it.combat = {};
					it.usable = false;
					delete it.effects;
				} else if (v === 'consumable') {
					it.usable = true;
					if (!it.effects) it.effects = { heal: 0 };
					delete it.slot; delete it.bonuses; delete it.combat;
				} else {
					it.usable = false;
					delete it.slot; delete it.bonuses; delete it.combat; delete it.effects;
				}
			});
		}

		function toggleUsable(e) { 
			col.edit(() => { 
				current.value.usable = !!e.target.checked;
				if (current.value.usable && !current.value.effects) current.value.effects = { heal: 0 };
			}); 
		}

		function setEffect(k, v) {
			col.edit(() => {
				if (!current.value.effects) current.value.effects = {};
				const n = Number(v) || 0;
				if (n === 0) delete current.value.effects[k]; else current.value.effects[k] = n;
			});
		}
		function setBonus(k, v) {
			col.edit(() => {
				if (!current.value.bonuses) current.value.bonuses = {};
				const n = Number(v) || 0;
				if (n === 0) delete current.value.bonuses[k]; else current.value.bonuses[k] = n;
			});
		}
		function setCombat(k, v) {
			col.edit(() => {
				if (!current.value.combat) current.value.combat = {};
				const n = Number(v) || 0;
				if (n === 0) delete current.value.combat[k]; else current.value.combat[k] = n;
			});
		}

		// ── Preview de equipo: qué slot ocupa la pieza actual ──
		const previewSlots = computed(() => EQUIP_SLOTS.map(s => ({
			slot: s, icon: SLOT_ICONS[s],
			active: isEquip.value && current.value.slot === s,
		})));

		function getItemThumb(id, o) {
			if (!o) return null;
			const img = o.image || o.sprite || '';
			if (img && typeof img === 'string') {
				const file = img.split('/').pop();
				if (file && file.includes('.')) return `/api/assets/item/${encodeURIComponent(file)}`;
			}
			return null;
		}

		return {
			store, col, current, isEquip, previewSlots, wizardOpen,
			ITEM_CATEGORIES, EQUIP_SLOTS, STAT_KEYS, COMBAT_KEYS, SLOT_ICONS,
			setName, setDesc, setField, setCategory, toggleUsable,
			setEffect, setBonus, setCombat,
			getItemThumb,
			getI18n, getI18nFallback, getI18nDisplay, setI18n,
		};
	},
	template: `
	<div class="manager">
		<entity-list-panel :c="col" search-placeholder="Buscar objeto…">
			<template #row="{ id, o }">
				<img v-if="getItemThumb(id, o)" :src="getItemThumb(id, o)" class="ent-thumb" alt=""
					@error="e => { e.target.style.display='none'; if (e.target.nextElementSibling) e.target.nextElementSibling.style.display='inline-block'; }" />
				<span class="ent-icon" :style="{ display: getItemThumb(id, o) ? 'none' : 'inline-block' }">{{ o.icon || '❓' }}</span>
				<span class="ent-name">{{ (o.name && o.name[store.currentLang]) || (o.name && (o.name.en || o.name.es)) || id }}</span>
				<span class="ent-id mono">{{ id }}</span>
			</template>
			<template #extra-actions>
				<button class="btn secondary sm" @click="wizardOpen=true">🧙 Asistente</button>
			</template>
		</entity-list-panel>
		<item-wizard-modal :open="wizardOpen" @close="wizardOpen=false" @created="wizardOpen=false"></item-wizard-modal>

		<section class="editor-pane" v-if="current">
			<editor-toolbar :can-undo="col.canUndo.value" :can-redo="col.canRedo.value"
				:can-paste="col.canPaste.value" :has-current="!!current" :dirty="col.dirty.value"
				:saved-text="col.savedText.value"
				@undo="col.undo()" @redo="col.redo()" @copy="col.copy()" @paste="col.paste()"
				@duplicate="col.duplicate()" @remove="col.remove()" @save="col.doSave()"></editor-toolbar>

			<div class="form-grid">
				<label>ID <input class="input mono" :value="col.selectedId.value" @change="col.rename($event.target.value)" /></label>
				<label>Icono <input class="input f-xs" :value="current.icon" @input="setField('icon',$event.target.value)" /></label>
				<label>Nombre [{{ store.currentLang.toUpperCase() }}] <input class="input" :value="getI18n(current.name)" :placeholder="getI18nFallback(current.name) || 'Nombre del objeto...'" @input="setName(store.currentLang,$event.target.value)" /></label>
				<label>Categoría
					<select class="input" :value="current.category" @change="setCategory($event.target.value)">
						<option v-for="c in ITEM_CATEGORIES" :key="c" :value="c">{{ c }}</option>
					</select>
				</label>
				<label class="check">
					<input type="checkbox" :checked="current.usable" @change="toggleUsable" /> Usable
				</label>
			</div>

			<div class="bilingual">
				<label>Descripción [{{ store.currentLang.toUpperCase() }}]
					<textarea class="input" :value="getI18n(current.desc)" :placeholder="getI18nFallback(current.desc) || 'Descripción del objeto...'" @input="setDesc(store.currentLang,$event.target.value)"></textarea>
				</label>
			</div>

			<!-- Efectos (usable) -->
			<template v-if="current.usable">
				<h3 class="sec">💫 Efectos (task3: % del máximo, no valor plano)</h3>
				<div class="form-grid">
					<label>Curar HP (% del máx.) <input class="input num" type="number" min="0" max="100" step="1" :value="Math.round(((current.effects||{}).heal_pct||0)*100)" @input="setEffect('heal_pct',$event.target.value/100)" /></label>
					<label>Restaurar MP (% del máx.) <input class="input num" type="number" min="0" max="100" step="1" :value="Math.round(((current.effects||{}).mana_pct||0)*100)" @input="setEffect('mana_pct',$event.target.value/100)" /></label>
				</div>
			</template>

			<!-- Equipamiento -->
			<template v-if="isEquip">
				<h3 class="sec">🛡️ Equipamiento</h3>
				<div class="equip-layout">
					<div>
						<label>Slot
							<select class="input" :value="current.slot" @change="setField('slot',$event.target.value)">
								<option v-for="s in EQUIP_SLOTS" :key="s" :value="s">{{ SLOT_ICONS[s] }} {{ s }}</option>
							</select>
						</label>
						<label>Tier (1-5, ver task3_rebalanceo: T1 niv.1-5 · T2 niv.6-10 · T3 niv.11-15 · T4 niv.16-20 · T5 niv.21-25)
							<select class="input" :value="current.tier||1" @change="setField('tier', Number($event.target.value))">
								<option v-for="t in [1,2,3,4,5]" :key="t" :value="t">Tier {{ t }}</option>
							</select>
						</label>
						<div class="sub">Bonos de atributo</div>
						<div class="mini-grid">
							<label v-for="k in STAT_KEYS" :key="k">{{ k.toUpperCase() }}
								<input class="input num" type="number" :value="(current.bonuses||{})[k]||0" @input="setBonus(k,$event.target.value)" />
							</label>
						</div>
						<div class="sub">Bonos de combate</div>
						<div class="mini-grid">
							<label v-for="k in COMBAT_KEYS" :key="k">{{ k }}
								<input class="input num" type="number" :value="(current.combat||{})[k]||0" @input="setCombat(k,$event.target.value)" />
							</label>
						</div>
					</div>
					<!-- ⭐ Preview de héroe con slots -->
					<div class="hero-preview">
						<div class="hero-title">Vista previa de equipamiento</div>
						<div class="hero-avatar">🧝</div>
						<div class="hero-slots">
							<div class="hero-slot" v-for="s in previewSlots" :key="s.slot" :class="{ on: s.active }" :title="s.slot">
								<span class="hs-icon">{{ s.icon }}</span>
								<span class="hs-name">{{ s.slot }}</span>
								<span v-if="s.active" class="hs-here">◀ aquí</span>
							</div>
						</div>
						<div class="hero-stats" v-if="isEquip">
							<div class="hs-line" v-for="(v,k) in (current.bonuses||{})" :key="'b'+k"><span>{{ k.toUpperCase() }}</span><b>+{{ v }}</b></div>
							<div class="hs-line combat" v-for="(v,k) in (current.combat||{})" :key="'c'+k"><span>{{ k }}</span><b>+{{ v }}</b></div>
						</div>
					</div>
				</div>
			</template>
		</section>

		<section class="editor-pane empty" v-else>
			<p class="muted">Selecciona o crea un objeto.</p>
		</section>
	</div>
	`,
};
