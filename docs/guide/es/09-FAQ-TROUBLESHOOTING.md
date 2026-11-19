# 09 — Preguntas Frecuentes y Solución de Problemas

## General

**¿Necesito saber GDScript para usar este template?**
No, para el 90% del trabajo (contenido, balance, historia, mapa, mazmorras). Solo lo
necesitas si quieres una mecánica que no existe todavía (un modo de juego nuevo, un tipo
de puzle de mazmorra realmente distinto a los Objetos Inteligentes existentes, un
cálculo de combate distinto al de ATB+PA). Ver `07-PERSONALIZAR-TU-PROYECTO.md` → Fase 0.

**¿Necesito Node/npm para el editor web?**
No. El editor es una SPA servida tal cual (HTML+JS+CSS con Vue 3 vía CDN), sin build
step. Node solo hace falta para dos scripts de mantenimiento opcionales
(`tools/check_editor.mjs`, `tools/extract_template.mjs`).

**¿Dónde se guardan las partidas del jugador?** Eso es un sistema aparte del contenido
de diseño: `scripts/autoload/SaveManager.gd` gestiona el guardado/carga de partida
(estado del jugador en `GlobalState.gd`), independiente de los JSON de `data/` (que son
el **diseño** del juego, no el progreso de una partida concreta).

## Editor web

**El editor no abre / "no se encontró la carpeta de datos".**
Estás ejecutando `serve.py` fuera del proyecto, o la carpeta `data/` no está donde
`serve.py` espera (`editor/serve.py` → la raíz se autodetecta como el padre de
`editor/`). Verifica que `data/` existe al mismo nivel que `editor/`.

**Guardé un cambio en el editor pero no lo veo en el juego.**
El editor escribe en disco al instante, pero **Godot solo lee `data/` al arrancar** (o
al recargar explícitamente, ver `Design.gd` → `reload()`). Cierra y vuelve a lanzar la
partida (▶️) tras guardar cambios de contenido.

**¿Puedo tener el editor abierto y Godot abierto a la vez?**
Sí, son procesos totalmente independientes que solo comparten los ficheros de `data/` en
disco. Es el flujo normal de trabajo (ver `02-PRIMEROS-PASOS.md` §5).

**Cambié el `id` de algo y ahora el validador se queja / algo dejó de funcionar.**
Los `id` son referenciados por string desde muchos otros ficheros sin integridad
referencial automática (no es una base de datos relacional). Si renombras un id,
tendrás que actualizar a mano todas las referencias, o mejor, evita renombrar ids ya
usados en producción y crea uno nuevo en su lugar. El Panel de QA / `validate_data.py`
te dice exactamente dónde quedaron referencias rotas.

