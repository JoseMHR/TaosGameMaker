// ui/DsTree.js
// ─────────────────────────────────────────────────────────────────────────────
// DESIGN SYSTEM · Árbol (Fase 1). Vista de árbol genérica y recursiva a partir de
// nodos { id, label, icon?, color?, children?, badge? }. Expandir/colapsar,
// selección y menú contextual (evento). Base reutilizable para el flujo de
// diálogos de NPCs, el contenido de ciudades, etc.
//
// Props:
//   nodes {Array}          nodos raíz.
//   modelValue {String}    id seleccionado (v-model).
//   defaultExpanded {Boolean}
// Emite: update:modelValue, 'select' (node), 'context' ({ node, event }).
// ─────────────────────────────────────────────────────────────────────────────
import { ref } from 'https://unpkg.com/vue@3/dist/vue.esm-browser.prod.js';

const DsTreeNode = {
	name: 'DsTreeNode',
	props: {
		node: { type: Object, required: true },
		selected: { type: String, default: '' },
		depth: { type: Number, default: 0 },
		defaultExpanded: { type: Boolean, default: true },
	},
	emits: ['select', 'context'],
	setup(props) {
		const open = ref(props.defaultExpanded);
		return { open };
	},
	computed: {
		hasChildren() { return Array.isArray(this.node.children) && this.node.children.length > 0; },
	},
	template: `
	<div class="ds-tree__node">
		<div class="ds-tree__row" :class="{ active: selected === node.id }"
			:style="{ paddingLeft: (8 + depth*14) + 'px', borderLeftColor: node.color || 'transparent' }"
			@click="$emit('select', node)"
			@contextmenu.prevent="$emit('context', { node, event: $event })">
			<button v-if="hasChildren" class="ds-tree__toggle" @click.stop="open = !open">{{ open ? '▾' : '▸' }}</button>
			<span v-else class="ds-tree__toggle ds-tree__toggle--leaf">•</span>
			<span v-if="node.icon" class="ds-tree__icon">{{ node.icon }}</span>
			<span class="ds-tree__label">{{ node.label }}</span>
			<span v-if="node.badge != null" class="ds-badge ds-badge--accent ds-tree__badge">{{ node.badge }}</span>
		</div>
		<div v-if="hasChildren && open" class="ds-tree__children">
			<ds-tree-node v-for="c in node.children" :key="c.id" :node="c" :selected="selected"
				:depth="depth+1" :default-expanded="defaultExpanded"
				@select="$emit('select', $event)" @context="$emit('context', $event)"></ds-tree-node>
		</div>
	</div>
	`,
};
DsTreeNode.components = { DsTreeNode };

export default {
	name: 'DsTree',
	components: { DsTreeNode },
	props: {
		nodes: { type: Array, default: () => [] },
		modelValue: { type: String, default: '' },
		defaultExpanded: { type: Boolean, default: true },
	},
	emits: ['update:modelValue', 'select', 'context'],
	methods: {
		onSelect(node) { this.$emit('update:modelValue', node.id); this.$emit('select', node); },
	},
	template: `
	<div class="ds-tree">
		<ds-tree-node v-for="n in nodes" :key="n.id" :node="n" :selected="modelValue"
			:default-expanded="defaultExpanded"
			@select="onSelect" @context="$emit('context', $event)"></ds-tree-node>
		<div v-if="!nodes.length" class="ds-tree__empty">Árbol vacío.</div>
	</div>
	`,
};
