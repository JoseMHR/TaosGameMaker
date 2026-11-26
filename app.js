/**
 * Taos Game Maker — Official Landing Page Application
 * Features:
 * - Full Bilingual Switcher (ES / EN) with LocalStorage persistence
 * - Reactive UI element translation across all sections
 */

const translations = {
  en: {
    // Nav
    "nav-overview": "Overview",
    "nav-getting-started": "Getting Started",
    "nav-architecture": "Architecture",
    "nav-data-formats": "Data Schemas",
    "nav-faq": "FAQ & Licensing",
    "nav-support": "💖 Support",
    "nav-btn-store": "Godot Store",
    "nav-btn-demo": "Play Demo (Free)",
    "nav-btn-engine": "Get Engine (Free)",

    // Hero
    "hero-badge": "Godot 4.3+ • Data-Driven RPG Framework & Local Web Studio",
    "hero-title": "Data-Driven Tactical JRPG Framework & <span class=\"gradient-text\">Local Web Studio</span> for Godot 4",
    "hero-subtitle": "Build deep 3D overworlds, first-person grid dungeon crawlers, turn-based tactical combat, and branching visual novels in Godot 4 without wrestling with spaghetti code. Fully driven by clean JSON databases and 45+ visual web tools.",
    "hero-btn-store": "<span>🏪</span> Godot Asset Store",
    "hero-btn-engine": "<span>⚡</span> GitHub Repository (Free & Open Source)",
    "hero-btn-demo": "<span>🎮</span> Play Demo: Echoes of Truth",
    "hero-btn-guide": "<span>📖</span> Quickstart Guide",
    "video-badge": "🎬 Engine & Web Studio Video Tour",
    "video-caption": "See the Godot 4 framework, 3D overworld, turn-based combat, and local Web Studio in action.",

    // Four Pillars
    "pillars-tag": "Core Engine Architecture",
    "pillars-title": "The Four Pillars of Taos Game Maker",
    "pillars-desc": "A unified engine combining classic RPG genres into a cohesive, production-ready framework built for Godot 4.",
    "pillar-1-title": "3D Overworld & Grid Exploration",
    "pillar-1-desc": "High-performance tile-based overworld system with smooth grid movement, custom terrain biomes (grasslands, deserts, volcanic crags, snowy wastes), dynamic weather systems, fog of war, interactive Points of Interest (POIs), gathering nodes, and seamless city transitions.",
    "pillar-1-tag-1": "3D Tile Coordinates",
    "pillar-1-tag-2": "Dynamic Biomes",
    "pillar-1-tag-3": "Weather & Fog",
    "pillar-1-tag-4": "Resource Gathering",

    "pillar-2-title": "First-Person Grid Dungeon Crawler",
    "pillar-2-desc": "Classic 90-degree step-and-turn first-person dungeon exploration. Procedural and handcrafted modular rooms, interactive dungeon pieces, door gates, loot chests with lock-picking mechanics, hidden traps, atmospheric torch lighting, and boss encounters.",
    "pillar-2-tag-1": "1st-Person Grid Step",
    "pillar-2-tag-2": "Modular Rooms",
    "pillar-2-tag-3": "Trap & Chest Systems",
    "pillar-2-tag-4": "3D Lighting",

    "pillar-3-title": "Turn-Based Tactical RPG Combat",
    "pillar-3-desc": "Full-featured tactical battle engine with initiative queue, dynamic action menus, status effects, damage formulas, skill trees, item inventories, juice animations (screen shake, damage popups, hit flashes), and multi-phase boss mechanics.",
    "pillar-3-tag-1": "Initiative Turn Order",
    "pillar-3-tag-2": "Status & Affinities",
    "pillar-3-tag-3": "Juice FX",
    "pillar-3-tag-4": "Enemy AI Routines",

    "pillar-4-title": "Visual Novel & Branching Narrative",
    "pillar-4-desc": "Expressive narrative engine featuring full-screen character portraits, expression transitions, branching player choices, global flag checks, quest hooks, profession synergy dialogs, and a responsive multi-language localization framework.",
    "pillar-4-tag-1": "Branching Dialog Trees",
    "pillar-4-tag-2": "Character Portraits",
    "pillar-4-tag-3": "Global Story Flags",
    "pillar-4-tag-4": "i18n Multi-Language",

    // How It Works
    "workflow-tag": "Production Workflow",
    "workflow-title": "How It Works: Clean Data, Visual Speed",
    "workflow-desc": "Keep stats, quests, and dialogues in readable JSON files, decoupled from GDScript logic.",
    "step-1-title": "Pure Data-Driven Core",
    "step-1-desc": "Every enemy, item, dialogue, quest, and map cell lives in human-readable JSON files. Zero proprietary binary formats.",
    "step-2-title": "45+ Local Web Studio Tools",
    "step-2-desc": "Run the included zero-dependency Python server. Design worlds, dialogues, and dungeon levels with visual drag-and-drop tools.",
    "step-3-title": "Instant Live Reload in Godot",
    "step-3-desc": "Save in the web editor and test immediately in Godot 4. The engine reloads data definitions on the fly.",
    "step-4-title": "Multiplatform Export Ready",
    "step-4-desc": "Export natively to Windows, Linux, macOS, Android (APK/AAB), and Web (HTML5) with tuned export presets.",
    "studio-tag-1": "Visual Studio Suite",
    "studio-tag-2": "45+ Web Tools",
    "studio-tag-3": "Instant Godot Reload",
    "studio-caption": "Local Web Studio running on Python: visual dungeon map editor, 3D walkthrough preview, entity palette, and real-time JSON sync.",

    // Transmedia
    "transmedia-tag": "Transmedia Showcase",
    "transmedia-title": "Built for Real Games: The Samiria Universe",
    "transmedia-desc": "Taos Game Maker isn't a theoretical prototype. It powers our own playable tactical RPG and fantasy literary franchise.",
    "game-tag": "Playable Demonstration Game",
    "game-desc": "A full tactical JRPG and first-person grid crawler built 100% with Taos Game Maker. Available on Google Play Store for Android, and on itch.io for PC, Windows, macOS, and Linux.",
    "game-btn-playstore": "Google Play Store (Android)",
    "game-btn-itch": "Play on itch.io (PC / Mac)",
    "game-btn-trailer": "🎬 Official Trailer",

    "book-tag": "Dark Fantasy Literary Universe",
    "book-desc": "The dark fantasy novel series that serves as the mythological foundation for the game's lore, ancient spheres, and celestial pantheon. Available worldwide on Amazon in both Spanish and English.",
    "book-btn-web": "Official Site",
    "book-btn-1": "Book 1",
    "book-btn-2": "Book 2",

    // Support & Donation
    "donate-tag": "💖 Community Support",
    "donate-title": "Support Taos Game Maker",
    "donate-desc": "Taos Game Maker is free and open source under the MIT License. If it helps with your project, you can support ongoing maintenance via PayPal.",
    "donate-btn-text": "Donate with PayPal",
    "donate-direct": "Direct Link ↗",

    // CTA
    "cta-title": "Explore Taos Game Maker",
    "cta-desc": "Get the complete Godot 4 framework, all 45+ Web Studio visual tools, starter assets, and multiplatform export presets under the MIT License.",
    "cta-btn-store": "<span>🏪</span> Godot Asset Store",
    "cta-btn-github": "<span>⭐</span> View on GitHub (Free & Open Source)",
    "cta-btn-release": "<span>📦</span> Download Latest Release",

    // Footer
    "footer-legal": "<strong>License & IP Notice:</strong> The Taos Game Maker engine and Web Studio suite are open source under the <strong>MIT License</strong> (free to use, modify, and ship commercial games with attribution). The narrative IP, characters, storyline, and original art of <em>Echoes of Truth</em> & <em>The Lazarus Saga</em> are © 2026 Taos World. All rights reserved.",
    "footer-brand-desc": "Data-driven tactical RPG framework and local web studio for Godot 4.",
    "footer-title-docs": "Documentation",
    "footer-title-products": "Products & Demos",
    "footer-title-community": "Community & Contact",
    "footer-link-getting-started": "Getting Started",
    "footer-link-architecture": "System Architecture",
    "footer-link-data-formats": "JSON Data Schemas",
    "footer-link-faq": "FAQ & Licensing",
    "footer-link-support": "💖 Support & Donate",
    "footer-link-store": "Godot Asset Store (Official)",
    "footer-link-release": "Download Latest Release",
    "footer-link-repo": "GitHub Repository (Free)",
    "footer-link-playstore": "Google Play Store (Android)",
    "footer-link-demo": "Echoes of Truth (itch.io - PC/Mac)",
    "footer-link-video": "Engine Video Tour",
    "footer-link-book": "Official Book Site",
    "footer-link-trailer": "🎬 Game Trailer (Echoes of Truth)",
    "footer-crafted": "Crafted for Godot Engine developers worldwide."
  },

  es: {
    // Nav
    "nav-overview": "Visión General",
    "nav-getting-started": "Primeros Pasos",
    "nav-architecture": "Arquitectura",
    "nav-data-formats": "Esquemas JSON",
    "nav-faq": "FAQ y Licencia",
    "nav-support": "💖 Apoyo",
    "nav-btn-store": "Godot Store",
    "nav-btn-demo": "Jugar Demo (Gratis)",
    "nav-btn-engine": "Descargar Motor",

    // Hero
    "hero-badge": "Godot 4.3+ • Framework RPG Data-Driven y Estudio Web Local",
    "hero-title": "Framework JRPG Táctico Data-Driven y <span class=\"gradient-text\">Estudio Web Local</span> para Godot 4",
    "hero-subtitle": "Crea overworlds 3D, mazmorras en primera persona por casillas, combate táctico por turnos y novelas visuales en Godot 4 sin lidiar con código espagueti. Todo impulsado por bases de datos JSON limpias y 45+ herramientas web visuales.",
    "hero-btn-store": "<span>🏪</span> Godot Asset Store",
    "hero-btn-engine": "<span>⚡</span> Repositorio GitHub (Código Abierto)",
    "hero-btn-demo": "<span>🎮</span> Jugar Demo: Echoes of Truth",
    "hero-btn-guide": "<span>📖</span> Guía de Inicio Rápido",
    "video-badge": "🎬 Tour en Vídeo del Motor y Estudio Web",
    "video-caption": "Descubre el framework para Godot 4, el overworld 3D, el combate táctico y el Estudio Web local en acción.",

    // Four Pillars
    "pillars-tag": "Arquitectura del Motor",
    "pillars-title": "Los Cuatro Pilares de Taos Game Maker",
    "pillars-desc": "Un motor unificado que combina géneros clásicos de rol en un framework sólido y listo para producción en Godot 4.",
    "pillar-1-title": "Overworld 3D y Exploración por Casillas",
    "pillar-1-desc": "Sistema de overworld 3D de alto rendimiento con movimiento suave por casillas, biomas de terreno personalizados (praderas, desiertos, riscos volcánicos, nieves), clima dinámico, niebla de guerra, puntos de interés (POIs), recolección de recursos y transiciones fluidas a ciudades.",
    "pillar-1-tag-1": "Coordenadas 3D",
    "pillar-1-tag-2": "Biomas Dinámicos",
    "pillar-1-tag-3": "Clima y Niebla",
    "pillar-1-tag-4": "Recolección",

    "pillar-2-title": "Mazmorras en 1ª Persona por Casillas",
    "pillar-2-desc": "Exploración clásica de mazmorras en primera persona con giros de 90° paso a paso. Salas modulares artesanales o procedurales, puertas interactivas, cofres con ganzúas, trampas ocultas, antorchas atmosféricas y combates contra jefes.",
    "pillar-2-tag-1": "Giro 90° por Casillas",
    "pillar-2-tag-2": "Salas Modulares",
    "pillar-2-tag-3": "Trampas y Cofres",
    "pillar-2-tag-4": "Iluminación 3D",

    "pillar-3-title": "Combate RPG Táctico por Turnos",
    "pillar-3-desc": "Motor de combate táctico completo con cola de iniciativa ATB, menús de acción dinámicos, estados alterados, fórmulas de daño, árboles de habilidades, inventarios, animaciones juice (temblor de pantalla, números flotantes, destellos) y jefes por fases.",
    "pillar-3-tag-1": "Turnos por Iniciativa",
    "pillar-3-tag-2": "Estados y Afinidades",
    "pillar-3-tag-3": "Efectos Juice",
    "pillar-3-tag-4": "IA Enemiga",

    "pillar-4-title": "Novela Visual y Narrativa Ramificada",
    "pillar-4-desc": "Motor narrativo expresivo con retratos de personajes en alta resolución, cambios de expresión, elecciones del jugador, comprobación de flags globales, ganchos de misiones, diálogos según profesión y sistema multilingüe i18n.",
    "pillar-4-tag-1": "Diálogos Ramificados",
    "pillar-4-tag-2": "Retratos de Personajes",
    "pillar-4-tag-3": "Flags de Historia",
    "pillar-4-tag-4": "Soporte Multilingüe",

    // How It Works
    "workflow-tag": "Flujo de Trabajo",
    "workflow-title": "Cómo Funciona: Datos Limpios, Máxima Rapidez",
    "workflow-desc": "Mantén estadísticas, misiones y diálogos en archivos JSON legibles, desacoplados del código GDScript.",
    "step-1-title": "Núcleo 100% Data-Driven",
    "step-1-desc": "Cada enemigo, objeto, diálogo, misión y casilla de mapa vive en archivos JSON legibles. Sin formatos binarios propietarios.",
    "step-2-title": "45+ Herramientas en el Estudio Web",
    "step-2-desc": "Inicia el servidor local de Python sin dependencias externas. Diseña mundos, diálogos y mazmorras con herramientas visuales.",
    "step-3-title": "Recarga en Caliente en Godot",
    "step-3-desc": "Guarda en el editor web y prueba de inmediato en Godot 4. El motor recarga las definiciones de datos al instante.",
    "step-4-title": "Exportación Multiplataforma Lista",
    "step-4-desc": "Exporta de forma nativa a Windows, Linux, macOS, Android (APK/AAB) y Web (HTML5) con presets configurados.",
    "studio-tag-1": "Suite de Estudio Visual",
    "studio-tag-2": "45+ Herramientas Web",
    "studio-tag-3": "Recarga en Caliente",
    "studio-caption": "Estudio Web local ejecutado con Python: editor visual de mazmorras, vista previa 3D en primera persona, paleta de entidades y sincronización JSON en tiempo real.",

    // Transmedia
    "transmedia-tag": "Universo Transmedia",
    "transmedia-title": "Creado para Juegos Reales: El Universo de Samiria",
    "transmedia-desc": "Taos Game Maker no es un prototipo teórico. Es el motor de nuestro propio RPG táctico jugable y de la saga literaria de fantasía.",
    "game-tag": "Juego de Demostración Completo",
    "game-desc": "Un RPG táctico completo y crawler en primera persona desarrollado al 100% con Taos Game Maker. Disponible oficialmente en Google Play Store para dispositivos Android, y en itch.io para jugar en PC, Windows, macOS y Linux.",
    "game-btn-playstore": "Google Play Store (Android)",
    "game-btn-itch": "Jugar en itch.io (PC / Mac)",
    "game-btn-trailer": "🎬 Tráiler Oficial",

    "book-tag": "Universo Literario de Fantasía Oscura",
    "book-desc": "La saga de novelas de fantasía oscura y ciencia ficción que conforma la base mitológica del juego, las esferas ancestrales y el panteón celestial. Disponible a nivel mundial en Amazon en español e inglés.",
    "book-btn-web": "Web Oficial",
    "book-btn-1": "Libro 1",
    "book-btn-2": "Libro 2",

    // Support & Donation
    "donate-tag": "💖 Apoyo Comunitario",
    "donate-title": "Apoya a Taos Game Maker",
    "donate-desc": "Taos Game Maker es gratuito y de código abierto bajo Licencia MIT. Si te resulta útil en tus proyectos, puedes apoyar su mantenimiento y evolución con una donación voluntaria en PayPal.",
    "donate-btn-text": "Donar con PayPal",
    "donate-direct": "Enlace Directo ↗",

    // CTA
    "cta-title": "Explora Taos Game Maker",
    "cta-desc": "Descarga el framework completo para Godot 4, las 45+ herramientas visuales del Estudio Web, starter assets y presets de exportación bajo Licencia MIT.",
    "cta-btn-store": "<span>🏪</span> Godot Asset Store",
    "cta-btn-github": "<span>⭐</span> Ver en GitHub (Código Abierto)",
    "cta-btn-release": "<span>📦</span> Descargar Última Versión",

    // Footer
    "footer-legal": "<strong>Aviso de Licencia e IP:</strong> El motor Taos Game Maker y el Estudio Web son de código abierto bajo <strong>Licencia MIT</strong> (libres para usar, modificar y comercializar juegos con atribución). La propiedad intelectual narrativa, personajes, historia y arte original de <em>Echoes of Truth</em> y <em>La Saga Lázaro</em> pertenecen a © 2026 Taos World. Todos los derechos reservados.",
    "footer-brand-desc": "Framework RPG táctico data-driven y estudio web local para Godot 4.",
    "footer-title-docs": "Documentación",
    "footer-title-products": "Proyectos y Demos",
    "footer-title-community": "Comunidad y Contacto",
    "footer-link-getting-started": "Primeros Pasos",
    "footer-link-architecture": "Arquitectura del Sistema",
    "footer-link-data-formats": "Esquemas de Datos JSON",
    "footer-link-faq": "FAQ y Licencias",
    "footer-link-support": "💖 Apoyo y Donaciones",
    "footer-link-store": "Godot Asset Store (Oficial)",
    "footer-link-release": "Descargar Última Versión",
    "footer-link-repo": "Repositorio GitHub (Gratis)",
    "footer-link-playstore": "Google Play Store (Android)",
    "footer-link-demo": "Echoes of Truth (itch.io - PC/Mac)",
    "footer-link-video": "Tour en Vídeo del Motor",
    "footer-link-book": "Web Oficial de los Libros",
    "footer-link-trailer": "🎬 Tráiler del Juego (Echoes of Truth)",
    "footer-crafted": "Diseñado para la comunidad de desarrolladores de Godot Engine."
  }
};

