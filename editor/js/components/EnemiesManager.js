// components/EnemiesManager.js
// ─────────────────────────────────────────────────────────────────────────────
// Gestor de enemies.json: lista con buscador + filtro por elemento, formulario
// de edición (texto/icono/sprite/IA), estadísticas base + escala por nivel,
// selector de habilidades por nivel de desbloqueo y editor de tabla de botín.
// Incluye un DESLIZADOR DE NIVEL (1-99) que recalcula stats en vivo y resalta
// las habilidades desbloqueadas a ese nivel.
// ─────────────────────────────────────────────────────────────────────────────
import { computed, ref } from 'https://unpkg.com/vue@3/dist/vue.esm-browser.prod.js';
import { store, ELEMENTS, ENEMY_AI, LOOT_KINDS, getI18n, getI18nFallback, getI18nDisplay, setI18n } from '../store.js';
import { goTo } from '../nav.js';
import * as FS from '../fs.js';
import { useCollection } from '../lib/useCollection.js';
import EntityListPanel from './EntityListPanel.js';
import EditorToolbar from './EditorToolbar.js';
import CombatSandboxModal from './CombatSandboxModal.js';

// task3_rebalanceo_global_limpieza_y_optimizacion.md FASE2: HP/Ataque/Defensa
// ya NO se editan por enemigo (base+escala): se generan proceduralmente por
// nivel + arquetipo en EnemyDatabase.gd. Aquí solo quedan editables la esquiva
// (que conserva su propio ritmo por enemigo) y las recompensas de XP/oro.
const ARCHETYPES = ['balanced', 'tank', 'glass_cannon', 'boss'];
// Mismas fórmulas/multiplicadores que EnemyDatabase.gd (_hp_base/_atk_base/
// _def_base/ARCHETYPE_MULTIPLIERS), duplicadas aquí solo para la vista previa
// en vivo del simulador de nivel — si cambias una, cambia la otra.
const ARCHETYPE_MULTIPLIERS = {
	balanced:     { hp: 1.0,   atk: 1.0,  def: 1.0 },
	tank:         { hp: 1.45,  atk: 0.80, def: 1.35 },
	glass_cannon: { hp: 0.75,  atk: 1.30, def: 0.70 },
	boss:         { hp: 2.50,  atk: 1.20, def: 1.20 },
};
function hpBase(level) { return 8.0 + 2.0 * level + 0.08 * Math.pow(level, 1.85); }
function atkBase(level) { return 2.5 + 1.2 * level + 0.02 * Math.pow(level, 1.8); }
function defBase(level) { return Math.max(0.0, 0.4 * (level - 1) + 0.01 * Math.pow(level, 1.8)); }
const DODGE_FIELDS = [
	['base_dodge', 'dodge_scale', 'Esquiva %'],
];
const REWARD_FIELDS = [
	['xp_reward_base', 'xp_reward_scale', 'XP'],
	['gold_reward_base', 'gold_reward_scale', 'Oro'],
];

export const GAME_ZONES = [
	{ value: 'zona_1_yelmo', label: 'Zona 1 — Yelmo (Nv. 1-5)', short: 'Z1 Yelmo' },
	{ value: 'zona_2_nieve', label: 'Zona 2 — Nieve (Nv. 5-7)', short: 'Z2 Nieve' },
	{ value: 'zona_3_sylphrena', label: 'Zona 3 — Sylphrena (Nv. 7-15)', short: 'Z3 Sylphrena' },
	{ value: 'zona_4_celestia', label: 'Zona 4 — Celestia (Nv. 15-25)', short: 'Z4 Celestia' },
	{ value: 'zona_5_desierto', label: 'Zona 5 — Desierto (Nv. 25-35)', short: 'Z5 Desierto' },
	{ value: 'zona_6_arcanum', label: 'Zona 6 — Arcanum (Nv. 35-45)', short: 'Z6 Arcanum' },
	{ value: 'zona_7_epilogo', label: 'Zona 7 — Epílogo (Nv. 45-50)', short: 'Z7 Epílogo' },
	{ value: 'zona_secreta', label: 'Zona Secreta (Nv. 50)', short: 'Z. Secreta' },
	{ value: 'sin_asignar', label: '⚠️ Sin zona asignada (Huérfano / Por revisar)', short: 'Sin zona' },
];

