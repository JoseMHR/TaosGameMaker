// ui/DsConfirmDialog.js
// ─────────────────────────────────────────────────────────────────────────────
// DESIGN SYSTEM · Diálogo de confirmación (Fase 1). Sustituye a los window.confirm
// nativos por un diálogo coherente con el tema. Reutiliza DsModal.
//
// Props: open, title, message, confirmText, cancelText, danger (estilo destructivo).
// Emite: 'confirm', 'cancel' (y 'close' al cerrar por backdrop/ESC = cancel).
// ─────────────────────────────────────────────────────────────────────────────
import DsModal from './DsModal.js';

export default {
	name: 'DsConfirmDialog',
	components: { DsModal },
	props: {
		open: { type: Boolean, default: false },
		title: { type: String, default: 'Confirmar' },
		message: { type: String, default: '¿Seguro?' },
		confirmText: { type: String, default: 'Aceptar' },
		cancelText: { type: String, default: 'Cancelar' },
		danger: { type: Boolean, default: false },
	},
	emits: ['confirm', 'cancel'],
	template: `
	<ds-modal :open="open" :title="title" size="sm" @close="$emit('cancel')">
		<p class="ds-confirm__msg">{{ message }}</p>
		<template #footer>
			<button class="btn ghost" @click="$emit('cancel')">{{ cancelText }}</button>
			<button class="btn" :class="danger ? 'danger' : 'primary'" @click="$emit('confirm')">{{ confirmText }}</button>
		</template>
	</ds-modal>
	`,
};
