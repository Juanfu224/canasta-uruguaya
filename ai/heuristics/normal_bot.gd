## Bot heurístico estándar (NORMAL). Combina los evaluadores en una política
## de juego determinista y respetuosa con las reglas autoritativas.
class_name NormalBot
extends BotPlayer


func _init() -> void:
	level = GameConfig.BotLevel.NORMAL


func decide(state: MatchState, player_id: int, phase: String) -> BotDecision:
	match phase:
		"DrawPhase":
			return _decide_draw(state, player_id)
		"PlayPhase":
			return _decide_play(state, player_id)
		"DiscardPhase":
			return _decide_discard(state, player_id)
		_:
			# Fallback: pasar para no quedarnos atrapados (no debería ocurrir).
			return BotDecision.pass_play()


func _decide_draw(state: MatchState, player_id: int) -> BotDecision:
	var cap: BotDecision = CaptureEval.evaluate(state, player_id)
	if cap != null:
		return cap
	return BotDecision.draw()


func _decide_play(state: MatchState, player_id: int) -> BotDecision:
	# Cierre prioritario si lo tenemos.
	if RulesEngine.can_close(state, player_id).ok:
		return BotDecision.close_match()
	var meld: BotDecision = MeldPlanner.plan(state, player_id)
	if meld != null:
		return meld
	return BotDecision.pass_play()


func _decide_discard(state: MatchState, player_id: int) -> BotDecision:
	var cid: int = DiscardPicker.pick(state, player_id)
	if cid == -1:
		# Defensivo: no debería ocurrir si la mano no es vacía.
		var hand: Array = state.hands[player_id]
		if not hand.is_empty():
			cid = (hand[0] as Card).id
	return BotDecision.discard(cid)
