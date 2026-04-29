## Fin de mano: calcula puntaje, acumula y decide si la partida sigue.
extends GameState

func name() -> String:
	return "RoundEnd"

func _enter(state: MatchState) -> void:
	# Puntajes por equipo.
	for team in state.teams:
		var ts: TeamState = team
		var is_closer: bool = (state.closer_player_id != -1
			and state.team_of(state.closer_player_id).team_id == ts.team_id)
		var closed_in_hand: bool = is_closer and state.closer_closed_in_hand
		var black_threes: int = _count_black_threes_in_hands(state)
		var hands_for_team: Array = []
		for p in range(state.config.n_players):
			if state.config.team_of_player(p) == ts.team_id:
				hands_for_team.append(state.hands[p])
		ScoreCalculator.score_team(ts, is_closer, closed_in_hand,
			hands_for_team, black_threes if is_closer else 0)
		# Acumular sin reiniciar (lo hacemos manualmente abajo si la partida
		# continúa, para mantener simetría con el reset de mazo/pozo).
		ts.cumulative_score += ts.hand_score

	# Verificar fin de partida.
	for team in state.teams:
		var ts: TeamState = team
		if ts.cumulative_score >= state.config.target_score:
			state.match_finished = true
			break

func _process(state: MatchState) -> Script:
	if state.match_finished:
		return load("res://fsm/states/state_match_end.gd") as Script
	# Reset para nueva mano.
	for team in state.teams:
		(team as TeamState).reset_for_new_hand()
	for p in range(state.config.n_players):
		state.hands[p] = ([] as Array[Card])
	state.deck = Deck.build_standard_108()
	# Semilla criptográficamente segura para cada nueva mano.
	RngService.start_match(0)
	state.deck.shuffle(RngService.match_rng)
	state.pozo = null
	state.hand_finished = false
	state.closer_player_id = -1
	state.closer_closed_in_hand = false
	state.current_player = (state.current_player + 1) % state.config.n_players
	return load("res://fsm/states/state_setup_pozo.gd") as Script

func _count_black_threes_in_hands(state: MatchState) -> int:
	var n: int = 0
	for h in state.hands:
		for c in h:
			if (c as Card).is_black_three:
				n += 1
	return n
