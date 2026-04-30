## Vista de una carta de Canasta (`Control`).
##
## Responsabilidades:
##   - Renderizar una carta (cara o dorso) usando un placeholder procedural.
##     El swap a `AtlasTexture` se hace en F7 sin tocar este script (ver
##     `_render_face`).
##   - Exponer una FSM de input ligera: IDLE → HOVERED → DRAGGING → RELEASED.
##   - Iniciar drag&drop nativo de Godot vía `_get_drag_data`. Solo emite
##     un payload con el `card_id` (entero); NUNCA expone el `Resource` para
##     evitar que un drop receiver pueda mutar estado del host.
##   - Recibir un transform objetivo (`set_target_transform`) y animarlo
##     por `Tween`. La matemática del fanning vive en `HandLayout`.
##
## Seguridad / autoría:
##   - Esta vista jamás muta `card`. Es estrictamente presentacional.
##   - El payload de drag es opaco: `{type: "card", card_id: int,
##     source_path: NodePath}`. El receptor (DropZone) debe re-validar.
##
## Performance móvil:
##   - `_process` se mantiene apagado salvo durante un hover/drag activo
##     (Balatro pattern). Esto baja el coste de mantener 20+ cartas vivas.
##   - Sin shaders en F3; los FX (`fake_3D`, `dissolve`) se cablean en F4.
class_name CardUI
extends Control

# ---------------------------------------------------------------------------
# Señales
# ---------------------------------------------------------------------------

## Emitida cuando el usuario inicia un drag sobre la carta.
signal drag_started(card_id: int)

## Emitida cuando el drag termina (drop válido O cancelación). Útil para que
## `HandLayout` haga relayout en uno u otro caso.
signal drag_ended(card_id: int)

## Emitida cuando la carta es tappeada (sin drag). Útil para "ver carta
## ampliada" o para selección secundaria.
signal tapped(card_id: int)

# ---------------------------------------------------------------------------
# Constantes y enums
# ---------------------------------------------------------------------------

## Tamaño base de la carta (en pixeles de viewport portrait 720x1280).
## Se mantiene aquí como `const` para que `HandLayout` pueda calcular
## espaciado sin instanciar primero un nodo.
const CARD_SIZE: Vector2 = Vector2(120, 168)

const DRAG_PAYLOAD_TYPE: String = "card"

## Estados internos de la carta. NO confundir con la FSM de partida (`fsm/`).
enum InputState { IDLE, HOVERED, DRAGGING, RELEASED }

const _SUIT_GLYPH := ["♣", "♦", "♥", "♠", "★"]
const _RANK_GLYPH := ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "JK"]

# ---------------------------------------------------------------------------
# Configuración exportada
# ---------------------------------------------------------------------------

## Si es false, se renderiza el dorso. Útil para `RemoteHand` (F5).
@export var face_up: bool = true

## Tiempo del tween de re-layout cuando llega un nuevo target transform.
@export_range(0.05, 1.0, 0.05) var settle_duration: float = 0.22

## Escala extra al hacer hover (mouse / focus). En móvil sin hover se
## muestra al iniciar drag.
@export_range(1.0, 1.5, 0.05) var hover_scale: float = 1.12

## Si está activo, se añade `CardHoverOscillator` como hijo para FX táctil.
## Desactivable para `RemoteHand` (cartas de oponente) donde no hay input.
@export var enable_hover_fx: bool = true

# ---------------------------------------------------------------------------
# Estado
# ---------------------------------------------------------------------------

var card: Card:
	get:
		return _card

var _card: Card = null
var _state: InputState = InputState.IDLE
var _target_position: Vector2 = Vector2.ZERO
var _target_rotation: float = 0.0
var _settle_tween: Tween = null
var _hover_tween: Tween = null

# ---------------------------------------------------------------------------
# Nodos hijos
# ---------------------------------------------------------------------------

@onready var _shadow: ColorRect = $Shadow
@onready var _face_panel: PanelContainer = $Face
@onready var _back_panel: PanelContainer = $Back
@onready var _rank_top: Label = $Face/Margin/Layout/RankTop
@onready var _suit_center: Label = $Face/Margin/Layout/SuitCenter
@onready var _rank_bottom: Label = $Face/Margin/Layout/RankBottom


func _ready() -> void:
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE
	pivot_offset = CARD_SIZE * 0.5
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Drag&drop unifica táctil + ratón en Godot 4 si emulate_mouse_from_touch
	# está desactivado y use_accumulated_input=false (configurado en main.gd).
	_apply_card_skin()
	_render_face()
	if enable_hover_fx and face_up and _motion_allowed():
		_attach_hover_oscillator()


