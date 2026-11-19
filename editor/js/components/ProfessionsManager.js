// components/ProfessionsManager.js
// ─────────────────────────────────────────────────────────────────────────────
// Gestor de professions.json: lista de profesiones en barra lateral, formulario
// bilingüe (nombre), icono, color y tabla/lista de habilidades editables y reordenables.
// Permite modificar el nivel de aprendizaje y reordenar el orden de aprendizaje.
// ─────────────────────────────────────────────────────────────────────────────
import { computed, ref } from 'https://unpkg.com/vue@3/dist/vue.esm-browser.prod.js';
import { store, markDirty, ELEMENTS, getI18n, getI18nFallback, getI18nDisplay, setI18n } from '../store.js';
import { goTo } from '../nav.js';
import { useCollection } from '../lib/useCollection.js';
import EntityListPanel from './EntityListPanel.js';
import EditorToolbar from './EditorToolbar.js';

export default {
	name: 'ProfessionsManager',
	components: { EntityListPanel, EditorToolbar },
	setup() {
		const skillTypes = ['physical', 'magic', 'ranged', 'heal', 'defense', 'buff', 'passive', 'none'];
		// Vista compacta: tabla densa con TODAS las habilidades de un vistazo
		// (persistida en localStorage). Alterna con la vista de tarjetas detallada.
		const compactView = ref(localStorage.getItem('prof_compact') === '1');
		function toggleCompact() { compactView.value = !compactView.value; localStorage.setItem('prof_compact', compactView.value ? '1' : '0'); }

		const col = useCollection({
			tabId: 'professions',
			dirtyKey: 'professions',
			collection: () => store.professions,
			setCollection: (v) => { store.professions = v; },
			selectedKey: 'selectedProfession',
			clipboardKind: 'profession',
			entityLabel: 'profesión',
			newIdBase: 'Nuevo_Trabajo',
			makeNew: () => ({
				name: { es: 'Nueva Profesión', en: 'New Job' },
				icon: '🧝', color: '3b82f6', skills: [],
			}),
			searchText: (id, prof) => id + ' ' + (prof.name?.es || ''),
			sorts: [
				{ key: 'name', label: 'Nombre', get: (id, prof) => (prof.name?.es || id).toLowerCase() },
				{ key: 'id', label: 'ID', get: (id) => id },
			],
		});
		const current = col.current;

		function touch() { col.touch(); }

		function setName(l, v) { col.edit(() => { setI18n(current.value, 'name', v, l); }); }
		function setField(k, v) { col.edit(() => { if (v === '' || v == null) delete current.value[k]; else current.value[k] = v; }); }

		// Resuelve las habilidades combinando la progresión de professions.json con las definiciones de skills.json
		const resolvedSkills = computed(() => {
			if (!current.value || !current.value.skills) return [];
			return current.value.skills.map((entry) => {
				const sid = entry.id;
				const def = store.skills?.[sid] || {};
				return {
					level: entry.level,
					id: sid,
					icon: def.icon || '✨',
					name: def.name || {},
					cost: def.cost || 0,
					type: def.type || 'physical',
					power: def.power || 1.0,
					element: def.element || 'physical',
					desc: def.desc || {},
					status: def.status || null
				};
			});
		});

		// ── Habilidades ──
		function addSkill() {
			if (!current.value) return;
			if (!current.value.skills) current.value.skills = [];

			const profId = store.selectedProfession;
			// Crear una clave única para la nueva habilidad
			const newId = `${profId.toLowerCase().replace(' ', '_')}_skill_${Date.now()}`;

			// Crear definición en skills.json
			if (!store.skills) store.skills = {};
			store.skills[newId] = {
				id: newId,
				name: { es: 'Nueva Habilidad', en: 'New Skill' },
				icon: '✨',
				type: 'physical',
				element: 'physical',
				power: 1.0,
				cost: 0,
				desc: { es: '', en: '' }
			};
			markDirty('skills');

			// Añadir a la progresión de la profesión seleccionada
			current.value.skills.push({ level: 1, id: newId });
			touch();
		}

		function removeSkill(idx) {
			if (!current.value || !current.value.skills) return;
			const removed = current.value.skills.splice(idx, 1);
			touch();

			// Si la habilidad no está en uso por otra profesión, se podría limpiar de skills.json opcionalmente
			if (removed.length > 0 && store.skills) {
				const sid = removed[0].id;
				let referenced = false;
				for (const p of Object.values(store.professions || {})) {
					if (p.skills && p.skills.some(s => s.id === sid)) {
						referenced = true;
						break;
					}
				}
				if (!referenced && store.skills[sid]) {
					delete store.skills[sid];
					markDirty('skills');
				}
			}
		}

		function moveSkill(idx, dir) {
			if (!current.value || !current.value.skills) return;
			const targetIdx = idx + dir;
			if (targetIdx < 0 || targetIdx >= current.value.skills.length) return;
			// Intercambiar progresión
			const temp = current.value.skills[idx];
			current.value.skills[idx] = current.value.skills[targetIdx];
			current.value.skills[targetIdx] = temp;
			touch();
		}

		function updateSkillField(idx, field, value) {
			if (!current.value || !current.value.skills) return;
			const sid = current.value.skills[idx].id;

			if (field === 'level') {
				current.value.skills[idx].level = Number(value) || 0;
				touch();
				return;
			}

			// Asegurar que exista la definición en skills.json
			if (!store.skills[sid]) {
				store.skills[sid] = {
					id: sid,
					name: { es: '', en: '' },
					desc: { es: '', en: '' },
					icon: '✨',
					type: 'physical',
					element: 'physical',
					power: 1.0,
					cost: 0
				};
			}

			const sDef = store.skills[sid];
			if (field === 'icon') sDef.icon = value;
			else if (field === 'type') sDef.type = value;
			else if (field === 'cost') sDef.cost = Number(value) || 0;
			else if (field === 'power') sDef.power = Number(value) || 0;
			else if (field === 'element') sDef.element = value;
			else if (field.startsWith('name.')) setI18n(sDef, 'name', value, field.split('.')[1]);
			else if (field.startsWith('desc.')) setI18n(sDef, 'desc', value, field.split('.')[1]);
			markDirty('skills');
		}

		function toggleSkillStatus(idx) {
			if (!current.value || !current.value.skills) return;
			const sid = current.value.skills[idx].id;
			if (!store.skills[sid]) return;
			const sDef = store.skills[sid];

			if (sDef.status) {
				delete sDef.status;
			} else {
				sDef.status = { type: 'stun', turns: 1, target: 'enemy' };
			}
			markDirty('skills');
		}

		function updateSkillStatusField(idx, field, value) {
			if (!current.value || !current.value.skills) return;
			const sid = current.value.skills[idx].id;
			if (!store.skills[sid] || !store.skills[sid].status) return;
			const status = store.skills[sid].status;

			if (field === 'turns') status.turns = Number(value) || 1;
			else status[field] = value;
			markDirty('skills');
		}

		// ── Visualizador de curva de stats ──
		const previewLevel = ref(1);
		const statsAtLevel = computed(() => {
			const c = current.value?.stats || {};
			const lvl = previewLevel.value;
			return {
				max_hp: Math.round((c.max_hp_base || 100) + (lvl - 1) * (c.max_hp_scale || 10)),
				max_mp: Math.round((c.max_mp_base || 20) + (lvl - 1) * (c.max_mp_scale || 2)),
				attack: Math.round((c.attack_base || 10) + (lvl - 1) * (c.attack_scale || 2)),
				defense: Math.round((c.defense_base || 5) + (lvl - 1) * (c.defense_scale || 1)),
				magic_atk: Math.round((c.magic_atk_base || 5) + (lvl - 1) * (c.magic_atk_scale || 1.5)),
				magic_def: Math.round((c.magic_def_base || 5) + (lvl - 1) * (c.magic_def_scale || 1)),
				speed: Math.round((c.speed_base || 10) + (lvl - 1) * (c.speed_scale || 0.5)),
			};
		});

		return {
			store, col, current, skillTypes, compactView, toggleCompact, ELEMENTS,
			setName, setField, resolvedSkills, addSkill, removeSkill, moveSkill, updateSkillField,
			goTo, previewLevel, statsAtLevel, toggleSkillStatus, updateSkillStatusField,
			getI18n, getI18nFallback, getI18nDisplay, setI18n,
		};
	},
	template: `
	<div class="manager">
		<!-- Barra lateral común -->
		<entity-list-panel :c="col" search-placeholder="Buscar profesión…" new-label="➕ Nueva">
			<template #row="{ id, o }">
				<span class="ent-icon">{{ o.icon || '🧝' }}</span>
				<span class="ent-name">{{ (o && o.name && (o.name[store.currentLang] || o.name.en || o.name.es)) || id }}</span>
				<span class="ent-id mono">{{ id }}  ·  {{ (o.skills || []).length }} habs</span>
			</template>
		</entity-list-panel>

		<!-- Panel del editor -->
		<section class="editor-pane" v-if="current">
			<editor-toolbar :can-undo="col.canUndo.value" :can-redo="col.canRedo.value"
				:can-paste="col.canPaste.value" :has-current="!!current" :dirty="col.dirty.value"
				:saved-text="col.savedText.value"
				@undo="col.undo()" @redo="col.redo()" @copy="col.copy()" @paste="col.paste()"
				@duplicate="col.duplicate()" @remove="col.remove()" @save="col.doSave()"></editor-toolbar>

			<h3 class="sec">ℹ️ Configuración de Clase</h3>
			<div class="form-grid">
				<label>ID
					<input class="input mono" type="text" :value="col.selectedId.value" @change="col.rename($event.target.value)" />
				</label>
				<label>Icono
					<input class="input f-xs" type="text" :value="current.icon" @input="setField('icon', $event.target.value)" />
				</label>
				<label>Color (Hexadecimal)
					<input class="input" type="color" :value="current.color ? (current.color.startsWith('#') ? current.color : '#' + current.color) : '#3b82f6'" @input="setField('color', $event.target.value.replace('#', ''))" />
				</label>
			</div>

			<div>
				<label>Nombre [{{ store.currentLang.toUpperCase() }}]
					<input class="input" type="text" :value="getI18n(current.name)" :placeholder="getI18nFallback(current.name) || 'Nombre de la profesión...'" @input="setName(store.currentLang, $event.target.value)" />
				</label>
			</div>

			<!-- Visualizador de Curva de Stats de la Profesión -->
			<div class="card panel prof-stats-curve-card" style="margin-top:20px; padding:14px">
				<div class="row between" style="align-items:center; margin-bottom:10px">
					<h3 class="sec" style="margin:0">📈 Curva de Estadísticas por Nivel</h3>
					<div class="row gap" style="align-items:center">
						<span class="level-badge">Nivel {{ previewLevel }}</span>
						<input type="range" min="1" max="50" v-model.number="previewLevel" style="width:140px" />
					</div>
				</div>
				<div class="prof-stats-grid">
					<div class="prof-stat-pill"><span class="lbl">❤️ HP:</span><strong class="mono">{{ statsAtLevel.hp }}</strong></div>
					<div class="prof-stat-pill"><span class="lbl">💧 MP:</span><strong class="mono" style="color:#38bdf8">{{ statsAtLevel.mp }}</strong></div>
					<div class="prof-stat-pill"><span class="lbl">⚔️ ATK:</span><strong class="mono" style="color:#f87171">{{ statsAtLevel.atk }}</strong></div>
					<div class="prof-stat-pill"><span class="lbl">🛡️ DEF:</span><strong class="mono" style="color:#60a5fa">{{ statsAtLevel.def }}</strong></div>
				</div>
			</div>

			<div class="pane-header" style="margin-top: 30px;">
				<h3 class="sec">✨ Habilidades de Profesión</h3>
				<div style="display:flex; gap:6px;">
					<button class="btn sm ghost" @click="toggleCompact" :title="compactView ? 'Vista detallada' : 'Ver todas de un vistazo'">
						{{ compactView ? '🗂️ Detalle' : '📊 Compacta' }}
					</button>
					<button class="btn secondary sm" @click="addSkill">➕ Añadir Habilidad</button>
				</div>
			</div>

			<!-- Vista COMPACTA: tabla densa con todas las habilidades de un vistazo -->
			<table v-if="compactView" class="prof-skill-table">
				<thead>
					<tr><th>Nv</th><th></th><th>Nombre</th><th>MP</th><th>Tipo</th><th>Pot.</th><th>Elem.</th><th>Estado</th><th></th></tr>
				</thead>
				<tbody>
					<tr v-for="(s, idx) in resolvedSkills" :key="idx">
						<td><input class="input num xs" type="number" :value="s.level" min="1" max="60" @input="updateSkillField(idx, 'level', $event.target.value)" /></td>
						<td><input class="input xs ico" type="text" :value="s.icon" @input="updateSkillField(idx, 'icon', $event.target.value)" /></td>
						<td><input class="input xs" type="text" :value="s.name" @input="updateSkillField(idx, 'name', $event.target.value)" /></td>
						<td><input class="input num xs" type="number" :value="s.cost" min="0" @input="updateSkillField(idx, 'cost', $event.target.value)" /></td>
						<td><select class="input xs" :value="s.type" @change="updateSkillField(idx, 'type', $event.target.value)"><option v-for="t in skillTypes" :key="t" :value="t">{{ t }}</option></select></td>
						<td><input class="input num xs" type="number" step="0.1" :value="s.power" @input="updateSkillField(idx, 'power', $event.target.value)" /></td>
						<td><select class="input xs" :value="s.element" @change="updateSkillField(idx, 'element', $event.target.value)"><option v-for="e in ELEMENTS" :key="e" :value="e">{{ e }}</option></select></td>
						<td class="prof-skill-table__st">{{ s.status ? s.status.type : '—' }}</td>
						<td class="prof-skill-table__act">
							<button class="btn xs ghost" @click="goTo('skills', s.id)" title="Editar PA/tag/resonancia y demás campos avanzados en Habilidades">✎</button>
							<button class="btn xs ghost" :disabled="idx===0" @click="moveSkill(idx,-1)">▲</button>
							<button class="btn xs ghost" :disabled="idx===resolvedSkills.length-1" @click="moveSkill(idx,1)">▼</button>
							<button class="btn xs err" @click="removeSkill(idx)">🗑️</button>
						</td>
					</tr>
					<tr v-if="!resolvedSkills.length"><td colspan="9" class="muted" style="text-align:center; padding:12px">Sin habilidades. Usa "➕ Añadir Habilidad".</td></tr>
				</tbody>
			</table>

			<div v-else class="skills-list" style="margin-top: 15px;">
				<div class="card panel" style="margin-bottom: 20px; padding: 15px; border: 1px solid rgba(255,255,255,0.1);"
					v-for="(s, idx) in resolvedSkills" :key="idx">
					<div class="d-flex" style="justify-content: space-between; align-items: center; margin-bottom: 10px;">
						<span style="font-weight: 700; color: #a855f7;">Habilidad #{{ idx + 1 }} - {{ s.name || 'Nueva' }}</span>
						<div style="display: flex; gap: 6px;">
							<button class="btn sm ghost" @click="goTo('skills', s.id)" title="Editar PA/tag/resonancia y demás campos avanzados en Habilidades">✎ Avanzado</button>
							<button class="btn sm ghost" :disabled="idx === 0" @click="moveSkill(idx, -1)">▲ Subir</button>
							<button class="btn sm ghost" :disabled="idx === resolvedSkills.length - 1" @click="moveSkill(idx, 1)">▼ Bajar</button>
							<button class="btn sm err" @click="removeSkill(idx)">🗑️ Quitar</button>
						</div>
					</div>

					<div class="form-grid">
						<label>Nivel
							<input class="input num" type="number" :value="s.level" @input="updateSkillField(idx, 'level', $event.target.value)" min="1" max="60" />
						</label>
						<label>Icono
							<input class="input f-xs" type="text" :value="s.icon" @input="updateSkillField(idx, 'icon', $event.target.value)" style="width: 60px;" />
						</label>
						<label>Nombre
							<input class="input" type="text" :value="s.name" @input="updateSkillField(idx, 'name', $event.target.value)" />
						</label>
						<label>Coste MP
							<input class="input num" type="number" :value="s.cost" @input="updateSkillField(idx, 'cost', $event.target.value)" min="0" />
						</label>
					</div>

					<div class="form-grid">
						<label>Tipo
							<select class="input" :value="s.type" @change="updateSkillField(idx, 'type', $event.target.value)">
								<option v-for="t in skillTypes" :key="t" :value="t">{{ t }}</option>
							</select>
						</label>
						<label>Potencia (Multiplicador)
							<input class="input num" type="number" step="0.1" :value="s.power" @input="updateSkillField(idx, 'power', $event.target.value)" />
						</label>
						<label>Elemento
							<select class="input" :value="s.element" @change="updateSkillField(idx, 'element', $event.target.value)">
								<option v-for="e in ELEMENTS" :key="e" :value="e">{{ e }}</option>
							</select>
						</label>
					</div>

					<div>
						<label>Descripción [{{ store.currentLang.toUpperCase() }}]
							<input class="input" type="text" :value="getI18n(s.desc)" :placeholder="getI18nFallback(s.desc) || 'Descripción de la habilidad...'" @input="updateSkillField(idx, 'desc.' + store.currentLang, $event.target.value)" />
						</label>
					</div>

					<!-- Configuración de Estados Alterados -->
					<div style="margin-top: 10px; border-top: 1px dashed rgba(255,255,255,0.08); padding-top: 10px;">
						<label style="display: flex; align-items: center; gap: 8px; cursor: pointer; font-size: 14px; font-weight: bold;">
							<input type="checkbox" :checked="!!s.status" @change="toggleSkillStatus(idx)" />
							Aplica Estado Alterado / Modificador de Combate
						</label>

						<div v-if="s.status" class="form-grid" style="margin-top: 8px;">
							<label>Estado
								<select class="input" :value="s.status.type" @change="updateSkillStatusField(idx, 'type', $event.target.value)">
									<!-- Nombres de estados soportados en combate -->
									<option value="stun">💫 stun (Aturdir)</option>
									<option value="slow">🐌 slow (Ralentizar)</option>
									<option value="poison">🟢 poison (Veneno)</option>
									<option value="burn">🔥 burn (Quemadura)</option>
									<!-- Nuevos estados especiales -->
									<option value="pdef_down">🛡️👇 pdef_down (Bajar DEF física 10%)</option>
									<option value="barrera">🧱 barrera (Reducir daño físico recibido 20%)</option>
									<option value="escudo">🛡️ escudo (Reducir daño mágico recibido 20%)</option>
									<option value="concentracion">🎯 concentracion (+25% daño, +20% precisión)</option>
									<option value="muro_ii">🧱🌟 muro_ii (Reducir daño físico & mágico 40%)</option>
									<option value="esconderse">🌫️ esconderse (+30% esquiva)</option>
									<option value="prisa">🏃 prisa (+25% velocidad/ATB)</option>
									<option value="esquiva_temporal">⏳ esquiva_temporal (Falla siguiente ataque enemigo)</option>
									<option value="burbuja_temporal">🫧 burbuja_temporal (-20% daño mutuo, +5% MP/SP turno)</option>
									<option value="distorsion">🌀 distorsion (Invertir velocidad)</option>
									<option value="confusion">🌀 confusion (30% fallo enemigo)</option>
									<option value="illusion">🔮 illusion (+30% esquiva)</option>
									<option value="fuerza_mental">🧠 fuerza_mental (+30% daño físico/mágico)</option>
									<option value="silence">🤫 silence (Impide usar magia/habilidades)</option>
									<option value="mente_serena">🧘 mente_serena (Siguiente hechizo daño x2)</option>
									<option value="fuerza_interior">🔥 fuerza_interior (+50% de daño)</option>
								</select>
							</label>
							<label>Probabilidad (0.0 a 1.0)
								<input class="input num" type="number" step="0.05" min="0" max="1" :value="s.status.chance" @input="updateSkillStatusField(idx, 'chance', $event.target.value)" />
							</label>
							<label>Turnos
								<input class="input num" type="number" min="1" :value="s.status.turns" @input="updateSkillStatusField(idx, 'turns', $event.target.value)" />
							</label>
						</div>
					</div>
				</div>
			</div>
		</section>

		<section class="editor-pane empty" v-else>
			<p class="muted">Selecciona o crea una profesión.</p>
		</section>
	</div>
	`,
};
