// Disolución con borde de "quemado" (port de Balatro `dissolve.gdshader`).
//
// Animar `dissolve_value` 1.0 -> 0.0 para hacer desaparecer la carta. La
// textura `dissolve_texture` es un noise (ver `Shaders.get_dissolve_noise()`).
shader_type canvas_item;

uniform sampler2D dissolve_texture : source_color, repeat_enable, filter_linear;
uniform float dissolve_value : hint_range(0.0, 1.0) = 1.0;
uniform float burn_size : hint_range(0.0, 1.0, 0.01) = 0.05;
uniform vec4 burn_color : source_color = vec4(1.0, 0.55, 0.15, 1.0);

void fragment() {
	vec4 main_texture = texture(TEXTURE, UV);
	vec4 noise_texture = texture(dissolve_texture, UV);

	float burn_size_step = burn_size * step(0.001, dissolve_value) * step(dissolve_value, 0.999);
	float threshold = smoothstep(noise_texture.x - burn_size_step, noise_texture.x, dissolve_value);
	float border = smoothstep(noise_texture.x, noise_texture.x + burn_size_step, dissolve_value);

	COLOR = main_texture;
	COLOR.a *= threshold;
	COLOR.rgb = mix(burn_color.rgb, main_texture.rgb, border);
}
