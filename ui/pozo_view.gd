## Vista del pozo (pila de descartes).
##
## Muestra la carta superior y el conteo total. Acepta drops desde la mano
## (descartar carta) reutilizando `DropZone` en composición.
##
## Estados visuales:
##   - Normal: borde neutro.
##   - Taponado (un Tres Negro descartado): borde rojo.
##   - Cruzado (un comodín descartado): borde dorado.
##
## En F3 los estados se exponen como API; F5 los conectará al `PozoController`
## autoritativo del host.
class_name PozoView
extends Control

enum PozoStatus { NORMAL, TAPONADO, CRUZADO }

signal discard_requested(card_id: int, source_path: NodePath)

const _CARD_SCENE: PackedScene = preload("res://ui/card_ui.tscn")

@onready var _drop: DropZone = $DropZone
@onready var _top_slot: Control = $TopCard
@onready var _count_label: Label = $CountLabel
@onready var _status_border: Panel = $StatusBorder

var _top_card_node: CardUI = null
var _count: int = 0


func _ready() -> void:
	_drop.accept_kind = "discard"
	_drop.card_dropped.connect(_on_card_dropped)
	set_status(PozoStatus.NORMAL)


## Reemplaza la carta superior visible. Pasa null para vaciar.
func set_top_card(card: Card) -> void:
	if _top_card_node != null:
		_top_card_node.queue_free()
		_top_card_node = null
	if card == null:
		return
	_top_card_node = _CARD_SCENE.instantiate() as CardUI
	_top_slot.add_child(_top_card_node)
	_top_card_node.bind(card, true)
	_top_card_node.position = Vector2.ZERO
	# La carta del pozo no se arrastra desde el pozo (la captura es una
	# acción explícita del jugador, no drag&drop). Bloqueamos input.
	_top_card_node.mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_count(n: int) -> void:
	_count = maxi(0, n)
	_count_label.text = "%d" % _count


func set_status(status: int) -> void:
	var col: Color
	match status:
		PozoStatus.TAPONADO:
			col = Color(0.85, 0.20, 0.20, 0.85)
		PozoStatus.CRUZADO:
			col = Color(0.92, 0.78, 0.20, 0.85)
		_:
			col = Color(0.40, 0.40, 0.45, 0.50)
	(_status_border.get_theme_stylebox("panel") as StyleBoxFlat).border_color = col
	_status_border.queue_redraw()


func _on_card_dropped(card_id: int, source_path: NodePath, _kind: String) -> void:
	discard_requested.emit(card_id, source_path)
