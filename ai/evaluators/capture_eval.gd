## Decide si capturar el pozo es ventajoso y qué cartas reclamar.
##
## Estrategia (heurística simple y conservadora):
##   1. Si el pozo está taponado o vacío → no capturar.
##   2. Identificar `target_rank` capturable (top o segunda si está cruzado).
##   3. Si target_rank == TRES → no capturar.
##   4. Si pozo cruzado y la mano no tiene 2 naturales del target → no
##      capturar (la regla "wild_in_crossed" prohíbe completar con comodines).
##   5. Si tenemos ≥2 naturales del target en mano → capturar reclamando los
##      naturales (evitamos comodines salvo necesidad estricta).
##   6. Si el equipo no abrió, validar que el meld resultante alcance el
##      umbral; si no alcanza → no capturar (preferimos meldear normal).
##
## Devuelve un `BotDecision.capture(...)` o null si no conviene.
class_name CaptureEval
extends RefCounted


static func evaluate(state: MatchState, player_id: int) -> BotDecision:
	if state.pozo == null or state.pozo.is_empty():
		return null
	if state.pozo.is_taponado():
		return null
	var target_rank: int = state.pozo.capturable_rank()
	if target_rank == -1 or target_rank == GameConfig.Rank.THREE:
		return null

	var hand: Array = state.hands[player_id]
	# Naturales del target en mano.
	var naturals_in_hand: Array[Card] = []
	for c in hand:
		if not (c as Card).is_wildcard and (c as Card).rank == target_rank:
			naturals_in_hand.append(c)

	# Naturales necesarios totales (top + claim ≥ 2). Top puede ser natural.
	var top: Card = state.pozo.top()
	var top_is_target_natural: bool = (top != null
		and not top.is_wildcard
		and top.rank == target_rank)

	var needed_from_hand: int = 1 if top_is_target_natural else 2
	if naturals_in_hand.size() < needed_from_hand:
		return null

	# Construir claim: tomar los `needed_from_hand` naturales (preserva determinismo).
	var claim_ids := PackedInt32Array()
	for i in range(needed_from_hand):
		claim_ids.append(naturals_in_hand[i].id)

	# Validar contra RulesEngine (autoritativa). Si falla, no capturamos.
	var res: RuleResult = RulesEngine.can_capture_pozo(state, player_id, claim_ids)
	if not res.ok:
		return null
	return BotDecision.capture(claim_ids)
