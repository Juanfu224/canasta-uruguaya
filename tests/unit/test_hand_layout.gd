## Tests unitarios de la matemática de fanning de `HandLayout`.
##
## Solo verifican la función estática `compute_layout`, que es pura: no
## requiere instanciar nodos ni viewport. El layout completo con tweens se
## valida visualmente en `scenes/MatchOffline.tscn` (criterio de aceptación
## de F3).
extends RefCounted

const TestAssert := preload("res://tools/test_assert.gd")

const _CONTAINER_W: float = 680.0
const _SPACING: float = 88.0
const _ANGLE: float = 22.0
const _ARC: float = 22.0


static func _layout(n: int, concave_down: bool = false) -> Array:
	return HandLayout.compute_layout(n, _CONTAINER_W, _SPACING, _ANGLE, _ARC, concave_down)


static func run() -> Array:
	var failures: Array[String] = []

	# ------------------------------------------------------------------
	# 1. Array vacío con n <= 0.
	# ------------------------------------------------------------------
	var t1 := TestAssert.new("empty_returns_empty_array")
	t1.eq(_layout(0).size(), 0, "n=0")
	t1.eq(_layout(-3).size(), 0, "n=-3")
	failures.append_array(t1.failures)

	# ------------------------------------------------------------------
	# 2. Carta única centrada con rotación cero.
	# ------------------------------------------------------------------
	var t2 := TestAssert.new("single_card_centered_zero_rotation")
	var out2: Array = _layout(1)
	t2.eq(out2.size(), 1, "size=1")
	var d2: Dictionary = out2[0]
	var expected_x: float = (_CONTAINER_W - CardUI.CARD_SIZE.x) * 0.5
	t2.is_true(absf((d2.position as Vector2).x - expected_x) < 0.01, "x centrado")
	t2.is_true(absf(d2.rotation as float) < 0.0001, "rotation=0")
	failures.append_array(t2.failures)

	# ------------------------------------------------------------------
	# 3. Rotaciones simétricas (primera + última ≈ 0).
	# ------------------------------------------------------------------
	var t3 := TestAssert.new("rotations_symmetric")
	for n: int in [3, 7, 11, 20]:
		var out3: Array = _layout(n)
		var sum: float = (out3[0].rotation as float) + (out3[n - 1].rotation as float)
		t3.is_true(absf(sum) < 0.0001, "simétrico n=%d" % n)
	failures.append_array(t3.failures)

	# ------------------------------------------------------------------
	# 4. Arco cóncavo hacia arriba: extremos más altos que el centro.
	# ------------------------------------------------------------------
	var t4 := TestAssert.new("arc_extremes_above_center_concave_up")
	var out4: Array = _layout(11, false)
	var y_first: float = (out4[0].position as Vector2).y
	var y_mid: float   = (out4[5].position as Vector2).y
	var y_last: float  = (out4[10].position as Vector2).y
	t4.is_true(y_first < y_mid, "extremo izq más alto")
	t4.is_true(y_last < y_mid, "extremo der más alto")
	failures.append_array(t4.failures)

	# ------------------------------------------------------------------
	# 5. Arco invertido con concave_down.
	# ------------------------------------------------------------------
	var t5 := TestAssert.new("arc_inverts_concave_down")
	var up: Array   = _layout(11, false)
	var down: Array = _layout(11, true)
	for i: int in 11:
		var diff: float = (up[i].position as Vector2).y + (down[i].position as Vector2).y
		t5.is_true(absf(diff) < 0.001, "y invertida i=%d" % i)
	failures.append_array(t5.failures)

	# ------------------------------------------------------------------
	# 6. Espaciado colapsado cuando hay demasiadas cartas.
	# ------------------------------------------------------------------
	var t6 := TestAssert.new("spacing_collapses_many_cards")
	var n6: int = 25
	var out6: Array = _layout(n6)
	var x_first: float = (out6[0].position as Vector2).x
	var x_last: float  = (out6[n6 - 1].position as Vector2).x
	t6.is_true(x_first >= -1.0, "primera carta no fuera del borde izq")
	t6.is_true(x_last + CardUI.CARD_SIZE.x <= _CONTAINER_W + 1.0, "última carta no fuera del borde der")
	var spacing6: float = (out6[1].position as Vector2).x - (out6[0].position as Vector2).x
	t6.is_true(spacing6 <= _SPACING + 0.001, "espaciado <= max_spacing")
	failures.append_array(t6.failures)

	# ------------------------------------------------------------------
	# 7. Todas las entradas tienen las claves y tipos esperados.
	# ------------------------------------------------------------------
	var t7 := TestAssert.new("consistent_keys_and_types")
	for entry: Dictionary in _layout(5):
		t7.is_true(entry.has("position"), "has position")
		t7.is_true(entry.has("rotation"), "has rotation")
		t7.is_true(entry.position is Vector2, "position is Vector2")
		t7.is_true(entry.rotation is float, "rotation is float")
	failures.append_array(t7.failures)

	return failures
