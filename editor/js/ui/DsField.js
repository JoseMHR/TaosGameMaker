// ui/DsField.js
// ─────────────────────────────────────────────────────────────────────────────
// DESIGN SYSTEM · Campo de formulario (Fase 1). Envoltorio consistente para un
// control: etiqueta, pista/ayuda, mensaje de error y el control en sí (slot).
// Homogeneiza el aspecto de TODOS los formularios del editor.
//
// Props: label, hint, error, required, inline (etiqueta a la izquierda).
// Slots: default (control), #label (etiqueta custom).
// ─────────────────────────────────────────────────────────────────────────────
export default {
	name: 'DsField',
	props: {
		label: { type: String, default: '' },
		hint: { type: String, default: '' },
		error: { type: String, default: '' },
		required: { type: Boolean, default: false },
		inline: { type: Boolean, default: false },
	},
	template: `
	<div class="ds-field" :class="{ 'ds-field--inline': inline, 'is-error': !!error }">
		<label v-if="label || $slots.label" class="ds-field__label">
			<slot name="label">{{ label }}</slot><span v-if="required" class="ds-field__req">*</span>
		</label>
		<div class="ds-field__control"><slot></slot></div>
		<div v-if="error" class="ds-field__error">{{ error }}</div>
		<div v-else-if="hint" class="ds-field__hint">{{ hint }}</div>
	</div>
	`,
};
