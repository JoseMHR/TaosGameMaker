# CODEMAP — Mapa de código (autogenerado)

> ⚙️ **Fichero AUTOGENERADO por `tools/gen_codemap.py`. NO editar a mano.**
> Regénералo tras cambios estructurales:  `python tools/gen_codemap.py`
>
> Índice de ALTA SEÑAL para localizar *dónde tocar* sin abrir ficheros enormes.
> Para saltar a un símbolo concreto, busca en `docs/SYMBOLS.tsv` (`symbol · kind · file · line`).

**Totales:** 146 ficheros `.gd` · 74808 líneas · 2414 funciones.

Leyenda: `nombre Lnn` = función en la línea *nn*. `(s)` = static · `_nombre` = privada.

## Autoloads (singletons)

### `AudioManager`  ·  autoload **AudioManager**
`scripts/autoload/AudioManager.gd` · 440 líneas · extends `Node`

GESTOR GLOBAL DE AUDIO — Autoload/Singleton
- **funcs:** `register_music_paths` L207, `has_music_track` L214, `play_music` L221, `push_music` L277, `push_combat_music` L288, `pop_music` L302, `clear_stack` L314, `stop_music` L319
  `register_ambient_paths` L335, `has_ambient_track` L342, `play_ambient_loop` L350, `stop_ambient_loop` L369, `play_sfx` L389, `play_ui` L421, `play_city_music` L426
- **privadas:** `_ready` L149, `_bind_existing_button_sounds` L172, `_on_node_added_for_sound` L180, `_bind_button_sound` L189, `_on_button_hover` L196, `_apply_crossfade` L267, `_on_ambient_finished` L383

### `Design`  ·  autoload **Design**
`scripts/autoload/Design.gd` · 1730 líneas · extends `Node`

Autoload Singleton — CARGADOR DE DISEÑO DATA-DRIVEN.
- **funcs:** `reload` L192, `get_skill_field` L307, `tr_cell_name` L349, `tr_cell_desc` L364, `world_boat_spawn` L382, `world_spawn` L393, `get_id` L456, `has_id` L461
  `id_raw` L466, `get_dungeon_tile` L471, `get_dungeon_tile_render` L477, `id_name` L484, `id_icon` L489, `get_item` L495, `get_item_name` L499, `get_item_desc` L506
  `get_item_icon` L513, `get_item_category` L517, `has_item_def` L521, `get_profession` L532, `get_professions` L538, `get_profession_skills` L547, `get_skill` L563, `has_skill` L567
  `get_enemy_skill` L574, `get_synergy` L585, `get_triple_synergy` L604, `skill_pa_cost` L628, `skill_tag` L642, `get_enemy` L648, `enemy` L652, `has_dungeon_layout` L664
  `get_dungeon_layout` L671, `all_dungeon_ids` L686, `canonical_dungeon_ids` L693, `get_dungeon_display_name` L706, `get_dungeon_total_floors` L715, `is_dungeon_completed` L728, `kit_piece` L765, `kit_pieces` L773
  `kits` L778, `get_terrain_ambience` L785, `get_weather_def` L794, `pick_terrain_weather` L810, `get_zone_at` L828, `get_zone_music_at` L843, `get_terrain_def` L859, `terrain_is_walkable` L865
  `terrain_damage` L872, `terrain_damage_interval` L876, `terrain_speed_mult` L880, `terrain_hazard` L889, `terrain_is_slippery` L895, `terrain_is_blendable` L900, `get_world_resource` L910, `resolve_gather_resource` L921
  `get_world_building` L933, `get_classic_building_style` L943, `get_cinematic` L976, `has_cinematic` L982, `get_scene` L989, `has_scene` L1000, `get_achievement` L1009, `get_tutorial` L1014
  `get_npc` L1028, `has_npc` L1041, `get_quest_secondary` L1051, `get_quest_secondary_stage` L1066, `npc_meta` L1075, `entry_node` L1098, `resolve_poi_encounter` L1144, `eval_condition` L1195
  `has_item` L1232, `no_item` L1235, `has_flag` L1238, `no_flag` L1241, `gflag` L1246, `has_gflag` L1249, `no_gflag` L1254, `discovered` L1260
  `not_discovered` L1265, `has_quest` L1271, `quest_stage` L1276, `quest_done` L1280, `gate_flag` L1286, `is_gate_locked` L1302, `stat` L1313, `rel` L1327
  `visits_of` L1333, `has_prof` L1339, `no_prof` L1344, `has_all_professions` L1348, `defeated` L1354, `hunt_progress` L1361, `apply_reward` L1368, `get_codex_entry` L1603
  `codex_ids` L1609, `codex_total` L1620, `has_event` L1663, `run_event` L1670, `quest_order` L1695, `quest_desc` L1702, `quest_combat_event` L1716, `get_world_transform` L1728
- **privadas:** `_ready` L186, `_validate_loaded_data` L317, `_build_indices` L335, `_load_json` L407, `_load_ids_dir` L428, `_load_dir_collection` L435, `_dungeon_path` L739, `_ensure_dungeon_ids` L742
  `_ensure_dialogues_loaded` L949, `_ensure_scenes_loaded` L962, `_ensure_cinematics_loaded` L969, `_loc_str` L1019, `_apply_token` L1393, `_emit_global_event` L1585, `_check_codex_completion` L1626, `_give_item` L1638
  `_pint` L1645

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
`scripts/autoload/GlobalState.gd` · 2852 líneas · extends `Node`

Singleton Autoload — Estado global del héroe, inventario y misiones.

- **regions:** `DATOS DEL HÉROE` L25, `FACETAS DE PERSONALIDAD (-10 a +10)` L57, `HABILIDADES DE FARMEO` L62, `BUFFS TEMPORALES DE COMIDA (Cocinero)` L67, `6 SLOTS DE EQUIPAMIENTO` L85, `INVENTARIO, MISIONES Y PROFESIÓN` L136, `ESTADO DEL MAPAMUNDI (persistente)` L250, `ENCARGOS (TABLÓN), CONTADORES Y MEMORIA DE NPCs` L290, `PROGRESO OFFLINE  (marca de tiempo del último guardado, en unix segundos)` L311, `CICLO DE VIDA` L319, `GESTIÓN DE XP Y NIVEL` L573, `RECÁLCULO DE ESTADÍSTICAS DERIVADAS Y EQUIPO` L804, `SUMA DE BONUS DE COMBATE DEL EQUIPO` L831, `GESTIÓN DE INVENTARIO` L914, `ALMACÉN DEL COFRE DE LA BASE (persistente — ver task4.md)` L979, `MÉTODOS DE EQUIPAMIENTO` L1072, `HABILIDADES DE FARMEO — Ganancia de XP` L1101, `RECURSOS DESCUBIERTOS / DESBLOQUEO DE LA BASE` L1166, `NIVELES DE CONSTRUCCIÓN — Mejoras (sumidero de oro + recursos)` L1400, `REINICIO DE CARACTERÍSTICAS (sumidero de oro: devuelve los puntos gastados)` L1424, `BOTÍN, RAREZA, FORJA Y RE-FORJA` L1452, `ENCARGOS (TABLÓN)  — repetibles, dan dirección al bucle` L1502, `FACETAS (consultas) Y MEMORIA DE NPCs` L1664, `ENEMIGOS DEL MAPAMUNDI — derrota y reaparición` L1819, `PROGRESO OFFLINE (idle) — al volver tras cerrar la app` L1909, `COCINA, CONSUMIBLES Y COMIDA` L1922, `MAPA — Marcar coordenada como explorada` L1952, `NODOS DE RECOLECCIÓN FINITOS  (reserva limitada + regeneración temporal)` L1960, `SERIALIZACIÓN (GUARDADO / CARGA)` L2410

