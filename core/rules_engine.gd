## Motor de reglas autoritativo de Canasta Uruguaya.
##
## Diseño:
##   - Funciones puras de validación: reciben `MatchState` + parámetros y
##     devuelven `RuleResult`. NO mutan.
##   - Funciones de ejecución: validan y, si pasa, mutan el estado.
##     Devuelven `RuleResult` para reflejar éxito/fracaso.
##   - Todo el estado mutable vive en `MatchState` y se modifica únicamente
##     por este módulo (o por el `RngService` para el robo).
##
## Códigos de error (`RuleResult.reason`):
##   "not_your_turn"      acción intentada por jugador que no es current_player
##   "pozo_taponado"      captura intentada con Tres Negro arriba
##   "pozo_empty"         captura intentada con pozo vacío
##   "no_match"           cartas reclamadas no forman/extienden meld del rango top
##   "no_pairs"           menos de 2 naturales del rango top entre claim+top
##   "below_threshold"    suma del meld no llega al umbral de apertura
##   "invalid_meld"       composición de cartas inválida (rangos mezclados, ratio comodines)
##   "cards_not_in_hand"  alguna carta reclamada no está en la mano del jugador
##   "wild_in_crossed"    se intenta usar comodín de la mano cuando pozo está cruzado
##   "cannot_close"       cierre rechazado (faltan canastas pura/impura o no es turno)
##   "no_red_three_meld"  no se permite formar meld con TRES rojo
class_name RulesEngine
extends RefCounted


# ---------------------------------------------------------------------------
# 1. Inicialización de mano
# ---------------------------------------------------------------------------

## Reparte cartas iniciales a todos los jugadores y configura el pozo.
## - Reparte `hand_size_for(n_players)` cartas a cada jugador.
## - Extrae automáticamente Treses Rojos a la zona del equipo y rellena.
## - Pone una carta visible en el pozo. Si es Tres Rojo: lo entierra y vuelve.
## - Si la primera carta del pozo es Tres Negro: queda taponado desde inicio.
##
## Pre: `state.deck` debe estar mezclado.
static func deal_initial(state: MatchState) -> void:
	var hs: int = GameConfig.hand_size_for(state.config.n_players)
	for p in range(state.config.n_players):
		var dealt: Array[Card] = state.deck.draw_n(hs)
		state.hands[p] = dealt
	# Treses rojos en mano inicial → al equipo, robar reemplazo.
	for p in range(state.config.n_players):
		_resolve_red_threes(state, p)
	# Carta inicial del pozo.
	state.pozo = PozoController.new()
	while not state.deck.is_empty():
		var c: Card = state.deck.draw_n(1)[0]
		if c.is_red_three:
			# Entierra el rojo en el fondo del mazo (regla canasta clásica).
			state.deck.cards.append(c)
			continue
		state.pozo.push(c)
		break


# ---------------------------------------------------------------------------
# 2. Robo de cartas (fase de robo: 2 cartas obligatorias)
# ---------------------------------------------------------------------------

## El jugador roba `DRAW_COUNT_PER_TURN` cartas del mazo. Resuelve treses rojos.
## Devuelve éxito siempre (mientras haya mazo). Si el mazo se agota, devuelve
## las cartas que pudo robar (puede ser 0 → fin de la mano por agotamiento).
static func draw_from_deck(state: MatchState, player_id: int) -> RuleResult:
	if player_id != state.current_player:
		return RuleResult.failure("not_your_turn")
	var drawn: Array[Card] = state.deck.draw_n(GameConfig.DRAW_COUNT_PER_TURN)
	for c in drawn:
		(state.hands[player_id] as Array).append(c)
	_resolve_red_threes(state, player_id)
	if state.deck.is_empty() and drawn.size() < GameConfig.DRAW_COUNT_PER_TURN:
		# Mazo agotado durante el robo → la mano debe terminar.
		state.hand_finished = true
	return RuleResult.success()


# ---------------------------------------------------------------------------
# 3. Captura del pozo
# ---------------------------------------------------------------------------

