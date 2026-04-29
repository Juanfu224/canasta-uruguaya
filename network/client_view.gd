## Vista del cliente (PEER no autoritativo).
##
## Se instancia en TODOS los participantes (incluido el host, donde es un
## consumidor adicional para reutilizar la misma UI).
##
## Responsabilidades:
##   - Mantener la copia local de `MatchState` reconstruida desde snapshots.
##   - Conocer la mano privada del jugador local; las manos de los demás se
##     representan como cartas dorso (sólo se conoce el conteo).
##   - Recibir notificaciones del host y exponerlas como señales tipadas
##     que la UI conecta.
##   - Enviar requests al host vía `RpcRouter.client_request_*`.
##
## Esta clase NO valida reglas: confía en el host. La validación local sólo
## es de UX (deshabilitar botones cuando no es nuestro turno) — si algo se
## escapa, el host rechazará vía `notify_rule_rejected`.
class_name ClientView
extends Node

signal snapshot_loaded(state: MatchState)
signal action_resolved(kind: String, payload: Dictionary, revision: int)
signal rule_rejected(kind: String, reason: String)
signal turn_advanced(current_player: int, phase: String)
signal private_hand_updated(card_ids: PackedInt32Array)

var match_state: MatchState = null
var local_player_id: int = -1
var current_phase: String = ""
var last_revision: int = 0

var rpc_router: RpcRouter = null
var _network: INetworkAuthority = null
var _private_hand_ids: PackedInt32Array = PackedInt32Array()


func setup(network: INetworkAuthority, router: RpcRouter, local_player_id_: int) -> void:
	_network = network
	rpc_router = router
	local_player_id = local_player_id_
	# Engancharnos a las RPCs del router. En GDScript todas las funciones
	# `@rpc` del router son no-op; las "interceptamos" extendiendo el router
	# con observación: lo más simple es que el router lo invoque por señal.
	# Para no acoplar más, conectamos las RPCs explícitamente vía override
	# en un nodo hijo del router. Aquí usamos el patrón de `set_meta`+lookup:
	router.set_meta("client_view", self)


# Invocados por RpcRouter (que reenvía cuando server == null, ver más abajo).
func on_snapshot(bytes: PackedByteArray) -> void:
	var snap: MatchSnapshot = Reconnection.from_bytes(bytes)
	if snap == null:
		push_error("ClientView: snapshot inválido")
		return
	match_state = snap.to_match_state(local_player_id, _private_hand_ids)
	current_phase = snap.current_state_name
	last_revision = snap.revision
	snapshot_loaded.emit(match_state)


func on_action_resolved(kind: String, payload: Dictionary, revision: int) -> void:
	if revision <= last_revision:
		return  # antiguo / duplicado
	last_revision = revision
	# Aplicar localmente el delta. Para F5 mantenemos simple: el cliente
	# refresca su match_state pidiendo snapshot al host si necesita
	# consistencia fuerte; los handlers UI se basan en `payload`.
	_apply_local_delta(kind, payload)
	action_resolved.emit(kind, payload, revision)


func on_rule_rejected(kind: String, reason: String) -> void:
	rule_rejected.emit(kind, reason)


func on_turn_advanced(current_player: int, phase: String) -> void:
	if match_state != null:
		match_state.current_player = current_player
	current_phase = phase
	turn_advanced.emit(current_player, phase)


func on_private_hand(card_ids: PackedInt32Array, revision: int) -> void:
	_private_hand_ids = card_ids
	if match_state != null and local_player_id >= 0 and local_player_id < match_state.hands.size():
		match_state.hands[local_player_id] = CardLookup.resolve(card_ids)
	if revision > last_revision:
		last_revision = revision
	private_hand_updated.emit(card_ids)


# ---------------------------------------------------------------------------
# UI helpers (lo que la escena de match invoca para enviar al host)
# ---------------------------------------------------------------------------

func is_local_turn() -> bool:
	return match_state != null and match_state.current_player == local_player_id

func request_draw() -> void:
	rpc_router.client_request_draw()

func request_capture(claim_ids: PackedInt32Array) -> void:
	rpc_router.client_request_capture(claim_ids)

func request_meld(card_ids: PackedInt32Array, declared_rank: int) -> void:
	rpc_router.client_request_meld(card_ids, declared_rank)

func request_discard(card_id: int) -> void:
	rpc_router.client_request_discard(card_id)

func request_close() -> void:
	rpc_router.client_request_close()


# ---------------------------------------------------------------------------
# Aplicación local de deltas
# ---------------------------------------------------------------------------

## Estrategia simple: para acciones públicas, mutamos los campos visibles
## (pozo, mazo size aproximada, melds del equipo, current_player). Para
## detalles complejos confiamos en el siguiente snapshot.
func _apply_local_delta(kind: String, payload: Dictionary) -> void:
	if match_state == null:
		return
	match kind:
		"discard":
			var card_id: int = int(payload.get("card_id", -1))
			var pid: int = int(payload.get("player_id", -1))
			if card_id >= 0 and pid >= 0:
				var card: Card = CardLookup.get_by_id(card_id)
				if card != null:
					match_state.pozo.push(card)
					if pid != local_player_id:
						# Manos de oponentes son placeholders; sólo bajamos su
						# tamaño al recibir el snapshot del próximo broadcast.
						pass
		"draw":
			# Se reflejará completamente en el próximo snapshot/private_hand.
			pass
		"capture":
			# Idem. La UI debe redibujar pozo cuando llegue snapshot.
			pass
		"meld":
			pass
		"close":
			match_state.hand_finished = true
		"match_end":
			match_state.match_finished = true
