## Fase de descarte: el jugador tira una carta al pozo. Avanza el turno.
extends GameState

var discard_resolved: bool = false

func name() -> String:
	return "DiscardPhase"

func _enter(_state: MatchState) -> void:
	discard_resolved = false

func mark_resolved() -> void:
	discard_resolved = true

func _process(state: MatchState) -> Script:
	if state.hand_finished:
		return load("res://fsm/states/state_round_end.gd") as Script
	if discard_resolved:
		state.advance_turn()
		return load("res://fsm/states/state_draw_phase.gd") as Script
	return null
