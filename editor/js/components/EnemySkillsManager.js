// components/EnemySkillsManager.js
// ─────────────────────────────────────────────────────────────────────────────
// Gestor de enemy_skills.json (catálogo de habilidades de ENEMIGO). Cada entrada:
//   `skill_id -> { name{es,en}, role:'attack'|'buff'|'debuff', power_mult,
//                  type:'physical'|'magic'|'ranged', element,
//                  status?{type,chance,turns,power}, self_status?{type,turns} }`.
//   · Los enemigos (data/enemies/<id>.json) referencian estos ids en `skills[]`
//     ({ level, skill_id }). El motor de combate (ViewCombat._choose_enemy_skill)
//     los agrupa por `role` para decidir la acción.
// Antes NO había forma de editarlas desde el editor (había que tocar el JSON a
// mano); esto cierra el hueco de cobertura de `docs/INDEX.md` (Combate/Bestiario).
// Reutiliza el CRUD/atajos comunes de useCollection y el panel de lista común.
// ─────────────────────────────────────────────────────────────────────────────
import { computed } from 'https://unpkg.com/vue@3/dist/vue.esm-browser.prod.js';
import { store, ELEMENTS, getI18n, getI18nFallback, getI18nDisplay, setI18n } from '../store.js';
import { useCollection } from '../lib/useCollection.js';
import EntityListPanel from './EntityListPanel.js';
import EditorToolbar from './EditorToolbar.js';

const ROLES = ['attack', 'buff', 'debuff'];
const ATTACK_TYPES = ['physical', 'magic', 'ranged'];
// Estados sugeridos (texto libre: el motor puede aceptar más). Ofensivos primero,
// luego los de auto-mejora que usan los `self_status` de los buffs.
const STATUS_SUGGEST = ['poison', 'burn', 'bleed', 'stun', 'slow', 'confusion', 'vulnerable'];
const SELF_STATUS_SUGGEST = ['berserk', 'prisa', 'barrera', 'regen'];

const ROLE_ICON = { attack: '⚔️', buff: '🔺', debuff: '🔻' };

