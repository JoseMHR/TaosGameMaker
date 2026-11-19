# CODEMAP — Mapa de código (autogenerado)

> ⚙️ **Fichero AUTOGENERADO por `tools/gen_codemap.py`. NO editar a mano.**
> Regénералo tras cambios estructurales:  `python tools/gen_codemap.py`
>
> Índice de ALTA SEÑAL para localizar *dónde tocar* sin abrir ficheros enormes.
> Para saltar a un símbolo concreto, busca en `docs/SYMBOLS.tsv` (`symbol · kind · file · line`).

**Totales:** 146 ficheros `.gd` · 73252 líneas · 2387 funciones.

Leyenda: `nombre Lnn` = función en la línea *nn*. `(s)` = static · `_nombre` = privada.

## Autoloads (singletons)

### `AudioManager`  ·  autoload **AudioManager**
`scripts/autoload/AudioManager.gd` · 440 líneas · extends `Node`

GESTOR GLOBAL DE AUDIO — Autoload/Singleton
- **funcs:** `register_music_paths` L207, `has_music_track` L214, `play_music` L221, `push_music` L277, `push_combat_music` L288, `pop_music` L302, `clear_stack` L314, `stop_music` L319
  `register_ambient_paths` L335, `has_ambient_track` L342, `play_ambient_loop` L350, `stop_ambient_loop` L369, `play_sfx` L389, `play_ui` L421, `play_city_music` L426
- **privadas:** `_ready` L149, `_bind_existing_button_sounds` L172, `_on_node_added_for_sound` L180, `_bind_button_sound` L189, `_on_button_hover` L196, `_apply_crossfade` L267, `_on_ambient_finished` L383

### `Design`  ·  autoload **Design**
`scripts/autoload/Design.gd` · 1712 líneas · extends `Node`

Autoload Singleton — CARGADOR DE DISEÑO DATA-DRIVEN.
- **funcs:** `reload` L192, `get_skill_field` L307, `tr_cell_name` L349, `tr_cell_desc` L355, `world_boat_spawn` L364, `world_spawn` L375, `get_id` L438, `has_id` L443
  `id_raw` L448, `get_dungeon_tile` L453, `get_dungeon_tile_render` L459, `id_name` L466, `id_icon` L471, `get_item` L477, `get_item_name` L481, `get_item_desc` L488
  `get_item_icon` L495, `get_item_category` L499, `has_item_def` L503, `get_profession` L514, `get_professions` L520, `get_profession_skills` L529, `get_skill` L545, `has_skill` L549
  `get_enemy_skill` L556, `get_synergy` L567, `get_triple_synergy` L586, `skill_pa_cost` L610, `skill_tag` L624, `get_enemy` L630, `enemy` L634, `has_dungeon_layout` L646
  `get_dungeon_layout` L653, `all_dungeon_ids` L668, `canonical_dungeon_ids` L675, `get_dungeon_display_name` L688, `get_dungeon_total_floors` L697, `is_dungeon_completed` L710, `kit_piece` L747, `kit_pieces` L755
  `kits` L760, `get_terrain_ambience` L767, `get_weather_def` L776, `pick_terrain_weather` L792, `get_zone_at` L810, `get_zone_music_at` L825, `get_terrain_def` L841, `terrain_is_walkable` L847
  `terrain_damage` L854, `terrain_damage_interval` L858, `terrain_speed_mult` L862, `terrain_hazard` L871, `terrain_is_slippery` L877, `terrain_is_blendable` L882, `get_world_resource` L892, `resolve_gather_resource` L903
  `get_world_building` L915, `get_classic_building_style` L925, `get_cinematic` L958, `has_cinematic` L964, `get_scene` L971, `has_scene` L982, `get_achievement` L991, `get_tutorial` L996
  `get_npc` L1010, `has_npc` L1023, `get_quest_secondary` L1033, `get_quest_secondary_stage` L1048, `npc_meta` L1057, `entry_node` L1080, `resolve_poi_encounter` L1126, `eval_condition` L1177
  `has_item` L1214, `no_item` L1217, `has_flag` L1220, `no_flag` L1223, `gflag` L1228, `has_gflag` L1231, `no_gflag` L1236, `discovered` L1242
  `not_discovered` L1247, `has_quest` L1253, `quest_stage` L1258, `quest_done` L1262, `gate_flag` L1268, `is_gate_locked` L1284, `stat` L1295, `rel` L1309
  `visits_of` L1315, `has_prof` L1321, `no_prof` L1326, `has_all_professions` L1330, `defeated` L1336, `hunt_progress` L1343, `apply_reward` L1350, `get_codex_entry` L1585
  `codex_ids` L1591, `codex_total` L1602, `has_event` L1645, `run_event` L1652, `quest_order` L1677, `quest_desc` L1684, `quest_combat_event` L1698, `get_world_transform` L1710
- **privadas:** `_ready` L186, `_validate_loaded_data` L317, `_build_indices` L335, `_load_json` L389, `_load_ids_dir` L410, `_load_dir_collection` L417, `_dungeon_path` L721, `_ensure_dungeon_ids` L724
  `_ensure_dialogues_loaded` L931, `_ensure_scenes_loaded` L944, `_ensure_cinematics_loaded` L951, `_loc_str` L1001, `_apply_token` L1375, `_emit_global_event` L1567, `_check_codex_completion` L1608, `_give_item` L1620
  `_pint` L1627

### `ExplorationSkills`  ·  autoload **ExplorationSkills**
`scripts/autoload/ExplorationSkills.gd` · 239 líneas · extends `Node`

REGISTRO DATA-DRIVEN DE LAS 6 HABILIDADES DE EXPLORACIÓN
- **funcs:** `get_skill` L115, `has_skill` L120, `all_ids` L125, `for_profession` L130, `display_name` L138, `verb` L146, `energy_cost` L151, `cooldown` L156
  `range_of` L161, `mode` L166, `is_unlocked` L189, `grant_session` L196, `begin_exclusive_session` L203, `clear_session` L211, `unlock` L217, `unlock_for_profession` L226
  `unlocked_ids` L234

### `GlobalEvents`  ·  autoload **GlobalEvents**
`scripts/autoload/GlobalEvents.gd` · 152 líneas · extends `Node`

Autoload Singleton — BUS GLOBAL DE EVENTOS.

- **signals:** `event` L31, `theme_changed` L39
- **funcs:** `emit_event` L62, `subscribe` L97, `unsubscribe` L110, `unsubscribe_object` L121, `get_log` L135, `clear_log` L140
- **privadas:** `_record` L149

### `GlobalState`  ·  autoload **GlobalState**
`scripts/autoload/GlobalState.gd` · 2846 líneas · extends `Node`

Singleton Autoload — Estado global del héroe, inventario y misiones.

- **regions:** `DATOS DEL HÉROE` L25, `FACETAS DE PERSONALIDAD (-10 a +10)` L57, `HABILIDADES DE FARMEO` L62, `BUFFS TEMPORALES DE COMIDA (Cocinero)` L67, `6 SLOTS DE EQUIPAMIENTO` L85, `INVENTARIO, MISIONES Y PROFESIÓN` L136, `ESTADO DEL MAPAMUNDI (persistente)` L250, `ENCARGOS (TABLÓN), CONTADORES Y MEMORIA DE NPCs` L290, `PROGRESO OFFLINE  (marca de tiempo del último guardado, en unix segundos)` L311, `CICLO DE VIDA` L319, `GESTIÓN DE XP Y NIVEL` L571, `RECÁLCULO DE ESTADÍSTICAS DERIVADAS Y EQUIPO` L802, `SUMA DE BONUS DE COMBATE DEL EQUIPO` L829, `GESTIÓN DE INVENTARIO` L912, `ALMACÉN DEL COFRE DE LA BASE (persistente — ver task4.md)` L977, `MÉTODOS DE EQUIPAMIENTO` L1070, `HABILIDADES DE FARMEO — Ganancia de XP` L1099, `RECURSOS DESCUBIERTOS / DESBLOQUEO DE LA BASE` L1164, `NIVELES DE CONSTRUCCIÓN — Mejoras (sumidero de oro + recursos)` L1398, `REINICIO DE CARACTERÍSTICAS (sumidero de oro: devuelve los puntos gastados)` L1422, `BOTÍN, RAREZA, FORJA Y RE-FORJA` L1450, `ENCARGOS (TABLÓN)  — repetibles, dan dirección al bucle` L1500, `FACETAS (consultas) Y MEMORIA DE NPCs` L1662, `ENEMIGOS DEL MAPAMUNDI — derrota y reaparición` L1817, `PROGRESO OFFLINE (idle) — al volver tras cerrar la app` L1907, `COCINA, CONSUMIBLES Y COMIDA` L1920, `MAPA — Marcar coordenada como explorada` L1950, `NODOS DE RECOLECCIÓN FINITOS  (reserva limitada + regeneración temporal)` L1958, `SERIALIZACIÓN (GUARDADO / CARGA)` L2404

- **signals:** `state_updated` L14, `leveled_up` L18, `job_leveled_up` L19, `skill_leveled_up` L23
- **funcs:** `grant_food_buff` L76, `has_food_buff` L80, `set_orientation` L388, `toggle_orientation` L403, `reset_for_new_game` L421, `reset_for_test_room` L519, `add_xp` L572, `debug_add_level` L599
  `debug_remove_level` L616, `add_job_xp` L639, `add_xp_to_all_jobs` L672, `add_job_xp_to` L689, `set_profession` L731, `get_profession_progress` L780, `get_profession_level` L796, `get_stat_with_bonuses` L803
  `recalculate_derived_stats` L811, `get_equip_combat` L831, `get_phys_damage` L846, `get_mag_damage` L854, `get_range_damage` L858, `get_speed` L863, `get_phys_defense` L868, `get_mag_defense` L877
  `get_dodge` L883, `get_crit` L890, `get_accuracy` L897, `get_carry_weight` L904, `add_item` L924, `grant_all_game_items` L931, `inventory_slot_cap` L968, `inventory_slot_count` L973
  `chest_slot_count` L985, `move_item_to_chest` L1015, `move_item_from_chest` L1034, `remove_item` L1056, `has_item` L1060, `get_item` L1064, `add_equipment_item` L1079, `equip_resource` L1085
  `equip_item` L1089, `unequip_item` L1093, `add_skill_xp` L1105, `gather_speed_multiplier` L1135, `gather_amount_multiplier` L1151, `discover_resource` L1167, `discover_lore` L1176, `is_lore_discovered` L1184
  `grant_codex_completion_reward` L1199, `is_building_unlocked` L1204, `is_building_built` L1214, `can_afford_building` L1218, `build_building` L1228, `is_shop_item_sold_out` L1243, `record_shop_purchase` L1249, `get_combat_skill_slots` L1264
  `has_any_job_skill_overflow` L1304, `get_active_combat_skills` L1368, `toggle_active_combat_skill` L1378, `building_level` L1401, `is_building_max` L1404, `building_upgrade_cost` L1407, `can_afford_upgrade` L1410, `upgrade_building` L1413
  `get_dummy_idle_xp` L1416, `spent_stat_points` L1424, `can_reset_stats` L1431, `reset_stats` L1436, `roll_rarity` L1455, `roll_equipment_drop` L1459, `grant_loot` L1464, `grant_loot_entries` L1468
  `can_forge` L1472, `forge` L1476, `is_reforgeable` L1480, `reforge_item` L1485, `can_refine` L1490, `refine_item` L1494, `is_encargo_active` L1505, `encargo_count` L1508
  `can_accept_encargo` L1511, `accept_encargo` L1514, `is_encargo_done` L1517, `claim_encargo` L1520, `encargo_effective_xp` L1525, `report_gather` L1529, `report_kill` L1533, `mark_enemy_seen` L1549
  `record_enemy_kill` L1559, `discover_travel_point` L1607, `get_travel_points` L1615, `discover_enemy_reaction` L1630, `report_visit` L1647, `generate_encargo` L1652, `ensure_encargos_for_city` L1656, `get_relation` L1672
  `add_relation` L1680, `get_faceta` L1687, `get_npc_relationship` L1697, `charm_price` L1704, `npc_visit_count` L1711, `mark_npc_visited` L1715, `npc_has_flag` L1723, `set_npc_flag` L1730
  `has_flag` L1744, `has_world_flag` L1748, `set_world_flag` L1752, `get_world_flag_val` L1756, `spawn_boat_at_port` L1761, `world_delta_key` L1789, `record_world_delta` L1798, `is_overworld_enemy_defeated` L1819
  `defeat_overworld_enemy` L1831, `get_world_delta` L1838, `has_world_delta` L1845, `clear_world_delta` L1851, `is_boss_defeated` L1864, `mark_boss_defeated` L1868, `is_chest_opened` L1874, `open_chest` L1881
  `apply_offline_progress` L1910, `cook` L1924, `cook_recipe` L1928, `use_consumable` L1932, `food_restore_values` L1936, `food_preview` L1940, `eat_food` L1944, `mark_explored` L1952
  `get_gather_remaining` L1996, `get_gather_capacity` L2007, `get_base_coord` L2011, `establish_base_at` L2021, `get_campfire_build_spot` L2086, `build_campfire_at` L2103, `get_camp_structure_def` L2140, `has_camp_structure` L2144
  `camp_current_structure_key` L2148, `camp_level_up_cost` L2152, `can_level_up_camp` L2156, `level_up_camp` L2160, `build_camp_structure` L2175, `can_establish_base_at` L2234, `base_territory_size` L2310, `is_within_base_territory` L2323
  `get_buildable_structure_at` L2339, `is_valid_camp_build_spot` L2352, `consume_gather` L2383, `to_dict` L2407, `from_dict` L2494, `get_surrounding_hex_coords` L2816, `has_all_professions_unlocked` L2835
- **privadas:** `_ready` L358, `_unhandled_input` L411, `_grant_job_xp_to_non_active` L703, `_store_active_job_progress` L741, `_don_nadie_progress` L752, `_load_job_progress_for` L759, `_item_counts_toward_cap` L954, `_slot_count_of` L958
  `_transfer_item_entry` L991, `_default_combat_skill_slots` L1336, `_bestiary_entry` L1539, `_progress_hunt_quests` L1591, `_canonical_npc_id` L1663, `_now_unix` L1960, `_node_key` L1964, `_apply_node_regen` L1968
  `_capacity_for` L1989, `_refresh_base_label` L2073, `_parse_delta_key` L2130, `_is_free_camp_cell` L2254, `_find_free_camp_spot` L2283, `_reset_camp_cell` L2367, `_run_save_migrations` L2481, `_serialize_explored` L2740
  `_deserialize_explored_entry` L2767, `_serialize_equipped` L2780, `_serialize_inventory` L2793, `_serialize_inventory_array` L2798

