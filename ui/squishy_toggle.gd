## CheckButton con animación squishy (port simplificado de Balatro
## `squishy_toggle.gd`).
##
## Diferencias con el original:
##   - SIN texturas custom de cursor (irrelevantes en móvil; el sistema
##     gestiona el indicador táctil).
##   - El "knob" se anima por scale + position usando dos tweens paralelos.
##   - El color de fondo cambia entre `off_color` y `on_color`.
##
## Pensado para usarse desde código (`button_pressed = ...`) o desde el
## inspector vía `toggled` signal.
class_name SquishyToggle
extends Control

signal toggled_state(state: bool)

const _DURATION: float = 0.25

@export var on_color: Color = Color(0.30, 0.75, 0.40, 1.0)
@export var off_color: Color = Color(0.35, 0.35, 0.40, 1.0)
@export var initial_state: bool = false

@onready var _bg: Panel = $Bg
@onready var _knob: Panel = $Bg/Knob
@onready var _label_off: Label = $Bg/LabelOff
@onready var _label_on: Label = $Bg/LabelOn

var _state: bool = false
var _t_pos: Tween = null
var _t_squish: Tween = null
var _t_color: Tween = null
var _knob_off_x: float = 0.0
var _knob_on_x: float = 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(160, 56)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_compute_positions()
	_state = initial_state
	_apply_state_immediate(_state)
	gui_input.connect(_on_gui_input)


func _compute_positions() -> void:
	var pad: float = 6.0
	_knob_off_x = pad
	_knob_on_x = _bg.size.x - _knob.size.x - pad


func is_on() -> bool:
	return _state


func set_on(value: bool, animate: bool = true) -> void:
	if value == _state:
		return
	_state = value
	if animate:
		_animate_to(value)
	else:
		_apply_state_immediate(value)
	toggled_state.emit(value)


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

func _on_gui_input(event: InputEvent) -> void:
	var pressed: bool = false
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		pressed = mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		pressed = not st.pressed
	if pressed:
		set_on(not _state, true)
		accept_event()


# ---------------------------------------------------------------------------
# Animación
# ---------------------------------------------------------------------------

func _animate_to(value: bool) -> void:
	_compute_positions()
	_kill_tweens()
	var target_x: float = _knob_on_x if value else _knob_off_x
	var target_color: Color = on_color if value else off_color

	_t_pos = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_t_pos.tween_property(_knob, "position:x", target_x, _DURATION)

	# Squish: scale Y abajo y X arriba (panqueque), luego elasticidad.
	_t_squish = create_tween().set_parallel(false)
	_t_squish.tween_property(_knob, "scale", Vector2(1.4, 0.7), _DURATION * 0.5) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_t_squish.tween_property(_knob, "scale", Vector2(1.0, 1.0), _DURATION * 1.4) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	_t_color = create_tween().set_trans(Tween.TRANS_CUBIC)
	_t_color.tween_property(_bg, "self_modulate", target_color, _DURATION)

	# Fade label opuesto.
	_label_off.modulate.a = 0.0 if value else 1.0
	_label_on.modulate.a = 1.0 if value else 0.0


func _apply_state_immediate(value: bool) -> void:
	_compute_positions()
	_knob.position.x = _knob_on_x if value else _knob_off_x
	_knob.scale = Vector2.ONE
	_bg.self_modulate = on_color if value else off_color
	_label_off.modulate.a = 0.0 if value else 1.0
	_label_on.modulate.a = 1.0 if value else 0.0


func _kill_tweens() -> void:
	for t: Tween in [_t_pos, _t_squish, _t_color]:
		if t != null and t.is_valid() and t.is_running():
			t.kill()
