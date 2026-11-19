// components/DungeonEditor.js
// ─────────────────────────────────────────────────────────────────────────────
// EDITOR VISUAL DE MAZMORRAS (Tarea 3) — data-driven sobre `data/dungeons/<id>.json`
// (colección "un fichero por id"; ver fs.js listCollection/readCollectionItem).
//
// Las mazmorras son de EXPLORACIÓN EN PRIMERA PERSONA basadas en CUADRÍCULA:
//   · Una mazmorra tiene N PLANTAS (floors), cada una es una rejilla WxH.
//   · Cada CASILLA tiene un TIPO (suelo, pared, puerta, lava, monstruo, …) y
//     PROPIEDADES (textura, tipo de pared, altura, rotación, color, colisión,
//     iluminación) más referencias (enemigo/NPC/objeto/teleport/evento).
//
// Ofrece: vista SUPERIOR editable con iconos por casilla, panel de propiedades,
// PREVIEW 3D isométrica (canvas), deshacer/rehacer y autoguardado (reutiliza las
// libs comunes de las Tareas 1-2), y gestión de mazmorras (crear/duplicar/borrar)
// sincronizada con `ids.json` para que se puedan colocar en el mapa del mundo.
//
// El formato NO toca el runtime existente: las mazmorras antiguas (CaveStage…)
// siguen en DungeonDatabase.gd; el runtime lee esta rejilla solo si existe una
// entrada aquí para el event_id (ver DungeonLayouts.gd / GridDungeonStage.gd).
// ─────────────────────────────────────────────────────────────────────────────
import { ref, reactive, computed, watch, onMounted, onUnmounted, nextTick } from 'https://unpkg.com/vue@3/dist/vue.esm-browser.prod.js';
import { store, nav, markDirty, markDungeonDirty, ensureDungeonLoaded, flash, save, getI18n, getI18nFallback, getI18nDisplay, setI18n } from '../store.js';
import * as FS from '../fs.js';
import { useHistory, deepClone } from '../lib/useHistory.js';
import { useAutosave } from '../lib/useAutosave.js';
import { useDungeonAssets } from '../lib/useDungeonAssets.js';
import { WALL_TYPES, FLOOR_TEX, ENV_THEME_OPTIONS, ENV_SKY_OPTIONS, ENV_VOID_OPTIONS } from '../lib/dungeonConstants.js';
import TEMPLATE from './templates/DungeonEditorTemplate.js';
import DungeonWalkthroughModal from './DungeonWalkthroughModal.js';
import DungeonWizardModal from './DungeonWizardModal.js';
import DsAudioBtn from '../ui/DsAudioBtn.js';

// ─── CATÁLOGO DE TIPOS DE CASILLA ────────────────────────────────────────────
// Cada tipo de casilla vive en su propio fichero `data/dungeon_tiles/<t>.json`
// (colección "un fichero por id", cargada por store.js en `store.dungeonTiles`):
// { t, label, icon, color, group, order, solid?, entity?, actuator?, stateful?,
//   orient?, smart?, render? }. `render` (opcional) describe la geometría
// COSMÉTICA genérica que construye Design/GridDungeonStage.gd sin código nuevo
// (suelo/pared/líquido/pincho/luz); los tipos sin `render` siguen dibujándose
// con una función dedicada en el motor (puertas, decoración, gameplay…).
// Ver `dunTiles`/`tileMap`/`tileGroups` más abajo (derivados de store.dungeonTiles).

// Tipos de pared y de suelo (para propiedades de casilla). Son etiquetas
// libres que el runtime interpreta al elegir material/altura. Compartidas con
// DungeonWizardModal.js vía lib/dungeonConstants.js (evita import circular;
// ver import al inicio del fichero).

// Nombre del PNG que el motor usa como textura por defecto de pared/suelo/techo
// cuando la celda no elige ni preset ni textura propia (`_build_materials` en
// GridDungeonStage.gd). Vive en assets/dungeon/textures — se resuelve vía
// `dungeonTextures` (ya lista ese directorio), no hace falta URL aparte.
const DEFAULT_SURFACE_TEX = 'tex_cave_wall.png';

// Colores EXACTOS de los presets "de fábrica" — MISMOS valores que _WALL_COLORS/
// _TEX_COLORS en GridDungeonStage.gd (convertidos de Color 0..1 a hex). IMPORTANTE:
// al elegir uno de estos presets, el motor NO tiñe la textura por defecto — la
// SUSTITUYE por un color plano (`_tinted()` quita la textura base, ver
// `_surface_material`/`_surface_tint`). Por eso aquí también se muestran como
// color plano exacto y NO como una textura/patrón inventado: mostrar un patrón
// de ladrillos o vetas de madera sería mentir sobre lo que realmente se ve en 3D
// (bug reportado: "ni parecido, ni me está seleccionando la textura real").
const WALL_COLORS = { stone: '#77777d', brick: '#8f4330', cave: '#55402f', wood: '#7f5227', metal: '#9ba1ab', ice: '#a9dced' };
const FLOOR_COLORS = { stone: '#77777d', dirt: '#6e4526', grass: '#418a33', sand: '#d6bd78', wood: '#7f5227', metal: '#9ba1ab', tiles: '#5a616e', lava_rock: '#3a1a10' };
// Los swatches del picker reutilizan los mismos colores exactos (antes eran
// degradados CSS inventados que no correspondían a nada real en el motor).
const TEX_SWATCH = FLOOR_COLORS;
const WALL_SWATCH = WALL_COLORS;

// ── CACHÉ de imágenes de TEXTURA REAL para las previsualizaciones ──────────────
// Antes `drawCube` pintaba SIEMPRE un color liso, ignorando por completo la
// textura elegida/subida — bug reportado ("ni parecido, ni me está
// seleccionando la textura real"). Cargamos cada PNG una vez (Image nativa) y
// lo reutilizamos como CanvasPattern; `onReady` (recibido por el que lo pide)
// se dispara al terminar de cargar para repintar con la textura ya lista.
const _texImgCache = new Map(); // url -> HTMLImageElement
function loadTexImage(url, onReady) {
	if (!url) return null;
	let img = _texImgCache.get(url);
	if (!img) {
		img = new Image();
		img.onload = () => onReady && onReady();
		img.src = url;
		_texImgCache.set(url, img);
	}
	return (img.complete && img.naturalWidth) ? img : null;
}

// Selector de textura/material con MINIATURA visual: rejilla de chips (muestra de
// color/patrón + etiqueta) en lugar de un <select> de texto. Reutilizable para
// textura de suelo y tipo de pared, en el panel del pincel y en el inspector.
//
// Además de los PRESETS de color (options + swatches), muestra las TEXTURAS reales
// (PNG) disponibles bajo assets/dungeon/textures — con su miniatura real — y, si
// `allowUpload`, un chip para SUBIR una nueva textura (emite 'upload' con el File).
// El valor de un preset es su nombre pelado ("stone"); el de una textura es su
// nombre de fichero ("mi_muro.png"), que el motor resuelve como PNG real.
const TexSwatchPicker = {
	name: 'TexSwatchPicker',
	props: {
		modelValue: { type: String, default: '' },
		options: { type: Array, required: true },
		swatches: { type: Object, default: () => ({}) },
		textures: { type: Array, default: () => [] },   // [{ name, url }]
		allowUpload: { type: Boolean, default: false },
		defaultTextureUrl: { type: String, default: '' }, // miniatura REAL de "por defecto"
	},
	emits: ['update:modelValue', 'upload'],
	setup(props, { emit }) {
		const swatchStyle = (v) => (props.swatches[v] ? { background: props.swatches[v] } : {});
		// El fichero de la textura por defecto ya aparece con su propia miniatura en
		// el chip "por defecto" (abajo) — se oculta de la lista de texturas reales
		// para no duplicarlo.
		const realTextures = computed(() => props.textures.filter(t => t.name !== DEFAULT_SURFACE_TEX));
		const pick = (v) => emit('update:modelValue', v);
		const onFile = (ev) => {
			const f = ev.target.files && ev.target.files[0];
			if (f) emit('upload', f);
			ev.target.value = '';
		};
		return { swatchStyle, pick, onFile, realTextures };
	},
	template: `
		<div class="tex-picker">
			<button v-for="o in options" :key="o" type="button" class="tex-chip"
				:class="{ active: modelValue===o }" @click="pick(o)" :title="o || 'por defecto (textura de roca real)'">
				<span class="tex-chip__sw" :class="{ 'is-default': !o }"
					:style="!o && defaultTextureUrl ? { backgroundImage: 'url(' + defaultTextureUrl + ')', backgroundSize: 'cover' } : swatchStyle(o)"></span>
				<span class="tex-chip__lbl">{{ o || 'por defecto' }}</span>
			</button>
			<button v-for="t in realTextures" :key="t.name" type="button" class="tex-chip"
				:class="{ active: modelValue===t.name || modelValue===t.name.replace(/\.[^.]+$/, '') }"
				@click="pick(t.name.replace(/\.[^.]+$/, ''))" :title="t.name">
				<span class="tex-chip__sw tex-chip__img" :style="{ backgroundImage: 'url(' + t.url + ')' }"></span>
				<span class="tex-chip__lbl">{{ t.name.replace(/\.[^.]+$/, '') }}</span>
			</button>
			<label v-if="allowUpload" class="tex-chip tex-chip--upload" title="Subir una textura .png a assets/dungeon/textures">
				<input type="file" accept=".png" @change="onFile" hidden />
				<span class="tex-chip__sw tex-chip__add">＋</span>
				<span class="tex-chip__lbl">subir</span>
			</label>
		</div>
	`,
};

// CAPACIDADES por tipo de casilla: qué propiedades de ASPECTO tienen sentido y
// EFECTO real en el motor para ese tipo. Deriva de los flags del catálogo
// (meta.solid/orient/render.shape) — así el panel de propiedades es CONTEXTUAL
// (no muestra "textura de pared" en una antorcha) y coherente con lo que
// GridDungeonStage.gd realmente dibuja. Ver (análisis de debilidades).
const LIGHT_EMITTERS = ['torch', 'light', 'crystal', 'campfire', 'rune', 'lava', 'decor'];
function tileCaps(meta) {
	if (!meta) return {};
	const shape = (meta.render && meta.render.shape) || '';
	const t = meta.t || '';
	const isFloorSurface = shape === 'floor' || t === 'floor' || t === 'bridge';
	const isWall = shape === 'wall' || t === 'wall';
	const isModel = shape === 'model';
	const isDecor = meta.decor === true || t === 'decor' || ['armario_libreria', 'barril_manzanas', 'caja_pesada', 'cama', 'escalera_con_muros', 'hojas_pared', 'bomba', 'bomb', 'barrel', 'crate', 'chest', 'cofre', 'column'].indexOf(t) !== -1;
	const emitsLight = LIGHT_EMITTERS.indexOf(t) !== -1 || shape === 'light' || shape === 'liquid';
	const canBlock = meta.solid === true || isWall || isModel || isDecor;
	return {
		floorTex: isFloorSurface,
		wallType: isWall,
		height: isWall,
		orient: meta.orient === true || isDecor,
		decor: isDecor,
		color: shape !== 'none' && t !== 'void',
		light: emitsLight,
		collision: canBlock && t !== 'door' && t !== 'gate',
		signage: isFloorSurface || isWall,
	};
}

// Editor REUTILIZABLE de propiedades de aspecto de una casilla. Lo usan tanto el
// panel del pincel (model = brushConfig) como el inspector (model = selCell), así
// no se duplica el marcado y ambos son contextuales por igual. Solo pinta los
// controles cuyo `caps.<x>` es true. Emite ('change', key, value); el padre
// decide cómo persistir (borrar si '' / false, etc.).
const CellPropsEditor = {
	name: 'CellPropsEditor',
	components: { TexSwatchPicker },
	props: {
		model: { type: Object, required: true },
		caps: { type: Object, required: true },
		defaultColor: { type: String, default: '#39404e' },
		hint: { type: String, default: '' },
		textures: { type: Array, default: () => [] },      // [{ name, url }] de assets/dungeon/textures
		uploadTexture: { type: Function, default: null },  // (File) => Promise<filename>
		defaultTextureUrl: { type: String, default: '' },  // miniatura REAL de "por defecto" (tex_cave_wall.png)
	},
	emits: ['change'],
	setup(props, { emit }) {
		const set = (k, v) => emit('change', k, v);
		const anyProps = computed(() => {
			const c = props.caps || {};
			return !!(c.floorTex || c.wallType || c.height || c.orient || c.decor || c.color || c.light || c.collision || c.signage);
		});
		// Sube la textura elegida y, al terminar, la asigna como material (tex/wall).
		const onUpload = async (key, file) => {
			if (!props.uploadTexture) return;
			const name = await props.uploadTexture(file);
			if (name) set(key, name);
		};
		return { set, onUpload, anyProps, FLOOR_TEX, WALL_TYPES, TEX_SWATCH, WALL_SWATCH };
	},
	template: `
		<div class="cell-props">
			<p v-if="hint" class="brush-card__hint">{{ hint }}</p>

			<!-- 1. Geometría y Aspecto -->
			<div v-if="caps.wallType || caps.floorTex || caps.height || caps.orient || caps.decor || caps.color" class="prop-sep">Aspecto y Geometría</div>
			<template v-if="caps.wallType">
				<label>Material de la pared</label>
				<tex-swatch-picker :model-value="model.wall || ''" :options="WALL_TYPES" :swatches="WALL_SWATCH"
					:textures="textures" :allow-upload="!!uploadTexture" :default-texture-url="defaultTextureUrl"
					@update:model-value="set('wall', $event)" @upload="onUpload('wall', $event)"></tex-swatch-picker>
				<label class="chkline" style="margin-top: 6px; margin-bottom: 8px;">
					<input type="checkbox" :checked="!!model.floor || !!model.has_floor" @change="set('floor', $event.target.checked)"> 🔲 Generar suelo bajo la pared
				</label>
			</template>
			<template v-if="caps.floorTex">
				<label>Material del suelo</label>
				<tex-swatch-picker :model-value="model.tex || ''" :options="FLOOR_TEX" :swatches="TEX_SWATCH"
					:textures="textures" :allow-upload="!!uploadTexture" :default-texture-url="defaultTextureUrl"
					@update:model-value="set('tex', $event)" @upload="onUpload('tex', $event)"></tex-swatch-picker>
			</template>
			<div v-if="caps.orient || caps.decor" class="row2" style="margin-top: 4px;">
				<div>
					<label>Dirección / Mirando a</label>
					<select :value="model.rot != null ? model.rot : (model.dir === 'este' || model.dir === 'derecha' ? 90 : (model.dir === 'sur' || model.dir === 'abajo' ? 180 : (model.dir === 'oeste' || model.dir === 'izquierda' ? 270 : 0)))" @change="set('rot', Number($event.target.value))">
						<option :value="0">⬆️ Norte / Arriba (0°)</option>
						<option :value="90">➡️ Este / Derecha (90°)</option>
						<option :value="180">⬇️ Sur / Abajo (180°)</option>
						<option :value="270">⬅️ Oeste / Izquierda (270°)</option>
					</select>
				</div>
				<div>
					<label>Posición en casilla</label>
					<select :value="model.wall_snap ? 'wall' : 'center'" @change="set('wall_snap', $event.target.value === 'wall')">
						<option value="center">🎯 Centro de casilla</option>
						<option value="wall">🧱 Pegado a la pared</option>
					</select>
				</div>
			</div>
			<div v-if="caps.height" class="row2">
				<div><label>Altura (m)</label>
					<input type="number" min="0" step="0.25" :value="model.h || ''" placeholder="auto" @change="set('h', $event.target.value===''?'':Number($event.target.value))" /></div>
				<div></div>
			</div>
			<div v-if="caps.orient" class="row2">
				<div><label>Escala (×)</label>
					<input type="number" min="0.25" max="4" step="0.25" :value="model.scale || 1" @change="set('scale', $event.target.value===''?'':Number($event.target.value))" /></div>
				<div></div>
			</div>
			<!-- Control de Modo Palanca / Interruptor (Un solo uso vs Múltiples usos) -->
			<div v-if="model.t === 'lever' || model.t === 'switch'" class="row2" style="margin-top: 6px;">
				<div>
					<label>Modo de activación</label>
					<select :value="model.multi_use ? 'multi' : 'single'" @change="set('multi_use', $event.target.value === 'multi')">
						<option value="single">🔒 Un solo uso (Fijo al accionar)</option>
						<option value="multi">🔄 Múltiples usos (Conmutable)</option>
					</select>
				</div>
				<div></div>
			</div>

			<div v-if="caps.color" class="row2">
				<div><label>Color (tinte)</label>
					<div class="row-flex">
						<input type="color" :value="model.color || defaultColor" @input="set('color', $event.target.value)" />
						<button class="btn xs ghost" @click="set('color', '')">reset</button>
					</div></div>
				<div></div>
			</div>

			<!-- 2. Iluminación -->
			<template v-if="caps.light">
				<div class="prop-sep">Iluminación</div>
				<div class="row2">
					<div><label>Iluminación</label>
						<input type="number" min="0" step="0.5" :value="model.light || 0" @change="set('light', $event.target.value===''?'':Number($event.target.value))" /></div>
					<div></div>
				</div>
				<div style="margin-top: 6px;">
					<label>Pared / Cara de la Antorcha</label>
					<select :value="model.torch_face || model.face || 'norte'" @change="set('torch_face', $event.target.value)">
						<option value="norte">⬆️ Norte (Pared del Fondo / -Z)</option>
						<option value="sur">⬇️ Sur (Pared de Enfrente / +Z)</option>
						<option value="este">➡️ Este (Pared Derecha / +X)</option>
						<option value="oeste">⬅️ Oeste (Pared Izquierda / -X)</option>
					</select>
				</div>
			</template>

			<!-- 3. Señaléctica y Texto -->
			<template v-if="caps.signage">
				<div class="prop-sep">Señaléctica y Texto</div>
				<div class="row2">
					<div>
						<label>Flecha (Señaléctica)</label>
						<select :value="model.arrow || model.arrow_dir || ''" @change="set('arrow', $event.target.value)">
							<option value="">(Sin flecha)</option>
							<option value="up">⬆️ Arriba</option>
							<option value="down">⬇️ Abajo</option>
							<option value="left">⬅️ Izquierda</option>
							<option value="right">➡️ Derecha</option>
						</select>
					</div>
					<div>
						<label>Color de Flecha</label>
						<div class="row-flex">
							<input type="color" :value="model.arrow_color || '#00ccff'" @input="set('arrow_color', $event.target.value)" />
							<button class="btn xs ghost" @click="set('arrow_color', '')">reset</button>
						</div>
					</div>
				</div>
				<div style="margin-top: 6px;">
					<label>Cara de la Pared (Mostrar Señal)</label>
					<select :value="model.wall_face || model.face || 'sur'" @change="set('wall_face', $event.target.value)">
						<option value="sur">⬇️ Sur (Frente al subir / +Z)</option>
						<option value="norte">⬆️ Norte (Detrás / -Z)</option>
						<option value="este">➡️ Este (Derecha / +X)</option>
						<option value="oeste">⬅️ Oeste (Izquierda / -X)</option>
						<option value="todas">🔄 Todas las 4 caras</option>
					</select>
				</div>
				<div class="row2" style="margin-top: 6px;">
					<div>
						<label>Texto en Pared/Suelo</label>
						<input type="text" :value="model.text || ''" placeholder="Ej: ¡Al Puerto! / Salida" @input="set('text', $event.target.value)" />
					</div>
					<div>
						<label>Color de Texto</label>
						<div class="row-flex">
							<input type="color" :value="model.text_color || '#fff5d4'" @input="set('text_color', $event.target.value)" />
							<button class="btn xs ghost" @click="set('text_color', '')">reset</button>
						</div>
					</div>
				</div>
				<div v-if="model.text" class="row2" style="margin-top: 6px;">
					<div>
						<label>Fuente del texto</label>
						<select :value="model.text_font || 'default'" @change="set('text_font', $event.target.value)">
							<option value="default">Predeterminada</option>
							<option value="horror">Terror</option>
							<option value="creepy">Creepy</option>
							<option value="cinzel">Cinzel</option>
						</select>
					</div>
					<div>
						<label>Tamaño del texto</label>
						<input type="number" min="8" max="120" step="1" :value="model.text_size || ''" placeholder="auto" @change="set('text_size', $event.target.value===''?'':Number($event.target.value))" />
					</div>
				</div>
				<div v-if="model.text" class="row2" style="margin-top: 6px;">
					<div>
						<label>Brillo emisión</label>
						<input type="number" min="0" max="5" step="0.1" :value="model.text_emission || ''" placeholder="auto" @change="set('text_emission', $event.target.value===''?'':Number($event.target.value))" />
					</div>
					<div></div>
				</div>
				<label v-if="model.text" class="chkline" style="margin-top: 4px;">
					<input type="checkbox" :checked="!!model.text_bg" @change="set('text_bg', $event.target.checked)"> Mostrar recuadro de fondo
				</label>
			</template>

			<!-- 4. Propiedades Físicas -->
			<template v-if="caps.collision">
				<div class="prop-sep">Física y Colisión</div>
				<label class="chkline">
					<input type="checkbox" :checked="model.col !== false" @change="set('col', $event.target.checked ? '' : false)"> Colisión (bloquea el paso)
				</label>
			</template>

			<p v-if="!anyProps" class="muted sm">Este elemento no tiene propiedades de aspecto configurables.</p>
		</div>
	`,
};

