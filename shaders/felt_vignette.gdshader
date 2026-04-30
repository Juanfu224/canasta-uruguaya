// Vignette radial sobre el fieltro: oscurece bordes para guiar la atención
// al centro de la mesa. Una sola muestra por fragmento, sin loops, sin
// samplers externos. Compatible con renderer Mobile y GLES3.
shader_type canvas_item;

uniform vec4 inner_color : source_color = vec4(0.075, 0.251, 0.184, 1.0);
uniform vec4 outer_color : source_color = vec4(0.024, 0.063, 0.051, 1.0);
uniform float strength : hint_range(0.0, 1.5) = 0.85;
uniform float falloff : hint_range(0.5, 4.0) = 1.6;

void fragment() {
	vec2 uv = UV - vec2(0.5);
	// Distancia normalizada con corrección suave de aspecto.
	float d = length(uv) * 1.4142136;
	float v = pow(clamp(d, 0.0, 1.0), falloff);
	vec3 mixed = mix(inner_color.rgb, outer_color.rgb, v * strength);
	COLOR = vec4(mixed, 1.0);
}
