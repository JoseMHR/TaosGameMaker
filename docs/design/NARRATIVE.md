# ESPECIFICACIÓN TÉCNICA: SISTEMA NARRATIVO Y POIS

## 1. VISTA DE NOVELA VISUAL (VN)

* **Fichero controlador**: `scenes/views/view_place/ViewPlace.gd`
* **Overlay Narrativo**: `scenes/components/narrative/NarrativeOverlay.gd`
* **Disposición en pantalla**:
  * **Fondo**: Imagen de entorno o interior de edificio (`assets/vn/bg/`).
  * **NPC Hablando**: Sprite centrado (`assets/vn/npcs/`).
  * **Opciones de Diálogo**: Al tocar responder al jugador, el NPC se despieza hacia un lateral y las opciones de respuesta se despliegan en el lado opuesto.
  * **POIs Informativos**: Espacios sin NPC activo. Muestran cuadro de texto descriptivo del entorno con opción de salida o examen.

## 2. FACETAS DEL PROTAGONISTA

El sistema evalúa 5 facetas personales para habilitar opciones de diálogo exclusivas:

* **Bondad**: Decisiones empáticas y ayuda desinteresada.
* **Cordura**: Resistencia mental ante eventos extraños o perturbadores.
* **Valor**: Determinación ante el peligro y confrontación directa.
* **Aspecto**: Presencia social, carisma y capacidad de persuasión.
* **Inteligencia**: Conocimiento arcano, deducción y comprensión de puzles.

> Claves canónicas (`editor/js/store.js:FACETS`): `valor`, `bondad`, `aspecto`, `inteligencia`, `cordura`. `GlobalState.get_faceta()` acepta también alias legados en el `reward` de los NPCs: `valentia→valor`, `amabilidad→bondad`, `encanto→aspecto`, `astucia→inteligencia`.

## 3. ESTRUCTURA DE DIÁLOGOS Y CONDICIONALES (`data/npcs/*.json`)

* Cada NPC/POI es un fichero JSON independiente en `data/npcs/`, con un diccionario plano de nodos por id (no hay un `entry_point` explícito; el nodo `_meta` define avatar/fondo y el primer nodo de texto real actúa como entrada).
* **Campos de cada nodo**:
  * `type`: `"meta"` (config del NPC), `"message"` (línea del NPC) u `"option"` (respuesta elegible por el jugador).
  * `text`: `{es, en}`.
  * `next`: array de ids de los siguientes nodos (o `["close"]` para cerrar el diálogo).
  * `reward`: mini-DSL en texto libre separado por `;`, ej. `"gold:-50;faceta:amabilidad=+1;flag:donated_orphans"` (también admite atajos como `"heal"`).
  * `condition` (opcional, solo en nodos `option`): expresión evaluada en runtime, ej. `gold >= 50 and no_flag("donated_orphans")`.
* `data/dialogues.json` es un fichero legado con una única entrada suelta (`diary_found`, un aviso tipo toast); NO es el sistema real de diálogos de NPCs.

## 4. POIS Y ESTRUCTURA DE CIUDAD (`ViewCity.gd`)

* **Ciudad / Gran Poblado**: POI contenedor que almacena una lista de sub-POIs (Taverna, Iglesia, Herrero, Tienda, Casas).
* **Navegación Urbana**: La vista de ciudad despliega una interfaz de cuadrículas con los accesos directos a cada edificio/edificación.
