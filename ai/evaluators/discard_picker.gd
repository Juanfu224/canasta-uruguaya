## Selecciona la mejor carta a descartar.
##
## Heurística (orden de preferencia):
##   1. Tres negro (tapona el pozo del rival sin coste para nosotros).
##   2. Carta de rango "huérfano" (sin pares en mano y sin meld del equipo
##      del mismo rango).
##   3. Carta de rango con menor punto-por-utilidad: bajar valor de penalización
##      en mano sin regalar fáciles al rival.
##   4. NUNCA descartar: comodín (a menos que sea la única opción), tres rojo
##      (se autorroban; defensivo), naturales de un rango con ≥2 en mano.
##
## Empate determinista: ID más bajo (estable bajo seed fija).
class_name DiscardPicker
extends RefCounted


static func pick(state: MatchState, player_id: int) -> int:
	var hand: Array = state.hands[player_id]
	if hand.is_empty():
		return -1
	var team: TeamState = state.team_of(player_id)

	var typed: Array[Card] = []
	for c in hand:
		typed.append(c)
	var a: HandAnalyzer.Analysis = HandAnalyzer.analyze(typed)

	# 1. Tres negro: óptimo para descartar.
	if not a.black_threes.is_empty():
		return _lowest_id(a.black_threes)

	# 2. Calcular score de cada carta (mayor = más descartable).
	var best_id: int = -1
	var best_score: float = -INF
	for c in hand:
		var card: Card = c
		if card.is_red_three:
			continue  # defensivo
		var sc: float = _discard_score(card, a, team)
		if sc > best_score or (sc == best_score and (best_id == -1 or card.id < best_id)):
			best_score = sc
			best_id = card.id

	if best_id == -1:
		# Fallback (sólo si la mano son todos comodines + treses rojos):
		# descartar la primera carta no-tres-rojo.
		for c in hand:
			if not (c as Card).is_red_three:
				return (c as Card).id
		return (hand[0] as Card).id

	return best_id


static func _discard_score(card: Card, a: HandAnalyzer.Analysis, team: TeamState) -> float:
	# Penalizar fuertemente comodines.
	if card.is_wildcard:
		return -1000.0
	var grp: HandAnalyzer.RankGroup = a.groups.get(card.rank, null)
	var same_rank: int = 0 if grp == null else grp.count()
	var has_team_meld: bool = team.find_meld_by_rank(card.rank) != null

	# Score base: queremos descartar lo que no nos sirve.
	# - Huérfano (1 sola carta del rango y sin meld del equipo) → muy descartable.
	# - Carta con compañeras (≥2 mismas rango) → menos descartable.
	# - Si el equipo ya tiene meld de ese rango → menos descartable (extiende).
	var sc: float = 0.0
	if same_rank <= 1 and not has_team_meld:
		sc += 100.0  # huérfano
	else:
		sc -= 10.0 * float(same_rank)
		if has_team_meld:
			sc -= 30.0
	# Preferir descartar puntos altos cuando todo igual (reduce penalización).
	sc += float(card.point_value) * 0.5
	return sc


static func _lowest_id(cards: Array[Card]) -> int:
	var best: int = (cards[0]).id
	for c in cards:
		if c.id < best:
			best = c.id
	return best
