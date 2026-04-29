## Combinación (meld) bajada por un equipo en la mesa.
##
## Reglas de Canasta Uruguaya soportadas:
##   - Meld natural: cartas del mismo rango (≥3), permite hasta `MAX_WILDS_PER_MELD`
##     comodines siempre que haya `MIN_NATURALS_FOR_IMPURE` o más naturales.
##   - Meld de comodines (sólo Jokers o sólo 2s): todas las cartas son comodines
##     del mismo tipo. Cuenta como rango virtual `JOKER` o `TWO`.
##   - Canasta = ≥7 cartas. Pura si 0 comodines, impura si tiene ≥1 comodín.
##
## Inmutabilidad:
##   El array `cards` es propiedad del meld; no se debe mutar desde fuera.
##   Usar `add_cards()` que valida y reintegra los contadores derivados.
class_name Meld
extends Resource

## Equipo dueño del meld.
@export var team_id: int = -1

## Rango del meld. Para melds de comodines puros: JOKER (jokers) o TWO (doses).
@export var rank: int = -1

## Cartas que componen el meld (orden de adición).
@export var cards: Array[Card] = []

## Cuántas cartas son naturales (no comodines). Recalculado en cada mutación.
@export var naturals: int = 0

## Cuántos comodines hay en el meld.
@export var wilds: int = 0


## Crea un meld vacío para un equipo y rango dado.
static func create(team_id_arg: int, rank_arg: int) -> Meld:
	var m: Meld = Meld.new()
	m.team_id = team_id_arg
	m.rank = rank_arg
	return m


## Total de cartas en el meld.
func size() -> int:
	return cards.size()


## ¿Es canasta? (≥7 cartas).
func is_canasta() -> bool:
	return cards.size() >= GameConfig.CANASTA_SIZE


## ¿Es pura? Sólo aplica cuando es canasta.
##   - Meld natural pura: 0 comodines.
##   - Meld de comodines: pura si todos del mismo subtipo (Jokers o 2s).
func is_pure() -> bool:
	if not is_canasta():
		return false
	if rank == GameConfig.Rank.JOKER or rank == GameConfig.Rank.TWO:
		# Meld de comodines: pura si todas las cartas son del subtipo declarado.
		for c in cards:
			if c.rank != rank:
				return false
		return true
	return wilds == 0


## ¿Es un meld 100% comodines (Jokers o 2s)?
func is_wildcard_meld() -> bool:
	return rank == GameConfig.Rank.JOKER or rank == GameConfig.Rank.TWO


## ¿Es meld de Ases?
func is_aces_meld() -> bool:
	return rank == GameConfig.Rank.ACE


## Suma de `point_value` de todas las cartas del meld.
func points() -> int:
	var total: int = 0
	for c in cards:
		total += c.point_value
	return total


## Verifica si añadir `extra` cartas mantiene el meld válido.
## NO muta. Devuelve true/false.
func can_add(extra: Array[Card]) -> bool:
	if extra.is_empty():
		return false
	# Construir set virtual de cartas resultante.
	var virt_cards: Array[Card] = cards.duplicate()
	for c in extra:
		virt_cards.append(c)
	return Meld.is_valid_composition(rank, virt_cards)


## Añade cartas al meld; ejecuta `can_add` y actualiza contadores.
## Devuelve true si la operación tuvo éxito.
func add_cards(extra: Array[Card]) -> bool:
	if not can_add(extra):
		return false
	for c in extra:
		cards.append(c)
		if c.is_wildcard:
			wilds += 1
		else:
			naturals += 1
	return true


# ---------------------------------------------------------------------------
# Validadores estáticos (puros)
# ---------------------------------------------------------------------------

## Valida la composición de un conjunto de cartas como meld del rango dado.
## - Mínimo 3 cartas.
## - Si rango es JOKER o TWO: TODAS deben ser comodines del subtipo correcto.
## - Si rango natural (4..K, A): naturales de ese rango + ≤MAX_WILDS comodines,
##   y siempre debe haber al menos 2 naturales (regla canasta clásica).
## - No se permite TRES como rango de meld (los treses no se bajan).
static func is_valid_composition(rank_arg: int, candidate: Array[Card]) -> bool:
	if candidate.size() < 3:
		return false
	if rank_arg == GameConfig.Rank.THREE:
		return false  # Treses nunca forman meld.

	# Meld de comodines puros: todas las cartas son del subtipo `rank_arg`.
	if rank_arg == GameConfig.Rank.JOKER or rank_arg == GameConfig.Rank.TWO:
		for c in candidate:
			if c.rank != rank_arg:
				return false
			if not c.is_wildcard:
				return false
		return true

	# Meld natural: cartas del rango exacto + comodines.
	var nat: int = 0
	var wld: int = 0
	for c in candidate:
		if c.is_wildcard:
			wld += 1
		elif c.rank == rank_arg:
			nat += 1
		else:
			return false  # Carta de rango distinto y no comodín.
	if nat < 2:
		return false
	if wld > GameConfig.MAX_WILDS_PER_MELD:
		return false
	return true


## Inferir el rango natural de un conjunto de cartas (excluyendo comodines).
## Devuelve -1 si no hay rango natural unánime o no hay naturales.
static func infer_rank(candidate: Array[Card]) -> int:
	var found: int = -1
	for c in candidate:
		if c.is_wildcard:
			continue
		if found == -1:
			found = c.rank
		elif c.rank != found:
			return -1
	return found
