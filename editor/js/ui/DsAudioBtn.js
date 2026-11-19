// ui/DsAudioBtn.js
// ─────────────────────────────────────────────────────────────────────────────
// Botón interactivo para reproducir/escuchar cualquier pista de audio
// (.ogg, .wav, .mp3) directamente en el navegador usando HTML5 Audio.
// ─────────────────────────────────────────────────────────────────────────────
import { ref, onUnmounted, watch } from 'https://unpkg.com/vue@3/dist/vue.esm-browser.prod.js';

let activeGlobalAudio = null;
let activeGlobalBtn = null;

export function stopAllGlobalAudio() {
	if (activeGlobalAudio) {
		activeGlobalAudio.pause();
		activeGlobalAudio.currentTime = 0;
		activeGlobalAudio = null;
	}
	if (activeGlobalBtn) {
		activeGlobalBtn.value = false;
		activeGlobalBtn = null;
	}
}

export default {
	name: 'DsAudioBtn',
	props: {
		src: { type: String, default: '' },
		label: { type: String, default: '' },
		size: { type: String, default: 'xs' }, // 'xs' | 'sm' | 'md'
	},
	setup(props) {
		const isPlaying = ref(false);
		const isLoading = ref(false);
		let audio = null;

		function resolveUrl(s) {
			if (!s) return '';
			s = s.trim();
			if (s.startsWith('http://') || s.startsWith('https://') || s.startsWith('/')) {
				return s;
			}
			if (s.startsWith('res://')) {
				s = s.replace('res://', '/');
			}
			if (!s.startsWith('/')) {
				// Buscar en assets de música si no tiene ruta
				s = '/assets/common/music/' + (s.endsWith('.ogg') || s.endsWith('.wav') || s.endsWith('.mp3') ? s : s + '.ogg');
			}
			return s;
		}

		function togglePlay() {
			if (!props.src) return;
			if (isPlaying.value) {
				stop();
				return;
			}

			stopAllGlobalAudio();

			const url = resolveUrl(props.src);
			audio = new Audio(url);
			isLoading.value = true;
			activeGlobalAudio = audio;
			activeGlobalBtn = isPlaying;

			audio.oncanplay = () => {
				isLoading.value = false;
			};

			audio.onended = () => {
				isPlaying.value = false;
				isLoading.value = false;
				audio = null;
				activeGlobalAudio = null;
				activeGlobalBtn = null;
			};

			audio.onerror = (e) => {
				console.warn('No se pudo reproducir audio:', url, e);
				isPlaying.value = false;
				isLoading.value = false;
				audio = null;
			};

			audio.play().then(() => {
				isPlaying.value = true;
				isLoading.value = false;
			}).catch((err) => {
				console.warn('Error al iniciar audio:', err);
				isPlaying.value = false;
				isLoading.value = false;
				audio = null;
			});
		}

		function stop() {
			if (audio) {
				audio.pause();
				audio.currentTime = 0;
				audio = null;
			}
			isPlaying.value = false;
			isLoading.value = false;
			if (activeGlobalAudio === audio) {
				activeGlobalAudio = null;
				activeGlobalBtn = null;
			}
		}

		watch(() => props.src, () => {
			if (isPlaying.value) stop();
		});

		onUnmounted(() => {
			stop();
		});

		return { isPlaying, isLoading, togglePlay };
	},
	template: `
	<button type="button" class="btn ds-audio-btn" :class="[size, { 'is-playing': isPlaying, 'is-loading': isLoading }]"
		:disabled="!src" @click.stop="togglePlay" :title="isPlaying ? 'Detener reproducción' : 'Escuchar audio'">
		<span class="ds-audio-btn__icon">{{ isPlaying ? '⏹' : isLoading ? '⏳' : '▶' }}</span>
		<span v-if="label" class="ds-audio-btn__lbl">{{ label }}</span>
	</button>
	`,
};
