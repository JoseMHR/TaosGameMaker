// components/templates/ScenesManagerTemplate.js
// Plantilla (markup Vue) extraída de ScenesManager.js.
// Solo maquetación: NO contiene lógica. La lógica (setup/props/estado) vive en ScenesManager.js.
// Regenerable con: node tools/extract_template.mjs editor/js/components/ScenesManager.js
export default `
	<div class="manager scenes-manager">
		<entity-list-panel :c="col" search-placeholder="Buscar escena…" new-label="➕ Nueva escena">
			<template #row="{ id, o }">
				<span class="ent-icon">🎭</span>
				<span class="ent-name">{{ (o && o.meta && o.meta.title && o.meta.title.es) || id }}</span>
				<span class="ent-id mono">{{ Object.keys((o && o.nodes) || {}).length }} nodos</span>
			</template>
		</entity-list-panel>

		<section class="editor-pane" v-if="current">
			<div class="row gap" style="align-items:center; justify-content:space-between; margin-bottom:8px">
				<editor-toolbar :can-undo="col.canUndo.value" :can-redo="col.canRedo.value"
					:can-paste="col.canPaste.value" :has-current="!!current" :dirty="col.dirty.value"
					:saved-text="col.savedText.value"
					@undo="col.undo()" @redo="col.redo()" @copy="col.copy()" @paste="col.paste()"
					@duplicate="col.duplicate()" @remove="col.remove()" @save="col.doSave()"></editor-toolbar>
				<button class="btn primary sm vn-sim-trigger-btn" @click="simOpen=true" title="Simular la escena completa con gráficos y audio">🎬 Probar Escena en Vivo</button>
			</div>

			<h3 class="sec">🎭 Escena</h3>
			<div class="form-grid">
				<label>ID
					<input class="input mono" type="text" :value="col.selectedId.value" @change="col.rename($event.target.value)" />
				</label>
				<label>Nodo de entrada
					<select class="input" :value="current.entry" @change="setEntry($event.target.value)">
						<option v-for="nid in nodeIds" :key="nid" :value="nid">{{ nid }}</option>
					</select>
				</label>
				<label>Título [{{ store.currentLang.toUpperCase() }}]
					<input class="input" type="text" :value="getI18n(current.meta && current.meta.title)" :placeholder="getI18nFallback(current.meta && current.meta.title) || 'Título de la escena...'" @input="setMeta('title.' + store.currentLang, $event.target.value)" />
				</label>
				<label>Fondo de Escenario (VN)
					<vn-asset-picker kind="bg" :model-value="current.bg || 'bg_city_celestia_archmage.png'" @update:model-value="current.bg=$event"></vn-asset-picker>
				</label>
				<label>Música de Fondo (BGM)
					<vn-asset-picker kind="audio" :model-value="current.music || 'bgm_city.ogg'" @update:model-value="current.music=$event"></vn-asset-picker>
				</label>
				<label class="full">Descripción (interna)
					<input class="input" type="text" :value="current.meta && current.meta.desc" @input="setMeta('desc', $event.target.value)" />
				</label>
			</div>

			<div class="scenes-graph" style="display:flex; gap:16px; margin-top:14px; align-items:flex-start">
				<!-- Lista de nodos -->
				<div class="scenes-nodes" style="flex:0 0 300px">
					<div class="pane-header">
						<h3 class="sec">🧩 Nodos ({{ nodeIds.length }})</h3>
						<button class="btn secondary sm" @click="addNode">➕ Nodo</button>
					</div>
					<div class="node-list" style="display:flex; flex-direction:column; gap:6px; margin-top:8px">
						<div v-for="nid in nodeIds" :key="nid"
							class="node-row" :class="{ active: store.selectedSceneNode === nid }"
							@click="selectNode(nid)"
							style="padding:8px 10px; border-radius:8px; cursor:pointer; border:1px solid rgba(255,255,255,0.08)"
							:style="store.selectedSceneNode === nid ? 'background:rgba(245,158,11,0.15); border-color:rgba(245,158,11,0.5)' : ''">
							<div class="flex" style="justify-content:space-between; align-items:center; gap:6px">
								<span><b class="mono">{{ nid }}</b> <span v-if="nid===current.entry" title="Entrada">▶</span></span>
								<span>{{ nodeKindMeta((current.nodes[nid]||{}).kind).icon }}</span>
							</div>
							<div class="muted" style="font-size:12px; margin-top:2px; overflow:hidden; text-overflow:ellipsis; white-space:nowrap">{{ nodeSummary(current.nodes[nid]) }}</div>
						</div>
					</div>
				</div>

				<!-- Inspector del nodo -->
				<div class="scenes-inspector" style="flex:1 1 auto" v-if="selNode">
					<div class="pane-header">
						<h3 class="sec">{{ nodeKindMeta(selNode.kind).icon }} Nodo</h3>
						<button class="btn sm err" @click="removeNode(store.selectedSceneNode)">🗑️ Eliminar</button>
					</div>
					<div class="form-grid">
						<label>ID del nodo
							<input class="input mono" type="text" :value="store.selectedSceneNode" @change="renameNode(store.selectedSceneNode, $event.target.value)" />
						</label>
						<label>Tipo
							<select class="input" :value="selNode.kind" @change="setKind(store.selectedSceneNode, $event.target.value)">
								<option v-for="k in NODE_KINDS" :key="k.kind" :value="k.kind">{{ k.icon }} {{ k.label }}</option>
							</select>
						</label>
					</div>

					<!-- SAY -->
					<template v-if="selNode.kind === 'say'">
						<div class="form-grid" style="margin-top:10px">
							<label>Hablante [{{ store.currentLang.toUpperCase() }}] <input class="input" :value="getI18n(selNode.speaker)" :placeholder="getI18nFallback(selNode.speaker) || 'Hablante...'" @input="setNodeField('speaker.' + store.currentLang, $event.target.value)" /></label>
							<label>Retrato (Personaje / Emoji)
								<vn-asset-picker kind="portrait" :model-value="selNode.portrait" @update:model-value="setNodeField('portrait', $event)"></vn-asset-picker>
							</label>
							<label>Estilo
								<select class="input" :value="selNode.style || 'box'" @change="setNodeField('style', $event.target.value)">
									<option value="box">Panel inferior (JRPG)</option>
									<option value="banner">Banner centrado (cinemática)</option>
								</select>
							</label>
							<div class="full">
								<label>Texto [{{ store.currentLang.toUpperCase() }}] <textarea class="input" :value="getI18n(selNode.text)" :placeholder="getI18nFallback(selNode.text) || 'Texto del diálogo...'" @input="setNodeField('text.' + store.currentLang, $event.target.value)" rows="3"></textarea></label>
							</div>
							<label>Auto-avance (s, 0 = manual) <input class="input num" type="number" step="0.1" :value="selNode.auto || 0" @input="setNodeField('auto', Number($event.target.value))" /></label>
							<label>Siguiente nodo
								<select class="input" :value="selNode.next || 'end'" @change="setNodeField('next', $event.target.value)">
									<option v-for="t in targetOptions" :key="t" :value="t">{{ t }}</option>
								</select>
							</label>
						</div>
						<div v-if="store.expertMode" class="fx-row" style="margin-top:8px; padding:10px; border:1px dashed rgba(255,255,255,0.15); border-radius:8px">
							<b class="muted">✨ Efectos expresivos <span style="font-weight:400">(fx, experto)</span></b>
							<div class="form-grid" style="margin-top:6px">
								<label>Velocidad texto <input class="input num" type="number" step="0.1" :value="selNode.fx && selNode.fx.speed" @input="setFx('speed', $event.target.value)" /></label>
								<label>Zoom <input class="input num" type="number" step="0.05" :value="selNode.fx && selNode.fx.zoom" @input="setFx('zoom', $event.target.value)" /></label>
								<label>Shake <input class="input num" type="number" step="0.1" :value="selNode.fx && selNode.fx.shake" @input="setFx('shake', $event.target.value)" /></label>
								<label>Glow <input class="input num" type="number" step="0.1" :value="selNode.fx && selNode.fx.glow" @input="setFx('glow', $event.target.value)" /></label>
								<label>Oscurecer <input class="input num" type="number" step="0.1" :value="selNode.fx && selNode.fx.darken" @input="setFx('darken', $event.target.value)" /></label>
							</div>
							<div class="row gap" style="margin-top:6px; align-items:center">
								<label class="full" style="flex:1">SFX (id de sonido) <input class="input mono" :value="selNode.fx && selNode.fx.sfx" @input="setNodeField('fx.sfx', $event.target.value)" placeholder="click / hit / ..." /></label>
								<ds-audio-btn v-if="selNode.fx && selNode.fx.sfx" :src="'/assets/common/sfx/' + selNode.fx.sfx + '.ogg'" size="sm"></ds-audio-btn>
							</div>
						</div>
					</template>

					<!-- CHOICE -->
					<template v-else-if="selNode.kind === 'choice'">
						<div class="form-grid" style="margin-top:10px">
							<label class="full">Enunciado [{{ store.currentLang.toUpperCase() }}] (opcional) <input class="input" :value="getI18n(selNode.prompt)" :placeholder="getI18nFallback(selNode.prompt) || 'Pregunta o aviso...'" @input="setNodeField('prompt.' + store.currentLang, $event.target.value)" /></label>
						</div>
						<div class="pane-header" style="margin-top:8px">
							<b class="muted">🔀 Opciones ({{ (selNode.options||[]).length }})</b>
							<button class="btn sm secondary" @click="addOption">➕ Opción</button>
						</div>
						<div v-for="(op, idx) in (selNode.options||[])" :key="idx" class="card panel" style="padding:10px; margin-top:8px; border:1px solid rgba(255,255,255,0.1)">
							<div class="flex" style="justify-content:space-between"><b class="mono">Opción #{{ idx+1 }}</b><button class="btn sm err" @click="removeOption(idx)">🗑️</button></div>
							<div class="form-grid" style="margin-top:6px">
								<div class="full">
									<label>Texto [{{ store.currentLang.toUpperCase() }}] <input class="input" :value="getI18n(op.text)" :placeholder="getI18nFallback(op.text) || 'Texto de la opción...'" @input="setOption(idx, 'text.' + store.currentLang, $event.target.value)" /></label>
								</div>
								<label class="full">Condición (opcional) <input class="input mono" :value="op.condition" @input="setOption(idx, 'condition', $event.target.value)" placeholder="gold > 0 / has_item(&quot;x&quot;)" /></label>
								<label>Ir a
									<select class="input" :value="op.to" @change="setOption(idx, 'to', $event.target.value)">
										<option v-for="t in targetOptions" :key="t" :value="t">{{ t }}</option>
									</select>
								</label>
							</div>
						</div>
					</template>

					<!-- STATE -->
					<template v-else-if="selNode.kind === 'state'">
						<div class="form-grid" style="margin-top:10px">
							<label class="full">Operaciones (mini-lenguaje, separadas por ;) <input class="input mono" :value="selNode.ops" @input="setNodeField('ops', $event.target.value)" placeholder="item:banana=1;faceta:amabilidad=+1;xp:10" /></label>
							<label>Siguiente nodo
								<select class="input" :value="selNode.next || 'end'" @change="setNodeField('next', $event.target.value)">
									<option v-for="t in targetOptions" :key="t" :value="t">{{ t }}</option>
								</select>
							</label>
						</div>
					</template>

					<!-- EVENT -->
					<template v-else-if="selNode.kind === 'event'">
						<div class="form-grid" style="margin-top:10px">
							<label class="full">Evento a emitir <input class="input mono" :value="selNode.emit" @input="setNodeField('emit', $event.target.value)" placeholder="EVENT_DAM_OPENED" /></label>
							<label>Siguiente nodo
								<select class="input" :value="selNode.next || 'end'" @change="setNodeField('next', $event.target.value)">
									<option v-for="t in targetOptions" :key="t" :value="t">{{ t }}</option>
								</select>
							</label>
						</div>
						<p class="muted" style="margin-top:6px">El Sistema Narrativo solo emite el evento; otros sistemas (Mapamundi, Combate...) deciden si reaccionan.</p>
					</template>

					<!-- FLOW -->
					<template v-else-if="selNode.kind === 'flow'">
						<div class="form-grid" style="margin-top:10px">
							<label>Operación
								<select class="input" :value="selNode.op || 'goto'" @change="setNodeField('op', $event.target.value)">
									<option v-for="op in FLOW_OPS" :key="op" :value="op">{{ op }}</option>
								</select>
							</label>
							<label v-if="selNode.op === 'goto'">Ir a
								<select class="input" :value="selNode.to" @change="setNodeField('to', $event.target.value)">
									<option v-for="t in targetOptions" :key="t" :value="t">{{ t }}</option>
								</select>
							</label>
							<template v-else-if="selNode.op === 'call'">
								<label>Subescena
									<select class="input" :value="selNode.scene" @change="setNodeField('scene', $event.target.value)">
										<option v-for="s in sceneIds" :key="s" :value="s">{{ s }}</option>
									</select>
								</label>
								<label>Al volver, ir a
									<select class="input" :value="selNode.next || 'end'" @change="setNodeField('next', $event.target.value)">
										<option v-for="t in targetOptions" :key="t" :value="t">{{ t }}</option>
									</select>
								</label>
							</template>
							<label v-else-if="selNode.op === 'wait'">Duración (s) <input class="input num" type="number" step="0.1" :value="selNode.dur" @input="setNodeField('dur', Number($event.target.value))" /></label>
						</div>
						<template v-if="selNode.op === 'branch'">
							<div class="pane-header" style="margin-top:8px">
								<b class="muted">🔁 Ramas condicionales</b>
								<button class="btn sm secondary" @click="addBranch">➕ Rama</button>
							</div>
							<div v-for="(b, idx) in (selNode.branches||[])" :key="idx" class="card panel" style="padding:10px; margin-top:8px; border:1px solid rgba(255,255,255,0.1)">
								<div class="flex" style="justify-content:space-between"><b class="mono">Rama #{{ idx+1 }}</b><button class="btn sm err" @click="removeBranch(idx)">🗑️</button></div>
								<div class="form-grid" style="margin-top:6px">
									<label class="full">Si (condición) <input class="input mono" :value="b.condition" @input="setBranch(idx, 'condition', $event.target.value)" placeholder="gflag(&quot;dam_opened&quot;)" /></label>
									<label>Ir a
										<select class="input" :value="b.to" @change="setBranch(idx, 'to', $event.target.value)">
											<option v-for="t in targetOptions" :key="t" :value="t">{{ t }}</option>
										</select>
									</label>
								</div>
							</div>
							<label class="full" style="margin-top:8px">Si ninguna (else) → ir a
								<select class="input" :value="selNode.else || 'end'" @change="setNodeField('else', $event.target.value)">
									<option v-for="t in targetOptions" :key="t" :value="t">{{ t }}</option>
								</select>
							</label>
						</template>
					</template>
				</div>
				<div class="scenes-inspector" style="flex:1 1 auto" v-else>
					<p class="muted">Selecciona un nodo para editarlo, o crea uno nuevo.</p>
				</div>
			</div>
		</section>

		<section class="editor-pane empty" v-else>
			<p class="muted">Selecciona o crea una escena del Sistema Narrativo.</p>
		</section>

		<!-- MODAL DE SIMULACIÓN VISUAL NOVEL EN VIVO -->
		<vn-simulator-modal v-if="current" :open="simOpen" :scene="current" :scene-id="col.selectedId.value"
			:default-bg="(current && current.bg) || 'bg_city_celestia_archmage.png'"
			:default-music="(current && current.music) || 'bgm_city.ogg'"
			@close="simOpen=false"></vn-simulator-modal>
	</div>
	`;
