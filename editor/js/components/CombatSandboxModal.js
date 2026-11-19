// components/CombatSandboxModal.js
// ─────────────────────────────────────────────────────────────────────────────
// SANDBOX / SIMULADOR DE COMBATE TÁCTICO RPG (FASE 2)
//
// IMPORTANTE: el juego real NO tiene party de varios personajes — hay un único
// protagonista con una PROFESIÓN activa (data/professions.json) y hasta 4
// HABILIDADES DE COMBATE equipadas (GlobalState.active_combat_skills, ver
// docstring en scripts/autoload/GlobalState.gd). Este simulador replica
// exactamente eso: un héroe, su profesión, su nivel y sus 4 huecos de
// habilidad, contra el enemigo seleccionado a su nivel.
//
// Reproduce en JS las fórmulas reales del motor (scripts/config/GameConfig.gd,
// scripts/autoload/GlobalState.gd y CombatDamageResolver.gd): daño ofensivo
// (ATK/INT/DEX * potencia/100), defensa restada en su totalidad (no a medias),
// crítico/esquiva/puntería derivados de stats, multiplicador elemental
// débil/resiste, y una réplica ligera de GameConfig.STATUS_EFFECTS para que
// buffs/debuffs/DoT/aturdimiento de las propias habilidades tengan efecto real
// en la simulación (mecánicas de turno/ATB como prisa/lentitud/silencio quedan
// fuera de alcance: este simulador no modela la barra de ATB).
//
// SIMPLIFICACIÓN CONOCIDA: la asignación de puntos de característica
// (STR/AGI/VIT/INT/DEX/LUK) es una decisión libre del jugador; aquí se asume
// un reparto MEDIO a partes iguales entre las 6 (igual criterio que un build
// equilibrado), para poder simular solo con nivel + profesión.
//
// Calcula: Tasa de victoria (%), TTK (media y P90), Daño Por Turno
// infligido/recibido, y un log turno a turno del último combate de muestra.
// ─────────────────────────────────────────────────────────────────────────────
import { ref, reactive, computed, watch, onUnmounted } from 'https://unpkg.com/vue@3/dist/vue.esm-browser.prod.js';
import { store } from '../store.js';

// Réplica ligera de GameConfig.STATUS_EFFECTS (solo los campos que afectan al
// cálculo de daño/turnos de esta simulación). `good:true` = estado beneficioso
// que aplica el propio héroe sobre sí mismo (para no re-lanzarlo en bucle).
const STATUS_EFFECTS = {
	poison: { dot: true }, bleed: { dot: true }, burn: { dot: true },
	stun: { skip: true },
	confusion: { miss_chance: 0.4 },
	pdef_down: { pdef_mult: 0.75 }, mdef_down: { mdef_mult: 0.75, dmg_out: 0.9 }, atk_down: { dmg_out: 0.9 },
	barrera: { good: true, mit_phys: 0.65 }, barrera_ii: { good: true, mit_phys: 0.50 },
	escudo: { good: true, mit_mag: 0.65 }, muro_ii: { good: true, mit_phys: 0.75, mit_mag: 0.75 },
	burbuja_temporal: { good: true, mit_phys: 0.8, mit_mag: 0.8 }, counter_stance: { good: true, mit_phys: 0.7 },
	concentracion: { good: true, dmg_out: 1.25 }, fuerza_mental: { good: true, dmg_out: 1.3 }, fuerza_interior: { good: true, dmg_out: 1.5 },
	berserk: { good: true, dmg_out: 1.5, pdef_mult: 0.75 }, focus: { good: true, dmg_out: 1.3 },
	blessing: { good: true, dmg_out: 1.15, mit_phys: 0.9, mit_mag: 0.9 },
	crit_up: { good: true, crit_add: 30 }, esconderse: { good: true, dodge_add: 40 }, illusion: { good: true, dodge_add: 30 },
	regen: { good: true, regenFrac: 0.08 },
};
const ELEMENT_WEAK_MULT = 1.5;
const ELEMENT_RESIST_MULT = 0.5;

