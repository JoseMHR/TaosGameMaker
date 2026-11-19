// components/MediaLibrary.js
// ─────────────────────────────────────────────────────────────────────────────
// BIBLIOTECA GLOBAL DE MEDIOS / ASSET EXPLORER (Task 5, Fase 3). Explorador
// centralizado de TODOS los assets del proyecto (sprites, fondos, modelos 3D,
// audio), reutilizando fs.js (listAssets/assetUrl/uploadAsset/deleteAsset,
// mismas rutas que ya usan EnemiesManager/NpcEditor/DungeonEditor/etc., así
// que no hay dos fuentes de verdad para "dónde vive cada asset").
//
// · Sprites/Fondos: vista previa de imagen.
// · Modelos 3D (.glb): <model-viewer> (ya vendorizado globalmente, ver
//   index.html / DungeonEditor.js).
// · Audio (.ogg/.mp3/.wav): reproductor con espectro en vivo (Web Audio API).
// · Subida por Drag & Drop, con botón opcional de "Procesar imagen" que llama
//   al nuevo endpoint /api/process_image (envuelve tools/process_image.py) en
//   el propio servidor de assets.
// ─────────────────────────────────────────────────────────────────────────────
import { ref, computed, watch, onMounted, onUnmounted, nextTick } from 'https://unpkg.com/vue@3/dist/vue.esm-browser.prod.js';
import * as FS from '../fs.js';
import { flash } from '../store.js';

const CATEGORIES = [
	{
		id: 'sprites', label: 'Sprites 2D', icon: '🧍', mediaType: 'image',
		kinds: [
			{ kind: 'npc', label: 'NPCs / Retratos' },
			{ kind: 'enemy', label: 'Enemigos' },
			{ kind: 'item', label: 'Objetos' },
			{ kind: 'skill', label: 'Habilidades' },
		],
	},
	{
		id: 'backgrounds', label: 'Fondos e Ilustraciones', icon: '🖼️', mediaType: 'image',
		kinds: [
			{ kind: 'bg', label: 'Novela Visual' },
			{ kind: 'combat_bg', label: 'Combate' },
			{ kind: 'terrain', label: 'Terreno (mapa)' },
		],
	},
	{
		id: 'audio', label: 'Audio y Música', icon: '🎵', mediaType: 'audio',
		kinds: [
			{ kind: 'music', label: 'Música (BGM)' },
			{ kind: 'sfx', label: 'Efectos (SFX)' },
		],
	},
];

const EXT_BY_TYPE = { image: ['.png', '.jpg', '.jpeg'], model: ['.glb', '.obj'], audio: ['.ogg', '.mp3', '.wav'] };
const MIME_BY_EXT = { '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.glb': 'model/gltf-binary', '.obj': 'text/plain', '.ogg': 'audio/ogg', '.mp3': 'audio/mpeg', '.wav': 'audio/wav' };

function extOf(name) { const m = /\.[a-z0-9]+$/i.exec(name || ''); return m ? m[0].toLowerCase() : ''; }

