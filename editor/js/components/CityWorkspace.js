// components/CityWorkspace.js
// ─────────────────────────────────────────────────────────────────────────────
// WORKSPACE DE CIUDAD. Primer "Workspace vertical": una vista
// ORIENTADA A LA TAREA que reúne en un solo sitio TODO lo relacionado con una
// ciudad/aldea, en vez de obligar a saltar entre pestañas sueltas:
//   · Datos de la ciudad (nombre, icono, descripción).
//   · Su ubicación en el mapa (con salto directo al editor de mapa).
//   · Sus edificios/POIs como tarjetas, con el NPC y la tienda vinculados y
//     accesos directos para editarlos, añadirlos, crearlos, reordenarlos.
//
// Es NO destructivo: edita `store.ids` igual que IdsManager (misma estructura de
// datos) y marca 'ids' como sucio. Está íntegramente construido sobre el Design
// System (DsSplitPanel, DsBreadcrumb, DsCard, DsField, DsEmpty, DsContextMenu…).
// ─────────────────────────────────────────────────────────────────────────────
import { ref, computed } from 'https://unpkg.com/vue@3/dist/vue.esm-browser.prod.js';
import { store, markDirty, POI_KINDS, visualOptions, getI18n, getI18nFallback, getI18nDisplay, setI18n } from '../store.js';
import { goTo } from '../nav.js';

