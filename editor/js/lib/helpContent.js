// lib/helpContent.js
// ─────────────────────────────────────────────────────────────────────────────
// AYUDA CONTEXTUAL. Registro de textos de ayuda por pestaña.
// Cada entrada: { summary, tips[], bestPractices[], pitfalls[], examples[{title,
// code?, note?}], shortcuts[{ keys, desc }] }. El panel `HelpDrawer` muestra la
// ayuda de `store.activeTab`; si no hay entrada concreta, usa la genérica. Es
// contenido puro (sin dependencias) para poder ampliarlo sin tocar UI ni lógica.
// ─────────────────────────────────────────────────────────────────────────────

// Atajos globales de la aplicación (siempre visibles en el panel de ayuda).
export const GLOBAL_SHORTCUTS = [
	{ keys: 'Ctrl/Cmd + S', desc: 'Guardar cambios en disco' },
	{ keys: 'Ctrl/Cmd + K', desc: 'Búsqueda global en todo el proyecto' },
	{ keys: 'Ctrl/Cmd + Z / Y', desc: 'Deshacer / rehacer (en editores con historial)' },
];

// Ayuda por pestaña. Amplía este mapa para documentar nuevos editores.
export const HELP = {
	_default: {
		summary: 'Editor de datos del proyecto. Los cambios se guardan en archivos JSON del juego; el motor los lee sin recompilar.',
		tips: [
			'Usa la barra lateral para cambiar de sección (modos Diseñador y Datos).',
			'El punto rojo de la barra superior indica cambios sin guardar.',
			'Marca secciones/entidades como favoritas para volver rápido.',
		],
		shortcuts: [],
	},
	map: {
		summary: 'Pinta el mapamundi por casillas. Cada herramienta tiene su propia selección para no mezclar terreno, recursos y entidades.',
		tips: [
			'Elige una herramienta (seleccionar, mover, terreno, recurso, entidad, borrar, inicio) antes de pintar.',
			'Arrastra para pintar en línea; clic derecho o Ctrl para borrar.',
			'La herramienta "inicio" fija el punto de aparición del protagonista.',
		],
		bestPractices: [
			'Usa "Seleccionar" para inspeccionar sin riesgo de modificar el mapa.',
			'Reubica ciudades/mazmorras con "Mover" en vez de borrar y recolocar (conserva la instancia).',
			'Comprueba el mapa real y el de debug: cada uno tiene su propio inicio.',
		],
		pitfalls: [
			'Colocar una entidad de data/ids/ que ya está en otra casilla: se mueve, no se duplica.',
			'Olvidar marcar el punto de inicio: el jugador aparecería en la casilla por defecto.',
			'Dejar una ciudad sin colocar en el mapa: será inaccesible (lo avisa el QA).',
		],
		examples: [
			{ title: 'Mover una ciudad', note: 'Herramienta ✋ Mover → clic en la ciudad (origen) → clic en la casilla destino.' },
		],
		shortcuts: [{ keys: 'Arrastrar', desc: 'Pintar en línea' }, { keys: 'Ctrl + clic', desc: 'Borrar casilla' }, { keys: 'Esc', desc: 'Cancelar movimiento en curso' }],
	},
	cityWorkspace: {
		summary: 'Vista de trabajo por ciudad: edita la ciudad y sus POIs (tabernas, tiendas, casas) en un mismo lugar.',
		tips: ['Los POIs deben existir en Entidades (data/ids/) y figurar en el content de la ciudad.'],
		shortcuts: [],
	},
	ids: {
		summary: 'Catálogo de entidades del mundo (data/ids/<id>.json, un fichero por entidad): ciudades, mazmorras y puntos de interés con su aspecto visual y contenido.',
		tips: [
			'El tipo lógico (city/poi/dungeon) y el "aspecto en el mundo" (maqueta) se eligen por separado.',
			'Un "gate" bloquea una dirección hasta que se cumple su condición open_when.',
		],
		shortcuts: [],
	},
	dungeons: {
		summary: 'Editor de mazmorras por rejilla: plantas, casillas, entidades y elementos interactivos con estados/IDs.',
		tips: [
			'Guarda casillas configuradas como assets reutilizables (sello del pincel).',
			'Los accionadores (interruptor/placa) enlazan por eid con puertas/compuertas.',
			'Marca el punto de inicio del jugador desde el inspector de casilla.',
			'La decoración (antorcha, cristal, columna…) admite rotación y escala.',
		],
		bestPractices: [
			'Da un eid claro a cada compuerta (p. ej. gate_norte) y refiérela desde su accionador.',
			'Ilumina con antorchas/cristales/hogueras: además de decorar, emiten luz real en el motor.',
			'Añade al menos una planta con suelo y un inicio antes de probar la mazmorra.',
		],
		pitfalls: [
			'Accionador sin objetivos o con un eid inexistente: no abre nada (lo avisa el QA).',
			'Compuerta con eid que ningún accionador acciona: queda bloqueada para siempre.',
			'Repetir un eid en dos elementos: el accionador no sabría a cuál referirse.',
		],
		examples: [
			{ title: 'Palanca que abre una compuerta', note: 'Compuerta: eid=gate_1, estado=closed. Palanca: target { eid: gate_1, action: open }.' },
		],
		shortcuts: [{ keys: 'Supr', desc: 'Vaciar casilla seleccionada' }, { keys: 'Ctrl + Z/Y', desc: 'Deshacer / rehacer' }],
	},
	npcs: {
		summary: 'Editor de diálogos por nodos. Modo Grafo con tarjetas arrastrables o vistas de lista/árbol. Simulador (Play Mode) para probar el flujo.',
		tips: [
			'El nodo de entrada es el primer "message" no referenciado por ningún next.',
			'Anota nodos con color, comentario, marcador o grupo (se guardan en _meta.editor).',
			'Las condiciones usan Godot Expression; enlaza con "next" a otros nodos o a close.',
		],
		bestPractices: [
			'Usa el Play Mode para simular condiciones y recompensas antes de guardar.',
			'Agrupa y colorea ramas largas para leerlas de un vistazo.',
			'Cierra siempre las ramas con un next a otro nodo o a "close".',
		],
		pitfalls: [
			'Nodo sin next ni "close": congela el diálogo (lo avisa el QA).',
			'Nodo inalcanzable desde la entrada: contenido muerto (lo avisa el QA).',
			'Referenciar en condición/recompensa un ítem que no existe en items.json.',
		],
		examples: [
			{ title: 'Opción condicionada', code: 'condition: has_item("banana")', note: 'Solo aparece si el jugador lleva una banana.' },
			{ title: 'Recompensa', code: 'gold:+50;faceta:amabilidad=+1', note: 'Da 50 de oro y sube amabilidad.' },
		],
		shortcuts: [
			{ keys: 'Doble clic', desc: 'Abrir el editor de un nodo (grafo)' },
			{ keys: 'Ctrl + C / V / D', desc: 'Copiar / pegar / duplicar nodos' },
			{ keys: 'Supr', desc: 'Eliminar nodos seleccionados' },
		],
	},
	enemies: { summary: 'Estadísticas base, escalado por nivel, habilidades y botín de cada enemigo.', tips: [], shortcuts: [] },
	items: {
		summary: 'Objetos del juego: nombre, icono, categoría, si es usable y sus efectos.',
		tips: ['Los ítems se obtienen vía tienda, botín, cofre, casilla de mazmorra o recompensa.'],
		bestPractices: ['Da a cada ítem al menos una vía de obtención para que sea alcanzable en juego.'],
		pitfalls: ['Definir un ítem que no se concede por ningún medio: es inobtenible (lo avisa el QA).'],
		shortcuts: [],
	},
	professions: { summary: 'Profesiones y su árbol de habilidades asociadas.', tips: [], shortcuts: [] },
	skills: {
		summary: 'Habilidades: tipo, coste, efectos y requisitos.',
		tips: ['Las habilidades se usan al asignarlas a una profesión o a una sinergia.'],
		bestPractices: ['Vincula cada habilidad a una profesión o sinergia; si no, no es alcanzable.'],
		pitfalls: ['Dejar habilidades sin usar por ninguna profesión ni sinergia (lo avisa el QA).'],
		shortcuts: [],
	},
	synergies: { summary: 'Combos de habilidades: combinaciones de skills que producen un resultado.', tips: [], shortcuts: [] },
	shops: { summary: 'Catálogos de tienda (stock) reutilizables: qué objetos vende y a qué precio.', tips: [], shortcuts: [] },
	events: { summary: 'Misiones y eventos: condición de disparo y acciones (mini-lenguaje de recompensas).', tips: [], shortcuts: [] },
	quests: { summary: 'Orden de estados de quest y disparadores por victoria en combate.', tips: [], shortcuts: [] },
	dialogues: { summary: 'Diálogos planos (no NPC) con avatar, texto y opciones. Se ejecutan como escenas en el Sistema Narrativo.', tips: [], shortcuts: [] },
	scenes: {
		summary: 'Sistema Narrativo unificado: cada ESCENA es un grafo de nodos que representa cualquier situación (conversación, cartel, tutorial, cinemática...). Un solo motor para toda la narrativa.',
		tips: [
			'Elige el tipo de cada nodo por su responsabilidad: say (texto), choice (opciones), state (cambia estado), event (emite evento global), flow (control: goto/call/branch/wait/end).',
			'Separa NARRATIVA de LÓGICA: el texto va en say/choice; las condiciones y efectos en state/event/flow. La escena se lee como un guion.',
			'Reutiliza escenas con un nodo flow "call" (subescena): evita duplicar saludos, despedidas, errores...',
		],
		bestPractices: [
			'Nodos pequeños y de una sola responsabilidad: más reutilizables y fáciles de seguir.',
			'Para desacoplar sistemas, usa nodos "event" (emit) en vez de tocar el mundo directamente: el Mapamundi/Combate deciden si reaccionan.',
			'Marca el nodo de entrada correcto; los nodos "flow: end" cierran la escena o vuelven de una subescena.',
		],
		pitfalls: [
			'Dejar un "next" apuntando a un nodo inexistente: la escena terminará antes de tiempo.',
			'Bucles sin salida entre nodos lógicos (state/event/flow): el motor los corta como salvaguarda.',
			'Poner condiciones en el texto: mantenlas en choice.condition o flow.branch para que el guion quede limpio.',
		],
		examples: [
			{ title: 'Saludo reutilizable', note: 'Crea la escena "merchant_greeting" y llámala desde cualquier NPC con un nodo flow "call".' },
			{ title: 'Abrir la presa', note: 'Un nodo event que emite EVENT_DAM_OPENED; el Mapamundi reacciona transformando el terreno.' },
		],
		shortcuts: [],
	},
	achievements: { summary: 'Logros: condición de desbloqueo y recompensa.', tips: [], shortcuts: [] },
	tutorials: { summary: 'Tutoriales por condición, con sus pasos.', tips: [], shortcuts: [] },
	ambience: { summary: 'Música y clima data-driven por terreno.', tips: [], shortcuts: [] },
	worldTransforms: { summary: 'Transformaciones del mundo (reglas o built-in) aplicadas por eventos.', tips: [], shortcuts: [] },
	config: { summary: 'Parámetros de balance globales (GameConfig los lee con fallback).', tips: [], shortcuts: [] },
};

/** Devuelve la ayuda de una pestaña, con fallback a la genérica. */
export function helpFor(tab) {
	return HELP[tab] || HELP._default;
}
