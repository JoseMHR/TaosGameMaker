---
Origen: docs/tasks/pendiente/task_2_expansion_proyecto.md, Fase 2 (adelantada
parcialmente porque el usuario dio ya las cifras/reglas concretas en la Fase 0).
Complementa docs/design/STORY.md (curva narrativa) con las cifras de progresión.
---

# PROGRESSION.md — Nivel, dificultad, Don Nadie y XP de profesión

## 1. Curva de nivel y dificultad por Acto y Zona

| Acto | Zona | Bioma / Entorno | Rango de Nivel | Boss / Hito de Salida |
|---|---|---|---|---|
| **Prólogo** | **Zona 1: Yelmo** | Páramo (`bad`) | **1 – 5** | Orco Berserker (Nivel 5) en `dun_yelmo_start` · Presa |
| **Acto 1** | **Zona 2: Hielo** | Nieve y hielo resbaladizo (`ice`/`icy`) | **5 – 8** | Goblin Capitán (Nivel 8) en `dun_yelmo_finish` |
| **Acto 1** | **Zona 3: Pradera** | Pradera (`grs`), agua, **Sylphrena** (`city_sylphrena`) | **8 – 14** | Jefe Bandido (Nivel 15) en `dun_bandidos` · 3 primeros Senderos |
| **Acto 2** | **Zona 4: Celestia** | Templos, pradera imperial, **Celestia** (`city_celestia`) | **15 – 25** | Puerto de Celestia · **Obtención del Barco** · 6 profesiones |
| **Acto 3** | **Zona 5: Gloriam** | Desierto (`sand`/`des`), **Gloriam** (`city_gloriam`) | **25 – 35** | `dun_desierto` · Travesía marítima |
| **Acto 4** | **Zona 6: Arcanum** | Páramo Arcano (`bad`), **Arcanum** (`city_arcanum`) | **35 – 45** | `dun_laboratorio` · Autómatas y tecnología arcana |
| **Acto 5** | **Zona 7: Final** | Ruinas Primordiales / Fin del Mundo | **45 – 50** | `dun_final` · **Guardián Supremo** (Nivel 50) |

**Tope de nivel y escalado procedural**: Los enemigos escalan dinámicamente mediante `EnemyDatabase._procedural_stats(level, archetype)` respetando el rango de su zona. El nivel 50 representa el techo del juego principal.

## 2. "Don Nadie" — diseño de habilidades ridículas con efecto real

`data/skills.json` ya define las habilidades de "Don Nadie"
(`nob_punch`, `nob_talk`, `nob_shout`, `nob_beg`, `nob_flatter`, `nob_taunt`,
`nob_pray`, `nob_play_dead`, `nob_dance`, `nob_throw_rock`, `nob_luck`,
`nob_desperation`, `nob_legend`), cada una de nivel 1 a 30 en `professions.json`.

**Regla de diseño**: cada habilidad ridícula tiene su efecto "de broma" base
(ya implementado: `pacify`, `random_heal`, `random_status`, etc.), PERO además
gana una **interacción especial contra una familia de enemigo concreta**,
donde deja de ser una broma y se vuelve la jugada correcta. Ejemplos concretos
a implementar por acto (a repartir entre las familias de enemigos que se creen):

- **`nob_beg` (Suplicar)**: contra enemigos "cobardes/tramposos" (bandidos,
  ladrones, saqueadores) tiene alta probabilidad de hacer que **huyan** en vez
  del efecto genérico `pacify`.
