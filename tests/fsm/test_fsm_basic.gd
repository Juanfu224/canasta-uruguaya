## Test simple de la FSM: arranca, transita InitMatch → SetupPozo → DrawPhase.
extends RefCounted

const TestAssert := preload("res://tools/test_assert.gd")

static func run() -> Array:
	var failures: Array[String] = []
	var t := TestAssert.new("fsm_transitions")

	var cfg := MatchConfig.standard_2v2(7)
	var state := MatchState.create(cfg)
	var fsm := GameStateMachine.new(state)
	fsm.start(load("res://fsm/states/state_init_match.gd") as Script)

	# Tras start: en InitMatch.
	t.eq(fsm.current.name(), "InitMatch", "start = InitMatch")
	t.not_null(state.deck, "deck creado")

	# tick → SetupPozo
	fsm.tick()
	t.eq(fsm.current.name(), "SetupPozo", "transición a SetupPozo")

	# tick → DrawPhase (después SetupPozo reparte y avanza)
	fsm.tick()
	t.eq(fsm.current.name(), "DrawPhase", "transición a DrawPhase")
	t.is_false(state.pozo == null, "pozo configurado")
	t.is_false(state.pozo.is_empty(), "pozo no vacío")

	# Cada jugador tiene cartas.
	for p in range(4):
		t.is_true((state.hands[p] as Array).size() > 0, "player %d con cartas" % p)

	failures.append_array(t.failures)
	return failures
