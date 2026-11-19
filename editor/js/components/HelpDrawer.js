// components/HelpDrawer.js
// ─────────────────────────────────────────────────────────────────────────────
// AYUDA CONTEXTUAL. Cajón lateral que muestra la ayuda de la
// pestaña activa (resumen, consejos y atajos), más los atajos globales. El
// contenido vive en `lib/helpContent.js`; este componente solo lo presenta.
// ─────────────────────────────────────────────────────────────────────────────
import { computed } from 'https://unpkg.com/vue@3/dist/vue.esm-browser.prod.js';
import { store } from '../store.js';
import { TAB_META } from '../nav.js';
import { helpFor, GLOBAL_SHORTCUTS } from '../lib/helpContent.js';

export default {
	name: 'HelpDrawer',
	props: { open: Boolean },
	emits: ['close'],
	setup() {
		const tab = computed(() => store.activeTab);
		const meta = computed(() => TAB_META[tab.value] || { label: tab.value, icon: '❓' });
		const help = computed(() => helpFor(tab.value));
		return { store, tab, meta, help, globals: GLOBAL_SHORTCUTS };
	},
	template: `
	<div>
		<div v-if="open" class="overlay" @click="$emit('close')"></div>
		<div class="help-drawer" :class="{ open }">
			<div class="help-head">
				<strong>{{ meta.icon }} Ayuda · {{ meta.label }}</strong>
				<span class="grow"></span>
				<button class="btn sm ghost" @click="$emit('close')">✕</button>
			</div>
			<div class="help-body">
				<p class="help-summary">{{ help.summary }}</p>

				<template v-if="help.tips && help.tips.length">
					<div class="help-section-title">💡 Consejos</div>
					<ul class="help-tips">
						<li v-for="(t,i) in help.tips" :key="i">{{ t }}</li>
					</ul>
				</template>

				<template v-if="help.bestPractices && help.bestPractices.length">
					<div class="help-section-title">✅ Buenas prácticas</div>
					<ul class="help-tips help-good">
						<li v-for="(t,i) in help.bestPractices" :key="i">{{ t }}</li>
					</ul>
				</template>

				<template v-if="help.pitfalls && help.pitfalls.length">
					<div class="help-section-title">⚠️ Errores frecuentes</div>
					<ul class="help-tips help-bad">
						<li v-for="(t,i) in help.pitfalls" :key="i">{{ t }}</li>
					</ul>
				</template>

				<template v-if="help.examples && help.examples.length">
					<div class="help-section-title">📋 Ejemplos</div>
					<div class="help-examples">
						<div v-for="(e,i) in help.examples" :key="i" class="help-example">
							<div class="help-example__title">{{ e.title }}</div>
							<code v-if="e.code" class="help-example__code">{{ e.code }}</code>
							<div v-if="e.note" class="help-example__note">{{ e.note }}</div>
						</div>
					</div>
				</template>

				<template v-if="help.shortcuts && help.shortcuts.length">
					<div class="help-section-title">⌨️ Atajos de esta sección</div>
					<div class="help-kbds">
						<div v-for="(s,i) in help.shortcuts" :key="i" class="help-kbd-row">
							<kbd>{{ s.keys }}</kbd><span>{{ s.desc }}</span>
						</div>
					</div>
				</template>

				<div class="help-section-title">🌐 Atajos globales</div>
				<div class="help-kbds">
					<div v-for="(s,i) in globals" :key="i" class="help-kbd-row">
						<kbd>{{ s.keys }}</kbd><span>{{ s.desc }}</span>
					</div>
				</div>
			</div>
		</div>
	</div>
	`,
};
