# 08 — Herramientas CLI y Validación (`tools/`)

Todos los scripts de `tools/` son **herramientas permanentes de mantenimiento**, no
código de un solo uso. No requieren dependencias externas salvo donde se indica
(`Pillow` para `process_image.py`). Ejecútalos siempre desde la raíz del proyecto.

## `validate_data.py` — validador de integridad cruzada (el más importante)

```bash
python tools/validate_data.py
```

Recorre TODO `data/` y comprueba referencias cruzadas entre ficheros que, si están
rotas, **fallan en silencio durante el juego** (una opción de diálogo que no hace nada,
un ítem inexistente que nunca se resuelve, una palanca que apunta a un `eid` que no
existe...). Comprobaciones incluidas:

1. Tokens `item:`/`-item:`/`has_item()`/`no_item()` → el ítem debe existir en `data/items/`.
2. Tokens `prof:` → la profesión debe existir en `professions.json`.
3. Ids de habilidad citados en `professions.json` → deben existir en `skills.json`.
4. `next: [...]` de cada nodo de NPC → el nodo destino debe existir en el mismo fichero
   (o ser `"close"`).
5. Tokens `dialogue:` → deben existir en `dialogues.json` (o tener una escena
   equivalente en `data/scenes/`). Tokens `cine:` → deben existir como escena en
   `data/scenes/`.
6. Mazmorras: todo `targets[].eid` debe apuntar a un `eid` definido en la MISMA mazmorra.
7. Mazmorras: todo tipo de casilla `"t"` debe existir en `data/dungeon_tiles/`.
8. Mapamundi: todo `"terrain"` debe existir en `data/world_terrains/`.
9. Ciudades: todo id en el `content` de una ciudad debe existir en `data/ids/`.
10. Botín inline de enemigos/cofres: los ítems referenciados deben existir.
11. Y más (tablas de botín, reconciliación de flags globales huérfanos, tokens de
    eventos/logros/cinemáticas...).

Ignora automáticamente copias de seguridad (`*.bak`, `*.backup`, `* - copia*`). Código de
salida `0` si no hay errores (ideal para engancharlo a un pre-commit hook o CI), `1` si
encuentra alguno. **Este mismo motor de validación está disponible en vivo dentro del
editor web** (Panel de QA), así que no siempre necesitas la terminal.

> Al añadir tu propio tipo de contenido nuevo (Fase 0 de `07-PERSONALIZAR-TU-PROYECTO.md`),
> considera añadir aquí sus propias comprobaciones de integridad si introduce referencias
> cruzadas nuevas (sigue el patrón de las funciones `check_*` ya existentes).

## `gen_codemap.py` — mapa de código del JUEGO (Godot/GDScript)

```bash
python tools/gen_codemap.py
```

Escanea `scripts/`, `scenes/` y `resources/` y regenera:
- `docs/CODEMAP.md` — mapa navegable por área con funciones, `@export`s y `#region`s.
- `docs/SYMBOLS.tsv` — índice plano "grepeable" (`símbolo \t tipo \t fichero \t línea`).

**Ejecútalo siempre que añadas/renombres/muevas funciones, señales o regiones en
GDScript**, para que la documentación técnica no quede desincronizada del código real
(estos ficheros son la fuente que consulta cualquier agente de IA o desarrollador nuevo
para localizar código sin leer el proyecto entero).

## `gen_editor_codemap.py` — mapa de código del EDITOR (Vue/JS)

```bash
python tools/gen_editor_codemap.py
```

Equivalente al anterior pero para `editor/js/`, regenera `editor/CODEMAP.md`. Ejecútalo
tras cualquier cambio estructural en componentes del editor.

## `check_editor.mjs` — verificador estático del editor

```bash
node tools/check_editor.mjs
```

Comprueba, sin necesidad de abrir el navegador:
1. **Sintaxis**: `node --check` de todos los `editor/**/*.js`.
2. **Imports**: cada import relativo resuelve a un fichero real (detecta refactors que
   dejan imports colgando). Los imports de CDN (`https://`) se ignoran a propósito.
3. **Cobertura de pestañas**: cada tab de `nav.js` (`TAB_META`) aparece registrada en el
   render de `app.js` (evita "registré el componente pero no lo pinté en ningún sitio").

Código de salida ≠ 0 si algo falla (apto para CI). **Ejecútalo siempre tras tocar
`editor/js/`**, antes de dar por bueno un cambio en el editor.

## `process_image.py` — normalizar sprites (ver también `06-ARTE-AUDIO-Y-ASSETS.md`)

```bash
pip install Pillow   # única dependencia externa de todo tools/
python tools/process_image.py entrada.jpg salida.png --type sprite
python tools/process_image.py entrada.png salida.png --resize 512x512
```

Convierte a PNG real de 32 bits, elimina fondo por flood-fill de color y suaviza bordes.
También accesible desde la Biblioteca de Medios del editor (endpoint
`/api/process_image`, mismo script por debajo).

## `recompress_assets.py` — reducir peso de assets

```bash
python tools/recompress_assets.py
```

Recorre assets ya importados y los recomprime. Útil antes de una build de publicación
para reducir el tamaño final del paquete exportado.

## `build_model_scenes.py` — generar escenas Godot desde modelos 3D en lote

```bash
python tools/build_model_scenes.py
```

Automatiza la creación de escenas `.tscn` wrapper a partir de una carpeta de modelos
sueltos (`.glb`/`.obj`), para no tener que configurar cada modelo a mano uno por uno en
el editor de Godot.


## `extract_template.mjs` — codemod interno del editor

```bash
node tools/extract_template.mjs editor/js/components/TuComponente.js
```

Extrae la plantilla Vue inline (`template: \`...\``) de un componente grande a su propio
módulo `components/templates/<Nombre>Template.js`, dejando `template: TEMPLATE` +
import. La extracción es **byte-perfecta** (copia literal, sin reescribir), así que no
cambia el comportamiento — solo mejora la carga incremental al editar componentes muy
grandes (varios de los editores de colección superan las 1000-2000 líneas). Es
idempotente: si ya está extraída, no hace nada.

## Resumen: ¿cuándo corro cada cosa?

| Acción que hiciste | Comando(s) a correr |
|---|---|
| Edité contenido en `data/` (con o sin el editor web) | `python tools/validate_data.py` |
| Toqué GDScript (`scripts/`, `scenes/`, `resources/`) | `python tools/gen_codemap.py` |
| Toqué el editor web (`editor/js/`) | `python tools/gen_editor_codemap.py` + `node tools/check_editor.mjs` |
| Añadí/generé sprites nuevos | `python tools/process_image.py ... --type sprite` |
| Voy a exportar una build de publicación | `python tools/recompress_assets.py` + checklist de `07-PERSONALIZAR-TU-PROYECTO.md` |

## Siguiente paso

Si te ha surgido una duda concreta o un error, revisa `09-FAQ-TROUBLESHOOTING.md`.
