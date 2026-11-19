// components/QaPanel.js
// ─────────────────────────────────────────────────────────────────────────────
// ASISTENTE DE QA. Cajón lateral con el diagnóstico de
// integridad. Ejecuta el validador bajo demanda (y al abrir), y presenta los
// hallazgos de forma "inteligente": recuento por severidad, filtro por sección
// (todas / solo la pestaña activa), búsqueda de texto, agrupación por sección y
// una PISTA DE ARREGLO por cada tipo de problema. Permite saltar al elemento.
// ─────────────────────────────────────────────────────────────────────────────
import { ref, computed, watch } from 'https://unpkg.com/vue@3/dist/vue.esm-browser.prod.js';
import { store } from '../store.js';
import { TAB_META } from '../nav.js';
import { runValidation } from '../validator.js';

// Pista de arreglo por código de hallazgo. Convierte un error críptico en una
// acción concreta para el diseñador. Si falta, se usa un texto genérico.
const FIX_HINTS = {
	'map-ref': 'Crea la entidad en "Entidades" o cambia el object de la casilla por uno existente.',
	'city-content': 'Crea el POI en "Entidades" o quítalo del content de la ciudad.',
	'gate-dir': 'Corrige gate.dir a north/south/east/west.',
	'gate-open': 'Añade una condición open_when al gate (o elimínalo si debe estar siempre abierto).',
	'npc-missing': 'Crea el NPC en "NPCs" o corrige la referencia npc de la entidad.',
	'next-broken': 'Corrige el enlace next para que apunte a un nodo existente o a "close".',
	'dead-end': 'Añade al menos un next (o "close") para que el diálogo pueda cerrarse.',
	'loot-table': 'Crea la tabla en "Botín" o corrige el nombre de la tabla del enemigo.',
	'loot-item': 'Crea el ítem en "Objetos" o corrige la entrada de botín.',
	'loot-table-ref': 'Crea el ítem/tabla referenciado o corrige la entrada.',
	'dialogue-item': 'Crea el ítem en "Objetos" o corrige la referencia en la condición/recompensa.',
	'event-ref': 'Crea el evento invocado en "Misiones/Eventos" o corrige el token event:.',
	// QA inteligente
	'npc-unreachable': 'Enlaza este nodo desde algún next del diálogo o elimínalo si es contenido muerto.',
	'item-unobtainable': 'Coloca el ítem en una tienda, tabla de botín, cofre o recompensa (o elimínalo si no se usa).',
	'skill-unused': 'Asigna la habilidad a una profesión o sinergia (o elimínala si es obsoleta).',
	'dungeon-undefined': 'Diseña la mazmorra en "Mazmorras" (añade plantas y casillas) o cambia el tipo de la entidad.',
	'dungeon-empty': 'Añade al menos una planta (floor) con casillas a la mazmorra.',
	'dungeon-eid-dup': 'Renombra los eids duplicados: cada elemento interactivo debe tener un id único.',
	'actuator-no-target': 'Añade un objetivo (target) al accionador o cámbialo por un elemento no interactivo.',
	'actuator-broken-target': 'Corrige el eid del objetivo para que apunte a un elemento existente de la mazmorra.',
	'gate-no-controller': 'Coloca un interruptor/palanca/placa que accione esta compuerta/puerta (o quítale el eid).',
	'entity-unplaced': 'Coloca la ciudad/mazmorra en el mapa con la herramienta "Entidades" (o elimínala).',
	'poi-orphan': 'Añade el POI al content de una ciudad o colócalo en el mapa (o elimínalo).',
	'event-cycle': 'Rompe el ciclo: quita una de las llamadas event: que se referencian entre sí.',
	// : colecciones data-driven (terrenos/casillas de mazmorra/kits).
	'map-terrain': 'Crea el terreno en "Terrenos" o repinta la casilla con un terreno existente.',
	'dungeon-tile-unknown': 'Crea el tipo en "Tipos de casilla" o corrige el "t" de la casilla.',
	'dungeon-smart-piece': 'Crea la pieza en "Kits (Obj. Inteligente)" o corrige el ref de la casilla smart.',
	'kit-piece-kit': 'Crea el kit en "Kits (Obj. Inteligente)" o corrige el kit de la pieza.',
	// : acciones "solo-código" — informativo, no un error.
	'code-only-qaction': 'Nada que arreglar: es válido por diseño. Solo se puede editar tocando QuestManager.gd.',
	'code-only-worldt': 'Nada que arreglar: es válido por diseño. Solo se puede editar tocando WorldMapBuilder.gd.',
	'code-only-combat': 'Nada que arreglar: es válido por diseño. Solo se puede editar tocando QuestManager.on_combat_victory.',
	'code-unknown-qaction': 'Crea el evento en "Misiones/Eventos" con este id, o corrige el nombre de la acción (probable typo).',
	'code-unknown-worldt': 'Crea la transformación en "Transformaciones de Mundo" con este id, o corrige el nombre (probable typo).',
};
function fixHint(code) { return FIX_HINTS[code] || 'Revisa la referencia: el elemento apuntado no existe o es inválido.'; }
function sectionOf(f) { return (f.ref && f.ref.tab) || 'otros'; }
function sectionLabel(tab) { return (TAB_META[tab] && TAB_META[tab].label) || 'Otros'; }
function sectionIcon(tab) { return (TAB_META[tab] && TAB_META[tab].icon) || '•'; }

