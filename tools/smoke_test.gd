## Nodo del smoke test headless. Ver `tools/SmokeTest.tscn`.
##
## Por qué no es un script SceneTree (`-s`):
##   En Godot 4.6 los autoloads NO se cargan al ejecutar con `-s script.gd`,
##   lo que rompe la compilación de `server_match.gd` (referencia a
##   `RngService`). En cambio, al ejecutar la escena directamente:
##       godot --headless --path . tools/SmokeTest.tscn
##   los autoloads sí se inicializan.
extends Node

const TIMEOUT_SEC: float = 90.0
const SEED_FOR_RUN: int = 42
## Score reducido para que el match termine en una o dos manos.
const SMOKE_TARGET_SCORE: int = 100

var _server: ServerMatch = null
var _t0_msec: int = 0


func _ready() -> void:
	_t0_msec = Time.get_ticks_msec()

	# Acelerar bots para que la simulación termine en segundos en CI.
	GameConfig.bot_instant = true

	if RngService.has_method("start_match"):
		RngService.start_match(SEED_FOR_RUN)

	var auth := LocalAuthority.new()
	add_child(auth)
	if auth.host_match(0, 0) != OK:
		push_error("Smoke: host_match falló")
		get_tree().quit(1)
		return

	_server = ServerMatch.new()
	_server.name = "ServerMatch"
	add_child(_server)

	# El host normalmente registra un ClientView que recibe los notify_*.
	# En el smoke test no lo necesitamos: silenciamos el get_meta seteando
	# explícitamente la meta a null en el router (los handlers ya hacen
	# `if cv != null: cv.on_*` así que se vuelven no-op).
	var router: Node = _server.get_node_or_null(^"RpcRouter")
	if router != null:
		router.set_meta("client_view", null)

	var cfg: MatchConfig = MatchConfig.standard_2v2(SEED_FOR_RUN)
	cfg.target_score = SMOKE_TARGET_SCORE
	_server.setup(auth, cfg, "BotHost", "uuid-smoke-host")
	_server.match_ended.connect(_on_match_ended)

	# 4 jugadores, todos bots NORMAL para no requerir input humano.
	for pid in range(0, cfg.n_players):
		_server.assign_bot(pid, GameConfig.BotLevel.NORMAL)

	print("[Smoke] match iniciado, esperando match_ended (timeout %.0fs)" % TIMEOUT_SEC)


var _last_log_msec: int = 0


func _process(_delta: float) -> void:
	if _t0_msec == 0:
		return
	var now: int = Time.get_ticks_msec()
	if now - _last_log_msec > 2000:
		_last_log_msec = now
		var ms: MatchState = _server.match_state if _server != null else null
		var phase: String = ""
		var pid: int = -1
		if _server != null and _server.fsm != null and _server.fsm.current != null:
			phase = _server.fsm.current.name()
		if ms != null:
			pid = ms.current_player
		print("[Smoke] t=%.1fs phase=%s pid=%d hand_finished=%s match_finished=%s"
			% [(now - _t0_msec) / 1000.0, phase, pid,
			   str(ms.hand_finished if ms != null else false),
			   str(ms.match_finished if ms != null else false)])
	var elapsed_sec: float = float(now - _t0_msec) / 1000.0
	if elapsed_sec > TIMEOUT_SEC:
		push_error("Smoke: timeout (%.1fs) sin match_ended" % elapsed_sec)
		get_tree().quit(1)


func _on_match_ended() -> void:
	var elapsed_sec: float = float(Time.get_ticks_msec() - _t0_msec) / 1000.0
	print("[Smoke] match_ended OK en %.2fs" % elapsed_sec)
	get_tree().quit(0)
