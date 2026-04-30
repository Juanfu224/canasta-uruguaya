## Escena offline de partida (F4.5 visual rebuild).
##
## Estructura del árbol:
##   - FeltLayer  (z=0): fondo procedural con vignette + frame dorado.
##   - PlayArea   (z=normal): manos, mazo, pozo, mesa de canastas.
##   - HudLayer   (z=1): TopHud (equipos / fase) + BottomHud (hint / menú).
##   - OverlayLayer (z=2): popups (puntajes, fin de mano, transiciones).
##
## La lógica autoritativa real llega en F5 (RpcRouter); aquí cada acción
## muta el estado local directamente para QA visual:
##   - Tap en el mazo  → robo doble.
##   - Drop en el pozo → descartar carta (taponado/cruzado por estado).
##   - Drop en mesa    → crear/extender meld; canasta a las 7 cartas.
extends Control

const _INITIAL_HAND_SIZE: int = 11
const _SCORE_POPUP_SCENE: PackedScene = preload("res://ui/score_popup.tscn")
const _LOADING_FLUID_SCENE: PackedScene = preload("res://ui/transitions/loading_fluid.tscn")
const _MATCH_LAYOUT_SCRIPT: GDScript = preload("res://scenes/match_layout.gd")
const _CANASTA_FLASH_SCRIPT: GDScript = preload("res://fx/canasta_flash.gd")
const _CARD_FLIGHT_SCRIPT: GDScript = preload("res://fx/card_flight.gd")
const _CARD_UI_SCENE: PackedScene = preload("res://ui/card_ui.tscn")

@onready var _play_area: Control = $PlayArea
@onready var _local_hand: HandLayout = $PlayArea/LocalHand
@onready var _remote_hand_top: HandLayout = $PlayArea/RemoteHandTop
@onready var _remote_hand_left: HandLayout = $PlayArea/RemoteHandLeft
@onready var _remote_hand_right: HandLayout = $PlayArea/RemoteHandRight
@onready var _pozo: PozoView = $PlayArea/Center/PozoView
@onready var _deck: DeckView = $PlayArea/Center/DeckView
@onready var _center: Control = $PlayArea/Center
@onready var _melds: MeldsTable = $PlayArea/MeldsTable
@onready var _top_hud: TopHud = $HudLayer/TopHud
@onready var _bottom_hud: BottomHud = $HudLayer/BottomHud
@onready var _overlay: CanvasLayer = $OverlayLayer

var _deck_logic: Deck = null
var _pozo_count: int = 0
var _visible_melds: Array[Meld] = []
var _layout: MatchLayout = null


func _ready() -> void:
	# Esta escena es solo QA visual (no autoritativa). Sólo permitirla bajo
	# el flag CLI `--match-offline-qa` para evitar que el flujo de menú la
	# alcance accidentalmente.
	var args: PackedStringArray = OS.get_cmdline_args()
	if not args.has("--match-offline-qa"):
		push_warning("MatchOffline solo disponible con --match-offline-qa; redirigiendo a Menu")
		get_tree().change_scene_to_file.call_deferred("res://scenes/Menu.tscn")
		return
	if RngService.current_match_seed == 0:
		RngService.start_match(0)
	_deck_logic = Deck.build_standard_108()
	_deck_logic.shuffle(RngService.match_rng)

	# Wire signals.
	_pozo.discard_requested.connect(_on_discard_requested)
	_deck.draw_requested.connect(_on_draw_requested)
	_melds.create_meld_requested.connect(_on_create_meld_requested)
	_melds.extend_meld_requested.connect(_on_extend_meld_requested)
	_top_hud.menu_pressed.connect(_on_back_to_menu)
	_bottom_hud.back_pressed.connect(_on_back_to_menu)

	# Layout responsive (portrait/landscape).
	_layout = _MATCH_LAYOUT_SCRIPT.new() as MatchLayout
	_layout.bind_nodes(
		self,
		_local_hand,
		_remote_hand_top,
		_remote_hand_left,
		_remote_hand_right,
		_center,
		_melds,
	)
	add_child(_layout)

	# Inicializa HUD.
	_top_hud.set_round(1, 4)
	_top_hud.set_phase("Robar", "draw")

	_deal_initial_hands()
	_deck.set_glow(true)
	_refresh_hud()