export default {
	name: 'CityWorkspace',
	setup() {
		const query = ref('');
		const addOpen = ref(false);
		const addPick = ref('');
		const newId = ref('');
		const ctx = ref({ open: false, x: 0, y: 0, idx: -1 });

		// ── Ciudades/aldeas ──────────────────────────────────────────────────────
		const cities = computed(() => {
			const q = query.value.trim().toLowerCase();
			return Object.values(store.ids || {})
				.filter(o => o.type === 'city')
				.filter(o => !q || o.id.toLowerCase().includes(q) || (o.name?.es || '').toLowerCase().includes(q))
				.sort((a, b) => (a.name?.es || a.id).localeCompare(b.name?.es || b.id));
		});

		// Ciudad seleccionada: reutiliza store.selectedId si apunta a una ciudad.
		const selectedCityId = ref(pickInitial());
		function pickInitial() {
			const s = store.selectedId;
			if (s && store.ids?.[s] && store.ids[s].type === 'city') return s;
			return cities.value[0]?.id || null;
		}
		const city = computed(() => selectedCityId.value ? store.ids?.[selectedCityId.value] : null);

		function selectCity(id) { selectedCityId.value = id; store.selectedId = id; }
		function touch() { markDirty('ids', selectedCityId.value); }

		// ── Edición de campos ─────────────────────────────────────────────────────
		function ensureBilingual(o, f) { if (!o[f]) o[f] = { es: '', en: '' }; return o[f]; }
		function setName(lang, v) { if (!city.value) return; ensureBilingual(city.value, 'name')[lang] = v; touch(); }
		function setDesc(lang, v) { if (!city.value) return; ensureBilingual(city.value, 'desc')[lang] = v; touch(); }
		function setIcon(v) { if (!city.value) return; if (v) city.value.icon = v; else delete city.value.icon; touch(); }
		function setVisual(v) { if (!city.value) return; if (v) city.value.visual = v; else delete city.value.visual; touch(); }
		const cityVisuals = computed(() => city.value ? visualOptions(city.value.type) : []);

		// ── Ubicación en el mapa ───────────────────────────────────────────────────
		// Busca en ambos mapas (real y debug) la casilla cuyo `object` es la ciudad.
		function findOnMap(id) {
			for (const [mapKey, w] of [['real', store.worldReal], ['debug', store.worldDebug]]) {
				const tiles = w?.tiles || [];
				for (let y = 0; y < tiles.length; y++) {
					const row = tiles[y] || [];
					for (let x = 0; x < row.length; x++) {
						if (row[x]?.object === id) return { map: mapKey, x, y };
					}
				}
			}
			return null;
		}
		const location = computed(() => selectedCityId.value ? findOnMap(selectedCityId.value) : null);
		function gotoMap() {
			const loc = location.value;
			if (loc) { store.activeMap = loc.map; store.world = loc.map === 'debug' ? store.worldDebug : store.worldReal; store.selectedCell = { x: loc.x, y: loc.y }; }
			goTo('map');
		}

		// ── Edificios / POIs ───────────────────────────────────────────────────────
		const buildings = computed(() => (city.value?.content || []).map((id, idx) => ({ idx, id, def: store.ids?.[id] || null })));
		const availablePois = computed(() => Object.values(store.ids || {})
			.filter(o => o.type === 'poi' && !(city.value?.content || []).includes(o.id)));

		function ensureContent() { if (!city.value.content) city.value.content = []; }
		function addExisting() {
			if (!addPick.value || !city.value) return;
			ensureContent();
			if (!city.value.content.includes(addPick.value)) city.value.content.push(addPick.value);
			touch(); addPick.value = ''; addOpen.value = false;
		}
		function createAndAdd() {
			const id = newId.value.trim();
			if (!id || !city.value) return;
			if (store.ids[id]) { store.error = 'Ya existe un id "' + id + '".'; return; }
			store.ids[id] = { id, type: 'poi', name: { es: id, en: id }, kind: 'npc' };
			ensureContent();
			city.value.content.push(id);
			touch(); newId.value = ''; addOpen.value = false;
		}
		function removeBuilding(idx) { city.value.content.splice(idx, 1); touch(); }
		function moveBuilding(idx, dir) {
			const arr = city.value.content; const j = idx + dir;
			if (j < 0 || j >= arr.length) return;
			[arr[idx], arr[j]] = [arr[j], arr[idx]]; touch();
		}
		function kindOf(def) { return def?.kind || ''; }
		function toneFor(b) { return b.def ? '' : 'err'; }

		function editPoi(id) { goTo('ids', id); }
		function editNpc(id) { goTo('npcs', id); }
		function editShop(stock) {
			// Las tiendas se indexan por 'stock'. Salta a la pestaña de tiendas.
			if (store.shops && store.shops[stock] != null) goTo('shops', stock); else goTo('shops');
		}

		// ── Menú contextual de un edificio ─────────────────────────────────────────
		function openCtx(e, idx) { ctx.value = { open: true, x: e.clientX, y: e.clientY, idx }; }
		const ctxItems = computed(() => {
			const b = buildings.value[ctx.value.idx];
			if (!b) return [];
			const items = [
				{ label: 'Editar POI', icon: '✏️', action: () => editPoi(b.id) },
			];
			if (b.def?.npc) items.push({ label: 'Ir al NPC', icon: '💬', action: () => editNpc(b.def.npc) });
			if (b.def?.stock) items.push({ label: 'Ir a la tienda', icon: '🛒', action: () => editShop(b.def.stock) });
			items.push({ divider: true });
			items.push({ label: 'Quitar de la ciudad', icon: '🗑', danger: true, action: () => removeBuilding(b.idx) });
			return items;
		});

		return {
			store, POI_KINDS, query, cities, selectedCityId, city, selectCity,
			setName, setDesc, setIcon, setVisual, cityVisuals,
			location, gotoMap,
			buildings, availablePois, addOpen, addPick, newId, addExisting, createAndAdd,
			removeBuilding, moveBuilding, kindOf, toneFor,
			editPoi, editNpc, editShop,
			ctx, ctxItems, openCtx,
			breadcrumb: computed(() => city.value
				? [{ label: 'Mundo', icon: '🌍' }, { label: 'Ciudades', icon: '🏙️' }, { label: city.value.name?.es || city.value.id, icon: city.value.icon || '🏰' }]
				: [{ label: 'Mundo', icon: '🌍' }, { label: 'Ciudades', icon: '🏙️' }]),
			getI18n, getI18nFallback, getI18nDisplay, setI18n,
		};
	},
	template: `
	<div class="city-ws">
		<ds-split-panel persist-key="city-ws" :initial="260" :min="200" :min-end="360">
			<!-- Lista de ciudades -->
			<template #start>
				<div class="city-ws__list">
					<div class="city-ws__listhead">
						<ds-search-input v-model="query" placeholder="Buscar ciudad…"></ds-search-input>
					</div>
					<div class="city-ws__cities">
						<button v-for="c in cities" :key="c.id" class="city-ws__city" :class="{ active: c.id===selectedCityId }" @click="selectCity(c.id)">
							<span class="nav-ico">{{ c.icon || '🏰' }}</span>
							<span class="city-ws__cityname">{{ c.name?.es || c.id }}</span>
							<ds-badge :value="(c.content||[]).length" tone="accent"></ds-badge>
						</button>
						<div v-if="!cities.length" class="ds-empty"><div class="ds-empty__icon">🏙️</div><p>No hay ciudades ni aldeas.</p></div>
					</div>
				</div>
			</template>

			<!-- Detalle de la ciudad -->
			<template #end>
				<div v-if="!city" class="city-ws__detail">
					<ds-empty icon="🏰" title="Selecciona una ciudad" hint="Elige una ciudad de la lista para gestionar todo su contenido en un solo lugar."></ds-empty>
				</div>
				<div v-else class="city-ws__detail">
					<header class="city-ws__head">
						<ds-breadcrumb :items="breadcrumb"></ds-breadcrumb>
						<div class="spacer"></div>
						<button class="btn sm ghost" @click="editPoi(city.id)" title="Abrir en el editor de entidades">✎ Editar en Datos</button>
					</header>

					<div class="city-ws__scroll">
						<!-- Datos -->
						<section class="panel section">
							<div class="sh"><span style="font-size:22px">{{ city.icon || '🏰' }}</span> Datos de la ciudad <span class="type-tag">{{ city.type }}</span></div>
							<div class="ws-grid">
								<ds-field label="Icono"><input :value="city.icon || ''" @input="setIcon($event.target.value)" placeholder="🏰" /></ds-field>
								<ds-field :label="'Nombre [' + store.currentLang.toUpperCase() + ']'"><input :value="getI18n(city.name)" :placeholder="getI18nFallback(city.name) || 'Nombre de la ciudad...'" @input="setName(store.currentLang, $event.target.value)" /></ds-field>
							</div>
							<ds-field v-if="cityVisuals.length" label="Aspecto en el mundo (maqueta 3D)" hint="Independiente del tipo lógico. Una ciudad puede verse como aldea, etc.">
								<select :value="city.visual || ''" @change="setVisual($event.target.value)">
									<option value="">Por defecto ({{ city.type }})</option>
									<option v-for="v in cityVisuals" :key="v.value" :value="v.value">{{ v.label }}</option>
								</select>
							</ds-field>
							<ds-field :label="'Descripción [' + store.currentLang.toUpperCase() + ']'"><textarea :value="getI18n(city.desc)" :placeholder="getI18nFallback(city.desc) || 'Descripción de la ciudad...'" @input="setDesc(store.currentLang, $event.target.value)"></textarea></ds-field>
						</section>

						<!-- Ubicación -->
						<section class="panel section">
							<div class="sh">📍 Ubicación en el mapa <span class="grow"></span>
								<button class="btn sm" @click="gotoMap">🗺️ Ver en el mapa</button></div>
							<div v-if="location" class="city-ws__loc">
								Colocada en el mapa <strong>{{ location.map==='debug' ? 'de pruebas' : 'real' }}</strong> en la casilla
								<span class="mono">({{ location.x }}, {{ location.y }})</span>.
							</div>
							<div v-else class="ds-empty" style="padding:14px">
								<p>Esta ciudad todavía <strong>no está colocada</strong> en ningún mapa. Ábrela en el editor de mapa y píntala como objeto de una casilla.</p>
							</div>
						</section>

						<!-- Edificios -->
						<section class="panel section">
							<div class="sh">🏬 Edificios y POIs <ds-badge :value="buildings.length" tone="accent"></ds-badge>
								<span class="grow"></span>
								<button class="btn sm primary" @click="addOpen=true">+ Añadir edificio</button></div>
							<div class="muted" style="margin-bottom:10px">El orden es el de los botones en el menú del lugar. Clic derecho en una tarjeta para más acciones.</div>
							<div v-if="!buildings.length" class="ds-empty"><div class="ds-empty__icon">🏗️</div><p>Sin edificios todavía.</p></div>
							<div class="ws-cards">
								<ds-card v-for="b in buildings" :key="b.idx"
									:title="b.def?.name?.es || b.id" :subtitle="b.id + (b.def ? '' : ' · NO EXISTE')"
									:icon="b.def?.icon || (b.def ? '📍' : '⚠️')" :tone="toneFor(b)"
									@contextmenu.prevent="openCtx($event, b.idx)">
									<template #actions>
										<span class="ws-arrows">
											<button class="btn sm ghost" @click="moveBuilding(b.idx,-1)" :disabled="b.idx===0" title="Subir">▲</button>
											<button class="btn sm ghost" @click="moveBuilding(b.idx,1)" :disabled="b.idx===buildings.length-1" title="Bajar">▼</button>
										</span>
									</template>
									<div class="ws-card-tags">
										<ds-tag v-if="kindOf(b.def)" :label="kindOf(b.def)" tone="accent"></ds-tag>
										<ds-tag v-if="b.def?.npc" :label="'NPC: ' + b.def.npc" icon="💬"></ds-tag>
										<ds-tag v-if="b.def?.stock" :label="'Tienda: ' + b.def.stock" icon="🛒"></ds-tag>
									</div>
									<div class="ws-card-actions">
										<button class="btn sm ghost" @click="editPoi(b.id)">✎ POI</button>
										<button v-if="b.def?.npc" class="btn sm ghost" @click="editNpc(b.def.npc)">💬 NPC</button>
										<button v-if="b.def?.stock" class="btn sm ghost" @click="editShop(b.def.stock)">🛒 Tienda</button>
									</div>
								</ds-card>
							</div>
						</section>
					</div>
				</div>
			</template>
		</ds-split-panel>

		<!-- Añadir edificio -->
		<ds-modal :open="addOpen" size="sm" title="Añadir edificio / POI" @close="addOpen=false">
			<ds-field label="Elegir uno existente">
				<select v-model="addPick" class="input">
					<option value="">— selecciona —</option>
					<option v-for="o in availablePois" :key="o.id" :value="o.id">{{ o.icon || '📍' }} {{ o.name?.es || o.id }} — {{ o.id }}</option>
				</select>
			</ds-field>
			<button class="btn sm primary" @click="addExisting" :disabled="!addPick">Añadir seleccionado</button>
			<hr style="border-color:var(--line); margin:16px 0" />
			<ds-field label="…o crear uno nuevo">
				<input v-model="newId" placeholder="nuevo id de POI" @keyup.enter="createAndAdd" />
			</ds-field>
			<template #footer>
				<button class="btn ghost" @click="addOpen=false">Cancelar</button>
				<button class="btn primary" @click="createAndAdd" :disabled="!newId.trim()">Crear y añadir</button>
			</template>
		</ds-modal>

		<ds-context-menu :open="ctx.open" :x="ctx.x" :y="ctx.y" :items="ctxItems" @close="ctx.open=false"></ds-context-menu>
	</div>
	`,
};
