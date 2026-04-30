## Autoridad de red local (offline / vs Bots).
##
## Implementa `INetworkAuthority` sin red real. Usa `OfflineMultiplayerPeer`
## para que la API de RPC de Godot opere en modo single-peer (peer_id=1):
## todas las llamadas `rpc()` se ejecutan localmente sin viajar por red.
##
## Uso típico (escena VsBots):
##     var auth := LocalAuthority.new()
##     auth.host_match(0, 0)           # bootstraps OfflineMultiplayerPeer
##     var server := ServerMatch.new()
##     add_child(server)
##     server.setup(auth, MatchConfig.standard_2v2(seed), "Tú", uuid)
##     server.assign_bot(1, GameConfig.BotLevel.NORMAL)
##     server.assign_bot(2, GameConfig.BotLevel.NORMAL)
##     server.assign_bot(3, GameConfig.BotLevel.NORMAL)
##     # `_all_slots_filled()` arranca la partida automáticamente.
class_name LocalAuthority
extends INetworkAuthority

var _peer: OfflineMultiplayerPeer = null


func host_match(_port: int, _max_clients: int) -> int:
	_peer = OfflineMultiplayerPeer.new()
	multiplayer.multiplayer_peer = _peer
	connection_succeeded.emit()
	return OK


func join_match(_ip: String, _port: int) -> int:
	push_warning("LocalAuthority: join_match no aplica en offline")
	return ERR_UNAVAILABLE


func disconnect_peer() -> void:
	if multiplayer.multiplayer_peer == _peer:
		multiplayer.multiplayer_peer = null
	_peer = null


func is_host() -> bool:
	return true


func local_peer_id() -> int:
	return 1


func get_connected_peers() -> PackedInt32Array:
	return PackedInt32Array([1])
