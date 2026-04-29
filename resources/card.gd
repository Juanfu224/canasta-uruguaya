## Representación inmutable de una carta de la baraja.
##
## Cada instancia es un `Resource` con un `id` único en el rango [0, 107].
## Las cartas se generan vía `tools/generate_card_atlas.gd` o directamente
## en `core/deck.gd::build_standard_108`. Una vez creadas no deben mutarse:
## las propiedades son `@export` solo para inspección/serialización.
##
## La identidad se basa en `id`, que es estable entre el host y los clientes
## (mismo orden de generación). Esto permite que las RPCs envíen `id: int`
## en lugar de la carta entera, reduciendo el ancho de banda.
class_name Card
extends Resource

## Identificador único en el mazo. 0..107.
@export var id: int = -1

## Palo (`GameConfig.Suit`).
@export var suit: int = GameConfig.Suit.JOKER

## Rango (`GameConfig.Rank`).
@export var rank: int = GameConfig.Rank.JOKER

## Valor en puntos individual (sin bonificaciones).
@export var point_value: int = 0

## Si la carta es comodín (Joker o cualquier 2).
@export var is_wildcard: bool = false

## Tres rojo (corazones o diamantes con rango TRES). Auto-roban reemplazo.
@export var is_red_three: bool = false

## Tres negro (tréboles o picas con rango TRES). Tapona el pozo al descartarse.
@export var is_black_three: bool = false


## Construye una carta natural a partir de palo y rango. Los flags derivados
## se calculan deterministicamente para evitar estados inconsistentes.
static func make(card_id: int, card_suit: int, card_rank: int) -> Card:
	var c: Card = Card.new()
	c.id = card_id
	c.suit = card_suit
	c.rank = card_rank
	c.point_value = GameConfig.points_for_rank(card_rank)
	c.is_wildcard = GameConfig.is_wildcard_rank(card_rank)
	c.is_red_three = card_rank == GameConfig.Rank.THREE and GameConfig.is_red_suit(card_suit)
	c.is_black_three = card_rank == GameConfig.Rank.THREE and GameConfig.is_black_suit(card_suit)
	return c


## Representación legible para logs y depuración. No usar en UI.
func _to_string() -> String:
	const SUIT_GLYPH := ["C", "D", "H", "S", "*"]
	const RANK_GLYPH := ["A", "2", "3", "4", "5", "6", "7", "8", "9", "T", "J", "Q", "K", "JK"]
	var s: String = SUIT_GLYPH[suit] if suit >= 0 and suit < SUIT_GLYPH.size() else "?"
	var r: String = RANK_GLYPH[rank] if rank >= 0 and rank < RANK_GLYPH.size() else "?"
	return "Card#%d[%s%s]" % [id, r, s]
