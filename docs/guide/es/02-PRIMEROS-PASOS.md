# 02 — Primeros Pasos

## 1. Requisitos

| Herramienta | Versión | Para qué |
|---|---|---|
| **Godot Engine** | **4.x** (recomendado **4.3 o superior**) | Ejecutar y compilar el juego |
| **Python** | 3.8+ | Levantar el servidor del editor web (`editor/serve.py`) y los scripts de `tools/` |
| **Node.js** | Cualquier LTS reciente | Opcional: solo para `tools/check_editor.mjs` (linter de sintaxis del editor) y `tools/extract_template.mjs` |
| Navegador moderno | Chrome/Edge/Firefox | Usar el editor web |

No hace falta npm, webpack, ni instalar dependencias de Python: **todo funciona con la
librería estándar**.

## 2. Abrir el juego en Godot

1. Abre Godot 4 (4.3+), "Import" → selecciona la carpeta raíz del proyecto (donde está
   `project.godot`).
2. Al abrir por primera vez, Godot reimportará todos los assets (puede tardar unos
   minutos por la cantidad de texturas/modelos).
3. Pulsa ▶️ (Play). La escena de arranque es `scenes/ui/main_menu/MainMenu.tscn`
   (definida en `project.godot` → `run/main_scene`).
4. El renderer está configurado como `mobile` (`project.godot` → `[rendering]`) para
   máxima compatibilidad; puedes cambiarlo si tu juego objetivo es solo escritorio.

## 3. Levantar el editor web de contenido

Desde una terminal, en la **raíz del proyecto** (o dentro de `editor/`, el script
autodetecta la raíz por su propia ubicación):

```bash
python editor/serve.py
```

o si ya estás dentro de `editor/`:

```bash
python serve.py
```

Esto:
1. Arranca un servidor HTTP local en `http://localhost:8000/`.
2. Abre automáticamente tu navegador en esa URL (usa `--no-open` para evitarlo).
3. Sirve la SPA (`editor/index.html` + `editor/js/`) y expone una API que lee/escribe
   directamente los JSON de `data/` y los archivos de `assets/`.

Opciones de línea de comandos:

```bash
python editor/serve.py --port 8123      # puerto alternativo
python editor/serve.py --host 0.0.0.0   # accesible desde otros dispositivos en tu red
python editor/serve.py --no-open        # no abrir navegador automáticamente
```

> ⚠️ El editor **escribe directamente sobre los ficheros de tu repositorio**. No hay
> "modo simulación": guardar en el editor modifica `data/*.json` en disco de inmediato
> (con copia `.bak` automática para los ficheros más críticos, ver
> `08-HERRAMIENTAS-CLI-Y-VALIDACION.md`). Usa control de versiones (git) y haz commits
> frecuentes mientras editas contenido.

## 4. Primer vistazo al editor

Al abrir `http://localhost:8000/` verás el **Hub de Inicio**
(`editor/js/components/WelcomePanel.js`), con los 4 modos de juego + sistemas globales
como tarjetas grandes. Dos formas de navegar:

- **Modo Datos**: agrupa las pestañas por tipo de dato (Mundo, Combate, Historia...).
- **Modo Diseñador**: agrupa por área de trabajo/tarea.

Ambos leen de la misma fuente única (`editor/js/nav.js` → `GAME_MODES`), así que no hay
contenido duplicado, solo dos formas de navegar la misma información.

Herramientas transversales disponibles en cualquier pestaña:
- **🔍 Búsqueda global** (`GlobalSearch.js`): busca por id o nombre en TODAS las
  colecciones a la vez.
- **✅ Panel de QA** (`QaPanel.js`): ejecuta el validador de integridad referencial
  directamente desde el navegador (equivalente en vivo a `tools/validate_data.py`).
- **↩️ Undo/Redo** por colección y **guardado** con marcador de "cambios sin guardar".
- **❓ Ayuda contextual** (`HelpDrawer.js`): explica qué hace la pestaña activa.

## 5. Flujo de trabajo recomendado día a día

1. Arranca `python editor/serve.py` y déjalo abierto en una pestaña del navegador.
2. Edita contenido (un enemigo, una mazmorra, un diálogo...) y guarda.
3. Cambia a Godot y pulsa ▶️ para ver el resultado en el juego (no hace falta reiniciar
   el editor web; solo relanzar la partida en Godot para que `Design.gd` relea los JSON).
4. Antes de hacer commit, corre el validador de datos:
   ```bash
   python tools/validate_data.py
   ```
   para detectar referencias rotas (un enemigo que suelta un ítem que no existe, un
   evento que dispara un diálogo inexistente, etc.) **antes** de que fallen en runtime.
5. Si tocaste **código** (GDScript del juego o JS del editor), regenera los mapas de
   código para mantener la documentación sincronizada (ver
   `08-HERRAMIENTAS-CLI-Y-VALIDACION.md`):
   ```bash
   python tools/gen_codemap.py          # si tocaste scripts/ o scenes/
   python tools/gen_editor_codemap.py   # si tocaste editor/js/
   node tools/check_editor.mjs          # linter rápido del editor
   ```

## 6. Siguiente paso

Con el proyecto en marcha, sigue con `03-EDITOR-WEB-GUIA-COMPLETA.md` para conocer cada
pestaña del editor a fondo, o salta directamente a `07-PERSONALIZAR-TU-PROYECTO.md` si
ya tienes claro que quieres empezar a transformar el juego en el tuyo.
