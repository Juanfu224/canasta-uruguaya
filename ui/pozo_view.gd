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
var _border_style: StyleBoxFlat = null


func _ready() -> void:
	_drop.accept_kind = "discard"
	_drop.card_dropped.connect(_on_card_dropped)
	# Duplicamos el StyleBox para no mutar el SubResource compartido entre
	# instancias (cada PozoView tiene su propio borde).
	var src: StyleBox = _status_border.get_theme_stylebox("panel")
	_border_style = (src.duplicate() if src is StyleBoxFlat else StyleBoxFlat.new()) as StyleBoxFlat
	_status_border.add_theme_stylebox_override("panel", _border_style)
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
	if _border_style == null:
		return
	var col: Color
	match status:
		PozoStatus.TAPONADO:
			col = Tokens.STATE_DANGER
		PozoStatus.CRUZADO:
			col = Tokens.TRIM_GOLD
		_:
			col = Tokens.TRIM_GOLD_DIM
	_border_style.border_color = col
	_status_border.queue_redraw()


func _on_card_dropped(card_id: int, source_path: NodePath, _kind: String) -> void:
	discard_requested.emit(card_id, source_path)
