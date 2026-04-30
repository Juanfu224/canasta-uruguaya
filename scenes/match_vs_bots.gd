## Lanzador de partida "vs Bots" (modo offline single-player).
##
## Esta escena temporal:
##   1. Configura `LocalAuthority` (OfflineMultiplayerPeer).
##   2. Instancia `ServerMatch` y le asigna 3 bots NORMAL en slots 1..3.
##   3. Crea el `ClientView` local (player 0 = humano).
##   4. Reparenta todo a `Match.tscn` y reemplaza la escena actual.
##
## El árbol y la lógica de UI se reusan tal cual de la escena Match.tscn de
## red — el motor no distingue: ServerMatch + RpcRouter (con OfflineMP peer)
## funcionan localmente sin red.
extends Node

const MATCH_PATH: String = "res://scenes/Match.tscn"

@export var bot_level: int = GameConfig.BotLevel.NORMAL
@export var n_bots: int = 3


func _ready() -> void:
	# Inicializa RNG determinista para la partida.
	if RngService.current_match_seed == 0:
		RngService.start_match(0)

	var auth := LocalAuthority.new()
	auth.name = "LocalAuthority"
	add_child(auth)
	var err: int = auth.host_match(0, 0)
	if err != OK:
		push_error("MatchVsBots: no se pudo crear LocalAuthority")
		return

	var server := ServerMatch.new()
	server.name = "ServerMatch"
	add_child(server)
	var nick: String = ProfileStore.nickname if not ProfileStore.nickname.is_empty() else "Tú"
	server.setup(auth, MatchConfig.standard_2v2(RngService.current_match_seed), nick, ProfileStore.uuid)

	# Asignar bots a los slots restantes (1..n).
	var max_p: int = mini(n_bots, server._config.n_players - 1)
	for i in range(1, max_p + 1):
		server.assign_bot(i, bot_level)

	# Crear ClientView local del jugador humano (slot 0).
	var client_view := ClientView.new()
	client_view.name = "ClientView"
	add_child(client_view)
	client_view.setup(auth, server.rpc_router, 0)

	# Reparentar a la escena Match.tscn.
	var packed: PackedScene = load(MATCH_PATH) as PackedScene
	if packed == null:
		push_error("MatchVsBots: no existe %s" % MATCH_PATH)
		return
	var match_scene: Node = packed.instantiate()
	match_scene.set_meta("is_host", true)
	server.reparent(match_scene)
	client_view.reparent(match_scene)

	get_tree().root.add_child(match_scene)
	get_tree().current_scene = match_scene
	queue_free()
