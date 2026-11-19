# ESPECIFICACIÓN TÉCNICA: MODO MAZMORRAS Y EXPLORACIÓN

## 1. REJILLA 3D Y NAVEGACIÓN

* **Fichero controlador**: `scenes/views/view_dungeon/ViewDungeon.gd`
* **Motor de Rejilla**: `GridDungeonStage.gd` (Maneja celdas `cell_size` y `wall_height`).
* **Entidades**:
  * **Jugador (`DungeonPlayer.gd`)**: Movimiento por rejilla en 1ª Persona (paso a paso o continuo), gestión de colisiones y altura.
  * **Enemigos (`DungeonEnemy.gd`)**: Sprites 2D billboarded en el espacio 3D. Detección de rango para iniciar combate.

## 2. MATRIZ DE HABILIDADES DE EXPLORACIÓN (6)

Ubicadas en la barra inferior HUD (`ExplorationHud.gd`). Gestionadas por `ExplorationSkills.gd` y `ExplorationSkillController.gd`:

| Habilidad                    | Icono | Identificador Tile/Objeto (`data/dungeon_tiles/`)                        | Mecánica e Interacción                                                                                                     |
| :--------------------------- | :---- | :------------------------------------------------------------------------- | :--------------------------------------------------------------------------------------------------------------------------- |
| **Onda Cinética**     | 💥    | `barrier`, `crate`, `statue`, `lever`, `switch`                  | Proyecta una onda de choque. Rompe barreras agrietadas, empuja objetos pesados y activa palancas a distancia.                |
| **Agarre Psíquico**   | ⭕    | `ring`, `high_item`, `column`                                        | Lanza un enganche energético para cruzar precipicios, atraer objetos lejanos o accionar interruptores elevados.             |
| **Instinto Cazador**   | 👁️  | `false_floor`, `false_wall`                                            | Activa un filtro visual. Revela paredes ilusas atraviesables, trampas invisibles y suelos falsos.                            |
| **Afinidad Elemental** | 🔥/💧 | `campfire`, `torch`, `roots`, `ice_block`, `water`, `electric` | **Absorber/Disparar**: Absorbe fuego/agua/electricidad de fuentes y los proyecta (ej. quemar raíces, derretir hielo). |
| **Purificar**          | ☁️  | `toxic_fog`, `water` (envenenada)                                      | Genera un área de purificación sagrada. Disipa nubes de niebla tóxica y limpia depósitos de agua contaminada.            |
| **Tiempo**             | ⏳    | `door`, `elevator`, `moving_platform`                                | Manipulación temporal de entorno. Permite congelar plataformas móviles, acelerar temporizadores o rebobinar puertas.       |

## 3. INTERACTUABLES Y PUZLES

* **Actuadores (`lever`, `switch`)**: Envían señales (`eid`) para modificar el estado de otros tiles (`targets: [{eid, action}]`).
* **Peligros Ambientales**: `lava` (daño por tick), `spikes` (daño al pisar si está desplegado), `toxic_fog`.
* **Smart Kits (`DungeonSmartFactory.gd`)**: Agrupaciones compuestas preconfiguradas (ej. `break_barrier`, `reveal_wall`, `grab_switch_high`).
