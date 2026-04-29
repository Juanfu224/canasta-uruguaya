## Tests unitarios para `autoloads/game_config.gd` (helpers estáticos puros).
extends GdUnitTestSuite


func test_opening_threshold_negative() -> void:
	assert_int(GameConfig.opening_threshold_for(-1)).is_equal(GameConfig.OPENING_THRESHOLD_NEGATIVE)
	assert_int(GameConfig.opening_threshold_for(-5000)).is_equal(GameConfig.OPENING_THRESHOLD_NEGATIVE)


func test_opening_threshold_initial() -> void:
	assert_int(GameConfig.opening_threshold_for(0)).is_equal(50)
	assert_int(GameConfig.opening_threshold_for(1499)).is_equal(50)


func test_opening_threshold_mid() -> void:
	assert_int(GameConfig.opening_threshold_for(1500)).is_equal(90)
	assert_int(GameConfig.opening_threshold_for(2999)).is_equal(90)


func test_opening_threshold_high() -> void:
	assert_int(GameConfig.opening_threshold_for(3000)).is_equal(120)
	assert_int(GameConfig.opening_threshold_for(7000)).is_equal(120)


func test_points_for_rank_face() -> void:
	assert_int(GameConfig.points_for_rank(GameConfig.Rank.KING)).is_equal(10)
	assert_int(GameConfig.points_for_rank(GameConfig.Rank.EIGHT)).is_equal(10)


func test_points_for_rank_low() -> void:
	assert_int(GameConfig.points_for_rank(GameConfig.Rank.FOUR)).is_equal(5)
	assert_int(GameConfig.points_for_rank(GameConfig.Rank.THREE)).is_equal(5)


func test_points_for_rank_special() -> void:
	assert_int(GameConfig.points_for_rank(GameConfig.Rank.ACE)).is_equal(15)
	assert_int(GameConfig.points_for_rank(GameConfig.Rank.TWO)).is_equal(20)
	assert_int(GameConfig.points_for_rank(GameConfig.Rank.JOKER)).is_equal(50)


func test_is_wildcard_rank() -> void:
	assert_bool(GameConfig.is_wildcard_rank(GameConfig.Rank.JOKER)).is_true()
	assert_bool(GameConfig.is_wildcard_rank(GameConfig.Rank.TWO)).is_true()
	assert_bool(GameConfig.is_wildcard_rank(GameConfig.Rank.ACE)).is_false()
	assert_bool(GameConfig.is_wildcard_rank(GameConfig.Rank.KING)).is_false()


func test_hand_size_for_each_player_count() -> void:
	assert_int(GameConfig.hand_size_for(2)).is_equal(15)
	assert_int(GameConfig.hand_size_for(3)).is_equal(13)
	assert_int(GameConfig.hand_size_for(4)).is_equal(11)
	assert_int(GameConfig.hand_size_for(6)).is_equal(11)
