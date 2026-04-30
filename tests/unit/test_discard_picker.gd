## Tests unitarios de DiscardPicker.
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

	# 1. Si hay tres negro en mano, se descarta primero.
	var t1 := TestAssert.new("discard_black_three_first")
	var s1 := _state()
	s1.hands[0] = [
		_natural(GameConfig.Rank.KING, 100),
		_bt(7),  # id menor, además es BT
		_joker(50),
	]
	t1.eq(DiscardPicker.pick(s1, 0), 7, "BT id=7")
	failures.append_array(t1.failures)

	# 2. Sin BT, no descarta comodín si hay otra opción.
	var t2 := TestAssert.new("discard_avoid_wildcard")
	var s2 := _state()
	s2.hands[0] = [
		_natural(GameConfig.Rank.KING, 1),
		_joker(2),
		_natural(GameConfig.Rank.SEVEN, 3),
	]
	var pick2: int = DiscardPicker.pick(s2, 0)
	t2.is_true(pick2 != 2, "no descarta joker")
	failures.append_array(t2.failures)

	# 3. Prefiere descartar carta huérfana (mejor que carta con compañeras).
	var t3 := TestAssert.new("discard_orphan_pref")
	var s3 := _state()
	s3.hands[0] = [
		_natural(GameConfig.Rank.SEVEN, 10),
		_natural(GameConfig.Rank.SEVEN, 11),
		_natural(GameConfig.Rank.SEVEN, 12),
		_natural(GameConfig.Rank.KING, 13),  # huérfana
	]
	t3.eq(DiscardPicker.pick(s3, 0), 13, "descarta KING huérfana")
	failures.append_array(t3.failures)

	return failures