## Valida que el jugador pueda capturar el pozo usando ciertas cartas de su mano.
##
## `claim_card_ids` son los ids de cartas de la MANO que se usarán junto con
## el TOP del pozo (y posiblemente extendiendo un meld existente del equipo)
## para formar un meld válido.
##
## Reglas:
##   1. Pozo no vacío y no taponado.
##   2. Las cartas reclamadas están todas en la mano del jugador.
##   3. Top + cartas reclamadas (+ meld existente si extiende) forman meld válido.
##   4. Pozo cruzado: las cartas reclamadas no incluyen comodines.
##   5. Hay al menos 2 naturales del rango natural objetivo entre las cartas
##      reclamadas + top (regla "dos naturales").
##   6. Si el equipo no abrió → la suma de puntos del meld total resultante
##      cumple el umbral de apertura.
static func can_capture_pozo(
	state: MatchState,
	player_id: int,
	claim_card_ids: PackedInt32Array
) -> RuleResult:
	if player_id != state.current_player:
		return RuleResult.failure("not_your_turn")
	if state.pozo == null or state.pozo.is_empty():
		return RuleResult.failure("pozo_empty")
	if state.pozo.is_taponado():
		return RuleResult.failure("pozo_taponado")

	var hand: Array = state.hands[player_id]
	var claimed: Array[Card] = []
	for cid in claim_card_ids:
		var found: Card = null
		for c in hand:
			if (c as Card).id == cid:
				found = c
				break
		if found == null:
			return RuleResult.failure("cards_not_in_hand")
		claimed.append(found)

	var top: Card = state.pozo.top()
	var is_crossed: bool = state.pozo.is_cruzado()

	# Pozo cruzado: claimed no debe contener comodines (regla casa estricta).
	if is_crossed:
		for c in claimed:
			if c.is_wildcard:
				return RuleResult.failure("wild_in_crossed")

	# Determinar rango natural objetivo.
	var target_rank: int = state.pozo.capturable_rank()
	if target_rank == -1:
		return RuleResult.failure("no_match")
	if target_rank == GameConfig.Rank.THREE:
		# No se forman melds de TRES.
		return RuleResult.failure("no_red_three_meld")

	# El meld resultante incluye top + claimed (+ meld existente si lo hay).
	var team: TeamState = state.team_of(player_id)
	var existing: Meld = team.find_meld_by_rank(target_rank)
	var virtual: Array[Card] = []
	if existing != null:
		for c in existing.cards:
			virtual.append(c)
	virtual.append(top)
	for c in claimed:
		virtual.append(c)

	if not Meld.is_valid_composition(target_rank, virtual):
		return RuleResult.failure("invalid_meld")

	# Regla "dos naturales" del rango entre top + claimed (no contar el meld
	# preexistente, porque la captura debe ser justificada por sí misma).
	var naturals_in_capture: int = 0
	if not top.is_wildcard and top.rank == target_rank:
		naturals_in_capture += 1
	for c in claimed:
		if not c.is_wildcard and c.rank == target_rank:
			naturals_in_capture += 1
	if naturals_in_capture < 2:
		return RuleResult.failure("no_pairs")

	# Umbral de apertura.
	if not team.opened:
		var pts: int = 0
		for c in virtual:
			pts += c.point_value
		# Restar lo que ya estaba en el meld preexistente (que es 0 porque si
		# `existing != null` significa que ya abrió; consistencia defensiva).
		if existing != null:
			for c in existing.cards:
				pts -= c.point_value
		if not OpeningThreshold.meets_threshold(team.cumulative_score, pts):
			return RuleResult.failure("below_threshold")

	return RuleResult.success()


## Ejecuta la captura del pozo. PRE: `can_capture_pozo` devolvió ok.
static func execute_capture_pozo(
	state: MatchState,
	player_id: int,
	claim_card_ids: PackedInt32Array
) -> RuleResult:
	var validation: RuleResult = can_capture_pozo(state, player_id, claim_card_ids)
	if not validation.ok:
		return validation

	var team: TeamState = state.team_of(player_id)
	var hand: Array = state.hands[player_id]
	# IMPORTANTE: calcular target_rank ANTES de vaciar el pozo.
	var target_rank: int = state.pozo.capturable_rank()
	var taken: Array[Card] = state.pozo.take_all()
	var claimed: Array[Card] = Hand.remove_by_ids(hand, claim_card_ids)

	# El meld de captura se compone del TOP + cartas reclamadas. El resto del
	# pozo (cartas debajo del top) va a la mano del jugador.
	var top: Card = taken[-1]
	var meld_cards: Array[Card] = []
	meld_cards.append(top)
	for c in claimed:
		meld_cards.append(c)

	# Cartas restantes del pozo (debajo del top): a la mano del jugador.
	for i in range(taken.size() - 1):
		(hand as Array).append(taken[i])

	# Crear o extender meld.
	var existing: Meld = team.find_meld_by_rank(target_rank)
	if existing == null:
		var new_meld: Meld = Meld.create(team.team_id, target_rank)
		var ok_add: bool = new_meld.add_cards(meld_cards)
		if not ok_add:
			# Caso defensivo: deberíamos haber validado, pero si falla, deshacer.
			return RuleResult.failure("invalid_meld")
		team.melds.append(new_meld)
	else:
		var ok_ext: bool = existing.add_cards(meld_cards)
		if not ok_ext:
			return RuleResult.failure("invalid_meld")

	team.opened = true
	return RuleResult.success()


# ---------------------------------------------------------------------------
# 4. Bajar combinación nueva desde la mano
# ---------------------------------------------------------------------------