- **signals:** `state_updated` L14, `leveled_up` L18, `job_leveled_up` L19, `skill_leveled_up` L23
- **funcs:** `grant_food_buff` L76, `has_food_buff` L80, `set_orientation` L388, `toggle_orientation` L403, `reset_for_new_game` L421, `reset_for_test_room` L521, `add_xp` L574, `debug_add_level` L601
  `debug_remove_level` L618, `add_job_xp` L641, `add_xp_to_all_jobs` L674, `add_job_xp_to` L691, `set_profession` L733, `get_profession_progress` L782, `get_profession_level` L798, `get_stat_with_bonuses` L805
  `recalculate_derived_stats` L813, `get_equip_combat` L833, `get_phys_damage` L848, `get_mag_damage` L856, `get_range_damage` L860, `get_speed` L865, `get_phys_defense` L870, `get_mag_defense` L879
  `get_dodge` L885, `get_crit` L892, `get_accuracy` L899, `get_carry_weight` L906, `add_item` L926, `grant_all_game_items` L933, `inventory_slot_cap` L970, `inventory_slot_count` L975
  `chest_slot_count` L987, `move_item_to_chest` L1017, `move_item_from_chest` L1036, `remove_item` L1058, `has_item` L1062, `get_item` L1066, `add_equipment_item` L1081, `equip_resource` L1087
  `equip_item` L1091, `unequip_item` L1095, `add_skill_xp` L1107, `gather_speed_multiplier` L1137, `gather_amount_multiplier` L1153, `discover_resource` L1169, `discover_lore` L1178, `is_lore_discovered` L1186
  `grant_codex_completion_reward` L1201, `is_building_unlocked` L1206, `is_building_built` L1216, `can_afford_building` L1220, `build_building` L1230, `is_shop_item_sold_out` L1245, `record_shop_purchase` L1251, `get_combat_skill_slots` L1266
  `has_any_job_skill_overflow` L1306, `get_active_combat_skills` L1370, `toggle_active_combat_skill` L1380, `building_level` L1403, `is_building_max` L1406, `building_upgrade_cost` L1409, `can_afford_upgrade` L1412, `upgrade_building` L1415
  `get_dummy_idle_xp` L1418, `spent_stat_points` L1426, `can_reset_stats` L1433, `reset_stats` L1438, `roll_rarity` L1457, `roll_equipment_drop` L1461, `grant_loot` L1466, `grant_loot_entries` L1470
  `can_forge` L1474, `forge` L1478, `is_reforgeable` L1482, `reforge_item` L1487, `can_refine` L1492, `refine_item` L1496, `is_encargo_active` L1507, `encargo_count` L1510
  `can_accept_encargo` L1513, `accept_encargo` L1516, `is_encargo_done` L1519, `claim_encargo` L1522, `encargo_effective_xp` L1527, `report_gather` L1531, `report_kill` L1535, `mark_enemy_seen` L1551
  `record_enemy_kill` L1561, `discover_travel_point` L1609, `get_travel_points` L1617, `discover_enemy_reaction` L1632, `report_visit` L1649, `generate_encargo` L1654, `ensure_encargos_for_city` L1658, `get_relation` L1674
  `add_relation` L1682, `get_faceta` L1689, `get_npc_relationship` L1699, `charm_price` L1706, `npc_visit_count` L1713, `mark_npc_visited` L1717, `npc_has_flag` L1725, `set_npc_flag` L1732
  `has_flag` L1746, `has_world_flag` L1750, `set_world_flag` L1754, `get_world_flag_val` L1758, `spawn_boat_at_port` L1763, `world_delta_key` L1791, `record_world_delta` L1800, `is_overworld_enemy_defeated` L1821
  `defeat_overworld_enemy` L1833, `get_world_delta` L1840, `has_world_delta` L1847, `clear_world_delta` L1853, `is_boss_defeated` L1866, `mark_boss_defeated` L1870, `is_chest_opened` L1876, `open_chest` L1883
  `apply_offline_progress` L1912, `cook` L1926, `cook_recipe` L1930, `use_consumable` L1934, `food_restore_values` L1938, `food_preview` L1942, `eat_food` L1946, `mark_explored` L1954
  `get_gather_remaining` L1998, `get_gather_capacity` L2009, `get_base_coord` L2013, `establish_base_at` L2023, `get_campfire_build_spot` L2092, `build_campfire_at` L2109, `get_camp_structure_def` L2146, `has_camp_structure` L2150
  `camp_current_structure_key` L2154, `camp_level_up_cost` L2158, `can_level_up_camp` L2162, `level_up_camp` L2166, `build_camp_structure` L2181, `can_establish_base_at` L2240, `base_territory_size` L2316, `is_within_base_territory` L2329
  `get_buildable_structure_at` L2345, `is_valid_camp_build_spot` L2358, `consume_gather` L2389, `to_dict` L2413, `from_dict` L2500, `get_surrounding_hex_coords` L2822, `has_all_professions_unlocked` L2841
- **privadas:** `_ready` L358, `_unhandled_input` L411, `_grant_job_xp_to_non_active` L705, `_store_active_job_progress` L743, `_don_nadie_progress` L754, `_load_job_progress_for` L761, `_item_counts_toward_cap` L956, `_slot_count_of` L960
  `_transfer_item_entry` L993, `_default_combat_skill_slots` L1338, `_bestiary_entry` L1541, `_progress_hunt_quests` L1593, `_canonical_npc_id` L1665, `_now_unix` L1962, `_node_key` L1966, `_apply_node_regen` L1970
  `_capacity_for` L1991, `_refresh_base_label` L2075, `_parse_delta_key` L2136, `_is_free_camp_cell` L2260, `_find_free_camp_spot` L2289, `_reset_camp_cell` L2373, `_run_save_migrations` L2487, `_serialize_explored` L2746
  `_deserialize_explored_entry` L2773, `_serialize_equipped` L2786, `_serialize_inventory` L2799, `_serialize_inventory_array` L2804

### `Juice`  ·  autoload **Juice**
`scripts/autoload/Juice.gd` · 562 líneas · extends `Node`

SERVICIO DE "JUICE" (game feel) — Autoload/Singleton
- **funcs:** `show_loading` L274, `set_loading_subtitle` L297, `hide_loading` L303, `reduced` L320, `fade_out` L330, `fade_in` L338, `transition` L349, `view_in` L370
  `hit_stop` L390, `shake` L408, `flash` L477, `pop` L494, `damage_number` L511
- **privadas:** `_ready` L43, `_build_loading_ui` L57, `_draw_loading_web_icon` L175, `_draw_loading_spinner` L199, `_draw_loading_divider` L241, `_process` L264, `_shake_control` L431, `_shake_node2d` L443
  `_shake_camera3d` L455

### `Locale`  ·  autoload **Locale**
`scripts/autoload/Locale.gd` · 1003 líneas · extends `Node`

Autoload Singleton — Internacionalización (i18n) y ajustes persistentes.

- **signals:** `locale_changed` L12, `audio_changed` L15, `accessibility_changed` L18, `theme_changed` L49
- **funcs:** `t` L117, `pick` L132, `is_supported` L144, `set_locale` L153, `toggle_locale` L164, `set_master_volume` L169, `set_sfx_enabled` L176, `set_reduce_motion` L184
  `set_font_scale` L191, `set_colorblind` L206, `set_text_speed` L213, `set_left_handed` L220, `set_ui_theme_id` L229, `has_key` L972, `translate_cell_name` L976, `translate_cell_desc` L984
  `translate_profession` L993
- **privadas:** `_ready` L55, `_ensure_main_theme_cjk` L70, `_resolve_fallback` L94, `_apply_font_scale` L199, `_apply_theme_font` L246, `_load_settings` L261, `_save_settings` L278, `_apply_audio` L292
  `_build_table` L304

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
`scripts/autoload/SceneManager.gd` · 287 líneas · extends `Node`

