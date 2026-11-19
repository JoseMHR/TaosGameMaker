// components/CinematicsManager.js
// ─────────────────────────────────────────────────────────────────────────────
// GESTOR DE CINEMÁTICAS — Carrusel de imágenes con textos multi-idioma.
//
// Edita colecciones en data/cinematics/<id>.json:
//   · id: Identificador único de la cinemática (ej. final_a, final_b, intro, ...)
//   · title: Título en todos los idiomas (es, en, fr, it, de, zh, ja)
//   · desc: Descripción / notas internas
//   · music: Pista de audio ambiental
//   · on_finish: 'end' (vuelve al mapa/juego) | 'credits' (pantalla de créditos)
//   · ops: Mini-lenguaje opcional (gflag, questf, ...)
//   · slides: Carrusel ordenado de diapositivas [ { bg, speaker, portrait, text, fx } ]
//
// Integra selector visual de fondos (assets/vn/bg/), filmstrip interactivo,
// pestañas de traducción en 7 idiomas y simulador de reproducción en vivo.
// ─────────────────────────────────────────────────────────────────────────────
import { ref, computed } from 'https://unpkg.com/vue@3/dist/vue.esm-browser.prod.js';
import { store, getI18n, getI18nFallback, getI18nDisplay, setI18n, flash } from '../store.js';
import * as FS from '../fs.js';
import { useCollection } from '../lib/useCollection.js';
import EntityListPanel from './EntityListPanel.js';
import EditorToolbar from './EditorToolbar.js';
import VnAssetPicker from './VnAssetPicker.js';
import DsAudioBtn from '../ui/DsAudioBtn.js';

const LANGS = [
	{ code: 'es', label: 'Español', flag: '🇪🇸' },
	{ code: 'en', label: 'English', flag: '🇬🇧' },
	{ code: 'fr', label: 'Français', flag: '🇫🇷' },
	{ code: 'it', label: 'Italiano', flag: '🇮🇹' },
	{ code: 'de', label: 'Deutsch', flag: '🇩🇪' },
	{ code: 'zh', label: '中文', flag: '🇨🇳' },
	{ code: 'ja', label: '日本語', flag: '🇯🇵' },
];

