## Disposición paramétrica de cartas en mano (fanning).
##
## Contiene `CardUI` como hijos y recalcula sus posiciones / rotaciones cada
## vez que se inserta o elimina una carta. La matemática es pública y pura
## (`compute_layout`) para poder testearla sin instanciar nodos.
##
## Diseño:
##   - El abanico se construye sobre un eje horizontal centrado en el pivot
##     del contenedor. La separación X entre cartas se ajusta dinámicamente
##     según el ancho disponible: a mayor número de cartas, mayor solape.
##   - La curva en Y es cuadrática (`(2t-1)^2`), simulando el arco que forma
##     la mano humana: extremos elevados, centro hundido. El signo se
##     invierte si `arc_concave_down` está en true (mano del oponente).
##   - La rotación interpola linealmente entre `±max_fan_angle_deg`.
##   - "Sine breathing": pequeño bob vertical sinusoidal por carta cuando la
##     mano está en reposo. Solo activo en `_process` mientras `_is_settled`
##     sea true (evita coste cuando está animándose).
##
## Performance:
##   - Un único `Tween` agrupa el relayout de todas las cartas (`set_parallel`).
##   - `_process` se desactiva si la amplitud del bob es 0 (configurable a 0
##     para HUDs estáticos / RemoteHand).
class_name HandLayout
extends Control

# ---------------------------------------------------------------------------
# Señales
# ---------------------------------------------------------------------------

signal card_added(card_id: int)
signal card_removed(card_id: int)
signal card_tapped(card_id: int)

# ---------------------------------------------------------------------------
# Configuración
# ---------------------------------------------------------------------------

const _CARD_SCENE: PackedScene = preload("res://ui/card_ui.tscn")

## Ángulo máximo del abanico (grados). Se aplica simétrico.
@export_range(0.0, 45.0, 0.5) var max_fan_angle_deg: float = 22.0

## Espaciado horizontal máximo entre cartas, en píxeles. Si el ancho
## disponible es insuficiente, se reduce automáticamente.
@export_range(20.0, 200.0, 1.0) var max_card_spacing: float = 88.0

## Magnitud de la curvatura vertical del abanico (alto del arco).
@export_range(0.0, 80.0, 1.0) var arc_height: float = 22.0

## Si es true, la curva apunta hacia abajo (mano del oponente arriba).
@export var arc_concave_down: bool = false

## Si es true, las cartas se renderizan boca arriba. False = dorso (RemoteHand).
@export var face_up: bool = true

## Amplitud del balanceo sinusoidal en reposo (px). 0 lo desactiva.
@export_range(0.0, 8.0, 0.25) var sine_amplitude: float = 1.5

## Frecuencia del balanceo (rad/s).
@export_range(0.5, 4.0, 0.1) var sine_frequency: float = 1.4

## Duración del tween de relayout.
@export_range(0.05, 1.0, 0.05) var settle_duration: float = 0.25

## Ancho máximo visible que el abanico puede ocupar (px). Si es <=0 se usa
## `size.x`. Lo setea `match_layout.gd` para evitar overflow al rotar la
## mano o cuando el viewport es estrecho.
@export var max_visible_width: float = 0.0

# ---------------------------------------------------------------------------
# Pool interno de CardUI
# ---------------------------------------------------------------------------

## Tope de nodos guardados en el pool por mano. 22-26 es el peor caso real
## (mano grande tras varios robos). Más allá de eso liberamos memoria.
const _MAX_POOL: int = 24

# ---------------------------------------------------------------------------
# Estado interno
# ---------------------------------------------------------------------------

var _cards: Array[CardUI] = []
var _pool: Array[CardUI] = []
var _layout_tween: Tween = null
var _is_settled: bool = true
var _time: float = 0.0


func _ready() -> void:
	clip_contents = false
	_update_process_state()


func _exit_tree() -> void:
	# Drenar el pool para no fugar nodos al cambiar de escena.
	for n in _pool:
		if is_instance_valid(n):
			n.queue_free()
	_pool.clear()


func _process(delta: float) -> void:
	if not _is_settled or sine_amplitude <= 0.0 or _cards.is_empty():
		return
	if not _breathing_allowed():
		return
	_time += delta
	# Breathing aditivo: NO sobreescribimos el target_position; sumamos un
	# offset visual al position cada frame.
	for i in _cards.size():
		var card_node: CardUI = _cards[i]
		if card_node == null:
			continue
		var target: Dictionary = card_node.get_target_transform()
		var base_pos: Vector2 = target.position
		var bob: float = sin(float(i) * 0.7 + _time * sine_frequency) * sine_amplitude
		card_node.position = base_pos + Vector2(0.0, bob)


