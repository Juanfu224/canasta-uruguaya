## Tests unitarios de Meld (composición, canasta pura/impura, comodines).
extends RefCounted

const TestAssert := preload("res://tools/test_assert.gd")


static func _natural(rank: int, id: int = 0, suit: int = GameConfig.Suit.CLUBS) -> Card:
	# Para tests; treses se evitan, así que ok usar cualquier suit/rank.
	return Card.make(id, suit, rank)


static func _joker(id: int = 1000) -> Card:
	return Card.make(id, GameConfig.Suit.JOKER, GameConfig.Rank.JOKER)


static func _two(id: int = 2000) -> Card:
	return Card.make(id, GameConfig.Suit.HEARTS, GameConfig.Rank.TWO)


static func run() -> Array:
	var failures: Array[String] = []

	# 1. Meld natural válido (3 reyes).
	var t1 := TestAssert.new("meld_natural_3_kings")
	var cards := [_natural(GameConfig.Rank.KING, 1),
				_natural(GameConfig.Rank.KING, 2),
				_natural(GameConfig.Rank.KING, 3)] as Array[Card]
	t1.is_true(Meld.is_valid_composition(GameConfig.Rank.KING, cards), "3 reyes válidos")
	failures.append_array(t1.failures)

	# 2. Meld con 1 comodín (2 naturales + 1 joker).
	var t2 := TestAssert.new("meld_2_kings_1_joker")
	var cards2 := [_natural(GameConfig.Rank.KING, 4),
				_natural(GameConfig.Rank.KING, 5),
				_joker(6)] as Array[Card]
	t2.is_true(Meld.is_valid_composition(GameConfig.Rank.KING, cards2), "2 nat + 1 wild")
	failures.append_array(t2.failures)

	# 3. Meld con 1 natural + 2 comodines → inválido (necesita ≥2 naturales).
	var t3 := TestAssert.new("meld_1_nat_2_wild_invalid")
	var cards3 := [_natural(GameConfig.Rank.KING, 7),
				_joker(8),
				_two(9)] as Array[Card]
	t3.is_false(Meld.is_valid_composition(GameConfig.Rank.KING, cards3), "1 nat + 2 wild inválido")
	failures.append_array(t3.failures)

	# 4. Meld con 4 comodines → excede MAX_WILDS_PER_MELD=3.
	var t4 := TestAssert.new("meld_4_wilds_exceeds")
	var cards4 := [_natural(GameConfig.Rank.KING, 10),
				_natural(GameConfig.Rank.KING, 11),
				_natural(GameConfig.Rank.KING, 12),
				_natural(GameConfig.Rank.KING, 13),
				_joker(14), _joker(15), _joker(16), _joker(17)] as Array[Card]
	t4.is_false(Meld.is_valid_composition(GameConfig.Rank.KING, cards4), "4 wilds inválido")
	failures.append_array(t4.failures)

	# 5. Meld de jokers puro (todos jokers).
	var t5 := TestAssert.new("wildcard_meld_jokers_pure")
	var cards5 := [_joker(20), _joker(21), _joker(22)] as Array[Card]
	t5.is_true(Meld.is_valid_composition(GameConfig.Rank.JOKER, cards5), "3 jokers válido")
	failures.append_array(t5.failures)

	# 6. Meld de doses puro (todos 2s).
	var t6 := TestAssert.new("wildcard_meld_twos_pure")
	var cards6 := [_two(30), _two(31), _two(32)] as Array[Card]
	t6.is_true(Meld.is_valid_composition(GameConfig.Rank.TWO, cards6), "3 doses válido")
	failures.append_array(t6.failures)

	# 7. Meld JOKER no admite mezcla con 2s.
	var t7 := TestAssert.new("wildcard_meld_jokers_with_two_invalid")
	var cards7 := [_joker(40), _joker(41), _two(42)] as Array[Card]
	t7.is_false(Meld.is_valid_composition(GameConfig.Rank.JOKER, cards7), "joker + 2 inválido")
	failures.append_array(t7.failures)

	# 8. Meld de TRES siempre inválido.
	var t8 := TestAssert.new("meld_three_invalid")
	var cards8 := [_natural(GameConfig.Rank.THREE, 50),
				_natural(GameConfig.Rank.THREE, 51),
				_natural(GameConfig.Rank.THREE, 52)] as Array[Card]
	t8.is_false(Meld.is_valid_composition(GameConfig.Rank.THREE, cards8), "tres inválido")
	failures.append_array(t8.failures)

	# 9. is_canasta + is_pure naturales.
	var t9 := TestAssert.new("canasta_pure_natural")
	var m := Meld.create(0, GameConfig.Rank.KING)
	var seven_kings: Array[Card] = []
	for i in range(7):
		seven_kings.append(_natural(GameConfig.Rank.KING, 100 + i,
			GameConfig.Suit.CLUBS if i < 4 else GameConfig.Suit.SPADES))
	t9.is_true(m.add_cards(seven_kings), "add 7 reyes")
	t9.is_true(m.is_canasta(), "is_canasta")
	t9.is_true(m.is_pure(), "is_pure (sin wilds)")
	failures.append_array(t9.failures)

	# 10. Canasta impura (4 naturales + 3 wilds).
	var t10 := TestAssert.new("canasta_impure")
	var m2 := Meld.create(0, GameConfig.Rank.KING)
	var imp: Array[Card] = []
	for i in range(4):
		imp.append(_natural(GameConfig.Rank.KING, 200 + i, GameConfig.Suit.HEARTS))
	imp.append(_joker(204))
	imp.append(_joker(205))
	imp.append(_two(206))
	t10.is_true(m2.add_cards(imp), "4 nat + 3 wild")
	t10.is_true(m2.is_canasta(), "is_canasta")
	t10.is_false(m2.is_pure(), "is_pure false")
	failures.append_array(t10.failures)

	# 11. Canasta puramente de jokers.
	var t11 := TestAssert.new("canasta_jokers_pure")
	var m3 := Meld.create(0, GameConfig.Rank.JOKER)
	var seven_jokers: Array[Card] = []
	for i in range(7):
		seven_jokers.append(_joker(300 + i))
	t11.is_true(m3.add_cards(seven_jokers), "add 7 jokers")
	t11.is_true(m3.is_canasta() and m3.is_pure(), "canasta + pura")
	t11.is_true(m3.is_wildcard_meld(), "is_wildcard_meld")
	failures.append_array(t11.failures)

	return failures
