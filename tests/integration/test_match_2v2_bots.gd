## Test de integración: simula una mano 4-bots usando NormalBot.
##
## Verifica que las decisiones de los bots SIEMPRE se validan correctamente
## contra `RulesEngine` y que la simulación no genera acciones inválidas.
extends RefCounted

const TestAssert := preload("res://tools/test_assert.gd")


static func _apply_decision(state: MatchState, pid: int, d: BotDecision, phase: String) -> RuleResult:
	match phase:
		"DrawPhase":
			if d.kind == "capture":
				return RulesEngine.execute_capture_pozo(state, pid, d.card_ids)
			return RulesEngine.draw_from_deck(state, pid)
		"PlayPhase":
			if d.kind == "meld":
				return RulesEngine.execute_meld(state, pid, d.card_ids, d.declared_rank)
			if d.kind == "close_match":
				var team: TeamState = state.team_of(pid)
				return RulesEngine.execute_close(state, pid, not team.opened)
			# pass_play: válido sólo en PlayPhase.
			return RulesEngine.can_pass_play(state, pid)
		"DiscardPhase":
			return RulesEngine.execute_discard(state, pid, d.card_ids[0] if d.card_ids.size() > 0 else -1)
		_:
			var r := RuleResult.new()
			r.ok = false
			r.reason = "phase_unknown"
			return r


static func run() -> Array:
	var failures: Array[String] = []
	var t := TestAssert.new("integration_bots_normal")

	var cfg := MatchConfig.standard_2v2(7)
	var state := MatchState.create(cfg)
	state.deck = Deck.build_standard_108()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	state.deck.shuffle(rng)
	RulesEngine.deal_initial(state)
	state.current_player = 0

	var bots: Array[BotPlayer] = []
	for i in range(cfg.n_players):
		bots.append(NormalBot.new())

	var max_turns: int = 200
	var invalid_count: int = 0
	var turns: int = 0
	while not state.hand_finished and turns < max_turns:
		var pid: int = state.current_player

		# DrawPhase
		var d_draw: BotDecision = bots[pid].decide(state, pid, "DrawPhase")
		var r1 := _apply_decision(state, pid, d_draw, "DrawPhase")
		if not r1.ok:
			invalid_count += 1
			# Fallback de seguridad para no atascar.
			RulesEngine.draw_from_deck(state, pid)
		if state.hand_finished:
			break

		# PlayPhase
		var d_play: BotDecision = bots[pid].decide(state, pid, "PlayPhase")
		var r2 := _apply_decision(state, pid, d_play, "PlayPhase")
		if not r2.ok and d_play.kind != "pass_play":
			invalid_count += 1
		if state.hand_finished:
			break

		# DiscardPhase
		var d_disc: BotDecision = bots[pid].decide(state, pid, "DiscardPhase")
		var r3 := _apply_decision(state, pid, d_disc, "DiscardPhase")
		if not r3.ok:
			invalid_count += 1
			# Fallback: descartar primera no-tres-rojo.
			for c in state.hands[pid]:
				if not (c as Card).is_red_three:
					RulesEngine.execute_discard(state, pid, (c as Card).id)
					break

		state.advance_turn()
		turns += 1

	t.eq(invalid_count, 0, "decisiones inválidas")
	t.is_true(turns > 0, "al menos un turno")
	failures.append_array(t.failures)
	return failures
