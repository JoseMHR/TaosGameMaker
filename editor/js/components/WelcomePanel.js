// components/WelcomePanel.js
// ─────────────────────────────────────────────────────────────────────────────
// Panel de INICIO / IDE Hub.
// Presenta los 4 MODOS PRINCIPALES DE JUEGO (Mapamundi, Mazmorras, Combate,
// Novela Visual) + el bloque de Sistemas Globales y Balance.
// ─────────────────────────────────────────────────────────────────────────────
import { computed } from 'https://unpkg.com/vue@3/dist/vue.esm-browser.prod.js';
import { store, t } from '../store.js';
import { GAME_MODES, TAB_META, goTo, getTabLabel } from '../nav.js';

export default {
	name: 'WelcomePanel',
	setup() {
		const mainModes = computed(() => GAME_MODES.filter(m => m.id !== 'common').map(m => ({
			...m,
			tabs: m.tabs.map(key => ({ key, icon: TAB_META[key]?.icon || '📄', label: getTabLabel(key) })).filter(t => t.label),
			stat: getModeStat(m.id),
		})));

		const commonMode = computed(() => {
			const m = GAME_MODES.find(g => g.id === 'common');
			if (!m) return null;
			return {
				...m,
				tabs: m.tabs.map(key => ({ key, icon: TAB_META[key]?.icon || '📄', label: getTabLabel(key) })).filter(t => t.label),
			};
		});

		function getModeStat(modeId) {
			if (modeId === 'world') {
				const w = store.world?.width || 0, h = store.world?.height || 0;
				const terrCount = Object.keys(store.worldTerrains || {}).length;
				return w && h ? t('welcome.stat_cells', { w, h, count: terrCount }) : t('tab.map');
			}
			if (modeId === 'dungeon') {
				const count = Object.keys(store.dungeons || {}).length;
				return t('welcome.stat_dungeons', { count });
			}
			if (modeId === 'combat') {
				const enCount = Object.keys(store.enemies || {}).length;
				const profCount = Object.keys(store.professions || {}).length;
				return t('welcome.stat_combat', { enemies: enCount, classes: profCount });
			}
			if (modeId === 'story') {
				const scCount = Object.keys(store.scenes || {}).length;
				const npcCount = Object.keys(store.npcs || {}).length;
				return t('welcome.stat_story', { scenes: scCount, npcs: npcCount });
			}
			return '';
		}

		return { mainModes, commonMode, goTo, t, getTabLabel };
	},
	template: `
	<div class="manager welcome-ide-hub">
		<div class="ide-hero">
			<div class="ide-hero__badge">{{ t('welcome.hero_badge') }}</div>
			<h1 class="ide-hero__title">{{ t('welcome.hero_title') }}</h1>
		</div>

		<!-- GRID DE LOS 4 MODOS PRINCIPALES DE JUEGO -->
		<div class="ide-modes-grid">
			<article v-for="m in mainModes" :key="m.id" class="ide-mode-card" :style="{ '--mode-color': m.color }">
				<header class="ide-mode-card__header">
					<div class="ide-mode-card__icon-wrap">
						<span class="ide-mode-card__icon">{{ m.icon }}</span>
					</div>
					<div class="ide-mode-card__titles">
						<div class="ide-mode-card__badge-row">
							<span class="ide-mode-badge">{{ m.badge }}</span>
							<span v-if="m.stat" class="ide-mode-stat">{{ m.stat }}</span>
						</div>
						<h2 class="ide-mode-card__title">{{ m.label }}</h2>
					</div>
				</header>

				<p class="ide-mode-card__tagline">{{ m.tagline }}</p>
				<p class="ide-mode-card__desc">{{ m.desc }}</p>

				<div class="ide-mode-card__actions">
					<button class="btn primary ide-mode-btn" @click="goTo(m.primaryTab)">
						<span>{{ t('welcome.open') }} {{ m.shortLabel }}</span>
						<span class="arrow">→</span>
					</button>
				</div>

				<div class="ide-mode-card__subtabs">
					<div class="ide-mode-card__subtabs-title">{{ t('welcome.available_modules') }}</div>
					<div class="ide-mode-chips">
						<button v-for="tItem in m.tabs" :key="tItem.key" class="btn xs ghost ide-chip"
							@click="goTo(tItem.key)" :title="t('welcome.open') + ' ' + tItem.label">
							<span class="ide-chip__ico">{{ tItem.icon || '📄' }}</span>
							<span class="ide-chip__lbl">{{ tItem.label }}</span>
						</button>
					</div>
				</div>
			</article>
		</div>

		<!-- BLOQUE 5: SISTEMAS GLOBALES, PROGRESIÓN Y BALANCE -->
		<section v-if="commonMode" class="ide-common-panel card panel">
			<div class="ide-common-panel__head">
				<div class="ide-common-panel__titles">
					<div class="row gap" style="align-items:center">
						<span class="ide-common-panel__icon">{{ commonMode.icon }}</span>
						<h3 class="sec" style="margin:0">{{ commonMode.label }}</h3>
						<span class="ide-mode-badge" style="background:rgba(16,185,129,0.15); color:#10b981; border:1px solid rgba(16,185,129,0.3)">{{ commonMode.badge }}</span>
					</div>
					<p class="muted" style="margin:4px 0 0 0; font-size:13px">{{ commonMode.desc }}</p>
				</div>
			</div>
			<div class="ide-common-panel__tabs">
				<button v-for="tItem in commonMode.tabs" :key="tItem.key" class="btn ghost ide-common-btn"
					@click="goTo(tItem.key)" :title="t('welcome.open') + ' ' + tItem.label">
					<span class="ide-common-btn__ico">{{ tItem.icon || '📄' }}</span>
					<span class="ide-common-btn__lbl">{{ tItem.label }}</span>
				</button>
			</div>
		</section>
	</div>
	`,
};

