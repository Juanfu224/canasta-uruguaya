## Popup de resultados de mano (puntuación).
##
## Adaptado del `level_up.gd` de Balatro. Recibe un `Array[TeamState]` y
## una `Dictionary` con desglose precalculado por `ScoreCalculator`, anima
## un count-up por cada bonus, y emite `closed` cuando termina (o el usuario
## pulsa "Continuar").
##
## Diseño:
##   - 100% presentacional: NO recalcula puntuación, solo muestra. Esto evita
##     duplicar lógica con `core/score_calculator.gd` (autoridad del host).
##   - Singleton-friendly: se instancia y se descarta. No reusa estado.
##   - El payload esperado es:
##       {
##         "teams": [
##           {
##             "team_id": int,
##             "label": String,
##             "rows": [{ "label": String, "value": int }, ...],
##             "hand_total": int,
##             "cumulative_before": int,
##             "cumulative_after": int,
##           }, ...
##         ],
##         "title": String   # opcional, default "Resultado de la mano"
##       }
##   - Si `teams` está vacío, se muestra mensaje placeholder.
##
## Performance:
##   - Una sola Tween chain. Cuando `closed` se emite, el caller debe hacer
##     `queue_free()` sobre el popup.
class_name ScorePopup
extends Control

## Emitida cuando el popup termina su secuencia (o el jugador pulsa Continuar).
signal closed

const _ROW_TWEEN_DURATION: float = 0.55
const _ROW_DELAY: float = 0.12

@onready var _backdrop: ColorRect = $Backdrop
@onready var _panel: PanelContainer = $Center/Panel
@onready var _title: Label = $Center/Panel/Margin/VBox/Title
@onready var _teams_container: VBoxContainer = $Center/Panel/Margin/VBox/Teams
@onready var _continue_btn: Button = $Center/Panel/Margin/VBox/Continue

var _payload: Dictionary = {}
var _master_tween: Tween = null


func _ready() -> void:
	_backdrop.modulate.a = 0.0
	_panel.scale = Vector2(0.6, 0.6)
	_panel.modulate.a = 0.0
	_continue_btn.disabled = true
	_continue_btn.modulate.a = 0.0
	_continue_btn.pressed.connect(_on_continue_pressed)


## Lanza el popup con un payload (ver doc de cabecera). Devuelve `self` para
## permitir `await popup.play(...).closed`.
func play(payload: Dictionary) -> ScorePopup:
	_payload = payload
	_title.text = payload.get("title", "Resultado de la mano")
	_build_team_rows()
	_animate_in()
	return self


# ---------------------------------------------------------------------------
# Construcción dinámica
# ---------------------------------------------------------------------------

func _build_team_rows() -> void:
	for child in _teams_container.get_children():
		child.queue_free()

	var teams: Array = _payload.get("teams", [])
	if teams.is_empty():
		var l: Label = Label.new()
		l.text = "(sin datos)"
		_teams_container.add_child(l)
		return

	for team_data: Dictionary in teams:
		_teams_container.add_child(_make_team_block(team_data))


func _make_team_block(team_data: Dictionary) -> VBoxContainer:
	var block: VBoxContainer = VBoxContainer.new()
	block.add_theme_constant_override("separation", 4)

	var header: Label = Label.new()
	header.text = team_data.get("label", "Equipo %d" % int(team_data.get("team_id", 0)))
	header.add_theme_font_size_override("font_size", 22)
	header.add_theme_color_override("font_color", Color(0.95, 0.85, 0.30))
	block.add_child(header)

	var rows: Array = team_data.get("rows", [])
	for row: Dictionary in rows:
		block.add_child(_make_score_row(row.get("label", "?"), int(row.get("value", 0))))

	# Línea total mano.
	block.add_child(_make_separator())
	block.add_child(_make_score_row("Total mano", int(team_data.get("hand_total", 0)), true))
	# Acumulado.
	block.add_child(_make_score_row(
		"Acumulado",
		int(team_data.get("cumulative_after", 0)),
		false,
		int(team_data.get("cumulative_before", 0))
	))
	return block


func _make_score_row(label_text: String, target_value: int, bold: bool = false, start_value: int = 0) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var l: Label = Label.new()
	l.text = label_text
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if bold:
		l.add_theme_font_size_override("font_size", 18)
	row.add_child(l)

	var v: Label = Label.new()
	v.text = str(start_value)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.custom_minimum_size = Vector2(80, 0)
	if bold:
		v.add_theme_font_size_override("font_size", 18)
		v.add_theme_color_override("font_color", Color(0.95, 0.95, 0.55))
	v.set_meta(&"target", target_value)
	v.set_meta(&"start", start_value)
	row.add_child(v)
	row.set_meta(&"value_label", v)
	return row


