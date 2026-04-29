## Estado mutable de un equipo durante una partida.
class_name TeamState
extends Resource

@export var team_id: int = -1

## Puntos obtenidos en la mano actual (se reinicia al empezar la próxima).
@export var hand_score: int = 0

## Puntos acumulados en la partida (suma de manos pasadas; determina umbrales).
@export var cumulative_score: int = 0

## ¿El equipo ha bajado al menos un meld en la mano actual?
@export var opened: bool = false

## Melds bajados por el equipo en la mano actual.
@export var melds: Array[Meld] = []

## Treses rojos capturados (se muestran inmediatamente al robarse).
@export var red_threes: Array[Card] = []


static func create(team_id_arg: int) -> TeamState:
	var t: TeamState = TeamState.new()
	t.team_id = team_id_arg
	return t


## Reinicia el estado de mano (no toca `cumulative_score`).
func reset_for_new_hand() -> void:
	hand_score = 0
	opened = false
	melds.clear()
	red_threes.clear()


## ¿Tiene al menos una canasta pura en mesa?
func has_pure_canasta() -> bool:
	for m in melds:
		if m.is_canasta() and m.is_pure():
			return true
	return false


## ¿Tiene al menos una canasta impura en mesa?
func has_impure_canasta() -> bool:
	for m in melds:
		if m.is_canasta() and not m.is_pure():
			return true
	return false


## ¿Cumple los requisitos para cerrar la mano? (≥1 pura y ≥1 impura).
func can_close() -> bool:
	return has_pure_canasta() and has_impure_canasta()


## Busca un meld del equipo de un rango dado. Devuelve null si no existe.
func find_meld_by_rank(rank_arg: int) -> Meld:
	for m in melds:
		if m.rank == rank_arg:
			return m
	return null
