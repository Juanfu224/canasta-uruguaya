## Bot fácil. Degrada `NormalBot`:
##   - Nunca captura el pozo (siempre roba).
##   - Descarte: elige al azar entre las top-3 cartas más descartables del
##     `DiscardPicker` (introduce ruido).
##   - Meldear: igual que NormalBot (no tiene sentido degradar la apertura
##     porque la jugabilidad se vuelve frustrante).
##   - Cierre: nunca cierra proactivamente (deja al rival ganar la mano).
class_name EasyBot
extends BotPlayer


func _init() -> void:
	level = GameConfig.BotLevel.EASY


func decide(state: MatchState, player_id: int, phase: String) -> BotDecision:
	match phase:
		"DrawPhase":
			return BotDecision.draw()
		"PlayPhase":
			var meld: BotDecision = MeldPlanner.plan(state, player_id)
			if meld != null:
				return meld
			return BotDecision.pass_play()
		"DiscardPhase":
			return _noisy_discard(state, player_id)
		_:
			return BotDecision.pass_play()


func _noisy_discard(state: MatchState, player_id: int) -> BotDecision:
	var hand: Array = state.hands[player_id]
	if hand.is_empty():
		return BotDecision.discard(-1)
	# Score todas las cartas igual que DiscardPicker, ordena, toma top-3, elige random.
	var typed: Array[Card] = []
	for c in hand:
		typed.append(c)
	var a: HandAnalyzer.Analysis = HandAnalyzer.analyze(typed)
	var team: TeamState = state.team_of(player_id)
	var scored: Array = []  # [score, card_id]
	for c in hand:
		var card: Card = c
		if card.is_red_three:
			continue
		var sc: float = _easy_score(card, a, team)
		scored.append([sc, card.id])
	if scored.is_empty():
		return BotDecision.discard((hand[0] as Card).id)
	scored.sort_custom(func(x, y): return (x[0] as float) > (y[0] as float))
	var k: int = mini(3, scored.size())
	var idx: int = RngService.match_rng.randi_range(0, k - 1)
	return BotDecision.discard(scored[idx][1] as int)


static func _easy_score(card: Card, a: HandAnalyzer.Analysis, team: TeamState) -> float:
	if card.is_wildcard:
		return -1000.0
	if card.is_black_three:
		return 1000.0
	var grp: HandAnalyzer.RankGroup = a.groups.get(card.rank, null)
	var same: int = 0 if grp == null else grp.count()
	var has: bool = team.find_meld_by_rank(card.rank) != null
	var sc: float = 0.0
	if same <= 1 and not has:
		sc += 80.0
	else:
		sc -= 10.0 * float(same)
	sc += float(card.point_value) * 0.3
	return sc
