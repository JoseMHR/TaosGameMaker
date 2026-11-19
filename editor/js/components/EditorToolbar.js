// components/EditorToolbar.js
// ─────────────────────────────────────────────────────────────────────────────
// BARRA DE ACCIONES COMÚN a todos los editores (Tarea 4). Presenta de forma
// uniforme: deshacer/rehacer, copiar/pegar/duplicar/eliminar, indicador de
// cambios pendientes, estado de autoguardado y guardar manual.
//
// Es un componente PRESENTACIONAL: recibe el estado por props y emite eventos.
// Encaja con el objeto devuelto por `useCollection` (los editores le pasan sus
// campos), pero también lo pueden usar editores no-colección (Mapa/Mazmorras).
// ─────────────────────────────────────────────────────────────────────────────
export default {
	name: 'EditorToolbar',
	props: {
		title: { type: String, default: '' },
		canUndo: { type: Boolean, default: false },
		canRedo: { type: Boolean, default: false },
		canPaste: { type: Boolean, default: false },
		hasCurrent: { type: Boolean, default: false },
		dirty: { type: Boolean, default: false },
		savedText: { type: String, default: '' },
		// Permite ocultar acciones que un editor concreto no soporte.
		show: {
			type: Object,
			default: () => ({ undo: true, copy: true, paste: true, duplicate: true, remove: true, save: true }),
		},
	},
	emits: ['undo', 'redo', 'copy', 'paste', 'duplicate', 'remove', 'save'],
	template: `
	<div class="editor-toolbar">
		<span v-if="title" class="et-title">{{ title }}</span>
		<div v-if="show.undo !== false" class="seg">
			<button class="btn sm ghost" :disabled="!canUndo" @click="$emit('undo')" title="Deshacer (Ctrl+Z)">↶</button>
			<button class="btn sm ghost" :disabled="!canRedo" @click="$emit('redo')" title="Rehacer (Ctrl+Y)">↷</button>
		</div>
		<div class="seg">
			<button v-if="show.copy !== false" class="btn sm ghost" :disabled="!hasCurrent" @click="$emit('copy')" title="Copiar (Ctrl+C)">⧉ Copiar</button>
			<button v-if="show.paste !== false" class="btn sm ghost" :disabled="!canPaste" @click="$emit('paste')" title="Pegar (Ctrl+V)">📋 Pegar</button>
			<button v-if="show.duplicate !== false" class="btn sm ghost" :disabled="!hasCurrent" @click="$emit('duplicate')" title="Duplicar (Ctrl+D)">⧉ Duplicar</button>
			<button v-if="show.remove !== false" class="btn sm danger" :disabled="!hasCurrent" @click="$emit('remove')" title="Eliminar (Supr)">🗑 Eliminar</button>
		</div>
		<span class="spacer"></span>
		<span v-if="dirty" class="et-dirty" title="Cambios sin guardar">●</span>
		<span class="et-saved">{{ savedText }}</span>
		<button v-if="show.save !== false" class="btn sm primary" :disabled="!dirty" @click="$emit('save')" title="Guardar (Ctrl+S)">💾 Guardar</button>
	</div>
	`,
};
