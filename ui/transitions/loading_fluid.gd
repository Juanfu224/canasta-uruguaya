## Transición fullscreen tipo "ola" (fluid). Útil entre rondas o al cargar
## una partida desde el menú.
##
## API:
##   var t: LoadingFluid = LoadingFluidScene.instantiate()
##   add_child(t)
##   await t.play_in(0.4)        # cubre la pantalla
##   # ... cargar la siguiente escena ...
##   await t.play_out(0.4)       # destapa
##   t.queue_free()
##
## También: `play_full(duration)` cubre y destapa con un callback intermedio.
##
## Cumple el requisito F4: transición <600ms incluso en gama media móvil.
class_name LoadingFluid
extends Control

@onready var _rect: ColorRect = $Wave

var _material: ShaderMaterial = null


func _ready() -> void:
	_material = Shaders.make_loading_fluid_material()
	_rect.material = _material
	# Empezamos invisibles para no molestar.
	_set_progress(0.0)
	mouse_filter = Control.MOUSE_FILTER_STOP


## Anima la cobertura de pantalla. `duration` ≤ 0.6s recomendado en móvil.
func play_in(duration: float = 0.4) -> Signal:
	return _animate_progress(0.0, 1.0, duration)


## Destapa la pantalla.
func play_out(duration: float = 0.4) -> Signal:
	return _animate_progress(1.0, 0.0, duration)


## Cubre, ejecuta `mid_callback`, y destapa.
func play_full(in_dur: float = 0.4, hold: float = 0.05, out_dur: float = 0.4, mid_callback: Callable = Callable()) -> void:
	await play_in(in_dur)
	if mid_callback.is_valid():
		mid_callback.call()
	if hold > 0.0:
		await get_tree().create_timer(hold).timeout
	await play_out(out_dur)


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

func _animate_progress(from_v: float, to_v: float, duration: float) -> Signal:
	_set_progress(from_v)
	duration = clampf(duration, 0.05, 1.0)
	var t: Tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	t.tween_method(_set_progress, from_v, to_v, duration)
	return t.finished


func _set_progress(p: float) -> void:
	if _material == null:
		return
	_material.set_shader_parameter("progress", clampf(p, 0.0, 1.0))
