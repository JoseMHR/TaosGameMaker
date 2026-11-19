// components/WorldBuildingsManager.js
// ─────────────────────────────────────────────────────────────────────────────
// Gestor de EDIFICIOS-ASSET del mapamundi (data/world_buildings/<code>.json),
// colección "un fichero por id" con CRUD COMPLETO desde el editor (a diferencia
// de world_terrains/world_resources, que son solo lectura). Cada entrada:
//   { label, icon, scene, scale?, y_offset?, description? }
// donde `scene` es la ruta `res://...tscn` de una escena construida en el editor
// 3D de Godot (o un modelo importado). Es la vía para AÑADIR un edificio nuevo
// al mundo SIN escribir GDScript: TabWorld3D._make_marker() instancia esa
// escena cuando el `item` de una casilla coincide con el `code` registrado aquí.
//
// Los 6 edificios procedurales cableados (ciudad/aldea/casita/templo/cueva/
// ruinas, en scenes/tabs/tab_world_3d/buildings/) siguen teniendo prioridad:
// un `code` que coincida con uno de esos 7 valores reservados (incluye "place")
// NUNCA se usará, así que se avisa en el formulario si se intenta.
// ─────────────────────────────────────────────────────────────────────────────
import { ref, computed } from 'https://unpkg.com/vue@3/dist/vue.esm-browser.prod.js';
import { store, markDirty, flash } from '../store.js';
import * as FS from '../fs.js';
import { useCollection } from '../lib/useCollection.js';
import EntityListPanel from './EntityListPanel.js';
import EditorToolbar from './EditorToolbar.js';

// Códigos ya reservados por las maquetas procedurales cableadas en TabWorld3D.gd
// (ver _make_marker): un edificio-asset con uno de estos `code` nunca se llega
// a instanciar, así que el formulario avisa en vez de dejar una ficha muerta.
const RESERVED_CODES = ['ciudad', 'aldea', 'casita', 'templo', 'place', 'cueva', 'ruinas'];

// ── PICKER DE ESCENA ─────────────────────────────────────────
// `scene` es una ruta libre `res://...`
const BUILDING_ASSET_KIND = 'buildings';
const BUILDING_SCENE_PREFIX = 'res://assets/common/models/buildings/';

// ── MAQUETAS CLÁSICAS ────────────────────────────────────────
// Las 8 maquetas procedurales cableadas (GenericMarkers.gd + Building*.gd)
// aceptan un override visual OPCIONAL desde `data/world_buildings_classic.json`
// (Design.get_classic_building_style). Aquí se declara, por código, qué campos
// tiene sentido exponer y cuál es su color/escala CABLEADA por defecto (el
// mismo valor que usaría GDScript si no hay override) para que el formulario
// muestre siempre algo coherente aunque el JSON esté vacío. "place" comparte
// la maqueta y el override de "templo" (mismo `elif` en GenericMarkers.gd).
const CLASSIC_BUILDINGS = {
	ciudad: { label: 'Ciudad', icon: '🏰', wall: '#e6e1d1', roof: '#bf473a' },
	aldea: { label: 'Aldea', icon: '🏡', wall: '#e6e1d1', roof: '#8c5933' },
	casita: { label: 'Casita', icon: '🏠', wall: '#dccdad', roof: '#804728' },
	templo: { label: 'Templo / Lugar', icon: '⛩️', wall: '#e0e0d9', roof: '#bf3830' },
	cueva: { label: 'Cueva / Mazmorra', icon: '🕳️', wall: '#3d3d42', roof: null },
	ruinas: { label: 'Ruinas', icon: '🏛️', wall: '#ad9e85', roof: null },
	presa: { label: 'Presa', icon: '🚧', wall: '#9e9e94', roof: null },
};
const CLASSIC_CODES = Object.keys(CLASSIC_BUILDINGS);

