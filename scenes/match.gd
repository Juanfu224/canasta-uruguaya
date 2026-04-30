## Escena de match en red (host autoritativo).
##
## Es la versión productiva de `MatchOffline`. La escena se reparenta desde
## el Lobby con `ServerMatch` y/o `ClientView` ya configurados como hijos.
##
## Flujo de UI:
##   - Eventos del usuario (drag&drop, tap mazo, botones) → llamamos a
##     `client_view.request_*` que hace RPC al host.
##   - Notificaciones del host (`action_resolved`, `private_hand_updated`,
##     `turn_advanced`, `rule_rejected`) → refrescamos UI.
##
## El host también juega: tiene su propio `ClientView` que conecta a su
## `RpcRouter` local. Las RPCs marcadas como `call_local` se invocan también
## en el peer 1, evitando ramas especiales.
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
@onready var _top_hud: TopHud = $HudLayer/TopHud
@onready var _bottom_hud: BottomHud = $HudLayer/BottomHud
@onready var _btn_pasar: Button = $BottomActionBar/BtnPasar
@onready var _btn_capturar: Button = $BottomActionBar/BtnCapturar
@onready var _btn_cerrar: Button = $BottomActionBar/BtnCerrar

var _server: ServerMatch = null
var _client_view: ClientView = null
var _is_host: bool = false
var _selected_card_ids: PackedInt32Array = PackedInt32Array()


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
	_local_hand.card_tapped.connect(_on_card_tapped)
	_btn_pasar.pressed.connect(_on_btn_pasar_pressed)
	_btn_capturar.pressed.connect(_on_btn_capturar_pressed)
	_btn_cerrar.pressed.connect(_on_btn_cerrar_pressed)
	if _bottom_hud != null:
		_bottom_hud.back_pressed.connect(_on_back_pressed)
	if _top_hud != null:
		_top_hud.menu_pressed.connect(_on_back_pressed)
	# Conectar señales del client_view.
	_client_view.snapshot_loaded.connect(_on_snapshot_loaded)
	_client_view.private_hand_updated.connect(_on_private_hand_updated)
	_client_view.turn_advanced.connect(_on_turn_advanced)
	_client_view.action_resolved.connect(_on_action_resolved)
	_client_view.rule_rejected.connect(_on_rule_rejected)

	# Si el host, ya tenemos match_state. Forzar refresh inicial.
	if _is_host and _server != null and _server.match_state != null:
		_redraw_full()
	_update_action_buttons()


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
# Selección de cartas y botones de acción
# ---------------------------------------------------------------------------

func _on_card_tapped(card_id: int) -> void:
	# Toggle selección.
	var idx: int = _selected_card_ids.find(card_id)
	if idx >= 0:
		_selected_card_ids.remove_at(idx)
	else:
		_selected_card_ids.append(card_id)
	_update_card_selection_visuals()
	_update_action_buttons()


func _update_card_selection_visuals() -> void:
	const SELECTED_TINT: Color = Color(1.4, 1.2, 0.4, 1.0)
	for child in _local_hand.get_children():
		var cu: CardUI = child as CardUI
		if cu == null or cu.card == null:
			continue
		if _selected_card_ids.find(cu.card.id) >= 0:
			cu.modulate = SELECTED_TINT
		else:
			cu.modulate = Color.WHITE


func _update_action_buttons() -> void:
	var phase: String = ""
	var local_turn: bool = false
	if _client_view != null:
		phase = _client_view.current_phase
		local_turn = _client_view.is_local_turn()
	# Pasar: visible siempre que sea tu turno en PlayPhase, sin requerir selección.
	_btn_pasar.disabled = not (local_turn and phase == "PlayPhase")
	# Capturar: requiere PlayPhase + cartas seleccionadas para reclamar.
	_btn_capturar.disabled = not (
		local_turn and phase == "PlayPhase" and _selected_card_ids.size() > 0
	)
	# Cerrar: requiere PlayPhase y turno local.
	_btn_cerrar.disabled = not (local_turn and phase == "PlayPhase")


