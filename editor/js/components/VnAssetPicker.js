// components/VnAssetPicker.js
// ─────────────────────────────────────────────────────────────────────────────
// Selector visual de assets para Novela Visual & Narrativa:
//   · kind='portrait' → Retratos de personajes (assets/vn/npcs/ y emojis)
//   · kind='bg'       → Fondos de escenario (assets/vn/bg/)
//   · kind='audio'    → Pistas de música y efectos sonoros con reproductor en vivo
// ─────────────────────────────────────────────────────────────────────────────
import { ref, computed, onMounted } from 'https://unpkg.com/vue@3/dist/vue.esm-browser.prod.js';
import DsSearchInput from '../ui/DsSearchInput.js';
import DsAudioBtn from '../ui/DsAudioBtn.js';

// Catálogo precargado de fondos conocidos (con fallback automático)
const DEFAULT_BGS = [
	// Prólogo & Cinemática Inicial
	{ id: 'bg_intro_1_exodo.png', label: 'Intro (1) — El Gran Éxodo de los Dragones', file: 'bg_intro_1_exodo.png', category: 'intro' },
	{ id: 'bg_intro_2_llegada.png', label: 'Intro (2) — La Llegada del Hombre y la Tregua', file: 'bg_intro_2_llegada.png', category: 'intro' },
	{ id: 'bg_intro_3_barrera.png', label: 'Intro (3) — Las Guerras y el Sacrificio', file: 'bg_intro_3_barrera.png', category: 'intro' },
	{ id: 'bg_intro_4_pacto.png', label: 'Intro (4) — El Último Huevo y el Pacto', file: 'bg_intro_4_pacto.png', category: 'intro' },
	{ id: 'bg_intro_5_traicion.png', label: 'Intro (5) — La Codicia y la Ruptura', file: 'bg_intro_5_traicion.png', category: 'intro' },

	// Finales y Cinemáticas
	{ id: 'bg_ending_a_1.png', label: 'Final A (1) — La Esfera se Deshace', file: 'bg_ending_a_1.png', category: 'finales' },
	{ id: 'bg_ending_a_2.png', label: 'Final A (2) — Hospital con Roxas', file: 'bg_ending_a_2.png', category: 'finales' },
	{ id: 'bg_ending_a_3.png', label: 'Final A (3) — Amanecer en Paz', file: 'bg_ending_a_3.png', category: 'finales' },
	{ id: 'bg_ending_b_1.png', label: 'Final B (1) — La Esfera se Quiebra', file: 'bg_ending_b_1.png', category: 'finales' },
	{ id: 'bg_ending_b_2.png', label: 'Final B (2) — El Espejo y la Mirada', file: 'bg_ending_b_2.png', category: 'finales' },
	{ id: 'bg_ending_b_3.png', label: 'Final B (3) — En la Oscuridad', file: 'bg_ending_b_3.png', category: 'finales' },
	{ id: 'bg_ending_c_1.png', label: 'Final C (1) — El Velo Olvidado', file: 'bg_ending_c_1.png', category: 'finales' },
	{ id: 'bg_ending_c_2.png', label: 'Final C (2) — Rutina y Huellas Borradas', file: 'bg_ending_c_2.png', category: 'finales' },
	{ id: 'bg_ending_c_3.png', label: 'Final C (3) — La Llave Abandonada', file: 'bg_ending_c_3.png', category: 'finales' },
	{ id: 'bg_ending_d_1.png', label: 'Final D (1) — Niebla Helada', file: 'bg_ending_d_1.png', category: 'finales' },
	{ id: 'bg_ending_d_2.png', label: 'Final D (2) — Silencio Blanco', file: 'bg_ending_d_2.png', category: 'finales' },
	{ id: 'bg_ending_d_3.png', label: 'Final D (3) — La Nieve lo Cubre Todo', file: 'bg_ending_d_3.png', category: 'finales' },
	{ id: 'bg_ending_e_1.png', label: 'Final E (1) — La Corona Vacía', file: 'bg_ending_e_1.png', category: 'finales' },
	{ id: 'bg_ending_e_2.png', label: 'Final E (2) — Cenizas en el Viento', file: 'bg_ending_e_2.png', category: 'finales' },
	{ id: 'bg_ending_e_3.png', label: 'Final E (3) — El Trono Solitario', file: 'bg_ending_e_3.png', category: 'finales' },
	{ id: 'bg_ending_f_1.png', label: 'Final F (1) — Detrás del Telón', file: 'bg_ending_f_1.png', category: 'finales' },
	{ id: 'bg_ending_f_2.png', label: 'Final F (2) — El Código del Mundo', file: 'bg_ending_f_2.png', category: 'finales' },
	{ id: 'bg_ending_f_3.png', label: 'Final F (3) — Más Allá de la Esfera', file: 'bg_ending_f_3.png', category: 'finales' },
	{ id: 'bg_ending_temple.png', label: 'Templo del Fin', file: 'bg_ending_temple.png', category: 'finales' },

	// Ciudades / Capitales
	{ id: 'bg_city_sylphrena.png', label: 'Capital Sylphrena (Zona 3)', file: 'bg_city_sylphrena.png', category: 'ciudades' },
	{ id: 'bg_city_celestia.png', label: 'Capital Imperial Celestia (Zona 4)', file: 'bg_city_celestia.png', category: 'ciudades' },
	{ id: 'bg_city_gloriam.png', label: 'Metrópolis de Gloriam (Zona 5)', file: 'bg_city_gloriam.png', category: 'ciudades' },
	{ id: 'bg_city_arcanum.png', label: 'Ciudadela de Arcanum (Zona 6)', file: 'bg_city_arcanum.png', category: 'ciudades' },

	// Sylphrena Edificios & POIs (Zona 3)
	{ id: 'bg_city_sylphrena_taberna.png', label: 'Taberna El Penique Negro', file: 'bg_city_sylphrena_taberna.png', category: 'sylphrena' },
	{ id: 'bg_city_sylphrena_church.png', label: 'Templo de la Luz', file: 'bg_city_sylphrena_church.png', category: 'sylphrena' },
	{ id: 'bg_city_sylphrena_shop.png', label: 'Comercio de Especias', file: 'bg_city_sylphrena_shop.png', category: 'sylphrena' },
	{ id: 'bg_city_sylphrena_herrero.png', label: 'Herrería de Borin', file: 'bg_city_sylphrena_herrero.png', category: 'sylphrena' },
	{ id: 'bg_city_sylphrena_mara.png', label: 'Casa de Mara', file: 'bg_city_sylphrena_mara.png', category: 'sylphrena' },
	{ id: 'bg_city_sylphrena_aldeano.png', label: 'Casa del Aldeano', file: 'bg_city_sylphrena_aldeano.png', category: 'sylphrena' },
	{ id: 'bg_city_sylphrena_board.png', label: 'Tablón de Encargos', file: 'bg_city_sylphrena_board.png', category: 'sylphrena' },
	{ id: 'bg_city_sylphrena_transportista.png', label: 'Puesto del Transportista', file: 'bg_city_sylphrena_transportista.png', category: 'sylphrena' },

	// Celestia Edificios & POIs (Zona 4)
	{ id: 'bg_city_celestia_taberna.png', label: 'Taberna Imperial', file: 'bg_city_celestia_taberna.png', category: 'celestia' },
	{ id: 'bg_city_celestia_shop.png', label: 'El Arcanum (Bazar / Tienda)', file: 'bg_city_celestia_shop.png', category: 'celestia' },
	{ id: 'bg_city_celestia_board.png', label: 'Tablón de Celestia', file: 'bg_city_celestia_board.png', category: 'celestia' },
	{ id: 'bg_city_celestia_transportista.png', label: 'Transportista de Celestia', file: 'bg_city_celestia_transportista.png', category: 'celestia' },
	{ id: 'bg_city_celestia_palace.png', label: 'Salón del Trono Real', file: 'bg_city_celestia_palace.png', category: 'celestia' },
	{ id: 'bg_city_celestia_archmage.png', label: 'Torre del Archimago', file: 'bg_city_celestia_archmage.png', category: 'celestia' },
	{ id: 'bg_city_celestia_sage.png', label: 'Santuario del Sabio', file: 'bg_city_celestia_sage.png', category: 'celestia' },
	{ id: 'bg_city_celestia_crier.png', label: 'Plaza del Pregonero', file: 'bg_city_celestia_crier.png', category: 'celestia' },

	// Gloriam Edificios & Lugares (Zona 5)
	{ id: 'bg_city_gloriam_taberna.png', label: 'Cantina del Espejismo (Taberna)', file: 'bg_city_gloriam_taberna.png', category: 'gloriam' },
	{ id: 'bg_city_gloriam_shop.png', label: 'Bazar de las Especias (Tienda)', file: 'bg_city_gloriam_shop.png', category: 'gloriam' },
	{ id: 'bg_city_gloriam_board.png', label: 'Tablón de Gloriam', file: 'bg_city_gloriam_board.png', category: 'gloriam' },
	{ id: 'bg_city_gloriam_transportista.png', label: 'Transportista del Desierto', file: 'bg_city_gloriam_transportista.png', category: 'gloriam' },
	{ id: 'bg_city_gloriam_oasis.png', label: 'Manantial del Sol (Oasis)', file: 'bg_city_gloriam_oasis.png', category: 'gloriam' },
	{ id: 'bg_city_gloriam_residencia.png', label: 'Casa de la Jequesa', file: 'bg_city_gloriam_residencia.png', category: 'gloriam' },

	// Arcanum Edificios & Lugares (Zona 6)
	{ id: 'bg_city_arcanum_taberna.png', label: 'El Tubo de Escape (Bar / Taberna)', file: 'bg_city_arcanum_taberna.png', category: 'arcanum' },
	{ id: 'bg_city_arcanum_shop.png', label: 'Mercado de Componentes (Tienda)', file: 'bg_city_arcanum_shop.png', category: 'arcanum' },
	{ id: 'bg_city_arcanum_board.png', label: 'Tablón de Arcanum', file: 'bg_city_arcanum_board.png', category: 'arcanum' },
	{ id: 'bg_city_arcanum_transportista.png', label: 'Transportista Arcano', file: 'bg_city_arcanum_transportista.png', category: 'arcanum' },
	{ id: 'bg_city_arcanum_lab.png', label: 'Laboratorio Central (Científicos)', file: 'bg_city_arcanum_lab.png', category: 'arcanum' },
	{ id: 'bg_city_arcanum_chatarra.png', label: 'Taller del Chatarrero', file: 'bg_city_arcanum_chatarra.png', category: 'arcanum' },
	{ id: 'bg_city_arcanum_refugio.png', label: 'Callejón de los Olvidados', file: 'bg_city_arcanum_refugio.png', category: 'arcanum' },

	// Templos de Profesión & Sagrarios
	{ id: 'bg_temple_guerrero.png', label: 'Templo del Sable (Guerrero)', file: 'bg_temple_guerrero.png', category: 'templos' },
	{ id: 'bg_temple_arquero.png', label: 'Templo del Arquero', file: 'bg_temple_arquero.png', category: 'templos' },
	{ id: 'bg_temple_elementalista.png', label: 'Templo Elementalista', file: 'bg_temple_elementalista.png', category: 'templos' },
	{ id: 'bg_temple_psiquico.png', label: 'Templo de la Mente (Psíquico)', file: 'bg_temple_psiquico.png', category: 'templos' },
	{ id: 'bg_temple_sacerdote.png', label: 'Templo del Sacerdote', file: 'bg_temple_sacerdote.png', category: 'templos' },
	{ id: 'bg_temple_tiempo.png', label: 'Templo del Tiempo', file: 'bg_temple_tiempo.png', category: 'templos' },
	{ id: 'bg_temple_guardian.png', label: 'El Guardián del Templo', file: 'bg_temple_guardian.png', category: 'templos' },
	{ id: 'bg_temple_origen.png', label: 'Templo Primordial / Origen', file: 'bg_temple_origen.png', category: 'templos' },

	// POIs Mapamundi - Zona 1 (Yelmo)
	{ id: 'bg_world_poi_yelmo_presa_001.png', label: 'Presa Abandonada (Zona 1)', file: 'bg_world_poi_yelmo_presa_001.png', category: 'mundo' },
	{ id: 'bg_world_poi_yelmo_anciana.png', label: 'Choza de la Anciana (Zona 1)', file: 'bg_world_poi_yelmo_anciana.png', category: 'mundo' },
	{ id: 'bg_world_poi_yelmo_recluso.png', label: 'Choza del Recluso (Zona 1)', file: 'bg_world_poi_yelmo_recluso.png', category: 'mundo' },

	// POIs Mapamundi - Zona 2 (Hielo)
	{ id: 'bg_world_poi_hielo_refugio_01.png', label: 'Refugio junto al Fuego (Zona 2)', file: 'bg_world_poi_hielo_refugio_01.png', category: 'mundo' },
	{ id: 'bg_world_poi_hielo_caravana_02.png', label: 'La Caravana Sepultada (Zona 2)', file: 'bg_world_poi_hielo_caravana_02.png', category: 'mundo' },
	{ id: 'bg_world_poi_hielo_campana_03.png', label: 'La Campana de Hielo (Zona 2)', file: 'bg_world_poi_hielo_campana_03.png', category: 'mundo' },
	{ id: 'bg_world_poi_hielo_cabana_crujiente.png', label: 'Cabaña de las Sombras (Zona 2)', file: 'bg_world_poi_hielo_cabana_crujiente.png', category: 'mundo' },
	{ id: 'bg_world_poi_hielo_altar_olvidado.png', label: 'Altar del Viento Susurrante (Zona 2)', file: 'bg_world_poi_hielo_altar_olvidado.png', category: 'mundo' },
	{ id: 'bg_world_poi_hielo_monolito_runico.png', label: 'Monolito Susurrante (Zona 2)', file: 'bg_world_poi_hielo_monolito_runico.png', category: 'mundo' },

	// POIs Mapamundi - Zona 3 (Pradera)
	{ id: 'bg_world_poi_pradera_buzon.png', label: 'Buzón Solitario (Zona 3)', file: 'bg_world_poi_pradera_buzon.png', category: 'mundo' },
	{ id: 'bg_world_poi_pradera_cantero_01.png', label: 'Choza del Cantero (Zona 3)', file: 'bg_world_poi_pradera_cantero_01.png', category: 'mundo' },
	{ id: 'bg_world_poi_pradera_puente_mono.png', label: 'Puente del Mono (Zona 3)', file: 'bg_world_poi_pradera_puente_mono.png', category: 'mundo' },
	{ id: 'bg_world_poi_pradera_patos.png', label: 'Manifiesto de las Plumas (Zona 3)', file: 'bg_world_poi_pradera_patos.png', category: 'mundo' },
	{ id: 'bg_world_poi_pradera_filosofo_piedra.png', label: 'La Roca Sonriente (Zona 3)', file: 'bg_world_poi_pradera_filosofo_piedra.png', category: 'mundo' },
	{ id: 'bg_world_poi_pradera_estatua_desafio.png', label: 'Torneo de Miradas (Zona 3)', file: 'bg_world_poi_pradera_estatua_desafio.png', category: 'mundo' },
	{ id: 'bg_world_poi_pradera_hombre_sombreros.png', label: 'Lord Sombrerius (Zona 3)', file: 'bg_world_poi_pradera_hombre_sombreros.png', category: 'mundo' },
	{ id: 'bg_world_poi_pradera_mimo_atrapado.png', label: 'Marcel el Silencioso (Zona 3)', file: 'bg_world_poi_pradera_mimo_atrapado.png', category: 'mundo' },
	{ id: 'bg_world_poi_pradera_pollo_mistico.png', label: 'Pollo Oracular (Zona 3)', file: 'bg_world_poi_pradera_pollo_mistico.png', category: 'mundo' },
	{ id: 'bg_world_poi_pradera_vendedor_aire.png', label: 'Barón Von Vapores (Zona 3)', file: 'bg_world_poi_pradera_vendedor_aire.png', category: 'mundo' },

	// POIs Mapamundi - Zona 4 (Celestia)
	{ id: 'bg_world_poi_celestia_puerto.png', label: 'Puerto de Celestia (Zona 4)', file: 'bg_world_poi_celestia_puerto.png', category: 'mundo' },
	{ id: 'bg_world_poi_celestia_tumba_elara.png', label: 'Tumba de la Navegante (Zona 4)', file: 'bg_world_poi_celestia_tumba_elara.png', category: 'mundo' },

	// POIs Mapamundi - Zona 5 (Gloriam / Desierto)
	{ id: 'bg_world_poi_gloriam_puesto_desierto.png', label: 'Puesto de Frascos Vacíos (Zona 5)', file: 'bg_world_poi_gloriam_puesto_desierto.png', category: 'mundo' },
	{ id: 'bg_world_poi_gloriam_campamento.png', label: 'Banquete Furtivo (Zona 5)', file: 'bg_world_poi_gloriam_campamento.png', category: 'mundo' },
	{ id: 'bg_world_poi_gloriam_entrenador_caracoles.png', label: 'Don Velocidad Caracoles (Zona 5)', file: 'bg_world_poi_gloriam_entrenador_caracoles.png', category: 'mundo' },
];

