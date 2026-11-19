// components/WorldTerrainsManager.js
// ─────────────────────────────────────────────────────────────────────────────
// Gestor de TERRENOS del mapamundi (data/world_terrains/<code>.json), colección
// "un fichero por id" con CRUD COMPLETO desde el editor. Cada
// entrada mezcla visual (label/color/icon/biome_color/description) y física
// (walkable/damage/damage_interval/speed_mult/texture/tint/emission*/uv_scroll/
// wave), más `variants[]` opcional para sub-biomas aleatorios (p. ej. la pradera
// alterna "Sendero"/"Pradera" con pesos). La lee en runtime Design.get_terrain_def()
// (scripts/autoload/Design.gd), consumida por terrain_is_walkable/terrain_damage/
// terrain_damage_interval/terrain_speed_mult y por WorldMapBuilder._apply_terrain_def.
// Crear un terreno nuevo aquí y usar su `code` en el pincel de terreno del Mapa
// no requiere tocar GDScript.
// ─────────────────────────────────────────────────────────────────────────────
import { ref, computed } from 'https://unpkg.com/vue@3/dist/vue.esm-browser.prod.js';
import { store, flash } from '../store.js';
import * as FS from '../fs.js';
import { useCollection } from '../lib/useCollection.js';
import EntityListPanel from './EntityListPanel.js';
import EditorToolbar from './EditorToolbar.js';

// Claves preestablecidas de textura (sin ruta res://, resueltas en GDScript por
// _texture_for_key) → nombre real del fichero en assets/world/map/, solo para
// poder MOSTRAR una miniatura de vista previa aquí en el editor.
const TEXTURE_PRESET_FILE = {
	'': 'tile_pradera.png', pradera: 'tile_pradera.png', grs: 'tile_pradera.png',
	beach: 'tile_beach.png', are: 'tile_beach.png',
	sand: 'tile_sand.png', des: 'tile_sand.png',
	mountain: 'tile_mountain.png', mnt: 'tile_mountain.png',
	snow: 'tile_snow.png', yelmo: 'tile_yelmo.png', bad: 'tile_yelmo.png',
	sea: 'tile_sea.png', cst: 'tile_sea.png',
	ice: 'tile_ice.png', icy: 'tile_ice.png',
	lava: 'tile_lava.png', lav: 'tile_lava.png',
	ground: 'tile_ground.png', gnd: 'tile_ground.png',
	templo: 'tile_templo.png', pth: 'tile_templo.png', stone: 'tile_templo.png',
	grieta: 'tile_grieta.png', void: 'tile_grieta.png',
	contaminacion: 'tile_contaminacion.png', pol: 'tile_contaminacion.png',
};
const TERRAIN_ASSET_KIND = 'terrain';
const TERRAIN_ASSET_PREFIX = 'res://assets/world/map/';

