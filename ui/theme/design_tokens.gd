## Tokens de diseño centralizados para Canasta Uruguaya.
##
## Filosofía: una sola fuente de verdad para colores, radios, tipografía,
## sombras, duraciones y z-index. Cualquier hardcode visual fuera de este
## archivo es un bug y debe migrarse aquí.
##
## Uso:
##     `Tokens.FELT_DEEP`, `Tokens.font_display(Tokens.T_LG)`, etc.
##
## NO es autoload (no necesita estado): clase `RefCounted` con sólo `const`
## y métodos estáticos. Se importa por `class_name`.
class_name Tokens
extends RefCounted

# ---------------------------------------------------------------------------
# Paleta — fieltro y carpintería
# ---------------------------------------------------------------------------

const FELT_DEEP: Color = Color(0.055, 0.165, 0.133, 1.0)     # #0E2A22
const FELT_MID: Color = Color(0.075, 0.251, 0.184, 1.0)      # #13402F
const FELT_HI: Color = Color(0.102, 0.325, 0.251, 1.0)       # #1A5340
const TRIM_GOLD: Color = Color(0.851, 0.643, 0.255, 1.0)     # #D9A441
const TRIM_GOLD_DIM: Color = Color(0.478, 0.353, 0.141, 1.0) # #7A5A24

# Tinta (textos, sombras profundas)
const INK: Color = Color(0.043, 0.059, 0.055, 1.0)           # #0B0F0E
const INK_SOFT: Color = Color(0.106, 0.141, 0.129, 1.0)      # #1B2421

# Papel (cara de la carta — cálido, no blanco puro)
const PAPER: Color = Color(0.957, 0.914, 0.812, 1.0)         # #F4E9CF
const PAPER_DIM: Color = Color(0.851, 0.804, 0.690, 1.0)     # #D9CDB0

# Palos
const RED_SUIT: Color = Color(0.784, 0.196, 0.227, 1.0)      # #C8323A
const BLACK_SUIT: Color = Color(0.063, 0.094, 0.110, 1.0)    # #10181C
const JOKER_PURPLE: Color = Color(0.478, 0.294, 0.851, 1.0)  # #7A4BD9
const WILD_TWO_TEAL: Color = Color(0.165, 0.616, 0.561, 1.0) # #2A9D8F
const RED_THREE_GLOW: Color = Color(0.914, 0.294, 0.294, 1.0) # #E94B4B

# Equipos
const TEAM_RED: Color = Color(0.698, 0.227, 0.282, 1.0)      # #B23A48
const TEAM_BLUE: Color = Color(0.227, 0.435, 0.698, 1.0)     # #3A6FB2

# Estados (semaforización)
const STATE_OK: Color = Color(0.247, 0.690, 0.443, 1.0)      # #3FB071
const STATE_WARN: Color = Color(0.886, 0.659, 0.231, 1.0)    # #E2A93B
const STATE_DANGER: Color = Color(0.820, 0.294, 0.294, 1.0)  # #D14B4B

# ---------------------------------------------------------------------------
# Radios y bordes
# ---------------------------------------------------------------------------

const R_SM: int = 8
const R_MD: int = 14
const R_LG: int = 22
const R_XL: int = 28

const BORDER_THIN: int = 1
const BORDER_MD: int = 2
const BORDER_THICK: int = 4

# ---------------------------------------------------------------------------
# Tipografía
# ---------------------------------------------------------------------------

const T_XS: int = 12
const T_SM: int = 14
const T_MD: int = 18
const T_LG: int = 24
const T_XL: int = 32
const T_DISPLAY: int = 44

# ---------------------------------------------------------------------------
# Espaciado base (múltiplos de 4)
# ---------------------------------------------------------------------------

const SP_XS: int = 4
const SP_SM: int = 8
const SP_MD: int = 12
const SP_LG: int = 18
const SP_XL: int = 24
const SP_XXL: int = 36

# ---------------------------------------------------------------------------
# Duraciones y curvas (segundos)
# ---------------------------------------------------------------------------

const DUR_FAST: float = 0.12
const DUR_SETTLE: float = 0.22
const DUR_POP: float = 0.32
const DUR_FLASH: float = 0.45

const BREATH_FREQ: float = 1.4

# ---------------------------------------------------------------------------
# Z-index (orden visual)
# ---------------------------------------------------------------------------

const Z_FELT: int = 0
const Z_MELDS: int = 10
const Z_HANDS: int = 20
const Z_DRAG: int = 900
const Z_HUD: int = 1000
const Z_POPUP: int = 2000

# ---------------------------------------------------------------------------
# Helpers de tipografía (SystemFont)
# ---------------------------------------------------------------------------

## Devuelve un SystemFont para UI (sans). Cae a fuentes del SO en orden.
## Cuando se incluyan fuentes en `assets/fonts/Inter-Regular.ttf`, este
## método se actualizará para preferirlas; por ahora la pila SystemFont
## garantiza una experiencia consistente sin dependencias binarias.
static func font_ui() -> SystemFont:
	var f: SystemFont = SystemFont.new()
	f.font_names = PackedStringArray(["Inter", "Helvetica Neue", "Arial", "Liberation Sans", "DejaVu Sans"])
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	return f


## SystemFont para títulos / display (serif).
static func font_display() -> SystemFont:
	var f: SystemFont = SystemFont.new()
	f.font_names = PackedStringArray(["Spectral", "Cardo", "Georgia", "Liberation Serif", "DejaVu Serif", "serif"])
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	return f


## SystemFont monoespaciada para contadores (alineación de dígitos).
static func font_mono() -> SystemFont:
	var f: SystemFont = SystemFont.new()
	f.font_names = PackedStringArray(["JetBrains Mono", "Fira Mono", "Liberation Mono", "DejaVu Sans Mono", "monospace"])
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	return f


# ---------------------------------------------------------------------------
# Helpers de StyleBox
# ---------------------------------------------------------------------------

## StyleBoxFlat genérico para paneles/HUD.
static func panel_style(
	bg: Color,
	border: Color = TRIM_GOLD_DIM,
	border_w: int = BORDER_MD,
	radius: int = R_MD,
	shadow: bool = true,
) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	if shadow:
		s.shadow_color = Color(0, 0, 0, 0.45)
		s.shadow_size = 6
		s.shadow_offset = Vector2(0, 2)
	return s


## StyleBoxFlat para botones (estado normal).
static func button_style(
	bg: Color = FELT_HI,
	border: Color = TRIM_GOLD,
	radius: int = R_MD,
) -> StyleBoxFlat:
	return panel_style(bg, border, BORDER_MD, radius, true)


## Hover: más claro y borde más vivo.
static func button_style_hover() -> StyleBoxFlat:
	var s: StyleBoxFlat = button_style(FELT_HI.lightened(0.12), TRIM_GOLD, R_MD)
	s.shadow_size = 8
	return s


## Pressed: hundido, sin sombra.
static func button_style_pressed() -> StyleBoxFlat:
	var s: StyleBoxFlat = panel_style(FELT_MID.darkened(0.15), TRIM_GOLD_DIM, BORDER_MD, R_MD, false)
	return s


## Disabled.
static func button_style_disabled() -> StyleBoxFlat:
	var s: StyleBoxFlat = panel_style(FELT_MID.darkened(0.30), TRIM_GOLD_DIM.darkened(0.4), BORDER_MD, R_MD, false)
	return s
