// components/WorldResourcesManager.js
// ─────────────────────────────────────────────────────────────────────────────
// Gestor de RECURSOS FARMEABLES del mapamundi (data/world_resources/<code>.json),
// colección "un fichero por id" con CRUD COMPLETO desde el editor.
// Cada entrada:
//   { label, icon, biome_color, order?, description?, placeable?,
//     skill?, item?, item_loc?, category?, name_loc?, found_loc?, capacity? }
// Los campos skill/item/capacity determinan la RECOLECCIÓN (oficio que lo
// trabaja, ítem que entrega y reserva del nodo antes de agotarse); los resuelve
// en runtime Design.resolve_gather_resource() (ver scripts/autoload/Design.gd),
// que fusiona esta ficha con la tabla cableada de respaldo GameConfig.RESOURCE_TYPES.
// Así se puede crear un recurso NUEVO íntegramente desde el editor, sin GDScript:
// basta con definir aquí sus campos y usar su `code` como `resource` de una
// casilla en el editor de mapamundi.
// ─────────────────────────────────────────────────────────────────────────────
import { ref, computed } from 'https://unpkg.com/vue@3/dist/vue.esm-browser.prod.js';
import { store } from '../store.js';
import * as FS from '../fs.js';
import { useCollection } from '../lib/useCollection.js';
import EntityListPanel from './EntityListPanel.js';
import EditorToolbar from './EditorToolbar.js';

// Oficios de recolección reconocidos por el motor (GameConfig.START_SKILLS /
// GATHER_TOOL_REQUIREMENTS). Un `skill` fuera de esta lista sigue funcionando
// (el jugador necesitaría tener esa clave de habilidad), pero no tendría
// herramienta/XP cableados; se avisa en el formulario.
// La opción '' (Ninguno) es válida y explícita: recursos como el cofre de
// botín, la vaca o la granja de cerdos no deberían exigir ningún oficio para
// recolectarse.
const GATHER_SKILL_OPTIONS = [
	['', 'Ninguno'],
	['lenador', 'lenador'],
	['minero', 'minero'],
	['pesca', 'pesca'],
	['agricultor', 'agricultor'],
	['ganadero', 'ganadero'],
	['cazador', 'cazador'],
];

// Valores cableados en GameConfig.RESOURCE_TYPES (scripts/config/GameConfig.gd),
// que el motor usa como respaldo cuando el JSON de este recurso no define
// skill/item explícitamente (ver Design.resolve_gather_resource). Se muestran
// aquí para que el editor refleje lo que realmente se aplica in-game, en vez de
// una suposición fija.
const ENGINE_DEFAULTS = {
	forest: { skill: 'lenador', item: 'wood' },
	forestBad: { skill: 'lenador', item: 'wood' },
	rock: { skill: 'minero', item: 'stone' },
	gold: { skill: 'minero', item: 'gold_ore' },
	fish: { skill: 'pesca', item: 'fish' },
};

