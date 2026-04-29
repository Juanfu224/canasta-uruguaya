## Reparte cartas iniciales y configura el pozo.
extends GameState

func name() -> String:
	return "SetupPozo"

func _enter(state: MatchState) -> void:
	RulesEngine.deal_initial(state)
	state.current_player = 0  # Host decide quién abre; por defecto player 0.

func _process(_state: MatchState) -> Script:
	return load("res://fsm/states/state_draw_phase.gd") as Script
