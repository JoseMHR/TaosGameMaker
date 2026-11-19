class_name UiKit
extends RefCounted
## ════════════════════════════════════════════════════════════════════════════
## UiKit — KIT DE INTERFAZ CENTRAL  (☑ PALETA Y ESTILOS REUTILIZABLES)
## ════════════════════════════════════════════════════════════════════════════
## Punto ÚNICO para el lenguaje visual del juego: paleta de colores y fábricas de
## StyleBox (paneles, tarjetas, barras, cápsulas, botones). Las vistas construidas
## por código usan estos helpers para verse coherentes, pulidas y elegantes sin
## repetir StyleBoxFlat a mano en cada fichero.
##
## Se usa como `UiKit.NOMBRE` / `UiKit.func(...)` (clase global, no se instancia).
##   Ej:  panel.add_theme_stylebox_override("panel", UiKit.card())
## ════════════════════════════════════════════════════════════════════════════


# ─────────────────────────────────────────────────────────────────────────────
# PALETA — COLORES BASE  (un solo sitio para retocar el aspecto global)
# ─────────────────────────────────────────────────────────────────────────────
const BG_DEEP: Color      = Color("070809")   # Fondo más profundo
const BG_BASE: Color      = Color("0a0b0f")   # Fondo de paneles/cabeceras
const SURFACE: Color      = Color("0f1118")   # Superficie de tarjetas
const SURFACE_ALT: Color  = Color("12151c")   # Superficie alternativa (resalte)
const SURFACE_HI: Color   = Color("181c28")   # Superficie elevada (hover)
const BORDER: Color       = Color("1c2230")   # Borde sutil
const BORDER_SOFT: Color  = Color("141925")   # Borde muy sutil

const ACCENT: Color       = Color("f59e0b")   # Ámbar — color de marca/acento
const ACCENT_SOFT: Color  = Color("f7c84a")   # Ámbar claro (texto destacado)
const ACCENT_DEEP: Color  = Color("b9770a")   # Ámbar oscuro (sombras/pressed)

const TEXT: Color         = Color("eef0f6")   # Texto principal
const TEXT_DIM: Color     = Color("a7adba")   # Texto secundario
const TEXT_MUTED: Color   = Color("a7adba")   # Texto secundario/suave
const TEXT_FAINT: Color   = Color("5c6270")   # Texto deshabilitado/placeholder

const HP: Color           = Color("e5484d")   # Vida (rojo)
const MP: Color           = Color("3b82f6")   # Maná (azul)
const XP: Color           = Color("38bdf8")   # Experiencia (cian)
const GOOD: Color         = Color("22c55e")   # Verde (éxito/positivo)
const WARN: Color         = Color("f59e0b")   # Aviso (ámbar)
const BAD: Color          = Color("ef4444")   # Error/negativo (rojo)

const PHYS: Color         = Color("f97316")   # Daño físico (naranja)
const MAGIC: Color        = Color("a855f7")   # Daño mágico (púrpura)
const RANGED: Color       = Color("34d399")   # Daño a distancia (verde menta)
const DEF_PHYS: Color     = Color("60a5fa")   # Defensa física (azul claro)
const DEF_MAGIC: Color    = Color("c084fc")   # Defensa mágica (lila)

# Constantes estandarizadas
const COLOR_GOLD_PRIMARY: Color = Color("f5a623")
const COLOR_GOLD_LIGHT: Color   = Color("fcd34d")
const COLOR_BG_DARK: Color       = Color("0c0e14")
const COLOR_HP_GREEN: Color      = Color("2ecc71")
const COLOR_MP_BLUE: Color       = Color("3498db")
const COLOR_SINTONIA_LIMIT: Color = Color("f1c40f")


# ─────────────────────────────────────────────────────────────────────────────
# ESCALA TIPOGRÁFICA — nombres semánticos para `add_theme_font_size_override`
# (ver task_arreglos.md §5.3). Adoptar en código NUEVO/tocado en vez de números
# mágicos (14, 16, 22, 28, 34, 46); no se ha reescrito el código YA existente
# de golpe para no arriesgar regresiones visuales sin verificación manual.
# ─────────────────────────────────────────────────────────────────────────────
const FONT_TITLE_HERO: int    = 55   # Titular hero (splash, resultado de combate)
const FONT_TITLE_SECTION: int = 40   # Título de sección/modal grande
const FONT_BODY_LARGE: int    = 34   # Cuerpo destacado (botones grandes, diálogo)
const FONT_BODY_MAIN: int     = 26   # Cuerpo estándar (texto de lista/tarjeta)
const FONT_BODY_SMALL: int    = 20   # Cuerpo secundario/pista
const FONT_CAPTION: int       = 17   # Pie de foto / metadatos discretos


