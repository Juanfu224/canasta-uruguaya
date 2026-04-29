## Escena de match en red (host autoritativo).
##
## Es la versión productiva de `MatchOffline`. La escena se reparenta desde
## el Lobby con `ServerMatch` y/o `ClientView` ya configurados como hijos.
##
## Flujo de UI:
##   - Eventos del usuario (drag&drop, tap mazo) → llamamos a
##     `client_view.request_*` que hace RPC al host.
##   - Notificaciones del host (`action_resolved`, `private_hand_updated`,
##     `turn_advanced`, `rule_rejected`) → refrescamos UI.
##
## El host también juega: tiene su propio `ClientView` que conecta a su
## `RpcRouter` local. La diferencia con un peer es que las RPCs se ejecutan
## sin viajar por red (Godot las invoca localmente).
extends Control

const _SCORE_POPUP_SCENE: PackedScene = preload("res://ui/score_popup.tscn")
const _LOADING_FLUID_SCENE: PackedScene = preload("res://ui/transitions/loading_fluid.tscn")

@onready var _local_hand: HandLayout = $LocalHand
@onready var _remote_hand_top: HandLayout = $RemoteHandTop
@onready var _remote_hand_left: HandLayout = $RemoteHandLeft
@onready var _remote_hand_right: HandLayout = $RemoteHandRight
@onready var _pozo: PozoView = $Center/PozoView
@onready var _deck: DeckView = $Center/DeckView
@onready var _melds: MeldsTable = $Top/MeldsTable
@onready var _info: Label = $InfoLabel

var _server: ServerMatch = null
var _client_view: ClientView = null
var _is_host: bool = false


func _ready() -> void:
	Input.use_accumulated_input = false
	_is_host = bool(get_meta("is_host", false))
	# Buscar ServerMatch / ClientView entre los hijos (reparented desde Lobby).
	_server = get_node_or_null("ServerMatch") as ServerMatch
	_client_view = get_node_or_null("ClientView") as ClientView
	if _client_view == null:
		push_error("Match: no hay ClientView; ¿se llegó desde Lobby?")
		return
	# Conectar UI inputs.
	_pozo.discard_requested.connect(_on_discard_requested)
	_deck.draw_requested.connect(_on_draw_requested)
	_melds.create_meld_requested.connect(_on_create_meld_requested)
	_melds.extend_meld_requested.connect(_on_extend_meld_requested)
	# Conectar señales del client_view.
	_client_view.snapshot_loaded.connect(_on_snapshot_loaded)
	_client_view.private_hand_updated.connect(_on_private_hand_updated)
	_client_view.turn_advanced.connect(_on_turn_advanced)
	_client_view.action_resolved.connect(_on_action_resolved)
	_client_view.rule_rejected.connect(_on_rule_rejected)

	# Si el host, ya tenemos match_state. Forzar refresh inicial.
	if _is_host and _server != null and _server.match_state != null:
		_redraw_full()


# ---------------------------------------------------------------------------
# Inputs UI → RPC host
# ---------------------------------------------------------------------------

func _on_draw_requested() -> void:
	if not _client_view.is_local_turn():
		_show_toast("No es tu turno")
		return
	_client_view.request_draw()


func _on_discard_requested(card_id: int, _source: NodePath) -> void:
	if not _client_view.is_local_turn():
		_show_toast("No es tu turno")
		return
	_client_view.request_discard(card_id)


func _on_create_meld_requested(card_id: int, _source: NodePath) -> void:
	if not _client_view.is_local_turn():
		return
	# Para meld nuevo enviamos sólo esa carta + rank inferido localmente.
	# El host validará. Para multi-carta meld se requiere UI selector más
	# complejo (pendiente F6 - mejorada UX).
	var rank: int = _infer_rank_from_local(card_id)
	_client_view.request_meld(PackedInt32Array([card_id]), rank)


func _on_extend_meld_requested(_meld_index: int, card_id: int, _source: NodePath) -> void:
	if not _client_view.is_local_turn():
		return
	# El motor identifica el meld a extender por declared_rank (no índice).
	var rank: int = _infer_rank_from_local(card_id)
	_client_view.request_meld(PackedInt32Array([card_id]), rank)


func _infer_rank_from_local(card_id: int) -> int:
	var card: Card = CardLookup.get_by_id(card_id)
	if card == null:
		return -1
	if card.is_wildcard:
		return GameConfig.Rank.JOKER
	return card.rank


# ---------------------------------------------------------------------------
# Notificaciones host → UI
# ---------------------------------------------------------------------------

func _on_snapshot_loaded(_state: MatchState) -> void:
	_redraw_full()


func _on_private_hand_updated(_card_ids: PackedInt32Array) -> void:
	_redraw_local_hand()
	_update_info()


func _on_turn_advanced(current_player: int, phase: String) -> void:
	_info.text = "Turno: jugador %d  |  Fase: %s" % [current_player, phase]


func _on_action_resolved(_kind: String, _payload: Dictionary, _revision: int) -> void:
	# Refrescar lo visible: pozo y melds derivados del state local.
	_redraw_pozo()
	_redraw_melds()
	_update_info()


func _on_rule_rejected(kind: String, reason: String) -> void:
	_show_toast("✗ %s: %s" % [kind, reason])


# ---------------------------------------------------------------------------
# Render
# ---------------------------------------------------------------------------

func _redraw_full() -> void:
	_redraw_local_hand()
	_redraw_pozo()
	_redraw_melds()
	_redraw_remote_counts()
	_update_info()


func _redraw_local_hand() -> void:
	var state: MatchState = _client_view.match_state
	if state == null:
		return
	var pid: int = _client_view.local_player_id
	if pid < 0 or pid >= state.hands.size():
		return
	# Limpiar y reconstruir.
	for child in _local_hand.get_children():
		child.queue_free()
	for c in state.hands[pid]:
		_local_hand.add_card(c, false)


func _redraw_pozo() -> void:
	var state: MatchState = _client_view.match_state
	if state == null or state.pozo == null:
		return
	_pozo.set_count(state.pozo.pile.size())
	if state.pozo.pile.size() > 0:
		_pozo.set_top_card(state.pozo.top())
	if state.pozo.is_taponado():
		_pozo.set_status(PozoView.PozoStatus.TAPONADO)
	elif state.pozo.is_cruzado():
		_pozo.set_status(PozoView.PozoStatus.CRUZADO)
	else:
		_pozo.set_status(PozoView.PozoStatus.NORMAL)


func _redraw_melds() -> void:
	var state: MatchState = _client_view.match_state
	if state == null:
		return
	var pid: int = max(0, _client_view.local_player_id)
	var team: TeamState = state.team_of(pid)
	if team != null:
		_melds.render_melds(team.melds)


func _redraw_remote_counts() -> void:
	# F5: en este iteración rendereamos las manos remotas vacías (sólo el
	# layout queda visible). En F6 se reemplaza por dorso real con conteo.
	pass


func _update_info() -> void:
	var state: MatchState = _client_view.match_state
	if state == null:
		return
	var deck_size: int = state.deck.size() if state.deck != null else 0
	var pozo_count: int = state.pozo.pile.size() if state.pozo != null else 0
	_info.text = "Mazo: %d | Pozo: %d | Turno: J%d (%s)" % [
		deck_size, pozo_count, state.current_player, _client_view.current_phase,
	]


# ---------------------------------------------------------------------------
# Misc
# ---------------------------------------------------------------------------

func _show_toast(msg: String) -> void:
	# Mínimo viable: actualizar info bar y log.
	_info.text = msg
	print("[Match] toast: %s" % msg)