const DEFAULT_PORTRAITS = [
	// Capital Sylphrena
	{ id: 'npc_city_sylphrena_taberna.png', label: 'Grog el Tabernero (Sylphrena)', file: 'npc_city_sylphrena_taberna.png', category: 'sylphrena' },
	{ id: 'npc_city_sylphrena_shop.png', label: 'Mercader Imperial (Sylphrena)', file: 'npc_city_sylphrena_shop.png', category: 'sylphrena' },
	{ id: 'npc_city_sylphrena_church.png', label: 'Sacerdotisa Elaria (Sylphrena)', file: 'npc_city_sylphrena_church.png', category: 'sylphrena' },
	{ id: 'npc_city_sylphrena_mara.png', label: 'Aldeana Mara (Sylphrena)', file: 'npc_city_sylphrena_mara.png', category: 'sylphrena' },
	{ id: 'npc_city_sylphrena_aldeano.png', label: 'Aldeano Despistado (Sylphrena)', file: 'npc_city_sylphrena_aldeano.png', category: 'sylphrena' },
	{ id: 'npc_city_sylphrena_herrero.png', label: 'Herrero Borin (Sylphrena)', file: 'npc_city_sylphrena_herrero.png', category: 'sylphrena' },

	// Capital Celestia
	{ id: 'npc_city_celestia_palace.png', label: 'Rey Aldebarán III (Celestia)', file: 'npc_city_celestia_palace.png', category: 'celestia' },
	{ id: 'npc_city_celestia_archmage.png', label: 'Archimago Vael (Celestia)', file: 'npc_city_celestia_archmage.png', category: 'celestia' },
	{ id: 'npc_city_celestia_sage.png', label: 'La Sabia Investigadora (Celestia)', file: 'npc_city_celestia_sage.png', category: 'celestia' },
	{ id: 'npc_city_celestia_shop.png', label: 'Mercader de Celestia', file: 'npc_city_celestia_shop.png', category: 'celestia' },
	{ id: 'npc_city_celestia_crier.png', label: 'El Pregonero de Celestia', file: 'npc_city_celestia_crier.png', category: 'celestia' },
	{ id: 'npc_city_celestia_taberna.png', label: 'Valerio el Posadero (Celestia)', file: 'npc_city_celestia_taberna.png', category: 'celestia' },

	// Metrópolis Gloriam
	{ id: 'npc_city_gloriam_taberna.png', label: 'Farid el Tabernero (Gloriam)', file: 'npc_city_gloriam_taberna.png', category: 'gloriam' },
	{ id: 'npc_city_gloriam_shop.png', label: 'Zaid el Mercader (Gloriam)', file: 'npc_city_gloriam_shop.png', category: 'gloriam' },
	{ id: 'npc_city_gloriam_oasis.png', label: 'Tariq el Nómada (Gloriam)', file: 'npc_city_gloriam_oasis.png', category: 'gloriam' },
	{ id: 'npc_city_gloriam_residencia.png', label: 'Leyla (Gloriam)', file: 'npc_city_gloriam_residencia.png', category: 'gloriam' },

	// Ciudadela Arcanum
	{ id: 'npc_city_arcanum_taberna.png', label: 'Vex el Camarero (Arcanum)', file: 'npc_city_arcanum_taberna.png', category: 'arcanum' },
	{ id: 'npc_city_arcanum_lab.png', label: 'Dr. Kaelen Científico (Arcanum)', file: 'npc_city_arcanum_lab.png', category: 'arcanum' },
	{ id: 'npc_city_arcanum_chatarra.png', label: 'Brik el Chatarrero (Arcanum)', file: 'npc_city_arcanum_chatarra.png', category: 'arcanum' },
	{ id: 'npc_city_arcanum_refugio.png', label: 'Nox el Vagabundo (Arcanum)', file: 'npc_city_arcanum_refugio.png', category: 'arcanum' },
	{ id: 'npc_city_arcanum_shop.png', label: 'Mercader de Arcanum', file: 'npc_city_arcanum_shop.png', category: 'arcanum' },

	// Templos de Profesión y Sagrarios
	{ id: 'npc_temple_guerrero.png', label: 'Maestro Espadachín (Templo)', file: 'npc_temple_guerrero.png', category: 'templos' },
	{ id: 'npc_temple_arquero.png', label: 'Maestra Arquera (Templo)', file: 'npc_temple_arquero.png', category: 'templos' },
	{ id: 'npc_temple_elementalista.png', label: 'Maestro Elementalista (Templo)', file: 'npc_temple_elementalista.png', category: 'templos' },
	{ id: 'npc_temple_psiquico.png', label: 'Maestro Psíquico (Templo)', file: 'npc_temple_psiquico.png', category: 'templos' },
	{ id: 'npc_temple_sacerdote.png', label: 'Clériga Sanadora (Templo)', file: 'npc_temple_sacerdote.png', category: 'templos' },
	{ id: 'npc_temple_tiempo.png', label: 'Guardián del Tiempo (Templo)', file: 'npc_temple_tiempo.png', category: 'templos' },
	{ id: 'npc_temple_guardian.png', label: 'Guardián del Sagrario', file: 'npc_temple_guardian.png', category: 'templos' },

	// Mapamundi POIs
	{ id: 'npc_world_poi_yelmo_anciana.png', label: 'Anciana del Yelmo (Zona 1)', file: 'npc_world_poi_yelmo_anciana.png', category: 'mundo' },
	{ id: 'npc_world_poi_yelmo_recluso.png', label: 'Recluso de la Cabaña (Zona 1)', file: 'npc_world_poi_yelmo_recluso.png', category: 'mundo' },
	{ id: 'npc_world_poi_hielo_refugio_01.png', label: 'Montañero del Refugio (Zona 2)', file: 'npc_world_poi_hielo_refugio_01.png', category: 'mundo' },
	{ id: 'npc_world_poi_hielo_caravana_02.png', label: 'Superviviente de la Caravana (Zona 2)', file: 'npc_world_poi_hielo_caravana_02.png', category: 'mundo' },
	{ id: 'npc_world_poi_hielo_campana_03.png', label: 'Vigilante de la Campana (Zona 2)', file: 'npc_world_poi_hielo_campana_03.png', category: 'mundo' },
	{ id: 'npc_world_poi_pradera_cantero_01.png', label: 'Grum el Cantero (Zona 3)', file: 'npc_world_poi_pradera_cantero_01.png', category: 'mundo' },
	{ id: 'npc_world_poi_pradera_puente_mono.png', label: 'Mono Guardián (Zona 3)', file: 'npc_world_poi_pradera_puente_mono.png', category: 'mundo' },
	{ id: 'npc_world_poi_celestia_puerto.png', label: 'Capitán del Puerto (Zona 4)', file: 'npc_world_poi_celestia_puerto.png', category: 'mundo' },
	{ id: 'npc_world_poi_celestia_tumba_elara.png', label: 'Espíritu de Elara (Zona 4)', file: 'npc_world_poi_celestia_tumba_elara.png', category: 'mundo' },
	{ id: 'npc_world_poi_celestia_centinela.png', label: 'Centinela Autómata (Zona 4)', file: 'npc_world_poi_celestia_centinela.png', category: 'mundo' },
	{ id: 'npc_world_poi_gloriam_puesto_desierto.png', label: 'Ermitaño de las Dunas (Zona 5)', file: 'npc_world_poi_gloriam_puesto_desierto.png', category: 'mundo' },
];