export default {
	name: 'WorldBuildingsManager',
	components: { EntityListPanel, EditorToolbar },
	setup() {
		const subTab = ref('assets'); // 'assets' (colección CRUD) | 'classic' (las 8 maquetas cableadas)

		// ── MAQUETAS CLÁSICAS: edición directa y ligera, sin historial propio
		// (mismo patrón que las `kits` de DungeonKitsManager) ──────────────────
		const classicStyles = computed(() => store.worldBuildingsClassic || (store.worldBuildingsClassic = {}));
		const selectedClassic = ref(CLASSIC_CODES[0]);
		function touchClassic() { markDirty('worldBuildingsClassic'); }
		function classicStyle(code) { return classicStyles.value[code] || {}; }
		function classicField(code, field, fallback) {
			const v = classicStyles.value[code]?.[field];
			return (v === undefined || v === null || v === '') ? fallback : v;
		}
		function setClassicField(code, field, v) {
			if (!classicStyles.value[code]) classicStyles.value[code] = {};
			classicStyles.value[code][field] = v;
			touchClassic();
		}
		function setClassicScale(code, v) { setClassicField(code, 'scale', parseFloat(v) || 1.0); }
		function resetClassic(code) {
			if (!classicStyles.value[code]) return;
			delete classicStyles.value[code];
			touchClassic();
		}
		function isClassicOverridden(code) {
			const s = classicStyles.value[code];
			return !!s && Object.keys(s).length > 0;
		}

		const col = useCollection({
			tabId: 'worldBuildings',
			dirtyKey: 'worldBuildings',
			dirtyMap: () => store.dirtyWorldBuildings,
			collection: () => store.worldBuildings,
			setCollection: (v) => { store.worldBuildings = v; },
			selectedKey: 'selectedWorldBuilding',
			clipboardKind: 'worldBuilding',
			entityLabel: 'edificio',
			newIdBase: 'edificio_nuevo',
			// world_buildings es colección "un fichero por id": al borrar/renombrar
			// hay que borrar también el fichero en disco del código saliente.
			onRemove: (code) => FS.deleteCollectionItem('world_buildings', code),
			makeNew: () => ({ label: 'Nuevo edificio', icon: '🏗️', scene: '', scale: 1.0, y_offset: 0.0, description: '' }),
			searchText: (id, o) => id + ' ' + (o?.label || '') + ' ' + (o?.scene || ''),
			sorts: [
				{ key: 'code', label: 'Código', get: (id) => id },
				{ key: 'label', label: 'Etiqueta', get: (id, o) => o?.label || '' },
			],
		});
		const current = col.current;

		function setField(field, v) { col.edit(() => { current.value[field] = v; }); }
		function setNumberField(field, v) { col.edit(() => { current.value[field] = parseFloat(v) || 0; }); }

		const isReserved = (code) => RESERVED_CODES.includes(code);

		// ── Picker de escena y modelo 3D (.tscn / .glb / .obj) ─────────────────────
		const sceneFiles = ref([]);
		const modelFiles = ref([]);
		const scenePickerOpen = ref(false);
		const modelPickerOpen = ref(false);
		async function refreshSceneFiles() { sceneFiles.value = await FS.listAssets(BUILDING_ASSET_KIND); }
		async function refreshModelFiles() { modelFiles.value = await FS.listAssets('world_model'); }
		function openScenePicker() { scenePickerOpen.value = true; refreshSceneFiles(); }
		function closeScenePicker() { scenePickerOpen.value = false; }
		function openModelPicker() { modelPickerOpen.value = true; refreshModelFiles(); }
		function closeModelPicker() { modelPickerOpen.value = false; }
		function selectSceneFile(file) {
			setField('scene', BUILDING_SCENE_PREFIX + file);
			scenePickerOpen.value = false;
		}
		function selectModelFile(file) {
			setField('model_path', 'assets/common/models/' + file);
			modelPickerOpen.value = false;
		}
		function onUploadModel(ev) {
			const file = ev.target.files && ev.target.files[0];
			ev.target.value = '';
			if (!file) return;
			if (!/\.(glb|obj)$/i.test(file.name)) {
				alert('Solo se admiten modelos .glb o .obj.');
				return;
			}
			let id = (window.prompt('Id/Nombre del modelo (sin extensión):', current.value?.code || file.name.replace(/\.(glb|obj)$/i, '')) || '').trim();
			if (!id) return;
			if (!/^[A-Za-z0-9_-]+$/.test(id)) {
				alert('Id no válido: solo letras, números, "_" y "-".');
				return;
			}
			const ext = file.name.slice(file.name.lastIndexOf('.')).toLowerCase();
			const filename = id + ext;
			const reader = new FileReader();
			reader.onload = async () => {
				try {
					await FS.uploadAsset('world_model', filename, reader.result, 'application/octet-stream');
					setField('model_path', 'assets/common/models/' + filename);
					await refreshModelFiles();
					flash(`Modelo 3D "${filename}" subido y asignado.`);
				} catch (e) {
					alert(e.message || String(e));
				}
			};
			reader.readAsArrayBuffer(file);
		}

		// ¿La ruta actual de `scene` corresponde a un fichero YA encontrado en
		// assets/common/models/buildings/? (vacía = todavía sin asignar, no es un error).
		const sceneFileMissing = computed(() => {
			const v = String(current.value?.scene || '');
			if (v === '') return false;
			const name = v.split('/').pop();
			return !sceneFiles.value.includes(name);
		});

		async function autoImportAssets() {
			const files = await FS.listAssets(BUILDING_ASSET_KIND);
			let count = 0;
			for (const file of files) {
				const stem = file.replace(/\.tscn$/i, '');
				const code = RESERVED_CODES.includes(stem) ? `${stem}_asset` : stem;
				if (!store.worldBuildings?.[code]) {
					const label = stem.charAt(0).toUpperCase() + stem.slice(1).replace(/_/g, ' ');
					const entry = {
						label,
						icon: '🏗️',
						scene: BUILDING_SCENE_PREFIX + file,
						scale: 1.0,
						y_offset: 0.0,
						description: `Importado automáticamente desde ${file}`
					};
					await FS.writeCollectionItem('world_buildings', code, entry);
					// El PUT ya lo persiste en disco; se refleja también en memoria
					// para que aparezca en la lista sin recargar el proyecto.
					store.worldBuildings[code] = entry;
					count++;
				}
			}
			if (count > 0) {
				flash(`Se han importado ${count} nuevo(s) edificio(s) 3D desde assets/common/models/buildings/.`);
			} else {
				alert('Todos los archivos .tscn de assets/common/models/buildings/ ya están registrados.');
			}
		}

		return {
			store, col, current, isReserved, RESERVED_CODES, setField, setNumberField,
			subTab, CLASSIC_BUILDINGS, CLASSIC_CODES, selectedClassic,
			classicField, setClassicField, setClassicScale, resetClassic, isClassicOverridden,
			sceneFiles, modelFiles, scenePickerOpen, modelPickerOpen, openScenePicker, closeScenePicker,
			openModelPicker, closeModelPicker, selectSceneFile, selectModelFile, onUploadModel, sceneFileMissing,
			autoImportAssets,
		};
	},
	template: `
	<div style="display:flex; flex-direction:column; height:100%; min-height:0; overflow:hidden">
		<!-- Barra superior con selector de sub-pestañas y descripción explicativa -->
		<div class="row gap" style="align-items:center; justify-content:space-between; padding:10px 16px; background:rgba(18,21,31,0.6); border-bottom:1px solid var(--line); flex-shrink:0">
			<div style="display:flex; gap:8px">
				<button class="btn sm" :class="{ primary: subTab === 'assets', ghost: subTab !== 'assets' }" @click="subTab = 'assets'">
					🏗️ Edificios 3D (.tscn / modelos)
				</button>
				<button class="btn sm" :class="{ primary: subTab === 'classic', ghost: subTab !== 'classic' }" @click="subTab = 'classic'">
					🏛️ Maquetas Clásicas (Colores & Escala)
				</button>
			</div>
			<div class="muted" style="font-size:12px">
				<span v-if="subTab === 'assets'">📦 Catálogo de edificios y estructuras 3D (en <span class="mono">assets/common/models/</span>) para vincular al mapa</span>
				<span v-else>🎨 Ajuste visual opcional de las 7 maquetas procedurales base de Godot</span>
			</div>
		</div>

		<!-- Contenedor principal de dos columnas -->
		<div class="manager" style="flex:1; min-height:0; overflow:hidden">
			<template v-if="subTab === 'assets'">
				<entity-list-panel :c="col" search-placeholder="Buscar edificio…" new-label="➕ Nuevo edificio">
					<template #extra-actions>
						<button class="btn xs ghost" style="margin-top:4px; width:100%" @click="autoImportAssets" title="Escanear assets/common/models/buildings/ y registrar automáticamente los nuevos .tscn">⚡ Auto-Importar Assets</button>
					</template>
					<template #row="{ id, o }">
						<span class="ent-icon">{{ o && o.icon || '🏗️' }}</span>
						<span class="ent-name">{{ o && o.label || id }}</span>
						<span class="ent-id mono" :class="{ err: isReserved(id) }">{{ id }}</span>
					</template>
				</entity-list-panel>

				<section class="editor-pane scroll" v-if="current" style="overflow-y:auto; height:100%; padding:14px">
					<editor-toolbar :can-undo="col.canUndo.value" :can-redo="col.canRedo.value"
						:can-paste="col.canPaste.value" :has-current="!!current" :dirty="col.dirty.value"
						:saved-text="col.savedText.value"
						@undo="col.undo()" @redo="col.redo()" @copy="col.copy()" @paste="col.paste()"
						@duplicate="col.duplicate()" @remove="col.remove()" @save="col.doSave()"></editor-toolbar>

					<h3 class="sec">🏗️ Ficha de Edificio 3D</h3>
					<p v-if="isReserved(col.selectedId.value)" class="warnbox">
						⚠️ "{{ col.selectedId.value }}" es un código RESERVADO por una maqueta procedural cableada
						en el motor (ciudad/aldea/casita/templo/place/cueva/ruinas). Esta ficha nunca se instanciará;
						usa otro código.
					</p>
					<div class="form-grid">
						<label>ID
							<input class="input mono" type="text" :value="col.selectedId.value" @change="col.rename($event.target.value)" />
						</label>
						<label>Icono
							<input class="input f-xs" type="text" :value="current.icon" @input="setField('icon', $event.target.value)" placeholder="🏯" />
						</label>
						<label class="full">Etiqueta
							<input class="input" type="text" :value="current.label" @input="setField('label', $event.target.value)" />
						</label>
						<label class="full">Escena Godot (.tscn en assets/common/models/buildings/)
							<div class="row gap">
								<input class="input mono" type="text" :value="current.scene" @input="setField('scene', $event.target.value)" placeholder="res://assets/common/models/buildings/puente.tscn" />
								<button class="btn xs secondary" @click="openScenePicker" type="button">📂 Elegir existente</button>
							</div>
						</label>
						<p v-if="sceneFileMissing" class="warnbox full">
							⚠️ "{{ current.scene }}" no coincide con ningún fichero encontrado en <span class="mono">assets/common/models/buildings/</span>
						</p>
						<div class="tex-modal" v-if="scenePickerOpen">
							<div class="tex-modal__backdrop" @click="closeScenePicker"></div>
							<div class="tex-modal__box">
								<div class="tex-modal__head">
									<b>Elegir escena (.tscn)</b>
									<button class="btn xs ghost" @click="closeScenePicker">✕</button>
								</div>
								<ul class="entity-list" style="max-height:320px">
									<li v-for="f in sceneFiles" :key="f" @click="selectSceneFile(f)">
										<span class="ent-icon">🎬</span>
										<span class="ent-name mono">{{ f }}</span>
									</li>
									<li v-if="!sceneFiles.length" class="empty-row">No hay escenas .tscn en assets/common/models/buildings/.</li>
								</ul>
							</div>
						</div>
						<template v-if="store.expertMode">
						<label class="full">Modelo 3D alternativo <span class="muted">(.glb / .obj / .gltf, experto)</span>
							<div class="row gap">
								<input class="input mono" type="text" :value="current.model_path" @input="setField('model_path', $event.target.value)" placeholder="assets/common/models/decorations/oro.gltf" />
								<button class="btn xs secondary" @click="openModelPicker" type="button">📂 Elegir existente</button>
								<label class="btn xs ghost" style="cursor:pointer; margin:0">⭱ Subir modelo
									<input type="file" accept=".glb,.obj,.gltf,.tscn" style="display:none" @change="onUploadModel" />
								</label>
							</div>
						</label>
						<div class="tex-modal" v-if="modelPickerOpen">
							<div class="tex-modal__backdrop" @click="closeModelPicker"></div>
							<div class="tex-modal__box">
								<div class="tex-modal__head">
									<b>Elegir modelo 3D (assets/common/models/)</b>
									<button class="btn xs ghost" @click="closeModelPicker">✕</button>
								</div>
								<ul class="entity-list" style="max-height:320px">
									<li v-for="f in modelFiles" :key="f" @click="selectModelFile(f)">
										<span class="ent-icon">📦</span>
										<span class="ent-name mono">{{ f }}</span>
									</li>
									<li v-if="!modelFiles.length" class="empty-row">No hay modelos en assets/common/models/.</li>
								</ul>
							</div>
						</div>
						<label>Escala
							<input class="input" type="number" step="0.05" :value="current.scale ?? 1.0" @input="setNumberField('scale', $event.target.value)" />
						</label>
						<label>Desplaz. Y <span class="muted">(altura)</span>
							<input class="input" type="number" step="0.01" :value="current.y_offset ?? 0.0" @input="setNumberField('y_offset', $event.target.value)" />
						</label>
						</template>
						<label class="full">Descripción (interna)
							<textarea class="input" rows="2" :value="current.description" @input="setField('description', $event.target.value)"></textarea>
						</label>
					</div>
					<div class="panel" style="margin-top:12px; padding:10px; background:rgba(255,255,255,0.02)">
						<div class="muted" style="font-size:12px">
							💡 <b>Cómo usar este edificio:</b> En la pestaña <b>Entidades</b> (<span class="mono">ids.json</span>) asigna este código en el campo <b>Aspecto en el mundo (visual)</b>. En runtime 3D, esa entidad mostrará este modelo en lugar de la maqueta por defecto.
						</div>
					</div>
				</section>

				<section class="editor-pane empty" v-else>
					<p class="muted">Selecciona o crea un edificio-asset para configurarlo.</p>
				</section>
			</template>

			<template v-else>
				<aside class="side" style="display:flex; flex-direction:column; height:100%; overflow:hidden">
					<div class="muted" style="padding:10px; font-size:11px; border-bottom:1px solid var(--line)">
						Maquetas base low-poly integradas en el motor. Puedes ajustar aquí sus colores y escala global.
					</div>
					<ul class="entity-list scroll" style="flex:1; overflow-y:auto">
						<li v-for="code in CLASSIC_CODES" :key="code"
							:class="{ active: selectedClassic === code }" @click="selectedClassic = code">
							<span class="ent-icon">{{ CLASSIC_BUILDINGS[code].icon }}</span>
							<span class="ent-name">{{ CLASSIC_BUILDINGS[code].label }}</span>
							<span class="ent-id mono">{{ code }}</span>
							<span v-if="isClassicOverridden(code)" class="ds-badge ds-badge--accent" title="Tiene override guardado">●</span>
						</li>
					</ul>
				</aside>

				<section class="editor-pane scroll" v-if="selectedClassic" style="overflow-y:auto; height:100%; padding:14px">
					<h3 class="sec">{{ CLASSIC_BUILDINGS[selectedClassic].icon }} {{ CLASSIC_BUILDINGS[selectedClassic].label }}</h3>
					<p class="muted mono">item == "{{ selectedClassic }}"</p>
					<div class="form-grid">
						<label>Color de pared
							<input class="input" type="color"
								:value="classicField(selectedClassic, 'wall_color', CLASSIC_BUILDINGS[selectedClassic].wall)"
								@input="setClassicField(selectedClassic, 'wall_color', $event.target.value)" />
						</label>
						<label v-if="CLASSIC_BUILDINGS[selectedClassic].roof">Color de tejado
							<input class="input" type="color"
								:value="classicField(selectedClassic, 'roof_color', CLASSIC_BUILDINGS[selectedClassic].roof)"
								@input="setClassicField(selectedClassic, 'roof_color', $event.target.value)" />
						</label>
						<label>Escala (multiplica la de siempre)
							<input class="input" type="number" step="0.05" min="0.1"
								:value="classicField(selectedClassic, 'scale', 1.0)"
								@input="setClassicScale(selectedClassic, $event.target.value)" />
						</label>
					</div>
					<button class="btn" style="margin-top:16px" :disabled="!isClassicOverridden(selectedClassic)"
						@click="resetClassic(selectedClassic)">↩️ Restaurar aspecto cableado de siempre</button>
				</section>
			</template>
		</div>
	</div>
	`,
};
