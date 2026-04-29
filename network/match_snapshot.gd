## Snapshot serializable del `MatchState` para sync inicial y reconexión.
##
## Se transmite vía RPC al cliente cuando se une a la partida o reconecta.
## El snapshot contiene SÓLO ids canónicos de carta (`PackedInt32Array`) —
## el cliente reconstruye los `Card` resources localmente vía `CardLookup`.
## Esto:
##   - Reduce drásticamente el bandwidth (108 cartas → 432 bytes vs varios KB).
##   - Imposibilita que un servidor malicioso envíe cartas con propiedades
##     falsificadas (rango/palo/valor): el cliente confía solo en el id.
##   - Permite snapshots determinísticos verificables por hash.
##
## Privacidad de manos:
##   El snapshot público (broadcast) contiene `hand_sizes: PackedInt32Array`
##   sin las cartas. Cada cliente recibe SU mano privada por separado vía
##   `RpcRouter.client_set_private_hand(peer, ids)`. La única excepción es
##   el snapshot persistido en disco para reconexión, que sí contiene todas
##   las manos pero es leído sólo por el host.
class_name MatchSnapshot
extends Resource

## Versión del esquema. Bump si la forma cambia (campo nuevo, semántica).
const SCHEMA_VERSION: int = 1

@export var schema_version: int = SCHEMA_VERSION
@export var match_id: String = ""
@export var revision: int = 0  # incrementa en cada `mark_resolved` (anti-replay)
@export var seed: int = 0

# Config (replicada para que el cliente pueda reconstruir).
@export var n_players: int = 4
@export var n_teams: int = 2
@export var target_score: int = 5000

# Estado dinámico.
@export var deck_ids: PackedInt32Array = PackedInt32Array()
@export var pozo_ids: PackedInt32Array = PackedInt32Array()
@export var hand_sizes: PackedInt32Array = PackedInt32Array()
# Manos privadas: SOLO en snapshots persistidos (disco). Vacío en broadcast.
@export var hands_private_ids: Array = []  # Array[PackedInt32Array]
@export var teams: Array[TeamState] = []
@export var current_player: int = 0
@export var match_finished: bool = false
@export var hand_finished: bool = false
@export var closer_player_id: int = -1
@export var closer_closed_in_hand: bool = false
@export var current_state_name: String = ""


## Construye un snapshot a partir de un `MatchState` autoritativo.
## Si `include_private_hands` es false, las manos no se serializan (broadcast
## público). El host envía las manos privadas por canal dirigido aparte.
static func from_match_state(
	state: MatchState,
	match_id: String,
	revision: int,
	seed: int,
	current_state_name: String,
	include_private_hands: bool = false,
) -> MatchSnapshot:
	var snap := MatchSnapshot.new()
	snap.schema_version = SCHEMA_VERSION
	snap.match_id = match_id
	snap.revision = revision
	snap.seed = seed
	snap.n_players = state.config.n_players
	snap.n_teams = state.config.n_teams
	snap.target_score = state.config.target_score
	snap.deck_ids = state.deck.to_id_array() if state.deck != null else PackedInt32Array()
	var pozo_ids := PackedInt32Array()
	if state.pozo != null:
		for c in state.pozo.pile:
			pozo_ids.append((c as Card).id)
	snap.pozo_ids = pozo_ids
	var sizes := PackedInt32Array()
	for h in state.hands:
		sizes.append((h as Array).size())
	snap.hand_sizes = sizes
	if include_private_hands:
		var private_ids: Array = []
		for h in state.hands:
			var ids := PackedInt32Array()
			for c in h:
				ids.append((c as Card).id)
			private_ids.append(ids)
		snap.hands_private_ids = private_ids
	snap.teams = state.teams.duplicate(true)
	snap.current_player = state.current_player
	snap.match_finished = state.match_finished
	snap.hand_finished = state.hand_finished
	snap.closer_player_id = state.closer_player_id
	snap.closer_closed_in_hand = state.closer_closed_in_hand
	snap.current_state_name = current_state_name
	return snap


## Reconstruye un `MatchState` desde el snapshot. Si `private_hand_for_player`
## es != -1 y `private_hand_ids` no es null, esa mano se llena con cartas
## reales; el resto de manos se llenan con cartas dorso (placeholder) según
## el conteo en `hand_sizes`.
##
## Devuelve null si el snapshot es inválido (versión incompatible o ids
## fuera de rango).
func to_match_state(
	private_hand_for_player: int = -1,
	private_hand_ids: PackedInt32Array = PackedInt32Array(),
) -> MatchState:
	if schema_version != SCHEMA_VERSION:
		push_error("MatchSnapshot: versión incompatible %d vs %d" % [schema_version, SCHEMA_VERSION])
		return null
	if n_players <= 0 or n_players > 8:
		push_error("MatchSnapshot: n_players fuera de rango: %d" % n_players)
		return null

	var cfg := MatchConfig.new()
	cfg.n_players = n_players
	cfg.n_teams = n_teams
	cfg.target_score = target_score
	cfg.seed = seed

	var state := MatchState.create(cfg)

	# Mazo: reconstruir desde ids.
	state.deck = Deck.new()
	var deck_cards := CardLookup.resolve(deck_ids)
	if deck_cards.is_empty() and deck_ids.size() > 0:
		push_error("MatchSnapshot: deck_ids inválidos")
		return null
	state.deck.cards = deck_cards

	# Pozo: reconstruir.
	state.pozo = PozoController.new()
	var pozo_cards := CardLookup.resolve(pozo_ids)
	if pozo_cards.is_empty() and pozo_ids.size() > 0:
		push_error("MatchSnapshot: pozo_ids inválidos")
		return null
	for c in pozo_cards:
		state.pozo.push(c)

	# Manos: si tenemos manos privadas (snapshot completo de host) las usamos
	# todas. Si no, sólo la del jugador local; el resto = placeholders dorso.
	state.hands.clear()
	if hands_private_ids.size() == n_players:
		for ids in hands_private_ids:
			var resolved := CardLookup.resolve(ids as PackedInt32Array)
			state.hands.append(resolved)
	else:
		for p in n_players:
			if p == private_hand_for_player:
				state.hands.append(CardLookup.resolve(private_hand_ids))
			else:
				# Placeholder: array vacío del tamaño correcto. El cliente
				# usa `hand_sizes` para renderizar cartas dorso del oponente.
				state.hands.append([] as Array[Card])

	state.teams = teams.duplicate(true)
	state.current_player = current_player
	state.match_finished = match_finished
	state.hand_finished = hand_finished
	state.closer_player_id = closer_player_id
	state.closer_closed_in_hand = closer_closed_in_hand
	return state
