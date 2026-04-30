## Insignia de equipo: nombre, puntos y umbral de apertura. Pensada para
## el `TopHud`. Compacta y legible en portrait 720x1280.
##
## API:
##   `set_team(label, color, score, threshold)`
##   `bump_score(new_value)` — count-up animado.
class_name TeamBadge
extends PanelContainer

@onready var _name_label: Label = $Margin/Row/Name
@onready var _score_label: Label = $Margin/Row/Score
@onready var _threshold_label: Label = $Margin/Row/Threshold

var _color: Color = Tokens.TEAM_RED
var _score: int = 0
var _threshold: int = 50
var _count_tween: Tween = null


func _ready() -> void:
	_apply_skin()
	_refresh()


func _apply_skin() -> void:
	var s: StyleBoxFlat = Tokens.panel_style(
		Tokens.INK_SOFT,
		_color,
		Tokens.BORDER_MD,
		Tokens.R_MD,
		true,
	)
	add_theme_stylebox_override("panel", s)


func set_team(label: String, color: Color, score: int, threshold: int) -> void:
	_color = color
	_threshold = threshold
	_score = score
	_name_label.text = label
	_apply_skin()
	_name_label.add_theme_color_override("font_color", color.lightened(0.25))
	_refresh()


func bump_score(new_value: int) -> void:
	if new_value == _score:
		return
	if _count_tween != null and _count_tween.is_valid():
		_count_tween.kill()
	var start: int = _score
	_score = new_value
	_count_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_count_tween.tween_method(_set_score_text, float(start), float(new_value), 0.45)
	_count_tween.parallel().tween_property(_score_label, "scale", Vector2(1.15, 1.15), 0.12)
	_count_tween.tween_property(_score_label, "scale", Vector2.ONE, 0.18)


func _set_score_text(v: float) -> void:
	_score_label.text = "%d" % int(round(v))


func _refresh() -> void:
	_score_label.text = "%d" % _score
	_threshold_label.text = "·  apertura %d" % _threshold
