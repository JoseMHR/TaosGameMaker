# 06 — Arte, Audio y Assets

## 1. Mapa de `assets/`

| Carpeta | Contenido |
|---|---|
| `assets/combat/` | Todo lo visual de combate: `character/` (sprites del jugador por profesión), `enemies/` (sprites de enemigos), `bg/` (fondos de batalla), `platform/`, `skills/` (iconos de habilidad), `effects/`/`effectsSprites/` (VFX) |
| `assets/common/` | Compartido por todo el juego: `fonts/` (tipografía Cinzel para titulares), `items/` (iconos de objetos), `models/` (TODOS los modelos 3D: `buildings/`, `characters/`, `decorations/`, `interactive/`), `music/`, `sfx/`, `shaders/`, `ui/`, `boot_splash.png` (pantalla de carga) |
| `assets/dungeon/` | Texturas específicas de mazmorras (`textures/`) |
| `assets/vn/` | Novela Visual: `bg/` (fondos de escena/POI), `npcs/` (retratos de personaje) |
| `assets/world/` | `map/` — texturas de terreno del mapamundi top-down |

Esta organización **coincide 1:1** con `ASSET_DIRS` en `editor/serve.py`, que es el mapa
que usa el editor para saber dónde guardar/leer cada "kind" de asset subido desde la
Biblioteca de Medios o cualquier selector visual (`VnAssetPicker.js`, etc.).

## 2. Convención de nombres de fichero

La mayoría de assets referenciados por id siguen el patrón `<prefijo>_<id>.<ext>`:

| Sistema | Patrón | Ejemplo |
|---|---|---|
| Retrato/sprite de NPC | `npc_<npc_id>.png` en `assets/vn/npcs/` | `npc_gaviota.png` |
| Sprite de enemigo | `<enemy_id>.png` en `assets/combat/enemies/` | `orco_berserker.png` |
| Sprite de jugador por profesión | `prof_<prof_id>.png` en `assets/combat/character/` | `prof_guerrero.png` |
| Avatar de profesión (selector) | `prof_av_<prof_id>.png` | `prof_av_guerrero.png` |
| Icono de ítem | `<item_id>.png` en `assets/common/items/` | `potion.png` |
| Icono de habilidad | `<skill_id>.png` en `assets/combat/skills/` | `heavy_strike.png` |
| Textura de terreno | `tile_<code>.png` en `assets/world/map/` | `tile_sea.png` |

> **Los avatares de NPC también pueden ser un emoji en vez de un fichero** (p. ej.
> `"reward": "avatar=🍸;..."` en `data/npcs/*.json`). El motor (`DialogueResource.gd`) y
> el editor lo detectan (cadena corta sin punto = emoji, con punto = nombre de fichero) y
> lo renderizan como texto en vez de intentar cargar una imagen. Es la forma más rápida
> de darle personalidad a un NPC sin encargar arte.

Algunas texturas de terreno están **protegidas contra borrado** desde el editor
(`serve.py` → `PROTECTED_ASSETS`) porque el motor las usa como fallback cableado si falta
la ficha de un terreno en `data/world_terrains/`. Puedes sobrescribirlas, pero no
borrarlas desde la Biblioteca de Medios.

## 3. Especificaciones técnicas por tipo (Resoluciones Estándar)

El template aplica un estándar estricto de resolución optimizado para VRAM y rendimiento móvil:

| Tipo | Formato | Resolución estándar | Notas |
|---|---|---|---|
| **Fondos de Novela Visual / POIs** | PNG / JPG | **1024×576** (16:9) | Pantalla completa en `assets/vn/bg/`. Al ser panorámico, permite ilustrar al personaje directamente integrado en la escena. |
| **Fondos de Combate** | PNG / JPG | **1024×576** (16:9) | `assets/combat/bg/` |
| **Sprites de NPCs** | PNG 32-bit RGBA | **512×512** | Fondo transparente en `assets/vn/npcs/`. Si un POI no tiene sprite recortado, el motor (`ViewPlace.gd`) muestra limpiamente la escena completa 16:9 de fondo junto a la caja de texto y el emoji avatar, sin forzar sprites genéricos. |
| **Sprites de Enemigos** | PNG 32-bit RGBA | **512×512** | Fondo transparente en `assets/combat/enemies/`. |
| **Sprites de Personaje / Clase** | PNG 32-bit RGBA | **512×512** | `assets/combat/character/`. |
| **Iconos (Ítems / Skills)** | PNG 32-bit RGBA | **128×128** o **256×256** | `assets/common/items/` y `assets/combat/skills/`. |
| **Modelos 3D** | `.glb` (preferido) o `.obj` | Escala 1.0 = 1 unidad Godot | Se importan directamente en Godot; ver `ModelLoader.gd` para cómo se cargan en runtime y `tools/build_model_scenes.py` para generar escenas `.tscn` a partir de modelos en lote. |
| **Música (BGM)** | `.ogg` / `.mp3` / `.wav` | Estéreo loopable | Gestionado por `AudioManager.gd`, registrado por región/terreno en `data/ambience.json`. |
| **SFX** | `.ogg` / `.mp3` / `.wav` | Mono / Estéreo corto | Reproducidos puntualmente por eventos de UI/combate. |
| **Tipografía** | `.ttf` (Cinzel incluida) | Vectorial | Ver `docs/design/UI_KIT.md` §4 para dónde se aplica. |

