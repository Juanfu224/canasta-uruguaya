## Estado completo de una partida en curso.
##
## Es la única "fuente de verdad" mientras corre la partida y se sostiene
## exclusivamente en el host autoritativo (F5). Los clientes reciben proyecciones
## (mano propia + cuenta de cartas rivales) vía `MultiplayerSynchronizer`.
##
## Diseño:
##   - Resource para serialización trivial (snapshots / reconexión).
##   - Sin lógica de negocio: las mutaciones pasan por `RulesEngine`.
class_name MatchState
extends Resource

@export var config: MatchConfig

## `Deck` no es Resource (es RefCounted con cartas), por eso lo guardamos vivo.
var deck: Deck

## Pila de descarte (controller con flags de taponado/cruzado).
var pozo: PozoController

## Manos privadas: índice = `player_id`. Cada mano es Array[Card].
@export var hands: Array = []  # Array[Array[Card]] — Godot no soporta nested typed arrays.

## Estados por equipo: índice = `team_id`.
@export var teams: Array[TeamState] = []

## Jugador al que le toca actuar.
@export var current_player: int = 0

## ¿La partida llegó al final (un equipo alcanzó target_score)?
@export var match_finished: bool = false

## ¿La mano actual terminó (alguien cerró o se agotó el mazo)?
@export var hand_finished: bool = false

## Identidad del jugador que cerró la mano (-1 si nadie cerró).
@export var closer_player_id: int = -1


static func create(cfg: MatchConfig) -> MatchState:
	var s: MatchState = MatchState.new()
	s.config = cfg
	s.hands.resize(cfg.n_players)
	for i in range(cfg.n_players):
		s.hands[i] = [] as Array[Card]
	s.teams.resize(cfg.n_teams)
	for t in range(cfg.n_teams):
		s.teams[t] = TeamState.create(t)
	return s


## Devuelve el `TeamState` del jugador.
func team_of(player_id: int) -> TeamState:
	return teams[config.team_of_player(player_id)]


func hand_of(player_id: int) -> Array:
	return hands[player_id]


## Avanza el turno al siguiente jugador (orden en sentido de la partida).
func advance_turn() -> void:
	current_player = (current_player + 1) % config.n_players