# ─────────────────────────────────────────────────────────────────────────────
# TEMAS DE INTERFAZ — paleta única para TODAS las superficies del juego
# (radial/Hub, HUD de combate, HUD superior del mapamundi), no solo combate.
# Centralizada aquí para que cualquier panel/HUD pueda leer el tema activo con
# `UiKit.theme_color(key, fallback)`. El contenido de "default" es el que ya
# usaba el combate rediseñado; el resto de superficies (Hub/HUD superior) leen
# "accent" del tema, con un aspecto casi idéntico al dorado fijo que tenían antes.
# ─────────────────────────────────────────────────────────────────────────────
static var THEMES: Dictionary = {
	# "default": antes era "Azul Dorado" con el dorado como color de marca
	# PERMANENTE (bordes, marco, texto de acento en todas partes). Rediseñado a
	# un azul moderno/elegante como color de marca ("accent"), reservando el
	# dorado ("highlight") EXCLUSIVAMENTE para indicar selección/estado activo
	# (pestaña activa, botón elegido, etc.).
	"default": {
		"panel_bg": Color(0.035, 0.05, 0.09, 0.96),
		"panel_glass": Color(0.06, 0.08, 0.14, 0.82),
		"border": Color(0.20, 0.32, 0.50, 0.78),
		"accent": Color(0.32, 0.62, 0.98),
		"accent2": Color(0.42, 0.85, 0.92),
		"highlight": Color(0.98, 0.80, 0.32),
		"danger": Color(0.86, 0.44, 0.44),
		"text": Color(0.92, 0.95, 1.0),
		"text_dim": Color(0.62, 0.70, 0.82),
		"hp": Color(0.95, 0.25, 0.25),
		"mp": Color(0.25, 0.55, 0.95),
		"atb": Color(0.25, 0.85, 0.55),
		"enemy_atb": Color(0.95, 0.85, 0.15),
		"flee": Color(0.86, 0.44, 0.44),
		# ── Marco premium — "elegante, moderno, agradable": doble filo azul
		# (zafiro -> añil) con relieve suave y un brillo lento recorriendo el
		# perímetro.
		"frame_color": Color(0.38, 0.68, 0.98),
		"frame_color_2": Color(0.11, 0.30, 0.62),
		"frame_width": 10.0,
		"frame_radius": 14.0,
		"frame_bevel": 0.5,
		"frame_glow": 0.35,
		"frame_sweep": 0.15,
		"frame_hue_shift": 0.0,
		# Mosaico sutil, coherente con el marco "moderno/elegante" (ver FASE 1 de
		# task_themes.md): piezas medianas y relieve discreto, no protagonista.
		"mosaic_scale": 18.0,
		"mosaic_strength": 0.25,
		# Tipografía del tema: cadena de fuentes de SISTEMA (sin depender de
		# archivos .ttf empaquetados) — moderna, limpia y muy legible. "Noto
		# Sans" no viene preinstalada en Windows (requiere instalarla aparte) y
		# quedaba como penúltima opción sin red de seguridad real detrás; se
		# añade "Arial" al final, presente en CUALQUIER instalación de
		# Windows, como último recurso garantizado.
		"font_names": PackedStringArray(["Segoe UI", "Calibri", "Trebuchet MS", "Verdana", "Noto Sans", "Arial"]),
	},
	"crimson": {
		"panel_bg": Color(0.08, 0.03, 0.04, 0.96),
		"panel_glass": Color(0.12, 0.04, 0.06, 0.80),
		"border": Color(0.40, 0.15, 0.20, 0.85),
		"accent": Color(0.95, 0.35, 0.40),
		"accent2": Color(0.95, 0.82, 0.35),
		"highlight": Color(0.95, 0.75, 0.30),
		"danger": Color(0.80, 0.20, 0.25),
		"text": Color(0.95, 0.92, 0.92),
		"text_dim": Color(0.75, 0.60, 0.62),
		"hp": Color(0.95, 0.30, 0.30),
		"mp": Color(0.45, 0.55, 0.90),
		"atb": Color(0.70, 0.85, 0.35),
		"enemy_atb": Color(0.95, 0.80, 0.25),
		"flee": Color(0.90, 0.30, 0.35),
		# "oscuro, siniestro, gótico": marco grueso rojo sangre/granate con
		# relieve tallado marcado y esquinas más afiladas (radio menor).
		"frame_color": Color(0.627, 0.094, 0.141),
		"frame_color_2": Color(0.353, 0.051, 0.086),
		"frame_width": 12.0,
		"frame_radius": 8.0,
		"frame_bevel": 0.75,
		"frame_glow": 0.30,
		"frame_sweep": 0.10,
		"frame_hue_shift": 0.0,
		# Mosaico marcado, como sillería de catedral gótica tallada en el marco.
		"mosaic_scale": 14.0,
		"mosaic_strength": 0.55,
		# Serif gótica/clásica — encaja con el tono "siniestro" del tema. Red de
		# seguridad final con "Arial": si NINGUNA de las anteriores existe en el
		# sistema, sigue habiendo texto legible en vez de depender del
		# comportamiento por defecto de `SystemFont`.
		"font_names": PackedStringArray(["Palatino Linotype", "Book Antiqua", "Georgia", "Times New Roman", "Arial"]),
	},
	"happyflower": {
		"panel_bg": Color(0.05, 0.07, 0.04, 0.96),
		"panel_glass": Color(0.08, 0.10, 0.05, 0.80),
		"border": Color(0.30, 0.35, 0.18, 0.85),
		"accent": Color(0.55, 0.85, 0.35),
		"accent2": Color(0.95, 0.55, 0.80),
		"highlight": Color(1.0, 0.90, 0.35),
		"danger": Color(0.95, 0.45, 0.30),
		"text": Color(0.94, 0.95, 0.92),
		"text_dim": Color(0.70, 0.72, 0.62),
		"hp": Color(0.90, 0.35, 0.35),
		"mp": Color(0.30, 0.65, 0.80),
		"atb": Color(0.45, 0.85, 0.40),
		"enemy_atb": Color(0.90, 0.85, 0.30),
		"flee": Color(0.95, 0.50, 0.35),
		# "colorido, alegre, nyan cat": marco muy redondeado con arcoíris
		# animado (hue-shift) recorriendo el perímetro, vivo y saltarín.
		"frame_color": Color(1.0, 0.48, 0.72),
		"frame_color_2": Color(0.48, 0.82, 1.0),
		"frame_width": 5.0,
		"frame_radius": 22.0,
		"frame_bevel": 0.3,
		"frame_glow": 0.5,
		"frame_sweep": 0.25,
		"frame_hue_shift": 0.6,
		# Mosaico ligero, casi juguetón, para no restar protagonismo al arcoíris.
		"mosaic_scale": 20.0,
		"mosaic_strength": 0.15,
		# Redondeada y desenfadada — coherente con el tono alegre del tema.
		# "Century Gothic" solo viene con MS Office (no con Windows en sí) y en
		# varias máquinas de prueba ninguna de las dos primeras existía,
		# dejando la tipografía en un estado poco fiable. "Verdana"/"Tahoma"/
		# "Arial" son estándar en TODA instalación de Windows.
		"font_names": PackedStringArray(["Comic Sans MS", "Century Gothic", "Verdana", "Tahoma", "Arial"]),
	},
	# "void": rediseñado de "simple/clásico RPG retro" a "Void" místico —
	# Violeta Abisal & Lapislázuli (task_themes.md, FASE 2, tema 4/8) — vacío
	# insondable con energía abisal violeta recorriendo el marco.
	"void": {
		"panel_bg": Color(0.035, 0.02, 0.06, 0.96),
		"panel_glass": Color(0.06, 0.03, 0.10, 0.82),
		"border": Color(0.30, 0.15, 0.45, 0.85),
		"accent": Color(0.62, 0.35, 0.92),
		"accent2": Color(0.20, 0.35, 0.85),
		"highlight": Color(0.85, 0.70, 1.0),
		"danger": Color(0.85, 0.25, 0.55),
		"text": Color(0.92, 0.88, 0.98),
		"text_dim": Color(0.60, 0.52, 0.72),
		"hp": Color(0.90, 0.25, 0.45),
		"mp": Color(0.35, 0.45, 0.95),
		"atb": Color(0.55, 0.35, 0.95),
		"enemy_atb": Color(0.80, 0.55, 0.95),
		"flee": Color(0.75, 0.30, 0.55),
		# "místico, abisal": marco violeta -> lapislázuli con relieve marcado y
		# mosaico ornamentado, como grabados de un altar olvidado en el abismo.
		"frame_color": Color(0.55, 0.25, 0.85),
		"frame_color_2": Color(0.15, 0.20, 0.55),
		"frame_width": 6.0,
		"frame_radius": 16.0,
		"frame_bevel": 0.6,
		"frame_glow": 0.5,
		"frame_sweep": 0.18,
		"frame_hue_shift": 0.0,
		"mosaic_scale": 22.0,
		"mosaic_strength": 0.5,
		# Elegante y ligeramente esotérica. "Arial" como red de seguridad final,
		# presente en cualquier instalación de Windows.
		"font_names": PackedStringArray(["Constantia", "Cambria", "Georgia", "Garamond", "Arial"]),
	},
	# "emerald"/"Silva": Verde Esmeralda & Jade (task_themes.md, FASE 2, tema
	# 5/8) — inspiración orgánico-druídica, musgo profundo y esmeralda viva.
	"emerald": {
		"panel_bg": Color(0.02, 0.05, 0.03, 0.96),
		"panel_glass": Color(0.04, 0.08, 0.05, 0.80),
		"border": Color(0.15, 0.35, 0.20, 0.85),
		"accent": Color(0.25, 0.80, 0.45),
		"accent2": Color(0.55, 0.90, 0.55),
		"highlight": Color(0.85, 0.95, 0.55),
		"danger": Color(0.85, 0.35, 0.25),
		"text": Color(0.90, 0.96, 0.90),
		"text_dim": Color(0.55, 0.68, 0.58),
		"hp": Color(0.85, 0.30, 0.30),
		"mp": Color(0.30, 0.70, 0.75),
		"atb": Color(0.35, 0.85, 0.45),
		"enemy_atb": Color(0.75, 0.85, 0.30),
		"flee": Color(0.80, 0.40, 0.30),
		# "orgánico, druídico": marco esmeralda -> musgo profundo, muy redondeado
		# (crecimiento natural) y mosaico discreto tipo hojarasca tallada.
		"frame_color": Color(0.16, 0.62, 0.35),
		"frame_color_2": Color(0.08, 0.30, 0.16),
		"frame_width": 5.0,
		"frame_radius": 18.0,
		"frame_bevel": 0.45,
		"frame_glow": 0.30,
		"frame_sweep": 0.12,
		"frame_hue_shift": 0.0,
		"mosaic_scale": 16.0,
		"mosaic_strength": 0.30,
		"font_names": PackedStringArray(["Garamond", "Book Antiqua", "Georgia", "Calibri", "Arial"]),
	},
	# "solari"/"Desierto": Terracota & Sol Dorado (task_themes.md, FASE 2, tema
	# 6/8) — imperio cálido del desierto, arenas oscuras y sol abrasador.
	"solari": {
		"panel_bg": Color(0.09, 0.05, 0.02, 0.96),
		"panel_glass": Color(0.14, 0.08, 0.03, 0.80),
		"border": Color(0.55, 0.30, 0.10, 0.85),
		"accent": Color(0.95, 0.55, 0.15),
		"accent2": Color(0.85, 0.35, 0.20),
		"highlight": Color(1.0, 0.85, 0.40),
		"danger": Color(0.85, 0.25, 0.20),
		"text": Color(0.98, 0.92, 0.82),
		"text_dim": Color(0.75, 0.60, 0.45),
		"hp": Color(0.90, 0.30, 0.25),
		"mp": Color(0.35, 0.55, 0.75),
		"atb": Color(0.90, 0.65, 0.20),
		"enemy_atb": Color(0.85, 0.45, 0.20),
		"flee": Color(0.80, 0.35, 0.20),
		# "cálido, imperial": marco sol dorado -> terracota profunda, esquinas
		# rectas de piedra labrada y mosaico marcado tipo azulejo desértico.
		"frame_color": Color(0.92, 0.55, 0.16),
		"frame_color_2": Color(0.55, 0.24, 0.10),
		"frame_width": 5.0,
		"frame_radius": 12.0,
		"frame_bevel": 0.55,
		"frame_glow": 0.40,
		"frame_sweep": 0.20,
		"frame_hue_shift": 0.0,
		"mosaic_scale": 20.0,
		"mosaic_strength": 0.40,
		"font_names": PackedStringArray(["Copperplate Gothic Light", "Georgia", "Constantia", "Cambria", "Arial"]),
	},
	# "cyber"/"Arcano": Cian Neón & Magenta Magitech (task_themes.md, FASE 2,
	# tema 7/8) — alto contraste magitécnico, muy vivo y anguloso.
	"cyber": {
		"panel_bg": Color(0.01, 0.03, 0.05, 0.96),
		"panel_glass": Color(0.02, 0.06, 0.09, 0.80),
		"border": Color(0.10, 0.45, 0.55, 0.85),
		"accent": Color(0.20, 0.95, 0.98),
		"accent2": Color(0.95, 0.20, 0.85),
		"highlight": Color(0.80, 1.0, 1.0),
		"danger": Color(0.95, 0.20, 0.35),
		"text": Color(0.88, 0.98, 1.0),
		"text_dim": Color(0.45, 0.65, 0.70),
		"hp": Color(0.95, 0.25, 0.45),
		"mp": Color(0.25, 0.75, 0.95),
		"atb": Color(0.30, 0.95, 0.85),
		"enemy_atb": Color(0.95, 0.35, 0.85),
		"flee": Color(0.85, 0.30, 0.65),
		# "magitécnico, alto contraste": marco cian -> magenta, esquinas casi
		# rectas (angular/tech) y barrido rápido, como energía de circuito.
		"frame_color": Color(0.15, 0.90, 0.95),
		"frame_color_2": Color(0.85, 0.15, 0.80),
		"frame_width": 4.0,
		"frame_radius": 6.0,
		"frame_bevel": 0.25,
		"frame_glow": 0.60,
		"frame_sweep": 0.35,
		"frame_hue_shift": 0.0,
		"mosaic_scale": 28.0,
		"mosaic_strength": 0.45,
		"font_names": PackedStringArray(["Bahnschrift", "Segoe UI", "Consolas", "Courier New", "Arial"]),
	},
	# "astral"/"Noche": Azul Noche & Plata Estelar (task_themes.md, FASE 2,
	# tema 8/8) — cielo nocturno con reflejos plateados/cósmicos.
	"astral": {
		"panel_bg": Color(0.02, 0.03, 0.07, 0.96),
		"panel_glass": Color(0.04, 0.05, 0.11, 0.80),
		"border": Color(0.20, 0.25, 0.45, 0.85),
		"accent": Color(0.55, 0.65, 0.95),
		"accent2": Color(0.85, 0.88, 0.98),
		"highlight": Color(0.95, 0.95, 1.0),
		"danger": Color(0.80, 0.35, 0.45),
		"text": Color(0.92, 0.94, 1.0),
		"text_dim": Color(0.55, 0.60, 0.75),
		"hp": Color(0.85, 0.30, 0.40),
		"mp": Color(0.40, 0.55, 0.95),
		"atb": Color(0.55, 0.70, 0.95),
		"enemy_atb": Color(0.75, 0.75, 0.90),
		"flee": Color(0.70, 0.40, 0.50),
		# "cósmico, sereno": marco plata estelar -> azul noche, relieve suave y
		# mosaico fino como un firmamento tallado.
		"frame_color": Color(0.75, 0.80, 0.95),
		"frame_color_2": Color(0.20, 0.25, 0.55),
		"frame_width": 5.0,
		"frame_radius": 16.0,
		"frame_bevel": 0.40,
		"frame_glow": 0.45,
		"frame_sweep": 0.15,
		"frame_hue_shift": 0.0,
		"mosaic_scale": 24.0,
		"mosaic_strength": 0.35,
		"font_names": PackedStringArray(["Candara", "Calibri", "Segoe UI", "Constantia", "Arial"]),
	},
}

## Color de la paleta del tema ACTIVO (`Locale.ui_theme_id`). `key` es una de
## las claves de `THEMES` ("panel_bg", "border", "accent", "text", ...);
## `fallback` se devuelve si el tema o la clave no existen.
static func theme_color(key: String, fallback: Color = Color.WHITE) -> Color:
	var t: Dictionary = THEMES.get(Locale.ui_theme_id, THEMES["default"])
	return t.get(key, fallback)


## Valor numérico de la paleta del tema ACTIVO (usado por los parámetros del
## marco premium: `frame_width`, `frame_radius`, `frame_bevel`, `frame_glow`,
## `frame_sweep`, `frame_hue_shift`). `fallback` si el tema o la clave no existen.
static func theme_float(key: String, fallback: float = 0.0) -> float:
	var t: Dictionary = THEMES.get(Locale.ui_theme_id, THEMES["default"])
	return float(t.get(key, fallback))


# ─────────────────────────────────────────────────────────────────────────────
# TIPOGRAFÍA POR TEMA — cada tema elige entre varias tipografías propias, como
# una cadena de fuentes de SISTEMA (`SystemFont`, sin necesidad de
# empaquetar archivos .ttf): se aplica GLOBALMENTE como fuente por defecto del
# árbol (`Locale._apply_theme_font()`), así que se hereda automáticamente en
# TODO texto que no tenga ya una fuente propia (HUD, mapamundi, diálogos...).
# ─────────────────────────────────────────────────────────────────────────────
static var _theme_fonts: Dictionary = {}   # theme_id -> SystemFont (caché)

