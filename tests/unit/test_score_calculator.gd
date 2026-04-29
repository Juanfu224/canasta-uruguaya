## Tests del ScoreCalculator: bonos, cierre, treses rojos invertidos, treses negros.
extends RefCounted

const TestAssert := preload("res://tools/test_assert.gd")

static func _natural(rank: int, id: int, suit: int = GameConfig.Suit.CLUBS) -> Card:
	return Card.make(id, suit, rank)

static func _joker(id: int) -> Card:
	return Card.make(id, GameConfig.Suit.JOKER, GameConfig.Rank.JOKER)

static func _red_three(id: int) -> Card:
	return Card.make(id, GameConfig.Suit.HEARTS, GameConfig.Rank.THREE)


## Crea un equipo con una canasta pura de reyes (700 pts en cartas + 500 bono).
static func _team_with_pure_canasta() -> TeamState:
	var t := TeamState.create(0)
	var m := Meld.create(0, GameConfig.Rank.KING)
	var seven: Array[Card] = []
	for i in range(7):
		seven.append(_natural(GameConfig.Rank.KING, i,
			GameConfig.Suit.CLUBS if i < 4 else GameConfig.Suit.HEARTS))
	m.add_cards(seven)
	t.melds.append(m)
	return t


## Equipo con canasta impura de reyes: 4 nat + 3 jokers.
static func _team_with_impure_canasta() -> TeamState:
	var t := TeamState.create(0)
	var m := Meld.create(0, GameConfig.Rank.KING)
	var imp: Array[Card] = []
	for i in range(4):
		imp.append(_natural(GameConfig.Rank.KING, i, GameConfig.Suit.CLUBS))
	imp.append(_joker(100))
	imp.append(_joker(101))
	imp.append(_joker(102))
	m.add_cards(imp)
	t.melds.append(m)
	return t


static func run() -> Array:
	var failures: Array[String] = []

	# Test 1: canasta pura sola.
	var t1 := TestAssert.new("score_pure_canasta_no_close")
	var team1 := _team_with_pure_canasta()
	# 7 reyes × 10 = 70 + 500 (bono pura) = 570.
	# No cerrador, sin treses, sin black threes, sin cartas en mano.
	var delta1 := ScoreCalculator.score_team(team1, false, false, [[]], 0)
	t1.eq(delta1, 570, "pura: 7×10 + 500")
	failures.append_array(t1.failures)

	# Test 2: canasta impura.
	var t2 := TestAssert.new("score_impure_canasta")
	var team2 := _team_with_impure_canasta()
	# 4×10 (reyes) + 3×50 (jokers) + 200 (bono impura) = 40+150+200 = 390.
	var delta2 := ScoreCalculator.score_team(team2, false, false, [[]], 0)
	t2.eq(delta2, 390, "impura: 40 + 150 + 200")
	failures.append_array(t2.failures)

	# Test 3: cerrador normal recibe +100.
	var t3 := TestAssert.new("score_closer_bonus")
	var team3 := _team_with_pure_canasta()
	var delta3 := ScoreCalculator.score_team(team3, true, false, [[]], 0)
	t3.eq(delta3, 670, "570 + 100 (cerrador)")
	failures.append_array(t3.failures)

	# Test 4: cierre en mano recibe +200.
	var t4 := TestAssert.new("score_closer_in_hand")
	var team4 := _team_with_pure_canasta()
	var delta4 := ScoreCalculator.score_team(team4, true, true, [[]], 0)
	t4.eq(delta4, 770, "570 + 200 (en mano)")
	failures.append_array(t4.failures)

	# Test 5: treses rojos suman cuando hay canasta.
	var t5 := TestAssert.new("score_red_threes_with_canasta")
	var team5 := _team_with_pure_canasta()
	team5.red_threes.append(_red_three(500))
	team5.red_threes.append(_red_three(501))
	var delta5 := ScoreCalculator.score_team(team5, false, false, [[]], 0)
	t5.eq(delta5, 570 + 200, "+2×100")
	failures.append_array(t5.failures)

	# Test 6: 4 treses rojos = 800 (bonus).
	var t6 := TestAssert.new("score_red_threes_full_set")
	var team6 := _team_with_pure_canasta()
	for i in range(4):
		team6.red_threes.append(_red_three(600 + i))
	var delta6 := ScoreCalculator.score_team(team6, false, false, [[]], 0)
	t6.eq(delta6, 570 + 800, "+800 (los 4)")
	failures.append_array(t6.failures)

	# Test 7: treses rojos invertidos cuando NO hay canasta.
	var t7 := TestAssert.new("score_red_threes_no_canasta_inverted")
	var team7 := TeamState.create(0)
	team7.red_threes.append(_red_three(700))
	team7.red_threes.append(_red_three(701))
	# Sin meld → sin canasta → invertido: -200.
	var delta7 := ScoreCalculator.score_team(team7, false, false, [[]], 0)
	t7.eq(delta7, -200, "-2×100 invertido")
	failures.append_array(t7.failures)

	# Test 8: penalización 4 treses negros (al cerrador).
	var t8 := TestAssert.new("score_4_black_threes_penalty")
	var team8 := _team_with_pure_canasta()
	var delta8 := ScoreCalculator.score_team(team8, true, false, [[]], 4)
	# 570 + 100 (cierre) - 500 (4 negros) = 170.
	t8.eq(delta8, 170, "570 + 100 - 500")
	failures.append_array(t8.failures)

	# Test 9: cartas en mano descontadas.
	var t9 := TestAssert.new("score_cards_in_hand_subtracted")
	var team9 := _team_with_pure_canasta()
	var hand_with_king := [_natural(GameConfig.Rank.KING, 900)] as Array[Card]  # 10 pts
	var delta9 := ScoreCalculator.score_team(team9, false, false, [hand_with_king], 0)
	t9.eq(delta9, 570 - 10, "-10 por carta en mano")
	failures.append_array(t9.failures)

	# Test 10: penalización por robo fuera de orden.
	var t10 := TestAssert.new("score_draw_out_of_order")
	var team10 := TeamState.create(0)
	team10.hand_score = 100
	ScoreCalculator.apply_draw_out_of_order_penalty(team10)
	t10.eq(team10.hand_score, 0, "100 - 100")
	failures.append_array(t10.failures)

	return failures
