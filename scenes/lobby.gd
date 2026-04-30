## Lobby de partidas LAN.
##
## Tres modos:
##   - Crear sala: hospeda. Aparece código + lista de slots.
##   - Unirse por código: input + botón.
##   - Escanear LAN: lista de salas anunciadas vía broadcast.
##
## La sala arranca automáticamente cuando se llenan los slots (ver
## ServerMatch.register_client). Esta UI es minimalista (Controls dinámicos)
## para no requerir editor visual.
class_name Lobby
extends Control

const MATCH_PATH: String = "res://scenes/Match.tscn"

@onready var _root: VBoxContainer = $Center/VBox

var _network: INetworkAuthority = null
var _server: ServerMatch = null
var _client_view: ClientView = null
var _discovery: LanDiscovery = null
var _is_host: bool = false

# UI nodes (created in _build_ui)
var _status_label: Label = null
var _code_label: Label = null
var _slots_label: Label = null
var _scan_list: ItemList = null
var _join_code_edit: LineEdit = null
var _btn_host: Button = null
var _btn_join_code: Button = null
var _btn_scan: Button = null
var _btn_back: Button = null
var _bots_row: HBoxContainer = null

var _scanned_rooms: Array[Dictionary] = []
var _join_target_ip: String = ""


func _ready() -> void:
	_network = NetworkAuthority
	_discovery = LanDiscovery.new()
	add_child(_discovery)
	_build_ui()
	_network.connection_succeeded.connect(_on_connect_ok)
	_network.connection_failed.connect(_on_connect_fail)
	_network.server_disconnected.connect(_on_server_disconnect)
	_discovery.room_discovered.connect(_on_room_discovered)
	_discovery.room_lost.connect(_on_room_lost)


func _build_ui() -> void:
	# Wrapper centrado.
	var center := CenterContainer.new()
	center.name = "Center"
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	add_child(center)
	var vb := VBoxContainer.new()
	vb.name = "VBox"
	vb.custom_minimum_size = Vector2(440, 0)
	vb.add_theme_constant_override("separation", 12)
	center.add_child(vb)
	_root = vb

	var title := Label.new()
	title.text = "Lobby LAN"
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)

	_status_label = Label.new()
	_status_label.text = "Crear sala o unirse"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_status_label)

	_btn_host = Button.new()
	_btn_host.text = "Crear sala"
	_btn_host.pressed.connect(_on_host_pressed)
	vb.add_child(_btn_host)

	var join_row := HBoxContainer.new()
	_join_code_edit = LineEdit.new()
	_join_code_edit.placeholder_text = "Código de sala"
	_join_code_edit.max_length = RoomCode.LENGTH
	_join_code_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_row.add_child(_join_code_edit)
	_btn_join_code = Button.new()
	_btn_join_code.text = "Unirse"
	_btn_join_code.pressed.connect(_on_join_code_pressed)
	join_row.add_child(_btn_join_code)
	vb.add_child(join_row)

	_btn_scan = Button.new()
	_btn_scan.text = "Buscar salas en LAN"
	_btn_scan.pressed.connect(_on_scan_pressed)
	vb.add_child(_btn_scan)

	_scan_list = ItemList.new()
	_scan_list.custom_minimum_size = Vector2(0, 160)
	_scan_list.item_activated.connect(_on_scan_item_activated)
	vb.add_child(_scan_list)

	_code_label = Label.new()
	_code_label.text = ""
	_code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_code_label.add_theme_font_size_override("font_size", 28)
	vb.add_child(_code_label)

	_slots_label = Label.new()
	_slots_label.text = ""
	_slots_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_slots_label)

	_bots_row = HBoxContainer.new()
	_bots_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_bots_row.visible = false
	vb.add_child(_bots_row)
	for level in [GameConfig.BotLevel.EASY, GameConfig.BotLevel.NORMAL, GameConfig.BotLevel.HARD]:
		var b: Button = Button.new()
		b.text = "+ Bot %s" % _bot_level_label(level)
		b.pressed.connect(_on_add_bot_pressed.bind(level))
		_bots_row.add_child(b)

	_btn_back = Button.new()
	_btn_back.text = "Volver al menú"
	_btn_back.pressed.connect(_on_back_pressed)
	vb.add_child(_btn_back)


