// lib/dungeonConstants.js
// ─────────────────────────────────────────────────────────────────────────────
// Constantes de mazmorra compartidas entre DungeonEditor.js y
// DungeonWizardModal.js (Task 5, 2.4). Extraídas a un módulo propio para evitar
// un import circular entre ambos ficheros.
// ─────────────────────────────────────────────────────────────────────────────

// Tipos de pared y de suelo (para propiedades de casilla). Son etiquetas
// libres que el runtime interpreta al elegir material/altura.
export const WALL_TYPES = ['', 'stone', 'brick', 'cave', 'wood', 'metal', 'ice'];
export const FLOOR_TEX = ['', 'stone', 'dirt', 'grass', 'sand', 'wood', 'metal', 'tiles', 'lava_rock'];

// Temas de AMBIENTACIÓN visual de mazmorra (GridDungeonStage.gd::THEME_CATALOG).
// Cada opción incluye el nombre CANÓNICO del doc de diseño y, entre paréntesis,
// la clave interna real a la que resuelve (alias, ver `resolve_theme_key` en
// GridDungeonStage.gd) — ambas son válidas en `theme`.
export const ENV_THEME_OPTIONS = [
	{ value: 'temple_sky',  label: 'Templo Celestial (temple_sky)' },
	{ value: 'cave',        label: 'Cueva' },
	{ value: 'snow_forest', label: 'Bosque Nevado (snow_forest)' },
	{ value: 'psychic_path',label: 'Senda Psíquica (psychic_path)' },
	{ value: 'arcanium_lab',label: 'Laboratorio Arcanium' },
	{ value: 'desert_ruins',label: 'Ruinas del Desierto (desert_ruins)' },
	{ value: 'ancient_ruins', label: 'Ruinas Antiguas (legacy)' },
	{ value: 'magma_caldera', label: 'Caldera de Magma' },
	{ value: 'overgrown',    label: 'Cripta Cubierta de Vegetación' },
	{ value: 'fortress',     label: 'Fortaleza' },
	{ value: 'sanctuary',    label: 'Santuario' },
	{ value: 'chrono_temple',label: 'Templo del Tiempo' },
];
// Cielos disponibles en `_build_environment()` (GridDungeonStage.gd). "" = por
// defecto del tema.
export const ENV_SKY_OPTIONS = [
	{ value: '', label: '(automático según tema)' },
	{ value: 'night_sky', label: 'Cielo Nocturno Volumétrico' },
	{ value: 'stars', label: 'Estrellas (limpio)' },
	{ value: 'psychic', label: 'Astral Psíquico' },
];

// Fondos de vacío / foso bajo la planta más baja (GridDungeonStage.gd)
export const ENV_VOID_OPTIONS = [
	{ value: 'none',   label: 'Ninguno (fondo oscuro)' },
	{ value: 'abyss',  label: '🌌 Vacío Real / Abismo Cósmico' },
	{ value: 'lava',   label: '🔥 Mar de Lava' },
	{ value: 'spikes', label: '🦔 Lecho de Pinchos' },
];
