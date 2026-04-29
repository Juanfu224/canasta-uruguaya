## Máquina de estados del Game Loop. Contenedor genérico que invoca el ciclo
## `_enter / _process / _exit` sobre el estado actual y permite transiciones.
##
## Uso (host autoritativo):
##   var fsm := GameStateMachine.new(match_state)
##   fsm.start(preload("res://fsm/states/state_init_match.gd"))
##   while not match_state.match_finished:
##       fsm.tick()
class_name GameStateMachine
extends RefCounted

var match_state: MatchState
var current: GameState
var current_script: Script

## Estados visitados — útil para logging y depuración.
var history: PackedStringArray = PackedStringArray()


func _init(state: MatchState) -> void:
	match_state = state


## Comienza la FSM en el estado dado. `state_script` es el `.gd` (preload).
func start(state_script: Script) -> void:
	transition_to(state_script)


## Ejecuta `_process` del estado actual. Si éste devuelve un Script, hace
## la transición. Devuelve true si hubo transición.
func tick() -> bool:
	if current == null:
		return false
	var next_script: Script = current._process(match_state)
	if next_script != null:
		transition_to(next_script)
		return true
	return false


func transition_to(state_script: Script) -> void:
	if current != null:
		current._exit(match_state)
	current_script = state_script
	current = state_script.new() as GameState
	current.fsm = self
	history.append(current.name())
	current._enter(match_state)
