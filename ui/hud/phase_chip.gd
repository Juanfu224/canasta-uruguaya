## Chip de fase de turno (Robar / Jugar / Descartar). Pensado para el
## `TopHud`. Anima un squish-stretch al cambiar de fase.
class_name PhaseChip
extends PanelContainer

@onready var _label: Label = $Margin/Label

var _current: String = ""


func _ready() -> void:
	pivot_offset = size * 0.5
	resized.connect(func() -> void: pivot_offset = size * 0.5)
	_apply_skin(Tokens.TRIM_GOLD)
	set_phase("Listo")


func _apply_skin(border: Color) -> void:
	var s: StyleBoxFlat = Tokens.panel_style(
		Tokens.INK_SOFT,
		border,
		Tokens.BORDER_MD,
		Tokens.R_LG,
		true,
	)
	add_theme_stylebox_override("panel", s)


func set_phase(text: String) -> void:
	if text == _current:
		return
	_current = text
	_label.text = text
	# Squish-stretch elastic.
	scale = Vector2(1.18, 0.85)
	var t: Tween = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "scale", Vector2.ONE, 0.45)


func set_color_for_phase(phase_id: String) -> void:
	var c: Color = Tokens.TRIM_GOLD
	match phase_id:
		"draw": c = Tokens.STATE_OK
		"play": c = Tokens.TRIM_GOLD
		"discard": c = Tokens.STATE_WARN
		"end": c = Tokens.STATE_DANGER
	_apply_skin(c)
	_label.add_theme_color_override("font_color", c.lightened(0.30))
