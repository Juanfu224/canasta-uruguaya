## Router de RPCs autoritativo (lado host) y emisor de requests (lado cliente).
##
## Es el único punto donde:
##   - Se aceptan acciones desde clientes vía RPC (`request_*`).
##   - Se valida la identidad del sender vs `MatchState.current_player`.
##   - Se aplica rate limiting por peer (defensa básica anti-spam).
##   - Se invoca `RulesEngine` y, en éxito, se notifica a todos los peers.
##
## Diseño de seguridad:
##   1. Todo `request_*` es `@rpc("any_peer", ...)` — cualquier cliente puede
##      llamarlo, pero el HOST decide si lo acepta. Los clientes NO ejecutan
##      la lógica del request en sí mismos.
##   2. Las notificaciones `notify_*` son `@rpc("authority", ...)` — sólo el
##      host las puede emitir. Godot bloquea automáticamente notificaciones
##      enviadas desde un peer no autoritativo.
##   3. El sender se obtiene siempre de `multiplayer.get_remote_sender_id()`,
##      nunca de un argumento del payload (que podría ser falsificado).
##   4. Token bucket por peer: máx `MAX_REQ_PER_S` requests/seg. Un peer que
##      excede el límite es ignorado silenciosamente para esa request (no
##      emitimos rechazo para no amplificar tráfico).
##   5. Tamaños de PackedInt32Array validados (0..MAX_CLAIM_CARDS).
##
## Esta clase corre en BOTH host y cliente. En cliente sólo se usan los
## métodos `client_*` para enviar requests. En host se procesan los
## handlers de las requests.
class_name RpcRouter
extends Node

const MAX_REQ_PER_S: float = 10.0
const TOKEN_BUCKET_CAPACITY: float = 12.0
const MAX_CLAIM_CARDS: int = 14  # mayor mano legal teórica + margen

# El servidor inyecta una referencia. En cliente queda null.
var server: Node = null  # tipo dinámico para evitar dependencia circular

# peer_id → {tokens: float, last_msec: int}
var _buckets: Dictionary = {}


# ---------------------------------------------------------------------------
# CLIENT-SIDE: helpers que envían requests al host (peer id 1).
# ---------------------------------------------------------------------------

func client_request_draw() -> void:
	rpc_id(1, "request_draw")

func client_request_capture(claim_ids: PackedInt32Array) -> void:
	rpc_id(1, "request_capture_pozo", claim_ids)

func client_request_meld(card_ids: PackedInt32Array, declared_rank: int) -> void:
	rpc_id(1, "request_meld", card_ids, declared_rank)

func client_request_discard(card_id: int) -> void:
	rpc_id(1, "request_discard", card_id)

func client_request_close() -> void:
	rpc_id(1, "request_close")

func client_request_pass_play() -> void:
	rpc_id(1, "request_pass_play")


# ---------------------------------------------------------------------------
# HOST-SIDE: handlers
# ---------------------------------------------------------------------------

@rpc("any_peer", "call_local", "reliable")
func request_draw() -> void:
	var ctx: Dictionary = _begin_request("draw")
	if ctx.is_empty():
		return
	var res: RuleResult = RulesEngine.draw_from_deck(server.match_state, ctx.player_id)
	_finish(ctx, res, "draw", {"player_id": ctx.player_id})


@rpc("any_peer", "call_local", "reliable")
func request_capture_pozo(claim_ids: PackedInt32Array) -> void:
	var ctx: Dictionary = _begin_request("capture")
	if ctx.is_empty():
		return
	if claim_ids.size() < 0 or claim_ids.size() > MAX_CLAIM_CARDS:
		_reject(ctx.peer_id, "capture", "invalid_payload")
		return
	var res: RuleResult = RulesEngine.execute_capture_pozo(server.match_state, ctx.player_id, claim_ids)
	_finish(ctx, res, "capture", {"player_id": ctx.player_id, "claim_ids": claim_ids})


@rpc("any_peer", "call_local", "reliable")
func request_meld(card_ids: PackedInt32Array, declared_rank: int) -> void:
	var ctx: Dictionary = _begin_request("meld")
	if ctx.is_empty():
		return
	if card_ids.size() <= 0 or card_ids.size() > MAX_CLAIM_CARDS:
		_reject(ctx.peer_id, "meld", "invalid_payload")
		return
	if declared_rank < 0 or declared_rank > GameConfig.Rank.JOKER:
		_reject(ctx.peer_id, "meld", "invalid_payload")
		return
	var res: RuleResult = RulesEngine.execute_meld(server.match_state, ctx.player_id, card_ids, declared_rank)
	_finish(ctx, res, "meld", {
		"player_id": ctx.player_id,
		"card_ids": card_ids,
		"declared_rank": declared_rank,
	})


@rpc("any_peer", "call_local", "reliable")
func request_discard(card_id: int) -> void:
	var ctx: Dictionary = _begin_request("discard")
	if ctx.is_empty():
		return
	if card_id < 0 or card_id >= GameConfig.TOTAL_CARDS:
		_reject(ctx.peer_id, "discard", "invalid_payload")
		return
	var res: RuleResult = RulesEngine.execute_discard(server.match_state, ctx.player_id, card_id)
	_finish(ctx, res, "discard", {"player_id": ctx.player_id, "card_id": card_id})