# ─────────────────────────────────────────────────────────────────────────────
# FALLBACK CJK (chino / japonés / coreano) — evita los "tofu" (□□□) cuando el
# idioma activo usa caracteres que las fuentes latinas empaquetadas (Cinzel,
# EBGaramond) NO contienen. Se construye una `SystemFont` con una cadena de
# familias CJK habituales en cada SO (Windows: Microsoft YaHei / Yu Gothic /
# Malgun Gothic; macOS: Hiragino Sans / Arial Unicode MS — NOTA: PingFang se
# excluye deliberadamente porque su formato TTC propietario en macOS provoca que
# FreeType/Godot falle al parsear las subcaras y genere errores en bucle;
# Linux/empaquetado: Noto Sans CJK).
# `allow_system_fallback` (activo por defecto) permite además que el SO rellene
# cualquier glifo que falte. Este `Font` se añade como `fallbacks` de las
# `FontFile` latinas y de las `SystemFont` de tema, de modo que el texto latino
# conserva su tipografía y SOLO los glifos CJK caen a la fuente CJK.
# ─────────────────────────────────────────────────────────────────────────────
static var _cjk_fallback_font: SystemFont = null

## Devuelve (y cachea) la `SystemFont` con la cadena de familias CJK del sistema.
static func cjk_fallback_font() -> SystemFont:
	if _cjk_fallback_font != null:
		return _cjk_fallback_font
	var f := SystemFont.new()
	f.font_names = PackedStringArray([
		"Noto Sans CJK SC", "Noto Sans CJK JP", "Noto Sans SC", "Noto Sans JP",
		"Microsoft YaHei", "Microsoft JhengHei", "Yu Gothic UI", "Yu Gothic",
		"Meiryo", "MS Gothic", "Malgun Gothic", "SimSun", "SimHei",
		"Hiragino Sans", "Hiragino Kaku Gothic ProN",
		"WenQuanYi Micro Hei", "Sarasa Gothic SC", "Arial Unicode MS",
	])
	f.font_italic = false
	f.allow_system_fallback = true
	_cjk_fallback_font = f
	return f


static var _emoji_fallback_font: Font = null
static var _emoji_fallback_loaded: bool = false

## Devuelve (y cachea) la fuente local de emojis y símbolos universales (NotoEmoji).
static func emoji_fallback_font() -> Font:
	if not _emoji_fallback_loaded:
		_emoji_fallback_loaded = true
		var path := "res://assets/common/fonts/NotoEmoji.ttf"
		if ResourceLoader.exists(path):
			_emoji_fallback_font = load(path) as Font
	return _emoji_fallback_font


## Añade (idempotente) los fallbacks de Emojis y CJK a la lista de `fallbacks` de `font`.
static func _ensure_cjk_fallback(font: Font) -> void:
	if font == null:
		return
	var fbs: Array[Font] = font.fallbacks
	var emoji := emoji_fallback_font()
	if emoji != null and not emoji in fbs:
		fbs.insert(0, emoji)
	var cjk := cjk_fallback_font()
	if cjk != null and not cjk in fbs:
		fbs.append(cjk)
	font.fallbacks = fbs


## Alias público de `_ensure_cjk_fallback` para llamar desde otros autoloads
## (p. ej. `Locale`) sobre fuentes concretas cargadas de recursos.
static func ensure_font_cjk_fallback(font: Font) -> void:
	_ensure_cjk_fallback(font)


## Asegura (idempotente) que el `default_font` de un `Theme` cargado tenga el
## fallback CJK y Emoji. Necesario para `main_theme.tres`.
static func ensure_theme_cjk_fallback(theme: Theme) -> void:
	if theme == null:
		return
	if theme.default_font != null:
		_ensure_cjk_fallback(theme.default_font)


## Devuelve (y cachea) la fuente del tema `theme_id`.
## En navegador Web (WASM), SystemFont no puede acceder a las fuentes del sistema operativo;
## por tanto, en Web se usa directamente EBGaramond.ttf con NotoEmoji.ttf como fallback universal.
static func build_theme_font(theme_id: String) -> Font:
	if _theme_fonts.has(theme_id):
		return _theme_fonts[theme_id]
	if OS.has_feature("web"):
		var web_font := load("res://assets/common/fonts/EBGaramond.ttf") as Font
		if web_font != null:
			_ensure_cjk_fallback(web_font)
			_theme_fonts[theme_id] = web_font
			return web_font
	var t: Dictionary = THEMES.get(theme_id, THEMES["default"])
	var names: PackedStringArray = t.get("font_names", PackedStringArray())
	var f := SystemFont.new()
	if not names.is_empty():
		f.font_names = names
	f.font_italic = false
	f.allow_system_fallback = true
	_ensure_cjk_fallback(f)
	_theme_fonts[theme_id] = f
	return f


## Fuente de sistema del tema ACTIVO (`Locale.ui_theme_id`).
static func theme_font() -> Font:
	return build_theme_font(Locale.ui_theme_id)


# ─────────────────────────────────────────────────────────────────────────────
# MARCO PREMIUM (shader de borde)
# ─────────────────────────────────────────────────────────────────────────────
# Sustituye los bordes planos de 1px de StyleBoxFlat por un marco grueso con
# relieve, degradado de dos colores y brillo animado recorriendo el perímetro
# (y arcoíris animado en "happyflower"). Implementado como un ColorRect hijo
# ("_PremiumBorderRect") que cubre el rect completo del panel, con un
# `ui_premium_border.gdshader` aplicado. Si el recurso del shader no está
# disponible (p. ej. export sin importar), degrada con elegancia a un
# StyleBoxFlat de doble borde reforzado (`_premium_fallback_style`).
# ─────────────────────────────────────────────────────────────────────────────

const PREMIUM_BORDER_SHADER_PATH := "res://assets/common/shaders/ui_premium_border.gdshader"
static var _premium_border_shader: Shader = null
static var _premium_border_shader_checked: bool = false

static func _get_premium_border_shader() -> Shader:
	if not _premium_border_shader_checked:
		_premium_border_shader_checked = true
		if ResourceLoader.exists(PREMIUM_BORDER_SHADER_PATH):
			_premium_border_shader = load(PREMIUM_BORDER_SHADER_PATH) as Shader
	return _premium_border_shader


## Aplica (o refresca) el marco premium del tema activo sobre `node`
## (`Panel`/`PanelContainer`/`Control`). Es IDEMPOTENTE: se puede volver a
## llamar en cada cambio de tema (`GlobalEvents.theme_changed`) o de tamaño sin
## crear nodos/materiales duplicados.
##
## `opts` (todas opcionales, sobrescriben el valor del tema activo):
##   "pad" (int, margen de contenido en px, default 10 — solo aplica si `node`
##          es `Panel`/`PanelContainer`), "bg_color", "border_color",
##          "border_color_2", "border_width", "corner_radius", "bevel_strength",
##          "glow_strength", "sweep_speed", "hue_shift_speed", "mosaic_scale",
##          "mosaic_strength" (0.0 desactiva el mosaico, ver task_themes.md).
static func premium_frame(node: Control, opts: Dictionary = {}) -> void:
	if node == null or not is_instance_valid(node):
		return

	var bg_color: Color = opts.get("bg_color", theme_color("panel_bg", Color(0.04, 0.035, 0.07, 0.96)))
	var border_color: Color = opts.get("border_color", theme_color("frame_color", Color(0.96, 0.77, 0.42)))
	var border_color_2: Color = opts.get("border_color_2", theme_color("frame_color_2", Color(0.72, 0.47, 0.04)))
	var border_width: float = float(opts.get("border_width", theme_float("frame_width", 10.0)))
	var corner_radius: float = float(opts.get("corner_radius", theme_float("frame_radius", 14.0)))
	var bevel_strength: float = float(opts.get("bevel_strength", theme_float("frame_bevel", 0.5)))
	var glow_strength: float = float(opts.get("glow_strength", theme_float("frame_glow", 0.35)))
	var sweep_speed: float = float(opts.get("sweep_speed", theme_float("frame_sweep", 0.15)))
	var hue_shift_speed: float = float(opts.get("hue_shift_speed", theme_float("frame_hue_shift", 0.0)))
	var mosaic_scale: float = float(opts.get("mosaic_scale", theme_float("mosaic_scale", 18.0)))
	var mosaic_strength: float = float(opts.get("mosaic_strength", theme_float("mosaic_strength", 0.0)))
	var pad: int = int(opts.get("pad", 20))
	var pad_left: int = int(opts.get("pad_left", pad))
	var pad_right: int = int(opts.get("pad_right", pad))
	var pad_top: int = int(opts.get("pad_top", pad))
	var pad_bottom: int = int(opts.get("pad_bottom", pad))

	# Vacía el estilo propio para que no dibuje su StyleBox por debajo del
	# marco de shader; conserva el margen de contenido para no descolocar a los hijos/texto.
	if node is Panel or node is PanelContainer:
		var empty_style := StyleBoxEmpty.new()
		empty_style.content_margin_left = pad_left
		empty_style.content_margin_right = pad_right
		empty_style.content_margin_top = pad_top
		empty_style.content_margin_bottom = pad_bottom
		node.add_theme_stylebox_override("panel", empty_style)
	elif node is Button:
		for st in ["normal", "hover", "pressed", "focus", "disabled"]:
			var empty_style := StyleBoxEmpty.new()
			empty_style.content_margin_left = pad_left
			empty_style.content_margin_right = pad_right
			empty_style.content_margin_top = pad_top
			empty_style.content_margin_bottom = pad_bottom
			node.add_theme_stylebox_override(st, empty_style)

	var shader := _get_premium_border_shader()
	if shader == null:
		# Fallback sin shader: StyleBoxFlat reforzado con doble borde simulado.
		var fallback_style := _premium_fallback_style(bg_color, border_color, border_width, corner_radius, pad)
		if node is Panel or node is PanelContainer:
			node.add_theme_stylebox_override("panel", fallback_style)
		elif node is Button:
			for st in ["normal", "hover", "pressed", "focus", "disabled"]:
				node.add_theme_stylebox_override(st, fallback_style)
		return

	var rect: ColorRect = node.get_node_or_null("_PremiumBorderRect") as ColorRect
	if rect == null:
		rect = ColorRect.new()
		rect.name = "_PremiumBorderRect"
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.show_behind_parent = true
		rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		node.add_child(rect)
		node.move_child(rect, 0)
	else:
		rect.show_behind_parent = true

	var mat: ShaderMaterial = rect.material as ShaderMaterial
	if mat == null:
		mat = ShaderMaterial.new()
		mat.shader = shader
		rect.material = mat

	var reduce := Locale.reduce_motion
	mat.set_shader_parameter("bg_color", bg_color)
	mat.set_shader_parameter("border_color", border_color)
	mat.set_shader_parameter("border_color_2", border_color_2)
	mat.set_shader_parameter("border_width", border_width)
	mat.set_shader_parameter("corner_radius", corner_radius)
	mat.set_shader_parameter("bevel_strength", bevel_strength)
	mat.set_shader_parameter("glow_strength", glow_strength)
	mat.set_shader_parameter("sweep_speed", 0.0 if reduce else sweep_speed)
	mat.set_shader_parameter("hue_shift_speed", 0.0 if reduce else hue_shift_speed)
	mat.set_shader_parameter("time_scale", 0.0 if reduce else 1.0)
	mat.set_shader_parameter("rect_size", rect.size)
	mat.set_shader_parameter("mosaic_scale", mosaic_scale)
	mat.set_shader_parameter("mosaic_strength", mosaic_strength)

	if not rect.has_meta("_premium_resize_wired"):
		rect.set_meta("_premium_resize_wired", true)
		rect.resized.connect(func() -> void:
			if is_instance_valid(rect) and rect.material is ShaderMaterial:
				(rect.material as ShaderMaterial).set_shader_parameter("rect_size", rect.size)
		)