const KNOWN_BOSSES = new Set([
	'guardian_supremo', 'devorador_dunas', 'bandido_jefe', 'arcanium_experimento',
	'lobo_alfa', 'orco_berserker', 'temple_boss_archer', 'temple_boss_elemental',
	'temple_boss_warrior', 'temple_boss_psychic', 'temple_boss_healer', 'temple_boss_time',
	'jefe_puerto', 'automata_jefe', 'cave_boss', 'guardian_celeste', 'titan_antiguo',
	'draco_abismal', 'sombra_eterna', 'quimera_suprema'
]);

function isBoss(id, e) {
	if (e?.archetype === 'boss' || e?.is_boss) return true;
	if (KNOWN_BOSSES.has(id)) return true;
	if (store.dungeons) {
		for (const d of Object.values(store.dungeons)) {
			if (d?.boss === id) return true;
		}
	}
	return false;
}

function getEnemyZone(id, e) {
	return e?.zone || 'sin_asignar';
}

function zoneShortName(z) {
	const found = GAME_ZONES.find(item => item.value === z);
	return found ? found.short : z;
}

export default {
	name: 'EnemiesManager',
	components: { EntityListPanel, EditorToolbar, CombatSandboxModal },
	setup() {
		const sandboxOpen = ref(false);
		const level = ref(1);
		const spriteList = ref([]);

		const col = useCollection({
			tabId: 'enemies',
			dirtyKey: 'enemies',
			dirtyMap: () => store.dirtyEnemies,
			collection: () => store.enemies,
			setCollection: (v) => { store.enemies = v; },
			selectedKey: 'selectedEnemy',
			clipboardKind: 'enemy',
			entityLabel: 'enemigo',
			newIdBase: 'enemy_new',
			// enemies es colección "un fichero por id" (data/enemies/<id>.json): al
			// borrar/renombrar hay que borrar también el fichero en disco del id saliente.
			onRemove: (id) => FS.deleteCollectionItem('enemies', id),
			makeNew: () => ({
				name: { es: 'Nuevo enemigo', en: 'New enemy' }, icon: '👾', image: '',
				archetype: 'balanced', attack_type: 'physical', zone: 'sin_asignar', is_boss: false,
				base_dodge: 4.0, dodge_scale: 0.2, element: 'physical', weak_to: [], resist: [],
				ai: 'aggressive', xp_reward_base: 20, xp_reward_scale: 4, gold_reward_base: 12, gold_reward_scale: 2,
				skills: [{ level: 1, skill_id: 'strike' }], loot: [{ kind: 'gold', min: 2, max: 8 }],
			}),
			searchText: (id, e) => id + ' ' + (e.name?.es || '') + ' ' + (e.name?.en || '') + ' ' + (e.zone || ''),
			filters: [
				{
					key: 'bossType',
					label: 'Tipo',
					options: [
						{ value: 'boss', label: '👑 Solo Bosses / Jefes' },
						{ value: 'regular', label: '👾 Solo Enemigos Comunes' },
					],
					get: (e, id) => isBoss(id, e) ? 'boss' : 'regular'
				},
				{
					key: 'zone',
					label: 'Zona',
					options: GAME_ZONES.map(z => ({ value: z.value, label: z.label })),
					get: (e, id) => getEnemyZone(id, e)
				},
				{ key: 'element', label: 'Elemento', options: ELEMENTS, get: (e) => e.element },
				{ key: 'archetype', label: 'Arquetipo', options: ARCHETYPES, get: (e) => e.archetype },
				{ key: 'ai', label: 'IA', options: ENEMY_AI, get: (e) => e.ai },
			],
			sorts: [
				{ key: 'zone', label: 'Zona', get: (id, e) => getEnemyZone(id, e) },
				{ key: 'name', label: 'Nombre', get: (id, e) => (e.name?.es || id).toLowerCase() },
				{ key: 'id', label: 'ID', get: (id) => id },
				{ key: 'archetype', label: 'Arquetipo', get: (id, e) => e.archetype || '' },
				{ key: 'element', label: 'Elemento', get: (id, e) => e.element || '' },
			],
		});
		const current = col.current;

		FS.listAssets('enemy').then(names => { spriteList.value = names; });

		function setName(lang, v) { col.edit(() => { setI18n(current.value, 'name', v, lang); }); }
		function setField(k, v) { col.edit(() => { current.value[k] = v; }); }
		function setNum(k, v) { col.edit(() => { current.value[k] = Number(v) || 0; }); }

		// ── Elementos débiles/resistentes (toggles) ──
		function toggleTag(field, el) {
			col.edit(() => {
				const e = current.value;
				if (!e[field]) e[field] = [];
				const i = e[field].indexOf(el);
				if (i >= 0) e[field].splice(i, 1); else e[field].push(el);
			});
		}

		// ── Habilidades ──
		function addSkill() {
			col.edit(() => {
				if (!current.value.skills) current.value.skills = [];
				current.value.skills.push({ level: 1, skill_id: 'new_skill' });
			});
		}
		function removeSkill(i) { col.edit(() => { current.value.skills.splice(i, 1); }); }

		// ── Loot ──
		function addLoot() {
			col.edit(() => {
				if (!current.value.loot) current.value.loot = [];
				current.value.loot.push({ kind: 'gold', min: 1, max: 5 });
			});
		}
		function removeLoot(i) { col.edit(() => { current.value.loot.splice(i, 1); }); }
		function setLoot(i, k, v) {
			// Number(v) sin fallback serializa NaN → null en JSON (Godot lo leería
			// como 0 inesperado o rompería el parse tipado). `|| 0` lo evita.
			col.edit(() => { current.value.loot[i][k] = (k === 'id' || k === 'kind') ? v : (Number(v) || 0); });
		}
		function touch() { col.touch(); }

		// ── Cálculo de escalado por nivel (para el slider) ──
		// HP/Ataque/Defensa: formula procedural por arquetipo (igual que EnemyDatabase.gd).
		function proceduralStat(key) {
			const e = current.value; if (!e) return 0;
			const mult = ARCHETYPE_MULTIPLIERS[e.archetype] || ARCHETYPE_MULTIPLIERS.balanced;
			const L = level.value;
			if (key === 'hp') return Math.round(hpBase(L) * mult.hp);
			if (key === 'attack') return Math.round(atkBase(L) * mult.atk);
			if (key === 'phys_defense' || key === 'mag_defense') return Math.round(defBase(L) * mult.def);
			return 0;
		}
		// Esquiva y recompensas: siguen siendo base + escala por enemigo.
		function scaled(baseKey, scaleKey) {
			const e = current.value; if (!e) return 0;
			const steps = Math.max(0, level.value - 1);
			const val = (Number(e[baseKey]) || 0) + (Number(e[scaleKey]) || 0) * steps;
			return baseKey === 'base_dodge' ? val.toFixed(1) : Math.round(val);
		}
		// Barra visual: proporción respecto a un tope razonable por stat.
		const PROCEDURAL_CAPS = { hp: 1500, attack: 120, phys_defense: 60, mag_defense: 60 };
		function proceduralBarPct(key) {
			return Math.min(100, (proceduralStat(key) / (PROCEDURAL_CAPS[key] || 100)) * 100);
		}
		function skillUnlocked(s) { return Number(s.level) <= level.value; }

		const spriteUrl = computed(() => {
			const img = current.value?.image || '';
			if (!img) return null;
			const file = img.split('/').pop();
			return FS.assetUrl('enemy', file);
		});

		// Catálogo de habilidades de enemigo (enemy_skills.json) para el
		// desplegable con búsqueda del skill_id (antes texto libre a mano).
		const enemySkillIds = computed(() => Object.keys(store.enemySkills || {}));
		function enemySkillLabel(id) {
			const s = store.enemySkills?.[id];
			return s ? (id + ' — ' + (s.name?.es || id)) : id;
		}

		function getEnemyRowSprite(id, o) {
			if (!o) return null;
			const img = o.image || o.sprite || '';
			if (img && typeof img === 'string') {
				const file = img.split('/').pop();
				if (file && file.includes('.')) return FS.assetUrl('enemy', file);
			}
			if (spriteList.value && spriteList.value.length) {
				const match = spriteList.value.find(s => {
					const base = s.toLowerCase().replace(/\.png$/, '');
					const idLow = id.toLowerCase();
					return base === idLow || base === 'en_' + idLow || base.replace(/^en_/, '') === idLow;
				});
				if (match) return FS.assetUrl('enemy', match);
			}
			return FS.assetUrl('enemy', id + '.png');
		}

		return {
			store, col, level, current, spriteList, goTo,
			ELEMENTS, ENEMY_AI, LOOT_KINDS, ARCHETYPES, DODGE_FIELDS, REWARD_FIELDS, GAME_ZONES,
			setName, setField, setNum, toggleTag, addSkill, removeSkill,
			addLoot, removeLoot, setLoot, touch, scaled, proceduralStat, proceduralBarPct, skillUnlocked, spriteUrl,
			getEnemyRowSprite, isBoss, getEnemyZone, zoneShortName,
			enemySkillIds, enemySkillLabel,
			sandboxOpen,
			getI18n, getI18nFallback, getI18nDisplay, setI18n,
		};
	},
	template: `
	<div class="manager">
		<!-- Panel izquierdo: lista común con miniaturas reales de sprites y filtros -->
		<entity-list-panel :c="col" search-placeholder="Buscar enemigo…">
			<template #row="{ id, o }">
				<img :src="getEnemyRowSprite(id, o)" class="ent-thumb" alt=""
					@error="e => { e.target.style.display='none'; if (e.target.nextElementSibling) e.target.nextElementSibling.style.display='inline-block'; }" />
				<span class="ent-icon" style="display:none">{{ o.icon || '👾' }}</span>
				<div style="flex:1; min-width:0; display:flex; flex-direction:column; gap:2px">
					<div style="display:flex; align-items:center; gap:4px">
						<span v-if="isBoss(id, o)" title="Jefe / Boss" style="font-size:12px; line-height:1">👑</span>
						<span class="ent-name" style="font-size:12px">{{ getI18nDisplay(o.name) || id }}</span>
					</div>
					<div style="display:flex; justify-content:space-between; align-items:center; font-size:10px; color:var(--txt-2)">
						<span class="ent-id mono">{{ id }}</span>
						<span v-if="o.zone && o.zone !== 'sin_asignar'" style="padding:1px 5px; border-radius:4px; background:rgba(255,255,255,0.06); font-size:9px; font-weight:600">{{ zoneShortName(o.zone) }}</span>
					</div>
				</div>
			</template>
		</entity-list-panel>

		<!-- Panel derecho: edición -->
		<section class="editor-pane" v-if="current">
			<div class="row gap" style="align-items:center; justify-content:space-between; margin-bottom:8px">
				<editor-toolbar :can-undo="col.canUndo.value" :can-redo="col.canRedo.value"
					:can-paste="col.canPaste.value" :has-current="!!current" :dirty="col.dirty.value"
					:saved-text="col.savedText.value"
					@undo="col.undo()" @redo="col.redo()" @copy="col.copy()" @paste="col.paste()"
					@duplicate="col.duplicate()" @remove="col.remove()" @save="col.doSave()"></editor-toolbar>
				<button class="btn primary sm" @click="sandboxOpen=true" title="Simular 50 batallas automáticas y balance">⚔️ Probar Combate (Sandbox)</button>
			</div>

			<div class="form-grid">
				<label>ID <input class="input mono" :value="col.selectedId.value" @change="col.rename($event.target.value)" /></label>
				<label>Icono <input class="input f-xs" :value="current.icon" @input="setField('icon',$event.target.value)" /></label>
				<label>Nombre [{{ store.currentLang.toUpperCase() }}] <input class="input" :value="getI18n(current.name)" :placeholder="getI18nFallback(current.name) || 'Nombre del enemigo...'" @input="setName(store.currentLang,$event.target.value)" /></label>
				<label>Sprite
					<select class="input" :value="(current.image||'').split('/').pop()" @change="setField('image', $event.target.value ? 'res://assets/combat/enemies/'+$event.target.value : '')">
						<option value="">(ninguno)</option>
						<option v-for="s in spriteList" :key="s" :value="s">{{ s }}</option>
					</select>
				</label>
				<label>Zona asignada
					<select class="input" :value="current.zone || 'sin_asignar'" @change="setField('zone', $event.target.value)">
						<option v-for="z in GAME_ZONES" :key="z.value" :value="z.value">{{ z.label }}</option>
					</select>
				</label>
				<label class="check" style="align-self:end; margin-bottom:8px">
					<input type="checkbox" :checked="isBoss(col.selectedId.value, current)" @change="setField('is_boss', $event.target.checked); if ($event.target.checked && current.archetype !== 'boss') setField('archetype', 'boss');" />
					<span style="font-weight:700">👑 Es Jefe / Boss de Mazmorra</span>
				</label>
				<label>IA
					<select class="input" :value="current.ai" @change="setField('ai',$event.target.value)">
						<option v-for="a in ENEMY_AI" :key="a" :value="a">{{ a }}</option>
					</select>
				</label>
				<label>Elemento
					<select class="input" :value="current.element" @change="setField('element',$event.target.value)">
						<option v-for="el in ELEMENTS" :key="el" :value="el">{{ el }}</option>
					</select>
				</label>
				<label>Tipo ataque
					<select class="input" :value="current.attack_type" @change="setField('attack_type',$event.target.value)">
						<option value="physical">physical</option>
						<option value="magic">magic</option>
						<option value="ranged">ranged</option>
					</select>
				</label>
				<label>Arquetipo (define HP/Ataque/Defensa por fórmula)
					<select class="input" :value="current.archetype" @change="setField('archetype',$event.target.value)">
						<option v-for="a in ARCHETYPES" :key="a" :value="a">{{ a }}</option>
					</select>
				</label>
			</div>

			<div class="preview-row" v-if="spriteUrl">
				<img :src="spriteUrl" class="sprite-preview" alt="sprite" />
			</div>

			<!-- Débil / Resiste -->
			<div class="tag-block">
				<div><span class="lbl">Débil a:</span>
					<button v-for="el in ELEMENTS" :key="'w'+el" class="tag" :class="{ on: (current.weak_to||[]).includes(el) }" @click="toggleTag('weak_to', el)">{{ el }}</button>
				</div>
				<div><span class="lbl">Resiste:</span>
					<button v-for="el in ELEMENTS" :key="'r'+el" class="tag" :class="{ on: (current.resist||[]).includes(el) }" @click="toggleTag('resist', el)">{{ el }}</button>
				</div>
			</div>

			<!-- Esquiva (única estadística de combate que sigue siendo base+escala por enemigo) -->
			<h3 class="sec">📊 Esquiva y recompensas</h3>
			<div class="stat-grid">
				<div class="stat-row head"><span></span><span>Base</span><span>+ / nivel</span></div>
				<div class="stat-row" v-for="f in DODGE_FIELDS" :key="f[0]">
					<span class="lbl">{{ f[2] }}</span>
					<input class="input num" type="number" step="0.1" :value="current[f[0]]" @input="setNum(f[0],$event.target.value)" />
					<input class="input num" type="number" step="0.1" :value="current[f[1]]" @input="setNum(f[1],$event.target.value)" />
				</div>
				<div class="stat-row" v-for="f in REWARD_FIELDS" :key="f[0]">
					<span class="lbl">{{ f[2] }}</span>
					<input class="input num" type="number" step="0.1" :value="current[f[0]]" @input="setNum(f[0],$event.target.value)" />
					<input class="input num" type="number" step="0.1" :value="current[f[1]]" @input="setNum(f[1],$event.target.value)" />
				</div>
			</div>

			<!-- ⭐ Level slider premium: HP/Ataque/Defensa por fórmula de arquetipo (solo lectura) -->
			<div class="level-sim">
				<div class="row between">
					<h3 class="sec">🎮️ Simulador de nivel ({{ current.archetype || 'balanced' }})</h3>
					<span class="level-badge">Nv. {{ level }}</span>
				</div>
				<input class="range" type="range" min="1" max="25" v-model.number="level" />
				<div class="sim-stats">
					<div class="sim-stat">
						<div class="row between"><span>HP</span><b>{{ proceduralStat('hp') }}</b></div>
						<div class="minibar"><i :style="{ width: proceduralBarPct('hp')+'%' }"></i></div>
					</div>
					<div class="sim-stat">
						<div class="row between"><span>Ataque</span><b>{{ proceduralStat('attack') }}</b></div>
						<div class="minibar"><i :style="{ width: proceduralBarPct('attack')+'%' }"></i></div>
					</div>
					<div class="sim-stat">
						<div class="row between"><span>Def. física</span><b>{{ proceduralStat('phys_defense') }}</b></div>
						<div class="minibar"><i :style="{ width: proceduralBarPct('phys_defense')+'%' }"></i></div>
					</div>
					<div class="sim-stat">
						<div class="row between"><span>Def. mágica</span><b>{{ proceduralStat('mag_defense') }}</b></div>
						<div class="minibar"><i :style="{ width: proceduralBarPct('mag_defense')+'%' }"></i></div>
					</div>
					<div class="sim-stat">
						<div class="row between"><span>Esquiva %</span><b>{{ scaled('base_dodge','dodge_scale') }}</b></div>
					</div>
				</div>
				<div class="sim-rewards">
					<span>XP: <b>{{ scaled('xp_reward_base','xp_reward_scale') }}</b></span>
					<span>Oro: <b>{{ scaled('gold_reward_base','gold_reward_scale') }}</b></span>
				</div>
			</div>

			<!-- Habilidades -->
			<h3 class="sec">✨ Habilidades (desbloqueo por nivel)</h3>
			<div class="skill-list">
				<div class="skill-row" v-for="(s,i) in (current.skills||[])" :key="i" :class="{ locked: !skillUnlocked(s), unlocked: skillUnlocked(s) }">
					<input class="input num" type="number" min="1" max="99" v-model.number="s.level" @input="touch" title="Nivel mínimo" />
					<input class="input mono" v-model="s.skill_id" @input="touch" placeholder="skill_id" list="enemy-skill-ids" />
					<button class="btn ghost xs" :disabled="!s.skill_id" @click="goTo('enemySkills', s.skill_id)" title="Editar esta skill de enemigo (o crearla si no existe)">✎</button>
					<span class="skill-flag">{{ skillUnlocked(s) ? '✔ disponible' : '🔒 Nv.'+s.level }}</span>
					<button class="btn danger xs" @click="removeSkill(i)">✕</button>
				</div>
				<datalist id="enemy-skill-ids"><option v-for="sid in enemySkillIds" :key="sid" :value="sid">{{ enemySkillLabel(sid) }}</option></datalist>
				<button class="btn ghost sm" @click="addSkill">＋ Habilidad</button>
			</div>

			<!-- Loot -->
			<h3 class="sec">🎁 Tabla de botín</h3>
			<div class="loot-list">
				<div class="loot-row" v-for="(l,i) in (current.loot||[])" :key="i">
					<select class="input" :value="l.kind" @change="setLoot(i,'kind',$event.target.value)">
						<option v-for="k in LOOT_KINDS" :key="k" :value="k">{{ k }}</option>
					</select>
					<input v-if="l.kind==='resource'||l.kind==='consumable'" class="input mono" :value="l.id" @input="setLoot(i,'id',$event.target.value)" placeholder="item id" />
					<button v-if="l.kind==='resource'||l.kind==='consumable'" class="btn ghost xs" :disabled="!l.id" @click="goTo('items', l.id)" title="Editar este objeto">✎</button>
					<input v-if="l.kind!=='equipment'" class="input num" type="number" :value="l.min" @input="setLoot(i,'min',$event.target.value)" placeholder="min" />
					<input v-if="l.kind!=='equipment'" class="input num" type="number" :value="l.max" @input="setLoot(i,'max',$event.target.value)" placeholder="max" />
					<input v-if="l.kind!=='gold'" class="input num" type="number" step="0.05" :value="l.chance" @input="setLoot(i,'chance',$event.target.value)" placeholder="chance" />
					<input v-if="l.kind==='equipment'" class="input num" type="number" :value="l.level" @input="setLoot(i,'level',$event.target.value)" placeholder="nivel" />
					<button class="btn danger xs" @click="removeLoot(i)">✕</button>
				</div>
				<button class="btn ghost sm" @click="addLoot">＋ Entrada de botín</button>
			</div>
		</section>

		<section class="editor-pane empty" v-else>
			<p class="muted">Selecciona o crea un enemigo.</p>
		</section>

		<!-- MODAL DE SANDBOX DE COMBATE Y BALANCE -->
		<combat-sandbox-modal v-if="current" :open="sandboxOpen" :enemy="current" :enemy-id="col.selectedId.value"
			@close="sandboxOpen=false"></combat-sandbox-modal>
	</div>
	`,
};