### `Juice`  ·  autoload **Juice**
`scripts/autoload/Juice.gd` · 277 líneas · extends `Node`

SERVICIO DE "JUICE" (game feel) — Autoload/Singleton
- **funcs:** `reduced` L44, `fade_out` L54, `fade_in` L62, `transition` L72, `view_in` L85, `hit_stop` L105, `shake` L123, `flash` L192
  `pop` L209, `damage_number` L226
- **privadas:** `_ready` L31, `_shake_control` L146, `_shake_node2d` L158, `_shake_camera3d` L170

### `Locale`  ·  autoload **Locale**
`scripts/autoload/Locale.gd` · 984 líneas · extends `Node`

Autoload Singleton — Internacionalización (i18n) y ajustes persistentes.

- **signals:** `locale_changed` L12, `audio_changed` L15, `accessibility_changed` L18, `theme_changed` L49
- **funcs:** `t` L112, `pick` L127, `is_supported` L139, `set_locale` L148, `toggle_locale` L159, `set_master_volume` L164, `set_sfx_enabled` L171, `set_reduce_motion` L179
  `set_font_scale` L186, `set_colorblind` L201, `set_text_speed` L208, `set_left_handed` L215, `set_ui_theme_id` L224, `has_key` L967, `translate_cell_name` L971, `translate_cell_desc` L979
- **privadas:** `_ready` L55, `_ensure_main_theme_cjk` L70, `_resolve_fallback` L89, `_apply_font_scale` L194, `_apply_theme_font` L241, `_load_settings` L256, `_save_settings` L273, `_apply_audio` L287
  `_build_table` L299

### `MetaManager`  ·  autoload **MetaManager**
`scripts/autoload/MetaManager.gd` · 109 líneas · extends `Node`

Autoload de META-PROGRESIÓN data-driven:

- **signals:** `achievement_unlocked` L19, `tutorial_step` L21
- **funcs:** `evaluate_all` L42, `is_achievement_unlocked` L74, `tutorial_index` L108
- **privadas:** `_ready` L28, `_on_state_updated` L37, `_evaluate_achievements` L52, `_evaluate_tutorials` L79

### `QuestManager`  ·  autoload **QuestManager**
`scripts/autoload/QuestManager.gd` · 392 líneas · extends `Node`

Autoload Singleton que centraliza toda la lógica de misiones y gating.

- **signals:** `dam_opened` L25, `map_cell_changed` L29, `combat_triggered` L31
- **funcs:** `on_cell_entered` L38, `is_quest_at_least` L53, `set_quest_forward` L74, `open_dam` L113, `handle_choice` L144, `on_combat_victory` L182, `trigger_combat` L242, `request_dialogue` L249
  `request_dialogue_id` L259, `play_cinematic` L270, `run_world_transform` L280, `start_quest` L327, `set_quest_stage` L340, `complete_quest` L349, `fail_quest` L357, `is_quest_active` L365
  `is_quest_completed` L369, `is_quest_failed` L373, `get_quest_stage` L377, `get_active_quest` L382
- **privadas:** `_catch_up_milestones` L87, `_show_animal_disclaimer` L126, `_unlock_monkey_bridge` L231

### `SaveManager`  ·  autoload **SaveManager**
`scripts/autoload/SaveManager.gd` · 177 líneas · extends `Node`

Autoload Singleton — Sistema de guardado y carga de la partida.

- **signals:** `game_saved` L9, `game_loaded` L11
- **funcs:** `has_save` L51, `is_in_dungeon` L56, `save_game` L68, `load_game` L97, `delete_save` L118, `request_autosave` L131
- **privadas:** `_ready` L33, `_await_pending_async_save` L90, `_on_state_updated` L144, `_on_autosave_timeout` L148, `_notification` L172

### `SceneManager`  ·  autoload **SceneManager**
`scripts/autoload/SceneManager.gd` · 282 líneas · extends `Node`

Autoload Singleton — Gestiona la navegación entre vistas sin destruir escenas.

- **signals:** `navigate_to` L10, `view_changed` L13, `tab_switched` L16, `combat_started` L19, `combat_ended` L23
- **funcs:** `is_orb_allowed` L52, `go_to_splash` L73, `go_to_menu` L83, `go_to_world` L97, `go_to_orb_room` L109, `go_to_place` L115, `go_to_city` L122, `go_to_building` L128
  `back_to_city` L137, `go_to_dungeon` L143, `go_to_cook` L152, `go_to_forge` L158, `go_to_shop` L164, `go_to_training` L170, `go_to_encargos` L178, `go_to_transport` L184
  `go_to_view` L190, `switch_tab` L196, `start_combat` L204, `end_combat` L215, `change_view_threaded` L235
- **privadas:** `_ready` L31, `_process` L255, `_finish_threaded_load` L269

### `SceneRunner`  ·  autoload **SceneRunner**
`scripts/autoload/SceneRunner.gd` · 627 líneas · extends `Node`

Autoload Singleton — INTÉRPRETE DEL SISTEMA NARRATIVO.

- **signals:** `say_shown` L34, `choice_shown` L37, `scene_finished` L39, `scene_started` L41
- **funcs:** `acquire_presenter` L58, `release_presenter` L63, `has_external_presenter` L69, `is_presenter` L75, `peek_next_kind` L83, `get_active_scene_id` L133, `is_active` L138, `start_scene` L145
  `start_built_scene` L161, `advance` L195, `choose` L206, `stop` L224, `skip_to_end` L238
- **privadas:** `_check_scene_music` L182, `_skip_flow` L283, `_goto` L327, `_run_flow` L384, `_show_credits` L438, `_wait_then` L451, `_present_say` L466, `_present_choice` L487
  `_choice_key` L497, `_is_option_chosen` L501, `_mark_option_chosen` L511, `_visible_options` L519, `_run_event_node` L539, `_push_scene` L555, `_finish_frame` L577, `_finish_all` L589
  `_top` L598, `_top_id` L601, `_ctx` L604, `_current_node` L607, `_next_of` L612, `_loc` L624

### `TimeManager`  ·  autoload **TimeManager**
`scripts/autoload/TimeManager.gd` · 177 líneas · extends `Node`

Autoload Singleton — RELOJ DEL MUNDO (ciclo día/noche) reutilizable.

- **signals:** `phase_changed` L24, `hour_changed` L27
- **funcs:** `phase` L73, `is_day` L77, `is_night` L81, `get_hour` L85, `get_clock_string` L89, `daylight_factor` L97, `advance_hours` L110, `set_hour` L116
  `set_paused` L122, `full_day_duration_sec` L129
- **privadas:** `_ready` L43, `_sync_from_state` L53, `_process` L59, `_advance` L139, `_emit_transitions` L147, `_hours_per_second` L161, `_day_span_hours` L169, `_phase_for_hour` L174

## Sistemas (scripts/systems)

### `CampStructuresManager`
`scripts/systems/CampStructuresManager.gd` · 144 líneas · extends `RefCounted`

- **regions:** `NIVELES DE CONSTRUCCIÓN DE LA BASE — Mejoras (sumidero de oro + recursos)` L38, `PROGRESIÓN POR NIVELES DEL CAMPAMENTO (evolución en cola)` L93
- **funcs:** `setup` L34, `building_level` L40, `is_building_max` L44, `building_upgrade_cost` L48, `can_afford_upgrade` L59, `upgrade_building` L71, `get_dummy_idle_xp` L84, `get_camp_structure_def` L95
  `has_camp_structure` L102, `camp_current_structure_key` L109, `camp_level_up_cost` L117, `can_level_up_camp` L122, `level_up_camp` L132

### `CookingBuffsManager`
`scripts/systems/CookingBuffsManager.gd` · 166 líneas · extends `RefCounted`

- **regions:** `BUFFS TEMPORALES DE COMIDA` L30, `COCINA — Convertir un ingrediente en un consumible` L44, `CONSUMIBLES — Usar un ítem consumible` L82, `COMIDA (Comestibles) — comer en la Hoguera del campamento` L114
- **funcs:** `setup` L26, `grant_food_buff` L32, `has_food_buff` L39, `cook` L47, `cook_recipe` L61, `use_consumable` L85, `food_restore_values` L117, `food_preview` L132
  `eat_food` L147

### `EncargosManager`
`scripts/systems/EncargosManager.gd` · 225 líneas · extends `RefCounted`
- **funcs:** `setup` L23, `generate_encargo` L60, `ensure_encargos_for_city` L129, `is_encargo_active` L149, `encargo_count` L152, `can_accept_encargo` L155, `accept_encargo` L158, `is_encargo_done` L169
  `claim_encargo` L175, `encargo_effective_xp` L191, `report_gather` L214, `report_kill` L218, `report_visit` L223
- **privadas:** `_load_bounty_templates`(s) L35, `_encargo_signature` L117, `_progress_encargos` L197

### `EnemyDatabase`
`scripts/systems/EnemyDatabase.gd` · 153 líneas