export default {
	name: 'WorldResourcesManager',
	components: { EntityListPanel, EditorToolbar },
	setup() {
		const col = useCollection({
			tabId: 'worldResources',
			dirtyKey: 'worldResources',
			dirtyMap: () => store.dirtyWorldResources,
			collection: () => store.worldResources,
			setCollection: (v) => { store.worldResources = v; },
			selectedKey: 'selectedWorldResource',
			clipboardKind: 'worldResource',
			entityLabel: 'recurso',
			newIdBase: 'recurso_nuevo',
			codeField: 'code',
			onRemove: (code) => FS.deleteCollectionItem('world_resources', code),
			makeNew: (code) => ({
				code, label: 'Nuevo recurso', icon: '🌿', biome_color: '#2c2b33', order: 99,
				description: '', placeable: true,
				skill: 'lenador', item: '', category: 'other', capacity: 10,
				item_loc: '', name_loc: '', found_loc: '',
			}),
			searchText: (id, o) => id + ' ' + (o?.label || '') + ' ' + (o?.skill || '') + ' ' + (o?.item || ''),
			sorts: [
				{ key: 'order', label: 'Orden', get: (id, o) => o?.order ?? 0 },
				{ key: 'code', label: 'Código', get: (id) => id },
				{ key: 'label', label: 'Etiqueta', get: (id, o) => o?.label || '' },
			],
		});
		const current = col.current;

		function setField(field, v) { col.edit(() => { current.value[field] = v; }); }
		function setNumberField(field, v) { col.edit(() => { current.value[field] = parseFloat(v) || 0; }); }
		function setBoolField(field, v) { col.edit(() => { current.value[field] = !!v; }); }
		function itemMissing(id) { return !!id && (!store.items || !store.items[id]); }
		// Un `skill` EXPLÍCITO (incluida la cadena vacía = "Ninguno") siempre manda;
		// solo se cae al valor cableado de GameConfig.RESOURCE_TYPES (o a "Ninguno")
		// cuando el campo no existe en absoluto en la ficha. Antes esto colapsaba
		// cualquier valor "falsy" (como '') al oficio "lenador" por defecto, lo que
		// hacía parecer que recursos sin oficio (cofre, vaca, granja) lo exigían.
		const effectiveSkill = computed(() => {
			const explicit = current.value ? current.value.skill : undefined;
			if (explicit !== undefined && explicit !== null) return explicit;
			return (ENGINE_DEFAULTS[col.selectedId.value] || {}).skill || '';
		});
		const effectiveItemHint = computed(() => (ENGINE_DEFAULTS[col.selectedId.value] || {}).item || 'wood');

		// ── Picker y subida de modelos 3D (.glb / .obj) ─────────────────────────
		const modelFiles = ref([]);
		const modelPickerOpen = ref(false);
		async function refreshModelFiles() { modelFiles.value = await FS.listAssets('world_model'); }
		function openModelPicker() { modelPickerOpen.value = true; refreshModelFiles(); }
		function closeModelPicker() { modelPickerOpen.value = false; }
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
					alert(`Modelo 3D "${filename}" subido y asignado.`);
				} catch (e) {
					alert(e.message || String(e));
				}
			};
			reader.readAsArrayBuffer(file);
		}

		return { store, col, current, GATHER_SKILL_OPTIONS, setField, setNumberField, setBoolField, itemMissing, effectiveSkill, effectiveItemHint, modelFiles, modelPickerOpen, openModelPicker, closeModelPicker, selectModelFile, onUploadModel };
	},
	template: `
	<div class="manager">
		<entity-list-panel :c="col" search-placeholder="Buscar recurso…" new-label="➕ Nuevo recurso">
			<template #row="{ id, o }">
				<span class="ent-icon">{{ o && o.icon || '🌿' }}</span>
				<span class="ent-name">{{ o && o.label || id }}</span>
				<span class="ent-id mono">{{ id }}</span>
			</template>
		</entity-list-panel>

		<section class="editor-pane" v-if="current">
			<editor-toolbar :can-undo="col.canUndo.value" :can-redo="col.canRedo.value"
				:can-paste="col.canPaste.value" :has-current="!!current" :dirty="col.dirty.value"
				:saved-text="col.savedText.value"
				@undo="col.undo()" @redo="col.redo()" @copy="col.copy()" @paste="col.paste()"
				@duplicate="col.duplicate()" @remove="col.remove()" @save="col.doSave()"></editor-toolbar>

			<h3 class="sec">🌿 Recurso farmeable</h3>
			<div class="form-grid">
				<label>ID
					<input class="input mono" type="text" :value="col.selectedId.value" @change="col.rename($event.target.value)" />
				</label>
				<label>Icono
					<input class="input f-xs" type="text" :value="current.icon" @input="setField('icon', $event.target.value)" placeholder="🌲" />
				</label>
				<label>Etiqueta
					<input class="input" type="text" :value="current.label" @input="setField('label', $event.target.value)" />
				</label>
				<label>Color de bioma
					<input class="input" type="color" :value="current.biome_color || '#2c2b33'" @input="setField('biome_color', $event.target.value)" />
				</label>
				<label>Orden
					<input class="input" type="number" step="1" :value="current.order ?? 0" @input="setNumberField('order', $event.target.value)" />
				</label>
				<label class="check">
					<input type="checkbox" :checked="current.placeable !== false" @change="setBoolField('placeable', $event.target.checked)" />
					Colocable con el pincel de recursos
				</label>
				<label class="full">Modelo 3D (.glb / .obj / .tscn en assets/common/models/)
					<div class="row gap">
						<input class="input mono" type="text" :value="current.model_path" @input="setField('model_path', $event.target.value)" placeholder="assets/common/models/decorations/tree_01.glb" />
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
				<label class="full">Descripción
					<textarea class="input" rows="2" :value="current.description" @input="setField('description', $event.target.value)"></textarea>
				</label>
			</div>

			<h3 class="sec">⛏️ Recolección</h3>
			<div class="form-grid">
				<label>Oficio requerido
					<select class="input" :value="effectiveSkill" @change="setField('skill', $event.target.value)">
						<option v-for="[val, lbl] in GATHER_SKILL_OPTIONS" :key="val" :value="val">{{ lbl }}</option>
					</select>
				</label>
				<label>Capacidad del nodo
					<input class="input" type="number" step="1" min="1" :value="current.capacity ?? 10" @input="setNumberField('capacity', $event.target.value)" />
				</label>
				<template v-if="store.expertMode">
				<label>Ítem que entrega <span class="muted">(id de items.json)</span>
					<input class="input mono" :class="{ bad: itemMissing(current.item) }" type="text"
						:value="current.item" @input="setField('item', $event.target.value)" :placeholder="effectiveItemHint" />
				</label>
				<label>Categoría del ítem
					<input class="input" type="text" :value="current.category || 'other'" @input="setField('category', $event.target.value)" />
				</label>
				<p v-if="itemMissing(current.item)" class="warnbox full">
					⚠️ El ítem "{{ current.item }}" no existe en <span class="mono">items.json</span>. Créalo en
					<b>Objetos</b> o corrige el id.
				</p>
				</template>
			</div>

			<template v-if="store.expertMode">
			<h3 class="sec">🌐 Textos <span class="muted" style="font-weight:400">(experto, claves de Locale.gd)</span></h3>
			<div class="form-grid">
				<label>Nombre del nodo <span class="muted">(name_loc)</span>
					<input class="input mono" type="text" :value="current.name_loc" @input="setField('name_loc', $event.target.value)" placeholder="node_bosque" />
				</label>
				<label>Objeto encontrado <span class="muted">(found_loc)</span>
					<input class="input mono" type="text" :value="current.found_loc" @input="setField('found_loc', $event.target.value)" placeholder="gather_found_lenador" />
				</label>
				<label>Nombre del ítem <span class="muted">(item_loc)</span>
					<input class="input mono" type="text" :value="current.item_loc" @input="setField('item_loc', $event.target.value)" placeholder="res_wood" />
				</label>
				<p class="muted full">Si se dejan vacías, el juego usa como texto la propia clave por defecto (sin traducir); no es obligatorio rellenarlas.</p>
			</div>
			</template>

			<p class="muted" style="margin-top:10px">
				Para usarlo: pinta este código como <span class="mono">resource</span> de una casilla en el
				<b>Mapa</b> (pincel de recursos). El motor lo resuelve solo, sin tocar GDScript.
			</p>
		</section>

		<section class="editor-pane empty" v-else>
			<p class="muted">Selecciona o crea un recurso farmeable.</p>
		</section>
	</div>
	`,
};