Autoload Singleton — Gestiona la navegación entre vistas sin destruir escenas.

- **signals:** `navigate_to` L10, `view_changed` L13, `tab_switched` L16, `combat_started` L19, `combat_ended` L23
- **funcs:** `is_orb_allowed` L52, `go_to_splash` L76, `go_to_menu` L86, `go_to_world` L100, `go_to_orb_room` L112, `go_to_place` L118, `go_to_city` L125, `go_to_building` L131
  `back_to_city` L140, `go_to_dungeon` L146, `go_to_cook` L157, `go_to_forge` L163, `go_to_shop` L169, `go_to_training` L175, `go_to_encargos` L183, `go_to_transport` L189
  `go_to_view` L195, `switch_tab` L201, `start_combat` L209, `end_combat` L220, `change_view_threaded` L240
- **privadas:** `_ready` L31, `_process` L260, `_finish_threaded_load` L274

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
`scripts/systems/OrbBarksManager.gd` · 472 líneas · extends `Node`

GESTOR DE FASES Y MENSAJES DE LA ESFERA DE LA VERDAD

- **signals:** `bark_requested` L13, `important_message_requested` L14
- **funcs:** `get_current_phase` L175, `set_phase` L182, `get_small_hint` L196, `trigger_auto_comment` L220, `trigger_bark` L234, `trigger_story_popup` L250, `trigger_bark_key` L255, `trigger_important_message` L267
  `trigger_bark_from_token` L274, `check_overworld_milestones` L282, `trigger_stuck_hint` L360, `reset_stuck_timer` L374, `check_skill_overflow_milestone` L384, `check_trial_completed_milestone` L405
- **privadas:** `_ready` L128, `_load_barks_db` L148, `_process` L160, `_on_state_updated` L378

### `OrbCompanionManager`  ·  autoload **OrbCompanionManager**
`scripts/systems/OrbCompanionManager.gd` · 1760 líneas · extends `Node`

GESTOR DINÁMICO DE DIÁLOGOS Y COMPORTAMIENTO DE LA ESFERA ACOMPAÑANTE

- **signals:** `play_orb_bark` L17
- **funcs:** `trigger_bark` L1359, `play` L1523, `set_cooldown` L1532, `is_on_cooldown` L1537, `notify_step` L1565, `notify_idle` L1622, `on_orb_clicked` L1690, `on_combat_ended` L1734
- **privadas:** `_ready` L1282, `_on_locale_changed` L1294, `_pool` L1301, `_process` L1320, `_get_next_line` L1332, `_init_deck` L1349, `_get_global_state` L1543, `_get_orb_barks_manager` L1550
  `_get_quest_manager` L1557, `_pick_locale` L1676

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
`scripts/systems/WorldMapBuilder.gd` · 761 líneas · extends `RefCounted`

Constructor del MAPAMUNDI (datos) que consume la vista 3D (TabWorld3D).
- **funcs:** `build_into_global`(s) L49, `apply_world_deltas`(s) L442, `apply_delta_to_cell`(s) L467, `apply_transform`(s) L486, `apply_monkey_cleared`(s) L598, `apply_cave_cleared`(s) L616, `apply_dam_opened`(s) L634
- **privadas:** `_make_cell`(s) L186, `_apply_terrain_visual`(s) L287, `_apply_terrain_def`(s) L309, `_apply_grs`(s) L334, `_apply_des`(s) L341, `_apply_ice`(s) L345, `_apply_bad`(s) L350, `_apply_gnd`(s) L354
  `_apply_cst`(s) L359, `_apply_sea`(s) L364, `_apply_mnt`(s) L369, `_apply_lav`(s) L374, `_apply_resource_visual`(s) L383, `_parse_coord_key`(s) L475, `_run_builtin`(s) L496, `_apply_rules`(s) L514
  `_cell_matches`(s) L534, `_apply_set`(s) L559, `_text`(s) L588

## Config (scripts/config)

### `GameConfig`
`scripts/config/GameConfig.gd` · 1139 líneas · extends `RefCounted`
- **funcs:** `xp_needed_for_char_level`(s) L93, `xp_needed_for_job_level`(s) L102, `resource_capacity`(s) L324, `dummy_train_xp`(s) L476, `camp_structures`(s) L516, `block_profile`(s) L574, `offensive_damage`(s) L595, `mitigate`(s) L608
  `heal_amount`(s) L613, `status_def`(s) L632, `status_is_good`(s) L645, `status_incoming_mult`(s) L650, `status_out_mult`(s) L658, `status_atb_mult`(s) L665, `atb_speed_multiplier`(s) L681, `status_crit_add`(s) L685
  `status_dodge_add`(s) L692, `status_any_flag`(s) L699, `get_shop_stock`(s) L784, `rarities`(s) L946, `refine_gold_cost`(s) L1024, `refine_resource_costs`(s) L1029, `get_rarity`(s) L1105, `building_upgrade_gold`(s) L1112
  `all_encargos`(s) L1127, `get_encargo`(s) L1132
- **privadas:** `_load_cfg`(s) L30, `_cf`(s) L40, `_ci`(s) L41, `_cb`(s) L42, `_cs`(s) L43, `_cd`(s) L44, `_merge_camp_structures`(s) L490, `_merge_rarities`(s) L927

### `UiKit`
`scripts/config/UiKit.gd` · 2065 líneas · extends `RefCounted`
- **funcs:** `theme_color`(s) L356, `theme_float`(s) L364, `cjk_fallback_font`(s) L395, `emoji_fallback_font`(s) L416, `ensure_font_cjk_fallback`(s) L441, `ensure_theme_cjk_fallback`(s) L447, `build_theme_font`(s) L457, `theme_font`(s) L479
  `premium_frame`(s) L518, `get_premium_material`(s) L614, `premium_panel`(s) L643, `premium_dialog_panel`(s) L651, `premium_button`(s) L663, `panel`(s) L707, `neoclassic_panel`(s) L724, `card`(s) L737
  `card_tinted`(s) L751, `dialog_panel`(s) L763, `header`(s) L775, `bar_bg`(s) L786, `bar_fill`(s) L796, `chip`(s) L806, `refine_badge`(s) L818, `with_corner_badge`(s) L841
  `button_primary`(s) L857, `button_ghost`(s) L868, `button_outline`(s) L879, `empty`(s) L890, `heading_font`(s) L904, `apply_heading`(s) L918, `section_title`(s) L926, `style_progress`(s) L938
  `style_progress_bordered`(s) L945, `pop`(s) L955, `bind_press_feedback`(s) L970, `style_segmented_tab`(s) L998, `section_header`(s) L1028, `margins`(s) L1040, `margins_all`(s) L1050, `toast`(s) L1056
  `overlay`(s) L1079, `confirm`(s) L1095, `show_ephemeral_modal`(s) L1159, `check_option_facet_req`(s) L1249, `create_narrative_info_drawer`(s) L1315, `show_item_modal`(s) L1414, `alert`(s) L1488, `rarity_color`(s) L1550
  `pill`(s) L1559, `banner`(s) L1572, `hero_card`(s) L1583, `button_tonal`(s) L1596, `avatar`(s) L1655, `resource_pill`(s) L1660, `strip_emojis`(s) L1679, `load_texture_safe`(s) L1690
  `show_stat_toast`(s) L1727, `animate_in`(s) L1883, `animate_out`(s) L1900, `show_harvest_toast`(s) L1919, `show_profession_unlocked_modal`(s) L1945
- **privadas:** `_ensure_cjk_fallback`(s) L426, `_get_premium_border_shader`(s) L499, `_premium_fallback_style`(s) L627

## Recursos (resources)

