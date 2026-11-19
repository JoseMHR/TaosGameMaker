// components/RewardEditor.js
// ─────────────────────────────────────────────────────────────────────────────
// Editor asistido del mini-lenguaje de recompensas (";"-separado). Parsea el
// string a tokens editables y lo re-serializa en cada cambio, emitiendo
// `update:modelValue`. Respeta la gramática de Design.gd (_apply_token).
// ─────────────────────────────────────────────────────────────────────────────
import { ref, watch } from 'https://unpkg.com/vue@3/dist/vue.esm-browser.prod.js';
import { REWARD_TOKENS, FACETS } from '../store.js';

const BY_KEY = Object.fromEntries(REWARD_TOKENS.map(t => [t.key, t]));

// Parsea "gold:+10;faceta:amabilidad=+1" -> [{key,value,...}]
function parse(str) {
	const toks = [];
	for (const raw of (str || '').split(';')) {
		const tok = raw.trim();
		if (!tok) continue;
		let key, rest;
		if (tok.startsWith('-item:')) { key = '-item'; rest = tok.slice(6); }
		else {
			const c = tok.indexOf(':');
			key = c === -1 ? tok : tok.slice(0, c);
			rest = c === -1 ? '' : tok.slice(c + 1);
		}
		const def = BY_KEY[key];
		const kind = def ? def.value : 'str';
		const t = { key, kind, raw: '' };
		if (kind === 'facet' || kind === 'item') {
			const eq = rest.indexOf('=');
			t.a = eq === -1 ? rest : rest.slice(0, eq);
			t.b = eq === -1 ? '' : rest.slice(eq + 1);
		} else {
			t.a = rest;
		}
		if (!def) { t.key = key; t.kind = 'raw'; t.raw = tok; }
		toks.push(t);
	}
	return toks;
}

function serializeTok(t) {
	if (t.kind === 'raw') return t.raw;
	if (t.kind === 'none') return t.key;
	if (t.kind === 'facet' || t.kind === 'item') return `${t.key}:${t.a || ''}=${t.b || ''}`;
	return `${t.key}:${t.a || ''}`;
}

export default {
	name: 'RewardEditor',
	props: { modelValue: { type: String, default: '' } },
	emits: ['update:modelValue'],
	setup(props, { emit }) {
		const toks = ref(parse(props.modelValue));

		// Si el valor externo cambia (cambio de nodo), re-parsear.
		watch(() => props.modelValue, (v) => {
			if (serialize() !== v) toks.value = parse(v);
		});

		function serialize() { return toks.value.map(serializeTok).filter(Boolean).join(';'); }
		function commit() { emit('update:modelValue', serialize()); }

		function addTok(key) {
			const def = BY_KEY[key];
			const t = { key, kind: def.value, a: '', b: '', raw: '' };
			if (def.value === 'facet') { t.a = FACETS[0]; t.b = '+1'; }
			if (def.value === 'int') t.a = '+1';
			toks.value.push(t); commit();
		}
		function removeTok(i) { toks.value.splice(i, 1); commit(); }

		function onAddSelect(e) {
			const v = e.target.value;
			if (v) { addTok(v); e.target.value = ''; }
		}

		return { toks, REWARD_TOKENS, FACETS, addTok, removeTok, commit, serialize, onAddSelect };
	},
	template: `
	<div>
		<div v-for="(t, i) in toks" :key="i" class="reward-tok">
			<span class="chip mono">{{ t.key }}</span>
			<template v-if="t.kind==='facet'">
				<select v-model="t.a" @change="commit"><option v-for="f in FACETS" :key="f" :value="f">{{ f }}</option></select>
				<input v-model="t.b" @input="commit" style="width:64px" placeholder="+1" />
			</template>
			<template v-else-if="t.kind==='item'">
				<input v-model="t.a" @input="commit" placeholder="item_id" />
				<span>×</span>
				<input v-model="t.b" @input="commit" style="width:56px" placeholder="1" />
			</template>
			<template v-else-if="t.kind==='int'">
				<input v-model="t.a" @input="commit" style="width:72px" placeholder="+1" />
			</template>
			<template v-else-if="t.kind==='none'"><span class="muted">(sin valor)</span></template>
			<template v-else-if="t.kind==='raw'">
				<input v-model="t.raw" @input="commit" placeholder="token crudo" />
			</template>
			<template v-else>
				<input v-model="t.a" @input="commit" placeholder="valor" />
			</template>
			<button class="btn sm danger" @click="removeTok(i)">✕</button>
		</div>

		<div class="flex" style="flex-wrap:wrap; gap:5px; margin-top:6px">
			<select @change="onAddSelect($event)">
				<option value="">+ Añadir acción…</option>
				<option v-for="r in REWARD_TOKENS" :key="r.key" :value="r.key">{{ r.key }} — {{ r.hint }}</option>
			</select>
		</div>
		<div v-if="serialize()" class="reward-preview">{{ serialize() }}</div>
	</div>
	`,
};
