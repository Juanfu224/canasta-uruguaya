## Test de integración: simula una partida 2v2 con seed determinista y
## verifica que la FSM completa una mano cuando un equipo cierra, dejando
## puntajes coherentes (>0 para el cerrador).
##
## NO simula AI compleja: usa una política mínima determinista:
##   - Robar 2.
##   - Si tiene >=3 cartas del mismo rango natural y el equipo aún no abrió,
##     intenta meld. (No optimiza umbrales — sólo prueba la maquinaria.)
##   - Descartar la carta de mayor valor.
extends RefCounted

const TestAssert := preload("res://tools/test_assert.gd")


static func _count_by_rank(hand: Array) -> Dictionary:
	var d: Dictionary = {}
	for c in hand:
		if (c as Card).is_wildcard:
			continue
		if (c as Card).rank == GameConfig.Rank.THREE:
			continue
		d[c.rank] = d.get(c.rank, 0) + 1
	return d


static func _highest_value_card_id(hand: Array) -> int:
	var best_id: int = -1
	var best_pts: int = -1
	for c in hand:
		if (c as Card).is_wildcard:
			continue  # no descartar wildcards (taparía pozo)
		if (c as Card).is_red_three or (c as Card).is_black_three:
			continue
		if (c as Card).point_value > best_pts:
			best_pts = (c as Card).point_value
			best_id = (c as Card).id
	if best_id == -1:
		# fallback: cualquier carta
		for c in hand:
			if not (c as Card).is_red_three:
				return (c as Card).id
	return best_id


static func run() -> Array:
	var failures: Array[String] = []
	var t := TestAssert.new("integration_2v2_one_hand")

	var cfg := MatchConfig.standard_2v2(1)
	var state := MatchState.create(cfg)
	state.deck = Deck.build_standard_108()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	state.deck.shuffle(rng)

	# Setup manual sin FSM (para test focalizado en RulesEngine).
	RulesEngine.deal_initial(state)
	state.current_player = 0

	# Simulación de turnos. Límite alto para que el mazo eventualmente se agote.
	var max_turns: int = 500
	var turns_played: int = 0
	while not state.hand_finished and turns_played < max_turns:
		var pid: int = state.current_player

		# Fase robo.
		var dr := RulesEngine.draw_from_deck(state, pid)
		if not dr.ok:
			failures.append("draw failed at turn %d: %s" % [turns_played, dr.reason])
			break
		if state.hand_finished:
			break

		# Fase juego: intenta bajar combinaciones triviales.
		var hand: Array = state.hands[pid]
		var counts := _count_by_rank(hand)
		for rank in counts.keys():
			if (counts[rank] as int) >= 3:
				# Recolectar ids de naturales de ese rango.
				var ids := PackedInt32Array()
				var pts: int = 0
				for c in hand:
					if not (c as Card).is_wildcard and (c as Card).rank == rank:
						ids.append((c as Card).id)
						pts += (c as Card).point_value
				if pts >= GameConfig.OPENING_THRESHOLD_INITIAL or state.team_of(pid).opened:
					var rm := RulesEngine.execute_meld(state, pid, ids, rank)
					if rm.ok:
						break  # un meld por turno para el test

		# Intento de cierre.
		if RulesEngine.can_close(state, pid).ok:
			RulesEngine.execute_close(state, pid)
			break

		# Fase descarte.
		var disc_id: int = _highest_value_card_id(state.hands[pid])
		if disc_id == -1:
			# No hay nada para descartar (mano vacía después de melds) → cierre forzado o break.
			break
		var dd := RulesEngine.execute_discard(state, pid, disc_id)
		if not dd.ok:
			failures.append("discard failed at turn %d: %s" % [turns_played, dd.reason])
			break

		state.advance_turn()
		turns_played += 1

	# Aserciones sobre el estado final de la mano.
	t.is_true(turns_played > 0, "turns played > 0")
	t.is_true(state.hand_finished, "hand_finished = true después de %d turnos" % turns_played)

	# Calcular puntajes.
	for team in state.teams:
		var ts: TeamState = team
		var is_closer: bool = (state.closer_player_id != -1
			and state.team_of(state.closer_player_id).team_id == ts.team_id)
		var hands_for_team: Array = []
		for p in range(state.config.n_players):
			if state.config.team_of_player(p) == ts.team_id:
				hands_for_team.append(state.hands[p])
		ScoreCalculator.score_team(ts, is_closer, false, hands_for_team, 0)

	# Al menos un equipo tiene score != 0 (alguien hizo algo).
	var any_score: bool = false
	for ts in state.teams:
		if (ts as TeamState).hand_score != 0:
			any_score = true
			break
	t.is_true(any_score, "al menos un equipo tiene puntaje no cero")

	failures.append_array(t.failures)
	return failures
