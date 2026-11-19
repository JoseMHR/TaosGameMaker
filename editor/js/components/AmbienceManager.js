// components/AmbienceManager.js
// ─────────────────────────────────────────────────────────────────────────────
// Gestor de ambience.json (Fase D): música y clima data-driven. NO es una
// colección `{id->entidad}`, sino un documento único con tres secciones:
//   · music   : { clave -> ruta .ogg }           (p. ej. "world", "dungeon")
//   · terrain : { código_terreno -> { weather, music? } }
//   · weather : { nombre -> { color, count, speed, size, drift, angle } }
// Se edita en su propio panel y marca cambios con markDirty('ambience').
// ─────────────────────────────────────────────────────────────────────────────
import { computed, onMounted, onUnmounted, ref } from 'https://unpkg.com/vue@3/dist/vue.esm-browser.prod.js';
import { store, markDirty, save, terrainsList } from '../store.js';
import { useDocumentHistory } from '../lib/useDocumentHistory.js';
import * as FS from '../fs.js';
import EditorToolbar from './EditorToolbar.js';
import DsAudioBtn from '../ui/DsAudioBtn.js';

const WEATHER_NUM_FIELDS = ['count', 'speed', 'size', 'drift', 'angle'];
// Carpeta real de música (AudioManager.gd / serve.py ASSET_DIRS["music"]).
// `music`/`terrain[].music` guardan la ruta `res://` completa; el picker
// visual trabaja con el nombre de fichero desnudo y convierte en ambos sentidos.
const MUSIC_RES_PREFIX = 'res://assets/common/music/';
function toMusicFile(resPath) { return (resPath || '').startsWith(MUSIC_RES_PREFIX) ? resPath.slice(MUSIC_RES_PREFIX.length) : (resPath || ''); }
function toMusicRes(fileName) { return fileName ? MUSIC_RES_PREFIX + fileName : ''; }
// Tope de partículas SIMULADAS en el preview (el `count` real puede ser mucho
// mayor; esto es solo una vista estilizada, no la simulación exacta del motor).
const PREVIEW_MAX_PARTICLES = 60;