const EMOJI_PRESETS = [
	'🧙‍♂️', '👑', '⚔️', '🏹', '🔮', '🛡️', '📜', '⛵', '🌅', '🏛️',
	'💎', '🔥', '❄️', '🌿', '🪵', '💰', '🗝️', '❓', '❗', '💬'
];

export default {
	name: 'VnAssetPicker',
	components: { DsSearchInput, DsAudioBtn },
	props: {
		modelValue: { type: String, default: '' },
		kind: { type: String, default: 'portrait' }, // 'portrait' | 'bg' | 'audio' | 'sfx'
		label: { type: String, default: '' },
		placeholder: { type: String, default: 'Seleccionar…' },
	},
	emits: ['update:modelValue', 'change'],
	setup(props, { emit }) {
		const open = ref(false);
		const search = ref('');
		const activeCat = ref('all');
		const customInput = ref('');

		const isBg = computed(() => props.kind === 'bg');
		const isPortrait = computed(() => props.kind === 'portrait');
		const isAudio = computed(() => props.kind === 'audio' || props.kind === 'sfx' || props.kind === 'music');

		const rawCatalog = computed(() => {
			if (isBg.value) return DEFAULT_BGS;
			if (isPortrait.value) return DEFAULT_PORTRAITS;
			return [];
		});

		const categories = computed(() => {
			const set = new Set(['all']);
			rawCatalog.value.forEach(item => { if (item.category) set.add(item.category); });
			return Array.from(set);
		});

		const filteredList = computed(() => {
			const q = search.value.trim().toLowerCase();
			const cat = activeCat.value;
			return rawCatalog.value.filter(item => {
				const matchesCat = cat === 'all' || item.category === cat;
				const matchesQuery = !q || item.label.toLowerCase().includes(q) || item.file.toLowerCase().includes(q);
				return matchesCat && matchesQuery;
			});
		});

		function resolvePreviewUrl(val) {
			if (!val || typeof val !== 'string') return '';
			if (val.startsWith('http://') || val.startsWith('https://') || val.startsWith('/')) return val;
			if (val.startsWith('res://')) return val.replace('res://', '/');
			if (isBg.value) {
				return '/assets/vn/bg/' + val;
			}
			if (isPortrait.value) {
				if (val.endsWith('.png') || val.endsWith('.jpg') || val.endsWith('.webp')) return '/assets/vn/npcs/' + val;
				return ''; // Emoji
			}
			return '';
		}

		const isEmojiVal = computed(() => {
			const v = typeof props.modelValue === 'string' ? props.modelValue : '';
			return isPortrait.value && v.length > 0 && v.length <= 4 && !v.includes('.');
		});

		const currentThumb = computed(() => resolvePreviewUrl(props.modelValue));

		function selectAsset(val) {
			emit('update:modelValue', val);
			emit('change', val);
			open.value = false;
		}

		function applyCustom() {
			if (customInput.value.trim()) {
				selectAsset(customInput.value.trim());
			}
		}

		function openModal() {
			search.value = '';
			activeCat.value = 'all';
			customInput.value = props.modelValue || '';
			open.value = true;
		}

		return {
			open, search, activeCat, customInput,
			isBg, isPortrait, isAudio, isEmojiVal,
			categories, filteredList, currentThumb,
			EMOJI_PRESETS,
			resolvePreviewUrl, selectAsset, applyCustom, openModal,
		};
	},
	template: `
	<div class="vn-asset-picker-wrap">
		<div class="vn-asset-picker-trigger" :class="{ 'is-bg-trigger': isBg }" @click="openModal" :title="'Elegir ' + (label || kind)">
			<div class="vn-asset-picker-preview" :class="{ 'is-bg': isBg }">
				<img v-if="currentThumb" :src="currentThumb" class="vn-asset-picker-img" alt="" />
				<span v-else-if="isEmojiVal" class="vn-asset-picker-emoji">{{ modelValue }}</span>
				<span v-else class="vn-asset-picker-empty-ico">{{ isBg ? '🖼️' : isPortrait ? '👤' : '🔊' }}</span>
			</div>
			<div class="vn-asset-picker-info">
				<span class="vn-asset-picker-val">{{ modelValue || placeholder }}</span>
				<span class="vn-asset-picker-btn-text">Elegir…</span>
			</div>
			<ds-audio-btn v-if="isAudio && modelValue" :src="modelValue" size="xs" style="margin-left:auto"></ds-audio-btn>
		</div>

		<!-- MODAL SELECTOR VISUAL -->
		<div v-if="open" class="modal-backdrop" @click.self="open=false">
			<div class="modal-window vn-asset-modal card panel">
				<div class="modal-head">
					<h3>{{ isBg ? '🖼️ Selector de Fondos de Escena' : isPortrait ? '👤 Selector de Retratos & Personajes' : '🔊 Selector de Audio' }}</h3>
					<button class="btn ghost sm modal-close" @click="open=false">✕</button>
				</div>

				<div class="vn-asset-modal-body">
					<!-- Barra de búsqueda y categorías -->
					<div class="row gap" style="margin-bottom:12px; align-items:center">
						<ds-search-input v-model="search" placeholder="Buscar por nombre o archivo…" style="flex:1"></ds-search-input>
						<div class="cat-picker" style="margin:0">
							<button v-for="c in categories" :key="c" class="btn xs" :class="{ primary: activeCat === c }" @click="activeCat = c">{{ c }}</button>
						</div>
					</div>

					<!-- Emojis rápidos para retratos -->
					<div v-if="isPortrait" class="vn-emoji-row">
						<span class="muted" style="font-size:11px">Emojis rápidos:</span>
						<button v-for="em in EMOJI_PRESETS" :key="em" type="button" class="btn xs ghost vn-emoji-btn"
							@click="selectAsset(em)">{{ em }}</button>
					</div>

					<!-- Grid de tarjetas de assets -->
					<div class="vn-asset-grid scroll">
						<button v-for="item in filteredList" :key="item.id" type="button"
							class="vn-asset-card" :class="{ active: modelValue === item.file }"
							@click="selectAsset(item.file)">
							<div class="vn-asset-card__thumb-wrap" :class="{ 'is-bg': isBg }">
								<img :src="resolvePreviewUrl(item.file)" class="vn-asset-card__img" alt="" loading="lazy" />
							</div>
							<div class="vn-asset-card__title">{{ item.label }}</div>
							<div class="vn-asset-card__file mono">{{ item.file }}</div>
						</button>
					</div>

					<div v-if="!filteredList.length" class="ds-empty" style="padding:24px">
						<p class="muted">No se encontraron assets que coincidan con "{{ search }}".</p>
					</div>

					<!-- Entrada manual personalizada -->
					<div class="vn-custom-input-row">
						<span class="muted" style="font-size:11.5px">O escribe un valor/emoji personalizado:</span>
						<div class="row gap">
							<input class="input sm mono" v-model="customInput" placeholder="nombre_archivo.png o emoji..." style="flex:1" />
							<button class="btn sm primary" @click="applyCustom">Usar personalizado</button>
						</div>
					</div>
				</div>
			</div>
		</div>
	</div>
	`,
};