### `CellResource`
`resources/definitions/CellResource.gd` · 349 líneas · extends `Resource`

Recurso personalizado que define cualquier casilla del mapamundi.
- **funcs:** `has_stone_path` L42, `set_gather_depleted` L137, `is_gather_depleted` L138, `is_growing_crop` L149, `is_crop_mature` L155, `is_walkable_terrain` L178, `is_gather_node` L186, `gather_skill` L191
  `is_solid` L198, `is_interactive` L213, `is_poi` L225, `opens_view` L251, `derive_legacy` L284, `get_display_name` L315, `get_display_description` L334

### `DialogueResource`
`resources/definitions/DialogueResource.gd` · 19 líneas · extends `Resource`

Recurso personalizado para diseñar diálogos estilo Novela Visual.

### `EquipmentResource`
`resources/definitions/EquipmentResource.gd` · 80 líneas · extends `Resource`

Recurso personalizado para definir armas, armaduras y accesorios del héroe.
- **funcs:** `active_traits` L51, `get_combat` L61, `refine_multiplier` L71, `effective_stat_bonus` L75, `effective_combat` L79

## Game Root / navegación

### `GameRoot`
`scenes/game/game_root/GameRoot.gd` · 2654 líneas · extends `Control`

Escena principal del juego — contiene HUD, ViewStack y TabBar.
- **funcs:** `is_radial_menu_open` L1742, `open_hub_modal_tab` L1818, `open_character_subtab` L1824, `refresh_hud_location_title` L1989
- **privadas:** `_ready` L112, `_on_hud_theme_changed` L161, `_set_hud_panel_visible` L179, `_update_radial_button_visibility` L188, `_update_responsive_layout` L198, `_setup_redesigned_hud` L344, `_apply_hud_scale` L575, `_build_floating_radial_button` L623
  `_style_floating_radial_button` L662, `_draw_radial_hamburger` L683, `_build_floating_map_button` L705, `_style_floating_map_button` L745, `_build_hud_profession_modal` L769, `_setup_hud_profession_modal` L836, `_open_hud_profession_modal` L928, `_on_hud_profession_selected` L948
  `_instantiate_views` L955, `_connect_signals` L996, `_on_achievement_unlocked` L1038, `_on_tutorial_step` L1047, `_on_leveled_up` L1055, `_on_job_leveled_up` L1062, `_on_skill_leveled_up` L1074, `_announce_levelup` L1102
  `_flush_pending_levelup_toasts` L1113, `_show_levelup_flow` L1123, `_profession_name_str` L1193, `_on_game_saved` L1201, `_show_meta_toast` L1215, `_on_navigate_to` L1289, `_on_tab_switched` L1452, `_enter_orb_room` L1478
  `_on_orb_finished` L1491, `_on_dam_opened` L1518, `_run_dam_cinematic` L1528, `_recreate_world_view` L1553, `_flash_transition` L1573, `_on_combat_started` L1585, `_on_combat_ended` L1606, `_input` L1634
  `_shortcut_input` L1646, `_unhandled_key_input` L1650, `_is_radial_hotkey` L1654, `_handle_global_hotkeys` L1676, `_toggle_radial_menu` L1746, `_on_radial_menu_closed` L1758, `_get_or_create_hub_modal` L1774, `_on_hub_modal_closed` L1784
  `_on_hub_wants_standalone_options` L1792, `_on_radial_action_selected` L1798, `_toggle_floating_view` L1831, `_handle_escape_key` L1852, `_show_view` L1932, `_update_hud_center_and_right_slots` L1993, `_build_location_bar` L2069, `_update_location_bar` L2110
  `_location_title` L2119, `_build_hazard_bar` L2128, `_process` L2175, `_hazard_fill_mult` L2200, `_refresh_hazard_bar` L2214, `_player_died_from_hazard` L2230, `_refresh_hud` L2252, `_start_hud_hp_danger` L2322
  `_stop_hud_hp_danger` L2333, `_refresh_materials_row` L2343, `_hero_symbol` L2401, `_profession_label` L2409, `_refresh_tab_texts` L2417, `_on_locale_changed` L2439, `_set_world_modal` L2450, `_open_menu` L2466
  `_close_menu` L2480, `_on_return_to_main_menu` L2488, `_set_active_tab` L2519, `_on_passive_timer_timeout` L2559, `_on_btn_close_cs_pressed` L2569, `_check_offline_progress` L2576, `_show_offline_popup` L2584, `_format_offline_time` L2640
  `_res_display` L2649

## Tabs (pestañas inferiores)

### `TabBag`
`scenes/tabs/tab_bag/TabBag.gd` · 894 líneas · extends `Control`

Controlador de la pestaña de la Bolsa/Inventario.
- **privadas:** `_ready` L40, `_update_responsive_layout` L58, `_build_shell` L160, `_refresh_v_catbar` L238, `_is_inside_hub` L279, `_on_close_pressed` L291, `_refresh_ui` L301, `_on_locale_changed` L314
  `_switch_category` L324, `_active_includes` L330, `_is_bag_usable` L341, `_render_inventory` L360, `_make_item_card` L419, `_enable_drag_scroll` L637, `_get_item_bonuses_text` L654, `_columns_for_width` L686
  `_use_consumable` L696, `_use_important_item` L716, `_inspect_equipment` L739

### `TabCharacter`
`scenes/tabs/tab_character/TabCharacter.gd` · 1795 líneas · extends `Control`

Controlador de la Ficha de Personaje. Muestra Stats + Facetas en una única
- **privadas:** `_ready` L72, `_build_shell` L96, `_refresh_v_sidebar` L164, `_on_close_pressed` L195, `_update_responsive_layout` L205, `_subtab_defs` L295, `_switch_subtab` L307, `_on_locale_changed` L313
  `_refresh` L321, `_restore_scroll_vertical` L342, `_build_unified_3col` L350, `_ignore_mouse_recursive` L385, `_enable_drag_scroll` L393, `_new_scroll_host` L411, `_hero_symbol` L436, `_profession_texture` L450
  `_profession_icon` L457, `_profession_name` L464, `_profession_color` L469, `_hsep` L477, `_labeled_bar` L482, `_pending_points_total` L506, `_remaining_stat_points` L514, `_build_points_banner` L525
  `_build_stats` L603, `_accordion_section` L641, `_build_core_section` L668, `_build_combat_section` L681, `_build_professions_section` L693, `_build_oficios_section` L698, `_simulated_stat` L702, `_derived_list` L707
  `_build_professions_summary` L785, `_make_profession_summary_row` L826, `_make_profession_summary_card` L882, `_make_core_stat_card` L937, `_make_reset_button` L1055, `_confirm_pending_stat_alloc` L1098, `_show_reset_confirm` L1115, `_make_derived_card` L1130
  `_build_dungeon_skills` L1190, `_build_exploration_skill_card` L1198, `_build_facetas` L1253, `_make_facet_card` L1272, `_make_center_bar` L1327, `_build_oficio` L1379, `_oficios` L1435, `_make_skill_card` L1448
  `_build_profesiones` L1510, `_two_column_grid` L1556, `_make_profession_icon_button` L1572, `_make_profession_activate_button` L1618, `_make_technique_card` L1683

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
`scenes/tabs/tab_professions/TabProfessions.gd` · 965 líneas · extends `Control`

Vista dedicada a la gestión de Profesiones y asignación de 4 Habilidades de Combate.
- **privadas:** `_ready` L44, `_build_ui` L57, `_enable_drag_scroll` L224, `_refresh` L240, `_render_prof_list` L252, `_ignore_mouse_recursive` L455, `_render_active_slots` L462, `_render_catalog` L546
  `_render_upcoming` L666, `_assign_skill` L739, `_on_activate_pressed` L768, `_render_oficios_list` L774, `_show_skill_info_modal` L886

