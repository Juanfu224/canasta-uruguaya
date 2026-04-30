## Barra inferior del HUD: hint contextual, acciones secundarias.
##
## API mínima usada por la escena offline:
##   - `set_hint(text)`
##   - `set_counts(deck, pozo, hand)`
##   - señal `back_pressed` para volver al menú.
class_name BottomHud
extends Control

signal back_pressed

@onready var _bg: PanelContainer = $Bg
@onready var _hint: Label = $Bg/Margin/Row/Hint
@onready var _counts: Label = $Bg/Margin/Row/Counts
@onready var _btn_back: Button = $Bg/Margin/Row/Back


func _ready() -> void:
	_apply_skin()
	_btn_back.pressed.connect(func() -> void: back_pressed.emit())


func _apply_skin() -> void:
	var s: StyleBoxFlat = Tokens.panel_style(
		Color(Tokens.INK_SOFT.r, Tokens.INK_SOFT.g, Tokens.INK_SOFT.b, 0.92),
		Tokens.TRIM_GOLD_DIM,
		Tokens.BORDER_MD,
		Tokens.R_MD,
		true,
	)
	_bg.add_theme_stylebox_override("panel", s)


func set_hint(text: String) -> void:
	_hint.text = text


func set_counts(deck_count: int, pozo_count: int, hand_count: int) -> void:
	_counts.text = "Mazo %d  ·  Pozo %d  ·  Mano %d" % [deck_count, pozo_count, hand_count]