Registro DATA-DRIVEN de enemigos de combate (antes estaban "inline" en ViewDungeon
- **funcs:** `get_enemy_def`(s) L63, `build_enemy`(s) L73
- **privadas:** `_hp_base`(s) L30, `_atk_base`(s) L33, `_def_base`(s) L36, `_procedural_stats`(s) L51, `_copy_loot`(s) L139, `_skills_for_level`(s) L146

### `GameFlagsManager`
`scripts/systems/GameFlagsManager.gd` · 76 líneas · extends `RefCounted`

- **regions:** `FLAGS GLOBALES DATA-DRIVEN` L27, `JEFES DERROTADOS (persistencia anti-reaparición)` L57, `PROFESIONES` L70
- **funcs:** `setup` L24, `has_flag` L30, `has_world_flag` L38, `set_world_flag` L42, `get_world_flag_val` L52, `is_boss_defeated` L60, `mark_boss_defeated` L64, `is_profession_unlocked` L73

### `ItemInventoryManager`
`scripts/systems/ItemInventoryManager.gd` · 272 líneas · extends `RefCounted`

- **regions:** `GESTIÓN DE INVENTARIO` L24, `MÉTODOS DE EQUIPAMIENTO` L107
- **funcs:** `setup` L21, `slot_count` L32, `add_item` L47, `remove_item` L80, `has_item` L92, `get_item` L99, `add_equipment_item` L124, `equip_item` L179
  `equip_resource` L204, `unequip_item` L245
- **privadas:** `_counts_toward_cap` L28, `_rarity_name` L110, `_equip_at_index` L222

### `LootManager`
`scripts/systems/LootManager.gd` · 180 líneas · extends `RefCounted`
- **funcs:** `setup` L22, `roll_rarity` L27, `roll_equipment_drop` L60, `grant_loot` L76, `grant_loot_entries` L83, `can_forge` L121, `forge` L130, `is_reforgeable` L144
  `reforge_item` L154
- **privadas:** `_grant_equipment_from_base` L40

### `ModelLoader`
`scripts/systems/ModelLoader.gd` · 359 líneas · extends `RefCounted`

CARGADOR UNIVERSAL INTELIGENTE DE MODELOS 3D (.tscn, .glb, .gltf, .obj)
- **funcs:** `load_model`(s) L209, `has_model`(s) L249, `resolve_path`(s) L255, `normalize_path`(s) L345, `clear_cache`(s) L357
- **privadas:** `_do_resolve_path`(s) L267, `_check_file_with_extensions`(s) L325

### `OrbBarksManager`  ·  autoload **OrbBarksManager**
`scripts/systems/OrbBarksManager.gd` · 347 líneas · extends `Node`

GESTOR DE FASES Y MENSAJES DE LA ESFERA DE LA VERDAD

- **signals:** `bark_requested` L13, `important_message_requested` L14
- **funcs:** `get_current_phase` L95, `set_phase` L102, `get_small_hint` L115, `trigger_auto_comment` L130, `trigger_bark` L135, `trigger_story_popup` L142, `trigger_bark_key` L147, `trigger_important_message` L159
  `trigger_bark_from_token` L166, `check_overworld_milestones` L174, `trigger_stuck_hint` L244, `reset_stuck_timer` L249, `check_skill_overflow_milestone` L259, `check_trial_completed_milestone` L280
- **privadas:** `_ready` L48, `_load_barks_db` L68, `_process` L80, `_on_state_updated` L253

### `OrbCompanionManager`  ·  autoload **OrbCompanionManager**
`scripts/systems/OrbCompanionManager.gd` · 1698 líneas · extends `Node`

GESTOR DINÁMICO DE DIÁLOGOS Y COMPORTAMIENTO DE LA ESFERA ACOMPAÑANTE

- **signals:** `play_orb_bark` L17
- **funcs:** `trigger_bark` L1359, `play` L1523, `set_cooldown` L1532, `is_on_cooldown` L1537, `notify_step` L1565, `notify_idle` L1622, `on_orb_clicked` L1639, `on_combat_ended` L1672
- **privadas:** `_ready` L1282, `_on_locale_changed` L1294, `_pool` L1301, `_process` L1320, `_get_next_line` L1332, `_init_deck` L1349, `_get_global_state` L1543, `_get_orb_barks_manager` L1550
  `_get_quest_manager` L1557, `_pick_locale` L1627

### `RefineManager`
`scripts/systems/RefineManager.gd` · 156 líneas · extends `RefCounted`
- **funcs:** `setup` L18, `can_refine` L95, `refine_item` L109
- **privadas:** `_find` L24, `_strip_refine_suffix` L33, `_can_afford` L41, `_pay` L50, `_clone` L62, `_add_refined_instance` L82

### `SaveSerializer`
`scripts/systems/SaveSerializer.gd` · 111 líneas
- **funcs:** `migrate_profession`(s) L8, `merge_int_dict`(s) L19, `deserialize_item`(s) L29, `equipment_to_dict`(s) L57, `apply_combat_fields`(s) L78, `dict_to_equipment`(s) L87

### `SceneAdapters`
`scripts/systems/SceneAdapters.gd` · 368 líneas · extends `RefCounted`

ADAPTADORES DEL SISTEMA NARRATIVO.
- **funcs:** `dialogue_to_scene`(s) L28, `interactive_to_scene`(s) L74, `npc_to_scene`(s) L110, `poi_to_scene`(s) L257, `cinematic_to_scene`(s) L300
- **privadas:** `_build_answer_to_menu_map`(s) L206

### `WorldFx`
`scripts/systems/WorldFx.gd` · 208 líneas · extends `RefCounted`

(Game Feel) — helpers de VFX reutilizables para el mundo 3D (mapamundi,
- **funcs:** `punch_scale`(s) L16, `pop_in`(s) L31, `burst`(s) L44, `glow_flash`(s) L74, `harvest_fx`(s) L92, `build_fx`(s) L102, `explosion_fx`(s) L111

### `WorldMapBuilder`
`scripts/systems/WorldMapBuilder.gd` · 744 líneas · extends `RefCounted`

Constructor del MAPAMUNDI (datos) que consume la vista 3D (TabWorld3D).
- **funcs:** `build_into_global`(s) L49, `apply_world_deltas`(s) L425, `apply_delta_to_cell`(s) L450, `apply_transform`(s) L469, `apply_monkey_cleared`(s) L581, `apply_cave_cleared`(s) L599, `apply_dam_opened`(s) L617
- **privadas:** `_make_cell`(s) L175, `_apply_terrain_visual`(s) L270, `_apply_terrain_def`(s) L292, `_apply_grs`(s) L317, `_apply_des`(s) L324, `_apply_ice`(s) L328, `_apply_bad`(s) L333, `_apply_gnd`(s) L337
  `_apply_cst`(s) L342, `_apply_sea`(s) L347, `_apply_mnt`(s) L352, `_apply_lav`(s) L357, `_apply_resource_visual`(s) L366, `_parse_coord_key`(s) L458, `_run_builtin`(s) L479, `_apply_rules`(s) L497
  `_cell_matches`(s) L517, `_apply_set`(s) L542, `_text`(s) L571

## Config (scripts/config)

### `GameConfig`
`scripts/config/GameConfig.gd` · 1139 líneas · extends `RefCounted`
- **funcs:** `xp_needed_for_char_level`(s) L93, `xp_needed_for_job_level`(s) L102, `resource_capacity`(s) L324, `dummy_train_xp`(s) L476, `camp_structures`(s) L516, `block_profile`(s) L574, `offensive_damage`(s) L595, `mitigate`(s) L608
  `heal_amount`(s) L613, `status_def`(s) L632, `status_is_good`(s) L645, `status_incoming_mult`(s) L650, `status_out_mult`(s) L658, `status_atb_mult`(s) L665, `atb_speed_multiplier`(s) L681, `status_crit_add`(s) L685
  `status_dodge_add`(s) L692, `status_any_flag`(s) L699, `get_shop_stock`(s) L784, `rarities`(s) L946, `refine_gold_cost`(s) L1024, `refine_resource_costs`(s) L1029, `get_rarity`(s) L1105, `building_upgrade_gold`(s) L1112
  `all_encargos`(s) L1127, `get_encargo`(s) L1132
- **privadas:** `_load_cfg`(s) L30, `_cf`(s) L40, `_ci`(s) L41, `_cb`(s) L42, `_cs`(s) L43, `_cd`(s) L44, `_merge_camp_structures`(s) L490, `_merge_rarities`(s) L927

### `UiKit`
`scripts/config/UiKit.gd` · 2047 líneas · extends `RefCounted`
- **funcs:** `theme_color`(s) L356, `theme_float`(s) L364, `cjk_fallback_font`(s) L395, `ensure_font_cjk_fallback`(s) L426, `ensure_theme_cjk_fallback`(s) L434, `build_theme_font`(s) L443, `theme_font`(s) L461, `premium_frame`(s) L500
  `get_premium_material`(s) L596, `premium_panel`(s) L625, `premium_dialog_panel`(s) L633, `premium_button`(s) L645, `panel`(s) L689, `neoclassic_panel`(s) L706, `card`(s) L719, `card_tinted`(s) L733
  `dialog_panel`(s) L745, `header`(s) L757, `bar_bg`(s) L768, `bar_fill`(s) L778, `chip`(s) L788, `refine_badge`(s) L800, `with_corner_badge`(s) L823, `button_primary`(s) L839
  `button_ghost`(s) L850, `button_outline`(s) L861, `empty`(s) L872, `heading_font`(s) L886, `apply_heading`(s) L900, `section_title`(s) L908, `style_progress`(s) L920, `style_progress_bordered`(s) L927
  `pop`(s) L937, `bind_press_feedback`(s) L952, `style_segmented_tab`(s) L980, `section_header`(s) L1010, `margins`(s) L1022, `margins_all`(s) L1032, `toast`(s) L1038, `overlay`(s) L1061
  `confirm`(s) L1077, `show_ephemeral_modal`(s) L1141, `check_option_facet_req`(s) L1231, `create_narrative_info_drawer`(s) L1297, `show_item_modal`(s) L1396, `alert`(s) L1470, `rarity_color`(s) L1532, `pill`(s) L1541
  `banner`(s) L1554, `hero_card`(s) L1565, `button_tonal`(s) L1578, `avatar`(s) L1637, `resource_pill`(s) L1642, `strip_emojis`(s) L1661, `load_texture_safe`(s) L1672, `show_stat_toast`(s) L1709
  `animate_in`(s) L1865, `animate_out`(s) L1882, `show_harvest_toast`(s) L1901, `show_profession_unlocked_modal`(s) L1927
- **privadas:** `_ensure_cjk_fallback`(s) L413, `_get_premium_border_shader`(s) L481, `_premium_fallback_style`(s) L609

## Recursos (resources)

### `CellResource`
`resources/definitions/CellResource.gd` · 309 líneas · extends `Resource`

Recurso personalizado que define cualquier casilla del mapamundi.
- **funcs:** `has_stone_path` L40, `set_gather_depleted` L135, `is_gather_depleted` L136, `is_growing_crop` L147, `is_crop_mature` L153, `is_walkable_terrain` L176, `is_gather_node` L184, `gather_skill` L189
  `is_solid` L196, `is_interactive` L211, `is_poi` L223, `opens_view` L249, `derive_legacy` L282

### `DialogueResource`
`resources/definitions/DialogueResource.gd` · 19 líneas · extends `Resource`

Recurso personalizado para diseñar diálogos estilo Novela Visual.

### `EquipmentResource`
`resources/definitions/EquipmentResource.gd` · 80 líneas · extends `Resource`

Recurso personalizado para definir armas, armaduras y accesorios del héroe.
- **funcs:** `active_traits` L51, `get_combat` L61, `refine_multiplier` L71, `effective_stat_bonus` L75, `effective_combat` L79

## Game Root / navegación

### `GameRoot`
`scenes/game/game_root/GameRoot.gd` · 2615 líneas · extends `Control`

Escena principal del juego — contiene HUD, ViewStack y TabBar.
- **funcs:** `is_radial_menu_open` L1703, `open_hub_modal_tab` L1779, `open_character_subtab` L1785, `refresh_hud_location_title` L1950
- **privadas:** `_ready` L112, `_on_hud_theme_changed` L159, `_set_hud_panel_visible` L177, `_update_radial_button_visibility` L186, `_update_responsive_layout` L196, `_setup_redesigned_hud` L342, `_apply_hud_scale` L573, `_build_floating_radial_button` L621
  `_style_floating_radial_button` L659, `_build_floating_map_button` L684, `_style_floating_map_button` L724, `_build_hud_profession_modal` L748, `_setup_hud_profession_modal` L815, `_open_hud_profession_modal` L907, `_on_hud_profession_selected` L927, `_instantiate_views` L934
  `_connect_signals` L975, `_on_achievement_unlocked` L1017, `_on_tutorial_step` L1026, `_on_leveled_up` L1034, `_on_job_leveled_up` L1041, `_on_skill_leveled_up` L1053, `_announce_levelup` L1081, `_flush_pending_levelup_toasts` L1092
  `_show_levelup_flow` L1102, `_profession_name_str` L1172, `_on_game_saved` L1180, `_show_meta_toast` L1194, `_on_navigate_to` L1268, `_on_tab_switched` L1413, `_enter_orb_room` L1439, `_on_orb_finished` L1452
  `_on_dam_opened` L1479, `_run_dam_cinematic` L1489, `_recreate_world_view` L1514, `_flash_transition` L1534, `_on_combat_started` L1546, `_on_combat_ended` L1567, `_input` L1595, `_shortcut_input` L1607
  `_unhandled_key_input` L1611, `_is_radial_hotkey` L1615, `_handle_global_hotkeys` L1637, `_toggle_radial_menu` L1707, `_on_radial_menu_closed` L1719, `_get_or_create_hub_modal` L1735, `_on_hub_modal_closed` L1745, `_on_hub_wants_standalone_options` L1753
  `_on_radial_action_selected` L1759, `_toggle_floating_view` L1792, `_handle_escape_key` L1813, `_show_view` L1893, `_update_hud_center_and_right_slots` L1954, `_build_location_bar` L2030, `_update_location_bar` L2071, `_location_title` L2080
  `_build_hazard_bar` L2089, `_process` L2136, `_hazard_fill_mult` L2161, `_refresh_hazard_bar` L2175, `_player_died_from_hazard` L2191, `_refresh_hud` L2213, `_start_hud_hp_danger` L2283, `_stop_hud_hp_danger` L2294
  `_refresh_materials_row` L2304, `_hero_symbol` L2362, `_profession_label` L2370, `_refresh_tab_texts` L2378, `_on_locale_changed` L2400, `_set_world_modal` L2411, `_open_menu` L2427, `_close_menu` L2441
  `_on_return_to_main_menu` L2449, `_set_active_tab` L2480, `_on_passive_timer_timeout` L2520, `_on_btn_close_cs_pressed` L2530, `_check_offline_progress` L2537, `_show_offline_popup` L2545, `_format_offline_time` L2601, `_res_display` L2610

## Tabs (pestañas inferiores)

### `TabBag`
`scenes/tabs/tab_bag/TabBag.gd` · 894 líneas · extends `Control`

Controlador de la pestaña de la Bolsa/Inventario.
- **privadas:** `_ready` L40, `_update_responsive_layout` L58, `_build_shell` L160, `_refresh_v_catbar` L238, `_is_inside_hub` L279, `_on_close_pressed` L291, `_refresh_ui` L301, `_on_locale_changed` L314
  `_switch_category` L324, `_active_includes` L330, `_is_bag_usable` L341, `_render_inventory` L360, `_make_item_card` L419, `_enable_drag_scroll` L637, `_get_item_bonuses_text` L654, `_columns_for_width` L686
  `_use_consumable` L696, `_use_important_item` L716, `_inspect_equipment` L739

### `TabCharacter`
`scenes/tabs/tab_character/TabCharacter.gd` · 1798 líneas · extends `Control`

Controlador de la Ficha de Personaje. Muestra Stats + Facetas en una única
- **privadas:** `_ready` L72, `_build_shell` L96, `_refresh_v_sidebar` L164, `_on_close_pressed` L195, `_update_responsive_layout` L205, `_subtab_defs` L295, `_switch_subtab` L307, `_on_locale_changed` L313
  `_refresh` L321, `_restore_scroll_vertical` L342, `_build_unified_3col` L350, `_ignore_mouse_recursive` L385, `_enable_drag_scroll` L393, `_new_scroll_host` L411, `_hero_symbol` L436, `_profession_texture` L450
  `_profession_icon` L457, `_profession_name` L464, `_profession_color` L472, `_hsep` L480, `_labeled_bar` L485, `_pending_points_total` L509, `_remaining_stat_points` L517, `_build_points_banner` L528
  `_build_stats` L606, `_accordion_section` L644, `_build_core_section` L671, `_build_combat_section` L684, `_build_professions_section` L696, `_build_oficios_section` L701, `_simulated_stat` L705, `_derived_list` L710
  `_build_professions_summary` L788, `_make_profession_summary_row` L829, `_make_profession_summary_card` L885, `_make_core_stat_card` L940, `_make_reset_button` L1058, `_confirm_pending_stat_alloc` L1101, `_show_reset_confirm` L1118, `_make_derived_card` L1133
  `_build_dungeon_skills` L1193, `_build_exploration_skill_card` L1201, `_build_facetas` L1256, `_make_facet_card` L1275, `_make_center_bar` L1330, `_build_oficio` L1382, `_oficios` L1438, `_make_skill_card` L1451
  `_build_profesiones` L1513, `_two_column_grid` L1559, `_make_profession_icon_button` L1575, `_make_profession_activate_button` L1621, `_make_technique_card` L1686

### `TabEquip`
`scenes/tabs/tab_equip/TabEquip.gd` · 504 líneas · extends `Control`

Pestaña de Equipo del Hub de Personaje — Diseño en 2 columnas:
- **privadas:** `_ready` L15, `_build_ui` L26, `_enable_drag_scroll` L94, `_refresh` L110, `_equip_slots` L150, `_make_slot_button` L162, `_build_equip_alternatives` L271, `_make_equip_option_card` L354
  `_equip_deltas` L431, `_equip_values` L450, `_delta_chip` L466, `_stat_short_label` L484, `_get_bonuses_text` L498

### `TabInfo`
`scenes/tabs/tab_info/TabInfo.gd` · 216 líneas · extends `Control`

PANTALLA INFORMACIÓN — vista de pestaña (como Personaje y Bolsa), NO un modal.
- **privadas:** `_ready` L30, `_update_responsive_layout` L46, `_build_ui` L75, `_make_nav_button` L138, `_select_section` L169, `_render_detail` L185, `_section_by_key` L200, `_on_visibility_changed` L209
  `_on_locale_changed` L214

### `TabProfessions`
`scenes/tabs/tab_professions/TabProfessions.gd` · 955 líneas · extends `Control`

Vista dedicada a la gestión de Profesiones y asignación de 4 Habilidades de Combate.
- **privadas:** `_ready` L44, `_build_ui` L57, `_enable_drag_scroll` L224, `_refresh` L240, `_render_prof_list` L252, `_ignore_mouse_recursive` L455, `_render_active_slots` L462, `_render_catalog` L537
  `_render_upcoming` L656, `_assign_skill` L729, `_on_activate_pressed` L758, `_render_oficios_list` L764, `_show_skill_info_modal` L876

### `TabWorld3D`
`scenes/tabs/tab_world_3d/TabWorld3D.gd` · 5326 líneas · extends `Control`

PROTOTIPO V2 DEL MAPAMUNDI — Entorno 3D con cámara top-down.

- **regions:** `CICLO DE VIDA` L588, `CONSTRUCCIÓN DE LA ESCENA 3D (SubViewport + cámara + luz + jugador)` L1183, `CONSTRUCCIÓN DE CASILLAS 3D` L1652, `NIEBLA DE GUERRA — aplicada a materiales (oculto / penumbra / visible)` L3286, `PATHFINDING Y GATING` L3291, `INPUT — MOVIMIENTO LIBRE (joystick táctil + teclado) y botón ENTRAR` L3448, `BARCO — navegación por costa/mar (ver GlobalState.boat_pos/is_sailing)` L3580, `CICLO DÍA / NOCHE — ILUMINACIÓN (consume TimeManager.daylight_factor())` L4004, `DAÑO AMBIENTAL POR TERRENO (data-driven: data/world_terrains/<code>.json)` L4014, `RELOJ DEL MUNDO (UI del ciclo día/noche)` L4109, `JOYSTICK VIRTUAL (aparece donde tocas en la zona inferior-izquierda)` L4287, `TELETRANSPORTE Y SPAWN SEGURO (evita siempre aparecer en mar, montaña o casillas bloqueantes)` L4323, `PANEL INFERIOR (ubicación / viaje) — construido por código` L4455, `GATING POR FASE DÍA/NOCHE (data-driven, reutilizable)` L4478, `HERRAMIENTAS + MODIFICACIÓN DEL TERRENO / CAMPAMENTO / ENEMIGOS` L4521, `OBJETOS INTERACTIVOS (cartel/lápida/libro…) — ventana de texto reutilizable` L4527, `RECOLECCIÓN EN EL MUNDO (sin cambiar de vista)` L4871, `SISTEMA DE MISIONES Y DIÁLOGO (con la corrección de aplazamiento)` L5091, `LOCALE` L5241, `CÁMARA DE CINEMÁTICAS (desacoplada del Sistema Narrativo)` L5266, `CINEMÁTICA DE LA PRESA PROGRESIVA` L5285
- **funcs:** `set_modal_mode` L745, `is_cell_passable` L3405, `hide_clock_and_map` L4117, `release_clock_and_map` L4133, `attach_clock_and_map_to_slot` L4148, `ensure_map_button` L4182, `teleport_player_to` L4424, `get_active_location_title` L4466
  `run_dam_opened_cinematic` L5290
- **privadas:** `_ready` L607, `_update_responsive_layout` L703, `_process` L765, `_cheby` L880, `_animate_walk_cycle` L891, `_animate_nearby` L979, `_animate_wandering_animal` L1045, `_update_terrain_step_particles` L1126
  `_configure_terrain_step_particles` L1145, `_build_viewport_and_scene` L1184, `_build_player_character` L1450, `_import_animation_library` L1506, `_find_animation_player` L1543, `_find_skeleton` L1553, `_enable_model_shadows` L1563, `_get_player_profession_texture` L1574
  `_profession_color` L1607, `_refresh_player_profession_tint` L1617, `_on_global_state_updated` L1627, `_mat` L1642, `_build_tiles` L1657, `_rebuild_tiles` L1671, `_chunk_key_prefix` L1722, `_finalize_chunk_from_classified` L1731
  `_unload_chunk` L1775, `_ground_group` L1827, `_create_render_resources` L1858, `_build_ocean_plane` L1871, `_register_one_tile` L1895, `_find_land_blend_direction` L2283, `_collect_grass_blades` L2291, `_building_cache_key` L2360
  `_build_marker_for` L2371, `_process_pending_marker_builds` L2438, `_flush_pending_marker_builds` L2464, `_attach_poi_night_light` L2479, `_dedupe_marker_materials` L2566, `_shared_mat_for` L2585, `_merge_mesh_children` L2608, `_collect_for_merge` L2634
  `_finalize_ground` L2660, `_finalize_grass` L2688, `_finalize_ground_blend` L2737, `_make_ground_blend_material` L2769, `_finalize_mountain_decor` L2794, `_build_shared_mountain_mesh` L2816, `_finalize_resource_decor` L2925, `_build_shared_log_mesh` L2982
  `_combine_node_meshes` L2988, `_extract_mesh_from_model` L3029, `_build_shared_rock_mesh` L3047, `_build_shared_cow_mesh` L3069, `_build_shared_pig_mesh` L3074, `_build_shared_cattle_mesh` L3078, `_build_shared_tombstone_mesh` L3084, `_build_shared_skeleton_mesh` L3131
  `_make_ground_material` L3181, `_get_base_texture` L3235, `_texture_for_key` L3247, `_hex_color` L3270, `_cell_to_world` L3280, `_recompute_gates` L3301, `_rebuild_gate_auroras` L3328, `_movement_blocked_by_gate` L3378
  `_unhandled_input` L3449, `_try_tap_move` L3473, `_screen_to_world_point` L3503, `_screen_to_cell` L3524, `_clear_move_target` L3533, `_setup_destination_marker` L3541, `_show_destination_marker` L3558, `_hide_destination_marker` L3569
  `_build_boat_visual` L3584, `_refresh_boat_marker` L3630, `_set_boat_visual` L3647, `_board_boat` L3658, `_disembark_boat` L3668, `_find_hex_path` L3691, `_update_overworld_footsteps` L3759, `_apply_free_movement` L3785
  `_keyboard_dir` L3875, `_world_to_cell` L3884, `_is_world_pos_walkable` L3889, `_enter_cell_if_changed` L3934, `_update_ambience` L3984, `_resolve_terrain_weather` L3992, `_reroll_weather` L3998, `_apply_daynight_lighting` L4008
  `_apply_terrain_hazard` L4017, `_build_clock` L4197, `_on_map_pressed` L4242, `_close_minimap` L4252, `_update_clock` L4260, `_on_world_hour_changed` L4269, `_on_world_phase_changed` L4275, `_build_joystick` L4290
  `_is_pos_over_ui` L4293, `_input` L4296, `_start_touch_gesture` L4299, `_drag_touch_gesture` L4302, `_end_touch_gesture` L4305, `_start_joystick` L4308, `_update_joystick` L4311, `_reset_joystick` L4314
  `_position_joystick` L4317, `_find_nearest_walkable_cell` L4325, `_find_safe_spawn_world_pos` L4355, `_is_spawn_pos_valid` L4412, `_build_bottom_panel` L4460, `_gather_action_label` L4463, `_update_location_panel` L4469, `_location_subtitle` L4472
  `_poi_open_phase` L4482, `_is_poi_time_locked` L4491, `_apply_phase_gate_to_enter` L4500, `_phase_lock_hint` L4513, `_open_interactive_popup` L4534, `_nudge_player_off_solid_cell` L4551, `_on_enter_pressed` L4574, `_check_and_trigger_cell_cinematic` L4638
  `_check_and_open_world_chest` L4680, `_show_world_chest_loot_dialogue` L4727, `_confirm_dungeon_entry` L4821, `_resolve_gather_res` L4874, `_gather_fx_color` L4888, `_on_gather_pressed` L4901, `_refresh_gather_button` L4970, `_play_chop` L4978
  `_spawn_world_float` L4986, `_show_discovery_banner` L5009, `_maybe_announce_discovery` L5059, `_reveal_around` L5077, `_setup_quest_system` L5092, `_on_visibility_changed` L5106, `_enable_subviewport_when_ready` L5172, `_on_map_cell_changed` L5181
  `_on_combat_triggered` L5204, `_rebuild_marker` L5219, `_on_locale_changed` L5242, `_refresh_world_labels_theme` L5253, `_on_cine_camera_event` L5276, `_on_scene_runner_finished` L5279, `_get_propagation_delay` L5293, `_spawn_temp_tile_popup` L5296
  `_update_base_aura` L5299, `_check_puerto_crisis_event` L5305

### `WeatherOverlay`
`scenes/tabs/tab_world_3d/WeatherOverlay.gd` · 161 líneas · extends `CanvasLayer`

CAPA DE CLIMA DATA-DRIVEN
- **funcs:** `apply` L69
- **privadas:** `_ready` L31, `_layout_emitter` L58, `_apply_tint` L117, `_apply_sound` L130, `_parse_color` L158

### `BuildingAldea`
`scenes/tabs/tab_world_3d/buildings/BuildingAldea.gd` · 51 líneas · extends `RefCounted`

Geometría procedural low-poly del marcador de ALDEA (`cell.item == "aldea"`):
- **funcs:** `build`(s) L18

### `BuildingCasita`
`scenes/tabs/tab_world_3d/buildings/BuildingCasita.gd` · 152 líneas · extends `RefCounted`

Geometría procedural low-poly del marcador de CASITA (`cell.item ==
- **funcs:** `build`(s) L20

### `BuildingCiudad`
`scenes/tabs/tab_world_3d/buildings/BuildingCiudad.gd` · 153 líneas · extends `RefCounted`

Geometría procedural low-poly del marcador de CIUDAD (`cell.item ==
- **funcs:** `build`(s) L18

### `BuildingCueva`
`scenes/tabs/tab_world_3d/buildings/BuildingCueva.gd` · 260 líneas · extends `RefCounted`

Geometría procedural low-poly para el marcador de CUEVA/MAZMORRA en el mapamundi.
- **funcs:** `build`(s) L16

### `BuildingPresa`
`scenes/tabs/tab_world_3d/buildings/BuildingPresa.gd` · 124 líneas · extends `RefCounted`

Geometría procedural low-poly del marcador de la PRESA (`cell.item == "presa"`):
- **funcs:** `build`(s) L23

### `BuildingPuerto`
`scenes/tabs/tab_world_3d/buildings/BuildingPuerto.gd` · 358 líneas · extends `RefCounted`

Geometría procedural low-poly del PUERTO DE CELESTIA y muelles de embarque.
- **funcs:** `build`(s) L15

### `BuildingRuinas`
`scenes/tabs/tab_world_3d/buildings/BuildingRuinas.gd` · 45 líneas · extends `RefCounted`

Geometría procedural low-poly del marcador de RUINAS (`cell.item ==
- **funcs:** `build`(s) L16

### `BuildingTemplo`
`scenes/tabs/tab_world_3d/buildings/BuildingTemplo.gd` · 76 líneas · extends `RefCounted`

Geometría procedural low-poly del marcador de TEMPLO/LUGAR (`cell.item ==
- **funcs:** `build`(s) L22

### `GenericMarkers`
`scenes/tabs/tab_world_3d/buildings/GenericMarkers.gd` · 1418 líneas · extends `RefCounted`

Geometría procedural low-poly de los marcadores "genéricos" del mapamundi que
- **funcs:** `make_marker`(s) L21, `build_pig_mesh`(s) L872, `build_cow_mesh`(s) L1066, `build_cattle_mesh`(s) L1344, `add_jumping_fish`(s) L1349
- **privadas:** `_color_or`(s) L854, `_apply_classic_scale`(s) L864, `_dim_model_meshes`(s) L1403

### `CampEatMenu`
`scenes/tabs/tab_world_3d/interactive/CampEatMenu.gd` · 244 líneas · extends `RefCounted`

Menú "Comer" del campamento: lista los comestibles de la bolsa y, al elegir
- **funcs:** `open_eat_menu`(s) L20
- **privadas:** `_render_eat_list`(s) L49, `_make_food_card`(s) L86, `_render_eat_preview`(s) L104, `_make_preview_row`(s) L178, `_do_eat`(s) L221

### `CampTentSystem`
`scenes/tabs/tab_world_3d/interactive/CampTentSystem.gd` · 922 líneas · extends `RefCounted`

CAMPAMENTO — TIENDA (checkpoint) + HOGUERA (comer/cocinar/descansar/tiempo) +
- **funcs:** `open_tent_menu`(s) L22, `tent_rest`(s) L128, `open_campfire_build_confirm`(s) L139, `build_campfire_confirmed`(s) L211, `refresh_campfire_ghost`(s) L241, `spawn_campfire_ghost`(s) L255, `open_camp_menu`(s) L294, `format_costs`(s) L350
  `open_camp_structure_build_confirm`(s) L364, `do_build_camp_structure_at`(s) L445, `spawn_generic_structure_ghost`(s) L479, `open_camp_structure`(s) L527, `train_dummy`(s) L543, `open_chest_menu`(s) L578, `camp_pass_time`(s) L722, `advance_to_hour`(s) L732
  `on_use_tent_pressed`(s) L747, `open_camp_build_confirm`(s) L762, `build_camp_confirmed`(s) L840, `spawn_camp_ghost`(s) L888
- **privadas:** `_build_chest_column`(s) L637, `_refresh_chest_column`(s) L670

### `DebugToolbar`
`scenes/tabs/tab_world_3d/interactive/DebugToolbar.gd` · 602 líneas · extends `RefCounted`

BARRA DE HERRAMIENTAS Y TELETRANSPORTE POR ZONAS DEL MODO DEBUG.
- **funcs:** `build_debug_toolbar`(s) L30, `add_debug_resources`(s) L221, `warp_to_zone`(s) L233, `unlock_all_professions_debug`(s) L537
- **privadas:** `_update_speed_button_label`(s) L195, `_style_debug_btn`(s) L204, `_set_jobs_subset_level`(s) L549, `_set_all_jobs_level`(s) L568, `_equip_item_safely`(s) L586

### `DebugWorldSeeder`
`scenes/tabs/tab_world_3d/interactive/DebugWorldSeeder.gd` · 87 líneas · extends `RefCounted`

Siembra de objetos de PRUEBA cerca del punto de inicio cuando GlobalState.
- **funcs:** `place_debug_bombable`(s) L30, `place_debug_enemy`(s) L59, `place_debug_sign`(s) L86
- **privadas:** `_cell_is_bare`(s) L20

### `OverworldPhysicsController`
`scenes/tabs/tab_world_3d/interactive/OverworldPhysicsController.gd` · 47 líneas · extends `RefCounted`
- **funcs:** `setup` L23, `apply_slippery_on_enter` L29, `maybe_stop_slide` L45

### `TerrainToolsSystem`
`scenes/tabs/tab_world_3d/interactive/TerrainToolsSystem.gd` · 553 líneas · extends `RefCounted`

HERRAMIENTAS + MODIFICACIÓN DEL TERRENO (data-driven, persistente vía deltas):
- **funcs:** `cell_has_actionable_obstacle`(s) L19, `find_tool_target`(s) L29, `update_tool_button`(s) L43, `on_tool_pressed`(s) L75, `adjacent_to_water`(s) L121, `cell_is_bare`(s) L145, `find_terrain_action`(s) L159, `apply_terrain_action`(s) L264
  `has_bombable_target`(s) L318, `update_bomb_button`(s) L336, `on_place_bomb_pressed`(s) L350, `spawn_bomb_actor`(s) L361, `detonate_bomb`(s) L458, `text_localized`(s) L550
- **privadas:** `_is_far_enough_from_water`(s) L133

### `TravelSystem`
`scenes/tabs/tab_world_3d/interactive/TravelSystem.gd` · 121 líneas · extends `RefCounted`

VIAJE RÁPIDO: overlay con los destinos descubiertos (incluida la tienda de
- **funcs:** `open_travel_menu`(s) L18, `travel_to`(s) L103, `close_travel_overlay`(s) L118

### `WorldChunkStreamer`
`scenes/tabs/tab_world_3d/interactive/WorldChunkStreamer.gd` · 178 líneas · extends `RefCounted`

Gestiona el streaming de chunks 3D del
- **funcs:** `chunk_coord_of`(s) L49, `initialize` L55, `update_active_chunks` L63, `poll_pending` L119, `rebuild_active_chunks` L143
- **privadas:** `_build_one_sync` L151, `_desired_chunks` L161, `_chunk_bounds` L171

### `WorldCinematicController`
`scenes/tabs/tab_world_3d/interactive/WorldCinematicController.gd` · 271 líneas · extends `RefCounted`

- **regions:** `CÁMARA DE CINEMÁTICAS (desacoplada del Sistema Narrativo)` L37, `CINEMÁTICA DE LA PRESA PROGRESIVA` L66
- **funcs:** `setup` L33, `run_dam_opened_cinematic` L68
- **privadas:** `_on_cine_camera_event` L42, `_on_scene_runner_finished` L58, `_get_propagation_delay` L152, `_spawn_temp_tile_popup` L170, `_update_base_aura` L221

### `WorldEnemies`
`scenes/tabs/tab_world_3d/interactive/WorldEnemies.gd` · 464 líneas · extends `RefCounted`

ENEMIGOS DEL MAPAMUNDI (actores dinámicos · ): deambulan lento y
- **funcs:** `is_enemy_active`(s) L33, `build_enemies`(s) L44, `refresh_enemies`(s) L58, `spawn_enemy_actor`(s) L91, `process_enemies`(s) L330, `step_enemy`(s) L386, `trigger_overworld_combat`(s) L415, `check_enemy_contact`(s) L455
- **privadas:** `_ensure_enemy_coords_indexed`(s) L24, `_make_vertical_eye`(s) L314

### `WorldEnvironmentController`
`scenes/tabs/tab_world_3d/interactive/WorldEnvironmentController.gd` · 189 líneas · extends `RefCounted`

- **regions:** `CICLO DÍA / NOCHE — ILUMINACIÓN` L48, `AMBIENTE DATA-DRIVEN (música + clima)` L95
- **funcs:** `setup` L45, `apply_daynight_lighting` L52, `update_ambience` L102, `resolve_terrain_weather` L174, `reroll_weather` L183
- **privadas:** `_animate_wind_gust` L156

### `WorldFogRenderer`
`scenes/tabs/tab_world_3d/interactive/WorldFogRenderer.gd` · 278 líneas · extends `RefCounted`

NIEBLA DE GUERRA (oculto / penumbra / visible) + VISIBILIDAD DE MARCADORES Y
- **funcs:** `restore_explored`(s) L17, `recompute_cell_fog`(s) L24, `update_fog_of_war`(s) L40, `fog_step`(s) L55, `process_fog_queue`(s) L91, `rebuild_nearby`(s) L116, `apply_visibility`(s) L124, `find_collision_objects`(s) L130
  `update_gather_collision`(s) L139, `apply_cell_visual`(s) L165

### `WorldHudBuilder`
`scenes/tabs/tab_world_3d/interactive/WorldHudBuilder.gd` · 615 líneas · extends `RefCounted`

- **regions:** `JOYSTICK VIRTUAL` L38, `PANEL INFERIOR (ubicación / viaje) — construido por código` L240
- **funcs:** `setup` L34, `get_active_location_title` L422
- **privadas:** `_build_joystick` L40, `_is_pos_over_ui` L79, `_input` L130, `_start_touch_gesture` L169, `_drag_touch_gesture` L181, `_end_touch_gesture` L194, `_start_joystick` L207, `_update_joystick` L217
  `_reset_joystick` L225, `_position_joystick` L233, `_build_bottom_panel` L242, `_gather_action_label` L409, `_update_location_panel` L440, `_location_subtitle` L603

### `WorldMeshBaker`
`scenes/tabs/tab_world_3d/interactive/WorldMeshBaker.gd` · 38 líneas · extends `RefCounted`

Parte PURAMENTE de datos del streaming de
- **funcs:** `classify_chunk_cells`(s) L32

## Vistas (scenes/views)

### `ViewBuilding`
`scenes/views/view_building/ViewBuilding.gd` · 8 líneas · extends `ViewPlace`

Hereda de ViewPlace (renderizador unificado de Novela Visual / POI).
- **funcs:** `setup` L7

### `ViewCity`
`scenes/views/view_city/ViewCity.gd` · 366 líneas · extends `Control`

Vista interior de una ciudad: muestra un grid de edificios clickables.
- **funcs:** `get_location_name` L78, `setup` L84
- **privadas:** `_ready` L31, `_refresh_chrome` L63, `_build_building_buttons` L139, `_make_building_tile` L156, `_update_layout` L310, `_on_btn_exit_pressed` L350, `_on_btn_toggle_ui_pressed` L354

### `ViewCombat`
`scenes/views/view_combat/ViewCombat.gd` · 4684 líneas · extends `Control`

SISTEMA DE COMBATE REDISEÑADO: TIEMPO REAL ACTIVO (ATB) + SINERGIAS + DEFENSA ACTIVA

- **regions:** `CICLO DE VIDA E INICIALIZACIÓN DE LA UI` L892, `INICIAR COMBATE` L2287, `BUCLE DE PROCESAMIENTO ATB EN TIEMPO REAL` L2527, `EJECUCIÓN DE ACCIONES` L2562, `BULLET-TIME Y ANILLO DE IMPACTO (QTE DE DEFENSA, task_reforma_defensa.md)` L3601, `BOTONES DE ACCIONES RÁPIDAS` L3733, `ENCOLAR Y CHEQUEAR SINERGIAS (por IDs, data-driven desde synergies.json)` L3881, `GESTIÓN DE TABS E INTERFAZ SELECCIÓN` L4082, `RESOLUCIÓN DE COMBATE Y DAÑO / ESTADOS ALTERADOS` L4088, `PANEL DE RESULTADO, REFRESCO DE BARRAS/COLA Y BOTONES` L4155, `AUXILIARES E IA DEL ENEMIGO` L4277

- **signals:** `combat_ended` L11
- **funcs:** `set_hero_defending` L797, `play_hero_attack_reaction` L804, `play_hero_hurt_reaction` L811, `toggle_pause` L2050, `set_paused` L2056, `add_sintonia` L2239, `reset_hero_position` L2288, `start_combat` L2312
  `regen_combat_mp` L3152, `play_enemy_hurt_reaction` L3592, `apply_damage_to_enemy` L4095, `apply_damage_to_player` L4098, `update_queue_ui_elements` L4168, `calculate_special_damage` L4281, `log_message` L4308
- **privadas:** `_make_console_divider` L284, `_style_glossy_bar` L299, `_panel_style` L321, `_set_command_bar_dimmed` L338, `_show_enemy_attack_banner` L354, `_hide_enemy_attack_banner` L378, `_start_defense_pulse` L394, `_stop_defense_pulse` L410
  `_start_hero_idle_breathing` L423, `_play_hero_attack_lunge` L437, `_play_hero_defend_brace` L466, `_play_hero_hurt_shake` L496, `_play_hero_lunge_action` L524, `_style_jrpg_button` L528, `_set_jrpg_button_labels` L594, `_theme_color` L611
  `_safe_reparent` L616, `_apply_console_layout` L634, `_rescale_jrpg_button` L734, `_apply_top_hud_layout` L758, `_get_hero_full_body_texture_path` L771, `_update_hero_sprite_pose` L776, `_load_portrait_texture` L817, `_apply_orientation_layout` L839
  `_ready` L913, `_on_ui_theme_changed` L937, `_on_view_resized` L946, `_build_ui` L956, `_build_enemy_attack_banner` L1831, `_setup_profession_modal` L1930, `_unhandled_input` L2032, `_open_profession_modal` L2070
  `_on_profession_selected` L2088, `_update_quick_skill_info` L2093, `_toggle_compact_deck` L2117, `_make_stat_bar_direct` L2131, `_stat_bar_value_direct` L2150, `_make_ghost_hp_bar` L2165, `_animate_hp_bar` L2190, `_queue_slot_style` L2214
  `_show_resonance_max_banner` L2250, `_process` L2531, `_is_awaiting_decision` L2565, `_on_player_turn_ready` L2571, `_base_pa_limit` L2596, `_effective_pa_cost` L2601, `_get_max_queue_slots` L2611, `_execute_queue_sequence` L2617
  `_add_resonance_for_skill` L2695, `_grant_dummy_training_xp` L2709, `_resolve_player_skill` L2724, `_resolve_class_change_action` L2925, `_effect_hit_count` L2954, `_apply_skill_effect` L2970, `_apply_named_effect` L3000, `_apply_random_big_effect` L3073
  `_show_resonant_aura` L3104, `_rebuild_powers_if_active` L3146, `_execute_basic_attack_damage` L3164, `_choose_enemy_skill` L3187, `_telegraph_enemy_intent` L3257, `_execute_enemy_action` L3309, `_play_enemy_windup` L3564, `_play_enemy_lunge` L3576
  `_atb_diff_to_ring_radius` L3606, `_hero_chest_global_pos` L3613, `_enter_camera_focus` L3625, `_exit_camera_focus` L3643, `_enter_bullet_time` L3662, `_exit_bullet_time` L3683, `_resolve_defense_encounter` L3696, `_force_end_defense_effects` L3711
  `_on_btn_attack_pressed` L3735, `_on_btn_defense_pressed` L3764, `_play_perfect_parry_flash` L3837, `_block_full_block` L3852, `_block_damage_mult` L3865, `_on_skill_pressed` L3882, `_check_and_fuse_synergies` L3935, `_animate_skill_fly` L3942
  `_flash_skill_card` L4000, `_animate_synergy_fusion` L4012, `_skill_name` L4068, `_recount_queued_pa` L4074, `_play_intro_sequence` L4092, `_end_combat` L4101, `_resolve_attack_on_enemy` L4104, `_reveal_elemental_reaction` L4107
  `_consume_status` L4110, `_status_tick` L4113, `_decrement_statuses` L4116, `_apply_status` L4119, `_try_apply_status_to_enemy` L4122, `_try_apply_status_to_player` L4125, `_apply_skill_status` L4128, `_update_status_labels` L4131
  `_rebuild_status_icons` L4134, `_rebuild_status_icons_deferred` L4137, `_status_summary` L4140, `_status_icon` L4143, `_status_color` L4146, `_status_label` L4149, `_animate_result_panel` L4159, `_shake` L4162
  `_build_queue_box_mapping` L4165, `_animate_synergy_badge` L4171, `_on_queue_slot_clicked` L4174, `_update_player_bars` L4177, `_update_resonance_glow` L4180, `_start_hp_danger_pulse` L4183, `_stop_hp_danger_pulse` L4186, `_sync_player_atb_labels` L4189
  `_update_action_buttons` L4192, `_refresh_chrome` L4195, `_on_btn_return_pressed` L4198, `_update_flee_button` L4201, `_update_enemy_hp_bar_color` L4233, `_on_btn_flee_pressed` L4248, `_on_btn_one_hit_kill_pressed` L4268, `_enemy_name` L4332
  `_resolve_combat_background_path` L4339, `_resolve_combat_platform_path` L4456, `_get_legacy_fallback_platform` L4521, `_element_icon` L4530, `_icons_for` L4534, `_enemy_info_text` L4541, `_skill_type_color` L4555, `_format_drops` L4566
  `_update_defense_ring_geometry` L4579, `_align_enemy_and_platform` L4587

### `CombatDamageResolver`
`scenes/views/view_combat/components/CombatDamageResolver.gd` · 650 líneas · extends `RefCounted`
- **funcs:** `setup` L34, `apply_damage_to_enemy` L121, `apply_damage_to_player` L161
- **privadas:** `_play_intro_sequence` L38, `_end_combat` L193, `_resolve_attack_on_enemy` L329, `_reveal_elemental_reaction` L436, `_consume_status` L449, `_status_tick` L455, `_decrement_statuses` L473, `_apply_status` L481
  `_try_apply_status_to_enemy` L489, `_try_apply_status_to_player` L504, `_apply_skill_status` L516, `_update_status_labels` L551, `_rebuild_status_icons` L563, `_rebuild_status_icons_deferred` L575, `_status_summary` L632, `_status_icon` L641
  `_status_color` L645, `_status_label` L649

### `CombatFx`
`scenes/views/view_combat/components/CombatFx.gd` · 666 líneas · extends `RefCounted`

EFECTOS VISUALES Y FEEDBACK SENSORIAL DE COMBATE
- **funcs:** `spawn_word`(s) L18, `spawn_center_callout`(s) L49, `spawn_dot_tick`(s) L82, `play_special_fx`(s) L109, `spawn_skill_projectile`(s) L216, `has_skill_effect`(s) L309, `play_skill_effect`(s) L327, `blood_screen_fx`(s) L358
  `spawn_floating_number`(s) L394, `shake_camera`(s) L486, `spawn_damage_number`(s) L501, `play_hit_reaction`(s) L510, `play_enemy_death_animation`(s) L535, `play_hero_defeat_animation`(s) L560, `play_hero_flee_animation`(s) L585, `play_enemy_flee_animation`(s) L605
  `spawn_biome_particles`(s) L629
- **privadas:** `_quad_bezier`(s) L139, `_spawn_trail_ghost`(s) L146, `_flash_impact`(s) L182, `_acquire_label`(s) L374, `_release_label`(s) L386

### `CombatQueueSystem`
`scenes/views/view_combat/components/CombatQueueSystem.gd` · 88 líneas · extends `RefCounted`
- **funcs:** `setup` L23, `get_max_queue_slots` L29, `check_and_fuse_synergies` L37

### `CombatResultUI`
`scenes/views/view_combat/components/CombatResultUI.gd` · 577 líneas · extends `RefCounted`
- **funcs:** `setup` L34, `update_queue_ui_elements` L121
- **privadas:** `_animate_result_panel` L40, `_shake` L64, `_build_queue_box_mapping` L81, `_stop_synergy_pulse` L106, `_animate_synergy_badge` L323, `_on_queue_slot_clicked` L354, `_update_player_bars` L366, `_update_resonance_glow` L409
  `_start_hp_danger_pulse` L425, `_stop_hp_danger_pulse` L436, `_sync_player_atb_labels` L446, `_update_action_buttons` L483, `_refresh_chrome` L530, `_on_btn_return_pressed` L540, `_on_btn_flee_pressed` L549

### `CombatTabsUI`
`scenes/views/view_combat/components/CombatTabsUI.gd` · 848 líneas · extends `RefCounted`

GESTIÓN DE TABS E INTERFAZ DE SELECCIÓN de combate: pestañas Poderes/Clases/
- **funcs:** `get_prof_texture_path`(s) L28, `get_prof_fullbody_path`(s) L47, `on_tab_pressed`(s) L65, `refresh_tab_highlight`(s) L72, `build_tab_grid`(s) L99, `make_skill_card`(s) L125, `make_skill_card_grid4`(s) L235, `make_empty_skill_card_grid4`(s) L385
  `build_powers_grid`(s) L414, `build_classes_grid`(s) L446, `enqueue_class_change`(s) L570, `change_class_during_combat`(s) L600, `build_bag_grid`(s) L632, `on_potion_pressed`(s) L789, `use_potion_action`(s) L811

### `CombatTurnEngine`
`scenes/views/view_combat/components/CombatTurnEngine.gd` · 228 líneas · extends `RefCounted`

- **signals:** `atb_updated` L25, `hero_turn_ready` L26, `enemy_turn_ready` L27
- **funcs:** `setup` L34, `tick` L38

### `DefenseImpactRing`
`scenes/views/view_combat/components/DefenseImpactRing.gd` · 120 líneas · extends `Control`
- **funcs:** `configure` L44, `center_on` L61, `set_progress` L67, `get_current_radius` L72, `resolve` L104
- **privadas:** `_init` L35, `_draw` L76

### `ResonanceCircle`
`scenes/views/view_combat/components/ResonanceCircle.gd` · 89 líneas · extends `CenterContainer`

- **signals:** `resonance_max_reached` L51
- **funcs:** `set_resonance` L53
- **privadas:** `_init` L22, `_draw` L32, `_start_pulse` L75, `_stop_pulse` L86

### `ViewCook`
`scenes/views/view_cook/ViewCook.gd` · 512 líneas · extends `Control`

Vista de la Cocina (se abre desde la Hoguera de la Base y campamentos).
- **funcs:** `setup` L56
- **privadas:** `_ready` L30, `_on_state_updated` L50, `_build_ui` L66, `_refresh_texts` L221, `_count_owned_cooking_ingredients` L248, `_render` L262, `_make_recipe_card` L311, `_on_cook` L428
  `_show_cook_result_banner` L459, `_update_layout` L489, `_input` L504

### `ViewDungeon`
`scenes/views/view_dungeon/ViewDungeon.gd` · 2520 líneas · extends `Control`

CONTROLADOR DE EXPLORACIÓN DE MAZMORRA EN 3D (Primera Persona)
- **funcs:** `get_dungeon_name` L176, `setup` L707, `stop_exploration` L993, `resume_exploration` L1000, `purge_dungeon_temp_elements`(s) L1195, `set_active_checkpoint` L1843
- **privadas:** `_ready` L138, `_on_dungeon_visibility_changed` L168, `_update_responsive_layout` L184, `_reposition_minimap` L204, `_build_hazard_overlay` L226, `_build_snow_mist_overlay` L235, `_build_exploration_hud` L254, `_build_minimap` L262
  `_setup_debug_speed_button` L305, `_update_debug_speed_btn_label` L336, `_toggle_debug_speed` L342, `_setup_minimap_floor` L354, `_build_skill_effects` L372, `_on_time_slow_changed` L388, `_process` L406, `_update_tutorial_barks` L452
  `_build_joystick` L507, `_input` L561, `_can_start_joystick_at` L622, `_start_left_joystick` L631, `_update_left_joystick` L641, `_reset_left_joystick` L649, `_position_left_joystick` L659, `_start_right_joystick` L665
  `_update_right_joystick` L675, `_reset_right_joystick` L683, `_position_right_joystick` L693, `_refresh_chrome` L699, `_build_debug_lab` L947, `_setup_tutorial` L970, `_restore_trial_profession` L987, `_setup_dungeon_enemies` L1029
  `_on_enemy_combat_triggered` L1045, `_get_boss_data` L1093, `_boss_key` L1104, `_remove_defeated_boss_nodes` L1116, `_collect_boss_nodes` L1126, `_update_boss_teleport_visibility` L1138, `_fallback_layout` L1167, `_fallback_cells` L1176
  `_clean_up_3d` L1203, `_on_btn_leave_pressed` L1224, `_force_unlock_movement_on_exit` L1245, `_on_exit_portal_entered` L1251, `_handle_exit_portal` L1261, `_apply_dungeon_exit_to` L1333, `_apply_named_portal_exit` L1359, `_find_portal_world_coord` L1385
  `_on_chest_entered` L1412, `_dim_chest_meshes` L1508, `_char_chest_meshes` L1519, `_show_chest_loot_dialogue` L1533, `_on_dungeon_cinematic_entered` L1613, `_trigger_dungeon_cinematic` L1622, `_on_teleport_entered` L1646, `_on_player_died` L1700
  `_show_prologue_game_over` L1711, `_on_player_took_damage` L1804, `_on_player_water_changed` L1823, `_rest_overlay_color` L1834, `_cache_snow_walls` L1857, `_check_snow_dungeon_lost` L1878, `_trigger_snow_lost` L1907, `_hide_world_map_button` L1985
  `_unhandled_input` L1998, `_setup_dun_final_6_event` L2005, `_start_memory_procession_sequence` L2038, `_collect_all_npc_memories` L2111, `_spawn_avatar_memory_node` L2198, `_show_sphere_discourse` L2282, `_build_memory_bridge` L2465

### `DungeonClimbZone`
`scenes/views/view_dungeon/components/DungeonClimbZone.gd` · 16 líneas · extends `Area3D`

Franja adosada a la cara abierta de un muro escalable (idea.md §1.1). Mismo
- **privadas:** `_ready` L6, `_on_body_entered` L10, `_on_body_exited` L14

### `DungeonEnemy`
`scenes/views/view_dungeon/components/DungeonEnemy.gd` · 476 líneas · extends `StaticBody3D`

CONTROLADOR DE ENEMIGOS EN LA MAZMORRA 3D

- **signals:** `combat_triggered` L19
- **funcs:** `refresh_visuals` L170, `trigger_combat_now` L474
- **privadas:** `_ready` L84, `_setup_detection_range` L149, `_start_idle_animation` L195, `_perform_float` L199, `_start_patrol` L216, `_process` L230, `_is_wall_ahead` L261, `_pick_cronofago_direction` L283
  `_process_cronofago` L336, `_is_time_distort_active` L395, `_find_player` L409, `_update_detection_color` L427, `_on_interaction_entered` L449, `_on_interaction_exited` L457, `_on_detection_entered` L462, `_on_detection_exited` L467

### `DungeonFlameZone`
`scenes/views/view_dungeon/components/DungeonFlameZone.gd` · 15 líneas · extends `Area3D`

Zona de peligro de llama encendida: al entrar un cuerpo, le inflige daño de fuego
- **privadas:** `_ready` L8, `_on_body_entered` L11

### `DungeonIceZone`
`scenes/views/view_dungeon/components/DungeonIceZone.gd` · 15 líneas · extends `Area3D`

Suelo de hielo deslizante (idea.md §1.2). Mismo patrón que DungeonWaterZone.gd.
- **privadas:** `_ready` L5, `_on_body_entered` L9, `_on_body_exited` L13

### `DungeonLavaZone`
`scenes/views/view_dungeon/components/DungeonLavaZone.gd` · 54 líneas · extends `Node`
- **privadas:** `_ready` L6, `_setup_hazard_area` L10, `_on_body_entered` L25, `_on_body_exited` L29, `_apply_lava_shader` L33, `_find_mesh_instance` L48

### `DungeonMinimap`
`scenes/views/view_dungeon/components/DungeonMinimap.gd` · 150 líneas · extends `Control`

MINIMAPA de orientación dentro de la mazmorra (Game Feel / UX): las mazmorras
- **funcs:** `set_boss_defeated` L41, `set_floor_data` L49, `update_player` L59
- **privadas:** `_ready` L32, `_reveal_around` L83, `_cell_at` L89, `_draw` L99, `_marker_color` L145

### `DungeonPlayer`
`scenes/views/view_dungeon/components/DungeonPlayer.gd` · 673 líneas · extends `CharacterBody3D`

CONTROLADOR EN PRIMERA PERSONA DE MAZMORRA (Controles tipo Tanque + Interacciones)

- **signals:** `took_damage` L13, `water_changed` L16
- **funcs:** `skill_controller` L120, `pull_self_to` L126, `stop_footsteps` L369, `set_in_water` L433, `set_in_lava` L444, `set_on_ice` L459, `set_climbing` L476, `add_water_current` L489
  `remove_water_current` L493, `apply_vertical_impulse` L500, `take_damage_spikes` L504, `take_damage_flame` L523, `set_stored_element` L582
- **privadas:** `_ready` L104, `_physics_process` L131, `_update_footsteps` L335, `_update_head_bob` L379, `_try_step_up` L409, `_apply_dungeon_damage` L542, `_camera` L560, `_process_skill_input` L565
  `_on_skill_used` L597, `_aim_point` L629, `_element_color` L642, `_recover_from_void_fall` L657

### `DungeonPoisonWaterZone`
`scenes/views/view_dungeon/components/DungeonPoisonWaterZone.gd` · 21 líneas · extends `Area3D`

ZONA DE AGUA ENVENENADA (Ralentización de agua + Daño continuo de veneno)
- **privadas:** `_ready` L7, `_on_body_entered` L11, `_on_body_exited` L17

### `DungeonSpikesZone`
`scenes/views/view_dungeon/components/DungeonSpikesZone.gd` · 11 líneas · extends `Area3D`
- **privadas:** `_ready` L6, `_on_body_entered` L9

### `DungeonWaterZone`
`scenes/views/view_dungeon/components/DungeonWaterZone.gd` · 25 líneas · extends `Area3D`
- **privadas:** `_ready` L11, `_on_body_entered` L15, `_on_body_exited` L21

### `GridDungeonStage`
`scenes/views/view_dungeon/components/GridDungeonStage.gd` · 5602 líneas · extends `Node3D`

ESCENARIO 3D GENÉRICO Y DATA-DRIVEN DE MAZMORRA DE REJILLA
- **funcs:** `resolve_theme_key`(s) L318, `build` L426, `get_floor_surface_kind` L600, `add_exit_teleport_at` L2333, `trigger_actuator` L4703, `cell_to_world` L5418, `cell_from_world` L5426
- **privadas:** `_defer_tween_setup` L417, `_ready` L447, `_process` L461, `_process_distance_culling` L471, `_cache_floor_geometry` L499, `_process_geometry_culling` L521, `_process_interactive_highlights` L542, `_build_materials` L604
  `_make_water_shader_mat` L679, `_make_poison_shader_mat` L708, `_make_lava_shader_mat` L728, `_create_lava_smoke_particles` L748, `_build_environment` L790, `_build_void_floor` L946, `_build_void_lava` L989, `_build_void_spikes` L1054
  `_build_void_abyss` L1127, `_build_floor` L1192, `_add_ceiling` L1228, `_add_ambient_dust` L1246, `_build_cell` L1277, `_add_floor_slab` L1615, `_add_lava_slab` L1633, `_add_wall_block` L1688
  `_add_model` L1723, `_add_liquid` L1759, `_add_spikes` L1877, `_set_hazard_warning` L1978, `_build_generic` L2010, `_register_light_element` L2048, `_hazard_script` L2060, `_add_light_from_spec` L2072
  `_add_enemy` L2083, `_add_marker` L2104, `_add_item_pickup_visual` L2186, `_add_cinematic_marker_visual` L2231, `_add_npc_marker_visual` L2289, `_get_portal_vortex_material`(s) L2383, `_get_portal_ring_material`(s) L2397, `_add_teleport_visual` L2420
  `_process_portal_facing` L2574, `_add_chest` L2603, `_build_lowpoly_chest` L2681, `_mesh_node` L2736, `_find_first_mesh_instance` L2745, `_track_interactable_mesh` L2761, `_add_light` L2778, `_process_light_culling` L2802
  `_process_flicker_lights` L2836, `_add_flicker` L2860, `_add_pulse` L2876, `_apply_transform` L2891, `_add_ramp` L2913, `_add_quad_st` L3018, `_add_door` L3040, `_add_gate` L3180
  `_add_shutters` L3242, `_add_actuator` L3318, `_add_weight_plate` L3501, `_canonical_wall_face` L3588, `_cell_type_at` L3597, `_has_wall_on_face` L3607, `_add_torch` L3612, `_add_crystal` L3674
  `_get_font` L3702, `_add_signage_overlay` L3729, `_add_floor_clutter` L4007, `_scatter_roll` L4052, `_strip_collisions` L4062, `_apply_wall_decor` L4074, `_apply_corner_decor` L4138, `_apply_floor_decal` L4187
  `_add_column` L4242, `_resolve_rotation_degrees` L4275, `_calculate_node_aabb` L4291, `_add_decor_prop` L4308, `_add_barrel` L4410, `_add_crate` L4415, `_add_statue` L4422, `_add_smart_object` L4449
  `_add_sign` L4480, `_add_rune` L4524, `_add_campfire` L4550, `_campfire_particles` L4597, `_wire_actuators` L4627, `_replay_persisted_actuators` L4639, `_actuator_flag_key` L4665, `_is_actuator_persisted_active` L4670
  `_on_gate_open_event` L4676, `_exit_tree` L4682, `_on_actuator_entered` L4695, `_element_anchor_node` L4841, `_spawn_energy_link` L4860, `_start_earthquake_loop` L4891, `_run_earthquake_step` L4898, `_convert_floor_to_lava` L4910
  `_register_element` L5040, `_apply_action` L5057, `_set_element_state` L5090, `_animate_door` L5123, `_animate_gate` L5141, `_animate_shutters` L5165, `_animate_light` L5181, `_animate_lever` L5199
  `_animate_plate` L5241, `_animate_wall_switch` L5261, `_animate_spikes` L5280, `_spawn_dust_burst` L5308, `_identify_boss_teleports` L5347, `_compute_spawn` L5408, `_cell_height` L5433, `_tinted` L5441
  `_surface_material` L5455, `_tile_model_override` L5492, `_uv_scale_for` L5503, `_parse_color` L5509, `_surface_tint` L5565, `_add_cell_light` L5579, `_marker_color` L5590

### `SkillVfx`
`scenes/views/view_dungeon/components/SkillVfx.gd` · 335 líneas · extends `Node3D`

FEEDBACK VISUAL PREMIUM DE LAS 6 HABILIDADES DE EXPLORACIÓN
- **funcs:** `cast`(s) L29
- **privadas:** `_beam`(s) L52, `_wave`(s) L102, `_pulse`(s) L137, `_ring`(s) L158, `_aura`(s) L176, `_sparkle`(s) L194, `_spawn_light`(s) L225, `_mat`(s) L287
  `_spawn`(s) L302, `_expand_and_free`(s) L313, `_basis_from_y`(s) L328

### `DungeonLab`
`scenes/views/view_dungeon/interaction/DungeonLab.gd` · 11 líneas · extends `Node3D`

LABORATORIO DEBUG DE OBJETOS INTELIGENTES
- **funcs:** `build` L10

### `DungeonSmartFactory`
`scenes/views/view_dungeon/interaction/DungeonSmartFactory.gd` · 2234 líneas · extends `RefCounted`

FÁBRICA DE OBJETOS INTELIGENTES DE MAZMORRA
- **funcs:** `build`(s) L28
- **privadas:** `_build_static`(s) L101, `_build_rigid`(s) L110, `_build_time`(s) L121, `_build_auto_platform`(s) L166, `_build_two_state`(s) L194, `_build_reveal`(s) L232, `_build_false_solid`(s) L246, `_get_water_shader_mat`(s) L269
  `_add_water_ambience`(s) L312, `_build_purify`(s) L350, `_build_water_tile`(s) L511, `_build_ice_block`(s) L610, `_build_flame`(s) L714, `_build_lava_pool`(s) L857, `_build_campfire`(s) L975, `_apply_cell_overrides`(s) L1139
  `_make_reaction`(s) L1160, `_attach`(s) L1243, `_add_shape`(s) L1254, `_add_collision`(s) L1422, `_box`(s) L1478, `_sphere`(s) L1488, `_cyl`(s) L1499, `_cone`(s) L1511
  `_build_checkpoint`(s) L1515, `_mat`(s) L1568, `_mat_alpha`(s) L1579, `_add_element_glyph`(s) L1599, `_color`(s) L1614, `_apply_transform`(s) L1622, `_build_burnable_roots`(s) L1636, `_dungeon_surface_material`(s) L1795
  `_build_sonic_ring`(s) L1823, `_build_psychic_column`(s) L1945, `_build_breakable_barrier`(s) L2116

### `ExplorationSkillController`
`scenes/views/view_dungeon/interaction/ExplorationSkillController.gd` · 480 líneas · extends `Node`

RUNTIME DE LAS HABILIDADES DE EXPLORACIÓN

- **signals:** `skill_used` L20, `skill_failed` L23, `element_changed` L25, `target_changed` L30
- **funcs:** `cooldown_left` L107, `is_toggled` L112, `is_ready` L117, `set_element` L126, `set_stored_element` L133, `try_use` L138
- **privadas:** `_ready` L62, `_process` L68, `_exit_tree` L95, `_build_ctx` L189, `_skill_source` L210, `_dispatch` L217, `_is_adjacent` L273, `_proximity_fallback` L285
  `_world` L325, `_update_aim_highlight` L342, `_has_line_of_sight` L403, `_acquire_aim_target` L428, `_accepted_unlocked_verbs` L464, `_max_unlocked_range` L476

### `Interactable`
`scenes/views/view_dungeon/interaction/Interactable.gd` · 159 líneas · extends `Node`

COMPONENTE DE OBJETO INTELIGENTE
- **funcs:** `host` L53, `set_host` L57, `accepts` L62, `has_proximity` L73, `react` L82, `set_highlight` L97, `of`(s) L142
- **privadas:** `_ready` L37, `_collect_reactions` L45, `_apply_highlight` L107, `_clear_highlight` L120, `_iter_meshes` L128

### `SkillCast`
`scenes/views/view_dungeon/interaction/SkillCast.gd` · 156 líneas · extends `RefCounted`

LOCALIZADOR DE OBJETIVOS PARA HABILIDADES
- **funcs:** `ray`(s) L20, `ray_impact`(s) L63, `ray_any`(s) L106, `sphere`(s) L140

### `SkillReaction`
`scenes/views/view_dungeon/interaction/SkillReaction.gd` · 55 líneas · extends `Node`

BASE DE LAS REACCIONES DE OBJETO INTELIGENTE
- **funcs:** `verb_base`(s) L33, `matches` L39, `apply` L53

### `TimeMotion`
`scenes/views/view_dungeon/interaction/TimeMotion.gd` · 85 líneas · extends `Node3D`

ANIMADOR DE OBJETO AFECTADO POR EL TIEMPO
- **privadas:** `_ready` L36, `_process` L42, `_spin` L73, `_offset` L81

### `ExplorationHud`
`scenes/views/view_dungeon/interaction/hud/ExplorationHud.gd` · 488 líneas · extends `Control`

HUD DE HABILIDADES DE EXPLORACIÓN

- **signals:** `menu_pressed` L21
- **funcs:** `bind` L76, `set_tutorial_highlight` L337, `add_minimap` L464, `blocks_joystick_point` L477
- **privadas:** `_ready` L65, `_build` L92, `_layout` L186, `_layout_grid_landscape` L217, `_layout_grid_portrait` L255, `_process` L290, `_refresh_static` L320, `_on_target_changed` L328
  `_draw_reticle` L346, `_skills_for_verbs` L381, `_on_element_changed` L391, `_on_skill_activated` L421, `_on_skill_failed` L427, `_on_skill_used` L448, `_on_menu_button_pressed` L454

### `ExplorationSkillButton`
`scenes/views/view_dungeon/interaction/hud/ExplorationSkillButton.gd` · 204 líneas · extends `Button`

BOTÓN CIRCULAR DE HABILIDAD DE EXPLORACIÓN

- **signals:** `activated` L19
- **funcs:** `setup` L45, `set_diameter` L61, `set_state` L69
- **privadas:** `_ready` L38, `_process` L84, `_on_pressed` L97, `_draw` L102, `_held` L203

### `ReactionActuator`
`scenes/views/view_dungeon/interaction/reactions/Actuator.gd` · 27 líneas · extends `SkillReaction`

REACCIÓN: ACCIONADOR / PALANCA / INTERRUPTOR
- **funcs:** `apply` L23
- **privadas:** `_init` L15

### `ReactionAnchor`
`scenes/views/view_dungeon/interaction/reactions/Anchor.gd` · 32 líneas · extends `SkillReaction`

REACCIÓN: ANCLAJE  (verbo: grab)
- **funcs:** `apply` L24
- **privadas:** `_init` L19

### `ReactionBreakable`
`scenes/views/view_dungeon/interaction/reactions/Breakable.gd` · 47 líneas · extends `SkillReaction`

REACCIÓN: ROMPIBLE  (verbo: impact)
- **funcs:** `apply` L27
- **privadas:** `_init` L22

### `ReactionBurnableRoots`
`scenes/views/view_dungeon/interaction/reactions/BurnableRoots.gd` · 223 líneas · extends `SkillReaction`

REACCIÓN: RAÍCES QUEMABLES POR FUEGO CON PROPAGACIÓN Y RESCOLDO EN EL SUELO
- **funcs:** `apply` L29
- **privadas:** `_init` L24, `_disable_collision_shapes` L162, `_create_ash_mark` L170, `_propagate_fire_to_adjacent` L188, `_consume_element` L220

### `ReactionCampfire`
`scenes/views/view_dungeon/interaction/reactions/Campfire.gd` · 63 líneas · extends `SkillReaction`

REACCIÓN: HOGUERA  (verbo: element)
- **funcs:** `apply` L34
- **privadas:** `_init` L29, `_apply_visual` L57

### `ReactionElementReceiver`
`scenes/views/view_dungeon/interaction/reactions/ElementReceiver.gd` · 72 líneas · extends `SkillReaction`

REACCIÓN: RECEPTOR ELEMENTAL  (verbo: element:<x>)
- **funcs:** `apply` L32
- **privadas:** `_init` L27, `_consume_element` L69

### `ReactionElementSource`
`scenes/views/view_dungeon/interaction/reactions/ElementSource.gd` · 37 líneas · extends `SkillReaction`

REACCIÓN: FUENTE ELEMENTAL  (verbo: element)
- **funcs:** `apply` L27
- **privadas:** `_init` L22

### `ReactionEmitEvent`
`scenes/views/view_dungeon/interaction/reactions/EmitEvent.gd` · 25 líneas · extends `SkillReaction`

REACCIÓN: EMITIR EVENTO  (verbo configurable)
- **funcs:** `apply` L18

### `ReactionFalseWall`
`scenes/views/view_dungeon/interaction/reactions/FalseWall.gd` · 101 líneas · extends `SkillReaction`

REACCIÓN: PARED/SUELO FALSO  (verbo: reveal)
- **funcs:** `apply` L37
- **privadas:** `_init` L32, `_glow_on` L51, `_set_glow_energy` L77, `_glow_off` L84, `_iter_meshes` L95

### `ReactionFlame`
`scenes/views/view_dungeon/interaction/reactions/Flame.gd` · 87 líneas · extends `SkillReaction`

REACCIÓN: LLAMA VIVA  (verbo: element)
- **funcs:** `apply` L44
- **privadas:** `_init` L39, `_extinguish` L62

### `ReactionIceMelt`
`scenes/views/view_dungeon/interaction/reactions/IceMelt.gd` · 87 líneas · extends `SkillReaction`

REACCIÓN: DERRETIR BLOQUE DE HIELO  (verbo: element)
- **funcs:** `apply` L49
- **privadas:** `_init` L44, `_consume_element` L84

### `ReactionLavaPool`
`scenes/views/view_dungeon/interaction/reactions/LavaPool.gd` · 103 líneas · extends `SkillReaction`

REACCIÓN: CHARCA DE LAVA  (verbo: element)
- **funcs:** `apply` L65
- **privadas:** `_init` L36, `_ready` L41, `_apply_lava_texture` L45

### `ReactionMovable`
`scenes/views/view_dungeon/interaction/reactions/Movable.gd` · 48 líneas · extends `SkillReaction`

REACCIÓN: MOVIBLE  (verbos: impact, grab)
- **funcs:** `apply` L24
- **privadas:** `_init` L19

### `ReactionPullable`
`scenes/views/view_dungeon/interaction/reactions/Pullable.gd` · 30 líneas · extends `SkillReaction`

REACCIÓN: ATRAÍBLE  (verbo: grab)
- **funcs:** `apply` L21
- **privadas:** `_init` L16

### `ReactionPurify`
`scenes/views/view_dungeon/interaction/reactions/Purify.gd` · 156 líneas · extends `SkillReaction`

REACCIÓN: PURIFICAR  (verbo: restore)
- **funcs:** `execute_purify` L32, `apply` L70
- **privadas:** `_init` L27, `_disable_areas` L108, `_glow_burst` L123

### `ReactionWaterTile`
`scenes/views/view_dungeon/interaction/reactions/ReactionWaterTile.gd` · 147 líneas · extends `SkillReaction`

REACCIÓN: CASILLA DE AGUA Y AGUA PROFUNDA (verbo: element)
- **funcs:** `apply` L45, `set_frozen` L102
- **privadas:** `_init` L40

### `ReactionRestorable`
`scenes/views/view_dungeon/interaction/reactions/Restorable.gd` · 39 líneas · extends `SkillReaction`

REACCIÓN: RESTAURABLE  (verbo: restore)
- **funcs:** `apply` L27
- **privadas:** `_init` L22

### `ReactionRevealable`
`scenes/views/view_dungeon/interaction/reactions/Revealable.gd` · 45 líneas · extends `SkillReaction`

REACCIÓN: REVELABLE  (verbo: reveal)
- **funcs:** `apply` L31
- **privadas:** `_ready` L22, `_on_hide` L43

### `ReactionSwitch`
`scenes/views/view_dungeon/interaction/reactions/Switch.gd` · 38 líneas · extends `SkillReaction`

REACCIÓN: INTERRUPTOR  (verbo configurable)
- **funcs:** `apply` L28
- **privadas:** `_init` L23

### `ReactionTimeAffected`
`scenes/views/view_dungeon/interaction/reactions/TimeAffected.gd` · 38 líneas · extends `SkillReaction`

REACCIÓN: AFECTADO POR EL TIEMPO  (verbo: timeshift)
- **funcs:** `apply` L28
- **privadas:** `_init` L23

### `ViewEncargos`
`scenes/views/view_encargos/ViewEncargos.gd` · 842 líneas · extends `Control`

TABLÓN DE ENCARGOS — MISIONES Y CONTRATOS EN CIUDAD Y BASE
- **funcs:** `setup` L72, `get_location_name` L86
- **privadas:** `_ready` L59, `_on_state_updated` L66, `_build_ui` L99, `_apply_theme` L318, `_refresh` L334, `_make_empty_state` L429, `_make_active_card` L462, `_make_avail_card` L568
  `_trigger_welcome_description` L648, `_on_accept` L686, `_on_claim` L700, `_on_leave_pressed` L716, `_encargo_title` L723, `_encargo_desc` L753, `_type_label` L792, `_show_text` L801
  `_pulse_more_indicator` L820, `_on_bottom_panel_input` L826, `_unhandled_input` L836

### `ViewForge`
`scenes/views/view_forge/ViewForge.gd` · 567 líneas · extends `Control`

HERRERÍA / FORJA — REFINAMIENTO DE EQUIPO EN CIUDAD Y BASE
- **funcs:** `setup` L53, `get_location_name` L64
- **privadas:** `_ready` L40, `_on_state_updated` L47, `_build_ui` L77, `_apply_theme` L235, `_refresh` L249, `_refresh_npc_avatar` L283, `_trigger_welcome_dialogue` L323, `_render_refine_list` L331
  `_make_refine_card` L359, `_equip_stats_text` L451, `_on_refine` L471, `_on_leave_pressed` L515, `_show_text` L522, `_pulse_more_indicator` L541, `_on_dialogue_panel_input` L547, `_unhandled_input` L557
  `_on_leave` L566

### `ViewGather`
`scenes/views/view_gather/ViewGather.gd` · 443 líneas · extends `Control`

Vista de recolección / farmeo (bosque, mina, río).
- **funcs:** `setup` L68
- **privadas:** `_ready` L44, `_resolve_res` L55, `_build_ui` L109, `_on_tap_input` L272, `_gather` L285, `_on_idle_tick` L309, `_apply_gather` L322, `_refresh_node` L342
  `_spawn_float` L372, `_refresh_texts` L392, `_refresh_skill_bar` L401, `_refresh_bonus_chip` L417, `_pulse` L439

### `ViewOrbRoom`
`scenes/views/view_orb_room/ViewOrbRoom.gd` · 938 líneas · extends `Control`

«Sala de la Esfera» — una sala 3D oscura con un pequeño altar y una esfera

- **signals:** `orb_finished` L16
- **funcs:** `play` L482
- **privadas:** `_ready` L84, `_on_visibility_changed` L97, `_on_theme_changed` L106, `_update_responsive_layout` L121, `_build_scene` L163, `_mat` L375, `_build_dialogue` L386, `_dialogue_for` L551
  `_death_text_for_cause` L579, `_finish_intro` L644, `_on_continue_pressed` L678, `_skip_conversation` L704, `_present_pages` L735, `_max_dialogue_text_height` L758, `_resize_panel_for_text` L772, `_split_text_into_pages` L795
  `_show_page` L829, `_update_more_indicator` L854, `_advance_pages` L878, `_on_panel_input` L893, `_unhandled_input` L901, `_process` L916

### `ViewPlace`
`scenes/views/view_place/ViewPlace.gd` · 1059 líneas · extends `Control`

Vista de un "Lugar" genérico (ni ciudad ni mazmorra): imagen de fondo + cuadro de
- **funcs:** `get_location_name` L70, `setup` L170
- **privadas:** `_ready` L46, `_exit_tree` L63, `_update_responsive_layout` L78, `_build_ui` L326, `_render` L504, `_set_visual_state_say` L585, `_set_visual_state_choice` L607, `_on_toggle_info` L639
  `_close_info_drawer` L651, `_on_runner_say` L658, `_on_runner_choice` L666, `_on_runner_finished` L674, `_on_stat_increased` L680, `_should_exit_directly_to_world` L689, `_close_view` L702, `_present_say_text` L717
  `_split_text_into_pages` L727, `_show_current_page` L757, `_update_more_indicator` L855, `_advance_dialogue` L872, `_make_vn_button` L898, `_style_vn_button` L912, `_apply_dialogue_theme` L919, `_on_theme_changed` L946
  `_show_choices_from_runner` L952, `_on_choice_selected` L981, `_show_continue_button` L988, `_animate_buttons_in` L1006, `_on_dialogue_panel_input` L1018, `_unhandled_input` L1023, `_refresh_static_texts` L1035, `_leave` L1045

### `ViewShop`
`scenes/views/view_shop/ViewShop.gd` · 784 líneas · extends `Control`

Vista de la Tienda (se abre desde una ciudad). Muestra el catálogo de la ciudad
- **funcs:** `setup` L83
- **privadas:** `_ready` L50, `_on_state_updated` L58, `_input` L67, `_build_ui` L120, `_apply_dialogue_theme` L310, `_setup_visuals` L324, `_refresh` L351, `_refresh_dynamic` L356
  `_refresh_npc_avatar` L365, `_trigger_welcome_dialogue` L397, `_show_text` L412, `_pulse_more_indicator` L433, `_on_dialogue_panel_input` L446, `_render_stock` L467, `_make_item_card` L483, `_update_stock_cards` L614
  `_on_buy` L672, `_equip_text` L741, `_on_leave_pressed` L770, `_unhandled_input` L777

### `ViewTraining`
`scenes/views/view_training/ViewTraining.gd` · 222 líneas · extends `Control`

Vista del Muñeco de Entrenamiento (se abre desde la Base cuando el muñeco está
- **privadas:** `_ready` L23, `_on_state_updated` L31, `_build_ui` L39, `_on_visibility_changed` L151, `_on_train_pressed` L159, `_refresh_texts` L171, `_refresh_footer` L182, `_spawn_float` L193
  `_hit_shake` L210, `_pulse` L218

### `ViewTransport`
`scenes/views/view_transport/ViewTransport.gd` · 443 líneas · extends `Control`

PUESTO DE TRANSPORTE / CARROMATOS EN CIUDADES
- **funcs:** `setup` L50, `get_location_name` L84
- **privadas:** `_ready` L36, `_on_state_updated` L44, `_get_city_name` L63, `_build_ui` L97, `_apply_theme` L230, `_refresh` L244, `_build_destination_card` L317, `_update_welcome_narrative` L393
  `_on_travel_pressed` L425, `_on_leave_pressed` L441

## Componentes (scenes/components)

### `NarrativeOverlay`  ·  autoload **NarrativeOverlay**
`scenes/components/narrative/NarrativeOverlay.gd` · 923 líneas · extends `CanvasLayer`

Autoload (CanvasLayer) — VISTA UNIFICADA DEL SISTEMA NARRATIVO.

- **signals:** `attract_interrupted` L79
- **privadas:** `_ready` L82, `_on_theme_changed` L104, `_update_responsive_layout` L120, `_build_ui` L166, `_process` L296, `_finish_typing` L330, `_on_text_revealed` L342, `_active_text_label` L357
  `_on_stat_increased` L370, `_on_scene_started` L376, `_on_scene_finished` L395, `_on_say_shown` L408, `_on_choice_shown` L462, `_on_dim_input` L508, `_unhandled_input` L520, `_advance_say` L549
  `_make_ctrl_button` L568, `_refresh_ctrl_labels` L578, `_set_auto` L592, `_set_skip` L599, `_on_toggle_auto` L606, `_on_toggle_skip` L613, `_record_history` L623, `_on_open_history` L632
  `_make_history_row` L692, `_close_history` L713, `_on_choice_pressed` L719, `_apply_fx` L727, `_pop_panel` L749, `_shake_panel` L756, `_glow_panel` L766, `_accent_soft_alpha` L779
  `_make_choice_button` L787, `_on_toggle_info` L799, `_close_info_drawer` L812, `_animate_choices_in` L818, `_clear_choices` L827, `_show_continue_hint` L832, `_animate_continue_hint` L853, `_reset_dim` L864
  `_apply_bg` L872, `_hide_all` L884, `_update_ctrl_bar_visibility` L917

### `OrbCompanionOverlay`  ·  autoload **OrbCompanionOverlay**
`scenes/components/orb_companion/OrbCompanionOverlay.gd` · 538 líneas · extends `CanvasLayer`

COMPAÑERO DE LA ESFERA DE LA VERDAD — WIDGET EN PANTALLA & MODO MODAL (REVISIÓN 3)
- **funcs:** `is_modal_active` L46, `show_important_message` L383, `show_bark` L452
- **privadas:** `_ready` L51, `_update_responsive_layout` L81, `_build_ui` L116, `_on_theme_changed` L238, `_process` L250, `_on_draw_orb` L266, `_update_visibility` L303, `_set_overlay_visible` L323
  `_on_orb_pressed` L328, `_on_companion_bark_requested` L350, `_on_bark_requested` L363, `_on_important_message_requested` L372, `_on_modal_dismissed` L423, `_hide_bark` L475, `_hide_modal` L494, `_on_scene_view_changed` L518
  `_on_scene_navigate_to` L522, `_on_scene_tab_switched` L526, `_on_scene_combat_started` L530, `_on_scene_combat_ended` L534

### `RadialMenuOverlay`
`scenes/components/radial_menu/RadialMenuOverlay.gd` · 248 líneas · extends `Control`

Menú Radial Rápido Diegético (TAB / "º" / Gamepad L1).

- **signals:** `action_selected` L8, `closed` L9
- **funcs:** `is_open` L171, `open` L175, `close` L198, `toggle` L219
- **privadas:** `_ready` L39, `_build_ui` L57, `_update_positions` L148, `_on_dim_input` L226, `_on_button_pressed` L235, `_unhandled_input` L243

## UI (scenes/ui)

### `AchievementsViewer`
`scenes/ui/achievements/AchievementsViewer.gd` · 189 líneas · extends `Control`

VISOR DE LOGROS — overlay reutilizable construido por código.

- **signals:** `closed` L14
- **privadas:** `_ready` L21, `_build_ui` L30, `_build_row` L130, `_on_bg_input` L185

### `BestiaryViewer`
`scenes/ui/bestiary/BestiaryViewer.gd` · 266 líneas · extends `Control`

VISOR DE BESTIARIO — overlay reutilizable construido por código.

- **signals:** `closed` L18
- **privadas:** `_ready` L25, `_build_ui` L34, `_seen` L145, `_build_card` L163, `_element_icons` L253, `_on_bg_input` L262

### `CodexViewer`
`scenes/ui/codex/CodexViewer.gd` · 369 líneas · extends `Control`

CÓDICE DE CURIOSIDADES (Task 2) — visor reutilizable construido por código.

- **signals:** `closed` L24
- **privadas:** `_ready` L43, `_build_ui` L52, `_build_progress` L130, `_build_completion_banner` L173, `_build_zones` L210, `_build_codex_card` L235, `_zone_label` L317, `_section_label` L324
  `_empty_note` L333, `_divider` L357, `_on_bg_input` L365

### `CreditsScreen`
`scenes/ui/credits/CreditsScreen.gd` · 909 líneas · extends `Control`

Pantalla cinematográfica de créditos estilo película.

- **signals:** `closed` L13
- **privadas:** `_ready` L46, `_exit_tree` L57, `_build_ui` L66, `_populate_credits_content` L229, `_build_sphere_modal` L582, `_start_sequence` L671, `_play_title_card` L677, `_play_attribution_card` L699
  `_start_credits_roll` L721, `_process` L755, `_on_roll_finished` L769, `_show_sphere_prompt` L790, `_on_sphere_continue_pressed` L799, `_skip_credits` L805, `_close_credits` L830, `_input` L858

### `DungeonsViewer`
`scenes/ui/dungeons/DungeonsViewer.gd` · 251 líneas · extends `Control`

VISOR DE MAZMORRAS — overlay reutilizable construido por código.

- **signals:** `closed` L18
- **privadas:** `_ready` L58, `_build_ui` L67, `_is_completed` L186, `_build_row` L191, `_on_bg_input` L247

### `CharacterHubModal`
`scenes/ui/hub/CharacterHubModal.gd` · 305 líneas · extends `Control`

Hub Macro de Personaje Unificado — Modal Flotante sobre el mundo 3D (30% Izq / 70% Der)

- **signals:** `closed` L6, `request_standalone_options` L12
- **funcs:** `open_at_tab` L166, `switch_tab` L180, `close` L256
- **privadas:** `_ready` L33, `_on_theme_changed` L45, `_build_ui` L54, `_load_tab_content` L211, `_notify_world_modal` L266, `_unhandled_input` L283, `_cycle_tab` L298

### `JournalViewer`
`scenes/ui/journal/JournalViewer.gd` · 377 líneas · extends `Control`

DIARIO / REGISTRO NARRATIVO — overlay reutilizable construido por código.

- **signals:** `closed` L19
- **privadas:** `_ready` L27, `_build_ui` L36, `_build_current_objective` L103, `_build_questline` L144, `_build_secondary_quests` L165, `_secondary_quest_row` L191, `_build_story_progress` L243, `_step_row` L277
  `_fact_row` L316, `_section_label` L356, `_divider` L365, `_on_bg_input` L373

### `LoadingScreen`
`scenes/ui/loading/LoadingScreen.gd` · 224 líneas · extends `Control`

Pantalla de carga asíncrona a pantalla completa con fondo negro sólido,
- **funcs:** `set_progress` L203
- **privadas:** `_ready` L34, `_process` L185, `_show_next_tip` L207

### `MainMenu`
`scenes/ui/main_menu/MainMenu.gd` · 456 líneas · extends `Control`

Pantalla de inicio del juego.
- **privadas:** `_ready` L44, `_exit_tree` L64, `_process` L68, `_input` L91, `_start_attract_mode` L132, `_cancel_attract_mode` L145, `_on_attract_finished` L161, `_update_responsive_layout` L173
  `_build_background` L205, `_animate_title` L246, `_init_secret_triggers` L256, `_on_hero_gui_input` L266, `_on_secret_hero_clicked` L272, `_animate_hero_feedback` L283, `_reveal_debug_buttons` L291, `_refresh_texts` L309
  `_update_continue_state` L323, `_on_btn_new_game_pressed` L333, `_start_new_game` L342, `_on_btn_debug_mode_pressed` L356, `_start_debug_game` L362, `_on_btn_test_room_pressed` L372, `_start_test_room` L378, `_ensure_real_world` L388
  `_on_btn_continue_pressed` L395, `_on_btn_options_pressed` L404, `_on_btn_credits_pressed` L410, `_on_btn_quit_pressed` L418, `_open_overlay` L426, `_close_overlay` L435, `_show_new_game_confirm` L444

### `MinimapViewer`
`scenes/ui/minimap/MinimapViewer.gd` · 297 líneas · extends `Control`

MAPA / MINIMAPA CON NIEBLA DE GUERRA — overlay reutilizable construido por código.

- **signals:** `closed` L18
- **privadas:** `_ready` L31, `_process` L37, `_unhandled_input` L43, `_build_ui` L52, `_draw_map` L114, `_draw_player_pin` L170, `_cell_rect` L180, `_cell_color` L187
  `_is_terrain_icon`(s) L207, `_poi_glyph` L215, `_draw_glyph` L284, `_on_bg_input` L293

### `OptionsMenu`
`scenes/ui/options/OptionsMenu.gd` · 628 líneas · extends `Control`

Overlay reutilizable de Opciones (idioma, volumen, sonido).

- **signals:** `closed` L9, `main_menu_requested` L11
- **funcs:** `close` L573
- **privadas:** `_ready` L55, `_unhandled_input` L68, `_exit_tree` L81, `_build_ui` L91, `_refresh_texts` L412, `_on_theme_changed` L462, `_on_theme_changed_live` L473, `_apply_theme` L481
  `_on_save_game` L498, `_set_orientation` L517, `_on_volume_changed` L522, `_on_font_scale_changed` L527, `_on_text_speed_changed` L532, `_on_locale_selected` L539, `_on_toggle_reduce_motion` L554, `_on_toggle_left_handed` L559
  `_on_toggle_colorblind` L565, `_section_label` L583, `_divider` L589, `_make_choice_button` L595, `_highlight` L606

### `RelationsViewer`
`scenes/ui/relations/RelationsViewer.gd` · 405 líneas · extends `Control`

VISOR DE RELACIONES CON NPCs — sub-vista de la pantalla Información (TabInfo).
- **funcs:** `humanize_id`(s) L383
- **privadas:** `_ready` L55, `_build_ui` L60, `_make_relation_card` L139, `_make_npc_avatar` L213, `_affinity_tier` L274, `_get_npc_info` L284, `_resolve_image_path` L364

### `SplashScreen`
`scenes/ui/splash/SplashScreen.gd` · 384 líneas · extends `Control`

Pantalla cinemática de apertura previa al menú principal.
- **privadas:** `_ready` L59, `_exit_tree` L75, `_unhandled_input` L80, `_load_fonts` L100, `_build_ui` L107, `_on_viewport_size_changed` L297, `_start_animation_sequence` L323, `_skip_to_menu` L366
  `_goto_main_menu` L383

## Otros

### `FireLightFlicker3D`
`scripts/graphics/FireLightFlicker3D.gd` · 70 líneas · extends `OmniLight3D`
- **privadas:** `_ready` L21, `_setup_visibility_culling` L29, `_on_screen_entered` L39, `_on_screen_exited` L46, `_schedule_next_flicker` L53, `_exit_tree` L68

### `OrbRotator3D`
`scripts/graphics/OrbRotator3D.gd` · 53 líneas · extends `Node3D`
- **privadas:** `_ready` L22, `_setup_culler` L27, `_on_screen_entered` L35, `_on_screen_exited` L40, `_process` L45

### `ParticleCuller3D`
`scripts/graphics/ParticleCuller3D.gd` · 39 líneas · extends `VisibleOnScreenNotifier3D`
- **privadas:** `_ready` L18, `_on_screen_entered` L32, `_on_screen_exited` L37

### `PoiAudio3D`
`scripts/graphics/PoiAudio3D.gd` · 27 líneas · extends `AudioStreamPlayer3D`
- **privadas:** `_ready` L16