# ---------------------------------------------------------------------------
# Host
# ---------------------------------------------------------------------------

func _on_host_pressed() -> void:
	var err: int = _network.host_match(GameConfig.NET_PORT_GAME, 3)
	if err != OK:
		_status_label.text = "Error al hospedar (%d)" % err
		return
	_is_host = true
	_server = ServerMatch.new()
	_server.name = "ServerMatch"
	add_child(_server)
	_server.setup(_network, MatchConfig.standard_2v2(0), ProfileStore.nickname, ProfileStore.uuid)
	_server.player_joined.connect(_on_player_joined)
	_server.player_left.connect(_on_player_left)
	_server.match_started.connect(_on_match_started)

	_code_label.text = _server.match_id
	_slots_label.text = _slots_text()
	_status_label.text = "Esperando jugadores..."

	# Crear ClientView local (el host TAMBIÉN juega).
	_create_client_view(0)
	# Anunciar.
	_discovery.start_advertising({
		"code": _server.match_id,
		"host": ProfileStore.nickname,
		"port": GameConfig.NET_PORT_GAME,
		"n": 1,
		"max": 4,
		"started": false,
	})
	_btn_host.disabled = true
	_btn_join_code.disabled = true
	_btn_scan.disabled = true
	_bots_row.visible = true


func _slots_text() -> String:
	if _server == null:
		return ""
	var lines: Array[String] = []
	for p in _server._config.n_players:
		var nick: String = _server._player_nicknames[p] if p < _server._player_nicknames.size() else ""
		if _server.bot_controller != null and _server.bot_controller.is_bot(p):
			lines.append("Slot %d: %s [BOT]" % [p, nick])
		elif nick.is_empty():
			lines.append("Slot %d: (vacío)" % p)
		else:
			lines.append("Slot %d: %s" % [p, nick])
	return "\n".join(lines)


func _bot_level_label(level: int) -> String:
	match level:
		GameConfig.BotLevel.EASY: return "Fácil"
		GameConfig.BotLevel.HARD: return "Difícil"
		_: return "Normal"


func _on_add_bot_pressed(level: int) -> void:
	if _server == null or not _is_host:
		return
	# Buscar primer slot vacío.
	for p in _server._config.n_players:
		var peer_id: int = _server._player_to_peer[p]
		var is_bot: bool = _server.bot_controller != null and _server.bot_controller.is_bot(p)
		if peer_id == -1 and not is_bot:
			_server.assign_bot(p, level)
			_slots_label.text = _slots_text()
			_discovery.update_advertise_info({"n": _count_filled(), "started": _server._started})
			return
	_status_label.text = "No hay slots libres"


func _on_player_joined(_pid: int, _peer: int, _nick: String) -> void:
	_slots_label.text = _slots_text()
	_discovery.update_advertise_info({"n": _count_filled(), "started": false})


func _on_player_left(_pid: int) -> void:
	_slots_label.text = _slots_text()
	_discovery.update_advertise_info({"n": _count_filled(), "started": false})


func _count_filled() -> int:
	var c := 0
	for p in _server._config.n_players:
		var peer_id: int = _server._player_to_peer[p]
		var is_bot: bool = _server.bot_controller != null and _server.bot_controller.is_bot(p)
		if peer_id != -1 or is_bot:
			c += 1
	return c


# ---------------------------------------------------------------------------
# Join (por código o por escaneo)
# ---------------------------------------------------------------------------

func _on_join_code_pressed() -> void:
	var code: String = RoomCode.normalize(_join_code_edit.text)
	if not RoomCode.is_valid(code):
		_status_label.text = "Código inválido"
		return
	# Sin servidor de relay, intentamos resolver vía descubrimiento LAN.
	_status_label.text = "Buscando '%s'..." % code
	_discovery.start_scanning()
	# Esperar hasta encontrar (timeout 5s).
	var elapsed := 0.0
	while elapsed < LanDiscovery.SCAN_DURATION_S:
		await get_tree().create_timer(0.25).timeout
		elapsed += 0.25
		for room in _scanned_rooms:
			if String(room.get("code", "")) == code:
				_join_at(room.get("host_ip", ""), int(room.get("port", GameConfig.NET_PORT_GAME)))
				return
	_status_label.text = "No se encontró la sala"


