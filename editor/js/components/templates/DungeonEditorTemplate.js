// components/templates/DungeonEditorTemplate.js
// Plantilla (markup Vue) extraída de DungeonEditor.js.
// Solo maquetación: NO contiene lógica. La lógica (setup/props/estado) vive en DungeonEditor.js.
// Regenerable con: node tools/extract_template.mjs editor/js/components/DungeonEditor.js
export default `
	<div class="dungeon-editor">
		<!-- Barra de herramientas (2 filas perennes) -->
		<div class="dun-toolbar">
			<!-- Fila 1: Selección de mazmorra, creación, utilidades y acciones globales -->
			<div class="dun-toolbar-row">
				<div class="seg dun-select-group">
					<label class="dun-topbar-label" title="Mazmorra activa">🏰 Mazmorra:</label>
					<select v-if="dungeonIds.length" :value="store.selectedDungeon" @change="store.selectedDungeon=$event.target.value" class="dun-select" title="Seleccionar mazmorra">
						<option v-for="id in dungeonIds" :key="id" :value="id">{{ (store.dungeons[id].name && store.dungeons[id].name.es) || id }} ({{ id }})</option>
					</select>
					<span v-else class="muted sm">Sin mazmorras.</span>
					<button class="btn sm primary" @click="openCreateModal" title="Crear una nueva mazmorra">+ Nueva mazmorra</button>
				</div>
				<dungeon-wizard-modal :open="dungeonWizardOpen" @close="dungeonWizardOpen=false" @created="dungeonWizardOpen=false"></dungeon-wizard-modal>

				<div class="seg">
					<button class="btn sm" :class="{ primary: showResize }" @click="showResize=true" :disabled="!dun" title="Redimensionar la mazmorra añadiendo/quitando casillas en los 4 bordes">⤢ Redimensionar</button>
					<button class="btn sm" @click="duplicateDungeon" :disabled="!dun" title="Duplicar mazmorra">⧉ Duplicar</button>
					<button class="btn sm danger" @click="deleteDungeon" :disabled="!dun" title="Eliminar mazmorra">🗑</button>
				</div>

				<div class="seg">
					<button class="btn sm ghost" @click="doUndo" :disabled="!canUndo" title="Deshacer (Ctrl+Z)">↶</button>
					<button class="btn sm ghost" @click="doRedo" :disabled="!canRedo" title="Rehacer (Ctrl+Y)">↷</button>
				</div>

				<div class="seg">
					<button class="btn sm" :class="{ primary: show3D }" @click="show3D=!show3D">🧊 Preview 3D</button>
					<button class="btn sm primary" @click="walkthroughOpen=true" style="font-weight:700" title="Explorar la mazmorra en 3D (WASD)">🏰 Paseo 3D</button>
				</div>

				<span class="spacer"></span>
				<span class="dun-autosave" :class="{ 'autosave-error': saveFailed }">{{ savedText }}</span>
				<button class="btn sm primary" @click="doSave">💾 Guardar</button>
			</div>

			<!-- Fila 2: Herramientas de edición perennes horizontalmente -->
			<div class="dun-toolbar-row tools-row">
				<div class="seg">
					<button class="btn sm" :class="{ primary: drawMode==='pencil' }" @click="drawMode='pencil'" title="Pintar celda a celda">🖌️ Pincel</button>
					<button class="btn sm" :class="{ primary: drawMode==='rect' }" @click="drawMode='rect'" title="Pintar un rectángulo de celdas">⏹️ Rectángulo</button>
					<button class="btn sm" :class="{ primary: drawMode==='fill' }" @click="drawMode='fill'" title="Rellenar celdas contiguas del mismo tipo">🪣 Rellenar</button>
				</div>
				<div class="seg">
					<button class="btn sm" :class="{ primary: drawMode==='select' }" @click="drawMode='select'" title="Ver una casilla sin pintarla (Shift+clic)">🔍 Seleccionar</button>
					<button class="btn sm" :class="{ primary: drawMode==='move' }" @click="drawMode='move'" title="Mover un elemento a otra posición">🚚 Mover</button>
					<button class="btn sm" :class="{ primary: drawMode==='eyedropper' }" @click="drawMode='eyedropper'" title="Copiar una casilla ya colocada al pincel (Alt+clic)">💉 Cuentagotas</button>
				</div>
				<div class="seg" v-if="floor">
					<button class="btn sm secondary" @click="fillEntireFloor" title="Rellenar toda la planta activa con el elemento actual">🪣 Rellenar toda la planta</button>
				</div>
				<div class="seg">
					<button class="btn sm" :class="{ primary: drawMode==='region' }" @click="drawMode='region'" title="Arrastra para marcar un rectángulo a copiar (Ctrl+C)">🔲 Región</button>
					<button class="btn sm" :class="{ primary: drawMode==='paste' }" @click="drawMode='paste'" :disabled="!clipboard" title="Haz clic para pegar el recorte copiado (Ctrl+V)">📌 Pegar</button>
					<template v-if="drawMode==='region' && regionSel">
						<button class="btn xs secondary" @click="copyRegion" title="Copiar la región marcada">📋 Copiar ({{ (regionSel.x1-regionSel.x0+1) }}×{{ (regionSel.y1-regionSel.y0+1) }})</button>
						<button class="btn xs ghost" @click="clearRegionSel" title="Quitar selección">✕</button>
					</template>
					<template v-if="drawMode==='paste' && clipboard">
						<button class="btn xs secondary" @click="rotateClipboardCW" title="Rotar 90° horario">↻ 90°</button>
						<button class="btn xs secondary" @click="mirrorClipboardH" title="Reflejar horizontalmente">⇋ Espejar</button>
					</template>
				</div>
			</div>
		</div>

		<!-- Sin mazmorra: estado vacío -->
		<div v-if="!dun" class="dun-empty">
			<div class="big">🏰</div>
			<h3>Editor visual de mazmorras</h3>
			<p class="muted">Crea una mazmorra de exploración basada en cuadrícula para tu juego.<br>Se registrará también en <span class="mono">ids.json</span> para poder colocarla en el mapa del mundo.</p>
			<button class="btn primary" @click="openCreateModal" style="margin-top:14px; font-weight:600">+ Crear nueva mazmorra</button>
		</div>

		<!-- Editor -->
		<div v-else class="dun-layout">
			<!-- Panel izquierdo: metadatos, plantas y paleta organizados en acordeón -->
			<div class="panel pad palette scroll">
				<div class="row gap" style="margin-bottom:8px; justify-content:space-between; align-items:center">
					<span style="font-weight:700; font-size:11px; text-transform:uppercase; letter-spacing:0.05em; color:var(--txt-2)">Inspector & Paleta</span>
					<div class="row gap">
						<button class="btn xs ghost" @click="collapseAllDunSections" title="Plegar todas las secciones">🔼 Plegar todo</button>
						<button class="btn xs ghost" @click="expandAllDunSections" title="Desplegar todas las secciones">🔽 Desplegar todo</button>
					</div>
				</div>

				<!-- SECCIÓN 1: DATOS PRINCIPALES -->
				<div class="dun-sec">
					<div class="dun-sec__head" @click="toggleDunSec('general')">
						<h3>🏰 Datos Principales</h3>
						<button class="btn xs ghost" type="button">{{ dunSections.general ? '▾' : '▸' }}</button>
					</div>
					<div class="dun-sec__body" v-show="dunSections.general">
						<label>Nombre de la Mazmorra [{{ store.currentLang.toUpperCase() }}]</label>
						<input :value="getI18n(dun.name)" :placeholder="getI18nFallback(dun.name) || 'Nombre de la mazmorra...'" @input="setName(store.currentLang, $event.target.value)" />
						<div class="row2">
							<div><label>Jefe (enemy_id)</label>
								<div class="row gap" style="align-items:center">
									<img v-if="enemySpriteUrl(dun.boss)" :src="enemySpriteUrl(dun.boss)" class="enemy-ref-thumb" alt="sprite" />
									<input :value="dun.boss" @change="setMeta('boss', $event.target.value)" list="dun-enemies" style="flex:1" />
								</div>
							</div>
							<div><label>Música</label>
								<div class="row gap" style="align-items:center">
									<input :value="dun.music" @change="setMeta('music', $event.target.value)" style="flex:1" />
									<ds-audio-btn :src="musicPreviewUrl(dun.music)" size="xs" title="Preescuchar música"></ds-audio-btn>
								</div>
							</div>
						</div>

						<!-- Integración con el mundo -->
						<div class="dun-world-box">
							<div class="row-flex">
								<span :class="inIds ? 'ok-chip' : 'warn-chip'">{{ inIds ? '✓ en ids.json' : '⚠ falta en ids.json' }}</span>
								<button class="btn xs" @click="syncToIds">↔ Sincronizar</button>
							</div>
							<div class="muted sm" v-if="worldPlacements.length" style="margin-top:4px">En mapa: {{ worldPlacements.map(p => '('+p.x+','+p.y+')').join(' ') }}</div>
							<div class="muted sm" v-else style="margin-top:4px">Sin colocar en el mapa todavía.</div>
							<button class="btn xs primary" style="margin-top:6px; width:100%" @click="goToMap"
								:title="worldPlacements.length ? 'Selecciona su casilla en el mapa' : 'Prepara el pincel de Entidades con esta mazmorra para colocarla'">
								🗺️ {{ worldPlacements.length ? 'Ver en el mapa →' : 'Colocar en el mapa →' }}
							</button>
						</div>
					</div>
				</div>

				<!-- SECCIÓN 2: PALETA DE ELEMENTOS -->
				<div class="dun-sec">
					<div class="dun-sec__head" @click="toggleDunSec('palette')">
						<h3 class="row-flex">
							<span class="grow">🎨 Paleta de Elementos <ds-tag v-if="showPaletteNewBadge" label="nuevo" tone="accent" size="sm"></ds-tag></span>
							<button class="btn xs ghost" @click.stop="collapseAllSections(); dismissPaletteNewBadge()" title="Colapsar categorías">🔼</button>
							<button class="btn xs ghost" @click.stop="expandAllSections(); dismissPaletteNewBadge()" title="Expandir categorías">🔽</button>
							<button class="btn xs ghost" type="button">{{ dunSections.palette ? '▾' : '▸' }}</button>
						</h3>
					</div>
					<div class="dun-sec__body" v-show="dunSections.palette">
						<input class="input" type="text" v-model="paletteSearch" @focus="dismissPaletteNewBadge" placeholder="🔍 Buscar objeto…" style="margin-bottom:8px" />
						<template v-for="sec in paletteSections" :key="sec.id">
							<div class="pal-group-title pal-group-title--clickable" @click="toggleSection(sec.id)">
								<span class="grow">{{ sec.icon }} {{ sec.label }}</span>
								<span class="dim">{{ isSectionOpen(sec.id) ? '▾' : '▸' }}</span>
							</div>
							<div class="tile-palette" v-show="isSectionOpen(sec.id)">
								<button v-for="t in sec.tiles" :key="t.t" class="tile-btn"
									:class="{ active: brush===t.t && !activeAsset }" :style="{ '--tc': t.color }"
									@click="selectTile(t.t)" :title="t.label">
									<span class="ti">{{ t.icon }}</span>
									<span class="tl" v-html="highlightMatch(t.label, paletteSearch)"></span>
								</button>
								<button v-for="p in sec.pieces" :key="p.id" class="tile-btn"
									:class="{ active: activeAsset && activeAsset.id==='kit_'+p.id }" :style="{ '--tc': sec.kitMeta ? sec.kitMeta.color : '#8a8a8a' }"
									@click="selectKitPiece(p.id, p)" :title="p.name.es + (sec.kitMeta ? ' — verbo: ' + sec.kitMeta.verb : '')">
									<span class="ti">{{ p.icon }}</span>
									<span class="tl" v-html="highlightMatch(p.name.es, paletteSearch)"></span>
								</button>
							</div>
						</template>
						<p v-if="paletteSearch.trim() && !paletteSections.length" class="muted sm">Sin resultados para «{{ paletteSearch }}».</p>
					</div>
				</div>

				<!-- SECCIÓN 3: DIMENSIONES Y PLANTAS -->
				<div class="dun-sec">
					<div class="dun-sec__head" @click="toggleDunSec('floors')">
						<h3>📐 Dimensiones y Plantas ({{ floors.length }})</h3>
						<button class="btn xs ghost" type="button">{{ dunSections.floors ? '▾' : '▸' }}</button>
					</div>
					<div class="dun-sec__body" v-show="dunSections.floors">
						<div class="row gap" style="margin-bottom:8px">
							<button class="btn sm primary" style="flex:1" @click="showResize=true" title="Redimensionar la mazmorra añadiendo/quitando casillas en los 4 bordes">⤢ Redimensionar...</button>
							<button class="btn sm" @click="addFloor" title="Añadir nueva planta">+ Planta</button>
						</div>

						<label>Plantas de la mazmorra</label>
						<div class="floor-list">
							<div v-for="(f, i) in floors" :key="i" class="floor-item" :class="{ active: i===floorIdx }">
								<button class="floor-pick" @click="selectFloor(i)">{{ i }}</button>
								<input class="floor-name" :value="f.name" @change="renameFloor(i, $event.target.value)" />
								<span class="mono dim">{{ f.w }}×{{ f.h }}</span>
								<button class="btn xs danger" @click="removeFloor(i)" :disabled="floors.length<=1">✕</button>
							</div>
						</div>

						<div class="row2" style="margin-top:8px" v-if="floor">
							<div>
								<label>Tamaño planta ({{ floorIdx }})</label>
								<div class="row gap" style="align-items:center">
									<input type="number" min="1" max="64" :value="floor.w" @change="resizeFloor(Number($event.target.value), floor.h)" style="width:50px" title="Ancho" />
									<span class="dim">×</span>
									<input type="number" min="1" max="64" :value="floor.h" @change="resizeFloor(floor.w, Number($event.target.value))" style="width:50px" title="Alto" />
								</div>
							</div>
							<div>
								<label>Escala 3D (m)</label>
								<div class="row gap" style="align-items:center">
									<input type="number" min="1" step="0.5" :value="dun.cell_size" @change="setMeta('cell_size', Number($event.target.value))" style="width:50px" title="Tamaño casilla (m)" />
									<span class="dim">/</span>
									<input type="number" min="1" step="0.5" :value="dun.wall_height" @change="setMeta('wall_height', Number($event.target.value))" style="width:50px" title="Altura pared (m)" />
								</div>
							</div>
						</div>

						<template v-if="floor">
							<label style="margin-top:10px">Plantillas rápidas de sala</label>
							<div class="preset-grid">
								<button v-for="p in ROOM_PRESETS" :key="p.id" class="btn xs" :title="p.hint" @click="applyRoomPreset(p.id)">{{ p.icon }} {{ p.label }}</button>
							</div>
						</template>
					</div>
				</div>

				<!-- SECCIÓN 4: ATMÓSFERA Y TEMÁTICA 3D -->
				<div class="dun-sec">
					<div class="dun-sec__head" @click="toggleDunSec('atmo')">
						<h3>🌫️ Atmósfera y Temática 3D</h3>
						<button class="btn xs ghost" type="button">{{ dunSections.atmo ? '▾' : '▸' }}</button>
					</div>
					<div class="dun-sec__body" v-show="dunSections.atmo">
						<label>Tema visual (paredes/suelo/scatter)</label>
						<select :value="dun.theme" @change="setMeta('theme', $event.target.value)">
							<option v-for="o in ENV_THEME_OPTIONS" :key="o.value" :value="o.value">{{ o.label }}</option>
						</select>
						<label style="margin-top:6px">Fondo de Caída al Vacío <span class="help-tip" title="Efecto visual que se ve debajo de la planta más baja en los huecos/precipicios y al caer">?</span></label>
						<select :value="dun.void_type || 'none'" @change="setMeta('void_type', $event.target.value)">
							<option v-for="o in ENV_VOID_OPTIONS" :key="o.value" :value="o.value">{{ o.label }}</option>
						</select>
						<template v-if="store.expertMode">
							<div class="row2">
								<div><label>Cielo</label>
									<select :value="dun.sky || ''" @change="setMeta('sky', $event.target.value)">
										<option v-for="o in ENV_SKY_OPTIONS" :key="o.value" :value="o.value">{{ o.label }}</option>
									</select>
								</div>
								<div><label>Luz relleno (sol)</label>
									<input type="range" min="0" max="1.5" step="0.05" :value="dun.fill_light ?? 0.9" @input="setMeta('fill_light', Number($event.target.value))" />
									<span class="dim mono">{{ (dun.fill_light ?? 0.9).toFixed?.(2) ?? dun.fill_light }}</span>
								</div>
							</div>
							<div class="row2">
								<div><label>Color luz ambiental</label>
									<input type="color" :value="dun.ambient_color || '#8c8c9e'" @change="setMeta('ambient_color', $event.target.value)" /></div>
								<div><label>Intensidad luz ambiental</label>
									<input type="range" min="0" max="2" step="0.05" :value="dun.ambient_energy ?? 1.2" @input="setMeta('ambient_energy', Number($event.target.value))" />
									<span class="dim mono">{{ (dun.ambient_energy ?? 1.2).toFixed?.(2) ?? dun.ambient_energy }}</span>
								</div>
							</div>
							<label class="chkline"><input type="checkbox" :checked="!!dun.fog" @change="setFogEnabled($event.target.checked)"> Niebla activada</label>
							<div class="row2" v-if="dun.fog">
								<div><label>Color niebla</label>
									<input type="color" :value="dun.fog_color || '#1a1a1f'" @change="setMeta('fog_color', $event.target.value)" /></div>
								<div><label>Densidad niebla</label>
									<input type="range" min="0" max="0.1" step="0.005" :value="dun.fog_density ?? 0.02" @input="setMeta('fog_density', Number($event.target.value))" />
									<span class="dim mono">{{ dun.fog_density ?? 0.02 }}</span>
								</div>
							</div>
							<label>Ambiente en bucle (SFX loop)</label>
							<input :value="dun.ambient_sfx_loop" @change="setMeta('ambient_sfx_loop', $event.target.value)" placeholder="id en AudioManager" />
						</template>
					</div>
				</div>

				<!-- SECCIÓN 5: SALIDA Y ENTRADAS MÚLTIPLES -->
				<div class="dun-sec">
					<div class="dun-sec__head" @click="toggleDunSec('portals')">
						<h3>🚪 Salida y Entradas Múltiples</h3>
						<button class="btn xs ghost" type="button">{{ dunSections.portals ? '▾' : '▸' }}</button>
					</div>
					<div class="dun-sec__body" v-show="dunSections.portals">
						<label>Salida al mundo <span class="help-tip" title="Casilla del mapamundi donde reaparece el jugador al salir de la mazmorra">?</span></label>
						<div class="row-flex">
							<label class="chkline"><input type="checkbox" :checked="!!dun.exit_to" @change="toggleExitTo($event.target.checked)"> Reubicar al salir</label>
							<template v-if="dun.exit_to">
								<span class="dim">X</span><input type="number" min="0" :value="(dun.exit_to&&dun.exit_to.x)||0" @change="setExitTo('x', Number($event.target.value))" style="width:60px" />
								<span class="dim">Y</span><input type="number" min="0" :value="(dun.exit_to&&dun.exit_to.y)||0" @change="setExitTo('y', Number($event.target.value))" style="width:60px" />
							</template>
						</div>

						<label style="margin-top:12px">Entradas nombradas (portales) <span class="help-tip" title="Permite crear múltiples puntos de aparición con nombre para mazmorras con 2+ entradas (ej. boca oeste y este)">?</span></label>
						<div v-for="(p, name) in (dun.portals || {})" :key="name" class="row-flex" style="margin-bottom:4px; flex-wrap:wrap">
							<span class="chip mono">{{ name }}</span>
							<span class="dim">P</span><input type="number" min="0" style="width:42px" :value="(p.spawn&&p.spawn.f)||0" @change="setPortalSpawn(name, 'f', Number($event.target.value))" title="Planta" />
							<span class="dim">X</span><input type="number" min="0" style="width:48px" :value="(p.spawn&&p.spawn.x)||0" @change="setPortalSpawn(name, 'x', Number($event.target.value))" title="Coordenada X" />
							<span class="dim">Y</span><input type="number" min="0" style="width:48px" :value="(p.spawn&&p.spawn.y)||0" @change="setPortalSpawn(name, 'y', Number($event.target.value))" title="Coordenada Y" />
							<button class="btn xs" :disabled="!sel" @click="setPortalHere(name)" title="Usar la casilla seleccionada como punto de aparición">📍 Usar aquí</button>
							<button class="btn xs err" @click="removePortal(name)">🗑️</button>
						</div>
						<div class="row-flex" style="margin-top:6px">
							<input v-model="newPortalName" placeholder="nombre (ej. west)" style="flex:1" @keyup.enter="addPortal" />
							<button class="btn sm secondary" @click="addPortal" :disabled="!newPortalName.trim()">➕ Añadir</button>
						</div>
					</div>
				</div>

				<!-- SECCIÓN 6: PREFABS Y PROPS 3D -->
				<div class="dun-sec">
					<div class="dun-sec__head" @click="toggleDunSec('prefabs')">
						<h3>🏛️ Prefabs y 📦 Props 3D</h3>
						<button class="btn xs ghost" type="button">{{ dunSections.prefabs ? '▾' : '▸' }}</button>
					</div>
					<div class="dun-sec__body" v-show="dunSections.prefabs">
						<label>Prefabs de salas preconfiguradas</label>
						<div class="row gap" style="flex-wrap:wrap; margin-bottom:8px">
							<select v-model="selPrefabId" style="flex:1">
								<option v-for="p in DUNGEON_PREFABS" :key="p.id" :value="p.id">{{ p.name }}</option>
							</select>
						</div>

						<template v-if="store.expertMode">
							<label style="margin-top:10px">Importar Props 3D <span class="dim">(.glb, experto)</span></label>
							<div class="prop-import">
								<label class="prop-import__file">
									<input type="file" accept=".glb" @change="onPropFile" />
									<span class="btn sm">📁 Elegir .glb</span>
									<span class="prop-import__fname" :title="propFileName">{{ propFileName || 'ningún fichero' }}</span>
								</label>
								<div class="row2" style="margin-top:6px">
									<div><label>Nombre</label>
										<input v-model="propName" placeholder="ej. Barril roto" /></div>
									<div><label>Icono</label>
										<input v-model="propIcon" maxlength="2" placeholder="📦" /></div>
								</div>
								<label class="chkline"><input type="checkbox" v-model="propSolid"> Bloquea el paso (colisión)</label>
								<button class="btn sm primary" style="width:100%; margin-top:8px" :disabled="!propFileName || importing" @click="importProp">
									{{ importing ? '⏳ Importando…' : '⬆️ Importar prop' }}
								</button>
							</div>
						</template>
						<template v-if="propTiles.length">
							<div class="pal-group-title">Props importados</div>
							<div class="prop-list">
								<div v-for="p in propTiles" :key="p.t" class="prop-list__row">
									<button class="btn xs" :class="{ primary: brush===p.t && !activeAsset }" @click="selectTile(p.t)" :title="'Colocar ' + p.label">{{ p.icon }} {{ p.label }}</button>
									<span class="spacer"></span>
									<button class="btn xs err" @click="deleteProp(p.t)" title="Borrar prop">🗑️</button>
								</div>
							</div>
						</template>

						<label style="margin-top:12px" class="row-flex">
							<span class="grow">🧩 Biblioteca de sellos</span>
							<button class="btn xs ghost" @click="showAssets=true" title="Gestionar assets">⚙</button>
						</label>
						<div v-if="activeAsset" class="asset-active" style="margin-bottom:6px">
							<span>Sello: <b>{{ activeAsset.icon }} {{ activeAsset.name }}</b></span>
							<button class="btn xs ghost" @click="clearAsset">✕</button>
						</div>
						<div class="asset-save">
							<input v-model="saveAssetName" placeholder="nombre del asset" :disabled="!selCell" @keyup.enter="saveCurrentAsAsset" />
							<button class="btn xs" @click="saveCurrentAsAsset" :disabled="!selCell" title="Guarda la casilla seleccionada como asset reutilizable">💾 Guardar casilla</button>
						</div>
					</div>
				</div>

				<!-- SECCIÓN 7: DIAGNÓSTICO DE MAZMORRA -->
				<div class="dun-sec">
					<div class="dun-sec__head" @click="toggleDunSec('issues')">
						<h3>
							<span>⚠️ Diagnóstico</span>
							<span v-if="!dungeonIssueCount.total" class="ok-chip" style="font-size:10px; margin-left:auto">✓ OK</span>
							<span v-else class="warn-chip" style="font-size:10px; margin-left:auto">⚠ {{ dungeonIssueCount.total }}</span>
						</h3>
						<button class="btn xs ghost" type="button">{{ dunSections.issues ? '▾' : '▸' }}</button>
					</div>
					<div class="dun-sec__body" v-show="dunSections.issues">
						<div v-if="!dungeonIssueCount.total" class="ok-chip">✓ Sin problemas detectados en la mazmorra.</div>
						<div v-else class="dun-issues__list">
							<button v-for="(iss, idx) in dungeonIssues" :key="idx" class="dun-issue" :class="iss.level"
								:disabled="iss.f===undefined" @click="jumpToIssue(iss)"
								:title="iss.f===undefined ? iss.msg : 'Ir a la casilla — ' + iss.msg">
								<span class="dun-issue__ico">{{ iss.level==='error' ? '⛔' : '⚠' }}</span>
								<span class="dun-issue__msg">{{ iss.msg }}</span>
							</button>
						</div>
					</div>
				</div>

				<datalist id="dun-enemies"><option v-for="e in enemyIds" :key="e" :value="e"></option></datalist>
				<p class="muted sm" style="margin-top:8px">Clic izq: pintar · Arrastrar: pintar en línea · Ctrl/clic der: borrar · Shift+clic: seleccionar sin pintar.</p>
			</div>

			<!-- Centro: rejilla cenital -->
			<div class="dun-grid-area">
				<div class="dun-grid-head">
					<div class="floor-tabs">
						<button v-for="(f, i) in floors" :key="i" :class="{ active: i===floorIdx }" @click="selectFloor(i)">{{ f.name }}</button>
					</div>
					<span class="spacer"></span>
					<div class="seg">
						<button class="btn xs ghost" @click="zoomBy(-0.15)" title="Alejar">−</button>
						<span class="zoom-lbl">{{ Math.round(zoom*100) }}%</span>
						<button class="btn xs ghost" @click="zoomBy(0.15)" title="Acercar">+</button>
						<button class="btn xs" @click="fitToView" title="Ajustar la planta entera a la pantalla">⤢ Ajustar</button>
					</div>
				</div>
				<div v-if="dungeonLoading" class="dun-loading-overlay">
					<div class="spinner"></div>
					<p class="muted" style="margin-top:10px">Cargando mazmorra…</p>
				</div>
				<div class="dun-grid-scroll scroll" ref="gridCanvasWrap" @wheel="onWheelZoom">
					<div v-if="floor" class="dun-grid" @contextmenu.prevent
						:style="{ gridTemplateColumns: 'repeat(' + floor.w + ', ' + cellPx + 'px)' }">
						<template v-for="(row, y) in floor.cells" :key="y">
							<div v-for="(cell, x) in row" :key="x" class="dun-cell"
								:class="{ selected: sel && sel.x===x && sel.y===y, spawn: isSpawn(x,y), 'in-rect': isInRect(x,y), 'in-paste': isInPastePreview(x,y), 'light-radius': inLightRadius(x,y) }"
								:style="[cellStyle(cell), { width: cellPx+'px', height: cellPx+'px', fontSize: Math.round(cellPx*0.5)+'px' }]"
								:title="cellTitle(x, y, cell)"
								@mousedown="beginStroke(x, y, $event)"
								@mouseenter="overCell(x, y)"
								@mouseup="endStroke">
								<span class="ci">{{ cellIcon(cell) }}</span>
								<span v-if="cell.ref" class="cref" :title="cell.ref"></span>
							</div>
						</template>
					</div>
				</div>
			</div>

			<!-- Derecha: inspector de casilla / preview 3D -->
			<div class="panel pad inspector scroll">
				<template v-if="show3D">
					<h3>Preview 3D</h3>
					<label class="chkline"><input type="checkbox" v-model="stack3D"> Apilar todas las plantas</label>
					<canvas ref="previewCanvas" width="360" height="360" class="dun-preview"></canvas>
					<p class="muted sm">Vista isométrica esquemática para comprobar el layout (no es el render final del juego).</p>
				</template>
				<template v-else>
					<!-- Panel del PINCEL ACTIVO: qué vas a colocar y con qué propiedades -->
					<div class="brush-card">
						<div class="brush-card__head">
							<span class="brush-card__ico">{{ activeAsset ? activeAsset.icon : (brushMeta ? brushMeta.icon : '🖌️') }}</span>
							<div class="grow">
								<div class="brush-card__name">{{ activeAsset ? activeAsset.name : (brushMeta ? brushMeta.label : brush) }}</div>
								<div class="brush-card__sub">{{ activeAsset ? 'Sello de la biblioteca' : (brushMeta ? brushMeta.group : '') }}</div>
							</div>
							<button v-if="activeAsset" class="btn xs ghost" @click="clearAsset" title="Dejar de usar el sello y pintar con un tipo">✕ usar tipo</button>
						</div>
						<canvas v-show="!previewModelUrl" ref="itemPreviewCanvas" class="item-preview" width="240" height="150" title="Vista previa del elemento activo"></canvas>
						<model-viewer v-if="previewModelUrl" :key="previewModelUrl" :src="previewModelUrl" class="item-preview item-preview--3d"
							camera-controls auto-rotate rotation-per-second="24deg" exposure="1" shadow-intensity="0.7"
							alt="Vista previa del modelo 3D" title="Arrastra para girar el modelo"></model-viewer>
						<cell-props-editor v-if="!activeAsset && brushMeta"
							:model="brushConfig" :caps="brushCaps" :default-color="brushMeta.color || '#39404e'"
							:textures="dungeonTextures" :upload-texture="importDungeonTexture" :default-texture-url="defaultTextureUrl"
							hint="Estas propiedades se aplican al pintar. Puedes cambiarlas en cada casilla luego."
							@change="setBrushConfig"></cell-props-editor>
						<template v-if="!activeAsset && brush==='switch'">
							<label>Modo del interruptor</label>
							<select :value="brushConfig.mode || 'wall'" @change="setBrushConfig('mode', $event.target.value)">
								<option value="wall">Interruptor de pared</option>
								<option value="button">Botón</option>
								<option value="pressure">Placa de presión</option>
							</select>
						</template>
						<template v-if="!activeAsset && brush==='door'">
							<label>Tipo de puerta</label>
							<select :value="brushConfig.kind || 'door'" @change="setBrushConfig('kind', $event.target.value)">
								<option value="door">Puerta normal</option>
								<option value="gate">Compuerta</option>
								<option value="timed">Puerta temporizada</option>
							</select>
							<template v-if="(brushConfig.kind || 'door') === 'timed'">
								<label>Duración (s)</label>
								<input type="number" min="0.1" step="0.1" :value="brushConfig.duration || 1.0" @change="setBrushConfig('duration', $event.target.value==='' ? '' : Number($event.target.value))" />
							</template>
						</template>
						<template v-if="!activeAsset && (brush==='crate' || brush==='statue')">
							<label>Variante</label>
							<select :value="brushConfig.variant || 'light'" @change="setBrushConfig('variant', $event.target.value)">
								<option value="light">Ligero</option>
								<option value="heavy">Pesado</option>
							</select>
						</template>
					</div>

					<h3>Casilla</h3>
					<div v-if="!selCell" class="empty">Selecciona una casilla de la rejilla (herramienta 🔍 o Shift+clic).</div>
					<template v-else>
						<div class="chip mono">({{ sel.x }}, {{ sel.y }}) · {{ selMeta ? selMeta.label : selCell.t }}</div>

						<label>Tipo</label>
						<select :value="selCell.t" @change="setCellProp('t', $event.target.value)">
							<optgroup v-for="g in TILE_GROUPS" :key="g" :label="g">
								<option v-for="t in tilesInGroup(g)" :key="t.t" :value="t.t">{{ t.icon }} {{ t.label }}</option>
							</optgroup>
						</select>

						<!-- Referencia de entidad -->
						<template v-if="selMeta && (selCell.t==='monster')">
							<label>Enemigo (enemy_id)</label>
							<div class="row gap" style="align-items:center">
								<img v-if="enemySpriteUrl(selCell.ref)" :src="enemySpriteUrl(selCell.ref)" class="enemy-ref-thumb" alt="sprite" />
								<input :value="selCell.ref" @change="setCellProp('ref', $event.target.value)" list="dun-enemies" style="flex:1" />
							</div>
							<label class="chkline"><input type="checkbox" :checked="selCell.boss" @change="setCellProp('boss', $event.target.checked || '')"> Es el jefe</label>
							<label>Nivel</label>
							<input class="input num" type="number" min="1" max="99" :value="selCell.level || 1"
								@change="setCellProp('level', $event.target.value ? Math.max(1, parseInt($event.target.value, 10) || 1) : '')" />
							<p class="muted" v-if="!selCell.ref" style="margin:2px 0 0">
								Sin "Enemigo" elegido: esta casilla usa el jefe de la
								mazmorra (ver arriba), no un enemigo/nivel fijo.
							</p>
						</template>
						<template v-else-if="selCell.t==='npc'">
							<label>NPC (npc id)</label>
							<input :value="selCell.ref" @change="setCellProp('ref', $event.target.value)" list="dun-npcs" />
							<datalist id="dun-npcs"><option v-for="n in npcIds" :key="n" :value="n"></option></datalist>
						</template>
						<template v-else-if="selCell.t==='item'">
							<label>Objeto (item id)</label>
							<input :value="selCell.ref" @change="setCellProp('ref', $event.target.value)" list="dun-items" />
							<label>Cantidad</label>
							<input type="number" min="1" :value="selCell.qty || 1" @change="setCellProp('qty', Number($event.target.value))" />
							<datalist id="dun-items"><option v-for="it in itemIds" :key="it" :value="it"></option></datalist>
						</template>
						<template v-else-if="selCell.t==='chest'">
							<label>Oro que contiene</label>
							<input type="number" min="0" :value="selCell.gold || 0" @change="setChestGold(Number($event.target.value))" />
							<label>Objetos del cofre
								<button class="btn sm secondary" style="margin-left:8px" @click="addChestItem" :disabled="!itemIds.length">➕ Añadir</button>
							</label>
							<div v-for="(it, idx) in (selCell.items || [])" :key="idx" class="row3" style="align-items:center; margin-bottom:4px">
								<input :value="it.id" @change="setChestItem(idx, 'id', $event.target.value)" list="dun-items" placeholder="item id" />
								<input type="number" min="1" :value="it.qty || 1" @change="setChestItem(idx, 'qty', Number($event.target.value))" title="Cantidad" />
								<button class="btn sm err" @click="removeChestItem(idx)">🗑️</button>
							</div>
							<p v-if="!(selCell.items && selCell.items.length)" class="dim" style="font-size:12px">Sin objetos. El cofre puede dar solo oro.</p>
							<datalist id="dun-items"><option v-for="it in itemIds" :key="it" :value="it"></option></datalist>
						</template>
						<template v-else-if="selCell.t==='teleport' || selCell.t==='stairs'">
							<label>Destino{{ selCell.t==='stairs' ? ' (planta a la que sube/baja)' : '' }}</label>
							<p v-if="selCell.t==='stairs'" class="brush-card__hint">Sin destino, la escalera es solo decorativa (no lleva a ninguna planta). Ponlo apuntando a la casilla de llegada (normalmente otra escalera) en la otra planta.</p>
							<div class="row3">
								<div><span class="dim">Planta</span><input type="number" min="0" :value="(selCell.to&&selCell.to.f)||0" @change="setTeleportTarget('f', Number($event.target.value))" /></div>
								<div><span class="dim">X</span><input type="number" min="0" :value="(selCell.to&&selCell.to.x)||0" @change="setTeleportTarget('x', Number($event.target.value))" /></div>
								<div><span class="dim">Y</span><input type="number" min="0" :value="(selCell.to&&selCell.to.y)||0" @change="setTeleportTarget('y', Number($event.target.value))" /></div>
							</div>
							<template v-if="selCell.t==='teleport' && !selCell.to">
								<label>Nombre de la salida (opcional)</label>
								<p class="brush-card__hint">Sin destino interno, este teletransporte SALE de la mazmorra. Si esta salida es una "puerta" concreta (una de las "Entradas nombradas" de arriba, p. ej. "west"), pon aquí ese MISMO nombre: al pisarla, el jugador reaparecerá en la casilla del mapamundi que declare esa entrada — no siempre en la que usó para entrar. Déjalo vacío para la salida genérica de siempre (vuelve al punto de entrada, o a "Salida al mundo" si está fijada).</p>
								<input :value="selCell.portal || ''" @change="setCellProp('portal', $event.target.value)" list="dun-portal-names" placeholder="west" />
								<datalist id="dun-portal-names"><option v-for="(p, name) in (dun.portals || {})" :key="name" :value="name"></option></datalist>
							</template>
						</template>
						<template v-else-if="selCell.t==='event'">
							<label>ID de evento</label>
							<input :value="selCell.ev" @change="setCellProp('ev', $event.target.value)" placeholder="ev_puerta_1" />
						</template>

						<!-- DISPARADOR DE CINEMÁTICA -->
						<template v-else-if="selCell.t==='cinematic'">
							<div class="prop-sep">🎬 Cinemática</div>
							<label>Cinemática a reproducir</label>
							<select :value="selCell.cinematic_id || ''" @change="setCellProp('cinematic_id', $event.target.value)">
								<option value="">— elige una cinemática —</option>
								<option v-for="cid in cinematicOptions" :key="cid" :value="cid">
									🎬 {{ store.cinematics?.[cid]?.title?.[store.currentLang] || store.cinematics?.[cid]?.title?.es || cid }} ({{ cid }})
								</option>
							</select>
							<div class="row2" style="margin-top: 6px;">
								<div>
									<label>Modo de activación</label>
									<select :value="selCell.trigger_on_step !== false ? 'step' : 'interact'" @change="setCellProp('trigger_on_step', $event.target.value === 'step')">
										<option value="step">👣 Al pisar (Automático)</option>
										<option value="interact">👆 Al interactuar (Acción)</option>
									</select>
								</div>
								<div>
									<label>Frecuencia</label>
									<select :value="selCell.once !== false ? 'once' : 'multi'" @change="setCellProp('once', $event.target.value === 'once')">
										<option value="once">🔒 Un solo uso (primera vez)</option>
										<option value="multi">🔄 Múltiples veces (cada vez)</option>
									</select>
								</div>
							</div>
							<div v-if="selCell.cinematic_id && store.cinematics?.[selCell.cinematic_id]" style="margin-top: 8px;">
								<button class="btn xs ghost" @click="store.selectedCinematic = selCell.cinematic_id; store.activeTab = 'cinematics'">
									✏️ Ir al editor de esta cinemática →
								</button>
							</div>
						</template>

						<!-- OBJETO INTELIGENTE (kit) — -->
						<template v-else-if="selCell.t==='smart'">
							<label>Pieza de kit</label>
							<select :value="selCell.kit || ''" @change="setCellProp('kit', $event.target.value)">
								<option value="">— elige una pieza —</option>
								<optgroup v-for="kg in kitGroups" :key="kg.id" :label="kg.meta.label.es">
									<option v-for="p in kg.items" :key="p.id" :value="p.id">{{ p.icon }} {{ p.name.es }}</option>
								</optgroup>
							</select>
							<template v-if="selPieceDef">
								<div class="muted sm" style="margin:4px 0">
									Habilidad: <b>{{ (kitsMeta[selPieceDef.kit]||{}).icon }} {{ (kitsMeta[selPieceDef.kit]||{}).label.es }}</b>
									· verbo <span class="mono">{{ (kitsMeta[selPieceDef.kit]||{}).verb }}</span>
								</div>
								<template v-if="pieceUsesElement(selPieceDef)">
									<label>Elemento</label>
									<select :value="selCell.element || ''" @change="setCellProp('element', $event.target.value)">
										<option value="">— por defecto de la pieza —</option>
										<option v-for="e in ELEMENTS" :key="e" :value="e">{{ e }}</option>
									</select>
								</template>
								<template v-if="selPieceDef.archetype === 'auto_platform'">
									<label>Dirección</label>
									<select :value="selCell.direction || 'horizontal'" @change="setCellProp('direction', $event.target.value)">
										<option value="horizontal">Horizontal (→ derecha)</option>
										<option value="vertical">Vertical (↑ arriba)</option>
									</select>
									<label>Distancia (casillas)</label>
									<input type="number" min="1" step="1" :value="selCell.distance ?? 3" @change="setCellProp('distance', parseInt($event.target.value) || 1)" />
									<p class="muted sm">Empieza en esta casilla y va y vuelve sin parar, recorriendo esa distancia en la dirección elegida. El jugador puede subirse caminando desde una casilla de suelo contigua.</p>
								</template>
								<template v-else>
									<label>Evento global al activarse (opcional)</label>
									<input :value="selCell.event || ''" @change="setCellProp('event', $event.target.value)" placeholder="EVENT_PUERTA_ABIERTA" />
									<p class="muted sm">Conéctalo a otro objeto/puerta que escuche ese evento para crear puzles.</p>
								</template>
							</template>
						</template>

						<!-- CARTEL DE GUÍA (sign) — -->
						<template v-else-if="selCell.t==='sign'">
							<label>Texto del cartel</label>
							<textarea :value="selCell.text || ''" @change="setCellProp('text', $event.target.value)" rows="3" placeholder="Escribe la instrucción. Usa saltos de línea para varias líneas."></textarea>
							<p class="muted sm">Se muestra como texto flotante en el mundo 3D. Ideal para tutoriales.</p>
						</template>

						<!-- Elemento interactivo con estados/IDs (Fase 6) -->
						<template v-if="isStateful(selCell.t) || isActuator(selCell.t)">
							<div class="prop-sep">Mecánica Interactiva</div>
							<label>Nombre / ID de señal (ej. puerta_1, palanca_a)</label>
							<p class="brush-card__hint">Identificador único para enlazar este objeto con palancas, placas o llaves.</p>
							<input :value="selCell.eid || ''" @change="setEid($event.target.value)" placeholder="ej. puerta_principal, palanca_1" />
							<template v-if="stateOptionsFor(selCell.t).length">
								<label>Estado inicial</label>
								<select :value="selCell.state || stateOptionsFor(selCell.t)[0]" @change="setState($event.target.value)">
									<option v-for="s in stateOptionsFor(selCell.t)" :key="s" :value="s">{{ s === 'closed' ? '🔒 Cerrado' : (s === 'open' ? '🔓 Abierto' : s) }}</option>
								</select>
							</template>
							<template v-if="selCell.t==='switch'">
								<label>Modo del interruptor</label>
								<select :value="selCell.mode || 'wall'" @change="setCellProp('mode', $event.target.value)">
									<option value="wall">Interruptor de pared</option>
									<option value="button">Botón</option>
									<option value="pressure">Placa de presión</option>
								</select>
							</template>
							<template v-if="selCell.t==='door'">
								<label>Tipo de puerta</label>
								<select :value="selCell.kind || 'door'" @change="setCellProp('kind', $event.target.value)">
									<option value="door">Puerta normal</option>
									<option value="gate">Compuerta levadiza</option>
									<option value="timed">Puerta con temporizador</option>
								</select>
								<template v-if="(selCell.kind || 'door') === 'timed'">
									<label>Duración abierta (segundos)</label>
									<input type="number" min="0.1" step="0.1" :value="selCell.duration || 1.0" @change="setCellProp('duration', $event.target.value==='' ? '' : Number($event.target.value))" />
								</template>
							</template>
							<template v-if="selCell.t==='crate' || selCell.t==='statue'">
								<label>Peso / Resistencia</label>
								<select :value="selCell.variant || 'light'" @change="setCellProp('variant', $event.target.value)">
									<option value="light">Ligero (empujable fácilmente)</option>
									<option value="heavy">Pesado (requiere gran fuerza)</option>
								</select>
							</template>
							<template v-if="selCell.t==='water'">
								<label class="chkline"><input type="checkbox" :checked="!!selCell.poisoned" @change="setCellProp('poisoned', $event.target.checked)"> ☠️ Agua Tóxica / Venenosa (daña al cruzar sin purificar)</label>
							</template>
							<template v-if="isActuator(selCell.t)">
								<label class="row-flex">Acciona estos objetos…
									<button class="btn sm secondary" style="margin-left:8px" @click="addTarget">➕ Conectar objeto</button>
								</label>
								<div v-if="!(selCell.targets && selCell.targets.length)" class="dim" style="font-size:12px">Sin conexiones. Conecta puertas o trampas para que respondan a esta palanca/placa.</div>
								<div v-for="(tg, idx) in (selCell.targets || [])" :key="idx" class="row3" style="align-items:center; margin-bottom:4px">
									<select :value="tg.eid" @change="setTarget(idx,'eid',$event.target.value)" :class="{ 'bad-ref': brokenTargets.has(tg.eid) }">
										<option value="">— elige objeto a accionar —</option>
										<option v-for="e in linkableTargets" :key="e.f+'_'+e.eid" :value="e.eid">{{ e.eid }} ({{ e.t }})</option>
									</select>
									<select :value="tg.action" @change="setTarget(idx,'action',$event.target.value)" title="Acción">
										<option v-for="a in TARGET_ACTIONS" :key="a" :value="a">{{ a === 'open' ? '🔓 Abrir' : (a === 'close' ? '🔒 Cerrar' : (a === 'toggle' ? '🔄 Alternar' : a)) }}</option>
									</select>
									<button class="btn sm err" @click="removeTarget(idx)">🗑️</button>
								</div>
								<div v-if="brokenTargets.size" class="warn-chip" style="margin-top:4px">⚠ Hay conexiones hacia un ID que no existe en esta mazmorra.</div>
							</template>
						</template>

						<!-- Propiedades de aspecto (contextuales al tipo) -->
						<div class="prop-sep">Aspecto</div>
						<cell-props-editor :model="selCell" :caps="selCaps" default-color="#39404e"
							:textures="dungeonTextures" :upload-texture="importDungeonTexture" :default-texture-url="defaultTextureUrl"
							@change="setCellProp"></cell-props-editor>

						<div class="prop-sep">Posición</div>
						<div class="row gap" style="flex-wrap:wrap; margin-bottom:6px">
							<button class="btn sm primary" style="width:100%" @click="moveSelectedCell" title="Mover este enemigo o elemento a otra posición de la mazmorra">🚚 Mover esta casilla</button>
							<button class="btn sm" style="width:100%" @click="markSpawnHere" :class="{ primary: isSpawn(sel.x, sel.y) }">🚩 {{ isSpawn(sel.x, sel.y) ? 'Inicio aquí' : 'Marcar inicio del jugador' }}</button>
						</div>
					</template>
				</template>
			</div>
		</div>

		<!-- Modal: Nueva Mazmorra -->
		<div v-if="showCreateDunModal" class="modal-back" @click.self="showCreateDunModal=false">
			<div class="modal dun-create-modal">
				<div class="dun-create-head">
					<div class="dun-create-icon">🏰</div>
					<div>
						<h3>Nueva Mazmorra</h3>
						<p class="muted sm" style="margin:2px 0 0">Configura el nombre, identificador y la plantilla de inicio.</p>
					</div>
				</div>

				<div class="dun-create-form">
					<label>Nombre de la mazmorra (ES)</label>
					<input v-model="newDunName" @input="onNewDunNameInput" placeholder="Ej. Cueva de los Perdidos" @keyup.enter="submitCreateDungeon" autofocus />

					<label>ID técnica (en ficheros y código)</label>
					<input v-model="newDunId" @input="newDunIdTouched=true" placeholder="dun_cueva_perdidos" class="mono" @keyup.enter="submitCreateDungeon" />
					<div class="hint sm muted" style="margin-top:3px; margin-bottom:12px; font-size:11px">Se guardará en <span class="mono">data/dungeons/&lt;id&gt;.json</span> y se sincronizará con <span class="mono">ids.json</span>.</div>

					<label style="margin-bottom:6px">Punto de partida / Plantilla:</label>
					<div class="dun-presets-grid">
						<label class="dun-preset-card" :class="{ active: newDunPreset==='standard' }">
							<input type="radio" v-model="newDunPreset" value="standard" />
							<div class="dun-preset-info">
								<div class="dun-preset-title">🏰 Estándar (15×21)</div>
								<div class="dun-preset-desc">Sala principal rectangular con entrada, jefe de prueba y portales.</div>
							</div>
						</label>

						<label class="dun-preset-card" :class="{ active: newDunPreset==='rooms' }">
							<input type="radio" v-model="newDunPreset" value="rooms" />
							<div class="dun-preset-info">
								<div class="dun-preset-title">🚪 Salas conectadas (18×12)</div>
								<div class="dun-preset-desc">3 cámaras con pasillos, palanca interactiva, compuerta y cofre.</div>
							</div>
						</label>

						<label class="dun-preset-card" :class="{ active: newDunPreset==='chasm' }">
							<input type="radio" v-model="newDunPreset" value="chasm" />
							<div class="dun-preset-info">
								<div class="dun-preset-title">🕳️ Abismo y Plataformas (19×13)</div>
								<div class="dun-preset-desc">Foso central con columnas de Agarre Psíquico y lanzadera temporal.</div>
							</div>
						</label>

						<label class="dun-preset-card" :class="{ active: newDunPreset==='blank' }">
							<input type="radio" v-model="newDunPreset" value="blank" />
							<div class="dun-preset-info">
								<div class="dun-preset-title">⬜ En blanco (15×15)</div>
								<div class="dun-preset-desc">Cuadrícula despejada con muros perimetrales y punto de spawn.</div>
							</div>
						</label>

						<label class="dun-preset-card" :class="{ active: newDunPreset==='wizard' }">
							<input type="radio" v-model="newDunPreset" value="wizard" />
							<div class="dun-preset-info">
								<div class="dun-preset-title">🧙 Asistente paso a paso</div>
								<div class="dun-preset-desc">Personalizar libremente dimensiones W×H, bioma/tema y texturas 3D.</div>
							</div>
						</label>
					</div>
				</div>

				<div class="row gap" style="margin-top:20px; justify-content:flex-end">
					<button class="btn ghost" @click="showCreateDunModal=false">Cancelar</button>
					<button class="btn primary" @click="submitCreateDungeon">
						{{ newDunPreset==='wizard' ? 'Continuar al Asistente →' : 'Crear mazmorra' }}
					</button>
				</div>
			</div>
		</div>

		<!-- Modal: Redimensionar Mazmorra (4 lados) -->
		<div v-if="showResize" class="modal-back" @click.self="showResize=false">
			<div class="modal resize-modal">
				<h3>⤢ Redimensionar mazmorra</h3>
				<p class="muted">Expande (+) o reduce (−) la mazmorra desde cualquier borde. Las casillas nuevas se rellenan con el tipo elegido.</p>

				<div class="row gap" style="margin: 10px 0; justify-content: space-between; align-items: center; background: var(--bg-1); padding: 8px 10px; border-radius: var(--radius-sm); border: 1px solid var(--line);">
					<label class="chkline" style="margin: 0; cursor: pointer;">
						<input type="checkbox" v-model="resizeAllFloors"> Aplicar a <b>todas las plantas</b>
					</label>
					<div class="row gap" style="align-items: center;">
						<span class="dim" style="font-size: 11px;">Rellenar con:</span>
						<select v-model="resizeFillTile" style="width: 100px; padding: 2px 6px; font-size: 11px;">
							<option value="void">⬛ Vacío (void)</option>
							<option value="wall">🧱 Pared (wall)</option>
							<option value="floor">⬜ Suelo (floor)</option>
						</select>
					</div>
				</div>

				<div class="resize-body">
					<!-- Controles en cruz -->
					<div class="resize-cross">
						<div class="rc-cell rc-top">
							<span class="rc-lbl">Arriba (Norte)</span>
							<div class="rc-steppers">
								<button class="btn xs" @click="bump('top',-1)">−</button>
								<span class="rc-val" :class="{ pos: resize.top>0, neg: resize.top<0 }">{{ resize.top>0?'+':'' }}{{ resize.top }}</span>
								<button class="btn xs" @click="bump('top',1)">+</button>
							</div>
						</div>
						<div class="rc-mid">
							<div class="rc-cell rc-left">
								<span class="rc-lbl">Izq. (Oeste)</span>
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
								<span class="rc-lbl">Der. (Este)</span>
								<div class="rc-steppers">
									<button class="btn xs" @click="bump('right',-1)">−</button>
									<span class="rc-val" :class="{ pos: resize.right>0, neg: resize.right<0 }">{{ resize.right>0?'+':'' }}{{ resize.right }}</span>
									<button class="btn xs" @click="bump('right',1)">+</button>
								</div>
							</div>
						</div>
						<div class="rc-cell rc-bottom">
							<span class="rc-lbl">Abajo (Sur)</span>
							<div class="rc-steppers">
								<button class="btn xs" @click="bump('bottom',-1)">−</button>
								<span class="rc-val" :class="{ pos: resize.bottom>0, neg: resize.bottom<0 }">{{ resize.bottom>0?'+':'' }}{{ resize.bottom }}</span>
								<button class="btn xs" @click="bump('bottom',1)">+</button>
							</div>
						</div>
					</div>
				</div>
				<div class="resize-summary">
					<span class="mono">{{ currentW }}×{{ currentH }}</span>
					<span>→</span>
					<span class="mono" :class="{ bad: !resizeValid }">{{ newW }}×{{ newH }}</span>
				</div>
				<div v-if="!resizeValid" class="warnbox">⚠️ El tamaño resultante debe estar entre 1×1 y 64×64.</div>
				<div v-else-if="removedNonEmpty>0" class="warnbox">⚠️ Se recortarán <b>{{ removedNonEmpty }}</b> casilla(s) con contenido (no vacías).</div>
				<div v-if="coordShift" class="warnbox">ℹ️ Expandir por arriba/izquierda <b>desplaza las coordenadas</b>. Los puntos de aparición y portales se ajustarán automáticamente.</div>
				<div class="row gap" style="margin-top:14px; justify-content:flex-end">
					<button class="btn ghost" @click="resetResize">Reiniciar</button>
					<button class="btn ghost" @click="showResize=false">Cerrar</button>
					<button class="btn primary" @click="applyResize" :disabled="!resizeValid || !resizeDirty">Aplicar</button>
				</div>
			</div>
		</div>

		<!-- Modal: gestión de la biblioteca de assets (Fase 6) -->
		<ds-modal :open="showAssets" size="md" title="🧩 Biblioteca de assets" @close="showAssets=false">
			<p class="muted">Los assets son casillas ya configuradas para reutilizar como sello del pincel. Los <b>de fábrica</b> vienen incluidos; los tuyos se guardan en este navegador.</p>
			<div class="prop-sep">De fábrica</div>
			<div class="asset-manage">
				<div v-for="a in assets.builtin" :key="a.id" class="asset-manage__row">
					<span class="asset-manage__ico">{{ a.icon }}</span>
					<span class="grow">{{ a.name }}</span>
					<ds-tag :label="a.cell.t" tone="accent"></ds-tag>
					<button class="btn xs" @click="selectAsset(a); showAssets=false">Usar</button>
				</div>
			</div>
			<div class="prop-sep">Mis assets</div>
			<div v-if="!(assets.user && assets.user.length)" class="ds-empty" style="padding:14px"><p>Aún no has guardado assets. Selecciona una casilla y pulsa "Guardar casilla".</p></div>
			<div class="asset-manage">
				<div v-for="a in (assets.user || [])" :key="a.id" class="asset-manage__row">
					<span class="asset-manage__ico">{{ a.icon }}</span>
					<input class="grow" :value="a.name" @change="assets.rename(a.id, $event.target.value)" />
					<ds-tag :label="a.cell.t" tone="accent"></ds-tag>
					<button class="btn xs" @click="selectAsset(a); showAssets=false">Usar</button>
					<button class="btn xs err" @click="assets.remove(a.id)">🗑️</button>
				</div>
			</div>
			<template #footer>
				<button class="btn ghost" @click="showAssets=false">Cerrar</button>
			</template>
		</ds-modal>

		<!-- Task 7, ítem 5.3: modal de confirmación propio (sustituye a window.confirm) -->
		<ds-confirm-dialog :open="confirmDialog.open" title="Confirmar" :message="confirmDialog.message"
			:danger="confirmDialog.danger" confirm-text="Aceptar" cancel-text="Cancelar"
			@confirm="onConfirmDialogConfirm" @cancel="onConfirmDialogCancel"></ds-confirm-dialog>

		<!-- MODO PASEO 3D EN 1ª PERSONA (FASE 3) -->
		<dungeon-walkthrough-modal v-if="dun" :open="walkthroughOpen" :dungeon="dun" :floor-index="floorIdx"
			:dungeon-id="store.selectedDungeon" @close="walkthroughOpen=false"></dungeon-walkthrough-modal>
	</div>
	`;
