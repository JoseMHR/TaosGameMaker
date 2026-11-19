// ui/index.js
// ─────────────────────────────────────────────────────────────────────────────
// DESIGN SYSTEM · Registro central (Fase 1). Punto único que agrupa TODOS los
// componentes reutilizables del editor y los registra GLOBALMENTE en la app Vue,
// de modo que cualquier editor (actual o futuro) pueda usarlos por su etiqueta
// (<ds-card>, <ds-modal>, <ds-palette>…) sin importarlos uno a uno.
//
// Regla del proyecto: todos los nuevos desarrollos DEBEN construirse
// reutilizando estos componentes; nunca duplicar componentes para un caso único.
// ─────────────────────────────────────────────────────────────────────────────
import DsModal from './DsModal.js';
import DsConfirmDialog from './DsConfirmDialog.js';
import DsHelpDialog from './DsHelpDialog.js';
import DsCard from './DsCard.js';
import DsTag from './DsTag.js';
import DsBadge from './DsBadge.js';
import DsToolbar from './DsToolbar.js';
import DsInspector from './DsInspector.js';
import DsSearchInput from './DsSearchInput.js';
import DsFilterPanel from './DsFilterPanel.js';
import DsField from './DsField.js';
import DsEmpty from './DsEmpty.js';
import DsPalette from './DsPalette.js';
import DsContextMenu from './DsContextMenu.js';
import DsSplitPanel from './DsSplitPanel.js';
import DsBreadcrumb from './DsBreadcrumb.js';
import DsTree from './DsTree.js';
import DsVirtualList from './DsVirtualList.js';
import DsAudioBtn from './DsAudioBtn.js';

// Mapa nombre → componente. El nombre kebab-case lo deriva Vue del `name` del
// componente, pero lo registramos explícitamente para dejarlo documentado.
export const DESIGN_SYSTEM = {
	DsModal, DsConfirmDialog, DsHelpDialog,
	DsCard, DsTag, DsBadge,
	DsToolbar, DsInspector, DsSearchInput, DsFilterPanel, DsField, DsEmpty,
	DsPalette, DsContextMenu, DsSplitPanel, DsBreadcrumb, DsTree, DsVirtualList,
	DsAudioBtn,
};

/**
 * Registra globalmente toda la biblioteca en la instancia de la app.
 * @param {import('vue').App} app instancia devuelta por createApp().
 */
export function registerDesignSystem(app) {
	for (const [name, comp] of Object.entries(DESIGN_SYSTEM)) {
		app.component(name, comp);
	}
	return app;
}

export {
	DsModal, DsConfirmDialog, DsHelpDialog,
	DsCard, DsTag, DsBadge,
	DsToolbar, DsInspector, DsSearchInput, DsFilterPanel, DsField, DsEmpty,
	DsPalette, DsContextMenu, DsSplitPanel, DsBreadcrumb, DsTree, DsVirtualList,
	DsAudioBtn,
};
