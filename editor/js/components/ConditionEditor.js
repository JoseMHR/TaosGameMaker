// components/ConditionEditor.js
// ─────────────────────────────────────────────────────────────────────────────
// Constructor VISUAL de condiciones (Godot Expression que evalúa
// Design.eval_condition, ver scripts/autoload/Design.gd). Parsea el string a
// una lista de átomos unidos por "and" (CONDITION_TOKENS en store.js) y los
// re-serializa en cada cambio, emitiendo `update:modelValue` — misma idea que
// RewardEditor.js pero para condiciones booleanas.
//
// SOLO reconoce el subconjunto "lista de átomos unidos por and" (sin
// paréntesis/or/not, que cubre la inmensa mayoría de condiciones reales, ver
// CONDITION_SNIPPETS). Si la condición actual usa algo más complejo, o no
// coincide con NINGÚN átomo conocido, se cae a un cuadro de texto crudo SIN
// tocar ni un carácter — nunca se corrompe una condición que no se entiende
// al 100%. El botón "▤ Ver/editar como texto" permite pasar a mano en
// cualquier momento (p. ej. para escribir un "or"/paréntesis a propósito).
// ─────────────────────────────────────────────────────────────────────────────
import { ref, watch } from 'https://unpkg.com/vue@3/dist/vue.esm-browser.prod.js';
import { CONDITION_TOKENS } from '../store.js';

const BY_KEY = Object.fromEntries(CONDITION_TOKENS.map(t => [t.key, t]));
const NUM_RE = '-?\\d+(?:\\.\\d+)?';
const OP_RE = '(==|!=|>=|<=|>|<)';

// Construye, para cada token conocido, un regex que reconoce su forma serializada.
function atomRegexes() {
	return CONDITION_TOKENS.map(t => {
		let re;
		if (t.kind === 'fnStr') re = new RegExp('^' + t.key + '\\(\\s*"([^"]*)"\\s*\\)$');
		else if (t.kind === 'fnCmpNum') re = new RegExp('^' + t.key + '\\(\\s*"([^"]*)"\\s*\\)\\s*' + OP_RE + '\\s*(' + NUM_RE + ')$');
		else if (t.kind === 'varCmpNum') re = new RegExp('^' + t.key + '\\s*' + OP_RE + '\\s*(' + NUM_RE + ')$');
		else if (t.kind === 'varCmpStr') re = new RegExp('^' + t.key + '\\s*' + OP_RE + '\\s*"([^"]*)"$');
		return { def: t, re };
	});
}
const ATOM_REGEXES = atomRegexes();

// Parsea un ÚNICO átomo (ya recortado). Devuelve {key,kind,a,op,b} o null si no coincide.
function parseAtom(text) {
	for (const { def, re } of ATOM_REGEXES) {
		const m = re.exec(text);
		if (!m) continue;
		if (def.kind === 'fnStr') return { key: def.key, kind: def.kind, a: m[1] };
		if (def.kind === 'fnCmpNum') return { key: def.key, kind: def.kind, a: m[1], op: m[2], b: m[3] };
		if (def.kind === 'varCmpNum') return { key: def.key, kind: def.kind, op: m[1], b: m[2] };
		if (def.kind === 'varCmpStr') return { key: def.key, kind: def.kind, op: m[1], a: m[2] };
	}
	return null;
}

// Parsea la condición ENTERA. Devuelve { atoms, raw:null } si TODOS los
// fragmentos (separados por " and ") se reconocen, o { atoms:null, raw:str }
// si hay que caer a texto crudo (vacío también cuenta como "reconocido: 0 átomos").
function parseAll(str) {
	const s = (str || '').trim();
	if (s === '') return { atoms: [], raw: null };
	if (/\bor\b|\bnot\b|[()]/.test(s)) return { atoms: null, raw: str };
	const parts = s.split(/\s+and\s+/);
	const atoms = [];
	for (const p of parts) {
		const a = parseAtom(p.trim());
		if (!a) return { atoms: null, raw: str };
		atoms.push(a);
	}
	return { atoms, raw: null };
}

function serializeAtom(a) {
	const def = BY_KEY[a.key];
	if (!def) return '';
	if (def.kind === 'fnStr') return `${a.key}("${a.a || ''}")`;
	if (def.kind === 'fnCmpNum') return `${a.key}("${a.a || ''}") ${a.op || '>='} ${a.b === '' || a.b == null ? '0' : a.b}`;
	if (def.kind === 'varCmpNum') return `${a.key} ${a.op || '>='} ${a.b === '' || a.b == null ? '0' : a.b}`;
	if (def.kind === 'varCmpStr') return `${a.key} ${a.op || '=='} "${a.a || ''}"`;
	return '';
}

