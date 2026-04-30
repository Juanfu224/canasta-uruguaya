## Controlador de layout responsive para `MatchOffline`.
##
## Recalcula posiciones, tamaños y rotaciones de las 4 manos + zona central
## (Deck/Pozo) + HUD según el viewport actual. Soporta:
##   - Portrait (h > w): mano local abajo, compañero arriba, oponentes a
##     izquierda y derecha rotados 90°.
##   - Landscape (w >= h): cruz aplanada — la zona central se ensancha y
##     las manos laterales se compactan. La mano superior se acerca al
##     borde para liberar espacio central.
##
## Filosofía:
##   - Sin layout containers nativos para las manos (el fanning paramétrico
##     necesita posiciones absolutas). Los anclajes se setean por código.
##   - Reacciona a `NOTIFICATION_RESIZED` con `call_deferred` para evitar
##     reentrancia con tweens de las cartas.
##   - Idempotente: aplicar el mismo layout dos veces produce el mismo
##     resultado.
##
## NO toca lógica de partida ni red.
class_name MatchLayout
extends Node

const _HAND_ASPECT_HEIGHT: float = 200.0  # alto del abanico de una mano
const _SIDE_HAND_HEIGHT_RATIO: float = 0.55  # % del viewport h para hands laterales
const _CENTER_W_PORTRAIT: float = 320.0
const _CENTER_W_LANDSCAPE: float = 380.0
const _MARGIN: float = 20.0

var _root: Control = null
var _local: Control = null
var _top: Control = null
var _left: Control = null
var _right: Control = null
var _center: Control = null
var _melds: Control = null
var _top_hud: CanvasLayer = null
var _bottom_hud: CanvasLayer = null

var _is_portrait_cached: bool = true


## Configura el controlador con referencias explícitas a los nodos a
## reposicionar. Llamar desde `MatchOffline._ready()`.
func bind_nodes(
	root: Control,
	local_hand: Control,
	top_hand: Control,
	left_hand: Control,
	right_hand: Control,
	center: Control,
	melds_table: Control,
) -> void:
	_root = root
	_local = local_hand
	_top = top_hand
	_left = left_hand
	_right = right_hand
	_center = center
	_melds = melds_table


func _ready() -> void:
	if _root != null:
		_root.resized.connect(_on_resized)
	# Layout inicial diferido para asegurar que `size` ya está propagado.
	call_deferred("apply_layout")


func _on_resized() -> void:
	# Diferido: evita reentrancia con tweens en curso.
	call_deferred("apply_layout")


## Aplica el layout al tamaño actual del root. Público para tests y para
## forzar un recalculo tras un cambio de orientación lógico.
func apply_layout() -> void:
	if _root == null or not _root.is_inside_tree():
		return
	var vp: Vector2 = _root.size
	if vp.x <= 0.0 or vp.y <= 0.0:
		return
	var portrait: bool = vp.y > vp.x
	_is_portrait_cached = portrait

	if portrait:
		_apply_portrait(vp)
	else:
		_apply_landscape(vp)


func is_portrait() -> bool:
	return _is_portrait_cached


# ---------------------------------------------------------------------------
# Portrait: mesa vertical, mano local abajo amplia, oponentes en cruz.
# ---------------------------------------------------------------------------

func _apply_portrait(vp: Vector2) -> void:
	var w: float = vp.x
	var h: float = vp.y

	# Mesa de melds arriba-centro.
	if _melds != null:
		var mh: float = clampf(h * 0.18, 140.0, 220.0)
		_set_rect(_melds, _MARGIN, _MARGIN, w - _MARGIN * 2.0, mh)

	# Mano superior (compañero, dorso) — debajo de la mesa de melds.
	if _top != null:
		var top_h: float = _HAND_ASPECT_HEIGHT
		var top_w: float = clampf(w - _MARGIN * 2.0, 320.0, 720.0)
		var top_y: float = clampf(h * 0.18, 140.0, 220.0) + _MARGIN
		_set_rect(_top, (w - top_w) * 0.5, top_y, top_w, top_h)
		_top.rotation = 0.0
		_apply_hand_width(_top, top_w * 0.92)

	# Manos laterales (rotadas 90°). Centradas verticalmente.
	var side_h: float = h * _SIDE_HAND_HEIGHT_RATIO
	var side_w: float = _HAND_ASPECT_HEIGHT
	var side_cy: float = h * 0.5
	if _left != null:
		# Tras rotar PI/2, el rect "pivot_offset" sirve si el origen se
		# define en su esquina sup-izq. Trabajamos con position + size en
		# eje sin rotar, luego aplicamos rotación.
		_set_rect(_left, _MARGIN, side_cy - side_h * 0.5, side_w, side_h)
		_left.pivot_offset = Vector2(side_w * 0.5, side_h * 0.5)
		_left.rotation = PI * 0.5
		# Compensación: tras rotación, el bounding box se invierte.
		# Empujamos position para que la mano quede pegada al borde izquierdo.
		var off_l: Vector2 = _rotated_offset(side_w, side_h, PI * 0.5)
		_left.position += off_l
		_apply_hand_width(_left, side_h * 0.90)
	if _right != null:
		_set_rect(_right, w - _MARGIN - side_w, side_cy - side_h * 0.5, side_w, side_h)
		_right.pivot_offset = Vector2(side_w * 0.5, side_h * 0.5)
		_right.rotation = -PI * 0.5
		var off_r: Vector2 = _rotated_offset(side_w, side_h, -PI * 0.5)
		_right.position += off_r
		_apply_hand_width(_right, side_h * 0.90)

	# Centro: deck + pozo. Lo ubica el HBox padre, sólo aseguramos posición.
	if _center != null:
		var cw: float = _CENTER_W_PORTRAIT
		var ch: float = 220.0
		_set_rect(_center, (w - cw) * 0.5, (h - ch) * 0.5, cw, ch)

	# Mano local abajo, ancha.
	if _local != null:
		var lw: float = clampf(w - _MARGIN * 2.0, 320.0, 760.0)
		var lh: float = 240.0
		var ly: float = h - lh - _MARGIN - 64.0  # 64 = espacio para BottomHud
		_set_rect(_local, (w - lw) * 0.5, ly, lw, lh)
		_local.rotation = 0.0
		_apply_hand_width(_local, lw * 0.94)