### `TabWorld3D`
`scenes/tabs/tab_world_3d/TabWorld3D.gd` · 5346 líneas · extends `Control`

PROTOTIPO V2 DEL MAPAMUNDI — Entorno 3D con cámara top-down.

- **regions:** `CICLO DE VIDA` L588, `CONSTRUCCIÓN DE LA ESCENA 3D (SubViewport + cámara + luz + jugador)` L1183, `CONSTRUCCIÓN DE CASILLAS 3D` L1652, `NIEBLA DE GUERRA — aplicada a materiales (oculto / penumbra / visible)` L3286, `PATHFINDING Y GATING` L3291, `INPUT — MOVIMIENTO LIBRE (joystick táctil + teclado) y botón ENTRAR` L3448, `BARCO — navegación por costa/mar (ver GlobalState.boat_pos/is_sailing)` L3580, `CICLO DÍA / NOCHE — ILUMINACIÓN (consume TimeManager.daylight_factor())` L4004, `DAÑO AMBIENTAL POR TERRENO (data-driven: data/world_terrains/<code>.json)` L4014, `RELOJ DEL MUNDO (UI del ciclo día/noche)` L4109, `JOYSTICK VIRTUAL (aparece donde tocas en la zona inferior-izquierda)` L4287, `TELETRANSPORTE Y SPAWN SEGURO (evita siempre aparecer en mar, montaña o casillas bloqueantes)` L4323, `PANEL INFERIOR (ubicación / viaje) — construido por código` L4455, `GATING POR FASE DÍA/NOCHE (data-driven, reutilizable)` L4478, `HERRAMIENTAS + MODIFICACIÓN DEL TERRENO / CAMPAMENTO / ENEMIGOS` L4521, `OBJETOS INTERACTIVOS (cartel/lápida/libro…) — ventana de texto reutilizable` L4527, `RECOLECCIÓN EN EL MUNDO (sin cambiar de vista)` L4871, `SISTEMA DE MISIONES Y DIÁLOGO (con la corrección de aplazamiento)` L5099, `LOCALE` L5249, `CÁMARA DE CINEMÁTICAS (desacoplada del Sistema Narrativo)` L5286, `CINEMÁTICA DE LA PRESA PROGRESIVA` L5305
- **funcs:** `set_modal_mode` L745, `is_cell_passable` L3405, `hide_clock_and_map` L4117, `release_clock_and_map` L4133, `attach_clock_and_map_to_slot` L4148, `ensure_map_button` L4182, `teleport_player_to` L4424, `get_active_location_title` L4466
  `run_dam_opened_cinematic` L5310
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
  `_spawn_world_float` L4986, `_show_discovery_banner` L5009, `_maybe_announce_discovery` L5059, `_reveal_around` L5085, `_setup_quest_system` L5100, `_on_visibility_changed` L5114, `_enable_subviewport_when_ready` L5180, `_on_map_cell_changed` L5189
  `_on_combat_triggered` L5212, `_rebuild_marker` L5227, `_on_locale_changed` L5250, `_refresh_world_labels_text` L5258, `_refresh_world_labels_theme` L5273, `_on_cine_camera_event` L5296, `_on_scene_runner_finished` L5299, `_get_propagation_delay` L5313
  `_spawn_temp_tile_popup` L5316, `_update_base_aura` L5319, `_check_puerto_crisis_event` L5325

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
`scenes/tabs/tab_world_3d/interactive/TravelSystem.gd` · 132 líneas · extends `RefCounted`

