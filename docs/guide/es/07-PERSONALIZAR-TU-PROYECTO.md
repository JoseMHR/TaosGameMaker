# 07 — Personalizar tu Proyecto (Paso a Paso)

Esta es la guía práctica para convertir este RPG de ejemplo en **tu propio juego**.
Sigue el orden propuesto: cada fase se apoya en la anterior. Ninguna fase requiere
tocar GDScript salvo que quieras mecánicas nuevas de verdad (lo señalamos donde aplica).

> 💡 Regla general: **haz commit de git antes de cada fase**. El editor escribe
> directamente en disco sin deshacer entre sesiones; git es tu única red de seguridad
> real a nivel de proyecto completo.

## Fase 0 — Decide el modelo y alcance

Antes de comenzar, define cómo vas a enfocar y distribuir este proyecto:

### Modelos de Distribución
- **Como Template Premium / Motor RPG para otros desarrolladores (itch.io, Gumroad, Asset Store)**:
  Distribuyes el repositorio completo con Godot 4 + la carpeta `editor/`. El comprador adquiere una solución llave en mano: un motor JRPG completo y probado junto a una herramienta web "No-Code" para crear su propio juego sin programar. La documentación de `docs/guide/` (disponible en 7 idiomas) sirve como manual de usuario oficial para tus clientes.
- **Como Videojuego Comercial Propio (Steam, Nintendo Switch, Google Play, iOS, itch.io)**:
  Reemplazas el contenido de ejemplo (`data/`) y el arte (`assets/`) por tu propia obra. Al exportar desde Godot (`export_presets.cfg`), las herramientas de desarrollo (`editor/`, `tools/`, `docs/`) quedan **automáticamente excluidas** del paquete final, generando un ejecutable limpio y optimizado para la plataforma de destino.

### Alcance del Juego
- **Conservar los 4 pilares tal cual** (mundo + mazmorras + combate + narrativa) y solo
  cambiar el contenido → esta guía es exactamente para ti, sigue todas las fases.
- **Quedarte solo con 1-2 pilares** (p. ej. solo combate + narrativa, sin mapamundi ni
  mazmorras) → es viable, pero requiere tocar código: quita el modo que no quieras del
  Hub (`scenes/ui/main_menu/`), de `editor/js/nav.js` (`GAME_MODES`) y deja de rellenar
  su contenido en `data/`. No borres los autoloads compartidos (`GlobalState`, `Design`,
  `QuestManager`...): los usan todos los modos.
- **Añadir un pilar/mecánica nueva que no existe** (crafteo, cartas, pesca minijuego...)
  → sí requiere GDScript nuevo; usa los sistemas especialistas existentes como plantilla
  de estilo (ver `docs/INDEX.md` → "SISTEMAS ESPECIALISTAS") y expón su contenido como un
  JSON nuevo siguiendo el patrón de `editor/js/collections.js` (ver
  `03-EDITOR-WEB-GUIA-COMPLETA.md` → "Cómo añadir tu propia pestaña").

## Fase 1 — Rebranding básico

1. **Nombre del proyecto**: `project.godot` → `[application] config/name="TuJuego"`.
2. **Icono**: sustituye `icon.png` (raíz) manteniendo el mismo nombre de fichero, o
   cambia la ruta en `project.godot` → `config/icon`.
3. **Pantalla de carga**: sustituye `assets/common/boot_splash.png` (mismo nombre) o
   cambia `project.godot` → `boot_splash/image` y `boot_splash/bg_color`.
4. **Créditos**: actualiza `Credits.txt` — el template incluye arte/audio/modelos de
   terceros (Kay Lousberg, Quaternius, varios packs de sonido); si sustituyes esos
   assets por los tuyos, actualiza también los créditos. Si los conservas, respeta sus
   licencias originales.
5. **Idiomas y Localización**: El juego integra 7 idiomas oficiales (`es`, `en`, `fr`, `it`, `de`, `zh`, `ja`).
   Si tu juego solo se publicará en un idioma (p. ej. solo inglés o solo español), puedes cambiar el idioma inicial por defecto en `scripts/autoload/Locale.gd` (`var current_locale = "es"`) y rellenar únicamente los campos de ese idioma en los JSON de `data/`.
6. **Exportación**: revisa `export_presets.cfg` (preset Android incluido) y ajusta
   `export_path`, nombre de paquete, íconos de plataforma, etc. Fíjate que
   `exclude_filter` ya excluye `editor/*, docs/*, tools/*, *.md, *.bak` del build final
   — el editor y la documentación son solo herramientas de desarrollo, **no se exportan
   con el juego**.

