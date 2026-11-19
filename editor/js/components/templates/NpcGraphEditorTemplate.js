// components/templates/NpcGraphEditorTemplate.js
// Plantilla (markup Vue) extraída de NpcGraphEditor.js.
// Solo maquetación: NO contiene lógica. La lógica (setup/props/estado) vive en NpcGraphEditor.js.
// Regenerable con: node tools/extract_template.mjs editor/js/components/NpcGraphEditor.js
export default `
	<div class="graph-wrapper">
		<!-- Barra de herramientas -->
		<div class="graph-toolbar">
			<div class="seg">
				<button class="btn sm ghost" @click="doUndo" :disabled="!canUndo" title="Deshacer (Ctrl+Z)">↶</button>
				<button class="btn sm ghost" @click="doRedo" :disabled="!canRedo" title="Rehacer (Ctrl+Y)">↷</button>
			</div>
			<div class="seg">
				<button class="btn sm ghost" @click="doDuplicate" :disabled="!selectionCount" title="Duplicar (Ctrl+D)">⧉</button>
				<button class="btn sm ghost danger" @click="doDeleteSelected" :disabled="!selectionCount" title="Eliminar (Supr)">🗑</button>
			</div>
			<input class="graph-search" v-model="searchQuery" @keyup.enter="onSearchEnter" placeholder="🔍 Buscar en el grafo…" />
			<div class="bm-menu">
				<button class="btn sm ghost" :class="{ primary: showBookmarks }" @click="showBookmarks=!showBookmarks" :title="'Marcadores (' + bookmarkList.length + ')'">🔖 {{ bookmarkList.length }}</button>
				<div v-if="showBookmarks" class="bm-dropdown">
					<div v-if="!bookmarkList.length" class="bm-empty">Sin marcadores. Marca nodos desde su panel de edición.</div>
					<button v-for="id in bookmarkList" :key="id" class="bm-item mono" @click="jumpBookmark(id)">🔖 {{ id }}</button>
				</div>
			</div>
			<span class="spacer"></span>
			<span v-if="selectionCount" class="chip">{{ selectionCount }} sel.</span>
			<button class="btn sm ghost" @click="fitView" title="Centrar (zoom-to-fit)">⊙ Centrar</button>
			<div class="seg">
				<button class="btn sm ghost" @click="zoomButton(-1)" title="Alejar">−</button>
				<span class="zoom-lbl mono">{{ zoomPct }}%</span>
				<button class="btn sm ghost" @click="zoomButton(1)" title="Acercar">+</button>
			</div>
		</div>

		<!-- Canvas + minimapa + drawer -->
		<div class="graph-canvas-container">
			<canvas ref="canvasRef" class="graph-canvas"
				@mousedown="onMouseDown" @wheel.prevent="onWheel" @dblclick="onDblClick" @contextmenu="onContextMenu"></canvas>
			<canvas ref="minimapRef" class="graph-minimap" width="180" height="120"
				@mousedown.stop.prevent="onMinimapDown"></canvas>
			<span class="graph-autosave">{{ savedText }}</span>

			<!-- Drawer lateral de edición del nodo -->
			<div class="graph-drawer" :class="{ open: !!drawerNodeId }">
				<template v-if="dNode">
					<div class="row-flex">
						<h3 style="margin:0">✏️ <span class="mono">{{ drawerNodeId }}</span></h3>
						<span class="grow"></span>
						<button class="btn xs ghost" :class="{ primary: dBookmarked }" @click="dToggleBookmark" :title="dBookmarked ? 'Quitar marcador' : 'Marcar nodo'">{{ dBookmarked ? '🔖' : '🏷️' }}</button>
						<button class="btn xs ghost" @click="closeDrawer">✕</button>
					</div>

					<!-- Anotaciones (Fase 7): color, grupo, comentario -->
					<div class="ann-box">
						<div class="ann-row">
							<label style="margin:0">Color</label>
							<input type="color" :value="dColor || '#1e3a5f'" @input="dSetColor($event.target.value)" />
							<button v-if="dColor" class="btn xs ghost" @click="dSetColor('')">reset</button>
							<span class="grow"></span>
							<label style="margin:0">Grupo</label>
							<select :value="dGroupId" @change="$event.target.value==='__new__' ? dCreateGroup() : dSetGroup($event.target.value)">
								<option value="">— sin grupo —</option>
								<option v-for="g in groupList" :key="g.id" :value="g.id">{{ g.name }}</option>
								<option value="__new__">＋ nuevo grupo…</option>
							</select>
						</div>
						<label>Comentario (nota de diseño)</label>
						<textarea class="ann-comment" :value="dComment" @input="dSetComment($event.target.value)" placeholder="Nota visible solo en el editor…"></textarea>
					</div>

					<label>Tipo</label>
					<select :value="dNode.type" @change="dSetType($event.target.value)">
						<option value="message">message</option>
						<option value="option">option</option>
					</select>
					<div style="margin-top:6px">
						<label>Texto [{{ store.currentLang.toUpperCase() }}]</label>
						<textarea :value="getI18n(dNode.text)" :placeholder="getI18nFallback(dNode.text) || 'Texto del nodo…'" @input="dSetText(store.currentLang, $event.target.value)" rows="3"></textarea>
					</div>
					<label>Condición (vacío = siempre disponible)</label>
					<condition-editor :model-value="dNode.condition || ''" @update:model-value="dSetCondition($event)"></condition-editor>
					<label style="margin-top:12px">Recompensas / acciones</label>
					<reward-editor :model-value="dNode.reward || ''" @update:model-value="dSetReward($event)"></reward-editor>
					<label style="margin-top:12px">Enlaces (next)</label>
					<div class="next-list">
						<div v-for="(nx, idx) in (dNode.next || [])" :key="idx" class="next-row">
							<select :value="nx" @change="dSetNext(idx,$event.target.value)" :class="{ 'is-broken': nextBroken(nx) }">
								<option value="close">🚪 close (cerrar)</option>
								<option v-if="nextBroken(nx)" :value="nx">⚠️ {{ nx }} (inexistente)</option>
								<option v-for="opt in nextOpts" :key="opt" :value="opt">{{ opt }}</option>
							</select>
							<button class="btn sm danger" @click="dRemoveNext(idx)">✕</button>
						</div>
						<button class="btn sm ghost" @click="dAddNext" style="align-self:flex-start">+ Enlace</button>
					</div>
				</template>
			</div>
		</div>
	</div>
	`;
