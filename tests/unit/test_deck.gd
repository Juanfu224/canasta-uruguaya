## Tests unitarios para `core/deck.gd`.
## Verifican composición exacta y reproducibilidad de la mezcla.
extends GdUnitTestSuite


func test_build_standard_108_total() -> void:
	var d: Deck = Deck.build_standard_108()
	assert_int(d.size()).is_equal(108)


func test_build_standard_108_composition() -> void:
	var d: Deck = Deck.build_standard_108()

	var jokers: int = 0
	var twos: int = 0
	var aces: int = 0
	var threes_red: int = 0
	var threes_black: int = 0
	var faces: int = 0
	var lows: int = 0  # 4..7 (3 contado aparte)

	for c in d.cards:
		if c.rank == GameConfig.Rank.JOKER:
			jokers += 1
		elif c.rank == GameConfig.Rank.TWO:
			twos += 1
		elif c.rank == GameConfig.Rank.ACE:
			aces += 1
		elif c.rank == GameConfig.Rank.THREE:
			if c.is_red_three:
				threes_red += 1
			else:
				threes_black += 1
		elif c.rank in [GameConfig.Rank.KING, GameConfig.Rank.QUEEN, GameConfig.Rank.JACK,
				GameConfig.Rank.TEN, GameConfig.Rank.NINE, GameConfig.Rank.EIGHT]:
			faces += 1
		else:
			lows += 1

	assert_int(jokers).is_equal(4)
	assert_int(twos).is_equal(8)
	assert_int(aces).is_equal(8)
	assert_int(threes_red).is_equal(4)
	assert_int(threes_black).is_equal(4)
	# 6 rangos altos × 8 = 48
	assert_int(faces).is_equal(48)
	# 4 rangos bajos (4,5,6,7) × 8 = 32
	assert_int(lows).is_equal(32)


func test_unique_ids() -> void:
	var d: Deck = Deck.build_standard_108()
	var seen: Dictionary = {}
	for c in d.cards:
		assert_bool(seen.has(c.id)).is_false()
		seen[c.id] = true
	assert_int(seen.size()).is_equal(108)


func test_shuffle_is_deterministic_for_same_seed() -> void:
	var rng_a: RandomNumberGenerator = RandomNumberGenerator.new()
	rng_a.seed = 42
	var rng_b: RandomNumberGenerator = RandomNumberGenerator.new()
	rng_b.seed = 42

	var d_a: Deck = Deck.build_standard_108()
	var d_b: Deck = Deck.build_standard_108()
	d_a.shuffle(rng_a)
	d_b.shuffle(rng_b)

	for i in range(d_a.cards.size()):
		assert_int(d_a.cards[i].id).is_equal(d_b.cards[i].id)


func test_shuffle_changes_order() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1
	var d: Deck = Deck.build_standard_108()
	var original_first_id: int = d.cards[0].id
	d.shuffle(rng)
	# Probabilísticamente >99.99% de que el primer ID cambie.
	var any_changed: bool = false
	for i in range(d.cards.size()):
		if d.cards[i].id != i:
			any_changed = true
			break
	assert_bool(any_changed).is_true()
	# Doble check: la suma de IDs se conserva (no hay pérdida).
	assert_int(_sum_ids(d)).is_equal(_expected_sum())


func test_draw_n_removes_from_top() -> void:
	var d: Deck = Deck.build_standard_108()
	var top_before: Array = [d.cards[0].id, d.cards[1].id, d.cards[2].id]
	var drawn: Array[Card] = d.draw_n(3)
	assert_int(drawn.size()).is_equal(3)
	assert_int(drawn[0].id).is_equal(top_before[0])
	assert_int(drawn[1].id).is_equal(top_before[1])
	assert_int(drawn[2].id).is_equal(top_before[2])
	assert_int(d.size()).is_equal(105)


func test_draw_n_caps_at_size() -> void:
	var d: Deck = Deck.build_standard_108()
	var drawn: Array[Card] = d.draw_n(200)
	assert_int(drawn.size()).is_equal(108)
	assert_bool(d.is_empty()).is_true()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _sum_ids(d: Deck) -> int:
	var s: int = 0
	for c in d.cards:
		s += c.id
	return s


func _expected_sum() -> int:
	# Suma de 0..107 = 107*108/2.
	return 107 * 108 / 2