# Consulta segura al autoload Settings (None en tests headless ⇒ permitido).
func _breathing_allowed() -> bool:
	if not is_inside_tree():
		return true
	var n: Node = get_tree().root.get_node_or_null(^"Settings")
	if n == null:
		return true
	return bool(n.call("breathing_allowed"))


func _update_process_state() -> void:
	set_process(sine_amplitude > 0.0)


# ---------------------------------------------------------------------------
# API pública
# ---------------------------------------------------------------------------

## Agrega una carta. Devuelve la `CardUI` creada (o null si `card` es null).
func add_card(card: Card, animate: bool = true) -> CardUI:
	if card == null:
		push_warning("HandLayout.add_card: card es null")
		return null
	var node: CardUI = _acquire_card_node()
	node.bind(card, face_up)
	# Spawn en el centro: el relayout lo lleva a su posición final.
	node.position = size * 0.5 - CardUI.CARD_SIZE * 0.5
	_cards.append(node)
	_connect_card_signals(node)
	relayout(animate)
	card_added.emit(card.id)
	return node


## Quita la primera carta cuyo id coincida. Devuelve true si la encontró.
func remove_card_by_id(card_id: int, animate: bool = true) -> bool:
	for i in _cards.size():
		var node: CardUI = _cards[i]
		if node != null and node.card != null and node.card.id == card_id:
			_cards.remove_at(i)
			_release_card_node(node)
			relayout(animate)
			card_removed.emit(card_id)
			return true
	return false


## Sincroniza la mano con `new_cards` reusando CardUI existentes via diff por
## `card.id`. Las cartas que dejan de estar se devuelven al pool y las nuevas
## se adquieren de él. Sólo hace un único relayout final.
func set_cards(new_cards: Array[Card]) -> void:
	var wanted_ids: Dictionary = {}
	for c in new_cards:
		if c != null:
			wanted_ids[c.id] = c

	# Eliminar cartas que ya no están en new_cards.
	var i: int = _cards.size() - 1
	while i >= 0:
		var node: CardUI = _cards[i]
		var cur_id: int = -1
		if node != null and node.card != null:
			cur_id = node.card.id
		if cur_id < 0 or not wanted_ids.has(cur_id):
			_cards.remove_at(i)
			_release_card_node(node)
			if cur_id >= 0:
				card_removed.emit(cur_id)
		i -= 1

	# Cartas existentes (por id) en orden actual.
	var present_ids: Dictionary = {}
	for n in _cards:
		if n != null and n.card != null:
			present_ids[n.card.id] = true

	# Añadir nuevas cartas en el orden de `new_cards`.
	for c in new_cards:
		if c == null:
			continue
		if present_ids.has(c.id):
			continue
		var node: CardUI = _acquire_card_node()
		node.bind(c, face_up)
		node.position = size * 0.5 - CardUI.CARD_SIZE * 0.5
		_cards.append(node)
		_connect_card_signals(node)
		card_added.emit(c.id)

	relayout(true)


## Ajusta la cantidad de cartas-dorso (RemoteHand). No requiere `Card`
## reales; usa cartas placeholder estables (id < 0) reusables del pool.
func set_card_count(n: int) -> void:
	var cur: int = _cards.size()
	if n == cur:
		return
	if n < cur:
		for _i in (cur - n):
			var node: CardUI = _cards.pop_back()
			_release_card_node(node)
		relayout(true)
		return
	var to_add: int = n - cur
	for j in to_add:
		var placeholder: Card = Card.new()
		placeholder.id = -1 - (cur + j)
		var node: CardUI = _acquire_card_node()
		node.bind(placeholder, face_up)
		node.position = size * 0.5 - CardUI.CARD_SIZE * 0.5
		_cards.append(node)
		_connect_card_signals(node)
	relayout(true)


# ---------------------------------------------------------------------------
# Pool helpers
# ---------------------------------------------------------------------------

func _acquire_card_node() -> CardUI:
	var node: CardUI = null
	while not _pool.is_empty():
		var candidate: CardUI = _pool.pop_back()
		if is_instance_valid(candidate):
			node = candidate
			break
	if node == null:
		node = _CARD_SCENE.instantiate() as CardUI
		add_child(node)
	else:
		node.revive_from_pool()
	return node


func _release_card_node(node: CardUI) -> void:
	if node == null or not is_instance_valid(node):
		return
	# Desconectar señales previas y limpiar estado.
	if node.drag_ended.is_connected(_on_card_drag_ended):
		node.drag_ended.disconnect(_on_card_drag_ended)
	if node.tapped.is_connected(_on_card_tapped):
		node.tapped.disconnect(_on_card_tapped)
	node.reset_for_pool()
	if _pool.size() < _MAX_POOL:
		_pool.append(node)
	else:
		# El pool está lleno: descartar al árbol para liberar memoria.
		node.queue_free()


