// components/AchievementsManager.js
// ─────────────────────────────────────────────────────────────────────────────
// Gestor de achievements.json (Fase G): logros por CONDICIÓN. Cada entrada es
// `ach_id -> { name{es,en}, desc{es,en}, icon, condition, reward }`.
//   · condition: expresión Godot evaluada por MetaManager (p. ej. stat("kills") >= 1).
//   · reward:    mini-lenguaje de recompensas (RewardEditor), aplicado al desbloquear.
// Reutiliza el CRUD/atajos comunes de useCollection y el panel de lista común.
// ─────────────────────────────────────────────────────────────────────────────
import { store, getI18n, getI18nFallback, getI18nDisplay, setI18n } from '../store.js';
import { useCollection } from '../lib/useCollection.js';
import EntityListPanel from './EntityListPanel.js';
import EditorToolbar from './EditorToolbar.js';
import RewardEditor from './RewardEditor.js';

// Fragmentos habituales de condición para el asistente (MetaManager / Design).
const COND_SNIPPETS = [
	'stat("kills") >= 25',
	'gold >= 1000',
	'stat("level") >= 10',
	'stat("job_level") >= 10',
	'has_prof("Guerrero")',
	'has_item("diario")',
	'gflag("dam_opened")',
	'bondad >= 5',
	'cordura >= 5',
];

export default {
	name: 'AchievementsManager',
	components: { EntityListPanel, EditorToolbar, RewardEditor },
	setup() {
		const col = useCollection({
			tabId: 'achievements',
			dirtyKey: 'achievements',
			collection: () => store.achievements,
			setCollection: (v) => { store.achievements = v; },
			selectedKey: 'selectedAchievement',
			clipboardKind: 'achievement',
			entityLabel: 'logro',
			newIdBase: 'nuevo_logro',
			makeNew: () => ({
				name: { es: 'Nuevo logro', en: 'New achievement' },
				desc: { es: '', en: '' },
				icon: '🏆',
				condition: 'stat("kills") >= 1',
				reward: 'gold:50;xp:20',
			}),
			searchText: (id, o) => id + ' ' + (o?.name?.es || '') + ' ' + (o?.name?.en || ''),
			sorts: [
				{ key: 'id', label: 'ID', get: (id) => id },
				{ key: 'name', label: 'Nombre', get: (id, o) => (o?.name?.es || id).toLowerCase() },
			],
		});
		const current = col.current;

		function setField(path, value) {
			col.edit(() => {
				const o = current.value;
				if (path === 'icon') o.icon = value;
				else if (path === 'condition') o.condition = value;
				else if (path === 'reward') o.reward = value;
				else if (path.startsWith('name.')) setI18n(o, 'name', value, path.split('.')[1]);
				else if (path.startsWith('desc.')) setI18n(o, 'desc', value, path.split('.')[1]);
			});
		}

		return {
			store, col, current, setField, COND_SNIPPETS,
			getI18n, getI18nFallback, getI18nDisplay, setI18n,
		};
	},
	template: `
	<div class="manager">
		<entity-list-panel :c="col" search-placeholder="Buscar logro…" new-label="➕ Nuevo logro">
			<template #row="{ id, o }">
				<span class="ent-icon">{{ (o && o.icon) || '🏆' }}</span>
				<span class="ent-name">{{ (o && o.name && (o.name[store.currentLang] || o.name.en || o.name.es)) || id }}</span>
				<span class="ent-id mono">{{ id }}</span>
			</template>
		</entity-list-panel>

		<section class="editor-pane" v-if="current">
			<editor-toolbar :can-undo="col.canUndo.value" :can-redo="col.canRedo.value"
				:can-paste="col.canPaste.value" :has-current="!!current" :dirty="col.dirty.value"
				:saved-text="col.savedText.value"
				@undo="col.undo()" @redo="col.redo()" @copy="col.copy()" @paste="col.paste()"
				@duplicate="col.duplicate()" @remove="col.remove()" @save="col.doSave()"></editor-toolbar>

			<h3 class="sec">🏆 Logro</h3>
			<div class="form-grid">
				<label>ID
					<input class="input mono" type="text" :value="col.selectedId.value" @change="col.rename($event.target.value)" />
				</label>
				<label>Icono
					<input class="input f-xs" type="text" :value="current.icon" @input="setField('icon', $event.target.value)" />
				</label>
				<label>Nombre [{{ store.currentLang.toUpperCase() }}]
					<input class="input" type="text" :value="getI18n(current.name)" :placeholder="getI18nFallback(current.name) || 'Nombre del logro...'" @input="setField('name.' + store.currentLang, $event.target.value)" />
				</label>
				<div class="full">
					<label>Descripción [{{ store.currentLang.toUpperCase() }}]
						<input class="input" type="text" :value="getI18n(current.desc)" :placeholder="getI18nFallback(current.desc) || 'Descripción del logro...'" @input="setField('desc.' + store.currentLang, $event.target.value)" />
					</label>
				</div>
			</div>

			<h3 class="sec" style="margin-top:16px">✅ Condición de desbloqueo</h3>
			<p class="muted" style="margin:0 0 6px">Expresión evaluada por el motor. Variables: <span class="mono">gold</span>, <span class="mono">stat("kills"|"level"|"deaths"…)</span>, <span class="mono">has_item("id")</span>.</p>
			<input class="input mono" type="text" :value="current.condition" @input="setField('condition', $event.target.value)" placeholder='stat("kills") >= 1' />
			<div class="flex" style="flex-wrap:wrap; gap:5px; margin-top:6px">
				<button v-for="s in COND_SNIPPETS" :key="s" class="btn sm ghost mono" @click="setField('condition', s)">{{ s }}</button>
			</div>

			<h3 class="sec" style="margin-top:16px">🎁 Recompensa al desbloquear</h3>
			<reward-editor :model-value="current.reward || ''" @update:model-value="setField('reward', $event)"></reward-editor>
		</section>

		<section class="editor-pane empty" v-else>
			<p class="muted">Selecciona o crea un logro.</p>
		</section>
	</div>
	`,
};