func _make_separator() -> HSeparator:
	return HSeparator.new()


# ---------------------------------------------------------------------------
# Animación
# ---------------------------------------------------------------------------

func _animate_in() -> void:
	_kill_master_tween()
	_master_tween = create_tween()
	_master_tween.set_parallel(false)

	# 1. Fade del backdrop.
	_master_tween.tween_property(_backdrop, "modulate:a", 0.65, 0.25)

	# 2. Pop del panel.
	var p1: Tween = _master_tween.parallel()
	p1.tween_property(_panel, "modulate:a", 1.0, 0.30)
	p1.tween_property(_panel, "scale", Vector2.ONE, 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# 3. Pequeña pausa.
	_master_tween.tween_interval(0.10)

	# 4. Count-up por cada fila numérica.
	for team_block in _teams_container.get_children():
		for child in team_block.get_children():
			if child is HBoxContainer and child.has_meta(&"value_label"):
				_chain_count_up(child)
				_master_tween.tween_interval(_ROW_DELAY)

	# 5. Mostrar botón continuar.
	_master_tween.tween_property(_continue_btn, "modulate:a", 1.0, 0.25)
	_master_tween.tween_callback(func() -> void:
		_continue_btn.disabled = false
		_continue_btn.grab_focus()
	)


func _chain_count_up(row: HBoxContainer) -> void:
	var label: Label = row.get_meta(&"value_label") as Label
	if label == null:
		return
	var target: int = int(label.get_meta(&"target", 0))
	var start: int = int(label.get_meta(&"start", 0))
	if start == target:
		# Solo flash.
		_master_tween.tween_property(label, "modulate", Color(1.4, 1.4, 1.0), 0.10)
		_master_tween.tween_property(label, "modulate", Color.WHITE, 0.15)
		return
	_master_tween.tween_method(
		_set_int_label.bind(label),
		float(start),
		float(target),
		_ROW_TWEEN_DURATION
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _set_int_label(value: float, label: Label) -> void:
	if label == null or not is_instance_valid(label):
		return
	label.text = str(int(round(value)))


# ---------------------------------------------------------------------------
# Cierre
# ---------------------------------------------------------------------------

func _on_continue_pressed() -> void:
	_continue_btn.disabled = true
	_kill_master_tween()
	var t: Tween = create_tween().set_parallel(true)
	t.tween_property(_backdrop, "modulate:a", 0.0, 0.18)
	t.tween_property(_panel, "modulate:a", 0.0, 0.18)
	t.tween_property(_panel, "scale", Vector2(0.85, 0.85), 0.18)
	await t.finished
	closed.emit()


func _kill_master_tween() -> void:
	if _master_tween != null and _master_tween.is_valid() and _master_tween.is_running():
		_master_tween.kill()


# ---------------------------------------------------------------------------
# Helpers estáticos para construir payloads desde TeamState
# ---------------------------------------------------------------------------

## Construye el payload estándar a partir de los `TeamState` finales y
## su valor `cumulative_score` ANTES de aplicar la mano. Esto permite
## animar el contador acumulado.
##
## `score_breakdowns` es un `Array[Dictionary]` paralelo a `team_states`,
## donde cada dict contiene labels y valores producidos por
## `ScoreCalculator.detail()`. Si está vacío, el popup mostrará solo
## `hand_score` y `cumulative_score`.
static func payload_from_team_states(
	team_states: Array,
	cumulative_before: Array,
	score_breakdowns: Array = [],
	title: String = "Resultado de la mano"
) -> Dictionary:
	var teams_array: Array = []
	for i in team_states.size():
		var ts: TeamState = team_states[i] as TeamState
		if ts == null:
			continue
		var rows: Array = []
		if i < score_breakdowns.size():
			rows = score_breakdowns[i].get("rows", [])
		var prev: int = int(cumulative_before[i]) if i < cumulative_before.size() else (ts.cumulative_score - ts.hand_score)
		teams_array.append({
			"team_id": ts.team_id,
			"label": "Equipo %d" % ts.team_id,
			"rows": rows,
			"hand_total": ts.hand_score,
			"cumulative_before": prev,
			"cumulative_after": ts.cumulative_score,
		})
	return {"title": title, "teams": teams_array}
