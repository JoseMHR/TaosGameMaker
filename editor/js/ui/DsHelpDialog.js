// ui/DsHelpDialog.js
// ─────────────────────────────────────────────────────────────────────────────
// DESIGN SYSTEM · Ayuda contextual (Fase 1). Ventana integrada (no documento
// externo) que cada editor abre para explicarse. El contenido es DATA-DRIVEN: se
// le pasa un objeto `help` con secciones, buenas prácticas, errores y atajos, de
// modo que añadir ayuda a un editor no requiere tocar este componente.
//
// Estructura de `help`:
//   {
//     title, intro,
//     sections: [{ heading, body?, items?: [String] }],
//     tips:   [String],        // buenas prácticas
//     pitfalls:[String],       // errores frecuentes
//     shortcuts:[{ keys, desc }],
//   }
// ─────────────────────────────────────────────────────────────────────────────
import DsModal from './DsModal.js';

export default {
	name: 'DsHelpDialog',
	components: { DsModal },
	props: {
		open: { type: Boolean, default: false },
		help: { type: Object, default: () => ({}) },
	},
	emits: ['close'],
	template: `
	<ds-modal :open="open" size="lg" @close="$emit('close')">
		<template #header>
			<h3 class="ds-modal__title">❓ {{ help.title || 'Ayuda' }}</h3>
		</template>
		<div class="ds-help">
			<p v-if="help.intro" class="ds-help__intro">{{ help.intro }}</p>

			<section v-for="(s,i) in (help.sections||[])" :key="i" class="ds-help__sec">
				<h4>{{ s.heading }}</h4>
				<p v-if="s.body">{{ s.body }}</p>
				<ul v-if="s.items && s.items.length"><li v-for="(it,j) in s.items" :key="j">{{ it }}</li></ul>
			</section>

			<section v-if="help.tips && help.tips.length" class="ds-help__sec ds-help__tips">
				<h4>✅ Buenas prácticas</h4>
				<ul><li v-for="(t,i) in help.tips" :key="i">{{ t }}</li></ul>
			</section>

			<section v-if="help.pitfalls && help.pitfalls.length" class="ds-help__sec ds-help__pitfalls">
				<h4>⚠️ Errores frecuentes</h4>
				<ul><li v-for="(p,i) in help.pitfalls" :key="i">{{ p }}</li></ul>
			</section>

			<section v-if="help.shortcuts && help.shortcuts.length" class="ds-help__sec">
				<h4>⌨️ Atajos</h4>
				<div class="ds-help__keys">
					<div v-for="(k,i) in help.shortcuts" :key="i" class="ds-help__key">
						<kbd>{{ k.keys }}</kbd><span>{{ k.desc }}</span>
					</div>
				</div>
			</section>
		</div>
	</ds-modal>
	`,
};
