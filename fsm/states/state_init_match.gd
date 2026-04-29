## Estado inicial: instala mazo barajado y prepara estructuras.
extends GameState

func name() -> String:
	return "InitMatch"

func _enter(state: MatchState) -> void:
	# Mazo construido y barajado por el host antes de instanciar la FSM, o aquí
	# si aún no existe.
	if state.deck == null:
		state.deck = Deck.build_standard_108()
		var rng := RandomNumberGenerator.new()
		rng.seed = state.config.seed
		state.deck.shuffle(rng)

func _process(_state: MatchState) -> Script:
	return load("res://fsm/states/state_setup_pozo.gd") as Script