## 4. Herramientas de procesado (`tools/`)

### `process_image.py` — normalizar sprites
```bash
python tools/process_image.py entrada.jpg salida.png --type sprite
python tools/process_image.py entrada.png salida.png --resize 512x512
```
Convierte a PNG real de 32 bits, **elimina el fondo por flood-fill de color** y suaviza
bordes (anti-halo). Imprescindible si generas sprites con una IA de imágenes que entrega
JPG o PNG con fondo sólido en vez de transparencia real — Godot necesita alpha real para
que el sprite no se vea con un recuadro de color alrededor.

> Requiere Pillow: `pip install Pillow` (único requisito externo de todo `tools/`).

También accesible **desde el propio editor web**: la Biblioteca de Medios tiene un botón
de "Procesar imagen" que llama a `/api/process_image`, que internamente envuelve este
mismo script — no hace falta usar la terminal si prefieres el flujo visual.

### `recompress_assets.py` — reducir peso de assets ya importados
Recorre assets pesados y los recomprime, útil antes de publicar una build para reducir
el tamaño final del paquete.

### `build_model_scenes.py` — generar escenas `.tscn` en lote
Automatiza la creación de escenas Godot wrapper a partir de una carpeta de modelos 3D
sueltos (`.glb`/`.obj`), para no tener que arrastrar y configurar cada uno a mano en el
editor de Godot.

## 5. Cómo sustituir el arte por el tuyo (flujo recomendado)

1. **No borres primero, sustituye por encima**: sube tu nuevo sprite con el MISMO
   nombre de fichero que el original (mismo id) desde la Biblioteca de Medios o
   arrastrándolo a la carpeta correspondiente — así no tienes que tocar ningún JSON que
   ya referencie ese asset.
2. Si cambias el **id** de una entidad (enemigo, ítem, NPC...), recuerda que el nombre
   de archivo de su sprite normalmente sigue el mismo id (ver tabla de convenciones
   arriba) — renómbralo también o el validador (`tools/validate_data.py`) te avisará de
   un "sprite no encontrado".
3. Para sprites nuevos desde una IA de generación de imágenes: pásalos siempre por
   `process_image.py --type sprite` antes de usarlos, para garantizar transparencia real
   y evitar el típico recuadro de color de fondo.
4. Para modelos 3D nuevos: colócalos en la subcarpeta de `assets/common/models/` que
   corresponda (`buildings/`, `characters/`, `decorations/`, `interactive/`) y usa
   `build_model_scenes.py` si necesitas generar muchas escenas wrapper de golpe.
5. Reimporta en Godot (automático al detectar el archivo nuevo) y comprueba en el editor
   web que la vista previa carga correctamente (todos los selectores de asset del editor
   muestran preview en vivo).

## 6. Paleta y estilo visual (UI del JUEGO, no del editor)

La identidad visual del juego (colores, tipografía, radios de esquina, helpers de UI
reutilizables) está centralizada en `scripts/config/UiKit.gd` y documentada íntegramente
en `docs/design/UI_KIT.md`. Si vas a rebrandear el juego visualmente, ese es el único
fichero que necesitas tocar para que **toda la UI del juego cambie de forma coherente**
(botones, paneles, barras de HP/MP, badges de rareza...), en vez de perseguir colores
hardcodeados escena por escena.

> Nota: el **editor web** usa su propia paleta CSS (`editor/styles.css`), totalmente
> independiente de `UiKit.gd` — es una herramienta de desarrollo, no parte de la
> experiencia del jugador, así que no hace falta (ni se recomienda) sincronizar sus
> colores con el rebrand de tu juego.

## 7. Siguiente paso

Con el contenido y el arte cubiertos, `07-PERSONALIZAR-TU-PROYECTO.md` te guía paso a
paso para convertir todo esto en tu propio juego.