## Devuelve el `ShaderMaterial` del marco premium ya instalado en `node` (o
## `null` si `node` no tiene `premium_frame` aplicado, p. ej. por estar en modo
## de respaldo sin shader). Pensado para animaciones puntuales avanzadas que
## necesitan variar el marco frame a frame (p. ej. el aura de Resonancia MÁX
## de `ViewCombat`) sin pasar por `premium_frame` en cada paso del tween.
static func get_premium_material(node: Control) -> ShaderMaterial:
	if node == null or not is_instance_valid(node):
		return null
	var rect := node.get_node_or_null("_PremiumBorderRect") as ColorRect
	if rect == null:
		return null
	return rect.material as ShaderMaterial


## StyleBoxFlat de respaldo (sin shader disponible): doble borde simulado con
## `border_color` grueso + sombra tintada con el mismo color para dar
## sensación de relieve/halo. Bastante más "premium" que el borde de 1px
## anterior, aunque sin el brillo animado del shader.
static func _premium_fallback_style(bg: Color, border: Color, border_w: float, radius: float, pad: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(maxi(2, int(round(border_w))))
	s.set_corner_radius_all(int(round(radius)))
	s.set_content_margin_all(pad)
	s.shadow_color = Color(border.r, border.g, border.b, 0.35)
	s.shadow_size = 8
	return s


## Reemplazo directo de `panel.add_theme_stylebox_override("panel",
## UiKit.neoclassic_panel(radius, pad))` que además instala el marco premium
## de shader del tema activo. Mismo uso: llamar sobre un `Panel`/
## `PanelContainer` recién creado.
static func premium_panel(node: Control, radius: int = 8, pad: int = 18) -> void:
	premium_frame(node, {"corner_radius": float(radius), "pad": pad})


## Reemplazo directo de `panel.add_theme_stylebox_override("panel",
## UiKit.dialog_panel(accent, radius))`. `accent` tiñe el filo del marco
## (border_color); el segundo tono del degradado se deriva oscureciéndolo,
## para no perder la identidad de color que pedía cada llamante concreto.
static func premium_dialog_panel(node: Control, accent: Color = ACCENT, radius: int = 24, pad: int = 24) -> void:
	premium_frame(node, {
		"border_color": accent,
		"border_color_2": accent.darkened(0.45),
		"corner_radius": float(radius),
		"pad": pad,
	})


## Aplica el marco premium del tema activo a un botón (`Button`), configurando
## el shader con proporciones idóneas para botones de acción/opciones y asignando
## los colores de texto temáticos correspondientes.
static func premium_button(btn: Button, opts: Dictionary = {}) -> void:
	if btn == null or not is_instance_valid(btn):
		return
	var is_disabled: bool = bool(opts.get("disabled", btn.disabled))
	var radius: float = float(opts.get("corner_radius", 14.0))
	var border_w: float = float(opts.get("border_width", 3.0))
	var pad_x: int = int(opts.get("pad_x", 16))
	var pad_y: int = int(opts.get("pad_y", 12))

	var frame_opts := opts.duplicate()
	frame_opts["corner_radius"] = radius
	frame_opts["border_width"] = border_w
	frame_opts["pad_left"] = int(opts.get("pad_left", pad_x))
	frame_opts["pad_right"] = int(opts.get("pad_right", pad_x))
	frame_opts["pad_top"] = int(opts.get("pad_top", pad_y))
	frame_opts["pad_bottom"] = int(opts.get("pad_bottom", pad_y))

	if is_disabled:
		btn.disabled = true
		var bg := theme_color("panel_bg", Color(0.04, 0.04, 0.06, 0.9)).darkened(0.3)
		bg.a = 0.6
		var b_col := theme_color("border", BORDER_SOFT).darkened(0.2)
		frame_opts["bg_color"] = frame_opts.get("bg_color", bg)
		frame_opts["border_color"] = frame_opts.get("border_color", b_col)
		frame_opts["border_color_2"] = frame_opts.get("border_color_2", b_col.darkened(0.5))
		frame_opts["glow_strength"] = 0.0
		frame_opts["sweep_speed"] = 0.0
		btn.add_theme_color_override("font_color", theme_color("text_dim", TEXT_FAINT))
		btn.add_theme_color_override("font_disabled_color", theme_color("text_dim", TEXT_FAINT))
	else:
		btn.disabled = false
		btn.add_theme_color_override("font_color", theme_color("text", TEXT))
		btn.add_theme_color_override("font_hover_color", theme_color("accent", ACCENT_SOFT))
		btn.add_theme_color_override("font_pressed_color", theme_color("highlight", ACCENT))
		btn.add_theme_color_override("font_focus_color", theme_color("accent", ACCENT_SOFT))

	premium_frame(btn, frame_opts)


# ─────────────────────────────────────────────────────────────────────────────
# FÁBRICAS DE STYLEBOX
# ─────────────────────────────────────────────────────────────────────────────

## Panel genérico (fondo + borde + esquinas redondeadas).
static func panel(bg: Color = SURFACE, border: Color = BORDER, radius: int = 16, border_w: int = 3) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	return s


## Panel neoclásico compartido por el HUD/Hub/combate (fondo oscuro + borde de
## acento dorado + sombra). Lee la paleta del tema activo:
## el fondo usa "panel_bg" (mismo tono oscuro que el resto del HUD en ese
## tema) y el borde usa "accent" (NO "border" — esa clave es el morado
## decorativo específico de los paneles rediseñados de combate en
## `ViewCombat.gd`, no el trim dorado que usa este panel en todo el Hub).
## Con el tema "default" el aspecto es prácticamente idéntico al original
## (fondo negro-azul + trim dorado + sombra 10px).
static func neoclassic_panel(radius: int = 8, pad: int = 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = theme_color("panel_bg", Color(0.05, 0.07, 0.11, 0.85))
	s.border_color = theme_color("accent", Color(0.85, 0.65, 0.2, 0.8))
	s.set_border_width_all(4)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	s.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	s.shadow_size = 10
	return s


## Tarjeta con margen interior. Si `accent` es true, resalta el borde en ámbar.
static func card(accent: bool = false, radius: int = 14, pad: int = 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = SURFACE
	s.border_color = ACCENT if accent else BORDER
	s.set_border_width_all(4 if accent else 3)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	if accent:
		s.shadow_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.12)
		s.shadow_size = 6
	return s


## Tarjeta resaltada por un color de acento concreto (ej. tipo de daño).
static func card_tinted(tint: Color, radius: int = 14, pad: int = 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = SURFACE
	s.border_color = Color(tint.r, tint.g, tint.b, 0.45)
	s.set_border_width_all(4)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	return s


## Panel de diálogo modal (fondo base + borde de acento tenue + sombra suave).
## Para overlays grandes centrados (opciones, créditos, popups informativos).
static func dialog_panel(accent: Color = ACCENT, radius: int = 24) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = BG_BASE
	s.border_color = Color(accent.r, accent.g, accent.b, 0.35)
	s.set_border_width_all(4)
	s.set_corner_radius_all(radius)
	s.shadow_color = Color(0, 0, 0, 0.6)
	s.shadow_size = 24
	return s


## Fondo de cabecera/pie translúcido (para superponer sobre escenas).
static func header(alpha: float = 0.92, bottom_border: bool = true) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(BG_BASE.r, BG_BASE.g, BG_BASE.b, alpha)
	s.set_border_width_all(0)
	if bottom_border:
		s.border_width_bottom = 2
		s.border_color = BORDER
	return s


## Fondo de barra de progreso.
static func bar_bg(radius: int = 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color("0a0c11")
	s.border_color = BORDER_SOFT
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	return s


## Relleno de barra de progreso de un color dado (con leve brillo).
static func bar_fill(color: Color, radius: int = 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.shadow_color = Color(color.r, color.g, color.b, 0.22)
	s.shadow_size = 3
	return s


## Cápsula/etiqueta pequeña (chip) con borde de acento.
static func chip(border: Color = ACCENT, bg_alpha: float = 0.9, radius: int = 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(BG_BASE.r, BG_BASE.g, BG_BASE.b, bg_alpha)
	s.border_color = Color(border.r, border.g, border.b, 0.5)
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	return s


## Insignia "+N" de nivel de REFINAMIENTO de un equipo (ver task5.md /
## EquipmentResource.refine_level). Devuelve null si `level <= 0` (nivel +0 no
## se indica). Colocar con `with_corner_badge` sobre el icono del equipo.
static func refine_badge(level: int) -> Control:
	if level <= 0:
		return null
	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := StyleBoxFlat.new()
	s.bg_color = COLOR_GOLD_PRIMARY
	s.set_corner_radius_all(8)
	s.content_margin_left = 6
	s.content_margin_right = 6
	s.content_margin_top = 1
	s.content_margin_bottom = 1
	badge.add_theme_stylebox_override("panel", s)
	var lbl := Label.new()
	lbl.text = "+%d" % level
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", COLOR_BG_DARK)
	badge.add_child(lbl)
	return badge

## Envuelve `inner` en un Control que además ancla `badge` a una esquina (por
## defecto, superior derecha — ver task5.md). Si `badge` es null (nivel +0),
## devuelve `inner` sin modificar.
static func with_corner_badge(inner: Control, badge: Control, preset: int = Control.PRESET_TOP_RIGHT) -> Control:
	if badge == null:
		return inner
	var wrap_ctrl := Control.new()
	wrap_ctrl.size_flags_horizontal = inner.size_flags_horizontal
	wrap_ctrl.size_flags_vertical = inner.size_flags_vertical
	wrap_ctrl.custom_minimum_size = inner.custom_minimum_size
	wrap_ctrl.mouse_filter = Control.MOUSE_FILTER_PASS
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrap_ctrl.add_child(inner)
	badge.set_anchors_and_offsets_preset(preset)
	wrap_ctrl.add_child(badge)
	return wrap_ctrl


## Estilo de botón primario (relleno ámbar) — para llamadas a la acción.
static func button_primary(radius: int = 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = ACCENT
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(10)
	s.shadow_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.25)
	s.shadow_size = 6
	return s


## Estilo de botón fantasma (transparente con borde) — acciones secundarias.
static func button_ghost(border: Color = BORDER, radius: int = 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = SURFACE_ALT
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(10)
	return s


## Estilo de botón con borde de contorno (outline).
static func button_outline(radius: int = 12, border: Color = ACCENT) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(BG_BASE.r, BG_BASE.g, BG_BASE.b, 0.7)
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(10)
	return s


## StyleBox vacío (para zonas transparentes que igualmente capturan input).
static func empty() -> StyleBoxEmpty:
	return StyleBoxEmpty.new()


# ─────────────────────────────────────────────────────────────────────────────
# HELPERS DE NODOS
# ─────────────────────────────────────────────────────────────────────────────

## Fuente "display" para titulares (Cinzel). Se carga y cachea una sola vez.
## Devuelve null si la fuente aún no está disponible/importada (degrada con elegancia).
static var _heading_font: Font = null
static var _heading_font_loaded: bool = false

## Devuelve la fuente de titulares (Cinzel) o null si no está disponible.
static func heading_font() -> Font:
	if not _heading_font_loaded:
		_heading_font_loaded = true
		var path := "res://assets/common/fonts/Cinzel.ttf"
		if ResourceLoader.exists(path):
			_heading_font = load(path) as Font
			# Cinzel solo cubre glifos latinos: sin este fallback, los titulares
			# en chino/japonés saldrían como cajas vacías (tofu).
			_ensure_cjk_fallback(_heading_font)
	return _heading_font


## Aplica la fuente de titulares (Cinzel) a una etiqueta si está disponible.
## Null-safe: si la fuente no está importada aún, no hace nada (degrada con elegancia).
static func apply_heading(label: Label) -> void:
	var hf := heading_font()
	if hf != null and label != null:
		label.add_theme_font_override("font", hf)


## Crea una etiqueta de sección con icono + título y estilo coherente.
## Aplica la fuente de titulares (Cinzel) si está disponible.
static func section_title(text: String, size: int = 26, color: Color = TEXT) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	var hf := heading_font()
	if hf != null:
		lbl.add_theme_font_override("font", hf)
	return lbl


## Aplica los estilos de fondo/relleno del UiKit a una ProgressBar existente.
static func style_progress(bar: ProgressBar, fill_color: Color, radius: int = 8) -> void:
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", bar_bg(radius))
	bar.add_theme_stylebox_override("fill", bar_fill(fill_color, radius))


## Aplica los estilos de fondo/relleno con un borde de color destacado (por defecto blanco).
static func style_progress_bordered(bar: ProgressBar, fill_color: Color, radius: int = 8, border_color: Color = Color.WHITE, border_w: int = 2) -> void:
	bar.show_percentage = false
	var bg := bar_bg(radius)
	bg.border_color = border_color
	bg.set_border_width_all(border_w)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", bar_fill(fill_color, radius))


## Anima un pequeño "pop" de escala sobre un Control (feedback al pulsar/cambiar).
static func pop(node: Control, scale: float = 1.12, time: float = 0.18) -> void:
	if node == null:
		return
	node.pivot_offset = node.size * 0.5
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector2(scale, scale), time * 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", Vector2.ONE, time * 0.6).set_trans(Tween.TRANS_SINE)


## Task 4 FASE 2.2 — Feedback táctil de pulsación para botones grandes (p. ej.
## el dock de acciones contextuales del mapamundi): al PULSAR reduce la escala
## a `press_scale` (por defecto 0.92×) en `down_time`; al SOLTAR/cancelar
## rebota elásticamente de vuelta a 1.0× en `up_time`. Complementa (no
## sustituye) el sonido de pulsación ya centralizado en AudioManager. Respeta
## `Locale.reduce_motion` (deja la escala fija en 1.0, sin animar).
static func bind_press_feedback(btn: BaseButton, press_scale: float = 0.92, down_time: float = 0.08, up_time: float = 0.22) -> void:
	if btn == null:
		return
	btn.button_down.connect(func() -> void:
		if not is_instance_valid(btn):
			return
		if Locale.reduce_motion:
			return
		btn.pivot_offset = btn.size * 0.5
		var tw := btn.create_tween()
		tw.tween_property(btn, "scale", Vector2(press_scale, press_scale), down_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	)
	btn.button_up.connect(func() -> void:
		if not is_instance_valid(btn):
			return
		if Locale.reduce_motion:
			btn.scale = Vector2.ONE
			return
		btn.pivot_offset = btn.size * 0.5
		var tw := btn.create_tween()
		tw.tween_property(btn, "scale", Vector2.ONE, up_time).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	)


## Aplica el estilo de "pestaña segmentada" (barra de sub-pestañas superior) a un
## botón: activa = píldora tonal ámbar con subrayado de acento y leve brillo;
## inactiva = fantasma transparente (mantiene el mismo tamaño para no dar saltos).
## Unifica el aspecto de las sub-tabs (personaje, bolsa…) con la bottom-nav.
static func style_segmented_tab(btn: Button, active: bool, tint: Color = ACCENT) -> void:
	if btn == null:
		return
	var s := StyleBoxFlat.new()
	s.set_corner_radius_all(12)
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	s.content_margin_left = 10
	s.content_margin_right = 10
	if active:
		s.bg_color = Color(tint.r, tint.g, tint.b, 0.16)
		s.border_width_bottom = 3
		s.border_color = tint
		s.shadow_color = Color(tint.r, tint.g, tint.b, 0.16)
		s.shadow_size = 6
		btn.add_theme_color_override("font_color", ACCENT_SOFT)
		btn.add_theme_color_override("font_hover_color", ACCENT_SOFT)
		btn.add_theme_color_override("font_pressed_color", tint)
		btn.add_theme_color_override("font_focus_color", ACCENT_SOFT)
	else:
		s.bg_color = Color(tint.r, tint.g, tint.b, 0.0)
		btn.add_theme_color_override("font_color", TEXT_FAINT)
		btn.add_theme_color_override("font_hover_color", ACCENT_SOFT)
		btn.add_theme_color_override("font_pressed_color", tint)
		btn.add_theme_color_override("font_focus_color", TEXT_FAINT)
	for st in ["normal", "hover", "pressed", "focus"]:
		btn.add_theme_stylebox_override(st, s)


## Etiqueta de cabecera de sección (icono + título) con el estilo de acento estándar.
static func section_header(text: String = "", size: int = 30) -> Label:
	return section_title(text, size, ACCENT_SOFT)


# ─────────────────────────────────────────────────────────────────────────────
# HELPERS DE NODOS — CONTENEDORES, AVISOS Y CAPAS MODALES
#   Centralizan patrones que antes se repetían en cada vista construida por código
#   (márgenes, avisos flotantes, capas modales y diálogos de confirmación).
#   Úsalos en lugar de recrearlos a mano en cada fichero.
# ─────────────────────────────────────────────────────────────────────────────

## MarginContainer con los cuatro márgenes indicados (atajo muy usado por las vistas).
static func margins(left: int, right: int, top: int, bottom: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", left)
	m.add_theme_constant_override("margin_right", right)
	m.add_theme_constant_override("margin_top", top)
	m.add_theme_constant_override("margin_bottom", bottom)
	return m


## MarginContainer con el mismo margen en los cuatro lados.
static func margins_all(pad: int) -> MarginContainer:
	return margins(pad, pad, pad, pad)


## Aviso flotante efímero: una etiqueta centrada que sube y se desvanece sola.
## Se autodestruye al terminar; no requiere mantener ninguna referencia.
static func toast(parent: Node, text: String, color: Color = ACCENT_SOFT) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 32)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(lbl)
	lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	var tw := lbl.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 120.0, 1.2).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 1.2).set_delay(0.3)
	tw.finished.connect(lbl.queue_free)


## Capa modal a pantalla completa con fondo oscurecido. Devuelve el Control raíz
## (líbralo con queue_free para cerrarla). Bloquea el input de lo que hay debajo.
static func overlay(parent: Node, dim: float = 0.9) -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.04, dim)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	if parent != null and is_instance_valid(parent):
		parent.add_child(root)
	return root


## Diálogo modal de confirmación reutilizable: capa + panel centrado (título +
## cuerpo + botones Cancelar/Aceptar). Llama a `on_confirm` SÓLO si se acepta;
## en ambos casos cierra la capa. Devuelve la capa raíz por si hace falta.
static func confirm(parent: Node, title: String, body: String, ok_text: String, cancel_text: String, on_confirm: Callable, accent: Color = ACCENT) -> Control:
	var root := overlay(parent)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var confirm_panel := PanelContainer.new()
	confirm_panel.custom_minimum_size = Vector2(640, 0)
	premium_dialog_panel(confirm_panel, accent, 22, 0)
	center.add_child(confirm_panel)
	animate_in(confirm_panel, 0.22)
	var margin := margins(40, 40, 34, 34)
	confirm_panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 22)
	margin.add_child(vbox)
	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 36)
	title_lbl.add_theme_color_override("font_color", accent)
	vbox.add_child(title_lbl)
	var body_lbl := Label.new()
	body_lbl.text = body
	body_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_lbl.add_theme_font_size_override("font_size", 23)
	body_lbl.add_theme_color_override("font_color", TEXT_DIM)
	vbox.add_child(body_lbl)
	var rows := HBoxContainer.new()
	rows.add_theme_constant_override("separation", 16)
	vbox.add_child(rows)
	var btn_cancel := Button.new()
	btn_cancel.text = cancel_text
	btn_cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_cancel.custom_minimum_size = Vector2(0, 64)
	btn_cancel.add_theme_font_size_override("font_size", 26)
	btn_cancel.pressed.connect(func() -> void:
		if AudioManager != null:
			AudioManager.play_sfx("main_menu_click")
		animate_out(confirm_panel, 0.15, root.queue_free)
	)
	rows.add_child(btn_cancel)
	var btn_ok := Button.new()
	btn_ok.text = ok_text
	btn_ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_ok.custom_minimum_size = Vector2(0, 64)
	btn_ok.add_theme_font_size_override("font_size", 26)
	btn_ok.pressed.connect(func() -> void:
		if AudioManager != null:
			AudioManager.play_sfx("main_menu_click")
		# La acción confirmada se dispara YA, sin esperar al fundido: si depende
		# de una navegación/cambio de escena (p. ej. "Guardar y Salir"), un
		# tween que no llegue a completarse (nodo destruido entretanto) no debe
		# poder impedirla — el fundido es puramente decorativo.
		if on_confirm.is_valid():
			on_confirm.call()
		animate_out(confirm_panel, 0.15, root.queue_free)
	)
	rows.add_child(btn_ok)
	return root


## Muestra un modal de aviso efímero (disclaimer/anuncio informativo o gracioso)
## centrado en pantalla, con fondo oscurecido y auto-cierre con temporizador.
static func show_ephemeral_modal(parent: Node, title: String, message: String, subtitle: String = "", duration: float = 3.0, accent: Color = ACCENT) -> Control:
	var tree := Engine.get_main_loop() as SceneTree
	var target_parent: Node = parent
	if target_parent == null:
		target_parent = tree.root if tree != null else null
	if target_parent == null or not is_instance_valid(target_parent):
		return null

	var root := Control.new()
	root.name = "EphemeralModal"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := ColorRect.new()
	bg.color = Color(0.01, 0.02, 0.04, 0.78)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	var panel_node := PanelContainer.new()
	panel_node.custom_minimum_size = Vector2(620, 0)
	premium_dialog_panel(panel_node, accent, 24, 0)
	center.add_child(panel_node)

	var margin := margins(36, 36, 28, 28)
	panel_node.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	if title != "":
		var title_lbl := Label.new()
		title_lbl.text = title
		title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_lbl.add_theme_font_size_override("font_size", 24)
		title_lbl.add_theme_color_override("font_color", accent)
		vbox.add_child(title_lbl)

	var body_lbl := Label.new()
	body_lbl.text = message
	body_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_lbl.add_theme_font_size_override("font_size", 22)
	body_lbl.add_theme_color_override("font_color", Color(1.0, 0.98, 0.92))
	vbox.add_child(body_lbl)

	if subtitle != "":
		var sub_lbl := Label.new()
		sub_lbl.text = subtitle
		sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub_lbl.add_theme_font_size_override("font_size", 16)
		sub_lbl.add_theme_color_override("font_color", TEXT_DIM)
		vbox.add_child(sub_lbl)

	target_parent.add_child(root)
	root.modulate.a = 0.0
	panel_node.scale = Vector2(0.85, 0.85)
	panel_node.pivot_offset = Vector2(310, 80)

	var tw := root.create_tween()
	tw.set_parallel(true)
	tw.tween_property(root, "modulate:a", 1.0, 0.25).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel_node, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Cierre tras `duration` segundos con fade out suave
	var close_tw := root.create_tween()
	close_tw.tween_interval(duration)
	close_tw.tween_property(root, "modulate:a", 0.0, 0.4).set_ease(Tween.EASE_IN)
	close_tw.tween_callback(root.queue_free)

	# Permitir también cerrar haciendo clic antes de los 3s
	root.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			root.queue_free()
	)

	return root


# ─────────────────────────────────────────────────────────────────────────────
# HELPERS NARRATIVOS
# ─────────────────────────────────────────────────────────────────────────────

## Comprueba si una opción de diálogo requiere un nivel mínimo de faceta.
static func check_option_facet_req(opt: Dictionary, npc_id: String = "") -> Dictionary:
	var cond: String = String(opt.get("condition", ""))
	var text: String = String(opt.get("text", ""))
	
	if cond == "" and "faceta:" in text:
		var start := text.find("faceta:")
		var space := text.find(" ", start)
		var bracket := text.find("]", start)
		var end_idx: int = space if space != -1 else bracket
		if end_idx != -1:
			cond = text.substr(start, end_idx - start)
			
	if cond == "":
		return {"has_req": false, "met": true}
		
	var met: bool = Design.eval_condition(cond, npc_id)
	var facet_icons := {
		"valor": "🛡️", "valentia": "🛡️",
		"bondad": "💚", "amabilidad": "💚",
		"aspecto": "🎭", "encanto": "🎭",
		"inteligencia": "🧠", "astucia": "🧠",
		"cordura": "🌀"
	}
	var facet_names := {
		"valor": "Valor", "valentia": "Valor",
		"bondad": "Bondad", "amabilidad": "Bondad",
		"aspecto": "Aspecto", "encanto": "Aspecto",
		"inteligencia": "Inteligencia", "astucia": "Inteligencia",
		"cordura": "Cordura"
	}
	
	var has_req := false
	var req_icon := "🔒"
	var fname := ""
	var req_val := 0
	
	for fk: String in facet_icons.keys():
		if fk in cond.to_lower():
			has_req = true
			req_icon = facet_icons[fk]
			fname = facet_names[fk]
			var regex := RegEx.new()
			regex.compile("(?:>=|>|==)(\\d+)")
			var result := regex.search(cond)
			if result:
				req_val = int(result.get_string(1))
			break
			
	if not has_req:
		return {"has_req": false, "met": met}
		
	var badge_text := Locale.t("vn_requires_facet", [fname, req_val]) if fname != "" else "Requiere faceta"
	return {
		"has_req": true,
		"met": met,
		"icon": req_icon,
		"facet_name": fname,
		"req_val": req_val,
		"badge_text": "%s %s" % [req_icon, badge_text]
	}


## Crea el panel lateral de información del diálogo (📖): afinidad con el NPC y las 5 facetas.
## Usa `premium_dialog_panel` (mismo marco/fondo que el resto de modales del
## juego: Logros, Bestiario, Opciones...) en vez de un color de marca estático,
## para que el tema activo también pinte esta modal.
static func create_narrative_info_drawer(npc_id: String, on_close: Callable) -> Control:
	var drawer := PanelContainer.new()
	drawer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drawer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	premium_dialog_panel(drawer, theme_color("accent", ACCENT), 20)
	
	var margin := margins(28, 28, 24, 24)
	drawer.add_child(margin)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	margin.add_child(vbox)
	
	# Cabecera con botón cerrar
	var header_box := HBoxContainer.new()
	header_box.add_theme_constant_override("separation", 14)
	vbox.add_child(header_box)
	
	var title := Label.new()
	title.text = "📖  " + Locale.t("vn_info_title")
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", theme_color("accent", ACCENT_SOFT))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_box.add_child(title)
	
	var btn_close := Button.new()
	btn_close.text = "X"
	btn_close.custom_minimum_size = Vector2(58, 58)
	btn_close.add_theme_font_size_override("font_size", 28)
	btn_close.pressed.connect(on_close)
	header_box.add_child(btn_close)
	
	vbox.add_child(HSeparator.new())
	
	# 1. Afinidad con el NPC
	var rel_title := Label.new()
	rel_title.text = "🤝  " + Locale.t("vn_affinity_label")
	rel_title.add_theme_font_size_override("font_size", 34)
	rel_title.add_theme_color_override("font_color", theme_color("text", TEXT))
	vbox.add_child(rel_title)
	
	var rel_val := GlobalState.get_npc_relationship(npc_id)
	var rel_bar := ProgressBar.new()
	rel_bar.max_value = 10
	rel_bar.value = clampi(rel_val, 0, 10)
	rel_bar.custom_minimum_size = Vector2(0, 56)
	style_progress(rel_bar, GOOD, 14)
	
	var rel_lbl := Label.new()
	rel_lbl.text = "%d / 10" % rel_val
	rel_lbl.add_theme_font_size_override("font_size", 32)
	rel_lbl.add_theme_color_override("font_color", theme_color("text", TEXT))
	rel_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rel_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rel_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rel_bar.add_child(rel_lbl)
	vbox.add_child(rel_bar)
	
	vbox.add_child(HSeparator.new())
	
	# 2. Las 5 facetas del héroe
	var facets_title := Label.new()
	facets_title.text = "🎭  " + Locale.t("vn_facets_label")
	facets_title.add_theme_font_size_override("font_size", 34)
	facets_title.add_theme_color_override("font_color", theme_color("text", TEXT))
	vbox.add_child(facets_title)
	
	var facet_defs: Array[Dictionary] = [
		{"key": "valor", "icon": "🛡️", "color": Color("ff9f43")},
		{"key": "bondad", "icon": "💚", "color": Color("10ac84")},
		{"key": "aspecto", "icon": "🎭", "color": Color("9b59b6")},
		{"key": "inteligencia", "icon": "🧠", "color": Color("41a3ff")},
		{"key": "cordura", "icon": "🌀", "color": Color("a855f7")},
	]
	
	for f in facet_defs:
		var val: int = GlobalState.get_faceta(f["key"])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		vbox.add_child(row)
		
		var f_lbl := Label.new()
		f_lbl.text = "%s %s" % [f["icon"], Locale.t("facet_" + f["key"])]
		f_lbl.add_theme_font_size_override("font_size", 32)
		f_lbl.add_theme_color_override("font_color", theme_color("text", TEXT))
		f_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(f_lbl)
		
		var val_lbl := Label.new()
		val_lbl.text = "%+d" % val
		val_lbl.add_theme_font_size_override("font_size", 34)
		var val_col: Color = f["color"] if val > 0 else (theme_color("danger", BAD) if val < 0 else theme_color("text_dim", TEXT_DIM))
		val_lbl.add_theme_color_override("font_color", val_col)
		row.add_child(val_lbl)
		
	return drawer


## Modal de notificación emergente cuando el jugador recibe un ítem (Tienda, Hacha, Caña, etc.).
static func show_item_modal(parent: Node, item_id: String, qty: int = 1) -> void:
	if parent == null:
		return
	var item_name := Design.get_item_name(item_id)
	var item_icon := Design.get_item_icon(item_id)
	if item_icon == "" or item_icon == "❓":
		item_icon = "🎁"

	var canvas := CanvasLayer.new()
	canvas.layer = 105
	parent.add_child(canvas)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(center)

	var panel_box := PanelContainer.new()
	panel_box.custom_minimum_size = Vector2(580, 220)
	premium_frame(panel_box, {"bg_color": Color(0.05, 0.07, 0.12, 0.96), "border_color": theme_color("accent", ACCENT), "corner_radius": 20.0, "pad": 0})
	center.add_child(panel_box)

	var margin := margins(30, 30, 24, 24)
	panel_box.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 22)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(hbox)

	var icon_box := avatar(item_icon, 84, ACCENT)
	icon_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(icon_box)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 6)
	hbox.add_child(vbox)

	var title_lbl := Label.new()
	title_lbl.text = "🎁  " + Locale.pick({"es": "¡NUEVO OBJETO OBTENIDO!", "en": "NEW ITEM RECEIVED!", "fr": "NOUVEL OBJET REÇU !", "it": "NUOVO OGGETTO RICEVUTO!", "de": "NEUER GEGENSTAND ERHALTEN!", "zh": "获得新物品！", "ja": "新しいアイテムを獲得！"})
	title_lbl.add_theme_font_size_override("font_size", 30)
	title_lbl.add_theme_color_override("font_color", ACCENT_SOFT)
	vbox.add_child(title_lbl)

	var desc_lbl := Label.new()
	var qty_str := (" x%d" % qty) if qty > 1 else ""
	desc_lbl.text = Locale.pick({
		"es": "Has recibido: %s%s" % [item_name, qty_str],
		"en": "You received: %s%s" % [item_name, qty_str],
		"fr": "Tu as reçu : %s%s" % [item_name, qty_str],
		"it": "Hai ricevuto: %s%s" % [item_name, qty_str],
		"de": "Du hast erhalten: %s%s" % [item_name, qty_str],
		"zh": "你获得了：%s%s" % [item_name, qty_str],
		"ja": "受け取ったもの：%s%s" % [item_name, qty_str],
	})
	desc_lbl.add_theme_font_size_override("font_size", 32)
	desc_lbl.add_theme_color_override("font_color", TEXT)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_lbl)

	AudioManager.play_ui("reward")
	pop(panel_box, 1.15, 0.25)

	var timer := parent.get_tree().create_timer(2.5)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(canvas):
			var tw := canvas.create_tween()
			tw.tween_property(panel_box, "modulate:a", 0.0, 0.35)
			tw.tween_callback(canvas.queue_free)
	)


