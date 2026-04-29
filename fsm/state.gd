## Base abstracta para estados del Game Loop. Cada estado expone un ciclo
## `_enter / _process / _exit` y referencia al `MatchState` y a la
## `GameStateMachine` que lo aloja.
class_name GameState
extends RefCounted

## Maquina dueña del estado. Inyectada por `GameStateMachine.transition_to`.
var fsm: GameStateMachine

## Identificador estable del estado (string corto), útil para logs/snapshots.
func name() -> String:
	return "GameState"

func _enter(_state: MatchState) -> void:
	pass

## Procesa eventos / decisiones. Devuelve la próxima clase de estado a
## transicionar, o `null` si el estado se mantiene.
func _process(_state: MatchState) -> Script:
	return null

func _exit(_state: MatchState) -> void:
	pass
