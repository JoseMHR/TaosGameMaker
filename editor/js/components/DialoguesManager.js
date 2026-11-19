// components/DialoguesManager.js
// ─────────────────────────────────────────────────────────────────────────────
// Gestor de dialogues.json (Fase F): diálogos GUIONIZADOS (no ramificados como
// los de NPC). Cada entrada es
//   `dialogue_id -> { npc_name{es,en}, npc_avatar, text{es,en}, choices:[ {text{es,en}, action} ] }`.
//   · action: normalmente "dismiss"/"close" para cerrar el popup.
// Reutiliza el CRUD/atajos comunes de useCollection y el panel de lista común.
// ─────────────────────────────────────────────────────────────────────────────
import { store, getI18n, getI18nFallback, getI18nDisplay, setI18n } from '../store.js';
import { useCollection } from '../lib/useCollection.js';
import EntityListPanel from './EntityListPanel.js';
import EditorToolbar from './EditorToolbar.js';

export default {
	name: 'DialoguesManager',
	components: { EntityListPanel, EditorToolbar },
	setup() {
		const col = useCollection({
			tabId: 'dialogues',
			dirtyKey: 'dialogues',
			collection: () => store.dialogues,
			setCollection: (v) => { store.dialogues = v; },
			selectedKey: 'selectedDialogue',
			clipboardKind: 'dialogue',
			entityLabel: 'diálogo',
			newIdBase: 'nuevo_dialogo',
			makeNew: () => ({
				npc_name: { es: 'Narrador', en: 'Narrator' },
				npc_avatar: '💬',
				text: { es: '', en: '' },
				choices: [{ text: { es: 'Continuar', en: 'Continue' }, action: 'dismiss' }],
			}),
			searchText: (id, o) => id + ' ' + (o?.npc_name?.es || '') + ' ' + (o?.text?.es || ''),
			sorts: [{ key: 'id', label: 'ID', get: (id) => id }],
		});
		const current = col.current;

		function setField(path, v) {
			col.edit(() => {
				const o = current.value;
				if (path === 'npc_avatar') o.npc_avatar = v;
				else if (path.startsWith('name.')) setI18n(o, 'npc_name', v, path.split('.')[1]);
				else if (path.startsWith('text.')) setI18n(o, 'text', v, path.split('.')[1]);
			});
		}
		function setChoice(idx, path, v) {
			col.edit(() => {
				const c = current.value.choices[idx];
				if (path === 'action') c.action = v;
				else if (path.startsWith('text.')) setI18n(c, 'text', v, path.split('.')[1]);
			});
		}
		function addChoice() { col.edit(() => { current.value.choices = current.value.choices || []; current.value.choices.push({ text: { es: '', en: '' }, action: 'dismiss' }); }); }
		function removeChoice(idx) { col.edit(() => { current.value.choices.splice(idx, 1); }); }

		function getDialogueAvatar(o) {
			if (!o) return null;
			const av = o.npc_avatar || '';
			if (!av) return null;
			if (av.includes('.') || av.startsWith('npc_')) {
				const f = av.endsWith('.png') ? av : (av.startsWith('npc_') ? av + '.png' : 'npc_' + av + '.png');
				return `/api/assets/npc/${encodeURIComponent(f)}`;
			}
			return null;
		}

		return {
			store, col, current, setField, setChoice, addChoice, removeChoice,
			getDialogueAvatar,
			getI18n, getI18nFallback, getI18nDisplay, setI18n,
		};
	},
	template: `
	<div class="manager">
		<entity-list-panel :c="col" search-placeholder="Buscar diálogo…" new-label="➕ Nuevo diálogo">
			<template #row="{ id, o }">
				<img v-if="getDialogueAvatar(o)" :src="getDialogueAvatar(o)" class="ent-thumb" alt=""
					@error="e => { e.target.style.display='none'; if (e.target.nextElementSibling) e.target.nextElementSibling.style.display='inline-block'; }" />
				<span class="ent-icon" :style="{ display: getDialogueAvatar(o) ? 'none' : 'inline-block' }">{{ (o && o.npc_avatar) || '💬' }}</span>
				<span class="ent-name">{{ (o && o.npc_name && (o.npc_name[store.currentLang] || o.npc_name.en || o.npc_name.es)) || id }}</span>
				<span class="ent-id mono">{{ id }}</span>
			</template>
		</entity-list-panel>

		<section class="editor-pane" v-if="current">
			<editor-toolbar :can-undo="col.canUndo.value" :can-redo="col.canRedo.value"
				:can-paste="col.canPaste.value" :has-current="!!current" :dirty="col.dirty.value"
				:saved-text="col.savedText.value"
				@undo="col.undo()" @redo="col.redo()" @copy="col.copy()" @paste="col.paste()"
				@duplicate="col.duplicate()" @remove="col.remove()" @save="col.doSave()"></editor-toolbar>

			<h3 class="sec">💬 Diálogo guionizado</h3>
			<div class="form-grid">
				<label>ID
					<input class="input mono" type="text" :value="col.selectedId.value" @change="col.rename($event.target.value)" />
				</label>
				<label>Avatar
					<input class="input f-xs" type="text" :value="current.npc_avatar" @input="setField('npc_avatar', $event.target.value)" />
				</label>
				<label>Nombre [{{ store.currentLang.toUpperCase() }}]
					<input class="input" type="text" :value="getI18n(current.npc_name)" :placeholder="getI18nFallback(current.npc_name) || 'Nombre...'" @input="setField('name.' + store.currentLang, $event.target.value)" />
				</label>
				<div class="full">
					<label>Texto [{{ store.currentLang.toUpperCase() }}]
						<textarea class="input" :value="getI18n(current.text)" :placeholder="getI18nFallback(current.text) || 'Texto del diálogo...'" @input="setField('text.' + store.currentLang, $event.target.value)" rows="3"></textarea>
					</label>
				</div>
			</div>

			<div class="pane-header" style="margin-top:14px">
				<h3 class="sec">🔘 Opciones ({{ (current.choices && current.choices.length) || 0 }})</h3>
				<button class="btn secondary sm" @click="addChoice">➕ Añadir opción</button>
			</div>
			<div class="skills-list" style="margin-top:10px">
				<div class="card panel" style="margin-bottom:10px; padding:12px; border:1px solid rgba(255,255,255,0.1)"
					v-for="(c, idx) in current.choices" :key="idx">
					<div class="form-grid" style="align-items:end">
						<label>Texto [{{ store.currentLang.toUpperCase() }}] <input class="input" type="text" :value="getI18n(c.text)" :placeholder="getI18nFallback(c.text) || 'Texto de la opción...'" @input="setChoice(idx, 'text.' + store.currentLang, $event.target.value)" /></label>
						<label>Acción <input class="input mono" type="text" :value="c.action" @input="setChoice(idx, 'action', $event.target.value)" placeholder="dismiss" /></label>
						<button class="btn sm err" @click="removeChoice(idx)">🗑️</button>
					</div>
				</div>
				<p v-if="!current.choices || !current.choices.length" class="muted">Sin opciones. El diálogo necesita al menos una para cerrarse.</p>
			</div>
		</section>

		<section class="editor-pane empty" v-else>
			<p class="muted">Selecciona o crea un diálogo.</p>
		</section>
	</div>
	`,
};