## Diálogo modal Informativo/Aviso con un solo botón (Aceptar / Entendido).
static func alert(parent: Node, title: String, body: String, ok_text: String = "OK", on_ok: Callable = Callable(), accent: Color = ACCENT) -> Control:
	var root := overlay(parent)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel_box := PanelContainer.new()
	panel_box.custom_minimum_size = Vector2(640, 0)
	premium_dialog_panel(panel_box, accent, 22, 0)
	center.add_child(panel_box)
	animate_in(panel_box, 0.22)
	var margin := margins(40, 40, 34, 34)
	panel_box.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 22)
	margin.add_child(vbox)

	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 36)
	title_lbl.add_theme_color_override("font_color", accent)
	vbox.add_child(title_lbl)

	var body_lbl := Label.new()
	body_lbl.text = body
	body_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_lbl.add_theme_font_size_override("font_size", 24)
	body_lbl.add_theme_color_override("font_color", TEXT)
	vbox.add_child(body_lbl)

	var btn_ok := Button.new()
	btn_ok.text = ok_text
	btn_ok.custom_minimum_size = Vector2(0, 64)
	btn_ok.add_theme_font_size_override("font_size", 26)
	for st in ["normal", "hover", "pressed", "focus"]:
		btn_ok.add_theme_stylebox_override(st, button_tonal(accent, 14))
	btn_ok.pressed.connect(func() -> void:
		animate_out(panel_box, 0.15, func() -> void:
			root.queue_free()
			if on_ok.is_valid():
				on_ok.call()
		)
	)
	vbox.add_child(btn_ok)
	return root


