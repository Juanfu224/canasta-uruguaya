## Tabla canónica `id → Card` (0..107).
##
## Sirve para que los clientes reconstruyan `Card` a partir de IDs recibidos
## por la red, sin que el host tenga que difundir las cartas serializadas.
## Esto reduce el ancho de banda y elimina la posibilidad de que un host
## malicioso falsifique propiedades de una carta (rango/palo/valor) — el
## cliente las deriva localmente del id.
##
## El orden de los IDs es el de `Deck.build_standard_108()`. Si esa función
## cambia, esta tabla se reconstruye automáticamente al primer uso.
class_name CardLookup
extends RefCounted


static var _by_id: Array[Card] = []


## Devuelve la `Card` (resource canónica) con el id dado, o null si está
## fuera de rango.
static func get_by_id(id: int) -> Card:
	if _by_id.is_empty():
		_build_table()
	if id < 0 or id >= _by_id.size():
		return null
	return _by_id[id]


## Resuelve un array de IDs a cartas. Devuelve un array vacío si algún id
## es inválido (fail-fast: detectar payloads corruptos antes de tocar UI).
static func resolve(ids: PackedInt32Array) -> Array[Card]:
	if _by_id.is_empty():
		_build_table()
	var out: Array[Card] = []
	for id in ids:
		if id < 0 or id >= _by_id.size():
			return [] as Array[Card]
		out.append(_by_id[id])
	return out


static func _build_table() -> void:
	# Reusa el mazo canónico para construir la tabla. NO se baraja: el orden
	# canónico mapea id → (suit, rank) directamente.
	var deck: Deck = Deck.build_standard_108()
	_by_id.resize(deck.cards.size())
	for c in deck.cards:
		_by_id[c.id] = c