export default {
	name: 'ConditionEditor',
	props: { modelValue: { type: String, default: '' } },
	emits: ['update:modelValue'],
	setup(props, { emit }) {
		const parsed = parseAll(props.modelValue);
		const atoms = ref(parsed.atoms || []);
		// Modo texto: forzado si no se pudo reconocer, o si el usuario lo pide.
		const rawMode = ref(parsed.atoms === null);
		const rawText = ref(parsed.raw !== null ? parsed.raw : (props.modelValue || ''));

		watch(() => props.modelValue, (v) => {
			if (serialize() === v) return; // eco de nuestro propio commit
			const p = parseAll(v);
			if (p.atoms !== null) { atoms.value = p.atoms; if (!rawMode.value) rawText.value = v; }
			else { rawText.value = v; rawMode.value = true; }
		});

		function serialize() {
			if (rawMode.value) return rawText.value;
			return atoms.value.map(serializeAtom).filter(Boolean).join(' and ');
		}
		function commit() { emit('update:modelValue', serialize()); }

		function addAtom(key) {
			const def = BY_KEY[key];
			if (!def) return;
			const a = { key, kind: def.kind };
			if (def.kind === 'fnStr') a.a = '';
			if (def.kind === 'fnCmpNum') { a.a = ''; a.op = def.ops[0]; a.b = '0'; }
			if (def.kind === 'varCmpNum') { a.op = def.ops[0]; a.b = '0'; }
			if (def.kind === 'varCmpStr') { a.op = def.ops[0]; a.a = ''; }
			atoms.value.push(a);
			commit();
		}
		function removeAtom(i) { atoms.value.splice(i, 1); commit(); }
		function onAddSelect(e) { const v = e.target.value; if (v) { addAtom(v); e.target.value = ''; } }

		// Alternar a modo texto: intenta re-parsear al volver a modo formulario;
		// si ya no encaja (el usuario escribió algo más complejo), se queda en texto.
		function toggleRawMode() {
			if (rawMode.value) {
				const p = parseAll(rawText.value);
				if (p.atoms !== null) { atoms.value = p.atoms; rawMode.value = false; }
				// si no se puede reconocer, se queda en modo texto sin más aviso.
			} else {
				rawText.value = serialize();
				rawMode.value = true;
			}
		}
		function onRawInput(v) { rawText.value = v; emit('update:modelValue', v); }

		return {
			CONDITION_TOKENS, atoms, rawMode, rawText,
			addAtom, removeAtom, onAddSelect, toggleRawMode, onRawInput, serialize,
			tokenDef: (key) => BY_KEY[key] || {},
		};
	},
	template: `
	<div class="cond-editor">
		<div class="flex" style="justify-content:flex-end; margin-bottom:4px">
			<button type="button" class="btn ghost xs" @click="toggleRawMode">
				{{ rawMode ? '🧩 Volver al formulario' : '▤ Ver/editar como texto' }}
			</button>
		</div>

		<template v-if="rawMode">
			<input class="input mono" :value="rawText" @input="onRawInput($event.target.value)"
				placeholder='p.ej. has_flag("regular") and cordura >= 2' />
			<p class="muted" style="margin:4px 0 0">
				Esta condición usa "or"/"not"/paréntesis, o no se reconoce del todo —
				se edita como texto (Godot Expression). El botón de arriba intenta
				volver al formulario si la simplificas a "A and B and C".
			</p>
		</template>
		<template v-else>
			<div v-for="(a, i) in atoms" :key="i" class="cond-atom">
				<span class="chip mono">{{ a.key }}</span>
				<template v-if="tokenDef(a.key).kind === 'fnStr'">
					<input v-model="a.a" @input="commit" :placeholder="tokenDef(a.key).argHint || 'valor'" />
				</template>
				<template v-else-if="tokenDef(a.key).kind === 'fnCmpNum'">
					<input v-model="a.a" @input="commit" :placeholder="tokenDef(a.key).argHint || 'id'" style="width:110px" />
					<select v-model="a.op" @change="commit"><option v-for="o in tokenDef(a.key).ops" :key="o" :value="o">{{ o }}</option></select>
					<input v-model="a.b" @input="commit" style="width:64px" placeholder="0" />
				</template>
				<template v-else-if="tokenDef(a.key).kind === 'varCmpNum'">
					<select v-model="a.op" @change="commit"><option v-for="o in tokenDef(a.key).ops" :key="o" :value="o">{{ o }}</option></select>
					<input v-model="a.b" @input="commit" style="width:64px" placeholder="0" />
				</template>
				<template v-else-if="tokenDef(a.key).kind === 'varCmpStr'">
					<select v-model="a.op" @change="commit"><option v-for="o in tokenDef(a.key).ops" :key="o" :value="o">{{ o }}</option></select>
					<input v-model="a.a" @input="commit" placeholder="estado" style="width:120px" />
				</template>
				<span class="spacer"></span>
				<button type="button" class="btn sm danger" @click="removeAtom(i)">✕</button>
			</div>
			<p v-if="atoms.length > 1" class="muted" style="margin:2px 0 6px">Se cumple si se cumplen TODAS a la vez (Y lógico).</p>

			<div class="flex" style="flex-wrap:wrap; gap:5px; margin-top:6px">
				<select @change="onAddSelect($event)">
					<option value="">+ Añadir condición…</option>
					<option v-for="t in CONDITION_TOKENS" :key="t.key" :value="t.key">{{ t.label }}</option>
				</select>
			</div>
			<div v-if="serialize()" class="cond-preview mono">{{ serialize() }}</div>
			<p v-else class="muted" style="margin:4px 0 0">Sin condiciones: la opción/nodo siempre está disponible.</p>
		</template>
	</div>
	`,
};