# ---------------------------------------------------------------------------
# Landscape: zona central ancha, manos compactas.
# ---------------------------------------------------------------------------

func _apply_landscape(vp: Vector2) -> void:
	var w: float = vp.x
	var h: float = vp.y

	# Mesa de melds: arriba abarcando 60% del ancho centrado.
	if _melds != null:
		var mw: float = clampf(w * 0.55, 480.0, 900.0)
		var mh: float = clampf(h * 0.20, 130.0, 200.0)
		_set_rect(_melds, (w - mw) * 0.5, _MARGIN, mw, mh)

	# Mano superior (compañero) inmediatamente debajo de la mesa.
	if _top != null:
		var top_w: float = clampf(w * 0.50, 460.0, 820.0)
		var top_h: float = _HAND_ASPECT_HEIGHT
		var top_y: float = clampf(h * 0.20, 130.0, 200.0) + _MARGIN
		_set_rect(_top, (w - top_w) * 0.5, top_y, top_w, top_h)
		_top.rotation = 0.0
		_apply_hand_width(_top, top_w * 0.92)

	# Manos laterales: ocupan 60% de la altura.
	var side_h: float = h * 0.60
	var side_w: float = _HAND_ASPECT_HEIGHT
	var side_cy: float = h * 0.55
	if _left != null:
		_set_rect(_left, _MARGIN, side_cy - side_h * 0.5, side_w, side_h)
		_left.pivot_offset = Vector2(side_w * 0.5, side_h * 0.5)
		_left.rotation = PI * 0.5
		_left.position += _rotated_offset(side_w, side_h, PI * 0.5)
		_apply_hand_width(_left, side_h * 0.90)
	if _right != null:
		_set_rect(_right, w - _MARGIN - side_w, side_cy - side_h * 0.5, side_w, side_h)
		_right.pivot_offset = Vector2(side_w * 0.5, side_h * 0.5)
		_right.rotation = -PI * 0.5
		_right.position += _rotated_offset(side_w, side_h, -PI * 0.5)
		_apply_hand_width(_right, side_h * 0.90)

	# Centro entre la mesa y la mano local.
	if _center != null:
		var cw: float = _CENTER_W_LANDSCAPE
		var ch: float = 220.0
		_set_rect(_center, (w - cw) * 0.5, (h - ch) * 0.5 + 20.0, cw, ch)

	# Mano local abajo.
	if _local != null:
		var lw: float = clampf(w * 0.55, 520.0, 980.0)
		var lh: float = 220.0
		var ly: float = h - lh - _MARGIN - 56.0
		_set_rect(_local, (w - lw) * 0.5, ly, lw, lh)
		_local.rotation = 0.0
		_apply_hand_width(_local, lw * 0.94)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _set_rect(node: Control, x: float, y: float, w: float, h: float) -> void:
	# Reset anchors a top-left para trabajar en coordenadas absolutas.
	node.anchor_left = 0.0
	node.anchor_top = 0.0
	node.anchor_right = 0.0
	node.anchor_bottom = 0.0
	node.offset_left = 0.0
	node.offset_top = 0.0
	node.offset_right = 0.0
	node.offset_bottom = 0.0
	node.position = Vector2(x, y)
	node.size = Vector2(w, h)


## Tras rotar un Control alrededor de pivot_offset, su bounding box se
## desplaza. Devuelve la corrección a aplicar a `position` para que la
## caja rotada quede en la misma esquina que la sin rotar.
static func _rotated_offset(w: float, h: float, rot_rad: float) -> Vector2:
	var cx: float = w * 0.5
	var cy: float = h * 0.5
	var cs: float = cos(rot_rad)
	var sn: float = sin(rot_rad)
	# Esquina sup-izq tras rotar alrededor del centro:
	var rx: float = cs * (-cx) - sn * (-cy)
	var ry: float = sn * (-cx) + cs * (-cy)
	return Vector2(cx - (cx + rx), cy - (cy + ry))


## Setea `max_visible_width` y ejecuta relayout si la mano lo soporta.
static func _apply_hand_width(hand: Control, w: float) -> void:
	if hand == null:
		return
	if hand.has_method("set"):
		hand.set("max_visible_width", w)
	if hand.has_method("relayout"):
		hand.call("relayout", false)
