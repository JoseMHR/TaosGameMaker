# 05 — Mecánicas de Juego (los 4 modos)

Esta sección resume cómo funciona cada modo por dentro. Para el detalle técnico exacto
(fórmulas, nombres de función, ficheros de escena) consulta siempre el documento de
`docs/design/` correspondiente — están escritos como especificación técnica y son la
fuente de verdad; aquí tienes el resumen orientado a decisiones de diseño.

## 1. 🗺️ Mundo (mapamundi 3D top-down)

📄 Detalle técnico: `docs/design/WORLD_MAP.md` · Controlador: `TabWorld3D.gd`

- Cámara top-down 3D con movimiento por baldosas (`data/world_terrains/`).
- **Recolección de recursos**: cada nodo de recurso en el mapa exige una herramienta
  equipada concreta (hacha→madera, pico→piedra/mineral, caña→pesca, pala→excavación).
  La tabla completa herramienta↔recurso↔ítem vive en `data/world_resources/`.
- **Acampada**: tienda de campaña (`tent`) para descansar y avanzar el reloj; hoguera
  (`plano_hoguera`) para cocinar recursos crudos en consumibles con buff.
- **Transformaciones dinámicas**: `data/world_transforms.json` reescribe baldosas en
  tiempo real cuando se cumple un flag de historia (ríos que aparecen al abrir una
  presa, vegetación que sustituye páramo, etc.) — ver `04-ESTRUCTURA-DE-DATOS.md` §1.
- **Sistemas especialistas** (extraídos de `TabWorld3D.gd` para que no sea un monolito):
  clima/audio de biomas, física de terreno/hielo, joystick/HUD inferior, cámara de
  cinemáticas — cada uno en su propio fichero bajo
  `scenes/tabs/tab_world_3d/interactive/`.

**Qué tocarías para tu juego**: `data/world.json` (el mapa en sí, se pinta desde la
pestaña "Mapa" del editor), `data/world_terrains/` y `data/world_resources/` si quieres
biomas/recursos distintos, `data/world_transforms.json` si tu historia tiene hitos que
cambian el mapa.

## 2. 🏰 Mazmorras (1ª persona, rejilla, puzles)

📄 Detalle técnico: `docs/design/DUNGEONS.md` · Controlador: `ViewDungeon.gd` ·
Rejilla: `GridDungeonStage.gd`

- Movimiento en 1ª persona por rejilla (paso a paso o continuo). Enemigos como sprites
  2D "billboarded" en el espacio 3D.
- **6 Habilidades de Exploración** (barra inferior, gestionadas por
  `ExplorationSkills.gd`), cada una interactúa con un subconjunto de tipos de casilla:

  | Habilidad | Interactúa con |
  |---|---|
  | 💥 Onda Cinética | barreras, cajas, estatuas, palancas/interruptores a distancia |
  | ⭕ Agarre Psíquico | anillos de enganche, objetos altos, columnas |
  | 👁️ Instinto Cazador | paredes/suelos falsos (revela lo invisible) |
  | 🔥/💧 Afinidad Elemental | hoguera/antorcha/raíces/hielo/agua/electricidad (absorber y disparar) |
  | ☁️ Purificar | niebla tóxica, agua contaminada |
  | ⏳ Tiempo | puertas, ascensores, plataformas móviles (congelar/acelerar/rebobinar) |

- **Interactuables**: palancas/interruptores envían señales (`eid`) a `targets` para
  modificar el estado de otras celdas; peligros ambientales (lava, pinchos, niebla
  tóxica) dañan por proximidad o al pisar.
- **Tipos de casilla**: se editan desde **🧩 Piezas de mazmorra** en el editor —
  🔒 fijas (código en `GridDungeonStage.gd`), 🎨 cosméticas (libres) y 🧩 Objetos
  Inteligentes (data-driven vía `DungeonSmartFactory.gd` + `data/dungeon_kits.json`).

**Qué tocarías para tu juego**: crea mazmorras nuevas desde la pestaña "Mazmorras", y
si necesitas un puzle/mecánica que no existe, primero mira si se puede montar
combinando **Objetos Inteligentes** existentes antes de tocar GDScript.

## 3. ⚔️ Combate (JRPG por turnos)

📄 Detalle técnico: `docs/design/COMBAT.md` · Controlador: `ViewCombat.gd`

- Disposición 2D clásica: jugador a la izquierda (`assets/combat/character/`), enemigo a
  la derecha (`assets/combat/enemies/`), fondo dinámico (`assets/combat/bg/`).
- **7 profesiones** por defecto (`Don Nadie`, `Guerrero`, `Arquero`, `Elementalista`,
  `Sacerdote`, `Psíquico`, `Tiempo`), hasta **4 habilidades activas** equipadas por
  profesión (`data/skills.json`/`data/professions.json`). Cambiar de profesión en pleno
  combate consume la acción.