export default {
	name: 'CombatSandboxModal',
	props: {
		open: { type: Boolean, default: false },
		enemy: { type: Object, default: () => null },
		enemyId: { type: String, default: '' },
	},
	emits: ['close'],
	setup(props, { emit }) {
		const enemyLevel = ref(1);
		const heroLevel = ref(1);
		const batchSize = ref(300); // Nº de combates Monte Carlo por cálculo (spec: 100-1.000)
		const isRunning = ref(false);
		const simResults = ref(null);
		const sampleCombatLog = ref([]);

		// ── Profesión y 4 huecos de habilidad equipada del héroe único ──────────
		const professionIds = computed(() => Object.keys(store.professions || {}));
		const heroProfession = ref('Guerrero');
		const equippedSkills = ref(['', '', '', '']);

		function skillDef(id) { return (id && store.skills?.[id]) || null; }
		function skillName(id) {
			const s = skillDef(id);
			if (!s) return '';
			return (s.icon ? s.icon + ' ' : '') + (s.name?.es || id);
		}
		// Habilidades de la profesión ya desbloqueadas al nivel actual del héroe.
		const unlockedSkillIds = computed(() => {
			const prof = store.professions?.[heroProfession.value];
			if (!prof || !Array.isArray(prof.skills)) return [];
			return prof.skills.filter(s => s.level <= heroLevel.value).map(s => s.id).filter(id => !!store.skills?.[id]);
		});
		// Opciones disponibles para un hueco concreto: no repetir una habilidad ya
		// puesta en otro hueco.
		function slotOptions(slotIdx) {
			const used = equippedSkills.value.filter((id, i) => i !== slotIdx && id);
			return unlockedSkillIds.value.filter(id => id === equippedSkills.value[slotIdx] || !used.includes(id));
		}
		// Al cambiar de profesión o subir de nivel: descarta habilidades que ya no
		// estén desbloqueadas y rellena huecos vacíos con las 4 más avanzadas
		// disponibles (aproximación razonable a "las mejores que tienes puestas").
		function autoEquipDefaults() {
			const unlocked = unlockedSkillIds.value;
			const kept = equippedSkills.value.map(id => (id && unlocked.includes(id)) ? id : '');
			const used = new Set(kept.filter(Boolean));
			const candidates = [...unlocked].reverse().filter(id => !used.has(id)); // más avanzadas primero
			for (let i = 0; i < 4; i++) {
				if (!kept[i] && candidates.length) kept[i] = candidates.shift();
			}
			equippedSkills.value = kept;
		}
		function setEquipped(slotIdx, id) {
			const arr = equippedSkills.value.slice();
			arr[slotIdx] = id;
			equippedSkills.value = arr;
			runSimulation();
		}
		function setProfession(id) {
			heroProfession.value = id;
			autoEquipDefaults();
			runSimulation();
		}
		watch(heroLevel, () => { autoEquipDefaults(); });

		// Fórmulas de stats de enemigos (arquetipo + nivel) — idénticas a
		// EnemyDatabase._hp_base/_atk_base/_def_base/ARCHETYPE_MULTIPLIERS.
		const ARCHETYPE_MULTIPLIERS = {
			balanced:     { hp: 1.0,  atk: 1.0,  def: 1.0 },
			tank:         { hp: 1.45, atk: 0.80, def: 1.35 },
			glass_cannon: { hp: 0.75, atk: 1.30, def: 0.70 },
			boss:         { hp: 2.50, atk: 1.20, def: 1.20 },
		};

		function getEnemyStats(lvl) {
			const e = props.enemy || {};
			const arch = e.archetype || 'balanced';
			const mult = ARCHETYPE_MULTIPLIERS[arch] || ARCHETYPE_MULTIPLIERS.balanced;
			const hp = Math.round((8.0 + 2.0 * lvl + 0.08 * Math.pow(lvl, 1.85)) * mult.hp);
			const atk = Math.round((2.5 + 1.2 * lvl + 0.02 * Math.pow(lvl, 1.8)) * mult.atk);
			const def = Math.round((Math.max(0.0, 0.4 * (lvl - 1) + 0.01 * Math.pow(lvl, 1.8))) * mult.def);
			const dodge = (e.base_dodge || 4) + (e.dodge_scale || 0.2) * (lvl - 1);
			return {
				hp, maxHp: hp, physDef: def, magDef: def, atk, dodge,
				attackType: e.attack_type || 'physical', element: e.element || 'physical',
				weak_to: e.weak_to || [], resist: e.resist || [],
			};
		}

		function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)); }

		// Réplica de GlobalState (STR/AGI/VIT/INT/DEX/LUK derivados) asumiendo un
		// reparto MEDIO de los puntos de característica entre las 6 (ver cabecera).
		function getHeroStats(lvl) {
			const bonus = (lvl - 1) / 6;
			const s = 5 + bonus; // str≈agi≈vit≈int≈dex≈luk con reparto equilibrado
			const maxHp = Math.round(120 + s * 12 + lvl * 20);
			const maxMp = Math.round(50 + s * 6 + lvl * 8);
			return {
				maxHp, hp: maxHp, maxMp, mp: maxMp,
				physDmg: Math.round(s * 2.2 + s * 0.5 + lvl * 1.5),
				magDmg: Math.round(s * 2.5 + lvl * 1.5),
				rangeDmg: Math.round(s * 1.8 + s * 0.3),
				healBase: Math.round(s * 3 + lvl * 2),
				physDef: Math.round(s * 1.1 + s * 0.4 + lvl * 0.8),
				magDef: Math.round(s * 0.7 + s * 0.5 + lvl * 0.8),
				crit: clamp(3 + s * 0.5 + s * 0.3, 0, 60),
				accuracy: clamp(80 + s * 1.2 + s * 0.4, 0, 100),
				dodge: clamp(2 + s * 0.6 + s * 0.3, 0, 60),
			};
		}

		// Multiplicador de daño elemental (igual fórmula que GameConfig.gd): x1.5 si
		// el elemento del atacante está en weak_to del enemigo, x0.5 si está en resist.
		function elementalMult(attackerElement, enemyStats) {
			if (enemyStats.weak_to.includes(attackerElement)) return ELEMENT_WEAK_MULT;
			if (enemyStats.resist.includes(attackerElement)) return ELEMENT_RESIST_MULT;
			return 1;
		}

		// ── Estados alterados (subconjunto de GameConfig.STATUS_EFFECTS) ────────
		function statusDot(statuses) {
			let dot = 0, regen = 0, stun = false;
			for (const type in statuses) {
				const def = STATUS_EFFECTS[type] || {};
				if (def.dot) dot += statuses[type].power || 0;
				if (def.regenFrac) regen += def.regenFrac;
				if (def.skip) stun = true;
			}
			return { dot, regen, stun };
		}
		function statusMult(statuses, key, fallback = 1) {
			let m = fallback;
			for (const type in statuses) m *= (STATUS_EFFECTS[type] || {})[key] ?? 1;
			return m;
		}
		function statusSum(statuses, key) {
			let a = 0;
			for (const type in statuses) a += (STATUS_EFFECTS[type] || {})[key] || 0;
			return a;
		}
		function decrementStatuses(statuses) {
			for (const type in statuses) { statuses[type].turns--; if (statuses[type].turns <= 0) delete statuses[type]; }
		}
		function applyStatus(statuses, type, turns, power) {
			if (!STATUS_EFFECTS[type]) return;
			const cur = statuses[type] || { turns: 0, power: 0 };
			statuses[type] = { turns: Math.max(cur.turns, turns), power: Math.max(cur.power, power) };
		}
		function tryApplySkillStatus(skill, statuses, dmg) {
			const st = skill.status;
			if (!st || Math.random() > (st.chance ?? 1)) return;
			let power = st.power || 0;
			if (power <= 0 && STATUS_EFFECTS[st.type]?.dot) power = Math.max(1, Math.round(dmg * 0.3));
			applyStatus(statuses, st.type, st.turns || 2, power);
		}

		// ── IA del héroe: elige qué de sus 4 habilidades equipadas usar ─────────
		function chooseHeroSkill(hero, equipped, heroStatuses) {
			const heals = equipped.filter(s => s.type === 'heal' && s.cost <= hero.mp);
			const buffs = equipped.filter(s => s.type === 'buff' && s.cost <= hero.mp);
			const attacks = equipped.filter(s => s.type !== 'heal' && s.type !== 'buff');
			if (heals.length && hero.hp / hero.maxHp < 0.35) return heals[Math.floor(Math.random() * heals.length)];
			const alreadyBuffed = Object.keys(heroStatuses).some(t => STATUS_EFFECTS[t]?.good);
			if (buffs.length && !alreadyBuffed && Math.random() < 0.25) return buffs[Math.floor(Math.random() * buffs.length)];
			if (!attacks.length) return equipped[0] || null;
			const affordable = attacks.filter(s => s.cost <= hero.mp);
			const pool = affordable.length ? affordable : [attacks.reduce((a, b) => (a.cost <= b.cost ? a : b))];
			return pool[Math.floor(Math.random() * pool.length)];
		}

		function statForType(hero, type) {
			if (type === 'magic') return hero.magDmg;
			if (type === 'ranged') return hero.rangeDmg;
			return hero.physDmg;
		}

		function doHeroAction(skill, hero, enemyStats, heroStatuses, enemyStatuses, log, isSample) {
			hero.mp = Math.max(0, hero.mp - (skill.cost || 0));
			if (skill.type === 'heal') {
				const healed = Math.round(hero.healBase * (skill.power / 100));
				hero.hp = Math.min(hero.maxHp, hero.hp + healed);
				if (isSample) log.push(`✨ Usas ${skillName(skill.id)} y recuperas ${healed} HP. (${hero.hp}/${hero.maxHp})`);
				return 0;
			}
			if (skill.type === 'buff') {
				if (skill.status) applyStatus(heroStatuses, skill.status.type, skill.status.turns || 3, skill.status.power || 0);
				if (isSample) log.push(`🛡️ Usas ${skillName(skill.id)}.`);
				return 0;
			}
			// Habilidad ofensiva: puntería, crítico, elemento y defensa reales.
			const hitChance = hero.accuracy - enemyStats.dodge;
			if (Math.random() * 100 > hitChance) {
				if (isSample) log.push(`💨 Usas ${skillName(skill.id)}, pero fallas.`);
				return 0;
			}
			const raw = statForType(hero, skill.type) * (skill.power / 100);
			let dmg = raw * statusMult(heroStatuses, 'dmg_out');
			const critChance = (hero.crit + statusSum(heroStatuses, 'crit_add')) / 100;
			const crit = Math.random() < critChance;
			if (crit) dmg *= 1.6;
			const mult = elementalMult(skill.element || 'physical', enemyStats);
			dmg *= mult;
			let edef = skill.type === 'magic' ? enemyStats.magDef : enemyStats.physDef;
			edef *= statusMult(enemyStatuses, skill.type === 'magic' ? 'mdef_mult' : 'pdef_mult');
			const finalDmg = Math.max(1, Math.round(dmg) - Math.round(edef));
			enemyStats.hp -= finalDmg;
			if (skill.status) tryApplySkillStatus(skill, enemyStatuses, finalDmg);
			const tag = crit ? ' ¡CRÍTICO!' : mult > 1 ? ' (¡DÉBIL!)' : mult < 1 ? ' (resiste)' : '';
			if (isSample) log.push(`💥 Usas ${skillName(skill.id)} e infliges ${finalDmg} de daño${tag}. (Vida enemigo: ${Math.max(0, enemyStats.hp)}/${enemyStats.maxHp})`);
			return finalDmg;
		}

		function doEnemyAction(enemyStats, hero, heroStatuses, enemyStatuses, log, isSample) {
			const dodgeChance = hero.dodge + statusSum(heroStatuses, 'dodge_add');
			if (Math.random() * 100 < dodgeChance) {
				if (isSample) log.push(`💨 ${props.enemy?.name?.es || 'El enemigo'} ataca, pero esquivas.`);
				return 0;
			}
			const hdef = enemyStats.attackType === 'magic' ? hero.magDef : hero.physDef;
			let base = Math.max(1, enemyStats.atk - hdef);
			base *= statusMult(enemyStatuses, 'dmg_out');
			const mitKey = enemyStats.attackType === 'magic' ? 'mit_mag' : 'mit_phys';
			base *= statusMult(heroStatuses, mitKey);
			const dmg = Math.max(1, Math.round(base));
			hero.hp = Math.max(0, hero.hp - dmg);
			if (isSample) log.push(`👾 ${props.enemy?.name?.es || props.enemyId} ataca causando ${dmg} de daño. (Tu vida: ${hero.hp}/${hero.maxHp})`);
			return dmg;
		}

		function runSimulation() {
			if (!props.enemy) return;
			const equipped = equippedSkills.value.map(skillDef).filter(Boolean);
			if (!equipped.length) { simResults.value = null; sampleCombatLog.value = ['⚠️ Equipa al menos 1 habilidad para simular.']; return; }
			isRunning.value = true;

			const roundsToSim = batchSize.value;
			let wins = 0;
			let totalTurns = 0;
			let totalDmgTaken = 0;
			let totalDmgDealt = 0;
			const winTurns = [];
			let lastLog = [];

			for (let r = 0; r < roundsToSim; r++) {
				const isSampleRound = (r === roundsToSim - 1);
				const currentLog = [];

				const enemyStats = getEnemyStats(enemyLevel.value);
				const hero = getHeroStats(heroLevel.value);
				const heroStatuses = {};
				const enemyStatuses = {};

				let turn = 0;
				const maxTurns = 40;

				if (isSampleRound) currentLog.push(`⚔️ ¡Comienza la batalla contra ${props.enemy.name?.es || props.enemyId} (NV ${enemyLevel.value})!`);

				while (enemyStats.hp > 0 && hero.hp > 0 && turn < maxTurns) {
					turn++;
					if (isSampleRound) currentLog.push(`--- Turno ${turn} ---`);

					// Turno del héroe: DoT/regen propios, aturdimiento, y su acción.
					const hTick = statusDot(heroStatuses);
					if (hTick.dot > 0) hero.hp = Math.max(0, hero.hp - hTick.dot);
					if (hTick.regen > 0) hero.hp = Math.min(hero.maxHp, hero.hp + Math.round(hero.maxHp * hTick.regen));
					if (!hTick.stun && hero.hp > 0 && enemyStats.hp > 0) {
						const skill = chooseHeroSkill(hero, equipped, heroStatuses);
						if (skill) totalDmgDealt += doHeroAction(skill, hero, enemyStats, heroStatuses, enemyStatuses, currentLog, isSampleRound);
					} else if (hTick.stun && isSampleRound) {
						currentLog.push('💫 Estás aturdido y pierdes el turno.');
					}
					decrementStatuses(heroStatuses);
					if (enemyStats.hp <= 0) break;

					// Turno del enemigo: DoT propio, aturdimiento, y su ataque.
					const eTick = statusDot(enemyStatuses);
					if (eTick.dot > 0) enemyStats.hp = Math.max(0, enemyStats.hp - eTick.dot);
					if (!eTick.stun && enemyStats.hp > 0 && hero.hp > 0) {
						totalDmgTaken += doEnemyAction(enemyStats, hero, heroStatuses, enemyStatuses, currentLog, isSampleRound);
					} else if (eTick.stun && isSampleRound) {
						currentLog.push(`💫 ${props.enemy?.name?.es || 'El enemigo'} está aturdido y pierde el turno.`);
					}
					decrementStatuses(enemyStatuses);
				}

				const heroWon = enemyStats.hp <= 0;
				if (heroWon) { wins++; winTurns.push(turn); }
				totalTurns += turn;

				if (isSampleRound) {
					if (heroWon) currentLog.push(`🎉 ¡Victoria en ${turn} turnos!`);
					else currentLog.push(`💀 Has sido derrotado en el turno ${turn}.`);
					lastLog = currentLog;
				}
			}

			const winRate = Math.round((wins / roundsToSim) * 100);
			const avgTurns = +(totalTurns / roundsToSim).toFixed(1);
			const avgDmg = Math.round(totalDmgTaken / roundsToSim);
			// TTK (Time-To-Kill): media y percentil 90 de turnos SOLO en victorias.
			const sortedWinTurns = [...winTurns].sort((a, b) => a - b);
			const p90Turns = sortedWinTurns.length ? sortedWinTurns[Math.min(sortedWinTurns.length - 1, Math.ceil(sortedWinTurns.length * 0.9) - 1)] : null;
			// DPT (Daño Por Turno) infligido/recibido, normalizado por el total de turnos jugados.
			const dptDealt = totalTurns ? +(totalDmgDealt / totalTurns).toFixed(1) : 0;
			const dptTaken = totalTurns ? +(totalDmgTaken / totalTurns).toFixed(1) : 0;

			let difficulty = 'Equilibrado';
			let diffClass = 'diff-balanced';
			let diffDesc = 'El combate tiene la tensión y duración adecuada para un encuentro estándar.';

			if (winRate >= 96 && avgTurns <= 3.5) {
				difficulty = 'Fácil / Farmeo';
				diffClass = 'diff-easy';
				diffDesc = 'Los héroes barren a este enemigo sin apenas sufrir daño. Ideal para enemigos comunes del mapa.';
			} else if (winRate >= 75) {
				difficulty = 'Equilibrado';
				diffClass = 'diff-balanced';
				diffDesc = 'Combate sólido y justo. Requiere unas pocas rondas sin poner en riesgo letal al grupo.';
			} else if (winRate >= 40) {
				difficulty = 'Desafiante (Mini-Jefe)';
				diffClass = 'diff-hard';
				diffDesc = 'Combate duro. Hay probabilidad de bajas si no se gestionan bien las curaciones.';
			} else {
				difficulty = 'Mortal (Jefe Supremo)';
				diffClass = 'diff-deadly';
				diffDesc = 'Muy alta probabilidad de derrota. Adecuado únicamente para jefes finales de mazmorra.';
			}

			simResults.value = {
				winRate,
				avgTurns,
				p90Turns,
				avgDmg,
				dptDealt,
				dptTaken,
				difficulty,
				diffClass,
				diffDesc,
			};
			sampleCombatLog.value = lastLog;
			isRunning.value = false;
		}

		function onKey(e) {
			if (e.key === 'Escape' && props.open) {
				emit('close');
			}
		}

		watch(() => props.open, (isOpen) => {
			if (isOpen) {
				window.addEventListener('keydown', onKey);
				if (!equippedSkills.value.some(Boolean)) autoEquipDefaults();
				runSimulation();
			} else {
				window.removeEventListener('keydown', onKey);
			}
		});

		onUnmounted(() => {
			window.removeEventListener('keydown', onKey);
		});

		return {
			store, enemyLevel, heroLevel, batchSize, isRunning, simResults, sampleCombatLog,
			professionIds, heroProfession, equippedSkills, unlockedSkillIds, slotOptions, skillName, skillDef,
			setProfession, setEquipped, autoEquipDefaults,
			runSimulation,
		};
	},
	template: `
	<div v-if="open" class="modal-backdrop" @click.self="$emit('close')">
		<div class="modal-window combat-sandbox-modal card panel">
			<div class="modal-head">
				<div class="row gap" style="align-items:center">
					<span class="combat-sim-badge">⚔️ SANDBOX DE COMBATE RPG</span>
					<h3>Simulador de Balance: {{ enemy?.name?.es || enemyId }}</h3>
				</div>
				<button class="btn ghost sm modal-close" @click="$emit('close')">✕</button>
			</div>

			<div class="combat-sandbox-body">
				<!-- Controles de Configuración de la Batalla -->
				<div class="sandbox-controls card panel">
					<div class="form-grid" style="grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));">
						<label>Nivel del Enemigo
							<div class="row gap" style="align-items:center">
								<input class="input num" type="number" min="1" max="99" v-model.number="enemyLevel" @change="runSimulation" />
								<input type="range" min="1" max="50" v-model.number="enemyLevel" @input="runSimulation" style="flex:1" />
							</div>
						</label>

						<label>Nivel de los Héroes
							<div class="row gap" style="align-items:center">
								<input class="input num" type="number" min="1" max="99" v-model.number="heroLevel" @change="runSimulation" />
								<input type="range" min="1" max="50" v-model.number="heroLevel" @input="runSimulation" style="flex:1" />
							</div>
						</label>

						<label>Profesión del Héroe
							<select class="input" :value="heroProfession" @change="setProfession($event.target.value)">
								<option v-for="pid in professionIds" :key="pid" :value="pid">{{ store?.professions?.[pid]?.icon || '' }} {{ store?.professions?.[pid]?.name?.es || pid }}</option>
							</select>
						</label>

						<label>Combates por lote (Monte Carlo)
							<select class="input" v-model.number="batchSize" @change="runSimulation">
								<option :value="100">100 combates</option>
								<option :value="300">300 combates</option>
								<option :value="1000">1.000 combates</option>
							</select>
						</label>
					</div>

					<div class="row gap" style="margin-top:12px; align-items:flex-end; flex-wrap:wrap">
						<label v-for="(sid, idx) in equippedSkills" :key="idx" style="flex:1; min-width:160px">Habilidad {{ idx + 1 }}
							<select class="input" :value="sid" @change="setEquipped(idx, $event.target.value)">
								<option value="">— Ninguna —</option>
								<option v-for="skid in slotOptions(idx)" :key="skid" :value="skid">{{ skillName(skid) }}</option>
							</select>
						</label>
						<button class="btn ghost sm" @click="autoEquipDefaults(); runSimulation();" title="Vuelve a poner las 4 habilidades más avanzadas desbloqueadas">🔄 Auto-equipar</button>
					</div>
					<p v-if="!unlockedSkillIds.length" class="muted" style="font-size:11px; margin-top:6px">Esta profesión no tiene ninguna habilidad desbloqueada a nivel {{ heroLevel }}.</p>

					<div class="row" style="margin-top:12px; justify-content:flex-end">
						<button class="btn primary sm" @click="runSimulation" :disabled="isRunning">
							{{ isRunning ? '⏳ Simulando...' : '⚔️ Recalcular ' + batchSize + ' Combates' }}
						</button>
					</div>
				</div>

				<!-- Panel de Resultados del Balance -->
				<div v-if="simResults" class="sandbox-results-grid" style="margin-top:14px">
					<!-- Tarjeta de Victoria % -->
					<div class="sandbox-card card panel">
						<div class="sc-title">Tasa de Victoria de los Héroes</div>
						<div class="sc-val" :class="simResults.diffClass">{{ simResults.winRate }}%</div>
						<div class="sc-bar-wrap">
							<div class="sc-bar-fill" :style="{ width: simResults.winRate + '%' }" :class="simResults.diffClass"></div>
						</div>
					</div>

					<!-- Tarjeta de Turnos Promedio (TTK) -->
					<div class="sandbox-card card panel">
						<div class="sc-title">TTK (Time-To-Kill)</div>
						<div class="sc-val mono">{{ simResults.avgTurns }} <span style="font-size:12px; opacity:.7">turnos</span></div>
						<div class="muted" style="font-size:11px">Media · P90: {{ simResults.p90Turns ?? '—' }} turnos (peor 10% de victorias)</div>
					</div>

					<!-- Tarjeta de Daño Recibido -->
					<div class="sandbox-card card panel">
						<div class="sc-title">Daño Total Recibido</div>
						<div class="sc-val mono" style="color:#f59e0b">{{ simResults.avgDmg }} HP</div>
						<div class="muted" style="font-size:11px">Desgaste promedio de la party</div>
					</div>

					<!-- Tarjeta DPT (Daño Por Turno) -->
					<div class="sandbox-card card panel">
						<div class="sc-title">DPT (Daño por Turno)</div>
						<div class="sc-val mono" style="font-size:16px"><span style="color:#4ade80">{{ simResults.dptDealt }}</span> / <span style="color:#f87171">{{ simResults.dptTaken }}</span></div>
						<div class="muted" style="font-size:11px">Infligido / Recibido por turno</div>
					</div>

					<!-- Veredicto de Dificultad -->
					<div class="sandbox-card card panel full" :class="simResults.diffClass + '-border'">
						<div class="row gap" style="align-items:center; margin-bottom:4px">
							<span class="diff-chip" :class="simResults.diffClass">{{ simResults.difficulty }}</span>
							<strong style="font-size:13.5px">{{ simResults.diffDesc }}</strong>
						</div>
					</div>
				</div>

				<!-- Registro Turno a Turno del Último Combate -->
				<div class="sandbox-log-section card panel" style="margin-top:14px">
					<div class="pane-header" style="margin-bottom:8px">
						<h4 style="margin:0; font-size:12.5px">📜 Transcripción del Último Combate de Muestra</h4>
						<span class="muted" style="font-size:11px">{{ sampleCombatLog.length }} eventos</span>
					</div>
					<div class="sandbox-log scroll">
						<div v-for="(line, idx) in sampleCombatLog" :key="idx" class="sandbox-log-line">
							{{ line }}
						</div>
					</div>
				</div>
			</div>
		</div>
	</div>
	`,
};
