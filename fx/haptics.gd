## Vibración háptica móvil con guards de seguridad y respeto a Settings.
##
## API estática (no requiere instancia):
##   `Haptics.tap()`     — feedback corto: drag start, hover (10ms)
##   `Haptics.success()` — drop válido / acción aceptada (40ms)
##   `Haptics.error()`   — drop cancelado / acción rechazada (80ms)
##
## Reglas:
##   - No-op en plataformas no-mobile (escritorio, web, headless).
##   - No-op si `Settings.vibration_enabled == false`.
##   - No-op si Godot está corriendo headless (`DisplayServer.headless`).
##   - Llamar desde *acciones del jugador local* únicamente. Nunca desde
##     callbacks de remotos para no drenar batería con eventos no
##     iniciados por el dueño del device.
class_name Haptics
extends RefCounted

const _DUR_TAP_MS: int = 10
const _DUR_SUCCESS_MS: int = 40
const _DUR_ERROR_MS: int = 80


static func tap() -> void:
	_vibrate(_DUR_TAP_MS)


static func success() -> void:
	_vibrate(_DUR_SUCCESS_MS)


static func error() -> void:
	_vibrate(_DUR_ERROR_MS)


static func _vibrate(duration_ms: int) -> void:
	if duration_ms <= 0:
		return
	if not OS.has_feature("mobile"):
		return
	if DisplayServer.get_name() == "headless":
		return
	# Acceso seguro al autoload Settings (puede no existir en tests headless).
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null:
		var settings_node: Node = tree.root.get_node_or_null(^"Settings")
		if settings_node != null and not bool(settings_node.get("vibration_enabled")):
			return
	Input.vibrate_handheld(duration_ms)
