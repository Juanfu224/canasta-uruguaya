## Tests unitarios de la matemática del fanning de `HandLayout`.
##
## Patrón de test del repo (igual que `tests/unit/test_meld.gd`): clase
## `RefCounted` con `static func run() -> Array`. Lanzado por
## `tools/run_f3_smoke.gd`.
##
## Solo verifica `HandLayout.compute_layout`, que es pura: no instancia
## nodos ni tweens. La validación visual del abanico se hace con
## `scenes/MatchOffline.tscn`.
extends RefCounted

const TestAssert := preload("res://tools/test_assert.gd")

const _CONTAINER_W: float = 680.0
const _SPACING: float = 88.0
const _ANGLE: float = 22.0
const _ARC: float = 22.0
const _EPS: float = 0.01


static func _layout(n: int, concave_down: bool = false) -> Array:
	return HandLayout.compute_layout(n, _CONTAINER_W, _SPACING, _ANGLE, _ARC, concave_down)


static func _approx_eq(a: float, b: float, eps: float = _EPS) -> bool:
	return absf(a - b) <= eps


static func run() -> Array:
	var failures: Array[String] = []

	# 1. Tamaño 0 o negativo → lista vacía.
	var t1 := TestAssert.new("compute_layout_empty")
	t1.eq(_layout(0).size(), 0, "n=0")
	t1.eq(_layout(-3).size(), 0, "n=-3")
	failures.append_array(t1.failures)

	# 2. Una sola carta: centrada y rotación 0.
	var t2 := TestAssert.new("compute_layout_single_centered")
	var single: Array = _layout(1)
	t2.eq(single.size(), 1, "1 transform")
	if single.size() == 1:
		var s: Dictionary = single[0]
		var expected_x: float = (_CONTAINER_W - CardUI.CARD_SIZE.x) * 0.5
		t2.is_true(_approx_eq(s.position.x, expected_x), "x centrado")
		t2.is_true(_approx_eq(s.rotation, 0.0, 0.0001), "rot 0")
	failures.append_array(t2.failures)

	# 3. Rotaciones simétricas para cualquier n>1.
	var t3 := TestAssert.new("compute_layout_rotations_symmetric")
	for n in [2, 3, 7, 11, 20]:
		var arr: Array = _layout(n)
		var first: float = arr[0].rotation
		var last: float = arr[n - 1].rotation
		t3.is_true(_approx_eq(first + last, 0.0, 0.0001), "n=%d simétrico" % n)
	failures.append_array(t3.failures)

	# 4. Curva cóncava hacia arriba (default): extremos por encima del centro.
	# Con arc_sign = -1 los extremos tienen y < 0; el medio y ≈ 0.
	var t4 := TestAssert.new("compute_layout_arc_concave_up")
	var arr_up: Array = _layout(11, false)
	t4.is_true(arr_up[0].position.y < arr_up[5].position.y, "extremo izq < medio")
	t4.is_true(arr_up[10].position.y < arr_up[5].position.y, "extremo der < medio")
	failures.append_array(t4.failures)

	# 5. concave_down invierte la y manteniendo el módulo.
	var t5 := TestAssert.new("compute_layout_arc_invertible")
	var arr_dn: Array = _layout(11, true)
	for i in 11:
		t5.is_true(_approx_eq(arr_up[i].position.y, -arr_dn[i].position.y, 0.001),
				"y_up == -y_dn @i=%d" % i)
	failures.append_array(t5.failures)

	# 6. Espaciado se colapsa cuando hay demasiadas cartas (no se sale del
	# contenedor). Con 25 cartas y spacing=88, 24*88=2112 > 680.
	var t6 := TestAssert.new("compute_layout_spacing_clamps")
	var n_big: int = 25
	var arr_big: Array = _layout(n_big)
	var x_first: float = arr_big[0].position.x
	var x_last: float = arr_big[n_big - 1].position.x
	t6.is_true(x_first >= -1.0, "x_first dentro del contenedor")
	t6.is_true(x_last + CardUI.CARD_SIZE.x <= _CONTAINER_W + 1.0, "x_last dentro del contenedor")
	# Spacing real ≤ max_spacing.
	var spacing_real: float = arr_big[1].position.x - arr_big[0].position.x
	t6.is_true(spacing_real <= _SPACING + 0.001, "spacing real ≤ max")
	failures.append_array(t6.failures)

	# 7. Estructura del payload (claves y tipos).
	var t7 := TestAssert.new("compute_layout_payload_shape")
	for entry in _layout(5):
		var d: Dictionary = entry
		t7.is_true(d.has("position"), "tiene position")
		t7.is_true(d.has("rotation"), "tiene rotation")
		t7.is_true(d.position is Vector2, "position Vector2")
		t7.is_true(d.rotation is float, "rotation float")
	failures.append_array(t7.failures)

	return failures