// Estados iniciales posibles por tipo de elemento interactivo (Fase 6). El motor
// arranca el elemento en este estado; los accionadores lo cambian en juego.
const STATE_OPTIONS = {
	door:         ['closed', 'open', 'locked'],
	switch:       ['off', 'on'],
	lever:        ['off', 'on'],
	light:        ['on', 'off'],
	water:        ['calm', 'frozen', 'electrified'],
	lava:         ['calm', 'frozen'],
	campfire:     ['off', 'on'],
	bridge:       ['closed', 'open'],
	spikes:       ['retracted', 'extended'],
	ice_block:    ['intact', 'melted'],
	roots:        ['blocking', 'cleared'],
	electric:     ['off', 'on'],
	chest:        ['closed', 'open'],
	column:       ['intact', 'displaced'],
	statue:       ['intact', 'displaced'],
};
// Acciones que un accionador puede aplicar a sus objetivos.
const TARGET_ACTIONS = ['toggle', 'open', 'close', 'on', 'off'];

// ─── PALETA UNIFICADA POR TEMA (Fase 1/2, Task 5) ───────────────────────────
// Antes la paleta mostraba los tipos genéricos (dungeon_tiles, agrupados por
// `group`) y las piezas de kit inteligente (dungeon_kits.json, agrupadas por
// `kit`) en DOS bloques visualmente separados, aunque compartían el mismo
// tema (p. ej. "Onda Cinética" aparecía dos veces: una vez como grupo de
// tipos y otra como kit). Esta tabla fusiona ambos por tema en UNA sola
// sección desplegable, sin renombrar ni borrar ningún tipo/pieza real.
const THEME_SECTIONS = [
	{ id: 'structure', icon: '🧱', label: 'Estructura y Decoración',   tileGroups: ['Estructura', 'Sistema', 'Peligros', 'Decoración'], kit: null },
	{ id: 'kinetic',   icon: '💥', label: 'Onda Cinética',            tileGroups: ['Onda Cinética'],     kit: 'kinetic_wave' },
	{ id: 'psychic',   icon: '🏛️', label: 'Agarre Psíquico',           tileGroups: ['Agarre Psíquico'],    kit: 'psychic_grab' },
	{ id: 'time',      icon: '⏳', label: 'Tiempo',                    tileGroups: ['Tiempo'],             kit: 'time_distort' },
	{ id: 'instinct',  icon: '👁️', label: 'Instinto Cazador',          tileGroups: ['Instinto Cazador'],   kit: 'explorer_instinct' },
	{ id: 'elemental', icon: '🔥', label: 'Afinidad Elemental',        tileGroups: ['Afinidad Elemental'], kit: 'elemental_affinity' },
	{ id: 'purify',    icon: '🧪', label: 'Purificación',              tileGroups: ['Purificar'],          kit: 'restoration' },
];

// ─── TASK 3 — ATMÓSFERA Y TEMÁTICA 3D ────────────────────────────────────────
// ENV_THEME_OPTIONS / ENV_SKY_OPTIONS: ver import desde lib/dungeonConstants.js
// al inicio del fichero (compartidas con DungeonWizardModal.js).
// Espejo MINIMO de AudioManager.MUSIC_PATHS (solo lo relevante a mazmorras),
// para poder generar una URL real de preescucha con <ds-audio-btn>. Si se
// añaden pistas nuevas allí, conviene reflejarlas aquí también.
const MUSIC_FILE_MAP = {
	menu: 'bgm_menu.ogg',
	orb_room: 'bgm_orb_room.ogg',
	world: 'bgm_world.ogg',
	combat: 'bgm_combat.ogg',
	combat_boss: 'bgm_combat_boss.ogg',
	dungeon: 'bgm_dungeon_cave.ogg',
	cave: 'bgm_dungeon_cave.ogg',
	ancient_ruins: 'bgm_ancient_ruins_ambient.ogg',
	arcanium_lab: 'bgm_arcanium_lab_ambient.ogg',
	snow_catacomb: 'bgm_snow_catacomb_ambient.ogg',
	nevada: 'bgm_world_snow.ogg',
	city: 'bgm_city.ogg',
};

