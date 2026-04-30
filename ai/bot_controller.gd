## Driver de bots en el host autoritativo.
##
## Vive como hijo de `ServerMatch`. En cada `_process()` revisa:
##   1. ¿El `current_player` es un bot asignado? Si no → no-op.
##   2. ¿La FSM está en una fase que admite acción del bot
##      (DrawPhase | PlayPhase | DiscardPhase)?
##   3. ¿Hay una decisión pendiente programada? Si no → programa una con
##      delay (UX) y un timer de Godot.
##
## Al disparar el timer:
##   - Llama a `BotPlayer.decide(state, pid, phase)`.
##   - Valida la decisión vía `RulesEngine.can_*` y la ejecuta.
##   - Si éxito → `server.on_action_resolved(kind, pid, payload)`.
##   - Si falla → log + fallback (pass_play o discard de la primera carta)
##     para evitar deadlock.
##
## Seguridad:
##   - Sólo se ejecuta en host. Los clientes nunca lo instancian.
##   - El bot NO puede leer `state.hands[other_player]` por convención
##     (el `BotPlayer.decide` recibe el state completo pero por contrato
##     sólo accede a su propia mano y al estado público).
class_name BotController
extends Node

## Mapa player_id → BotPlayer | null. Slot null = humano.
var bots: Array[BotPlayer] = []

## Server padre (ServerMatch).
var server: Node = null

## Flag por jugador: true si hay una decisión en vuelo (timer activo).
var _pending: PackedByteArray = PackedByteArray()


func setup(server_node: Node, n_players: int) -> void:
	server = server_node
	bots.resize(n_players)
	_pending.resize(n_players)
	for i in n_players:
		bots[i] = null
		_pending[i] = 0


## Asigna un bot al slot. `level` ∈ GameConfig.BotLevel.
func assign(player_id: int, level: int) -> void:
	if player_id < 0 or player_id >= bots.size():
		return
	bots[player_id] = _create_bot(level)


## Quita el bot del slot (cuando un humano reconecta o ocupa el slot).
func unassign(player_id: int) -> void:
	if player_id < 0 or player_id >= bots.size():
		return
	bots[player_id] = null
	_pending[player_id] = 0


func is_bot(player_id: int) -> bool:
	if player_id < 0 or player_id >= bots.size():
		return false
	return bots[player_id] != null


func _create_bot(level: int) -> BotPlayer:
	match level:
		GameConfig.BotLevel.EASY:
			return EasyBot.new()
		GameConfig.BotLevel.HARD:
			return HardBot.new()
		_:
			return NormalBot.new()


func _process(_delta: float) -> void:
	if server == null:
		return
	var state: MatchState = server.match_state
	if state == null or state.match_finished:
		return
	var pid: int = state.current_player
	if not is_bot(pid):
		return
	if _pending[pid] != 0:
		return
	if server.fsm == null or server.fsm.current == null:
		return
	var phase: String = server.fsm.current.name()
	if phase != "DrawPhase" and phase != "PlayPhase" and phase != "DiscardPhase":
		return

	# Programar la decisión.
	_pending[pid] = 1
	if GameConfig.bot_instant:
		_execute_decision(pid, phase)
	else:
		var delay_ms: int = RngService.match_rng.randi_range(
			GameConfig.BOT_THINK_MIN_MS, GameConfig.BOT_THINK_MAX_MS
		)
		var timer: SceneTreeTimer = get_tree().create_timer(float(delay_ms) / 1000.0)
		timer.timeout.connect(_on_think_timeout.bind(pid, phase), CONNECT_ONE_SHOT)


func _on_think_timeout(pid: int, phase: String) -> void:
	# La FSM puede haber cambiado mientras esperábamos (ej. desconexión,
	# match end). Revalidar antes de actuar.
	var state: MatchState = server.match_state
	if state == null or state.match_finished:
		_pending[pid] = 0
		return
	if state.current_player != pid:
		_pending[pid] = 0
		return
	if server.fsm == null or server.fsm.current == null:
		_pending[pid] = 0
		return
	var phase_now: String = server.fsm.current.name()
	if phase_now != phase:
		# La fase ya cambió; reprogramaremos en el próximo `_process` con la nueva.
		_pending[pid] = 0
		return
	_execute_decision(pid, phase)


func _execute_decision(pid: int, phase: String) -> void:
	var bot: BotPlayer = bots[pid]
	if bot == null:
		_pending[pid] = 0
		return
	var decision: BotDecision = bot.decide(server.match_state, pid, phase)
	if decision == null:
		decision = _safe_fallback(phase, pid)

	var ok: bool = _apply(decision, pid)
	if not ok:
		# Fallback: aplicar acción mínima para evitar deadlock.
		var fb: BotDecision = _safe_fallback(phase, pid)
		_apply(fb, pid)
	_pending[pid] = 0


func _safe_fallback(phase: String, pid: int) -> BotDecision:
	match phase:
		"DrawPhase":
			return BotDecision.draw()
		"PlayPhase":
			return BotDecision.pass_play()
		"DiscardPhase":
			var hand: Array = server.match_state.hands[pid]
			for c in hand:
				if not (c as Card).is_red_three and not (c as Card).is_wildcard:
					return BotDecision.discard((c as Card).id)
			# Sólo comodines / treses rojos: descartar el primero no-rojo.
			for c in hand:
				if not (c as Card).is_red_three:
					return BotDecision.discard((c as Card).id)
			return BotDecision.discard(-1)
		_:
			return BotDecision.pass_play()


## Aplica la decisión vía `RulesEngine`. Si éxito, llama a
## `server.on_action_resolved`. Devuelve true si tuvo éxito.
func _apply(d: BotDecision, pid: int) -> bool:
	var state: MatchState = server.match_state
	var res: RuleResult
	var payload: Dictionary
	match d.kind:
		"draw":
			res = RulesEngine.draw_from_deck(state, pid)
			payload = {"player_id": pid}
		"capture":
			res = RulesEngine.execute_capture_pozo(state, pid, d.card_ids)
			payload = {"player_id": pid, "claim_ids": d.card_ids}
		"meld":
			res = RulesEngine.execute_meld(state, pid, d.card_ids, d.declared_rank)
			payload = {"player_id": pid, "card_ids": d.card_ids, "declared_rank": d.declared_rank}
		"close":
			var team: TeamState = state.team_of(pid)
			var in_hand: bool = not team.opened
			res = RulesEngine.execute_close(state, pid, in_hand)
			payload = {"player_id": pid}
		"pass_play":
			res = RulesEngine.can_pass_play(state, pid)
			payload = {"player_id": pid}
		"discard":
			res = RulesEngine.execute_discard(state, pid, d.target_card_id)
			payload = {"player_id": pid, "card_id": d.target_card_id}
		_:
			push_warning("BotController: kind desconocido %s" % d.kind)
			return false

	if not res.ok:
		push_warning("BotController: regla rechazada kind=%s reason=%s pid=%d"
			% [d.kind, res.reason, pid])
		return false

	server.on_action_resolved(d.kind, pid, payload)
	return true
