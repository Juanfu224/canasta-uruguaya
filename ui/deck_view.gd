## Vista del mazo de robo (pila de cartas dorso).
##
## Muestra una columna 3D simulada (varias cartas dorso apiladas con un
## leve offset) y el contador. Tap en el mazo emite `draw_requested` (la
## acción real "robar 2 cartas" la valida F5/RpcRouter).
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
@onready var _hit: Button = $HitArea

var _count: int = 0


func _ready() -> void:
	_build_stack()
	_hit.pressed.connect(_on_pressed)


func set_count(n: int) -> void:
	_count = maxi(0, n)
	_count_label.text = "%d" % _count


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
	draw_requested.emit()