export default {
	name: 'QaPanel',
	props: { open: Boolean },
	emits: ['close'],
	setup(props, { emit }) {
		const findings = ref([]);
		const running = ref(false);
		const ran = ref(false);
		const query = ref('');
		const onlyCurrent = ref(false);   // filtro: solo la pestaña activa
		const levelFilter = ref('all');   // 'all' | 'error' | 'warning'

		const errors = computed(() => findings.value.filter(f => f.level === 'error'));
		const warnings = computed(() => findings.value.filter(f => f.level === 'warning'));
		// : nivel 'info' — no es un problema, es transparencia sobre
		// qué acciones dependen de código cableado en vez de datos.
		const infos = computed(() => findings.value.filter(f => f.level === 'info'));

		// Hallazgos tras aplicar filtros (sección/severidad/búsqueda).
		const filtered = computed(() => {
			const q = query.value.trim().toLowerCase();
			return findings.value.filter(f => {
				if (levelFilter.value !== 'all' && f.level !== levelFilter.value) return false;
				if (onlyCurrent.value && sectionOf(f) !== store.activeTab) return false;
				if (q && !((f.message || '').toLowerCase().includes(q) || (f.code || '').toLowerCase().includes(q))) return false;
				return true;
			});
		});

		// Agrupa los hallazgos filtrados por sección (pestaña) para lectura rápida.
		const grouped = computed(() => {
			const map = new Map();
			for (const f of filtered.value) {
				const tab = sectionOf(f);
				if (!map.has(tab)) map.set(tab, []);
				map.get(tab).push(f);
			}
			return Array.from(map.entries()).map(([tab, items]) => ({
				tab, label: sectionLabel(tab), icon: sectionIcon(tab),
				errors: items.filter(i => i.level === 'error').length, items,
			})).sort((a, b) => b.errors - a.errors);
		});

		async function run() {
			running.value = true;
			try {
				findings.value = await runValidation(store, { checkAssets: store.hasAssets });
				ran.value = true;
			} catch (e) {
				store.error = 'Error en el validador: ' + (e.message || e);
			} finally {
				running.value = false;
			}
		}

		// Ejecuta automáticamente al abrir el panel (una vez por apertura).
		watch(() => props.open, (o) => { if (o && !running.value) run(); });

		function jump(f) {
			if (!f.ref) return;
			store.activeTab = f.ref.tab;
			const tgt = f.ref.target;
			if (f.ref.tab === 'map' && tgt) store.selectedCell = tgt;
			else if (f.ref.tab === 'ids') store.selectedId = tgt;
			else if (f.ref.tab === 'npcs') { store.selectedNpc = tgt.npc; }
			else if (f.ref.tab === 'enemies') store.selectedEnemy = tgt;
			else if (f.ref.tab === 'items') store.selectedItem = tgt;
			else if (f.ref.tab === 'skills') store.selectedSkill = tgt;
			else if (f.ref.tab === 'dungeons') store.selectedDungeon = tgt;
			else if (f.ref.tab === 'dungeonKits') store.selectedKitPiece = tgt;
			emit('close');
		}

		return {
			store, findings, running, ran, errors, warnings, infos, run, jump,
			query, onlyCurrent, levelFilter, filtered, grouped, fixHint,
		};
	},
	template: `
	<div>
		<div v-if="open" class="overlay" @click="$emit('close')"></div>
		<div class="qa-drawer" :class="{ open }">
			<div class="qa-head">
				<strong>🔎 Asistente de QA</strong>
				<span class="grow"></span>
				<button class="btn sm" @click="run" :disabled="running">{{ running ? '…' : '↻ Re-analizar' }}</button>
				<button class="btn sm ghost" @click="$emit('close')">✕</button>
			</div>
			<div class="qa-body">
				<div class="qa-counts">
					<button class="chip pill-err dot" :class="{ active: levelFilter==='error' }" @click="levelFilter = levelFilter==='error' ? 'all' : 'error'">{{ errors.length }} errores</button>
					<button class="chip pill-warn dot" :class="{ active: levelFilter==='warning' }" @click="levelFilter = levelFilter==='warning' ? 'all' : 'warning'">{{ warnings.length }} avisos</button>
					<button class="chip dot" style="color:var(--acc)" :class="{ active: levelFilter==='info' }" @click="levelFilter = levelFilter==='info' ? 'all' : 'info'">{{ infos.length }} info</button>
				</div>
				<div class="qa-filters">
					<input class="qa-search" v-model="query" placeholder="🔍 Filtrar hallazgos…" />
					<label class="qa-check"><input type="checkbox" v-model="onlyCurrent"> Solo esta sección</label>
				</div>

				<div v-if="!ran" class="empty">Analizando la integridad del contenido…</div>
				<div v-else-if="!findings.length" class="empty pill-ok">✓ Todo correcto. Sin problemas detectados.</div>
				<div v-else-if="!filtered.length" class="empty">Sin hallazgos que coincidan con el filtro.</div>
				<template v-else>
					<div v-for="g in grouped" :key="g.tab" class="qa-group">
						<div class="qa-group__head">
							<span>{{ g.icon }} {{ g.label }}</span>
							<span class="grow"></span>
							<span class="chip sm">{{ g.items.length }}</span>
						</div>
						<div v-for="(f, i) in g.items" :key="i" class="qa-item" :class="f.level" @click="jump(f)">
							<span class="ic">{{ f.level==='error' ? '⛔' : (f.level==='info' ? 'ℹ️' : '⚠️') }}</span>
							<div>
								<div class="msg">{{ f.message }}</div>
								<div class="qa-fix">🛠️ {{ fixHint(f.code) }}</div>
								<div class="code">{{ f.code }} · ir al elemento →</div>
							</div>
						</div>
					</div>
				</template>
			</div>
		</div>
	</div>
	`,
};
