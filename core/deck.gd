## Mazo determinista de 108 cartas (2 barajas inglesas + 4 jokers).
##
## Reglas de diseño:
##   - `build_standard_108()` produce SIEMPRE el mismo orden canónico de IDs.
##     Esto permite que la mezcla sea la única fuente de aleatoriedad y que
##     las pruebas sean reproducibles.
##   - `shuffle(rng)` recibe un `RandomNumberGenerator` externo (inyectado
##     desde `RngService.match_rng`) en lugar de usar uno global. Esto evita
##     acoplamiento estático y facilita testing.
##   - `draw_n` muta el estado interno; el mazo es de uso exclusivo del host
##     autoritativo (F5).
class_name Deck
extends RefCounted

## Cartas restantes en el mazo. La cabeza (índice 0) es la próxima a robar.
var cards: Array[Card] = []


## Construye el orden canónico de las 108 cartas con IDs estables.
##
## Ordering canónico:
##   Por mazo (0..1): por palo (CLUBS, DIAMONDS, HEARTS, SPADES) por rango
##   (ACE..KING). Luego 4 jokers al final.
##   IDs van 0..103 (naturales) y 104..107 (jokers).
static func build_standard_108() -> Deck:
	var d: Deck = Deck.new()
	var next_id: int = 0
	for _deck_index in range(GameConfig.DECKS_COUNT):
		for suit in [
			GameConfig.Suit.CLUBS,
			GameConfig.Suit.DIAMONDS,
			GameConfig.Suit.HEARTS,
			GameConfig.Suit.SPADES,
		]:
			for rank in range(GameConfig.RANKS_PER_DECK):
				d.cards.append(Card.make(next_id, suit, rank))
				next_id += 1
	for _j in range(GameConfig.JOKERS_COUNT):
		d.cards.append(Card.make(next_id, GameConfig.Suit.JOKER, GameConfig.Rank.JOKER))
		next_id += 1
	return d


## Mezcla in-place usando Fisher–Yates con el RNG inyectado.
## Determinista para una seed fija → tests reproducibles.
func shuffle(rng: RandomNumberGenerator) -> void:
	assert(rng != null, "Deck.shuffle requiere un RNG no nulo")
	var n: int = cards.size()
	for i in range(n - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		if j != i:
			var tmp: Card = cards[i]
			cards[i] = cards[j]
			cards[j] = tmp


## Roba `n` cartas de la cabeza. Si quedan menos de `n`, devuelve las que haya.
func draw_n(n: int) -> Array[Card]:
	assert(n >= 0, "Deck.draw_n: n debe ser no-negativo")
	var available: int = mini(n, cards.size())
	if available == 0:
		return []
	var drawn: Array[Card] = cards.slice(0, available)
	cards = cards.slice(available)
	return drawn


func size() -> int:
	return cards.size()


func is_empty() -> bool:
	return cards.is_empty()


## Útil para snapshots / reconexión: lista de IDs en orden actual.
func to_id_array() -> PackedInt32Array:
	var ids: PackedInt32Array = PackedInt32Array()
	ids.resize(cards.size())
	for i in range(cards.size()):
		ids[i] = cards[i].id
	return ids
