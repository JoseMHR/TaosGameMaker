// app.js
// ─────────────────────────────────────────────────────────────────────────────
// Raíz de la SPA. Monta la topbar (proyecto, búsqueda global, guardar), la barra
// lateral de navegación (Modo Diseñador / Modo Datos) y el editor activo. Avisa
// antes de cerrar con cambios sin guardar.
// ─────────────────────────────────────────────────────────────────────────────
import { createApp, computed, ref, onMounted } from 'https://unpkg.com/vue@3/dist/vue.esm-browser.prod.js';
import { store, nav, openProject, reloadAll, save, anyDirty, toggleExpertMode, applyCompact, t, flash } from './store.js';
import { startQaIndexAutoRefresh, refreshQaIndex } from './lib/qaIndex.js';
import { TAB_COMPONENT } from './collections.js';
import { registerDesignSystem } from './ui/index.js';
import DsGallery from './ui/DsGallery.js';
import EditorSidebar from './components/EditorSidebar.js';
import WelcomePanel from './components/WelcomePanel.js';
import GlobalSearch from './components/GlobalSearch.js';
import HelpDrawer from './components/HelpDrawer.js';
import FirstStepsPanel from './components/FirstStepsPanel.js';
import CityWorkspace from './components/CityWorkspace.js';
import MapEditor from './components/MapEditor.js';
import IdsManager from './components/IdsManager.js';
import NpcEditor from './components/NpcEditor.js';
import EnemiesManager from './components/EnemiesManager.js';
import ItemsManager from './components/ItemsManager.js';
import QaPanel from './components/QaPanel.js';
import ProfessionsManager from './components/ProfessionsManager.js';
import DungeonEditor from './components/DungeonEditor.js';
import EventsManager from './components/EventsManager.js';
import ShopsManager from './components/ShopsManager.js';
import SkillsManager from './components/SkillsManager.js';
import EnemySkillsManager from './components/EnemySkillsManager.js';
import SynergiesManager from './components/SynergiesManager.js';
import QuestsManager from './components/QuestsManager.js';
import AmbienceManager from './components/AmbienceManager.js';
import ScenesManager from './components/ScenesManager.js';
import CinematicsManager from './components/CinematicsManager.js';
import AchievementsManager from './components/AchievementsManager.js';
import WorldTransformsManager from './components/WorldTransformsManager.js';
import WorldBuildingsManager from './components/WorldBuildingsManager.js';
import WorldTerrainsManager from './components/WorldTerrainsManager.js';
import WorldResourcesManager from './components/WorldResourcesManager.js';
import DungeonPiecesManager from './components/DungeonPiecesManager.js';
import ConfigManager from './components/ConfigManager.js';
import MediaLibrary from './components/MediaLibrary.js';

