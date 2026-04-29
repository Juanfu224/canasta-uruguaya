## Fase de juego: el jugador puede bajar combinaciones y/o decidir cerrar.
## Pasa a DiscardPhase cuando el host marca `play_resolved`, o a RoundEnd si
## el jugador cierra.
extends GameState

var play_resolved: bool = false

func name() -> String:
	return "PlayPhase"

func _enter(_state: MatchState) -> void:
	play_resolved = false

func mark_resolved() -> void:
	play_resolved = true

func _process(state: MatchState) -> Script:
	if state.hand_finished:
		return load("res://fsm/states/state_round_end.gd") as Script
	if play_resolved:
		return load("res://fsm/states/state_discard_phase.gd") as Script
	return null
