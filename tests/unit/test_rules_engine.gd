## Tests de RulesEngine: validación captura, meld, cierre, draw.
extends RefCounted

const TestAssert := preload("res://tools/test_assert.gd")

static func _natural(rank: int, id: int, suit: int = GameConfig.Suit.CLUBS) -> Card:
	return Card.make(id, suit, rank)

static func _joker(id: int) -> Card:
	return Card.make(id, GameConfig.Suit.JOKER, GameConfig.Rank.JOKER)

static func _two(id: int, suit: int = GameConfig.Suit.HEARTS) -> Card:
	return Card.make(id, suit, GameConfig.Rank.TWO)

static func _black_three(id: int) -> Card:
	return Card.make(id, GameConfig.Suit.SPADES, GameConfig.Rank.THREE)


## Construye un MatchState mínimo (4 jugadores, sin mazo barajado real).
static func _bare_state() -> MatchState:
	var cfg := MatchConfig.standard_2v2(123)
	var s := MatchState.create(cfg)
	s.deck = Deck.new()  # vacío para tests, no se va a usar
	s.pozo = PozoController.new()
	s.current_player = 0
	return s


static func run() -> Array:
	var failures: Array[String] = []

	# ----------------------------------------------------------------------
	# 1. can_capture_pozo: pozo vacío → pozo_empty.
	# ----------------------------------------------------------------------
	var t1 := TestAssert.new("capture_empty_pozo")
	var s1 := _bare_state()
	var r1 := RulesEngine.can_capture_pozo(s1, 0, PackedInt32Array())
	t1.is_false(r1.ok, "no ok")
	t1.eq(r1.reason, "pozo_empty", "pozo_empty")
	failures.append_array(t1.failures)

	# ----------------------------------------------------------------------
	# 2. can_capture_pozo: pozo taponado → pozo_taponado.
	# ----------------------------------------------------------------------
	var t2 := TestAssert.new("capture_taponado")
	var s2 := _bare_state()
	s2.pozo.push(_natural(GameConfig.Rank.SEVEN, 1, GameConfig.Suit.HEARTS))
	s2.pozo.push(_black_three(2))
	var r2 := RulesEngine.can_capture_pozo(s2, 0, PackedInt32Array())
	t2.eq(r2.reason, "pozo_taponado", "pozo_taponado")
	failures.append_array(t2.failures)

	# ----------------------------------------------------------------------
	# 3. can_capture_pozo: top normal, faltan naturales (solo 1) → no_pairs.
	# ----------------------------------------------------------------------
	var t3 := TestAssert.new("capture_no_pairs")
	var s3 := _bare_state()
	# Top: rey. Mano del jugador: 1 rey + 1 joker (sólo 1 natural sumando con top → 2 naturales).
	# Espera: con 1 nat de la mano + 1 top = 2 naturales → SHOULD pass naturales.
	# Hagamos: mano sólo joker + algo no king → no hay 2 naturales → no_pairs.
	s3.pozo.push(_natural(GameConfig.Rank.KING, 10, GameConfig.Suit.HEARTS))
	var hand3: Array = s3.hands[0]
	hand3.append(_joker(11))
	hand3.append(_joker(12))
	# Apertura ya hecha para enfocarnos en la regla de naturales.
	s3.team_of(0).opened = true
	var r3 := RulesEngine.can_capture_pozo(s3, 0,
		PackedInt32Array([11, 12]))
	# top=KING(natural,1) + 2 jokers (0 nat) = 1 natural total. Falla por naturales o por composición.
	# Composition KING con 1 nat + 2 wilds → MIN_NATURALS_FOR_IMPURE no se exige aquí pero
	# is_valid_composition exige nat>=2 → invalid_meld primero.
	t3.is_false(r3.ok, "no ok")
	t3.is_true(r3.reason == "no_pairs" or r3.reason == "invalid_meld",
		"falla por naturales/composición")
	failures.append_array(t3.failures)

	# ----------------------------------------------------------------------
	# 4. can_capture_pozo: válido (top king + king + king).
	# ----------------------------------------------------------------------
	var t4 := TestAssert.new("capture_valid")
	var s4 := _bare_state()
	s4.pozo.push(_natural(GameConfig.Rank.KING, 20, GameConfig.Suit.HEARTS))
	var hand4: Array = s4.hands[0]
	hand4.append(_natural(GameConfig.Rank.KING, 21, GameConfig.Suit.SPADES))
	hand4.append(_natural(GameConfig.Rank.KING, 22, GameConfig.Suit.CLUBS))
	s4.team_of(0).opened = true
	var r4 := RulesEngine.can_capture_pozo(s4, 0, PackedInt32Array([21, 22]))
	t4.is_true(r4.ok, "ok: %s" % r4.reason)
	failures.append_array(t4.failures)

	# ----------------------------------------------------------------------
	# 5. execute_capture_pozo: ejecuta y crea meld de KING.
	# ----------------------------------------------------------------------
	var t5 := TestAssert.new("execute_capture_creates_meld")
	var r5 := RulesEngine.execute_capture_pozo(s4, 0, PackedInt32Array([21, 22]))
	t5.is_true(r5.ok, "ejecutó: %s" % r5.reason)
	var team4 := s4.team_of(0)
	var meld_king := team4.find_meld_by_rank(GameConfig.Rank.KING)
	t5.not_null(meld_king, "meld king existe")
	t5.eq(meld_king.size(), 3, "3 reyes en meld")
	t5.is_true(team4.opened, "equipo abierto")
	t5.is_true(s4.pozo.is_empty(), "pozo vacío")
	failures.append_array(t5.failures)

	# ----------------------------------------------------------------------
	# 6. can_meld: válido + abre umbral.
	# ----------------------------------------------------------------------
	var t6 := TestAssert.new("meld_valid_meets_threshold")
	var s6 := _bare_state()
	# Bajamos 3 ases (15×3 = 45) → debajo de 50 → below_threshold.
	var hand6: Array = s6.hands[0]
	hand6.append(_natural(GameConfig.Rank.ACE, 30, GameConfig.Suit.HEARTS))
	hand6.append(_natural(GameConfig.Rank.ACE, 31, GameConfig.Suit.CLUBS))
	hand6.append(_natural(GameConfig.Rank.ACE, 32, GameConfig.Suit.SPADES))
	var r6 := RulesEngine.can_meld(s6, 0, PackedInt32Array([30, 31, 32]),
		GameConfig.Rank.ACE)
	t6.eq(r6.reason, "below_threshold", "45 < 50")
	failures.append_array(t6.failures)

	# Ahora añadimos un 4to as para 60 puntos.
	hand6.append(_natural(GameConfig.Rank.ACE, 33, GameConfig.Suit.HEARTS))
	var r6b := RulesEngine.can_meld(s6, 0,
		PackedInt32Array([30, 31, 32, 33]), GameConfig.Rank.ACE)
	t6.is_true(r6b.ok, "60 ≥ 50: %s" % r6b.reason)
	failures.append_array(t6.failures)

	# ----------------------------------------------------------------------
	# 7. can_close: rechazado si solo canasta impura.
	# ----------------------------------------------------------------------
	var t7 := TestAssert.new("close_only_impure_rejected")
	var s7 := _bare_state()
	var team7 := s7.team_of(0)
	var imp_meld := Meld.create(0, GameConfig.Rank.KING)
	var imp_cards: Array[Card] = []
	for i in range(4):
		imp_cards.append(_natural(GameConfig.Rank.KING, 40 + i, GameConfig.Suit.CLUBS))
	imp_cards.append(_joker(50))
	imp_cards.append(_joker(51))
	imp_cards.append(_joker(52))
	imp_meld.add_cards(imp_cards)
	team7.melds.append(imp_meld)
	var r7 := RulesEngine.can_close(s7, 0)
	t7.eq(r7.reason, "cannot_close", "falta pura")
	failures.append_array(t7.failures)

	# Añadimos pura → debe permitir cierre.
	var pure_meld := Meld.create(0, GameConfig.Rank.QUEEN)
	var pure_cards: Array[Card] = []
	for i in range(7):
		pure_cards.append(_natural(GameConfig.Rank.QUEEN, 60 + i,
			GameConfig.Suit.CLUBS if i < 4 else GameConfig.Suit.HEARTS))
	pure_meld.add_cards(pure_cards)
	team7.melds.append(pure_meld)
	var r7b := RulesEngine.can_close(s7, 0)
	t7.is_true(r7b.ok, "pura+impura → ok: %s" % r7b.reason)
	failures.append_array(t7.failures)

	# ----------------------------------------------------------------------
	# 8. not_your_turn.
	# ----------------------------------------------------------------------
	var t8 := TestAssert.new("not_your_turn")
	var s8 := _bare_state()
	s8.current_player = 0
	var r8 := RulesEngine.can_meld(s8, 1, PackedInt32Array(), GameConfig.Rank.KING)
	t8.eq(r8.reason, "not_your_turn", "not_your_turn")
	failures.append_array(t8.failures)

	# ----------------------------------------------------------------------
	# 9. cards_not_in_hand.
	# ----------------------------------------------------------------------
	var t9 := TestAssert.new("cards_not_in_hand")
	var s9 := _bare_state()
	var r9 := RulesEngine.can_discard(s9, 0, 9999)
	t9.eq(r9.reason, "cards_not_in_hand", "id inexistente")
	failures.append_array(t9.failures)

	# ----------------------------------------------------------------------
	# 10. execute_discard pone la carta en pozo.
	# ----------------------------------------------------------------------
	var t10 := TestAssert.new("execute_discard")
	var s10 := _bare_state()
	var hand10: Array = s10.hands[0]
	var card10 := _natural(GameConfig.Rank.SEVEN, 70, GameConfig.Suit.HEARTS)
	hand10.append(card10)
	var r10 := RulesEngine.execute_discard(s10, 0, 70)
	t10.is_true(r10.ok, "ok")
	t10.eq(s10.pozo.size(), 1, "pozo +1")
	t10.eq(hand10.size(), 0, "mano vacía")
	failures.append_array(t10.failures)

	# ----------------------------------------------------------------------
	# 11. deal_initial reparte las 11 cartas y configura pozo.
	# ----------------------------------------------------------------------
	var t11 := TestAssert.new("deal_initial")
	var cfg11 := MatchConfig.standard_2v2(42)
	var s11 := MatchState.create(cfg11)
	s11.deck = Deck.build_standard_108()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	s11.deck.shuffle(rng)
	RulesEngine.deal_initial(s11)
	for p in range(4):
		var hsize: int = (s11.hands[p] as Array).size()
		# Cada jugador con 11 cartas (no contamos treses extraídos).
		t11.is_true(hsize >= GameConfig.HAND_SIZE_4P - 4 and hsize <= GameConfig.HAND_SIZE_4P,
			"player %d hand %d ≈ 11" % [p, hsize])
	t11.is_false(s11.pozo.is_empty(), "pozo no vacío")
	t11.is_false(s11.pozo.top().is_red_three, "top no es tres rojo")
	failures.append_array(t11.failures)

	# ----------------------------------------------------------------------
	# 12. draw_from_deck roba 2 cartas.
	# ----------------------------------------------------------------------
	var t12 := TestAssert.new("draw_from_deck_two_cards")
	var size_before: int = (s11.hands[0] as Array).size()
	var r12 := RulesEngine.draw_from_deck(s11, 0)
	t12.is_true(r12.ok, "ok")
	# Esperamos +2 (o +1 si robó un tres rojo y no hay reemplazo, pero con seed=42 es unlikely).
	var size_after: int = (s11.hands[0] as Array).size()
	t12.is_true(size_after - size_before >= 1 and size_after - size_before <= 2,
		"+1 o +2 cartas (reds extraídos): got +%d" % (size_after - size_before))
	failures.append_array(t12.failures)

	return failures
