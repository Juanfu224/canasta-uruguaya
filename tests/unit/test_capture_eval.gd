## Tests unitarios de CaptureEval.
extends RefCounted

const TestAssert := preload("res://tools/test_assert.gd")


static func _natural(rank: int, id: int, suit: int = GameConfig.Suit.CLUBS) -> Card:
	return Card.make(id, suit, rank)


static func _joker(id: int) -> Card:
	return Card.make(id, GameConfig.Suit.JOKER, GameConfig.Rank.JOKER)


static func _bt(id: int) -> Card:
	return Card.make(id, GameConfig.Suit.SPADES, GameConfig.Rank.THREE)


static func _state() -> MatchState:
	var s := MatchState.create(MatchConfig.standard_2v2(0))
	s.deck = Deck.new()
	s.pozo = PozoController.new()
	s.current_player = 0
	return s


static func run() -> Array:
	var failures: Array[String] = []

	# 1. Pozo vacío → null.
	var t1 := TestAssert.new("capture_empty")
	var s1 := _state()
	t1.eq(CaptureEval.evaluate(s1, 0), null, "pozo vacío => null")
	failures.append_array(t1.failures)

	# 2. Pozo taponado (top = tres negro) → null.
	var t2 := TestAssert.new("capture_taponado")
	var s2 := _state()
	s2.pozo.push(_natural(GameConfig.Rank.SEVEN, 1, GameConfig.Suit.HEARTS))
	s2.pozo.push(_bt(2))
	t2.eq(CaptureEval.evaluate(s2, 0), null, "taponado => null")
	failures.append_array(t2.failures)

	# 3. Top THREE no se intenta (target rank == THREE).
	# Difícil de construir: el top no puede ser tres negro normal sin taponar.
	# Saltamos.

	# 4. Top normal con 2 naturales en mano → BotDecision.capture.
	var t4 := TestAssert.new("capture_ok")
	var s4 := _state()
	s4.pozo.push(_natural(GameConfig.Rank.SEVEN, 5, GameConfig.Suit.HEARTS))
	s4.hands[0] = [
		_natural(GameConfig.Rank.SEVEN, 6, GameConfig.Suit.CLUBS),
		_natural(GameConfig.Rank.SEVEN, 7, GameConfig.Suit.DIAMONDS),
		_natural(GameConfig.Rank.KING, 8),
	]
	var d4 := CaptureEval.evaluate(s4, 0)
	t4.not_null(d4, "decisión no-null")
	if d4 != null:
		t4.eq(d4.kind, "capture", "kind=capture")
		# Top es target natural → necesita 1 de mano.
		t4.eq(d4.card_ids.size(), 1, "1 claim card")
	failures.append_array(t4.failures)

	# 5. Top no natural target, mano sólo tiene 1 natural → null.
	var t5 := TestAssert.new("capture_insuf")
	var s5 := _state()
	s5.pozo.push(_natural(GameConfig.Rank.KING, 11, GameConfig.Suit.HEARTS))
	s5.pozo.push(_natural(GameConfig.Rank.NINE, 12, GameConfig.Suit.HEARTS))
	s5.hands[0] = [
		_natural(GameConfig.Rank.NINE, 13, GameConfig.Suit.CLUBS),
		_joker(14),
	]
	t5.eq(CaptureEval.evaluate(s5, 0), null, "1 natural no alcanza")
	failures.append_array(t5.failures)

	return failures
