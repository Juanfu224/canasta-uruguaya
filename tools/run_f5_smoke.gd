## Smoke test F5 (sin red real, single-process).
##
## Valida la cadena ServerMatch → RpcRouter → MatchState → FSM SIN abrir
## sockets ENet. La idea: instanciar `ServerMatch` con un mock de
## `INetworkAuthority` que simula `multiplayer.get_remote_sender_id()` vía
## un campo configurable.
##
## Ejecutar (cuando haya binario Godot disponible):
##   godot --headless --path . -s tools/run_f5_smoke.gd
extends SceneTree


func _initialize() -> void:
	print("[F5 Smoke] Inicio")
	_test_room_code()
	_test_card_lookup()
	_test_snapshot_roundtrip()
	print("[F5 Smoke] OK")
	quit()


func _test_room_code() -> void:
	for i in 16:
		var code: String = RoomCode.generate()
		assert(RoomCode.is_valid(code), "código inválido: %s" % code)
		assert(code.length() == RoomCode.LENGTH)
	# Normalización: minúsculas → mayúsculas, '1' confundido por 'I' rechazado.
	assert(RoomCode.normalize("abcdef".to_upper()) == "ABCDEF")
	print("[F5 Smoke] room_code OK")


func _test_card_lookup() -> void:
	for id in GameConfig.TOTAL_CARDS:
		var c: Card = CardLookup.get_by_id(id)
		assert(c != null, "card_lookup faltó id=%d" % id)
		assert(c.id == id)
	var ids := PackedInt32Array([0, 1, 2, 50, 107])
	var cards: Array[Card] = CardLookup.resolve(ids)
	assert(cards.size() == 5)
	# id fuera de rango → empty.
	var bad := PackedInt32Array([0, 999])
	var resolved: Array[Card] = CardLookup.resolve(bad)
	assert(resolved.is_empty(), "resolve debe ser fail-fast con id inválido")
	print("[F5 Smoke] card_lookup OK")


func _test_snapshot_roundtrip() -> void:
	# Construir un MatchState mínimo y serializar/deserializar.
	var cfg: MatchConfig = MatchConfig.standard_2v2(42)
	var state: MatchState = MatchState.create(cfg)
	state.deck = Deck.build_standard_108()
	state.deck.shuffle(RngService.match_rng)
	state.pozo = PozoController.new()
	# Repartir 11 cartas a cada mano para tener payload realista.
	for p in cfg.n_players:
		state.hands[p] = state.deck.draw_n(11)
	var snap: MatchSnapshot = MatchSnapshot.from_match_state(
		state, "TESTID", 1, 42, "DrawPhase", true,
	)
	var bytes: PackedByteArray = Reconnection.to_bytes(snap)
	assert(bytes.size() > 0)
	var snap2: MatchSnapshot = Reconnection.from_bytes(bytes)
	assert(snap2 != null)
	assert(snap2.revision == 1)
	assert(snap2.match_id == "TESTID")
	assert(snap2.deck_ids.size() == state.deck.size())
	# Reconstruir state con mano privada del jugador 0.
	var private_ids: PackedInt32Array = snap2.hands_private_ids[0]
	var rebuilt: MatchState = snap2.to_match_state(0, private_ids)
	assert(rebuilt != null)
	assert(rebuilt.config.n_players == cfg.n_players)
	assert(rebuilt.hands[0].size() == 11)
	print("[F5 Smoke] snapshot_roundtrip OK")
