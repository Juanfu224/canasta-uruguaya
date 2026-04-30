## Planificador de melds: dado el estado y la mano, propone el mejor meld a
## bajar (o extender) en la fase PlayPhase.
##
## Heurística:
##   1. Si tenemos meld del rango ya abierto → priorizar EXTENDERLO con todos
##      los naturales de ese rango (acercarse a canasta = +500/+200 bono).
##   2. Buscar el rango con más naturales (≥3) en mano. Si rango ≥ "buscamos
##      canasta" (ya tenemos ≥4) y hay comodines disponibles, agregar uno.
##   3. Antes de meldear: verificar umbral de apertura si el equipo no abrió.
##      Si no alcanza, intentar combinar dos rangos (no soportado en MVP →
##      retornar null, esperar próxima ronda).
##   4. Devolver `BotDecision.meld(card_ids, rank)` o null.
##
## Notas:
##   - No bajamos comodines puros (Joker/2-meld) en MVP — generan canastas
##     de 7 comodines pero son raras y arriesgadas.
##   - No usamos comodines si quedan ≤1 (los reservamos para captura/extensión).
class_name MeldPlanner
extends RefCounted


## Propone un meld. Devuelve null si no hay jugada conveniente.
static func plan(state: MatchState, player_id: int) -> BotDecision:
	var hand: Array = state.hands[player_id]
	var team: TeamState = state.team_of(player_id)
	var typed: Array[Card] = []
	for c in hand:
		typed.append(c)
	var a: HandAnalyzer.Analysis = HandAnalyzer.analyze(typed)

	# 1. Extensión de meld existente con naturales sueltos.
	for m in team.melds:
		var meld: Meld = m
		if meld.rank == GameConfig.Rank.JOKER or meld.rank == GameConfig.Rank.TWO:
			continue  # no soportado en MVP
		var grp: HandAnalyzer.RankGroup = a.groups.get(meld.rank, null)
		if grp != null and grp.count() > 0:
			var ids := PackedInt32Array()
			for c in grp.cards:
				ids.append(c.id)
			# Verificar que la extensión es válida y cumple umbral si no abrió.
			var res: RuleResult = RulesEngine.can_meld(state, player_id, ids, meld.rank)
			if res.ok:
				return BotDecision.meld(ids, meld.rank)

	# 2. Buscar mejor meld nuevo. Priorizar rangos con más naturales.
	var ranks: Array[int] = HandAnalyzer.ranks_by_size_desc(a)
	var wilds_avail: int = a.wilds.size()
	# Reservar al menos 1 comodín para futuras capturas si no nos sobran.
	var wilds_usable: int = max(0, wilds_avail - 1)

	for r in ranks:
		var grp: HandAnalyzer.RankGroup = a.groups[r]
		var nat: int = grp.count()
		if nat < 3:
			continue
		# Plan A: meld puro (todos los naturales).
		var ids_pure := PackedInt32Array()
		for c in grp.cards:
			ids_pure.append(c.id)
		var res_pure: RuleResult = RulesEngine.can_meld(state, player_id, ids_pure, r)
		if res_pure.ok:
			return BotDecision.meld(ids_pure, r)

		# Plan B: añadir 1 comodín si disponible y nat ≥ 4 (cerca de canasta).
		if wilds_usable > 0 and nat >= GameConfig.MIN_NATURALS_FOR_IMPURE - 1:
			var ids_mix := ids_pure.duplicate()
			ids_mix.append(a.wilds[0].id)
			var res_mix: RuleResult = RulesEngine.can_meld(state, player_id, ids_mix, r)
			if res_mix.ok:
				return BotDecision.meld(ids_mix, r)

	# 3. Si no abrió y no llegamos al umbral con grupos sueltos: combinar grupos.
	if not team.opened:
		var combined: BotDecision = _try_open_with_combination(state, player_id, a)
		if combined != null:
			return combined

	return null


## Intenta abrir combinando 2 rangos (cada meld ≥3 naturales). Si los puntos
## sumados alcanzan el umbral, baja el de mayor puntos primero — el motor
## sólo permite UN meld por turno, así que dejamos al heurístico decidir
## cuál bajar primero. (Producir múltiples melds requeriría cambios FSM.)
static func _try_open_with_combination(
	state: MatchState, player_id: int, a: HandAnalyzer.Analysis
) -> BotDecision:
	var team: TeamState = state.team_of(player_id)
	var threshold: int = OpeningThreshold.required_for(team.cumulative_score)
	var ranks: Array[int] = HandAnalyzer.ranks_by_size_desc(a)
	var best: BotDecision = null
	var best_pts: int = -1
	for r in ranks:
		var grp: HandAnalyzer.RankGroup = a.groups[r]
		if grp.count() < 3:
			continue
		var ids := PackedInt32Array()
		var pts: int = 0
		for c in grp.cards:
			ids.append(c.id)
			pts += c.point_value
		if pts < threshold:
			continue
		var res: RuleResult = RulesEngine.can_meld(state, player_id, ids, r)
		if res.ok and pts > best_pts:
			best = BotDecision.meld(ids, r)
			best_pts = pts
	return best
