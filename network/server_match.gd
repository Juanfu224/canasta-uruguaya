## Orquestador autoritativo de la partida (HOST).
##
## Sólo se instancia en el host. Posee:
##   - `MatchState` autoritativo.
##   - `GameStateMachine` que dirige el flujo (DrawPhase, PlayPhase, ...).
##   - `RpcRouter` que recibe requests y entrega notificaciones.
##   - `Reconnection` para persistir snapshots.
##
## Responsabilidades:
##   1. Asignar peers a slots de jugador (player_id 0..n-1) en orden de
##      conexión. El host SIEMPRE es player 0 (peer_id == 1).
##   2. Driver de FSM: cada `tick()` empuja el estado un paso. Es seguro
##      llamar repetidamente; los estados son idempotentes hasta que se
##      cumple la condición de transición.
##   3. Tras cada acción autoritativa exitosa:
##        a. Incrementar `_revision` (anti-replay y orden monotónico).
##        b. Marcar la fase FSM como resuelta (`mark_resolved`).
##        c. Tickear FSM hasta estabilizar.
##        d. Broadcast `notify_action_resolved` con payload público.
##        e. Enviar mano privada actualizada SOLO al jugador afectado.
##        f. Persistir snapshot atómico (throttled).
##   4. En reconexión: detectar peer conocido y enviar snapshot completo.
##
## Threading: todo single-threaded en el main loop de Godot. Los handlers
## de RPC se ejecutan en el frame del polling de `multiplayer`.
class_name ServerMatch
extends Node

signal match_started()
signal match_ended()
signal player_joined(player_id: int, peer_id: int, nickname: String)
signal player_left(player_id: int)

var match_id: String = ""
var match_state: MatchState = null
var fsm: GameStateMachine = null
var rpc_router: RpcRouter = null

var _network: INetworkAuthority = null
var _reconnection: Reconnection = null
var _config: MatchConfig = null

# Slot assignment.
# player_id (0..n-1) → peer_id; -1 si vacante.
var _player_to_peer: PackedInt32Array = PackedInt32Array()
# peer_id → player_id (también permite reconectar a un peer con UUID conocido).
var _peer_to_player_map: Dictionary = {}
# player_id → nickname (UI / lobby).
var _player_nicknames: PackedStringArray = PackedStringArray()
# Identidad estable cliente (UUID profile) → player_id, para reconexión.
var _uuid_to_player: Dictionary = {}

var _revision: int = 0
var _started: bool = false


# ---------------------------------------------------------------------------
# Inicialización
# ---------------------------------------------------------------------------

func setup(network: INetworkAuthority, config: MatchConfig, host_nickname: String, host_uuid: String) -> void:
	assert(network != null, "ServerMatch.setup: network requerido")
	assert(config != null, "ServerMatch.setup: config requerido")
	assert(network.is_host(), "ServerMatch.setup: solo el host instancia esto")
	_network = network
	_config = config
	match_id = RoomCode.generate()
	_reconnection = Reconnection.new()

	_player_to_peer.resize(config.n_players)
	_player_nicknames.resize(config.n_players)
	for i in config.n_players:
		_player_to_peer[i] = -1
		_player_nicknames[i] = ""

	# Asignar slot 0 al host.
	var host_peer: int = network.local_peer_id()
	_assign_slot(0, host_peer, host_nickname, host_uuid)

	# Crear router como hijo (Godot necesita NodePath para RPC).
	rpc_router = RpcRouter.new()
	rpc_router.name = "RpcRouter"
	rpc_router.server = self
	add_child(rpc_router)

	# Conectar señales del transporte.
	_network.peer_connected.connect(_on_peer_connected)
	_network.peer_disconnected.connect(_on_peer_disconnected)


# ---------------------------------------------------------------------------
# Ciclo de match
# ---------------------------------------------------------------------------