func _on_btn_pasar_pressed() -> void:
	if _client_view == null:
		return
	_client_view.rpc_router.client_request_pass_play()


func _on_btn_capturar_pressed() -> void:
	if _client_view == null or _selected_card_ids.size() == 0:
		return
	_client_view.request_capture(_selected_card_ids.duplicate())
	_selected_card_ids = PackedInt32Array()
	_update_card_selection_visuals()
	_update_action_buttons()


func _on_btn_cerrar_pressed() -> void:
	if _client_view == null:
		return
	_client_view.request_close()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file.call_deferred("res://scenes/Menu.tscn")


# ---------------------------------------------------------------------------
# Notificaciones host → UI
# ---------------------------------------------------------------------------

func _on_snapshot_loaded(_state: MatchState) -> void:
	_redraw_full()


func _on_private_hand_updated(_card_ids: PackedInt32Array) -> void:
	_redraw_local_hand()
	_update_info()
	_update_action_buttons()


func _on_turn_advanced(current_player: int, phase: String) -> void:
	_show_toast("Turno: J%d  |  Fase: %s" % [current_player, phase])
	_redraw_remote_counts()
	_update_info()
	_update_action_buttons()


func _on_action_resolved(_kind: String, _payload: Dictionary, _revision: int) -> void:
	_redraw_full()


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
	_update_action_buttons()


func _redraw_local_hand() -> void:
	var state: MatchState = _client_view.match_state
	if state == null:
		return
	var pid: int = _client_view.local_player_id
	if pid < 0 or pid >= state.hands.size():
		return
	var hand: Array[Card] = []
	for c in state.hands[pid]:
		hand.append(c)
	_local_hand.set_cards(hand)
	# Limpiar selección de cartas que ya no estén en mano.
	var still_present: PackedInt32Array = PackedInt32Array()
	for cid in _selected_card_ids:
		for c in hand:
			if c.id == cid:
				still_present.append(cid)
				break
	_selected_card_ids = still_present
	_update_card_selection_visuals()


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
	var state: MatchState = _client_view.match_state
	if state == null:
		return
	var local_pid: int = _client_view.local_player_id
	var n_players: int = state.hands.size()
	# Mapeo relativo al jugador local en mesa 4 jugadores: derecha=+1, frente=+2,
	# izquierda=+3 (módulo n_players).
	for offset in range(1, n_players):
		var pid: int = (local_pid + offset) % n_players
		var count: int = (state.hands[pid] as Array).size()
		var target: HandLayout = null
		match offset:
			1:
				target = _remote_hand_right
			2:
				target = _remote_hand_top
			3:
				target = _remote_hand_left
		if target != null:
			target.set_card_count(count)


func _update_info() -> void:
	var state: MatchState = _client_view.match_state
	if state == null:
		return
	var deck_size: int = state.deck.size() if state.deck != null else 0
	var pozo_count: int = state.pozo.pile.size() if state.pozo != null else 0
	var local_pid: int = _client_view.local_player_id
	var local_hand_size: int = 0
	if local_pid >= 0 and local_pid < state.hands.size():
		local_hand_size = (state.hands[local_pid] as Array).size()
	if _bottom_hud != null:
		_bottom_hud.set_counts(deck_size, pozo_count, local_hand_size)
		_bottom_hud.set_hint("Turno: J%d (%s)" % [state.current_player, _client_view.current_phase])
	if _top_hud != null:
		_top_hud.set_phase(_client_view.current_phase, _client_view.current_phase)
		# Actualizar marcadores de equipo.
		for team in state.teams:
			var ts: TeamState = team as TeamState
			if ts == null:
				continue
			var threshold: int = OpeningThreshold.required_for(ts.cumulative_score)
			_top_hud.set_team_threshold(ts.team_id, ts.cumulative_score, threshold)


# ---------------------------------------------------------------------------
# Misc
# ---------------------------------------------------------------------------

func _show_toast(msg: String) -> void:
	if _bottom_hud != null:
		_bottom_hud.set_hint(msg)
	print("[Match] toast: %s" % msg)
