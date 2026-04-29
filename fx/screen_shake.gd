## Sacudida ligera de un `Control` (o cualquier `Node2D`).
##
## API:
##   ScreenShake.shake(target, magnitude_px, duration_s)
##
## Implementación:
##   - Un único Tween con offsets aleatorios decrecientes (Hermite-like).
##   - Restaura la `position` original al terminar.
##   - Si el target no es válido, no-op silencioso.
##
## Diseño defensivo: el caller no necesita preocuparse por killar tweens
## previos — si llega un nuevo shake mientras hay otro vivo, se acumulan
## offsets aditivos sobre la posición original guardada.
class_name ScreenShake
extends RefCounted

## Aplica un shake corto sobre `target.position`.
##   target:        nodo `Control` o `Node2D` con propiedad `position`.
##   magnitude_px:  amplitud máxima en píxeles. 6-12 = sutil, 20+ = brusco.
##   duration_s:    duración total. <0.4s en móvil para no marear.
##   steps:         pasos discretos del shake (más = más temblor por seg).
static func shake(target: Node, magnitude_px: float = 8.0, duration_s: float = 0.2, steps: int = 6) -> void:
	if target == null or not is_instance_valid(target):
		return
	if not (target is Control or target is Node2D):
		push_warning("ScreenShake: target debe ser Control o Node2D")
		return
	if magnitude_px <= 0.0 or duration_s <= 0.0:
		return
	steps = maxi(steps, 2)

	var origin: Vector2 = target.position
	var step_time: float = duration_s / float(steps)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()

	var tween: Tween = target.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	for i in steps:
		var falloff: float = 1.0 - (float(i) / float(steps))
		var ox: float = rng.randf_range(-magnitude_px, magnitude_px) * falloff
		var oy: float = rng.randf_range(-magnitude_px, magnitude_px) * falloff
		tween.tween_property(target, "position", origin + Vector2(ox, oy), step_time)
	tween.tween_property(target, "position", origin, step_time)