## Comienza la partida. Pre: todos los slots ocupados (ó forzado).
func start_match() -> void:
	assert(not _started, "ServerMatch: ya iniciado")
	# Inicializar RNG determinista.
	var seed: int = _config.seed if _config.seed != 0 else RngService.start_match(0)
	if _config.seed == 0:
		_config.seed = seed
	match_state = MatchState.create(_config)
	match_state.deck = Deck.build_standard_108()
	match_state.deck.shuffle(RngService.match_rng)
	RulesEngine.deal_initial(match_state)

	fsm = GameStateMachine.new(match_state)
	fsm.start(load("res://fsm/states/state_init_match.gd") as Script)
	# Tickear hasta DrawPhase del primer jugador.
	_tick_until_stable()
	_started = true
	_revision = 1

	# Broadcast estado inicial a todos los clientes.
	_broadcast_full_snapshot(false)
	_send_private_hands_to_all()
	match_started.emit()


func _process(_delta: float) -> void:
	if _started and not match_state.match_finished:
		# Tick "vacío" sólo si el estado puede transicionar sin acción del
		# jugador (p.ej. RoundEnd → SetupPozo). Estados que esperan acción
		# (DrawPhase, PlayPhase, DiscardPhase) son no-op aquí.
		_tick_until_stable()
		if match_state.match_finished:
			_revision += 1
			rpc_router.rpc("notify_action_resolved", "match_end", {}, _revision)
			match_ended.emit()
			Reconnection.delete_for(match_id)


func _tick_until_stable() -> void:
	# Limita a N transiciones para evitar loops infinitos por bug.
	var max_steps: int = 32
	while max_steps > 0:
		var changed: bool = fsm.tick()
		if not changed:
			break
		max_steps -= 1


# ---------------------------------------------------------------------------
# Slot management / connection
# ---------------------------------------------------------------------------

func _assign_slot(player_id: int, peer_id: int, nickname: String, uuid: String) -> void:
	_player_to_peer[player_id] = peer_id
	_player_nicknames[player_id] = nickname
	_peer_to_player_map[peer_id] = player_id
	if not uuid.is_empty():
		_uuid_to_player[uuid] = player_id
	player_joined.emit(player_id, peer_id, nickname)


func _on_peer_connected(peer_id: int) -> void:
	# El handshake real (nickname/uuid) lo hace una RPC del cliente. Aquí
	# sólo creamos un slot tentativo si hay vacante.
	pass  # se completa en `register_client`


## Llamado por el cliente recién conectado vía RPC `client_register` (handler
## en RpcRouter o aquí; preferimos aquí para mantener la lógica concentrada).
@rpc("any_peer", "call_remote", "reliable")
func register_client(nickname: String, uuid: String) -> void:
	var peer_id: int = multiplayer.get_remote_sender_id()
	if peer_id == 0:
		return
	# Saneo defensivo del nickname.
	var clean_nick: String = LanDiscovery._sanitize_nickname(nickname)
	# Reconexión: ¿UUID conocido?
	if _uuid_to_player.has(uuid):
		var pid: int = _uuid_to_player[uuid]
		# Reasignar peer_id al slot existente.
		var old_peer: int = _player_to_peer[pid]
		_peer_to_player_map.erase(old_peer)
		_player_to_peer[pid] = peer_id
		_peer_to_player_map[peer_id] = pid
		# Enviar snapshot completo + mano privada.
		_send_snapshot_to_peer(peer_id)
		return
	# Nuevo jugador: ¿hay slot vacante?
	for p in _config.n_players:
		if _player_to_peer[p] == -1:
			_assign_slot(p, peer_id, clean_nick, uuid)
			# Si todos los slots se llenaron y la partida no comenzó, arrancar.
			if not _started and _all_slots_filled():
				start_match()
			else:
				_send_snapshot_to_peer(peer_id)
			return
	# Sin vacantes — desconectar al peer.
	_network.disconnect_peer()  # close del peer concreto requeriría API extra


func _all_slots_filled() -> bool:
	for p in _config.n_players:
		if _player_to_peer[p] == -1:
			return false
	return true


