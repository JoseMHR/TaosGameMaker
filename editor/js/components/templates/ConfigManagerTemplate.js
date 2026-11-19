// components/templates/ConfigManagerTemplate.js
// Plantilla (markup Vue) extraída de ConfigManager.js.
// Solo maquetación: NO contiene lógica. La lógica (setup/props/estado) vive en ConfigManager.js.
// Regenerable con: node tools/extract_template.mjs editor/js/components/ConfigManager.js
export default `
	<div class="manager" style="display:block; overflow:auto">
		<section class="editor-pane">
			<editor-toolbar :dirty="dirty" :has-current="true" :can-undo="canUndo" :can-redo="canRedo"
				:show="{ undo:true, copy:false, paste:false, duplicate:false, remove:false, save:true }"
				@undo="undo()" @redo="redo()" @save="doSave()"></editor-toolbar>

			<h3 class="sec">⚙️ Parámetros de balance (config.json)</h3>
			<p class="muted" style="margin:4px 0 14px">Estos valores los lee <span class="mono">GameConfig.gd</span> con <b>fallback</b>: si borras una clave (o el fichero), el juego usa su valor por defecto. Cambian el balance sin tocar código.</p>

			<div class="subtabs">
				<button :class="{ active: subTab === 'scalars' }" @click="subTab = 'scalars'">🔢 Escalares</button>
				<button :class="{ active: subTab === 'balance' }" @click="subTab = 'balance'">🧪 Balance avanzado (estados / rareza / campamento)</button>
			</div>

			<template v-if="subTab === 'scalars'">
				<div v-for="dict in DICT_FIELDS" :key="dict.key" class="card panel" style="margin-bottom:12px; padding:12px; border:1px solid rgba(255,255,255,0.1)">
					<h4 class="sec" style="margin:0 0 8px">{{ dict.title }}</h4>
					<div class="form-grid">
						<label v-for="k in dict.keys" :key="k">{{ k }}
							<input class="input num" type="number" :value="dictVal(dict.key, k, dict.def[k])" @input="setDict(dict.key, k, $event.target.value, dict.def)" />
						</label>
					</div>
				</div>

				<div v-for="s in SECTIONS" :key="s.title" class="card panel" style="margin-bottom:12px; padding:12px; border:1px solid rgba(255,255,255,0.1)">
					<h4 class="sec" style="margin:0 0 8px">{{ s.title }}</h4>
					<div class="form-grid">
						<label v-for="f in s.fields" :key="f[0]">{{ f[1] }} <span class="mono muted" style="font-size:10px">{{ f[0] }}</span>
							<input v-if="f[2] === 'bool'" type="checkbox" :checked="!!val(f[0], f[3])" @change="setField(f[0], 'bool', $event.target.checked)" />
							<input v-else-if="f[2] === 'str'" class="input" type="text" :value="val(f[0], f[3])" @input="setField(f[0], 'str', $event.target.value)" />
							<input v-else class="input num" type="number" :step="f[2] === 'float' ? 'any' : '1'" :value="val(f[0], f[3])" @input="setField(f[0], f[2], $event.target.value)" />
						</label>
					</div>
				</div>
			</template>

			<template v-else-if="store.expertMode">
				<p class="muted" style="margin:4px 0 14px">
					Overrides OPCIONALES por clave sobre las tablas cableadas de <span class="mono">GameConfig.gd</span>
					(<span class="mono">STATUS_EFFECTS</span> / <span class="mono">RARITIES</span> / <span class="mono">CAMP_STRUCTURES</span>). Solo se pueden tocar
					campos que YA EXISTEN — no se pueden crear estados, rarezas o construcciones nuevas aquí (el motor
					solo interpreta las claves que ya conoce). Un campo sin override usa el valor cableado.
				</p>

				<h4 class="sec">💫 Estados alterados</h4>
				<div v-for="key in STATUS_KEYS" :key="key" class="card panel" style="margin-bottom:10px; padding:10px 12px; border:1px solid rgba(255,255,255,0.1)">
					<div class="flex" style="justify-content:space-between; align-items:center">
						<b class="mono">{{ key }}</b>
						<span class="muted" style="font-size:11px">{{ STATUS_BASE[key].good ? 'beneficioso' : 'perjudicial' }}</span>
					</div>
					<div class="form-grid" style="margin-top:6px">
						<label>Icono
							<input class="input f-xs" type="text" :value="fieldVal('status_effects', key, 'icon', STATUS_BASE[key].icon)"
								@input="setOverrideField('status_effects', key, 'icon', 'str', $event.target.value)" />
						</label>
						<label>Color
							<input class="input" type="color" :value="'#' + fieldVal('status_effects', key, 'color', STATUS_BASE[key].color)"
								@input="setOverrideField('status_effects', key, 'color', 'color', $event.target.value)" />
						</label>
						<label v-for="f in statusModFields(key)" :key="f">{{ f }}
							<input v-if="STATUS_FIELD_TYPES[f] === 'bool'" type="checkbox"
								:checked="!!fieldVal('status_effects', key, f, STATUS_BASE[key][f])"
								@change="setOverrideField('status_effects', key, f, 'bool', $event.target.checked)" />
							<input v-else class="input num" type="number" step="any"
								:value="fieldVal('status_effects', key, f, STATUS_BASE[key][f])"
								@input="setOverrideField('status_effects', key, f, 'float', $event.target.value)" />
						</label>
					</div>
					<button class="btn ghost sm" style="margin-top:6px" @click="resetOverrideField('status_effects', key, 'icon'); resetOverrideField('status_effects', key, 'color'); statusModFields(key).forEach(f => resetOverrideField('status_effects', key, f))">↩️ Restaurar valores cableados</button>
				</div>

				<h4 class="sec" style="margin-top:16px">🎲 Rareza de botín</h4>
				<div v-for="key in RARITY_KEYS" :key="key" class="card panel" style="margin-bottom:10px; padding:10px 12px; border:1px solid rgba(255,255,255,0.1)">
					<b class="mono">{{ key }}</b>
					<div class="form-grid" style="margin-top:6px">
						<label>Color
							<input class="input" type="color" :value="'#' + fieldVal('loot_rarities', key, 'color', RARITY_BASE[key].color)"
								@input="setOverrideField('loot_rarities', key, 'color', 'color', $event.target.value)" />
						</label>
						<label>Multiplicador
							<input class="input num" type="number" step="0.05"
								:value="fieldVal('loot_rarities', key, 'mult', RARITY_BASE[key].mult)"
								@input="setOverrideField('loot_rarities', key, 'mult', 'float', $event.target.value)" />
						</label>
						<label>Peso (tirada)
							<input class="input num" type="number" step="0.5"
								:value="fieldVal('loot_rarities', key, 'weight', RARITY_BASE[key].weight)"
								@input="setOverrideField('loot_rarities', key, 'weight', 'float', $event.target.value)" />
						</label>
					</div>
					<button class="btn ghost sm" style="margin-top:6px" @click="resetOverrideField('loot_rarities', key, 'color'); resetOverrideField('loot_rarities', key, 'mult'); resetOverrideField('loot_rarities', key, 'weight')">↩️ Restaurar valores cableados</button>
				</div>

				<h4 class="sec" style="margin-top:16px">🏕️ Construcciones del campamento</h4>
				<p class="muted" style="margin:2px 0 8px">Orden de evolución fijo (Hoguera → Muñeco → Cofre → Tablón → Herrería). Solo icono y coste (madera/piedra) son editables aquí.</p>
				<div v-for="key in CAMP_STRUCT_KEYS" :key="key" class="card panel" style="margin-bottom:10px; padding:10px 12px; border:1px solid rgba(255,255,255,0.1)">
					<b>{{ CAMP_STRUCT_BASE[key].label }}</b> <span class="mono muted" style="font-size:11px">{{ key }}</span>
					<div class="form-grid" style="margin-top:6px">
						<label>Icono
							<input class="input f-xs" type="text" :value="fieldVal('camp_structures', key, 'icon', CAMP_STRUCT_BASE[key].icon)"
								@input="setOverrideField('camp_structures', key, 'icon', 'str', $event.target.value)" />
						</label>
						<label>Coste madera
							<input class="input num" type="number" min="0"
								:value="fieldVal('camp_structures', key, 'cost_wood', CAMP_STRUCT_BASE[key].cost_wood)"
								@input="setOverrideField('camp_structures', key, 'cost_wood', 'int', $event.target.value)" />
						</label>
						<label>Coste piedra
							<input class="input num" type="number" min="0"
								:value="fieldVal('camp_structures', key, 'cost_stone', CAMP_STRUCT_BASE[key].cost_stone)"
								@input="setOverrideField('camp_structures', key, 'cost_stone', 'int', $event.target.value)" />
						</label>
					</div>
					<button class="btn ghost sm" style="margin-top:6px" @click="resetOverrideField('camp_structures', key, 'icon'); resetOverrideField('camp_structures', key, 'cost_wood'); resetOverrideField('camp_structures', key, 'cost_stone')">↩️ Restaurar valores cableados</button>
				</div>
			</template>
		</section>
	</div>
	`;
