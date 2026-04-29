## Interfaz mínima de autoridad de red.
##
## Esta capa abstrae el transporte concreto (ENet en F5; servidor neutral
## en F10). El resto del juego (`RpcRouter`, `ServerMatch`, `Lobby`) sólo
## conoce esta API. Cambiar de transporte = swap de implementación, sin
## tocar lógica de juego.
##
## Convención de IDs:
##   - `peer_id`: id de transporte (1 = host en ENet; >1 clientes).
##   - `player_id`: id de slot de juego (0..n_players-1). Asignado por el
##     host cuando todos los peers están listos. Determinista a partir del
##     orden de unión (player 0 = host por defecto).
##
## Esta clase es un "interface" en sentido GDScript: define la firma. Las
## subclases implementan los métodos. Los `push_error` por defecto sirven
## para detectar usos contra una autoridad mock no inicializada.
class_name INetworkAuthority
extends Node

## Conexión establecida (cliente). En el host se emite implícitamente.
signal connection_succeeded()

## Falla de conexión (cliente). El cliente debe volver al lobby.
signal connection_failed(reason: String)

## Servidor cerrado (cliente recibe). Match abortada.
signal server_disconnected()

## Nuevo peer entró. En host: cualquier cliente. En cliente: otros peers.
signal peer_connected(peer_id: int)

## Peer salió. Host debe pausar el match si era un jugador activo.
signal peer_disconnected(peer_id: int)


## Inicia el rol de host. Devuelve OK o un Error de Godot.
func host_match(_port: int, _max_clients: int) -> int:
	push_error("INetworkAuthority.host_match no implementado")
	return ERR_UNCONFIGURED


## Inicia el rol de cliente conectándose a `ip:port`.
func join_match(_ip: String, _port: int) -> int:
	push_error("INetworkAuthority.join_match no implementado")
	return ERR_UNCONFIGURED


## Cierra el peer activo (sin importar el rol).
func disconnect_peer() -> void:
	push_error("INetworkAuthority.disconnect_peer no implementado")


## Devuelve true si este peer es el host autoritativo.
func is_host() -> bool:
	return false


## Id de transporte local (1 si host, >1 si cliente, 0 si desconectado).
func local_peer_id() -> int:
	return 0


## Lista de peer_ids actualmente conectados (incluido el local en host).
func get_connected_peers() -> PackedInt32Array:
	return PackedInt32Array()