func _on_peer_disconnected(peer_id: int) -> void:
	if not _peer_to_player_map.has(peer_id):
		return
	var pid: int = _peer_to_player_map[peer_id]
	_peer_to_player_map.erase(peer_id)
	_player_to_peer[pid] = -1
	rpc_router.forget_peer(peer_id)
	player_left.emit(pid)
	# No removemos `_uuid_to_player[uuid] = pid` para permitir reconexión.


# ---------------------------------------------------------------------------
# Hooks llamados por RpcRouter
# ---------------------------------------------------------------------------

func get_match_state() -> MatchState:
	return match_state

func peer_to_player(peer_id: int) -> int:
	return _peer_to_player_map.get(peer_id, -1)

func player_to_peer(player_id: int) -> int:
	if player_id < 0 or player_id >= _player_to_peer.size():
		return -1
	return _player_to_peer[player_id]

## Llamado por RpcRouter tras una acción autoritativa exitosa.
func on_action_resolved(kind: String, player_id: int, payload: Dictionary) -> void:
	# Marcar fase FSM como resuelta. Cada estado expone `mark_resolved`.
	if fsm != null and fsm.current != null and fsm.current.has_method("mark_resolved"):
		fsm.current.mark_resolved()
	_tick_until_stable()
	_revision += 1

	# Broadcast notificación pública.
	rpc_router.rpc("notify_action_resolved", kind, payload, _revision)

	# Enviar manos privadas afectadas.
	_send_private_hand_to_player(player_id)
	# En captura, el pozo cambia para todos pero las manos no de los demás.
	# En descarte, sólo el propio jugador. Para simplicidad enviamos sólo
	# al actor; el resto recibe su delta al inicio de su turno (próx fase).

	# Si la fase cambió a DrawPhase del próximo, avisar.
	if fsm != null and fsm.current != null:
		rpc_router.rpc("notify_turn_advanced", match_state.current_player, fsm.current.name())

	# Persistir snapshot.
	if _reconnection != null:
		var snap := MatchSnapshot.from_match_state(
			match_state, match_id, _revision, _config.seed, fsm.current.name() if fsm.current else "",
			true,
		)
		_reconnection.save_throttled(snap)


# ---------------------------------------------------------------------------
# Snapshot / mano privada
# ---------------------------------------------------------------------------

func _broadcast_full_snapshot(include_private: bool) -> void:
	var snap := MatchSnapshot.from_match_state(
		match_state, match_id, _revision, _config.seed,
		fsm.current.name() if fsm.current else "",
		include_private,
	)
	var bytes: PackedByteArray = Reconnection.to_bytes(snap)
	rpc_router.rpc("client_load_snapshot", bytes)


func _send_snapshot_to_peer(peer_id: int) -> void:
	var snap := MatchSnapshot.from_match_state(
		match_state, match_id, _revision, _config.seed,
		fsm.current.name() if fsm.current else "",
		false,
	)
	var bytes: PackedByteArray = Reconnection.to_bytes(snap)
	rpc_router.rpc_id(peer_id, "client_load_snapshot", bytes)
	# Enviar mano privada del player asociado.
	var pid: int = _peer_to_player_map.get(peer_id, -1)
	if pid >= 0:
		_send_private_hand_to_player(pid)


func _send_private_hand_to_all() -> void:
	for p in _config.n_players:
		_send_private_hand_to_player(p)


func _send_private_hand_to_player(player_id: int) -> void:
	if player_id < 0 or player_id >= match_state.hands.size():
		return
	var peer_id: int = _player_to_peer[player_id]
	if peer_id <= 0:
		return  # vacante o desconectado
	if peer_id == _network.local_peer_id():
		# El host es ese jugador: no enviar RPC a sí mismo (la UI lee directo).
		return
	var ids := PackedInt32Array()
	for c in match_state.hands[player_id]:
		ids.append((c as Card).id)
	rpc_router.rpc_id(peer_id, "client_set_private_hand", ids, _revision)
