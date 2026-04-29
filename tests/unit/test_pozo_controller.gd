## Tests del PozoController (taponado, cruzado, capturable_rank).
extends RefCounted

const TestAssert := preload("res://tools/test_assert.gd")

static func _card(suit: int, rank: int, id: int = 0) -> Card:
	return Card.make(id, suit, rank)

static func run() -> Array:
	var failures: Array[String] = []

	# Taponado por Tres Negro.
	var t1 := TestAssert.new("pozo_taponado")
	var p := PozoController.new()
	p.push(_card(GameConfig.Suit.HEARTS, GameConfig.Rank.SEVEN, 1))
	p.push(_card(GameConfig.Suit.SPADES, GameConfig.Rank.THREE, 2))  # 3 negro
	t1.is_true(p.is_taponado(), "taponado")
	t1.is_false(p.is_cruzado(), "no cruzado")
	failures.append_array(t1.failures)

	# Cruzado por joker → capturable_rank devuelve rango debajo.
	var t2 := TestAssert.new("pozo_cruzado_joker")
	var p2 := PozoController.new()
	p2.push(_card(GameConfig.Suit.HEARTS, GameConfig.Rank.KING, 10))
	p2.push(_card(GameConfig.Suit.JOKER, GameConfig.Rank.JOKER, 11))
	t2.is_true(p2.is_cruzado(), "cruzado")
	t2.eq(p2.capturable_rank(), GameConfig.Rank.KING, "rango debajo = KING")
	failures.append_array(t2.failures)

	# Cruzado por 2 (también comodín).
	var t3 := TestAssert.new("pozo_cruzado_two")
	var p3 := PozoController.new()
	p3.push(_card(GameConfig.Suit.HEARTS, GameConfig.Rank.SEVEN, 20))
	p3.push(_card(GameConfig.Suit.HEARTS, GameConfig.Rank.TWO, 21))  # 2 = wildcard
	t3.is_true(p3.is_cruzado(), "cruzado por 2")
	t3.eq(p3.capturable_rank(), GameConfig.Rank.SEVEN, "rango debajo = 7")
	failures.append_array(t3.failures)

	# Pozo normal.
	var t4 := TestAssert.new("pozo_normal")
	var p4 := PozoController.new()
	p4.push(_card(GameConfig.Suit.HEARTS, GameConfig.Rank.JACK, 30))
	t4.is_false(p4.is_cruzado(), "no cruzado")
	t4.is_false(p4.is_taponado(), "no taponado")
	t4.eq(p4.capturable_rank(), GameConfig.Rank.JACK, "JACK")
	failures.append_array(t4.failures)

	# Vacío.
	var t5 := TestAssert.new("pozo_empty")
	var p5 := PozoController.new()
	t5.is_true(p5.is_empty(), "empty")
	t5.eq(p5.capturable_rank(), -1, "rank -1")
	failures.append_array(t5.failures)

	# take_all vacía la pila.
	var t6 := TestAssert.new("pozo_take_all")
	var p6 := PozoController.new()
	p6.push(_card(GameConfig.Suit.HEARTS, GameConfig.Rank.JACK, 40))
	p6.push(_card(GameConfig.Suit.SPADES, GameConfig.Rank.JACK, 41))
	var taken: Array = p6.take_all()
	t6.eq(taken.size(), 2, "tomó 2")
	t6.is_true(p6.is_empty(), "vacío")
	failures.append_array(t6.failures)

	return failures
