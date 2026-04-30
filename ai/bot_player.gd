## Interfaz abstracta de un bot heurístico.
##
## Toma decisiones puramente sobre el `MatchState` autoritativo (host) y la
## fase FSM actual. NUNCA expone ni lee información privada de otros
## jugadores: solo accede a `state.hands[own_player_id]` y al estado público
## (pozo, melds del equipo, mazo size, scores).
##
## Cada subclase implementa `decide()`. La lógica determinista consulta a
## `RngService.match_rng` solo para desempates (preserva la repetibilidad
## bajo seed fija).
class_name BotPlayer
extends RefCounted

## Nivel de dificultad del bot (informativo).
var level: int = GameConfig.BotLevel.NORMAL


## Devuelve la decisión a ejecutar para el jugador `player_id` dado el
## `phase` actual ("DrawPhase" | "PlayPhase" | "DiscardPhase").
##
## Contrato:
##   - SIEMPRE devuelve una `BotDecision` válida y compatible con la fase.
##   - DrawPhase   → kind ∈ {"draw","capture"}.
##   - PlayPhase   → kind ∈ {"meld","close","pass_play"}.
##   - DiscardPhase→ kind == "discard".
##   - Las cartas reclamadas siempre pertenecen a la mano del jugador.
func decide(_state: MatchState, _player_id: int, _phase: String) -> BotDecision:
	push_error("BotPlayer.decide: subclase debe implementar")
	return BotDecision.pass_play()
