// components/DungeonWalkthroughModal.js
// ─────────────────────────────────────────────────────────────────────────────
// MODO PASEO 3D EN PRIMERA PERSONA (Walkthrough Mode — FASE 3)
//
// Permite explorar la mazmorra en 3D subjetivo (1ª persona) en tiempo real
// con controles WASD, colisiones con paredes, niebla de distancia, minimapa
// interactivo y música ambiental de mazmorra.
// ─────────────────────────────────────────────────────────────────────────────
import { ref, reactive, computed, watch, onMounted, onUnmounted, nextTick } from 'https://unpkg.com/vue@3/dist/vue.esm-browser.prod.js';
import { stopAllGlobalAudio } from '../ui/DsAudioBtn.js';

const MUSIC_MAP = {
	dungeon: 'bgm_dungeon_cave.ogg',
	cave: 'bgm_dungeon_cave.ogg',
	ancient_ruins: 'bgm_ancient_ruins_ambient.ogg',
	arcanium_lab: 'bgm_arcanium_lab_ambient.ogg',
	snow_catacomb: 'bgm_snow_catacomb_ambient.ogg',
	orb_room: 'bgm_orb_room.ogg',
	world: 'bgm_world.ogg',
	menu: 'bgm_menu.ogg',
	combat: 'bgm_combat.ogg',
	city: 'bgm_city.ogg',
};

function resolveMusicUrl(musicKey) {
	if (!musicKey) return '/assets/common/music/bgm_dungeon_cave.ogg';
	if (MUSIC_MAP[musicKey]) return '/assets/common/music/' + MUSIC_MAP[musicKey];
	if (musicKey.endsWith('.ogg') || musicKey.endsWith('.mp3') || musicKey.endsWith('.wav')) {
		return musicKey.startsWith('/') || musicKey.startsWith('http') ? musicKey : '/assets/common/music/' + musicKey;
	}
	return '/assets/common/music/bgm_dungeon_cave.ogg';
}

