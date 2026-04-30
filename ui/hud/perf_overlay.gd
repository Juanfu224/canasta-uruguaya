## Overlay de performance para QA en builds de debug.
##
## Muestra en pantalla:
##   - FPS actual (Engine.get_frames_per_second).
##   - Draw calls por frame (RENDER_TOTAL_DRAW_CALLS_IN_FRAME).
##   - Memoria estática (MEMORY_STATIC) en MB.
##   - Cantidad de nodos vivos (OBJECT_NODE_COUNT).
##
## Solo se instancia desde `scenes/main.gd` cuando `OS.is_debug_build()`.
## La tecla F3 alterna su visibilidad. Es transparente al input (mouse_filter
## IGNORE en todos los hijos) para no interferir con el juego.
extends CanvasLayer

const _UPDATE_INTERVAL: float = 0.5

@onready var _label: Label = $Panel/Label

var _accum: float = 0.0
var _visible: bool = true


func _ready() -> void:
	# Sobrevive cambios de escena (lo monta Main en root).
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	_label.add_theme_color_override("font_color", Color(0.9, 1.0, 0.9))


func _process(delta: float) -> void:
	if not _visible:
		return
	_accum += delta
	if _accum < _UPDATE_INTERVAL:
		return
	_accum = 0.0
	var fps: float = Engine.get_frames_per_second()
	var draws: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var mem_mb: float = float(Performance.get_monitor(Performance.MEMORY_STATIC)) / (1024.0 * 1024.0)
	var nodes: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	_label.text = "FPS %.0f  draws %d  mem %.1f MB  nodes %d" % [fps, draws, mem_mb, nodes]


func _input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		if (event as InputEventKey).keycode == KEY_F3:
			_visible = not _visible
			$Panel.visible = _visible