const App = {
	components: {
		DsGallery,
		EditorSidebar,
		WelcomePanel,
		GlobalSearch,
		HelpDrawer,
		FirstStepsPanel,
		CityWorkspace,
		MapEditor,
		IdsManager,
		NpcEditor,
		EnemiesManager,
		EnemySkillsManager,
		ItemsManager,
		QaPanel,
		ProfessionsManager,
		DungeonEditor,
		EventsManager,
		ShopsManager,
		SkillsManager,
		SynergiesManager,
		QuestsManager,
		AmbienceManager,
		ScenesManager,
		CinematicsManager,
		AchievementsManager,
		WorldTransformsManager,
		WorldBuildingsManager,
		WorldTerrainsManager,
		WorldResourcesManager,
		DungeonPiecesManager,
		ConfigManager,
		MediaLibrary,
	},
	setup() {
		const galleryOpen = ref(false);
		const stepsOpen = ref(false);

		const dirty = computed(() => anyDirty());
		// Editor activo: se resuelve por el descriptor único (collections.js), no por
		// un switch de v-if. `<keep-alive>` conserva el estado de cada editor ya visitado.
		// 'home' es un caso especial (panel de inicio/onboarding, B5), no una colección.
		const activeComponent = computed(() =>
			store.activeTab === 'home' ? 'WelcomePanel' : (TAB_COMPONENT[store.activeTab] || null));

		function pick() { openProject().then(() => { if (store.loaded) startQaIndexAutoRefresh(); }); }
		async function doSave() { await save(false); refreshQaIndex(); }
		async function doReload() {
			if (dirty.value && !confirm('Hay cambios sin guardar. ¿Recargar desde disco y perderlos?')) return;
			await reloadAll();
			refreshQaIndex();
		}
		function onSidebarAction(action) { if (action === 'qa') nav.qaOpen = true; }

		const runningGodot = ref(false);
		const isDraggingFile = ref(false);

		async function runGodot() {
			runningGodot.value = true;
			try {
				const res = await fetch('/api/godot/run', { method: 'POST' });
				const data = await res.json();
				if (data.ok) {
					flash('🎮 ¡Godot lanzado con éxito!');
				} else {
					flash('⚠️ ' + (data.error || 'No se pudo iniciar Godot'));
				}
			} catch (e) {
				flash('⚠️ Error conectando con el servidor: ' + e.message);
			} finally {
				runningGodot.value = false;
			}
		}

		async function handleDropFiles(files) {
			isDraggingFile.value = false;
			if (!files || !files.length) return;
			for (let i = 0; i < files.length; i++) {
				const file = files[i];
				const name = file.name;
				const lower = name.toLowerCase();
				let kind = 'npc';
				if (lower.startsWith('bg_') || lower.includes('background')) kind = 'bg';
				else if (lower.startsWith('enemy_') || lower.includes('monster')) kind = 'enemy';
				else if (lower.endsWith('.ogg') || lower.endsWith('.wav') || lower.endsWith('.mp3')) {
					kind = lower.includes('sfx') ? 'sfx' : 'music';
				}

				try {
					const buf = await file.arrayBuffer();
					await FS.uploadAsset(kind, name, buf, file.type || 'application/octet-stream');
					flash(`✅ Asset subido a ${kind}: ${name}`);
				} catch (e) {
					flash(`❌ Error subiendo ${name}: ${e.message}`);
				}
			}
		}

		// Conexión automática al arrancar: el servidor ya conoce la ruta, no hay
		// que elegir carpeta. Si falla, la bienvenida muestra el error y reintento.
		// También aplica el modo compacto persistido (Fase 8).
		onMounted(() => {
			applyCompact();
			openProject().then(() => { if (store.loaded) startQaIndexAutoRefresh(); });

			window.addEventListener('dragover', (e) => { e.preventDefault(); isDraggingFile.value = true; });
			window.addEventListener('dragleave', (e) => {
				if (e.clientX <= 0 || e.clientY <= 0) isDraggingFile.value = false;
			});
			window.addEventListener('drop', (e) => {
				e.preventDefault();
				if (e.dataTransfer && e.dataTransfer.files) handleDropFiles(e.dataTransfer.files);
			});
		});

		const langMenuOpen = ref(false);
		const currentLangObj = computed(() =>
			store.supportedLanguages.find(l => l.code === store.currentLang) || store.supportedLanguages[0]);

		function setLang(code) {
			store.currentLang = code;
			langMenuOpen.value = false;
			flash(`🌐 ${currentLangObj.value.code.toUpperCase()} · ${currentLangObj.value.label}`);
		}

		// Atajos globales: Ctrl/Cmd+S guardar, Ctrl/Cmd+K búsqueda global, F1 ayuda, Esc cerrar menús.
		window.addEventListener('keydown', (e) => {
			const k = e.key.toLowerCase();
			if ((e.ctrlKey || e.metaKey) && k === 's') {
				e.preventDefault();
				if (store.loaded) doSave();
			} else if ((e.ctrlKey || e.metaKey) && k === 'k') {
				e.preventDefault();
				if (store.loaded) nav.searchOpen = true;
			} else if (e.key === 'F1') {
				e.preventDefault();
				if (store.loaded) nav.helpOpen = !nav.helpOpen;
			} else if (e.key === 'Escape') {
				if (langMenuOpen.value) langMenuOpen.value = false;
			}
		});

		window.addEventListener('click', (e) => {
			if (langMenuOpen.value && !e.target.closest('.lang-picker-dropdown')) {
				langMenuOpen.value = false;
			}
		});

		return {
			store, nav, dirty, activeComponent, galleryOpen, stepsOpen,
			runningGodot, isDraggingFile, runGodot,
			pick, doSave, doReload, onSidebarAction, toggleExpertMode,
			langMenuOpen, currentLangObj, setLang, t,
		};
	},
	template: `
	<div class="topbar" v-if="store.loaded">
		<div class="brand">{{ t('topbar.brand') }}</div>
		<button class="global-search-trigger" @click="nav.searchOpen=true" title="Búsqueda global (Ctrl+K)">
			<span>🔍 {{ t('topbar.search') }}</span><kbd>Ctrl K</kbd>
		</button>
		<button class="btn ghost sm" :class="{ primary: store.activeTab==='home' }" @click="store.activeTab='home'" title="Panel de inicio (¿qué quieres editar?)">🏠 {{ t('topbar.home') }}</button>
		<button class="btn primary sm godot-run-btn" @click="runGodot" :disabled="runningGodot" title="Lanzar el juego en Godot Engine">
			<span>{{ runningGodot ? t('topbar.starting_godot') : t('topbar.run_godot') }}</span>
		</button>
		<div class="spacer"></div>
		<span class="proj-name">📁 {{ store.projectName }}</span>
		<span v-if="dirty" class="dirty-dot" :title="t('topbar.unsaved')">●</span>
		<button class="btn ghost sm expert-toggle" :class="{ primary: store.expertMode }" @click="toggleExpertMode" :title="store.expertMode ? 'Modo experto: se ven los campos avanzados/opcionales. Clic para volver a Simple.' : 'Modo simple: se ocultan los campos avanzados/opcionales. Clic para ver todo (Experto).'">{{ store.expertMode ? '🧪 ' + t('topbar.expert') : '🙂 ' + t('topbar.simple') }}</button>
		<button class="btn ghost sm" @click="galleryOpen=true" title="Design System (biblioteca de componentes)">🎨 {{ t('topbar.ui_gallery') }}</button>
		<button class="btn ghost sm" :class="{ primary: stepsOpen }" @click="stepsOpen=!stepsOpen" title="Guía de primeros pasos">🚀 {{ t('topbar.first_steps') }}</button>
		<button class="btn ghost sm" :class="{ primary: nav.helpOpen }" @click="nav.helpOpen=!nav.helpOpen" title="Ayuda contextual (F1)">❓ {{ t('topbar.help') }}</button>
		<button class="btn ghost sm" @click="doReload">↻ {{ t('topbar.reload') }}</button>

		<!-- Selector de Idioma Global HUD -->
		<div class="lang-picker-dropdown">
			<button class="btn ghost sm lang-btn" :class="{ open: langMenuOpen }" @click.stop="langMenuOpen = !langMenuOpen" :title="t('topbar.lang_title')">
				<span class="lang-code">{{ currentLangObj.code.toUpperCase() }}</span>
				<span class="lang-caret">▾</span>
			</button>
			<div v-if="langMenuOpen" class="lang-dropdown-menu" @click.stop>
				<div class="lang-dropdown-header">🌐 {{ t('topbar.lang_header') }}</div>
				<div v-for="l in store.supportedLanguages" :key="l.code"
					class="lang-dropdown-item"
					:class="{ active: store.currentLang === l.code }"
					@click="setLang(l.code)">
					<span class="lang-badge mono">{{ l.code.toUpperCase() }}</span>
					<span class="lang-name">{{ l.label }}</span>
				</div>
			</div>
		</div>

		<button class="btn primary" @click="doSave" :disabled="!dirty">💾 {{ t('topbar.save') }}</button>
	</div>

	<!-- Dropzone Universal Overlay -->
	<div v-if="isDraggingFile" class="universal-dropzone-overlay" @dragover.prevent @drop.prevent>
		<div class="universal-dropzone-box card panel">
			<div class="dropzone-icon">📥</div>
			<h2>Arrastra tus archivos aquí</h2>
			<p class="muted">PNG, JPG, WEBP, OGG, WAV se ubicarán automáticamente en assets/</p>
		</div>
	</div>

	<div v-if="store.error" class="errbar">{{ store.error }} <a href="#" @click.prevent="store.error=''">(cerrar)</a></div>

	<!-- Bienvenida / conexión -->
	<div v-if="!store.loaded" class="main">
		<div class="welcome">
			<div class="welcome-logo">🗺️</div>
			<h1>Bienvenido al Editor de Mundos</h1>
			<p>Tu espacio de trabajo para crear y dar forma a cada rincón del juego.</p>
			<div class="panel card">
				<template v-if="store.loading">
					<div class="spinner spinner--lg"></div>
					<p class="muted loading-text" style="margin-top:16px">Espere unos momentos<span class="loading-dots"><span>.</span><span>.</span><span>.</span></span></p>
				</template>
				<template v-else>
					<button class="btn primary" style="font-size:15px; padding:12px 22px" @click="pick">↻ Reintentar conexión</button>
					<p class="muted" style="margin-top:14px">El servidor detecta la ruta automáticamente; no necesitas elegir carpeta.</p>
				</template>
			</div>
			<div v-if="!store.loading && store.error" class="warnbox">
				⚠️ No hay conexión con el servidor. Arráncalo así y recarga:
				<pre class="mono" style="margin:8px 0 0; white-space:pre-wrap">python serve.py        # desde editor
# o:  python editor/serve.py         # desde la raíz
# luego abre  http://localhost:8000/</pre>
			</div>
		</div>
	</div>

	<!-- Contenido: barra lateral de navegación + editor activo (render dinámico
	     derivado de collections.js; keep-alive conserva el estado de cada editor). -->
	<div v-else class="main">
		<editor-sidebar @action="onSidebarAction"></editor-sidebar>
		<div class="content">
			<keep-alive max="5">
				<component :is="activeComponent"></component>
			</keep-alive>
		</div>
	</div>

	<qa-panel :open="nav.qaOpen" @close="nav.qaOpen=false"></qa-panel>
	<ds-gallery :open="galleryOpen" @close="galleryOpen=false"></ds-gallery>
	<global-search :open="nav.searchOpen" @close="nav.searchOpen=false"></global-search>
	<help-drawer :open="nav.helpOpen" @close="nav.helpOpen=false"></help-drawer>
	<first-steps-panel :open="stepsOpen" @close="stepsOpen=false" @open-qa="stepsOpen=false; nav.qaOpen=true"></first-steps-panel>

	<div v-if="store.toast" class="toast">{{ store.toast }}</div>
	`,
};

const app = createApp(App);
registerDesignSystem(app);   // Registra la biblioteca de componentes (Fase 1) globalmente.
app.mount('#app');
