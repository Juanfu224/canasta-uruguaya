## Controlador del pozo de descarte.
##
## Estados especiales:
##   - **Taponado**: el último descarte fue un Tres Negro. Mientras esté
##     taponado, no se puede capturar el pozo; el siguiente jugador debe robar.
##   - **Cruzado**: el último descarte fue un comodín (Joker o 2). Sólo se
##     puede capturar emparejando el rango natural del descarte ANTERIOR
##     mediante naturales puros (sin usar comodines de la mano para
##     completar el meld de captura). Se cruza la carta visualmente.
class_name PozoController
extends RefCounted

## Pila de descarte. La cabeza (índice -1) es la carta visible/top.
var pile: Array[Card] = []


func size() -> int:
	return pile.size()


func is_empty() -> bool:
	return pile.is_empty()


## Carta visible. null si vacío.
func top() -> Card:
	if pile.is_empty():
		return null
	return pile[-1]


## ¿El pozo está taponado por un Tres Negro arriba?
func is_taponado() -> bool:
	var t: Card = top()
	return t != null and t.is_black_three


## ¿El pozo está cruzado por un comodín arriba?
func is_cruzado() -> bool:
	var t: Card = top()
	return t != null and t.is_wildcard


## Empuja una carta al pozo (descartada por el jugador que terminó su turno).
func push(card: Card) -> void:
	pile.append(card)


## Captura todo el pozo y lo vacía. Devuelve TODAS las cartas (incluyendo top).
func take_all() -> Array[Card]:
	var taken: Array[Card] = pile.duplicate()
	pile.clear()
	return taken


## Carta debajo del top (segunda desde arriba), útil cuando el top es comodín
## (pozo cruzado) y se quiere conocer el rango natural a emparejar.
func second_from_top() -> Card:
	if pile.size() < 2:
		return null
	return pile[-2]


## Rango "natural" relevante para captura.
##   - Pozo cruzado: rango natural inmediatamente debajo del comodín.
##   - Pozo normal: rango del top.
##   - Pozo vacío: -1.
func capturable_rank() -> int:
	if pile.is_empty():
		return -1
	if is_cruzado():
		var sec: Card = second_from_top()
		if sec == null or sec.is_wildcard:
			# Si la pila debajo también es comodín o está vacía, no hay rango natural.
			return -1
		return sec.rank
	return top().rank
