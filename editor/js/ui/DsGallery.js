// ui/DsGallery.js
// ─────────────────────────────────────────────────────────────────────────────
// DESIGN SYSTEM · Galería / documentación viva (Fase 1). Muestra cada componente
// de la biblioteca con ejemplos interactivos. Sirve como:
//   1. Verificación visual de que el Design System funciona.
//   2. Referencia para quien construya nuevos editores (qué hay disponible).
// Se abre desde la topbar (botón "🎨 UI"). No edita datos: es 100% inocuo.
// ─────────────────────────────────────────────────────────────────────────────
import { ref, reactive } from 'https://unpkg.com/vue@3/dist/vue.esm-browser.prod.js';

export default {
	name: 'DsGallery',
	props: { open: { type: Boolean, default: false } },
	emits: ['close'],
	setup() {
		const confirmOpen = ref(false);
		const helpOpen = ref(false);
		const ctxOpen = ref(false);
		const ctx = reactive({ x: 0, y: 0 });
		const palette = ref('grs');
		const multi = ref(['fire']);
		const filters = reactive({ tipo: '', elemento: '' });
		const search = ref('');
		const treeSel = ref('n2');
		// Demo de lista virtualizada: 5000 filas renderizadas sin degradar la UI.
		const bigList = Array.from({ length: 5000 }, (_, i) => ({ id: 'row_' + i, label: 'Registro #' + (i + 1) }));

		const terrains = [
			{ value: 'sea', label: 'Mar', color: '#0a2e52' },
			{ value: 'grs', label: 'Pradera', color: '#3f8f43' },
			{ value: 'des', label: 'Desierto', color: '#cbb45e' },
			{ value: 'mnt', label: 'Montaña', color: '#41414a' },
		];
		const elements = [
			{ value: 'fire', label: '🔥 Fuego' }, { value: 'ice', label: '❄️ Hielo' }, { value: 'poison', label: '☠️ Veneno' },
		];
		const tree = [{
			id: 'n1', label: 'Entrada', icon: '💬', color: '#6c8cff', children: [
				{ id: 'n2', label: 'Opción A', icon: '➡️', badge: 2 },
				{ id: 'n3', label: 'Opción B', icon: '➡️', children: [{ id: 'n4', label: 'Respuesta', icon: '🗨️' }] },
			],
		}];
		const help = {
			title: 'Galería del Design System',
			intro: 'Estos componentes son la base de TODOS los editores. Reutilízalos siempre.',
			sections: [{ heading: '¿Para qué sirve?', body: 'Garantiza un lenguaje visual coherente y evita duplicar código.' }],
			tips: ['Reutiliza componentes existentes.', 'Añade ayuda contextual a cada editor.'],
			pitfalls: ['Crear un componente nuevo para un caso que ya cubre el Design System.'],
			shortcuts: [{ keys: 'Ctrl+S', desc: 'Guardar' }, { keys: 'Esc', desc: 'Cerrar diálogos' }],
		};
		const ctxItems = [
			{ label: 'Editar', icon: '✏️' },
			{ label: 'Duplicar', icon: '⧉', shortcut: 'Ctrl+D' },
			{ divider: true },
			{ label: 'Eliminar', icon: '🗑', danger: true },
		];
		function openCtx(e) { ctx.x = e.clientX; ctx.y = e.clientY; ctxOpen.value = true; }

		return { confirmOpen, helpOpen, ctxOpen, ctx, palette, multi, filters, search, treeSel,
			terrains, elements, tree, help, ctxItems, openCtx, bigList };
	},
	template: `
	<ds-modal :open="open" size="xl" title="🎨 Design System · Galería" @close="$emit('close')">
		<div class="ds-gallery">
			<section><h4>Botones</h4>
				<div class="row"><button class="btn primary">Primario</button><button class="btn">Normal</button>
				<button class="btn ghost">Ghost</button><button class="btn danger">Peligro</button>
				<button class="btn sm">Pequeño</button></div>
			</section>

			<section><h4>Tags &amp; Badges</h4>
				<div class="row">
					<ds-tag label="city" icon="🏰" color="#6c8cff"></ds-tag>
					<ds-tag label="fuego" tone="err"></ds-tag>
					<ds-tag label="ok" tone="ok"></ds-tag>
					<ds-tag label="quitable" removable></ds-tag>
					<ds-badge :value="128" tone="accent"></ds-badge>
					<ds-badge value="99+" tone="warn"></ds-badge>
					<ds-badge dot tone="ok"></ds-badge>
				</div>
			</section>

			<section><h4>Búsqueda &amp; Filtros</h4>
				<div class="row" style="max-width:520px">
					<ds-search-input v-model="search" placeholder="Buscar entidad…"></ds-search-input>
				</div>
				<ds-filter-panel :filters="[{key:'tipo',label:'Tipo',options:['city','poi','dungeon']},{key:'elemento',label:'Elemento',options:['fuego','hielo']}]" v-model="filters"></ds-filter-panel>
			</section>

			<section><h4>Cards</h4>
				<div class="ds-gallery__cards">
					<ds-card title="Ciudad Imperial" subtitle="city · 8 edificios" icon="🏰" clickable>
						<template #actions><button class="btn sm ghost">⋯</button></template>
						Fondo, NPCs, tiendas y eventos gestionados aquí.
					</ds-card>
					<ds-card title="Slime" subtitle="enemy · lvl 1-10" icon="👾" selected tone="ok">Débil al fuego.</ds-card>
					<ds-card title="Referencia rota" subtitle="poi" icon="⚠️" tone="err">Falta el NPC vinculado.</ds-card>
				</div>
			</section>

			<section><h4>Paletas</h4>
				<div class="row" style="align-items:flex-start; gap:24px">
					<div style="min-width:180px"><ds-palette :items="terrains" v-model="palette"></ds-palette></div>
					<div style="min-width:180px"><ds-palette :items="elements" v-model="multi" multiple></ds-palette></div>
				</div>
			</section>

			<section><h4>Árbol</h4>
				<div style="max-width:420px"><ds-tree :nodes="tree" v-model="treeSel"></ds-tree></div>
			</section>

			<section><h4>Campos de formulario</h4>
				<div style="max-width:420px">
					<ds-field label="Nombre" hint="Aparece en el juego"><input class="input" placeholder="Ciudad Imperial" /></ds-field>
					<ds-field label="ID" required error="Ya existe ese id"><input class="input" value="city_imperial" /></ds-field>
				</div>
			</section>

			<section><h4>Diálogos &amp; menús</h4>
				<div class="row">
					<button class="btn" @click="confirmOpen = true">Confirmación</button>
					<button class="btn" @click="helpOpen = true">Ayuda</button>
					<button class="btn" @click="openCtx">Clic → menú contextual</button>
				</div>
			</section>

			<section><h4>Breadcrumb</h4>
				<ds-breadcrumb :items="[{label:'Mundo',icon:'🌍'},{label:'Ciudad Imperial',icon:'🏰'},{label:'Taberna',icon:'🍺'}]"></ds-breadcrumb>
			</section>

			<section><h4>Lista virtualizada ({{ bigList.length }} filas)</h4>
				<div style="height:180px; border:1px solid var(--line); border-radius:10px; overflow:hidden">
					<ds-virtual-list :items="bigList" :item-height="30" key-field="id">
						<template #default="{ item, index }">
							<div class="ds-gallery__vrow">{{ index + 1 }}. {{ item.label }}</div>
						</template>
					</ds-virtual-list>
				</div>
			</section>

			<section><h4>Panel dividido redimensionable</h4>
				<div style="height:120px; border:1px solid var(--line); border-radius:10px; overflow:hidden">
					<ds-split-panel persist-key="gallery-demo" :initial="200" :min="120" :min-end="120">
						<template #start><div class="ds-gallery__pane">Arrastra el divisor →</div></template>
						<template #end><div class="ds-gallery__pane">El tamaño se recuerda (localStorage).</div></template>
					</ds-split-panel>
				</div>
			</section>
		</div>

		<ds-confirm-dialog :open="confirmOpen" title="¿Eliminar?" message="Esta acción se puede deshacer con Ctrl+Z." confirm-text="Eliminar" danger @confirm="confirmOpen=false" @cancel="confirmOpen=false"></ds-confirm-dialog>
		<ds-help-dialog :open="helpOpen" :help="help" @close="helpOpen=false"></ds-help-dialog>
		<ds-context-menu :open="ctxOpen" :x="ctx.x" :y="ctx.y" :items="ctxItems" @close="ctxOpen=false"></ds-context-menu>
	</ds-modal>
	`,
};
