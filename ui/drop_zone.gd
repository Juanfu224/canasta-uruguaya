## Zona de drop genérica para `CardUI`.
##
## Acepta payloads producidos por `CardUI._get_drag_data` con el formato:
##     `{type: "card", card_id: int, source_path: NodePath}`
##
## Re-valida el payload defensivamente (no asume que viene de nuestro propio
## código): un drop manipulado o roto debe rechazarse silenciosamente.
##
## Casos de uso:
##   - Pozo (descarte): `accept_kind = "discard"`.
##   - Mesa de combinaciones del equipo: `accept_kind = "meld"`.
##   - Slot vacío para crear nueva combinación: `accept_kind = "new_meld"`.
##
## El orquestador (Match.gd / RpcRouter en F5) escucha `card_dropped` y
## traduce el drop a una llamada `request_*` validada por el servidor.
class_name DropZone
extends Control

signal card_dropped(card_id: int, source_path: NodePath, kind: String)

const _PAYLOAD_TYPE: String = "card"

@export var accept_kind: String = "discard"

## Si está activo, resalta visualmente el área cuando un drag está sobre ella.
@export var highlight_on_hover: bool = true

@onready var _highlight: ColorRect = get_node_or_null("Highlight") as ColorRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	if _highlight != null:
		_highlight.modulate.a = 0.0


# ---------------------------------------------------------------------------
# Drag&Drop nativo
# ---------------------------------------------------------------------------

func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	var ok: bool = _is_valid_payload(data)
	if highlight_on_hover and _highlight != null:
		_highlight.modulate.a = 0.35 if ok else 0.0
	return ok


func _drop_data(_at: Vector2, data: Variant) -> void:
	if highlight_on_hover and _highlight != null:
		_highlight.modulate.a = 0.0
	if not _is_valid_payload(data):
		return
	var d: Dictionary = data
	# Háptica de confirmación al jugador local que soltó la carta.
	Haptics.success()
	card_dropped.emit(int(d["card_id"]), d["source_path"] as NodePath, accept_kind)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and highlight_on_hover and _highlight != null:
		_highlight.modulate.a = 0.0


# ---------------------------------------------------------------------------
# Validación defensiva
# ---------------------------------------------------------------------------

static func _is_valid_payload(data: Variant) -> bool:
	if not (data is Dictionary):
		return false
	var d: Dictionary = data
	if d.get("type", "") != _PAYLOAD_TYPE:
		return false
	if not (d.get("card_id", null) is int):
		return false
	if int(d["card_id"]) < 0:
		return false
	# source_path puede ser NodePath o String — acepta ambos.
	var sp: Variant = d.get("source_path", null)
	if sp == null:
		return false
	if not (sp is NodePath or sp is String):
		return false
	return true
