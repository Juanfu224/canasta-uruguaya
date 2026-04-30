## Vista del mazo de robo (pila de cartas dorso).
##
## Muestra una columna 3D simulada (varias cartas dorso apiladas con un
## leve offset) y el contador. Tap en el mazo emite `draw_requested` (la
## acción real "robar 2 cartas" la valida F5/RpcRouter).
##
## Visual:
##   - Glow dorado opcional cuando es la fase de robo (`set_glow(true)`).
##   - Squish on tap (squish 0.95 → 1.05 → 1.0 con elastic).
##   - Etiqueta "Mazo" debajo del stack.
class_name DeckView
extends Control

signal draw_requested

const _CARD_SCENE: PackedScene = preload("res://ui/card_ui.tscn")

## Cuántas cartas dorso renderizar como decoración (estética). Independiente
## del conteo lógico del mazo.
@export_range(1, 8, 1) var visible_stack_depth: int = 4

## Offset entre cartas apiladas, en px.
@export var stack_offset: Vector2 = Vector2(2.0, -2.0)

@onready var _stack: Control = $Stack
@onready var _count_label: Label = $CountLabel
@onready var _label: Label = $DeckLabel
@onready var _glow: Panel = $Glow
@onready var _hit: Button = $HitArea

var _count: int = 0
var _glow_style: StyleBoxFlat = null
var _tap_tween: Tween = null


func _ready() -> void:
	_apply_skin()
	_build_stack()
	_hit.pressed.connect(_on_pressed)
	pivot_offset = size * 0.5
	resized.connect(func() -> void: pivot_offset = size * 0.5)


func _apply_skin() -> void:
	# Glow dorado (oculto por defecto).
	_glow_style = Tokens.panel_style(
		Color(Tokens.TRIM_GOLD.r, Tokens.TRIM_GOLD.g, Tokens.TRIM_GOLD.b, 0.10),
		Tokens.TRIM_GOLD,
		Tokens.BORDER_THICK,
		Tokens.R_LG,
		false,
	)
	_glow_style.shadow_color = Color(Tokens.TRIM_GOLD.r, Tokens.TRIM_GOLD.g, Tokens.TRIM_GOLD.b, 0.55)
	_glow_style.shadow_size = 14
	_glow.add_theme_stylebox_override("panel", _glow_style)
	_glow.visible = false

	_count_label.add_theme_font_override("font", Tokens.font_mono())
	_count_label.add_theme_font_size_override("font_size", Tokens.T_SM)
	_count_label.add_theme_color_override("font_color", Tokens.PAPER)

	_label.add_theme_font_override("font", Tokens.font_display())
	_label.add_theme_font_size_override("font_size", Tokens.T_SM)
	_label.add_theme_color_override("font_color", Tokens.TRIM_GOLD)


func set_count(n: int) -> void:
	_count = maxi(0, n)
	_count_label.text = "%d" % _count


## Activa/desactiva el halo dorado (p.ej. en fase de robo).
func set_glow(on: bool) -> void:
	_glow.visible = on


## Posición global del centro del stack (para CardFlight).
func get_draw_origin_global() -> Vector2:
	return _stack.get_global_rect().get_center()


func _build_stack() -> void:
	for child in _stack.get_children():
		child.queue_free()
	for i in visible_stack_depth:
		var c: CardUI = _CARD_SCENE.instantiate() as CardUI
		_stack.add_child(c)
		c.bind(null, false)  # dorso
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.position = stack_offset * float(i)


func _on_pressed() -> void:
	# Squish al pulsar, luego notificar.
	if _tap_tween != null and _tap_tween.is_valid():
		_tap_tween.kill()
	_tap_tween = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_tap_tween.tween_property(self, "scale", Vector2(0.95, 0.95), Tokens.DUR_FAST)
	_tap_tween.tween_property(self, "scale", Vector2.ONE, Tokens.DUR_POP)
	draw_requested.emit()
