## Tests unitarios de MeldPlanner.
extends RefCounted

const TestAssert := preload("res://tools/test_assert.gd")


static func _natural(rank: int, id: int, suit: int = GameConfig.Suit.CLUBS) -> Card:
	return Card.make(id, suit, rank)


static func _state() -> MatchState:
	var s := MatchState.create(MatchConfig.standard_2v2(0))
	s.deck = Deck.new()
	s.pozo = PozoController.new()
	s.current_player = 0
	# Equipo 0 ya abierto (para evitar requisito de umbral en tests básicos).
	s.teams[0].opened = true
	return s


static func run() -> Array:
	var failures: Array[String] = []

	# 1. Sin grupo ≥3 → null.
	var t1 := TestAssert.new("plan_no_meld")
	var s1 := _state()
	s1.hands[0] = [
		_natural(GameConfig.Rank.SEVEN, 1),
		_natural(GameConfig.Rank.SEVEN, 2),
		_natural(GameConfig.Rank.KING, 3),
	]
	t1.eq(MeldPlanner.plan(s1, 0), null, "plan null sin trío")
	failures.append_array(t1.failures)

	# 2. Tres naturales → propone meld.
	var t2 := TestAssert.new("plan_pure_trio")
	var s2 := _state()
	s2.hands[0] = [
		_natural(GameConfig.Rank.KING, 10),
		_natural(GameConfig.Rank.KING, 11, GameConfig.Suit.HEARTS),
		_natural(GameConfig.Rank.KING, 12, GameConfig.Suit.DIAMONDS),
		_natural(GameConfig.Rank.SEVEN, 13),
	]
	var d2 := MeldPlanner.plan(s2, 0)
	t2.not_null(d2, "decisión")
	if d2 != null:
		t2.eq(d2.kind, "meld", "kind=meld")
		t2.eq(d2.declared_rank, GameConfig.Rank.KING, "rank=KING")
		t2.eq(d2.card_ids.size(), 3, "3 cartas")
	failures.append_array(t2.failures)

	return failures