**El editor me avisa antes de renombrar/borrar un tipo de casilla de mazmorra ("🔒
Comportamiento fijo"). ¿Por qué?**
Porque ese tipo tiene lógica hardcodeada en `GridDungeonStage.gd` (puertas, cofres,
palancas, etc.). Renombrarlo sin tocar el código correspondiente rompería el
comportamiento de cualquier celda nueva que uses ese tipo. Las piezas 🎨 cosméticas y
🧩 Objetos Inteligentes no tienen esta restricción: son 100% seguras de editar.

**Un avatar de NPC no carga / veo un 404 en la consola del navegador para
`npc_<algo>.png`.**
Comprueba si ese "algo" es en realidad un **emoji** (p. ej. `avatar=🍸`). Los avatares
de NPC pueden ser un sprite real (`assets/vn/npcs/npc_<id>.png`) O un emoji renderizado
como texto — ambos son válidos por diseño. Si el editor no distingue esto en algún
componente propio que añadas, replica la detección ya usada en `VnAssetPicker.js`/
`VnSimulatorModal.js`: una cadena corta (≤4 caracteres) sin punto se trata como emoji, no
como nombre de fichero.

**¿Por qué algunos POIs no muestran un sprite recortado de NPC en el centro de la pantalla?**
Porque en este template, muchos fondos de POI (como las ilustraciones panorámicas 16:9 en
`assets/vn/bg/`) ya tienen al personaje y su puesto/escenario dibujados de forma integrada
en la propia ilustración. Si un POI no tiene un archivo `npc_<id>.png` recortado en
`assets/vn/npcs/`, el motor (`ViewPlace.gd`) muestra la ilustración de fondo limpia y completa,
presentando en el cuadro de diálogo el nombre del personaje y su icono emoji, sin superponer
ningún sprite genérico que tape el arte.

## Datos y contenido

**¿Cómo sé si un campo JSON admite texto plano o debe ser multilingüe (7 idiomas)?**
Todo texto visible al jugador (nombres, descripciones, diálogos, hints de misión) se define como diccionario multilingüe con las 7 claves soportadas (`es`, `en`, `fr`, `it`, `de`, `zh`, `ja`). Los campos técnicos (`id`, `type`, `icon`, claves numéricas de balance, condiciones y recompensas) son cadenas o números planos. Si solo deseas desarrollar tu juego en un único idioma (por ejemplo, inglés o español), puedes rellenar únicamente esa clave o duplicarla; el motor aplica fallback seguro automáticamente. Si tienes duda sobre un campo concreto, mira un ejemplo ya existente del mismo tipo de fichero en `data/` — el patrón es muy consistente entre colecciones.

**Mi evento/logro/cinemática no dispara el diálogo que espero.**
Recuerda que si existe una **escena** (`data/scenes/<id>.json`) con el MISMO id que el
`dialogue:`/`cine:` que invocas, esa escena se reproduce EN VEZ del diálogo/cinemática
legado (mecanismo de migración progresiva del Sistema Narrativo, ver
`03-EDITOR-WEB-GUIA-COMPLETA.md` → "Escenas"). Si no es intencional, borra o renombra la
escena que está "haciendo sombra".

**Un enemigo no suelta el botín que configuré.**
Cada entrada de botín tira su `chance` de forma **independiente** (no es un pool
acumulado tipo ruleta). Si pones 5 entradas al 20% cada una, es perfectamente normal que
en una tirada no caiga ninguna, o caigan varias a la vez.

**¿Cómo avanza la questline principal? ¿Puedo saltarme estados?**
`quests.json` → `order` es una lista ordenada. El token `questf:<estado>` avanza HACIA
ADELANTE hasta ese estado sin importar en qué punto estaba el jugador (si te saltas
estados intermedios, el motor sincroniza automáticamente sus transformaciones de mundo
asociadas). `quests:<estado>` en cambio fija el estado directamente sin esa lógica de
"avance", úsalo con cuidado.

## Arte y assets

**Mi sprite se ve con un recuadro/halo de color alrededor.**
Le falta transparencia real (canal alpha). Pásalo por
`python tools/process_image.py entrada.png salida.png --type sprite` antes de usarlo —
elimina el fondo por flood-fill y suaviza el borde.

**Borré/sustituí una textura de terreno y el editor no me deja.**
Algunas texturas de terreno están protegidas contra borrado (`serve.py` →
`PROTECTED_ASSETS`) porque el motor las usa como fallback cableado si falta la ficha de
un terreno. Puedes sobrescribirlas (mismo nombre de archivo), pero no eliminarlas desde
el editor.

**¿Dónde pongo modelos 3D nuevos?**
En la subcarpeta de `assets/common/models/` que corresponda semánticamente
(`buildings/`, `characters/`, `decorations/`, `interactive/`). Formatos soportados:
`.glb` (preferido) y `.obj`.

## Validación y mantenimiento

**`validate_data.py` me da un error que no entiendo.**
El mensaje siempre indica el fichero/campo exacto y qué referencia falta o está mal
formada (p. ej. `[item inexistente] data/enemies/goblin.json: token 'item:pocion' no
existe en data/items/`). Corrige el id citado o crea el recurso que falta.

**¿Tengo que correr los scripts de `tools/` manualmente cada vez?**
Sí, no hay hooks de git preconfigurados en el template. Si quieres automatizarlo, añade
un pre-commit hook que llame a `python tools/validate_data.py` (y opcionalmente a
`node tools/check_editor.mjs` si el commit toca `editor/js/`).

## No encuentro la respuesta a mi duda aquí

1. Repasa el documento de esta guía correspondiente a esa área (ver el índice en
   `README.md`).
2. Consulta `docs/design/*.md` si es una duda de MECÁNICA/BALANCE concreta.
3. Consulta `docs/INDEX.md` + `docs/CODEMAP.md`/`docs/SYMBOLS.tsv` si es una duda de
   DÓNDE VIVE una función o sistema concreto en el código.
4. Si nada de lo anterior resuelve la duda, probablemente sea un comportamiento no
   documentado — el propio código (con sus comentarios extensos en español) suele ser
   la fuente de verdad más fiable en última instancia.
