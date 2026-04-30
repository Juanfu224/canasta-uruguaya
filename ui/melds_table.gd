## Mesa de combinaciones (melds) de un equipo.
##
## Renderiza cada meld como una fila horizontal de `CardUI` superpuestas con
## un badge "¡Canasta!" cuando el meld llega a 7 cartas.
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
const _CANASTA_SIZE: int = 7

@onready var _bg: Panel = $Bg
@onready var _header: Label = $Header
@onready var _list: HBoxContainer = $Scroll/Row
@onready var _new_meld_zone: DropZone = $NewMeldZone


func _ready() -> void:
	_apply_skin()
	_new_meld_zone.accept_kind = _MELD_KIND_CREATE
	_new_meld_zone.card_dropped.connect(_on_new_meld_dropped)


func _apply_skin() -> void:
	var s: StyleBoxFlat = Tokens.panel_style(
		Color(Tokens.INK.r, Tokens.INK.g, Tokens.INK.b, 0.45),
		Tokens.TRIM_GOLD_DIM,
		Tokens.BORDER_THIN,
		Tokens.R_LG,
		false,
	)
	_bg.add_theme_stylebox_override("panel", s)
	_header.add_theme_font_override("font", Tokens.font_display())
	_header.add_theme_font_size_override("font_size", Tokens.T_SM)
	_header.add_theme_color_override("font_color", Tokens.TRIM_GOLD)


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
	row.custom_minimum_size = Vector2(_meld_visual_width(meld), CardUI.CARD_SIZE.y + 24.0)
	row.mouse_filter = Control.MOUSE_FILTER_PASS

	# Cartas apiladas con overlap.
	for j in meld.cards.size():
		var c: CardUI = _CARD_SCENE.instantiate() as CardUI
		row.add_child(c)
		c.bind(meld.cards[j], true)
		c.position = Vector2(_CARD_OVERLAP * float(j), 0.0)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Badge "¡Canasta!" cuando la combinación está completa.
	if meld.cards.size() >= _CANASTA_SIZE:
		row.add_child(_build_canasta_badge(meld))

	# DropZone superpuesta sobre toda la fila para "extender".
	var dz: DropZone = _DROP_SCENE.instantiate() as DropZone
	row.add_child(dz)
	dz.accept_kind = _MELD_KIND_EXTEND
	dz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Capturamos el índice por bind para que el receptor sepa qué meld extiende.
	dz.card_dropped.connect(_on_meld_dropped.bind(index))
	return row


func _build_canasta_badge(meld: Meld) -> Control:
	var badge: PanelContainer = PanelContainer.new()
	var is_pure: bool = meld.wilds == 0
	var border_col: Color = Tokens.TRIM_GOLD if is_pure else Tokens.STATE_OK
	var bg_col: Color = Color(Tokens.INK.r, Tokens.INK.g, Tokens.INK.b, 0.85)
	badge.add_theme_stylebox_override(
		"panel",
		Tokens.panel_style(bg_col, border_col, Tokens.BORDER_MD, Tokens.R_MD, true),
	)
	badge.position = Vector2(0.0, -22.0)
	badge.z_index = 5
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_bottom", 2)
	badge.add_child(margin)

	var l: Label = Label.new()
	l.text = "¡Canasta!" if is_pure else "Canasta"
	l.add_theme_font_override("font", Tokens.font_display())
	l.add_theme_font_size_override("font_size", Tokens.T_XS)
	l.add_theme_color_override("font_color", border_col)
	margin.add_child(l)
	return badge


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
