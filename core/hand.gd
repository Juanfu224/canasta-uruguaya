## Helpers para manipular manos (Array[Card]).
##
## Las manos son `Array[Card]` planos. Estas funciones son puras (no mutan
## salvo `add` / `remove_ids` que devuelven nuevos arrays).
class_name Hand
extends RefCounted


## Inserta una carta al final.
static func add_card(hand: Array, card: Card) -> void:
	hand.append(card)


## Elimina la primera ocurrencia de una carta por id. Devuelve true si se quitó.
static func remove_by_id(hand: Array, card_id: int) -> bool:
	for i in range(hand.size()):
		if (hand[i] as Card).id == card_id:
			hand.remove_at(i)
			return true
	return false


## Quita varias cartas a la vez por sus ids. Devuelve las cartas removidas
## (en el orden que aparecen en la mano original). Si alguno de los ids no
## está, devuelve un array vacío y NO muta la mano.
static func remove_by_ids(hand: Array, ids: PackedInt32Array) -> Array[Card]:
	var idx_to_remove: Array[int] = []
	var removed: Array[Card] = []
	# Mapear ids → índices en mano. Validar todos antes de mutar.
	var id_set: Dictionary = {}
	for cid in ids:
		id_set[cid] = (id_set.get(cid, 0) as int) + 1
	for i in range(hand.size()):
		var c: Card = hand[i]
		if id_set.has(c.id) and (id_set[c.id] as int) > 0:
			idx_to_remove.append(i)
			removed.append(c)
			id_set[c.id] = (id_set[c.id] as int) - 1
	# Verificar que se encontraron todos.
	for v in id_set.values():
		if (v as int) > 0:
			return [] as Array[Card]
	# Eliminar de mayor a menor índice para no invalidar.
	idx_to_remove.reverse()
	for i in idx_to_remove:
		hand.remove_at(i)
	return removed


## Cuenta cartas naturales (no comodín) de un rango específico en la mano.
static func count_naturals_of_rank(hand: Array, rank: int) -> int:
	var n: int = 0
	for c in hand:
		if not c.is_wildcard and c.rank == rank:
			n += 1
	return n


## Suma de point_value de las cartas que quedan en mano (penalización al cierre).
static func points_in_hand(hand: Array) -> int:
	var total: int = 0
	for c in hand:
		total += c.point_value
	return total


## Extrae todos los treses rojos de la mano y los devuelve. Muta la mano.
static func extract_red_threes(hand: Array) -> Array[Card]:
	var out: Array[Card] = []
	var i: int = 0
	while i < hand.size():
		var c: Card = hand[i]
		if c.is_red_three:
			out.append(c)
			hand.remove_at(i)
		else:
			i += 1
	return out