VIAJE RÁPIDO: overlay con los destinos descubiertos (incluida la tienda de
- **funcs:** `open_travel_menu`(s) L18, `travel_to`(s) L114, `close_travel_overlay`(s) L129

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
`scenes/tabs/tab_world_3d/interactive/WorldHudBuilder.gd` · 639 líneas · extends `RefCounted`

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
`scenes/views/view_combat/ViewCombat.gd` · 4682 líneas · extends `Control`

SISTEMA DE COMBATE REDISEÑADO: TIEMPO REAL ACTIVO (ATB) + SINERGIAS + DEFENSA ACTIVA

- **regions:** `CICLO DE VIDA E INICIALIZACIÓN DE LA UI` L892, `INICIAR COMBATE` L2287, `BUCLE DE PROCESAMIENTO ATB EN TIEMPO REAL` L2525, `EJECUCIÓN DE ACCIONES` L2560, `BULLET-TIME Y ANILLO DE IMPACTO (QTE DE DEFENSA, task_reforma_defensa.md)` L3599, `BOTONES DE ACCIONES RÁPIDAS` L3731, `ENCOLAR Y CHEQUEAR SINERGIAS (por IDs, data-driven desde synergies.json)` L3879, `GESTIÓN DE TABS E INTERFAZ SELECCIÓN` L4080, `RESOLUCIÓN DE COMBATE Y DAÑO / ESTADOS ALTERADOS` L4086, `PANEL DE RESULTADO, REFRESCO DE BARRAS/COLA Y BOTONES` L4153, `AUXILIARES E IA DEL ENEMIGO` L4275

- **signals:** `combat_ended` L11
- **funcs:** `set_hero_defending` L797, `play_hero_attack_reaction` L804, `play_hero_hurt_reaction` L811, `toggle_pause` L2050, `set_paused` L2056, `add_sintonia` L2239, `reset_hero_position` L2288, `start_combat` L2312
  `regen_combat_mp` L3150, `play_enemy_hurt_reaction` L3590, `apply_damage_to_enemy` L4093, `apply_damage_to_player` L4096, `update_queue_ui_elements` L4166, `calculate_special_damage` L4279, `log_message` L4306
- **privadas:** `_make_console_divider` L284, `_style_glossy_bar` L299, `_panel_style` L321, `_set_command_bar_dimmed` L338, `_show_enemy_attack_banner` L354, `_hide_enemy_attack_banner` L378, `_start_defense_pulse` L394, `_stop_defense_pulse` L410
  `_start_hero_idle_breathing` L423, `_play_hero_attack_lunge` L437, `_play_hero_defend_brace` L466, `_play_hero_hurt_shake` L496, `_play_hero_lunge_action` L524, `_style_jrpg_button` L528, `_set_jrpg_button_labels` L594, `_theme_color` L611
  `_safe_reparent` L616, `_apply_console_layout` L634, `_rescale_jrpg_button` L734, `_apply_top_hud_layout` L758, `_get_hero_full_body_texture_path` L771, `_update_hero_sprite_pose` L776, `_load_portrait_texture` L817, `_apply_orientation_layout` L839
  `_ready` L913, `_on_ui_theme_changed` L937, `_on_view_resized` L946, `_build_ui` L956, `_build_enemy_attack_banner` L1831, `_setup_profession_modal` L1930, `_unhandled_input` L2032, `_open_profession_modal` L2070
  `_on_profession_selected` L2088, `_update_quick_skill_info` L2093, `_toggle_compact_deck` L2117, `_make_stat_bar_direct` L2131, `_stat_bar_value_direct` L2150, `_make_ghost_hp_bar` L2165, `_animate_hp_bar` L2190, `_queue_slot_style` L2214
  `_show_resonance_max_banner` L2250, `_process` L2529, `_is_awaiting_decision` L2563, `_on_player_turn_ready` L2569, `_base_pa_limit` L2594, `_effective_pa_cost` L2599, `_get_max_queue_slots` L2609, `_execute_queue_sequence` L2615
  `_add_resonance_for_skill` L2693, `_grant_dummy_training_xp` L2707, `_resolve_player_skill` L2722, `_resolve_class_change_action` L2923, `_effect_hit_count` L2952, `_apply_skill_effect` L2968, `_apply_named_effect` L2998, `_apply_random_big_effect` L3071
  `_show_resonant_aura` L3102, `_rebuild_powers_if_active` L3144, `_execute_basic_attack_damage` L3162, `_choose_enemy_skill` L3185, `_telegraph_enemy_intent` L3255, `_execute_enemy_action` L3307, `_play_enemy_windup` L3562, `_play_enemy_lunge` L3574
  `_atb_diff_to_ring_radius` L3604, `_hero_chest_global_pos` L3611, `_enter_camera_focus` L3623, `_exit_camera_focus` L3641, `_enter_bullet_time` L3660, `_exit_bullet_time` L3681, `_resolve_defense_encounter` L3694, `_force_end_defense_effects` L3709
  `_on_btn_attack_pressed` L3733, `_on_btn_defense_pressed` L3762, `_play_perfect_parry_flash` L3835, `_block_full_block` L3850, `_block_damage_mult` L3863, `_on_skill_pressed` L3880, `_check_and_fuse_synergies` L3933, `_animate_skill_fly` L3940
  `_flash_skill_card` L3998, `_animate_synergy_fusion` L4010, `_skill_name` L4066, `_recount_queued_pa` L4072, `_play_intro_sequence` L4090, `_end_combat` L4099, `_resolve_attack_on_enemy` L4102, `_reveal_elemental_reaction` L4105
  `_consume_status` L4108, `_status_tick` L4111, `_decrement_statuses` L4114, `_apply_status` L4117, `_try_apply_status_to_enemy` L4120, `_try_apply_status_to_player` L4123, `_apply_skill_status` L4126, `_update_status_labels` L4129
  `_rebuild_status_icons` L4132, `_rebuild_status_icons_deferred` L4135, `_status_summary` L4138, `_status_icon` L4141, `_status_color` L4144, `_status_label` L4147, `_animate_result_panel` L4157, `_shake` L4160
  `_build_queue_box_mapping` L4163, `_animate_synergy_badge` L4169, `_on_queue_slot_clicked` L4172, `_update_player_bars` L4175, `_update_resonance_glow` L4178, `_start_hp_danger_pulse` L4181, `_stop_hp_danger_pulse` L4184, `_sync_player_atb_labels` L4187
  `_update_action_buttons` L4190, `_refresh_chrome` L4193, `_on_btn_return_pressed` L4196, `_update_flee_button` L4199, `_update_enemy_hp_bar_color` L4231, `_on_btn_flee_pressed` L4246, `_on_btn_one_hit_kill_pressed` L4266, `_enemy_name` L4330
  `_resolve_combat_background_path` L4337, `_resolve_combat_platform_path` L4454, `_get_legacy_fallback_platform` L4519, `_element_icon` L4528, `_icons_for` L4532, `_enemy_info_text` L4539, `_skill_type_color` L4553, `_format_drops` L4564
  `_update_defense_ring_geometry` L4577, `_align_enemy_and_platform` L4585

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
`scenes/views/view_dungeon/ViewDungeon.gd` · 2585 líneas · extends `Control`

CONTROLADOR DE EXPLORACIÓN DE MAZMORRA EN 3D (Primera Persona)
- **funcs:** `get_dungeon_name` L247, `setup` L789, `stop_exploration` L1058, `resume_exploration` L1065, `purge_dungeon_temp_elements`(s) L1260, `set_active_checkpoint` L1908
- **privadas:** `_ready` L198, `_on_dungeon_visibility_changed` L228, `_enable_subviewport_when_ready` L241, `_update_responsive_layout` L291, `_reposition_minimap` L314, `_build_hazard_overlay` L334, `_build_snow_mist_overlay` L343, `_build_exploration_hud` L362
  `_build_minimap` L370, `_draw_dungeon_menu_hamburger` L414, `_setup_minimap_floor` L434, `_build_skill_effects` L452, `_on_time_slow_changed` L468, `_process` L486, `_update_tutorial_barks` L532, `_build_joystick` L589
  `_input` L643, `_can_start_joystick_at` L700, `_start_left_joystick` L709, `_update_left_joystick` L719, `_reset_left_joystick` L727, `_position_left_joystick` L737, `_start_right_joystick` L743, `_update_right_joystick` L753
  `_reset_right_joystick` L761, `_position_right_joystick` L771, `_refresh_chrome` L777, `_build_debug_lab` L1012, `_setup_tutorial` L1035, `_restore_trial_profession` L1052, `_setup_dungeon_enemies` L1094, `_on_enemy_combat_triggered` L1110
  `_get_boss_data` L1158, `_boss_key` L1169, `_remove_defeated_boss_nodes` L1181, `_collect_boss_nodes` L1191, `_update_boss_teleport_visibility` L1203, `_fallback_layout` L1232, `_fallback_cells` L1241, `_clean_up_3d` L1268
  `_on_btn_leave_pressed` L1289, `_force_unlock_movement_on_exit` L1310, `_on_exit_portal_entered` L1316, `_handle_exit_portal` L1326, `_apply_dungeon_exit_to` L1398, `_apply_named_portal_exit` L1424, `_find_portal_world_coord` L1450, `_on_chest_entered` L1477
  `_dim_chest_meshes` L1573, `_char_chest_meshes` L1584, `_show_chest_loot_dialogue` L1598, `_on_dungeon_cinematic_entered` L1678, `_trigger_dungeon_cinematic` L1687, `_on_teleport_entered` L1711, `_on_player_died` L1765, `_show_prologue_game_over` L1776
  `_on_player_took_damage` L1869, `_on_player_water_changed` L1888, `_rest_overlay_color` L1899, `_cache_snow_walls` L1922, `_check_snow_dungeon_lost` L1943, `_trigger_snow_lost` L1972, `_hide_world_map_button` L2050, `_unhandled_input` L2063
  `_setup_dun_final_6_event` L2070, `_start_memory_procession_sequence` L2103, `_collect_all_npc_memories` L2176, `_spawn_avatar_memory_node` L2263, `_show_sphere_discourse` L2347, `_build_memory_bridge` L2530

### `DungeonClimbZone`
`scenes/views/view_dungeon/components/DungeonClimbZone.gd` · 16 líneas · extends `Area3D`

Franja adosada a la cara abierta de un muro escalable (idea.md §1.1). Mismo
- **privadas:** `_ready` L6, `_on_body_entered` L10, `_on_body_exited` L14

### `DungeonEnemy`
`scenes/views/view_dungeon/components/DungeonEnemy.gd` · 477 líneas · extends `StaticBody3D`

CONTROLADOR DE ENEMIGOS EN LA MAZMORRA 3D

- **signals:** `combat_triggered` L19
- **funcs:** `refresh_visuals` L170, `trigger_combat_now` L475
- **privadas:** `_ready` L84, `_setup_detection_range` L149, `_start_idle_animation` L195, `_perform_float` L199, `_start_patrol` L216, `_process` L230, `_is_wall_ahead` L261, `_pick_cronofago_direction` L283
  `_process_cronofago` L336, `_is_time_distort_active` L396, `_find_player` L410, `_update_detection_color` L428, `_on_interaction_entered` L450, `_on_interaction_exited` L458, `_on_detection_entered` L463, `_on_detection_exited` L468

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
`scenes/views/view_dungeon/components/DungeonSpikesZone.gd` · 19 líneas · extends `Area3D`
- **funcs:** `set_active` L10
- **privadas:** `_ready` L7, `_on_body_entered` L15

### `DungeonWaterZone`
`scenes/views/view_dungeon/components/DungeonWaterZone.gd` · 25 líneas · extends `Area3D`
- **privadas:** `_ready` L11, `_on_body_entered` L15, `_on_body_exited` L21

### `GridDungeonStage`
`scenes/views/view_dungeon/components/GridDungeonStage.gd` · 5668 líneas · extends `Node3D`

ESCENARIO 3D GENÉRICO Y DATA-DRIVEN DE MAZMORRA DE REJILLA
- **funcs:** `resolve_theme_key`(s) L318, `build` L447, `get_floor_surface_kind` L644, `add_exit_teleport_at` L2380, `trigger_actuator` L4750, `cell_to_world` L5480, `cell_from_world` L5488
- **privadas:** `_get_shared_box_mesh`(s) L366, `_get_shared_box_shape`(s) L375, `_defer_tween_setup` L438, `_ready` L491, `_process` L505, `_process_distance_culling` L515, `_cache_floor_geometry` L543, `_process_geometry_culling` L565
  `_process_interactive_highlights` L586, `_build_materials` L648, `_make_water_shader_mat` L723, `_make_poison_shader_mat` L752, `_make_lava_shader_mat` L772, `_create_lava_smoke_particles` L792, `_build_environment` L834, `_build_void_floor` L990
  `_build_void_lava` L1033, `_build_void_spikes` L1098, `_build_void_abyss` L1171, `_build_floor` L1236, `_add_ceiling` L1275, `_add_ambient_dust` L1293, `_build_cell` L1324, `_add_floor_slab` L1662
  `_add_lava_slab` L1677, `_add_wall_block` L1729, `_add_model` L1761, `_add_liquid` L1797, `_add_spikes` L1915, `_set_hazard_warning` L2025, `_build_generic` L2057, `_register_light_element` L2095
  `_hazard_script` L2107, `_add_light_from_spec` L2119, `_add_enemy` L2130, `_add_marker` L2151, `_add_item_pickup_visual` L2233, `_add_cinematic_marker_visual` L2278, `_add_npc_marker_visual` L2336, `_get_portal_vortex_material`(s) L2430
  `_get_portal_ring_material`(s) L2444, `_add_teleport_visual` L2467, `_process_portal_facing` L2621, `_add_chest` L2650, `_build_lowpoly_chest` L2728, `_mesh_node` L2783, `_find_first_mesh_instance` L2792, `_track_interactable_mesh` L2808
  `_add_light` L2825, `_process_light_culling` L2849, `_process_flicker_lights` L2883, `_add_flicker` L2907, `_add_pulse` L2923, `_apply_transform` L2938, `_add_ramp` L2960, `_add_quad_st` L3065
  `_add_door` L3087, `_add_gate` L3227, `_add_shutters` L3289, `_add_actuator` L3365, `_add_weight_plate` L3548, `_canonical_wall_face` L3635, `_cell_type_at` L3644, `_has_wall_on_face` L3654
  `_add_torch` L3659, `_add_crystal` L3721, `_get_font` L3749, `_add_signage_overlay` L3776, `_add_floor_clutter` L4054, `_scatter_roll` L4099, `_strip_collisions` L4109, `_apply_wall_decor` L4121
  `_apply_corner_decor` L4185, `_apply_floor_decal` L4234, `_add_column` L4289, `_resolve_rotation_degrees` L4322, `_calculate_node_aabb` L4338, `_add_decor_prop` L4355, `_add_barrel` L4457, `_add_crate` L4462
  `_add_statue` L4469, `_add_smart_object` L4496, `_add_sign` L4527, `_add_rune` L4571, `_add_campfire` L4597, `_campfire_particles` L4644, `_wire_actuators` L4674, `_replay_persisted_actuators` L4686
  `_actuator_flag_key` L4712, `_is_actuator_persisted_active` L4717, `_on_gate_open_event` L4723, `_exit_tree` L4729, `_on_actuator_entered` L4742, `_element_anchor_node` L4888, `_spawn_energy_link` L4907, `_start_earthquake_loop` L4938
  `_run_earthquake_step` L4945, `_convert_floor_to_lava` L4957, `_register_element` L5087, `_apply_action` L5104, `_set_element_state` L5137, `_animate_door` L5170, `_animate_gate` L5188, `_animate_shutters` L5212
  `_animate_light` L5228, `_animate_lever` L5246, `_animate_plate` L5288, `_animate_wall_switch` L5308, `_animate_spikes` L5327, `_spawn_dust_burst` L5370, `_identify_boss_teleports` L5409, `_compute_spawn` L5470
  `_cell_height` L5495, `_tinted` L5503, `_surface_material` L5521, `_tile_model_override` L5558, `_uv_scale_for` L5569, `_parse_color` L5575, `_surface_tint` L5631, `_add_cell_light` L5645
  `_marker_color` L5656

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
`scenes/views/view_dungeon/interaction/hud/ExplorationHud.gd` · 506 líneas · extends `Control`

HUD DE HABILIDADES DE EXPLORACIÓN

- **signals:** `menu_pressed` L21
- **funcs:** `bind` L76, `set_tutorial_highlight` L355, `add_minimap` L482, `blocks_joystick_point` L495
- **privadas:** `_ready` L65, `_build` L92, `_draw_btn_menu_hamburger` L182, `_layout` L204, `_layout_grid_landscape` L235, `_layout_grid_portrait` L273, `_process` L308, `_refresh_static` L338
  `_on_target_changed` L346, `_draw_reticle` L364, `_skills_for_verbs` L399, `_on_element_changed` L409, `_on_skill_activated` L439, `_on_skill_failed` L445, `_on_skill_used` L466, `_on_menu_button_pressed` L472

### `ExplorationSkillButton`
`scenes/views/view_dungeon/interaction/hud/ExplorationSkillButton.gd` · 208 líneas · extends `Button`

BOTÓN CIRCULAR DE HABILIDAD DE EXPLORACIÓN

- **signals:** `activated` L19
- **funcs:** `setup` L45, `set_diameter` L61, `set_state` L69
- **privadas:** `_ready` L38, `_process` L84, `_on_pressed` L97, `_draw` L102, `_held` L207

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
`scenes/views/view_gather/ViewGather.gd` · 455 líneas · extends `Control`

Vista de recolección / farmeo (bosque, mina, río).
- **funcs:** `setup` L69
- **privadas:** `_ready` L45, `_resolve_res` L56, `_build_ui` L115, `_on_tap_input` L278, `_gather` L291, `_on_idle_tick` L315, `_apply_gather` L328, `_refresh_node` L348
  `_spawn_float` L378, `_refresh_texts` L398, `_refresh_skill_bar` L413, `_refresh_bonus_chip` L429, `_pulse` L451

### `ViewOrbRoom`
`scenes/views/view_orb_room/ViewOrbRoom.gd` · 946 líneas · extends `Control`

«Sala de la Esfera» — una sala 3D oscura con un pequeño altar y una esfera

- **signals:** `orb_finished` L16
- **funcs:** `play` L490
- **privadas:** `_ready` L84, `_on_visibility_changed` L97, `_on_theme_changed` L106, `_update_responsive_layout` L121, `_build_scene` L163, `_mat` L375, `_build_dialogue` L386, `_dialogue_for` L559
  `_death_text_for_cause` L587, `_finish_intro` L652, `_on_continue_pressed` L686, `_skip_conversation` L712, `_present_pages` L743, `_max_dialogue_text_height` L766, `_resize_panel_for_text` L780, `_split_text_into_pages` L803
  `_show_page` L837, `_update_more_indicator` L862, `_advance_pages` L886, `_on_panel_input` L901, `_unhandled_input` L909, `_process` L924

### `ViewPlace`
`scenes/views/view_place/ViewPlace.gd` · 1076 líneas · extends `Control`

Vista de un "Lugar" genérico (ni ciudad ni mazmorra): imagen de fondo + cuadro de
- **funcs:** `get_location_name` L70, `setup` L182
- **privadas:** `_ready` L46, `_exit_tree` L63, `_update_responsive_layout` L90, `_build_ui` L338, `_render` L516, `_set_visual_state_say` L597, `_set_visual_state_choice` L619, `_on_toggle_info` L651
  `_close_info_drawer` L663, `_on_runner_say` L670, `_on_runner_choice` L678, `_on_runner_finished` L686, `_on_stat_increased` L692, `_should_exit_directly_to_world` L701, `_close_view` L714, `_present_say_text` L729
  `_split_text_into_pages` L739, `_show_current_page` L769, `_update_more_indicator` L867, `_advance_dialogue` L884, `_make_vn_button` L910, `_style_vn_button` L924, `_apply_dialogue_theme` L931, `_on_theme_changed` L958
  `_show_choices_from_runner` L964, `_on_choice_selected` L993, `_show_continue_button` L1000, `_animate_buttons_in` L1018, `_on_dialogue_panel_input` L1030, `_unhandled_input` L1035, `_refresh_static_texts` L1047, `_leave` L1062

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
`scenes/views/view_transport/ViewTransport.gd` · 455 líneas · extends `Control`

PUESTO DE TRANSPORTE / CARROMATOS EN CIUDADES
- **funcs:** `setup` L50, `get_location_name` L88
- **privadas:** `_ready` L36, `_on_state_updated` L44, `_get_city_name` L63, `_build_ui` L109, `_apply_theme` L242, `_refresh` L256, `_build_destination_card` L329, `_update_welcome_narrative` L405
  `_on_travel_pressed` L437, `_on_leave_pressed` L453

## Componentes (scenes/components)

### `NarrativeOverlay`  ·  autoload **NarrativeOverlay**
`scenes/components/narrative/NarrativeOverlay.gd` · 936 líneas · extends `CanvasLayer`

Autoload (CanvasLayer) — VISTA UNIFICADA DEL SISTEMA NARRATIVO.

- **signals:** `attract_interrupted` L79
- **privadas:** `_ready` L82, `_on_theme_changed` L104, `_update_responsive_layout` L120, `_build_ui` L166, `_process` L298, `_finish_typing` L332, `_on_text_revealed` L344, `_active_text_label` L359
  `_on_stat_increased` L372, `_on_scene_started` L378, `_on_scene_finished` L397, `_on_say_shown` L410, `_on_choice_shown` L464, `_input` L510, `_on_dim_input` L517, `_unhandled_input` L529
  `_advance_say` L558, `_make_ctrl_button` L577, `_refresh_ctrl_labels` L588, `_set_auto` L602, `_set_skip` L609, `_on_toggle_auto` L616, `_on_toggle_skip` L623, `_record_history` L636
  `_on_open_history` L645, `_make_history_row` L705, `_close_history` L726, `_on_choice_pressed` L732, `_apply_fx` L740, `_pop_panel` L762, `_shake_panel` L769, `_glow_panel` L779
  `_accent_soft_alpha` L792, `_make_choice_button` L800, `_on_toggle_info` L812, `_close_info_drawer` L825, `_animate_choices_in` L831, `_clear_choices` L840, `_show_continue_hint` L845, `_animate_continue_hint` L866
  `_reset_dim` L877, `_apply_bg` L885, `_hide_all` L897, `_update_ctrl_bar_visibility` L930

### `OrbCompanionOverlay`  ·  autoload **OrbCompanionOverlay**
`scenes/components/orb_companion/OrbCompanionOverlay.gd` · 588 líneas · extends `CanvasLayer`

COMPAÑERO DE LA ESFERA DE LA VERDAD — WIDGET EN PANTALLA & MODO MODAL (REVISIÓN 3)
- **funcs:** `is_modal_active` L46, `show_important_message` L433, `show_bark` L502
- **privadas:** `_ready` L51, `_update_responsive_layout` L83, `_build_ui` L118, `_on_locale_changed` L238, `_update_locale_texts` L242, `_on_theme_changed` L267, `_process` L279, `_on_draw_orb` L295
  `_update_visibility` L333, `_set_overlay_visible` L353, `_on_orb_pressed` L358, `_on_companion_bark_requested` L406, `_on_bark_requested` L417, `_on_important_message_requested` L424, `_on_modal_dismissed` L473, `_hide_bark` L525
  `_hide_modal` L544, `_on_scene_view_changed` L568, `_on_scene_navigate_to` L572, `_on_scene_tab_switched` L576, `_on_scene_combat_started` L580, `_on_scene_combat_ended` L584

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
`scenes/ui/credits/CreditsScreen.gd` · 1257 líneas · extends `Control`

Pantalla cinematográfica de créditos estilo película.

- **signals:** `closed` L13
- **privadas:** `_ready` L50, `_exit_tree` L61, `_build_ui` L70, `_load_qr_texture` L414, `_build_qr_card` L428, `_is_mouse_over_qr_cards` L508, `_populate_credits_content` L519, `_build_sphere_modal` L880
  `_start_sequence` L970, `_play_title_card` L976, `_play_engine_card` L998, `_play_attribution_card` L1028, `_start_credits_roll` L1058, `_process` L1092, `_on_roll_finished` L1106, `_show_sphere_prompt` L1127
  `_on_sphere_continue_pressed` L1136, `_skip_credits` L1142, `_close_credits` L1169, `_input` L1197

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
`scenes/ui/journal/JournalViewer.gd` · 380 líneas · extends `Control`

DIARIO / REGISTRO NARRATIVO — overlay reutilizable construido por código.

- **signals:** `closed` L19
- **privadas:** `_ready` L27, `_build_ui` L36, `_build_current_objective` L103, `_build_questline` L144, `_build_secondary_quests` L165, `_secondary_quest_row` L191, `_build_story_progress` L243, `_step_row` L280
  `_fact_row` L319, `_section_label` L359, `_divider` L368, `_on_bg_input` L376

### `LoadingScreen`
`scenes/ui/loading/LoadingScreen.gd` · 224 líneas · extends `Control`

Pantalla de carga asíncrona a pantalla completa con fondo negro sólido,
- **funcs:** `set_progress` L203
- **privadas:** `_ready` L34, `_process` L185, `_show_next_tip` L207

### `MainMenu`
`scenes/ui/main_menu/MainMenu.gd` · 462 líneas · extends `Control`

Pantalla de inicio del juego.
- **privadas:** `_ready` L44, `_exit_tree` L64, `_process` L68, `_input` L91, `_start_attract_mode` L132, `_cancel_attract_mode` L145, `_on_attract_finished` L161, `_update_responsive_layout` L173
  `_build_background` L205, `_animate_title` L246, `_init_secret_triggers` L256, `_on_hero_gui_input` L266, `_on_secret_hero_clicked` L272, `_animate_hero_feedback` L283, `_reveal_debug_buttons` L291, `_refresh_texts` L309
  `_update_continue_state` L323, `_on_btn_new_game_pressed` L333, `_start_new_game` L342, `_on_btn_debug_mode_pressed` L358, `_start_debug_game` L364, `_on_btn_test_room_pressed` L376, `_start_test_room` L382, `_ensure_real_world` L394
  `_on_btn_continue_pressed` L401, `_on_btn_options_pressed` L410, `_on_btn_credits_pressed` L416, `_on_btn_quit_pressed` L424, `_open_overlay` L432, `_close_overlay` L441, `_show_new_game_confirm` L450

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
`scenes/ui/splash/SplashScreen.gd` · 615 líneas · extends `Control`

Pantalla cinemática de apertura previa al menú principal.
- **privadas:** `_ready` L66, `_exit_tree` L82, `_unhandled_input` L87, `_load_fonts` L119, `_build_ui` L130, `_on_viewport_size_changed` L320, `_start_animation_sequence` L349, `_skip_to_menu` L392
  `_goto_main_menu` L409, `_show_web_notice` L416, `_build_web_notice_ui` L438, `_dismiss_web_notice` L601

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

