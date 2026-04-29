## Configuración inmutable de una partida.
class_name MatchConfig
extends Resource

@export var n_players: int = 4
@export var n_teams: int = 2
@export var target_score: int = GameConfig.TARGET_SCORE_STANDARD
## Semilla para el RNG de la partida (mezcla del mazo). Reproducible.
@export var seed: int = 0


static func standard_2v2(seed_arg: int = 0) -> MatchConfig:
	var c: MatchConfig = MatchConfig.new()
	c.n_players = 4
	c.n_teams = 2
	c.target_score = GameConfig.TARGET_SCORE_STANDARD
	c.seed = seed_arg
	return c


## Devuelve el `team_id` (0..n_teams-1) del jugador `player_id` (0..n_players-1).
## Asignación: alterna por índice (player 0,2 → equipo 0; player 1,3 → equipo 1).
func team_of_player(player_id: int) -> int:
	return player_id % n_teams