export default {
	name: 'AmbienceManager',
	components: { EditorToolbar, DsAudioBtn },
	setup() {
		// Catálogo de terrenos, derivado de la colección data-driven `store.worldTerrains`
		// (data/world_terrains/<code>.json). Ver terrainsList() en store.js.
		const TERRAINS = computed(() => terrainsList());
		const amb = computed(() => store.ambience || (store.ambience = {}));
		const dirty = computed(() => !!store.dirty.ambience);
		function touch() { markDirty('ambience'); }
		function doSave() { save(false); }

		// Task 5 (1.3): historial de deshacer/rehacer (este editor es un documento
		// único, no una colección {id->entidad}, así que usa useDocumentHistory en
		// vez de useCollection).
		const hist = useDocumentHistory({
			tabId: 'ambience',
			getDoc: () => amb.value,
			setDoc: (v) => { store.ambience = v; touch(); },
		});
		function edit(fn) { hist.edit(fn); touch(); }

		// ── Música ──────────────────────────────────────────────────────────
		// Task 5 (4.1): picker visual (dropdown de ficheros reales en
		// assets/common/music/) en vez de campo de texto libre a ciegas.
		const musicFiles = ref([]);
		onMounted(async () => { try { musicFiles.value = await FS.listAssets('music'); } catch (_) { musicFiles.value = []; } });
		/** Opciones del <select>: los ficheros reales + el actual si no está en la lista (para no perder datos). */
		function musicOptionsFor(currentRes) {
			const cur = toMusicFile(currentRes);
			const opts = musicFiles.value.slice();
			if (cur && !opts.includes(cur)) opts.push(cur);
			return opts.sort();
		}
		const musicKeys = computed(() => Object.keys(amb.value.music || {}));
		function setMusic(key, path) { edit(() => { amb.value.music = amb.value.music || {}; amb.value.music[key] = path; }); }
		function setMusicFile(key, fileName) { setMusic(key, toMusicRes(fileName)); }
		function renameMusic(oldK, newK) {
			newK = (newK || '').trim(); if (!newK || newK === oldK || amb.value.music[newK] !== undefined) return;
			edit(() => { const m = amb.value.music; m[newK] = m[oldK]; delete m[oldK]; });
		}
		function addMusic() { edit(() => { amb.value.music = amb.value.music || {}; let k = 'nueva_pista', n = 1; while (amb.value.music[k] !== undefined) k = 'nueva_pista_' + (++n); amb.value.music[k] = 'res://assets/common/music/bgm_combat.ogg'; }); }
		function removeMusic(key) { edit(() => { delete amb.value.music[key]; }); }

		// ── Terreno → clima ─────────────────────────────────────────────────
		const terrainKeys = computed(() => Object.keys(amb.value.terrain || {}));
		const weatherNames = computed(() => ['none', ...Object.keys(amb.value.weather || {})]);
		function addTerrain(code) {
			edit(() => {
				amb.value.terrain = amb.value.terrain || {};
				const c = code || (TERRAINS.value.find(t => !amb.value.terrain[t.code]) || TERRAINS.value[0]).code;
				amb.value.terrain[c] = { weather: 'none' };
			});
		}
		function setTerrainWeather(code, w) { edit(() => { amb.value.terrain[code].weather = w; }); }
		function setTerrainMusic(code, m) { edit(() => { if (m === '') delete amb.value.terrain[code].music; else amb.value.terrain[code].music = m; }); }
		function setTerrainMusicFile(code, fileName) { setTerrainMusic(code, toMusicRes(fileName)); }
		function removeTerrain(code) { edit(() => { delete amb.value.terrain[code]; }); }

		// ── Clima (partículas) ──────────────────────────────────────────────
		const weatherKeys = computed(() => Object.keys(amb.value.weather || {}));
		function addWeather() { edit(() => { amb.value.weather = amb.value.weather || {}; let k = 'nuevo_clima', n = 1; while (amb.value.weather[k]) k = 'nuevo_clima_' + (++n); amb.value.weather[k] = { color: '#ffffff', count: 120, speed: 100, size: 2, drift: 20, angle: 10 }; }); }
		function renameWeather(oldK, newK) {
			newK = (newK || '').trim(); if (!newK || newK === oldK || amb.value.weather[newK]) return;
			edit(() => { const w = amb.value.weather; w[newK] = w[oldK]; delete w[oldK]; });
		}
		function setWeatherField(key, field, v) { edit(() => { amb.value.weather[key][field] = field === 'color' ? v : (Number(v) || 0); }); }
		function removeWeather(key) { edit(() => { delete amb.value.weather[key]; }); }

		// ── Task 5 (4.1): Canvas Preview interactivo del clima (simula lluvia/
		// nieve/arena según count/speed/drift/size/color/angle). Estilizado, NO es
		// la simulación exacta del motor (ver PREVIEW_MAX_PARTICLES).
		const weatherCanvases = {};   // { key: HTMLCanvasElement }
		const weatherParticles = {}; // { key: [{x,y,vy,drift,size}] }
		function setWeatherCanvas(key, el) { if (el) weatherCanvases[key] = el; else { delete weatherCanvases[key]; delete weatherParticles[key]; } }
		function ensureParticles(key, w, h) {
			const cfg = amb.value.weather[key];
			const n = Math.max(1, Math.min(PREVIEW_MAX_PARTICLES, Math.round((cfg?.count || 20) / 4) || 20));
			let arr = weatherParticles[key];
			if (!arr || arr.length !== n) {
				arr = []; for (let i = 0; i < n; i++) arr.push({ x: Math.random() * w, y: Math.random() * h, seed: Math.random() * 1000 });
				weatherParticles[key] = arr;
			}
			return arr;
		}
		let weatherRafId = null;
		function tickWeatherPreviews() {
			weatherRafId = requestAnimationFrame(tickWeatherPreviews);
			for (const key of Object.keys(weatherCanvases)) {
				const canvas = weatherCanvases[key];
				const cfg = amb.value.weather[key];
				if (!canvas || !cfg) continue;
				const w = canvas.width, h = canvas.height;
				const ctx = canvas.getContext('2d');
				ctx.clearRect(0, 0, w, h);
				ctx.fillStyle = 'rgba(10,14,22,0.9)'; ctx.fillRect(0, 0, w, h);
				const particles = ensureParticles(key, w, h);
				const speed = (cfg.speed || 50) / 50;      // px/frame aprox., normalizado
				const drift = (cfg.drift || 0) / 50;
				const angleRad = ((cfg.angle || 0) * Math.PI) / 180;
				const size = Math.max(1, Math.min(6, cfg.size || 2));
				ctx.fillStyle = cfg.color || '#dbe8f0';
				for (const p of particles) {
					p.y += speed * 1.6;
					p.x += Math.sin(p.seed + p.y * 0.02) * drift * 0.6 + Math.sin(angleRad) * speed * 0.5;
					if (p.y > h) { p.y = -4; p.x = Math.random() * w; }
					if (p.x > w) p.x -= w; else if (p.x < 0) p.x += w;
					ctx.beginPath(); ctx.arc(p.x, p.y, size / 2, 0, Math.PI * 2); ctx.fill();
				}
			}
		}
		onMounted(() => { tickWeatherPreviews(); });
		onUnmounted(() => { if (weatherRafId) cancelAnimationFrame(weatherRafId); });

		return {
			store, amb, dirty, doSave, TERRAINS, WEATHER_NUM_FIELDS,
			canUndo: hist.canUndo, canRedo: hist.canRedo, undo: hist.undo, redo: hist.redo,
			musicKeys, setMusic, setMusicFile, musicOptionsFor, toMusicFile, renameMusic, addMusic, removeMusic,
			terrainKeys, weatherNames, addTerrain, setTerrainWeather, setTerrainMusic, setTerrainMusicFile, removeTerrain,
			weatherKeys, addWeather, renameWeather, setWeatherField, removeWeather, setWeatherCanvas,
		};
	},
	template: `
	<div class="manager" style="display:block; overflow:auto">
		<section class="editor-pane">
			<editor-toolbar :dirty="dirty" :has-current="true" :can-undo="canUndo" :can-redo="canRedo"
				:show="{ undo:true, copy:false, paste:false, duplicate:false, remove:false, save:true }"
				@undo="undo()" @redo="redo()" @save="doSave()"></editor-toolbar>

			<h3 class="sec">🎵 Música</h3>
			<p class="muted" style="margin:0 0 8px">Clave lógica → ruta del <span class="mono">.ogg</span>. Se referencia desde <span class="mono">terrain</span> y desde mazmorras (<span class="mono">music</span>).</p>
			<div class="skills-list">
				<div class="card panel" style="margin-bottom:8px; padding:10px" v-for="k in musicKeys" :key="k">
					<div class="form-grid" style="align-items:end">
						<label>Clave <input class="input mono" type="text" :value="k" @change="renameMusic(k, $event.target.value)" /></label>
						<label class="col-span-2">Pista (assets/common/music/)
							<select class="input" :value="toMusicFile(amb.music[k])" @change="setMusicFile(k, $event.target.value)">
								<option v-for="f in musicOptionsFor(amb.music[k])" :key="f" :value="f">{{ f }}</option>
							</select>
						</label>
						<div class="row gap" style="align-items:center">
							<ds-audio-btn :src="amb.music[k]" size="sm"></ds-audio-btn>
							<button class="btn sm err" @click="removeMusic(k)">🗑️</button>
						</div>
					</div>
				</div>
			</div>
			<button class="btn secondary sm" @click="addMusic">➕ Añadir pista</button>

			<h3 class="sec" style="margin-top:18px">🌦️ Terreno → clima</h3>
			<p class="muted" style="margin:0 0 8px">Al pisar un terreno con clima, aparece el overlay. <span class="mono">music</span> es opcional (sobreescribe la de mundo).</p>
			<div class="skills-list">
				<div class="card panel" style="margin-bottom:8px; padding:10px" v-for="code in terrainKeys" :key="code">
					<div class="form-grid" style="align-items:end">
						<label>Terreno <input class="input mono" type="text" :value="code" disabled /></label>
						<label>Clima
							<select class="input" :value="amb.terrain[code].weather" @change="setTerrainWeather(code, $event.target.value)">
								<option v-for="w in weatherNames" :key="w" :value="w">{{ w }}</option>
							</select>
						</label>
						<label>Música (opcional)
							<select class="input" :value="toMusicFile(amb.terrain[code].music)" @change="setTerrainMusicFile(code, $event.target.value)">
								<option value="">(hereda mundo)</option>
								<option v-for="f in musicOptionsFor(amb.terrain[code].music)" :key="f" :value="f">{{ f }}</option>
							</select>
						</label>
						<div class="row gap" style="align-items:center">
							<ds-audio-btn v-if="amb.terrain[code].music" :src="amb.terrain[code].music" size="sm"></ds-audio-btn>
							<button class="btn sm err" @click="removeTerrain(code)">🗑️</button>
						</div>
					</div>
				</div>
			</div>
			<button class="btn secondary sm" @click="addTerrain('')">➕ Añadir terreno</button>

			<template v-if="store.expertMode">
			<h3 class="sec" style="margin-top:18px">❄️ Climas <span class="muted" style="font-weight:400">(partículas, experto)</span></h3>
			<div class="skills-list">
				<div class="card panel" style="margin-bottom:8px; padding:10px" v-for="k in weatherKeys" :key="k">
					<div class="flex" style="justify-content:space-between; margin-bottom:6px">
						<input class="input mono" style="max-width:200px" type="text" :value="k" @change="renameWeather(k, $event.target.value)" />
						<button class="btn sm err" @click="removeWeather(k)">🗑️</button>
					</div>
					<div class="flex" style="gap:12px; align-items:flex-start">
						<div class="form-grid" style="flex:1">
							<label>color <input class="input" type="text" :value="amb.weather[k].color" @input="setWeatherField(k, 'color', $event.target.value)" placeholder="#dbe8f0" /></label>
							<label v-for="f in WEATHER_NUM_FIELDS" :key="f">{{ f }}
								<input class="input num" type="number" :value="amb.weather[k][f]" @input="setWeatherField(k, f, $event.target.value)" />
							</label>
						</div>
						<div>
							<div class="muted" style="font-size:10px; margin-bottom:4px; text-align:center">Preview en vivo</div>
							<canvas :ref="el => setWeatherCanvas(k, el)" width="150" height="90" class="weather-preview-canvas"></canvas>
						</div>
					</div>
				</div>
			</div>
			<button class="btn secondary sm" @click="addWeather">➕ Añadir clima</button>
			</template>
		</section>
	</div>
	`,
};
