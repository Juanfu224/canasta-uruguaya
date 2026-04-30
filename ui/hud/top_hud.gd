## Barra superior del HUD: insignias de equipos a izquierda y derecha,
## ronda + fase al centro, botón "menú" a la esquina derecha.
##
## Diseño:
##   - PanelContainer con fondo ink semitransparente y borde dorado.
##   - Anclado a top horizontal: ocupa todo el ancho con 8px margin.
##   - Sin lógica: expone API setters y reemite señal `menu_pressed`.
class_name TopHud
extends Control

signal menu_pressed

@onready var _bg: PanelContainer = $Bg
@onready var _team_red: TeamBadge = $Bg/Margin/Row/TeamRed
@onready var _team_blue: TeamBadge = $Bg/Margin/Row/TeamBlue
@onready var _round_label: Label = $Bg/Margin/Row/Center/RoundLabel
@onready var _phase: PhaseChip = $Bg/Margin/Row/Center/PhaseChip
@onready var _btn_menu: Button = $Bg/Margin/Row/MenuButton


func _ready() -> void:
	_apply_skin()
	_btn_menu.pressed.connect(func() -> void: menu_pressed.emit())
	_team_red.set_team("Equipo Rojo", Tokens.TEAM_RED, 0, 50)
	_team_blue.set_team("Equipo Azul", Tokens.TEAM_BLUE, 0, 50)


func _apply_skin() -> void:
	var s: StyleBoxFlat = Tokens.panel_style(
		Color(Tokens.INK_SOFT.r, Tokens.INK_SOFT.g, Tokens.INK_SOFT.b, 0.92),
		Tokens.TRIM_GOLD_DIM,
		Tokens.BORDER_MD,
		Tokens.R_MD,
		true,
	)
	_bg.add_theme_stylebox_override("panel", s)


func set_round(round_index: int, total_rounds: int) -> void:
	_round_label.text = "Mano %d / %d" % [round_index, total_rounds]


func set_phase(label: String, phase_id: String = "play") -> void:
	_phase.set_phase(label)
	_phase.set_color_for_phase(phase_id)


func bump_team_score(team_id: int, value: int) -> void:
	if team_id == 1:
		_team_red.bump_score(value)
	else:
		_team_blue.bump_score(value)


func set_team_threshold(team_id: int, score: int, threshold: int) -> void:
	if team_id == 1:
		_team_red.set_team("Equipo Rojo", Tokens.TEAM_RED, score, threshold)
	else:
		_team_blue.set_team("Equipo Azul", Tokens.TEAM_BLUE, score, threshold)
