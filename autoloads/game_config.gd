## Configuración global del juego: enums, constantes y reglas inmutables.
##
## Singleton (autoload). NO mantiene estado mutable de la partida; eso es
## responsabilidad del host autoritativo (ver `core/rules_engine.gd`, F2).
##
## Diseño:
## - Todo lo expuesto aquí es `const` para garantizar inmutabilidad y
##   permitir uso desde scripts `@tool` sin instanciar el autoload.
## - Las enums se referencian como `GameConfig.Suit.HEARTS`, etc.
extends Node

# ---------------------------------------------------------------------------
# Enumeraciones de carta
# ---------------------------------------------------------------------------

## Palos de la baraja inglesa. JOKER es un pseudo-palo para los comodines
## mayores, que no pertenecen a ningún palo real.
enum Suit {
	CLUBS,    # ♣ Trébol (negro)
	DIAMONDS, # ♦ Diamante (rojo)
	HEARTS,   # ♥ Corazón (rojo)
	SPADES,   # ♠ Pica (negro)
	JOKER,    # comodín mayor
}

## Rangos. ACE = 1, JACK..KING en orden. JOKER es un rango propio para
## simplificar lookups por rango.
enum Rank {
	ACE,
	TWO,
	THREE,
	FOUR,
	FIVE,
	SIX,
	SEVEN,
	EIGHT,
	NINE,
	TEN,
	JACK,
	QUEEN,
	KING,
	JOKER,
}

# ---------------------------------------------------------------------------
# Composición del mazo (2 barajas inglesas + 4 jokers = 108)
# ---------------------------------------------------------------------------

const TOTAL_CARDS: int = 108
const DECKS_COUNT: int = 2
const JOKERS_COUNT: int = 4
const RANKS_PER_DECK: int = 13
const SUITS_PER_RANK: int = 4

# ---------------------------------------------------------------------------
# Valor en puntos por rango (puntos individuales en mano)
# ---------------------------------------------------------------------------

const POINTS_JOKER: int = 50
const POINTS_TWO: int = 20
const POINTS_ACE: int = 15
const POINTS_FACE: int = 10  # K, Q, J, 10, 9, 8
const POINTS_LOW: int = 5    # 7, 6, 5, 4, 3

# ---------------------------------------------------------------------------
# Bonificaciones de canastas
# ---------------------------------------------------------------------------

const CANASTA_PURE_BONUS: int = 500
const CANASTA_IMPURE_BONUS: int = 200
const CANASTA_WILDS_PURE_BONUS: int = 3000
const CANASTA_WILDS_IMPURE_BONUS: int = 2000
const CANASTA_ACES_PURE_BONUS: int = 800
const CANASTA_ACES_IMPURE_BONUS: int = 500

# ---------------------------------------------------------------------------
# Treses y penalizaciones
# ---------------------------------------------------------------------------

const RED_THREE_BONUS: int = 100
const RED_THREE_FULL_SET_BONUS: int = 800  # los 4 juntos
const BLACK_THREE_FULL_SET_PENALTY: int = -500
const DRAW_OUT_OF_ORDER_PENALTY: int = -100

# ---------------------------------------------------------------------------
# Umbrales dinámicos de apertura (por puntuación acumulada del equipo)
# ---------------------------------------------------------------------------

const OPENING_THRESHOLD_NEGATIVE: int = 15
const OPENING_THRESHOLD_INITIAL: int = 50  # 0..1499
const OPENING_THRESHOLD_MID: int = 90      # 1500..2999
const OPENING_THRESHOLD_HIGH: int = 120    # >=3000

# ---------------------------------------------------------------------------
# Configuración de partida
# ---------------------------------------------------------------------------

const TARGET_SCORE_QUICK: int = 5000
const TARGET_SCORE_STANDARD: int = 7000

const HAND_SIZE_2P: int = 15
const HAND_SIZE_3P: int = 13
const HAND_SIZE_4P: int = 11
const HAND_SIZE_6P: int = 11

const CANASTA_SIZE: int = 7
const MAX_WILDS_PER_MELD: int = 3
const MIN_NATURALS_FOR_IMPURE: int = 4

## Robo obligatorio uruguayo: dos cartas por turno.
const DRAW_COUNT_PER_TURN: int = 2

# ---------------------------------------------------------------------------
# Red / multiplayer
# ---------------------------------------------------------------------------

const NET_PORT_GAME: int = 8910
const NET_PORT_DISCOVERY: int = 8911
const ROOM_CODE_LENGTH: int = 6

# ---------------------------------------------------------------------------
# Helpers estáticos puros
# ---------------------------------------------------------------------------

## Devuelve el valor en puntos individual de un rango (sin contar bonos).
static func points_for_rank(rank: int) -> int:
	match rank:
		Rank.JOKER:
			return POINTS_JOKER
		Rank.TWO:
			return POINTS_TWO
		Rank.ACE:
			return POINTS_ACE
		Rank.KING, Rank.QUEEN, Rank.JACK, Rank.TEN, Rank.NINE, Rank.EIGHT:
			return POINTS_FACE
		Rank.SEVEN, Rank.SIX, Rank.FIVE, Rank.FOUR, Rank.THREE:
			return POINTS_LOW
		_:
			push_error("GameConfig.points_for_rank: rango desconocido %s" % rank)
			return 0

## Un palo es "rojo" si es Diamantes o Corazones.
static func is_red_suit(suit: int) -> bool:
	return suit == Suit.DIAMONDS or suit == Suit.HEARTS

## Un palo es "negro" si es Tréboles o Picas.
static func is_black_suit(suit: int) -> bool:
	return suit == Suit.CLUBS or suit == Suit.SPADES

## Comodines: Joker (cualquier palo) o cualquier 2.
static func is_wildcard_rank(rank: int) -> bool:
	return rank == Rank.JOKER or rank == Rank.TWO

## Umbral de apertura según puntuación acumulada del equipo.
static func opening_threshold_for(team_cumulative_score: int) -> int:
	if team_cumulative_score < 0:
		return OPENING_THRESHOLD_NEGATIVE
	if team_cumulative_score < 1500:
		return OPENING_THRESHOLD_INITIAL
	if team_cumulative_score < 3000:
		return OPENING_THRESHOLD_MID
	return OPENING_THRESHOLD_HIGH

## Tamaño de mano inicial según número de jugadores.
static func hand_size_for(n_players: int) -> int:
	match n_players:
		2:
			return HAND_SIZE_2P
		3:
			return HAND_SIZE_3P
		4:
			return HAND_SIZE_4P
		6:
			return HAND_SIZE_6P
		_:
			push_error("GameConfig.hand_size_for: jugadores no soportados %d" % n_players)
			return HAND_SIZE_4P
