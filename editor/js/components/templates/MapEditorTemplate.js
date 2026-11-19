// components/templates/MapEditorTemplate.js
// Plantilla (markup Vue) extraída de MapEditor.js.
// Solo maquetación: NO contiene lógica. La lógica (setup/props/estado) vive en MapEditor.js.
// Regenerable con: node tools/extract_template.mjs editor/js/components/MapEditor.js
export default `
	<div class="map-editor">
		<!-- Barra de herramientas del mundo (Tarea 2) -->
		<div class="map-toolbar">
			<div class="seg map-select" title="Elige qué mapa editar: el mapa real del juego, o una copia de pruebas para experimentar sin riesgo">
				<button class="btn sm" :class="{ primary: store.activeMap==='real' }" @click="selectMap('real')">🗺️ Mapa Real</button>
				<button class="btn sm" :class="{ primary: store.activeMap==='debug' }" @click="selectMap('debug')">🧪 Mapa de Pruebas</button>
			</div>
			<div class="seg">
				<button class="btn sm ghost" @click="doUndo" :disabled="!canUndo" title="Deshacer (Ctrl+Z)">↶</button>
				<button class="btn sm ghost" @click="doRedo" :disabled="!canRedo" title="Rehacer (Ctrl+Y)">↷</button>
			</div>
			<span class="dims mono">{{ store.activeMap==='debug' ? '🧪' : '🗺️' }} {{ width }}×{{ height }}</span>
			<button class="btn sm" :class="{ primary: showResize }" @click="showResize=true">⤢ Redimensionar</button>
			<button class="btn sm" :class="{ primary: showSnaps }" @click="showSnaps=true">📸 Copias de seguridad ({{ snapshots.length }})</button>
			<button class="btn sm ghost" @click="exportMapRender" title="Exportar imagen PNG compuesta del mapa en alta resolución">🖼️ Exportar PNG</button>
			<div class="seg" title="Alterna la capa visual del mapa">
				<button v-for="l in MAP_LAYERS" :key="l.id" class="btn sm" :class="{ primary: store.mapLayer===l.id }" @click="setMapLayer(l.id)" :title="l.help">{{ l.label }}</button>
			</div>
			<span class="spacer"></span>
			<span class="map-autosave">{{ savedText }}</span>
			<button class="btn sm primary" @click="doSave" :disabled="!dirtyWorld">💾 Guardar</button>
		</div>

	<div class="map-layout" :style="mapLayoutStyle" :class="{ resizing: paletteResizing }" @mouseup="stopPaint" @mouseleave="stopPaint">
		<!-- Paleta: herramientas de responsabilidad única + selector por herramienta -->
		<div class="panel pad palette scroll">
			<h3>Herramienta</h3>
			<div class="tool-picker">
				<button v-for="t in TOOLS" :key="t.id" class="tool-btn" :class="{ active: store.brush.tool===t.id }"
					:title="t.help" @click="setTool(t.id)">
					<span class="tool-btn__ico">{{ t.icon }}</span>
					<span class="tool-btn__lbl">{{ t.label }}</span>
				</button>
			</div>
			<p class="muted tool-help">{{ (TOOLS.find(t => t.id===store.brush.tool) || {}).help }}</p>

			<!-- MODO DE TRAZO -->
			<template v-if="!['select', 'move', 'spawn'].includes(store.brush.tool)">
				<h3>Modo de trazo</h3>
				<div class="row gap" style="margin-bottom: 14px; flex-wrap: wrap;">
					<button class="btn sm" :class="{ primary: drawMode==='pencil' }" @click="drawMode='pencil'" title="Pintar celda a celda">🖌️ Pincel</button>
					<button class="btn sm" :class="{ primary: drawMode==='rect' }" @click="drawMode='rect'" title="Pintar un rectángulo de celdas">⏹️ Rectángulo</button>
					<button class="btn sm" :class="{ primary: drawMode==='fill' }" @click="drawMode='fill'" title="Rellenar celdas contiguas del mismo tipo">🪣 Rellenar</button>
				</div>
			</template>

			<!-- SELECCIONAR -->
			<template v-if="store.brush.tool==='select'">
				<h3>🖱️ Seleccionar</h3>
				<p class="muted" style="font-size:12px">Haz clic en una casilla para inspeccionarla en el panel derecho. Esta herramienta <b>nunca modifica</b> el mapa.</p>
			</template>

			<!-- MOVER MAPA -->
			<template v-else-if="store.brush.tool==='pan'">
				<h3>🖐️ Mover mapa</h3>
				<p class="muted" style="font-size:12px">Haz clic y arrastra sobre el mapa para desplazarte en cualquier dirección. También puedes mantener pulsada la <b>Barra Espaciadora</b> o usar la <b>rueda/trackpad</b>.</p>
				<div class="row gap" style="margin-top:10px; flex-wrap:wrap">
					<button class="btn xs ghost" @click="scrollMap(-300, 0)">◀ Izquierda</button>
					<button class="btn xs ghost" @click="scrollMap(300, 0)">Derecha ▶</button>
					<button class="btn xs ghost" @click="scrollMap(0, -300)">▲ Arriba</button>
					<button class="btn xs ghost" @click="scrollMap(0, 300)">▼ Abajo</button>
					<button class="btn xs primary" @click="gotoSpawn">🎯 Ir al inicio</button>
				</div>
			</template>

			<!-- MOVER OBJETO -->
			<template v-else-if="store.brush.tool==='move'">
				<h3>📦 Mover objeto</h3>
				<p class="muted" style="font-size:12px">Haz clic en una casilla con objeto para <b>recogerlo</b>, y luego en la casilla <b>destino</b>. No toca el terreno. Pulsa <b>Esc</b> para cancelar.</p>
				<div class="spawn-info">
					<div v-if="moveSrc" class="row gap" style="align-items:center; flex-wrap:wrap">
						<span class="chip mono">📦 {{ moveSrc.object }}</span>
						<span class="chip mono">origen ({{ moveSrc.x }}, {{ moveSrc.y }})</span>
						<button class="btn xs ghost" @click="moveSrc=null">Cancelar</button>
					</div>
					<div v-else class="empty">Selecciona una casilla con objeto para empezar a moverlo.</div>
				</div>
			</template>

			<!-- TERRENO -->
			<template v-else-if="store.brush.tool==='terrain'">
				<h3>Terrenos</h3>
				<div class="brush-size-picker" v-if="drawMode==='pencil'">
					<button v-for="n in BRUSH_SIZES" :key="n" class="btn xs" :class="{ primary: store.brush.size===n }"
						@click="setBrushSize(n)" :title="'Pincel '+n+'x'+n">{{ n }}x{{ n }}</button>
					<button class="btn xs" :class="{ primary: store.brush.smooth }" @click="toggleBrushSmooth" :disabled="store.brush.size===1"
						title="Suaviza los bordes del pincel (brocha circular en vez de cuadrada)">〰️ Suavizar</button>
				</div>
				<ds-palette :items="terrainItems" v-model="store.brush.terrain"></ds-palette>
				<button class="btn sm secondary" style="margin-top:12px; width:100%" @click="fillEntireMapTerrain" title="Cambiar todo el terreno del mapa al seleccionado">🪣 Rellenar todo el mapa</button>
				<div class="row gap" style="margin-top:10px; flex-wrap:wrap">
					<button class="btn xs ghost" @click="goToTerrainEditor" title="Editar textura, clima, velocidad y daño del terreno seleccionado">✏️ Editar "{{ store.brush.terrain }}"</button>
					<button class="btn xs ghost" @click="goToNewTerrain" title="Crear un tipo de terreno nuevo">➕ Nuevo terreno</button>
				</div>
			</template>

			<!-- RECURSOS -->
			<template v-else-if="store.brush.tool==='resource'">
				<h3>Recursos farmeables</h3>
				<ds-palette :items="resourceItems" v-model="store.brush.resource" searchable search-placeholder="Buscar recurso…"></ds-palette>
				<button class="btn xs ghost" style="margin-top:10px" @click="store.activeTab='worldResources'" title="Editar o crear recursos farmeables">✏️ Editar recursos</button>
			</template>

			<!-- ENTIDADES (con selector de categoría) -->
			<template v-else-if="store.brush.tool==='entity'">
				<h3>Entidades únicas</h3>
				<div class="cat-picker">
					<button v-for="c in ENTITY_CATS" :key="c.value" class="btn xs" :class="{ primary: store.brush.entityCat===c.value }"
						@click="store.brush.entityCat=c.value">{{ c.label }}</button>
				</div>
				<ds-palette :items="entityItems" v-model="store.brush.entity" searchable search-placeholder="Buscar por nombre o id…"></ds-palette>
				<div v-if="!entityItems.length" class="ds-empty" style="padding:16px"><p>No hay entidades en esta categoría.</p></div>
				<button v-if="store.brush.entityCat==='dungeon'" class="btn xs primary" style="margin-top:10px"
					@click="quickCreateDungeon" title="Crea una mazmorra en blanco y la deja lista para colocar aquí mismo">🏰 + Nueva mazmorra…</button>
				<button class="btn xs ghost" style="margin-top:10px" @click="store.activeTab='ids'" title="Crear, editar o borrar entidades (ciudades/mazmorras/POIs)">✏️ Editar entidades</button>
			</template>

			<!-- ENEMIGOS -->
			<template v-else-if="store.brush.tool==='enemy'">
				<h3>Enemigos del mapamundi</h3>
				<ds-palette :items="enemyItems" v-model="store.brush.enemy" searchable search-placeholder="Buscar enemigo…"></ds-palette>
				<button class="btn xs ghost" style="margin-top:10px" @click="store.activeTab='enemies'" title="Crear o editar estadísticas de enemigos">✏️ Editar enemigos</button>
			</template>

			<!-- BORRAR -->
			<template v-else-if="store.brush.tool==='erase'">
				<h3>🧽 Borrador de objetos</h3>
				<p class="muted" style="font-size:12px">Haz clic (o arrastra) sobre las casillas para quitarles el objeto o enemigo. El terreno no se toca.</p>
			</template>

			<!-- REGIÓN -->
			<template v-else-if="store.brush.tool==='region'">
				<h3>⬚ Selección de región</h3>
				<p class="muted" style="font-size:12px">Arrastra para seleccionar un área rectangular (ej. un lago o un bosque) para copiar y pegar en bloque.</p>
				<div class="row gap" style="margin-top:10px; flex-wrap:wrap">
					<button class="btn xs" :disabled="!regionSel" @click="copyRegion" title="Copiar (Ctrl+C)">⧉ Copiar</button>
					<button class="btn xs" :disabled="!regionClipboard" @click="requestPasteRegion" title="Pegar (Ctrl+V)">📋 Pegar</button>
					<button class="btn ghost xs" :disabled="!regionSel" @click="clearRegion" title="Deseleccionar (Esc)">✕ Deseleccionar</button>
				</div>
				<p v-if="regionSel" class="muted" style="font-size:11px; margin-top:8px">Selección: {{ regionSel.x1-regionSel.x0+1 }}×{{ regionSel.y1-regionSel.y0+1 }} casillas</p>
				<p v-if="regionClipboard" class="muted" style="font-size:11px">Portapapeles: {{ regionClipboard.w }}×{{ regionClipboard.h }} casillas</p>
				<p v-if="regionPasteReady" class="warnbox" style="margin-top:8px; font-size:11px">📥 Haz clic en el mapa para pegar.</p>
			</template>

			<!-- INICIO -->
			<template v-else-if="store.brush.tool==='spawn'">
				<h3>🚩 Inicio del protagonista</h3>
				<p class="muted" style="font-size:12px">{{ spawnLabel }}. Haz clic en una casilla para colocar el punto de aparición de este mapa.</p>
				<div class="spawn-info">
					<div v-if="spawnPos" class="row gap" style="align-items:center">
						<span class="chip mono">🚩 ({{ spawnPos.x }}, {{ spawnPos.y }})</span>
						<button class="btn xs ghost" @click="gotoSpawn">Ver casilla</button>
					</div>
					<div v-else class="empty">Sin inicio definido (se usa el valor por defecto del juego).</div>
				</div>
			</template>

			<!-- MEDIR -->
			<template v-else-if="store.brush.tool==='measure'">
				<h3>📏 Medir distancias</h3>
				<p class="muted" style="font-size:12px">Haz clic y arrastra entre dos casillas para ver la distancia entre ellas.</p>
				<div v-if="measureInfo" class="measure-card" style="margin-top:10px">
					<div class="measure-row"><span>Desde:</span><b class="mono">({{ measureInfo.x0 }}, {{ measureInfo.y0 }})</b></div>
					<div class="measure-row"><span>Hasta:</span><b class="mono">({{ measureInfo.x1 }}, {{ measureInfo.y1 }})</b></div>
					<div class="measure-row"><span>Manhattan (|dx|+|dy|):</span><b>{{ measureInfo.manhattan }} casillas</b></div>
					<div class="measure-row"><span>Euclidiana (línea recta):</span><b>{{ measureInfo.euclidean }} casillas</b></div>
				</div>
			</template>
		</div>

		<!-- Redimensionador del panel de paleta (arrastrar para ensanchar) -->
		<div class="palette-resizer" :class="{ dragging: paletteResizing }" @mousedown="onPaletteResizeDown" title="Arrastra para ensanchar el panel">
			<span class="palette-resizer__grip"></span>
		</div>

		<!-- Rejilla con HUD y Minimapa -->
		<div class="map-viewport-wrap">
			<div class="map-wrap" ref="wrapRef"
				@wheel="onWheel" @scroll="onScroll"
				@mousedown="onWrapDown" @mousemove="onWrapMove" @mouseup="onWrapUp"
				@contextmenu.prevent
				:class="{ panning: panning || spacePressed || store.brush.tool==='pan', 'is-hand': spacePressed || store.brush.tool==='pan' }">
				<div class="zoom-controls">
					<button class="btn xs" @click="zoomOut" title="Reducir zoom (Ctrl -)">－</button>
					<span class="zoom-lbl">{{ Math.round(zoom*100) }}%</span>
					<button class="btn xs" @click="zoomIn" title="Aumentar zoom (Ctrl +)">＋</button>
					<button class="btn xs ghost" @click="resetZoom" title="Restablecer zoom al 100%">⟲ 100%</button>
					<span class="zoom-sep"></span>
					<button class="btn xs ghost nav-arrow-btn" @click="scrollMap(-250, 0)" title="Desplazar a la izquierda (◀)">◀</button>
					<button class="btn xs ghost nav-arrow-btn" @click="scrollMap(0, -250)" title="Desplazar arriba (▲)">▲</button>
					<button class="btn xs ghost nav-arrow-btn" @click="scrollMap(0, 250)" title="Desplazar abajo (▼)">▼</button>
					<button class="btn xs ghost nav-arrow-btn" @click="scrollMap(250, 0)" title="Desplazar a la derecha (▶)">▶</button>
					<button class="btn xs ghost" @click="centerMap" title="Centrar cámara en el mapa">🎯 Centrar</button>
					<span class="zoom-sep"></span>
					<button class="btn xs" :class="{ primary: showInspector }" @click="toggleInspector" title="Mostrar/ocultar inspector de casilla">🔍 Inspector {{ sel ? '('+sel.x+','+sel.y+')' : '' }}</button>
				</div>
				<!-- Rejilla VIRTUALIZADA: solo se montan las casillas visibles (+ colchón),
				     cada una colocada explícitamente en su grid-column/grid-row (ver
				     visibleCells/visibleRange en MapEditor.js). .grid conserva su
				     tamaño total real gracias a gridTemplateColumns + gridAutoRows. -->
				<div class="grid" :style="{ gridTemplateColumns: 'repeat(' + width + ', ' + (30*zoom) + 'px)', gridAutoRows: (30*zoom) + 'px', gap: (2*zoom) + 'px' }">
					<div v-for="c in visibleCells" :key="c.y*width+c.x"
						class="cell"
						:class="{ sel: sel && sel.x===c.x && sel.y===c.y, badref: badRefs.has(c.x+','+c.y), spawn: isSpawn(c.x, c.y), moving: isMoveSrc(c.x, c.y), 'in-rect': isInRect(c.x, c.y), 'in-region': isInRegionSel(c.x, c.y) }"
						:style="cellGridStyle(c.x, c.y)"
						@mousedown.left.prevent="onCellDown(c.x, c.y, $event)"
						@dblclick="onCellDblClick(c.x, c.y)"
						@mouseenter="onCellEnter(c.x, c.y, $event)"
						@mousemove="onCellMove($event)"
						@mouseleave="onCellLeave">
						<span v-if="store.mapLayer!=='biome'" class="cell-layer-overlay" :style="{ background: layerOverlayColor(c.x,c.y) }"></span>
						<span v-if="isSpawn(c.x, c.y)" class="spawn-flag" :title="spawnLabel">🚩</span>
						<template v-else-if="tileAt(c.x,c.y) && tileAt(c.x,c.y).enemy">
							<img v-if="getTileEnemy(tileAt(c.x,c.y)) && getTileEnemy(tileAt(c.x,c.y)).sprite" :src="getTileEnemy(tileAt(c.x,c.y)).sprite" class="cell-enemy-thumb" :title="getTileEnemy(tileAt(c.x,c.y)).name" alt="" />
							<span v-else class="cell-enemy-missing" :title="'(Sin sprite) ' + (getTileEnemy(tileAt(c.x,c.y)) ? getTileEnemy(tileAt(c.x,c.y)).name : 'Enemigo')">❌</span>
						</template>
						<template v-else-if="tileAt(c.x,c.y) && tileAt(c.x,c.y).object && getTilePoiNpc(tileAt(c.x,c.y))">
							<img :src="getTilePoiNpc(tileAt(c.x,c.y)).sprite" class="cell-enemy-thumb" :title="getTilePoiNpc(tileAt(c.x,c.y)).name" alt="" />
						</template>
						<span v-else-if="tileAt(c.x,c.y) && (tileAt(c.x,c.y).object || tileAt(c.x,c.y).interactive || tileAt(c.x,c.y).obstacle || tileAt(c.x,c.y).chest)" class="obj-emoji">{{ objIcon(tileAt(c.x,c.y)) }}</span>
					</div>
				</div>
				<!-- Tooltip flotante: la posición (left/top) se escribe directamente
				     sobre este nodo desde MapEditor.js (positionTooltip), NO vía :style
				     reactivo, para no forzar un re-render de toda la rejilla en cada
				     mousemove (ver comentario en la declaración de 'hover'). -->
				<div v-if="hover && hoverInfo()" ref="tooltipRef" class="map-tooltip">
					<div class="tt-coord mono">{{ hoverInfo().coord }}</div>
					<div class="tt-terr">{{ hoverInfo().terrain }}</div>
					<div v-if="hoverInfo().object" class="tt-obj">📦 {{ hoverInfo().object }}</div>
				</div>
			</div>
			<!-- Minimapa interactivo: FIJO en la esquina superior derecha del visor de mapa, sin desplazarse con el scroll -->
			<div class="minimap" :class="{ collapsed: minimapCollapsed }">
				<div class="minimap-head">
					<span class="minimap-title">🗺️ Mapa</span>
					<button class="btn xs ghost minimap-toggle" @click.stop="toggleMinimap" :title="minimapCollapsed ? 'Mostrar minimapa' : 'Minimizar minimapa'">{{ minimapCollapsed ? '▢' : '—' }}</button>
				</div>
				<div v-if="!minimapCollapsed" class="minimap-canvas-wrap" @mousedown.stop="onMinimapDown" @mousemove.stop="onMinimapMove" @mouseup.stop="onMinimapUp" @mouseleave="onMinimapUp" title="Haz clic o arrastra para desplazarte por el mapa">
					<canvas ref="minimapRef" :width="MINIMAP_W" :height="MINIMAP_H"></canvas>
					<div v-if="minimapViewport" class="minimap-viewport" :style="{ left: minimapViewport.left+'px', top: minimapViewport.top+'px', width: minimapViewport.width+'px', height: minimapViewport.height+'px' }"></div>
				</div>
			</div>
		</div>

		<!-- Inspector (colapsable/restaurable) -->
		<div v-if="!showInspector" class="panel flex" @click="toggleInspector"
			style="flex-direction:column; align-items:center; justify-content:flex-start; padding:12px 4px; cursor:pointer; gap:12px; background:rgba(15,23,42,0.9); border-left:1px solid rgba(255,255,255,0.1)"
			title="Haz clic para mostrar el inspector de casilla">
			<button class="btn xs ghost" style="pointer-events:none">🔍</button>
			<div style="writing-mode:vertical-rl; text-orientation:mixed; font-size:11px; font-weight:600; letter-spacing:1px; color:var(--txt-1)">
				INSPECTOR {{ sel ? '(' + sel.x + ',' + sel.y + ')' : '' }}
			</div>
		</div>

		<div v-else class="panel pad inspector scroll">
			<div class="flex" style="justify-content:space-between; align-items:center; margin-bottom:10px">
				<h3 style="margin:0">Inspector de casilla</h3>
				<button class="btn xs ghost" @click="showInspector = false" title="Minimizar inspector">✕ Minimizar</button>
			</div>
			<div v-if="!selTile" class="empty">Haz clic en una casilla en modo <b>Seleccionar</b> para editarla.</div>
			<template v-else>
				<!-- PREVISUALIZADOR VISUAL DE CASILLA (Textura real + Objeto) -->
				<div v-if="selTileInfo" class="map-inspector-tile-card">
					<div class="mit-preview-box" :style="{ background: selTileInfo.color }">
						<img :src="selTileInfo.textureImg" class="mit-preview-tex" alt="Tile texture" />
						<span v-if="selTileInfo.objectIcon" class="mit-preview-obj">{{ selTileInfo.objectIcon }}</span>
						<span class="mit-preview-coord mono">({{ sel.x }}, {{ sel.y }})</span>
					</div>
					<div class="mit-details">
						<div class="mit-name-row">
							<span class="mit-icon">{{ selTileInfo.icon }}</span>
							<strong class="mit-label">{{ selTileInfo.label }}</strong>
							<span class="mit-code mono">{{ selTileInfo.code }}</span>
						</div>
						<p class="mit-desc muted">{{ selTileInfo.desc }}</p>
					</div>
				</div>

				<!-- FICHA DE CUALIDADES Y PELIGROS DE LA CASILLA -->
				<div v-if="selTileInfo" class="map-tile-traits">
					<div class="mtt-header">Cualidades de casilla:</div>
					
					<!-- Transitabilidad y Velocidad -->
					<div class="mtt-row">
						<span class="mtt-badge" :style="{ color: selTileInfo.passability.color, borderColor: selTileInfo.passability.color }">
							{{ selTileInfo.passability.icon }} {{ selTileInfo.passability.label }}
						</span>
						<span class="mtt-badge mtt-badge--speed" title="Multiplicador de velocidad de movimiento">
							⚡ {{ selTileInfo.speedLabel }}
						</span>
					</div>

					<!-- Peligros / Hazards -->
					<div v-if="selTileInfo.hazards.length" class="mtt-hazards">
						<div v-for="(h, hi) in selTileInfo.hazards" :key="hi" class="mtt-hazard-chip" :style="{ color: h.color, borderColor: h.color }" :title="h.desc">
							<span class="mtt-hazard-ico">{{ h.icon }}</span>
							<span class="mtt-hazard-lbl">{{ h.label }}</span>
						</div>
					</div>

					<!-- Clima asignado -->
					<div class="mtt-weather-row" v-if="selTileInfo.weather">
						<span class="muted" style="font-size:11px">Ambiente:</span>
						<span class="chip mono" style="font-size:11px">🌦️ {{ selTileInfo.weather }}</span>
					</div>
				</div>

				<div style="margin-bottom:12px">
					<label style="font-size:11px; font-weight:700; text-transform:uppercase; color:var(--txt-2); margin-bottom:4px; display:block">Terreno de casilla</label>
					<select class="input" :value="selTile.terrain" @change="setSelTerrain($event.target.value)" style="width:100%">
						<option v-for="t in TERRAINS" :key="t.code" :value="t.code">{{ t.icon }} {{ t.label }} ({{ t.code }})</option>
					</select>
				</div>

				<!-- ELEMENTO / CONTENIDO DE LA CASILLA -->
				<div v-if="selTileItem" class="map-item-card">
					<div class="map-item-card__header">
						<span class="map-item-card__badge" :class="selTileItem.typeBadgeClass">
							{{ selTileItem.typeIcon }} {{ selTileItem.typeLabel }}
						</span>
						<div class="map-item-card__actions">
							<button class="btn xs" @click="startMoveCurrentItem" title="Recoger para colocar en otra casilla">📦 Mover</button>
							<button class="btn xs danger" @click="clearCurrentTileItem" title="Quitar elemento de esta casilla">🗑️ Quitar</button>
						</div>
					</div>

					<div class="map-item-card__main">
						<div class="map-item-card__icon">{{ selTileItem.icon }}</div>
						<div class="map-item-card__info">
							<div class="map-item-card__title">{{ selTileItem.name }}</div>
							<div class="map-item-card__id mono">{{ selTileItem.id }}</div>
							<p v-if="selTileItem.desc && selTileItem.subType !== 'dungeon'" class="map-item-card__desc">{{ selTileItem.desc }}</p>
						</div>
					</div>

					<!-- PREVISUALIZACIÓN DE SPRITES / FONDOS -->
					<div v-if="selTileVisuals" class="map-insp-visuals">
						<!-- Enemigo en el mapa: su sprite -->
						<template v-if="selTileVisuals.enemySprite">
							<div class="map-insp-visual-row">
								<img :src="selTileVisuals.enemySprite" class="map-insp-sprite enemy-sprite" :title="selTileVisuals.enemyName" alt="" />
								<span class="map-insp-visual-label">{{ selTileVisuals.enemyName }}</span>
							</div>
						</template>
						<!-- POI / Ciudad: NPC portrait + BG -->
						<template v-if="selTileVisuals.npcSprite || selTileVisuals.bg">
							<div class="map-insp-visual-row">
								<img v-if="selTileVisuals.npcSprite" :src="selTileVisuals.npcSprite"
									class="map-insp-sprite npc-sprite" :title="selTileVisuals.npcId" alt=""
									@error="e => { if(selTileVisuals.npcSpriteFallback && e.target.src !== selTileVisuals.npcSpriteFallback) e.target.src = selTileVisuals.npcSpriteFallback; else e.target.style.display='none'; }" />
								<img v-if="selTileVisuals.bg" :src="selTileVisuals.bg" class="map-insp-bg" :title="selTileVisuals.bgName" alt="" />
							</div>
						</template>
						<!-- Mazmorra: boss sprite prominente -->
						<template v-if="selTileVisuals.bossSprite">
							<div class="map-insp-visual-row boss-card" style="display:flex; align-items:center; gap:10px; padding:6px 8px; background:rgba(255,215,0,0.08); border:1px solid rgba(255,215,0,0.25); border-radius:6px; margin:4px 0">
								<img :src="selTileVisuals.bossSprite" class="map-insp-sprite enemy-sprite" :title="selTileVisuals.bossName" alt="" style="width:44px; height:44px; object-fit:contain" />
								<div style="min-width:0; flex:1">
									<div style="font-size:10px; font-weight:700; color:#ffd700; text-transform:uppercase; letter-spacing:0.5px">👑 Jefe Asignado</div>
									<div class="map-insp-visual-label" style="font-size:13px; font-weight:700; white-space:nowrap; overflow:hidden; text-overflow:ellipsis">{{ selTileVisuals.bossName }}</div>
									<div class="mono muted" style="font-size:10px">{{ selTileVisuals.bossId }}</div>
								</div>
							</div>
						</template>
						<!-- Mazmorra sin boss definido -->
						<div v-else-if="selTileItem && selTileItem.subType === 'dungeon' && selTileVisuals && !selTileVisuals.bossSprite && !selTileVisuals.bossId" class="map-insp-visual-row muted" style="font-size:11px">⚠️ Sin boss asignado</div>
					</div>

					<!-- ACCIONES ESPECÍFICAS POR TIPO -->
					<div class="row gap" style="margin-top:8px; margin-bottom:6px; flex-wrap:wrap">
						<button v-if="selTileItem.subType === 'dungeon'" class="btn sm primary" style="width:100%"
							@click="goToDungeon(selTileItem.id)" title="Abre esta mazmorra en la pestaña Mazmorras">🏰 Editar mazmorra →</button>
						<button v-else-if="selTileItem.subType === 'poi' || selTileItem.subType === 'city'" class="btn sm primary" style="width:100%"
							@click="store.selectedId = selTileItem.id; store.activeTab = 'ids'" title="Abre la ficha de este lugar con sus presencias y fondos">📍 Editar Lugar & Presencias →</button>
						<button v-if="selTileItem.kind === 'entity'" class="btn xs ghost" style="width:100%; margin-top:2px"
							@click="duplicateEntity(selTileItem.id)" title="Clona la entidad con un ID nuevo">⧉ Duplicar entidad</button>
					</div>

					<!-- FORMULARIOS INLINE SI CORRESPONDE -->
					<!-- Si es Enemigo -->
					<div v-if="selTileItem.kind === 'enemy' && inspEnemy" style="margin-top:10px; border-top:1px dashed var(--line); padding-top:8px">
						<label>Tipo de enemigo</label>
						<select :value="inspEnemy.enemy || inspEnemy.enemy_id" @change="setInline('enemy','enemy',$event.target.value); setInline('enemy','enemy_id',$event.target.value)">
							<option v-for="id in ENEMY_IDS" :key="id" :value="id">{{ id }}</option>
						</select>
						<div class="row gap" style="flex-wrap:wrap; margin-top:4px">
							<div><label>Nivel</label>
								<input type="number" min="1" :value="inspEnemy.level || 1" @input="setInline('enemy','level',+$event.target.value)" style="width:70px" /></div>
							<div><label>Aura</label>
								<input type="color" :value="inspEnemy.color || '#ff4d4d'" @input="setInline('enemy','color',$event.target.value)" style="width:65px; height:30px; padding:0; border:none; cursor:pointer" /></div>
							<div><label>Radio</label>
								<input type="number" min="0" max="10" :value="inspEnemy.radius !== undefined ? inspEnemy.radius : 1" @input="setInline('enemy','radius',+$event.target.value)" style="width:65px" /></div>
						</div>
						<div class="row gap" style="flex-wrap:wrap; margin-top:4px">
							<div><label>Velocidad</label>
								<input type="number" step="0.1" min="0.2" max="5.0" :value="inspEnemy.speed !== undefined ? inspEnemy.speed : 1.0" @input="setInline('enemy','speed',+$event.target.value)" style="width:70px" /></div>
							<div><label>Respawn (s)</label>
								<input type="number" min="0" :value="inspEnemy.respawn_time !== undefined ? inspEnemy.respawn_time : (inspEnemy.respawn || 60)" @input="setInline('enemy','respawn_time',+$event.target.value)" style="width:85px" /></div>
						</div>
						<div class="row gap" style="flex-wrap:wrap; margin-top:6px; align-items:center">
							<label style="display:inline-flex; align-items:center; gap:6px; font-weight:normal; font-size:11px; cursor:pointer">
								<input type="checkbox" :checked="inspEnemy.respawn !== false" @change="setInline('enemy','respawn',$event.target.checked)" /> Respawn
							</label>
							<label style="display:inline-flex; align-items:center; gap:6px; font-weight:normal; font-size:11px; cursor:pointer">
								<input type="checkbox" :checked="inspEnemy.aggressive !== false" @change="setInline('enemy','aggressive',$event.target.checked)" /> Aggro
							</label>
						</div>
					</div>

					<!-- Si es Interactivo -->
					<div v-if="selTileItem.kind === 'interactive' && inspInteractive" style="margin-top:10px; border-top:1px dashed var(--line); padding-top:8px">
						<label>Tipo</label>
						<select :value="inspInteractive.kind" @change="setInline('interactive','kind',$event.target.value)">
							<option v-for="k in INTERACTIVE_KINDS" :key="k.value" :value="k.value">{{ k.label }}</option>
						</select>

						<!-- Caso especial: Cinemática -->
						<div v-if="inspInteractive.kind === 'cinematic'" style="margin-top:8px; padding:10px; background:rgba(168,85,247,0.12); border-radius:6px; border:1px solid rgba(168,85,247,0.3)">
							<label style="font-weight:600; color:#c084fc">🎬 Cinemática</label>
							<select :value="inspInteractive.cinematic_id || ''" @change="setInline('interactive','cinematic_id',$event.target.value)">
								<option v-for="cid in cinematicOptions" :key="cid" :value="cid">
									🎬 {{ store.cinematics?.[cid]?.title?.[store.currentLang] || store.cinematics?.[cid]?.title?.es || cid }} ({{ cid }})
								</option>
							</select>
							<label class="row gap" style="align-items:center; margin-top:8px; cursor:pointer; font-size:12px">
								<input type="checkbox" :checked="inspInteractive.trigger_on_step !== false" @change="setInline('interactive','trigger_on_step',$event.target.checked)" />
								<span>👣 Activar automáticamente al pisar la casilla</span>
							</label>
							<label class="row gap" style="align-items:center; margin-top:6px; cursor:pointer; font-size:12px">
								<input type="checkbox" :checked="inspInteractive.once !== false" @change="setInline('interactive','once',$event.target.checked)" />
								<span>🔒 Solo una vez (no repetir tras verse)</span>
							</label>
							<div style="margin-top:8px">
								<button v-if="inspInteractive.cinematic_id && store.cinematics?.[inspInteractive.cinematic_id]" class="btn xs ghost"
									@click="store.selectedCinematic=inspInteractive.cinematic_id; store.activeTab='cinematics'">
									✏️ Ir al editor de esta cinemática →
								</button>
							</div>
						</div>

						<!-- Otros interactivos (letreros, etc.) -->
						<template v-else>
							<label>Icono</label>
							<input :value="inspInteractive.icon" @input="setInline('interactive','icon',$event.target.value)" style="width:70px" />
							<label>Título [{{ store.currentLang.toUpperCase() }}]</label>
							<input :value="getI18n(inspInteractive.title)" :placeholder="getI18nFallback(inspInteractive.title) || 'Título del letrero...'" @input="setInline('interactive', 'title.' + store.currentLang, $event.target.value)" />
							<label>Texto [{{ store.currentLang.toUpperCase() }}]</label>
							<textarea :value="getI18n(inspInteractive.text)" :placeholder="getI18nFallback(inspInteractive.text) || 'Texto o mensaje del letrero...'" @input="setInline('interactive', 'text.' + store.currentLang, $event.target.value)" rows="2"></textarea>
						</template>
					</div>

					<!-- Si es Obstáculo -->
					<div v-if="selTileItem.kind === 'obstacle' && inspObstacle" style="margin-top:10px; border-top:1px dashed var(--line); padding-top:8px">
						<label>Herramienta que lo rompe</label>
						<select :value="inspObstacle.tool || ''" @change="setInline('obstacle','tool',$event.target.value)">
							<option v-for="tl in TOOL_IDS" :key="tl.value" :value="tl.value">{{ tl.label }}</option>
						</select>
						<label class="row gap" style="align-items:center; margin-top:6px; font-size:11px">
							<input type="checkbox" :checked="!!inspObstacle.bombable" @change="setInline('obstacle','bombable',$event.target.checked)" />
							<span>💣 Demolible con bomba</span>
						</label>
						<label style="margin-top:6px">Orientación</label>
						<select :value="inspObstacle.orientation || 'horizontal'" @change="setInline('obstacle','orientation',$event.target.value)">
							<option value="horizontal">Horizontal ↔</option>
							<option value="vertical">Vertical ↕</option>
						</select>
						<div class="row gap" style="flex-wrap:wrap; margin-top:4px">
							<div><label>Recompensa (item)</label>
								<input :value="inspObstacle.reward && inspObstacle.reward.item" @input="setObstacleReward('item',$event.target.value)" style="width:110px" /></div>
							<div><label>Cantidad</label>
								<input type="number" min="0" :value="inspObstacle.reward && inspObstacle.reward.qty" @input="setObstacleReward('qty',+$event.target.value)" style="width:60px" /></div>
						</div>
					</div>

					<!-- Si es Cofre -->
					<div v-if="selTileItem.kind === 'chest' && inspChest" style="margin-top:10px; border-top:1px dashed var(--line); padding-top:8px">
						<label>Oro del cofre</label>
						<input type="number" min="0" :value="inspChest.gold || 0" @input="setChestGold($event.target.value)" style="width:100px" />

						<div style="margin-top:10px; display:flex; justify-content:space-between; align-items:center;">
							<label style="margin:0">Ítems del botín</label>
							<button class="btn sm secondary" @click="addChestItem">➕ Añadir ítem</button>
						</div>

						<div v-if="!inspChest.items || !inspChest.items.length" class="muted" style="font-size:11px; margin-top:4px">
							(Sin ítems configurados, solo oro)
						</div>
						<div v-for="(it, idx) in inspChest.items" :key="idx" class="row gap" style="margin-top:6px; align-items:center;">
							<input :value="it.id" @input="setChestItem(idx, 'id', $event.target.value)" list="map-items-catalog" placeholder="ID de ítem..." style="flex:1" />
							<input type="number" min="1" :value="it.qty || 1" @input="setChestItem(idx, 'qty', $event.target.value)" style="width:60px" title="Cantidad" />
							<button class="btn sm err" @click="removeChestItem(idx)">🗑️</button>
						</div>
					</div>
				</div>

				<!-- ACCESOS RÁPIDOS PARA CASILLA VACÍA -->
				<div v-else class="map-empty-box">
					<div class="map-empty-box__title">📦 Casilla libre (Sin elemento)</div>
					<div class="map-empty-box__sub">Elige qué elemento colocar en esta casilla:</div>
					
					<div class="map-quick-add-grid">
						<button class="btn xs map-quick-add-btn" :class="{ primary: activeQuickAdd==='city' }" @click="activeQuickAdd = activeQuickAdd==='city' ? null : 'city'">
							<span class="emoji">🏛️</span> + Ciudad
						</button>
						<button class="btn xs map-quick-add-btn" :class="{ primary: activeQuickAdd==='poi' }" @click="activeQuickAdd = activeQuickAdd==='poi' ? null : 'poi'">
							<span class="emoji">📍</span> + POI
						</button>
						<button class="btn xs map-quick-add-btn" :class="{ primary: activeQuickAdd==='dungeon' }" @click="activeQuickAdd = activeQuickAdd==='dungeon' ? null : 'dungeon'">
							<span class="emoji">🏰</span> + Mazmorra
						</button>
						<button class="btn xs map-quick-add-btn" :class="{ primary: activeQuickAdd==='resource' }" @click="activeQuickAdd = activeQuickAdd==='resource' ? null : 'resource'">
							<span class="emoji">🌲</span> + Farmeo
						</button>
						<button class="btn xs map-quick-add-btn" @click="addChest">
							<span class="emoji">🧰</span> + Cofre
						</button>
						<button class="btn xs map-quick-add-btn" @click="addEnemy">
							<span class="emoji">👾</span> + Enemigo
						</button>
						<button class="btn xs map-quick-add-btn" @click="addInteractive">
							<span class="emoji">🪧</span> + Interactivo
						</button>
						<button class="btn xs map-quick-add-btn" @click="addCinematic" style="border-color:rgba(168,85,247,0.4)">
							<span class="emoji">🎬</span> + Cinemática
						</button>
						<button class="btn xs map-quick-add-btn" @click="addObstacle">
							<span class="emoji">🪨</span> + Obstáculo
						</button>
						<button class="btn xs map-quick-add-btn" @click="addBlockedPath" title="Utilidades y decoración: Camino bloqueado por piedra (solo demolible con bomba)">
							<span class="emoji">🧱</span> + Utilidad/Decoración
						</button>
					</div>

					<!-- DESPLEGABLE / PICKER SEGÚN CATEGORÍA SELECCIONADA -->
					<div v-if="activeQuickAdd === 'city'" class="map-quick-picker">
						<div class="map-quick-picker__header">
							<span>🏛️ Colocar Ciudad</span>
							<button class="btn xs ghost" @click="activeQuickAdd = null">✕</button>
						</div>
						<div class="map-quick-picker__list">
							<div v-for="c in citiesList" :key="c.id" class="map-quick-picker__item" @click="quickAddCity(c.id)">
								<span>{{ c.icon || '🏛️' }} <b>{{ c.name?.es || c.id }}</b></span>
								<span class="mono muted" style="font-size:10px">{{ c.id }}</span>
							</div>
						</div>
						<button class="btn xs primary" style="width:100%" @click="quickCreateCity">+ Crear nueva ciudad</button>
					</div>

					<div v-else-if="activeQuickAdd === 'poi'" class="map-quick-picker">
						<div class="map-quick-picker__header">
							<span>📍 Colocar Punto de Interés (POI)</span>
							<button class="btn xs ghost" @click="activeQuickAdd = null">✕</button>
						</div>
						<div class="map-quick-picker__list">
							<div v-for="p in poisList" :key="p.id" class="map-quick-picker__item" @click="quickAddPoi(p.id)">
								<span>{{ p.icon || '📍' }} <b>{{ p.name?.es || p.id }}</b></span>
								<span class="mono muted" style="font-size:10px">{{ p.id }}</span>
							</div>
						</div>
						<button class="btn xs primary" style="width:100%" @click="quickCreatePoi">+ Crear nuevo POI</button>
					</div>

					<div v-else-if="activeQuickAdd === 'dungeon'" class="map-quick-picker">
						<div class="map-quick-picker__header">
							<span>🏰 Colocar Mazmorra</span>
							<button class="btn xs ghost" @click="activeQuickAdd = null">✕</button>
						</div>
						<div class="map-quick-picker__list">
							<div v-for="d in dungeonsList" :key="d.id" class="map-quick-picker__item" @click="quickAddDungeon(d.id)">
								<span>{{ d.icon || '🏰' }} <b>{{ d.name?.es || d.id }}</b></span>
								<span class="mono muted" style="font-size:10px">{{ d.id }}</span>
							</div>
						</div>
						<button class="btn xs primary" style="width:100%" @click="quickCreateDungeon">+ Crear nueva mazmorra</button>
					</div>

					<div v-else-if="activeQuickAdd === 'resource'" class="map-quick-picker">
						<div class="map-quick-picker__header">
							<span>🌲 Colocar Recurso de Farmeo</span>
							<button class="btn xs ghost" @click="activeQuickAdd = null">✕</button>
						</div>
						<div class="map-quick-picker__list">
							<div v-for="r in farmingList" :key="r.code" class="map-quick-picker__item" @click="quickAddResource(r.code)">
								<span>{{ r.icon }} <b>{{ r.label }}</b></span>
								<span class="mono muted" style="font-size:10px">{{ r.code }}</span>
							</div>
						</div>
					</div>
				</div>
			</template>
		</div>
	</div>

	<!-- Modal: Redimensionar mundo (Tarea 2) -->
	<div v-if="showResize" class="modal-back" @click.self="showResize=false">
		<div class="modal resize-modal">
			<h3>⤢ Redimensionar mundo</h3>
			<p class="muted">Expande (+) o reduce (−) el mundo desde cualquier borde. Las casillas nuevas se rellenan con <b>mar</b>. No se pierde nada salvo lo que recortes.</p>
			<div class="resize-body">
				<!-- Controles en cruz -->
				<div class="resize-cross">
					<div class="rc-cell rc-top">
						<span class="rc-lbl">Arriba</span>
						<div class="rc-steppers">
							<button class="btn xs" @click="bump('top',-1)">−</button>
							<span class="rc-val" :class="{ pos: resize.top>0, neg: resize.top<0 }">{{ resize.top>0?'+':'' }}{{ resize.top }}</span>
							<button class="btn xs" @click="bump('top',1)">+</button>
						</div>
					</div>
					<div class="rc-mid">
						<div class="rc-cell rc-left">
							<span class="rc-lbl">Izq.</span>
							<div class="rc-steppers">
								<button class="btn xs" @click="bump('left',-1)">−</button>
								<span class="rc-val" :class="{ pos: resize.left>0, neg: resize.left<0 }">{{ resize.left>0?'+':'' }}{{ resize.left }}</span>
								<button class="btn xs" @click="bump('left',1)">+</button>
							</div>
						</div>
						<!-- Previsualización esquemática -->
						<div class="rc-preview" v-if="preview">
							<div class="rp-box" :style="{ width: preview.boxW+'px', height: preview.boxH+'px' }">
								<div class="rp-kept" :style="{ left: preview.retX+'px', top: preview.retY+'px', width: preview.retW+'px', height: preview.retH+'px' }"></div>
							</div>
						</div>
						<div class="rc-cell rc-right">
							<span class="rc-lbl">Der.</span>
							<div class="rc-steppers">
								<button class="btn xs" @click="bump('right',-1)">−</button>
								<span class="rc-val" :class="{ pos: resize.right>0, neg: resize.right<0 }">{{ resize.right>0?'+':'' }}{{ resize.right }}</span>
								<button class="btn xs" @click="bump('right',1)">+</button>
							</div>
						</div>
					</div>
					<div class="rc-cell rc-bottom">
						<span class="rc-lbl">Abajo</span>
						<div class="rc-steppers">
							<button class="btn xs" @click="bump('bottom',-1)">−</button>
							<span class="rc-val" :class="{ pos: resize.bottom>0, neg: resize.bottom<0 }">{{ resize.bottom>0?'+':'' }}{{ resize.bottom }}</span>
							<button class="btn xs" @click="bump('bottom',1)">+</button>
						</div>
					</div>
				</div>
			</div>
			<div class="resize-summary">
				<span class="mono">{{ width }}×{{ height }}</span>
				<span>→</span>
				<span class="mono" :class="{ bad: !resizeValid }">{{ newW }}×{{ newH }}</span>
			</div>
			<div v-if="!resizeValid" class="warnbox">⚠️ El tamaño resultante debe ser al menos 1×1.</div>
			<div v-else-if="removedNonEmpty>0" class="warnbox">⚠️ Se recortarán <b>{{ removedNonEmpty }}</b> casilla(s) con contenido (terreno no-mar u objeto).</div>
			<div v-if="coordShift" class="warnbox">ℹ️ Expandir por arriba/izquierda <b>desplaza las coordenadas</b> de todo el mapa. Revisa después el <b>🚩 Inicio</b> del protagonista (el motor lo acota a la rejilla, pero conviene recolocarlo).</div>
			<div class="row gap" style="margin-top:14px; justify-content:flex-end">
				<button class="btn ghost" @click="resetResize">Reiniciar</button>
				<button class="btn ghost" @click="showResize=false">Cerrar</button>
				<button class="btn primary" @click="applyResize" :disabled="!resizeValid || !resizeDirty">Aplicar</button>
			</div>
		</div>
	</div>

	<!-- Modal: Snapshots del mundo (Tarea 2) -->
	<div v-if="showSnaps" class="modal-back" @click.self="showSnaps=false">
		<div class="modal snaps-modal">
			<h3>📸 Copias de seguridad del mundo</h3>
			<p class="muted">Guarda el mundo tal y como está ahora, para poder volver atrás si algo sale mal más adelante. Se guardan en este navegador; expórtalas si quieres llevarlas a otro ordenador.</p>
			<div class="row gap" style="margin:10px 0">
				<input v-model="newSnapName" placeholder="Nombre de la copia…" @keyup.enter="createSnapshot" />
				<button class="btn primary" @click="createSnapshot">+ Crear</button>
				<label class="btn ghost" style="cursor:pointer; margin:0">⭱ Importar
					<input type="file" accept="application/json,.json" style="display:none" @change="importSnapshot" />
				</label>
			</div>
			<div class="snap-list">
				<div v-for="s in snapshots" :key="s.id" class="snap-row">
					<span class="grow">
						<div class="t">{{ s.name }}</div>
						<div class="s mono">{{ snapDate(s.ts) }}</div>
					</span>
					<button class="btn xs" @click="restoreSnapshot(s.id)" title="Restaurar">↺</button>
					<button class="btn xs ghost" @click="exportSnapshot(s.id)" title="Exportar a fichero">⭳</button>
					<button class="btn xs danger" @click="removeSnapshot(s.id)" title="Eliminar">✕</button>
				</div>
				<div v-if="!snapshots.length" class="empty">Aún no has creado ninguna copia de seguridad.</div>
			</div>
			<div class="row" style="margin-top:14px; justify-content:flex-end">
				<button class="btn ghost" @click="showSnaps=false">Cerrar</button>
			</div>
		</div>
	</div>

	<!-- Datalist de IDs de items para cofres del mapa -->
	<datalist id="map-items-catalog">
		<option v-for="id in allItemIds" :key="id" :value="id">{{ id }}</option>
	</datalist>
	</div>
	`;
