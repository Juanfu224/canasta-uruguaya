## Tests unitarios para `resources/card.gd`.
## Compatible con GdUnit4 (instalar vía AssetLib).
extends GdUnitTestSuite


func test_card_make_natural_face() -> void:
	var c: Card = Card.make(42, GameConfig.Suit.HEARTS, GameConfig.Rank.KING)
	assert_int(c.id).is_equal(42)
	assert_int(c.suit).is_equal(GameConfig.Suit.HEARTS)
	assert_int(c.rank).is_equal(GameConfig.Rank.KING)
	assert_int(c.point_value).is_equal(GameConfig.POINTS_FACE)
	assert_bool(c.is_wildcard).is_false()
	assert_bool(c.is_red_three).is_false()
	assert_bool(c.is_black_three).is_false()


func test_card_two_is_wildcard() -> void:
	var c: Card = Card.make(0, GameConfig.Suit.CLUBS, GameConfig.Rank.TWO)
	assert_bool(c.is_wildcard).is_true()
	assert_int(c.point_value).is_equal(GameConfig.POINTS_TWO)


func test_card_joker_is_wildcard_50pts() -> void:
	var c: Card = Card.make(107, GameConfig.Suit.JOKER, GameConfig.Rank.JOKER)
	assert_bool(c.is_wildcard).is_true()
	assert_int(c.point_value).is_equal(GameConfig.POINTS_JOKER)


func test_card_red_three_flag() -> void:
	var c1: Card = Card.make(1, GameConfig.Suit.HEARTS, GameConfig.Rank.THREE)
	var c2: Card = Card.make(2, GameConfig.Suit.DIAMONDS, GameConfig.Rank.THREE)
	assert_bool(c1.is_red_three).is_true()
	assert_bool(c2.is_red_three).is_true()
	assert_bool(c1.is_black_three).is_false()


func test_card_black_three_flag() -> void:
	var c1: Card = Card.make(1, GameConfig.Suit.CLUBS, GameConfig.Rank.THREE)
	var c2: Card = Card.make(2, GameConfig.Suit.SPADES, GameConfig.Rank.THREE)
	assert_bool(c1.is_black_three).is_true()
	assert_bool(c2.is_black_three).is_true()
	assert_bool(c1.is_red_three).is_false()