export default {
	name: 'CinematicsManager',
	components: { EntityListPanel, EditorToolbar, VnAssetPicker, DsAudioBtn },
	setup() {
		const selectedSlideIndex = ref(0);
		const selectedLang = ref('es');
		const simOpen = ref(false);
		const simIndex = ref(0);

		const col = useCollection({
			tabId: 'cinematics',
			dirtyKey: 'cinematics',
			dirtyMap: () => store.dirtyCinematics,
			collection: () => store.cinematics,
			setCollection: (v) => { store.cinematics = v; },
			selectedKey: 'selectedCinematic',
			clipboardKind: 'cinematic',
			entityLabel: 'cinemática',
			newIdBase: 'cinematica',
			onRemove: (id) => FS.deleteCollectionItem('cinematics', id),
			makeNew: () => ({
				id: 'nueva_cinematica',
				title: { es: 'Nueva Cinemática', en: 'New Cinematic', fr: '', it: '', de: '', zh: '', ja: '' },
				desc: '',
				music: 'world_zone1_flooded',
				on_finish: 'end',
				slides: [
					{
						bg: 'bg_ending_temple.png',
						speaker: { es: 'Narrador', en: 'Narrator', fr: '', it: '', de: '', zh: '', ja: '' },
						portrait: '🎬',
						text: { es: 'Escribe aquí la historia...', en: 'Write your story here...', fr: '', it: '', de: '', zh: '', ja: '' },
						fx: { darken: 0.35 }
					}
				]
			}),
			searchText: (id, o) => id + ' ' + (o?.title?.es || '') + ' ' + (o?.title?.en || '') + ' ' + (o?.desc || ''),
			sorts: [
				{ key: 'id', label: 'ID', get: (id) => id },
				{ key: 'slides', label: 'Diapositivas', get: (id, o) => (o?.slides || []).length },
			],
		});

		const current = col.current;
		const slides = computed(() => (current.value && Array.isArray(current.value.slides)) ? current.value.slides : []);
		const currentSlide = computed(() => slides.value[selectedSlideIndex.value] || null);

		function resolveBgUrl(bg) {
			if (!bg || typeof bg !== 'string') return '';
			if (bg.startsWith('/') || bg.startsWith('http://') || bg.startsWith('https://')) return bg;
			if (bg.startsWith('res://')) return bg.replace('res://', '/');
			return '/assets/vn/bg/' + bg;
		}

		function selectSlide(idx) {
			if (idx >= 0 && idx < slides.value.length) {
				selectedSlideIndex.value = idx;
			}
		}

		function addSlide() {
			col.edit(() => {
				current.value.slides = current.value.slides || [];
				const lastBg = currentSlide.value?.bg || 'bg_ending_temple.png';
				const lastSpeaker = currentSlide.value?.speaker ? JSON.parse(JSON.stringify(currentSlide.value.speaker)) : { es: 'Narrador', en: 'Narrator', fr: '', it: '', de: '', zh: '', ja: '' };
				const newSlide = {
					bg: lastBg,
					speaker: lastSpeaker,
					portrait: currentSlide.value?.portrait || '🎬',
					text: { es: '', en: '', fr: '', it: '', de: '', zh: '', ja: '' },
					fx: { darken: 0.35 }
				};
				current.value.slides.push(newSlide);
				selectedSlideIndex.value = current.value.slides.length - 1;
			});
		}

		function duplicateSlide(idx) {
			col.edit(() => {
				const src = current.value.slides[idx];
				if (!src) return;
				const clone = JSON.parse(JSON.stringify(src));
				current.value.slides.splice(idx + 1, 0, clone);
				selectedSlideIndex.value = idx + 1;
			});
		}

		function removeSlide(idx) {
			if (slides.value.length <= 1) {
				flash('Una cinemática debe tener al menos una diapositiva.');
				return;
			}
			col.edit(() => {
				current.value.slides.splice(idx, 1);
				if (selectedSlideIndex.value >= current.value.slides.length) {
					selectedSlideIndex.value = Math.max(0, current.value.slides.length - 1);
				}
			});
		}

		function moveSlide(idx, delta) {
			const target = idx + delta;
			if (target < 0 || target >= slides.value.length) return;
			col.edit(() => {
				const item = current.value.slides.splice(idx, 1)[0];
				current.value.slides.splice(target, 0, item);
				selectedSlideIndex.value = target;
			});
		}

		function setSlideField(field, val) {
			col.edit(() => {
				if (currentSlide.value) {
					currentSlide.value[field] = val;
				}
			});
		}

		function setSlideSpeaker(val, lang = selectedLang.value) {
			col.edit(() => {
				if (currentSlide.value) {
					setI18n(currentSlide.value, 'speaker', val, lang);
				}
			});
		}

		function setSlideText(val, lang = selectedLang.value) {
			col.edit(() => {
				if (currentSlide.value) {
					setI18n(currentSlide.value, 'text', val, lang);
				}
			});
		}

		function setSlideFx(key, val) {
			col.edit(() => {
				if (!currentSlide.value) return;
				currentSlide.value.fx = currentSlide.value.fx || {};
				if (val === '' || val === null || isNaN(val)) {
					delete currentSlide.value.fx[key];
				} else {
					currentSlide.value.fx[key] = Number(val);
				}
				if (Object.keys(currentSlide.value.fx).length === 0) {
					delete currentSlide.value.fx;
				}
			});
		}

		function setTitle(val, lang = selectedLang.value) {
			col.edit(() => {
				setI18n(current.value, 'title', val, lang);
			});
		}

		function setField(key, val) {
			col.edit(() => {
				current.value[key] = val;
			});
		}

		function hasTextInLang(slide, lang) {
			if (!slide || !slide.text) return false;
			const txt = (typeof slide.text === 'object') ? slide.text[lang] : (lang === 'es' ? slide.text : '');
			return !!(txt && String(txt).trim().length > 0);
		}

		function getSlideTextPreview(slide) {
			if (!slide) return '';
			return getI18nDisplay(slide.text, selectedLang.value) || '(Sin texto)';
		}

		function getSlideSpeakerPreview(slide) {
			if (!slide) return '';
			return getI18nDisplay(slide.speaker, selectedLang.value) || '';
		}

		// Simulador
		function openSimulator() {
			if (!slides.value.length) return;
			simIndex.value = selectedSlideIndex.value;
			simOpen.value = true;
		}

		function nextSimSlide() {
			if (simIndex.value < slides.value.length - 1) {
				simIndex.value++;
			} else {
				simOpen.value = false;
				flash('Fin de la cinemática.');
			}
		}

		function prevSimSlide() {
			if (simIndex.value > 0) {
				simIndex.value--;
			}
		}

		const simSlide = computed(() => slides.value[simIndex.value] || null);

		return {
			store, col, current, slides, currentSlide,
			selectedSlideIndex, selectedLang, LANGS,
			resolveBgUrl, selectSlide, addSlide, duplicateSlide, removeSlide, moveSlide,
			setSlideField, setSlideSpeaker, setSlideText, setSlideFx,
			setTitle, setField, hasTextInLang, getSlideTextPreview, getSlideSpeakerPreview,
			simOpen, simIndex, simSlide, openSimulator, nextSimSlide, prevSimSlide,
			getI18n, getI18nFallback, getI18nDisplay,
		};
	},
	template: `
	<div class="manager">
		<entity-list-panel :c="col" search-placeholder="Buscar cinemática…" new-label="➕ Nueva cinemática">
			<template #row="{ id, o }">
				<span class="ent-icon">🎬</span>
				<span class="ent-name">{{ (o && o.title && (o.title[store.currentLang] || o.title.es || o.title.en)) || id }}</span>
				<span class="ent-id mono">{{ (o && o.slides && o.slides.length) || 0 }} diap.</span>
			</template>
		</entity-list-panel>

		<section class="editor-pane scroll" v-if="current">
			<editor-toolbar :can-undo="col.canUndo.value" :can-redo="col.canRedo.value"
				:can-paste="col.canPaste.value" :has-current="!!current" :dirty="col.dirty.value"
				:saved-text="col.savedText.value"
				@undo="col.undo()" @redo="col.redo()" @copy="col.copy()" @paste="col.paste()"
				@duplicate="col.duplicate()" @remove="col.remove()" @save="col.doSave()">
				<template #actions>
					<button class="btn primary sm" @click="openSimulator" :disabled="!slides.length" title="Probar esta cinemática como se verá en el juego">
						▶ Probar Cinemática
					</button>
				</template>
			</editor-toolbar>

			<!-- CABECERA DE LA CINEMÁTICA -->
			<div class="card panel" style="margin-bottom:14px; padding:16px">
				<div class="row gap" style="align-items:center; margin-bottom:12px">
					<h3 class="sec" style="margin:0">🎬 Configuración General</h3>
					<span class="muted mono" style="font-size:12px; margin-left:auto">ID: {{ col.selectedId.value }}</span>
				</div>

				<div class="form-grid">
					<div>
						<label>ID de la Cinemática</label>
						<input class="input mono" type="text" :value="col.selectedId.value" @change="col.rename($event.target.value)" />
					</div>
					<div>
						<label>Música de Fondo</label>
						<div class="flex" style="gap:6px">
							<input class="input mono" type="text" :value="current.music || ''" @input="setField('music', $event.target.value)" placeholder="world_zone1_flooded" />
							<ds-audio-btn v-if="current.music" :src="current.music" size="sm"></ds-audio-btn>
						</div>
					</div>
					<div>
						<label>Al Finalizar (on_finish)</label>
						<select class="input" :value="current.on_finish || 'end'" @change="setField('on_finish', $event.target.value)">
							<option value="end">Volver al punto donde estaba el jugador (end)</option>
							<option value="credits">Ir a la Pantalla de Créditos (credits)</option>
						</select>
					</div>
					<div>
						<label>Flags / Ops globales (opcional)</label>
						<input class="input mono" type="text" :value="current.ops || ''" @input="setField('ops', $event.target.value)" placeholder="gflag:ending_acceptance;questf:game_completed" />
					</div>
					<div class="full">
						<label>Título [{{ selectedLang.toUpperCase() }}] — {{ LANGS.find(l => l.code === selectedLang)?.label }}</label>
						<input class="input" type="text" :value="getI18n(current.title, selectedLang)" :placeholder="getI18nFallback(current.title) || 'Título de la cinemática o final...'" @input="setTitle($event.target.value)" />
					</div>
					<div class="full">
						<label>Descripción / Notas de diseño</label>
						<input class="input" type="text" :value="current.desc || ''" @input="setField('desc', $event.target.value)" placeholder="Resumen del final o evento narrativo..." />
					</div>
				</div>
			</div>

			<!-- SELECTOR DE IDIOMA PARA EDICIÓN DE TEXTOS -->
			<div class="row gap" style="align-items:center; margin-bottom:8px">
				<span class="muted" style="font-size:12px; font-weight:700">Idioma activo de edición y vista previa:</span>
				<div class="cine-lang-tabs" style="margin:0">
					<button v-for="l in LANGS" :key="l.code" type="button"
						class="cine-lang-btn" :class="{ active: selectedLang === l.code }"
						@click="selectedLang = l.code">
						<span>{{ l.flag }}</span>
						<span>{{ l.code.toUpperCase() }}</span>
						<span class="cine-lang-dot" :class="{ empty: currentSlide && !hasTextInLang(currentSlide, l.code) }"
							:title="currentSlide && hasTextInLang(currentSlide, l.code) ? 'Traducido' : 'Sin texto en ' + l.code"></span>
					</button>
				</div>
			</div>

			<!-- CARRUSEL DE DIAPOSITIVAS (FILMSTRIP / STORYBOARD) -->
			<div class="card panel" style="margin-bottom:14px; padding:14px">
				<div class="row gap" style="align-items:center; margin-bottom:10px">
					<h3 class="sec" style="margin:0">🎞️ Diapositivas ({{ slides.length }})</h3>
					<span class="muted" style="font-size:11.5px">Haz clic en una diapositiva para editar su imagen y textos</span>
					<button class="btn secondary sm" style="margin-left:auto" @click="addSlide">➕ Añadir Diapositiva</button>
				</div>

				<div class="cine-strip">
					<div v-for="(slide, idx) in slides" :key="idx"
						class="cine-slide-card" :class="{ active: selectedSlideIndex === idx }"
						@click="selectSlide(idx)">
						<div class="cine-slide-card__thumb">
							<img v-if="slide.bg" :src="resolveBgUrl(slide.bg)" class="cine-slide-card__img" alt="" loading="lazy" />
							<span v-else class="muted" style="font-size:24px">🖼️</span>
							<span class="cine-slide-card__num">#{{ idx + 1 }}</span>
							<span v-if="slide.speaker" class="cine-slide-card__speaker">
								{{ slide.portrait || '' }} {{ getSlideSpeakerPreview(slide) }}
							</span>
						</div>
						<div class="cine-slide-card__body">
							<div class="cine-slide-card__text">{{ getSlideTextPreview(slide) }}</div>
							<div class="cine-slide-card__actions" @click.stop>
								<div class="flex" style="gap:2px">
									<button class="btn xs ghost" :disabled="idx === 0" @click="moveSlide(idx, -1)" title="Mover hacia la izquierda">◀</button>
									<button class="btn xs ghost" :disabled="idx === slides.length - 1" @click="moveSlide(idx, 1)" title="Mover hacia la derecha">▶</button>
								</div>
								<div class="flex" style="gap:2px">
									<button class="btn xs ghost" @click="duplicateSlide(idx)" title="Duplicar diapositiva">📋</button>
									<button class="btn xs err ghost" :disabled="slides.length <= 1" @click="removeSlide(idx)" title="Eliminar diapositiva">🗑️</button>
								</div>
							</div>
						</div>
					</div>
				</div>
			</div>

			<!-- INSPECTOR DE LA DIAPOSITIVA SELECCIONADA -->
			<div class="card panel" v-if="currentSlide" style="padding:16px">
				<div class="row gap" style="align-items:center; margin-bottom:14px">
					<h3 class="sec" style="margin:0">🖼️ Diapositiva #{{ selectedSlideIndex + 1 }} de {{ slides.length }}</h3>
					<div class="flex" style="gap:6px; margin-left:auto">
						<button class="btn xs ghost" :disabled="selectedSlideIndex === 0" @click="selectSlide(selectedSlideIndex - 1)">◀ Anterior</button>
						<button class="btn xs ghost" :disabled="selectedSlideIndex === slides.length - 1" @click="selectSlide(selectedSlideIndex + 1)">Siguiente ▶</button>
					</div>
				</div>

				<div class="form-grid">
					<!-- SELECTOR DE FONDO CON PREVISUALIZADOR -->
					<div class="full">
						<label style="font-weight:700">Imagen de Fondo (Background)</label>
						<vn-asset-picker kind="bg" :model-value="currentSlide.bg || ''"
							label="Fondo" placeholder="Seleccionar imagen de fondo..."
							@update:model-value="setSlideField('bg', $event)"></vn-asset-picker>
					</div>

					<!-- PERSONAJE / HABLANTE -->
					<div>
						<label>Nombre del Hablante [{{ selectedLang.toUpperCase() }}]</label>
						<input class="input" type="text" :value="getI18n(currentSlide.speaker, selectedLang)"
							:placeholder="getI18nFallback(currentSlide.speaker) || 'Narrador / Personaje...'"
							@input="setSlideSpeaker($event.target.value)" />
					</div>
					<div>
						<label>Retrato / Emoji del Hablante</label>
						<vn-asset-picker kind="portrait" :model-value="currentSlide.portrait || ''"
							label="Retrato" placeholder="Emoji o retrato..."
							@update:model-value="setSlideField('portrait', $event)"></vn-asset-picker>
					</div>

					<!-- TEXTO MULTI-IDIOMA -->
					<div class="full">
						<div class="row gap" style="align-items:center; margin-bottom:4px">
							<label style="font-weight:700; margin:0">
								Texto de la Diapositiva [{{ selectedLang.toUpperCase() }}] — {{ LANGS.find(l => l.code === selectedLang)?.label }}
							</label>
							<span v-if="!hasTextInLang(currentSlide, selectedLang)" class="badge err" style="margin-left:auto; font-size:10px">
								Sin traducción en {{ selectedLang.toUpperCase() }}
							</span>
							<span v-else class="badge ok" style="margin-left:auto; font-size:10px">
								✓ Traducido
							</span>
						</div>
						<textarea class="input" rows="4" style="font-size:14px; line-height:1.5"
							:value="getI18n(currentSlide.text, selectedLang)"
							:placeholder="getI18nFallback(currentSlide.text) || 'Escribe el texto a mostrar en la diapositiva...'"
							@input="setSlideText($event.target.value)"></textarea>
					</div>

					<!-- EFECTOS VISUALES & SONOROS -->
					<div class="full">
						<details class="panel" style="background:var(--bg-2); border:1px solid var(--line); border-radius:8px; padding:8px 12px">
							<summary style="cursor:pointer; font-weight:700; font-size:12.5px; color:var(--txt-1)">
								✨ Efectos Visuales y Sonido de Entrada (FX opcionales)
							</summary>
							<div class="form-grid" style="margin-top:12px">
								<div>
									<label>Oscurecimiento (darken: 0.0 a 1.0)</label>
									<input class="input" type="number" step="0.05" min="0" max="1"
										:value="currentSlide.fx?.darken ?? ''" placeholder="0.35"
										@input="setSlideFx('darken', $event.target.value)" />
								</div>
								<div>
									<label>Resplandor (glow: 0.0 a 1.0)</label>
									<input class="input" type="number" step="0.05" min="0" max="1"
										:value="currentSlide.fx?.glow ?? ''" placeholder="0.4"
										@input="setSlideFx('glow', $event.target.value)" />
								</div>
								<div>
									<label>Sacudida de Pantalla (shake: 0.0 a 1.0)</label>
									<input class="input" type="number" step="0.05" min="0" max="1"
										:value="currentSlide.fx?.shake ?? ''" placeholder="0.0"
										@input="setSlideFx('shake', $event.target.value)" />
								</div>
								<div>
									<label>Efecto de Sonido (sfx)</label>
									<input class="input mono" type="text"
										:value="currentSlide.fx?.sfx ?? ''" placeholder="click / magic / bell..."
										@input="setSlideFx('sfx', $event.target.value)" />
								</div>
							</div>
						</details>
					</div>
				</div>
			</div>
		</section>

		<section class="editor-pane empty" v-else>
			<p class="muted">Selecciona o crea una cinemática para editar.</p>
		</section>

		<!-- MODAL DE SIMULACIÓN EN VIVO (PREVIEW PLAYER) -->
		<div v-if="simOpen" class="modal-backdrop" @click.self="simOpen=false">
			<div class="modal-window cine-player-modal card panel">
				<div class="modal-head" style="padding:10px 16px; border-bottom:1px solid rgba(255,255,255,0.1)">
					<div class="row gap" style="align-items:center">
						<span style="font-weight:700">🎬 {{ getI18nDisplay(current?.title, selectedLang) }}</span>
						<span class="muted" style="font-size:12px">— Diapositiva {{ simIndex + 1 }} de {{ slides.length }}</span>
					</div>
					<button class="btn ghost sm modal-close" @click="simOpen=false">✕</button>
				</div>

				<div class="cine-player-viewport" @click="nextSimSlide" v-if="simSlide">
					<img :src="resolveBgUrl(simSlide.bg)" class="cine-player-bg" alt="" />
					<div class="cine-player-darken" :style="{ opacity: simSlide.fx?.darken ?? 0.3 }"></div>
					<div class="cine-player-glow" v-if="simSlide.fx?.glow" :style="{ opacity: simSlide.fx.glow }"></div>

					<!-- CAJA DE DIÁLOGO NARRATIVA -->
					<div class="cine-player-dialogue-wrap">
						<div class="cine-player-speaker" v-if="simSlide.speaker">
							<span>{{ simSlide.portrait || '🕊️' }}</span>
							<span>{{ getI18nDisplay(simSlide.speaker, selectedLang) }}</span>
						</div>
						<div class="cine-player-text">
							{{ getI18nDisplay(simSlide.text, selectedLang) }}
						</div>
						<div class="cine-player-prompt">
							<span>Haz clic para continuar</span>
							<span class="cine-player-prompt-icon">▼</span>
						</div>
					</div>
				</div>

				<div class="row gap" style="padding:10px 16px; align-items:center; background:#070a10">
					<button class="btn sm ghost" :disabled="simIndex === 0" @click="prevSimSlide">◀ Anterior</button>
					<div class="flex" style="gap:4px; margin:0 auto">
						<span v-for="(_, i) in slides" :key="i"
							style="width:8px; height:8px; border-radius:50%; transition:all 0.2s"
							:style="{ background: i === simIndex ? '#38bdf8' : 'rgba(255,255,255,0.2)' }"></span>
					</div>
					<button class="btn sm primary" @click="nextSimSlide">
						{{ simIndex === slides.length - 1 ? 'Cerrar Cinemática ✓' : 'Siguiente ▶' }}
					</button>
				</div>
			</div>
		</div>
	</div>
	`,
};
