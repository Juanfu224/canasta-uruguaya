## Smoke test headless de partida completa con 4 bots.
##
## Ejecuta una partida con bot_instant=true (sin delays) y valida que
## ServerMatch emite match_ended antes del timeout, sin errores.
##
## Comando:
##   godot --headless --path . -s tools/run_match_smoke.gd
extends SceneTree

const TIMEOUT_SEC: float = 30.0
const SEED: int = 42

var _server: Node = null
var _auth: Node = null
var _finished: bool = false
var _had_error: bool = false


func _initialize() -> void:
	# Esperar un frame para que autoloads estén en árbol.
	await process_frame

	# Acceder a autoloads vía root (quirk Godot 4.6 CLI).
	var rng_service: Node = root.get_node_or_null(^"RngService")
	if rng_service != null and rng_service.has_method("start_match"):
		rng_service.call("start_match", SEED)

	var game_config: Node = root.get_node_or_null(^"GameConfig")
	if game_config != null:
		# Activar modo instantáneo de bots para acelerar.
		game_config.set("bot_instant", true)

	_setup_match()


func _setup_match() -> void:
	var local_authority_script: Script = load("res://network/local_authority.gd") as Script
	var server_match_script: Script = load("res://network/server_match.gd") as Script
	var match_config_script: Script = load("res://resources/match_config.gd") as Script
	if local_authority_script == null or server_match_script == null or match_config_script == null:
		push_error("SMOKE FAIL: no se pudieron cargar scripts core")
		quit(1)
		return

	_auth = local_authority_script.new()
	_auth.name = "LocalAuthority"
	root.add_child(_auth)
	var err: int = _auth.host_match(0, 0)
	if err != OK:
		push_error("SMOKE FAIL: host_match err=%d" % err)
		quit(1)
		return

	_server = server_match_script.new()
	_server.name = "ServerMatch"
	root.add_child(_server)

	var config: Resource = match_config_script.standard_2v2(SEED)
	# Reducir target_score para que la partida termine en pocos rounds.
	config.target_score = 200
	_server.setup(_auth, config, "Smoke", "smoke-uuid")

	# ClientView dummy para que rpc_router.notify_* no se queje al hacer
	# get_meta("client_view"). Slot 0 — irrelevante porque también es bot.
	var client_view_script: Script = load("res://network/client_view.gd") as Script
	var cv: Node = client_view_script.new()
	cv.name = "ClientView"
	root.add_child(cv)
	cv.setup(_auth, _server.rpc_router, 0)

	_server.match_ended.connect(_on_match_ended)

	# Asignar bot a slot 0 (el host) primero para que el bot_controller actúe
	# en su lugar; luego rellenar 1..3 — el último gatilla start_match().
	_server.assign_bot(0, 1)
	for i in range(1, config.n_players):
		_server.assign_bot(i, 1)

	# Watchdog timeout.
	var timer: SceneTreeTimer = create_timer(TIMEOUT_SEC)
	timer.timeout.connect(_on_timeout)


func _on_match_ended() -> void:
	if _finished:
		return
	_finished = true
	var scores: String = ""
	var ms: Object = _server.get("match_state")
	if ms != null:
		var teams: Array = ms.get("teams")
		if teams != null:
			for t in teams:
				scores += " T%d=%d" % [t.team_id, t.cumulative_score]
	print("SMOKE OK: partida terminada.%s" % scores)
	quit(0)


func _on_timeout() -> void:
	if _finished:
		return
	push_error("SMOKE FAIL: timeout %ss sin terminar partida" % TIMEOUT_SEC)
	quit(1)