# ---------------------------------------------------------------------------
# Acciones del jugador (acopladas al estado local; F5 reemplaza por RPC).
# ---------------------------------------------------------------------------

func _on_back_to_menu() -> void:
	var transition: LoadingFluid = _LOADING_FLUID_SCENE.instantiate() as LoadingFluid
	_overlay.add_child(transition)
	await transition.play_in(0.4)
	get_tree().change_scene_to_file("res://scenes/Menu.tscn")


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
	var origin: Vector2 = _deck.get_draw_origin_global()
	var destination: Vector2 = _local_hand.get_global_rect().get_center()
	for c in drawn:
		_fly_ghost_card(c, origin, destination, 120.0, 0.32, false)
		_local_hand.add_card(c, true)
	_deck.set_count(_deck_logic.size())
	_deck.set_glow(false)
	_top_hud.set_phase("Jugar", "play")
	_bottom_hud.set_hint("Arrastra cartas a la mesa para canastrar o al pozo para descartar.")
	_refresh_hud()


func _on_discard_requested(card_id: int, _source: NodePath) -> void:
	var card: Card = _find_card_in_local_hand(card_id)
	if card == null:
		return
	var origin: Vector2 = _local_hand.get_global_rect().get_center()
	var destination: Vector2 = _pozo.get_global_rect().get_center()
	_local_hand.remove_card_by_id(card_id, true)
	_fly_ghost_card(card, origin, destination, 90.0, 0.30, true)
	_pozo_count += 1
	_pozo.set_top_card(card)
	_pozo.set_count(_pozo_count)
	if card.is_black_three:
		_pozo.set_status(PozoView.PozoStatus.TAPONADO)
	elif card.is_wildcard:
		_pozo.set_status(PozoView.PozoStatus.CRUZADO)
	else:
		_pozo.set_status(PozoView.PozoStatus.NORMAL)
	_top_hud.set_phase("Robar", "draw")
	_bottom_hud.set_hint("Toca el mazo para robar dos cartas.")
	_deck.set_glow(true)
	_refresh_hud()


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
	_refresh_hud()


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
	_refresh_hud()
	# Feedback al completar canasta (≥7 cartas).
	if meld.cards.size() == 7:
		ScreenShake.shake(_melds, 10.0, 0.25)
		_CANASTA_FLASH_SCRIPT.spawn(self, Tokens.TRIM_GOLD)
		_top_hud.bump_team_score(1, 1500)


func _find_card_in_local_hand(card_id: int) -> Card:
	for child in _local_hand.get_children():
		var cu := child as CardUI
		if cu != null and cu.card != null and cu.card.id == card_id:
			return cu.card
	return null


func _refresh_hud() -> void:
	_bottom_hud.set_counts(_deck_logic.size(), _pozo_count, _local_hand.get_card_count())


# ---------------------------------------------------------------------------
# FX: vuelo de carta-fantasma sobre OverlayLayer.
# ---------------------------------------------------------------------------

func _fly_ghost_card(
	card: Card,
	from_global: Vector2,
	to_global: Vector2,
	arc_height: float = 100.0,
	duration: float = 0.32,
	face_up: bool = true,
) -> void:
	if card == null or _overlay == null:
		return
	var ghost: CardUI = _CARD_UI_SCENE.instantiate() as CardUI
	if ghost == null:
		return
	ghost.enable_hover_fx = false
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(ghost)
	ghost.bind(card, face_up)
	ghost.global_position = from_global - ghost.size * 0.5
	var target: Vector2 = to_global - ghost.size * 0.5
	var tween: Tween = _CARD_FLIGHT_SCRIPT.fly(ghost, ghost.global_position, target, duration, arc_height, false)
	if tween == null:
		ghost.queue_free()
		return
	tween.finished.connect(func() -> void:
		if is_instance_valid(ghost):
			ghost.queue_free()
	)