@rpc("any_peer", "call_local", "reliable")
func request_close() -> void:
	var ctx: Dictionary = _begin_request("close")
	if ctx.is_empty():
		return
	# Detectar "cierre en mano" — equipo no había abierto antes de este turno.
	var team: TeamState = server.match_state.team_of(ctx.player_id)
	var in_hand: bool = not team.opened
	var res: RuleResult = RulesEngine.execute_close(server.match_state, ctx.player_id, in_hand)
	_finish(ctx, res, "close", {"player_id": ctx.player_id})


## Pasa la fase de juego sin bajar meld. SOLO válido durante PlayPhase.
@rpc("any_peer", "call_local", "reliable")
func request_pass_play() -> void:
	var ctx: Dictionary = _begin_request("pass_play")
	if ctx.is_empty():
		return
	# Sólo aceptar si la FSM está en PlayPhase (evita saltarse DrawPhase).
	if server.fsm == null or server.fsm.current == null or server.fsm.current.name() != "PlayPhase":
		_reject(ctx.peer_id, "pass_play", "wrong_phase")
		return
	var res: RuleResult = RulesEngine.can_pass_play(server.match_state, ctx.player_id)
	_finish(ctx, res, "pass_play", {"player_id": ctx.player_id})


# ---------------------------------------------------------------------------
# HOST → CLIENTS: notificaciones de cambios autoritativos.
# ---------------------------------------------------------------------------

@rpc("authority", "call_local", "reliable")
func notify_action_resolved(kind: String, payload: Dictionary, revision: int) -> void:
	var cv: Node = get_meta("client_view", null)
	if cv != null:
		cv.on_action_resolved(kind, payload, revision)

@rpc("authority", "call_local", "reliable")
func notify_rule_rejected(kind: String, reason: String) -> void:
	var cv: Node = get_meta("client_view", null)
	if cv != null:
		cv.on_rule_rejected(kind, reason)

@rpc("authority", "call_local", "reliable")
func notify_turn_advanced(new_current_player: int, phase: String) -> void:
	var cv: Node = get_meta("client_view", null)
	if cv != null:
		cv.on_turn_advanced(new_current_player, phase)

@rpc("authority", "call_local", "reliable")
func client_set_private_hand(card_ids: PackedInt32Array, revision: int) -> void:
	var cv: Node = get_meta("client_view", null)
	if cv != null:
		cv.on_private_hand(card_ids, revision)

@rpc("authority", "call_local", "reliable")
func client_load_snapshot(snapshot_bytes: PackedByteArray) -> void:
	var cv: Node = get_meta("client_view", null)
	if cv != null:
		cv.on_snapshot(snapshot_bytes)


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

## Valida sender, rate limit y que el server esté inicializado. Devuelve un
## diccionario `{peer_id, player_id}` o vacío si la request fue descartada.
func _begin_request(kind: String) -> Dictionary:
	if server == null or not server.has_method("get_match_state"):
		return {}
	var peer_id: int = multiplayer.get_remote_sender_id()
	if peer_id == 0:
		# Self-call local del host (offline / vs Bots) — usar el id propio.
		peer_id = multiplayer.get_unique_id()
	if not _consume_token(peer_id):
		# Excedió rate limit. Silencioso para no amplificar.
		push_warning("RpcRouter: rate-limit peer=%d kind=%s" % [peer_id, kind])
		return {}
	var player_id: int = server.peer_to_player(peer_id)
	if player_id < 0:
		_reject(peer_id, kind, "unknown_peer")
		return {}
	return {"peer_id": peer_id, "player_id": player_id}


func _finish(ctx: Dictionary, res: RuleResult, kind: String, payload: Dictionary) -> void:
	if not res.ok:
		_reject(ctx.peer_id, kind, res.reason)
		return
	server.on_action_resolved(kind, ctx.player_id, payload)


func _reject(peer_id: int, kind: String, reason: String) -> void:
	rpc_id(peer_id, "notify_rule_rejected", kind, reason)


## Token bucket: cada peer tiene capacidad `TOKEN_BUCKET_CAPACITY` y se
## rellena a `MAX_REQ_PER_S` tokens/seg. Una request consume 1.
func _consume_token(peer_id: int) -> bool:
	var now_msec: int = Time.get_ticks_msec()
	var bucket: Dictionary = _buckets.get(peer_id, {
		"tokens": TOKEN_BUCKET_CAPACITY,
		"last_msec": now_msec,
	})
	var dt_s: float = float(now_msec - int(bucket.last_msec)) / 1000.0
	var refilled: float = mini(TOKEN_BUCKET_CAPACITY, float(bucket.tokens) + dt_s * MAX_REQ_PER_S)
	if refilled < 1.0:
		bucket.tokens = refilled
		bucket.last_msec = now_msec
		_buckets[peer_id] = bucket
		return false
	bucket.tokens = refilled - 1.0
	bucket.last_msec = now_msec
	_buckets[peer_id] = bucket
	return true


## El servidor llama esto al desconectarse un peer para liberar memoria.
func forget_peer(peer_id: int) -> void:
	_buckets.erase(peer_id)
