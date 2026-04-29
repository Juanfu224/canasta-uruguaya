## Calculadora de puntos al final de una mano.
##
## Reglas (ver `docs/arquitectura-canasta-uruguaya.md` y `plan.md`):
##   1. Bonos de canasta:                pure 500, impure 200,
##                                       wilds pure 3000, wilds impure 2000,
##                                       aces pure 800, aces impure 500.
##   2. Bonus puntos de cartas en melds: suma de `point_value`.
##   3. Treses rojos: +100 c/u; +400 extra si los 4 (total 800).
##                    Si el equipo NO logró ninguna canasta → invertidos
##                    a negativo (mismas magnitudes).
##   4. Penalización 4 Treses Negros al cierre (atrapados en cualquier mano):
##      −500 al equipo que los descartó / acumuló (regla casa: aplicado al equipo
##      cerrador si los tiene).
##   5. Bonus por cierre: +100 (si cierra normal). +200 si cierra "en mano"
##      (sin bajar nada antes en la mano). El que cierra recibe este bonus.
##   6. Cartas que quedan en mano al cierre: descontadas (suma negativa).
##   7. Penalización por robo fuera de orden: −100, sumada externamente
##      via `apply_draw_out_of_order_penalty`.
class_name ScoreCalculator
extends RefCounted


## Calcula el delta de puntos para un equipo al final de la mano y lo aplica
## a `team.hand_score`. Devuelve el delta calculado.
##
## Parámetros:
##   `team`            estado del equipo a puntuar
##   `is_closer`       true si este equipo cerró la mano
##   `closed_in_hand`  true si cerró sin haber bajado nada antes (cierre "en mano")
##   `players_hands`   array de Array[Card] con las cartas que cada miembro
##                     del equipo tenía en mano al momento del cierre
##   `black_threes_caught` total de Treses Negros que el equipo terminó
##                     poseyendo (en mesa o capturados)
static func score_team(
	team: TeamState,
	is_closer: bool,
	closed_in_hand: bool,
	players_hands: Array,
	black_threes_caught: int
) -> int:
	var delta: int = 0

	# 1. Bonos de canasta + 2. puntos de las cartas en meld.
	for m in team.melds:
		delta += m.points()
		if m.is_canasta():
			delta += _canasta_bonus(m)

	# 3. Treses rojos.
	var has_canasta: bool = false
	for m in team.melds:
		if m.is_canasta():
			has_canasta = true
			break
	var rt_count: int = team.red_threes.size()
	var rt_score: int = rt_count * GameConfig.RED_THREE_BONUS
	if rt_count == 4:
		# Total deseado: 800 → ya hay 400 por individuales, +400 extra.
		rt_score += GameConfig.RED_THREE_FULL_SET_BONUS - 4 * GameConfig.RED_THREE_BONUS
	if not has_canasta:
		rt_score = -rt_score
	delta += rt_score

	# 4. Penalización 4 Treses Negros (regla casa).
	if black_threes_caught >= 4:
		delta += GameConfig.BLACK_THREE_FULL_SET_PENALTY

	# 5. Bonus de cierre.
	if is_closer:
		delta += 200 if closed_in_hand else 100

	# 6. Cartas en mano: descontadas.
	for h in players_hands:
		delta -= Hand.points_in_hand(h)

	team.hand_score = delta
	return delta


## Suma `hand_score` a `cumulative_score` y reinicia para la próxima mano.
static func commit_hand_score(team: TeamState) -> void:
	team.cumulative_score += team.hand_score
	team.reset_for_new_hand()


## Aplica la penalización por robar fuera de orden.
static func apply_draw_out_of_order_penalty(team: TeamState) -> void:
	team.hand_score += GameConfig.DRAW_OUT_OF_ORDER_PENALTY


# ---------------------------------------------------------------------------
# Internos
# ---------------------------------------------------------------------------

static func _canasta_bonus(m: Meld) -> int:
	if m.is_wildcard_meld():
		return GameConfig.CANASTA_WILDS_PURE_BONUS if m.is_pure() else GameConfig.CANASTA_WILDS_IMPURE_BONUS
	if m.is_aces_meld():
		return GameConfig.CANASTA_ACES_PURE_BONUS if m.is_pure() else GameConfig.CANASTA_ACES_IMPURE_BONUS
	return GameConfig.CANASTA_PURE_BONUS if m.is_pure() else GameConfig.CANASTA_IMPURE_BONUS