export default {
	name: 'DungeonEditor',
	components: { TexSwatchPicker, CellPropsEditor, DungeonWalkthroughModal, DungeonWizardModal, DsAudioBtn },
	setup() {
		const walkthroughOpen = ref(false);
		const dungeonWizardOpen = ref(false);
		// Task 7, ítem 5.3: modal de confirmación propio (ds-confirm-dialog, ya
		// existente en el design system pero sin adoptar) en vez de los 4
		// window.confirm() nativos (deleteDungeon/removeFloor/fillEntireFloor/
		// deleteProp), inconsistentes con la estética oscura/dorada del resto.
		const confirmDialog = reactive({ open: false, message: '', danger: true, onYes: null });
		function askConfirm(message, onYes, danger = true) {
			confirmDialog.message = message;
			confirmDialog.danger = danger;
			confirmDialog.onYes = onYes;
			confirmDialog.open = true;
		}
		function onConfirmDialogConfirm() {
			confirmDialog.open = false;
			const fn = confirmDialog.onYes;
			confirmDialog.onYes = null;
			if (fn) fn();
		}
		function onConfirmDialogCancel() {
			confirmDialog.open = false;
			confirmDialog.onYes = null;
		}

		// ── Estado de UI ──────────────────────────────────────────────────────
		const floorIdx = ref(0);
		const brush = ref('floor');           // tipo activo del pincel (modo tipo)
		const painting = ref(false);
		// Modos: pintar celda a celda / rectángulo / relleno contiguo, más dos modos
		// que NO pintan y resuelven dolores de UX: 'select' (inspeccionar la casilla
		// sin pisarla) y 'eyedropper' (copiar la casilla clicada al pincel).
		// : arranca en 'select' — nadie debería poder pintar sin haber
		// elegido antes, a propósito, un tipo de casilla o un modo de pintado.
		// : 'region' (marcar un rectángulo para COPIAR, sin pintar
		// nada) y 'paste' (clic = pegar el contenido copiado, con fantasma de
		// previsualización) — backlog repetido varias veces ("copiar/pegar
		// regiones y selección múltiple").
		const drawMode = ref('select'); // 'pencil' | 'rect' | 'fill' | 'select' | 'eyedropper' | 'region' | 'paste'
		const rectStart = ref(null); // { x, y, isErase }
		const rectEnd = ref(null); // { x, y }
		const eraseMode = ref(false);
		// Configuración por defecto del pincel de TIPO (no-asset): se estampa junto al
		// tipo al pintar, para que "elegir pared" pinte ya con su textura/altura/color
		// y colisión deseados. Se limpia al cambiar de tipo. Ver newBrushCell().
		const brushConfig = ref({});

		// ── Copiar/pegar regiones ────────────────────────────────
		// `regionSel`: último rectángulo CONFIRMADO (tras soltar el ratón en modo
		// 'region'), sobrevive a la suelta para poder revisarlo y pulsar "Copiar".
		// `clipboard`: recorte ya copiado (independiente del layout activo, así que
		// también sirve para pegar en OTRA planta o incluso otra mazmorra).
		const regionSel = ref(null); // { x0, y0, x1, y1 }
		const clipboard = ref(null); // { w, h, cells: Cell[][] }
		const pasteHover = ref(null); // { x, y } — última casilla bajo el ratón en modo 'paste'

		function isInRect(x, y) {
			if (drawMode.value === 'rect' && rectStart.value && rectEnd.value) {
				return rectInBounds(x, y, rectStart.value, rectEnd.value);
			}
			if (drawMode.value === 'region') {
				if (rectStart.value && rectEnd.value) return rectInBounds(x, y, rectStart.value, rectEnd.value);
				if (regionSel.value) return rectInBounds(x, y, regionSel.value, { x: regionSel.value.x1, y: regionSel.value.y1 });
			}
			return false;
		}
		function rectInBounds(x, y, a, b) {
			const x0 = Math.min(a.x, b.x), x1 = Math.max(a.x, b.x);
			const y0 = Math.min(a.y, b.y), y1 = Math.max(a.y, b.y);
			return x >= x0 && x <= x1 && y >= y0 && y <= y1;
		}
		// Fantasma de la casilla de pegado: resalta dónde caería el recorte si se
		// suelta aquí (esquina superior izquierda = casilla bajo el ratón).
		function isInPastePreview(x, y) {
			if (drawMode.value !== 'paste' || !clipboard.value || !pasteHover.value) return false;
			const dx = x - pasteHover.value.x, dy = y - pasteHover.value.y;
			return dx >= 0 && dx < clipboard.value.w && dy >= 0 && dy < clipboard.value.h;
		}

		// ── Task 5 (5.2): Medidor de radio de luces — la casilla SELECCIONADA que
		// emite luz muestra en la rejilla 2D el alcance real de la culling de luces
		// dinámicas (GridDungeonStage.gd::LIGHT_CULL_RANGE = 6m), convertido a
		// casillas vía cell_size de esta mazmorra.
		const LIGHT_CULL_RANGE_M = 6.0;
		function isLightEmitterCell(cell) { return !!cell && LIGHT_EMITTERS.includes(cell.t) && Number(cell.light || 0) > 0; }
		function lightRadiusCellCount() {
			const cs = (dun.value && Number(dun.value.cell_size)) || 4;
			return Math.max(1, Math.round(LIGHT_CULL_RANGE_M / cs));
		}
		function inLightRadius(x, y) {
			if (!sel.value || !selCell.value || !isLightEmitterCell(selCell.value)) return false;
			const r = lightRadiusCellCount();
			const dx = x - sel.value.x, dy = y - sel.value.y;
			return (dx * dx + dy * dy) <= r * r && !(dx === 0 && dy === 0);
		}

		// ── Task 5 (5.2): Rotación 3D con teclas R/E — rota la orientación
		// PENDIENTE (del asset activo o de la config del pincel de tipo) ANTES de
		// colocarla en la rejilla, en pasos de 90°. Ver caps.orient/model.rot en
		// CellPropsEditor más arriba.
		function rotatePendingOrientation(deltaDeg) {
			const norm = (v) => ((Number(v || 0) + deltaDeg) % 360 + 360) % 360;
			if (activeAsset.value) {
				activeAsset.value = { ...activeAsset.value, cell: { ...activeAsset.value.cell, rot: norm(activeAsset.value.cell.rot) } };
				flash('↻ Rotación del asset activo: ' + activeAsset.value.cell.rot + '°');
			} else {
				setBrushConfig('rot', norm(brushConfig.value.rot));
				flash('↻ Rotación del pincel: ' + (brushConfig.value.rot || 0) + '°');
			}
		}

		const sel = ref(null);                 // {x, y} de la casilla seleccionada
		const show3D = ref(false);
		const stack3D = ref(false);            // apilar todas las plantas en la preview
		const zoom = ref(1);
		const gridCanvasWrap = ref(null);
		const previewCanvas = ref(null);
		const newDunId = ref('');
		const showCreateDunModal = ref(false);
		const newDunName = ref('');
		const newDunIdTouched = ref(false);
		const newDunPreset = ref('standard');

		// ── Biblioteca de assets (Fase 6) ─────────────────────────────────────────
		// Si `activeAsset` != null, el pincel ESTAMPA esa casilla configurada en vez
		// de pintar un tipo suelto. Elegir un tipo en la paleta limpia el asset.
		const assets = useDungeonAssets();
		const activeAsset = ref(null);
		const showAssets = ref(false);   // modal de gestión de assets
		const saveAssetName = ref('');

		// ── KITS DE OBJETOS INTELIGENTES ─────────────────────────────────
		// Catálogo de solo lectura (data/dungeon_kits.json). Se pinta una pieza
		// estampando una celda { t:'smart', kit:<piece_id> } (reutiliza activeAsset).
		const ELEMENTS = ['fuego', 'hielo', 'rayo', 'agua', 'viento', 'tierra'];
		const kitsMeta = computed(() => (store.dungeonKits && store.dungeonKits.kits) || {});
		const kitPieces = computed(() => (store.dungeonKits && store.dungeonKits.pieces) || {});
		// Piezas agrupadas por kit, en el orden de declaración de kits.
		const kitGroups = computed(() => {
			const groups = [];
			const meta = kitsMeta.value, pieces = kitPieces.value;
			for (const kitId of Object.keys(meta)) {
				const items = Object.entries(pieces)
					.filter(([, p]) => p.kit === kitId)
					.map(([id, p]) => ({ id, ...p }));
				if (items.length) groups.push({ id: kitId, meta: meta[kitId], items });
			}
			return groups;
		});
		// Def de la pieza de la celda smart seleccionada (o null).
		const selPieceDef = computed(() => {
			const c = selCell.value;
			if (!c || c.t !== 'smart' || !c.kit) return null;
			return kitPieces.value[c.kit] || null;
		});
		function selectKitPiece(pieceId, piece) {
			brush.value = 'smart';
			activeAsset.value = {
				id: 'kit_' + pieceId,
				name: (piece.name && piece.name.es) || pieceId,
				icon: piece.icon || '🧩',
				cell: { t: 'smart', kit: pieceId },
			};
		}
		function pieceUsesElement(pieceDef) {
			if (!pieceDef) return false;
			if (pieceDef.kit === 'elemental_affinity') return true;
			const r = pieceDef.reaction || {};
			return r.type === 'element' || r.type === 'element_source' || !!r.accepted_element || !!r.source_element;
		}

		// ── PALETA UNIFICADA POR TEMA (Fase 1/2, Task 5) ─────────────────────
		// Sustituye los dos bloques separados (grupos de tipos + "Kits de
		// mecánicas") por una única lista de secciones desplegables, cada una
		// con sus tipos genéricos Y sus piezas de kit ya mezclados.
		const paletteSearch = ref('');
		// Subcategorías de la paleta comprimidas/plegadas por defecto
		const openSections = reactive({});
		// Task 7, ítem 5.1: badge "nuevo" para que quien ya conocía el editor
		// descubra la paleta unificada (Task 5); se recuerda en localStorage y
		// desaparece la primera vez que se interactúa con el buscador o con
		// Colapsar/Expandir todo.
		const showPaletteNewBadge = ref((() => {
			try { return localStorage.getItem('mw_dun_palette_seen_v1') !== '1'; } catch (_) { return false; }
		})());
		function dismissPaletteNewBadge() {
			if (!showPaletteNewBadge.value) return;
			showPaletteNewBadge.value = false;
			try { localStorage.setItem('mw_dun_palette_seen_v1', '1'); } catch (_) { /* almacenamiento no disponible */ }
		}
		const paletteSections = computed(() => {
			const q = paletteSearch.value.trim().toLowerCase();
			return THEME_SECTIONS.map((sec) => {
				let tiles = dunTiles.value.filter((t) => sec.tileGroups.includes(t.group));
				const kg = sec.kit ? kitGroups.value.find((g) => g.id === sec.kit) : null;
				let pieces = kg ? kg.items : [];
				if (q) {
					tiles = tiles.filter((t) => (t.label || '').toLowerCase().includes(q));
					pieces = pieces.filter((p) => ((p.name && p.name.es) || '').toLowerCase().includes(q));
				}
				return { ...sec, tiles, pieces, kitMeta: kg ? kg.meta : null };
			}).filter((sec) => !q || sec.tiles.length || sec.pieces.length);
		});
		function isSectionOpen(id) {
			if (paletteSearch.value.trim()) return true; // en búsqueda activa, todo desplegado
			return !!openSections[id];
		}
		// Task 7, ítem 5.2: resaltar la coincidencia de búsqueda dentro del
		// nombre del botón (antes solo filtraba, sin indicar POR QUÉ apareció
		// cada resultado). Escapa primero para no introducir HTML del propio
		// nombre del ítem.
		function _escapeHtml(s) {
			return String(s == null ? '' : s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
		}
		function highlightMatch(text, query) {
			const safe = _escapeHtml(text);
			const q = (query || '').trim();
			if (!q) return safe;
			const idx = safe.toLowerCase().indexOf(q.toLowerCase());
			if (idx === -1) return safe;
			return safe.slice(0, idx) + '<mark>' + safe.slice(idx, idx + q.length) + '</mark>' + safe.slice(idx + q.length);
		}
		function toggleSection(id) { openSections[id] = !openSections[id]; }
		function collapseAllSections() { for (const s of THEME_SECTIONS) openSections[s.id] = false; }
		function expandAllSections() { for (const s of THEME_SECTIONS) openSections[s.id] = true; }
		// ── PREFABS DE SALAS COMPLETAS ──────────────────────────────────
		const DUNGEON_PREFABS = [
			{
				id: 'entrance',
				name: '🏛️ Entrada de Cueva (3x3)',
				desc: 'Pasillo de entrada con paredes laterales, suelo y apertura al sur.',
				w: 3, h: 3,
				grid: [
					[{ t: 'wall' }, { t: 'wall' }, { t: 'wall' }],
					[{ t: 'wall' }, { t: 'floor' }, { t: 'wall' }],
					[{ t: 'floor' }, { t: 'floor' }, { t: 'floor' }]
				]
			},
			{
				id: 'crossroad',
				name: '➕ Cruce 4 Caminos (3x3)',
				desc: 'Cruce de 4 direcciones con 4 columnas en las esquinas.',
				w: 3, h: 3,
				grid: [
					[{ t: 'floor' }, { t: 'floor' }, { t: 'floor' }],
					[{ t: 'floor' }, { t: 'smart', kit: 'grab_column' }, { t: 'floor' }],
					[{ t: 'floor' }, { t: 'floor' }, { t: 'floor' }]
				]
			},
			{
				id: 'boss_room',
				name: '👑 Sala del Jefe (5x5)',
				desc: 'Gran sala rodeada de paredes con spawner de jefe central y antorchas.',
				w: 5, h: 5,
				grid: [
					[{ t: 'wall' }, { t: 'wall' }, { t: 'wall' }, { t: 'wall' }, { t: 'wall' }],
					[{ t: 'wall' }, { t: 'torch' }, { t: 'floor' }, { t: 'torch' }, { t: 'wall' }],
					[{ t: 'wall' }, { t: 'floor' }, { t: 'monster' }, { t: 'floor' }, { t: 'wall' }],
					[{ t: 'wall' }, { t: 'torch' }, { t: 'floor' }, { t: 'torch' }, { t: 'wall' }],
					[{ t: 'wall' }, { t: 'floor' }, { t: 'floor' }, { t: 'floor' }, { t: 'wall' }]
				]
			},
			{
				id: 'library',
				name: '📚 Biblioteca / Sala de Secretos (4x3)',
				desc: 'Sala revestida con pared falsa y cofre escondido.',
				w: 4, h: 3,
				grid: [
					[{ t: 'wall' }, { t: 'smart', kit: 'reveal_wall' }, { t: 'wall' }, { t: 'wall' }],
					[{ t: 'wall' }, { t: 'smart', kit: 'reveal_chest' }, { t: 'floor' }, { t: 'wall' }],
					[{ t: 'floor' }, { t: 'floor' }, { t: 'floor' }, { t: 'floor' }]
				]
			}
		];

		const selPrefabId = ref('entrance');

		function stampPrefab(prefabId, ox, oy) {
			const p = DUNGEON_PREFABS.find(x => x.id === prefabId);
			if (!p || !floor.value) return;
			pushHistory();
			for (let dy = 0; dy < p.h; dy++) {
				for (let dx = 0; dx < p.w; dx++) {
					const tx = ox + dx;
					const ty = oy + dy;
					if (ty < floor.value.h && tx < floor.value.w) {
						floor.value.cells[ty][tx] = JSON.parse(JSON.stringify(p.grid[dy][dx]));
					}
				}
			}
			markDungeonDirty(store.selectedDungeon);
		}

		const history = useHistory({ limit: 60 });
		let strokeTaken = false;

		// ── Selectores de dominio ───────────────────────────────────────────────
		const dungeonIds = computed(() => Object.keys(store.dungeons || {}));
		const dun = computed(() => (store.dungeons && store.selectedDungeon)
			? store.dungeons[store.selectedDungeon] : null);
		const floors = computed(() => (dun.value && Array.isArray(dun.value.floors)) ? dun.value.floors : []);
		const floor = computed(() => floors.value[floorIdx.value] || null);
		const selCell = computed(() => {
			if (!sel.value || !floor.value) return null;
			const row = floor.value.cells[sel.value.y];
			return row ? row[sel.value.x] : null;
		});
		// Catálogo de tipos de casilla, derivado de la colección data-driven
		// `store.dungeonTiles` (data/dungeon_tiles/<t>.json). Ordenado por `order`
		// para conservar el orden curado de la paleta (grupos y botones).
		const dunTiles = computed(() => Object.values(store.dungeonTiles || {}).sort((a, b) => (a.order ?? 0) - (b.order ?? 0)));
		const tileMap = computed(() => Object.fromEntries(dunTiles.value.map(t => [t.t, t])));
		const tileGroups = computed(() => [...new Set(dunTiles.value.map(t => t.group))]);

		const selMeta = computed(() => selCell.value ? tileMap.value[selCell.value.t] : null);
		const brushMeta = computed(() => tileMap.value[brush.value] || null);
		// Capacidades contextuales: qué propiedades de aspecto mostrar para el
		// pincel activo / la casilla seleccionada (ver tileCaps()).
		const brushCaps = computed(() => tileCaps(brushMeta.value));
		const selCaps = computed(() => tileCaps(selMeta.value));

		// Opciones para referencias de entidades.
		const enemyIds = computed(() => Object.keys(store.enemies || {}));
		const npcIds = computed(() => Object.keys(store.npcs || {}));
		const itemIds = computed(() => Object.keys(store.items || {}));
		const cinematicOptions = computed(() => Object.keys(store.cinematics || {}));

		// Miniatura del sprite de un enemigo (enemies.json `image`, mismo criterio
		// que EnemiesManager.js: `FS.assetUrl('enemy', <nombre de fichero>)`),
		// para reconocer de un vistazo qué enemigo hay puesto en una celda o como
		// jefe sin tener que ir a la pestaña de Enemigos a comprobarlo.
		function enemySpriteUrl(enemyId) {
			const img = store.enemies?.[enemyId]?.image || '';
			if (!img) return null;
			return FS.assetUrl('enemy', img.split('/').pop());
		}

		// ── Constructores ────────────────────────────────────────────────────────
		function blankFloor(w, h, name) {
			const cells = [];
			for (let y = 0; y < h; y++) {
				const row = [];
				for (let x = 0; x < w; x++) row.push({ t: 'void' });
				cells.push(row);
			}
			return { name: name || ('Planta ' + 0), w, h, cells };
		}

		// ── TEXTURAS DE MAZMORRA (assets/dungeon/textures) ─────────
		// Lista reactiva de texturas reales disponibles para material de suelo/pared,
		// con su URL servible para la miniatura. El diseñador puede además SUBIR una
		// nueva (PNG) que queda disponible al instante para todas las casillas.
		const dungeonTextures = ref([]);
		async function loadDungeonTextures() {
			try {
				const names = await FS.listAssets('dungeon_tex');
				dungeonTextures.value = names.map(n => ({ name: n, url: FS.assetUrl('dungeon_tex', n) }));
			} catch (_) { dungeonTextures.value = []; }
		}
		// URL real de la textura por defecto (tex_cave_wall.png): la que aplica el
		// motor a CUALQUIER pared/suelo/techo sin `wall`/`tex` propios. Se muestra
		// como miniatura del chip "por defecto" para que el diseñador sepa qué es
		// lo que REALMENTE va a ver (antes ese chip era un rayado neutro sin
		// relación con el aspecto real — bug reportado: "ni parecido").
		const defaultTextureUrl = computed(() => {
			const f = dungeonTextures.value.find(t => t.name === DEFAULT_SURFACE_TEX);
			return f ? f.url : '';
		});
		async function importDungeonTexture(file) {
			if (!file) return '';
			if (!/\.png$/i.test(file.name)) { flash('La textura debe ser un .png.'); return ''; }
			const base = slugify(file.name.replace(/\.png$/i, ''));
			const fileName = base + '.png';
			try {
				const buf = await file.arrayBuffer();
				await FS.uploadAsset('dungeon_tex', fileName, buf, 'image/png');
				await loadDungeonTextures();
				flash('Textura añadida: ' + fileName);
				return fileName;
			} catch (e) {
				flash('Error al subir la textura: ' + (e.message || String(e)));
				return '';
			}
		}

		function templateRoomsDungeon(id) {
			const w = 18, h = 12;
			const cells = [];
			for (let y = 0; y < h; y++) {
				const row = [];
				for (let x = 0; x < w; x++) row.push({ t: 'wall' });
				cells.push(row);
			}
			for (let y = 4; y <= 8; y++) {
				for (let x = 1; x <= 5; x++) cells[y][x] = { t: 'floor' };
			}
			cells[6][2] = { t: 'torch', torch_face: 'norte' };
			cells[4][3] = { t: 'torch', torch_face: 'norte' };
			for (let y = 5; y <= 7; y++) {
				for (let x = 6; x <= 11; x++) cells[y][x] = { t: 'floor' };
			}
			cells[5][8] = { t: 'lever', eid: 'palanca_sala', targets: [{ eid: 'puerta_jefe', action: 'open' }] };
			cells[6][11] = { t: 'door', state: 'closed', eid: 'puerta_jefe' };
			for (let y = 3; y <= 9; y++) {
				for (let x = 12; x <= 16; x++) cells[y][x] = { t: 'floor' };
			}
			cells[4][13] = { t: 'torch', torch_face: 'norte' };
			cells[8][13] = { t: 'torch', torch_face: 'sur' };
			cells[6][14] = { t: 'monster', ref: 'test_dummy_boss', level: 15 };
			cells[6][16] = { t: 'chest', chest_id: id + '_chest' };

			return {
				id,
				name: { es: 'Mazmorra con Salas', en: 'Room Dungeon' },
				music: 'dungeon',
				boss: 'test_dummy_boss',
				random_pool: ['test_dummy_weak'],
				cell_size: 3,
				wall_height: 3,
				spawn: { f: 0, x: 2, y: 6 },
				floors: [{ name: 'Planta Principal', w, h, cells }],
			};
		}

		function templateChasmDungeon(id) {
			const w = 19, h = 13;
			const cells = [];
			for (let y = 0; y < h; y++) {
				const row = [];
				for (let x = 0; x < w; x++) row.push({ t: 'wall' });
				cells.push(row);
			}
			for (let y = 4; y <= 8; y++) {
				for (let x = 1; x <= 5; x++) cells[y][x] = { t: 'floor' };
			}
			cells[4][3] = { t: 'torch', torch_face: 'norte' };
			for (let y = 1; y <= 11; y++) {
				for (let x = 6; x <= 12; x++) cells[y][x] = { t: 'void' };
			}
			cells[6][5] = { t: 'floor' };
			cells[6][7] = { t: 'smart', kit: 'grab_column' };
			cells[6][9] = { t: 'smart', kit: 'grab_ring' };
			cells[6][11] = { t: 'smart', kit: 'grab_column' };
			cells[6][13] = { t: 'floor' };
			for (let y = 3; y <= 9; y++) {
				for (let x = 13; x <= 17; x++) cells[y][x] = { t: 'floor' };
			}
			cells[6][15] = { t: 'monster', ref: 'test_dummy_boss', level: 20 };
			cells[6][17] = { t: 'chest', chest_id: id + '_chest' };

			return {
				id,
				name: { es: 'Mazmorra del Abismo', en: 'Chasm Dungeon' },
				music: 'dungeon',
				boss: 'test_dummy_boss',
				random_pool: ['test_dummy_weak'],
				cell_size: 3,
				wall_height: 3.2,
				spawn: { f: 0, x: 2, y: 6 },
				floors: [{ name: 'Nivel del Abismo', w, h, cells }],
			};
		}

		function templateStandardDungeon(id) {
			const w = 15, h = 21;
			const cells = [];
			for (let y = 0; y < h; y++) {
				const row = [];
				for (let x = 0; x < w; x++) {
					if (x === 0 || x === w - 1 || y === 0 || y === h - 1) row.push({ t: 'wall' });
					else row.push({ t: 'floor' });
				}
				cells.push(row);
			}
			cells[19][7] = { t: 'teleport' };
			cells[3][7] = { t: 'monster', boss: true, ref: 'test_dummy_boss', level: 15 };
			cells[2][7] = { t: 'teleport' };

			return {
				id,
				name: { es: 'Nueva Mazmorra Estándar', en: 'New Standard Dungeon' },
				theme: 'cave',
				music: 'dungeon',
				boss: 'test_dummy_boss',
				boss_level: 15,
				random_pool: ['test_dummy_weak'],
				cell_size: 4,
				wall_height: 4,
				ceiling: true,
				fog: true,
				ambient_energy: 0.4,
				ambient_color: '#2c2522',
				fill_light: 0.25,
				spawn: { f: 0, x: 7, y: 18 },
				portals: {
					west: { spawn: { f: 0, x: 7, y: 18 } },
					east: { spawn: { f: 0, x: 7, y: 2 } }
				},
				floors: [{ name: 'Planta Principal', w, h, cells }],
			};
		}

		function blankDungeon(id) {
			return templateStandardDungeon(id);
		}

		// ── Historial (fotografía la mazmorra activa completa) ────────────────────
		function snapshot() {
			if (!dun.value) return;
			history.push(deepClone(dun.value));
		}
		function applyDun(state) {
			if (!state || !store.selectedDungeon) return;
			store.dungeons[store.selectedDungeon] = state;
			markDungeonDirty(store.selectedDungeon);
			clampFloor();
			sel.value = null;
			renderPreview();
		}
		function doUndo() { const p = history.undo(deepClone(dun.value)); if (p) applyDun(p); }
		function doRedo() { const n = history.redo(deepClone(dun.value)); if (n) applyDun(n); }

		function clampFloor() {
			if (floorIdx.value >= floors.value.length) floorIdx.value = Math.max(0, floors.value.length - 1);
		}

		// ── Gestión de mazmorras ──────────────────────────────────────────────────
		function slugify(s) {
			return String(s || '').toLowerCase().trim()
				.replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '') || 'dun';
		}
		function uniqueId(base) {
			let id = base, n = 2;
			while (store.dungeons[id]) id = base + '_' + (n++);
			return id;
		}

		function openCreateModal() {
			newDunName.value = '';
			newDunId.value = '';
			newDunIdTouched.value = false;
			newDunPreset.value = 'standard';
			showCreateDunModal.value = true;
		}

		function onNewDunNameInput() {
			if (!newDunIdTouched.value) {
				const s = slugify(newDunName.value);
				newDunId.value = s ? ('dun_' + s) : '';
			}
		}

		function templateBlankDungeon(id) {
			const w = 15, h = 15;
			const cells = [];
			for (let y = 0; y < h; y++) {
				const row = [];
				for (let x = 0; x < w; x++) {
					if (x === 0 || x === w - 1 || y === 0 || y === h - 1) row.push({ t: 'wall' });
					else row.push({ t: 'floor' });
				}
				cells.push(row);
			}
			const spawnX = Math.floor(w / 2);
			const spawnY = h - 2;
			cells[spawnY][spawnX] = { t: 'teleport' };
			return {
				id,
				name: { es: 'Nueva Mazmorra', en: 'New Dungeon' },
				theme: 'cave',
				music: 'dungeon',
				boss: '',
				boss_level: 1,
				random_pool: [],
				cell_size: 4,
				wall_height: 4,
				ceiling: true,
				fog: true,
				ambient_energy: 0.4,
				ambient_color: '#2c2522',
				fill_light: 0.25,
				spawn: { f: 0, x: spawnX, y: spawnY },
				portals: {},
				floors: [{ name: 'Planta Principal', w, h, cells }],
			};
		}

		function submitCreateDungeon() {
			if (newDunPreset.value === 'wizard') {
				showCreateDunModal.value = false;
				dungeonWizardOpen.value = true;
				return;
			}
			const rawName = (newDunName.value || '').trim();
			const rawId = (newDunId.value || '').trim();
			let baseId = rawId;
			if (!baseId && rawName) baseId = 'dun_' + slugify(rawName);
			if (!baseId) baseId = 'dun_' + (newDunPreset.value || 'new');
			const id = uniqueId(slugify(baseId));

			let dunData;
			if (newDunPreset.value === 'rooms') dunData = templateRoomsDungeon(id);
			else if (newDunPreset.value === 'chasm') dunData = templateChasmDungeon(id);
			else if (newDunPreset.value === 'blank') dunData = templateBlankDungeon(id);
			else dunData = templateStandardDungeon(id);

			if (rawName) {
				dunData.name = { es: rawName, en: dunData.name?.en || '' };
			}
			store.dungeons[id] = dunData;
			markDungeonDirty(id);
			store.selectedDungeon = id;
			floorIdx.value = 0; sel.value = null; history.clear();
			showCreateDunModal.value = false;
			newDunId.value = '';
			newDunName.value = '';
			maybeSyncIds(id);
			flash('Mazmorra creada' + (newDunPreset.value !== 'standard' ? ' (' + newDunPreset.value + ')' : '') + ': ' + id);
			nextTick(renderPreview);
		}

		function createDungeon() {
			createDungeonWithTemplate('standard');
		}

		function createDungeonWithTemplate(preset) {
			const raw = (newDunId.value || '').trim();
			const id = uniqueId(slugify(raw || ('dun_' + (preset || 'new'))));
			let dunData;
			if (preset === 'rooms') dunData = templateRoomsDungeon(id);
			else if (preset === 'chasm') dunData = templateChasmDungeon(id);
			else if (preset === 'blank') dunData = templateBlankDungeon(id);
			else dunData = templateStandardDungeon(id);
			store.dungeons[id] = dunData;
			markDungeonDirty(id);
			store.selectedDungeon = id;
			floorIdx.value = 0; sel.value = null; history.clear();
			newDunId.value = '';
			maybeSyncIds(id);
			flash('Mazmorra creada' + (preset !== 'blank' ? ' (plantilla: ' + preset + ')' : '') + ': ' + id);
			nextTick(renderPreview);
		}

		function duplicateDungeon() {
			if (!dun.value) return;
			const id = uniqueId(store.selectedDungeon + '_copy');
			const copy = deepClone(dun.value);
			copy.id = id;
			store.dungeons[id] = copy;
			markDungeonDirty(id);
			store.selectedDungeon = id;
			floorIdx.value = 0; sel.value = null; history.clear();
			maybeSyncIds(id);
			flash('Mazmorra duplicada: ' + id);
			nextTick(renderPreview);
		}

		// El borrado es INMEDIATO (llama al DELETE ya, no espera a "Guardar"): cada
		// mazmorra es su propio fichero (data/dungeons/<id>.json), así que no hay
		// forma de "deshacer" un borrado sin guardar como con los documentos únicos.
		function deleteDungeon() {
			if (!dun.value) return;
			const id = store.selectedDungeon;
			askConfirm('¿Eliminar la mazmorra "' + id + '" (data/dungeons/' + id + '.json)?\n(No borra su entrada en ids.json ni del mapa. No se puede deshacer.)', async () => {
				try {
					await FS.deleteCollectionItem('dungeons', id);
				} catch (e) {
					flash('Error al borrar: ' + (e.message || String(e)));
					return;
				}
				delete store.dungeons[id];
				delete store.dirtyDungeons[id];
				store.selectedDungeon = Object.keys(store.dungeons)[0] || null;
				floorIdx.value = 0; sel.value = null; history.clear();
				flash('Mazmorra eliminada: ' + id);
				nextTick(renderPreview);
			});
		}

		// Crea/actualiza la entrada de ids.json (type dungeon) para que la mazmorra
		// pueda colocarse en el mapa del mundo. No pisa una entrada existente salvo
		// para asegurar el tipo.
		function maybeSyncIds(id) {
			if (!store.ids) return;
			if (!store.ids[id]) {
				store.ids[id] = {
					id,
					type: 'dungeon',
					name: deepClone(dun.value?.name || { es: id, en: id }),
					icon: '🕳️',
					desc: { es: '', en: '' },
				};
				markDirty('ids', id);
			}
		}
		const inIds = computed(() => !!(store.ids && store.selectedDungeon && store.ids[store.selectedDungeon]));
		function syncToIds() {
			if (!dun.value) return;
			const id = store.selectedDungeon;
			const e = store.ids[id] || { id, type: 'dungeon', icon: '🕳️', desc: { es: '', en: '' } };
			e.type = 'dungeon';
			e.name = deepClone(dun.value.name || { es: id, en: id });
			store.ids[id] = e;
			markDirty('ids', id);
			flash('Sincronizado con ids.json (colócala en el mapa).');
		}

		// Casillas del mundo que referencian esta mazmorra (para "integración con
		// el mapa del mundo"). Busca el object==event_id en world.tiles.
		const worldPlacements = computed(() => {
			const out = [];
			const id = store.selectedDungeon;
			const w = store.world;
			if (!id || !w || !Array.isArray(w.tiles)) return out;
			for (let y = 0; y < w.tiles.length; y++) {
				const row = w.tiles[y];
				if (!Array.isArray(row)) continue;
				for (let x = 0; x < row.length; x++) {
					if (row[x] && row[x].object === id) out.push({ x, y });
				}
			}
			return out;
		});
		// Salto directo al mapa, simétrico al botón "Editar
		// mazmorra →" del mapa: si ya está colocada, selecciona su casilla; si no,
		// deja el pincel de Entidades listo con esta mazmorra para clicar y
		// colocarla en un solo paso (sin ir a buscarla a mano en la paleta).
		function goToMap() {
			const id = store.selectedDungeon;
			if (!id) return;
			const placements = worldPlacements.value;
			if (placements.length) {
				store.selectedCell = { x: placements[0].x, y: placements[0].y };
			} else {
				store.brush.tool = 'entity';
				store.brush.entityCat = 'all';
				store.brush.entity = id;
				flash('Haz clic en una casilla del mapa para colocar "' + id + '".');
			}
			store.activeTab = 'map';
		}

		// ── Metadatos de la mazmorra ──────────────────────────────────────────────
		function setMeta(key, value) {
			if (!dun.value) return;
			snapshot();
			dun.value[key] = value;
			markDungeonDirty(store.selectedDungeon);
		}
		function setName(lang, value) {
			if (!dun.value) return;
			snapshot();
			if (!dun.value.name) dun.value.name = {};
			dun.value.name[lang] = value;
			markDungeonDirty(store.selectedDungeon);
		}
		function setPool(text) {
			if (!dun.value) return;
			snapshot();
			dun.value.random_pool = text.split(',').map(s => s.trim()).filter(Boolean);
			markDungeonDirty(store.selectedDungeon);
		}

		// ── TASK 3 — Atmósfera y Temática 3D ────────────────────────────────────
		const atmoOpen = ref(true);
		function toggleAtmo() { atmoOpen.value = !atmoOpen.value; }
		// URL real (servida por el editor) para el botón de preescucha de música,
		// a partir del espejo MUSIC_FILE_MAP. Si el id no está mapeado (p. ej. una
		// pista custom añadida solo en ambience.json), el botón queda deshabilitado.
		function musicPreviewUrl(trackId) {
			const file = MUSIC_FILE_MAP[String(trackId || '').trim()];
			return file ? ('/assets/common/music/' + file) : '';
		}
		function setFogEnabled(checked) { setMeta('fog', !!checked); }

		// ── Gestión de plantas ────────────────────────────────────────────────────
		function addFloor() {
			if (!dun.value) return;
			snapshot();
			const ref0 = floor.value || { w: 8, h: 8 };
			dun.value.floors.push(blankFloor(ref0.w, ref0.h, 'Planta ' + dun.value.floors.length));
			markDungeonDirty(store.selectedDungeon);
			floorIdx.value = dun.value.floors.length - 1;
			sel.value = null;
			nextTick(renderPreview);
		}
		function removeFloor(i) {
			if (!dun.value || dun.value.floors.length <= 1) { flash('La mazmorra necesita al menos una planta.'); return; }
			askConfirm('¿Eliminar "' + dun.value.floors[i].name + '"?', () => {
				snapshot();
				dun.value.floors.splice(i, 1);
				markDungeonDirty(store.selectedDungeon);
				clampFloor();
				sel.value = null;
				nextTick(renderPreview);
			});
		}
		function renameFloor(i, name) {
			snapshot();
			dun.value.floors[i].name = name;
			markDungeonDirty(store.selectedDungeon);
		}
		function selectFloor(i) { floorIdx.value = i; sel.value = null; nextTick(renderPreview); }

		// ── Secciones colapsables del panel lateral izquierdo ───────────────
		// Por defecto solo Datos Principales y Paleta de Elementos desplegados
		const dunSections = reactive({
			general: true,
			palette: true,
			floors: false,
			atmo: false,
			portals: false,
			prefabs: false,
			issues: false,
		});
		function toggleDunSec(secId) {
			dunSections[secId] = !dunSections[secId];
		}
		function collapseAllDunSections() {
			for (const k in dunSections) dunSections[k] = false;
		}
		function expandAllDunSections() {
			for (const k in dunSections) dunSections[k] = true;
		}

		function onSelectTemplate(tmpl) {
			if (!tmpl) return;
			if (tmpl === 'standard') {
				createDungeon();
			} else {
				createDungeonWithTemplate(tmpl);
			}
		}

		// ── Redimensionado de mazmorra desde cualquier borde (con preview) ────
		const showResize = ref(false);
		const resize = reactive({ top: 0, right: 0, bottom: 0, left: 0 });
		const resizeAllFloors = ref(true);
		const resizeFillTile = ref('void');
		const currentW = computed(() => floor.value ? floor.value.w : 0);
		const currentH = computed(() => floor.value ? floor.value.h : 0);
		const newW = computed(() => currentW.value + resize.left + resize.right);
		const newH = computed(() => currentH.value + resize.top + resize.bottom);
		const resizeValid = computed(() => newW.value >= 1 && newH.value >= 1 && newW.value <= 64 && newH.value <= 64);
		const resizeDirty = computed(() => resize.top !== 0 || resize.right !== 0 || resize.bottom !== 0 || resize.left !== 0);
		const coordShift = computed(() => resize.top > 0 || resize.left > 0);

		function bump(side, d) { resize[side] += d; }
		function resetResize() { resize.top = resize.right = resize.bottom = resize.left = 0; }

		function keptBounds(w, h) {
			return {
				x0: resize.left < 0 ? -resize.left : 0,
				x1: resize.right < 0 ? w - 1 + resize.right : w - 1,
				y0: resize.top < 0 ? -resize.top : 0,
				y1: resize.bottom < 0 ? h - 1 + resize.bottom : h - 1,
			};
		}

		const removedNonEmpty = computed(() => {
			if (!resizeDirty.value || !dun.value) return 0;
			const targetFloors = resizeAllFloors.value ? (dun.value.floors || []) : (floor.value ? [floor.value] : []);
			let c = 0;
			for (const f of targetFloors) {
				const { x0, x1, y0, y1 } = keptBounds(f.w, f.h);
				for (let y = 0; y < f.h; y++) {
					for (let x = 0; x < f.w; x++) {
						if (x < x0 || x > x1 || y < y0 || y > y1) {
							const cell = f.cells?.[y]?.[x];
							if (cell && cell.t && cell.t !== 'void') c++;
						}
					}
				}
			}
			return c;
		});

		const preview = computed(() => {
			const nw = newW.value, nh = newH.value;
			if (nw < 1 || nh < 1) return null;
			const MAX = 168, s = Math.max(2, Math.min(MAX / nw, MAX / nh, 9));
			const kb = keptBounds(currentW.value, currentH.value);
			return {
				s, boxW: nw * s, boxH: nh * s,
				retX: (kb.x0 + resize.left) * s, retY: (kb.y0 + resize.top) * s,
				retW: (kb.x1 - kb.x0 + 1) * s, retH: (kb.y1 - kb.y0 + 1) * s,
			};
		});

		function applyResize() {
			if (!resizeValid.value || !resizeDirty.value || !dun.value) return;
			if (removedNonEmpty.value > 0 &&
				!confirm('Se recortarán ' + removedNonEmpty.value + ' casilla(s) con contenido (no vacías). ¿Continuar?')) return;
			snapshot();
			const nw = newW.value, nh = newH.value;
			const targetFloors = resizeAllFloors.value ? (dun.value.floors || []) : (floor.value ? [floor.value] : []);
			const fillT = resizeFillTile.value || 'void';

			for (const f of targetFloors) {
				const oldCells = f.cells || [];
				const oldW = f.w || 0, oldH = f.h || 0;
				const newCells = [];
				for (let ny = 0; ny < nh; ny++) {
					const row = [];
					const oy = ny - resize.top;
					for (let nx = 0; nx < nw; nx++) {
						const ox = nx - resize.left;
						if (oy >= 0 && oy < oldH && ox >= 0 && ox < oldW && oldCells[oy] && oldCells[oy][ox]) {
							row.push(deepClone(oldCells[oy][ox]));
						} else {
							row.push({ t: fillT });
						}
					}
					newCells.push(row);
				}
				f.w = nw;
				f.h = nh;
				f.cells = newCells;
			}

			// Desplazar spawn principal
			if (dun.value.spawn) {
				const shouldShiftSpawn = resizeAllFloors.value || (dun.value.spawn.f === floorIdx.value);
				if (shouldShiftSpawn) {
					dun.value.spawn.x = Math.max(0, Math.min(nw - 1, (dun.value.spawn.x || 0) + resize.left));
					dun.value.spawn.y = Math.max(0, Math.min(nh - 1, (dun.value.spawn.y || 0) + resize.top));
				}
			}

			// Desplazar entradas nombradas (portales)
			if (dun.value.portals) {
				for (const pName in dun.value.portals) {
					const p = dun.value.portals[pName];
					if (p && p.spawn) {
						const shouldShiftPortal = resizeAllFloors.value || (p.spawn.f === floorIdx.value);
						if (shouldShiftPortal) {
							p.spawn.x = Math.max(0, Math.min(nw - 1, (p.spawn.x || 0) + resize.left));
							p.spawn.y = Math.max(0, Math.min(nh - 1, (p.spawn.y || 0) + resize.top));
						}
					}
				}
			}

			markDungeonDirty(store.selectedDungeon);
			if (sel.value && (sel.value.x >= nw || sel.value.y >= nh)) sel.value = null;
			resetResize();
			showResize.value = false;
			nextTick(renderPreview);
			flash('Mazmorra redimensionada a ' + nw + '×' + nh + '.');
		}

		// Redimensiona la planta activa rápido desde el input simple
		function resizeFloor(nw, nh) {
			if (!floor.value) return;
			nw = Math.max(1, Math.min(64, nw | 0));
			nh = Math.max(1, Math.min(64, nh | 0));
			const f = floor.value;
			if (nw === f.w && nh === f.h) return;
			snapshot();
			const cells = [];
			for (let y = 0; y < nh; y++) {
				const row = [];
				for (let x = 0; x < nw; x++) {
					const old = (f.cells[y] && f.cells[y][x]) ? f.cells[y][x] : { t: 'void' };
					row.push(deepClone(old));
				}
				cells.push(row);
			}
			f.w = nw; f.h = nh; f.cells = cells;
			markDungeonDirty(store.selectedDungeon);
			if (sel.value && (sel.value.x >= nw || sel.value.y >= nh)) sel.value = null;
			nextTick(renderPreview);
		}

		// ── PRESETS DE SALA (plantillas rápidas sobre la planta activa) ────────────
		// Arranque instantáneo para quien no sabe por dónde empezar: reescriben la
		// planta activa con una estructura común. Snapshot para deshacer.
		const ROOM_PRESETS = [
			{ id: 'standard', icon: '🏰', label: 'Plantilla Canónica', hint: '15x21: Spawn, Teleport retorno, Boss y Teleport salida' },
			{ id: 'walled', icon: '🏛️', label: 'Sala amurallada', hint: 'Suelo con borde de pared' },
			{ id: 'open', icon: '⬜', label: 'Sala abierta', hint: 'Todo suelo' },
			{ id: 'corridor', icon: '║', label: 'Pasillo', hint: 'Pasillo central con paredes' },
			{ id: 'guardian', icon: '⚔️', label: 'Sala con guardián', hint: 'Sala + monstruo y cofre' },
			{ id: 'clear', icon: '🗑️', label: 'Vaciar', hint: 'Todo vacío (void)' },
		];
		function applyRoomPreset(id) {
			const f = floor.value;
			if (!f) return;
			const preset = ROOM_PRESETS.find(p => p.id === id);
			askConfirm('¿Aplicar la plantilla "' + (preset ? preset.label : id) + '" a la planta activa?\nSe reemplaza todo su contenido (puedes deshacer con Ctrl+Z).', () => {
				snapshot();
				if (id === 'standard') {
					f.w = 15; f.h = 21;
					const cells = [];
					for (let y = 0; y < 21; y++) {
						const row = [];
						for (let x = 0; x < 15; x++) {
							if (x === 0 || x === 14 || y === 0 || y === 20) row.push({ t: 'wall' });
							else row.push({ t: 'floor' });
						}
						cells.push(row);
					}
					cells[19][7] = { t: 'teleport' };
					cells[3][7] = { t: 'monster', boss: true, ref: (dun.value && dun.value.boss) || 'test_dummy_boss', level: (dun.value && dun.value.boss_level) || 15 };
					cells[2][7] = { t: 'teleport' };
					f.cells = cells;
					if (dun.value) {
						dun.value.spawn = { f: floorIdx.value, x: 7, y: 18 };
						dun.value.portals = {
							west: { spawn: { f: floorIdx.value, x: 7, y: 18 } },
							east: { spawn: { f: floorIdx.value, x: 7, y: 2 } }
						};
					}
					markDungeonDirty(store.selectedDungeon);
					sel.value = null;
					nextTick(renderPreview);
					flash('Plantilla canónica aplicada (15x21 con spawn, teleports y boss).');
					return;
				}

				const W = f.w, H = f.h;
				const border = (x, y) => x === 0 || y === 0 || x === W - 1 || y === H - 1;
				const cells = [];
				for (let y = 0; y < H; y++) {
					const row = [];
					for (let x = 0; x < W; x++) {
						let t = 'floor';
						if (id === 'clear') t = 'void';
						else if (id === 'open') t = 'floor';
						else if (id === 'walled' || id === 'guardian') t = border(x, y) ? 'wall' : 'floor';
						else if (id === 'corridor') {
							// Pasillo vertical de 2 de ancho centrado; el resto, pared.
							const cx = Math.floor(W / 2);
							t = (x >= cx - 1 && x <= cx) ? 'floor' : 'wall';
						}
						row.push({ t });
					}
					cells.push(row);
				}
				// Sala con guardián: coloca monstruo (jefe) y cofre en extremos interiores.
				if (id === 'guardian' && W >= 4 && H >= 4) {
					cells[1][1] = { t: 'monster', boss: true };
					cells[H - 2][W - 2] = { t: 'chest', gold: 100 };
				}
				f.cells = cells;
				// Reubica el spawn de esa planta a una casilla transitable si procede.
				if (dun.value && dun.value.spawn && dun.value.spawn.f === floorIdx.value) {
					const sx = Math.min(Math.max(1, dun.value.spawn.x | 0), W - 2);
					const sy = Math.min(Math.max(1, dun.value.spawn.y | 0), H - 2);
					if (cells[sy] && cells[sy][sx] && cells[sy][sx].t !== 'void' && cells[sy][sx].t !== 'wall') {
						dun.value.spawn.x = sx; dun.value.spawn.y = sy;
					}
				}
				markDungeonDirty(store.selectedDungeon);
				sel.value = null;
				nextTick(renderPreview);
				flash('Plantilla aplicada: ' + (preset ? preset.label : id) + '.');
			});
		}

		// ── Pintar / seleccionar casillas ─────────────────────────────────────────
		function beginStroke(x, y, ev) {
			if (!floor.value) return;
			const isErase = ev && (ev.button === 2 || ev.ctrlKey);
			// Atajos de teclado: Shift = inspeccionar, Alt = cuentagotas (además de
			// los modos de herramienta 'select'/'eyedropper' de la barra).
			const wantSelect = drawMode.value === 'select' || (ev && ev.shiftKey);
			const wantPick = drawMode.value === 'eyedropper' || (ev && ev.altKey);

			if (wantPick && !isErase) {
				pickCell(x, y);
				painting.value = false;
				return;
			}
			if (wantSelect) {
				selectCell(x, y);
				painting.value = false;
				return;
			}

			// Modo 'move': recoge la casilla elegida para moverla a otra posición.
			if (drawMode.value === 'move') {
				const c = floor.value.cells[y] && floor.value.cells[y][x];
				if (!c || c.t === 'void') {
					flash('Haz clic en una casilla con un elemento para moverlo.');
					painting.value = false;
					return;
				}
				snapshot();
				const cellData = deepClone(c);
				clipboard.value = { w: 1, h: 1, cells: [[cellData]], isMove: true, moveFrom: { f: floorIdx.value, x, y } };
				floor.value.cells[y][x] = { t: 'void' };
				markDungeonDirty(store.selectedDungeon);
				sel.value = null;
				drawMode.value = 'paste';
				schedulePreview();
				flash(`Moviendo ${cellData.t} de (${x},${y}). Haz clic en la casilla de destino para colocarlo.`);
				painting.value = false;
				return;
			}

			// Modo 'paste': un solo clic coloca el recorte copiado,
			// anclado por su esquina superior izquierda en la casilla pulsada.
			if (drawMode.value === 'paste') {
				pasteAt(x, y);
				painting.value = false;
				return;
			}

			painting.value = true;
			strokeTaken = false;
			eraseMode.value = isErase;

			if (drawMode.value === 'rect' || drawMode.value === 'region') {
				rectStart.value = { x, y, isErase };
				rectEnd.value = { x, y };
			} else if (drawMode.value === 'fill') {
				applyDungeonFloodFill(x, y, isErase);
				painting.value = false;
			} else {
				if (isErase) {
					paintCell(x, y, 'void');
				} else {
					paintCell(x, y, brush.value);
				}
			}
		}
		function overCell(x, y) {
			// Fantasma de pegado: se actualiza con solo pasar el ratón por encima,
			// sin necesidad de mantener pulsado (pegar es de un solo clic).
			if (drawMode.value === 'paste') pasteHover.value = { x, y };
			if (!painting.value) return;
			if (drawMode.value === 'rect' || drawMode.value === 'region') {
				rectEnd.value = { x, y };
			} else if (drawMode.value === 'pencil') {
				if (eraseMode.value) {
					paintCell(x, y, 'void');
				} else {
					paintCell(x, y, brush.value);
				}
			}
		}
		function endStroke() {
			if (painting.value && drawMode.value === 'rect' && rectStart.value && rectEnd.value) {
				applyDungeonRectangle();
			} else if (painting.value && drawMode.value === 'region' && rectStart.value && rectEnd.value) {
				// Solo MARCA el rectángulo (no pinta nada): queda listo para "📋 Copiar".
				regionSel.value = {
					x0: Math.min(rectStart.value.x, rectEnd.value.x),
					y0: Math.min(rectStart.value.y, rectEnd.value.y),
					x1: Math.max(rectStart.value.x, rectEnd.value.x),
					y1: Math.max(rectStart.value.y, rectEnd.value.y),
				};
			}
			painting.value = false;
			rectStart.value = null;
			rectEnd.value = null;
			eraseMode.value = false;
		}

		// ── Mover casilla / enemigo seleccionada ──────────────────────────────────
		function moveSelectedCell() {
			if (!sel.value || !floor.value) {
				flash('Selecciona primero la casilla que quieres mover.');
				return;
			}
			const { x, y } = sel.value;
			const c = floor.value.cells[y] && floor.value.cells[y][x];
			if (!c || c.t === 'void') {
				flash('La casilla seleccionada está vacía.');
				return;
			}
			snapshot();
			const cellData = deepClone(c);
			clipboard.value = { w: 1, h: 1, cells: [[cellData]], isMove: true, moveFrom: { f: floorIdx.value, x, y } };
			floor.value.cells[y][x] = { t: 'void' };
			markDungeonDirty(store.selectedDungeon);
			sel.value = null;
			drawMode.value = 'paste';
			schedulePreview();
			flash(`Moviendo ${cellData.t} de (${x},${y}). Haz clic en la nueva posición para colocarlo.`);
		}

		// ── Copiar/pegar regiones ────────────────────────────────
		function copyRegion() {
			const f = floor.value;
			if (!f || !regionSel.value) return;
			const { x0, y0, x1, y1 } = regionSel.value;
			const w = x1 - x0 + 1, h = y1 - y0 + 1;
			const cells = [];
			for (let y = y0; y <= y1; y++) {
				const row = [];
				for (let x = x0; x <= x1; x++) {
					row.push(deepClone((f.cells[y] && f.cells[y][x]) || { t: 'void' }));
				}
				cells.push(row);
			}
			clipboard.value = { w, h, cells };
			flash('Copiadas ' + w + '×' + h + ' casillas. Cambia a "📌 Pegar" y haz clic para colocarlas.');
		}
		// Rotación/espejado del RECORTE ya copiado (Pilar 4.1: "rotación y espejado
		// de salas"), antes de pegarlo. Transforma solo la GEOMETRÍA de la rejilla;
		// campos direccionales de una celda concreta (p.ej. orientación de un muro,
		// destino relativo de un teletransporte) no se reorientan automáticamente:
		// revísalos tras pegar si la pieza los usa.
		function rotateClipboardCW() {
			const c = clipboard.value; if (!c) return;
			const { w, h, cells } = c;
			const out = [];
			for (let r = 0; r < w; r++) {
				const row = [];
				for (let col = 0; col < h; col++) row.push(deepClone(cells[h - 1 - col][r]));
				out.push(row);
			}
			clipboard.value = { ...c, w: h, h: w, cells: out };
			flash('Recorte rotado 90°.');
		}
		function mirrorClipboardH() {
			const c = clipboard.value; if (!c) return;
			clipboard.value = { ...c, cells: c.cells.map(row => row.slice().reverse().map(deepClone)) };
			flash('Recorte reflejado horizontalmente.');
		}
		function clearRegionSel() {
			regionSel.value = null;
			rectStart.value = null;
			rectEnd.value = null;
		}
		// Pega el recorte anclado por su esquina superior izquierda en (x,y). Recorta
		// silenciosamente lo que se salga de la planta (no hace falta que quepa entero).
		function pasteAt(x, y) {
			const f = floor.value;
			if (!f || !clipboard.value) return;
			snapshot();
			let modified = false;
			const wasMove = clipboard.value.isMove;
			for (let dy = 0; dy < clipboard.value.h; dy++) {
				const ty = y + dy;
				if (ty < 0 || ty >= f.h || !f.cells[ty]) continue;
				for (let dx = 0; dx < clipboard.value.w; dx++) {
					const tx = x + dx;
					if (tx < 0 || tx >= f.w) continue;
					f.cells[ty][tx] = deepClone(clipboard.value.cells[dy][dx]);
					modified = true;
				}
			}
			if (modified) {
				markDungeonDirty(store.selectedDungeon);
				selectCell(x, y);
				schedulePreview();
				if (wasMove) {
					clipboard.value = null;
					drawMode.value = 'select';
					flash(`Elemento movido correctamente a (${x},${y}).`);
				} else {
					flash('Región pegada.');
				}
			}
		}

		function applyDungeonFloodFill(startX, startY, isErase) {
			const f = floor.value;
			if (!f) return;
			const cells = f.cells;
			const h = f.h;
			const w = f.w;
			if (startX < 0 || startX >= w || startY < 0 || startY >= h) return;

			const startCell = cells[startY]?.[startX];
			if (!startCell) return;
			const startType = startCell.t;

			let targetType = 'void';
			if (!isErase) {
				targetType = activeAsset.value ? activeAsset.value.cell.t : brush.value;
			}
			if (startType === targetType && !activeAsset.value) return;

			snapshot();
			let modified = false;

			const queue = [[startX, startY]];
			const visited = new Set();
			visited.add(`${startX},${startY}`);

			while (queue.length > 0) {
				const [cx, cy] = queue.shift();
				const currentCell = cells[cy]?.[cx];
				if (currentCell && currentCell.t === startType) {
					if (isErase) {
						cells[cy][cx] = { t: 'void' };
					} else {
						if (activeAsset.value) {
							cells[cy][cx] = deepClone(activeAsset.value.cell);
						} else {
							cells[cy][cx] = newBrushCell();
						}
					}
					modified = true;

					for (const [nx, ny] of [[cx+1, cy], [cx-1, cy], [cx, cy+1], [cx, cy-1]]) {
						if (nx >= 0 && nx < w && ny >= 0 && ny < h) {
							const key = `${nx},${ny}`;
							if (!visited.has(key)) {
								visited.add(key);
								queue.push([nx, ny]);
							}
						}
					}
				}
			}

			if (modified) {
				markDungeonDirty(store.selectedDungeon);
				schedulePreview();
			}
		}

		function applyDungeonRectangle() {
			const f = floor.value;
			if (!f || !rectStart.value || !rectEnd.value) return;
			const x0 = Math.min(rectStart.value.x, rectEnd.value.x);
			const x1 = Math.max(rectStart.value.x, rectEnd.value.x);
			const y0 = Math.min(rectStart.value.y, rectEnd.value.y);
			const y1 = Math.max(rectStart.value.y, rectEnd.value.y);
			const isErase = rectStart.value.isErase;

			snapshot();
			let modified = false;

			for (let y = y0; y <= y1; y++) {
				for (let x = x0; x <= x1; x++) {
					if (!f.cells[y] || !f.cells[y][x]) continue;
					const current = f.cells[y][x];
					if (isErase) {
						if (current.t !== 'void') {
							f.cells[y][x] = { t: 'void' };
							modified = true;
						}
					} else {
						if (activeAsset.value) {
							f.cells[y][x] = deepClone(activeAsset.value.cell);
							modified = true;
						} else {
							f.cells[y][x] = newBrushCell();
							modified = true;
						}
					}
				}
			}

			if (modified) {
				markDungeonDirty(store.selectedDungeon);
				schedulePreview();
			}
		}

		function fillEntireFloor() {
			const f = floor.value;
			if (!f) return;
			const target = activeAsset.value ? activeAsset.value.name : (tileMap.value[brush.value]?.label || brush.value);
			askConfirm('¿Estás seguro de que quieres cambiar TODAS las casillas de la planta a "' + target + '"?', () => {
				snapshot();
				let modified = false;
				for (let y = 0; y < f.h; y++) {
					for (let x = 0; x < f.w; x++) {
						const cell = f.cells[y][x];
						if (activeAsset.value) {
							f.cells[y][x] = deepClone(activeAsset.value.cell);
							modified = true;
						} else {
							f.cells[y][x] = newBrushCell();
							modified = true;
						}
					}
				}
				if (modified) {
					markDungeonDirty(store.selectedDungeon);
					schedulePreview();
					flash('Toda la planta rellenada con "' + target + '".');
				}
			});
		}

		function paintCell(x, y, t) {
			const f = floor.value;
			if (!f || !f.cells[y]) return;
			// Modo asset (Fase 6): estampa la casilla configurada de la biblioteca,
			// salvo que sea un borrado explícito ('void').
			if (activeAsset.value && t !== 'void') {
				if (!strokeTaken) { snapshot(); strokeTaken = true; }
				f.cells[y][x] = deepClone(activeAsset.value.cell);
				markDungeonDirty(store.selectedDungeon); selectCell(x, y); schedulePreview();
				return;
			}
			const cur = f.cells[y][x];
			// Con configuración de pincel, siempre reestampa (para aplicar los cambios);
			// sin ella, evita repintar una casilla idéntica del mismo tipo.
			const hasCfg = Object.keys(brushConfigClean()).length > 0;
			if (cur && cur.t === t && t !== 'void' && !hasCfg) { selectCell(x, y); return; }
			if (!strokeTaken) { snapshot(); strokeTaken = true; }
			f.cells[y][x] = t === 'void' ? { t: 'void' } : newBrushCell();
			markDungeonDirty(store.selectedDungeon);
			selectCell(x, y);
			schedulePreview();
		}

		function selectCell(x, y) { sel.value = { x, y }; }

		// ── Pincel: tipo suelto vs asset ──────────────────────────────────────────
		// Config del pincel de tipo, sin claves vacías (lo que se estampa además de `t`).
		function brushConfigClean() {
			const clean = {};
			for (const k in brushConfig.value) {
				const v = brushConfig.value[k];
				if (v === '' || v == null) continue;
				clean[k] = v;
			}
			return clean;
		}
		// Celda que produce el pincel de TIPO (tipo + su configuración por defecto).
		function newBrushCell() { return { t: brush.value, ...brushConfigClean() }; }
		// Edita una clave de la configuración del pincel (vacío/undefined la elimina).
		function setBrushConfig(key, value) {
			const next = { ...brushConfig.value };
			if (value === '' || value == null || value === false) delete next[key];
			else next[key] = value;
			brushConfig.value = next;
		}
		function selectTile(t) {
			brush.value = t; activeAsset.value = null;
			// Al cambiar de tipo, la config previa deja de tener sentido.
			brushConfig.value = {};
			// Si estabas en un modo que no pinta, vuelve al pincel para poder colocar.
			if (drawMode.value === 'select' || drawMode.value === 'eyedropper') drawMode.value = 'pencil';
		}
		// Cuentagotas: copia la casilla clicada al pincel para replicarla tal cual.
		// Si es un objeto inteligente (kit) reusa el sello del kit; si no, estampa una
		// copia exacta de la celda vía activeAsset.
		function pickCell(x, y) {
			const f = floor.value;
			const c = f && f.cells[y] ? f.cells[y][x] : null;
			if (!c || c.t === 'void') { selectCell(x, y); return; }
			if (c.t === 'smart' && c.kit && kitPieces.value[c.kit]) {
				selectKitPiece(c.kit, kitPieces.value[c.kit]);
			} else {
				const meta = tileMap.value[c.t];
				brush.value = c.t;
				activeAsset.value = {
					id: 'pick', name: (meta && meta.label) || c.t, icon: (meta && meta.icon) || '⭐',
					cell: deepClone(c),
				};
			}
			selectCell(x, y);
			flash('Pincel copiado de (' + x + ',' + y + ').');
		}
		function selectAsset(a) { activeAsset.value = a; }
		function clearAsset() { activeAsset.value = null; }
		function saveCurrentAsAsset() {
			const c = selCell.value;
			if (!c) { flash('Selecciona una casilla para guardarla como asset.'); return; }
			const name = (saveAssetName.value || '').trim() || (tileMap.value[c.t]?.label || c.t);
			const icon = tileMap.value[c.t]?.icon || '⭐';
			assets.saveFromCell(name, c, icon);
			saveAssetName.value = '';
			flash('Asset guardado: ' + name);
		}

		// ── PROPS PERSONALIZADOS (import de modelos .glb) ──────────
		// Un "prop" es un TIPO DE CASILLA nuevo (data/dungeon_tiles/<id>.json) cuyo
		// `render` es {shape:'model', model:'<fichero>.glb'}. Al crearlo aparece
		// automáticamente en la paleta (grupo "Props"), como cualquier otro tipo.
		const propName = ref('');
		const propIcon = ref('📦');
		const propSolid = ref(true);
		const propFile = ref(null);      // File (.glb) elegido
		const propFileName = ref('');
		const importing = ref(false);
		// Tipos de casilla que son props de modelo (para listarlos/borrarlos).
		const propTiles = computed(() => dunTiles.value.filter(t => t.render && t.render.shape === 'model'));

		function uniqueTileId(base) {
			let id = base, n = 2;
			const tiles = store.dungeonTiles || {};
			while (tiles[id]) id = base + '_' + (n++);
			return id;
		}
		function onPropFile(ev) {
			const f = ev.target.files && ev.target.files[0];
			propFile.value = f || null;
			propFileName.value = f ? f.name : '';
			// Prerrellena el nombre visible a partir del fichero si está vacío.
			if (f && !propName.value.trim()) {
				propName.value = f.name.replace(/\.glb$/i, '').replace(/[_\-]+/g, ' ').trim();
			}
		}
		async function importProp() {
			const f = propFile.value;
			if (!f) { flash('Elige un fichero .glb primero.'); return; }
			if (!/\.glb$/i.test(f.name)) { flash('El modelo debe ser un .glb.'); return; }
			const name = (propName.value || '').trim() || f.name.replace(/\.glb$/i, '');
			const slug = slugify(name);
			const fileName = slug + '.glb';
			const id = uniqueTileId('prop_' + slug);
			importing.value = true;
			try {
				const buf = await f.arrayBuffer();
				await FS.uploadAsset('model', fileName, buf, 'model/gltf-binary');
				const tile = {
					t: id,
					label: name,
					icon: (propIcon.value || '📦').trim() || '📦',
					color: '#8a6d3b',
					group: 'Props',
					order: 900 + propTiles.value.length,
					entity: true,
					orient: true,
					render: { shape: 'model', model: fileName },
				};
				if (propSolid.value) { tile.solid = true; tile.render.solid = true; }
				await FS.writeCollectionItem('dungeon_tiles', id, tile);
				// Refresca el catálogo reactivo → la paleta muestra el prop al instante.
				if (!store.dungeonTiles) store.dungeonTiles = {};
				store.dungeonTiles[id] = tile;
				selectTile(id);
				propName.value = ''; propFile.value = null; propFileName.value = '';
				flash('Prop importado: ' + name + ' (colócalo desde la paleta, grupo "Props").');
			} catch (e) {
				flash('Error al importar el prop: ' + (e.message || String(e)));
			} finally {
				importing.value = false;
			}
		}
		function deleteProp(t) {
			const tile = tileMap.value[t];
			if (!tile) return;
			askConfirm('¿Borrar el prop "' + (tile.label || t) + '"?\nSe elimina data/dungeon_tiles/' + t + '.json y su modelo .glb. Las casillas que lo usen quedarán sin dibujar.', async () => {
				try {
					await FS.deleteCollectionItem('dungeon_tiles', t);
					const model = tile.render && tile.render.model;
					if (model) { try { await FS.deleteAsset('model', model); } catch (_) { /* modelo compartido o ya borrado */ } }
					delete store.dungeonTiles[t];
					if (brush.value === t) selectTile('floor');
					flash('Prop borrado: ' + (tile.label || t));
				} catch (e) {
					flash('Error al borrar el prop: ' + (e.message || String(e)));
				}
			});
		}

		// Editar una propiedad de la casilla seleccionada.
		function setCellProp(key, value) {
			const c = selCell.value;
			if (!c) return;
			snapshot();
			if (value === '' || value === null || value === undefined) delete c[key];
			else c[key] = value;
			markDungeonDirty(store.selectedDungeon);
			schedulePreview();
		}
		function setTeleportTarget(part, value) {
			const c = selCell.value;
			if (!c) return;
			snapshot();
			if (!c.to) c.to = { f: 0, x: 0, y: 0 };
			c.to[part] = Math.max(0, value | 0);
			markDungeonDirty(store.selectedDungeon);
		}
		// ── Cofre data-driven: oro + lista de objetos { id, qty } ───────────────
		function setChestGold(value) {
			const c = selCell.value;
			if (!c) return;
			snapshot();
			const g = Math.max(0, value | 0);
			if (g === 0) delete c.gold; else c.gold = g;
			markDungeonDirty(store.selectedDungeon);
			schedulePreview();
		}
		function addChestItem() {
			const c = selCell.value;
			if (!c) return;
			snapshot();
			if (!Array.isArray(c.items)) c.items = [];
			c.items.push({ id: itemIds.value[0] || '', qty: 1 });
			markDungeonDirty(store.selectedDungeon);
		}
		function removeChestItem(idx) {
			const c = selCell.value;
			if (!c || !Array.isArray(c.items)) return;
			snapshot();
			c.items.splice(idx, 1);
			if (!c.items.length) delete c.items;
			markDungeonDirty(store.selectedDungeon);
		}
		function setChestItem(idx, part, value) {
			const c = selCell.value;
			if (!c || !Array.isArray(c.items) || !c.items[idx]) return;
			snapshot();
			if (part === 'qty') c.items[idx].qty = Math.max(1, value | 0);
			else c.items[idx].id = value;
			markDungeonDirty(store.selectedDungeon);
		}
		// ── Salida al mundo (portal de salida data-driven) ─────────────────────
		function toggleExitTo(on) {
			if (!dun.value) return;
			snapshot();
			if (on) dun.value.exit_to = { x: 0, y: 0 };
			else delete dun.value.exit_to;
			markDungeonDirty(store.selectedDungeon);
		}
		function setExitTo(part, value) {
			if (!dun.value) return;
			snapshot();
			if (!dun.value.exit_to) dun.value.exit_to = { x: 0, y: 0 };
			dun.value.exit_to[part] = Math.max(0, value | 0);
			markDungeonDirty(store.selectedDungeon);
		}
		function markSpawnHere() {
			if (!sel.value || !dun.value) return;
			snapshot();
			dun.value.spawn = { f: floorIdx.value, x: sel.value.x, y: sel.value.y };
			markDungeonDirty(store.selectedDungeon);
			schedulePreview();
			flash('Punto de inicio fijado.');
		}
		const isSpawn = (x, y) => dun.value && dun.value.spawn
			&& dun.value.spawn.f === floorIdx.value && dun.value.spawn.x === x && dun.value.spawn.y === y;

		// ── Entradas/salidas NOMBRADAS ────────────────────────
		// Una mazmorra puede tener 2-3 "puertas" (p. ej. dun_001: oeste/este de un
		// túnel): cada una es un punto de aparición propio (`portals.<nombre>.spawn`).
		// En el mapamundi, cada casilla-puerta declara qué entrada usar
		// (`portal.entry`, editable en el inspector del Mapa) y, dentro de la
		// mazmorra, la celda de teletransporte que actúa como esa MISMA puerta se
		// marca con `portal:"<nombre>"` (ver plantilla, sección Teletransporte). Al
		// salir por ella, ViewDungeon busca en el mundo la casilla con esa entrada
		// y reaparece ahí — no siempre en la casilla por la que se entró.
		const newPortalName = ref('');
		function addPortal() {
			const name = newPortalName.value.trim();
			if (!dun.value || !name) return;
			snapshot();
			if (!dun.value.portals) dun.value.portals = {};
			if (!dun.value.portals[name]) {
				dun.value.portals[name] = { spawn: { f: floorIdx.value, x: 0, y: 0 } };
			}
			markDungeonDirty(store.selectedDungeon);
			newPortalName.value = '';
		}
		function removePortal(name) {
			if (!dun.value || !dun.value.portals) return;
			snapshot();
			delete dun.value.portals[name];
			markDungeonDirty(store.selectedDungeon);
		}
		function setPortalSpawn(name, part, value) {
			if (!dun.value) return;
			snapshot();
			if (!dun.value.portals) dun.value.portals = {};
			if (!dun.value.portals[name] || !dun.value.portals[name].spawn) {
				dun.value.portals[name] = { spawn: { f: 0, x: 0, y: 0 } };
			}
			dun.value.portals[name].spawn[part] = Math.max(0, value | 0);
			markDungeonDirty(store.selectedDungeon);
		}
		function setPortalHere(name) {
			if (!sel.value || !dun.value || !name) return;
			snapshot();
			if (!dun.value.portals) dun.value.portals = {};
			dun.value.portals[name] = { spawn: { f: floorIdx.value, x: sel.value.x, y: sel.value.y } };
			markDungeonDirty(store.selectedDungeon);
			flash('Entrada "' + name + '" fijada aquí.');
		}

		// ── ELEMENTOS INTERACTIVOS con ESTADOS e IDs (Fase 6) ─────────────────────
		// Un elemento con estado (puerta, compuerta, interruptor…) puede tener un
		// `eid` (id único dentro de la mazmorra) y un `state` inicial. Los accionadores
		// (interruptor/botón/palanca/placa) declaran `targets`: [{ eid, action }].
		const isActuator = (t) => !!(tileMap.value[t] && tileMap.value[t].actuator);
		const isStateful = (t) => !!(tileMap.value[t] && tileMap.value[t].stateful);
		const stateOptionsFor = (t) => STATE_OPTIONS[t] || [];

		// Todos los eid definidos en la mazmorra (para enlazar y detectar duplicados/rotos).
		const elementIds = computed(() => {
			const out = [];
			const fl = floors.value;
			for (let fi = 0; fi < fl.length; fi++) {
				const cells = fl[fi].cells || [];
				for (let y = 0; y < cells.length; y++) {
					const row = cells[y] || [];
					for (let x = 0; x < row.length; x++) {
						const c = row[x];
						if (c && c.eid) out.push({ eid: c.eid, t: c.t, f: fi, x, y });
					}
				}
			}
			return out;
		});
		const elementIdSet = computed(() => new Set(elementIds.value.map(e => e.eid)));
		// Objetivos que apuntan a un eid inexistente (para avisar en el inspector).
		const brokenTargets = computed(() => {
			const c = selCell.value;
			if (!c || !Array.isArray(c.targets)) return new Set();
			const set = elementIdSet.value;
			return new Set(c.targets.filter(tg => tg.eid && !set.has(tg.eid)).map(tg => tg.eid));
		});

		function setEid(v) {
			const c = selCell.value; if (!c) return;
			snapshot();
			const val = String(v || '').trim().replace(/\s+/g, '_');
			if (val) c.eid = val; else delete c.eid;
			markDungeonDirty(store.selectedDungeon);
		}
		function setState(v) { setCellProp('state', v); }
		function addTarget() {
			const c = selCell.value; if (!c) return;
			snapshot();
			if (!Array.isArray(c.targets)) c.targets = [];
			c.targets.push({ eid: '', action: 'toggle' });
			markDungeonDirty(store.selectedDungeon);
		}
		function removeTarget(idx) {
			const c = selCell.value; if (!c || !Array.isArray(c.targets)) return;
			snapshot();
			c.targets.splice(idx, 1);
			if (!c.targets.length) delete c.targets;
			markDungeonDirty(store.selectedDungeon);
		}
		function setTarget(idx, part, value) {
			const c = selCell.value; if (!c || !Array.isArray(c.targets) || !c.targets[idx]) return;
			snapshot();
			c.targets[idx][part] = value;
			markDungeonDirty(store.selectedDungeon);
		}
		// Objetivos enlazables: elementos con estado que NO sean el propio actuador.
		const linkableTargets = computed(() => {
			const c = selCell.value;
			return elementIds.value.filter(e => isStateful(e.t) && e.eid !== (c && c.eid));
		});

		// ── PROBLEMAS DE ESTA MAZMORRA, EN VIVO ────────────────────
		// Valida la mazmorra ABIERTA sin salir a la pestaña QA global: spawn,
		// teletransportes, eids duplicados/rotos, actuadores sin objetivo, puertas
		// sin control, tipos desconocidos, Objeto Inteligente sin pieza válida,
		// cofres con ítems/tabla rotos y boss/monstruo/pool inexistentes. Mismas
		// reglas que `validator.js` (sección Mazmorras), reimplementadas aquí en
		// forma reactiva y sin depender de hidratar TODAS las mazmorras del store.
		const CONTROLLABLE_TYPES = new Set(['door', 'gate', 'light']);
		const dungeonIssues = computed(() => {
			const d = dun.value;
			const out = [];
			if (!d) return out;
			const fl = Array.isArray(d.floors) ? d.floors : [];
			if (!fl.length) { out.push({ level: 'warning', msg: 'La mazmorra no tiene ninguna planta.' }); return out; }
			const enemySet = new Set(enemyIds.value);
			const itemSet = new Set(itemIds.value);
			const loot = store.loot || {};
			const pieces = kitPieces.value;
			if (d.boss && !enemySet.has(d.boss)) out.push({ level: 'error', msg: `El boss "${d.boss}" no existe en enemies.json.` });
			for (const eid of (Array.isArray(d.random_pool) ? d.random_pool : [])) {
				if (!enemySet.has(eid)) out.push({ level: 'warning', msg: `"${eid}" del pool aleatorio no existe en enemies.json.` });
			}
			// Spawn del jugador.
			const sp = d.spawn || {};
			const spFloor = fl[Number(sp.f) || 0];
			if (!spFloor) {
				out.push({ level: 'error', msg: `El inicio del jugador apunta a la planta ${Number(sp.f) || 0}, que no existe.` });
			} else {
				const spRow = Array.isArray(spFloor.cells) ? spFloor.cells[Number(sp.y) || 0] : null;
				const spCell = spRow ? spRow[Number(sp.x) || 0] : null;
				const sx = Number(sp.x) || 0, sy = Number(sp.y) || 0, sf = Number(sp.f) || 0;
				if (!spCell || spCell.t === 'void') {
					out.push({ level: 'warning', msg: `El inicio del jugador (${sx},${sy}) cae en una casilla vacía.`, f: sf, x: sx, y: sy });
				} else if (tileMap.value[spCell.t] && tileMap.value[spCell.t].solid && spCell.col !== false) {
					out.push({ level: 'warning', msg: `El inicio del jugador (${sx},${sy}) cae dentro de un "${spCell.t}" sólido.`, f: sf, x: sx, y: sy });
				}
			}
			const eidCount = {};
			fl.forEach((floor, fi) => {
				(Array.isArray(floor.cells) ? floor.cells : []).forEach((row, y) => {
					(Array.isArray(row) ? row : []).forEach((cell, x) => {
						if (!cell) return;
						if (cell.eid) eidCount[cell.eid] = (eidCount[cell.eid] || 0) + 1;
						if (cell.t === 'monster') {
							const eid = cell.ref || (cell.boss ? d.boss : '');
							if (eid && !enemySet.has(eid)) out.push({ level: 'error', msg: `Monstruo en planta ${fi + 1} (${x},${y}) usa "${eid}", que no existe en enemies.json.`, f: fi, x, y });
						}
						if (cell.t && !tileMap.value[cell.t]) out.push({ level: 'warning', msg: `Casilla en planta ${fi + 1} (${x},${y}) usa el tipo desconocido "${cell.t}".`, f: fi, x, y });
						if (cell.t === 'smart' && cell.ref && !pieces[cell.ref]) out.push({ level: 'error', msg: `Objeto Inteligente en planta ${fi + 1} (${x},${y}) usa la pieza "${cell.ref}", que no existe.`, f: fi, x, y });
						if (cell.t === 'chest') {
							for (const it of (Array.isArray(cell.items) ? cell.items : [])) {
								if (it && it.id && !itemSet.has(it.id)) out.push({ level: 'error', msg: `Cofre en planta ${fi + 1} (${x},${y}) contiene "${it.id}", que no existe en items.json.`, f: fi, x, y });
							}
							if (typeof cell.loot === 'string' && !Array.isArray(loot[cell.loot])) out.push({ level: 'error', msg: `Cofre en planta ${fi + 1} (${x},${y}) usa la tabla "${cell.loot}", que no existe en loot.json.`, f: fi, x, y });
						}
						if ((cell.t === 'teleport' || cell.t === 'stairs') && cell.to && typeof cell.to === 'object') {
							const label = cell.t === 'stairs' ? 'Escalera' : 'Teletransporte';
							const to = cell.to;
							const tf = fl[Number(to.f) || 0];
							const tx = Number(to.x), ty = Number(to.y);
							const okBounds = tf && tx >= 0 && ty >= 0 && tx < tf.w && ty < tf.h;
							if (!okBounds) out.push({ level: 'error', msg: `${label} en planta ${fi + 1} (${x},${y}) apunta fuera de límites.`, f: fi, x, y });
							else {
								const destCell = tf.cells[ty] && tf.cells[ty][tx];
								if (!destCell || destCell.t === 'void') out.push({ level: 'warning', msg: `${label} en planta ${fi + 1} (${x},${y}) lleva a una casilla vacía.`, f: fi, x, y });
							}
						} else if (cell.t === 'stairs' && !cell.to) {
							out.push({ level: 'warning', msg: `Escalera en planta ${fi + 1} (${x},${y}) no tiene destino: es solo decorativa, no sube de planta.`, f: fi, x, y });
						}
					});
				});
			});
			for (const [eid, n] of Object.entries(eidCount)) {
				if (n > 1) out.push({ level: 'error', msg: `El eid "${eid}" está repetido ${n} veces (deben ser únicos).` });
			}
			const eidSet = new Set(Object.keys(eidCount));
			const targetedEids = new Set();
			fl.forEach((floor, fi) => {
				(Array.isArray(floor.cells) ? floor.cells : []).forEach((row, y) => {
					(Array.isArray(row) ? row : []).forEach((cell, x) => {
						if (!cell || !isActuator(cell.t)) return;
						const targets = Array.isArray(cell.targets) ? cell.targets.filter(t => t && t.eid) : [];
						if (!targets.length) out.push({ level: 'warning', msg: `El ${cell.t} en planta ${fi + 1} (${x},${y}) no acciona ningún objetivo.`, f: fi, x, y });
						for (const tg of targets) {
							targetedEids.add(tg.eid);
							if (!eidSet.has(tg.eid)) out.push({ level: 'error', msg: `El ${cell.t} en planta ${fi + 1} (${x},${y}) acciona el eid "${tg.eid}", que no existe.`, f: fi, x, y });
						}
					});
				});
			});
			fl.forEach((floor, fi) => {
				(Array.isArray(floor.cells) ? floor.cells : []).forEach((row, y) => {
					(Array.isArray(row) ? row : []).forEach((cell, x) => {
						if (!cell || !CONTROLLABLE_TYPES.has(cell.t) || !cell.eid) return;
						if (!targetedEids.has(cell.eid)) {
							const label = cell.t === 'gate' ? 'La compuerta' : (cell.t === 'light' ? 'La luz' : 'La puerta');
							out.push({ level: 'warning', msg: `${label} "${cell.eid}" (planta ${fi + 1}) no la acciona ningún interruptor/palanca/placa.`, f: fi, x, y });
						}
					});
				});
			});
			return out;
		});
		const dungeonIssueCount = computed(() => {
			let errors = 0, warnings = 0;
			for (const i of dungeonIssues.value) { if (i.level === 'error') errors++; else warnings++; }
			return { errors, warnings, total: errors + warnings };
		});
		// Salta a la casilla del problema (si trae posición) para arreglarla al momento.
		function jumpToIssue(iss) {
			if (iss.f === undefined) return;
			if (iss.f !== floorIdx.value) selectFloor(iss.f);
			if (iss.x !== undefined && iss.y !== undefined) nextTick(() => selectCell(iss.x, iss.y));
		}

		// ── Zoom y encuadre de la rejilla ─────────────────────────────────────────
		// Límites amplios: mazmorras de 48×48 necesitan alejar mucho para ver el
		// conjunto, y acercar bastante para editar casilla a casilla con comodidad.
		const ZOOM_MIN = 0.2, ZOOM_MAX = 3;
		const BASE_CELL = 34;   // px de casilla a zoom 1 (debe coincidir con cellPx)
		function clampZoom(z) { return Math.max(ZOOM_MIN, Math.min(ZOOM_MAX, +z.toFixed(2))); }
		function zoomBy(delta) { zoom.value = clampZoom(zoom.value + delta); }

		// Ajusta el zoom para que TODA la planta activa quepa en el visor (con un
		// pequeño margen). Es la respuesta al dolor "no veo la mazmorra entera".
		function fitToView() {
			const wrap = gridCanvasWrap.value;
			const f = floor.value;
			if (!wrap || !f) return;
			const padding = 34;                 // margen visual (coincide con el padding CSS)
			const availW = Math.max(40, wrap.clientWidth - padding);
			const availH = Math.max(40, wrap.clientHeight - padding);
			const perCell = BASE_CELL + 1;       // +1 por el gap de la rejilla
			const z = Math.min(availW / (f.w * perCell), availH / (f.h * perCell));
			zoom.value = clampZoom(z);
		}
		// Rueda del ratón sobre la rejilla: zoom con Ctrl/⌘ (evita conflicto con el
		// scroll normal). Sin Ctrl, deja el desplazamiento nativo del contenedor.
		function onWheelZoom(ev) {
			if (!ev.ctrlKey && !ev.metaKey) return;
			ev.preventDefault();
			zoomBy(ev.deltaY < 0 ? 0.15 : -0.15);
		}

		// ── Estilos de la rejilla superior ────────────────────────────────────────
		const cellPx = computed(() => Math.round(BASE_CELL * zoom.value));
		// Estilo de una casilla de la rejilla 2D superior. Para pared/suelo replica
		// `resolveSurfaceFill` (misma resolución que la preview isométrica y el
		// motor): si hay una textura real (subida o la de roca por defecto) se ve
		// como miniatura tileada; si es un preset, el color plano EXACTO que
		// aplicará el motor. Antes esta rejilla solo pintaba el color base del
		// TIPO, ignorando qué material tenía realmente la celda.
		function cellStyle(cell) {
			void texReadyTick.value; // dependencia reactiva: repinta al terminar de cargar una textura
			const meta = tileMap.value[cell?.t] || tileMap.value.void;
			if (cell && cell.t === 'water' && cell.poisoned) return { background: '#4a9a3a' };
			if (cell) {
				const caps = tileCaps(meta);
				if (caps.wallType || caps.floorTex) {
					const surf = resolveSurfaceFill(cell, caps.wallType);
					if (surf.img) return { backgroundImage: `url("${surf.img.src}")`, backgroundSize: '20px 20px', backgroundColor: meta.color };
					return { background: surf.flat };
				}
			}
			let bg = meta.color;
			if (cell && cell.color) bg = cell.color;         // tinte personalizado
			return { background: bg };
		}
		function cellIcon(cell) {
			if (cell && cell.t === 'smart' && cell.kit) {
				const p = kitPieces.value[cell.kit];
				if (p) return p.icon || '🧩';
			}
			const meta = tileMap.value[cell?.t];
			return meta ? meta.icon : '';
		}
		// Título (tooltip) de una celda: qué tipo es + su eid, para identificarla al
		// pasar el ratón sin tener que seleccionarla (rejilla más legible).
		function cellTitle(x, y, cell) {
			if (!cell || cell.t === 'void') return `(${x},${y}) vacío`;
			const meta = tileMap.value[cell.t];
			let s = `(${x},${y}) ${meta ? meta.label : cell.t}`;
			if (cell.eid) s += ` · eid:${cell.eid}`;
			return s;
		}

		// ── Preview 3D isométrica (canvas) ─────────────────────────────────────────
		let previewScheduled = false;
		function schedulePreview() {
			if (!show3D.value || previewScheduled) return;
			previewScheduled = true;
			requestAnimationFrame(() => { previewScheduled = false; renderPreview(); });
		}

		function renderPreview() {
			const cv = previewCanvas.value;
			if (!cv || !show3D.value || !dun.value) return;
			const ctx = cv.getContext('2d');
			const W = cv.width, H = cv.height;
			ctx.clearRect(0, 0, W, H);
			ctx.fillStyle = '#0a0c14';
			ctx.fillRect(0, 0, W, H);

			const list = stack3D.value ? floors.value.map((f, i) => ({ f, i })) : [{ f: floor.value, i: floorIdx.value }];
			// Dimensión máxima para escalar.
			let maxDim = 8;
			for (const { f } of list) if (f) maxDim = Math.max(maxDim, f.w, f.h);
			const tw = Math.max(10, Math.min(30, (W * 0.8) / (maxDim * 2)));  // ancho de rombo
			const th = tw * 0.5;
			const zScale = th * 1.2;
			const wallH = Number(dun.value.wall_height) || 3;
			const originX = W / 2;
			const originY = H * 0.30;

			const proj = (x, y, z) => ({
				sx: originX + (x - y) * tw,
				sy: originY + (x + y) * th - z * zScale,
			});

			// Recolectar cubos de todas las plantas a dibujar, ordenados por profundidad.
			const cubes = [];
			for (const { f, i } of list) {
				if (!f) continue;
				const baseZ = stack3D.value ? i * (wallH + 0.2) : 0;
				for (let y = 0; y < f.h; y++) {
					for (let x = 0; x < f.w; x++) {
						const cell = f.cells[y][x];
						if (!cell || cell.t === 'void') continue;
						cubes.push({ x, y, cell, baseZ, spawn: dun.value.spawn && dun.value.spawn.f === i && dun.value.spawn.x === x && dun.value.spawn.y === y });
					}
				}
			}
			cubes.sort((a, b) => (a.baseZ - b.baseZ) || ((a.x + a.y) - (b.x + b.y)));

			for (const cube of cubes) drawCube(ctx, proj, cube, wallH);

			// Leyenda.
			ctx.fillStyle = 'rgba(255,255,255,.5)';
			ctx.font = '11px Inter, sans-serif';
			ctx.fillText(stack3D.value ? 'Todas las plantas' : (floor.value ? floor.value.name : ''), 10, H - 10);
		}

		function cubeHeight(cell, wallH) {
			const m = tileMap.value[cell.t];
			const custom = Number(cell.h);
			if (m && m.solid) return custom > 0 ? custom : wallH;      // pared
			if (cell.t === 'door') return (custom > 0 ? custom : wallH) * 0.85;
			if (cell.t === 'lava' || cell.t === 'water') return 0.18;
			if (cell.t === 'spikes') return 0.35;
			if (m && m.entity) return custom > 0 ? custom : 0.7;        // marcador
			return custom > 0 ? custom : 0.25;                          // suelo/plano
		}

		function shade(hex, factor) {
			const c = hex.replace('#', '');
			const n = parseInt(c.length === 3 ? c.split('').map(ch => ch + ch).join('') : c, 16);
			let r = (n >> 16) & 255, g = (n >> 8) & 255, b = n & 255;
			r = Math.max(0, Math.min(255, Math.round(r * factor)));
			g = Math.max(0, Math.min(255, Math.round(g * factor)));
			b = Math.max(0, Math.min(255, Math.round(b * factor)));
			return `rgb(${r},${g},${b})`;
		}

		// Repinta las previews (canvas, imperativas) Y fuerza que la rejilla 2D
		// (reactiva vía Vue) vuelva a evaluar `cellStyle` cuando termina de cargar
		// una textura pedida por `resolveSurfaceFill` — la primera vez se pinta un
		// color de espera y, en cuanto el PNG está listo, todo se repinta ya con él.
		const texReadyTick = ref(0);
		function onTextureReady() { texReadyTick.value++; schedulePreview(); nextTick(renderItemPreview); }

		// Resuelve qué se pinta REALMENTE en una superficie de pared/suelo,
		// replicando el MISMO orden de prioridad que _surface_tint/_surface_material
		// en GridDungeonStage.gd, para que la preview del editor sea fiel al motor
		// (bug reportado: "ni parecido, ni me está seleccionando la textura real"):
		//  1) color explícito de la celda → color plano.
		//  2) wall/tex apunta a una textura REAL (subida) → esa imagen como patrón.
		//  3) wall/tex es un preset conocido (stone/brick/…) → color plano EXACTO
		//     (el motor QUITA la textura al aplicar un preset — no la tiñe).
		//  4) nada de lo anterior → la textura de roca por defecto
		//     (tex_cave_wall.png), la misma que usa el motor por defecto.
		function resolveSurfaceFill(cell, isWall) {
			if (cell.color) return { flat: cell.color };
			const key = String((isWall ? cell.wall : cell.tex) || '');
			if (key) {
				const found = dungeonTextures.value.find(t => t.name === key || t.name === key + '.png');
				if (found) {
					const img = loadTexImage(found.url, onTextureReady);
					return img ? { img } : { flat: isWall ? '#6b5040' : '#39404e' };
				}
				const preset = (isWall ? WALL_COLORS : FLOOR_COLORS)[key];
				if (preset) return { flat: preset };
			}
			if (defaultTextureUrl.value) {
				const img = loadTexImage(defaultTextureUrl.value, onTextureReady);
				if (img) return { img };
			}
			return { flat: isWall ? '#6b5040' : '#39404e' };
		}

		// Tipos SIN `entity` en su catálogo pero cuyo icono SÍ ayuda a identificarlos
		// de un vistazo en la preview isométrica (líquidos/peligros con forma plana).
		const ICON_ALSO_FOR = new Set(['lava', 'water', 'spikes']);
		function drawCube(ctx, proj, cube, wallH, opts) {
			const { x, y, cell, baseZ } = cube;
			const meta = tileMap.value[cell.t] || tileMap.value.floor;
			const caps = tileCaps(meta);
			const surf = (caps.wallType || caps.floorTex) ? resolveSurfaceFill(cell, caps.wallType) : null;
			const col = surf ? (surf.flat || meta.color) : (cell.color || meta.color);
			const h = cubeHeight(cell, wallH);
			const zTop = baseZ + h;
			const forceIcon = !!(opts && opts.forceIcon);

			// Los 4 vértices superiores e inferiores del prisma de una casilla.
			const t00 = proj(x, y, zTop), t10 = proj(x + 1, y, zTop);
			const t11 = proj(x + 1, y + 1, zTop), t01 = proj(x, y + 1, zTop);
			const b10 = proj(x + 1, y, baseZ), b11 = proj(x + 1, y + 1, baseZ), b01 = proj(x, y + 1, baseZ);

			// Pinta una cara: con la TEXTURA real (patrón) si hay una resuelta, o
			// con el color plano de siempre si no (entidades, decoración, líquidos…).
			function face(pts, shadeFactor) {
				if (surf && surf.img) {
					poly(ctx, pts, { img: surf.img, shade: shadeFactor, repeats: caps.wallType ? 1.4 : 2.2 });
				} else {
					ctx.fillStyle = shade(col, shadeFactor);
					poly(ctx, pts);
				}
			}
			// Cara derecha (x+1).
			face([t10, b10, b11, t11], 0.62);
			// Cara frontal (y+1).
			face([t11, b11, b01, t01], 0.48);
			// Cara superior.
			face([t00, t10, t11, t01], cube.spawn ? 1.25 : 1.0);

			// Icono en la cara superior para entidades/interactivos/peligros (o
			// SIEMPRE que `forceIcon` — preview de un solo elemento).
			// Insignia oscura semitransparente detrás: sin ella el icono podía
			// desaparecer sobre un tinte de color parecido (p. ej. 🔥 hoguera sobre
			// naranja) — bug reportado. El tamaño se calcula a partir del ancho real
			// de la cara superior en pantalla, así escala bien tanto en la preview
			// general (muchas casillas pequeñas) como en la de un solo elemento.
			if (forceIcon || meta.entity || cell.t === 'door' || cell.t === 'stairs' || ICON_ALSO_FOR.has(cell.t)) {
				const cx = (t00.sx + t11.sx) / 2, cy = (t00.sy + t11.sy) / 2;
				const topW = Math.hypot(t10.sx - t00.sx, t10.sy - t00.sy);
				const fontPx = forceIcon ? Math.max(30, Math.min(56, topW * 0.55)) : Math.max(10, Math.min(15, topW * 0.32));
				const rx = fontPx * 0.62, ry = rx * 0.58;
				ctx.beginPath();
				ctx.ellipse(cx, cy, rx, ry, 0, 0, Math.PI * 2);
				ctx.closePath();
				ctx.fillStyle = 'rgba(8,10,16,0.55)';
				ctx.fill();
				ctx.font = fontPx + 'px sans-serif';
				ctx.textAlign = 'center';
				ctx.textBaseline = 'middle';
				ctx.fillText(meta.icon, cx, cy);
				ctx.textAlign = 'start';
			}
			if (cube.spawn) {
				const cx = (t00.sx + t11.sx) / 2, cy = (t00.sy + t11.sy) / 2;
				ctx.font = '13px sans-serif';
				ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
				ctx.fillText('🚩', cx, cy - 12);
				ctx.textAlign = 'start';
			}
		}
		// `opts.img` (opcional): pinta la textura real como patrón repetido dentro
		// del polígono (recortado con clip) en vez del `fillStyle` plano, y aplica
		// `opts.shade` como sombreado multiplicativo — así la textura conserva el
		// mismo efecto de profundidad pseudo-3D que ya tenían las caras de color liso.
		function poly(ctx, pts, opts) {
			ctx.beginPath();
			ctx.moveTo(pts[0].sx, pts[0].sy);
			for (let i = 1; i < pts.length; i++) ctx.lineTo(pts[i].sx, pts[i].sy);
			ctx.closePath();
			if (opts && opts.img) {
				const xs = pts.map(p => p.sx), ys = pts.map(p => p.sy);
				const minX = Math.min(...xs), minY = Math.min(...ys);
				const w = Math.max(...xs) - minX || 1, h = Math.max(...ys) - minY || 1;
				ctx.save();
				ctx.clip();
				const pattern = ctx.createPattern(opts.img, 'repeat');
				if (pattern && pattern.setTransform && typeof DOMMatrix !== 'undefined') {
					try {
						const scale = Math.max(w, h) / (opts.repeats || 1.6) / opts.img.naturalWidth;
						pattern.setTransform(new DOMMatrix().scale(scale || 1));
					} catch (_) { /* navegador sin DOMMatrix encadenable: se queda a tamaño nativo */ }
				}
				ctx.fillStyle = pattern;
				ctx.fillRect(minX, minY, w, h);
				if (opts.shade != null && opts.shade < 1) {
					// Oscurece (caras en sombra), igual que el sombreado de las caras planas.
					ctx.globalCompositeOperation = 'multiply';
					const g = Math.max(0, Math.min(255, Math.round(255 * opts.shade)));
					ctx.fillStyle = `rgb(${g},${g},${g})`;
					ctx.fillRect(minX, minY, w, h);
					ctx.globalCompositeOperation = 'source-over';
				} else if (opts.shade != null && opts.shade > 1) {
					// Aclara ligeramente (resalte del inicio del jugador).
					ctx.globalAlpha = Math.min(0.4, opts.shade - 1);
					ctx.fillStyle = '#fff';
					ctx.fillRect(minX, minY, w, h);
					ctx.globalAlpha = 1;
				}
				ctx.restore();
				ctx.strokeStyle = 'rgba(0,0,0,.35)';
				ctx.lineWidth = 0.6;
				ctx.stroke();
				return;
			}
			ctx.fill();
			ctx.strokeStyle = 'rgba(0,0,0,.35)';
			ctx.lineWidth = 0.6;
			ctx.stroke();
		}

		// ── PREVISUALIZACIÓN DE ITEM (una sola casilla, isométrica) ────────────────
		// Responde a "cuando selecciono una puerta o escalera no sé qué forma tiene":
		// dibuja el elemento activo (sello de biblioteca > casilla seleccionada >
		// pincel de tipo) como un mini-render isométrico, reutilizando el mismo
		// dibujo que la preview 3D. Escaleras llevan un esquema de peldaños propio.
		const itemPreviewCanvas = ref(null);
		function previewCellData() {
			if (activeAsset.value && activeAsset.value.cell) return activeAsset.value.cell;
			if (selCell.value && selCell.value.t && selCell.value.t !== 'void') return selCell.value;
			if (brush.value) return Object.assign({ t: brush.value }, brushConfig.value || {});
			return null;
		}
		function renderItemPreview() {
			const cv = itemPreviewCanvas.value;
			if (!cv) return;
			const ctx = cv.getContext('2d');
			const W = cv.width, H = cv.height;
			ctx.clearRect(0, 0, W, H);
			ctx.fillStyle = '#11131c';
			ctx.fillRect(0, 0, W, H);
			const cell = previewCellData();
			if (!cell || cell.t === 'void') return;
			const meta = tileMap.value[cell.t] || tileMap.value.floor;
			const wallH = (dun.value && Number(dun.value.wall_height)) || 3;
			const tw = 40, th = tw * 0.5, zScale = th * 1.15;
			const proj = (x, y, z) => ({ sx: (W / 2) + (x - y) * tw, sy: (H * 0.60) + (x + y) * th - z * zScale });
			if (cell.t === 'stairs') {
				_drawStairsPreview(ctx, proj, cell.color || (meta && meta.color) || '#8a8f9c');
			} else {
				drawCube(ctx, proj, { x: 0, y: 0, cell, baseZ: 0, spawn: false }, wallH, { forceIcon: true });
			}
			// Nota para props de modelo: el esquema es un marcador, no el GLB real.
			if (meta && meta.render && meta.render.shape === 'model') {
				ctx.fillStyle = 'rgba(255,255,255,.55)';
				ctx.font = '10px Inter, sans-serif';
				ctx.textAlign = 'center';
				ctx.fillText('modelo 3D (' + (meta.render.model || '?') + ')', W / 2, H - 8);
				ctx.textAlign = 'start';
			}
		}
		// Peldaños ascendentes (esquema): varias lonjas en Y, cada una más alta.
		function _drawStairsPreview(ctx, proj, col) {
			const steps = 5, total = 1.4, dz = total / steps;
			for (let i = 0; i < steps; i++) {
				const y0 = i / steps, y1 = (i + 1) / steps, z = dz * (i + 1);
				const t00 = proj(0, y0, z), t10 = proj(1, y0, z), t11 = proj(1, y1, z), t01 = proj(0, y1, z);
				const r00 = proj(0, y0, z - dz), r10 = proj(1, y0, z - dz);
				ctx.fillStyle = shade(col, 0.5);
				poly(ctx, [t00, t10, r10, r00]);   // contrahuella (frente del peldaño)
				ctx.fillStyle = shade(col, 1.0);
				poly(ctx, [t00, t10, t11, t01]);    // huella (parte pisable)
			}
		}
		const scheduleItemPreview = () => nextTick(renderItemPreview);
		watch([brush, selCell, activeAsset], scheduleItemPreview);
		watch(brushConfig, scheduleItemPreview, { deep: true });

		// URL del .glb REAL del elemento previsualizado, si es un
		// prop de modelo importado (`render.shape:"model"`). Se muestra con
		// <model-viewer> (vendorizado, ver index.html); el canvas isométrico queda
		// como esquema de RESPALDO cuando no hay modelo (o mientras no hay ficheros).
		const previewModelUrl = computed(() => {
			const cell = previewCellData();
			if (!cell || cell.t === 'void') return null;
			const meta = tileMap.value[cell.t];
			if (!meta || !meta.render || meta.render.shape !== 'model') return null;
			let file = String(meta.render.model || '');
			if (!file) return null;
			if (!/\.glb$/i.test(file)) file += '.glb';
			return FS.assetUrl('model', file);
		});

		watch(show3D, (v) => { if (v) nextTick(renderPreview); });
		watch(stack3D, () => nextTick(renderPreview));
		watch(floorIdx, () => nextTick(renderPreview));
		// Al cambiar de mazmorra seleccionada, traer su contenido COMPLETO (floors[]
		// real) si todavía solo teníamos el resumen ligero del listado inicial.
		// Task 7, ítem 6.3: indicador de carga mientras se trae del disco una
		// mazmorra grande (antes la rejilla se quedaba en blanco/vacía en
		// silencio hasta que `ensureDungeonLoaded` resolvía).
		const dungeonLoading = ref(false);
		watch(() => store.selectedDungeon, (id) => {
			floorIdx.value = 0; sel.value = null; history.clear();
			dungeonLoading.value = true;
			ensureDungeonLoaded(id)
				.then(() => nextTick(() => { renderPreview(); fitToView(); }))
				.finally(() => { dungeonLoading.value = false; });
		});

		// ── Autoguardado + atajos ──────────────────────────────────────────────────
		const autosave = useAutosave({
			intervalMs: 9000,
			isDirty: () => Object.keys(store.dirtyDungeons).length > 0 || store.dirty.ids,
			onSave: () => save(false),
		});
		function onKey(e) {
			if (store.activeTab !== 'dungeons') return;
			const tag = (e.target && e.target.tagName) || '';
			if (tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT') return;
			if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'z') { e.preventDefault(); doUndo(); }
			else if ((e.ctrlKey || e.metaKey) && (e.key.toLowerCase() === 'y' || (e.shiftKey && e.key.toLowerCase() === 'z'))) { e.preventDefault(); doRedo(); }
			else if ((e.key === 'Delete' || e.key === 'Backspace') && sel.value) { e.preventDefault(); paintCell(sel.value.x, sel.value.y, 'void'); }
			// Copiar/pegar regiones: Ctrl+C copia el rectángulo ya
			// marcado en modo "Región" (o cambia a ese modo si no hay ninguno aún);
			// Ctrl+V cambia a modo "Pegar" listo para colocar el último recorte.
			else if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'c') {
				e.preventDefault();
				if (drawMode.value !== 'region') drawMode.value = 'region';
				if (regionSel.value) copyRegion();
			}
			else if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'v' && clipboard.value) {
				e.preventDefault();
				drawMode.value = 'paste';
			}
			// Task 5 (5.2): R/E rotan en 90° la orientación PENDIENTE (asset activo o
			// config del pincel de tipo) antes de colocarla en la rejilla.
			else if (!e.ctrlKey && !e.metaKey && e.key.toLowerCase() === 'r') { e.preventDefault(); rotatePendingOrientation(90); }
			else if (!e.ctrlKey && !e.metaKey && e.key.toLowerCase() === 'e') { e.preventDefault(); rotatePendingOrientation(-90); }
		}
		// Creación pendiente desde la Paleta de Comandos (Task 5, `> Nueva Mazmorra`):
		// este editor no usa useCollection/EntityListPanel (tiene su propio panel y
		// su propio flujo de creación con plantilla), así que observa la señal aquí.
		watch(() => nav.pendingNew, (t) => {
			if (t !== 'dungeons') return;
			nav.pendingNew = null;
			openCreateModal();
		}, { immediate: true });

		onMounted(() => {
			window.addEventListener('keydown', onKey); window.addEventListener('mouseup', endStroke); autosave.start();
			// Selección inicial: puede llegar aquí con solo el resumen ligero.
			ensureDungeonLoaded(store.selectedDungeon).then(() => nextTick(() => { renderPreview(); fitToView(); renderItemPreview(); }));
			loadDungeonTextures();
		});
		onUnmounted(() => { window.removeEventListener('keydown', onKey); window.removeEventListener('mouseup', endStroke); autosave.stop(); });

		return {
			store, DUN_TILES: dunTiles, TILE_GROUPS: tileGroups, TILE_MAP: tileMap, WALL_TYPES, FLOOR_TEX, TEX_SWATCH, WALL_SWATCH, TARGET_ACTIONS,
			floorIdx, brush, painting, sel, show3D, stack3D, zoom, newDunId,
			showCreateDunModal, newDunName, newDunIdTouched, newDunPreset, openCreateModal, onNewDunNameInput, submitCreateDungeon,
			drawMode, rectStart, rectEnd, isInRect, fillEntireFloor,
			regionSel, clipboard, pasteHover, isInPastePreview, copyRegion, clearRegionSel, pasteAt,
			rotateClipboardCW, mirrorClipboardH,
			inLightRadius, rotatePendingOrientation,
			gridCanvasWrap, previewCanvas, itemPreviewCanvas, previewModelUrl,
			zoomBy, fitToView, onWheelZoom,
			brushConfig, setBrushConfig, pickCell, brushMeta, brushCaps, selCaps,
			dungeonTextures, importDungeonTexture, defaultTextureUrl,
			dungeonIds, dun, floors, floor, selCell, selMeta,
			enemyIds, npcIds, itemIds, cinematicOptions, inIds, worldPlacements, goToMap, enemySpriteUrl,
			canUndo: history.canUndo, canRedo: history.canRedo, doUndo, doRedo,
			savedText: autosave.savedAgoText, saveFailed: autosave.saveFailed, dungeonLoading,
			confirmDialog, onConfirmDialogConfirm, onConfirmDialogCancel,
			createDungeon, createDungeonWithTemplate, duplicateDungeon, deleteDungeon, syncToIds,
			setMeta, setName, setPool,
			addFloor, removeFloor, renameFloor, selectFloor, resizeFloor,
			// Acordeón de secciones del inspector izquierdo
			dunSections, toggleDunSec, collapseAllDunSections, expandAllDunSections,
			// Redimensionado de mazmorra (4 lados con preview)
			showResize, resize, resizeAllFloors, resizeFillTile, newW, newH, resizeValid, resizeDirty, coordShift,
			bump, resetResize, removedNonEmpty, preview, applyResize,
			ROOM_PRESETS, applyRoomPreset,
			beginStroke, overCell, endStroke, selectCell, moveSelectedCell,
			setCellProp, setTeleportTarget, markSpawnHere, isSpawn,
			newPortalName, addPortal, removePortal, setPortalSpawn, setPortalHere,
			setChestGold, addChestItem, removeChestItem, setChestItem,
			toggleExitTo, setExitTo,
			cellPx, cellStyle, cellIcon, cellTitle, tilesInGroup: (g) => dunTiles.value.filter(t => t.group === g),
			doSave: () => save(false),
			// Fase 6 — biblioteca de assets
			assets, activeAsset, showAssets, saveAssetName,
			selectTile, selectAsset, clearAsset, saveCurrentAsAsset,
			// — props personalizados (import .glb)
			propName, propIcon, propSolid, propFileName, importing, propTiles,
			onPropFile, importProp, deleteProp,
			// — kits de objetos inteligentes
			ELEMENTS, kitsMeta, kitGroups, selPieceDef, selectKitPiece, pieceUsesElement,
			// Fase 1/2 (Task 5) — paleta unificada por tema (búsqueda + colapso)
			paletteSearch, paletteSections, isSectionOpen, toggleSection, collapseAllSections, expandAllSections, highlightMatch,
			showPaletteNewBadge, dismissPaletteNewBadge,
			// — prefabs de salas
			DUNGEON_PREFABS, selPrefabId, stampPrefab,
			// Fase 6 — elementos interactivos con estados/IDs
			isActuator, isStateful, stateOptionsFor, elementIds, linkableTargets, brokenTargets,
			setEid, setState, addTarget, removeTarget, setTarget,
			dungeonIssues, dungeonIssueCount, jumpToIssue,
			walkthroughOpen, dungeonWizardOpen,
			// Task 3 — Atmósfera y Temática 3D
			atmoOpen, toggleAtmo, musicPreviewUrl, setFogEnabled,
			ENV_THEME_OPTIONS, ENV_SKY_OPTIONS, ENV_VOID_OPTIONS,
			getI18n, getI18nFallback, getI18nDisplay, setI18n,
			onSelectTemplate,
		};
	},
	template: TEMPLATE,
};
