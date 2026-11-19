# ESPECIFICACIÓN TÉCNICA: MODO COMBATE

## 1. ARQUITECTURA DE VISTA Y MESH/SPRITES

* **Fichero controlador**: `scenes/views/view_combat/ViewCombat.gd`
* **Componentes UI**: `CombatTabsUI.gd`, `ResonanceCircle.gd`, `CombatFx.gd`
* **Base de datos**: `EnemyDatabase.gd` cargado vía `Design.gd` (`data/enemies/`)
* **Disposición escénica (2D JRPG)**:
  * **Jugador (Izquierda)**: Sprite 2D visto de espalda (`assets/combat/character/prof_<id>.png`).
  * **Enemigo (Derecha)**: Sprite 2D encarado de frente (`assets/combat/enemies/<id>.png`).
  * **Escenario**: Fondo dinámico (`assets/combat/bg/`) y plataformas (`assets/combat/platform/`).

## 2. SISTEMA DE PROFESIONES Y HABILIDADES

* **Profesiones (7)**: `Don Nadie`, `Guerrero`, `Arquero`, `Elementalista`, `Sacerdote`, `Psíquico`, `Tiempo` (identificadores reales usados en `GlobalState.gd`/`data/professions.json`; no son snake_case).
* **Equipamiento de Habilidades**: Cada profesión puede equipar hasta **4 habilidades activas** simultáneas (definidas en `data/skills.json`).
* **Selector de Profesión Activa**:
  * Clic sobre el avatar del protagonista despliega un panel flotante/radial con los 7 avatares (`assets/combat/character/prof_av_<id>.png`).
  * Cambiar de profesión consume el turno o modifica la lista de habilidades disponibles según el estado de la batalla.

## 3. FLUJO DE TURNO Y RECURSOS

* **Estadísticas de Combate**: `HP` (Vida), `MP` (Maná), `Resonancia` (barra 0-100, reemplaza a la antigua Sintonía/SP), `Atraque/Defensa Física/Mágica`, `Agilidad` (determina orden).
* **Sistema de turno ATB + cola de Puntos de Acción (PA)** *(actualizado tras la Task 2; sustituye al viejo turno "Atacar/Defender/Habilidades/Items" en 4 pestañas fijas)*:
  * El ATB del jugador se llena en tiempo real; al llenarse, se **encolan** habilidades (hasta `GameConfig.PA_LIMIT_NORMAL` PA, o `PA_LIMIT_RESONANT` en Turno Resonante) y se ejecutan de golpe al pulsar **ATACAR**.
  * Dos habilidades consecutivas en la cola pueden fusionarse en una **sinergia** data-driven (`data/synergies.json`), con hasta triple sinergia si la Resonancia está al 100%.
  * **DEFENDER**: QTE de dos zonas mientras el enemigo descarga su ATB (`GameConfig.BLOCK_PROFILE`): ventana ancha = defensa correcta (~50% menos daño), ventana interior estrecha = Defensa Perfecta (~80% menos daño + Resonancia). `Don Nadie` no tiene ventana perfecta (`BLOCK_PROFILE_NONE`).
* **Pestañas de selección de acción (`CombatTabsUI.gd`, NO son "turnos" sino categorías de la cola)**:
  1. `powers`: Rejilla de las habilidades equipadas de la profesión activa (definidas en `data/skills.json`/`professions.json`).
  2. `classes`: Cambio de clase en pleno combate (consume la acción, redirige a `powers`).
  3. `bag`: Consumibles usables en combate (`potion`, `cooked_fish`, etc.).

## 4. ELEMENTOS Y RESISTENCIAS

* **Tipos Elementales**: `physical`, `fire`, `water`, `ice`, `lightning`, `wind`, `earth`, `poison`, `holy`, `mind`, `time`.
* **Multiplicadores de Daño**: Calculados en base a las debilidades/resistencias definidas en el JSON del enemigo (`data/enemies/`).