## Fase 2 — Define tu mundo narrativo (opcional pero recomendado primero)

Aunque no es obligatorio escribir la historia antes que las mecánicas, hacerlo primero
te da los nombres/ids que vas a usar en todo lo demás (zonas, ciudades, enemigos por
zona, profesiones si tu narrativa las condiciona).

1. Lee `docs/design/STORY.md` como **ejemplo de formato**, no como contenido a conservar.
2. Define tus propios Actos/Zonas/Biomas/Ciudades (no hay límite: la tabla de
   `docs/INDEX.md` es documentación descriptiva del contenido de ejemplo, no una
   restricción técnica — puedes tener 3 zonas o 15).
3. Actualiza `data/quests.json` → `order` con los estados de TU historia principal, y
   `descriptions` con sus títulos/pistas.
4. Si quieres conservar la documentación de referencia actualizada para tu propio
   equipo, reescribe `docs/design/STORY.md`/`PROGRESSION.md` con tu canon (no lo lee el
   motor, es documentación humana).

## Fase 3 — Sistema de personajes y combate

1. **Profesiones/clases** (pestaña "Profesiones" del editor, `data/professions.json`):
   borra las 7 de ejemplo y crea las tuyas (nombre, icono, color, qué habilidades
   desbloquea a qué nivel).
2. **Habilidades** (pestaña "Habilidades", `data/skills.json`): crea el catálogo de
   habilidades de tus clases. Recuerda el límite de **4 habilidades activas
   equipadas simultáneamente** por profesión (mecánica de motor, no de datos).
3. **Sinergias** (pestaña "Sinergias", `data/synergies.json`): define tus combos si
   quieres conservar la mecánica de fusión de habilidades en cola.
4. **Bestiario** (pestaña "Enemigos", `data/enemies/`): crea tus enemigos con su
   elemento/debilidades/resistencias, IA y botín inline. Usa el escalado procedural
   (arquetipo + nivel) en vez de definir stats manuales por nivel.
5. **Balance de combate** (pestaña "Config" → bloque combate, `data/config.json`):
   ajusta `COMBAT_TURN_INTERVAL`, `PA_LIMIT_NORMAL/RESONANT`, `RESONANCE_MAX`,
   multiplicadores de daño elemental, etc.

> Si tu juego NO es un JRPG por turnos, este es el pilar que más código tocarías
> (`ViewCombat.gd` y sus componentes). Los otros 3 pilares son más agnósticos al
> género y más fáciles de conservar tal cual.

## Fase 4 — Economía y objetos

1. **Ítems** (pestaña "Objetos", `data/items/`): borra/crea consumibles, equipo y
   materiales. Recuerda las categorías: `consumable`, `equipment`, `important`, `other`.
2. **Tiendas** (pestaña "Tiendas", `data/shops.json`): define catálogos de stock
   reutilizables, luego asígnalos a NPCs/ciudades por `stock_id`.
3. **Balance económico** (`data/config.json`): costes de reforjado, reset de stats,
   escalado de mejora de edificios, capacidad de carga.

## Fase 5 — El mundo (mapa, zonas, recursos)

1. **Terrenos** (pestaña "Terrenos", `data/world_terrains/`): define tus biomas (código,
   color, icono, transitabilidad, variantes visuales).
2. **Recursos recolectables** (pestaña "Recursos, mapa", `data/world_resources/`):
   define qué se puede recolectar y con qué herramienta.
3. **Edificios** (pestaña "Edificios (assets)", `data/world_buildings/`): registra tus
   maquetas 3D colocables.
4. **Pinta el mapa** (pestaña "Mapa", `data/world.json`): coloca terrenos, ciudades,
   POIs, mazmorras y recursos sobre la rejilla.
5. **Ciudades** (workspace "Ciudades" + pestaña "Entidades"): crea cada ciudad con sus
   POIs (taberna, tienda, casas...) usando el workspace dedicado para no saltar entre
   pestañas.
6. **Transformaciones dinámicas** (pestaña "Transformaciones",
   `data/world_transforms.json`): si tu historia tiene hitos que cambian el mapa
   (inundaciones, derrumbes, apertura de caminos), defínelos aquí en vez de scriptearlos
   a mano.

## Fase 6 — Mazmorras

1. Antes de crear contenido, decide qué **Objetos Inteligentes** necesitas (pestaña
   "🧩 Piezas de mazmorra" → filtra por categoría) — la mayoría de puzles se resuelven
   combinando piezas existentes sin tocar código.
