shader_type spatial;
render_mode cull_disabled;
#include "res://scripts/city_common.gdshaderinc"
// Laub: Blattmuster aus Rauschen (Alpha-Test), weiche Kugel-Normalen, Wind, Licht durch die Blaetter.

uniform sampler2D n_leaf : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D n_blotch : repeat_enable, filter_linear_mipmap_anisotropic;
uniform float wind = 1.0;
uniform float leaf_scale = 1.15;
uniform float cover = 0.55;

varying vec3 wp;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float k = clamp(VERTEX.y * 0.12, 0.0, 1.0);
	float sw = sin(TIME * 1.3 + w.x * 0.31 + w.z * 0.23) * 0.05 + sin(TIME * 3.1 + w.x * 0.9 + w.z * 0.7) * 0.02;
	VERTEX.x += sw * k * wind;
	VERTEX.z += cos(TIME * 1.1 + w.z * 0.29) * 0.035 * k * wind;
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 lp = wp.xz * leaf_scale + vec2(wp.y * 1.7, wp.y * 2.3);
	float l1 = texture(n_leaf, lp * 0.5).r;
	float l2 = texture(n_leaf, lp * 1.35 + vec2(0.3, 0.6)).r;
	float leaf = l1 * 0.6 + l2 * 0.4;
	float edge = 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW)));
	float thr = (1.0 - cover) + 0.22 * edge * edge;
	ALPHA = step(thr, leaf);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	float v = texture(n_blotch, wp.xz * 0.35 + wp.y * 0.2).r;
	vec3 base = COLOR.rgb;
	// dunklere Tiefe, hellere Blaetter an der Oberflaeche
	float tone = 0.85 + 0.9 * smoothstep(0.25, 0.75, l2) * (0.6 + 0.4 * v);
	ALBEDO = base * tone;
	ROUGHNESS = 0.75;
	SPECULAR = 0.3;
	BACKLIGHT = ALBEDO * 0.35;
}
