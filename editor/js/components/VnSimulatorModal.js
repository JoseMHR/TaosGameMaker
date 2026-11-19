// components/VnSimulatorModal.js
// ─────────────────────────────────────────────────────────────────────────────
// EMULADOR INTERACTIVO DE NOVELA VISUAL & NARRATIVA (WYSIWYG en Vivo).
//
// Simula fielmente el comportamiento de NarrativeOverlay.gd de Godot:
//   · Pantalla 16:9 con fondo de escenario real (assets/vn/bg/)
//   · Retratos de personajes a escala real con animaciones
//   · Caja de diálogo translúcida con typewriter animable
//   · Botones de decisión interactivos para saltos de nodo
//   · Emulación de variables de estado (oro, facetas, items)
//   · Reproducción de música ambiental (BGM) y efectos de sonido (SFX)
// ─────────────────────────────────────────────────────────────────────────────
import { ref, reactive, computed, watch, onUnmounted, nextTick } from 'https://unpkg.com/vue@3/dist/vue.esm-browser.prod.js';
import { getI18nDisplay } from '../store.js';
import { stopAllGlobalAudio } from '../ui/DsAudioBtn.js';

export default {
	name: 'VnSimulatorModal',
	props: {
		open: { type: Boolean, default: false },
		scene: { type: Object, default: () => null },
		sceneId: { type: String, default: '' },
		defaultBg: { type: String, default: 'bg_city_celestia_archmage.png' },
		defaultMusic: { type: String, default: 'bgm_city.ogg' },
	},
	emits: ['close'],
	setup(props, { emit }) {
		const currentNodeId = ref('');
		const isTyping = ref(false);
		const revealedChars = ref(0);
		const currentFullText = ref('');
		const history = ref([]);
		const showHistory = ref(false);
		const showState = ref(false);
		const autoMode = ref(false);
		const isFinished = ref(false);
		const activeBg = ref(props.defaultBg);
		const isMuted = ref(false);

		// Estado global simulado
		const simState = reactive({
			gold: 150,
			xp: 20,
			level: 1,
			facetas: { amabilidad: 2, valor: 1, ingenio: 3 },
			items: { pocion_vida: 2, madera: 5 },
			flags: {},
		});

		let typeInterval = null;
		let autoTimer = null;
		let bgmAudio = null;

		const nodes = computed(() => props.scene?.nodes || {});
		const currentNode = computed(() => {
			if (!currentNodeId.value) return null;
			return nodes.value[currentNodeId.value] || null;
		});

		const currentSpeaker = computed(() => {
			const n = currentNode.value;
			if (!n) return '';
			return getI18nDisplay(n.speaker) || '';
		});

		const currentPortrait = computed(() => {
			const n = currentNode.value;
			if (!n) return '';
			return n.portrait || '';
		});

		const isEmojiPortrait = computed(() => {
			const p = currentPortrait.value;
			return p && p.length <= 4 && !p.includes('.');
		});

		const portraitImgUrl = computed(() => {
			const p = currentPortrait.value;
			if (!p || isEmojiPortrait.value) return '';
			if (p.startsWith('http://') || p.startsWith('https://') || p.startsWith('/')) return p;
			return '/assets/vn/npcs/' + p;
		});

		const bgImgUrl = computed(() => {
			const bg = activeBg.value || props.defaultBg;
			if (!bg) return '/assets/vn/bg/bg_city_celestia_archmage.png';
			if (bg.startsWith('http://') || bg.startsWith('https://') || bg.startsWith('/')) return bg;
			return '/assets/vn/bg/' + bg;
		});

		// ── Control de Audio ──
		function playSfx(sfxId) {
			if (isMuted.value || !sfxId) return;
			try {
				const sound = new Audio('/assets/common/sfx/' + sfxId + '.ogg');
				sound.volume = 0.6;
				sound.play().catch(() => {});
			} catch (e) {}
		}

		function startBgm() {
			if (isMuted.value) return;
			stopBgm();
			try {
				const track = props.defaultMusic || 'bgm_city.ogg';
				bgmAudio = new Audio('/assets/common/music/' + track);
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

		// ── Avance del Typewriter ──
		function startTypewriter(text) {
			clearInterval(typeInterval);
			currentFullText.value = text || '';
			revealedChars.value = 0;
			isTyping.value = true;

			if (!text) {
				isTyping.value = false;
				checkAutoAdvance();
				return;
			}

			const speed = 25; // ms por carácter
			typeInterval = setInterval(() => {
				revealedChars.value++;
				if (revealedChars.value >= currentFullText.value.length) {
					completeTypewriter();
				}
			}, speed);
		}

		function completeTypewriter() {
			clearInterval(typeInterval);
			revealedChars.value = currentFullText.value.length;
			isTyping.value = false;
			checkAutoAdvance();
		}

		const displayedText = computed(() => {
			return currentFullText.value.slice(0, revealedChars.value);
		});

		// ── Ejecución de Operaciones de Estado (ops) ──
		function applyOps(opsStr) {
			if (!opsStr) return;
			const parts = opsStr.split(';');
			for (let p of parts) {
				p = p.trim();
				if (!p) continue;
				if (p.startsWith('gold:')) {
					const val = parseInt(p.replace('gold:', '')) || 0;
					simState.gold += val;
				} else if (p.startsWith('item:')) {
					const [item, qty] = p.replace('item:', '').split('=');
					const q = parseInt(qty) || 1;
					simState.items[item] = (simState.items[item] || 0) + q;
				} else if (p.startsWith('faceta:')) {
					const [f, val] = p.replace('faceta:', '').split('=');
					const v = parseInt(val) || 1;
					if (simState.facetas[f] !== undefined) simState.facetas[f] += v;
				} else if (p.startsWith('flag:')) {
					const f = p.replace('flag:', '').trim();
					simState.flags[f] = true;
				}
			}
		}

		// ── Carga y Proceso de Nodo ──
		function loadNode(nid) {
			clearTimeout(autoTimer);
			if (!nid || nid === 'end' || !nodes.value[nid]) {
				isFinished.value = true;
				return;
			}

			currentNodeId.value = nid;
			const n = nodes.value[nid];

			if (n.kind === 'say') {
				const txt = getI18nDisplay(n.text) || '';
				history.value.push({
					speaker: currentSpeaker.value || 'Narrador',
					text: txt,
					portrait: currentPortrait.value,
				});
				if (n.fx && n.fx.sfx) playSfx(n.fx.sfx);
				startTypewriter(txt);
			} else if (n.kind === 'choice') {
				isTyping.value = false;
				currentFullText.value = getI18nDisplay(n.prompt) || '¿Qué decides?';
				revealedChars.value = currentFullText.value.length;
			} else if (n.kind === 'state') {
				applyOps(n.ops);
				loadNode(n.next || 'end');
			} else if (n.kind === 'event') {
				loadNode(n.next || 'end');
			} else if (n.kind === 'flow') {
				if (n.op === 'goto') loadNode(n.to || 'end');
				else if (n.op === 'end') isFinished.value = true;
				else loadNode(n.next || 'end');
			}
		}

		function onAdvance() {
			if (isFinished.value) return;
			if (isTyping.value) {
				completeTypewriter();
				return;
			}

			const n = currentNode.value;
			if (!n) return;

			if (n.kind === 'say') {
				const nextId = n.next || 'end';
				loadNode(nextId);
			}
		}

		function chooseOption(opt) {
			history.value.push({
				speaker: 'Jugador (Elección)',
				text: getI18nDisplay(opt.text) || '',
				isChoice: true,
			});
			playSfx('click');
			loadNode(opt.to || 'end');
		}

		function checkAutoAdvance() {
			if (autoMode.value && !isFinished.value && currentNode.value?.kind === 'say') {
				autoTimer = setTimeout(() => {
					onAdvance();
				}, 1600);
			}
		}

		function toggleAuto() {
			autoMode.value = !autoMode.value;
			if (autoMode.value && !isTyping.value) checkAutoAdvance();
		}

		function restart() {
			isFinished.value = false;
			history.value = [];
			const entry = props.scene?.entry || 'n1';
			loadNode(entry);
		}

		function closeModal() {
			stopBgm();
			clearInterval(typeInterval);
			clearTimeout(autoTimer);
			emit('close');
		}

		function onKey(e) {
			if (e.key === 'Escape' && props.open) {
				e.preventDefault();
				closeModal();
			}
		}

		watch(() => props.open, (isOpen) => {
			if (isOpen) {
				stopAllGlobalAudio();
				restart();
				startBgm();
				window.addEventListener('keydown', onKey);
			} else {
				stopBgm();
				clearInterval(typeInterval);
				clearTimeout(autoTimer);
				window.removeEventListener('keydown', onKey);
			}
		});

		onUnmounted(() => {
			stopBgm();
			clearInterval(typeInterval);
			clearTimeout(autoTimer);
			window.removeEventListener('keydown', onKey);
		});

		return {
			currentNodeId, currentNode, currentSpeaker, currentPortrait,
			isEmojiPortrait, portraitImgUrl, bgImgUrl, activeBg,
			isTyping, displayedText, history, showHistory, showState, simState,
			autoMode, isFinished, isMuted,
			onAdvance, chooseOption, toggleAuto, toggleMute, restart, closeModal,
			getI18nDisplay,
		};
	},
	template: `
	<div v-if="open" class="modal-backdrop vn-sim-backdrop" @click.self="closeModal">
		<div class="vn-sim-window card panel">
			<!-- Barra de herramientas superior -->
			<header class="vn-sim-topbar">
				<div class="vn-sim-title">
					<span class="vn-sim-badge">🎬 SIMULADOR VISUAL NOVEL</span>
					<strong>{{ getI18nDisplay(scene?.meta?.title) || sceneId || 'Escena' }}</strong>
					<span class="vn-sim-node-tag mono">Nodo: {{ currentNodeId }}</span>
				</div>
				<div class="vn-sim-actions">
					<button class="btn sm ghost" :class="{ active: autoMode }" @click="toggleAuto" title="Modo Auto-avance">⏩ Auto</button>
					<button class="btn sm ghost" :class="{ active: showHistory }" @click="showHistory = !showHistory" title="Ver historial de diálogo">📜 Historial</button>
					<button class="btn sm ghost" :class="{ active: showState }" @click="showState = !showState" title="Variables simuladas">📊 Variables</button>
					<button class="btn sm ghost" @click="toggleMute" :title="isMuted ? 'Activar música' : 'Silenciar'">{{ isMuted ? '🔇' : '🔊' }}</button>
					<button class="btn sm ghost" @click="restart" title="Reiniciar escena desde el principio">↺ Reiniciar</button>
					<button class="btn sm danger" @click="closeModal" title="Cerrar simulador">✕</button>
				</div>
			</header>

			<!-- PANTALLA PRINCIPAL 16:9 DE LA NOVELA VISUAL -->
			<div class="vn-screen" :style="{ backgroundImage: 'url(' + bgImgUrl + ')' }" @click="onAdvance">
				<div class="vn-screen-overlay"></div>

				<!-- Personaje / Retrato a escala -->
				<div v-if="portraitImgUrl || isEmojiPortrait" class="vn-character-layer" :class="{ 'has-img': portraitImgUrl }">
					<img v-if="portraitImgUrl" :src="portraitImgUrl" class="vn-character-sprite" alt="" />
					<div v-else-if="isEmojiPortrait" class="vn-character-emoji-card">
						<span class="vn-char-emoji">{{ currentPortrait }}</span>
					</div>
				</div>

				<!-- Panel de Estado / Variables Flotante -->
				<div v-if="showState" class="vn-state-drawer card panel scroll" @click.stop>
					<h4>📊 Variables Simuladas</h4>
					<div class="vn-stat-row"><span>💰 Oro:</span><strong class="mono">{{ simState.gold }}</strong></div>
					<div class="vn-stat-row"><span>⭐ XP:</span><strong class="mono">{{ simState.xp }} (Nivel {{ simState.level }})</strong></div>
					<div class="vn-stat-section">Facetas:</div>
					<div class="vn-stat-row" v-for="(v, k) in simState.facetas" :key="k">
						<span style="text-transform:capitalize">{{ k }}:</span><strong class="mono">+{{ v }}</strong>
					</div>
					<div class="vn-stat-section">Inventario:</div>
					<div class="vn-stat-row" v-for="(qty, item) in simState.items" :key="item">
						<span>{{ item }}:</span><strong class="mono">×{{ qty }}</strong>
					</div>
				</div>

				<!-- Drawer de Historial -->
				<div v-if="showHistory" class="vn-history-drawer card panel scroll" @click.stop>
					<h4>📜 Historial de la Conversación</h4>
					<div v-for="(h, idx) in history" :key="idx" class="vn-history-entry" :class="{ 'is-choice': h.isChoice }">
						<strong class="vn-history-speaker">{{ h.speaker }}</strong>
						<p class="vn-history-text">{{ h.text }}</p>
					</div>
					<div v-if="!history.length" class="muted" style="font-size:12px">Aún no hay mensajes en el historial.</div>
				</div>

				<!-- Pantalla de Fin de Escena -->
				<div v-if="isFinished" class="vn-finished-overlay" @click.stop>
					<div class="vn-finished-card card panel">
						<div class="vn-finished-icon">✨</div>
						<h2>Fin de la Escena</h2>
						<p class="muted">Has llegado al final de esta rama narrativa.</p>
						<button class="btn primary" @click="restart">↺ Volver a reproducir</button>
					</div>
				</div>

				<!-- CAJA DE DIÁLOGO INFERIOR -->
				<div v-else class="vn-dialog-box" @click.stop="onAdvance">
					<!-- Nombre del hablante -->
					<div v-if="currentSpeaker" class="vn-speaker-badge">
						<span v-if="isEmojiPortrait" class="vn-speaker-emoji">{{ currentPortrait }}</span>
						<span class="vn-speaker-name">{{ currentSpeaker }}</span>
					</div>

					<!-- Texto con typewriter -->
					<div class="vn-dialog-text">
						<span>{{ displayedText }}</span>
						<span v-if="isTyping" class="vn-cursor">▌</span>
					</div>

					<!-- Opciones de Decisión (choice) -->
					<div v-if="currentNode?.kind === 'choice' && !isTyping" class="vn-choices-container" @click.stop>
						<button v-for="(opt, idx) in (currentNode.options || [])" :key="idx"
							class="vn-choice-btn" @click="chooseOption(opt)">
							<span class="vn-choice-arrow">◆</span>
							<span class="vn-choice-label">{{ getI18nDisplay(opt.text) }}</span>
						</button>
					</div>

					<!-- Flecha de continuar -->
					<div v-if="!isTyping && currentNode?.kind === 'say'" class="vn-continue-hint">
						<span>Toca para continuar</span>
						<span class="vn-continue-arrow">▼</span>
					</div>
				</div>
			</div>
		</div>
	</div>
	`,
};
