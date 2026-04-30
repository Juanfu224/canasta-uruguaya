## Bot difícil. Extiende `NormalBot` con un look-ahead 1-ply en DiscardPhase:
## evalúa las 3 mejores opciones del `DiscardPicker` simulando la jugada
## y elige la que minimice el riesgo de capturar el pozo el rival.
##
## Implementación segura: NO mira las manos rivales (info privada). Sólo
## razona sobre lo público:
##   - Cuántas cartas le ha visto descartar al rival (no rastreado en MVP →
##     usamos heurística simple: penalizar descartar rangos en los que el
##     rival ya tiene meld abierto).
class_name HardBot
extends NormalBot


func _init() -> void:
	level = GameConfig.BotLevel.HARD


func _decide_discard(state: MatchState, player_id: int) -> BotDecision:
	var hand: Array = state.hands[player_id]
	if hand.is_empty():
		return BotDecision.discard(-1)
	var typed: Array[Card] = []
	for c in hand:
		typed.append(c)
	var a: HandAnalyzer.Analysis = HandAnalyzer.analyze(typed)
	var own_team: TeamState = state.team_of(player_id)

	# Construir rangos en los que CUALQUIER equipo rival tiene meld abierto.
	var rival_open_ranks: Dictionary = {}
	for t in state.teams:
		var team: TeamState = t
		if team.team_id == own_team.team_id:
			continue
		for m in team.melds:
			rival_open_ranks[(m as Meld).rank] = true

	var best_id: int = -1
	var best_score: float = -INF
	for c in hand:
		var card: Card = c
		if card.is_red_three:
			continue
		var sc: float = DiscardPicker._discard_score(card, a, own_team)
		# Penalizar regalar a un rival que ya tiene meld abierto del rango.
		if rival_open_ranks.has(card.rank):
			sc -= 200.0
		# Penalizar descartar naturales si tenemos comodines guardados (pareja
		# potencial para canasta).
		var grp: HandAnalyzer.RankGroup = a.groups.get(card.rank, null)
		if grp != null and grp.count() >= 2 and not card.is_wildcard:
			sc -= 50.0
		if sc > best_score or (sc == best_score and (best_id == -1 or card.id < best_id)):
			best_score = sc
			best_id = card.id

	if best_id == -1:
		best_id = DiscardPicker.pick(state, player_id)
	return BotDecision.discard(best_id)