export default {
	name: 'MediaLibrary',
	setup() {
		const activeCategoryId = ref(CATEGORIES[0].id);
		const activeCategory = computed(() => CATEGORIES.find(c => c.id === activeCategoryId.value) || CATEGORIES[0]);
		const activeKind = ref(CATEGORIES[0].kinds[0].kind);
		watch(activeCategoryId, () => { activeKind.value = activeCategory.value.kinds[0].kind; selected.value = null; });

		const search = ref('');
		const files = ref([]);
		const loading = ref(false);
		async function reload() {
			loading.value = true;
			try { files.value = await FS.listAssets(activeKind.value); } catch (_) { files.value = []; }
			loading.value = false;
		}
		watch(activeKind, reload, { immediate: true });

		const filteredFiles = computed(() => {
			const q = search.value.trim().toLowerCase();
			const list = q ? files.value.filter(f => f.toLowerCase().includes(q)) : files.value.slice();
			return list.sort();
		});

		const selected = ref(null);
		const selectedUrl = computed(() => selected.value ? FS.assetUrl(activeKind.value, selected.value) : '');

		function select(name) { selected.value = name; }

		// ── Drag & Drop / subida ────────────────────────────────────────────────
		const isDragging = ref(false);
		const uploading = ref(false);
		async function uploadFiles(fileList) {
			const type = activeCategory.value.mediaType;
			const allowed = EXT_BY_TYPE[type] || [];
			uploading.value = true;
			try {
				for (const file of fileList) {
					const ext = extOf(file.name);
					if (!allowed.includes(ext)) { flash('⚠️ Extensión no admitida en "' + activeCategory.value.label + '": ' + file.name); continue; }
					const buf = await file.arrayBuffer();
					try {
						await FS.uploadAsset(activeKind.value, file.name, buf, MIME_BY_EXT[ext] || 'application/octet-stream');
						flash('✅ Subido: ' + file.name);
					} catch (e) { flash('❌ ' + file.name + ': ' + e.message); }
				}
			} finally {
				uploading.value = false;
				await reload();
			}
		}
		function onDrop(e) {
			isDragging.value = false;
			if (e.dataTransfer && e.dataTransfer.files && e.dataTransfer.files.length) uploadFiles(e.dataTransfer.files);
		}
		function onFilePick(e) { if (e.target.files && e.target.files.length) uploadFiles(e.target.files); e.target.value = ''; }

		// ── Procesado server-side (tools/process_image.py) ──────────────────────
		const processing = ref(false);
		async function processSelected(kind) {
			if (!selected.value) return;
			processing.value = true;
			try {
				await FS.processImage(activeKind.value, selected.value, kind);
				flash('🪄 Procesado: ' + selected.value);
			} catch (e) {
				flash('❌ Error al procesar: ' + e.message);
			} finally {
				processing.value = false;
			}
		}

		async function removeSelected() {
			if (!selected.value) return;
			if (!confirm('¿Eliminar "' + selected.value + '" de assets/? Esta acción no se puede deshacer.')) return;
			try {
				await FS.deleteAsset(activeKind.value, selected.value);
				flash('🗑️ Eliminado: ' + selected.value);
				selected.value = null;
				await reload();
			} catch (e) { flash('❌ ' + e.message); }
		}

		// ── Espectro de audio en vivo (Web Audio API) ───────────────────────────
		const audioEl = ref(null);
		const spectrumCanvas = ref(null);
		let audioCtx = null, analyser = null, sourceNode = null, rafId = null;
		function ensureAudioGraph() {
			if (audioCtx || !audioEl.value) return;
			try {
				audioCtx = new (window.AudioContext || window.webkitAudioContext)();
				sourceNode = audioCtx.createMediaElementSource(audioEl.value);
				analyser = audioCtx.createAnalyser();
				analyser.fftSize = 128;
				sourceNode.connect(analyser);
				analyser.connect(audioCtx.destination);
			} catch (_) { /* Web Audio no disponible: el <audio> nativo sigue funcionando igualmente. */ }
		}
		function drawSpectrum() {
			rafId = requestAnimationFrame(drawSpectrum);
			const canvas = spectrumCanvas.value;
			if (!canvas || !analyser) return;
			const ctx = canvas.getContext('2d');
			const data = new Uint8Array(analyser.frequencyBinCount);
			analyser.getByteFrequencyData(data);
			const w = canvas.width, h = canvas.height;
			ctx.clearRect(0, 0, w, h);
			const barW = w / data.length;
			for (let i = 0; i < data.length; i++) {
				const barH = (data[i] / 255) * h;
				ctx.fillStyle = 'rgba(61,214,255,' + (0.35 + 0.65 * (data[i] / 255)) + ')';
				ctx.fillRect(i * barW, h - barH, Math.max(1, barW - 1), barH);
			}
		}
		function onAudioPlay() { ensureAudioGraph(); if (audioCtx && audioCtx.state === 'suspended') audioCtx.resume(); if (!rafId) drawSpectrum(); }
		onUnmounted(() => { if (rafId) cancelAnimationFrame(rafId); if (audioCtx) audioCtx.close().catch(() => {}); });

		return {
			CATEGORIES, activeCategoryId, activeCategory, activeKind, search, filteredFiles, loading,
			selected, selectedUrl, select, isDragging, uploading, onDrop, onFilePick,
			processing, processSelected, removeSelected,
			audioEl, spectrumCanvas, onAudioPlay,
			assetUrl: FS.assetUrl,
		};
	},
	template: `
	<div class="media-lib">
		<aside class="media-lib__side">
			<h3 class="sec">📁 Biblioteca de Medios</h3>
			<button v-for="c in CATEGORIES" :key="c.id" class="media-lib__catbtn" :class="{ active: activeCategoryId===c.id }" @click="activeCategoryId=c.id">
				<span>{{ c.icon }}</span> {{ c.label }}
			</button>
			<div class="media-lib__kinds">
				<button v-for="k in activeCategory.kinds" :key="k.kind" class="btn sm" :class="activeKind===k.kind ? 'primary' : 'ghost'" @click="activeKind=k.kind">{{ k.label }}</button>
			</div>
		</aside>

		<section class="media-lib__grid-wrap"
			@dragover.prevent="isDragging=true" @dragleave.prevent="isDragging=false" @drop.prevent="onDrop">
			<div class="media-lib__toolbar">
				<input class="input" type="search" v-model="search" placeholder="Buscar fichero…" />
				<label class="btn secondary sm" style="cursor:pointer">
					📤 Subir<input type="file" multiple style="display:none" @change="onFilePick" />
				</label>
				<span class="muted" v-if="uploading">Subiendo…</span>
			</div>
			<div class="media-lib__grid" :class="{ 'media-lib__grid--bg': activeCategory.id === 'backgrounds', 'media-lib__grid--audio': activeCategory.id === 'audio' }">
				<div v-for="f in filteredFiles" :key="f" class="media-lib__item" :class="{ active: selected===f, 'is-bg': activeCategory.id === 'backgrounds', 'is-audio': activeCategory.id === 'audio' }" @click="select(f)" @keydown.enter="select(f)" role="button" tabindex="0" :title="f">
					<div v-if="activeCategory.mediaType==='image'" class="media-lib__thumb-wrap" :class="{ 'is-bg': activeCategory.id === 'backgrounds' }">
						<img :src="assetUrl(activeKind, f)" :alt="f" loading="lazy" />
					</div>
					<div v-else class="media-lib__audio-item-icon">
						<span>{{ activeKind === 'music' ? '🎵' : '🔊' }}</span>
					</div>
					<span class="media-lib__name mono">{{ f }}</span>
				</div>
				<p v-if="!loading && !filteredFiles.length" class="muted" style="padding:16px">Sin ficheros. Arrastra alguno aquí para subirlo.</p>
			</div>
			<div v-if="isDragging" class="media-lib__dropzone-overlay">
				<div class="dropzone-icon">📥</div>
				<p>Suelta para subir a <b>{{ activeKind }}</b></p>
			</div>
		</section>

		<section class="media-lib__preview">
			<template v-if="!selected">
				<p class="muted">Selecciona un fichero para previsualizarlo.</p>
			</template>
			<template v-else>
				<h4 class="sec mono" style="word-break:break-all">{{ selected }}</h4>
				<img v-if="activeCategory.mediaType==='image'" :src="selectedUrl" class="media-lib__preview-img" />
				<div v-else class="media-lib__audio">
					<audio ref="audioEl" :src="selectedUrl" controls @play="onAudioPlay" style="width:100%"></audio>
					<canvas ref="spectrumCanvas" width="320" height="80" class="media-lib__spectrum"></canvas>
				</div>
				<div class="row gap" style="margin-top:10px">
					<button v-if="activeCategory.mediaType==='image'" class="btn sm secondary" :disabled="processing" @click="processSelected('sprite')" title="Convierte a PNG 32-bit y elimina el fondo (tools/process_image.py --type sprite)">🪄 Procesar (sprite)</button>
					<button v-if="activeCategory.mediaType==='image'" class="btn sm ghost" :disabled="processing" @click="processSelected('background')" title="Solo normaliza a PNG 32-bit (tools/process_image.py --type background)">🪄 Normalizar (fondo)</button>
					<span class="spacer"></span>
					<button class="btn sm err" @click="removeSelected">🗑️ Eliminar</button>
				</div>
			</template>
		</section>
	</div>
	`,
};
