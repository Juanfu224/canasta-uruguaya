## Helpers compartidos para shaders del proyecto.
##
## Centraliza la creación de la textura de noise reutilizable que usan
## el shader `dissolve.gdshader` y cualquier otro FX disolutivo.
class_name Shaders
extends RefCounted

const FAKE_3D_PATH: StringName = &"res://shaders/fake_3d.gdshader"
const DISSOLVE_PATH: StringName = &"res://shaders/dissolve.gdshader"
const LOADING_FLUID_PATH: StringName = &"res://shaders/loading_fluid.gdshader"

static var _dissolve_noise: NoiseTexture2D = null


## Devuelve una `NoiseTexture2D` reutilizable de 256x256 (suficiente para
## las cartas de 120x168). Se construye una sola vez y se cachea.
static func get_dissolve_noise() -> NoiseTexture2D:
	if _dissolve_noise != null:
		return _dissolve_noise
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.04
	noise.seed = 1337
	var tex: NoiseTexture2D = NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.normalize = true
	tex.noise = noise
	_dissolve_noise = tex
	return _dissolve_noise


## Crea un `ShaderMaterial` para `dissolve` listo para usar. El parámetro
## `dissolve_value` empieza en 1.0 (carta visible). Animar a 0.0 para
## desintegrar.
static func make_dissolve_material(burn_color: Color = Color(1.0, 0.55, 0.15)) -> ShaderMaterial:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = load(DISSOLVE_PATH) as Shader
	mat.set_shader_parameter("dissolve_texture", get_dissolve_noise())
	mat.set_shader_parameter("dissolve_value", 1.0)
	mat.set_shader_parameter("burn_size", 0.07)
	mat.set_shader_parameter("burn_color", burn_color)
	return mat


## Crea un `ShaderMaterial` para `loading_fluid`. `progress` arranca en 0.0
## (pantalla en bg_color) y se anima a 1.0 (totalmente cubierta).
static func make_loading_fluid_material(
	bg_color: Color = Color(0.07, 0.10, 0.12),
	wave_1_color: Color = Color(0.10, 0.45, 0.70),
	wave_2_color: Color = Color(0.06, 0.32, 0.55)
) -> ShaderMaterial:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = load(LOADING_FLUID_PATH) as Shader
	mat.set_shader_parameter("progress", 0.0)
	mat.set_shader_parameter("bg_color", bg_color)
	mat.set_shader_parameter("wave_1_color", wave_1_color)
	mat.set_shader_parameter("wave_2_color", wave_2_color)
	mat.set_shader_parameter("wave_seperation", 0.025)
	return mat