// Initial language detection: url param > saved > browser > 'en'
const urlParams = typeof window !== 'undefined' && window.location ? new URLSearchParams(window.location.search) : null;
const langParam = urlParams ? urlParams.get('lang') : null;
let currentLang = (langParam && translations[langParam]) ? langParam : (localStorage.getItem('tgm_lang') || (navigator.language && navigator.language.startsWith('es') ? 'es' : 'en'));

function setLanguage(lang) {
  if (!translations[lang]) return;
  currentLang = lang;
  localStorage.setItem('tgm_lang', lang);
  document.documentElement.setAttribute('lang', lang);

  // Update switcher button active state
  document.querySelectorAll('.lang-btn').forEach(btn => {
    btn.classList.toggle('active', btn.getAttribute('data-lang') === lang);
  });

  const t = translations[lang];

  // Update elements by ID
  for (const [id, value] of Object.entries(t)) {
    const el = document.getElementById(id);
    if (el) {
      if (typeof value === 'string' && value.includes('<')) {
        el.innerHTML = value;
      } else {
        el.textContent = value;
      }
    }
  }

  // Also update data-i18n attributes
  document.querySelectorAll('[data-i18n]').forEach(el => {
    const key = el.getAttribute('data-i18n');
    if (t[key]) {
      if (typeof t[key] === 'string' && t[key].includes('<')) {
        el.innerHTML = t[key];
      } else {
        el.textContent = t[key];
      }
    }
  });

  // Dynamic URLs by language
  const gameTrailer = document.getElementById('game-btn-trailer');
  if (gameTrailer) {
    gameTrailer.href = lang === 'es' ? 'https://youtu.be/xNsCNHatSUI' : 'https://youtu.be/Omau2eJ1cR8';
  }
  const footerTrailer = document.getElementById('footer-link-trailer');
  if (footerTrailer) {
    footerTrailer.href = lang === 'es' ? 'https://youtu.be/xNsCNHatSUI' : 'https://youtu.be/Omau2eJ1cR8';
  }
  const book1 = document.getElementById('book-btn-1');
  if (book1) {
    book1.href = lang === 'es' ? 'https://www.amazon.es/dp/B0HLSQKMR1' : 'https://www.amazon.com/dp/B0HMFQVSF2';
  }
  const book2 = document.getElementById('book-btn-2');
  if (book2) {
    book2.href = lang === 'es' ? 'https://www.amazon.es/dp/B0HLSTMRWC' : 'https://www.amazon.com/dp/B0HMF7GWZD';
  }
}

// Run on page load
document.addEventListener('DOMContentLoaded', () => {
  setLanguage(currentLang);
});