- **Turno ATB + cola de Puntos de Acción (PA)**: la barra ATB del jugador se llena en
  tiempo real; al llenarse, se **encolan** habilidades (hasta `PA_LIMIT_NORMAL`, o
  `PA_LIMIT_RESONANT` en Turno Resonante — ambos en `data/config.json`) y se ejecutan de
  golpe. Dos habilidades consecutivas en la cola pueden fusionarse en una **sinergia**
  (`data/synergies.json`), hasta triple sinergia con Resonancia al 100%.
- **Defender**: QTE de dos zonas mientras el enemigo ataca — ventana ancha = defensa
  normal, ventana estrecha interior = Defensa Perfecta (más reducción + gana Resonancia).
- **Elementos**: `physical, fire, water, ice, lightning, wind, earth, poison, holy, mind,
  time` con multiplicador por debilidad/resistencia (`ELEMENT_WEAK_MULT`/
  `ELEMENT_RESIST_MULT` en `config.json`).
- **Sistemas especialistas** (extraídos de `ViewCombat.gd`): motor de turnos ATB, cola y
  sinergias, resolución de daño/estados alterados, panel de resultado/UI — cada uno en
  `scenes/views/view_combat/components/`.

**Qué tocarías para tu juego**: `data/professions.json`/`data/skills.json` para tu
propio sistema de clases, `data/enemies/` para tu bestiario, `data/synergies.json` para
tus combos, `data/config.json` (bloque combate) para ritmo/dificultad.

## 4. 📖 Narrativa (novela visual, NPCs, ciudades)

📄 Detalle técnico: `docs/design/NARRATIVE.md` · Controlador: `ViewPlace.gd` · Overlay:
`NarrativeOverlay.gd`

- Disposición de Novela Visual: fondo de escenario (`assets/vn/bg/`), NPC centrado
  (`assets/vn/npcs/` o **emoji** como retrato — ambos soportados por diseño), opciones de
  diálogo desplegadas al lado.
- **5 Facetas del protagonista** (`valor`, `bondad`, `aspecto`, `inteligencia`,
  `cordura`): habilitan opciones de diálogo exclusivas cuando superan un umbral en la
  `condition` del nodo.
- **Diálogos de NPC** (`data/npcs/<id>.json`): diccionario plano de nodos `message`/
  `option` con `text` multilingüe (7 idiomas), `next`, `reward` y `condition` — ver
  `04-ESTRUCTURA-DE-DATOS.md` para el mini-lenguaje completo.
- **Ciudades/POIs** (`ViewCity.gd`): una ciudad es un POI contenedor con una lista de
  sub-POIs (taberna, iglesia, herrero, tienda, casas), navegables como cuadrícula de
  accesos directos.
- **Sistema Narrativo unificado** (`scenes/`, motor `SceneRunner.gd`): grafos de nodo
  más ricos (`say`/`choice`/`state`/`event`/`flow`) pensados para reemplazar
  progresivamente diálogos/cinemáticas antiguos sin tocar quien los invoca (mismo id →
  se reproduce la escena en vez del contenido legado).

**Qué tocarías para tu juego**: reescribe `data/npcs/` con tu propio reparto de
personajes, `data/ids/` para tus ciudades/POIs, y usa `data/scenes/` si tu historia
necesita ramificaciones más complejas que un simple árbol de diálogo.

## 5. La "historia oculta" de este template (referencia, no obligatoria)

El juego incluido trae una historia completa de ejemplo con un giro narrativo (ver
`docs/design/STORY.md`): 5 Actos / 7 Zonas + Zona Extra, niveles 1-50, con una premisa
de "fantasía onírica que esconde un drama real". **No necesitas conservar nada de esto**:
es contenido de muestra para que el template se sienta como un juego terminado desde el
minuto uno, pero está 100% en `data/` y `assets/`, listo para sustituir por tu propia
historia siguiendo `07-PERSONALIZAR-TU-PROYECTO.md`.

## 6. Progresión y dificultad

📄 Detalle técnico: `docs/design/PROGRESSION.md`

- Curva de nivel/dificultad por Acto y Zona (referencia de diseño, no una restricción de
  motor — puedes tener tantas zonas como quieras).
- Los enemigos escalan de forma **procedural** por nivel y arquetipo
  (`EnemyDatabase._procedural_stats`), así que no hace falta postear stats manuales para
  cada nivel de cada enemigo: defines la base y el arquetipo, el motor interpola.
- El nivel máximo de personaje/profesión son parámetros de `data/config.json`
  (`MAX_CHAR_LEVEL`, `MAX_JOB_LEVEL`), no están hardcodeados.

## 7. Siguiente paso

Si tu objetivo es sustituir el arte y el audio del juego, sigue con
`06-ARTE-AUDIO-Y-ASSETS.md`. Si ya quieres empezar a transformar el juego en el tuyo,
salta a `07-PERSONALIZAR-TU-PROYECTO.md`.