func get_card_count() -> int:
	return _cards.size()


## Recalcula posiciones de todas las cartas según el ancho disponible.
func relayout(animate: bool = true) -> void:
	if _cards.is_empty():
		return
	var effective_width: float = size.x
	if max_visible_width > 0.0:
		effective_width = minf(effective_width, max_visible_width)
	var transforms: Array = compute_layout(
		_cards.size(),
		effective_width,
		max_card_spacing,
		max_fan_angle_deg,
		arc_height,
		arc_concave_down,
	)
	_kill_tween()
	_is_settled = false
	if animate:
		_layout_tween = create_tween() \
			.set_ease(Tween.EASE_OUT) \
			.set_trans(Tween.TRANS_CUBIC) \
			.set_parallel(true)
		for i in _cards.size():
			var node: CardUI = _cards[i]
			if node == null:
				continue
			var t: Dictionary = transforms[i]
			node.set_target_transform(t.position, t.rotation, false)
			_layout_tween.tween_property(node, "position", t.position, settle_duration)
			_layout_tween.tween_property(node, "rotation", t.rotation, settle_duration)
		_layout_tween.chain().tween_callback(_on_layout_settled)
	else:
		for i in _cards.size():
			var node: CardUI = _cards[i]
			if node == null:
				continue
			var t: Dictionary = transforms[i]
			node.set_target_transform(t.position, t.rotation, false)
		_is_settled = true


# ---------------------------------------------------------------------------
# Matemática del fanning (pura, testeable)
# ---------------------------------------------------------------------------

## Calcula la lista de transforms `{position, rotation}` para `n_cards`.
## - `container_width`: ancho del contenedor padre (px).
## - `max_spacing`: separación deseada entre cartas (px).
## - `fan_angle_deg`: ángulo simétrico máximo en grados.
## - `arc`: altura del arco vertical.
## - `concave_down`: invierte la curva.
##
## Devuelve un `Array[Dictionary]` con las claves `position: Vector2` y
## `rotation: float` (radianes). La posición se da del top-left del nodo
## CardUI (`size = CARD_SIZE`).
static func compute_layout(
	n_cards: int,
	container_width: float,
	max_spacing: float,
	fan_angle_deg: float,
	arc: float,
	concave_down: bool,
) -> Array:
	var out: Array = []
	if n_cards <= 0:
		return out

	var card_w: float = CardUI.CARD_SIZE.x
	var card_h: float = CardUI.CARD_SIZE.y

	# Espaciado adaptativo: si todo el abanico no entra, reducir.
	var available: float = maxf(container_width - card_w, 0.0)
	var spacing: float = max_spacing
	if n_cards > 1:
		spacing = minf(max_spacing, available / float(n_cards - 1))
	# Ancho ocupado por el centro de la carta más a la izquierda al más a la derecha.
	var span: float = spacing * float(maxi(n_cards - 1, 0))
	var center_x: float = container_width * 0.5
	var max_rad: float = deg_to_rad(fan_angle_deg)
	var arc_sign: float = 1.0 if concave_down else -1.0

	for i in n_cards:
		var t: float = 0.5 if n_cards == 1 else float(i) / float(n_cards - 1)
		var x: float = center_x - span * 0.5 + spacing * float(i) - card_w * 0.5
		# Curva cuadrática: (2t-1)^2 ∈ [0,1], cero en el centro, 1 en extremos.
		var quad: float = (2.0 * t - 1.0) * (2.0 * t - 1.0)
		var y_offset: float = quad * arc * arc_sign
		var y: float = card_h * 0.0 + y_offset  # baseline = 0 en y, ajustar fuera
		var rot: float = lerp_angle(-max_rad, max_rad, t)
		out.append({"position": Vector2(x, y), "rotation": rot})
	return out


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

func _on_layout_settled() -> void:
	_is_settled = true


func _connect_card_signals(node: CardUI) -> void:
	node.drag_ended.connect(_on_card_drag_ended)
	if not node.tapped.is_connected(_on_card_tapped):
		node.tapped.connect(_on_card_tapped)


func _on_card_tapped(card_id: int) -> void:
	card_tapped.emit(card_id)


func _on_card_drag_ended(_card_id: int) -> void:
	# Si el drop fue exitoso, el orquestador (Match.gd) habrá llamado a
	# remove_card_by_id; si no, simplemente reanimamos el layout para que
	# la carta vuelva a su sitio.
	relayout(true)


func _kill_tween() -> void:
	if _layout_tween != null and _layout_tween.is_valid() and _layout_tween.is_running():
		_layout_tween.kill()