## Aplica StyleBox tokenizado a la cara (papel) y al dorso (azul/gold).
## Centraliza el look en `Tokens` para evitar hardcodes en .tscn.
func _apply_card_skin() -> void:
	var face_style: StyleBoxFlat = StyleBoxFlat.new()
	face_style.bg_color = Tokens.PAPER
	face_style.set_corner_radius_all(Tokens.R_MD)
	face_style.set_border_width_all(2)
	face_style.border_color = Tokens.PAPER_DIM.darkened(0.20)
	face_style.shadow_color = Color(0, 0, 0, 0.45)
	face_style.shadow_size = 4
	face_style.shadow_offset = Vector2(0, 2)
	if _face_panel != null:
		_face_panel.add_theme_stylebox_override("panel", face_style)

	var back_style: StyleBoxFlat = StyleBoxFlat.new()
	back_style.bg_color = Tokens.FELT_HI.darkened(0.10)
	back_style.set_corner_radius_all(Tokens.R_MD)
	back_style.set_border_width_all(3)
	back_style.border_color = Tokens.TRIM_GOLD
	back_style.shadow_color = Color(0, 0, 0, 0.45)
	back_style.shadow_size = 4
	back_style.shadow_offset = Vector2(0, 2)
	if _back_panel != null:
		_back_panel.add_theme_stylebox_override("panel", back_style)


func _attach_hover_oscillator() -> void:
	# Evita duplicarlo si ya existe (por reuso del nodo).
	if has_node(^"HoverOscillator"):
		return
	var osc: CardHoverOscillator = CardHoverOscillator.new()
	osc.name = "HoverOscillator"
	osc.hover_scale = hover_scale
	add_child(osc)


# Consulta el autoload Settings de forma segura (puede no existir en tests).
static func _motion_allowed() -> bool:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		var n: Node = (loop as SceneTree).root.get_node_or_null(^"Settings")
		if n != null:
			return not bool(n.get("reduce_motion"))
	return true


## Limpia el estado para que el nodo pueda reusarse desde un pool.
## Tras llamar a `reset_for_pool` el nodo queda invisible y sin signals
## conectadas; HandLayout debe re-bindear y volver a conectarlo antes de
## reanimarlo.
func reset_for_pool() -> void:
	_card = null
	_state = InputState.IDLE
	modulate = Color(1, 1, 1, 1)
	scale = Vector2.ONE
	rotation = 0.0
	_target_position = Vector2.ZERO
	_target_rotation = 0.0
	_kill_tween(_settle_tween)
	_kill_tween(_hover_tween)
	# Desconectar todas las conexiones externas a las señales del nodo.
	for sig in [drag_started, drag_ended, tapped]:
		for conn in sig.get_connections():
			sig.disconnect(conn["callable"])
	visible = false
	set_process(false)
	set_process_input(false)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Reverso de `reset_for_pool`: prepara el nodo para volver a montarse.
func revive_from_pool() -> void:
	visible = true
	set_process(true)
	set_process_input(true)
	mouse_filter = Control.MOUSE_FILTER_STOP
	modulate = Color(1, 1, 1, 1)
	scale = Vector2.ONE


# ---------------------------------------------------------------------------
# API pública
# ---------------------------------------------------------------------------

## Asocia este nodo visual a un `Card` lógico. Se puede llamar antes o
## después de `_ready()`. Re-renderiza el contenido.
func bind(card_resource: Card, is_face_up: bool = true) -> void:
	_card = card_resource
	face_up = is_face_up
	if is_inside_tree():
		_render_face()


## Define posición y rotación final dentro del padre. Si `animate` es true
## se anima con tween; si no, se aplica de inmediato (útil al spawnear
## desde un punto fijo, ej. mazo).
func set_target_transform(target_pos: Vector2, target_rot: float, animate: bool = true) -> void:
	_target_position = target_pos
	_target_rotation = target_rot
	if not animate or not is_inside_tree():
		position = target_pos
		rotation = target_rot
		return
	_kill_tween(_settle_tween)
	_settle_tween = create_tween() \
		.set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_CUBIC) \
		.set_parallel(true)
	_settle_tween.tween_property(self, "position", target_pos, settle_duration)
	_settle_tween.tween_property(self, "rotation", target_rot, settle_duration)


