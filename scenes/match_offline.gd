## Escena offline de partida para QA visual de F3.
##
## Esta NO es la versión final del Match. Aquí el host autoritativo aún
## no existe (eso llega en F5). Se usa para verificar a ojo:
##   - Fanning de 11 a 20 cartas sin solapamiento ilegible.
##   - Drag&drop táctil hacia pozo y melds.
##   - Layout responsive en viewport portrait 720x1280.
##
## Acciones:
##   - Tap en el mazo central → robo doble (mueve 2 cartas a la mano local).
##   - Drop sobre el pozo → descarta una carta.
##   - Drop sobre la mesa de melds → crea o extiende un meld (estético).
##
## NOTA: cualquier acción aquí se ejecuta directamente sobre el estado local.
## En F5 todas estas acciones se sustituyen por `request_*` RPCs validados
## por el host.
extends Control

const _INITIAL_HAND_SIZE: int = 11
const _SCORE_POPUP_SCENE: PackedScene = preload("res://ui/score_popup.tscn")
const _LOADING_FLUID_SCENE: PackedScene = preload("res://ui/transitions/loading_fluid.tscn")

@onready var _local_hand: HandLayout = $LocalHand
@onready var _remote_hand_top: HandLayout = $RemoteHandTop
@onready var _remote_hand_left: HandLayout = $RemoteHandLeft
@onready var _remote_hand_right: HandLayout = $RemoteHandRight
@onready var _pozo: PozoView = $Center/PozoView
@onready var _deck: DeckView = $Center/DeckView
@onready var _melds: MeldsTable = $Top/MeldsTable
@onready var _info: Label = $InfoLabel

var _deck_logic: Deck = null
var _pozo_count: int = 0
var _visible_melds: Array[Meld] = []


func _ready() -> void:
	if RngService.current_match_seed == 0:
		RngService.start_match(0)
	_deck_logic = Deck.build_standard_108()
	_deck_logic.shuffle(RngService.match_rng)

	_pozo.discard_requested.connect(_on_discard_requested)
	_deck.draw_requested.connect(_on_draw_requested)
	_melds.create_meld_requested.connect(_on_create_meld_requested)
	_melds.extend_meld_requested.connect(_on_extend_meld_requested)

	_deal_initial_hands()
	_update_info()
	_build_qa_toolbar()


# ---------------------------------------------------------------------------
# QA Toolbar (F4): sólo en escena offline. En F5 se reemplaza por HUD real.
# ---------------------------------------------------------------------------

func _build_qa_toolbar() -> void:
	var bar: HBoxContainer = HBoxContainer.new()
	bar.name = "QAToolbar"
	bar.position = Vector2(16, 16)
	bar.add_theme_constant_override("separation", 8)
	add_child(bar)

	var btn_menu: Button = Button.new()
	btn_menu.text = "← Menú"
	btn_menu.custom_minimum_size = Vector2(110, 40)
	btn_menu.pressed.connect(_on_back_to_menu)
	bar.add_child(btn_menu)

	var btn_score: Button = Button.new()
	btn_score.text = "Test puntaje"
	btn_score.custom_minimum_size = Vector2(140, 40)
	btn_score.pressed.connect(_on_test_score_popup)
	bar.add_child(btn_score)


func _on_back_to_menu() -> void:
	var transition: LoadingFluid = _LOADING_FLUID_SCENE.instantiate() as LoadingFluid
	add_child(transition)
	await transition.play_in(0.4)
	get_tree().change_scene_to_file("res://scenes/Menu.tscn")


