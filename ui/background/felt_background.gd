## Fondo de mesa de fieltro. Pensado para ser hijo de un `CanvasLayer` con
## `layer = Tokens.Z_FELT`, ocupando todo el viewport (anchors full).
##
## Composición (de fondo a frente):
##   1. ColorRect base con shader de vignette radial (gradiente fieltro).
##   2. Marco interno (Panel) con esquinas redondeadas y borde dorado tenue.
##
## Sin parallax animado ni partículas: presupuesto perf móvil.
class_name FeltBackground
extends Control

const _SHADER: Shader = preload("res://shaders/felt_vignette.gdshader")

@onready var _vignette: ColorRect = $Vignette
@onready var _frame: Panel = $Frame


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Material vignette compartido por instancia (no globalmente, para evitar
	# leaks de estado entre escenas).
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = _SHADER
	mat.set_shader_parameter("inner_color", Tokens.FELT_MID)
	mat.set_shader_parameter("outer_color", Tokens.FELT_DEEP.darkened(0.25))
	mat.set_shader_parameter("strength", 0.95)
	mat.set_shader_parameter("falloff", 1.6)
	_vignette.material = mat

	# Marco con borde dorado tenue.
	var frame_style: StyleBoxFlat = Tokens.panel_style(
		Color(0, 0, 0, 0),  # transparente, sólo borde
		Tokens.TRIM_GOLD_DIM,
		Tokens.BORDER_THICK,
		Tokens.R_XL,
		false,
	)
	_frame.add_theme_stylebox_override("panel", frame_style)