- **`nob_play_dead` (Hacerse el Muerto)**: contra depredadores (lobos, osos,
  bestias) hace que pierdan el interés y se retiren; contra enemigos NO
  vivos (autómatas, esqueletos) no tiene ningún efecto especial (chiste: "no
  distinguen que finges estar muerto de que ya lo estás").
- **`nob_flatter` (Adular)**: contra enemigos con ego/jerarquía (capitanes,
  nobles corruptos, oficiales) puede evitar que ataquen un turno o unirse
  brevemente.
- **`nob_dance` (Bailar)**: contra enemigos "encantados/hechizados"
  (elementales, hadas, espíritus) puede romper su enfoque (quitarles un buff/
  aggro), pero contra soldados disciplinados no hace nada.
- **`nob_desperation` (Desesperación)**: ya requiere HP bajo; mantiene su
  lectura de "última carta" en cualquier enemigo, sin condición especial.

Este patrón (efecto base + bonus situacional por tag de enemigo) se implementa
con el campo `tag` que ya usan algunas skills (`nob_throw_rock` tiene
`"tag": "nobody_rock"`) extendido a una tabla de enemigo→reacción especial,
consultada por el resolutor de daño/efectos de combate.
**Archivo de implementación**: `scenes/views/view_combat/components/CombatDamageResolver.gd`
(o un nuevo `NobodyReactionTable` si crece mucho) + añadir `tags` (familia
narrativa) a las fichas de `data/enemies/*.json` que aún no lo tengan.

## 3. XP de profesión: individual por trabajo PARTICIPANTE en el combate

### 3.0 ✅ IMPLEMENTADO

Ya no es un cambio pendiente: implementado tal cual describe §3.3.
- `scenes/views/view_combat/ViewCombat.gd`: nuevo `_jobs_used_this_combat`
  (se limpia en `start_combat`); `_on_skill_pressed` registra
  `GlobalState.profession` en él al encolar cualquier habilidad que NO sea
  una poción (el "cambio de clase" nunca pasa por esta función, así que ya
  queda excluido sin lógica extra).
- `scripts/autoload/GlobalState.gd`: nuevo `add_job_xp_to(prof, amount)`
  (otorga XP a una profesión concreta, activa o no) y helper compartido
  `_grant_job_xp_to_non_active`, reutilizado también por `add_xp_to_all_jobs`
  (Muñeco de Entrenamiento) para no duplicar la lógica de nivelado.
- `scenes/views/view_combat/components/CombatDamageResolver.gd`:
  `_end_combat` reparte `xp_reward * 0.7` a CADA profesión de
  `_jobs_used_this_combat` (ración completa, no dividida); si el array queda
  vacío (victoria sin encolar ninguna habilidad), cae al comportamiento
  anterior (solo la profesión activa) como red de seguridad.
- **Efecto colateral positivo**: al unificar la lógica de nivelado en
  `_grant_job_xp_to_non_active`, el Muñeco de Entrenamiento ahora también
  emite `job_leveled_up` (toast) cuando hace subir de nivel a una profesión
  NO activa — antes ese caso no avisaba. Es una mejora, no una regresión.
- **Pendiente de verificación manual** (no se puede probar desde aquí):
  partida con 2+ profesiones desbloqueadas, usar habilidades de ambas en el
  mismo combate, ganar, y comprobar que las dos suben de XP de trabajo.

### 3.1 Comportamiento ANTERIOR (para referencia histórica)

`scenes/views/view_combat/components/CombatDamageResolver.gd:139-143`, al ganar
un combate:
```gdscript
GlobalState.add_xp(xp_reward)          # nivel de personaje (siempre)
GlobalState.add_job_xp(int(xp_reward * 0.7))   # SOLO la profesión ACTIVA al terminar
```
`GlobalState.add_job_xp()` (`scripts/autoload/GlobalState.gd:542`) escribe
solo en `profession` (la profesión activa en ESE instante). Si el jugador
cambió de profesión 3 veces durante el combate, las otras 2 no reciben nada.
Existe también `add_xp_to_all_jobs()` (línea 577), pero esa reparte XP a
**todas** las profesiones desbloqueadas, las hayan usado o no — tampoco es lo
pedido.

### 3.2 Comportamiento REQUERIDO (especificado por el usuario)

> "La progresión de experiencia de los jobs debe ser individual, recibe
> experiencia todos los jobs que hayan participado en el combate, no todos, ni
> solo el último."

Es decir: un tercer comportamiento, a medio camino: **cada profesión que
ejecutó al menos una habilidad durante ESE combate** recibe su propia XP de
trabajo (usando siempre el ritmo individual de `add_job_xp`/`profession_levels`,
nunca "todas reciben la del ganador").

### 3.3 Cambio de implementación necesario (acotado, bajo riesgo)

1. **Al empezar combate** (`ViewCombat` init / reset de estado de combate):
   inicializar un `Array[String] _jobs_used_this_combat = []`.
2. **Cada vez que se ejecuta una habilidad de profesión** (no una acción de
   "cambiar de clase", que ya se gestiona aparte): si `GlobalState.profession`
   no está en `_jobs_used_this_combat`, añadirlo. Punto de enganche natural:
   donde ya se resuelve/ejecuta la habilidad en `CombatQueueSystem.gd` /
   `ViewCombat.gd` (mismo sitio donde hoy se consume PA de la cola).
3. **Al ganar combate** (`CombatDamageResolver.gd:139-143`): sustituir la
   llamada única a `add_job_xp` por un bucle sobre `_jobs_used_this_combat`,
   otorgando a cada una su ración de XP con el mismo mecanismo por-profesión
   que ya usa `add_xp_to_all_jobs()` (que ya sabe sumar XP a una profesión NO
   activa vía `profession_levels`, reutilizable tal cual). "Don Nadie" sigue
   yendo al nivel base del héroe (regla ya existente en `add_job_xp`).
4. **Reparto de cantidad**: opción simple y justa — la misma cantidad
   (`xp_reward * 0.7`) a CADA profesión que participó, no dividida entre
   ellas (incentiva probar varias profesiones en el mismo combate en vez de
   penalizarlo). A confirmar/balancear en playtests del Acto 2.

**Archivos a tocar cuando se implemente** (no en esta sesión de planificación,
sino al producir el Acto 1, que es donde por primera vez el jugador tendrá más
de una profesión activa en combate):
`scenes/views/view_combat/ViewCombat.gd`,
`scenes/views/view_combat/components/CombatQueueSystem.gd`,
`scenes/views/view_combat/components/CombatDamageResolver.gd`,
`scripts/autoload/GlobalState.gd` (posible helper nuevo
`add_job_xp_to(prof, amount)` reutilizando la lógica interna de
`add_xp_to_all_jobs` para una sola profesión, en vez de duplicar código).

## 4. Resumen de dependencias para producir el Acto 1

✅ Resuelto (§3.0): ya no bloquea el inicio de la producción del Acto 1. El
jugador que prueba las 6 profesiones en un mismo combate ve subir la XP de
trabajo de todas las que usó, no solo la última.

## 5. Escalado de enemigos por bioma/acto

### 5.0 Cómo escala HOY un enemigo (auditado en código, no hace falta tocarlo)

`scripts/systems/EnemyDatabase.gd:build_enemy(id, level)` ya escala CUALQUIER
enemigo a CUALQUIER nivel con una fórmula continua por ficha:
`stat = base_stat + stat_scale * (level - 1)`. Esto significa que
`monster_lvl_1/25/50` **no son plantillas fijas de esos 3 niveles exactos**:
son 3 enemigos "genéricos" distintos (icono verde/azul/rojo, sprite propio),
cada uno con su propia recta base+pendiente, usados como enemigos de
emboscada del mapamundi en 3 tramos de nivel. Verificado con los datos reales:

| Nivel ancla | `base_hp` | `hp_scale` | HP a ese nivel (fórmula propia) | HP si se extendiera la recta del ancla anterior |
|---|---|---|---|---|
| 1  | 30  | 8  | 30  | — |
| 25 | 220 | 12 | 220 | 30+8×24 = 222 (☑ casi idéntico → continuidad real) |
| 50 | 600 | 16 | 600 | 220+12×25 = 520 (❌ salto: la curva ACELERA de tier a tier) |

Igual patrón en `xp_reward_base/scale` y `gold_reward_base/scale` (comprobado:
Nv.25 encaja con extender Nv.1, Nv.50 da un salto sobre extender Nv.25). Es
decir, el juego YA usa una curva **por tramos, ligeramente acelerada** — no
hay que inventar un sistema nuevo, solo seguir añadiendo anclas nuevas en los
niveles que hacen falta (20/40/60, las fronteras de acto) con el mismo criterio.

### 5.1 Anclas nuevas propuestas (20/40/60) — punto de partida para playtests

Extrapolando la aceleración ya observada entre anclas (cada tramo escala su
salto ~1.5-1.9× respecto al anterior):

| Nivel ancla | `base_hp` (aprox.) | `hp_scale` (aprox.) | `base_attack` | `attack_scale` |
|---|---|---|---|---|
| 20 (fin Acto 1 / inicio Acto 2) | ~180 | ~11 | ~13 | ~1.6 |
| 40 (fin Acto 2 / inicio Acto 3) | ~450 | ~15 | ~28 | ~2.0 |
| 60 (clímax Acto 3) | ~850 | ~20 | ~55 | ~2.6 |

**Estas cifras son un PUNTO DE PARTIDA, no una tabla cerrada** — al producir
cada acto, crear la ficha `monster_lvl_20`/`_40`/`_60` (mismo patrón que las
3 ya existentes) con estos valores, jugar un combate típico de ese tramo, y
ajustar. Los `xp_reward_base`/`gold_reward_base` deben seguir la misma
proporción que ya usan los 3 anclas actuales (`xp_reward_base` ≈ 4× `base_hp`
de la ficha nv.1 y nv.25; ajustar según se vea en juego).

### 5.2 Familias ya existentes (`family`, ya en el 100% del bestiario "con nombre")

Auditado sobre los 57 ficheros de `data/enemies/`: **6 familias**, ya usadas de
forma consistente (los 3 `monster_lvl_*` genéricos son la única excepción, sin
`family`):

| Familia | Nº fichas | Ejemplos ya existentes |
|---|---|---|
| `magical` | 14 | elementales, demonios, espíritus, hada, 4 de los 6 `temple_boss_*` |
| `beast` | 11 | lobos, oso, jabalí, murciélago, araña, serpiente, `temple_boss_archer` |
| `monster` | 11 | goblins (todas variantes), orcos, esqueletos, slime, troll |
| `humanoid` | 9 | bandido, mercenario, soldado, mago renegado, `temple_boss_warrior` |
| `construct` | 6 | golem, autómata, robot, armadura viviente, torreta, `dungeon_boss` |
| `giant` | 3 | ogro, minotauro, `cave_boss` |

Esta taxonomía **ya es la base perfecta** para la tabla de reacciones de "Don
Nadie" (§2): p. ej. `nob_play_dead` puede leer `family == "beast"` para los
depredadores, `nob_flatter` puede leer `family == "humanoid"` con jerarquía
(soldado/capitán/mercenario), etc. Puede hacer falta un campo más fino que
`family` para casos concretos (p. ej. distinguir "cobarde/tramposo" dentro de
`humanoid`) — decidir al implementar §2, no aquí.

### 5.3 Familias por bioma/acto (siguiendo `WORLD_LAYOUT.md` §3.2)

Principio: **reutilizar familias ya existentes** (cero coste de arte/mecánica
nuevo) para el grueso del contenido, e introducir enemigos/familias nuevas
solo donde el tono lo pide de verdad:

| Sub-zona (Acto 2) | Familias sugeridas | Notas |
|---|---|---|
| Costa de llegada | `beast` (costeros) | Reusa `escorpion`/`spider`/variantes; tono amable, nivel bajo del tramo. |
| Bosques/llanuras centrales | `monster`, `humanoid` | Bandidos/mercenarios como antagonistas de quests secundarias; goblins ya establecidos como "carne de cañón". |
| Tierras áridas/cañones | `beast`, `magical` (elementales de fuego/rayo) | Terreno `des`/`mnt` ya lo sugiere; sube el reto antes de Arcanium. |
| **Arcanium** | `construct` (reutilizar tal cual: golem/robot/automata/torreta encajan PERFECTO como "seguridad" de una sociedad moderna) + `humanoid` (agentes/científicos) | Mínimo coste de arte nuevo: la familia `construct` ya tiene el aspecto tecnológico que pide Arcanium. |
| Frontera con El Templo | `giant`, `magical` (guardianes) | Presagio del Acto 3; enemigos más duros que gating natural. |

Para el **Acto 3** (`STORY.md` §5: "manifestaciones de la propia culpa/
negación, no solo más stats"): reutilizar `magical` (`sombra_oscura`,
`espiritu`, `demonio` ya tienen el tono correcto) como base, y valorar una
familia nueva y pequeña, exclusiva del Acto 3, tipo `manifestacion` — enemigos
simbólicos ligados a los 5 sentimientos encerrados (`STORY.md` §0.2), a
diseñar al producir ese acto (no ahora, evita crear contenido narrativo por
adelantado sin el resto del Acto 3 escrito).

### 5.4 Siguiente paso

Nada de esto requiere cambios de código adicionales — es 100% `data/enemies/*.json`
nuevo siguiendo el patrón ya auditado. Se crea al producir cada acto
(Fase 3..N), no en este documento de diseño puro. Cualquier sprite nuevo que
haga falta (p. ej. un `construct` con estética Arcanium distinta de los ya
existentes) se anota en `docs/assets_pendientes.md` en su momento.
