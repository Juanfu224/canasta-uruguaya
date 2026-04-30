## Construye el `Theme` global del juego desde `Tokens` programáticamente.
##
## Se invoca una sola vez en `Main._ready()` y se asigna a la raíz del árbol
## (`get_tree().root.theme = ThemeBuilder.build()`), afectando a todas las
## escenas hijas sin tener que asignar el theme manualmente.
##
## Razones para construirlo en código (vs. .theme binario):
##   - Diff legible en VCS.
##   - Cambios en tokens propagan a recursos sin tocar binarios.
##   - Imposible que un .theme se desincronice de los tokens.
class_name ThemeBuilder
extends RefCounted


static func build() -> Theme:
	var theme: Theme = Theme.new()

	# Default font para todo control (SystemFont con fallbacks).
	theme.default_font = Tokens.font_ui()
	theme.default_font_size = Tokens.T_MD

	_apply_button(theme)
	_apply_label(theme)
	_apply_panel(theme)
	_apply_panel_container(theme)
	_apply_popup(theme)
	_apply_separator(theme)
	_apply_scrollbar(theme)
	_apply_tooltip(theme)
	return theme


# ---------------------------------------------------------------------------
# Button
# ---------------------------------------------------------------------------

static func _apply_button(theme: Theme) -> void:
	theme.set_stylebox("normal", "Button", Tokens.button_style())
	theme.set_stylebox("hover", "Button", Tokens.button_style_hover())
	theme.set_stylebox("pressed", "Button", Tokens.button_style_pressed())
	theme.set_stylebox("disabled", "Button", Tokens.button_style_disabled())
	theme.set_stylebox("focus", "Button", Tokens.panel_style(
		Color(0, 0, 0, 0), Tokens.TRIM_GOLD, Tokens.BORDER_THICK, Tokens.R_MD, false
	))

	theme.set_color("font_color", "Button", Tokens.PAPER)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", Tokens.PAPER_DIM)
	theme.set_color("font_disabled_color", "Button", Tokens.PAPER_DIM.darkened(0.35))

	theme.set_font("font", "Button", Tokens.font_ui())
	theme.set_font_size("font_size", "Button", Tokens.T_MD)

	theme.set_constant("h_separation", "Button", Tokens.SP_SM)


# ---------------------------------------------------------------------------
# Label
# ---------------------------------------------------------------------------

static func _apply_label(theme: Theme) -> void:
	theme.set_color("font_color", "Label", Tokens.PAPER)
	theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.55))
	theme.set_constant("shadow_offset_x", "Label", 0)
	theme.set_constant("shadow_offset_y", "Label", 1)
	theme.set_font("font", "Label", Tokens.font_ui())
	theme.set_font_size("font_size", "Label", Tokens.T_MD)


# ---------------------------------------------------------------------------
# Panel
# ---------------------------------------------------------------------------

static func _apply_panel(theme: Theme) -> void:
	theme.set_stylebox("panel", "Panel", Tokens.panel_style(Tokens.INK_SOFT, Tokens.TRIM_GOLD_DIM))


static func _apply_panel_container(theme: Theme) -> void:
	theme.set_stylebox("panel", "PanelContainer", Tokens.panel_style(Tokens.INK_SOFT, Tokens.TRIM_GOLD_DIM))


# ---------------------------------------------------------------------------
# Popup / AcceptDialog
# ---------------------------------------------------------------------------

static func _apply_popup(theme: Theme) -> void:
	var s: StyleBoxFlat = Tokens.panel_style(Tokens.INK_SOFT, Tokens.TRIM_GOLD, Tokens.BORDER_MD, Tokens.R_LG, true)
	s.shadow_size = 12
	s.shadow_color = Color(0, 0, 0, 0.55)
	theme.set_stylebox("panel", "PopupPanel", s)
	theme.set_stylebox("panel", "PopupMenu", s)


# ---------------------------------------------------------------------------
# Separator
# ---------------------------------------------------------------------------

static func _apply_separator(theme: Theme) -> void:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = Tokens.TRIM_GOLD_DIM
	s.set_content_margin_all(0)
	theme.set_stylebox("separator", "HSeparator", s)
	theme.set_stylebox("separator", "VSeparator", s)
	theme.set_constant("separation", "HSeparator", 2)
	theme.set_constant("separation", "VSeparator", 2)


# ---------------------------------------------------------------------------
# Scrollbar (delgada, oscura)
# ---------------------------------------------------------------------------

static func _apply_scrollbar(theme: Theme) -> void:
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.20)
	bg.set_corner_radius_all(Tokens.R_SM)
	var grab: StyleBoxFlat = StyleBoxFlat.new()
	grab.bg_color = Tokens.TRIM_GOLD_DIM
	grab.set_corner_radius_all(Tokens.R_SM)
	theme.set_stylebox("scroll", "HScrollBar", bg)
	theme.set_stylebox("grabber", "HScrollBar", grab)
	theme.set_stylebox("scroll", "VScrollBar", bg)
	theme.set_stylebox("grabber", "VScrollBar", grab)


# ---------------------------------------------------------------------------
# Tooltip
# ---------------------------------------------------------------------------

static func _apply_tooltip(theme: Theme) -> void:
	var s: StyleBoxFlat = Tokens.panel_style(Tokens.INK, Tokens.TRIM_GOLD, Tokens.BORDER_THIN, Tokens.R_SM, true)
	theme.set_stylebox("panel", "TooltipPanel", s)
	theme.set_color("font_color", "TooltipLabel", Tokens.PAPER)
	theme.set_font("font", "TooltipLabel", Tokens.font_ui())
	theme.set_font_size("font_size", "TooltipLabel", Tokens.T_SM)