# ─────────────────────────────────────────────────────────────────────────────
# PALETA EXTENDIDA — RAREZA
# ─────────────────────────────────────────────────────────────────────────────

## Colores de rareza de equipo/objetos (para bolsa, tienda y forja).
const RARITY_COLORS: Dictionary = {
	"common":    Color("9aa3b2"),
	"uncommon":  Color("3fb950"),
	"rare":      Color("3b82f6"),
	"epic":      Color("a855f7"),
	"legendary": Color("f5a623"),
}

## Devuelve el color asociado a una rareza (gris tenue si es desconocida).
static func rarity_color(rarity: String) -> Color:
	return RARITY_COLORS.get(rarity, TEXT_DIM)


# ─────────────────────────────────────────────────────────────────────────────
# FÁBRICAS DE STYLEBOX — COMPONENTES DEL NUEVO LENGUAJE VISUAL
# ─────────────────────────────────────────────────────────────────────────────

## Cápsula tintada (pill) con borde del color dado. Ideal para etiquetas/recursos.
static func pill(tint: Color = ACCENT, radius: int = 999) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(tint.r, tint.g, tint.b, 0.14)
	s.border_color = Color(tint.r, tint.g, tint.b, 0.55)
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(8)
	s.content_margin_left = 14
	s.content_margin_right = 14
	return s


