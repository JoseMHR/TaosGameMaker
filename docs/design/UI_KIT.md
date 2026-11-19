# UI_KIT.md — PALETA, TIPOGRAFÍA Y ESPACIADOS ESTÁNDAR

> Extraído literalmente de `scripts/config/UiKit.gd` (Task 7, ítem 6.1). Este
> documento es la fuente de verdad de DISEÑO visual; el código sigue siendo la
> fuente de verdad de IMPLEMENTACIÓN. Si tocas un color/estilo en `UiKit.gd`,
> actualiza también este fichero para que no se desincronicen.

## 1. Paleta de color base

| Uso | Constante | Hex |
|---|---|---|
| Fondo más profundo | `BG_DEEP` | `#070809` |
| Fondo de paneles/cabeceras | `BG_BASE` | `#0a0b0f` |
| Superficie de tarjetas | `SURFACE` | `#0f1118` |
| Superficie alternativa (resalte) | `SURFACE_ALT` | `#12151c` |
| Superficie elevada (hover) | `SURFACE_HI` | `#181c28` |
| Borde sutil | `BORDER` | `#1c2230` |
| Borde muy sutil | `BORDER_SOFT` | `#141925` |
| **Acento de marca** | `ACCENT` | `#f59e0b` (ámbar) |
| Acento claro (texto destacado) | `ACCENT_SOFT` | `#f7c84a` |
| Acento oscuro (sombras/pressed) | `ACCENT_DEEP` | `#b9770a` |
| Texto principal | `TEXT` | `#eef0f6` |
| Texto secundario | `TEXT_DIM` | `#a7adba` |
| Texto deshabilitado/placeholder | `TEXT_FAINT` | `#5c6270` |

## 2. Colores semánticos

| Uso | Constante | Hex |
|---|---|---|
| Vida (HP) | `HP` | `#e5484d` |
| Maná (MP) | `MP` | `#3b82f6` |
| Experiencia (XP) | `XP` | `#38bdf8` |
| Éxito/positivo | `GOOD` | `#22c55e` |
| Aviso | `WARN` | `#f59e0b` |
| Error/negativo | `BAD` | `#ef4444` |
| Daño físico | `PHYS` | `#f97316` |
| Daño mágico | `MAGIC` | `#a855f7` |
| Daño a distancia | `RANGED` | `#34d399` |
| Defensa física | `DEF_PHYS` | `#60a5fa` |
| Defensa mágica | `DEF_MAGIC` | `#c084fc` |

> ⚠️ Existen 5 constantes "Estandarizadas" heredadas (`COLOR_GOLD_PRIMARY`,
> `COLOR_BG_DARK`, `COLOR_HP_GREEN`, `COLOR_MP_BLUE`, `COLOR_SINTONIA_LIMIT`)
> que se solapan con las de arriba (p. ej. `COLOR_HP_GREEN` ≈ verde de HP en
> combate). No son duplicados accidentales: distintas pantallas convergieron a
> tonos ligeramente distintos con el tiempo. Al escribir código NUEVO, preferir
> siempre la paleta base (sección 1/2) salvo que se esté tocando código que ya
## usa las constantes heredadas, para no introducir un tercer tono sutilmente distinto.

## 3. Rareza de objetos (bolsa/tienda/forja)

`UiKit.RARITY_COLORS`: `common` gris `#9aa3b2` → `uncommon` verde `#3fb950` →
`rare` azul `#3b82f6` → (ver el diccionario completo en `UiKit.gd` para
`epic`/`legendary`, cuyos tonos exactos dependen de `GameConfig.rarities()`).

## 4. Tipografía

* **Titulares/display**: fuente **Cinzel** (`assets/common/fonts/Cinzel.ttf`),
  aplicada vía `UiKit.apply_heading(label)` / `UiKit.section_title(...)`.
  Se carga de forma perezosa y cacheada (`UiKit.heading_font()`); si el
  recurso no está importado, degrada con elegancia a la fuente por defecto
  del proyecto en vez de fallar.
* **Cuerpo de texto**: fuente por defecto del proyecto (tema global de Godot),
  sin override explícito salvo tamaño (`add_theme_font_size_override`).
* **Escalado de accesibilidad**: `Locale.font_scale` (0.8–1.6, ajustable desde
  Opciones → Accesibilidad) reescala globalmente el tamaño de fuente de la UI.
* **Regla de consistencia**: Cinzel se usa en títulos de combate, nombres de
  profesión y cabeceras de sección (Hub, Opciones); el Editor web de mazmorras
  usa su PROPIA tipografía CSS (no Cinzel, es una superficie completamente
  distinta — HTML/Vue, no Godot) — es una diferencia intencional, no un
  descuido, ya que el editor es una herramienta de desarrollo, no parte de la
  experiencia in-game.

## 5. Radios de esquina y bordes estándar

| Elemento | Radio típico | Ancho de borde típico |
|---|---|---|
| Panel genérico (`UiKit.panel`) | 16px (parametrizable) | 1px |
| Tarjeta (`UiKit.card`) | 14px | — |
| Botón primario (`UiKit.button_primary`) | 12px | — |
| Insignias/badges circulares | `999` (círculo perfecto) | 1-2px |

## 6. Helpers reutilizables clave (`UiKit.gd`)

| Función | Uso |
|---|---|
| `panel(bg, border, radius, border_w)` | Fondo + borde + esquinas redondeadas genérico |
| `card(accent, radius, pad)` | Tarjeta con margen interior; `accent=true` resalta borde en ámbar |
| `button_primary(radius)` | Botón de acción principal (relleno ámbar) |
| `button_tonal(tint, radius)` | Botón secundario con identidad de color propia (relleno suave 18% alpha) |
| `margins(left, right, top, bottom)` | Atajo de `MarginContainer` |
| `toast(parent, text, color)` | Aviso flotante efímero (sube y se desvanece solo) |
| `confirm(parent, title, body, ok_text, cancel_text, on_confirm, accent)` | Modal de confirmación reutilizable (Cancelar/Aceptar) |
| `pop(node, scale, duration)` | Micro-interacción de "pop" elástico |
| `animate_in(node, duration)` | Entrada estándar de paneles/pantallas |

## 7. Accesibilidad (persistida en `Locale.gd`)

| Ajuste | Rango/valores | Dónde se edita |
|---|---|---|
| `reduce_motion` | bool | Opciones → Accesibilidad |
| `font_scale` | 0.8 – 1.6 | Opciones → Accesibilidad (slider) |
| `text_speed` | 0.5 – 2.0 | Opciones → Accesibilidad (slider) |
| `colorblind` | bool | Opciones → Accesibilidad |
| `left_handed` | bool | Opciones → Accesibilidad |

Todo el código que crea tweens de movimiento/shake debe comprobar
`Locale.reduce_motion` antes de animar (patrón ya establecido en
`CombatFx`, `NarrativeOverlay`, `ResonanceCircle`, etc.).

---

*Generado durante Task 7 (pulido UX). Si `UiKit.gd`/`Locale.gd` cambian de
forma sustancial, regenera esta tabla a mano — no hay script automático.*
