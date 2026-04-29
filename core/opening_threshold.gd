## Umbrales de apertura. Wrapper sobre `GameConfig.opening_threshold_for` para
## que el módulo `core/` no tenga que depender directamente del autoload en tests
## puros, y para localizar futuras variantes (modo "fácil", custom rule sets).
class_name OpeningThreshold
extends RefCounted


static func required_for(team_cumulative_score: int) -> int:
	return GameConfig.opening_threshold_for(team_cumulative_score)


## ¿La suma de puntos de las cartas baja-das alcanza el umbral del equipo?
## - Importante: al ABRIR, sólo cuentan los puntos de las cartas que se bajan
##   en ese turno (no las que ya estaban en mesa, porque por definición no
##   las hay si el equipo no había abierto).
static func meets_threshold(team_cum_score: int, points_being_played: int) -> bool:
	return points_being_played >= required_for(team_cum_score)