2. Crea tus mazmorras (pestaña "Mazmorras"): usa el asistente para el esqueleto inicial,
   pinta las plantas, coloca enemigos/jefes/cofres/interruptores.
3. Prueba el recorrido con el modal de "Walkthrough" antes de darlo por terminado.
4. Si necesitas un tipo de interacción que ningún Objeto Inteligente cubre, es el único
   punto de este flujo donde probablemente necesites tocar GDScript
   (`DungeonSmartFactory.gd` para el archetype nuevo + `GridDungeonStage.gd` si afecta al
   render/colisión de la celda).

## Fase 7 — Narrativa: NPCs, diálogos, misiones

1. **NPCs** (pestaña "NPCs", `data/npcs/`): crea el grafo de diálogo de cada personaje.
   Usa el simulador en vivo (🎬 Probar en Novela Visual) para revisar el resultado sin
   abrir Godot.
2. **Eventos** (pestaña "Misiones/Eventos", `data/events.json`): define los
   disparadores que conectan "algo pasó" con "el mundo reacciona" (usa el mini-lenguaje
   de `04-ESTRUCTURA-DE-DATOS.md`).
3. **Misiones principales** (pestaña "Estados/Quests"): ya deberías tener el `order`
   definido desde la Fase 2; aquí conectas victorias de combate concretas
   (`combat_victory`) con el avance de la historia.
4. **Logros y tutoriales** (pestañas "Logros"/"Tutoriales"): opcionales pero baratos de
   añadir y mejoran mucho la sensación de producto terminado.
5. **Escenas del Sistema Narrativo** (pestaña "Escenas", `data/scenes/`): resérvalas
   para momentos narrativos más elaborados (cinemáticas con ramificación real). No es
   obligatorio usarlas si el árbol de diálogo plano de NPCs te basta.

## Fase 8 — Arte y audio

Sigue `06-ARTE-AUDIO-Y-ASSETS.md` íntegro. Resumen del orden recomendado:
1. Sustituye primero los assets más visibles (splash, icono, sprite de jugador,
   fondos de las primeras zonas) para poder mostrar avances cuanto antes.
2. Ve reemplazando enemigos/NPCs/ítems a medida que los vas creando en el paso anterior.
3. Deja música/SFX para el final salvo que ya tengas el paquete de audio decidido.

## Fase 9 — Balance fino y accesibilidad

Repasa `data/config.json` completo (pestaña "Config") una vez tengas contenido real:
curvas de XP, HP/MP por atributo, esquiva/crítico, energía, progreso offline. Son los
números que decidirán si tu juego se siente bien ritmado. Revisa también el bloque de
accesibilidad (`UI_FONT_SCALE_*`, `COLORBLIND_DEFAULT`) — ya viene resuelto en el motor
(`Locale.gd`), solo tienes que decidir los valores por defecto.

## Fase 10 — Validar antes de cada entrega

```bash
python tools/validate_data.py
```
Corre esto **siempre** antes de dar por cerrada una sesión de contenido. Detecta:
referencias a ids inexistentes (ítems, enemigos, diálogos, escenas, terrenos...),
condiciones/recompensas mal formadas, flags globales que se escriben pero nunca se leen
(posible contenido muerto), y más. El mismo motor de validación está disponible en vivo
dentro del editor (Panel de QA).

## Fase 11 — Checklist antes de exportar/publicar

- [ ] `python tools/validate_data.py` sin errores (los avisos son aceptables si los
      entiendes).
- [ ] `python tools/gen_codemap.py` y `python tools/gen_editor_codemap.py` corridos si
      tocaste código, para que la documentación técnica no quede desincronizada.
- [ ] `node tools/check_editor.mjs` sin errores si tocaste `editor/js/`.
- [ ] Revisado `Credits.txt` con todos los assets de terceros que conservas.
- [ ] Revisado `export_presets.cfg` (nombre de paquete, icono de plataforma, filtros de
      exportación).
- [ ] Probado el juego completo de principio a fin al menos una vez en Godot (no solo
      en el editor de contenido).
- [ ] Comprobado que `editor/`, `docs/`, `tools/` siguen excluidos del build exportado
      (`export_filter`/`exclude_filter` en `export_presets.cfg`) — son herramientas de
      desarrollo, no deben viajar con el juego final.

## Siguiente paso

Para automatizar parte de este flujo (validación, generación de documentación,
procesado de imágenes en lote), revisa `08-HERRAMIENTAS-CLI-Y-VALIDACION.md`.