## Devuelve la posición objetivo conocida (la última fijada por HandLayout).
## Permite a HandLayout reanudar relayout sin re-calcular para todas las cartas.
func get_target_transform() -> Dictionary:
	return {"position": _target_position, "rotation": _target_rotation}


# ---------------------------------------------------------------------------
# Drag & Drop nativo de Godot (mouse + touch)
# ---------------------------------------------------------------------------

func _get_drag_data(_at_position: Vector2) -> Variant:
	if _card == null or not face_up:
		return null
	# Preview visual: clonar mínimo para evitar capturar referencias del padre.
	var preview: Control = _build_drag_preview()
	set_drag_preview(preview)

	_state = InputState.DRAGGING
	# Ocultamos la carta en mano mientras dura el drag para no duplicarla
	# visualmente. Restauramos en _notification(NOTIFICATION_DRAG_END).
	modulate.a = 0.35
	# Tap háptico al iniciar arrastre (jugador local).
	Haptics.tap()
	drag_started.emit(_card.id)
	return {
		"type": DRAG_PAYLOAD_TYPE,
		"card_id": _card.id,
		"source_path": get_path(),
	}


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		# Se llama tras drop válido O cancelación. is_drag_successful() distingue.
		if _state == InputState.DRAGGING:
			_state = InputState.IDLE
			modulate.a = 1.0
			# Si el drop no fue aceptado por ninguna DropZone, vibrar error.
			if not is_drag_successful():
				Haptics.error()
			drag_ended.emit(_card.id if _card != null else -1)


# ---------------------------------------------------------------------------
# Tap (sin drag): emitimos `tapped`
# ---------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if _card == null:
		return
	# Detectamos tap rápido (presionar y soltar sin moverse).
	# El drag&drop nativo se dispara solo si hay InputEventMouseMotion mientras
	# se mantiene presionado, así que un tap nunca activa _get_drag_data.
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed and _state != InputState.DRAGGING:
			tapped.emit(_card.id)
			accept_event()
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if not st.pressed and _state != InputState.DRAGGING:
			tapped.emit(_card.id)
			accept_event()


# ---------------------------------------------------------------------------
# Render
# ---------------------------------------------------------------------------

func _render_face() -> void:
	if _face_panel == null:
		return
	_face_panel.visible = face_up and _card != null
	_back_panel.visible = not face_up

	if not face_up or _card == null:
		_shadow.visible = true
		return

	var rank_text: String = _RANK_GLYPH[_card.rank] if _card.rank >= 0 and _card.rank < _RANK_GLYPH.size() else "?"
	var suit_text: String = _SUIT_GLYPH[_card.suit] if _card.suit >= 0 and _card.suit < _SUIT_GLYPH.size() else "?"

	_rank_top.text = rank_text
	_rank_bottom.text = rank_text
	_suit_center.text = suit_text

	var col: Color = _color_for_card(_card)
	_rank_top.add_theme_color_override("font_color", col)
	_rank_bottom.add_theme_color_override("font_color", col)
	_suit_center.add_theme_color_override("font_color", col)


static func _color_for_card(c: Card) -> Color:
	if c == null:
		return Tokens.INK
	if c.is_wildcard and c.rank == GameConfig.Rank.JOKER:
		return Tokens.JOKER_PURPLE
	if c.is_wildcard and c.rank == GameConfig.Rank.TWO:
		return Tokens.WILD_TWO_TEAL
	if c.rank == GameConfig.Rank.THREE and GameConfig.is_red_suit(c.suit):
		return Tokens.RED_THREE_GLOW
	if GameConfig.is_red_suit(c.suit):
		return Tokens.RED_SUIT
	return Tokens.BLACK_SUIT


func _build_drag_preview() -> Control:
	# Preview = duplicado liviano (sin scripts ni señales conectadas).
	var preview := Control.new()
	preview.size = CARD_SIZE
	preview.pivot_offset = CARD_SIZE * 0.5
	preview.scale = Vector2(hover_scale, hover_scale)

	var dup_face: Control = _face_panel.duplicate(DUPLICATE_USE_INSTANTIATION) as Control
	dup_face.size = CARD_SIZE
	dup_face.position = -CARD_SIZE * 0.5
	preview.add_child(dup_face)
	# Centramos el preview bajo el dedo.
	preview.position = -CARD_SIZE * 0.5
	return preview


# ---------------------------------------------------------------------------
# Utilidades internas
# ---------------------------------------------------------------------------

static func _kill_tween(t: Tween) -> void:
	if t != null and t.is_valid() and t.is_running():
		t.kill()