## Banner/cabecera: superficie con una franja de acento a la izquierda.
static func banner(accent: Color = ACCENT, radius: int = 16) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = SURFACE_ALT
	s.border_color = Color(accent.r, accent.g, accent.b, 0.85)
	s.border_width_left = 4
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(14)
	return s


## Tarjeta "héroe": superficie elevada con borde de acento y sombra de color.
static func hero_card(accent: Color = ACCENT, radius: int = 18) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = SURFACE_HI
	s.border_color = Color(accent.r, accent.g, accent.b, 0.6)
	s.set_border_width_all(2)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(16)
	s.shadow_color = Color(accent.r, accent.g, accent.b, 0.18)
	s.shadow_size = 12
	return s


## Botón "tonal": relleno suave de un color (acción secundaria con identidad).
static func button_tonal(tint: Color, radius: int = 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(tint.r, tint.g, tint.b, 0.18)
	s.border_color = Color(tint.r, tint.g, tint.b, 0.6)
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(10)
	return s


# ─────────────────────────────────────────────────────────────────────────────
# HELPERS DE NODOS — COMPONENTES COMPUESTOS
# ─────────────────────────────────────────────────────────────────────────────

class CircleAvatar extends PanelContainer:
	var _bg_color: Color
	var _border_color: Color
	var _border_width: float = 2.0

	func _init(symbol: String, diameter: int, tint: Color) -> void:
		custom_minimum_size = Vector2(diameter, diameter)
		_bg_color = Color(tint.r, tint.g, tint.b, 0.16)
		_border_color = Color(tint.r, tint.g, tint.b, 0.7)
		_border_width = 2.0
		mouse_filter = MOUSE_FILTER_IGNORE

		var empty_sb := StyleBoxEmpty.new()
		add_theme_stylebox_override("panel", empty_sb)

		if symbol.begins_with("res://") and ResourceLoader.exists(symbol):
			var tex := load(symbol) as Texture2D
			if tex != null:
				var tr := TextureRect.new()
				tr.texture = tex
				tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				tr.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
				tr.mouse_filter = MOUSE_FILTER_IGNORE
				add_child(tr)
				return

		var lbl := Label.new()
		lbl.text = symbol
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", int(diameter * 0.5))
		lbl.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		lbl.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(lbl)

	func _draw() -> void:
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.5
		draw_circle(center, radius, _bg_color)
		if _border_width > 0.0:
			draw_arc(center, radius - _border_width * 0.5, 0.0, TAU, 64, _border_color, _border_width, true)


## Avatar circular con un emoji/símbolo centrado sobre fondo tintado sin artefactos visuales.
static func avatar(symbol: String, diameter: int = 88, tint: Color = ACCENT) -> PanelContainer:
	return CircleAvatar.new(symbol, diameter, tint)


## Pill compuesta: PanelContainer con icono + valor (recursos del HUD/cabeceras).
static func resource_pill(icon: String, value: String, tint: Color = ACCENT) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", pill(tint))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	p.add_child(hb)
	var ic := Label.new()
	ic.text = icon
	ic.add_theme_font_size_override("font_size", 22)
	hb.add_child(ic)
	var vl := Label.new()
	vl.text = value
	vl.add_theme_font_size_override("font_size", 22)
	vl.add_theme_color_override("font_color", TEXT)
	hb.add_child(vl)
	return p


## Elimina emoticonos/emojis y espacios sobrantes al inicio de textos de opciones.
static func strip_emojis(txt: String) -> String:
	var regex := RegEx.new()
	regex.compile("[\\x{1F300}-\\x{1F9FF}]|[\\x{2600}-\\x{26FF}]|[\\x{2700}-\\x{27BF}]")
	var cleaned := regex.sub(txt, "", true)
	return cleaned.strip_edges()


static var _texture_cache: Dictionary = {}

## Carga una textura de forma segura, compatible tanto con el editor/debug PC
## como con la versión exportada (APK Android / PCK), resolviendo remapeos de recursos.
static func load_texture_safe(path: String) -> Texture2D:
	if path == "" or not path.begins_with("res://"):
		return null
	if _texture_cache.has(path):
		return _texture_cache[path]

	var global_p := ProjectSettings.globalize_path(path)
	var disk_exists := FileAccess.file_exists(global_p) or FileAccess.file_exists(path)
	var res_exists := ResourceLoader.exists(path) or ResourceLoader.exists(path, "Texture2D")
	if not res_exists and not disk_exists:
		_texture_cache[path] = null
		return null

	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Texture2D:
			_texture_cache[path] = res as Texture2D
			return res as Texture2D
	if ResourceLoader.exists(path, "Texture2D"):
		var res_tex = load(path)
		if res_tex is Texture2D:
			_texture_cache[path] = res_tex as Texture2D
			return res_tex as Texture2D

	if disk_exists:
		var img := Image.load_from_file(global_p)
		if img and not img.is_empty():
			var tex := ImageTexture.create_from_image(img)
			_texture_cache[path] = tex
			return tex

	_texture_cache[path] = null
	return null


## Muestra una notificación modal flotante y vistosa cuando sube la Relación o una Faceta,
## y hace volar un distintivo "+1" hacia el botón de Status.
static func show_stat_toast(parent: Control, data: Dictionary, status_btn: Control = null) -> void:
	if not parent or not is_instance_valid(parent):
		return

	var type := String(data.get("type", ""))
	var amount := int(data.get("amount", 1))
	var message := ""
	var toast_color := ACCENT

	if type == "rel":
		if amount >= 0:
			message = Locale.pick({
				"es": "🤝  ¡Tu relación ha subido +%d punto!" % amount,
				"en": "🤝  Relationship increased +%d!" % amount,
				"fr": "🤝  Ta relation a augmenté de +%d !" % amount,
				"it": "🤝  La tua relazione è aumentata di +%d!" % amount,
				"de": "🤝  Deine Beziehung ist um +%d gestiegen!" % amount,
				"zh": "🤝  你的关系度提升了 +%d！" % amount,
				"ja": "🤝  親密度が +%d 上昇した！" % amount,
			})
			toast_color = Color("ff9f43")
		else:
			message = Locale.pick({
				"es": "💔  ¡Tu relación ha bajado -%d punto!" % absi(amount),
				"en": "💔  Relationship decreased -%d!" % absi(amount),
				"fr": "💔  Ta relation a baissé de -%d !" % absi(amount),
				"it": "💔  La tua relazione è diminuita di -%d!" % absi(amount),
				"de": "💔  Deine Beziehung ist um -%d gesunken!" % absi(amount),
				"zh": "💔  你的关系度下降了 -%d！" % absi(amount),
				"ja": "💔  親密度が -%d 下がった！" % absi(amount),
			})
			toast_color = Color("ee5253")
	elif type == "faceta":
		var key := String(data.get("key", "bondad"))
		var key_loc := Locale.t("facet_" + key)
		var icon := "💚"
		match key:
			"valor": icon = "🛡️"
			"bondad", "amabilidad": icon = "💚"
			"aspecto", "encanto": icon = "🎭"
			"inteligencia": icon = "🧠"
			"cordura": icon = "🌀"
		if amount >= 0:
			message = Locale.pick({
				"es": "%s  ¡Has ganado +%d de %s!" % [icon, amount, key_loc],
				"en": "%s  Gained +%d %s!" % [icon, amount, key_loc],
				"fr": "%s  Tu as gagné +%d de %s !" % [icon, amount, key_loc],
				"it": "%s  Hai guadagnato +%d di %s!" % [icon, amount, key_loc],
				"de": "%s  Du hast +%d %s erhalten!" % [icon, amount, key_loc],
				"zh": "%s  你获得了 +%d %s！" % [icon, amount, key_loc],
				"ja": "%s  %s が +%d 上昇した！" % [icon, key_loc, amount],
			})
			toast_color = Color("10ac84")
		else:
			message = Locale.pick({
				"es": "%s  ¡Has perdido -%d de %s!" % [icon, absi(amount), key_loc],
				"en": "%s  Lost -%d %s!" % [icon, absi(amount), key_loc],
				"fr": "%s  Tu as perdu -%d de %s !" % [icon, absi(amount), key_loc],
				"it": "%s  Hai perso -%d di %s!" % [icon, absi(amount), key_loc],
				"de": "%s  Du hast -%d %s verloren!" % [icon, absi(amount), key_loc],
				"zh": "%s  你失去了 -%d %s！" % [icon, absi(amount), key_loc],
				"ja": "%s  %s が -%d 下がった！" % [icon, key_loc, absi(amount)],
			})
			toast_color = Color("ee5253")
	else:
		return

	var toast_node := PanelContainer.new()
	# El borde semántico por tipo (rel=naranja/faceta=verde) se conserva tal cual
	# (igual que HP/MP no cambian de color entre temas), pero el fondo del
	# panel sale del tema activo, como el resto de modales del juego.
	premium_dialog_panel(toast_node, toast_color, 24)
	toast_node.pivot_offset = Vector2(260, 45)

	var margin := margins(32, 32, 18, 18)
	toast_node.add_child(margin)

	var lbl := Label.new()
	lbl.text = message
	lbl.add_theme_font_size_override("font_size", 30)
	lbl.add_theme_color_override("font_color", theme_color("text", TEXT))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	margin.add_child(lbl)

	parent.add_child(toast_node)
	toast_node.anchor_left = 0.5
	toast_node.anchor_right = 0.5
	toast_node.anchor_top = 0.18
	toast_node.anchor_bottom = 0.18
	toast_node.offset_left = -260
	toast_node.offset_right = 260
	toast_node.offset_top = 0
	toast_node.offset_bottom = 90
	toast_node.grow_horizontal = Control.GROW_DIRECTION_BOTH

	# Animación de aparición (Pop con muelle TRANS_BACK)
	toast_node.scale = Vector2(0.2, 0.2)
	toast_node.modulate.a = 0.0

	var tw := parent.create_tween()
	tw.set_parallel(true)
	tw.tween_property(toast_node, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(toast_node, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)

	# Tras 1.0 segundo, hace volar la partícula "+1" al botón de Status
	var tw_fly := parent.create_tween()
	tw_fly.tween_interval(1.0)
	tw_fly.tween_callback(func() -> void:
		if not is_instance_valid(toast_node):
			return

		# Crear insignia "±1" flotante (signo correcto: +N si sube, -N si baja).
		var badge := Label.new()
		badge.text = ("+%d" % amount) if amount >= 0 else ("%d" % amount)
		badge.add_theme_font_size_override("font_size", 44)
		badge.add_theme_color_override("font_color", toast_color)
		parent.add_child(badge)

		var start_pos := toast_node.global_position + Vector2(260, 45)
		badge.global_position = start_pos

		var dest_pos := Vector2.ZERO
		if status_btn and is_instance_valid(status_btn):
			dest_pos = status_btn.global_position + status_btn.size * 0.5
		else:
			var vp_sz := parent.get_viewport_rect().size
			dest_pos = Vector2(vp_sz.x - 140.0, 50.0)

		# Desvanecer el panel principal
		var tw_fade := parent.create_tween()
		tw_fade.tween_property(toast_node, "modulate:a", 0.0, 0.35)
		tw_fade.tween_callback(toast_node.queue_free)

		# Volar la partícula "+1" hasta la posición del botón de Facetas y Relación (esquina superior derecha)
		var tw_particle := parent.create_tween()
		tw_particle.set_parallel(true)
		tw_particle.tween_property(badge, "global_position", dest_pos, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw_particle.tween_property(badge, "scale", Vector2(1.4, 1.4), 0.3).set_ease(Tween.EASE_OUT)
		tw_particle.chain().tween_property(badge, "scale", Vector2(0.6, 0.6), 0.3).set_ease(Tween.EASE_IN)
		tw_particle.tween_property(badge, "modulate:a", 0.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

		tw_particle.chain().tween_callback(func() -> void:
			badge.queue_free()
			if status_btn and is_instance_valid(status_btn):
				var pulse := parent.create_tween()
				pulse.tween_property(status_btn, "scale", Vector2(1.2, 1.2), 0.15).set_ease(Tween.EASE_OUT)
				pulse.tween_property(status_btn, "scale", Vector2.ONE, 0.2).set_ease(Tween.EASE_IN)
		)
	)


# ─────────────────────────────────────────────────────────────────────────────
# TRANSICIONES DE UI (fades suaves y escalas para modales y paneles)
# ─────────────────────────────────────────────────────────────────────────────
## Realiza un fade-in y escala sutil de un Control respetando reduce_motion.
static func animate_in(node: Control, duration: float = 0.20) -> Tween:
	if node == null or not is_instance_valid(node):
		return null
	if Locale.reduce_motion:
		node.modulate = Color.WHITE
		node.scale = Vector2.ONE
		return null
	node.modulate = Color.TRANSPARENT
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2(0.95, 0.95)
	var tw := node.create_tween().set_parallel(true)
	tw.tween_property(node, "modulate", Color.WHITE, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return tw


## Realiza un fade-out y escala sutil, y ejecuta un callback al terminar.
static func animate_out(node: Control, duration: float = 0.15, on_finished: Callable = Callable()) -> Tween:
	if node == null or not is_instance_valid(node):
		if on_finished.is_valid():
			on_finished.call()
		return null
	if Locale.reduce_motion:
		if on_finished.is_valid():
			on_finished.call()
		return null
	node.pivot_offset = node.size * 0.5
	var tw := node.create_tween().set_parallel(true)
	tw.tween_property(node, "modulate", Color.TRANSPARENT, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(node, "scale", Vector2(0.95, 0.95), duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if on_finished.is_valid():
		tw.chain().tween_callback(on_finished)
	return tw


## Muestra una notificación flotante de recolección (madera, piedra, peces, plantas)
static func show_harvest_toast(parent: Node, icon_name: String, amount: int = 1) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var badge := Label.new()
	badge.text = "%s +%d" % [icon_name, amount]
	badge.add_theme_font_size_override("font_size", 22)
	badge.add_theme_color_override("font_color", ACCENT_SOFT)
	badge.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	badge.add_theme_constant_override("outline_size", 8)

	var vp_sz := (parent as Control).get_viewport_rect().size if (parent != null and parent is Control) else Vector2(800, 600)
	badge.position = Vector2(vp_sz.x * 0.5 - 60.0, vp_sz.y * 0.6)
	parent.add_child(badge)

	badge.scale = Vector2(0.7, 0.7)
	badge.modulate.a = 0.0

	var tw := parent.create_tween().set_parallel(true)
	tw.tween_property(badge, "modulate:a", 1.0, 0.15)
	tw.tween_property(badge, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(badge, "position:y", badge.position.y - 45.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(badge, "modulate:a", 0.0, 0.25)
	tw.chain().tween_callback(badge.queue_free)


## Modal de celebración que se muestra cuando el jugador desbloquea una nueva profesión.
static func show_profession_unlocked_modal(parent: Node, prof_key: String, on_closed: Callable = Callable()) -> CanvasLayer:
	if parent == null or not is_instance_valid(parent):
		return null

	var def: Dictionary = Design.get_profession(prof_key) if Design != null else {}
	var prof_name: String = Locale.pick(def.get("name", {})) if not def.is_empty() else prof_key
	var prof_icon: String = String(def.get("icon", "⚔️")) if not def.is_empty() else "⚔️"
	var color_hex: String = String(def.get("color", "f59e0b"))
	var prof_color := Color(color_hex)

	var canvas := CanvasLayer.new()
	canvas.layer = 106
	parent.add_child(canvas)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(root)

	# Fondo oscuro místico
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.03, 0.07, 0.85)
	root.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var panel_box := PanelContainer.new()
	panel_box.custom_minimum_size = Vector2(680, 0)
	premium_frame(panel_box, {
		"bg_color": Color(0.06, 0.08, 0.14, 0.98),
		"border_color": prof_color,
		"corner_radius": 24.0,
		"border_width": 3.0,
		"pad": 0
	})
	center.add_child(panel_box)
	animate_in(panel_box, 0.28)

	var margin := margins(44, 44, 36, 36)
	panel_box.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)

	# Icono gigante en caja avatar con halo brillante
	var icon_box := avatar(prof_icon, 110, prof_color)
	icon_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(icon_box)
	pop(icon_box, 1.25, 0.3)

	var title_lbl := Label.new()
	title_lbl.text = "🎉  " + Locale.pick({
		"es": "¡NUEVA PROFESIÓN DESBLOQUEADA!",
		"en": "NEW PROFESSION UNLOCKED!",
		"fr": "NOUVELLE PROFESSION DÉBLOQUÉE !",
		"it": "NUOVA PROFESSIONE SBLOCCATA!",
		"de": "NEUER BERUF FREIGESCHALTET!",
		"zh": "全新职业已解锁！",
		"ja": "新たな職業が解放された！"
	})
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 30)
	title_lbl.add_theme_color_override("font_color", COLOR_GOLD_PRIMARY)
	apply_heading(title_lbl)
	vbox.add_child(title_lbl)

	var name_lbl := Label.new()
	name_lbl.text = "%s  %s" % [prof_icon, prof_name.to_upper()]
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 42)
	name_lbl.add_theme_color_override("font_color", prof_color)
	apply_heading(name_lbl)
	vbox.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = Locale.pick({
		"es": "¡Enhorabuena! Has superado la prueba y aprendido las disciplinas de esta clase. Ahora puedes seleccionarla en combate o cambiar a ella en cualquier momento desde el menú de Profesiones.",
		"en": "Congratulations! You have passed the trial and mastered this discipline. You can now select it in battle or switch to it at any time from the Professions menu.",
		"fr": "Félicitations ! Tu as réussi l'épreuve et maîtrisé cette discipline. Tu peux désormais l'utiliser en combat ou la changer à tout moment depuis le menu Professions.",
		"it": "Congratulazioni! Hai superato la prova e appreso questa disciplina. Ora puoi selezionarla in combattimento o cambiarla in qualsiasi momento dal menu Professioni.",
		"de": "Herzlichen Glückwunsch! Du hast die Prüfung bestanden und diese Disziplin gemeistert. Du kannst sie jetzt im Kampf wählen oder jederzeit im Berufe-Menü wechseln.",
		"zh": "恭喜！你已通过试炼并掌握了该领域的本领。现在你可以在战斗中使用它，或随时在‘职业’菜单中切换。",
		"ja": "おめでとう！試練を突破し、この道を体得した。今後は戦闘で活用したり、「職業」メニューからいつでも転職できるぞ。"
	})
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 24)
	desc_lbl.add_theme_color_override("font_color", TEXT)
	vbox.add_child(desc_lbl)

	var btn_ok := Button.new()
	btn_ok.text = "✨  " + Locale.pick({"es": "¡A por todas!", "en": "Let's go!", "fr": "En avant !", "it": "Andiamo!", "de": "Los geht's!", "zh": "出发！", "ja": "よし、行こう！"})
	btn_ok.custom_minimum_size = Vector2(260, 64)
	btn_ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_ok.add_theme_font_size_override("font_size", 26)
	btn_ok.add_theme_stylebox_override("normal", button_primary(14))
	btn_ok.add_theme_stylebox_override("hover", button_primary(14))
	btn_ok.add_theme_stylebox_override("pressed", button_primary(14))
	btn_ok.add_theme_stylebox_override("focus", button_primary(14))
	btn_ok.add_theme_color_override("font_color", BG_DEEP)
	btn_ok.add_theme_color_override("font_hover_color", BG_DEEP)
	btn_ok.add_theme_color_override("font_pressed_color", BG_DEEP)
	vbox.add_child(btn_ok)

	AudioManager.play_ui("reward")
	AudioManager.play_sfx("level_up")

	btn_ok.pressed.connect(func() -> void:
		animate_out(panel_box, 0.18, func() -> void:
			if is_instance_valid(canvas):
				canvas.queue_free()
			if on_closed.is_valid():
				on_closed.call()
		)
	)

	return canvas
