// components/ConfigManager.js
// ─────────────────────────────────────────────────────────────────────────────
// Gestor de config.json: PARÁMETROS DE BALANCE del juego (los lee GameConfig.gd
// con fallback a sus valores por defecto). NO es una colección {id->entidad},
// sino un documento plano de clave→valor, agrupado por secciones para editarlo
// cómodamente. Cada campo tiene un tipo (int/float/bool/str) y un default; si el
// valor no existe en config.json, se muestra el default (y GameConfig usa el suyo).
// Se edita en su propio panel y marca cambios con markDirty('config').
// ─────────────────────────────────────────────────────────────────────────────
import { ref, computed } from 'https://unpkg.com/vue@3/dist/vue.esm-browser.prod.js';
import { store, markDirty, save } from '../store.js';
import { useDocumentHistory } from '../lib/useDocumentHistory.js';
import EditorToolbar from './EditorToolbar.js';
import TEMPLATE from './templates/ConfigManagerTemplate.js';

// ── BALANCE AVANZADO ─────────────────────────────────────────
// Espejo en JS de las tablas ESTRUCTURALES de GameConfig.gd (STATUS_EFFECTS /
// RARITIES) — solo para mostrar el valor CABLEADO de cada campo. El override
// real vive en config.json bajo "status_effects"/"loot_rarities" (mismo doc
// que los escalares de arriba) y lo mezcla GameConfig.status_def()/rarities()
// en tiempo de ejecución. Mantener sincronizado a mano con GameConfig.gd si se
// retocan los valores base ahí — este mirror NUNCA se escribe, solo se lee
// como "valor por defecto" cuando el override no toca ese campo.
// No se pueden crear estados/rarezas NUEVOS aquí (fuera de alcance explícito,
// ): el motor de combate solo interpreta las claves que ya conoce.
const STATUS_FIELD_TYPES = {
	good: 'bool', dot: 'bool', no_charge: 'bool', skip: 'bool', silence: 'bool', force_crit: 'bool',
	atb_mult: 'float', miss_chance: 'float', mit_phys: 'float', mit_mag: 'float', dmg_out: 'float',
	crit_add: 'float', dodge_add: 'float', pdef_mult: 'float', mdef_mult: 'float', regen: 'float',
};
const STATUS_BASE = {
	poison: { icon: '🟢', color: '84cc16', dot: true },
	bleed: { icon: '🩸', color: 'b91c1c', dot: true },
	burn: { icon: '🔥', color: 'f97316', dot: true },
	stun: { icon: '💫', color: 'facc15', skip: true },
	slow: { icon: '🐌', color: '38bdf8', atb_mult: 0.7 },
	chrono_lock: { icon: '🔒', color: '818cf8', no_charge: true },
	confusion: { icon: '🌀', color: 'a855f7', miss_chance: 0.4 },
	silence: { icon: '🤫', color: '6b7280', silence: true },
	pdef_down: { icon: '🪓', color: 'e11d48', pdef_mult: 0.75 },
	mdef_down: { icon: '💢', color: 'e11d48', mdef_mult: 0.75, dmg_out: 0.9 },
	atk_down: { icon: '🗣️', color: '94a3b8', dmg_out: 0.9 },
	distorsion: { icon: '🌀', color: '6366f1' },
	barrera: { icon: '🧱', color: '3b82f6', good: true, mit_phys: 0.65 },
	barrera_ii: { icon: '🧱', color: '2563eb', good: true, mit_phys: 0.50 },
	escudo: { icon: '🛡️', color: 'a855f7', good: true, mit_mag: 0.65 },
	muro_ii: { icon: '🧱', color: 'f59e0b', good: true, mit_phys: 0.75, mit_mag: 0.75 },
	burbuja_temporal: { icon: '🫧', color: '0ea5e9', good: true, mit_phys: 0.8, mit_mag: 0.8 },
	counter_stance: { icon: '↩️', color: 'f97316', good: true, mit_phys: 0.7 },
	concentracion: { icon: '🎯', color: 'eab308', good: true, dmg_out: 1.25 },
	fuerza_mental: { icon: '🧠', color: 'f43f5e', good: true, dmg_out: 1.3 },
	fuerza_interior: { icon: '🔥', color: 'ef4444', good: true, dmg_out: 1.5 },
	mente_serena: { icon: '🧘', color: 'f59e0b', good: true },
	prisa: { icon: '🏃', color: '06b6d4', good: true, atb_mult: 1.25 },
	prisa_ii: { icon: '💨', color: '0891b2', good: true, atb_mult: 1.45 },
	berserk: { icon: '😤', color: 'ef4444', good: true, dmg_out: 1.5, pdef_mult: 0.75 },
	focus: { icon: '🧠', color: 'c084fc', good: true, dmg_out: 1.3 },
	blessing: { icon: '🌟', color: 'fde047', good: true, dmg_out: 1.15, mit_phys: 0.9, mit_mag: 0.9 },
	crit_up: { icon: '🎯', color: 'f59e0b', good: true, crit_add: 0.30 },
	guaranteed_crit: { icon: '💥', color: 'f97316', good: true, force_crit: true },
	esconderse: { icon: '🌫️', color: '10b981', good: true, dodge_add: 40.0 },
	illusion: { icon: '🔮', color: 'ec4899', good: true, dodge_add: 30.0 },
	esquiva_temporal: { icon: '⏳', color: '38bdf8', good: true, dodge_add: 999.0 },
	regen: { icon: '🌿', color: '22c55e', good: true, regen: 0.08 },
};
const RARITY_BASE = {
	common: { color: 'b8c0cc', mult: 1.0, weight: 58.0 },
	uncommon: { color: '4ade80', mult: 1.3, weight: 26.0 },
	rare: { color: '3b82f6', mult: 1.7, weight: 12.0 },
	epic: { color: 'a855f7', mult: 2.2, weight: 3.5 },
	legendary: { color: 'f59e0b', mult: 3.2, weight: 0.5 },
};
// Espejo de GameConfig.CAMP_STRUCTURES (evolución en cola de la Base, en orden:
// Nv2→Nv6). El override real vive en config.json bajo "camp_structures" y lo
// mezcla GameConfig.camp_structures() en tiempo de ejecución (mismo patrón que
// _rarities_merged). Solo icono y coste (madera/piedra) son editables: son los
// únicos campos que hoy usa el motor fuera del nombre/descripción/`action`
// cableados — crear una construcción nueva exige una `action` nueva en
// CampTentSystem, fuera de alcance de este editor.
const CAMP_STRUCT_BASE = {
	campfire: { icon: '🔥', label: 'Hoguera', cost_wood: 20, cost_stone: 0 },
	dummy: { icon: '🎯', label: 'Muñeco de Entrenamiento', cost_wood: 15, cost_stone: 15 },
	chest: { icon: '📦', label: 'Cofre', cost_wood: 15, cost_stone: 15 },
	board: { icon: '📋', label: 'Tablón de Encargos', cost_wood: 20, cost_stone: 20 },
	forge: { icon: '🔨', label: 'Herrería', cost_wood: 25, cost_stone: 20 },
};

