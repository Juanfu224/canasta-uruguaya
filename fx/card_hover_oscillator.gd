## Oscilador de hover/inclinación tipo Balatro para `CardUI`.
##
## Se adjunta como hijo de un `CardUI` (Control) y gestiona:
##   - Inclinación (rotation) según velocidad del puntero usando un
##     muelle amortiguado.
##   - Paralaje del nodo `Face` siguiendo la posición local del puntero.
##   - Escalado en hover/idle con tween.
##
## Es presentacional: NO altera `position` (eso lo gestiona HandLayout) ni
## emite señales lógicas. Si el usuario reduce-motion está activo en
## ProfileStore, el padre puede simplemente no agregar este nodo.
class_name CardHoverOscillator
extends Node

@export_range(10.0, 600.0) var spring: float = 150.0
@export_range(0.5, 30.0) var damp: float = 10.0
@export_range(0.0001, 0.05) var velocity_to_rotation: float = 0.005
@export_range(0.05, 0.6) var max_displacement: float = 0.21  # ≈ 12°
@export_range(0.0, 24.0) var tilt_pixels: float = 6.0
@export_range(1.0, 1.5) var hover_scale: float = 1.08
@export_range(0.04, 0.4) var scale_tween_time: float = 0.12

var _card_ui: Control = null
var _face: Control = null
var _initial_face_position: Vector2 = Vector2.ZERO

var _displacement: float = 0.0    # rotación actual (rad)
var _velocity: float = 0.0        # velocidad angular (rad/s)
var _mouse_velocity_x: float = 0.0
var _is_hover: bool = false
var _scale_tween: Tween = null


func _ready() -> void:
	var parent: Node = get_parent()
	_card_ui = parent as Control
	if _card_ui == null:
		push_error("CardHoverOscillator: el padre debe ser un Control (CardUI).")
		set_process(false)
		return

	if _card_ui.has_node(^"Face"):
		_face = _card_ui.get_node(^"Face") as Control
		if _face != null:
			_initial_face_position = _face.position

	_card_ui.gui_input.connect(_on_parent_gui_input)
	_card_ui.mouse_entered.connect(_on_mouse_entered)
	_card_ui.mouse_exited.connect(_on_mouse_exited)
	# Optimización: el _process se desactiva cuando el sistema reposa.
	set_process(false)


func _on_parent_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_velocity_x = (event as InputEventMouseMotion).relative.x
		set_process(true)
	elif event is InputEventScreenDrag:
		_mouse_velocity_x = (event as InputEventScreenDrag).relative.x
		set_process(true)


func _on_mouse_entered() -> void:
	_is_hover = true
	_tween_scale(hover_scale)
	set_process(true)


func _on_mouse_exited() -> void:
	_is_hover = false
	_mouse_velocity_x = 0.0
	_tween_scale(1.0)
	# El _process seguirá activo hasta asentar el muelle.
	set_process(true)


func _process(delta: float) -> void:
	if _card_ui == null:
		return

	# Spring–damper: F = -k*x - c*v, con impulso del cursor.
	var target_offset: float = clampf(_mouse_velocity_x * velocity_to_rotation, -max_displacement, max_displacement)
	var force: float = -spring * (_displacement - target_offset) - damp * _velocity
	_velocity += force * delta
	_displacement += _velocity * delta
	_card_ui.rotation = _displacement

	# Paralaje 2D del Face: sigue al puntero en coordenadas locales.
	if _face != null and _is_hover:
		var local_pos: Vector2 = _card_ui.get_local_mouse_position() - _card_ui.size * 0.5
		var norm_x: float = clampf(local_pos.x / max(1.0, _card_ui.size.x * 0.5), -1.0, 1.0)
		var norm_y: float = clampf(local_pos.y / max(1.0, _card_ui.size.y * 0.5), -1.0, 1.0)
		_face.position = _initial_face_position + Vector2(-norm_x, -norm_y) * tilt_pixels * 2.0
	elif _face != null:
		_face.position = _face.position.lerp(_initial_face_position, clampf(delta * 8.0, 0.0, 1.0))

	# Decaimiento del impulso de cursor para que la rotación regrese al centro.
	_mouse_velocity_x = lerpf(_mouse_velocity_x, 0.0, clampf(delta * 12.0, 0.0, 1.0))

	# Apagado cuando el sistema reposa.
	if not _is_hover and absf(_displacement) < 0.001 and absf(_velocity) < 0.001 and absf(_mouse_velocity_x) < 0.05:
		_card_ui.rotation = 0.0
		_displacement = 0.0
		_velocity = 0.0
		set_process(false)


func _tween_scale(target: float) -> void:
	if _card_ui == null:
		return
	if _scale_tween != null and _scale_tween.is_valid():
		_scale_tween.kill()
	_scale_tween = _card_ui.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_scale_tween.tween_property(_card_ui, "scale", Vector2(target, target), scale_tween_time)
