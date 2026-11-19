// components/FirstStepsPanel.js
// ─────────────────────────────────────────────────────────────────────────────
// GUÍA DE PRIMEROS PASOS (Task 1 Fase 7). Cajón lateral con una checklist fija
// para crear tu primer contenido de punta a punta (enemigo → mazmorra → NPC →
// POI → mapa → profesión → QA → guardar), pensada para alguien que abre el
// editor por primera vez y no sabe por dónde empezar. Cada paso enlaza
// directamente a la pestaña correspondiente (mismo `goTo` que el resto del
// editor); el progreso (pasos marcados) se guarda en localStorage y es solo
// una ayuda visual — no bloquea ni obliga a seguir el orden.
// ─────────────────────────────────────────────────────────────────────────────
import { computed, reactive } from 'https://unpkg.com/vue@3/dist/vue.esm-browser.prod.js';
import { goTo } from '../nav.js';

const LS_KEY = 'mw-first-steps-done';
function loadDone() {
	try { return JSON.parse(localStorage.getItem(LS_KEY) || '{}'); } catch (e) { return {}; }
}
function saveDone(v) { localStorage.setItem(LS_KEY, JSON.stringify(v)); }

const STEPS = [
	{ id: 'enemy', icon: '👾', title: 'Crea tu primer enemigo', desc: 'Nombre, sprite, estadísticas y alguna habilidad. Usa "🧬 Duplicar y subir de tier" si prefieres partir de uno ya existente.', tab: 'enemies' },
	{ id: 'dungeon', icon: '🕳️', title: 'Colócalo en una mazmorra', desc: 'Casilla de tipo "monstruo": elige tu enemigo y, si quieres, un nivel concreto.', tab: 'dungeons' },
	{ id: 'npc', icon: '💬', title: 'Crea un NPC con su diálogo', desc: 'Al menos un mensaje de bienvenida y una opción de despedida ("close").', tab: 'npcs' },
	{ id: 'poi', icon: '📍', title: 'Crea un POI y enlázalo con ese NPC', desc: 'En Ciudades/IDs, usa "✚ Este POI tiene NPC" para crear el enlace en un clic.', tab: 'ids' },
	{ id: 'map', icon: '🗺️', title: 'Colócalo en el mapa', desc: 'Herramienta "Entidades": pinta tu POI en la casilla que quieras.', tab: 'map' },
	{ id: 'profession', icon: '🧝', title: 'Revisa una profesión y sus habilidades', desc: 'Añade o edita una habilidad y su nivel de desbloqueo.', tab: 'professions' },
	{ id: 'qa', icon: '🔎', title: 'Pasa el Asistente de QA', desc: 'Botón "🔎 QA" de la barra lateral: comprueba que nada quedó roto o inalcanzable.', tab: null },
	{ id: 'save', icon: '💾', title: 'Guarda los cambios', desc: 'Botón "💾 Guardar" de la barra superior (o Ctrl+S).', tab: null },
];

export default {
	name: 'FirstStepsPanel',
	props: { open: Boolean },
	emits: ['close', 'open-qa'],
	setup(props, { emit }) {
		const done = reactive(loadDone());
		function toggle(id) {
			done[id] = !done[id];
			saveDone({ ...done });
		}
		function resetAll() {
			if (!confirm('¿Reiniciar el progreso de la guía de primeros pasos?')) return;
			for (const k of Object.keys(done)) delete done[k];
			saveDone({});
		}
		const doneCount = computed(() => STEPS.filter(s => done[s.id]).length);
		const pct = computed(() => Math.round((doneCount.value / STEPS.length) * 100));
		function go(step) {
			if (step.id === 'qa') { emit('open-qa'); return; }
			if (step.tab) goTo(step.tab);
		}
		return { STEPS, done, toggle, resetAll, doneCount, pct, go };
	},
	template: `
	<div>
		<div v-if="open" class="overlay" @click="$emit('close')"></div>
		<div class="help-drawer" :class="{ open }">
			<div class="help-head">
				<strong>🚀 Primeros pasos</strong>
				<span class="grow"></span>
				<button class="btn sm ghost" @click="$emit('close')">✕</button>
			</div>
			<div class="help-body">
				<p class="help-summary">
					Checklist para montar tu primer contenido de punta a punta. No es
					obligatorio seguir el orden ni completarla entera — es solo una guía.
				</p>
				<div class="steps-progress">
					<div class="steps-progress__bar"><i :style="{ width: pct + '%' }"></i></div>
					<span class="muted">{{ doneCount }} / {{ STEPS.length }} completados</span>
				</div>
				<div class="steps-list">
					<div v-for="s in STEPS" :key="s.id" class="steps-item" :class="{ done: done[s.id] }">
						<label class="steps-item__check">
							<input type="checkbox" :checked="!!done[s.id]" @change="toggle(s.id)" />
						</label>
						<div class="steps-item__body">
							<div class="steps-item__title">{{ s.icon }} {{ s.title }}</div>
							<div class="steps-item__desc">{{ s.desc }}</div>
						</div>
						<button class="btn xs secondary" @click="go(s)">Ir →</button>
					</div>
				</div>
				<button class="btn sm ghost" style="margin-top:10px" @click="resetAll">↺ Reiniciar progreso</button>
			</div>
		</div>
	</div>
	`,
};