func _on_test_score_popup() -> void:
	var popup: ScorePopup = _SCORE_POPUP_SCENE.instantiate() as ScorePopup
	add_child(popup)
	var payload: Dictionary = {
		"title": "Resultado de la mano (demo)",
		"teams": [
			{
				"team_id": 1,
				"label": "Equipo Rojo",
				"rows": [
					{"label": "Canasta pura", "value": GameConfig.CANASTA_PURE_BONUS},
					{"label": "Canasta impura", "value": GameConfig.CANASTA_IMPURE_BONUS},
					{"label": "Canasta de ases pura", "value": GameConfig.CANASTA_ACES_PURE_BONUS},
					{"label": "Treses rojos (3)", "value": GameConfig.RED_THREE_BONUS * 3},
					{"label": "Cartas en mesa", "value": 285},
					{"label": "Cartas en mano", "value": -120},
				],
				"hand_total": 1965,
				"cumulative_before": 1500,
				"cumulative_after": 3465,
			},
			{
				"team_id": 2,
				"label": "Equipo Azul",
				"rows": [
					{"label": "Canasta impura", "value": GameConfig.CANASTA_IMPURE_BONUS},
					{"label": "Cartas en mesa", "value": 140},
					{"label": "Robo fuera de orden", "value": GameConfig.DRAW_OUT_OF_ORDER_PENALTY},
					{"label": "Cartas en mano", "value": -260},
				],
				"hand_total": -20,
				"cumulative_before": 1820,
				"cumulative_after": 1800,
			},
		],
	}
	popup.play(payload)


func _deal_initial_hands() -> void:
	for c in _deck_logic.draw_n(_INITIAL_HAND_SIZE):
		_local_hand.add_card(c, false)
	for hand in [_remote_hand_top, _remote_hand_left, _remote_hand_right]:
		hand.face_up = false
		for c in _deck_logic.draw_n(_INITIAL_HAND_SIZE):
			hand.add_card(c, false)
	_deck.set_count(_deck_logic.size())


func _on_draw_requested() -> void:
	var drawn: Array[Card] = _deck_logic.draw_n(GameConfig.DRAW_COUNT_PER_TURN)
	for c in drawn:
		_local_hand.add_card(c, true)
	_deck.set_count(_deck_logic.size())
	_update_info()


func _on_discard_requested(card_id: int, _source: NodePath) -> void:
	var card: Card = _find_card_in_local_hand(card_id)
	if card == null:
		return
	_local_hand.remove_card_by_id(card_id, true)
	_pozo_count += 1
	_pozo.set_top_card(card)
	_pozo.set_count(_pozo_count)
	if card.is_black_three:
		_pozo.set_status(PozoView.PozoStatus.TAPONADO)
	elif card.is_wildcard:
		_pozo.set_status(PozoView.PozoStatus.CRUZADO)
	else:
		_pozo.set_status(PozoView.PozoStatus.NORMAL)
	_update_info()


func _on_create_meld_requested(card_id: int, _source: NodePath) -> void:
	var card: Card = _find_card_in_local_hand(card_id)
	if card == null:
		return
	_local_hand.remove_card_by_id(card_id, true)
	var rank_value: int = card.rank
	if card.is_wildcard:
		rank_value = GameConfig.Rank.JOKER
	var m: Meld = Meld.create(0, rank_value)
	m.cards.append(card)
	if card.is_wildcard:
		m.wilds = 1
	else:
		m.naturals = 1
	_visible_melds.append(m)
	_melds.render_melds(_visible_melds)


func _on_extend_meld_requested(meld_index: int, card_id: int, _source: NodePath) -> void:
	if meld_index < 0 or meld_index >= _visible_melds.size():
		return
	var card: Card = _find_card_in_local_hand(card_id)
	if card == null:
		return
	_local_hand.remove_card_by_id(card_id, true)
	var meld: Meld = _visible_melds[meld_index]
	meld.cards.append(card)
	if card.is_wildcard:
		meld.wilds += 1
	else:
		meld.naturals += 1
	_melds.render_melds(_visible_melds)
	# F4: feedback al completar canasta (≥7 cartas).
	if meld.cards.size() == 7:
		ScreenShake.shake(_melds, 10.0, 0.25)


func _find_card_in_local_hand(card_id: int) -> Card:
	for child in _local_hand.get_children():
		var cu := child as CardUI
		if cu != null and cu.card != null and cu.card.id == card_id:
			return cu.card
	return null


func _update_info() -> void:
	_info.text = "Mazo: %d   |   Mano local: %d   |   Pozo: %d" % [
		_deck_logic.size(),
		_local_hand.get_card_count(),
		_pozo_count,
	]
