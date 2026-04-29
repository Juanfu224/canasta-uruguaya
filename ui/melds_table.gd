## Mesa de combinaciones (melds) de un equipo.
##
## Renderiza cada meld como una fila horizontal de `CardUI` superpuestas.
## Acepta drops para "agregar a un meld existente" o "crear nuevo meld"
## (cuando se suelta sobre el slot vacío al final).
##
## Esta capa es solo presentación. El propietario (Match.gd / RpcRouter)
## es quien decide si un drop equivale a `request_meld_extend(meld_idx)` o
## `request_meld_create()`, validando contra `RulesEngine`.
class_name MeldsTable
extends Control

signal extend_meld_requested(meld_index: int, card_id: int, source_path: NodePath)
signal create_meld_requested(card_id: int, source_path: NodePath)

const _CARD_SCENE: PackedScene = preload("res://ui/card_ui.tscn")
const _DROP_SCENE: PackedScene = preload("res://ui/drop_zone.tscn")

const _MELD_KIND_EXTEND: String = "meld_extend"
const _MELD_KIND_CREATE: String = "meld_create"
const _CARD_OVERLAP: float = 32.0  # px entre cartas dentro de un meld
const _MELD_GAP: float = 18.0     # px entre melds

@onready var _list: HBoxContainer = $Scroll/Row
@onready var _new_meld_zone: DropZone = $NewMeldZone


func _ready() -> void:
	_new_meld_zone.accept_kind = _MELD_KIND_CREATE
	_new_meld_zone.card_dropped.connect(_on_new_meld_dropped)


## Reemplaza completamente la lista de melds visibles. Idempotente.
func render_melds(melds: Array[Meld]) -> void:
	for child in _list.get_children():
		child.queue_free()
	for i in melds.size():
		_list.add_child(_build_meld_row(melds[i], i))


# ---------------------------------------------------------------------------
# Construcción de filas
# ---------------------------------------------------------------------------

func _build_meld_row(meld: Meld, index: int) -> Control:
	var row := Control.new()
	row.custom_minimum_size = Vector2(_meld_visual_width(meld), CardUI.CARD_SIZE.y + 8.0)
	row.mouse_filter = Control.MOUSE_FILTER_PASS

	# Cartas apiladas con overlap.
	for j in meld.cards.size():
		var c: CardUI = _CARD_SCENE.instantiate() as CardUI
		row.add_child(c)
		c.bind(meld.cards[j], true)
		c.position = Vector2(_CARD_OVERLAP * float(j), 0.0)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# DropZone superpuesta sobre toda la fila para "extender".
	var dz: DropZone = _DROP_SCENE.instantiate() as DropZone
	row.add_child(dz)
	dz.accept_kind = _MELD_KIND_EXTEND
	dz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Capturamos el índice por bind para que el receptor sepa qué meld extiende.
	dz.card_dropped.connect(_on_meld_dropped.bind(index))
	return row


static func _meld_visual_width(meld: Meld) -> float:
	if meld.cards.is_empty():
		return CardUI.CARD_SIZE.x
	return CardUI.CARD_SIZE.x + _CARD_OVERLAP * float(meld.cards.size() - 1) + _MELD_GAP


# ---------------------------------------------------------------------------
# Handlers
# ---------------------------------------------------------------------------

func _on_meld_dropped(card_id: int, source_path: NodePath, _kind: String, meld_index: int) -> void:
	extend_meld_requested.emit(meld_index, card_id, source_path)


func _on_new_meld_dropped(card_id: int, source_path: NodePath, _kind: String) -> void:
	create_meld_requested.emit(card_id, source_path)
