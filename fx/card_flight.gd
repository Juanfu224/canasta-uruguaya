## Helper estático para animar un nodo Control siguiendo una curva Bezier
## cuadrática entre dos puntos. Pensado para "vuelo" de cartas:
##   - Robo (mazo → mano).
##   - Descarte (mano → pozo).
##   - Captura del pozo (pozo → mano).
##
## Uso:
##   `await CardFlight.fly(card, from_global, to_global, 0.35, arc_height_px=80.0)`
##
## El nodo se tween-anima en 'global_position' usando un control point
## desplazado perpendicularmente al vector from→to. Sin signals, sin estado:
## el caller decide qué hacer al completar.
class_name CardFlight
extends RefCounted


## Anima `node` por una curva Bezier cuadrática.
## - `from`, `to`: posiciones globales.
## - `duration`: segundos.
## - `arc_height`: altura del arco en pixeles (perpendicular).
## - `rotate_full_turn`: si true, suma 2π a la rotación durante el vuelo.
##
## Devuelve un Tween para que el caller pueda await.
static func fly(
	node: Control,
	from: Vector2,
	to: Vector2,
	duration: float = 0.35,
	arc_height: float = 80.0,
	rotate_full_turn: bool = false,
) -> Tween:
	if node == null or not node.is_inside_tree():
		return null

	var tree: SceneTree = node.get_tree()
	var tween: Tween = tree.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Bezier cuadrático: control point perpendicular al midpoint.
	var mid: Vector2 = (from + to) * 0.5
	var dir: Vector2 = (to - from)
	var perp: Vector2 = Vector2(-dir.y, dir.x).normalized() * arc_height
	var control: Vector2 = mid + perp

	# Capturamos referencias por copia para el closure.
	var _from: Vector2 = from
	var _to: Vector2 = to
	var _ctrl: Vector2 = control
	var update_pos := func(t: float) -> void:
		if not is_instance_valid(node):
			return
		node.global_position = _bezier(_from, _ctrl, _to, t)

	tween.tween_method(update_pos, 0.0, 1.0, duration)

	if rotate_full_turn:
		var start_rot: float = node.rotation
		tween.parallel().tween_property(node, "rotation", start_rot + TAU, duration)

	return tween


static func _bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var u: float = 1.0 - t
	return (u * u) * p0 + (2.0 * u * t) * p1 + (t * t) * p2