func _on_scan_pressed() -> void:
	_scan_list.clear()
	_scanned_rooms.clear()
	_discovery.start_scanning()
	_status_label.text = "Escaneando..."


func _on_room_discovered(info: Dictionary) -> void:
	# Evitar duplicados.
	for r in _scanned_rooms:
		if r.get("code") == info.get("code"):
			return
	_scanned_rooms.append(info)
	_scan_list.add_item("%s — %s (%d/%d)" % [
		String(info.get("code", "?")),
		String(info.get("host", "?")),
		int(info.get("n", 0)),
		int(info.get("max", 4)),
	])


func _on_room_lost(code: String) -> void:
	for i in _scanned_rooms.size():
		if _scanned_rooms[i].get("code") == code:
			_scanned_rooms.remove_at(i)
			_scan_list.remove_item(i)
			return


func _on_scan_item_activated(idx: int) -> void:
	if idx < 0 or idx >= _scanned_rooms.size():
		return
	var info: Dictionary = _scanned_rooms[idx]
	_join_at(String(info.get("host_ip", "")), int(info.get("port", GameConfig.NET_PORT_GAME)))


func _join_at(host_ip: String, port: int) -> void:
	if host_ip.is_empty():
		_status_label.text = "IP inválida"
		return
	_join_target_ip = host_ip
	_status_label.text = "Conectando a %s..." % host_ip
	var err: int = _network.join_match(host_ip, port)
	if err != OK:
		_status_label.text = "No se pudo conectar (%d)" % err


# ---------------------------------------------------------------------------
# Connection callbacks (peer)
# ---------------------------------------------------------------------------

func _on_connect_ok() -> void:
	_is_host = false
	_status_label.text = "Conectado, registrando..."
	# Crear router de cliente y client_view antes de registrar.
	var router := RpcRouter.new()
	router.name = "RpcRouter"
	# IMPORTANTE: en el cliente NO seteamos `router.server`, así sólo procesa
	# RPCs autoritativas entrantes.
	add_child(router)
	_client_view = ClientView.new()
	_client_view.name = "ClientView"
	add_child(_client_view)
	_client_view.setup(_network, router, -1)  # local_player_id se asignará al recibir snapshot
	# Registrarse en el host.
	router.rpc_id(1, "register_client", ProfileStore.nickname, ProfileStore.uuid)
	# El cliente se queda en el lobby hasta recibir snapshot, entonces salta.
	_client_view.snapshot_loaded.connect(_on_client_snapshot)


func _on_connect_fail(reason: String) -> void:
	_status_label.text = "Falló la conexión: %s" % reason
	_btn_host.disabled = false
	_btn_join_code.disabled = false
	_btn_scan.disabled = false


func _on_server_disconnect() -> void:
	_status_label.text = "Desconectado del servidor"


func _on_client_snapshot(_state: MatchState) -> void:
	# Pasar a la escena Match con el client_view ya configurado.
	_transition_to_match(false)


func _on_match_started() -> void:
	_transition_to_match(true)


# ---------------------------------------------------------------------------
# Transición a Match
# ---------------------------------------------------------------------------

func _transition_to_match(is_host: bool) -> void:
	# Reparenting: pasamos el ServerMatch / ClientView / RpcRouter a la escena
	# de Match para que sobrevivan al cambio.
	var packed: PackedScene = load(MATCH_PATH) as PackedScene
	if packed == null:
		push_error("Lobby: no existe %s" % MATCH_PATH)
		return
	var match_scene: Node = packed.instantiate()
	match_scene.set_meta("is_host", is_host)
	if is_host:
		_server.reparent(match_scene)
	# El client_view local del host también debe reparentarse.
	if _client_view != null:
		_client_view.reparent(match_scene)
	get_tree().root.add_child(match_scene)
	get_tree().current_scene = match_scene
	queue_free()


func _create_client_view(local_player_id: int) -> void:
	var router: RpcRouter = _server.rpc_router
	router.set_meta("client_view", null)  # placeholder; el host también juega
	_client_view = ClientView.new()
	_client_view.name = "ClientView"
	add_child(_client_view)
	_client_view.setup(_network, router, local_player_id)


func _on_back_pressed() -> void:
	if _is_host:
		_discovery.stop()
	if _network.local_peer_id() != 0:
		_network.disconnect_peer()
	get_tree().change_scene_to_file("res://scenes/Menu.tscn")
