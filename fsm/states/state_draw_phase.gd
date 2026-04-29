## Fase de robo: el jugador roba 2 cartas o intenta capturar el pozo.
##
## Decisión:
##   - Si el cliente solicita capturar (vía `request_capture_pozo`) y la regla
##     valida → ejecutar y pasar a `PlayPhase`.
##   - Si solicita robar → ejecutar y pasar a `PlayPhase`.
##   - Si el mazo se agotó durante el robo → `RoundEnd`.
##
## Esta FSM es pasiva: se queda en este estado hasta que el host haya
## llamado a `RulesEngine.draw_from_deck` o `execute_capture_pozo`. La señal
## de salida es la flag `draw_resolved` que el host setea tras la mutación.
extends GameState

var draw_resolved: bool = false

func name() -> String:
	return "DrawPhase"

func _enter(_state: MatchState) -> void:
	draw_resolved = false

## El host llama esto tras procesar una RPC válida (robo o captura).
func mark_resolved() -> void:
	draw_resolved = true

func _process(state: MatchState) -> Script:
	if state.hand_finished:
		return load("res://fsm/states/state_round_end.gd") as Script
	if draw_resolved:
		return load("res://fsm/states/state_play_phase.gd") as Script
	return null