// Definición declarativa de las secciones y sus campos (clave, etiqueta, tipo, default).
// Debe reflejar los `static var` de GameConfig.gd que leen de config.json.
const SECTIONS = [
	{ title: '🧑 Héroe · inicio', fields: [
		['START_GOLD', 'Oro inicial', 'int', 0],
		['START_LEVEL', 'Nivel inicial', 'int', 1],
		['START_XP', 'XP inicial', 'int', 0],
		['START_XP_NEEDED', 'XP para nivel 2', 'int', 10],
		['START_STAT_POINTS', 'Puntos de stat iniciales', 'int', 5],
		['START_PROFESSION', 'Profesión inicial', 'str', 'Don Nadie'],
	]},
	{ title: '🐞 Modo debug', fields: [
		['DEBUG_GOLD', 'Oro (debug)', 'int', 1000],
		['DEBUG_LEVEL', 'Nivel (debug)', 'int', 30],
		['DEBUG_STAT_POINTS', 'Puntos de stat (debug)', 'int', 50],
		['DEBUG_MOVE_MULTIPLIER', 'Multiplicador de velocidad (debug)', 'float', 3.0],
	]},
	{ title: '📈 Progresión (límites 30/25 y curvas polinómicas)', fields: [
		['MAX_CHAR_LEVEL', 'Nivel máx. de héroe', 'int', 30],
		['MAX_JOB_LEVEL', 'Nivel máx. de profesión', 'int', 25],
		['STAT_POINTS_PER_LEVEL', 'Puntos de stat por nivel', 'int', 1],
		['XP_CHAR_BASE', 'XP héroe: base', 'float', 100.0],
		['XP_CHAR_EXPONENT', 'XP héroe: exponente', 'float', 1.4],
		['XP_JOB_BASE', 'XP profesión: base', 'float', 80.0],
		['XP_JOB_EXPONENT', 'XP profesión: exponente', 'float', 1.35],
		['STARTING_HP_BUFF_MULT', 'Buff inicial "El Yelmo": mult. HP', 'float', 1.0],
		['STARTING_HP_BUFF_DURATION_SEC', 'Buff inicial: duración (s)', 'int', 600],
	]},
	{ title: '❤️ Fórmulas HP/MP', fields: [
		['HP_BASE', 'HP base', 'int', 9],
		['HP_PER_VIT', 'HP por VIT', 'int', 2],
		['HP_PER_LEVEL', 'HP por nivel', 'int', 1],
		['MP_BASE', 'MP base', 'int', 5],
		['MP_PER_INT', 'MP por INT', 'int', 1],
		['MP_PER_LEVEL', 'MP por nivel', 'int', 1],
	]},
	{ title: '⚔️ Daño y defensas', fields: [
		['PHYS_DMG_FROM_STR', 'Daño físico por STR', 'float', 0.5],
		['PHYS_DMG_FROM_DEX', 'Daño físico por DEX', 'float', 0.1],
		['PHYS_DMG_FROM_LEVEL', 'Daño físico por nivel', 'float', 0.5],
		['MAG_DMG_FROM_INT', 'Daño mágico por INT', 'float', 0.6],
		['MAG_DMG_FROM_LEVEL', 'Daño mágico por nivel', 'float', 0.5],
		['RANGE_DMG_FROM_DEX', 'Daño distancia por DEX', 'float', 0.5],
		['RANGE_DMG_FROM_STR', 'Daño distancia por STR', 'float', 0.1],
		['SPEED_FROM_AGI', 'Velocidad por AGI', 'float', 1.5],
		['PDEF_FROM_VIT', 'Def. física por VIT', 'float', 0.2],
		['PDEF_FROM_STR', 'Def. física por STR', 'float', 0.1],
		['PDEF_FROM_LEVEL', 'Def. física por nivel', 'float', 0.3],
		['MDEF_FROM_INT', 'Def. mágica por INT', 'float', 0.2],
		['MDEF_FROM_VIT', 'Def. mágica por VIT', 'float', 0.1],
		['MDEF_FROM_LEVEL', 'Def. mágica por nivel', 'float', 0.3],
	]},
	{ title: '🎯 Esquiva / Crítico / Puntería', fields: [
		['DODGE_BASE', 'Esquiva base (%)', 'float', 2.0],
		['DODGE_FROM_AGI', 'Esquiva por AGI', 'float', 0.6],
		['DODGE_FROM_LUK', 'Esquiva por LUK', 'float', 0.3],
		['DODGE_MAX', 'Esquiva máx (%)', 'float', 60.0],
		['CRIT_BASE', 'Crítico base (%)', 'float', 3.0],
		['CRIT_FROM_LUK', 'Crítico por LUK', 'float', 0.5],
		['CRIT_FROM_DEX', 'Crítico por DEX', 'float', 0.3],
		['CRIT_MAX', 'Crítico máx (%)', 'float', 60.0],
		['CRIT_MULTIPLIER', 'Multiplicador de crítico', 'float', 1.6],
		['ACCURACY_BASE', 'Puntería base (%)', 'float', 80.0],
		['ACC_FROM_DEX', 'Puntería por DEX', 'float', 1.2],
		['ACC_FROM_LUK', 'Puntería por LUK', 'float', 0.4],
		['ACCURACY_MAX', 'Puntería máx (%)', 'float', 100.0],
		['CARRY_BASE', 'Carga base', 'int', 50],
		['CARRY_PER_STR', 'Carga por STR', 'int', 5],
	]},
	{ title: '🪵 Recolección / Oficios', fields: [
		['SKILL_XP_CURVE_MULTIPLIER', 'Curva XP de oficio', 'float', 1.5],
		['GATHER_XP_PER_TAP', 'XP por toque', 'int', 10],
		['GATHER_AMOUNT_PER_TAP', 'Unidades por toque', 'int', 1],
		['GATHER_TAP_COOLDOWN_MS', 'Espera entre toques (ms)', 'int', 1000],
		['GATHER_NODE_CAPACITY', 'Capacidad de nodo', 'int', 40],
		['GATHER_REGEN_INTERVAL', 'Regen nodo (s/unidad)', 'float', 30.0],
		['GATHER_IDLE_INTERVAL', 'Intervalo idle (s)', 'float', 5.0],
		['GATHER_IDLE_AMOUNT', 'Unidades idle por tick', 'int', 1],
		['GATHER_SPEED_BONUS_PER_LEVEL', 'Bonus veloc. por nivel de oficio (niv. 2-4 y 6-9)', 'float', 0.10],
		['GATHER_LEVEL_AMOUNT_THRESHOLD', 'Nivel de oficio que dobla la cantidad', 'int', 5],
		['GATHER_LEVEL_AMOUNT_MULTIPLIER', 'Multiplicador de cantidad en ese nivel', 'int', 2],
	]},
	{ title: '⚡ Energía', fields: [
		['MAX_ENERGY', 'Energía máx', 'int', 100],
		['ENERGY_REGEN_PER_SEC', 'Regen energía (por s)', 'float', 18.0],
	]},
	{ title: '🏕️ Base', fields: [
		['CAMPFIRE_REGEN_HP', 'Hoguera: HP por tick', 'int', 5],
		['CAMPFIRE_REGEN_MP', 'Hoguera: MP por tick', 'int', 5],
		['TRAINING_XP_PER_TAP', 'Muñeco: XP por toque', 'int', 1],
		['TRAINING_IDLE_XP', 'Muñeco: XP idle', 'int', 1],
		['TRAINING_IDLE_INTERVAL', 'Muñeco: intervalo idle (s)', 'float', 5.0],
		['BUILDING_MAX_LEVEL', 'Nivel máx. construcción', 'int', 3],
		['BUILDING_UPGRADE_GROWTH', 'Crecimiento coste mejora', 'float', 1.8],
		['BUILDING_UPGRADE_GOLD_BASE', 'Oro base mejora', 'int', 50],
	]},
	{ title: '🌍 Mundo / Peligros', fields: [
		['WORLD_WIDTH', 'Ancho del mundo', 'int', 1000],
		['WORLD_HEIGHT', 'Alto del mundo', 'int', 1000],
		['HAZARD_FILL_SECONDS', 'Peligro: llenar (s)', 'float', 22.0],
		['HAZARD_DECAY_SECONDS', 'Peligro: vaciar (s)', 'float', 7.0],
	]},
	{ title: '🌗 Ciclo día / noche', fields: [
		['DAY_DURATION_SEC', 'Duración del día (s reales)', 'float', 180.0],
		['NIGHT_DURATION_SEC', 'Duración de la noche (s reales)', 'float', 60.0],
		['DAY_START_HOUR', 'Hora de amanecer (0-24)', 'float', 6.0],
		['NIGHT_START_HOUR', 'Hora de anochecer (0-24)', 'float', 20.0],
		['DAY_TWILIGHT_HOURS', 'Horas de transición (amanecer/atardecer)', 'float', 1.0],
	]},
	{ title: '🗡️ Combate', fields: [
		['COMBAT_TURN_INTERVAL', 'Intervalo de turno (s)', 'float', 3.5],
		['COMBAT_MAX_QUEUE', 'Slots de cola', 'int', 4],
		['COMBAT_DEFAULT_XP_REWARD', 'XP por defecto', 'int', 20],
		['COMBAT_DEFAULT_GOLD_REWARD', 'Oro por defecto', 'int', 10],
		['PA_LIMIT_NORMAL', 'PA por turno', 'int', 3],
		['PA_LIMIT_RESONANT', 'PA por turno resonante', 'int', 4],
		['RESONANCE_MAX', 'Resonancia máx', 'float', 100.0],
		['RESONANCE_GAIN_SYNERGY', 'Resonancia por sinergia', 'float', 35.0],
		['COMBAT_DECISION_TIME_SCALE', 'Escala tiempo al decidir', 'float', 0.2],
		['PHYS_DMG_MULT', 'Mult. daño físico', 'float', 1.0],
		['MAG_DMG_MULT', 'Mult. daño mágico', 'float', 1.0],
		['RANGE_DMG_MULT', 'Mult. daño distancia', 'float', 1.0],
		['COMBO_CHAIN_LEN', 'Golpes para combo', 'int', 3],
		['COMBO_DMG_MULT', 'Mult. daño combo', 'float', 1.5],
		['ELEMENT_WEAK_MULT', 'Mult. debilidad elemental', 'float', 1.5],
		['ELEMENT_RESIST_MULT', 'Mult. resistencia elemental', 'float', 0.5],
	]},
	{ title: '🏰 Mazmorra / Forja', fields: [
		['DUNGEON_TICK_INTERVAL', 'Tick de avance (s)', 'float', 1.2],
		['DUNGEON_TICK_AMOUNT', '% exploración por tick', 'int', 10],
		['DUNGEON_AMBUSH_CHANCE', 'Prob. emboscada', 'float', 0.15],
		['REFORGE_COST_GOLD', 'Coste re-forjar (oro)', 'int', 80],
		['STAT_RESET_COST_GOLD', 'Coste reset stats (oro)', 'int', 50],
	]},
	{ title: '📋 Encargos / Offline', fields: [
		['ENCARGO_MAX_ACTIVE', 'Encargos activos máx', 'int', 3],
		['OFFLINE_MAX_SECONDS', 'Offline: tope (s)', 'int', 28800],
		['OFFLINE_MIN_SECONDS', 'Offline: mínimo (s)', 'int', 60],
		['OFFLINE_GATHER_PER_INTERVAL', 'Offline: unidades por intervalo', 'int', 1],
		['OFFLINE_GATHER_CAP_PER_RES', 'Offline: tope por recurso', 'int', 80],
	]},
	{ title: '🔤 Accesibilidad', fields: [
		['UI_FONT_SCALE_MIN', 'Escala fuente mín', 'float', 0.8],
		['UI_FONT_SCALE_MAX', 'Escala fuente máx', 'float', 1.5],
		['UI_FONT_SCALE_DEFAULT', 'Escala fuente por defecto', 'float', 1.0],
		['COLORBLIND_DEFAULT', 'Modo daltónico por defecto', 'bool', false],
	]},
];

