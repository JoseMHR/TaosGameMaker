# ESPECIFICACIÓN TÉCNICA: MAPAMUNDI Y SISTEMAS MUNDO

## 1. NAVEGACIÓN Y GENERACIÓN 3D

* **Fichero controlador**: `scenes/tabs/tab_world_3d/TabWorld3D.gd`
* **Constructor del Mapa**: `WorldMapBuilder.gd`
* **Camara y Perspectiva**: Top-down 3D con inclinación ortogonal/perspectiva. Movimiento basado en baldosas (`data/world_terrains/`).

## 2. HERRAMIENTAS Y RECOLECCIÓN DE RECURSOS

Manejado vía `TravelSystem.gd`. Requiere equipar la herramienta adecuada para interactuar con los nodos de recurso:

| Herramienta               | Ítem ID Equipado | Nodo Recurso Mapa         | Recurso Obtenido                                  | Archivos JSON                        |
| :------------------------ | :---------------- | :------------------------ | :------------------------------------------------ | :----------------------------------- |
| **Hacha**           | `hacha`         | `forest`, `forestBad` | Madera (`wood`)                                 | `data/world_resources/forest.json` |
| **Pico**            | `pico`          | `rock`, `gold`    | Piedra (`stone`), Mineral de Oro (`gold_ore`) | `data/world_resources/rock.json`   |
| **Caña de Pescar** | `cana_pescar`   | Zonas de Agua / Río      | Pescado (`fish`)                                | `data/world_resources/fish.json`   |
| **Pala**            | `pala`          | Tierra / Excavación      | Objetos ocultos / Arcilla                         | `data/items/pala.json`             |

## 3. SISTEMA DE ACAMPADA Y CAMPAMENTOS

Manejado vía `CampTentSystem.gd` y `CampEatMenu.gd`:

* **Tienda de Campaña (`tent`)**:
  * Permite desplegar un campamento en casillas transitables fuera de ciudades.
  * Opciones: Descansar/Pasar la noche (recupera HP/MP y avanza el reloj en `TimeManager.gd`).
* **Hoguera (`plano_hoguera`)**:
  * Requiere consumo de madera (`wood`).
  * Permite cocinar materias primas (ej. convertir `fish` en `cooked_fish`).

## 4. TRANSFORMACIONES DINÁMICAS DEL MUNDO (`data/world_transforms.json`)

Sistema de modificación de baldosas y recursos en tiempo real mediante eventos de historia:

* **Mapeo de Reglas**: Define reemplazos de terreno basados en `flags` globales (ej. al activar la regla `dam_opened`, las baldosas de lava y tierra seca `bad`/`lav` en el rango de coordenadas especificado se reemplazan dinámicamente por ríos `sea`/`gnd` y vegetación).
