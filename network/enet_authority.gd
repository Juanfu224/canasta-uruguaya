## Implementación de `INetworkAuthority` sobre `ENetMultiplayerPeer`.
##
## ENet provee transporte UDP confiable + ordenado por canales. Para Canasta
## (turn-based, low rate) las garantías de fiabilidad son suficientes; no
## necesitamos lockstep, predicción ni rollback.
##
## Configuración:
##   - Puerto fijo `GameConfig.NET_PORT_GAME` (8910).
##   - Compresión `COMPRESS_RANGE_CODER` (mejor ratio para texto/JSON).
##   - 4 channels reservados:
##       0 → control (handshake, lobby, snapshots completos)
##       1 → state diffs / broadcasts de turno
##       2 → manos privadas (dirigido por peer)
##       3 → animaciones / cues no críticos
##
## Seguridad:
##   - El host valida que el `peer_id` del sender coincide con el slot de
##     jugador esperado en cada RPC (via `RpcRouter`).
##   - DTLS opcional vía `set_dtls_*` cuando F10 (servidor neutral) lo
##     requiera. En LAN F5 lo dejamos off para simplicidad.
##   - Rate limiting se hace en `RpcRouter` (capa superior).
class_name EnetAuthority
extends INetworkAuthority

const _CHANNEL_COUNT: int = 4

var _peer: ENetMultiplayerPeer = null
var _is_host: bool = false


func _ready() -> void:
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)


func host_match(port: int, max_clients: int) -> int:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, max_clients, _CHANNEL_COUNT)
	if err != OK:
		push_error("EnetAuthority.host_match: create_server falló (%d)" % err)
		return err
	# Compresión activa solo si no estamos en headless test (acelera CI).
	peer.host.compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.multiplayer_peer = peer
	_peer = peer
	_is_host = true
	# Host emite explícitamente connection_succeeded para simetría con clientes.
	connection_succeeded.emit()
	return OK


func join_match(ip: String, port: int) -> int:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port, _CHANNEL_COUNT)
	if err != OK:
		push_error("EnetAuthority.join_match: create_client falló (%d)" % err)
		return err
	peer.host.compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.multiplayer_peer = peer
	_peer = peer
	_is_host = false
	return OK


func disconnect_peer() -> void:
	if _peer == null:
		return
	_peer.close()
	multiplayer.multiplayer_peer = null
	_peer = null
	_is_host = false


func is_host() -> bool:
	return _is_host and _peer != null


func local_peer_id() -> int:
	if _peer == null:
		return 0
	return multiplayer.get_unique_id()


func get_connected_peers() -> PackedInt32Array:
	if _peer == null:
		return PackedInt32Array()
	var peers: Array = multiplayer.get_peers()
	var out := PackedInt32Array()
	out.resize(peers.size() + 1)
	out[0] = multiplayer.get_unique_id()
	for i in peers.size():
		out[i + 1] = peers[i]
	return out


# ---------------------------------------------------------------------------
# Bridges hacia las señales del MultiplayerAPI
# ---------------------------------------------------------------------------

func _on_connected_to_server() -> void:
	connection_succeeded.emit()


func _on_connection_failed() -> void:
	# Limpiar estado para permitir reintento.
	multiplayer.multiplayer_peer = null
	_peer = null
	connection_failed.emit("connection_failed")


func _on_server_disconnected() -> void:
	multiplayer.multiplayer_peer = null
	_peer = null
	server_disconnected.emit()


func _on_peer_connected(peer_id: int) -> void:
	peer_connected.emit(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	peer_disconnected.emit(peer_id)
