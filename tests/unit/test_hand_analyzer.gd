## Tests unitarios de HandAnalyzer.
extends RefCounted

const TestAssert := preload("res://tools/test_assert.gd")


static func _natural(rank: int, id: int, suit: int = GameConfig.Suit.CLUBS) -> Card:
	return Card.make(id, suit, rank)


static func _joker(id: int) -> Card:
	return Card.make(id, GameConfig.Suit.JOKER, GameConfig.Rank.JOKER)


static func _two(id: int) -> Card:
	return Card.make(id, GameConfig.Suit.HEARTS, GameConfig.Rank.TWO)


static func _bt(id: int) -> Card:
	return Card.make(id, GameConfig.Suit.SPADES, GameConfig.Rank.THREE)


static func run() -> Array:
	var failures: Array[String] = []

	# 1. Agrupa por rango y separa comodines.
	var t1 := TestAssert.new("hand_analyzer_groups")
	var hand1: Array[Card] = [
		_natural(GameConfig.Rank.SEVEN, 1),
		_natural(GameConfig.Rank.SEVEN, 2),
		_natural(GameConfig.Rank.KING, 3),
		_joker(4),
		_two(5),
		_bt(6),
	]
	var a1 := HandAnalyzer.analyze(hand1)
	t1.eq(a1.size, 6, "size")
	t1.eq((a1.groups[GameConfig.Rank.SEVEN] as HandAnalyzer.RankGroup).count(), 2, "two sevens")
	t1.eq((a1.groups[GameConfig.Rank.KING] as HandAnalyzer.RankGroup).count(), 1, "one king")
	t1.eq(a1.wilds.size(), 2, "wilds=2")
	t1.eq(a1.jokers, 1, "jokers=1")
	t1.eq(a1.twos, 1, "twos=1")
	t1.eq(a1.black_threes.size(), 1, "bt=1")
	t1.is_false(a1.groups.has(GameConfig.Rank.THREE), "no THREE in groups")
	failures.append_array(t1.failures)

	# 2. ranks_by_size_desc ordena de mayor a menor cantidad.
	var t2 := TestAssert.new("ranks_by_size")
	var hand2: Array[Card] = [
		_natural(GameConfig.Rank.FIVE, 10),
		_natural(GameConfig.Rank.FIVE, 11),
		_natural(GameConfig.Rank.FIVE, 12),
		_natural(GameConfig.Rank.NINE, 13),
		_natural(GameConfig.Rank.NINE, 14),
		_natural(GameConfig.Rank.KING, 15),
	]
	var a2 := HandAnalyzer.analyze(hand2)
	var order := HandAnalyzer.ranks_by_size_desc(a2)
	t2.eq(order[0], GameConfig.Rank.FIVE, "first=FIVE")
	t2.eq(order[1], GameConfig.Rank.NINE, "second=NINE")
	t2.eq(order[2], GameConfig.Rank.KING, "third=KING")
	failures.append_array(t2.failures)

	return failures
