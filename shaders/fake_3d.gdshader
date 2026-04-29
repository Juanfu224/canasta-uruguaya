// Tilt 3D paramétrico para CanvasItem (port de Balatro `fake_3D.gdshader`).
//
// Aplicar a un nodo con TEXTURE válida (TextureRect / Sprite2D). Animar
// `x_rot` y `y_rot` desde GDScript. Coste: matriz 3x3 + 1 sample por frag.
// Apto para gama media móvil con <50 instancias visibles.
shader_type canvas_item;

uniform vec2 rect_size;
uniform float fov : hint_range(1.0, 179.0) = 90.0;
uniform bool cull_back = true;
uniform float y_rot : hint_range(-360.0, 360.0) = 0.0;
uniform float x_rot : hint_range(-360.0, 360.0) = 0.0;
uniform float inset : hint_range(0.0, 1.0) = 0.0;

varying flat vec2 o;
varying vec3 p;

void vertex() {
	float sin_b = sin(y_rot / 180.0 * PI);
	float cos_b = cos(y_rot / 180.0 * PI);
	float sin_c = sin(x_rot / 180.0 * PI);
	float cos_c = cos(x_rot / 180.0 * PI);

	mat3 inv_rot_mat;
	inv_rot_mat[0] = vec3(cos_b, 0.0, -sin_b);
	inv_rot_mat[1] = vec3(sin_b * sin_c, cos_c, cos_b * sin_c);
	inv_rot_mat[2] = vec3(sin_b * cos_c, -sin_c, cos_b * cos_c);

	float t = tan(fov / 360.0 * PI);
	p = inv_rot_mat * vec3((UV - 0.5), 0.5 / t);
	float v = (0.5 / t) + 0.5;
	p.xy *= v * inv_rot_mat[2].z;
	o = v * inv_rot_mat[2].xy;

	VERTEX += (UV - 0.5) * rect_size * t * (1.0 - inset);
}

void fragment() {
	if (cull_back && p.z <= 0.0) discard;
	vec2 uv = (p.xy / p.z).xy - o;
	COLOR = texture(TEXTURE, uv + 0.5);
	COLOR.a *= step(max(abs(uv.x), abs(uv.y)), 0.5);
}