// Sub-diccionarios editables aparte (números por clave): stats/facetas iniciales.
const DICT_FIELDS = [
	{ key: 'START_STATS', title: '📊 Características iniciales', keys: ['str', 'agi', 'vit', 'int', 'dex', 'luk'], def: { str: 5, agi: 5, vit: 5, int: 5, dex: 5, luk: 5 } },
	{ key: 'START_FACETAS', title: '🎭 Facetas iniciales', keys: ['valor', 'bondad', 'aspecto', 'inteligencia', 'cordura'], def: { valor: 0, bondad: 0, aspecto: 0, inteligencia: 0, cordura: 0 } },
];

export default {
	name: 'ConfigManager',
	components: { EditorToolbar },
	setup() {
		const cfg = computed(() => (store.config || (store.config = {})));
		const dirty = computed(() => !!store.dirty.config);
		function touch() { markDirty('config'); }
		function doSave() { save(false); }

		// Task 5 (1.3): historial de deshacer/rehacer (documento único, no colección).
		const hist = useDocumentHistory({ tabId: 'config', getDoc: () => cfg.value, setDoc: (v) => { store.config = v; touch(); } });
		function edit(fn) { hist.edit(fn); touch(); }

		// Valor efectivo de una clave (el guardado, o su default declarado).
		function val(key, def) { return cfg.value[key] !== undefined ? cfg.value[key] : def; }

		function setField(key, type, raw) {
			let v;
			if (type === 'int') v = Math.trunc(Number(raw) || 0);
			else if (type === 'float') v = Number(raw) || 0;
			else if (type === 'bool') v = !!raw;
			else v = String(raw);
			edit(() => { cfg.value[key] = v; });
		}
		function dictVal(dictKey, k, def) {
			const d = cfg.value[dictKey];
			if (d && d[k] !== undefined) return d[k];
			return def;
		}
		function setDict(dictKey, k, raw, def) {
			edit(() => {
				if (!cfg.value[dictKey] || typeof cfg.value[dictKey] !== 'object') cfg.value[dictKey] = Object.assign({}, def);
				cfg.value[dictKey][k] = Math.trunc(Number(raw) || 0);
			});
		}

		// ── BALANCE AVANZADO: overrides por clave sobre
		// STATUS_EFFECTS/RARITIES, guardados en config.json["status_effects"/"loot_rarities"].
		const subTab = ref('scalars'); // 'scalars' | 'balance'
		const STATUS_KEYS = Object.keys(STATUS_BASE);
		const RARITY_KEYS = Object.keys(RARITY_BASE);
		const CAMP_STRUCT_KEYS = Object.keys(CAMP_STRUCT_BASE);

		function overrideOf(group, key) {
			const g = cfg.value[group];
			return (g && g[key] && typeof g[key] === 'object') ? g[key] : {};
		}
		function fieldVal(group, key, field, def) {
			const ov = overrideOf(group, key);
			return ov[field] !== undefined ? ov[field] : def;
		}
		function isOverridden(group, key, field) {
			return overrideOf(group, key)[field] !== undefined;
		}
		function setOverrideField(group, key, field, type, raw) {
			let v;
			if (type === 'bool') v = !!raw;
			else if (type === 'color') v = String(raw || '').replace(/^#/, '');
			else if (type === 'str') v = String(raw);
			else if (type === 'int') v = Math.trunc(Number(raw) || 0);
			else v = Number(raw);
			edit(() => {
				if (!cfg.value[group] || typeof cfg.value[group] !== 'object') cfg.value[group] = {};
				if (!cfg.value[group][key] || typeof cfg.value[group][key] !== 'object') cfg.value[group][key] = {};
				cfg.value[group][key][field] = v;
			});
		}
		function resetOverrideField(group, key, field) {
			const ov = cfg.value[group] && cfg.value[group][key];
			if (!ov || ov[field] === undefined) return;
			edit(() => {
				delete ov[field];
				if (Object.keys(ov).length === 0) delete cfg.value[group][key];
			});
		}
		// Campos numéricos/booleanos presentes en la ficha BASE de un estado
		// (los únicos con sentido de override: el motor no interpreta ninguno más).
		function statusModFields(key) {
			return Object.keys(STATUS_BASE[key]).filter(f => f !== 'icon' && f !== 'color');
		}

		return {
			store, SECTIONS, DICT_FIELDS, dirty, doSave, val, setField, dictVal, setDict,
			subTab, STATUS_BASE, STATUS_KEYS, STATUS_FIELD_TYPES, RARITY_BASE, RARITY_KEYS,
			CAMP_STRUCT_BASE, CAMP_STRUCT_KEYS,
			fieldVal, isOverridden, setOverrideField, resetOverrideField, statusModFields,
			canUndo: hist.canUndo, canRedo: hist.canRedo, undo: hist.undo, redo: hist.redo,
		};
	},
	template: TEMPLATE,
};
