# ⚔️ JRPG Complete Template & Engine — Guía del Usuario

> **Bienvenido a la plantilla profesional de JRPG para Godot 4.**  
> Este proyecto combina un juego completo (mapamundi 3D, mazmorras en primera persona, combate por turnos y narrativa estilo novela visual) con un **Editor Web Visual propio** que te permite crear, modificar y balancear todo tu juego sin tocar una sola línea de código.

---

## ⚡ Inicio Rápido (En 3 Minutos)

No necesitas configurar bases de datos, ni compilar nada complejo. El proyecto está listo para usar desde el primer minuto:

### 1. Requisitos
- **Godot Engine 4.3+** (Standard o .NET).
- **Python 3.8+** (preinstalado en macOS/Linux; disponible en [python.org](https://www.python.org/) para Windows).

### 2. Abrir y Jugar en Godot
1. Abre **Godot Engine** y pulsa **Importar**.
2. Selecciona el archivo `project.godot` de este directorio.
3. Pulsa **Ejecutar proyecto** (o la tecla `F5`). ¡Ya estás en el menú principal!
   - Para probar todo el contenido de golpe, selecciona **Modo Debug / Sala de Tests** en el menú.

### 3. Abrir el Editor Web de Contenido
El editor de contenido es una aplicación web local que no requiere `npm` ni compilación:
1. Abre una terminal en la carpeta del proyecto.
2. Ejecuta:
   ```bash
   python editor/serve.py
   ```
3. Abre en tu navegador:
   👉 **[http://localhost:8000](http://localhost:8000)**

Cualquier cambio que guardes en el editor web (nuevos enemigos, mapas, diálogos, etc.) **se refleja al instante en Godot sin reiniciar el motor**.

---

## 🎮 ¿Qué incluye esta plantilla?

### 🗺️ 4 Modos de Juego Totalmente Integrados
1. **Mapamundi 3D Top-Down**: Sistema de baldosas hexagonales/cuadradas, niebla de guerra, biomas, peligros climáticos, transformaciones persistentes del mundo (árboles talables, rocas rompibles, campamentos construibles) y vehículo acuático (barco navegable).
2. **Mazmorras en Primera Persona (3D Dungeon Crawler)**: Mazmorras clásicas paso a paso con minimapa dinámico, niebla de guerra, puertas con llave, trampas, cofres y combates contra jefes.
3. **Combate Táctico por Turnos**: Sistema JRPG por turnos con cálculo de daño elemental, estados alterados, barra de turnos, árboles de habilidades de clase, sinergias de equipo y animaciones de cámara.
4. **Narrativa y Novela Visual**: Diálogos ramificados con árbol de decisiones, retratos emotivos, música ambiental reactiva, misiones principales y secundarias, y sistema de flags globales persistentes.

### 🛠️ Editor Web Visual "No-Code"
Una suite completa de diseño de juegos en el navegador:
- **Editor de Mapamundi 3D**: Pinta terrenos, coloca ciudades, mazmorras, recursos, enemigos y cofres con un clic.
- **Editor de Mazmorras**: Diseña niveles en rejilla 3D con vista previa de texturas, puertas, eventos y modal de recorrido paso a paso (*Dungeon Walkthrough*).
- **Diseñador de Enemigos y Habilidades**: Ajusta estadísticas, IA, sprites, drops, afinidades y prueba cualquier combate en vivo con el **Combat Sandbox** integrado en el navegador.
- **Editor de Diálogos y Misiones**: Crea árboles de conversación con editor de grafos visual (*NpcGraphEditor*), ramificaciones y previsualización fiel con el simulador de novela visual (*VnSimulator*).
- **Árboles de Talentos, Oficios y Sinergias**: Balancea la progresión de los personajes y sus profesiones.
- **Asistentes Rápidos (Wizards)**: Genera esqueletos completos de mazmorras, misiones, ítems y POIs con NPC en un solo clic.
- **Soporte Multilingüe Completo (7 idiomas)**: Español, inglés, francés, italiano, alemán, chino y japonés integrados de fábrica con selección instantánea.

### 🧪 Entorno de Pruebas / Sala Debug
- Incluye `data/world_test.json`, un mundo de pruebas organizado con 8 pabellones temáticos donde están expuestos el **100% de los POIs (162), ciudades (4), mazmorras (13) y enemigos (41)** del juego para que puedas probar cualquier interacción en segundos.

---

## 📚 Índice de la Guía Paso a Paso

Esta carpeta (`docs/guide/`) contiene manuales detallados pensados para que cualquier persona o equipo adapte la plantilla a su propia visión (disponibles en 7 idiomas en `docs/guide/<idioma>/`):

| Capítulo | Título | ¿Para qué sirve? |
|---|---|---|
| **01** | [**Visión General y Arquitectura**](01-VISION-GENERAL-Y-ARQUITECTURA.md) | Entiende la estructura general, el stack técnico y la filosofía *data-driven* del proyecto. |
| **02** | [**Primeros Pasos**](02-PRIMEROS-PASOS.md) | Guía de configuración inicial, flujo de trabajo diario y primeros experimentos. |
| **03** | [**Editor Web: Guía Completa**](03-EDITOR-WEB-GUIA-COMPLETA.md) | Manual exhaustivo pestaña por pestaña de todas las herramientas del editor. |
| **04** | [**Estructura de Datos (JSON)**](04-ESTRUCTURA-DE-DATOS.md) | Diccionario de datos: qué significa cada campo, cómo funcionan las condiciones (`has:`, `gflag:`) y las recompensas. |
| **05** | [**Mecánicas de Juego**](05-MECANICAS-DE-JUEGO.md) | Funcionamiento interno del mapamundi, mazmorras, combate por turnos y narrativa. |
| **06** | [**Arte, Audio y Assets**](06-ARTE-AUDIO-Y-ASSETS.md) | Cómo sustituir sprites, modelos 3D, música y sonidos por los de tu propio juego. |
| **07** | [**Personalizar Tu Proyecto**](07-PERSONALIZAR-TU-PROYECTO.md) | **El capítulo clave**: Hoja de ruta paso a paso para convertir esta base en TU juego comercial. |
| **08** | [**Herramientas CLI y Validación**](08-HERRAMIENTAS-CLI-Y-VALIDACION.md) | Scripts automatizados en `tools/` para validar la integridad de tus datos en 1 segundo. |
| **09** | [**Preguntas Frecuentes y Solución de Problemas**](09-FAQ-TROUBLESHOOTING.md) | Respuestas rápidas a los errores y dudas más comunes al editar. |

---

## 🧭 Mapa Rápido de Carpetas

```text
📁 ods-proy-godot/
├── 📄 project.godot          # Fichero principal de configuración de Godot 4
├── 📁 data/                  # EL CORAZÓN DEL JUEGO: todo el contenido en JSON
│   ├── world.json            # Mapamundi oficial de la aventura
│   ├── world_test.json       # Mapamundi de pruebas con todos los POIs y enemigos
│   ├── enemies/              # Fichas de estadísticas e IA de enemigos
│   ├── dungeons/             # Layouts y configuración de mazmorras
│   ├── ids/                  # Ciudades, casas, templos y puntos de interés (POIs)
│   ├── quests.json           # Misiones principales y objetivos de historia
│   └── dialogues.json        # Árboles de conversación y eventos
├── 📁 editor/                # Aplicación web local del editor (Vue 3 + serve.py)
├── 📁 scenes/                # Escenas de Godot (.tscn): vistas, interfaz y componentes
├── 📁 scripts/               # Lógica del motor (.gd): autoloads y sistemas
├── 📁 assets/                # Gráficos 2D, modelos 3D low-poly, música y SFX
├── 📁 tools/                 # Utilidades CLI (validación de datos y compilación)
└── 📁 docs/                  # Documentación técnica y guías completas de uso
    └── 📁 guide/             # Esta suite de guías para humanos
```

---

## 💡 El Principio Rector del Template

> **"Si se puede meter en un JSON, no lo metas en código."**

Todo el sistema está pensado para desacoplar el **código del motor** (que ya funciona, escala y está probado) del **contenido creativo** (la historia, los monstruos, los mapas y el arte). 

Crear tu propio juego con esta plantilla consiste en **editar o reemplazar los JSONs de `data/` usando el editor web**, manteniendo intacto el robusto motor GDScript inferior.

---

## 🛠️ Comprobación Rápida de Salud

Antes de exportar o publicar tu juego, puedes verificar que todos tus enlaces de datos sean coherentes ejecutando:

```bash
python3 tools/validate_data.py
```

Si tus datos son correctos, verás: `✅ Sin errores de integridad cruzada.`