export default {
	name: 'EnemySkillsManager',
	components: { EntityListPanel, EditorToolbar },
	setup() {
		const col = useCollection({
			tabId: 'enemySkills',
			dirtyKey: 'enemySkills',
			collection: () => store.enemySkills,
			setCollection: (v) => { store.enemySkills = v; },
			selectedKey: 'selectedEnemySkill',
			clipboardKind: 'enemySkill',
			entityLabel: 'skill de enemigo',
			newIdBase: 'enemy_skill_new',
			makeNew: () => ({
				name: { es: 'Nueva habilidad', en: 'New skill' },
				role: 'attack',
				type: 'physical',
				element: 'physical',
				power_mult: 1.0,
			}),
			searchText: (id, o) => id + ' ' + (o?.name?.es || '') + ' ' + (o?.name?.en || ''),
			filters: [
				{ key: 'role', label: 'Rol', options: ROLES, get: (o) => o?.role },
				{ key: 'element', label: 'Elemento', options: ELEMENTS, get: (o) => o?.element || 'physical' },
			],
			sorts: [
				{ key: 'id', label: 'ID', get: (id) => id },
				{ key: 'name', label: 'Nombre', get: (id, o) => (o?.name?.es || id).toLowerCase() },
				{ key: 'power', label: 'Potencia', get: (id, o) => Number(o?.power_mult) || 0 },
			],
		});
		const current = col.current;
		const isAttack = computed(() => current.value && current.value.role !== 'buff');
		const hasStatus = computed(() => current.value && current.value.status && typeof current.value.status === 'object');
		const hasSelfStatus = computed(() => current.value && current.value.self_status && typeof current.value.self_status === 'object');

		function setName(l, v) { col.edit(() => { setI18n(current.value, 'name', v, l); }); }
		function setField(k, v) { col.edit(() => { current.value[k] = v; }); }
		function setNum(k, v) { col.edit(() => { current.value[k] = Number(v) || 0; }); }

		function setRole(v) {
			col.edit(() => {
				const o = current.value; o.role = v;
				// Ajuste de campos por rol, sin destruir datos existentes:
				if (v === 'buff') {
					if (!o.self_status) o.self_status = { type: 'barrera', turns: 3 };
					delete o.type; delete o.element; delete o.power_mult; delete o.status;
				} else {
					if (o.power_mult == null) o.power_mult = 1.0;
					if (!o.type) o.type = 'physical';
					if (!o.element) o.element = 'physical';
					delete o.self_status;
				}
			});
		}

		function toggleStatus(on) {
			col.edit(() => {
				if (on) current.value.status = { type: 'poison', chance: 0.5, turns: 3, power: 4 };
				else delete current.value.status;
			});
		}
		function setStatus(field, v) {
			col.edit(() => {
				const num = field === 'chance' || field === 'turns' || field === 'power';
				current.value.status[field] = num ? (Number(v) || 0) : v;
			});
		}
		function setSelfStatus(field, v) {
			col.edit(() => {
				current.value.self_status[field] = field === 'turns' ? (Number(v) || 0) : v;
			});
		}

		const elementColors = {
			fire: '#ef4444',
			ice: '#38bdf8',
			lightning: '#eab308',
			thunder: '#eab308',
			wind: '#10b981',
			earth: '#d97706',
			dark: '#a855f7',
			holy: '#fef08a',
			physical: '#94a3b8',
		};

		const skillCardStyle = computed(() => {
			if (!current.value) return {};
			const el = current.value.element || 'physical';
			const color = elementColors[el] || '#3b82f6';
			return {
				borderColor: color,
				boxShadow: `0 0 20px ${color}22`,
			};
		});

		const naturalExplanation = computed(() => {
			if (!current.value) return '';
			const o = current.value;
			if (o.role === 'buff') {
				return `Habilidad de soporte de enemigo: se aplica el estado [${o.self_status?.type || 'buff'}] durante ${o.self_status?.turns || 1} turnos.`;
			}
			let text = `Ataque enemigo ${o.type || 'físico'} (${o.element || 'físico'}) con multiplicador ×${o.power_mult || 1.0}. `;
			if (o.status && o.status.type) {
				text += `Probabilidad del ${Math.round((o.status.chance || 0) * 100)}% de aplicar [${o.status.type}] (${o.status.turns || 1} turnos, potencia ${o.status.power || 0}).`;
			}
			return text;
		});

		return {
			store, col, current, isAttack, hasStatus, hasSelfStatus,
			ROLES, ATTACK_TYPES, ELEMENTS, STATUS_SUGGEST, SELF_STATUS_SUGGEST, ROLE_ICON,
			setName, setField, setNum, setRole, toggleStatus, setStatus, setSelfStatus,
			skillCardStyle, naturalExplanation,
			getI18n, getI18nFallback, getI18nDisplay, setI18n,
		};
	},
	template: `
	<div class="manager">
		<entity-list-panel :c="col" search-placeholder="Buscar skill de enemigo…" new-label="➕ Nueva skill">
			<template #row="{ id, o }">
				<span class="ent-icon">{{ ROLE_ICON[o && o.role] || '⚔️' }}</span>
				<span class="ent-name">{{ (o && o.name && (o.name[store.currentLang] || o.name.en || o.name.es)) || id }}</span>
				<span class="ent-id mono">{{ (o && o.role) || '' }}</span>
			</template>
		</entity-list-panel>

		<section class="editor-pane" v-if="current">
			<editor-toolbar :can-undo="col.canUndo.value" :can-redo="col.canRedo.value"
				:can-paste="col.canPaste.value" :has-current="!!current" :dirty="col.dirty.value"
				:saved-text="col.savedText.value"
				@undo="col.undo()" @redo="col.redo()" @copy="col.copy()" @paste="col.paste()"
				@duplicate="col.duplicate()" @remove="col.remove()" @save="col.doSave()"></editor-toolbar>

			<!-- 🎴 Tarjeta Visual WYSIWYG de Habilidad Enemiga -->
			<div class="skill-card-preview card panel" :style="skillCardStyle" style="margin-bottom:14px; padding:14px; border:2px solid; border-radius:12px; background:linear-gradient(180deg, rgba(20,24,35,0.9), rgba(10,14,20,0.95))">
				<div class="flex" style="justify-content:space-between; align-items:center">
					<div class="flex" style="gap:10px; align-items:center">
						<span style="font-size:32px">{{ ROLE_ICON[current.role] || '⚔️' }}</span>
						<div>
							<h3 style="margin:0; font-size:18px">{{ getI18nDisplay(current.name) || col.selectedId.value }}</h3>
							<div class="mono muted" style="font-size:12px">{{ col.selectedId.value }}</div>
						</div>
					</div>
					<div class="flex" style="gap:6px">
						<span class="type-tag" style="font-size:11px; text-transform:uppercase; font-weight:700">{{ current.element || 'físico' }}</span>
						<span class="type-tag" style="font-size:11px; text-transform:uppercase">{{ current.role }}</span>
					</div>
				</div>

				<div class="flex" style="gap:12px; margin-top:10px; padding:8px; background:rgba(0,0,0,0.3); border-radius:8px">
					<div><b>🎭 Rol:</b> {{ current.role }}</div>
					<div v-if="isAttack"><b>💥 Multiplicador:</b> ×{{ current.power_mult || 1.0 }}</div>
					<div v-if="isAttack"><b>🛡️ Tipo:</b> {{ current.type }}</div>
				</div>

				<div style="margin-top:8px; font-size:12px; padding:6px 10px; background:rgba(239,68,68,0.1); border-left:3px solid #ef4444; border-radius:4px">
					💡 <b>Lógica de combate:</b> {{ naturalExplanation }}
				</div>
			</div>

			<h3 class="sec">☄️ Parámetros de Skill</h3>
			<div class="form-grid">
				<label>ID
					<input class="input mono" type="text" :value="col.selectedId.value" @change="col.rename($event.target.value)" />
				</label>
				<label>Rol
					<select class="input" :value="current.role" @change="setRole($event.target.value)">
						<option v-for="r in ROLES" :key="r" :value="r">{{ ROLE_ICON[r] }} {{ r }}</option>
					</select>
				</label>
			</div>
			<div>
				<label>Nombre [{{ store.currentLang.toUpperCase() }}] <input class="input" type="text" :value="getI18n(current.name)" :placeholder="getI18nFallback(current.name) || 'Nombre de la habilidad...'" @input="setName(store.currentLang, $event.target.value)" /></label>
			</div>

			<!-- Ataque / debuff: tipo, elemento, potencia y estado infligido -->
			<template v-if="isAttack">
				<h3 class="sec" style="margin-top:14px">⚙️ Ataque</h3>
				<div class="form-grid">
					<label>Tipo
						<select class="input f-sm" :value="current.type" @change="setField('type', $event.target.value)">
							<option v-for="t in ATTACK_TYPES" :key="t" :value="t">{{ t }}</option>
						</select>
					</label>
					<label>Elemento
						<select class="input f-sm" :value="current.element" @change="setField('element', $event.target.value)">
							<option v-for="e in ELEMENTS" :key="e" :value="e">{{ e }}</option>
						</select>
					</label>
					<label>Multiplicador de daño
						<input class="input num" type="number" step="0.1" :value="current.power_mult" @input="setNum('power_mult', $event.target.value)" />
					</label>
				</div>

				<label class="flex" style="gap:8px; align-items:center; margin-top:12px">
					<input type="checkbox" :checked="hasStatus" @change="toggleStatus($event.target.checked)" />
					<span>Inflige un estado al golpear</span>
				</label>
				<div v-if="hasStatus" class="form-grid" style="margin-top:8px">
					<label>Estado
						<input class="input mono f-sm" list="es-status-list" :value="current.status.type" @input="setStatus('type', $event.target.value)" />
						<datalist id="es-status-list"><option v-for="s in STATUS_SUGGEST" :key="s" :value="s"></option></datalist>
					</label>
					<label>Probabilidad (0-1) <input class="input num" type="number" step="0.05" min="0" max="1" :value="current.status.chance" @input="setStatus('chance', $event.target.value)" /></label>
					<label>Turnos <input class="input num" type="number" :value="current.status.turns" @input="setStatus('turns', $event.target.value)" /></label>
					<label>Poder <input class="input num" type="number" :value="current.status.power" @input="setStatus('power', $event.target.value)" /></label>
				</div>
			</template>

			<!-- Buff: el enemigo se auto-mejora (self_status) -->
			<template v-else>
				<h3 class="sec" style="margin-top:14px">🔺 Auto-mejora</h3>
				<div class="form-grid" v-if="hasSelfStatus">
					<label>Estado propio
						<input class="input mono f-sm" list="es-selfstatus-list" :value="current.self_status.type" @input="setSelfStatus('type', $event.target.value)" />
						<datalist id="es-selfstatus-list"><option v-for="s in SELF_STATUS_SUGGEST" :key="s" :value="s"></option></datalist>
					</label>
					<label>Turnos <input class="input num" type="number" :value="current.self_status.turns" @input="setSelfStatus('turns', $event.target.value)" /></label>
				</div>
			</template>
		</section>

		<section class="editor-pane empty" v-else>
			<p class="muted">Selecciona o crea una skill de enemigo.</p>
		</section>
	</div>
	`,
};