export default {
	name: 'DungeonWalkthroughModal',
	props: {
		open: { type: Boolean, default: false },
		dungeon: { type: Object, default: () => null },
		floorIndex: { type: Number, default: 0 },
		dungeonId: { type: String, default: '' },
	},
	emits: ['close'],
	setup(props, { emit }) {
		const canvasRef = ref(null);
		const isMuted = ref(false);
		let bgmAudio = null;
		let animId = null;

		// Estado del jugador
		const player = reactive({
			x: 2.5,
			y: 2.5,
			dir: 0, // ángulo en radianes
			fov: Math.PI / 3, // 60 grados
		});

		const keysDown = reactive({});

		const currentFloor = computed(() => {
			const d = props.dungeon;
			if (!d || !d.floors || !d.floors[props.floorIndex]) return null;
			return d.floors[props.floorIndex];
		});

		const gridW = computed(() => currentFloor.value?.w ?? currentFloor.value?.width ?? 10);
		const gridH = computed(() => currentFloor.value?.h ?? currentFloor.value?.height ?? 10);
		const cells = computed(() => currentFloor.value?.cells || []);

		function getCell(x, y) {
			const gx = Math.floor(x);
			const gy = Math.floor(y);
			if (gx < 0 || gx >= gridW.value || gy < 0 || gy >= gridH.value) return { t: 'wall' };
			const raw = cells.value;
			if (Array.isArray(raw)) {
				if (raw[gy] && raw[gy][gx]) return raw[gy][gx];
			} else if (raw && typeof raw === 'object') {
				const k = gx + ',' + gy;
				if (raw[k]) return raw[k];
			}
			return { t: 'floor' };
		}

		function isSolid(x, y) {
			const c = getCell(x, y);
			return c.t === 'wall' || c.t === 'door_locked' || c.t === 'void' || (c.t === 'door' && c.state === 'closed');
		}

		// ── Audio ──
		function startBgm() {
			if (isMuted.value) return;
			stopBgm();
			try {
				const musicUrl = resolveMusicUrl(props.dungeon?.music);
				bgmAudio = new Audio(musicUrl);
				bgmAudio.loop = true;
				bgmAudio.volume = 0.35;
				bgmAudio.play().catch(() => {});
			} catch (e) {}
		}

		function stopBgm() {
			if (bgmAudio) {
				bgmAudio.pause();
				bgmAudio.currentTime = 0;
				bgmAudio = null;
			}
		}

		function toggleMute() {
			isMuted.value = !isMuted.value;
			if (isMuted.value) stopBgm();
			else startBgm();
		}

		// ── Bucle de Renderizado 3D (Raycasting en tiempo real) ──
		function renderFrame() {
			const cv = canvasRef.value;
			if (!cv) return;
			const ctx = cv.getContext('2d');
			const W = cv.width;
			const H = cv.height;

			// Movimiento del jugador
			const moveSpeed = 0.055;
			const rotSpeed = 0.045;

			if (keysDown['KeyA'] || keysDown['ArrowLeft']) player.dir -= rotSpeed;
			if (keysDown['KeyD'] || keysDown['ArrowRight']) player.dir += rotSpeed;

			let dx = 0;
			let dy = 0;
			if (keysDown['KeyW'] || keysDown['ArrowUp']) {
				dx += Math.cos(player.dir) * moveSpeed;
				dy += Math.sin(player.dir) * moveSpeed;
			}
			if (keysDown['KeyS'] || keysDown['ArrowDown']) {
				dx -= Math.cos(player.dir) * moveSpeed;
				dy -= Math.sin(player.dir) * moveSpeed;
			}

			// Colisiones
			if (!isSolid(player.x + dx, player.y)) player.x += dx;
			if (!isSolid(player.x, player.y + dy)) player.y += dy;

			// Fondo: Techo y Suelo con degradado de niebla
			const skyGrad = ctx.createLinearGradient(0, 0, 0, H / 2);
			skyGrad.addColorStop(0, '#060913');
			skyGrad.addColorStop(1, '#111827');
			ctx.fillStyle = skyGrad;
			ctx.fillRect(0, 0, W, H / 2);

			const floorGrad = ctx.createLinearGradient(0, H / 2, 0, H);
			floorGrad.addColorStop(0, '#111827');
			floorGrad.addColorStop(1, '#05070c');
			ctx.fillStyle = floorGrad;
			ctx.fillRect(0, H / 2, W, H / 2);

			// Raycasting 3D de Paredes (Optimizado a 320 rayos con interpolación)
			const numRays = Math.min(W, 320);
			const rayW = W / numRays;
			const halfFov = player.fov / 2;
			const maxDist = 20;

			for (let i = 0; i < numRays; i++) {
				const rayAngle = player.dir - halfFov + (i / numRays) * player.fov;
				const cosRay = Math.cos(rayAngle);
				const sinRay = Math.sin(rayAngle);

				let dist = 0;
				let hit = false;
				let hitCell = null;
				const step = 0.06;

				while (!hit && dist < maxDist) {
					dist += step;
					const checkX = player.x + cosRay * dist;
					const checkY = player.y + sinRay * dist;
					const cell = getCell(checkX, checkY);
					if (cell.t === 'wall' || cell.t === 'door_locked' || cell.t === 'door_open' || (cell.t === 'door' && cell.state === 'closed')) {
						hit = true;
						hitCell = cell;
					}
				}

				// Corrección de efecto ojo de pez
				const correctedDist = Math.max(0.1, dist * Math.cos(rayAngle - player.dir));
				const wallH = Math.min(H, (H / correctedDist) * 1.1);

				// Sombreado de niebla por distancia
				const fogFactor = Math.min(1, dist / maxDist);
				let r = 75; let g = 85; let b = 110;
				if (hitCell?.t === 'door_locked' || (hitCell?.t === 'door' && hitCell?.state === 'closed')) { r = 180; g = 60; b = 60; }
				else if (hitCell?.t === 'door_open') { r = 60; g = 180; b = 100; }

				r = Math.round(r * (1 - fogFactor));
				g = Math.round(g * (1 - fogFactor));
				b = Math.round(b * (1 - fogFactor));

				ctx.fillStyle = `rgb(${r},${g},${b})`;
				ctx.fillRect(i * rayW, (H - wallH) / 2, rayW + 0.5, wallH);
			}

			// Minimapa 2D en esquina superior derecha
			const miniSize = 100;
			const miniPad = 14;
			const startX = W - miniSize - miniPad;
			const startY = miniPad;

			ctx.fillStyle = 'rgba(10, 14, 24, 0.85)';
			ctx.strokeStyle = 'rgba(59, 130, 246, 0.4)';
			ctx.lineWidth = 1.5;
			ctx.fillRect(startX, startY, miniSize, miniSize);
			ctx.strokeRect(startX, startY, miniSize, miniSize);

			const cellW = miniSize / gridW.value;
			const cellH = miniSize / gridH.value;

			for (let y = 0; y < gridH.value; y++) {
				for (let x = 0; x < gridW.value; x++) {
					const c = getCell(x, y);
					if (c.t === 'wall') {
						ctx.fillStyle = 'rgba(140, 150, 175, 0.8)';
						ctx.fillRect(startX + x * cellW, startY + y * cellH, cellW, cellH);
					} else if (c.t === 'door_locked' || (c.t === 'door' && c.state === 'closed')) {
						ctx.fillStyle = '#ef4444';
						ctx.fillRect(startX + x * cellW, startY + y * cellH, cellW, cellH);
					}
				}
			}

			// Posición y cono del jugador en minimapa
			const pMiniX = startX + player.x * cellW;
			const pMiniY = startY + player.y * cellH;

			ctx.fillStyle = '#38bdf8';
			ctx.beginPath();
			ctx.arc(pMiniX, pMiniY, 3, 0, Math.PI * 2);
			ctx.fill();

			ctx.strokeStyle = 'rgba(56, 189, 248, 0.6)';
			ctx.beginPath();
			ctx.moveTo(pMiniX, pMiniY);
			ctx.lineTo(pMiniX + Math.cos(player.dir) * 12, pMiniY + Math.sin(player.dir) * 12);
			ctx.stroke();

			animId = requestAnimationFrame(renderFrame);
		}

		function onKeyDown(e) {
			keysDown[e.code] = true;
			if (e.key === 'Escape' && props.open) {
				emit('close');
			}
		}

		function onKeyUp(e) {
			keysDown[e.code] = false;
		}

		watch(() => props.open, (isOpen) => {
			if (isOpen) {
				stopAllGlobalAudio();
				let sx = props.dungeon?.spawn?.x != null ? props.dungeon.spawn.x + 0.5 : 2.5;
				let sy = props.dungeon?.spawn?.y != null ? props.dungeon.spawn.y + 0.5 : 2.5;
				if (isSolid(sx, sy)) {
					for (let y = 0; y < gridH.value; y++) {
						let found = false;
						for (let x = 0; x < gridW.value; x++) {
							if (!isSolid(x + 0.5, y + 0.5)) {
								sx = x + 0.5;
								sy = y + 0.5;
								found = true;
								break;
							}
						}
						if (found) break;
					}
				}
				player.x = sx;
				player.y = sy;
				player.dir = 0;
				window.addEventListener('keydown', onKeyDown);
				window.addEventListener('keyup', onKeyUp);
				startBgm();
				nextTick(() => {
					renderFrame();
				});
			} else {
				stopBgm();
				cancelAnimationFrame(animId);
				window.removeEventListener('keydown', onKeyDown);
				window.removeEventListener('keyup', onKeyUp);
			}
		});

		onUnmounted(() => {
			stopBgm();
			cancelAnimationFrame(animId);
			window.removeEventListener('keydown', onKeyDown);
			window.removeEventListener('keyup', onKeyUp);
		});

		return {
			canvasRef, isMuted, player,
			toggleMute,
		};
	},
	template: `
	<div v-if="open" class="modal-backdrop" @click.self="$emit('close')">
		<div class="modal-window dungeon-walkthrough-modal card panel">
			<div class="modal-head">
				<div class="row gap" style="align-items:center">
					<span class="dungeon-3d-badge">🏰 MODO PASEO 3D</span>
					<h3>{{ (typeof dungeon?.name === 'object' ? dungeon?.name?.es : dungeon?.name) || dungeonId }} — Planta {{ floorIndex + 1 }}</h3>
				</div>
				<div class="row gap" style="align-items:center">
					<button class="btn sm ghost" @click="toggleMute">{{ isMuted ? '🔇' : '🔊' }}</button>
					<button class="btn ghost sm modal-close" @click="$emit('close')">✕</button>
				</div>
			</div>

			<div class="dungeon-walkthrough-body">
				<!-- Canvas 3D Principal -->
				<div class="dungeon-3d-viewport-wrap">
					<canvas ref="canvasRef" width="760" height="420" class="dungeon-3d-canvas"></canvas>

					<!-- Guía de Controles Flotante -->
					<div class="dungeon-3d-controls-guide">
						<span>🎮 Controles: <b>W A S D</b> o <b>Flechas</b> para moverte y girar</span>
						<span class="mono">Posición: ({{ player.x.toFixed(1) }}, {{ player.y.toFixed(1) }})</span>
					</div>
				</div>
			</div>
		</div>
	</div>
	`,
};