## Valida que el jugador pueda bajar un meld nuevo (rango distinto de los ya
## abiertos por su equipo) usando cartas de su mano.
static func can_meld(
	state: MatchState,
	player_id: int,
	card_ids: PackedInt32Array,
	declared_rank: int
) -> RuleResult:
	if player_id != state.current_player:
		return RuleResult.failure("not_your_turn")

	var hand: Array = state.hands[player_id]
	var claimed: Array[Card] = []
	for cid in card_ids:
		var found: Card = null
		for c in hand:
			if (c as Card).id == cid:
				found = c
				break
		if found == null:
			return RuleResult.failure("cards_not_in_hand")
		claimed.append(found)

	if not Meld.is_valid_composition(declared_rank, claimed):
		return RuleResult.failure("invalid_meld")

	var team: TeamState = state.team_of(player_id)
	if not team.opened:
		var pts: int = 0
		for c in claimed:
			pts += c.point_value
		if not OpeningThreshold.meets_threshold(team.cumulative_score, pts):
			return RuleResult.failure("below_threshold")
	return RuleResult.success()


## Ejecuta el meld. PRE: `can_meld` devolvió ok.
static func execute_meld(
	state: MatchState,
	player_id: int,
	card_ids: PackedInt32Array,
	declared_rank: int
) -> RuleResult:
	var v: RuleResult = can_meld(state, player_id, card_ids, declared_rank)
	if not v.ok:
		return v
	var team: TeamState = state.team_of(player_id)
	var hand: Array = state.hands[player_id]
	var removed: Array[Card] = Hand.remove_by_ids(hand, card_ids)

	var existing: Meld = team.find_meld_by_rank(declared_rank)
	if existing == null:
		var nm: Meld = Meld.create(team.team_id, declared_rank)
		nm.add_cards(removed)
		team.melds.append(nm)
	else:
		existing.add_cards(removed)
	team.opened = true
	return RuleResult.success()


# ---------------------------------------------------------------------------
# 5. Descarte
# ---------------------------------------------------------------------------

static func can_discard(state: MatchState, player_id: int, card_id: int) -> RuleResult:
	if player_id != state.current_player:
		return RuleResult.failure("not_your_turn")
	for c in state.hands[player_id]:
		if (c as Card).id == card_id:
			return RuleResult.success()
	return RuleResult.failure("cards_not_in_hand")


static func execute_discard(state: MatchState, player_id: int, card_id: int) -> RuleResult:
	var v: RuleResult = can_discard(state, player_id, card_id)
	if not v.ok:
		return v
	var hand: Array = state.hands[player_id]
	var idx: int = -1
	for i in range(hand.size()):
		if (hand[i] as Card).id == card_id:
			idx = i
			break
	var card: Card = hand[idx]
	hand.remove_at(idx)
	state.pozo.push(card)
	return RuleResult.success()


# ---------------------------------------------------------------------------
# 6. Cierre de mano
# ---------------------------------------------------------------------------

static func can_close(state: MatchState, player_id: int) -> RuleResult:
	if player_id != state.current_player:
		return RuleResult.failure("not_your_turn")
	var team: TeamState = state.team_of(player_id)
	if not team.can_close():
		return RuleResult.failure("cannot_close")
	return RuleResult.success()


## Marca la mano como cerrada por el jugador. Pre: `can_close` ok.
## `in_hand`: pasar `true` si el equipo NO había abierto al comienzo de este
## turno (cierre en mano = bono extra de 200 pts al calcular puntaje).
static func execute_close(state: MatchState, player_id: int, in_hand: bool = false) -> RuleResult:
	var v: RuleResult = can_close(state, player_id)
	if not v.ok:
		return v
	state.hand_finished = true
	state.closer_player_id = player_id
	state.closer_closed_in_hand = in_hand
	return RuleResult.success()


## Acción "pasar fase de juego": el jugador no quiere/no puede meldear y
## fuerza la transición PlayPhase → DiscardPhase. La FSM la consume vía
## `mark_resolved` en `ServerMatch.on_action_resolved`.
##
## No muta el estado: sólo valida turno. El caller (RpcRouter) además debe
## verificar que la fase FSM actual sea PlayPhase para evitar saltarse
## DrawPhase u otra etapa.
static func can_pass_play(state: MatchState, player_id: int) -> RuleResult:
	if player_id != state.current_player:
		return RuleResult.failure("not_your_turn")
	return RuleResult.success()


# ---------------------------------------------------------------------------
# Helpers internos
# ---------------------------------------------------------------------------

## Mueve los treses rojos de la mano del jugador a la zona de su equipo y
## roba reemplazo del mazo (si quedan cartas). Recursivo: si el reemplazo
## también es Tres Rojo, vuelve a robar.
static func _resolve_red_threes(state: MatchState, player_id: int) -> void:
	var hand: Array = state.hands[player_id]
	var team: TeamState = state.team_of(player_id)
	while true:
		var rts: Array[Card] = Hand.extract_red_threes(hand)
		if rts.is_empty():
			break
		for rt in rts:
			team.red_threes.append(rt)
		# Reemplazo (1 carta por cada rojo extraído). Si mazo se agota, salir.
		var need: int = rts.size()
		var replacement: Array[Card] = state.deck.draw_n(need)
		for c in replacement:
			hand.append(c)
		if replacement.size() < need:
			break