export default {
	name: 'WorldTerrainsManager',
	components: { EntityListPanel, EditorToolbar },
	setup() {
		const col = useCollection({
			tabId: 'worldTerrains',
			dirtyKey: 'worldTerrains',
			dirtyMap: () => store.dirtyWorldTerrains,
			collection: () => store.worldTerrains,
			setCollection: (v) => { store.worldTerrains = v; },
			selectedKey: 'selectedWorldTerrain',
			clipboardKind: 'worldTerrain',
			entityLabel: 'terreno',
			newIdBase: 'terreno_nuevo',
			codeField: 'code',
			onRemove: (code) => FS.deleteCollectionItem('world_terrains', code),
			makeNew: (code) => ({
				code, label: 'Nuevo terreno', color: '#3f8f43', icon: '🌱', biome_color: '#1c2b17',
				order: 99, description: '', walkable: true,
				damage: 0, damage_interval: 0.6, speed_mult: 1.0,
				hazard: '', slippery: false,
			}),
			searchText: (id, o) => id + ' ' + (o?.label || ''),
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

		// ── Variantes (sub-biomas aleatorios con peso) ─────────────────────────
		function addVariant() {
			col.edit(() => {
				if (!Array.isArray(current.value.variants)) current.value.variants = [];
				current.value.variants.push({ weight: 1, label: current.value.label || '', icon: current.value.icon || '', biome_color: current.value.biome_color || '#000000' });
			});
		}
		function removeVariant(idx) { col.edit(() => { current.value.variants.splice(idx, 1); }); }
		function setVariantField(idx, field, v) {
			col.edit(() => { current.value.variants[idx][field] = (field === 'weight') ? (parseFloat(v) || 0) : v; });
		}

		// ── Movimiento de la textura (uv_scroll): array [x, y] en data/world_terrains.
		function setUvScroll(axis, v) {
			col.edit(() => {
				const arr = Array.isArray(current.value.uv_scroll) ? current.value.uv_scroll.slice() : [0, 0];
				arr[axis] = parseFloat(v) || 0;
				current.value.uv_scroll = arr;
			});
		}

		// ── Textura del terreno: preview + subir nueva (PNG) + elegir existente ──
		// (ver §"editor de terreno más amigable"). El campo `texture` sigue
		// siendo o bien una clave preestablecida ("sand"/"mountain"/…) o una ruta
		// "res://assets/world/map/<id>.png"; este picker es solo una capa visual
		// encima de ese mismo campo, sin cambiar el formato de datos.
		function textureFileFor(texVal) {
			const v = String(texVal || '');
			if (v.startsWith(TERRAIN_ASSET_PREFIX)) return v.slice(TERRAIN_ASSET_PREFIX.length);
			if (v.startsWith('res://')) return v.split('/').pop();
			return TEXTURE_PRESET_FILE[v] || TEXTURE_PRESET_FILE[''];
		}
		const texturePreviewUrl = computed(() => current.value ? FS.assetUrl(TERRAIN_ASSET_KIND, textureFileFor(current.value.texture)) : null);
		const textureFiles = ref([]);
		const texturePickerOpen = ref(false);
		async function refreshTextureFiles() { textureFiles.value = await FS.listAssets(TERRAIN_ASSET_KIND); }
		function openTexturePicker() { texturePickerOpen.value = true; refreshTextureFiles(); }
		function closeTexturePicker() { texturePickerOpen.value = false; }
		function selectTexture(file) {
			setField('texture', TERRAIN_ASSET_PREFIX + file);
			texturePickerOpen.value = false;
		}
		/** Terreno (id) que usa actualmente el fichero de textura dado, o null. */
		function terrainUsing(file) {
			for (const [code, t] of Object.entries(store.worldTerrains || {})) {
				if (textureFileFor(t.texture) === file) return code;
			}
			return null;
		}
		async function deleteTexture(file) {
			const usedBy = terrainUsing(file);
			if (usedBy) {
				alert(`Esta textura se está usando para "${usedBy}". Cámbiale la textura a ese terreno antes de borrarla.`);
				return;
			}
			if (!confirm(`¿Borrar la textura "${file}" de assets/world/map/? No se puede deshacer.`)) return;
			try {
				await FS.deleteAsset(TERRAIN_ASSET_KIND, file);
				await refreshTextureFiles();
				flash(`Textura "${file}" borrada.`);
			} catch (e) {
				alert(e.message || String(e));
			}
		}
		function onUploadTexture(ev) {
			const file = ev.target.files && ev.target.files[0];
			ev.target.value = '';
			if (!file) return;
			if (file.type !== 'image/png' && !/\.png$/i.test(file.name)) {
				alert('Solo se admiten imágenes PNG.');
				return;
			}
			let id = (window.prompt('Id de la textura (nombre de fichero, sin espacios ni extensión):', current.value?.code || '') || '').trim();
			if (!id) return;
			if (!/^[A-Za-z0-9_-]+$/.test(id)) {
				alert('Id no válido: solo letras, números, "_" y "-".');
				return;
			}
			const filename = id + '.png';
			const reader = new FileReader();
			reader.onload = async () => {
				try {
					await FS.uploadAsset(TERRAIN_ASSET_KIND, filename, reader.result);
					setField('texture', TERRAIN_ASSET_PREFIX + filename);
					await refreshTextureFiles();
					flash(`Textura "${filename}" subida y asignada.`);
				} catch (e) {
					alert(e.message || String(e));
				}
			};
			reader.readAsArrayBuffer(file);
		}

		function getTerrainThumb(id, o) {
			if (!o) return null;
			const tex = o.texture || '';
			if (tex) {
				const f = tex.split('/').pop();
				if (f) return `/api/assets/terrain/${encodeURIComponent(f)}`;
			}
			return `/api/assets/terrain/tile_${encodeURIComponent(id)}.png`;
		}

		return {
			store, col, current, setField, setNumberField, setBoolField, addVariant, removeVariant, setVariantField,
			setUvScroll, FS, texturePreviewUrl, textureFiles, texturePickerOpen, openTexturePicker, closeTexturePicker,
			selectTexture, deleteTexture, onUploadTexture, terrainUsing, textureFileFor,
			getTerrainThumb,
		};
	},
	template: `
	<div class="manager">
		<entity-list-panel :c="col" search-placeholder="Buscar terreno…" new-label="➕ Nuevo terreno">
			<template #row="{ id, o }">
				<img v-if="getTerrainThumb(id, o)" :src="getTerrainThumb(id, o)" class="ent-thumb" alt=""
					@error="e => { e.target.style.display='none'; if (e.target.nextElementSibling) e.target.nextElementSibling.style.display='inline-block'; }" />
				<span class="ent-icon" :style="{ display: getTerrainThumb(id, o) ? 'none' : 'inline-block' }">{{ o && o.icon || '🌱' }}</span>
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

			<h3 class="sec" style="margin-top:6px">🖼️ Textura del terreno</h3>
			<div class="tex-picker">
				<img class="tex-picker__preview" :src="texturePreviewUrl" alt="" />
				<div class="tex-picker__actions">
					<div class="row gap">
						<button class="btn xs secondary" @click="openTexturePicker">🖼️ Elegir existente</button>
						<label class="btn xs ghost" style="cursor:pointer; margin:0">⭱ Subir nueva (PNG)
							<input type="file" accept="image/png,.png" style="display:none" @change="onUploadTexture" />
						</label>
					</div>
					<span class="tex-picker__name mono">{{ current.texture || 'pradera (por defecto)' }}</span>
				</div>
			</div>

			<div class="tex-modal" v-if="texturePickerOpen">
				<div class="tex-modal__backdrop" @click="closeTexturePicker"></div>
				<div class="tex-modal__box">
					<div class="tex-modal__head">
						<b>Elegir textura</b>
						<button class="btn xs ghost" @click="closeTexturePicker">✕</button>
					</div>
					<div class="tex-grid">
						<div v-for="f in textureFiles" :key="f" class="tex-grid__item" :class="{ active: textureFileFor(current.texture) === f }">
							<img :src="FS.assetUrl('terrain', f)" :title="f" @click="selectTexture(f)" />
							<span class="tex-grid__name">{{ f }}</span>
							<button class="tex-grid__del" title="Borrar textura" @click.stop="deleteTexture(f)">✕</button>
						</div>
						<p v-if="!textureFiles.length" class="muted full">No hay texturas en assets/world/map/.</p>
					</div>
				</div>
			</div>

			<h3 class="sec">🗺️ Terreno</h3>
			<div class="form-grid cols3">
				<label>ID
					<input class="input mono" type="text" :value="col.selectedId.value" @change="col.rename($event.target.value)" />
				</label>
				<label>Icono
					<input class="input f-xs" type="text" :value="current.icon" @input="setField('icon', $event.target.value)" placeholder="🌱" />
				</label>
				<label>Orden
					<input class="input" type="number" step="1" :value="current.order ?? 0" @input="setNumberField('order', $event.target.value)" />
				</label>
				<label>Etiqueta
					<input class="input" type="text" :value="current.label" @input="setField('label', $event.target.value)" />
				</label>
				<label>Color pincel
					<input class="input" type="color" :value="current.color || '#3f8f43'" @input="setField('color', $event.target.value)" />
				</label>
				<label>Color bioma
					<input class="input" type="color" :value="current.biome_color || '#1c2b17'" @input="setField('biome_color', $event.target.value)" />
				</label>
				<label class="full">Descripción
					<textarea class="input" rows="2" :value="current.description" @input="setField('description', $event.target.value)"></textarea>
				</label>
			</div>

			<h3 class="sec">⚙️ Física</h3>
			<div class="form-grid cols3">
				<label>Daño por tick
					<input class="input" type="number" step="1" min="0" :value="current.damage ?? 0" @input="setNumberField('damage', $event.target.value)" />
				</label>
				<label>Intervalo de daño (s)
					<input class="input" type="number" step="0.05" min="0.05" :value="current.damage_interval ?? 0.6" @input="setNumberField('damage_interval', $event.target.value)" />
				</label>
				<label>Multiplicador de velocidad
					<input class="input" type="number" step="0.05" min="0.05" :value="current.speed_mult ?? 1.0" @input="setNumberField('speed_mult', $event.target.value)" />
				</label>
				<label>Peligro ambiental
					<select class="input" :value="current.hazard || ''" @change="setField('hazard', $event.target.value)">
						<option value="">Ninguno</option>
						<option value="heat">🔥 Calor (insolación)</option>
						<option value="cold">❄️ Frío (congelación)</option>
					</select>
				</label>
				<label class="check">
					<input type="checkbox" :checked="current.walkable !== false" @change="setBoolField('walkable', $event.target.checked)" />
					Transitable
				</label>
				<label class="check">
					<input type="checkbox" :checked="!!current.slippery" @change="setBoolField('slippery', $event.target.checked)" />
					Resbaladizo (hielo)
				</label>
				<label class="check">
					<input type="checkbox" :checked="current.blendable !== false" @change="setBoolField('blendable', $event.target.checked)" />
					Fusionable (difuminar bordes con vecinos)
				</label>
				<p class="muted full" style="margin-top:-2px">Peligro: se acumula mientras el jugador pisa el terreno (barra bajo el HUD); si se llena, muere y reaparece con 1 PV. Independiente del "daño por tick" (directo, tipo lava).</p>
			</div>

			<template v-if="store.expertMode">
			<h3 class="sec">✨ Render 3D <span class="muted" style="font-weight:400">(experto)</span></h3>
			<p class="muted" style="margin-top:-4px">100% data-driven: se aplica a CUALQUIER terreno (incluidos mar/orilla/nieve/yelmo/tierra/montaña).</p>
			<div class="form-grid cols4">
				<label title="Aclara u oscurece la textura">Tinte
					<input class="input" type="color" :value="current.tint || '#ffffff'" @input="setField('tint', $event.target.value)" />
				</label>
				<label>Brillo del tinte
					<input class="input" type="number" step="0.05" min="0" :value="current.tint_boost ?? 1" @input="setNumberField('tint_boost', $event.target.value)" />
				</label>
				<label title="0 = pulido/brillante, 1 = mate">Rugosidad
					<input class="input" type="number" step="0.05" min="0" max="1" :value="current.roughness ?? 0.85" @input="setNumberField('roughness', $event.target.value)" />
				</label>
				<label title="Efecto de oleaje (wave)">Ondulación
					<input class="input" type="number" step="0.005" min="0" :value="current.wave ?? 0" @input="setNumberField('wave', $event.target.value)" />
				</label>
				<label title="Desplazamiento de textura X (uv_scroll)">Textura X
					<input class="input" type="number" step="0.005" :value="(current.uv_scroll && current.uv_scroll[0]) ?? 0" @input="setUvScroll(0, $event.target.value)" />
				</label>
				<label title="Desplazamiento de textura Y (uv_scroll)">Textura Y
					<input class="input" type="number" step="0.005" :value="(current.uv_scroll && current.uv_scroll[1]) ?? 0" @input="setUvScroll(1, $event.target.value)" />
				</label>
				<label>Color emisión
					<input class="input" type="color" :value="current.emission || '#000000'" @input="setField('emission', $event.target.value)" />
				</label>
				<label>Energía emisión
					<input class="input" type="number" step="0.1" min="0" :value="current.emission_energy ?? 0" @input="setNumberField('emission_energy', $event.target.value)" />
				</label>
				<label>Pulso emisión
					<input class="input" type="number" step="0.1" min="0" :value="current.emission_pulse ?? 0" @input="setNumberField('emission_pulse', $event.target.value)" />
				</label>
			</div>
			</template>

			<template v-if="store.expertMode">
			<h3 class="sec">🎲 Variantes <span class="muted" style="font-weight:400">(sub-biomas aleatorios, experto)</span></h3>
			<p class="muted">Alternan al azar dentro del mismo código, ponderadas por <span class="mono">weight</span> (p. ej. Pradera con "Sendero" y "Pradera").</p>
			<table class="prof-skill-table" v-if="current.variants && current.variants.length">
				<thead><tr><th>Peso</th><th>Icono</th><th>Etiqueta</th><th>Color de bioma</th><th></th></tr></thead>
				<tbody>
					<tr v-for="(v, idx) in current.variants" :key="idx">
						<td><input class="input" type="number" step="1" min="0" :value="v.weight" @input="setVariantField(idx, 'weight', $event.target.value)" style="width:64px" /></td>
						<td><input class="input" type="text" :value="v.icon" @input="setVariantField(idx, 'icon', $event.target.value)" style="width:56px" /></td>
						<td><input class="input" type="text" :value="v.label" @input="setVariantField(idx, 'label', $event.target.value)" /></td>
						<td><input class="input" type="color" :value="v.biome_color || '#000000'" @input="setVariantField(idx, 'biome_color', $event.target.value)" /></td>
						<td><button class="btn sm danger" @click="removeVariant(idx)" title="Quitar variante">🗑</button></td>
					</tr>
				</tbody>
			</table>
			<button class="btn sm ghost" @click="addVariant" style="margin-top:6px">➕ Añadir variante</button>
			</template>

			<p class="muted" style="margin-top:10px">
				Para usarlo: pinta este código con el pincel de <b>terreno</b> en el <b>Mapa</b>. El motor lo
				resuelve solo (física + visual), sin tocar GDScript.
			</p>
		</section>

		<section class="editor-pane empty" v-else>
			<p class="muted">Selecciona o crea un terreno.</p>
		</section>
	</div>
	`,
};
