// components/templates/NpcEditorTemplate.js
// Plantilla (markup Vue) extraída de NpcEditor.js.
// Solo maquetación: NO contiene lógica. La lógica (setup/props/estado) vive en NpcEditor.js.
// Regenerable con: node tools/extract_template.mjs editor/js/components/NpcEditor.js
export default `
	<div class="npc-layout">
		<!-- Lista de NPCs -->
		<div class="col panel pad">
			<div class="col-head">
				<input v-model="search" placeholder="Buscar NPC…" />
				<button class="btn sm primary" @click="showAddNpc=true">+ NPC</button>
			</div>
			<div class="list-sort">
				<label>Orden:</label>
				<select v-model="sortKey">
					<option value="id">ID</option>
					<option value="name">Nombre</option>
					<option value="nodes">Nº nodos</option>
				</select>
			</div>
			<!-- Lista virtualizada para escalar a miles de NPCs sin degradar la UI. -->
			<ds-virtual-list v-if="npcList.length > 80" class="col-body list" :items="npcList" :item-height="46" key-field="id">
				<template #default="{ item: n }">
					<div class="list-row" :class="{ active: store.selectedNpc===n.id }" @click="selectNpc(n.id)">
						<img v-if="n.portrait" :src="n.portrait" class="list-thumb" alt=""
							@error="e => { e.target.style.display='none'; if (e.target.nextElementSibling) e.target.nextElementSibling.style.display='inline-block'; }" />
						<span class="emoji" :style="{ display: n.portrait ? 'none' : 'inline-block' }">{{ n.emoji || '💬' }}</span>
						<span class="meta grow"><div class="t">{{ n.meta || n.id }}</div><div class="s">{{ n.id }}</div></span>
						<span class="type-tag">{{ n.count }}</span>
					</div>
				</template>
			</ds-virtual-list>
			<div v-else class="col-body list">
				<div v-for="n in npcList" :key="n.id" class="list-row" :class="{ active: store.selectedNpc===n.id }" @click="selectNpc(n.id)">
					<img v-if="n.portrait" :src="n.portrait" class="list-thumb" alt=""
						@error="e => { e.target.style.display='none'; if (e.target.nextElementSibling) e.target.nextElementSibling.style.display='inline-block'; }" />
					<span class="emoji" :style="{ display: n.portrait ? 'none' : 'inline-block' }">{{ n.emoji || '💬' }}</span>
					<span class="meta grow"><div class="t">{{ n.meta || n.id }}</div><div class="s">{{ n.id }}</div></span>
					<span class="type-tag">{{ n.count }}</span>
				</div>
				<div v-if="!npcList.length" class="empty">Sin NPCs.</div>
			</div>
		</div>

		<!-- Flujo de nodos -->
		<div class="col">
			<div v-if="!current" class="panel empty" style="margin:0">Selecciona o crea un NPC.</div>
			<div v-else class="editor-scroll">
				<!-- Cabecera premium de dos columnas (ficha del NPC) -->
				<div class="npc-meta-header card panel">
					<div class="meta-inputs">
						<editor-toolbar
							:title="'💬 ' + store.selectedNpc"
							:has-current="!!current"
							:can-paste="canPasteNpc"
							:can-undo="canUndo" :can-redo="canRedo"
							:dirty="Object.keys(store.dirtyNpcs).length > 0"
							:saved-text="autosave.savedAgoText.value"
							:show="{ undo: true, copy: true, paste: true, duplicate: true, remove: true, save: true }"
							@undo="undo()" @redo="redo()"
							@copy="copyNpc" @paste="pasteNpc" @duplicate="duplicateNpc" @remove="deleteNpc" @save="saveNow">
						</editor-toolbar>
						<div class="row-flex">
							<button class="btn sm primary vn-sim-trigger-btn" @click="vnSimOpen=true" title="Simular diálogo completo como Novela Visual">🎬 Probar en Novela Visual</button>
							<button class="btn sm" @click="startSim">🎮 Inspector Rápido</button>
							<button class="btn sm secondary" @click="showAddNode=true">+ Nodo</button>
						</div>
						<div style="margin-top:6px">
							<label style="display:flex; justify-content:space-between">
								<span>Nombre del Personaje [{{ store.currentLang.toUpperCase() }}]</span>
								<span class="muted" style="font-weight:normal; text-transform:none">{{ currentLangBadge }}</span>
							</label>
							<input :value="getI18n(current._meta.text)" :placeholder="getI18nFallback(current._meta.text) || 'Nombre del personaje...'" @input="setText(current._meta, store.currentLang, $event.target.value)" />
						</div>
						<label style="margin-top:10px">Configuración de Recompensas / Fondo (avatar=…; bg=r,g,b)</label>
						<reward-editor :model-value="current._meta.reward || ''" @update:model-value="current._meta.reward=$event; touch()"></reward-editor>
						<div class="muted" style="margin-top:8px">Nodo de entrada: <span class="mono">{{ entryNodeId || '—' }}</span> · {{ nodeEntries.length }} nodos</div>
					</div>

					<div class="meta-preview-card" :style="metaCardStyle">
						<div class="avatar-frame">
							<img v-if="spriteUrl" :src="spriteUrl" class="avatar-img" alt="Avatar" />
							<div v-else-if="isEmojiAvatar" class="avatar-placeholder" style="font-size:36px">{{ currentAvatarName }}</div>
							<div v-else class="avatar-placeholder">👤</div>
						</div>
						<div class="character-info">
							<div class="char-name">{{ current._meta.text.es || store.selectedNpc }}</div>
							<div style="margin-top:6px; width:100%">
								<vn-asset-picker kind="portrait" :model-value="currentAvatarName" @update:model-value="setNpcAvatar($event)" label="Retrato"></vn-asset-picker>
							</div>
							<div v-if="appearingLocations.length" style="margin-top:8px; font-size:11px; width:100%" class="muted">
								<b>📍 Aparece en:</b>
								<div style="display:flex; flex-wrap:wrap; gap:4px; margin-top:2px">
									<span v-for="loc in appearingLocations" :key="loc.id" class="chip" style="font-size:11px; cursor:pointer; background:rgba(255,255,255,0.06); padding:2px 6px; border-radius:4px" @click="store.selectedId=loc.id; store.activeTab='ids'" :title="'Ir a ' + loc.name">
										{{ loc.icon }} {{ loc.name }}
									</span>
								</div>
							</div>
						</div>

						<!-- Simulador de diálogo (Play Mode) con simulación de condiciones/recompensas -->
						<div v-if="simOpen" class="dialogue-simulator">
							<div class="sim-title">
								<span>🎮 {{ current._meta.text.es || store.selectedNpc }}</span>
								<span>
									<button class="btn xs ghost" @click="simShowState=!simShowState" :title="simShowState ? 'Ocultar estado' : 'Mostrar estado'">⚙️</button>
									<button class="btn xs ghost" @click="restartSim" title="Reiniciar simulación y estado">↺</button>
									<button class="btn xs ghost" @click="simLang = simLang==='es'?'en':'es'">{{ simLang.toUpperCase() }}</button>
									<button class="btn xs ghost" @click="stopSim">✕</button>
								</span>
							</div>

							<!-- Estado simulado editable (jugador) -->
							<div v-if="simShowState" class="sim-state">
								<div class="sim-state__row">
									<label>Oro</label><input type="number" v-model.number="simState.gold" />
									<label>Relación</label><input type="number" v-model.number="simState.relation" />
									<label>Visitas</label><input type="number" v-model.number="simState.visits" />
								</div>
								<div class="sim-state__row">
									<label>Quest</label><input class="mono" v-model="simState.quest" placeholder="quest_state" style="flex:1" />
								</div>
								<div class="sim-state__facets">
									<span v-for="f in SIM_FACETS" :key="f" class="sim-facet">
										<label>{{ f }}</label><input type="number" v-model.number="simState.facetas[f]" />
									</span>
								</div>
								<div class="sim-state__chips">
									<span class="sim-chip-label">🚩 Flags:</span>
									<button v-for="f in simFlags" :key="f" class="chip xs" @click="simToggleFlag(f)" title="Quitar">{{ f }} ✕</button>
									<button class="btn xs ghost" @click="simAddFlag">+ flag</button>
								</div>
								<div class="sim-state__chips">
									<span class="sim-chip-label">🎒 Ítems:</span>
									<button v-for="it in simItems" :key="it.id" class="chip xs" @click="simRemoveItem(it.id)" title="Quitar">{{ it.id }}×{{ it.n }} ✕</button>
									<button class="btn xs ghost" @click="simAddItem">+ ítem</button>
								</div>
							</div>

							<div v-if="simNode" class="sim-text">{{ simText(simNode) }}</div>
							<div v-else class="sim-text muted">Fin de la conversación.</div>
							<div v-if="simNode && simReward(simNode)" class="sim-reward">🎁 {{ simReward(simNode) }}</div>

							<div class="sim-options">
								<button v-for="o in simOptions" :key="o.id" class="btn sm sim-opt" :class="'cond-'+o.status" @click="simChoose(o.id)">
									<span>▸ {{ simText(o.node) }}</span>
									<span v-if="o.cond" class="sim-opt__cond" :title="o.cond">{{ condLabel(o.status) }}</span>
								</button>
								<button v-if="simContinue && simContinue!=='close'" class="btn sm primary" @click="simChoose(simContinue)">Continuar ▸</button>
								<button v-if="simContinue==='close' || (!simOptions.length && !simContinue)" class="btn sm ghost" @click="stopSim">Cerrar diálogo</button>
							</div>

							<!-- Registro de efectos de recompensa aplicados -->
							<div v-if="simLog.length" class="sim-logbox">
								<div class="sim-logbox__title">Efectos aplicados</div>
								<div v-for="(entry, i) in simLog" :key="i" class="sim-log-entry">
									<span class="mono sim-log-node">{{ entry.node }}{{ entry.entry ? ' (entrada)' : '' }}</span>
									<span v-for="(e, j) in entry.effects" :key="j" class="sim-log-eff">{{ e.icon }} {{ e.text }}</span>
								</div>
							</div>
						</div>
					</div>
				</div>

				<!-- Selector de vista del flujo -->
				<div class="flow-toolbar">
					<div class="seg">
						<button class="btn sm" :class="{ primary: flowMode==='script' }" @click="flowMode='script'">💬 Guión Visual</button>
						<button class="btn sm" :class="{ primary: flowMode==='tree' }" @click="flowMode='tree'">🌳 Árbol</button>
						<button class="btn sm" :class="{ primary: flowMode==='list' }" @click="flowMode='list'">📃 Lista</button>
						<button class="btn sm" :class="{ primary: flowMode==='graph' }" @click="flowMode='graph'">🕸️ Grafo</button>
					</div>
					<span class="muted">Los enlaces "close" cierran el diálogo.</span>
				</div>

				<!-- Vista GUIÓN VISUAL (100% Clics & Escritura) -->
				<div v-if="flowMode==='script'" class="script-flow-container" style="padding:10px 0">
					<div v-for="(row, i) in flowTree" :key="'script-'+row.id+'-'+i" class="script-step-row"
						:style="{ marginLeft: Math.min(row.depth * 28, 140) + 'px', marginBottom:'14px' }">

						<!-- Mensaje del Personaje / NPC -->
						<div v-if="(current[row.id]||{}).type==='message'" class="script-card script-card--message card panel"
							:class="{ 'is-entry': row.id===entryNodeId, flash: flashNode===row.id }" :id="'node-'+row.id"
							style="border-left:4px solid #3b82f6; background:rgba(15,23,42,0.85); padding:14px; border-radius:10px">
							<div class="script-card__header flex" style="justify-content:space-between; align-items:center; margin-bottom:8px">
								<div class="flex" style="align-items:center; gap:8px">
									<span style="font-size:20px">👤</span>
									<b style="color:var(--txt-0)">{{ current._meta?.text?.es || store.selectedNpc }}</b>
									<span class="chip mono xs">{{ row.id }}</span>
									<span v-if="row.id===entryNodeId" class="chip ok xs">🚩 Inicio</span>
									<span v-if="row.orphan" class="chip pill-warn xs">Huérfano</span>
								</div>
								<div class="flex" style="gap:4px">
									<button class="btn xs ghost" @click="gotoNode(row.id)">#</button>
									<button class="btn xs danger" @click="deleteNode(row.id)">🗑️</button>
								</div>
							</div>

							<!-- Caja de texto dinámica por idioma activo -->
							<div style="margin-top:8px">
								<label style="font-size:11px; display:flex; justify-content:space-between">
									<span>Texto del Personaje [{{ store.currentLang.toUpperCase() }}]</span>
									<span class="muted" style="text-transform:none">{{ currentLangBadge }}</span>
								</label>
								<textarea class="input script-textarea" :placeholder="getI18nFallback(current[row.id].text) || 'Escribe lo que dice el personaje…'" rows="3"
									:value="getI18n(current[row.id].text)" @input="setText(current[row.id], store.currentLang, $event.target.value)"></textarea>
							</div>

							<!-- Condición opcional -->
							<div v-if="current[row.id].condition !== undefined" style="margin-top:8px">
								<label style="font-size:11px">🔒 Requisito para decir esta frase</label>
								<condition-editor :model-value="current[row.id].condition || ''" @update:model-value="setCondition(current[row.id], $event)"></condition-editor>
							</div>

							<!-- Recompensa opcional -->
							<div v-if="current[row.id].reward" style="margin-top:8px">
								<label style="font-size:11px">🎁 Recompensas / Efectos</label>
								<reward-editor :model-value="current[row.id].reward || ''" @update:model-value="setReward(current[row.id], $event)"></reward-editor>
							</div>

							<!-- Barra de acciones 1-clic -->
							<div class="script-card__actions flex" style="gap:8px; margin-top:10px; flex-wrap:wrap; align-items:center">
								<button class="btn xs primary" @click="appendNextMessage(row.id)" title="Añade la siguiente frase del personaje">
									➕ Siguiente Frase
								</button>
								<button class="btn xs secondary" @click="appendChoices(row.id)" title="Añade opciones para que el jugador elija">
									🔀 Añadir Elección del Jugador
								</button>
								<span class="grow"></span>
								<button v-if="current[row.id].condition === undefined" class="btn xs ghost" @click="setCondition(current[row.id], '')">
									+ 🔒 Condición
								</button>
								<button v-if="!current[row.id].reward" class="btn xs ghost" @click="setReward(current[row.id], 'gold:10')">
									+ 🎁 Recompensa
								</button>
							</div>
						</div>

						<!-- Opción de Respuesta del Jugador -->
						<div v-else-if="(current[row.id]||{}).type==='option'" class="script-card script-card--option card panel"
							:class="{ flash: flashNode===row.id }" :id="'node-'+row.id"
							style="border-left:4px solid #38bdf8; background:rgba(15,23,42,0.7); padding:12px; border-radius:10px">
							<div class="script-card__header flex" style="justify-content:space-between; align-items:center; margin-bottom:6px">
								<div class="flex" style="align-items:center; gap:8px">
									<span>💬</span>
									<b style="color:#38bdf8">Elección del Jugador</b>
									<span class="chip mono xs">{{ row.id }}</span>
								</div>
								<div class="flex" style="gap:4px">
									<button class="btn xs danger" @click="deleteNode(row.id)">🗑️</button>
								</div>
							</div>

							<!-- Texto de la opción dinámico por idioma activo -->
							<div style="margin-top:6px">
								<label style="font-size:11px; display:flex; justify-content:space-between">
									<span>Texto de la Opción [{{ store.currentLang.toUpperCase() }}]</span>
									<span class="muted" style="text-transform:none">{{ currentLangBadge }}</span>
								</label>
								<input class="input" :placeholder="getI18nFallback(current[row.id].text) || 'Lo que responde el jugador…'"
									:value="getI18n(current[row.id].text)" @input="setText(current[row.id], store.currentLang, $event.target.value)" />
							</div>

							<!-- Condición y recompensa de la opción -->
							<div v-if="current[row.id].condition !== undefined" style="margin-top:8px">
								<label style="font-size:11px">🔒 Requisito para ver esta opción</label>
								<condition-editor :model-value="current[row.id].condition || ''" @update:model-value="setCondition(current[row.id], $event)"></condition-editor>
							</div>

							<div v-if="current[row.id].reward" style="margin-top:8px">
								<label style="font-size:11px">🎁 Recompensa al elegir</label>
								<reward-editor :model-value="current[row.id].reward || ''" @update:model-value="setReward(current[row.id], $event)"></reward-editor>
							</div>

							<!-- Destino de la opción -->
							<div class="flex" style="gap:6px; margin-top:8px; align-items:center; flex-wrap:wrap">
								<span class="muted" style="font-size:11px">Destino:</span>
								<button class="btn xs" :class="{ primary: current[row.id].next?.[0]==='close' }" @click="setSemanticDest(current[row.id], 'close')">
									✕ Cierra conversación
								</button>
								<button class="btn xs" :class="{ primary: current[row.id].next?.[0]===entryNodeId }" @click="setSemanticDest(current[row.id], 'menu')">
									↺ Vuelve al inicio
								</button>
								<button v-if="!current[row.id].next?.length || (current[row.id].next[0]!=='close' && current[row.id].next[0]!==entryNodeId)"
									class="btn xs primary" @click="appendNextMessage(row.id)">
									➕ Respuesta del Personaje
								</button>
								<span class="grow"></span>
								<button v-if="current[row.id].condition === undefined" class="btn xs ghost" @click="setCondition(current[row.id], '')">
									+ 🔒 Condición
								</button>
								<button v-if="!current[row.id].reward" class="btn xs ghost" @click="setReward(current[row.id], 'rel:1')">
									+ ❤️ Afinidad / Objeto
								</button>
							</div>
						</div>
					</div>

					<!-- Botón al pie del guión si no hay nodos -->
					<div v-if="!flowTree.length" class="empty" style="padding:30px; text-align:center">
						<h3>💬 Conversación vacía</h3>
						<p class="muted">Crea el saludo o primer mensaje del personaje para comenzar.</p>
						<button class="btn primary" @click="appendNextMessage(null)">➕ Crear Primer Mensaje</button>
					</div>
				</div>

				<!-- Vista GRAFO: canvas interactivo (Tarea 1) -->
				<npc-graph-editor v-if="flowMode==='graph'"
					:npc-id="store.selectedNpc"
					:npc-data="current"
					:entry-node-id="entryNodeId"
					:next-options="nextOptions"
					:condition-snippets="CONDITION_SNIPPETS"
					@node-updated="onGraphNodeUpdated"
					@node-added="onGraphNodeAdded"
					@node-deleted="onGraphNodeDeleted"></npc-graph-editor>

				<!-- Vista ÁRBOL: filas jerárquicas con colapso y control de ciclos -->
				<div v-if="flowMode==='tree'" class="node-flow tree">
					<template v-for="(row, i) in flowTree" :key="row.id + '-' + i">
						<!-- Retorno a nodo ya visitado (ciclo) -->
						<div v-if="row.loop" class="loop-ref" :style="{ marginLeft: (row.depth*22)+'px' }">
							↩ Retorna a <span class="mono">{{ row.id }}</span>
							<button class="btn xs ghost" @click="gotoNode(row.id)">↳ ir</button>
						</div>
						<!-- Nodo normal (oculto si un ancestro está colapsado) -->
						<div v-else-if="!rowHidden(flowTree, i)" :id="'node-'+row.id"
							class="node" :class="['type-'+((current[row.id]||{}).type||'message'), { flash: flashNode===row.id, dup: row.dup, orphan: row.orphan }]"
							:style="{ marginLeft: (row.depth*22)+'px' }">
							<div class="node-head">
								<button class="btn xs ghost collapse" @click="toggleCollapse(row.id)" :title="collapsed[row.id]?'Expandir':'Colapsar'">{{ collapsed[row.id] ? '＋' : '－' }}</button>
								<span class="node-id">{{ row.id }}</span>
								<span v-if="row.id===entryNodeId" class="chip">entrada</span>
								<span v-if="row.dup" class="chip">↺ visitado</span>
								<span v-if="row.orphan" class="chip pill-warn">huérfano</span>
								<select :value="(current[row.id]||{}).type" @change="setType(current[row.id],$event.target.value)" style="width:auto">
									<option value="message">message</option>
									<option value="option">option</option>
								</select>
								<span class="spacer"></span>
								<button class="btn sm danger" @click="deleteNode(row.id)">✕</button>
							</div>
							<template v-if="!collapsed[row.id]">
								<div style="margin-top:6px">
									<label>Texto [{{ store.currentLang.toUpperCase() }}]</label>
									<textarea :value="getI18n(current[row.id].text)" :placeholder="getI18nFallback(current[row.id].text) || 'Texto del nodo…'" @input="setText(current[row.id], store.currentLang, $event.target.value)" rows="3"></textarea>
								</div>
								<label>Condición (Godot Expression, vacío = siempre)</label>
								<input :value="current[row.id].condition || ''" @input="setCondition(current[row.id],$event.target.value)" class="mono" placeholder='p.ej. has_flag("regular") and encanto >= 2' />
								<div class="flex" style="flex-wrap:wrap; gap:4px; margin-top:5px">
									<button v-for="s in CONDITION_SNIPPETS" :key="s" class="chip" style="cursor:pointer" @click="appendSnippet(current[row.id],s)">+ {{ s }}</button>
								</div>
								<label style="margin-top:12px">Recompensas / acciones</label>
								<reward-editor :model-value="current[row.id].reward || ''" @update:model-value="setReward(current[row.id],$event)"></reward-editor>
								<label style="margin-top:12px">Enlaces (next)</label>
								<div class="next-list">
									<div v-for="(nx, idx) in (current[row.id].next || [])" :key="idx" class="next-row">
										<select :value="nx" @change="setNext(current[row.id],idx,$event.target.value)" :class="{ 'is-broken': nextBroken(nx) }">
											<option value="close">🚪 close (cerrar)</option>
											<option v-if="nextBroken(nx)" :value="nx">⚠️ {{ nx }} (inexistente)</option>
											<option v-for="opt in nextOptions" :key="opt" :value="opt">{{ opt }}</option>
										</select>
										<button class="btn sm ghost" @click="gotoNode(nx)" :disabled="nx==='close'" title="Ir al nodo">↳</button>
										<button class="btn sm danger" @click="removeNext(current[row.id],idx)">✕</button>
									</div>
									<button class="btn sm ghost" @click="addNext(current[row.id],'close')" style="align-self:flex-start">+ Enlace</button>
								</div>
								<div v-if="isDeadEnd(current[row.id])" class="chip pill-err dot" style="margin-top:8px">Nodo sin salida: congelaría el diálogo</div>
							</template>
						</div>
					</template>
				</div>

				<!-- Vista LISTA: bloques planos (todos los nodos) -->
				<div v-else-if="flowMode==='list'" class="node-flow">
					<div v-for="{ id, node } in nodeEntries" :key="id" :id="'node-'+id"
						class="node" :class="['type-'+(node.type||'message'), { flash: flashNode===id }]">
						<div class="node-head">
							<span class="node-id">{{ id }}</span>
							<span v-if="id===entryNodeId" class="chip">entrada</span>
							<select :value="node.type" @change="setType(node,$event.target.value)" style="width:auto">
								<option value="message">message</option>
								<option value="option">option</option>
							</select>
							<span class="spacer"></span>
							<button class="btn sm danger" @click="deleteNode(id)">✕</button>
						</div>
						<div style="margin-top:6px">
							<label>Texto [{{ store.currentLang.toUpperCase() }}]</label>
							<textarea :value="getI18n(node.text)" :placeholder="getI18nFallback(node.text) || 'Texto del nodo…'" @input="setText(node, store.currentLang, $event.target.value)" rows="3"></textarea>
						</div>
						<label>Condición (Godot Expression, vacío = siempre)</label>
						<input :value="node.condition || ''" @input="setCondition(node,$event.target.value)" class="mono" placeholder='p.ej. has_flag("regular") and encanto >= 2' />
						<div class="flex" style="flex-wrap:wrap; gap:4px; margin-top:5px">
							<button v-for="s in CONDITION_SNIPPETS" :key="s" class="chip" style="cursor:pointer" @click="appendSnippet(node,s)">+ {{ s }}</button>
						</div>
						<label style="margin-top:12px">Recompensas / acciones</label>
						<reward-editor :model-value="node.reward || ''" @update:model-value="setReward(node,$event)"></reward-editor>
						<label style="margin-top:12px">Enlaces (next)</label>
						<div class="next-list">
							<div v-for="(nx, idx) in (node.next || [])" :key="idx" class="next-row">
								<select :value="nx" @change="setNext(node,idx,$event.target.value)" :class="{ 'is-broken': nextBroken(nx) }">
									<option value="close">🚪 close (cerrar)</option>
									<option v-if="nextBroken(nx)" :value="nx">⚠️ {{ nx }} (inexistente)</option>
									<option v-for="opt in nextOptions" :key="opt" :value="opt">{{ opt }}</option>
								</select>
								<button class="btn sm ghost" @click="gotoNode(nx)" :disabled="nx==='close'" title="Ir al nodo">↳</button>
								<button class="btn sm danger" @click="removeNext(node,idx)">✕</button>
							</div>
							<button class="btn sm ghost" @click="addNext(node,'close')" style="align-self:flex-start">+ Enlace</button>
						</div>
						<div v-if="isDeadEnd(node)" class="chip pill-err dot" style="margin-top:8px">Nodo sin salida: congelaría el diálogo</div>
					</div>
				</div>
			</div>
		</div>

		<!-- Modal: nuevo nodo -->
		<div v-if="showAddNode" class="modal-back" @click.self="showAddNode=false">
			<div class="modal">
				<h3>Nuevo nodo</h3>
				<label>ID del nodo</label>
				<input v-model="newNodeId" :placeholder="(store.selectedNpc||'')+'_X'" @keyup.enter="addNode" />
				<label>Tipo</label>
				<select v-model="newNodeType"><option value="message">message</option><option value="option">option</option></select>
				<div class="row">
					<button class="btn ghost" @click="showAddNode=false">Cancelar</button>
					<button class="btn primary" @click="addNode">Crear</button>
				</div>
			</div>
		</div>

		<!-- Modal: nuevo NPC -->
		<div v-if="showAddNpc" class="modal-back" @click.self="showAddNpc=false">
			<div class="modal">
				<h3>Nuevo NPC</h3>
				<label>ID del NPC</label>
				<input v-model="newNpcId" placeholder="p.ej. villager_bob" @keyup.enter="addNpc" />
				<div class="row">
					<button class="btn ghost" @click="showAddNpc=false">Cancelar</button>
					<button class="btn primary" @click="addNpc">Crear</button>
				</div>
			</div>
		</div>

		<!-- MODAL DE SIMULACIÓN VISUAL NOVEL EN VIVO -->
		<vn-simulator-modal v-if="current && npcSceneData" :open="vnSimOpen" :scene="npcSceneData" :scene-id="store.selectedNpc"
			default-bg="bg_building_tavern.jpg" default-music="bgm_city.ogg"
			@close="vnSimOpen=false"></vn-simulator-modal>
	</div>
	`;
