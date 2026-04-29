## Fin de partida: estado terminal. Determina equipo ganador.
extends GameState

var winner_team_id: int = -1

func name() -> String:
	return "MatchEnd"

func _enter(state: MatchState) -> void:
	state.match_finished = true
	var best_score: int = -2147483648
	for team in state.teams:
		var ts: TeamState = team
		if ts.cumulative_score > best_score:
			best_score = ts.cumulative_score
			winner_team_id = ts.team_id

func _process(_state: MatchState) -> Script:
	return null
